-- Kanto Reforged trainer AI: three tiers.
--   soft  — EXP_SMART (trash / wild): dump no-ops, soft STAB/SE, situational
--           status/setup/heal. Better than Gen 1 random, still loose.
--   lite  — EXP_SMART + EXP_TACTICAL_LITE: mid-roll damage sense, mild KO bias,
--           emergency heals. Gym trainers + serious midgame classes.
--   elite — EXP_SMART + EXP_TACTICAL + themes + matchup switches / smarter
--           items. Leaders, E4, Champ, curated story bosses.
--
-- Tier gate order is mandatory: elite roster BEFORE gym-map / serious-class
-- lite, so a leader on a gym map never silently downgrades to lite.

local TypeChart = require("src.battle.TypeChart")
local Damage = require("src.battle.Damage")
local TrainerAI = require("src.battle.TrainerAI")

local TrainerAi = {}

TrainerAi.LAYER_ID = "EXP_SMART"
TrainerAi.LAYER_TACTICAL = "EXP_TACTICAL"
TrainerAi.LAYER_TACTICAL_LITE = "EXP_TACTICAL_LITE"
TrainerAi.OPTION_KEY = "smarter_ai"
TrainerAi.OPTION = {
  key = TrainerAi.OPTION_KEY,
  label = "SMARTER AI",
  type = "toggle",
  default = true,
}

function TrainerAi.enabled(mod)
  return mod and mod.options and mod.options:get(TrainerAi.OPTION_KEY) and true or false
end

-- ------- Tier rosters -------------------------------------------------------

-- Classes where every party index is elite (rivals).
local ELITE_ALL_PARTIES = {
  OPP_RIVAL1 = true,
  OPP_RIVAL2 = true,
  OPP_RIVAL3 = true,
}

-- Exact party indexes for elite story/boss fights.
-- Rockets: Mt Moon #1-4 and Nugget Bridge #6 only (#5 → lite via serious class).
local ELITE_PARTIES = {
  OPP_BROCK = { [1] = true },
  OPP_MISTY = { [1] = true },
  OPP_LT_SURGE = { [1] = true },
  OPP_ERIKA = { [1] = true },
  OPP_KOGA = { [1] = true },
  OPP_SABRINA = { [1] = true },
  OPP_BLAINE = { [1] = true },
  OPP_GIOVANNI = { [1] = true, [2] = true, [3] = true },
  OPP_LORELEI = { [1] = true },
  OPP_BRUNO = { [1] = true },
  OPP_AGATHA = { [1] = true },
  OPP_LANCE = { [1] = true },
  OPP_ROCKET = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true },
}

local GYM_MAPS = {
  PEWTER_GYM = true,
  CERULEAN_GYM = true,
  VERMILION_GYM = true,
  CELADON_GYM = true,
  FUCHSIA_GYM = true,
  SAFFRON_GYM = true,
  CINNABAR_GYM = true,
  VIRIDIAN_GYM = true,
  FIGHTING_DOJO = true,
}

local LITE_CLASSES = {
  OPP_COOLTRAINER_M = true,
  OPP_COOLTRAINER_F = true,
  OPP_BLACKBELT = true,
  OPP_PSYCHIC = true,
  OPP_JUGGLER = true,
  OPP_SCIENTIST = true,
  OPP_TAMER = true,
  OPP_ROCKET = true,
  OPP_CHANNELER = true,
}

TrainerAi.GYM_MAPS = GYM_MAPS
TrainerAi.LITE_CLASSES = LITE_CLASSES
TrainerAi.ELITE_PARTIES = ELITE_PARTIES
TrainerAi.ELITE_ALL_PARTIES = ELITE_ALL_PARTIES

