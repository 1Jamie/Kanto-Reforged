return function(T, Data)
  local CoreInstall = require("mods.Kanto-Reforged.battle.core.install")

  local function runEffect(id, battle, user, target, move, rng)
    return CoreInstall.tryRunEffect(battle, id, user, target, move, rng or math.random)
  end

  local function g1Battle(foeSide)
    return {
      player = { name = "Player", isPlayer = true, mon = { hp = 50, stats = { hp = 50 } } },
      enemy = { name = "Foe", mon = { hp = 50, stats = { hp = 50 } } },
      sides = { player = {}, enemy = foeSide or { hazards = {} } },
      data = Data,
      sayNext = function() end,
    }
  end

  local function g2Battle(foeSide)
    return {
      weatherTurns = 0,
      player = { hp = 50, species = "PIDGEY", name = "Player" },
      enemy = { hp = 50, species = "RATTATA", name = "Foe" },
      sides = { player = {}, enemy = foeSide or { hazards = {} } },
      sideOf = function(_, mon)
        if mon.species == "PIDGEY" then return "player" end
        return "enemy"
      end,
      data = Data,
      emit = function() end,
    }
  end

  -- Hazards
  do
    local g1Side = { hazards = {} }
    local g1 = g1Battle(g1Side)
    runEffect("EXP_SPIKES_EFFECT", g1, g1.player, g1.enemy, Data.moves.SPIKES)
    T.eq(g1Side.hazards[1] and g1Side.hazards[1].id, "SPIKES", "gen1 spikes parity")

    local g2Side = { hazards = {} }
    local g2 = g2Battle(g2Side)
    runEffect("EXP_SPIKES_EFFECT", g2, g2.player, g2.enemy, Data.moves.SPIKES)
    T.eq(g2Side.hazards[1] and g2Side.hazards[1].id, "SPIKES", "gen2 spikes parity")
    T.check(g2Side.spikes, "gen2 spikes flag")
  end

  -- Taunt
  do
    local g1 = g1Battle()
    runEffect("EXP_TAUNT_EFFECT", g1, g1.player, g1.enemy, Data.moves.TAUNT)
    T.eq(g1.enemy.expTauntedTurns, 3, "gen1 taunt parity")

    local g2 = g2Battle()
    runEffect("EXP_TAUNT_EFFECT", g2, g2.player, g2.enemy, Data.moves.TAUNT)
    T.eq(g2.enemy.expTauntedTurns, 3, "gen2 taunt parity")
  end

  -- Protect
  do
    local g1 = g1Battle()
    g1.player.expProtectStreak = 0
    runEffect("EXP_PROTECT_EFFECT", g1, g1.player, g1.enemy, Data.moves.PROTECT,
      function() return 0 end)
    T.check(g1.player.expProtected, "gen1 protect parity")

    local g2 = g2Battle()
    g2.player.expProtectStreak = 0
    runEffect("EXP_PROTECT_EFFECT", g2, g2.player, g2.enemy, Data.moves.PROTECT,
      function() return 0 end)
    T.check(g2.player.expProtected, "gen2 protect parity")
  end

  -- Endure
  do
    local g1 = g1Battle()
    runEffect("EXP_ENDURE_EFFECT", g1, g1.player, g1.enemy, Data.moves.ENDURE)
    T.check(g1.player.expEnduring, "gen1 endure parity")

    local g2 = g2Battle()
    runEffect("EXP_ENDURE_EFFECT", g2, g2.player, g2.enemy, Data.moves.ENDURE)
    T.check(g2.player.expEnduring, "gen2 endure parity")
  end

  -- Perish Song
  do
    local g1 = g1Battle()
    runEffect("EXP_PERISH_SONG_EFFECT", g1, g1.player, g1.enemy, Data.moves.PERISH_SONG)
    T.eq(g1.player.expPerishTurns, 4, "gen1 perish user")
    T.eq(g1.enemy.expPerishTurns, 4, "gen1 perish foe")
  end

  -- Psych Up
  do
    local g1 = g1Battle()
    g1.player.stages = { attack = 0 }
    g1.enemy.stages = { attack = 2, defense = -1 }
    runEffect("EXP_PSYCH_UP_EFFECT", g1, g1.player, g1.enemy, Data.moves.PSYCH_UP)
    T.eq(g1.player.stages.attack, 2, "gen1 psych up copies attack")
    T.eq(g1.player.stages.defense, -1, "gen1 psych up copies defense")
  end

  -- Torment
  do
    local g2 = g2Battle()
    runEffect("EXP_TORMENT_EFFECT", g2, g2.player, g2.enemy, Data.moves.TORMENT)
    T.check(g2.enemy.expTormented, "gen2 torment parity")
  end

  local function runHook(id, hookName, battle, user, target, move, raw)
    return CoreInstall.tryRunHook(battle, id, hookName, user, target, move, raw)
  end

  -- Fake Out gate (first turn only)
  do
    local g1 = g1Battle()
    g1.player.expJustEntered = true
    local ok = runHook("EXP_FAKE_OUT_EFFECT", "gate", g1, g1.player, g1.enemy, Data.moves.FAKE_OUT)
    T.check(ok, "gen1 fake out gate first turn")
    g1.player.expJustEntered = nil
    ok = runHook("EXP_FAKE_OUT_EFFECT", "gate", g1, g1.player, g1.enemy, Data.moves.FAKE_OUT)
    T.eq(ok, false, "gen1 fake out gate fails after first turn")

    local g2 = g2Battle()
    g2.player.expJustEntered = true
    ok = runHook("EXP_FAKE_OUT_EFFECT", "gate", g2, g2.player, g2.enemy, Data.moves.FAKE_OUT)
    T.check(ok, "gen2 fake out gate first turn")
  end

  -- Endeavor chooseDamage
  do
    local g1 = g1Battle()
    g1.player.mon.hp = 10
    g1.enemy.mon.hp = 40
    local dmg = runHook("EXP_ENDEAVOR_EFFECT", "chooseDamage", g1, g1.player, g1.enemy,
      Data.moves.ENDEAVOR)
    T.eq(dmg, 30, "gen1 endeavor damage gap")

    local g2 = g2Battle()
    g2.player.hp = 10
    g2.enemy.hp = 40
    dmg = runHook("EXP_ENDEAVOR_EFFECT", "chooseDamage", g2, g2.player, g2.enemy,
      Data.moves.ENDEAVOR)
    T.eq(dmg, 30, "gen2 endeavor damage gap")
  end

  -- Sleep Talk / Nature Power call-move hooks
  do
    local g1 = g1Battle()
    g1.player.mon.status = "SLP"
    g1.player.mon.moves = {
      { id = "TACKLE", pp = 10 },
      { id = "SLEEP_TALK", pp = 5 },
    }
    g1.player.curMoves = g1.player.mon.moves
    local pick = runHook("EXP_SLEEP_TALK_EFFECT", "callsMove", g1, g1.player, g1.enemy,
      Data.moves.SLEEP_TALK, nil)
    T.eq(pick, "TACKLE", "gen1 sleep talk picks usable move")

    local g2 = g2Battle()
    g2.player.status = "sleep"
    g2.player.moves = {
      { id = "TACKLE", pp = 10 },
      { id = "SLEEP_TALK", pp = 5 },
    }
    pick = runHook("EXP_SLEEP_TALK_EFFECT", "callsMove", g2, g2.player, g2.enemy,
      Data.moves.SLEEP_TALK, nil)
    T.eq(pick, "TACKLE", "gen2 sleep talk picks usable move")

    T.eq(runHook("EXP_NATURE_POWER_EFFECT", "callsMove", g1, g1.player, g1.enemy,
      Data.moves.NATURE_POWER), "EARTHQUAKE", "gen1 nature power")
    T.eq(runHook("EXP_NATURE_POWER_EFFECT", "callsMove", g2, g2.player, g2.enemy,
      Data.moves.NATURE_POWER), "EARTHQUAKE", "gen2 nature power")
  end
end
