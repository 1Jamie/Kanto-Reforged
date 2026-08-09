-- Kanto Reforged trainer AI: four tiers.
--   natural — EXP_NATURAL (common wild): dump no-ops only; otherwise messy.
--   soft    — EXP_SMART (trash trainers + threat wilds): mild prefs, decay,
--             near-best mix, light situational nudges.
--   lite    — EXP_SMART + EXP_TACTICAL_LITE: mid-roll damage, KO bias, items.
--   elite   — EXP_SMART + EXP_TACTICAL + themes + switches / smarter items.
--
-- Tier gate order is mandatory: elite roster BEFORE gym-map / serious-class
-- lite, so a leader on a gym map never silently downgrades to lite.
-- Wilds never use lite/elite; they are natural or soft via wildTier().

local TypeChart = require("src.battle.TypeChart")
local Damage = require("src.battle.Damage")
local TrainerAI = require("src.battle.TrainerAI")
local Stats = require("src.pokemon.Stats")

local TrainerAi = {}

TrainerAi.LAYER_ID = "EXP_SMART"
TrainerAi.LAYER_NATURAL = "EXP_NATURAL"
TrainerAi.LAYER_TACTICAL = "EXP_TACTICAL"
TrainerAi.LAYER_TACTICAL_LITE = "EXP_TACTICAL_LITE"
TrainerAi.OPTION_KEY = "smarter_ai"
TrainerAi.OPTION = {
  key = TrainerAi.OPTION_KEY,
  label = "SMARTER AI",
  type = "toggle",
  default = true,
}

-- Voluntary-switch free-hit timing (player Switch → enemy attack).
-- gen3 (default): lock AI move against the outgoing mon, then land it
--   on the switch-in (matches RS/FRLG/Emerald turn lock-in).
-- gen1: pick after send-out (engine default; feels like AI saw the swap).
TrainerAi.SWITCH_LOCK_KEY = "switch_hit_ai"
TrainerAi.SWITCH_LOCK_GEN3 = "gen3"
TrainerAi.SWITCH_LOCK_GEN1 = "gen1"
TrainerAi.SWITCH_LOCK_OPTION = {
  key = TrainerAi.SWITCH_LOCK_KEY,
  label = "SWITCH HIT AI",
  type = "choice",
  default = TrainerAi.SWITCH_LOCK_GEN3,
  choices = {
    { "GEN 3", TrainerAi.SWITCH_LOCK_GEN3 },
    { "GEN 1", TrainerAi.SWITCH_LOCK_GEN1 },
  },
}

function TrainerAi.enabled(mod)
  return mod and mod.options and mod.options:get(TrainerAi.OPTION_KEY) and true or false
end

function TrainerAi.switchLockGen3(mod)
  if not mod or not mod.options then return true end
  local value = mod.options:get(TrainerAi.SWITCH_LOCK_KEY)
  if value == TrainerAi.SWITCH_LOCK_GEN1 then return false end
  return true
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

-- Wild soft upgrades: scary maps (fodder species stay natural here).
local THREAT_MAPS = {
  ROCK_TUNNEL_1F = true, ROCK_TUNNEL_B1F = true,
  POKEMON_TOWER_1F = true, POKEMON_TOWER_2F = true, POKEMON_TOWER_3F = true,
  POKEMON_TOWER_4F = true, POKEMON_TOWER_5F = true, POKEMON_TOWER_6F = true,
  POKEMON_TOWER_7F = true,
  POWER_PLANT = true,
  POKEMON_MANSION_1F = true, POKEMON_MANSION_2F = true,
  POKEMON_MANSION_3F = true, POKEMON_MANSION_B1F = true,
  SEAFOAM_ISLANDS_1F = true, SEAFOAM_ISLANDS_B1F = true,
  SEAFOAM_ISLANDS_B2F = true, SEAFOAM_ISLANDS_B3F = true,
  SEAFOAM_ISLANDS_B4F = true,
  VICTORY_ROAD_1F = true, VICTORY_ROAD_2F = true, VICTORY_ROAD_3F = true,
  CERULEAN_CAVE_1F = true, CERULEAN_CAVE_2F = true, CERULEAN_CAVE_B1F = true,
}

-- Common early pests: stay natural even on threat maps.
local FODDER_SPECIES = {
  ZUBAT = true, GEODUDE = true, RATTATA = true, SPEAROW = true,
  CATERPIE = true, WEEDLE = true, PIDGEY = true, MAGIKARP = true,
}