-- Light personality biases (elite only). Score deltas: lower = prefer.
local THEMES = {
  OPP_BROCK = {
    preferSetup = 1, preferDefense = 1, preferScreens = 1, fullHealUrgency = true,
  },
  OPP_MISTY = { preferType = "WATER", preferStatus = 1 },
  OPP_LT_SURGE = { preferType = "ELECTRIC", preferPara = 1, preferSpeed = 1 },
  OPP_ERIKA = { preferStatus = 1, preferSeed = 1, preferDrain = 1 },
  OPP_KOGA = { preferPoison = 1, preferStatus = 1 },
  OPP_SABRINA = { preferStatus = 1, preferConfuse = 1, preferDisruption = 1 },
  OPP_BLAINE = { preferType = "FIRE", preferAttack = 1 },
  OPP_GIOVANNI = { preferType = "GROUND", preferAttack = 1 },
  OPP_LORELEI = { preferStatus = 1, preferType = "ICE" },
  OPP_BRUNO = { preferType = "FIGHTING", preferSetup = 1, preferAttack = 1 },
  OPP_AGATHA = { preferType = "GHOST", switchBias = 1.5 },
  OPP_LANCE = { preferSE = 1, preferSTAB = 1, preferType = "DRAGON" },
  OPP_RIVAL3 = { preferKO = 1, preferSE = 1, greedyItems = true },
  OPP_ROCKET = { preferAttack = 0.5 },
}
TrainerAi.THEMES = THEMES

function TrainerAi.isElite(oppClass, partyIndex)
  if not oppClass then return false end
  if ELITE_ALL_PARTIES[oppClass] then return true end
  local parties = ELITE_PARTIES[oppClass]
  return parties and parties[partyIndex or 1] and true or false
end

function TrainerAi.isGymMap(mapId)
  return mapId and GYM_MAPS[mapId] and true or false
end

function TrainerAi.isLiteClass(oppClass)
  return oppClass and LITE_CLASSES[oppClass] and true or false
end

-- elite before lite (gym leaders are also gym-map battles).
function TrainerAi.tier(battle)
  if not battle or battle.kind ~= "trainer" then return "soft" end
  local class = battle.oppClass or (battle.trainer and battle.trainer.id)
  local party = battle.expPartyIndex or 1
  if TrainerAi.isElite(class, party) then return "elite" end
  if TrainerAi.isGymMap(battle.expMapId) or TrainerAi.isLiteClass(class) then
    return "lite"
  end
  return "soft"
end

-- ------- Soft EXP_SMART helpers --------------------------------------------

local STATUS_EFFECTS = {
  EFFECT_01 = true, SLEEP_EFFECT = true, POISON_EFFECT = true,
  PARALYZE_EFFECT = true,
  EXP_BURN_EFFECT = true,
  EXP_YAWN_EFFECT = true,
}

local CONFUSE_EFFECTS = {
  CONFUSION_EFFECT = true,
  EXP_ATTRACT_EFFECT = true,
  EXP_SWAGGER_EFFECT = true,
}

local STAGE_EFFECTS = {
  ATTACK_UP1_EFFECT = { "attack", 1 },
  DEFENSE_UP1_EFFECT = { "defense", 1 },
  SPEED_UP1_EFFECT = { "speed", 1 },
  SPECIAL_UP1_EFFECT = { "special", 1 },
  ACCURACY_UP1_EFFECT = { "accuracy", 1 },
  EVASION_UP1_EFFECT = { "evasion", 1 },
  ATTACK_UP2_EFFECT = { "attack", 1 },
  DEFENSE_UP2_EFFECT = { "defense", 1 },
  SPEED_UP2_EFFECT = { "speed", 1 },
  SPECIAL_UP2_EFFECT = { "special", 1 },
  ACCURACY_UP2_EFFECT = { "accuracy", 1 },
  EVASION_UP2_EFFECT = { "evasion", 1 },
  ATTACK_DOWN1_EFFECT = { "attack", -1 },
  DEFENSE_DOWN1_EFFECT = { "defense", -1 },
  SPEED_DOWN1_EFFECT = { "speed", -1 },
  SPECIAL_DOWN1_EFFECT = { "special", -1 },
  ACCURACY_DOWN1_EFFECT = { "accuracy", -1 },
  EVASION_DOWN1_EFFECT = { "evasion", -1 },
  ATTACK_DOWN2_EFFECT = { "attack", -1 },
  DEFENSE_DOWN2_EFFECT = { "defense", -1 },
  SPEED_DOWN2_EFFECT = { "speed", -1 },
  SPECIAL_DOWN2_EFFECT = { "special", -1 },
  ACCURACY_DOWN2_EFFECT = { "accuracy", -1 },
  EVASION_DOWN2_EFFECT = { "evasion", -1 },
}

