-- AI switch first must not leave the player's move hitting the withdrawn mon.
return function(T, Data, _run)
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  require("src.battle.TypeChart").load(Data)

  local game = {
    data = Data,
    save = {
      party = { Pokemon.new(Data, "PIKACHU", 50) },
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
  T.check(#battle.enemyParty >= 2, "youngster has a backup mon")

  local oldEnemyMon = battle.enemy.mon
  local oldHp = oldEnemyMon.hp
  local switchTo = (battle.enemyIndex == 1) and 2 or 1
  local newMon = battle.enemyParty[switchTo]
  local newHpBefore = newMon.hp
  T.check(newMon ~= oldEnemyMon, "backup mon is distinct")

  local playerMove = battle.player.curMoves[1]
  T.check(playerMove and playerMove.id, "player has a move")

  -- Enemy outspeeds so the AI switch resolves before the player's attack.
  battle.player.curStats.speed = 1
  battle.enemy.curStats.speed = 999

  local origEnemyAction = battle.enemyAction
  battle.enemyAction = function()
    return { special = "aiSwitch", index = switchTo }
  end

  battle:resolveTurn(playerMove)

  local sawSwitch, sawMove = false, false
  local function pump(limit)
    for _ = 1, (limit or 120) do
      if #battle.queue == 0 then break end
      local item = table.remove(battle.queue, 1)
      if item.text then
        if item.text:find("with%-", 1) or item.text:find("sent\nout", 1) then
          sawSwitch = true
        end
        if item.text:find("used", 1, true) then
          sawMove = true
          -- After the move announcement, the switch-in must already be active
          -- and should be the one taking damage — not the withdrawn lead.
          T.eq(battle.enemy.mon, newMon,
            "attack aims at the switch-in, not the withdrawn mon")
        end
      end
      if item.fn then
        battle.nextInsert = 0
        item.fn()
      end
    end
  end
  pump()
  battle.enemyAction = origEnemyAction

  T.check(sawSwitch, "AI switch text appeared")
  T.check(sawMove, "player move text appeared")
  T.eq(oldEnemyMon.hp, oldHp, "withdrawn mon HP unchanged")
  T.check(newMon.hp < newHpBefore,
    "switch-in took the damage (was the real target)")
end