-- Iconic off-map threats only. Cave commons (Onix, Cubone, Golbat, Machop…)
-- get soft via THREAT_MAPS when not fodder — listing them here made midgame
-- grass feel samey. Legendaries live in LEGENDARY_SPECIES and fold in below.
local THREAT_SPECIES = {
  GYARADOS = true, SNORLAX = true, CHANSEY = true, KANGASKHAN = true,
  LAPRAS = true, DRAGONAIR = true, DRAGONITE = true,
  GENGAR = true, HAUNTER = true,
  ALAKAZAM = true, HYPNO = true, EXEGGUTOR = true,
  ARCANINE = true, RAPIDASH = true, RHYDON = true,
  ELECTABUZZ = true, MAGMAR = true, JYNX = true, MR_MIME = true,
  SCYTHER = true, PINSIR = true, TAUROS = true,
  OMASTAR = true, KABUTOPS = true, AERODACTYL = true,
  HITMONLEE = true, HITMONCHAN = true, MACHAMP = true,
  STARMIE = true, CLOYSTER = true, SLOWBRO = true,
}

local LEGENDARY_SPECIES = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true, LUGIA = true, HO_OH = true,
  CELEBI = true, REGIROCK = true, REGICE = true, REGISTEEL = true,
  LATIAS = true, LATIOS = true, KYOGRE = true, GROUDON = true,
  RAYQUAZA = true, JIRACHI = true, DEOXYS = true,
}

-- Soft-threat lookup = iconic threats ∪ legendaries (no duplicated entries).
for id in pairs(LEGENDARY_SPECIES) do
  THREAT_SPECIES[id] = true
end

TrainerAi.GYM_MAPS = GYM_MAPS
TrainerAi.LITE_CLASSES = LITE_CLASSES
TrainerAi.ELITE_PARTIES = ELITE_PARTIES
TrainerAi.ELITE_ALL_PARTIES = ELITE_ALL_PARTIES
TrainerAi.THREAT_MAPS = THREAT_MAPS
TrainerAi.FODDER_SPECIES = FODDER_SPECIES
TrainerAi.THREAT_SPECIES = THREAT_SPECIES
TrainerAi.LEGENDARY_SPECIES = LEGENDARY_SPECIES

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

function TrainerAi.isThreatMap(mapId)
  return mapId and THREAT_MAPS[mapId] and true or false
end

function TrainerAi.isFodderSpecies(species)
  return species and FODDER_SPECIES[species] and true or false
end

-- Includes legendaries (merged from LEGENDARY_SPECIES at load).
function TrainerAi.isThreatSpecies(species)
  return species and THREAT_SPECIES[species] and true or false
end

function TrainerAi.isLegendarySpecies(species)
  return species and LEGENDARY_SPECIES[species] and true or false
end

function TrainerAi.isRareMap(mapId)
  if not mapId then return false end
  local ok, Encounters = pcall(require, "mods.Kanto-Reforged.encounters")
  if not ok or not Encounters or not Encounters.MAPS then return false end
  local def = Encounters.MAPS[mapId]
  return def and def.rare and true or false
end

local function wildSpeciesOf(battle)
  return battle.expWildSpecies
    or (battle.enemy and battle.enemy.mon and battle.enemy.mon.species)
    or (battle.enemy and battle.enemy.def and battle.enemy.def.id)
end

-- Common wild → natural; threat wild → soft. Never lite/elite for wilds.
function TrainerAi.wildTier(battle)
  if not battle then return "natural" end
  if battle.expRoamer then return "soft" end
  local species = wildSpeciesOf(battle)
  -- Threat set already includes legendaries (derived at load).
  if TrainerAi.isThreatSpecies(species) then return "soft" end
  local mapId = battle.expMapId
  if TrainerAi.isRareMap(mapId) then return "soft" end
  if TrainerAi.isThreatMap(mapId) and not TrainerAi.isFodderSpecies(species) then
    return "soft"
  end
  return "natural"
end

-- elite before lite (gym leaders are also gym-map battles).
function TrainerAi.tier(battle)
  if not battle then return "soft" end
  if battle.kind == "wild" then
    return TrainerAi.wildTier(battle)
  end
  if battle.kind ~= "trainer" then
    return "soft"
  end
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

local function softOpenerEffect(effect)
  return STATUS_EFFECTS[effect] or CONFUSE_EFFECTS[effect]
    or STAGE_EFFECTS[effect] or effect == "LEECH_SEED_EFFECT"
end

-- After using an opener, raise its score penalty; decays 1 per AI turn back to 0.
-- Low-accuracy moves cool longer so Hypnosis/Supersonic do not immediately re-lock.
-- Soft gets the full bump; lite/elite get half (tactical dumps already cover pressure).
local function softDecayBump(def, tier)
  if not def or not softOpenerEffect(def.effect) then return 0 end
  local acc = def.accuracy or 100
  local bump = 2
  if acc < 70 then
    bump = 4
  elseif acc < 90 then
    bump = 3
  end
  if tier == "lite" or tier == "elite" then
    return math.max(1, math.floor(bump / 2))
  end
  return bump