local SCREEN_EFFECTS = {
  LIGHT_SCREEN_EFFECT = "lightScreen",
  REFLECT_EFFECT = "reflect",
  MIST_EFFECT = "mist",
  FOCUS_ENERGY_EFFECT = "focusEnergy",
  EXP_SAFEGUARD_EFFECT = "expSafeguard",
}

local HEAL_ITEMS = {
  POTION = true, SUPER_POTION = true, HYPER_POTION = true, FULL_RESTORE = true,
}
local X_ITEMS = {
  X_ATTACK = "attack", X_DEFEND = "defense", X_SPEED = "speed",
  X_SPECIAL = "special",
}

local function hasType(types, id)
  for _, t in ipairs(types or {}) do
    if t == id then return true end
  end
  return false
end

local function stageOf(battler, stat)
  return (battler.stages and battler.stages[stat]) or 0
end

local function hpRatio(battler)
  local mon = battler and battler.mon
  if not mon or not mon.stats or not mon.stats.hp or mon.stats.hp <= 0 then
    return 1
  end
  return mon.hp / mon.stats.hp
end

local function themeFor(battle)
  local class = battle and (battle.oppClass or (battle.trainer and battle.trainer.id))
  return (class and THEMES[class]) or {}
end

local function rulesetOf(battle)
  return (battle and battle.ruleset)
    or { randMin = 217, randMax = 255, critIgnoresStages = true }
end

local function fixedRng(value)
  return function(lo, hi)
    if hi == nil then return value end
    if value < lo then return lo end
    if value > hi then return hi end
    return value
  end
end

-- Mid-roll and high-roll damage estimates (no crit). Returns mid, high, typeMult.
-- Returns nil mid when the move is non-damaging or battlers lack stats.
function TrainerAi.estimateDamage(battle, attacker, defender, moveDef, opts)
  opts = opts or {}
  if not moveDef or (moveDef.power or 0) <= 0 then return nil, nil, 10 end
  if not attacker or not defender then return nil, nil, 10 end
  if not attacker.curStats or not defender.curStats then return nil, nil, 10 end
  if not attacker.mon or not attacker.mon.level then return nil, nil, 10 end
  local ruleset = rulesetOf(battle)
  local lo = ruleset.randMin or 217
  local hi = ruleset.randMax or 255
  local mid = math.floor((lo + hi) / 2)
  local move = moveDef
  if not move.id then
    move = {}
    for k, v in pairs(moveDef) do move[k] = v end
  end
  local midDmg = Damage.compute(ruleset, attacker, defender, move, {
    forceCrit = false,
    rng = fixedRng(mid),
  })
  local highDmg = midDmg
  if opts.highRoll then
    highDmg = Damage.compute(ruleset, attacker, defender, move, {
      forceCrit = false,
      rng = fixedRng(hi),
    })
  end
  local mult = TypeChart.effectiveness(move.type, defender.curTypes)
  return midDmg, highDmg, mult
end

local function damageBucket(dmg, coarse)
  if not dmg or dmg <= 0 then return 0 end
  if coarse then
    if dmg >= 80 then return 3 elseif dmg >= 40 then return 2 elseif dmg >= 15 then return 1 end
    return 0
  end
  if dmg >= 100 then return 4 elseif dmg >= 60 then return 3
  elseif dmg >= 30 then return 2 elseif dmg >= 12 then return 1 end
  return 0
