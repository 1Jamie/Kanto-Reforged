-- Object-index hygiene + overworld NPC / legendary content smoke tests.
return function(T, Data, run)
  local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
  local MapScripts = require("src.script.MapScripts")
  local Competitive = require("mods.Kanto-Reforged.competitive_items")
  local BerryQuests = require("mods.Kanto-Reforged.berry_quests")
  local Roamers = require("mods.Kanto-Reforged.roamers")
  local DexNav = require("mods.Kanto-Reforged.dexnav")
  local LegendMythicals = require("mods.Kanto-Reforged.legend_mythicals")
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
    local LegendShrines = require("mods.Kanto-Reforged.legend_shrines")
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

  -- Circuit host party builds without error.
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
    local ok, battle = pcall(BattleState.newTrainer, game, "OPP_EXP_BATTLE_CLUB", 1)
    T.check(ok and battle ~= nil, "Circuit Host battle constructs")
    if ok and battle then
      T.check(#battle.enemyParty >= 1, "Circuit Host has a party")
    end
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
  local mod = Roamers._mod or require("mods.Kanto-Reforged.level_caps")._mod
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
    local LegendRegis = require("mods.Kanto-Reforged.legend_regis")
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
