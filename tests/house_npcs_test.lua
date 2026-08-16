-- Object-index hygiene + overworld NPC / legendary content smoke tests.
return function(T, Data, run)
  local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
  local MapScripts = require("src.script.MapScripts")
  local Competitive = require("mods.Kanto-Reforged.items.competitive_items")
  local BerryQuests = require("mods.Kanto-Reforged.world.berry_quests")
  local Roamers = require("mods.Kanto-Reforged.world.roamers")
  local DexNav = require("mods.Kanto-Reforged.ui.dexnav")
  local LegendMythicals = require("mods.Kanto-Reforged.world.legend_mythicals")
  local Warp = require("src.world.Warp")

  -- Claim registry must include baseline + every appendNpc from this milestone.
  local claims = HouseNpcs.claims()
  local function claimed(map, index, owner)
    local k = map .. "#" .. tostring(index)
    T.eq(claims[k], owner, k .. " owned by " .. owner)
  end
  claimed("VIRIDIAN_CITY", 8, "level_caps")
  claimed("CELADON_CITY", 10, "overworld_loot")
  claimed("LAVENDER_TOWN", 4, "overworld_loot")
  claimed("SAFFRON_CITY", 16, "overworld_loot")
  claimed("POWER_PLANT", 15, "overworld_loot")
  claimed("ROCK_TUNNEL_B1F", 9, "overworld_loot")
  claimed("CELADON_MANSION_2F", 1, "battle_clubs")
  claimed("CELADON_MANSION_2F", 2, "roamers")
  claimed("CELADON_MANSION_ROOF", 1, "legend_shrines")
  claimed("UNDERGROUND_PATH_ROUTE_5", 2, "judge_npc")
  claimed("SAFFRON_PIDGEY_HOUSE", 5, "move_hub")
  claimed("CINNABAR_LAB_METRONOME_ROOM", 3, "item_smith")
  claimed("ROUTE_23", 8, "legend_mythicals")
  claimed("POWER_PLANT", 16, "legend_regis")
  -- Sevii ferry uses the existing Vermilion City gangway sailor (no new dock NPC)

  -- Double-claim must error
  local ok, err = pcall(HouseNpcs.claim, "CELADON_MANSION_2F", 1, "other")
  T.check(not ok, "duplicate claim errors")
  T.check(tostring(err):find("collision", 1, true) ~= nil, "collision message")

  -- Objects present on maps
  local function findObj(mapId, name)
    for _, o in ipairs(Data.maps[mapId].objects or {}) do
      if o.name == name then return o end
    end
    return nil
  end
  T.check(findObj("CELADON_MANSION_2F", "CELADONMANSION2F_BATTLE_CLUB") ~= nil,
    "Battle Club NPC present")
  T.check(findObj("CELADON_MANSION_2F", "CELADONMANSION2F_BEAST_TRACKER") ~= nil,
    "Beast Tracker NPC present")
  T.check(findObj("CELADON_MANSION_ROOF", "CELADONMANSIONROOF_HO_OH") ~= nil,
    "Ho-Oh on roof")
  do
    local LegendShrines = require("mods.Kanto-Reforged.world.legend_shrines")
    local hoOh = findObj("CELADON_MANSION_ROOF", "CELADONMANSIONROOF_HO_OH")
    T.eq(hoOh.x, LegendShrines.HO_OH_X, "Ho-Oh on patio x")
    T.eq(hoOh.y, LegendShrines.HO_OH_Y, "Ho-Oh on patio y")
    T.check(hoOh.x ~= 4,
      "Ho-Oh not in east corridor (Eevee path)")

    local Map = require("src.world.Map")
    local def = Data.maps.CELADON_MANSION_ROOF
    local ts = Data.tilesets.MANSION
    -- Vanilla cabin top stays solid — no custom walk-on-roof blocks.
    T.check(not Map.defIsWalkableCell(def, ts, 2, 4),
      "cabin roof stays solid (no broken walkable patch)")
    T.check(not Map.defIsWalkableCell(def, ts, 3, 4),
      "cabin roof east cell stays solid")
    T.check(Map.defIsWalkableCell(def, ts, LegendShrines.HO_OH_X, LegendShrines.HO_OH_Y),
      "Ho-Oh patio cell is walkable")
    T.check(Map.defIsWalkableCell(def, ts, 4, 5),
      "east corridor stays walkable (Eevee path)")
    T.check(Map.defIsWalkableCell(def, ts, 2, 7),
      "Eevee house door still walkable")
    -- Vanilla uses two stair warps; both remain.
    local stairs = 0
    for _, w in ipairs(def.warps or {}) do
      if w.destMap == "CELADON_MANSION_3F" then stairs = stairs + 1 end
    end
    T.eq(stairs, 2, "both roof stair warps to 3F remain")
  end
  T.check(findObj("ROUTE_2_TRADE_HOUSE", "ROUTE2TRADEHOUSE_TAILLOW") ~= nil,
    "Taillow trade NPC")
  T.check(findObj("FUCHSIA_BILLS_GRANDPAS_HOUSE", "FUCHSIABILLSGRANDPASHOUSE_SEEDOT") ~= nil,
    "Seedot trade NPC")

  -- Talk must start Commands.trade via ScriptRunner, not a bare call
  -- (no ctx.runner → instant close).
  do
    local MapScripts = require("src.script.MapScripts")
    local m = MapScripts.get("ROUTE_2_TRADE_HOUSE")
    local talk = m and m.talk and m.talk.TEXT_ROUTE2TRADEHOUSE_TAILLOW
    T.check(type(talk) == "function", "Taillow trader has a Lua talk handler")
    local ran
    local fakeOw = {
      runner = {
        run = function(_, script, extra)
          ran = { script = script, extra = extra }
        end,
      },
    }
    local game = { data = Data, save = { party = {} }, stack = { push = function() end } }
    talk(game, fakeOw, {}, function() end)
    T.check(ran ~= nil, "Taillow talk starts the script runner")
    T.eq(ran.script[1][1], "trade", "runner script is the trade command")
    T.eq(ran.script[1][2], 11, "trade index 11 is Taillow")
    T.eq(ran.script[1][3], "MOD_TRADE_TAILLOW_DONE", "trade completion flag")
  end

  -- Talk handlers resolve through compose
  local function talkOk(map, text)
    local m = MapScripts.get(map)
    return m and m.talk and m.talk[text] ~= nil
  end
  T.check(talkOk("CELADON_MANSION_2F", "TEXT_CELADONMANSION2F_BATTLE_CLUB"),
    "Battle Club talk")
  T.check(talkOk("CELADON_MANSION_2F", "TEXT_CELADONMANSION2F_BEAST_TRACKER"),
    "Tracker talk")
  T.check(talkOk("UNDERGROUND_PATH_ROUTE_5", "TEXT_UNDERGROUNDPATHROUTE5_JUDGE"),
    "Judge talk")
  T.check(talkOk("SAFFRON_PIDGEY_HOUSE", "TEXT_SAFFRONPIDGEYHOUSE_MOVE_HUB"),
    "Move Hub talk")

  -- Every KR-added overworld object with a TEXT_ id must have a Lua talk
  -- handler (item balls use OverworldState:talkTo's item arm instead).
  do
    local expectTalk = {
      { "VIRIDIAN_CITY", "TEXT_VIRIDIANCITY_CANDY_GUY" },
      { "CELADON_CITY", "TEXT_CELADONCITY_ITEMFINDER_HINT" },
      { "LAVENDER_TOWN", "TEXT_LAVENDERTOWN_HOLD_HINT" },
      { "SAFFRON_CITY", "TEXT_SAFFRONCITY_BLACK_BELT_GIFT" },
      { "CELADON_MANSION_2F", "TEXT_CELADONMANSION2F_BATTLE_CLUB" },
      { "CELADON_MANSION_2F", "TEXT_CELADONMANSION2F_BEAST_TRACKER" },
      { "VERMILION_PIDGEY_HOUSE", "TEXT_VERMILIONPIDGEYHOUSE_DARK_SPECIALIST" },
      { "CELADON_HOTEL", "TEXT_CELADONHOTEL_BERRY_SPECIALIST" },
      { "CELADON_MANSION_3F", "TEXT_CELADONMANSION3F_BLENDER" },
      { "BERRY_FARM", "TEXT_BERRY_FARM_GIRL" },
      { "BERRY_FARM", "TEXT_BERRY_FARM_FISHER" },
      { "BERRY_FARM", "TEXT_BERRY_FARM_SCHOLAR" },
      { "BERRY_FARM", "TEXT_BERRY_FARM_SOIL_EXPERT" },
      { "BERRY_FARM", "TEXT_BERRY_FARM_MERCHANT" },
      { "UNDERGROUND_PATH_ROUTE_5", "TEXT_UNDERGROUNDPATHROUTE5_JUDGE" },
      { "SAFFRON_PIDGEY_HOUSE", "TEXT_SAFFRONPIDGEYHOUSE_MOVE_HUB" },
      { "CINNABAR_LAB_METRONOME_ROOM", "TEXT_CINNABARLABMETRONOMEROOM_SMITH" },
      { "ROUTE_2_TRADE_HOUSE", "TEXT_ROUTE2TRADEHOUSE_TAILLOW" },
      { "FUCHSIA_BILLS_GRANDPAS_HOUSE", "TEXT_FUCHSIABILLSGRANDPASHOUSE_SEEDOT" },
      { "DAYCARE", "TEXT_DAYCARE_GENTLEMAN" },
      { "DAYCARE", "TEXT_DAYCARE_LADY" },
      { "ROUTE_16_FLY_HOUSE", "TEXT_ROUTE16FLYHOUSE_WING_HUNTER" },
      { "ROUTE_12_GATE_2F", "TEXT_ROUTE12GATE2F_WING_HUNTER" },
      { "CINNABAR_LAB", "TEXT_CINNABARLAB_ORB_HUNTER" },
      { "CELADON_MANSION_ROOF", "TEXT_CELADONMANSIONROOF_HO_OH" },
      { "SEAFOAM_ISLANDS_B1F", "TEXT_SEAFOAMISLANDSB1F_LUGIA" },
      { "SEAFOAM_ISLANDS_B3F", "TEXT_SEAFOAMISLANDSB3F_KYOGRE" },
      { "POKEMON_MANSION_B1F", "TEXT_POKEMONMANSIONB1F_GROUDON" },
      { "PEWTER_SPEECH_HOUSE", "TEXT_PEWTERSPEECHHOUSE_REGI_SCHOLAR" },
      { "SEAFOAM_ISLANDS_B2F", "TEXT_SEAFOAMISLANDSB2F_REGICE" },
      { "POWER_PLANT", "TEXT_POWERPLANT_REGISTEEL" },
      { "REGIROCK_CHAMBER", "TEXT_REGIROCKCHAMBER_REGIROCK" },
      { "ROUTE_23", "TEXT_ROUTE23_SKY_GATE" },
      { "VIRIDIAN_FOREST", "TEXT_VIRIDIANFOREST_SHRINE_GATE" },
      { "VERMILION_DOCK", "TEXT_VERMILIONDOCK_SAILOR" },
      { "MT_MOON_B1F", "TEXT_MTMOONB1F_JIRACHI" },
      { "SKY_PILLAR_KANT", "TEXT_SKYPILLARKANT_RAYQUAZA" },
      { "ILEX_SHRINE_KANT", "TEXT_ILEXSHRINEKANT_CELEBI" },
      { "BIRTH_ISLAND_KANT", "TEXT_BIRTHISLANDKANT_DEOXYS" },
      { "CINNABAR_LAB_FOSSIL_ROOM", "TEXT_CINNABARLABFOSSILROOM_GEN3" },
      { "INDIGO_PLATEAU_LOBBY", "TEXT_INDIGOPLATEAULOBBY_EON_WATCHER" },
    }
    local missing = {}
    for _, row in ipairs(expectTalk) do
      if not talkOk(row[1], row[2]) then
        missing[#missing + 1] = row[1] .. "/" .. row[2]
      end
    end
    T.eq(#missing, 0, "KR NPC TEXT_ ids have talk handlers"
      .. (#missing > 0 and (": " .. table.concat(missing, ", ")) or ""))

    local byText = {}
    for _, row in ipairs(expectTalk) do byText[row[2]] = true end
    for _, def in pairs(Data.maps) do
      for _, o in ipairs(def.objects or {}) do
        local text = o.text
        if type(text) == "string" and text:find("^TEXT_") and byText[text] then
          T.check(o.x ~= nil and o.y ~= nil, text .. " has coords")
        end
      end
    end

    -- Item balls must carry an item payload (talkTo pickup arm).
    for _, name in ipairs({
      "ROCKTUNNELB1F_FOCUS_BAND",
      "POKEMONTOWER7F_BLACKGLASSES",
      "POWERPLANT_METAL_COAT",
    }) do
      local found
      for _, def in pairs(Data.maps) do
        for _, o in ipairs(def.objects or {}) do
          if o.name == name then found = o end
        end
      end
      T.check(found and found.item and found.item ~= "0",
        name .. " is an item ball")
    end

    local stubGame = {
      data = Data,
      save = {
        party = {},
        inventory = {},
        money = 0,
        flags = {},
        daycare = {},
        player = { name = "RED" },
      },
      stack = { push = function() end, pop = function() end, top = function() end },
    }
    local stubOw = { runner = nil, map = { id = "ROUTE_2_TRADE_HOUSE" } }
    local crashed = {}
    for _, row in ipairs(expectTalk) do
      local fn = MapScripts.get(row[1]).talk[row[2]]
      local ok, err = pcall(fn, stubGame, stubOw, { def = { text = row[2] } }, function() end)
      if not ok then
        crashed[#crashed + 1] = row[2] .. ": " .. tostring(err)
      end
    end
    T.eq(#crashed, 0, "KR talk handlers do not crash without a script runner"
      .. (#crashed > 0 and (": " .. crashed[1]) or ""))
  end

  -- Competitive items + trainers
  T.check(Data.items.CHOICE_BAND ~= nil, "Choice Band registered")
  T.check(Data.items.LIFE_ORB ~= nil, "Life Orb registered")
  T.check(Data.items.FOCUS_SASH ~= nil, "Focus Sash registered")
  T.check(Data.items.ROAMING_RADAR ~= nil, "Roaming Radar registered")
  T.check(Data.trainers.OPP_EXP_BATTLE_CLUB ~= nil, "Battle Club trainer class")
  T.check(Competitive.ITEMS.CHOICE_BAND ~= nil, "Competitive catalog has Choice Band")

  -- HouseNpcs.ask must wire TextBox.choice (not the broken ChoiceBox arity).
  do
    local pushed = {}
    local game = {
      data = Data,
      save = { party = {}, inventory = {}, money = 0 },
      stack = {
        push = function(_, screen) pushed[#pushed + 1] = screen end,
        pop = function() end,
        top = function() return pushed[#pushed] end,
      },
      input = { wasPressed = function() return false end },
    }
    local answered
    HouseNpcs.ask(game, "Battle?", function(yes) answered = yes end)
    T.eq(#pushed, 1, "ask pushes one TextBox")
    local box = pushed[1]
    T.check(type(box.choice) == "function", "ask uses TextBox choice callback")
    box.choice(true)
    T.eq(answered, true, "YES reaches ask callback")
  end

  -- Circuit host party builds without error + scale rules.
  do
    local BattleState = require("src.battle.BattleState")
    local Pokemon = require("src.pokemon.Pokemon")
    local game = {
      data = Data,
      save = {
        party = { Pokemon.new(Data, "PIKACHU", 30) },
        player = { name = "RED" },
        inventory = {},
        options = { battleStyle = "set" },
        pokedex = { seen = {}, owned = {} },
        flags = {},
        money = 0,
      },
      stack = { push = function() end, pop = function() end, top = function() end },
    }
    HouseNpcs._scaleGame = game
    local ok, battle = pcall(BattleState.newTrainer, game, "OPP_EXP_BATTLE_CLUB", 1)
    HouseNpcs._scaleGame = nil
    T.check(ok and battle ~= nil, "Circuit Host battle constructs")
    if ok and battle then
      T.check(#battle.enemyParty >= 1, "Circuit Host has a party")
    end

    local soft = HouseNpcs.softCap(nil, {
      data = Data,
      save = { flags = {}, inventory = {}, party = {} },
    })
    T.check(type(soft) == "number" and soft >= 14, "softCap is a milestone number")

    local scaleGame = {
      data = Data,
      save = {
        party = {
          Pokemon.new(Data, "RATTATA", 5),
          Pokemon.new(Data, "PIDGEOT", 40),
        },
        flags = {},
        inventory = {},
      },
    }
    T.eq(HouseNpcs.highestPartyLevel(scaleGame), 40,
      "highestPartyLevel uses strongest mon, not lead")
    T.eq(HouseNpcs.scaleCap(nil, scaleGame), math.max(soft, 40),
      "scaleCap is max(softCap, highest party) when caps off")

    scaleGame.save.party = {
      Pokemon.new(Data, "RATTATA", 35),
      Pokemon.new(Data, "PIDGEY", 10),
    }
    T.eq(HouseNpcs.highestPartyLevel(scaleGame), 35, "highest can be the lead")

    scaleGame.save.party = {
      { species = "BULBASAUR", isEgg = true, level = 99, eggCycles = 5 },
      Pokemon.new(Data, "PIDGEY", 12),
    }
    T.eq(HouseNpcs.highestPartyLevel(scaleGame), 12, "eggs do not set scale")

    scaleGame.save.party = { Pokemon.new(Data, "PIDGEY", 3) }
    T.eq(HouseNpcs.scaleCap(nil, scaleGame), soft,
      "underleveled party keeps softCap floor when caps off")

    -- Caps on: stay on the story bracket even if party somehow reads higher.
    local LevelCaps = require("mods.Kanto-Reforged.ui.level_caps")
    local fakeMod = {
      save = {
        get = function(_, key, default)
          if key == LevelCaps.SAVE_KEY then return true end
          return default
        end,
      },
    }
    scaleGame.save.party = { Pokemon.new(Data, "PIDGEOT", 99) }
    T.eq(HouseNpcs.scaleCap(fakeMod, scaleGame), soft,
      "caps on: Circuit stays at softCap (competitive bracket)")
    T.eq(HouseNpcs.scaleCap(nil, scaleGame), math.max(soft, 99),
      "caps off: overlevel still raises Circuit")

    HouseNpcs._scaleGame = scaleGame
    scaleGame.save.party = { Pokemon.new(Data, "PIKACHU", 55) }
    local stashed = HouseNpcs.scaleCap(nil, nil)
    HouseNpcs._scaleGame = nil
    T.eq(stashed, math.max(soft, 55), "scaleCap reads _scaleGame stash")

    local battleGame = {
      data = Data,
      save = {
        party = {
          Pokemon.new(Data, "RATTATA", 8),
          Pokemon.new(Data, "FEAROW", 42),
        },
        player = { name = "RED" },
        inventory = {},
        options = { battleStyle = "set" },
        pokedex = { seen = {}, owned = {} },
        flags = {},
        money = 0,
      },
      stack = { push = function() end, pop = function() end, top = function() end },
    }
    HouseNpcs._scaleGame = battleGame
    local scaledBattle = BattleState.newTrainer(battleGame, "OPP_EXP_BATTLE_CLUB", 1)
    HouseNpcs._scaleGame = nil
    local aceMon = scaledBattle.enemyParty[#scaledBattle.enemyParty]
    local expect = math.max(HouseNpcs.softCap(nil, battleGame), 42)
    T.eq(aceMon.level, expect,
      "Circuit ace level follows max(softCap, party high)")
  end

  -- Extra trades appended (vanilla 10 + 2)
  T.eq(#Data.field.trades, 12, "two extra in-game trades")
  T.eq(Data.field.trades[11].get, "TAILLOW", "trade 11 is Taillow")
  T.eq(Data.field.trades[12].get, "SEEDOT", "trade 12 is Seedot")

  -- Custom legendary maps ≥1100 + return warps
  T.check(Data.maps.SKY_PILLAR_KANT ~= nil, "SKY_PILLAR_KANT registered")
  T.eq(Data.maps.SKY_PILLAR_KANT.index, 1101, "Sky Pillar index 1101")
  T.eq(Data.maps.ILEX_SHRINE_KANT.index, 1102, "Ilex index 1102")
  T.eq(Data.maps.BIRTH_ISLAND_KANT.index, 1103, "Birth Island index 1103")
  T.check(talkOk("SKY_PILLAR_KANT", "TEXT_SKYPILLARKANT_RAYQUAZA"), "Rayquaza talk")

  run.loader.modSave["Kanto-Reforged"] = run.loader.modSave["Kanto-Reforged"] or {}
  run.loader.modSave["Kanto-Reforged"].legend_return_SKY_PILLAR_KANT = {
    map = "ROUTE_23", x = 10, y = 20,
  }
  local exitWarp = LegendMythicals.EXIT_WARPS[1]
  local retMap, retX, retY = Warp.destination(Data, {
    x = exitWarp.x, y = exitWarp.y, destMap = exitWarp.destMap, destWarp = 1,
  }, nil)
  T.eq(retMap, "ROUTE_23", "Sky Pillar exit returns to Route 23")
  T.eq(retX, 10, "Sky Pillar exit x")
  T.eq(retY, 20, "Sky Pillar exit y")

  -- Roamers + DexNav ROAM row
  local mod = Roamers._mod or require("mods.Kanto-Reforged.ui.level_caps")._mod
  T.check(mod ~= nil and mod.save ~= nil, "roamers installed with mod API")
  Roamers.activateBeasts(mod)
  local loc = Roamers.getLocation(mod, "RAIKOU")
  T.check(loc ~= nil, "Raikou has a location after activate")
  local items = DexNav.buildItems(Data, loc, { seen = {}, owned = {} }, { "RAIKOU" })
  local hasRoam = false
  for _, row in ipairs(items) do
    if row.right == "ROAM" and row.value == "RAIKOU" then hasRoam = true end
  end
  T.check(hasRoam, "DexNav lists ROAM row when roamer is here")

  -- Berry blender recipes are 10∶1 vitamins (no berry-printing except Lum craft)
  local vitamin = false
  for _, rec in ipairs(BerryQuests.RECIPES) do
    if rec.give == "HP_UP" then
      vitamin = true
      T.eq(rec.need.CHERI_BERRY, 10, "HP UP costs 10 Cheri")
      local prompt = BerryQuests.formatRecipePrompt(Data, rec)
      T.check(type(prompt) == "string" and #prompt > 0, "blender prompt is text")
      T.check(prompt:find("CHERI", 1, true) or prompt:find("10", 1, true),
        "blender prompt lists Cheri cost")
      T.check(prompt:find("Make one", 1, true) or prompt:find("HP UP", 1, true),
        "blender prompt asks to confirm")
    end
    if rec.give ~= "LUM_BERRY" then
      for id in pairs(rec.need) do
        T.check(id:find("BERRY", 1, true) ~= nil,
          "non-Lum recipes consume berries only")
      end
    end
  end
  T.check(vitamin, "HP UP recipe present")
  do
    local lines = BerryQuests.formatNeedLines(Data, {
      CHERI_BERRY = 10, PECHA_BERRY = 1,
    })
    T.eq(#lines, 2, "need lines covers both berries")
    T.check(lines[1]:find("1x", 1, true) ~= nil
        or lines[2]:find("1x", 1, true) ~= nil, "counts appear in need lines")
  end

  -- Mansion 2F club NPCs stay out of the east stair hall (x=6/7).
  do
    local club = findObj("CELADON_MANSION_2F", "CELADONMANSION2F_BATTLE_CLUB")
    local tracker = findObj("CELADON_MANSION_2F", "CELADONMANSION2F_BEAST_TRACKER")
    T.check(club and club.x ~= 6 and club.x ~= 7,
      "Battle Club not in east hall")
    T.check(tracker and tracker.x ~= 6 and tracker.x ~= 7,
      "Beast Tracker not in east hall")
    T.eq(club.x, 2, "Battle Club in meeting room")
    T.eq(club.y, 5, "Battle Club north of plants")
    T.eq(tracker.x, 1, "Beast Tracker SW of meeting room")
    T.eq(tracker.y, 8, "Beast Tracker on south row")
  end

  -- Fossils + Regis keys exist
  T.check(Data.items.ROOT_FOSSIL ~= nil or Data.items.CLAW_FOSSIL ~= nil
      or Data.maps.CINNABAR_LAB_FOSSIL_ROOM ~= nil,
    "Gen3 fossil content wired")
  T.check(Data.maps.REGIROCK_CHAMBER ~= nil, "REGIROCK_CHAMBER registered")
  T.eq(Data.maps.REGIROCK_CHAMBER.index, 1104, "Regirock chamber index 1104")
  T.check(findObj("REGIROCK_CHAMBER", "REGIROCKCHAMBER_REGIROCK") ~= nil,
    "Regirock in chamber")
  T.check(findObj("ROCK_TUNNEL_B1F", "ROCKTUNNELB1F_REGIROCK") == nil,
    "Regirock no longer on B1F main path")
  do
    local LegendRegis = require("mods.Kanto-Reforged.world.legend_regis")
    local Map = require("src.world.Map")
    local def = Data.maps.ROCK_TUNNEL_B1F
    local ts = Data.tilesets.CAVERN
    local lx, ly = LegendRegis.LADDER_X, LegendRegis.LADDER_Y
    T.check(Map.defIsWalkableCell(def, ts, lx, ly),
      "Rock Tunnel Regirock ladder cell walkable")
    T.check(Map.defIsWalkableCell(def, ts, lx, ly - 1),
      "approach spur north of ladder stays walkable")
    local warps = def.warps or {}
    T.eq(#warps, 5, "B1F gained Regirock chamber warp")
    local w = warps[5]
    T.eq(w.x, lx, "ladder warp x")
    T.eq(w.y, ly, "ladder warp y")
    T.eq(w.destMap, "REGIROCK_CHAMBER", "ladder leads to chamber")
    T.check(talkOk("REGIROCK_CHAMBER", "TEXT_REGIROCKCHAMBER_REGIROCK"),
      "Regirock chamber talk")
  end
  T.check(findObj("POWER_PLANT", "POWERPLANT_REGISTEEL") ~= nil, "Registeel present")
  T.check(Data.items.RAINBOW_WING ~= nil, "Rainbow Wing key")
  T.check(Data.items.SILVER_WING ~= nil, "Silver Wing key")
end