end

local function boardPressure(view, mode)
  local cache = view._expTactical
  if cache then return cache end
  cache = { midKo = false, highKo = false, bestMid = 0 }
  local user, target = view.user, view.target
  local battle = view.battle
  local data = view.data or (battle and battle.data)
  if not (user and target and data and user.curMoves) then
    view._expTactical = cache
    return cache
  end
  local wantHigh = mode == "elite"
  local targetHp = target.mon and target.mon.hp or 0
  for _, mv in ipairs(user.curMoves) do
    local def = data.moves[mv.id]
    if def and (def.power or 0) > 0 then
      local mid, high = TrainerAi.estimateDamage(battle, user, target, def, {
        highRoll = wantHigh,
      })
      if mid and mid > cache.bestMid then cache.bestMid = mid end
      if mid and targetHp > 0 and mid >= targetHp then cache.midKo = true end
      if wantHigh and high and targetHp > 0 and high >= targetHp then
        cache.highKo = true
      end
    end
  end
  view._expTactical = cache
  return cache
end

-- ------- Soft score (EXP_SMART) ---------------------------------------------

function TrainerAi.score(view, def, score)
  if not def then return score end
  local user, target = view.user, view.target
  local power = def.power or 0
  local effect = def.effect
  local userHp = hpRatio(user)
  local stageInfo = STAGE_EFFECTS[effect]

  -- Stage moves: dump when already stacked; never leave a "dead zone" where
  -- a half-applied Sand Attack still outscores every attack forever.
  if stageInfo then
    local stat, dir = stageInfo[1], stageInfo[2]
    local cur = stageOf(dir < 0 and target or user, stat)
    if dir < 0 then
      local isAccEva = (stat == "accuracy" or stat == "evasion")
      if isAccEva then
        -- Sand Attack / Flash / Smokescreen: one try, then stop.
        if cur <= -1 then return score + 5 end
      else
        -- Growl / Tail Whip / String Shot etc.: light stack only.
        if cur <= -2 then return score + 5 end
        if cur <= -1 then score = score + 2 end
      end
    else
      if cur >= 6 then return score + 6 end
      if cur >= 2 then score = score + 3 end
    end
  end

  if power == 0 and STATUS_EFFECTS[effect] and target.mon and target.mon.status then
    return score + 6
  end
  if effect == "EXP_YAWN_EFFECT" then
    if (target.mon and target.mon.status) or target.expYawnTurns then
      return score + 6
    end
  end
  if CONFUSE_EFFECTS[effect] and target.confusedTurns then
    return score + 6
  end
  if effect == "LEECH_SEED_EFFECT" then
    if target.leechSeeded or hasType(target.curTypes, "GRASS") then
      return score + 6
    end
  end
  if effect == "HEAL_EFFECT" and user.mon
     and user.mon.hp >= (user.mon.stats and user.mon.stats.hp or 0) then
    return score + 6
  end
  local screenKey = SCREEN_EFFECTS[effect]
  if screenKey and user[screenKey] then
    return score + 6
  end
  if effect == "SUBSTITUTE_EFFECT" and user.substituteHP then
    return score + 6
  end
  if effect == "DISABLE_EFFECT" and target.disabledSlot then
    return score + 6
  end

  if power > 0 then
    score = score - 1
    if hasType(user.curTypes, def.type) then
      score = score - 1
    end
    local row = TypeChart.rows(def.type, target.curTypes)[1]
    if row == 0 then
      score = score + 6
    elseif row and row > 10 then
      score = score - 2
    elseif row and row < 10 then
      score = score + 1
    end
    return score
  end

  -- Major status: prefer as an opener when healthy; dumps above when already applied.
  if STATUS_EFFECTS[effect] and target.mon and not target.mon.status then
    if userHp > 0.5 then
      score = score - 3
    else
      score = score - 2
    end
  end

  if CONFUSE_EFFECTS[effect] and not target.confusedTurns then
    if userHp > 0.5 then
      score = score - 1
    end
  end

  if effect == "LEECH_SEED_EFFECT"
     and not target.leechSeeded
     and not hasType(target.curTypes, "GRASS") then
    if userHp > 0.4 then
      score = score - 1
    end
  end

  if stageInfo then
    local stat, dir = stageInfo[1], stageInfo[2]
    local cur = stageOf(dir < 0 and target or user, stat)
    if dir > 0 then
      -- Self setup: one prefer while unboosted, then back off.
      if cur < 1 and userHp > 0.4 then
        score = score - 3
      elseif cur >= 1 then
        score = score + 2
      end
    else
      -- Foe drops: mild once at 0 (ties STAB); hard dumps above stop the spam.
      if cur >= 0 and userHp > 0.4 then
        score = score - 2
      end
    end
  end

  if screenKey and not user[screenKey] and userHp > 0.4 then
    score = score - 1
  end
  if effect == "SUBSTITUTE_EFFECT" and not user.substituteHP and userHp > 0.4 then
    score = score - 1
  end

  if effect == "HEAL_EFFECT" then
    if userHp <= 0.25 then
      score = score - 4
    elseif userHp <= 0.5 then
      score = score - 3
    end
  end

  return score
