-- Slot-2 Exp. Share: 70% pool to fighters / ≤30% to bench slot 2 (clamped).
return function(T, Data, run)
  local ModernXpShare = require("mods.expansion_pack.modern_xp_share")
  local Experience = require("src.battle.Experience")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")

  local schema = run.loader.optionSchemas.expansion_pack
  local modernOpt
  for _, opt in ipairs(schema or {}) do
    if opt.key == ModernXpShare.OPTION_KEY then modernOpt = opt break end
  end
  T.check(modernOpt ~= nil, "XP SHARE (SLOT 2) option schema registered")
  T.eq(modernOpt.type, "toggle", "slot-2 XP share is a toggle")
  T.eq(modernOpt.default, true, "slot-2 XP share defaults on")
  T.eq(modernOpt.label, "XP SHARE (SLOT 2)", "slot-2 XP share label")

  -- Fraction math (scenarios A–C).
  do
    local f1, b1 = ModernXpShare.fractions(1, true)
    T.eq(f1, 0.70, "solo fighter gets 70% of pool")
    T.eq(b1, 0.30, "solo bench slot 2 gets 30% of pool")

    local f2, b2 = ModernXpShare.fractions(2, true)
    T.eq(f2, 0.35, "two fighters each get 35%")
    T.check(b2 < f2, "two-fighter bench share stays below each fighter")
    T.check(b2 >= 0.25 and b2 <= 0.30, "two-fighter bench share in 25–30%")

    local f3, b3 = ModernXpShare.fractions(3, true)
    T.check(math.abs(f3 - (0.70 / 3)) < 1e-9, "three fighters split 70%")
    T.check(b3 < f3, "three-fighter bench share stays below each fighter")
    T.check(b3 >= 0.15 and b3 <= 0.18, "three-fighter bench share in 15–18%")

    local fv, bv = ModernXpShare.fractions(2, false)
    T.eq(fv, 0.5, "no bench: equal split of full pool")
    T.eq(bv, 0, "no bench: zero bench fraction")
  end

  local saved = {}
  local function setOpt(key, value)
    saved[key] = run.loader.modOptions.expansion_pack
      and run.loader.modOptions.expansion_pack[key]
    run.loader.modOptions.expansion_pack = run.loader.modOptions.expansion_pack or {}
    run.loader.modOptions.expansion_pack[key] = value
  end
  local function restoreOpts()
    run.loader.modOptions.expansion_pack = run.loader.modOptions.expansion_pack or {}
    for k, v in pairs(saved) do
      run.loader.modOptions.expansion_pack[k] = v
    end
  end

  local function makeBattle(party)
    local game = {
      data = Data,
      save = {
        party = party,
        player = { name = "RED" },
        inventory = {},
        options = { battleStyle = "set" },
        pokedex = { seen = {}, owned = {} },
        flags = {},
        money = 0,
      },
      stack = { push = function() end, pop = function() end, top = function() end },
    }
    local b = BattleState.newWild(game, "RATTATA", 10)
    b.sayNext = function() end
    b.uiNext = function() end
    b.drainNext = function() end
    b.learnMove = function() end
    b.queue = {}
    b.nextInsert = 0
    return game, b
  end

  local enemyDef = Data.pokemon.RATTATA
  local function expectGain(frac)
    return Experience.gainFor(enemyDef, 10, false, 1 / frac, false, Data.constants)
  end
  local solo = Experience.gainFor(enemyDef, 10, false, 1, false, Data.constants)

  -- Scenario A: solo lead 70%, slot 2 30%; slot 3+ nothing; EXP.ALL ignored.
  do
    setOpt(ModernXpShare.OPTION_KEY, true)
    local lead = Pokemon.new(Data, "BULBASAUR", 20)
    local slot2 = Pokemon.new(Data, "SQUIRTLE", 20)
    local slot3 = Pokemon.new(Data, "PIDGEY", 20)
    local fainted = Pokemon.new(Data, "CHARMANDER", 20)
    fainted.hp = 0
    local game, b = makeBattle({ lead, slot2, slot3, fainted })
    game.save.inventory.EXP_ALL = 1
    b.participants = { [lead] = true }
    local before = { lead.exp, slot2.exp, slot3.exp, fainted.exp }
    b:awardExperience()
    local wantLead, wantSlot2 = expectGain(0.70), expectGain(0.30)
    T.eq(lead.exp - before[1], wantLead, "A: solo lead gets 70% pool")
    T.eq(slot2.exp - before[2], wantSlot2, "A: slot 2 gets 30% pool")
    T.eq(slot3.exp - before[3], 0, "A: slot 3+ gets nothing")
    T.eq(fainted.exp - before[4], 0, "A: fainted gets nothing")
    T.check(wantLead + wantSlot2 <= solo + 1,
      "A: total payout does not exceed solo pool (floor slack)")
    T.check(wantLead > wantSlot2 * 2, "A: lead gets more than double slot 2")
    restoreOpts()
  end

  -- Toggle OFF: vanilla sole participant full; bench zero.
  do
    setOpt(ModernXpShare.OPTION_KEY, false)
    local lead = Pokemon.new(Data, "BULBASAUR", 20)
    local bench = Pokemon.new(Data, "SQUIRTLE", 20)
    local game, b = makeBattle({ lead, bench })
    b.participants = { [lead] = true }
    local before = { lead.exp, bench.exp }
    b:awardExperience()
    T.eq(lead.exp - before[1], solo, "vanilla: sole participant gets full pool")
    T.eq(bench.exp - before[2], 0, "vanilla: bench gets nothing without EXP.ALL")
    restoreOpts()
  end

  -- Scenario B: two fighters split 70%; slot 2 benched gets clamped share.
  do
    setOpt(ModernXpShare.OPTION_KEY, true)
    local a = Pokemon.new(Data, "BULBASAUR", 20)
    local bMon = Pokemon.new(Data, "CHARMANDER", 20)
    local slot2 = Pokemon.new(Data, "SQUIRTLE", 20)
    -- Fight with slots 1 and 3; slot 2 stays benched.
    local game, battle = makeBattle({ a, slot2, bMon })
    battle.participants = { [a] = true, [bMon] = true }
    local fFrac, bFrac = ModernXpShare.fractions(2, true)
    local before = { a.exp, slot2.exp, bMon.exp }
    battle:awardExperience()
    local wantF, wantB = expectGain(fFrac), expectGain(bFrac)
    T.eq(a.exp - before[1], wantF, "B: fighter A gets half of 70%")
    T.eq(bMon.exp - before[3], wantF, "B: fighter B gets half of 70%")
    T.eq(slot2.exp - before[2], wantB, "B: benched slot 2 gets clamped share")
    T.check(wantB < wantF, "B: bench stays below each fighter")
    restoreOpts()
  end

  -- Scenario C: three fighters; bench clamped into mid-teens.
  do
    setOpt(ModernXpShare.OPTION_KEY, true)
    local a = Pokemon.new(Data, "BULBASAUR", 20)
    local slot2 = Pokemon.new(Data, "SQUIRTLE", 20)
    local bMon = Pokemon.new(Data, "CHARMANDER", 20)
    local cMon = Pokemon.new(Data, "PIDGEY", 20)
    local game, battle = makeBattle({ a, slot2, bMon, cMon })
    battle.participants = { [a] = true, [bMon] = true, [cMon] = true }
    local fFrac, bFrac = ModernXpShare.fractions(3, true)
    local before = { a.exp, slot2.exp, bMon.exp, cMon.exp }
    battle:awardExperience()
    local wantF, wantB = expectGain(fFrac), expectGain(bFrac)
    T.eq(a.exp - before[1], wantF, "C: fighter A share")
    T.eq(bMon.exp - before[3], wantF, "C: fighter B share")
    T.eq(cMon.exp - before[4], wantF, "C: fighter C share")
    T.eq(slot2.exp - before[2], wantB, "C: benched slot 2 clamped share")
    T.check(wantB < wantF, "C: bench stays below each fighter")
    restoreOpts()
  end

  -- Slot 2 also fought: vanilla equal split of full pool, no extra bench pass.
  do
    setOpt(ModernXpShare.OPTION_KEY, true)
    local a = Pokemon.new(Data, "BULBASAUR", 20)
    local bMon = Pokemon.new(Data, "SQUIRTLE", 20)
    local game, battle = makeBattle({ a, bMon })
    battle.participants = { [a] = true, [bMon] = true }
    local before = { a.exp, bMon.exp }
    local half = Experience.gainFor(enemyDef, 10, false, 2, false, Data.constants)
    battle:awardExperience()
    T.eq(a.exp - before[1], half, "slot 2 fought: equal half of full pool")
    T.eq(bMon.exp - before[2], half, "slot 2 fought: no extra bench share")
    restoreOpts()
  end
end