end

function TrainerAi.decayMoveWeights(battler)
  local weights = battler and battler.expAiMoveWeight
  if not weights then return end
  for id, w in pairs(weights) do
    if w <= 1 then
      weights[id] = nil
    else
      weights[id] = w - 1
    end
  end
end

function TrainerAi.bumpMoveWeight(battler, moveId, amount)
  if not battler or not moveId or not amount or amount <= 0 then return end
  battler.expAiMoveWeight = battler.expAiMoveWeight or {}
  local cur = battler.expAiMoveWeight[moveId] or 0
  if amount > cur then
    battler.expAiMoveWeight[moveId] = amount
  end
end

local function moveWeightPenalty(user, moveId)
  local weights = user and user.expAiMoveWeight
  if not weights or not moveId then return 0 end
  return weights[moveId] or 0
end

local HEAL_ITEMS = {
  -- Trainer bag / class items only. Held berries never go through aiItem /
  -- recordItemUsed — they auto-consume on pinch/status and must not burn
  -- the AI item budget.
  POTION = true, SUPER_POTION = true, HYPER_POTION = true, FULL_RESTORE = true,
}
local X_ITEMS = {
  X_ATTACK = "attack", X_DEFEND = "defense", X_SPEED = "speed",
  X_SPECIAL = "special",
}

local PRIORITY_MOVES = {
  QUICK_ATTACK = true, MACH_PUNCH = true, EXTREME_SPEED = true,
  AQUA_JET = true, ICE_SHARD = true, BULLET_PUNCH = true,
  SHADOW_SNEAK = true, VACUUM_WAVE = true, SUCKER_PUNCH = true,
  FIRST_IMPRESSION = true, ACCELROCK = true,
}

local function hasType(types, id)
  for _, t in ipairs(types or {}) do
    if t == id then return true end
  end
  return false
end

local function stageOf(battler, stat)
  return (battler and battler.stages and battler.stages[stat]) or 0
end

local function hpRatio(battler)
  local mon = battler and battler.mon
  if not mon or not mon.stats or not mon.stats.hp or mon.stats.hp <= 0 then
    return 1
  end
  return mon.hp / mon.stats.hp
end

-- Residual chip that makes self-setup suicidal next turns.
local function hasResidual(battler)
  if not battler then return false end
  if battler.leechSeeded then return true end
  local st = battler.mon and battler.mon.status
  return st == "PSN" or st == "BRN" or st == "TOX"
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

-- Effective in-battle speed helper
function TrainerAi.effectiveSpeed(battler)
  if not battler or not battler.curStats or not battler.curStats.speed then return 0 end
  local spd = battler.curStats.speed
  local stage = stageOf(battler, "speed")
  spd = Stats.applyStage(spd, stage)
  if battler.mon and battler.mon.status == "PAR" then
    spd = math.floor(spd * 0.25)
  end
  return spd
end

function TrainerAi.isAiFaster(battle)
  if not battle or not battle.enemy or not battle.player then return true end
  return TrainerAi.effectiveSpeed(battle.enemy) >= TrainerAi.effectiveSpeed(battle.player)
end

-- Best damage player can inflict on enemy
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

function TrainerAi.playerMaxDamage(battle)
  if not battle or not battle.player or not battle.enemy then return 0 end
  return bestDamageVs(battle, battle.player, battle.enemy)
end

-- Mod-side battle item tracking for trainer bag/class items only.
-- Held berries auto-consume elsewhere and never call recordItemUsed.
-- Lite and elite share expBattleItemsUsed / expMonItemsUsed; caps differ by tier().
local function canUseItem(battle, theme)
  if not battle then return false end
  battle.expBattleItemsUsed = battle.expBattleItemsUsed or 0
  battle.expMonItemsUsed = battle.expMonItemsUsed or {}
  local monIdx = battle.enemyIndex or 1
  local monUsed = battle.expMonItemsUsed[monIdx] or 0

  -- Rival 3 (Champion) gets max 3 items per battle (1 per mon).
  -- Standard Elite trainers get max 2 items per battle, max 1 per mon.
  -- Lite trainers get max 1 item total per battle, max 1 per mon.
  local tier = TrainerAi.tier(battle)
  local maxBattleItems = (theme and theme.greedyItems) and 3 or (tier == "elite" and 2 or 1)
  local maxMonItems = 1

  return battle.expBattleItemsUsed < maxBattleItems and monUsed < maxMonItems
end