end

-- ------- Tactical score (lite / elite) --------------------------------------

local function scoreTactical(view, def, score, mode)
  if not def then return score end
  local user, target = view.user, view.target
  local power = def.power or 0
  local effect = def.effect
  local userHp = hpRatio(user)
  local targetHp = target.mon and target.mon.hp or 0
  local pressure = boardPressure(view, mode)
  local theme = (mode == "elite" and themeFor(view.battle)) or {}
  local coarse = mode == "lite"
  local koBias = mode == "elite" and 4 or 2
  if theme.preferKO then koBias = koBias + theme.preferKO end

  -- Dual-type effectiveness (replaces first-row soft SE for damaging).
  local typeMult = TypeChart.effectiveness(def.type, target.curTypes)

  if power > 0 then
    if typeMult == 0 then
      return score + 6
    end
    -- Prefer true dual-type SE more than single-type soft layer alone.
    if typeMult >= 20 then
      score = score - (mode == "elite" and 2 or 1)
    elseif typeMult > 10 then
      score = score - (mode == "elite" and 1 or 0)
    elseif typeMult < 10 then
      score = score + (mode == "elite" and 2 or 1)
    end

    local mid, high = TrainerAi.estimateDamage(view.battle, user, target, def, {
      highRoll = mode == "elite",
    })
    if mid then
      score = score - damageBucket(mid, coarse)
      if targetHp > 0 and mid >= targetHp then
        score = score - koBias
      elseif mode == "elite" and high and targetHp > 0 and high >= targetHp then
        -- Elite-only: finish is possible on a good roll.
        score = score - math.max(1, math.floor(koBias / 2))
      end
    end

    if hasType(user.curTypes, def.type) and theme.preferSTAB then
      score = score - theme.preferSTAB
    end
    if typeMult > 10 and theme.preferSE then
      score = score - theme.preferSE
    end
    if theme.preferType and def.type == theme.preferType then
      score = score - 1
    end
    if theme.preferAttack then
      score = score - theme.preferAttack
    end
    if theme.preferDrain and (effect == "DRAIN_HP_EFFECT" or effect == "MEGA_DRAIN_EFFECT"
        or effect == "LEECH_SEED_EFFECT") then
      score = score - theme.preferDrain
    end
    return score
  end

  -- Non-damaging under pressure: dump setup/status when a KO is on the board.
  local canKo = pressure.midKo or (mode == "elite" and pressure.highKo)
  local foeLow = target.mon and target.mon.stats and target.mon.stats.hp > 0
    and (target.mon.hp / target.mon.stats.hp) <= 0.4
  if canKo or (mode == "elite" and foeLow) then
    if STATUS_EFFECTS[effect] or CONFUSE_EFFECTS[effect]
       or STAGE_EFFECTS[effect] or SCREEN_EFFECTS[effect]
       or effect == "SUBSTITUTE_EFFECT" or effect == "LEECH_SEED_EFFECT" then
      score = score + (mode == "elite" and 3 or 1)
    end
  end

  -- Theme nudges for status / disruption (elite only, when not under KO pressure).
  if mode == "elite" and not canKo then
    if STATUS_EFFECTS[effect] and theme.preferStatus then
      score = score - theme.preferStatus
    end
    if CONFUSE_EFFECTS[effect] and theme.preferConfuse then
      score = score - theme.preferConfuse
    end
    if effect == "PARALYZE_EFFECT" and theme.preferPara then
      score = score - theme.preferPara
    end
    if (effect == "POISON_EFFECT" or effect == "POISON_SIDE_EFFECT1"
        or effect == "POISON_SIDE_EFFECT2") and theme.preferPoison then
      score = score - theme.preferPoison
    end
    if effect == "LEECH_SEED_EFFECT" and theme.preferSeed then
      score = score - theme.preferSeed
    end
    local stageInfo = STAGE_EFFECTS[effect]
    if stageInfo and stageInfo[2] > 0 and theme.preferSetup then
      score = score - theme.preferSetup
    end
    if stageInfo and stageInfo[1] == "defense" and stageInfo[2] > 0
       and theme.preferDefense then
      score = score - theme.preferDefense
    end
    if stageInfo and stageInfo[1] == "speed" and stageInfo[2] > 0
       and theme.preferSpeed then
      score = score - theme.preferSpeed
    end
    if SCREEN_EFFECTS[effect] and theme.preferScreens then
      score = score - theme.preferScreens
    end
    if theme.preferDisruption and (STATUS_EFFECTS[effect] or CONFUSE_EFFECTS[effect]
        or effect == "DISABLE_EFFECT") then
      score = score - theme.preferDisruption
    end
  end

  return score
