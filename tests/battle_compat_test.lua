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
end
