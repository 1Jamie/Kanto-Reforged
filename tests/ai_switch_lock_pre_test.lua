-- Switch free-hit timing option: Gen 3 locks vs outgoing mon; Gen 1 picks
-- after send-out. Default is Gen 3.
return function(T, Data, run)
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local TrainerAi = require("mods.Kanto-Reforged.battle.trainer_ai")
  require("src.battle.TypeChart").load(Data)

  T.check(BattleState._krGen3SwitchLock,
    "switch-hit timing wrap installed")

  local schema = run.loader.optionSchemas["Kanto-Reforged"]
  local lockOpt
  for _, opt in ipairs(schema or {}) do
    if opt.key == TrainerAi.SWITCH_LOCK_KEY then lockOpt = opt break end
  end
  T.check(lockOpt ~= nil, "SWITCH HIT AI option schema registered")
  T.eq(lockOpt.type, "choice", "switch hit AI is a choice")
  T.eq(lockOpt.default, TrainerAi.SWITCH_LOCK_GEN1, "switch hit AI defaults to classic timing")
  T.eq(lockOpt.choices[1][1], "CLASSIC", "switch-hit classic label is CLASSIC")
  T.eq(lockOpt.choices[2][1], "GEN 3", "switch-hit lock label is GEN 3")

  local opts = run.loader.modOptions["Kanto-Reforged"]
      or {}
  run.loader.modOptions["Kanto-Reforged"] = opts
  local saved = opts[TrainerAi.SWITCH_LOCK_KEY]

  local function makeBattle()
    local game = {
      data = Data,
      save = {
        party = {
          Pokemon.new(Data, "PIKACHU", 50),
          Pokemon.new(Data, "SQUIRTLE", 50),
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
    return BattleState.newTrainer(game, "OPP_YOUNGSTER", 1), game
  end

  local function pump(battle)
    local sawUsed = false
    for _ = 1, 120 do
      if #battle.queue == 0 then break end
      local item = table.remove(battle.queue, 1)
      if item.text and item.text:find("used", 1, true) then
        sawUsed = true
      end
      if item.fn then
        battle.nextInsert = 0
        item.fn()
      end
    end
    return sawUsed
  end

  local function runSwitch(mode)
    opts[TrainerAi.SWITCH_LOCK_KEY] = mode
    local battle, game = makeBattle()
    local incoming = game.save.party[2]
    local lockedMove = battle.enemy.curMoves[1]
    T.check(lockedMove and lockedMove.id, "enemy has a move (" .. mode .. ")")

    local chooseSpecies, chooseCount = nil, 0
    battle.enemyAction = function()
      chooseCount = chooseCount + 1
      chooseSpecies = battle.player.mon and battle.player.mon.species
      return lockedMove
    end

    local hpBefore = incoming.hp
    battle:resolveSwitch(incoming)
    local sawUsed = pump(battle)
    return {
      chooseCount = chooseCount,
      chooseSpecies = chooseSpecies,
      sawUsed = sawUsed,
      incoming = incoming,
      hpBefore = hpBefore,
      playerMon = battle.player.mon,
      lockedMove = lockedMove,
    }
  end

  -- Gen 3 (default): choose against Pikachu, hit Squirtle.
  do
    local r = runSwitch(TrainerAi.SWITCH_LOCK_GEN3)
    T.eq(r.chooseCount, 1, "Gen 3: AI chose exactly once")
    T.eq(r.chooseSpecies, "PIKACHU",
      "Gen 3: locked against the outgoing mon")
    T.eq(r.playerMon, r.incoming, "Gen 3: switch-in is active")
    T.check(r.sawUsed, "Gen 3: free-hit text appeared")
    if r.lockedMove.power and r.lockedMove.power > 0 then
      T.check(r.incoming.hp < r.hpBefore, "Gen 3: switch-in took the hit")
    end
  end

  -- Gen 1: choose after send-out (against Squirtle).
  do
    local r = runSwitch(TrainerAi.SWITCH_LOCK_GEN1)
    T.eq(r.chooseCount, 1, "Gen 1: AI chose exactly once")
    T.eq(r.chooseSpecies, "SQUIRTLE",
      "Gen 1: picked after the swap, against the switch-in")
    T.eq(r.playerMon, r.incoming, "Gen 1: switch-in is active")
    T.check(r.sawUsed, "Gen 1: free-hit text appeared")
  end

  opts[TrainerAi.SWITCH_LOCK_KEY] = saved
end