end

function TrainerAi.scoreTactical(view, def, score)
  return scoreTactical(view, def, score, "elite")
end

function TrainerAi.scoreTacticalLite(view, def, score)
  return scoreTactical(view, def, score, "lite")
end

-- ------- Matchup / action helpers -------------------------------------------

local function partyBattler(data, mon)
  if not mon or not data then return nil end
  local def = data.pokemon[mon.species]
  return {
    mon = mon,
    def = def,
    curStats = mon.stats,
    curTypes = (def and def.types) or { "NORMAL" },
    stages = {},
    curMoves = mon.moves,
  }
end

local function bestDamageVs(battle, attacker, defender)
  local data = battle.data
  if not (attacker and defender and data) then return 0 end
  local best = 0
  for _, mv in ipairs(attacker.curMoves or {}) do
    local def = data.moves[mv.id]
    if def and (def.power or 0) > 0 then
      local mid = TrainerAi.estimateDamage(battle, attacker, defender, def)
      if mid and mid > best then best = mid end
      if not mid then
        local mult = TypeChart.effectiveness(def.type, defender.curTypes)
        local proxy = (def.power or 0) * mult / 10
        if proxy > best then best = proxy end
      end
    end
  end
  if best == 0 and attacker.curTypes then
    -- No moves yet: type product vs foe as a weak proxy.
    for _, t in ipairs(attacker.curTypes) do
      local mult = TypeChart.effectiveness(t, defender.curTypes)
      if mult > best then best = mult end
    end
  end
  return best
end