-- Only count bag/class item uses — never held berries or other held items.
local function recordItemUsed(battle, itemId)
  if not battle then return end
  if itemId and not HEAL_ITEMS[itemId] and itemId ~= "FULL_HEAL"
      and itemId ~= "GUARD_SPEC" and not X_ITEMS[itemId] then
    return
  end
  battle.expBattleItemsUsed = (battle.expBattleItemsUsed or 0) + 1
  battle.expMonItemsUsed = battle.expMonItemsUsed or {}
  local monIdx = battle.enemyIndex or 1
  battle.expMonItemsUsed[monIdx] = (battle.expMonItemsUsed[monIdx] or 0) + 1
end

-- ------- Situation snapshot + natural / soft scoring -----------------------

-- Soft canKo is HP-fact only (≤20%). Soft threatened stays false (no damage guess).
-- Lite/elite use real estimateDamage / boardPressure.
function TrainerAi.situation(view, mode)
  mode = mode or "soft"
  local cached = view and view._expSituation
  if cached and cached.mode == mode then return cached end
  local user = view and view.user
  local target = view and view.target
  local sit = {
    mode = mode,
    userHp = hpRatio(user),
    foeHp = hpRatio(target),
    faster = nil,
    threatened = false,
    canKo = false,
    foeStatus = target and target.mon and target.mon.status or nil,
    foeConfused = target and target.confusedTurns and true or false,
    foeSeeded = target and target.leechSeeded and true or false,
  }
  if view and view.battle and user and user.curStats and target and target.curStats then
    sit.faster = TrainerAi.isAiFaster(view.battle)
  end
  if mode == "soft" then
    sit.canKo = sit.foeHp <= 0.20
    sit.threatened = false
  else
    local pressure = boardPressure(view, mode == "elite" and "elite" or "lite")
    sit.canKo = pressure.midKo or (mode == "elite" and pressure.highKo) or false
    if view.battle and user and user.mon then
      local playerDmg = TrainerAi.playerMaxDamage(view.battle) or 0
      sit.threatened = user.mon.hp > 0 and playerDmg >= user.mon.hp
    end
  end
  if view then view._expSituation = sit end
  return sit
end

local function isDrainEffect(effect)
  return effect == "DRAIN_HP_EFFECT" or effect == "MEGA_DRAIN_EFFECT"
      or effect == "DREAM_EATER_EFFECT"
end

-- t0.5: dump worthless plays; mild STAB only. No strategy brain.
-- Score polarity: lower is better (prefer), higher is dump.
function TrainerAi.scoreNatural(view, def, score)
  if not def then return score end
  local user, target = view.user, view.target
  local power = def.power or 0
  local effect = def.effect
  local stageInfo = STAGE_EFFECTS[effect]

  if stageInfo then
    local stat, dir = stageInfo[1], stageInfo[2]
    local cur = stageOf(dir < 0 and target or user, stat)
    if dir < 0 then
      local isAccEva = (stat == "accuracy" or stat == "evasion")
      if isAccEva and cur <= -1 then return score + 6 end
      if not isAccEva and cur <= -2 then return score + 6 end
    else
      if cur >= 2 then return score + 6 end
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
  if (effect == "POISON_EFFECT" or effect == "POISON_SIDE_EFFECT1"
      or effect == "POISON_SIDE_EFFECT2")
      and (hasType(target.curTypes, "POISON") or hasType(target.curTypes, "STEEL")) then
    return score + 6
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
    local row = TypeChart.rows(def.type, target.curTypes)[1]
    if row == 0 then return score + 6 end
    if hasType(user.curTypes, def.type) then
      score = score - 1
    end
    return score
  end

  return score
end

local function applySoftSituation(view, def, score, power)
  local sit = TrainerAi.situation(view, "soft")
  local effect = def.effect
  local isOpener = softOpenerEffect(effect)
  local isStatusLike = STATUS_EFFECTS[effect] or CONFUSE_EFFECTS[effect]
      or effect == "LEECH_SEED_EFFECT"
  local stageInfo = STAGE_EFFECTS[effect]
  local selfSetup = stageInfo and stageInfo[2] > 0

  -- Foe already disrupted: capitalize with damage; don't restage openers.
  if sit.foeStatus or sit.foeConfused then
    if power > 0 then
      score = score - 1
    elseif isOpener then
      score = score + 2
    end
  end

  -- User low HP: heal/drain over theater.
  if sit.userHp < 0.35 then
    if effect == "HEAL_EFFECT" or (power > 0 and isDrainEffect(effect)) then
      score = score - 1
    elseif selfSetup or isStatusLike then
      score = score + 1
    end
  end

  -- Conservative finish: only unambiguous very-low foe HP (soft canKo).
  if sit.canKo then
    if power > 0 then
      score = score - 1
    elseif isOpener then
      score = score + 2
    end
  end

  -- Faster and both healthy: mild anti-setup-theater (keep openers eligible).
  if sit.faster == true and sit.userHp > 0.5 and sit.foeHp > 0.5 then
    if selfSetup then
      score = score + 1
    end
  end

  -- Low-accuracy status costs extra unless trusted threatened (soft: never).
  if isStatusLike and (def.accuracy or 100) < 70 and not sit.threatened then
    score = score + 1
  end

  return score
