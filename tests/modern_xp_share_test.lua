-- Slot-2 Exp. Share: 70% pool to fighters / ≤30% to bench slot 2 (clamped).
return function(T, Data, run)
  local ModernXpShare = require("mods.Kanto-Reforged.ui.modern_xp_share")
  local Experience = require("src.battle.Experience")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")

  local schema = run.loader.optionSchemas["Kanto-Reforged"]
  local modernOpt
  for _, opt in ipairs(schema or {}) do
    if opt.key == ModernXpShare.OPTION_KEY then modernOpt = opt break end
  end
  T.check(modernOpt ~= nil, "XP SHARE (SLOT 2) option schema registered")
  T.eq(modernOpt.type, "toggle", "slot-2 XP share is a toggle")
  T.eq(modernOpt.default, true, "slot-2 XP share defaults on")
  T.eq(modernOpt.label, "XP SHARE (SLOT 2)", "slot-2 XP share label")
  T.check(ModernXpShare._installed, "slot-2 XP share installed via battle.exp_award")

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
    saved[key] = run.loader.modOptions["Kanto-Reforged"]
      and run.loader.modOptions["Kanto-Reforged"][key]
    run.loader.modOptions["Kanto-Reforged"] = run.loader.modOptions["Kanto-Reforged"] or {}
    run.loader.modOptions["Kanto-Reforged"][key] = value
  end
  local function restoreOpts()
    run.loader.modOptions["Kanto-Reforged"] = run.loader.modOptions["Kanto-Reforged"] or {}
    for k, v in pairs(saved) do
      run.loader.modOptions["Kanto-Reforged"][k] = v
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
    b.sayNextAutoWaitSfx = function() end
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
    b:awardExp()
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
    b:awardExp()
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
    battle:awardExp()
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
    battle:awardExp()
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
    battle:awardExp()
    T.eq(a.exp - before[1], half, "slot 2 fought: equal half of full pool")
    T.eq(bMon.exp - before[2], half, "slot 2 fought: no extra bench share")
    restoreOpts()
  end

  -- Faint tail must not crash: awardExp's deferred steps stay a table when
  -- the hook (or a stub) suppresses a second XP pass.  Regression for the
  -- old enemyMonFainted Experience.apply stub that returned only two values.
  do
    setOpt(ModernXpShare.OPTION_KEY, true)
    local lead = Pokemon.new(Data, "BULBASAUR", 20)
    local slot2 = Pokemon.new(Data, "SQUIRTLE", 20)
    local game, b = makeBattle({ lead, slot2 })
    b.participants = { [lead] = true }
    local ok, err = pcall(function() b:awardExp() end)
    T.check(ok, "awardExp with hook does not crash: " .. tostring(err))
    -- Stock faint path re-enters awardExp safely after our payout cleared
    -- participants; second call is a no-op (empty alive).
    b.participants = {}
    ok, err = pcall(function() b:awardExp() end)
    T.check(ok, "second awardExp after share is safe: " .. tostring(err))
    restoreOpts()
  end

  -- Gen 2: same toggle drives battle.exp_award on Gold's Battle.
  do
    local okBattle, Battle = pcall(require, "src.battle.gen2.Battle")
    local okMon, Mon = pcall(require, "src.battle.gen2.Mon")
    if okBattle and okMon and Battle and Mon then
      local perfect = { attack = 15, defense = 15, speed = 15, special = 15 }
      perfect.hp = Mon.hpDV(perfect)
      local function g2Award(partySpec, optOn)
        setOpt(ModernXpShare.OPTION_KEY, optOn)
        local party, participants = {}, {}
        for index, spec in ipairs(partySpec) do
          local mon = Mon.new(Data, "MACHOP", 20, { dvs = perfect })
          if not mon then
            mon = Mon.new(Data, "BULBASAUR", 20, { dvs = perfect })
          end
          if spec.hp then mon.hp = spec.hp end
          party[index] = mon
          if spec.participant then participants[index] = true end
        end
        local wildSpecies = Data.pokemon.PIDGEY and "PIDGEY" or "RATTATA"
        local wild = Mon.new(Data, wildSpecies, 14, { dvs = perfect })
        local battle = Battle.new({
          data = Data, party = party, wild = wild,
          save = { player = { id = 1, badges = {} } },
          random = function(n) return (n or 1) > 1 and 1 or 0 end,
        })
        battle.participants = participants
        local before = {}
        for i, mon in ipairs(party) do before[i] = mon.experience or 0 end
        local ok, err = pcall(function() battle:awardExperience(wild) end)
        T.check(ok, "Gen2 awardExperience ok: " .. tostring(err))
        local gained = {}
        for i, mon in ipairs(party) do
          gained[i] = (mon.experience or 0) - before[i]
        end
        restoreOpts()
        return gained, party
      end

      local gSolo = g2Award({ { participant = true }, {} }, true)
      T.check(gSolo[1] > 0, "Gen2 toggle on: fighter gains XP")
      T.check(gSolo[2] > 0, "Gen2 toggle on: slot 2 bench gains XP")
      T.check(gSolo[1] > gSolo[2], "Gen2 toggle on: fighter gets more than bench")

      local gOff = g2Award({ { participant = true }, {} }, false)
      T.check(gOff[1] > 0, "Gen2 toggle off: fighter still gains")
      T.eq(gOff[2], 0, "Gen2 toggle off: bench gets nothing without EXP.SHARE item")

      local gBoth = g2Award({ { participant = true }, { participant = true } }, true)
      T.eq(gBoth[1], gBoth[2], "Gen2: both fighters equal when slot 2 fought")

      -- EXP.SHARE *item* must not tax our toggle payout (engine applyShare
      -- closes over halved; we bypass that while replacing vanilla).
      local function g2WithItem(optOn)
        setOpt(ModernXpShare.OPTION_KEY, optOn)
        local p1 = Mon.new(Data, "BULBASAUR", 20, { dvs = perfect })
        local p2 = Mon.new(Data, "SQUIRTLE", 20, { dvs = perfect })
        p2.item = "EXP_SHARE"
        local wild = Mon.new(Data, Data.pokemon.PIDGEY and "PIDGEY" or "RATTATA",
          14, { dvs = perfect })
        local battle = Battle.new({
          data = Data, party = { p1, p2 }, wild = wild,
          save = { player = { id = 1, badges = {} } },
          random = function(n) return (n or 1) > 1 and 1 or 0 end,
        })
        battle.participants = { [1] = true }
        local b1, b2 = p1.experience, p2.experience
        battle:awardExperience(wild)
        restoreOpts()
        return p1.experience - b1, p2.experience - b2
      end
      local noItem = gSolo
      local withItemF, withItemB = g2WithItem(true)
      T.eq(withItemF, noItem[1],
        "Gen2 toggle on: EXP.SHARE item does not tax fighter share")
      T.eq(withItemB, noItem[2],
        "Gen2 toggle on: EXP.SHARE item does not tax bench share")
      local offF, offB = g2WithItem(false)
      T.check(offB > 0, "Gen2 toggle off: EXP.SHARE item still pays the holder")
      T.check(offF > 0 and offF <= noItem[1],
        "Gen2 toggle off: vanilla halved pool for fighter")
    end
  end
end