function TrainerAi.bestSwitchIndex(battle)
  local player = battle.player
  local data = battle.data
  if not player or not data then return nil, 0, 0 end
  local current = bestDamageVs(battle, battle.enemy, player)
  local bestIdx, bestScore = nil, current
  for i, mon in ipairs(battle.enemyParty or {}) do
    if mon.hp > 0 and i ~= battle.enemyIndex then
      local bat = partyBattler(data, mon)
      local score = bestDamageVs(battle, bat, player)
      if score > bestScore then
        bestScore = score
        bestIdx = i
      end
    end
  end
  return bestIdx, bestScore, current
end

local function classItem(battle)
  local class = TrainerAI.classFor(battle)
  return class and class.item, class
end

local function hasUsableHealItem(battle)
  local item = classItem(battle)
  if item and HEAL_ITEMS[item] then return item end
  -- Prefer class heal; otherwise a sensible default for elites with no heal item.
  return nil
end

function TrainerAi.eliteAction(battle)
  if not battle or battle.kind ~= "trainer" then return nil end
  if (battle.aiUses or 0) <= 0 then return nil end
  local enemy = battle.enemy
  if not enemy or not enemy.mon then return nil end
  -- Fresh switch budget each time a new enemy mon is active.
  if battle.expAiSwitchMon ~= battle.enemyIndex then
    battle.expAiSwitchMon = battle.enemyIndex
    battle.expAiSwitches = 0
  end
  local theme = themeFor(battle)
  local userHp = hpRatio(enemy)
  local data = battle.data
  local pressure = boardPressure({
    user = enemy, target = battle.player, battle = battle, data = data,
  }, "elite")
  local canKo = pressure.midKo or pressure.highKo

  -- Full Heal / status clear when it actually matters.
  local status = enemy.mon.status
  if status and (theme.fullHealUrgency or status == "SLP" or status == "FRZ"
      or status == "PAR" or status == "BRN") then
    local item, class = classItem(battle)
    if class and class.onStatus and class.item then
      return { special = "aiItem", item = class.item }
    end
    if item == "FULL_HEAL" or item == "FULL_RESTORE" then
      return { special = "aiItem", item = item }
    end
    -- Brock-style urgency even if class table differs after patches.
    if theme.fullHealUrgency then
      return { special = "aiItem", item = "FULL_HEAL" }
    end
  end

  -- Matchup switch: current is clearly worse than a backup.
  local switchBias = theme.switchBias or 1
  local bestIdx, bestScore, currentScore = TrainerAi.bestSwitchIndex(battle)
  if bestIdx and not canKo then
    local margin = 20 / switchBias
    local dying = userHp <= 0.25
    if bestScore >= currentScore + margin
       or (dying and bestScore > currentScore * 1.25) then
      -- Rate-limit: at most one AI switch per mon send-out unless Agatha-ish.
      local switches = battle.expAiSwitches or 0
      local maxSwitches = switchBias >= 1.5 and 2 or 1
      if switches < maxSwitches then
        battle.expAiSwitches = switches + 1
        return { special = "aiSwitch", index = bestIdx }
      end
    end
  end

  -- Heal when low and not holding a KO.
  if userHp <= (theme.greedyItems and 0.4 or 0.3) and not canKo then
    local heal = hasUsableHealItem(battle)
    if heal then
      return { special = "aiItem", item = heal }
    end
    local item = classItem(battle)
    if item and HEAL_ITEMS[item] then
      return { special = "aiItem", item = item }
    end
    if theme.greedyItems then
      return { special = "aiItem", item = "FULL_RESTORE" }
    end
  end

  -- X items / Guard Spec when healthy, not staged, no KO on the board.
  if userHp > 0.5 and not canKo then
    local item = classItem(battle)
    local xStat = item and X_ITEMS[item]
    if xStat and stageOf(enemy, xStat) < 1 then
      return { special = "aiItem", item = item }
    end
    if item == "GUARD_SPEC" and not enemy.mist then
      return { special = "aiItem", item = item }
    end
  end

  return nil
end

