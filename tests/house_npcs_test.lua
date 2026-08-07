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

  run.loader.modSave.expansion_pack = run.loader.modSave.expansion_pack or {}
  run.loader.modSave.expansion_pack.legend_return_SKY_PILLAR_KANT = {
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
    end
    if rec.give ~= "LUM_BERRY" then
      for id in pairs(rec.need) do
        T.check(id:find("BERRY", 1, true) ~= nil,
          "non-Lum recipes consume berries only")
      end
    end
  end
  T.check(vitamin, "HP UP recipe present")

  -- Fossils + Regis keys exist
  T.check(Data.items.ROOT_FOSSIL ~= nil or Data.items.CLAW_FOSSIL ~= nil
      or Data.maps.CINNABAR_LAB_FOSSIL_ROOM ~= nil,
    "Gen3 fossil content wired")
  T.check(findObj("ROCK_TUNNEL_B1F", "ROCKTUNNELB1F_REGIROCK") ~= nil, "Regirock present")
  T.check(findObj("POWER_PLANT", "POWERPLANT_REGISTEEL") ~= nil, "Registeel present")
  T.check(Data.items.RAINBOW_WING ~= nil, "Rainbow Wing key")
  T.check(Data.items.SILVER_WING ~= nil, "Silver Wing key")
end
