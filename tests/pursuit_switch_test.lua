-- Pursuit hits the outgoing mon for 2x on switch, then skips the free hit.
return function(T, Data, run)
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  require("src.battle.TypeChart").load(Data)

  T.check(BattleState._krGen3SwitchLock,
    "Pursuit/switch-lock wrap installed")
  T.check(Data.moves.PURSUIT ~= nil, "PURSUIT move registered")
  T.eq(Data.moves.FLIP_TURN.effect, "EXP_U_TURN_EFFECT",
    "Flip Turn shares U-turn switch-out effect")
  T.eq(Data.moves.HELPING_HAND.effect, "EXP_HELPING_HAND_EFFECT",
    "Helping Hand uses fail-in-singles effect")
  T.check(Data.move_effects.EXP_HELPING_HAND_EFFECT ~= nil,
    "Helping Hand effect registered")

  local DisabledMoves = require("mods.Kanto-Reforged.pokemon.disabled_moves")
  T.check(DisabledMoves.isDisabled("HELPING_HAND"),
    "Helping Hand is disabled for learnsets")

  -- Learnsets should not teach Helping Hand after scrub.
  local eevee = Data.pokemon and Data.pokemon.EEVEE
  if eevee and eevee.learnset then
    for _, entry in ipairs(eevee.learnset) do
      T.check(entry.move ~= "HELPING_HAND",
        "Eevee learnset has no Helping Hand")
    end
  end

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
    local battle = BattleState.newTrainer(game, "OPP_YOUNGSTER", 1)
    return battle, game
  end

  local function pump(battle)
    local sawPursuit = false
    for _ = 1, 160 do
      if #battle.queue == 0 then break end
      local item = table.remove(battle.queue, 1)
      if item.text and item.text:find("PURSUIT", 1, true) then
        sawPursuit = true
      end
      if item.fn then
        battle.nextInsert = 0
        item.fn()
      end
    end
    return sawPursuit
  end

  do
    local battle, game = makeBattle()
    local outgoing = battle.player.mon
    local incoming = game.save.party[2]
    local outHpBefore = outgoing.hp
    local inHpBefore = incoming.hp

    -- Force Pursuit as the only enemy action.
    local pursuit = { id = "PURSUIT", pp = 20, power = 40, type = "DARK" }
    -- Prefer a real curMoves slot when present so PP/name resolve.
    for _, m in ipairs(battle.enemy.curMoves or {}) do
      if m.id == "PURSUIT" then pursuit = m break end
    end
    if not battle.data.moves.PURSUIT then
      battle.data.moves.PURSUIT = Data.moves.PURSUIT
    end
    battle.enemy.curMoves = { pursuit }
    battle.enemyAction = function()
      return pursuit
    end

    battle:resolveSwitch(incoming)
    local sawPursuit = pump(battle)

    T.check(sawPursuit, "Pursuit was announced on switch")
    T.check(outgoing.hp < outHpBefore,
      "Pursuit damaged the outgoing mon")
    T.eq(incoming.hp, inHpBefore,
      "incoming mon took no free-hit damage after Pursuit")
    T.eq(battle.player.mon, incoming,
      "switch completed after non-KO Pursuit")
  end

  -- Helping Hand fails in singles.
  do
    local Setup = require("mods.Kanto-Reforged.battle.core.effects.setup")
    local failed = false
    Setup.helpingHand({
      adapter = {
        sayFail = function() failed = true end,
      },
    })
    T.check(failed, "Helping Hand calls sayFail in singles")
  end
end