end

-- ------- Soft score (EXP_SMART) ---------------------------------------------
-- Score polarity: lower is better. Prefer subtracts; dumps add.

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

  -- Decaying per-move weight: after an opener is used its score penalty rises,
  -- then falls 1 per AI turn back to baseline (no permanent try-once ban).
  score = score + moveWeightPenalty(user, def.id)

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
  if (effect == "POISON_EFFECT" or effect == "POISON_SIDE_EFFECT1"
      or effect == "POISON_SIDE_EFFECT2")
      and (hasType(target.curTypes, "POISON") or hasType(target.curTypes, "STEEL")) then
    return score + 6
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
      score = score - 1
    elseif row and row < 10 then
      score = score + 1
    end
    -- Soft anti-repeat: nudge off the same attack so they mix moves.
    if def.id and user.expAiLastMoveId == def.id then
      score = score + 1
    end
    return applySoftSituation(view, def, score, power)
  end

  -- Major status / confusion: mild healthy prefer at baseline weight; decay
  -- penalty above handles not chaining the same opener every turn.
  if STATUS_EFFECTS[effect] and target.mon and not target.mon.status then
    if userHp > 0.5 then
      score = score - 1
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
      -- Self setup: mild once while unboosted; dump under residual chip.
      if hasResidual(user) then
        score = score + 3
      elseif cur < 1 and userHp > 0.4 then
        score = score - 1
      elseif cur >= 1 then
        score = score + 2
      end
    else
      -- Foe drops: mild once at 0; hard dumps above stop the spam.
      if cur >= 0 and userHp > 0.4 then
        score = score - 1
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

  return applySoftSituation(view, def, score, power)
end

-- ------- Tactical score (lite / elite) --------------------------------------
-- Score polarity: lower is better (same as soft/natural).

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

  -- Belt-and-suspenders: never double-sleep / stack major status (Gen 1 AI fail).
  if power == 0 and STATUS_EFFECTS[effect] and target.mon and target.mon.status then
    return score + 6
  end
  if CONFUSE_EFFECTS[effect] and target.confusedTurns then
    return score + 6
  end
  if effect == "LEECH_SEED_EFFECT"
     and (target.leechSeeded or hasType(target.curTypes, "GRASS")) then
    return score + 6
  end
  if (effect == "POISON_EFFECT" or effect == "POISON_SIDE_EFFECT1"
      or effect == "POISON_SIDE_EFFECT2")
      and (hasType(target.curTypes, "POISON") or hasType(target.curTypes, "STEEL")) then
    return score + 6
  end

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

    -- Lite anti-repeat (elite stays sharp on the best KO tool).
    if mode == "lite" and def.id and user.expAiLastMoveId == def.id then
      if not (mid and targetHp > 0 and mid >= targetHp) then
        score = score + 1
      end
    end

    -- Priority move finish bonus
    if PRIORITY_MOVES[def.id] or effect == "EXP_PRIORITY_EFFECT" or (def.priority and def.priority > 0) then
      if mid and targetHp > 0 and mid >= targetHp then
        score = score - (mode == "elite" and 5 or 3)
      elseif not TrainerAi.isAiFaster(view.battle) and targetHp > 0 then
        score = score - (mode == "elite" and 3 or 1)
      end
    end

    -- Gen 1 Hyper Beam KO finish bonus (skips recharge in Gen 1 on KO)
    if def.id == "HYPER_BEAM" or effect == "HYPER_BEAM_EFFECT" then
      if mid and targetHp > 0 and mid >= targetHp then
        score = score - (mode == "elite" and 4 or 2)
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
    -- Lite situational: capitalize when foe is already disrupted.
    if mode == "lite" then
      local sit = TrainerAi.situation(view, "lite")
      if (sit.foeStatus or sit.foeConfused) and mid then
        score = score - 1
      end
    end
    return score
  end

  -- Non-damaging under pressure: dump setup/status when a KO is on the board or foe is low.
  local canKo = pressure.midKo or (mode == "elite" and pressure.highKo)
  local foeLow = target.mon and target.mon.stats and target.mon.stats.hp > 0
    and (target.mon.hp / target.mon.stats.hp) <= 0.4
  local sit = TrainerAi.situation(view, mode)
  if canKo or (mode == "elite" and foeLow) or (mode == "lite" and sit.threatened) then
    if STATUS_EFFECTS[effect] or CONFUSE_EFFECTS[effect]
       or STAGE_EFFECTS[effect] or SCREEN_EFFECTS[effect]
       or effect == "SUBSTITUTE_EFFECT" or effect == "LEECH_SEED_EFFECT" then
      score = score + (mode == "elite" and 4 or 2)
    end
  end

  -- Self-setup gating: dump if user HP < 50%, foe low, threatened, or residual.
  local stageInfo = STAGE_EFFECTS[effect]
  if stageInfo and stageInfo[2] > 0 then
    if userHp < 0.5 or foeLow or hasResidual(user)
        or (mode == "lite" and sit.threatened) then
      score = score + (mode == "elite" and 4 or 2)
    end
  end

  -- Lite speed control: slower and cannot KO → slight prefer para / speed drop.
  if mode == "lite" and not canKo and sit.faster == false then
    if effect == "PARALYZE_EFFECT" then
      score = score - 1
    elseif stageInfo and stageInfo[1] == "speed" and stageInfo[2] < 0 then
      score = score - 1
    end
  end
  if mode == "lite" and canKo and sit.faster == true then
    if effect == "PARALYZE_EFFECT"
       or (stageInfo and stageInfo[1] == "speed") then
      score = score + 1
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