function TrainerAi.liteAction(battle)
  if not battle or battle.kind ~= "trainer" then return nil end
  if (battle.aiUses or 0) <= 0 then return nil end
  local enemy = battle.enemy
  if not enemy or not enemy.mon then return nil end
  -- Emergency heal only; no matchup pivots, no X items.
  if hpRatio(enemy) <= 0.25 then
    local item, class = classItem(battle)
    if item and HEAL_ITEMS[item] then
      return { special = "aiItem", item = item }
    end
    -- Class with onStatus Full Heal does not count as a heal here.
    if class and class.item and HEAL_ITEMS[class.item] then
      return { special = "aiItem", item = class.item }
    end
  end
  return nil
end

-- ------- Register / install -------------------------------------------------

function TrainerAi.register(mod)
  mod.content.ai_classes:register(TrainerAi.LAYER_ID, {
    kind = "layer",
    score = TrainerAi.score,
  })
  mod.content.ai_classes:register(TrainerAi.LAYER_TACTICAL, {
    kind = "layer",
    score = TrainerAi.scoreTactical,
  })
  mod.content.ai_classes:register(TrainerAi.LAYER_TACTICAL_LITE, {
    kind = "layer",
    score = TrainerAi.scoreTacticalLite,
  })
end

local function appendLayer(mods, id)
  for _, m in ipairs(mods) do
    if m == id then return end
  end
  mods[#mods + 1] = id
end

local function currentMapId(game)
  local ow = game and game.overworld
  return ow and ow.map and ow.map.id or nil
end

function TrainerAi.install(mod)
  if TrainerAI._expansionSmartAi then return end

  -- Stash party index + map id on every trainer battle.
  local BattleState = require("src.battle.BattleState")
  local originalNewTrainer = BattleState.newTrainer
  BattleState.newTrainer = function(game, oppClass, partyIndex)
    local battle = originalNewTrainer(game, oppClass, partyIndex)
    if battle then
      battle.expPartyIndex = partyIndex or 1
      battle.expMapId = currentMapId(game)
      battle.expAiSwitches = 0
    end
    return battle
  end

  -- Inject soft + tier layer into chooseMove.
  local originalChoose = TrainerAI.chooseMove
  TrainerAI.chooseMove = function(battler, rng, battle)
    if not battle or not TrainerAi.enabled(mod) then
      return originalChoose(battler, rng, battle)
    end
    local saved = battle.enemyAIMods
    local mods = {}
    if type(saved) == "table" then
      for i, m in ipairs(saved) do mods[i] = m end
    end
    appendLayer(mods, TrainerAi.LAYER_ID)
    local tier = TrainerAi.tier(battle)
    if tier == "elite" then
      appendLayer(mods, TrainerAi.LAYER_TACTICAL)
    elseif tier == "lite" then
      appendLayer(mods, TrainerAi.LAYER_TACTICAL_LITE)
    end
    battle.enemyAIMods = mods
    local ok, result = pcall(originalChoose, battler, rng, battle)
    battle.enemyAIMods = saved
    if not ok then error(result) end
    return result
  end

  -- Elite / lite actions replace vanilla classAction for those tiers.
  mod.hooks:wrap("battle.enemy_action", function(next, battle)
    if not TrainerAi.enabled(mod) then return next(battle) end
    local tier = TrainerAi.tier(battle)
    if tier == "soft" then return next(battle) end

    local locked = battle.lockedAction and battle:lockedAction(battle.enemy)
    if locked then return locked end

    local act
    if tier == "elite" then
      act = TrainerAi.eliteAction(battle)
    else
      act = TrainerAi.liteAction(battle)
    end
    if act then return act end

    -- Skip vanilla blind classAction; still use chooseMove (with layer inject).
    return TrainerAI.chooseMove(battle.enemy, battle.rng, battle)
  end)

  TrainerAI._expansionSmartAi = true
end

return TrainerAi
