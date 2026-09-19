return function(T)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local Adapters = require("mods.Kanto-Reforged.battle.adapters")

  local g1Battler = { mon = { hp = 50, species = "PIDGEY" }, name = "Bird" }
  T.eq(BattleCompat.mon(g1Battler).species, "PIDGEY", "gen1 mon unwrap")
  T.eq(BattleCompat.hp(g1Battler), 50, "gen1 hp")

  local g2Mon = { hp = 40, species = "RATTATA", maxHp = 40 }
  T.eq(BattleCompat.mon(g2Mon).species, "RATTATA", "gen2 bare mon")
  T.eq(BattleCompat.toGen2Status("BRN"), "burn", "status translation")
  T.eq(BattleCompat.toGen1Status("burn"), "BRN", "status reverse")

  local battle = {
    player = g1Battler,
    enemy = { mon = { hp = 30, species = "CATERPIE" } },
    sides = { player = {}, enemy = { hazards = {} } },
    data = {},
  }
  local adapter = Adapters.forBattle(battle)
  T.check(adapter ~= nil, "adapter created")
  T.eq(adapter._host, "gen1", "gen1-shaped battle uses gen1 adapter")
  T.eq(adapter:hp(g1Battler), 50, "adapter hp")
  T.check(not adapter:isFainted(g1Battler), "not fainted")

  local g2Battle = {
    weatherTurns = 0,
    player = g2Mon,
    enemy = { hp = 30, species = "CATERPIE" },
    sides = { player = {}, enemy = {} },
    data = {},
    emit = function() end,
  }
  local g2Adapter = Adapters.forBattle(g2Battle)
  T.eq(g2Adapter._host, "gen2", "gen2-shaped battle uses gen2 adapter")

  -- Test mon & save scrubbing to ensure SaveSerializer.encode never crashes on userdata/ephemerals
  local SaveSerializer = require("src.core.SaveSerializer")
  local dummyUserdata = newproxy(true)
  local dummyFn = function() end

  local shinyMon = {
    species = "CHIKORITA",
    nickname = "Leafy",
    level = 16,
    experience = 4096,
    hp = 50,
    maxHp = 50,
    shiny = true,
    gender = "female",
    item = "MIRACLE_SEED",
    dvs = { attack = 10, defense = 10, speed = 10, special = 10 },
    statExp = { hp = 100, attack = 100, defense = 100, speed = 100, special = 100 },
    moves = { "TACKLE", "GROWL", "RAZOR_LEAF", "REFLECT" },
    -- Transient runtime and AI fields
    curStats = { hp = 50, attack = 25, defense = 28, speed = 24, special = 26 },
    curTypes = { "GRASS" },
    curMoves = { "TACKLE", "GROWL", "RAZOR_LEAF", "REFLECT" },
    stages = { attack = 1, defense = 0 },
    expProtected = true,
    expEnduring = true,
    expChoiceLock = "RAZOR_LEAF",
    expLastConsumedItem = "BERRY",
    expAteBerry = true,
    expProtectStreak = 1,
    expFlashFire = true,
    _krFrontAnim = { strip = dummyUserdata, quads = { dummyUserdata } },
    _krFrontAnimHeld = false,
    _krCastformForm = "sunny",
    _krBattle = { state = "active" },
    sprite = dummyUserdata,
    extraFunc = dummyFn,
  }
  -- Cycle test
  shinyMon.mon = shinyMon

  local save = {
    player = { name = "KRIS", id = 12345 },
    party = { shinyMon },
    boxes = {
      {
        {
          species = "PIDGEY",
          level = 5,
          experience = 125,
          hp = 20,
          dvs = { attack = 5, defense = 5, speed = 5, special = 5 },
          _krFrontAnim = { strip = dummyUserdata },
          fn = dummyFn,
        },
      },
    },
    daycare = {
      mon1 = {
        species = "DITTO",
        level = 20,
        experience = 8000,
        hp = 55,
        sprite = dummyUserdata,
      },
    },
    flags = { EVENT_TEST = true },
  }

  -- Before scrubbing, SaveSerializer.encode MUST fail due to userdata
  local okBefore, errBefore = pcall(SaveSerializer.encode, save)
  T.check(not okBefore, "SaveSerializer.encode fails before scrub on userdata")
  T.check(tostring(errBefore):find("cannot serialize userdata", 1, true) ~= nil,
    "errBefore is cannot serialize userdata")

  -- Scrub save
  BattleCompat.scrubSave(save)

  -- Verify legitimate fields are preserved
  T.eq(shinyMon.species, "CHIKORITA", "scrub keeps species")
  T.eq(shinyMon.nickname, "Leafy", "scrub keeps nickname")
  T.eq(shinyMon.level, 16, "scrub keeps level")
  T.eq(shinyMon.experience, 4096, "scrub keeps experience")
  T.eq(shinyMon.hp, 50, "scrub keeps hp")
  T.eq(shinyMon.shiny, true, "scrub keeps shiny flag")
  T.eq(shinyMon.gender, "female", "scrub keeps gender")
  T.eq(shinyMon.item, "MIRACLE_SEED", "scrub keeps item")
  T.eq(shinyMon.dvs.attack, 10, "scrub keeps DVs")
  T.eq(shinyMon.statExp.hp, 100, "scrub keeps statExp")
  T.eq(#shinyMon.moves, 4, "scrub keeps moves")

  -- Verify ephemeral / userdata / function fields are removed
  T.eq(shinyMon.mon, nil, "scrub removed mon.mon cycle")
  T.eq(shinyMon.curStats, nil, "scrub removed curStats")
  T.eq(shinyMon.curTypes, nil, "scrub removed curTypes")
  T.eq(shinyMon.curMoves, nil, "scrub removed curMoves")
  T.eq(shinyMon.stages, nil, "scrub removed stages")
  T.eq(shinyMon.expProtected, nil, "scrub removed expProtected")
  T.eq(shinyMon.expChoiceLock, nil, "scrub removed expChoiceLock")
  T.eq(shinyMon.expAteBerry, nil, "scrub removed expAteBerry")
  T.eq(shinyMon._krFrontAnim, nil, "scrub removed _krFrontAnim")
  T.eq(shinyMon._krCastformForm, nil, "scrub removed _krCastformForm")
  T.eq(shinyMon._krBattle, nil, "scrub removed _krBattle")
  T.eq(shinyMon.sprite, nil, "scrub removed sprite")
  T.eq(shinyMon.extraFunc, nil, "scrub removed function")
  T.eq(save.boxes[1][1]._krFrontAnim, nil, "scrub removed box mon _krFrontAnim")
  T.eq(save.daycare.mon1.sprite, nil, "scrub removed daycare mon sprite")

  -- After scrubbing, SaveSerializer.encode MUST succeed cleanly
  local okAfter, encoded = pcall(SaveSerializer.encode, save)
  T.check(okAfter, "SaveSerializer.encode succeeds after scrubSave")
  T.check(type(encoded) == "string" and #encoded > 50, "valid encoded save string produced")
end
