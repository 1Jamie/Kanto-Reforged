-- Test defensive handling and graceful degradation for EXP calculation
return function(T, Data, run)
  local Experience = require("src.battle.Experience")
  local Pokemon = require("src.pokemon.Pokemon")
  local Growth = require("src.pokemon.Growth")

  local enemyDef = Data.pokemon.RATTATA

  -- Test 1: mon with exp = nil falls back to level-based growth exp
  do
    local mon = Pokemon.new(Data, "BULBASAUR", 5)
    mon.exp = nil
    local expectedBase = Growth.expForLevel(Data.pokemon.BULBASAUR.growthRate, 5, Data.growth_rates)
    local levels, gained, steps = Experience.apply(Data, mon, enemyDef, 5, false, 1, false)
    T.check(mon.exp ~= nil, "mon.exp initialized after apply")
    T.check(gained > 0, "gained EXP calculated")
    T.eq(mon.exp, expectedBase + gained, "mon.exp correctly computed from fallback base + gained")
  end

  -- Test 2: mon with only Gen 2 mon.experience field
  do
    local mon = Pokemon.new(Data, "CHARMANDER", 10)
    mon.exp = nil
    mon.experience = 1000
    local levels, gained, steps = Experience.apply(Data, mon, enemyDef, 5, false, 1, false)
    T.eq(mon.exp, 1000 + gained, "mon.exp adopted mon.experience value")
    T.eq(mon.experience, 1000 + gained, "mon.experience synced with mon.exp")
  end

  -- Test 3: mon with completely empty statExp, dvs, stats, hp
  do
    local bareMon = { species = "PIDGEY", level = 3 }
    local levels, gained, steps = Experience.apply(Data, bareMon, enemyDef, 3, false, 1, false)
    T.check(bareMon.exp ~= nil, "bare mon gained exp")
    T.check(bareMon.statExp ~= nil, "bare mon statExp initialized")
    T.check(bareMon.dvs ~= nil, "bare mon dvs initialized")
    T.check(bareMon.stats ~= nil, "bare mon stats initialized")
    T.check(bareMon.hp ~= nil, "bare mon hp initialized")
  end

  -- Test 4: nil safety on bad inputs
  do
    local levels, gained, steps = Experience.apply(nil, nil, nil, 1, false, 1, false)
    T.eq(#levels, 0, "empty levels for nil inputs")
    T.eq(gained, 0, "zero gained for nil inputs")
    T.eq(#steps, 0, "empty steps for nil inputs")
  end

  -- Test 5: Experience.commit nil safety
  do
    Experience.commit(Data, nil, nil)
    local mon = { species = "PIKACHU", level = 5, exp = 150, experience = 150 }
    Experience.commit(Data, mon, { level = 6, stats = { hp = 20, attack = 15, defense = 15, speed = 20, special = 15 }, hp = 20 })
    T.eq(mon.level, 6, "committed level")
    T.eq(mon.hp, 20, "committed hp")
  end
end
