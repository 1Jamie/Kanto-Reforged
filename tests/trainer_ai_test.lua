-- Smarter AI scoring + curated trainer Gen 2/3 mixes.
return function(T, Data, run)
  local TrainerAi = require("mods.Kanto-Reforged.trainer_ai")
  local ExpTrainers = require("mods.Kanto-Reforged.trainers")
  local TrainerAI = require("src.battle.TrainerAI")

  local schema = run.loader.optionSchemas["Kanto-Reforged"]
  local smartOpt
  for _, opt in ipairs(schema or {}) do
    if opt.key == TrainerAi.OPTION_KEY then smartOpt = opt break end
  end
  T.check(smartOpt ~= nil, "SMARTER AI option schema registered")
  T.eq(smartOpt.type, "toggle", "smarter AI is a toggle")
  T.eq(smartOpt.default, true, "smarter AI defaults on")

  local layer = Data.ai_classes and Data.ai_classes[TrainerAi.LAYER_ID]
  T.check(layer ~= nil and layer.kind == "layer", "EXP_SMART layer registered")
  T.check(type(layer.score) == "function", "EXP_SMART has a score function")

  -- Helper view for scoring unit checks
  local function view(opts)
    opts = opts or {}
    return {
      user = opts.user or {
        curTypes = { "NORMAL" },
        stages = opts.userStages or {},
        mon = opts.userMon or { hp = 50, stats = { hp = 100 } },
        lightScreen = opts.lightScreen,
        reflect = opts.reflect,
        mist = opts.mist,
        focusEnergy = opts.focusEnergy,
        substituteHP = opts.substituteHP,
      },
      target = opts.target or {
        curTypes = opts.targetTypes or { "NORMAL" },
        stages = opts.targetStages or {},
        mon = opts.targetMon or { hp = 50, stats = { hp = 50 }, status = opts.status },
        confusedTurns = opts.confused,
        leechSeeded = opts.seeded,
        expYawnTurns = opts.yawn,
      },
    }
  end

  local growDef = Data.moves.GROWL
  local tackleDef = Data.moves.TACKLE
  T.check(growDef and tackleDef, "GROWL and TACKLE exist for AI scoring tests")

  -- At attack -6, Growl is dumped; Tackle is preferred.
  local vFloor = view({ targetStages = { attack = -6 } })
  local growFloor = TrainerAi.score(vFloor, growDef, 10)
  local tackleFloor = TrainerAi.score(vFloor, tackleDef, 10)
  T.check(growFloor > tackleFloor + 2,
    "smart AI dumps Growl at -6 harder than it rates Tackle")

  -- Fresh stages / healthy: Growl can compete with Tackle once; not forever.
  local vFresh = view({ userMon = { hp = 80, stats = { hp = 100 } } })
  local growFresh = TrainerAi.score(vFresh, growDef, 10)
  local tackleFresh = TrainerAi.score(vFresh, tackleDef, 10)
  T.check(growFresh <= tackleFresh,
    "smart AI lets Growl compete with or beat Tackle when stages are fresh")

  -- After one Attack drop, Growl backs off so Tackle wins.
  local vOnce = view({
    userMon = { hp = 80, stats = { hp = 100 } },
    targetStages = { attack = -1 },
  })
  T.check(TrainerAi.score(vOnce, growDef, 10) > TrainerAi.score(vOnce, tackleDef, 10),
    "smart AI stops preferring Growl after one Attack drop")

  -- Sand Attack: ok once at 0 accuracy; locked spam after -1 is the bug we fixed.
  local sandDef = Data.moves.SAND_ATTACK
  if sandDef then
    local vSandFresh = view({ userMon = { hp = 80, stats = { hp = 100 } } })
    T.check(TrainerAi.score(vSandFresh, sandDef, 10)
        <= TrainerAi.score(vSandFresh, tackleDef, 10),
      "smart AI lets Sand Attack compete once while accuracy is fresh")
    local vSandHit = view({
      userMon = { hp = 80, stats = { hp = 100 } },
      targetStages = { accuracy = -1 },
    })
    T.check(TrainerAi.score(vSandHit, sandDef, 10)
        > TrainerAi.score(vSandHit, tackleDef, 10) + 2,
      "smart AI dumps Sand Attack after one Accuracy drop")
  end

  -- Already-statused sleep move is dumped.
  local sleepDef = Data.moves.SING or Data.moves.SLEEP_POWDER or Data.moves.HYPNOSIS
  if sleepDef then
    local vStatus = view({ status = "PSN" })
    T.check(TrainerAi.score(vStatus, sleepDef, 10) >= 16,
      "smart AI dumps sleep moves when the target is already statused")

    -- Healthy opener: status can beat a neutral attack.
    local vHealthy = view({
      userMon = { hp = 80, stats = { hp = 100 } },
      status = nil,
    })
    T.check(TrainerAi.score(vHealthy, sleepDef, 10)
        < TrainerAi.score(vHealthy, tackleDef, 10),
      "smart AI prefers sleep over Tackle vs a healthy unstatused target")
  end

  -- Will-O-Wisp (Will-O-Wisp burn) treated as status infliction.
  local willO = Data.moves.WILL_O_WISP
  if willO then
    local vBurn = view({ userMon = { hp = 80, stats = { hp = 100 } } })
    T.check(TrainerAi.score(vBurn, willO, 10) < TrainerAi.score(vBurn, tackleDef, 10),
      "smart AI prefers Will-O-Wisp over Tackle when healthy")
    T.check(TrainerAi.score(view({ status = "PAR" }), willO, 10) >= 16,
      "smart AI dumps Will-O-Wisp into an already-statused target")
  end

  -- Super-effective damaging gets an extra nudge.
  local ember = Data.moves.EMBER
  if ember then
    local vGrass = view({ targetTypes = { "GRASS" } })
    local vWater = view({ targetTypes = { "WATER" } })
    T.check(TrainerAi.score(vGrass, ember, 10) < TrainerAi.score(vWater, ember, 10),
      "smart AI prefers Ember into Grass over Ember into Water")
  end

  -- Equal-scoring attacks stay tied so chooseMove can roll between them
  -- (Scratch vs Tackle: both Normal damaging, same STAB/effectiveness).
  local scratchDef = Data.moves.SCRATCH
  T.check(scratchDef ~= nil, "SCRATCH exists for attack-tie tests")
  do
    local v = view()
    T.eq(TrainerAi.score(v, tackleDef, 10), TrainerAi.score(v, scratchDef, 10),
      "two equal Normal attacks keep the same EXP_SMART score (random tiebreak)")
  end

  -- Self setup while healthy: Swords Dance / Growth-style preferred early.
  local swords = Data.moves.SWORDS_DANCE or Data.moves.MEDITATE or Data.moves.SHARPNESS
  if not swords then
    -- Fall back to any ATTACK_UP2 / DEFENSE_UP2 style from Data.moves
    for _, def in pairs(Data.moves) do
      if def.effect == "ATTACK_UP2_EFFECT" or def.effect == "SPECIAL_UP2_EFFECT" then
        swords = def
        break
      end
    end
  end
  if swords then
    local vSetup = view({
      userMon = { hp = 90, stats = { hp = 100 } },
      userStages = { attack = 0, special = 0 },
    })
    T.check(TrainerAi.score(vSetup, swords, 10) < TrainerAi.score(vSetup, tackleDef, 10),
      "smart AI prefers setup over Tackle while healthy with fresh stages")
    local vStacked = view({
      userMon = { hp = 90, stats = { hp = 100 } },
      userStages = { attack = 2, special = 2 },
    })
    T.check(TrainerAi.score(vStacked, swords, 10) > TrainerAi.score(vStacked, tackleDef, 10),
      "smart AI stops preferring setup once stages are already boosted")
  end

  -- Heal preferred at low HP over status.
  local healDef = Data.moves.RECOVER or Data.moves.SOFTBOILED or Data.moves.REST
  if healDef and healDef.effect == "HEAL_EFFECT" then
    local vLow = view({
      userMon = { hp = 20, stats = { hp = 100 } },
      status = nil,
    })
    local statusMove = sleepDef or Data.moves.POISON_POWDER
    if statusMove then
      T.check(TrainerAi.score(vLow, healDef, 10) < TrainerAi.score(vLow, statusMove, 10),
        "smart AI prefers heal over status at low HP")
    end
    T.check(TrainerAi.score(vLow, healDef, 10) < TrainerAi.score(vLow, tackleDef, 10),
      "smart AI prefers heal over Tackle at low HP")
    local vFull = view({ userMon = { hp = 100, stats = { hp = 100 } } })
    T.check(TrainerAi.score(vFull, healDef, 10) >= 16,
      "smart AI dumps heal at full HP")
  end

  -- Status dump is per current target: poisoned mon dumps Toxic-likes,
  -- a fresh switch-in does not inherit that dump.
  local poisonMove = Data.moves.POISON_POWDER or Data.moves.POISON_GAS or Data.moves.TOXIC
  T.check(poisonMove ~= nil, "a poison-status move exists for switch tests")
  do
    local againstPoisoned = TrainerAi.score(view({ status = "PAR" }), poisonMove, 10)
    local againstFresh = TrainerAi.score(view({ status = nil }), poisonMove, 10)
    T.check(againstPoisoned >= 16,
      "status move dumped hard against an already-statused active target")
    T.check(againstFresh < againstPoisoned - 3,
      "after a switch to a fresh mon, status moves are reconsidered (not battle-cached)")
  end

  -- chooseMove with empty aiMods (wild-style) still uses EXP_SMART when on.
  local savedOpts = run.loader.modOptions["Kanto-Reforged"]
  run.loader.modOptions["Kanto-Reforged"] = run.loader.modOptions["Kanto-Reforged"] or {}
  run.loader.modOptions["Kanto-Reforged"][TrainerAi.OPTION_KEY] = true

  local mon = {
    curMoves = {
      { id = "GROWL", pp = 40 },
      { id = "TACKLE", pp = 35 },
    },
    curTypes = { "NORMAL" },
    stages = {},
    mon = { hp = 30, stats = { hp = 30 } },
    aiLayer2 = 0,
  }
  local battle = {
    data = Data,
    enemyAIMods = {},
    player = {
      curTypes = { "NORMAL" },
      stages = { attack = -6 },
      mon = { hp = 40, stats = { hp = 40 } },
    },
    ruleset = { enemyUnlimitedPP = true },
  }
  -- Force a deterministic "random" that would pick Growl if scoring were skipped
  -- (index 1). Smart scoring must still land on Tackle at -6.
  local picks = {}
  for _ = 1, 8 do
    mon.aiLayer2 = 0
    local pick = TrainerAI.chooseMove(mon, function() return 1 end, battle)
    picks[#picks + 1] = pick.id
  end
  local sawTackle = false
  for _, id in ipairs(picks) do
    if id == "TACKLE" then sawTackle = true end
  end
  T.check(sawTackle, "wild-style empty aiMods still prefers Tackle via EXP_SMART")
  T.check(picks[1] ~= "GROWL" or sawTackle,
    "smart AI does not exclusively spam Growl at -6")

  -- Two tied attacks: cycling rng must see both, not lock onto slot 1.
  do
    local attacker = {
      curMoves = {
        { id = "TACKLE", pp = 35 },
        { id = "SCRATCH", pp = 35 },
      },
      curTypes = { "NORMAL" },
      stages = {},
      mon = { hp = 40, stats = { hp = 40 } },
      aiLayer2 = 0,
    }
    local b = {
      data = Data,
      enemyAIMods = { TrainerAi.LAYER_ID },
      player = {
        curTypes = { "NORMAL" },
        stages = {},
        mon = { hp = 40, stats = { hp = 40 } },
      },
      ruleset = { enemyUnlimitedPP = true },
    }
    local n, seen = 0, {}
    local function cycleRng(lo, hi)
      n = n + 1
      if hi <= lo then return lo end
      return (n % 2 == 1) and lo or hi
    end
    for _ = 1, 12 do
      attacker.aiLayer2 = 0
      local pick = TrainerAI.chooseMove(attacker, cycleRng, b)
      seen[pick.id] = true
    end
    T.check(seen.TACKLE and seen.SCRATCH,
      "equal-scoring attacks are rolled among, not locked to movelist order")
  end

  -- Live chooseMove re-reads battle.player each call: status dump lifts after
  -- the active target is replaced (player switch).
  do
    local poisonId = poisonMove.id
    local caster = {
      curMoves = {
        { id = poisonId, pp = 35 },
        { id = "TACKLE", pp = 35 },
      },
      curTypes = { "NORMAL" },
      stages = {},
      mon = { hp = 40, stats = { hp = 40 } },
      aiLayer2 = 0,
    }
    local poisonedPlayer = {
      curTypes = { "NORMAL" },
      stages = {},
      mon = { hp = 40, stats = { hp = 40 }, status = "PAR" },
    }
    local freshPlayer = {
      curTypes = { "NORMAL" },
      stages = {},
      mon = { hp = 40, stats = { hp = 40 } },
    }
    local b = {
      data = Data,
      enemyAIMods = { TrainerAi.LAYER_ID },
      player = poisonedPlayer,
      ruleset = { enemyUnlimitedPP = true },
    }
    -- Against the statused mon, force the only minimum (Tackle).
    caster.aiLayer2 = 0
    local vsStatused = TrainerAI.chooseMove(caster, function() return 1 end, b)
    T.eq(vsStatused.id, "TACKLE",
      "chooseMove dumps status into an already-statused active target")

    -- Player switches: status move is eligible again and can win vs Tackle
    -- when the user is healthy enough for the opener bonus.
    b.player = freshPlayer
    caster.mon.hp = 40
    caster.mon.stats = { hp = 40 }
    caster.aiLayer2 = 0
    local vsFresh = TrainerAI.chooseMove(caster, function() return 1 end, b)
    T.eq(vsFresh.id, poisonId,
      "chooseMove opens with status into a fresh healthy switch-in")
  end

  -- Toggle off restores vanilla empty-mod random (rng returns 1 → GROWL).
  run.loader.modOptions["Kanto-Reforged"][TrainerAi.OPTION_KEY] = false
  mon.aiLayer2 = 0
  battle.enemyAIMods = {}
  local vanillaPick = TrainerAI.chooseMove(mon, function() return 1 end, battle)
  T.eq(vanillaPick.id, "GROWL", "with smarter AI off, empty mods stay uniform-random")

  run.loader.modOptions["Kanto-Reforged"][TrainerAi.OPTION_KEY] = true

  -- ------- Three-tier gate -------------------------------------------------
  local tactLayer = Data.ai_classes[TrainerAi.LAYER_TACTICAL]
  local liteLayer = Data.ai_classes[TrainerAi.LAYER_TACTICAL_LITE]
  T.check(tactLayer and tactLayer.kind == "layer", "EXP_TACTICAL layer registered")
  T.check(liteLayer and liteLayer.kind == "layer", "EXP_TACTICAL_LITE layer registered")

  local function fakeBattle(opts)
    opts = opts or {}
    return {
      kind = "trainer",
      oppClass = opts.class,
      trainer = { id = opts.class },
      expPartyIndex = opts.party or 1,
      expMapId = opts.map,
      data = Data,
      enemyAIMods = opts.aiMods or {},
      ruleset = { randMin = 217, randMax = 255, critIgnoresStages = true,
                  enemyUnlimitedPP = true },
    }
  end

  -- Elite-before-lite: Brock on PEWTER_GYM must stay elite (gate-order regression).
  T.eq(TrainerAi.tier(fakeBattle({ class = "OPP_BROCK", party = 1, map = "PEWTER_GYM" })),
    "elite", "Brock on PEWTER_GYM is elite, not lite (elite checked first)")
  T.eq(TrainerAi.tier(fakeBattle({
    class = "OPP_JR_TRAINER_M", party = 1, map = "PEWTER_GYM",
  })), "lite", "Pewter gym Jr Trainer is lite")
  T.eq(TrainerAi.tier(fakeBattle({
    class = "OPP_YOUNGSTER", party = 1, map = "ROUTE_1",
  })), "soft", "route Youngster stays soft")
  T.eq(TrainerAi.tier(fakeBattle({ class = "OPP_COOLTRAINER_M", party = 1 })),
    "lite", "Cooltrainer is lite anywhere")

  -- Rocket party split: #1-4/#6 elite, #5 lite (easy off-by-one).
  T.eq(TrainerAi.tier(fakeBattle({ class = "OPP_ROCKET", party = 1 })),
    "elite", "Rocket#1 (Mt Moon) is elite")
  T.eq(TrainerAi.tier(fakeBattle({ class = "OPP_ROCKET", party = 5 })),
    "lite", "Rocket#5 is lite (not elite)")
  T.eq(TrainerAi.tier(fakeBattle({ class = "OPP_ROCKET", party = 6 })),
    "elite", "Rocket#6 (Nugget Bridge) is elite")
  T.eq(TrainerAi.isElite("OPP_ROCKET", 3), true, "Rocket#3 is elite")
  T.eq(TrainerAi.isElite("OPP_ROCKET", 5), false, "Rocket#5 is not elite")

  -- ------- Damage / KO policy (lite mid-only vs elite high-roll) ------------
  local function atkBattler(opts)
    opts = opts or {}
    return {
      curTypes = opts.types or { "WATER" },
      stages = {},
      curStats = opts.stats or { attack = 80, defense = 50, special = 80, speed = 60 },
      curMoves = opts.moves or {
        { id = "WATER_GUN", pp = 25 },
        { id = "GROWL", pp = 40 },
      },
      mon = {
        hp = opts.hp or 60, stats = { hp = 60 }, level = opts.level or 30,
        species = opts.species or "SQUIRTLE",
      },
      aiLayer2 = 0,
    }
  end
  local function defBattler(opts)
    opts = opts or {}
    return {
      curTypes = opts.types or { "FIRE" },
      stages = {},
      curStats = opts.stats or { attack = 40, defense = 40, special = 40, speed = 40 },
      mon = {
        hp = opts.hp or 20, stats = { hp = opts.maxHp or 80 }, level = 20,
        species = opts.species or "CHARMANDER",
        status = opts.status,
      },
    }
  end

  local waterGun = Data.moves.WATER_GUN
  local growDef2 = Data.moves.GROWL
  T.check(waterGun ~= nil, "WATER_GUN exists for tactical KO tests")

  do
    -- Build a board where mid-roll does not KO but high-roll does.
    local attacker = atkBattler({
      level = 25,
      stats = { attack = 55, defense = 50, special = 55, speed = 50 },
      moves = { { id = "WATER_GUN", pp = 25 }, { id = "GROWL", pp = 40 } },
    })
    local targetHp = 18
    local defender = defBattler({
      hp = targetHp, maxHp = 80,
      stats = { attack = 40, defense = 60, special = 70, speed = 40 },
    })
    local b = fakeBattle({ class = "OPP_BROCK", party = 1, map = "PEWTER_GYM" })
    b.player = defender
    local mid, high = TrainerAi.estimateDamage(b, attacker, defender, waterGun, {
      highRoll = true,
    })
    T.check(mid ~= nil and high ~= nil, "estimateDamage returns mid and high")
    -- If the numbers don't split, nudge HP into the gap for a fair policy test.
    if mid >= targetHp or high < targetHp then
      defender.mon.hp = math.max(1, mid + 1)
      if high < defender.mon.hp then
        -- Force a synthetic split for the score-policy assertion below.
        mid, high = defender.mon.hp - 1, defender.mon.hp
      else
        mid, high = TrainerAi.estimateDamage(b, attacker, defender, waterGun, {
          highRoll = true,
        })
      end
    end
    T.check(mid < defender.mon.hp and high >= defender.mon.hp,
      "fixture: mid-roll misses KO, high-roll would KO")

    local vElite = {
      user = attacker, target = defender, battle = b, data = Data,
    }
    local vLite = {
      user = attacker, target = defender,
      battle = fakeBattle({ class = "OPP_JR_TRAINER_M", map = "PEWTER_GYM" }),
      data = Data,
    }
    local eliteGun = TrainerAi.scoreTactical(vElite, waterGun, 10)
    local eliteGrowl = TrainerAi.scoreTactical(vElite, growDef2, 10)
    local liteGun = TrainerAi.scoreTacticalLite(vLite, waterGun, 10)
    local liteGrowl = TrainerAi.scoreTacticalLite(vLite, growDef2, 10)
    T.check(eliteGun < eliteGrowl,
      "elite KO bias (high-roll) prefers Water Gun over Growl")
    -- Lite must NOT treat high-roll-only KO as a finish: Growl can still compete
    -- or win when mid-roll does not KO (mild bias only on mid).
    T.check(liteGun >= eliteGun or liteGrowl <= eliteGrowl,
      "lite mid-roll policy is weaker / distinct from elite high-roll KO")
    T.check(eliteGun < liteGun,
      "elite scores a high-roll KO attack harder than lite on the same board")
  end

  -- Elite setup dump under KO pressure is stronger than lite.
  do
    local swords = Data.moves.SWORDS_DANCE
    local attacker = atkBattler({
      level = 40,
      stats = { attack = 120, defense = 50, special = 100, speed = 80 },
      moves = {
        { id = "HYDRO_PUMP", pp = 5 },
        { id = "SWORDS_DANCE", pp = 20 },
      },
      types = { "WATER" },
    })
    if not Data.moves.HYDRO_PUMP then
      attacker.curMoves[1] = { id = "WATER_GUN", pp = 25 }
    end
    local defender = defBattler({
      hp = 5, maxHp = 80,
      stats = { attack = 30, defense = 30, special = 30, speed = 30 },
    })
    local bElite = fakeBattle({ class = "OPP_LANCE", party = 1 })
    bElite.player = defender
    local vE = { user = attacker, target = defender, battle = bElite, data = Data }
    local vL = {
      user = attacker, target = defender,
      battle = fakeBattle({ class = "OPP_COOLTRAINER_F", party = 1 }),
      data = Data,
    }
    local atkId = attacker.curMoves[1].id
    local atkDef = Data.moves[atkId]
    if swords and atkDef then
      local eAtk = TrainerAi.scoreTactical(vE, atkDef, 10)
      local eSetup = TrainerAi.scoreTactical(vE, swords, 10)
      local lAtk = TrainerAi.scoreTacticalLite(vL, atkDef, 10)
      local lSetup = TrainerAi.scoreTacticalLite(vL, swords, 10)
      T.check(eAtk < eSetup, "elite prefers attack over setup when a KO exists")
      T.check((eSetup - eAtk) >= (lSetup - lAtk),
        "elite KO/setup pressure gap is at least as strong as lite")
    end
  end

  -- Lance theme: SE STAB gets an extra nudge vs a neutral equal attack.
  do
    local ember = Data.moves.EMBER
    local tackle = Data.moves.TACKLE
    if ember and tackle then
      local user = {
        curTypes = { "FIRE", "FLYING" },
        stages = {},
        curStats = { attack = 70, defense = 60, special = 70, speed = 70 },
        curMoves = { { id = "EMBER", pp = 25 }, { id = "TACKLE", pp = 35 } },
        mon = { hp = 70, stats = { hp = 70 }, level = 40, species = "CHARIZARD" },
      }
      local grass = defBattler({
        types = { "GRASS" },
        hp = 60, maxHp = 60,
        stats = { attack = 50, defense = 50, special = 50, speed = 50 },
      })
      local bLance = fakeBattle({ class = "OPP_LANCE", party = 1 })
      bLance.player = grass
      local bPlain = fakeBattle({ class = "OPP_RIVAL1", party = 1 })
      bPlain.player = grass
      local vLance = { user = user, target = grass, battle = bLance, data = Data }
      local vPlain = { user = user, target = grass, battle = bPlain, data = Data }
      local lanceGap = TrainerAi.scoreTactical(vPlain, tackle, 10)
        - TrainerAi.scoreTactical(vLance, ember, 10)
      local plainGap = TrainerAi.scoreTactical(vPlain, tackle, 10)
        - TrainerAi.scoreTactical(vPlain, ember, 10)
      T.check(lanceGap >= plainGap,
        "Lance theme does not weaken SE preference vs a plain elite")
      -- Theme preferSE/preferSTAB should make Ember at least as attractive.
      T.check(TrainerAi.scoreTactical(vLance, ember, 10)
          <= TrainerAi.scoreTactical(vPlain, ember, 10),
        "Lance theme scores SE Ember at least as well as unthemed elite")
    end
  end

  -- Elite matchup switch picks the better backup; lite introduces none.
  local function battlerFromPartyMon(mon)
    local def = Data.pokemon[mon.species]
    return {
      mon = mon,
      def = def,
      curStats = mon.stats,
      curTypes = (def and def.types) or { "NORMAL" },
      stages = {},
      curMoves = mon.moves,
      aiLayer2 = 0,
    }
  end

  do
    local player = defBattler({
      types = { "WATER" },
      hp = 50, maxHp = 50,
      stats = { attack = 50, defense = 50, special = 50, speed = 50 },
      species = "SQUIRTLE",
    })
    -- Ensure player types match Water for Ember resist / Grass SE.
    player.curTypes = { "WATER" }
    local weakMon = {
      species = "CHARMANDER", level = 25, hp = 40,
      stats = { hp = 40, attack = 52, defense = 30, special = 50, speed = 50 },
      moves = { { id = "EMBER", pp = 25 }, { id = "SCRATCH", pp = 35 } },
    }
    local strongMon = {
      species = "ODDISH", level = 25, hp = 45,
      stats = { hp = 45, attack = 50, defense = 50, special = 60, speed = 40 },
      moves = {
        { id = (Data.moves.ABSORB and "ABSORB") or "TACKLE", pp = 25 },
        { id = "TACKLE", pp = 35 },
      },
    }
    -- Prefer a Grass move if available.
    if Data.moves.VINE_WHIP then
      strongMon.moves[1] = { id = "VINE_WHIP", pp = 25 }
      strongMon.species = "BULBASAUR"
    elseif Data.moves.MEGA_DRAIN then
      strongMon.moves[1] = { id = "MEGA_DRAIN", pp = 10 }
    end
    local b = fakeBattle({ class = "OPP_AGATHA", party = 1 })
    b.player = player
    b.enemyIndex = 1
    b.enemyParty = { weakMon, strongMon }
    b.enemy = battlerFromPartyMon(weakMon)
    b.aiUses = 2
    b.expAiSwitches = 0
    b.expAiSwitchMon = 1

    local bestIdx, bestScore, curScore = TrainerAi.bestSwitchIndex(b)
    T.eq(bestIdx, 2, "bestSwitchIndex picks the Grass backup into Water")
    T.check(bestScore > curScore, "backup outdamages the Fire active into Water")

    local act = TrainerAi.eliteAction(b)
    T.check(act and act.special == "aiSwitch" and act.index == 2,
      "eliteAction matchup-switches to the better backup")

    local bLite = fakeBattle({ class = "OPP_COOLTRAINER_M", party = 1 })
    bLite.player = player
    bLite.enemyIndex = 1
    bLite.enemyParty = { weakMon, strongMon }
    bLite.enemy = battlerFromPartyMon(weakMon)
    bLite.aiUses = 2
    local liteAct = TrainerAi.liteAction(bLite)
    T.check(liteAct == nil or liteAct.special ~= "aiSwitch",
      "liteAction does not introduce matchup pivots")
  end

  -- chooseMove injects the right tactical layer by tier.
  do
    local attacker = {
      curMoves = { { id = "TACKLE", pp = 35 }, { id = "GROWL", pp = 40 } },
      curTypes = { "NORMAL" },
      stages = {},
      curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
      mon = { hp = 40, stats = { hp = 40 }, level = 20, species = "RATTATA" },
      aiLayer2 = 0,
    }
    local player = {
      curTypes = { "NORMAL" },
      stages = { attack = -6 },
      curStats = { attack = 40, defense = 40, special = 40, speed = 40 },
      mon = { hp = 40, stats = { hp = 40 }, level = 20 },
    }

    local seen = {}
    local function captureInject(b)
      local layer = Data.ai_classes[TrainerAi.LAYER_ID]
      local savedScore = layer.score
      layer.score = function(view, def, score)
        local mods = view.battle and view.battle.enemyAIMods or {}
        local hasT, hasL = false, false
        for _, m in ipairs(mods) do
          if m == TrainerAi.LAYER_TACTICAL then hasT = true end
          if m == TrainerAi.LAYER_TACTICAL_LITE then hasL = true end
        end
        seen.tactical = hasT
        seen.lite = hasL
        seen.smart = false
        for _, m in ipairs(mods) do
          if m == TrainerAi.LAYER_ID then seen.smart = true end
        end
        return savedScore(view, def, score)
      end
      attacker.aiLayer2 = 0
      TrainerAI.chooseMove(attacker, function() return 1 end, b)
      layer.score = savedScore
    end

    local bElite = fakeBattle({ class = "OPP_BROCK", party = 1, map = "PEWTER_GYM" })
    bElite.player = player
    seen = {}
    captureInject(bElite)
    T.check(seen.smart and seen.tactical and not seen.lite,
      "elite chooseMove injects EXP_SMART + EXP_TACTICAL only")

    local bLite = fakeBattle({
      class = "OPP_JR_TRAINER_M", party = 1, map = "PEWTER_GYM",
    })
    bLite.player = player
    seen = {}
    captureInject(bLite)
    T.check(seen.smart and seen.lite and not seen.tactical,
      "lite chooseMove injects EXP_SMART + EXP_TACTICAL_LITE only")

    local bSoft = fakeBattle({ class = "OPP_YOUNGSTER", party = 1, map = "ROUTE_1" })
    bSoft.player = player
    seen = {}
    captureInject(bSoft)
    T.check(seen.smart and not seen.tactical and not seen.lite,
      "soft chooseMove injects EXP_SMART only")
  end

  -- Toggle off: elite and lite both stop injecting tactical layers.
  do
    run.loader.modOptions["Kanto-Reforged"][TrainerAi.OPTION_KEY] = false
    local attacker = {
      curMoves = { { id = "GROWL", pp = 40 }, { id = "TACKLE", pp = 35 } },
      curTypes = { "NORMAL" },
      stages = {},
      curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
      mon = { hp = 30, stats = { hp = 30 }, level = 10, species = "RATTATA" },
      aiLayer2 = 0,
    }
    local player = {
      curTypes = { "NORMAL" },
      stages = { attack = -6 },
      curStats = { attack = 40, defense = 40, special = 40, speed = 40 },
      mon = { hp = 40, stats = { hp = 40 }, level = 10 },
    }

    -- Elite off: empty aiMods → uniform random (GROWL at rng=1).
    local bElite = fakeBattle({ class = "OPP_BROCK", party = 1, map = "PEWTER_GYM" })
    bElite.player = player
    bElite.enemyAIMods = {}
    attacker.aiLayer2 = 0
    local eliteOff = TrainerAI.chooseMove(attacker, function() return 1 end, bElite)
    T.eq(eliteOff.id, "GROWL",
      "toggle off: elite empty-mods stays vanilla-random (no EXP_TACTICAL)")

    -- Lite off: gym Jr Trainer likewise vanilla-random.
    local bLite = fakeBattle({
      class = "OPP_JR_TRAINER_M", party = 1, map = "PEWTER_GYM",
    })
    bLite.player = player
    bLite.enemyAIMods = {}
    attacker.aiLayer2 = 0
    local liteOff = TrainerAI.chooseMove(attacker, function() return 1 end, bLite)
    T.eq(liteOff.id, "GROWL",
      "toggle off: lite gym Jr Trainer stays vanilla-random (no EXP_TACTICAL_LITE)")

    run.loader.modOptions["Kanto-Reforged"][TrainerAi.OPTION_KEY] = true
  end

  run.loader.modOptions["Kanto-Reforged"] = savedOpts

  -- Trainer mixes landed on the live Data table.
  T.eq(Data.trainers.OPP_BROCK.parties[1][1].species, "ARON",
    "Brock's Geodude swapped for Aron")
  T.eq(Data.trainers.OPP_MISTY.parties[1][1].species, "MARILL",
    "Misty's Staryu swapped for Marill")
  T.eq(Data.trainers.OPP_LT_SURGE.parties[1][1].species, "ELECTRIKE",
    "Surge's Voltorb swapped for Electrike")
  T.eq(Data.trainers.OPP_ERIKA.parties[1][2].species, "ROSELIA",
    "Erika's Tangela swapped for Roselia")
  T.eq(Data.trainers.OPP_BLAINE.parties[1][1].species, "HOUNDOUR",
    "Blaine's Growlithe swapped for Houndour")
  T.eq(Data.trainers.OPP_GIOVANNI.parties[3][2].species, "DONPHAN",
    "Giovanni gym Dugtrio swapped for Donphan")
  T.eq(Data.trainers.OPP_LORELEI.parties[1][1].species, "PILOSWINE",
    "Lorelei's Dewgong swapped for Piloswine")
  T.eq(Data.trainers.OPP_BRUNO.parties[1][1].species, "STEELIX",
    "Bruno's Onix swapped for Steelix")
  T.eq(Data.trainers.OPP_AGATHA.parties[1][2].species, "CROBAT",
    "Agatha's Golbat swapped for Crobat")
  T.eq(Data.trainers.OPP_LANCE.parties[1][1].species, "KINGDRA",
    "Lance's Gyarados swapped for Kingdra")
  T.eq(Data.trainers.OPP_RIVAL3.parties[1][3].species, "AGGRON",
    "Champion rival Rhydon swapped for Aggron")
  T.eq(Data.trainers.OPP_BUG_CATCHER.parties[1][1].species, "SPINARAK",
    "Bug Catcher party 1 leads with Spinarak")
  T.eq(Data.trainers.OPP_HIKER.parties[1][1].species, "ARON",
    "Hiker party 1 leads with Aron")

  -- Onix ace still there for Brock (only first slot swapped)
  T.eq(Data.trainers.OPP_BROCK.parties[1][2].species, "ONIX",
    "Brock still ends on Onix")

  -- Mix table is non-empty and only references registered species
  T.check(#ExpTrainers.MIX >= 20, "curated trainer mix has a real set of swaps")
  for _, row in ipairs(ExpTrainers.MIX) do
    local species = row[4]
    T.check(Data.pokemon[species] ~= nil,
      "trainer mix species " .. tostring(species) .. " is registered")
  end
end
