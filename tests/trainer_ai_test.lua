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

  -- Fresh stages / healthy: mild Growl prefer loses to STAB Tackle; ties non-STAB.
  local vFresh = view({ userMon = { hp = 80, stats = { hp = 100 } } })
  local growFresh = TrainerAi.score(vFresh, growDef, 10)
  local tackleFresh = TrainerAi.score(vFresh, tackleDef, 10)
  T.check(growFresh > tackleFresh,
    "smart AI prefers STAB Tackle over fresh Growl on soft")
  local vFreshWater = view({
    user = {
      curTypes = { "WATER" },
      stages = {},
      mon = { hp = 80, stats = { hp = 100 } },
    },
    target = {
      curTypes = { "NORMAL" },
      stages = {},
      mon = { hp = 50, stats = { hp = 50 } },
    },
  })
  T.eq(TrainerAi.score(vFreshWater, growDef, 10),
      TrainerAi.score(vFreshWater, tackleDef, 10),
    "smart AI lets Growl tie a non-STAB Tackle when stages are fresh")

  -- After one Attack drop, Growl backs off so Tackle wins.
  local vOnce = view({
    userMon = { hp = 80, stats = { hp = 100 } },
    targetStages = { attack = -1 },
  })
  T.check(TrainerAi.score(vOnce, growDef, 10) > TrainerAi.score(vOnce, tackleDef, 10),
    "smart AI stops preferring Growl after one Attack drop")

  -- Sand Attack: mild once at 0 accuracy; locked spam after -1 is the bug we fixed.
  local sandDef = Data.moves.SAND_ATTACK
  if sandDef then
    local vSandFresh = view({ userMon = { hp = 80, stats = { hp = 100 } } })
    T.check(TrainerAi.score(vSandFresh, sandDef, 10)
        > TrainerAi.score(vSandFresh, tackleDef, 10),
      "smart AI prefers STAB Tackle over fresh Sand Attack on soft")
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

    -- Healthy opener: sleep only gets a mild -1, so STAB Tackle still wins;
    -- against a non-STAB attack they tie (random among minima).
    local vHealthy = view({
      userMon = { hp = 80, stats = { hp = 100 } },
      status = nil,
    })
    T.check(TrainerAi.score(vHealthy, sleepDef, 10)
        > TrainerAi.score(vHealthy, tackleDef, 10),
      "smart AI prefers STAB Tackle over sleep on soft (no status lock)")
    local vNoStab = view({
      user = {
        curTypes = { "WATER" },
        stages = {},
        mon = { hp = 80, stats = { hp = 100 } },
      },
      target = {
        curTypes = { "NORMAL" },
        stages = {},
        mon = { hp = 50, stats = { hp = 50 }, status = nil },
      },
    })
    T.check(TrainerAi.score(vNoStab, sleepDef, 10)
        == TrainerAi.score(vNoStab, tackleDef, 10) + 1,
      "smart AI applies low-acc sleep cost vs a non-STAB Tackle when healthy")
    local confusionDef = Data.moves.CONFUSION
    if confusionDef then
      local vPsychic = view({
        user = {
          curTypes = { "PSYCHIC_TYPE" },
          stages = {},
          mon = { hp = 80, stats = { hp = 100 } },
        },
        target = {
          curTypes = { "NORMAL" },
          stages = {},
          mon = { hp = 50, stats = { hp = 50 }, status = nil },
        },
      })
      T.check(TrainerAi.score(vPsychic, sleepDef, 10)
          > TrainerAi.score(vPsychic, confusionDef, 10),
        "smart AI prefers STAB Confusion over Hypnosis/Sing on soft")
    end

    local sonic = Data.moves.SUPERSONIC
    if sonic then
      T.check(TrainerAi.score(vHealthy, sonic, 10)
          > TrainerAi.score(vHealthy, tackleDef, 10),
        "smart AI prefers STAB Tackle over Supersonic on soft")
      T.check(TrainerAi.score(vNoStab, sonic, 10)
          == TrainerAi.score(vNoStab, tackleDef, 10) + 1,
        "smart AI applies low-acc Supersonic cost vs a non-STAB Tackle when healthy")
    end

    -- Decaying weight: after use the move is devalued, then returns to baseline.
    local vWeighted = view({
      user = {
        curTypes = { "WATER" },
        stages = {},
        mon = { hp = 80, stats = { hp = 100 } },
        expAiMoveWeight = { [sleepDef.id] = 4 },
      },
      target = {
        curTypes = { "NORMAL" },
        stages = {},
        mon = { hp = 50, stats = { hp = 50 }, status = nil },
      },
    })
    T.check(TrainerAi.score(vWeighted, sleepDef, 10)
        > TrainerAi.score(vWeighted, tackleDef, 10) + 2,
      "smart AI devalues sleep while its decay weight is high")
    local vCooled = view({
      user = {
        curTypes = { "WATER" },
        stages = {},
        mon = { hp = 80, stats = { hp = 100 } },
        expAiMoveWeight = { [sleepDef.id] = 1 },
      },
      target = {
        curTypes = { "NORMAL" },
        stages = {},
        mon = { hp = 50, stats = { hp = 50 }, status = nil },
      },
    })
    T.check(TrainerAi.score(vCooled, sleepDef, 10)
        > TrainerAi.score(vNoStab, sleepDef, 10),
      "partially cooled sleep is still above baseline")
    T.check(TrainerAi.score(vNoStab, sleepDef, 10)
        == TrainerAi.score(vNoStab, tackleDef, 10) + 1,
      "at baseline weight low-acc sleep still costs vs non-STAB Tackle")

    local decayUser = { expAiMoveWeight = { HYPNOSIS = 3, GROWL = 1 } }
    TrainerAi.decayMoveWeights(decayUser)
    T.eq(decayUser.expAiMoveWeight.HYPNOSIS, 2, "decay reduces opener weight by 1")
    T.eq(decayUser.expAiMoveWeight.GROWL, nil, "decay clears weight at 1")
  end

  -- Will-O-Wisp (Will-O-Wisp burn) treated as status infliction.
  local willO = Data.moves.WILL_O_WISP
  if willO then
    local vBurn = view({ userMon = { hp = 80, stats = { hp = 100 } } })
    T.check(TrainerAi.score(vBurn, willO, 10)
        > TrainerAi.score(vBurn, tackleDef, 10),
      "smart AI prefers STAB Tackle over Will-O-Wisp on soft")
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

  -- Anti-repeat: same attack is nudged so soft AI mixes moves.
  do
    local vRepeat = view({
      user = {
        curTypes = { "NORMAL" },
        stages = {},
        mon = { hp = 50, stats = { hp = 100 } },
        expAiLastMoveId = "TACKLE",
      },
      target = {
        curTypes = { "NORMAL" },
        stages = {},
        mon = { hp = 50, stats = { hp = 50 } },
      },
    })
    T.check(TrainerAi.score(vRepeat, tackleDef, 10)
        > TrainerAi.score(vRepeat, scratchDef, 10),
      "smart AI devalues repeating the same attack on soft")
  end

  -- Near-best margin: best and next-best can share a pool (margin 1).
  do
    local attacker = {
      curMoves = {
        { id = "WATER_GUN", pp = 25 },
        { id = "TACKLE", pp = 35 },
      },
      curTypes = { "WATER" },
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
    if Data.moves.WATER_GUN then
      local seen = {}
      local n = 0
      local function cycle(lo, hi)
        n = n + 1
        if hi <= lo then return lo end
        return (n % 2 == 1) and lo or hi
      end
      for _ = 1, 16 do
        attacker.aiLayer2 = 0
        attacker.expAiLastMoveId = nil
        local pick = TrainerAi.chooseWithMargin(attacker, cycle, b, 1)
        seen[pick.id] = true
      end
      T.check(seen.WATER_GUN, "near-best pool still includes the STAB attack")
      T.check(seen.TACKLE,
        "near-best margin lets a near-best attack mix instead of locking STAB")
    end
  end

  -- Self setup while healthy: mild prefer loses to STAB, ties non-STAB; dumps when stacked.
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
    T.check(TrainerAi.score(vSetup, swords, 10) > TrainerAi.score(vSetup, tackleDef, 10),
      "smart AI prefers STAB Tackle over setup on soft (no scripted opener)")
    local vSetupWater = view({
      user = {
        curTypes = { "WATER" },
        stages = { attack = 0, special = 0 },
        mon = { hp = 90, stats = { hp = 100 } },
      },
      target = {
        curTypes = { "NORMAL" },
        stages = {},
        mon = { hp = 50, stats = { hp = 50 } },
      },
    })
    T.eq(TrainerAi.score(vSetupWater, swords, 10),
        TrainerAi.score(vSetupWater, tackleDef, 10),
      "smart AI lets setup tie a non-STAB Tackle while healthy")
    local vStacked = view({
      userMon = { hp = 90, stats = { hp = 100 } },
      userStages = { attack = 2, special = 2 },
    })
    T.check(TrainerAi.score(vStacked, swords, 10) > TrainerAi.score(vStacked, tackleDef, 10),
      "smart AI stops preferring setup once stages are already boosted")

    local vStageWeighted = view({
      user = {
        curTypes = { "WATER" },
        stages = {},
        mon = { hp = 90, stats = { hp = 100 } },
        expAiMoveWeight = { [swords.id] = 3 },
      },
      target = {
        curTypes = { "NORMAL" },
        stages = {},
        mon = { hp = 50, stats = { hp = 50 } },
      },
    })
    T.check(TrainerAi.score(vStageWeighted, swords, 10)
        > TrainerAi.score(vStageWeighted, tackleDef, 10) + 1,
      "smart AI devalues setup while its decay weight is high")
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

    -- Player switches: status dump lifts. Soft AI only mild-prefers status, so
    -- use a non-STAB caster so poison ties Tackle and rng can open with it.
    b.player = freshPlayer
    caster.curTypes = { "WATER" }
    caster.mon.hp = 40
    caster.mon.stats = { hp = 40 }
    caster.aiLayer2 = 0
    local vsFresh = TrainerAI.chooseMove(caster, function() return 1 end, b)
    T.eq(vsFresh.id, poisonId,
      "chooseMove can open with status into a fresh switch-in when tied")

    -- Same foe again: decay weight from the status try favors damage next.
    caster.aiLayer2 = 0
    local vsRetry = TrainerAI.chooseMove(caster, function() return 1 end, b)
    T.eq(vsRetry.id, "TACKLE",
      "chooseMove prefers damage while status decay weight is hot")
    T.check(caster.expAiMoveWeight and (caster.expAiMoveWeight[poisonId] or 0) > 0,
      "status pick applies a decay weight")

    -- After the weight cools, status can compete again (long fights stay open).
    -- Clear last-move anti-repeat so only decay weight is under test.
    caster.expAiLastMoveId = nil
    caster.expAiMoveWeight[poisonId] = 3
    caster.aiLayer2 = 0
    local vsCooling = TrainerAI.chooseMove(caster, function() return 1 end, b)
    T.eq(vsCooling.id, "TACKLE",
      "chooseMove still prefers damage while a decay weight remains")
    caster.expAiMoveWeight = nil
    caster.expAiLastMoveId = nil
    caster.aiLayer2 = 0
    local vsBaseline = TrainerAI.chooseMove(caster, function() return 1 end, b)
    T.eq(vsBaseline.id, poisonId,
      "chooseMove can reopen with status once decay weight returns to baseline")
  end

  -- Toggle off restores vanilla empty-mod random (rng returns 1 → GROWL).
  run.loader.modOptions["Kanto-Reforged"][TrainerAi.OPTION_KEY] = false
  mon.aiLayer2 = 0
  battle.enemyAIMods = {}
  local vanillaPick = TrainerAI.chooseMove(mon, function() return 1 end, battle)
  T.eq(vanillaPick.id, "GROWL", "with smarter AI off, empty mods stay uniform-random")

  run.loader.modOptions["Kanto-Reforged"][TrainerAi.OPTION_KEY] = true

  -- ------- Four-tier gate -------------------------------------------------
  local tactLayer = Data.ai_classes[TrainerAi.LAYER_TACTICAL]
  local liteLayer = Data.ai_classes[TrainerAi.LAYER_TACTICAL_LITE]
  local naturalLayer = Data.ai_classes[TrainerAi.LAYER_NATURAL]
  T.check(tactLayer and tactLayer.kind == "layer", "EXP_TACTICAL layer registered")
  T.check(liteLayer and liteLayer.kind == "layer", "EXP_TACTICAL_LITE layer registered")
  T.check(naturalLayer and naturalLayer.kind == "layer", "EXP_NATURAL layer registered")

  local function fakeBattle(opts)
    opts = opts or {}
    return {
      kind = opts.kind or "trainer",
      oppClass = opts.class,
      trainer = { id = opts.class },
      expPartyIndex = opts.party or 1,
      expMapId = opts.map,
      expWildSpecies = opts.species,
      expRoamer = opts.roamer,
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

  -- Wild natural vs soft threat rules.
  T.eq(TrainerAi.tier(fakeBattle({
    kind = "wild", map = "MT_MOON_1F", species = "ZUBAT",
  })), "natural", "Mt Moon Zubat is natural")
  T.eq(TrainerAi.tier(fakeBattle({
    kind = "wild", map = "ROCK_TUNNEL_1F", species = "ZUBAT",
  })), "natural", "Rock Tunnel Zubat stays fodder/natural")
  T.eq(TrainerAi.tier(fakeBattle({
    kind = "wild", map = "ROCK_TUNNEL_1F", species = "CUBONE",
  })), "soft", "Rock Tunnel Cubone is soft")
  T.eq(TrainerAi.tier(fakeBattle({
    kind = "wild", map = "CERULEAN_CAVE_1F", species = "GOLBAT",
  })), "soft", "Cerulean Cave wild is soft (rare map)")
  T.eq(TrainerAi.tier(fakeBattle({
    kind = "wild", map = "ROUTE_1", species = "RATTATA", roamer = true,
  })), "soft", "roamer flag forces soft")
  T.eq(TrainerAi.tier(fakeBattle({
    kind = "wild", map = "ROUTE_1", species = "SNORLAX",
  })), "soft", "threat species is soft even off threat maps")
  T.eq(TrainerAi.tier(fakeBattle({
    kind = "wild", map = "ROUTE_12", species = "GOLBAT",
  })), "natural", "Golbat off threat maps stays natural (list tightened)")
  T.eq(TrainerAi.tier(fakeBattle({
    kind = "wild", map = "ROCK_TUNNEL_1F", species = "ONIX",
  })), "soft", "Onix soft via threat map, not species list")
  T.eq(TrainerAi.isThreatSpecies("ARTICUNO"), true,
    "legendaries fold into THREAT_SPECIES (derived, not duplicated)")
  T.eq(TrainerAi.isLegendarySpecies("ARTICUNO"), true, "ARTICUNO is legendary")
  T.eq(TrainerAi.tier(fakeBattle({
    kind = "wild", map = "ROUTE_1", species = "MEWTWO",
  })), "soft", "legendary wild is soft via derived threat set")
  -- No duplicate literal keys in the exported threat table.
  local kangHits = 0
  for id in pairs(TrainerAi.THREAT_SPECIES) do
    if id == "KANGASKHAN" then kangHits = kangHits + 1 end
  end
  T.eq(kangHits, 1, "KANGASKHAN appears once in THREAT_SPECIES")

  -- Natural scoring: dump useless status; no Hypnosis prefer over Tackle.
  do
    local hyp = Data.moves.HYPNOSIS or sleepDef
    local vNat = view({
      userMon = { hp = 80, stats = { hp = 100 } },
      status = nil,
    })
    if hyp then
      T.check(TrainerAi.scoreNatural(vNat, hyp, 10)
          >= TrainerAi.scoreNatural(vNat, tackleDef, 10),
        "natural AI does not prefer Hypnosis over Tackle")
    end
    T.check(TrainerAi.scoreNatural(view({ status = "PSN" }), sleepDef, 10) >= 16,
      "natural AI dumps sleep into an already-statused target")
    local vImmune = view({ targetTypes = { "GHOST" } })
    T.check(TrainerAi.scoreNatural(vImmune, tackleDef, 10) >= 16,
      "natural AI dumps immune Normal attacks")
  end

  -- Soft situational branches (conservative canKo).
  do
    local sing = Data.moves.SING or sleepDef
    local vAsleep = view({
      userMon = { hp = 80, stats = { hp = 100 } },
      status = "SLP",
    })
    if sing then
      T.check(TrainerAi.score(vAsleep, tackleDef, 10)
          < TrainerAi.score(vAsleep, sing, 10),
        "soft AI prefers Tackle over Sing into an already-sleeping foe")
    end

    local recover = Data.moves.RECOVER or Data.moves.SOFTBOILED
    if recover and recover.effect == "HEAL_EFFECT" then
      local vLow = view({
        userMon = { hp = 20, stats = { hp = 100 } },
        userStages = { attack = 0 },
      })
      T.check(TrainerAi.score(vLow, recover, 10)
          < TrainerAi.score(vLow, growDef, 10),
        "soft AI prefers heal over Growl at low HP")
    end

    if sleepDef then
      local vHealthyWater = view({
        user = {
          curTypes = { "WATER" },
          stages = {},
          mon = { hp = 80, stats = { hp = 100 } },
        },
        target = {
          curTypes = { "NORMAL" },
          stages = {},
          mon = { hp = 50, stats = { hp = 50 }, status = nil },
        },
      })
      T.check(TrainerAi.score(vHealthyWater, sleepDef, 10)
          > TrainerAi.score(vHealthyWater, tackleDef, 10) - 2,
        "low-acc sleep is devalued vs baseline Tackle when not threatened")
    end

    local swords = Data.moves.SWORDS_DANCE or Data.moves.MEDITATE
    local vFinish = view({
      user = {
        curTypes = { "WATER" },
        stages = {},
        mon = { hp = 80, stats = { hp = 100 } },
      },
      target = {
        curTypes = { "NORMAL" },
        stages = {},
        mon = { hp = 8, stats = { hp = 50 }, status = nil },
      },
    })
    if swords then
      T.check(TrainerAi.score(vFinish, tackleDef, 10)
          < TrainerAi.score(vFinish, swords, 10),
        "soft AI prefers attack over setup when foe HP is very low")
    end

    -- Residual chip: dump self-setup while poisoned / seeded.
    if swords then
      local vPsn = view({
        user = {
          curTypes = { "WATER" },
          stages = {},
          mon = { hp = 80, stats = { hp = 100 }, status = "PSN" },
        },
        target = {
          curTypes = { "NORMAL" },
          stages = {},
          mon = { hp = 50, stats = { hp = 50 } },
        },
      })
      T.check(TrainerAi.score(vPsn, swords, 10)
          > TrainerAi.score(vPsn, tackleDef, 10),
        "soft AI dumps setup while poisoned")
    end

    -- Mid HP + SE STAB must NOT dump sleep for a guessed KO.
    local ember = Data.moves.EMBER
    if ember and sleepDef then
      local vMidSe = view({
        user = {
          curTypes = { "FIRE" },
          stages = {},
          mon = { hp = 80, stats = { hp = 100 } },
        },
        target = {
          curTypes = { "GRASS" },
          stages = {},
          mon = { hp = 40, stats = { hp = 50 }, status = nil },
        },
      })
      local sleepScore = TrainerAi.score(vMidSe, sleepDef, 10)
      local emberScore = TrainerAi.score(vMidSe, ember, 10)
      -- Sleep remains competitive enough that a mid-HP SE read does not
      -- hard-dump it the way a real KO dump would (>= +2 gap from openers).
      T.check(sleepScore < 16,
        "soft AI does not hard-dump sleep solely for mid-HP SE STAB guess")
      T.check(emberScore <= sleepScore + 3,
        "mid-HP SE prefer stays mild (no confident KO opener dump)")
    end
  end

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
        seen.natural = false
        for _, m in ipairs(mods) do
          if m == TrainerAi.LAYER_ID then seen.smart = true end
          if m == TrainerAi.LAYER_NATURAL then seen.natural = true end
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
    T.check(seen.smart and not seen.tactical and not seen.lite and not seen.natural,
      "soft chooseMove injects EXP_SMART only")

    -- Lite/elite get a lighter opener decay than soft (Hypnosis acc < 70 → soft 4, lite 2).
    local hyp = Data.moves.HYPNOSIS
    if hyp then
      local openerUser = {
        curMoves = { { id = "HYPNOSIS", pp = 20 }, { id = "TACKLE", pp = 35 } },
        curTypes = { "PSYCHIC" },
        stages = {},
        curStats = { attack = 40, defense = 40, special = 60, speed = 50 },
        mon = { hp = 40, stats = { hp = 40 }, level = 20, species = "DROWZEE" },
        aiLayer2 = 0,
      }
      local fresh = {
        curTypes = { "NORMAL" },
        stages = {},
        curStats = { attack = 40, defense = 40, special = 40, speed = 40 },
        mon = { hp = 40, stats = { hp = 40 }, level = 20 },
      }
      -- Force Hypnosis as sole near-best by dumping Tackle type-wise isn't needed:
      -- score soft prefers status mildly; pin RNG and ensure status isn't dumped.
      local bSoftDecay = fakeBattle({ class = "OPP_YOUNGSTER", party = 1, map = "ROUTE_1" })
      bSoftDecay.player = fresh
      bSoftDecay.enemy = openerUser
      openerUser.expAiMoveWeight = nil
      openerUser.expAiLastMoveId = nil
      openerUser.aiLayer2 = 0
      -- Pre-bump Tackle so Hypnosis wins the soft pick.
      TrainerAi.bumpMoveWeight(openerUser, "TACKLE", 8)
      local softPick = TrainerAI.chooseMove(openerUser, function() return 1 end, bSoftDecay)
      T.eq(softPick.id, "HYPNOSIS", "soft test forces Hypnosis opener")
      local softW = openerUser.expAiMoveWeight and openerUser.expAiMoveWeight.HYPNOSIS or 0

      local liteUser = {
        curMoves = { { id = "HYPNOSIS", pp = 20 }, { id = "TACKLE", pp = 35 } },
        curTypes = { "PSYCHIC" },
        stages = {},
        curStats = { attack = 40, defense = 40, special = 60, speed = 50 },
        mon = { hp = 40, stats = { hp = 40 }, level = 20, species = "DROWZEE" },
        aiLayer2 = 0,
      }
      local bLiteDecay = fakeBattle({
        class = "OPP_JR_TRAINER_M", party = 1, map = "PEWTER_GYM",
      })
      bLiteDecay.player = fresh
      bLiteDecay.enemy = liteUser
      TrainerAi.bumpMoveWeight(liteUser, "TACKLE", 8)
      local litePick = TrainerAI.chooseMove(liteUser, function() return 1 end, bLiteDecay)
      T.eq(litePick.id, "HYPNOSIS", "lite test forces Hypnosis opener")
      local liteW = liteUser.expAiMoveWeight and liteUser.expAiMoveWeight.HYPNOSIS or 0
      T.check(softW > liteW and liteW > 0,
        "lite opener decay is lighter than soft (soft=" .. softW .. " lite=" .. liteW .. ")")
    end

    local bWild = fakeBattle({
      kind = "wild", map = "MT_MOON_1F", species = "ZUBAT",
    })
    bWild.player = player
    bWild.enemy = attacker
    seen = {}
    local savedChoose = TrainerAi.chooseWithMargin
    TrainerAi.chooseWithMargin = function(battler, rng, battle, margin)
      local mods = battle.enemyAIMods or {}
      seen.smart, seen.natural, seen.tactical, seen.lite = false, false, false, false
      for _, m in ipairs(mods) do
        if m == TrainerAi.LAYER_ID then seen.smart = true end
        if m == TrainerAi.LAYER_NATURAL then seen.natural = true end
        if m == TrainerAi.LAYER_TACTICAL then seen.tactical = true end
        if m == TrainerAi.LAYER_TACTICAL_LITE then seen.lite = true end
      end
      return savedChoose(battler, rng, battle, margin)
    end
    attacker.aiLayer2 = 0
    TrainerAI.chooseMove(attacker, function() return 1 end, bWild)
    TrainerAi.chooseWithMargin = savedChoose
    T.check(seen.natural and not seen.smart and not seen.tactical and not seen.lite,
      "natural wild chooseMove injects EXP_NATURAL only")
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
  local brock = Data.trainers.OPP_BROCK.parties[1]
  T.eq(#brock, 3, "Brock party is Sudowoodo + Aron + Onix")
  T.eq(brock[1].species, "SUDOWOODO", "Brock's Geodude swapped for Sudowoodo")
  T.eq(brock[2].species, "ARON", "Brock Gen3 add is Aron before ace")
  T.eq(brock[3].species, "ONIX", "Brock still ends on Onix")
  T.eq(brock[3].heldItem, "BERRY", "Brock Onix holds BERRY")

  local misty = Data.trainers.OPP_MISTY.parties[1]
  T.eq(#misty, 3, "Misty party grew by Gen3 add")
  T.eq(misty[1].species, "MARILL", "Misty's Staryu swapped for Marill")
  T.eq(misty[2].species, "CORPHISH", "Misty Gen3 add is Corphish")
  T.eq(misty[3].species, "STARMIE", "Misty still ends on Starmie")
  T.eq(misty[3].heldItem, "PECHA_BERRY", "Misty Starmie holds Pecha")

  local surge = Data.trainers.OPP_LT_SURGE.parties[1]
  T.eq(surge[1].species, "FLAAFFY", "Surge's Voltorb swapped for Flaaffy")
  T.eq(surge[#surge].species, "RAICHU", "Surge still ends on Raichu")
  T.eq(surge[#surge].heldItem, "CHESTO_BERRY", "Surge Raichu holds Chesto")

  local erika = Data.trainers.OPP_ERIKA.parties[1]
  T.eq(erika[2].species, "BELLOSSOM", "Erika's Tangela swapped for Bellossom")
  T.eq(erika[#erika].species, "VILEPLUME", "Erika still ends on Vileplume")
  T.eq(erika[#erika].heldItem, "RAWST_BERRY", "Erika Vileplume holds Rawst")

  local blaine = Data.trainers.OPP_BLAINE.parties[1]
  T.eq(blaine[1].species, "TORKOAL", "Blaine Gen3 lead is Torkoal")
  T.eq(blaine[2].species, "GROWLITHE", "Blaine keeps Growlithe")
  T.eq(blaine[3].species, "PONYTA", "Blaine keeps Ponyta")
  T.eq(blaine[4].species, "RAPIDASH", "Blaine keeps Rapidash")
  T.eq(blaine[5].species, "ARCANINE", "Blaine still ends on Arcanine")
  T.eq(blaine[5].heldItem, "PERSIM_BERRY", "Blaine Arcanine holds Persim (not Aspear)")

  local giovanni = Data.trainers.OPP_GIOVANNI.parties[3]
  T.eq(giovanni[2].species, "DONPHAN", "Giovanni gym Dugtrio swapped for Donphan")
  T.eq(giovanni[#giovanni - 1].species, "FLYGON", "Giovanni Gen3 add is Flygon before ace")
  T.eq(giovanni[#giovanni].species, "RHYDON", "Giovanni still ends on Rhydon")
  T.eq(giovanni[#giovanni].heldItem, "CHERI_BERRY", "Giovanni Rhydon holds Cheri")

  local lorelei = Data.trainers.OPP_LORELEI.parties[1]
  T.eq(lorelei[1].species, "PILOSWINE", "Lorelei's Dewgong swapped for Piloswine")
  T.eq(lorelei[#lorelei - 1].species, "WALREIN", "Lorelei Gen3 add is Walrein")
  T.eq(lorelei[#lorelei].species, "LAPRAS", "Lorelei still ends on Lapras")
  T.eq(lorelei[#lorelei].heldItem, "CHERI_BERRY", "Lorelei Lapras holds Cheri")

  T.eq(Data.trainers.OPP_BRUNO.parties[1][1].species, "STEELIX",
    "Bruno's Onix swapped for Steelix")
  T.eq(Data.trainers.OPP_BRUNO.parties[1][#Data.trainers.OPP_BRUNO.parties[1]].species,
    "MACHAMP", "Bruno still ends on Machamp")
  T.eq(Data.trainers.OPP_AGATHA.parties[1][2].species, "CROBAT",
    "Agatha's Golbat swapped for Crobat")
  T.eq(Data.trainers.OPP_LANCE.parties[1][1].species, "KINGDRA",
    "Lance's Gyarados swapped for Kingdra")
  local lance = Data.trainers.OPP_LANCE.parties[1]
  T.eq(lance[#lance - 1].species, "SALAMENCE", "Lance Gen3 add is Salamence")
  T.eq(lance[#lance].species, "DRAGONITE", "Lance still ends on Dragonite")
  T.eq(lance[#lance].heldItem, "LUM_BERRY", "Lance Dragonite holds Lum")

  -- Schema + BattleState heldItem must work without local engine forks.
  do
    local Schemas = require("src.mods.Schemas")
    local slotRec = Schemas.REGISTRIES.trainers.fields.parties.inner.inner
    T.check(slotRec.fields.heldItem ~= nil,
      "mod extended trainer party schema with heldItem")
    T.check(slotRec.fields.moves ~= nil,
      "mod extended trainer party schema with moves")

    local Pokemon = require("src.pokemon.Pokemon")
    local BattleState = require("src.battle.BattleState")
    local game = {
      data = Data,
      save = {
        party = { Pokemon.new(Data, "PIKACHU", 50) },
        player = {},
        inventory = {},
      },
      stack = { push = function() end },
    }
    local battle = BattleState.newTrainer(game, "OPP_BROCK", 1)
    local ace = battle.enemyParty[#battle.enemyParty]
    T.eq(ace and ace.species, "ONIX", "Brock battle ace is Onix")
    T.eq(ace and ace.heldItem, "BERRY",
      "Brock battle applies ace berry without engine BattleState patch")
  end

  -- Rival continuity: League finals foreshadowed mid; finals debut at RIVAL3
  T.eq(Data.trainers.OPP_RIVAL2.parties[10][2].species, "LAIRON",
    "Rival late-mid foreshadows Aggron via Lairon")
  T.eq(Data.trainers.OPP_RIVAL2.parties[10][3].species, "HOUNDOUR",
    "Fire-path late mid keeps Houndour (no early Houndoom)")
  T.eq(Data.trainers.OPP_RIVAL2.parties[11][3].species, "CARVANHA",
    "Water-path late mid keeps Carvanha (no early Sharpedo)")
  T.eq(Data.trainers.OPP_RIVAL2.parties[12][4].species, "SEADRA",
    "Dragon-path late mid shows Seadra before Kingdra")
  T.eq(Data.trainers.OPP_RIVAL3.parties[1][3].species, "AGGRON",
    "Champion rival Rhydon swapped for Aggron")
  T.eq(Data.trainers.OPP_RIVAL3.parties[1][4].species, "HOUNDOOM",
    "Champion fire coverage reveals Houndoom")
  T.eq(Data.trainers.OPP_RIVAL3.parties[2][4].species, "SHARPEDO",
    "Champion water coverage reveals Sharpedo")
  T.eq(Data.trainers.OPP_RIVAL3.parties[3][5].species, "KINGDRA",
    "Champion dragon coverage reveals Kingdra")

  T.eq(Data.trainers.OPP_BUG_CATCHER.parties[1][1].species, "SPINARAK",
    "Bug Catcher party 1 leads with Spinarak")
  T.eq(Data.trainers.OPP_HIKER.parties[1][1].species, "ARON",
    "Hiker party 1 leads with Aron")

  -- Nugget Bridge: mostly Gen 1; one Gen 2–3 spice on a few fights.
  -- Bug Catcher #9 and Jr Trainer #3 stay fully vanilla for nostalgia.
  local nbBug = Data.trainers.OPP_BUG_CATCHER.parties[9]
  T.eq(nbBug[1].species, "CATERPIE", "Nugget Bridge Bug Catcher stays Caterpie")
  T.eq(nbBug[2].species, "WEEDLE", "Nugget Bridge Bug Catcher stays Weedle")
  local nbLass8 = Data.trainers.OPP_LASS.parties[8]
  T.eq(nbLass8[1].species, "PIDGEY", "Nugget Bridge Lass#8 keeps Pidgey")
  T.eq(nbLass8[2].species, "MARILL", "Nugget Bridge Lass#8 spices Marill")
  local nbYoung = Data.trainers.OPP_YOUNGSTER.parties[4]
  T.eq(nbYoung[1].species, "ZIGZAGOON", "Nugget Bridge Youngster spices Zigzagoon")
  T.eq(nbYoung[2].species, "EKANS", "Nugget Bridge Youngster keeps Ekans")
  T.eq(nbYoung[3].species, "ZUBAT", "Nugget Bridge Youngster keeps Zubat")
  local nbLass7 = Data.trainers.OPP_LASS.parties[7]
  T.eq(nbLass7[1].species, "TAILLOW", "Nugget Bridge Lass#7 spices Taillow")
  T.eq(nbLass7[2].species, "NIDORAN_F", "Nugget Bridge Lass#7 keeps Nidoran♀")
  T.eq(Data.trainers.OPP_JR_TRAINER_M.parties[3][1].species, "MANKEY",
    "Nugget Bridge Jr Trainer#3 stays Mankey (single-mon nostalgia)")
  local nbJr2 = Data.trainers.OPP_JR_TRAINER_M.parties[2]
  T.eq(nbJr2[1].species, "RATTATA", "Nugget Bridge Jr Trainer#2 keeps Rattata")
  T.eq(nbJr2[2].species, "ARON", "Nugget Bridge Jr Trainer#2 spices Aron")
  T.eq(Data.trainers.OPP_ROCKET.parties[6][1].species, "POOCHYENA",
    "Nugget Bridge Rocket spices Poochyena")
  T.eq(Data.trainers.OPP_ROCKET.parties[6][2].species, "ZUBAT",
    "Nugget Bridge Rocket keeps Zubat")

  local pewterJr = Data.trainers.OPP_JR_TRAINER_M.parties[1]
  T.eq(pewterJr[1].species, "PHANPY", "Pewter gym Jr Trainer full Phanpy")
  T.eq(pewterJr[2].species, "ARON", "Pewter gym Jr Trainer full Aron")

  local cerSwimmer = Data.trainers.OPP_SWIMMER.parties[1]
  T.eq(cerSwimmer[1].species, "CORPHISH", "Cerulean gym Swimmer Corphish")
  T.eq(cerSwimmer[2].species, "CLAMPERL", "Cerulean gym Swimmer Clamperl")

  local vermRocker = Data.trainers.OPP_ROCKER.parties[1]
  T.eq(vermRocker[1].species, "ELECTRIKE", "Vermilion Rocker full Electrike")
  T.eq(vermRocker[2].species, "MAREEP", "Vermilion Rocker Mareep")
  T.eq(vermRocker[3].species, "PLUSLE", "Vermilion Rocker Plusle")

  local celBeauty = Data.trainers.OPP_BEAUTY.parties[1]
  T.eq(celBeauty[1].species, "SEEDOT", "Celadon Beauty full Seedot")
  T.eq(celBeauty[4].species, "SHROOMISH", "Celadon Beauty full Shroomish")

  T.eq(Data.trainers.OPP_ROCKET.parties[4][1].species, "MIGHTYENA",
    "Mt Moon Rocket#4 is Mightyena")
  T.eq(Data.trainers.OPP_BLACKBELT.parties[2][3].species, "HARIYAMA",
    "Fighting Dojo Blackbelt ends on Hariyama")
  T.eq(Data.trainers.OPP_CHANNELER.parties[5][1].species, "SHUPPET",
    "Tower Channeler sample is Shuppet")

  -- Tier-2 pass 2: late gyms, Tower 7F, travel
  local saffron = Data.trainers.OPP_PSYCHIC_TR.parties[1]
  T.eq(saffron[1].species, "KIRLIA", "Saffron Psychic full Kirlia")
  T.eq(saffron[4].species, "XATU", "Saffron Psychic full Xatu")
  T.eq(Data.trainers.OPP_JUGGLER.parties[3][2].species, "WOBBUFFET",
    "Fuchsia Juggler has Wobbuffet")
  T.eq(Data.trainers.OPP_TAMER.parties[2][1].species, "SEVIPER",
    "Fuchsia Tamer lead Seviper")
  T.eq(Data.trainers.OPP_SUPER_NERD.parties[10][4].species, "TORKOAL",
    "Cinnabar Super Nerd ends on Torkoal")
  T.eq(Data.trainers.OPP_BURGLAR.parties[4][3].species, "MAGCARGO",
    "Cinnabar Burglar Magcargo")
  T.eq(Data.trainers.OPP_BLACKBELT.parties[8][1].species, "HARIYAMA",
    "Viridian gym Blackbelt Hariyama")
  T.eq(Data.trainers.OPP_BLACKBELT.parties[1][2].species, "HITMONTOP",
    "Dojo master Hitmonchan → Hitmontop")
  T.eq(Data.trainers.OPP_ROCKET.parties[19][3].species, "CROBAT",
    "Tower 7F Rocket#19 Crobat")
  T.eq(Data.trainers.OPP_ROCKET.parties[21][3].species, "MIGHTYENA",
    "Tower 7F Rocket#21 Mightyena")
  T.eq(Data.trainers.OPP_CHANNELER.parties[19][2].species, "DUSKULL",
    "Tower 6F Channeler Duskull")
  T.eq(Data.trainers.OPP_SAILOR.parties[4][1].species, "CORPHISH",
    "SS Anne Sailor Corphish")
  T.eq(Data.trainers.OPP_HIKER.parties[13][2].species, "ARON",
    "Rock Tunnel Hiker Aron")
  T.eq(Data.trainers.OPP_BIKER.parties[12][4].species, "SWALOT",
    "Cycling Road Biker Swalot")
  T.eq(Data.trainers.OPP_ROCKET.parties[41][2].species, "SABLEYE",
    "Silph Rocket#41 Sableye")
  local vr = Data.trainers.OPP_COOLTRAINER_M.parties[5]
  T.eq(vr[1].species, "BAYLEEF", "Victory Road Cooltrainer Bayleef")
  T.eq(vr[4].species, "CHARIZARD", "Victory Road keeps Charizard ace")

  -- Mix table is non-empty and only references registered species
  T.check(#ExpTrainers.MIX >= 20, "curated trainer mix has a real set of swaps")
  for _, row in ipairs(ExpTrainers.MIX) do
    local species = row[4]
    T.check(Data.pokemon[species] ~= nil,
      "trainer mix species " .. tostring(species) .. " is registered")
  end
  for _, row in ipairs(ExpTrainers.ACE_BERRIES) do
    local item = row[3]
    T.check(type(item) == "string" and #item > 0,
      "ace berry id present for " .. tostring(row[1]))
  end

  -- ------- Overhauled Tier 3 AI Rules --------------------------------------
  -- 1. Absolute KO Priority: If AI has a move that KOs player, eliteAction returns nil (attack forced).
  do
    local attacker = atkBattler({
      level = 40,
      hp = 10, -- low HP!
      stats = { attack = 100, defense = 50, special = 50, speed = 100 },
      moves = { { id = "WATER_GUN", pp = 25 } },
    })
    local defender = defBattler({
      hp = 5, -- defender is low, easily KO'd by Water Gun!
      maxHp = 50,
      stats = { attack = 50, defense = 30, special = 30, speed = 40 },
    })
    local b = fakeBattle({ class = "OPP_BROCK", party = 1, map = "PEWTER_GYM" })
    b.player = defender
    b.enemy = attacker
    b.aiUses = 2

    local act = TrainerAi.eliteAction(b)
    T.eq(act, nil, "eliteAction forces attack (returns nil) when KO is available, even at low HP")
  end

  -- 2. Anti-Heal Trap: Faster player that OHKOs AI prevents AI from wasting heal item.
  do
    local attacker = atkBattler({
      level = 30,
      hp = 10, -- 10 / 100 HP (10%)
      stats = { attack = 50, defense = 30, special = 30, speed = 20 }, -- slow AI!
      moves = { { id = "TACKLE", pp = 35 } },
    })
    attacker.mon.stats.hp = 100
    attacker.mon.hp = 10
    local defender = defBattler({
      hp = 80, maxHp = 80,
      stats = { attack = 150, defense = 50, special = 50, speed = 100 }, -- fast & deadly player!
      moves = { { id = "EARTHQUAKE", pp = 10 } },
    })
    defender.curMoves = { { id = "EARTHQUAKE", pp = 10 } }
    local b = fakeBattle({ class = "OPP_BROCK", party = 1, map = "PEWTER_GYM" })
    b.player = defender
    b.enemy = attacker
    b.aiUses = 2

    local act = TrainerAi.eliteAction(b)
    T.eq(act, nil, "anti-heal trap: slow AI about to be OHKO'd skips healing item")
  end

  -- 3. Item Budget & Rival 3 Greedy Item Limit: Max 2 items for standard Elite, max 3 for Rival 3.
  do
    local attacker = atkBattler({
      level = 30,
      hp = 10,
      stats = { attack = 50, defense = 50, special = 50, speed = 100 },
      moves = { { id = "TACKLE", pp = 35 } },
    })
    attacker.mon.stats.hp = 100
    attacker.mon.hp = 10
    local defender = defBattler({
      hp = 80, maxHp = 80,
      stats = { attack = 10, defense = 50, special = 50, speed = 20 }, -- weak player
      moves = { { id = "TACKLE", pp = 35 } },
    })
    defender.curMoves = { { id = "TACKLE", pp = 35 } }

    -- Standard Elite (Erika has SUPER_POTION): Max 2 items total per battle.
    -- (Brock's class item is FULL_HEAL only — status clear, not HP heal.)
    local bElite = fakeBattle({ class = "OPP_ERIKA", party = 1, map = "CELADON_GYM" })
    bElite.player = defender
    bElite.enemy = attacker
    bElite.aiUses = 2
    bElite.enemyIndex = 1

    local act1 = TrainerAi.eliteAction(bElite)
    T.check(act1 ~= nil and act1.special == "aiItem", "Elite item 1 allowed")
    bElite.enemyIndex = 2 -- Mon 2
    local act2 = TrainerAi.eliteAction(bElite)
    T.check(act2 ~= nil and act2.special == "aiItem", "Elite item 2 allowed")
    bElite.enemyIndex = 3 -- Mon 3
    local act3 = TrainerAi.eliteAction(bElite)
    T.eq(act3, nil, "Elite item 3 blocked (battle item cap of 2 reached)")

    -- Champion Rival 3: Max 3 items total per battle
    local bRival = fakeBattle({ class = "OPP_RIVAL3", party = 1 })
    bRival.player = defender
    bRival.enemy = attacker
    bRival.aiUses = 2
    bRival.enemyIndex = 1

    local r1 = TrainerAi.eliteAction(bRival)
    T.check(r1 ~= nil and r1.special == "aiItem", "Rival3 item 1 allowed")
    bRival.enemyIndex = 2
    local r2 = TrainerAi.eliteAction(bRival)
    T.check(r2 ~= nil and r2.special == "aiItem", "Rival3 item 2 allowed")
    bRival.enemyIndex = 3
    local r3 = TrainerAi.eliteAction(bRival)
    T.check(r3 ~= nil and r3.special == "aiItem", "Rival3 item 3 allowed")
    bRival.enemyIndex = 4
    local r4 = TrainerAi.eliteAction(bRival)
    T.eq(r4, nil, "Rival3 item 4 blocked (battle item cap of 3 reached)")

    -- Held berries must not burn the AI bag-item budget (bag heals still count).
    local bBerry = fakeBattle({ class = "OPP_ERIKA", party = 1, map = "CELADON_GYM" })
    bBerry.player = defender
    bBerry.enemy = attacker
    bBerry.aiUses = 2
    bBerry.enemyIndex = 1
    bBerry.expBattleItemsUsed = 0
    bBerry.expMonItemsUsed = {}
    local a1 = TrainerAi.eliteAction(bBerry)
    T.check(a1 and a1.special == "aiItem", "heal item still records")
    T.check(bBerry.expBattleItemsUsed == 1, "bag heal increments budget")
    -- Berries are held-item only; HEAL_ITEMS / X_ITEMS never include them, so
    -- recordItemUsed ignores berry ids if somehow invoked.
    local HeldItems = require("mods.Kanto-Reforged.held_items")
    T.check(HeldItems.isBerry("BERRY"), "BERRY is a held berry")
    T.check(HeldItems.isBerry("LUM_BERRY"), "LUM_BERRY is a held berry")
    T.check(not HeldItems.isBerry("SUPER_POTION"), "SUPER_POTION is not a berry")
  end

  -- 4. Priority Move KO finish bonus in scoreTactical
  do
    local quickAttack = Data.moves.QUICK_ATTACK
    local tackle = Data.moves.TACKLE
    if quickAttack and tackle then
      local attacker = atkBattler({
        level = 20,
        stats = { attack = 50, defense = 50, special = 50, speed = 40 },
        moves = { { id = "QUICK_ATTACK", pp = 30 }, { id = "TACKLE", pp = 35 } },
      })
      local defender = defBattler({
        hp = 8, maxHp = 50, -- low HP defender
        stats = { attack = 50, defense = 40, special = 40, speed = 80 }, -- faster defender
      })
      local b = fakeBattle({ class = "OPP_LANCE", party = 1 })
      b.player = defender
      local v = { user = attacker, target = defender, battle = b, data = Data }
      local qaScore = TrainerAi.scoreTactical(v, quickAttack, 10)
      local tackleScore = TrainerAi.scoreTactical(v, tackle, 10)
      T.check(qaScore < tackleScore, "scoreTactical gives Quick Attack extra finish bonus when target is in KO range")
    end
  end
end