-- Like TrainerAI.chooseMove, but any move within `margin` of the best score
-- stays eligible. Soft/lite use margin 1 so near-best attacks mix instead of
-- locking the single strongest move every turn.
function TrainerAi.chooseWithMargin(battler, rng, battle, margin)
  rng = rng or love.math.random
  margin = margin or 0
  TrainerAi.decayMoveWeights(battler)
  local unlimited = battle and battle.ruleset and battle.ruleset.enemyUnlimitedPP
  local usable = {}
  for i, mv in ipairs(battler.curMoves) do
    if battler.disabledSlot ~= i and (unlimited or mv.pp > 0) then
      usable[#usable + 1] = mv
    end
  end
  if #usable == 0 then
    return { id = "STRUGGLE", pp = 1, struggle = true }
  end

  local encourageTurn = (battler.aiLayer2 or 0) == 1
  battler.aiLayer2 = (battler.aiLayer2 or 0) + 1

  local mods = battle and battle.enemyAIMods or nil
  if not mods or #mods == 0 or not battle then
    return usable[rng(1, #usable)]
  end

  local classes = battle.data and battle.data.ai_classes
  local layers, view = {}, nil
  for _, modId in ipairs(mods) do
    local id = type(modId) == "string" and modId or ("LAYER_" .. tostring(modId))
    local record = classes and classes[id]
    if not (record and record.score) then record = TrainerAI.LAYERS[id] end
    if record and record.score then
      layers[#layers + 1] = record.score
      view = view or {
        battle = battle, user = battler, target = battle.player,
        data = battle.data, rng = rng, encourageTurn = encourageTurn,
      }
    end
  end

  local scores = {}
  for i, mv in ipairs(usable) do
    local def = battle.data.moves[mv.id]
    local s = 10
    for _, score in ipairs(layers) do
      s = score(view, def, s) or s
    end
    scores[i] = s
  end
  local best = math.huge
  for _, s in ipairs(scores) do
    if s < best then best = s end
  end
  local pool = {}
  for i, s in ipairs(scores) do
    if s <= best + margin then
      pool[#pool + 1] = usable[i]
    end
  end
  if #pool == 1 then return pool[1] end
  return pool[rng(1, #pool)]
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

function TrainerAi.bestSwitchIndex(battle)
  local player = battle.player
  local data = battle.data
  if not player or not data then return nil, 0, 0 end
  local outCurrent = bestDamageVs(battle, battle.enemy, player)
  local inCurrent = bestDamageVs(battle, player, battle.enemy)
  -- Matchup value: outgoing pressure minus half incoming (walls/resists that
  -- sponge can win even with middling offense — matters for Agatha etc.).
  local function matchup(outgoing, incoming)
    return outgoing - math.floor((incoming or 0) * 0.5)
  end
  local current = matchup(outCurrent, inCurrent)
  local bestIdx, bestScore = nil, current
  for i, mon in ipairs(battle.enemyParty or {}) do
    if mon.hp > 0 and i ~= battle.enemyIndex then
      local bat = partyBattler(data, mon)
      local outgoing = bestDamageVs(battle, bat, player)
      local incoming = bestDamageVs(battle, player, bat)
      -- Don't switch into a KO! Backup must survive player's attack (hp > damage * 1.25).
      if mon.hp > incoming * 1.25 then
        local score = matchup(outgoing, incoming)
        if score > bestScore then
          bestScore = score
          bestIdx = i
        end
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

  -- =========================================================================
  -- RULE 1: ABSOLUTE KO PRIORITY OVER ITEMS & SWITCHES
  -- If AI has ANY move that can KO player this turn, force attack immediately!
  -- =========================================================================
  if canKo then
    return nil
  end

  local playerDmg = TrainerAi.playerMaxDamage(battle)
  local aiFaster = TrainerAi.isAiFaster(battle)

  -- Full Heal / status clear when it actually matters and is safe.
  local status = enemy.mon.status
  if status and (theme.fullHealUrgency or status == "SLP" or status == "FRZ"
      or status == "PAR" or status == "BRN") then
    -- Don't use status item if player will KO AI on this turn anyway.
    if playerDmg < enemy.mon.hp and canUseItem(battle, theme) then
      local item, class = classItem(battle)
      if class and class.onStatus and class.item then
        recordItemUsed(battle, class.item)
        return { special = "aiItem", item = class.item }
      end
      if item == "FULL_HEAL" or item == "FULL_RESTORE" then
        recordItemUsed(battle, item)
        return { special = "aiItem", item = item }
      end
      if theme.fullHealUrgency then
        recordItemUsed(battle, "FULL_HEAL")
        return { special = "aiItem", item = "FULL_HEAL" }
      end
    end
  end

  -- Matchup switch: current is clearly worse than a backup.
  local switchBias = theme.switchBias or 1
  local bestIdx, bestScore, currentScore = TrainerAi.bestSwitchIndex(battle)
  if bestIdx then
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

  -- =========================================================================
  -- RULE 2: SMART HEALING & ANTI-HEAL TRAP PROTECTION
  -- =========================================================================
  local healThreshold = theme.greedyItems and 0.45 or 0.35
  if userHp <= healThreshold and canUseItem(battle, theme) then
    -- Anti-Heal Trap check:
    -- If player is faster and can KO AI before AI moves, or if player's attack
    -- strips >= 75% of healed HP (so AI remains in critical HP post-heal without turn gain),
    -- do NOT waste the item!
    local isTrapped = false
    if not aiFaster then
      if playerDmg >= enemy.mon.hp then
        isTrapped = true -- OHKO'd before heal can land
      else
        local maxHp = (enemy.mon.stats and enemy.mon.stats.hp) or 100
        local postHealHp = math.min(maxHp, enemy.mon.hp + math.floor(maxHp * 0.75))
        if playerDmg >= postHealHp * 0.75 then
          isTrapped = true -- Player damage invalidates heal
        end
      end
    end

    if not isTrapped then
      local heal = hasUsableHealItem(battle)
      if heal then
        recordItemUsed(battle, heal)
        return { special = "aiItem", item = heal }
      end
      local item = classItem(battle)
      if item and HEAL_ITEMS[item] then
        recordItemUsed(battle, item)
        return { special = "aiItem", item = item }
      end
      if theme.greedyItems then
        recordItemUsed(battle, "FULL_RESTORE")
        return { special = "aiItem", item = "FULL_RESTORE" }
      end
    end
  end

  -- =========================================================================
  -- RULE 3: SMART X-ITEMS / GUARD SPEC GATING
  -- Only use X-items when AI is healthy (>70% HP), turn 1 of mon, and foe threat is low (<25% HP).
  -- =========================================================================
  if userHp > 0.70 and canUseItem(battle, theme) then
    local maxHp = (enemy.mon.stats and enemy.mon.stats.hp) or 100
    local foeLowThreat = playerDmg < maxHp * 0.25 or (battle.player and battle.player.mon and (battle.player.mon.status == "SLP" or battle.player.mon.status == "FRZ"))
    if foeLowThreat then
      local item = classItem(battle)
      local xStat = item and X_ITEMS[item]
      if xStat and stageOf(enemy, xStat) < 1 then
        recordItemUsed(battle, item)
        return { special = "aiItem", item = item }
      end
      if item == "GUARD_SPEC" and not enemy.mist then
        recordItemUsed(battle, item)
        return { special = "aiItem", item = item }
      end
    end
  end

  return nil
end

function TrainerAi.liteAction(battle)
  if not battle or battle.kind ~= "trainer" then return nil end
  if (battle.aiUses or 0) <= 0 then return nil end
  local enemy = battle.enemy
  if not enemy or not enemy.mon then return nil end

  local theme = themeFor(battle)
  local pressure = boardPressure({
    user = enemy, target = battle.player, battle = battle, data = battle.data,
  }, "lite")
  if pressure.midKo then
    return nil -- Absolute KO Priority for Lite tier as well
  end

  -- Emergency heal only; max 1 item total per battle for Lite class.
  if hpRatio(enemy) <= 0.25 and canUseItem(battle, theme) then
    local playerDmg = TrainerAi.playerMaxDamage(battle)
    if playerDmg < enemy.mon.hp then
      local item, class = classItem(battle)
      if item and HEAL_ITEMS[item] then
        recordItemUsed(battle, item)
        return { special = "aiItem", item = item }
      end
      if class and class.item and HEAL_ITEMS[class.item] then
        recordItemUsed(battle, class.item)
        return { special = "aiItem", item = class.item }
      end
    end
  end
  return nil
end

-- ------- Register / install -------------------------------------------------

function TrainerAi.register(mod)
  mod.content.ai_classes:register(TrainerAi.LAYER_NATURAL, {
    kind = "layer",
    score = TrainerAi.scoreNatural,
  })
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
      battle.expBattleItemsUsed = 0
      battle.expMonItemsUsed = {}
    end
    return battle
  end

  local originalNewWild = BattleState.newWild
  BattleState.newWild = function(game, species, level, opts)
    local battle = originalNewWild(game, species, level, opts)
    if battle then
      battle.expMapId = currentMapId(game)
      battle.expWildSpecies = species
    end
    return battle
  end

  -- Retarget queued actions to the live side battlers. Older engines
  -- captured battler refs in resolveTurn; an AI switch then left the
  -- player's move hitting the withdrawn mon (SE text, no visible HP loss).
  -- Current engines already refresh in resolveTurn; this wrap is idempotent.
  if not BattleState._krLiveBattlerRetarget then
    BattleState._krLiveBattlerRetarget = true
    local originalExecute = BattleState.executeAction
    BattleState.executeAction = function(self, user, target, action)
      if user then
        user = user.isPlayer and self.player or self.enemy
      end
      if target then
        target = target.isPlayer and self.player or self.enemy
      end
      return originalExecute(self, user, target, action)
    end
  end

  -- Voluntary-switch free-hit timing (see SWITCH_LOCK_OPTION).
  -- When set to Gen 3, lock the AI action against the outgoing mon;
  -- Gen 1 leaves the engine's post-send-out pick alone.
  if not BattleState._krGen3SwitchLock then
    BattleState._krGen3SwitchLock = true
    local originalResolveSwitch = BattleState.resolveSwitch
    BattleState.resolveSwitch = function(self, newMon)
      local skipFree = (self.player and self.player.expBatonPass)
          or (self.player and self.player.expWantsSwitch)
          or self.expSkipNextEnemyAction
      if not skipFree and TrainerAi.switchLockGen3(mod) then
        local locked = self:enemyAction()
        self.enemyAction = function()
          self.enemyAction = nil
          return locked
        end
      end
      return originalResolveSwitch(self, newMon)
    end
  end

  -- Inject tier layers into chooseMove.
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
    local tier = TrainerAi.tier(battle)
    if tier == "natural" then
      appendLayer(mods, TrainerAi.LAYER_NATURAL)
    else
      appendLayer(mods, TrainerAi.LAYER_ID)
      if tier == "elite" then
        appendLayer(mods, TrainerAi.LAYER_TACTICAL)
      elseif tier == "lite" then
        appendLayer(mods, TrainerAi.LAYER_TACTICAL_LITE)
      end
    end
    battle.enemyAIMods = mods
    -- Natural: wide margin (messy). Soft/lite: near-best. Elite: exact.
    local margin = 1
    if tier == "elite" then
      margin = 0
    elseif tier == "natural" then
      margin = 2
    end
    local ok, result = pcall(TrainerAi.chooseWithMargin, battler, rng, battle, margin)
    battle.enemyAIMods = saved
    if not ok then error(result) end
    if result and battler then
      battler.expAiLastMoveId = result.id
      local def = battle.data and battle.data.moves and battle.data.moves[result.id]
      -- Natural stays messy (no decay). Soft/lite/elite cool openers after use.
      if tier ~= "natural" and def then
        TrainerAi.bumpMoveWeight(battler, result.id, softDecayBump(def, tier))
      end
    end
    return result
  end

  -- Elite / lite actions replace vanilla classAction for those tiers.
  mod.hooks:wrap("battle.enemy_action", function(next, battle)
    if not TrainerAi.enabled(mod) then return next(battle) end
    local tier = TrainerAi.tier(battle)
    if tier == "soft" or tier == "natural" then return next(battle) end

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
