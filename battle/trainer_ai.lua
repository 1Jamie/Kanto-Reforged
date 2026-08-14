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
-- classic (stored as "gen1"): pick after send-out (engine / pre-Gen3 timing).
-- gen3: lock AI move against the outgoing mon, then land it on the switch-in.
TrainerAi.SWITCH_LOCK_KEY = "switch_hit_ai"
TrainerAi.SWITCH_LOCK_GEN3 = "gen3"
TrainerAi.SWITCH_LOCK_GEN1 = "gen1" -- classic timing value (label is host-aware)

local function switchLockOption(classicLabel)
  return {
    key = TrainerAi.SWITCH_LOCK_KEY,
    label = "SWITCH HIT AI",
    type = "choice",
    default = TrainerAi.SWITCH_LOCK_GEN1,
    choices = {
      { classicLabel, TrainerAi.SWITCH_LOCK_GEN1 },
      { "GEN 3", TrainerAi.SWITCH_LOCK_GEN3 },
    },
  }
end

-- Red/Blue: GEN 1 vs GEN 3. Gold: GEN 2 vs GEN 3 (same stored values).
TrainerAi.SWITCH_LOCK_OPTION = switchLockOption("GEN 1")
TrainerAi.SWITCH_LOCK_OPTION_GEN2 = switchLockOption("GEN 2")

function TrainerAi.switchLockOptionForHost()
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then return TrainerAi.SWITCH_LOCK_OPTION_GEN2 end
  return TrainerAi.SWITCH_LOCK_OPTION
end

function TrainerAi.enabled(mod)
  return mod and mod.options and mod.options:get(TrainerAi.OPTION_KEY) and true or false
end

function TrainerAi.switchLockGen3(mod)
  if not mod or not mod.options then return false end
  return mod.options:get(TrainerAi.SWITCH_LOCK_KEY) == TrainerAi.SWITCH_LOCK_GEN3
end

-- ------- Tier rosters -------------------------------------------------------

-- Classes where every party index is elite (rivals).
local ELITE_ALL_PARTIES = {
  OPP_RIVAL1 = true,
  OPP_RIVAL2 = true,
  OPP_RIVAL3 = true,
  RIVAL1 = true,
  RIVAL2 = true,
  RIVAL3 = true,
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
  -- Johto / Gold class ids (no OPP_ prefix)
  BROCK = { [1] = true },
  MISTY = { [1] = true },
  FALKNER = { [1] = true },
  BUGSY = { [1] = true },
  WHITNEY = { [1] = true },
  MORTY = { [1] = true },
  CHUCK = { [1] = true },
  JASMINE = { [1] = true },
  PRYCE = { [1] = true },
  CLAIR = { [1] = true },
  LT_SURGE = { [1] = true },
  ERIKA = { [1] = true },
  JANINE = { [1] = true },
  SABRINA = { [1] = true },
  BLAINE = { [1] = true },
  BLUE = { [1] = true },
  WILL = { [1] = true },
  KOGA = { [1] = true },
  BRUNO = { [1] = true },
  KAREN = { [1] = true },
  LANCE = { [1] = true },
  RED = { [1] = true },
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
  -- Johto gyms
  VIOLET_GYM = true,
  AZALEA_GYM = true,
  GOLDENROD_GYM = true,
  ECRUTEAK_GYM = true,
  CIANWOOD_GYM = true,
  OLIVINE_GYM = true,
  MAHOGANY_GYM = true,
  BLACKTHORN_GYM = true,
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
  COOLTRAINERM = true,
  COOLTRAINERF = true,
  BLACKBELT_T = true,
  PSYCHIC_T = true,
  JUGGLER = true,
  SCIENTIST = true,
  BOARDER = true,
  SKIER = true,
  EXECUTIVE_M = true,
  EXECUTIVE_F = true,
  GRUNTM = true,
  GRUNTF = true,
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
-- Gold class ids share the same themes (no OPP_ prefix / Johto leaders).
THEMES.BROCK = THEMES.OPP_BROCK
THEMES.MISTY = THEMES.OPP_MISTY
THEMES.LT_SURGE = THEMES.OPP_LT_SURGE
THEMES.ERIKA = THEMES.OPP_ERIKA
THEMES.KOGA = THEMES.OPP_KOGA
THEMES.SABRINA = THEMES.OPP_SABRINA
THEMES.BLAINE = THEMES.OPP_BLAINE
THEMES.LORELEI = THEMES.OPP_LORELEI
THEMES.BRUNO = THEMES.OPP_BRUNO
THEMES.AGATHA = THEMES.OPP_AGATHA
THEMES.LANCE = THEMES.OPP_LANCE
THEMES.BLUE = THEMES.OPP_RIVAL3
THEMES.RED = THEMES.OPP_RIVAL3
THEMES.RIVAL1 = { preferSE = 1 }
THEMES.RIVAL2 = { preferSE = 1, preferKO = 1 }
THEMES.WILL = { preferStatus = 1, preferType = "PSYCHIC" }
THEMES.KAREN = { preferType = "DARK", preferStatus = 1 }
THEMES.FALKNER = { preferType = "FLYING", preferSpeed = 1 }
THEMES.BUGSY = { preferType = "BUG" }
THEMES.WHITNEY = { preferType = "NORMAL", preferStatus = 1 }
THEMES.MORTY = { preferType = "GHOST", preferStatus = 1 }
THEMES.CHUCK = { preferType = "FIGHTING", preferAttack = 1 }
THEMES.JASMINE = { preferType = "STEEL", preferDefense = 1 }
THEMES.PRYCE = { preferType = "ICE", preferStatus = 1 }
THEMES.CLAIR = { preferType = "DRAGON", preferSE = 1 }
THEMES.JANINE = { preferPoison = 1, preferStatus = 1 }
TrainerAi.THEMES = THEMES

function TrainerAi.isElite(oppClass, partyIndex)
  if not oppClass then return false end
  if ELITE_ALL_PARTIES[oppClass] then return true end
  local parties = ELITE_PARTIES[oppClass]
  if not parties then return false end
  -- Gen2 battles often carry a string memberId (RIVAL1_1_CHIKORITA) instead
  -- of a numeric party slot. Gold elite rosters are [1]-keyed; map unknowns
  -- to slot 1 so gym leaders/E4 are not silently downgraded to lite.
  local idx = partyIndex
  if type(idx) ~= "number" then idx = 1 end
  return parties[idx] and true or false
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
  -- Gold / Gen2 effect ids
  EFFECT_SLEEP = true, EFFECT_POISON = true, EFFECT_TOXIC = true,
  EFFECT_PARALYZE = true, EFFECT_BURN = true, EFFECT_FREEZE = true,
  EFFECT_SLEEP_HIT = true,
}

local CONFUSE_EFFECTS = {
  CONFUSION_EFFECT = true,
  EXP_ATTRACT_EFFECT = true,
  EXP_SWAGGER_EFFECT = true,
  EFFECT_CONFUSE = true,
  EFFECT_CONFUSE_HIT = true,
  EFFECT_SWAGGER = true,
  EFFECT_ATTRACT = true,
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
  -- Gold / Gen2
  EFFECT_ATTACK_UP = { "attack", 1 },
  EFFECT_DEFENSE_UP = { "defense", 1 },
  EFFECT_SP_ATK_UP = { "specialAttack", 1 },
  EFFECT_EVASION_UP = { "evasion", 1 },
  EFFECT_ATTACK_UP_2 = { "attack", 1 },
  EFFECT_DEFENSE_UP_2 = { "defense", 1 },
  EFFECT_SPEED_UP_2 = { "speed", 1 },
  EFFECT_SP_DEF_UP_2 = { "specialDefense", 1 },
  EFFECT_DEFENSE_CURL = { "defense", 1 },
  EFFECT_ATTACK_DOWN = { "attack", -1 },
  EFFECT_DEFENSE_DOWN = { "defense", -1 },
  EFFECT_SPEED_DOWN = { "speed", -1 },
  EFFECT_ACCURACY_DOWN = { "accuracy", -1 },
  EFFECT_EVASION_DOWN = { "evasion", -1 },
  EFFECT_ATTACK_DOWN_2 = { "attack", -1 },
  EFFECT_DEFENSE_DOWN_2 = { "defense", -1 },
  EFFECT_SPEED_DOWN_2 = { "speed", -1 },
}

local SCREEN_EFFECTS = {
  LIGHT_SCREEN_EFFECT = "lightScreen",
  REFLECT_EFFECT = "reflect",
  MIST_EFFECT = "mist",
  FOCUS_ENERGY_EFFECT = "focusEnergy",
  EXP_SAFEGUARD_EFFECT = "expSafeguard",
  EFFECT_LIGHT_SCREEN = "lightScreen",
  EFFECT_REFLECT = "reflect",
  EFFECT_MIST = "mist",
  EFFECT_FOCUS_ENERGY = "focusEnergy",
  EFFECT_SAFEGUARD = "expSafeguard",
}

local LEECH_SEED_EFFECTS = {
  LEECH_SEED_EFFECT = true,
  EFFECT_LEECH_SEED = true,
}

local HEAL_SELF_EFFECTS = {
  HEAL_EFFECT = true,
  EFFECT_HEAL = true,
  EFFECT_MORNING_SUN = true,
  EFFECT_SYNTHESIS = true,
  EFFECT_MOONLIGHT = true,
  EFFECT_SOFTBOILED = true,
  EFFECT_REST = true,
}

local SUBSTITUTE_EFFECTS = {
  SUBSTITUTE_EFFECT = true,
  EFFECT_SUBSTITUTE = true,
}

local DISABLE_EFFECTS = {
  DISABLE_EFFECT = true,
  EFFECT_DISABLE = true,
}

local function softOpenerEffect(effect)
  return STATUS_EFFECTS[effect] or CONFUSE_EFFECTS[effect]
    or STAGE_EFFECTS[effect] or LEECH_SEED_EFFECTS[effect]
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
  X_SPECIAL = "specialAttack", X_SP_ATK = "specialAttack",
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

local function stageOf(battler, stat, battle)
  if not battler then return 0 end
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local key = BattleCompat.stageStat(stat, battle or (battler and battler._krBattle))
  local stages = battler.stages
  if stages then
    if stages[key] ~= nil then return stages[key] end
    -- Gen1 "special" vs Gen2 specialAttack fallback either direction.
    if key == "specialAttack" and stages.special ~= nil then return stages.special end
    if key == "special" and stages.specialAttack ~= nil then return stages.specialAttack end
    return stages[key] or 0
  end
  return 0
end

local function hpRatio(battler)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local mon = BattleCompat.mon(battler)
  if not mon then return 1 end
  local maxHp = (mon.stats and mon.stats.hp) or mon.maxHp or 0
  if maxHp <= 0 then return 1 end
  return (mon.hp or 0) / maxHp
end

-- Residual chip that makes self-setup suicidal next turns.
local function hasResidual(battler, battle)
  if not battler then return false end
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  if BattleCompat.isSeeded(battle, battler) then return true end
  return BattleCompat.hasStatus(battler, "PSN", "BRN", "TOX", "poison", "burn", "toxic")
end

local function themeFor(battle)
  local class = battle and (battle.oppClass or (battle.trainer and (
    battle.trainer.classId or battle.trainer.class or battle.trainer.id)))
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

local function aiRng(battle)
  if battle and type(battle.rng) == "function" then return battle.rng end
  if battle and type(battle.random) == "function" then
    -- Gen2 BattleRandom is 0..n-1; adapt to love-style 1..n / lo..hi.
    return function(lo, hi)
      if hi == nil then
        local n = lo or 1
        return (battle.random(n) or 0) + 1
      end
      local span = hi - lo + 1
      return lo + (battle.random(span) or 0)
    end
  end
  return love and love.math and love.math.random or math.random
end

-- Mid-roll and high-roll damage estimates (no crit). Returns mid, high, typeMult.
-- Returns nil mid when the move is non-damaging or battlers lack stats.
function TrainerAi.estimateDamage(battle, attacker, defender, moveDef, opts)
  opts = opts or {}
  if not moveDef or (moveDef.power or 0) <= 0 then return nil, nil, 10 end
  if not attacker or not defender then return nil, nil, 10 end
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  BattleCompat.prepareAiBattler(battle, attacker)
  BattleCompat.prepareAiBattler(battle, defender)
  if not attacker.curStats or not defender.curStats then return nil, nil, 10 end
  local aMon = BattleCompat.mon(attacker)
  if not aMon or not aMon.level then return nil, nil, 10 end

  local defTypes = defender.curTypes or BattleCompat.types(defender)
  local data = battle and battle.data
  if data and data.type_chart then
    pcall(TypeChart.load, data)
  end
  local mult = 10
  local okMult, got = pcall(TypeChart.effectiveness, moveDef.type, defTypes)
  if okMult and got then mult = got end

  if BattleCompat.isGen2(battle) then
    local ok, G2Damage = pcall(require, "src.battle.gen2.Damage")
    if not ok or not G2Damage or not G2Damage.calc then
      return nil, nil, mult
    end
    local chart = battle.data and battle.data.type_chart
    local typesTable = chart and chart.types
    local physical = G2Damage.isPhysical and G2Damage.isPhysical(moveDef.type, typesTable)
    if physical == nil then
      -- Fallback: Gen2 physical if not in special list — Damage.isPhysical is source of truth.
      physical = true
    end
    local atk = attacker.curStats.attack
    local spa = attacker.curStats.specialAttack or attacker.curStats.special
    -- Burn halves physical Attack (DamageStats / statusPenaltyFor).
    if physical and BattleCompat.hasStatus(attacker, "BRN", "burn") then
      atk = math.max(1, math.floor(atk / 2))
    end
    local weatherPercent = 10
    do
      local okE, Effects = pcall(require, "src.battle.gen2.Effects")
      if okE and Effects and Effects.weatherModifier and battle.weather then
        weatherPercent = math.floor(
          Effects.weatherModifier(battle.weather, moveDef.type, moveDef.effect) * 10)
      end
    end
    local screen = false
    if physical then
      screen = BattleCompat.hasScreen(battle, defender, "reflect")
    else
      screen = BattleCompat.hasScreen(battle, defender, "lightScreen")
    end
    local function roll(variation)
      local dmg = G2Damage.calc({
        level = aMon.level,
        power = moveDef.power,
        moveType = moveDef.type,
        attacker = {
          attack = atk,
          specialAttack = spa,
          types = attacker.curTypes or BattleCompat.types(attacker),
          stages = attacker.stages or {},
        },
        defender = {
          defense = defender.curStats.defense,
          specialDefense = defender.curStats.specialDefense
            or defender.curStats.special,
          types = defTypes,
          stages = defender.stages or {},
        },
        types = typesTable,
        matchups = chart and chart.matchups,
        critical = false,
        variation = variation,
        weatherPercent = weatherPercent,
        screen = screen,
      })
      return dmg or 0
    end
    local midDmg = roll(92)
    local highDmg = opts.highRoll and roll(100) or midDmg
    return midDmg, highDmg, mult
  end

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
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local targetHp = BattleCompat.hp(target)
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
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  if BattleCompat.hasStatus(battler, "PAR", "paralyze") then
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
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local sit = {
    mode = mode,
    userHp = hpRatio(user),
    foeHp = hpRatio(target),
    faster = nil,
    threatened = false,
    canKo = false,
    foeStatus = target and BattleCompat.status(target) or nil,
    foeConfused = target and BattleCompat.isConfused(view and view.battle, target) or false,
    foeSeeded = target and BattleCompat.isSeeded(view and view.battle, target) or false,
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
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local user, target = view.user, view.target
  local power = def.power or 0
  local effect = def.effect
  local stageInfo = STAGE_EFFECTS[effect]

  if stageInfo then
    local stat, dir = stageInfo[1], stageInfo[2]
    local cur = stageOf(dir < 0 and target or user, stat, view.battle)
    if dir < 0 then
      local isAccEva = (stat == "accuracy" or stat == "evasion")
      if isAccEva and cur <= -1 then return score + 6 end
      if not isAccEva and cur <= -2 then return score + 6 end
    else
      if cur >= 2 then return score + 6 end
    end
  end

  if power == 0 and STATUS_EFFECTS[effect] and BattleCompat.status(target) then
    return score + 6
  end
  if effect == "EXP_YAWN_EFFECT" then
    if BattleCompat.status(target) or target.expYawnTurns then
      return score + 6
    end
  end
  if CONFUSE_EFFECTS[effect] and BattleCompat.isConfused(view.battle, target) then
    return score + 6
  end
  if LEECH_SEED_EFFECTS[effect] then
    if BattleCompat.isSeeded(view.battle, target) or hasType(target.curTypes, "GRASS") then
      return score + 6
    end
  end
  if (effect == "POISON_EFFECT" or effect == "POISON_SIDE_EFFECT1"
      or effect == "POISON_SIDE_EFFECT2" or effect == "EFFECT_POISON"
      or effect == "EFFECT_TOXIC" or effect == "EFFECT_POISON_HIT")
      and (hasType(target.curTypes, "POISON") or hasType(target.curTypes, "STEEL")) then
    return score + 6
  end
  if HEAL_SELF_EFFECTS[effect] then
    local mon = BattleCompat.mon(user)
    local maxHp = mon and ((mon.stats and mon.stats.hp) or mon.maxHp or 0) or 0
    if mon and maxHp > 0 and (mon.hp or 0) >= maxHp then
      return score + 6
    end
  end
  local screenKey = SCREEN_EFFECTS[effect]
  if screenKey and BattleCompat.hasScreen(view.battle, user, screenKey) then
    return score + 6
  end
  if SUBSTITUTE_EFFECTS[effect] and BattleCompat.hasSubstitute(view.battle, user) then
    return score + 6
  end
  if DISABLE_EFFECTS[effect] and BattleCompat.disabledMoveId(view.battle, target) then
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
      or LEECH_SEED_EFFECTS[effect]
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
    if HEAL_SELF_EFFECTS[effect] or (power > 0 and isDrainEffect(effect)) then
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
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local user, target = view.user, view.target
  local power = def.power or 0
  local effect = def.effect
  local userHp = hpRatio(user)
  local stageInfo = STAGE_EFFECTS[effect]

  -- Stage moves: dump when already stacked; never leave a "dead zone" where
  -- a half-applied Sand Attack still outscores every attack forever.
  if stageInfo then
    local stat, dir = stageInfo[1], stageInfo[2]
    local cur = stageOf(dir < 0 and target or user, stat, view.battle)
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

  if power == 0 and STATUS_EFFECTS[effect] and BattleCompat.status(target) then
    return score + 6
  end
  if effect == "EXP_YAWN_EFFECT" then
    if BattleCompat.status(target) or target.expYawnTurns then
      return score + 6
    end
  end
  if CONFUSE_EFFECTS[effect] and BattleCompat.isConfused(view.battle, target) then
    return score + 6
  end
  if LEECH_SEED_EFFECTS[effect] then
    if BattleCompat.isSeeded(view.battle, target) or hasType(target.curTypes, "GRASS") then
      return score + 6
    end
  end
  if (effect == "POISON_EFFECT" or effect == "POISON_SIDE_EFFECT1"
      or effect == "POISON_SIDE_EFFECT2" or effect == "EFFECT_POISON"
      or effect == "EFFECT_TOXIC" or effect == "EFFECT_POISON_HIT")
      and (hasType(target.curTypes, "POISON") or hasType(target.curTypes, "STEEL")) then
    return score + 6
  end
  if HEAL_SELF_EFFECTS[effect] then
    local mon = BattleCompat.mon(user)
    local maxHp = mon and ((mon.stats and mon.stats.hp) or mon.maxHp or 0) or 0
    if mon and maxHp > 0 and (mon.hp or 0) >= maxHp then
      return score + 6
    end
  end
  local screenKey = SCREEN_EFFECTS[effect]
  if screenKey and BattleCompat.hasScreen(view.battle, user, screenKey) then
    return score + 6
  end
  if SUBSTITUTE_EFFECTS[effect] and BattleCompat.hasSubstitute(view.battle, user) then
    return score + 6
  end
  if DISABLE_EFFECTS[effect] and BattleCompat.disabledMoveId(view.battle, target) then
    return score + 6
  end

  if power > 0 then
    score = score - 1
    if hasType(user.curTypes, def.type) then
      score = score - 1
    end
    local row = TypeChart.rows(def.type, target.curTypes or {})[1]
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
  if STATUS_EFFECTS[effect] and not BattleCompat.status(target) then
    if userHp > 0.5 then
      score = score - 1
    end
  end

  if CONFUSE_EFFECTS[effect] and not BattleCompat.isConfused(view.battle, target) then
    if userHp > 0.5 then
      score = score - 1
    end
  end

  if LEECH_SEED_EFFECTS[effect]
     and not BattleCompat.isSeeded(view.battle, target)
     and not hasType(target.curTypes, "GRASS") then
    if userHp > 0.4 then
      score = score - 1
    end
  end

  if stageInfo then
    local stat, dir = stageInfo[1], stageInfo[2]
    local cur = stageOf(dir < 0 and target or user, stat, view.battle)
    if dir > 0 then
      -- Self setup: mild once while unboosted; dump under residual chip.
      if hasResidual(user, view.battle) then
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

  if screenKey and not BattleCompat.hasScreen(view.battle, user, screenKey) and userHp > 0.4 then
    score = score - 1
  end
  if SUBSTITUTE_EFFECTS[effect] and not BattleCompat.hasSubstitute(view.battle, user) and userHp > 0.4 then
    score = score - 1
  end

  if HEAL_SELF_EFFECTS[effect] then
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
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local userHp = hpRatio(user)
  local targetHp = BattleCompat.hp(target)
  local pressure = boardPressure(view, mode)
  local theme = (mode == "elite" and themeFor(view.battle)) or {}
  local coarse = mode == "lite"
  local koBias = mode == "elite" and 4 or 2
  if theme.preferKO then koBias = koBias + theme.preferKO end

  -- Belt-and-suspenders: never double-sleep / stack major status (Gen 1 AI fail).
  if power == 0 and STATUS_EFFECTS[effect] and BattleCompat.status(target) then
    return score + 6
  end
  if CONFUSE_EFFECTS[effect] and BattleCompat.isConfused(view.battle, target) then
    return score + 6
  end
  if LEECH_SEED_EFFECTS[effect]
     and (BattleCompat.isSeeded(view.battle, target) or hasType(target.curTypes, "GRASS")) then
    return score + 6
  end
  if (effect == "POISON_EFFECT" or effect == "POISON_SIDE_EFFECT1"
      or effect == "POISON_SIDE_EFFECT2" or effect == "EFFECT_POISON"
      or effect == "EFFECT_TOXIC" or effect == "EFFECT_POISON_HIT")
      and (hasType(target.curTypes, "POISON") or hasType(target.curTypes, "STEEL")) then
    return score + 6
  end

  -- Dual-type effectiveness (replaces first-row soft SE for damaging).
  local typeMult = 10
  if power > 0 then
    typeMult = TypeChart.effectiveness(def.type, target.curTypes)
  end

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
        or LEECH_SEED_EFFECTS[effect]) then
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
  local foeLow = hpRatio(target) <= 0.4
  local sit = TrainerAi.situation(view, mode)
  if canKo or (mode == "elite" and foeLow) or (mode == "lite" and sit.threatened) then
    if STATUS_EFFECTS[effect] or CONFUSE_EFFECTS[effect]
       or STAGE_EFFECTS[effect] or SCREEN_EFFECTS[effect]
       or SUBSTITUTE_EFFECTS[effect] or LEECH_SEED_EFFECTS[effect] then
      score = score + (mode == "elite" and 4 or 2)
    end
  end

  -- Self-setup gating: dump if user HP < 50%, foe low, threatened, or residual.
  local stageInfo = STAGE_EFFECTS[effect]
  if stageInfo and stageInfo[2] > 0 then
    if userHp < 0.5 or foeLow or hasResidual(user, view.battle)
        or (mode == "lite" and sit.threatened) then
      score = score + (mode == "elite" and 4 or 2)
    end
  end

  -- Lite speed control: slower and cannot KO → slight prefer para / speed drop.
  if mode == "lite" and not canKo and sit.faster == false then
    if effect == "PARALYZE_EFFECT" or effect == "EFFECT_PARALYZE"
        or effect == "EFFECT_PARALYZE_HIT" then
      score = score - 1
    elseif stageInfo and stageInfo[1] == "speed" and stageInfo[2] < 0 then
      score = score - 1
    end
  end
  if mode == "lite" and canKo and sit.faster == true then
    if effect == "PARALYZE_EFFECT" or effect == "EFFECT_PARALYZE"
        or effect == "EFFECT_PARALYZE_HIT"
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
    if (effect == "PARALYZE_EFFECT" or effect == "EFFECT_PARALYZE"
        or effect == "EFFECT_PARALYZE_HIT") and theme.preferPara then
      score = score - theme.preferPara
    end
    if (effect == "POISON_EFFECT" or effect == "POISON_SIDE_EFFECT1"
        or effect == "POISON_SIDE_EFFECT2" or effect == "EFFECT_POISON"
        or effect == "EFFECT_TOXIC" or effect == "EFFECT_POISON_HIT")
        and theme.preferPoison then
      score = score - theme.preferPoison
    end
    if LEECH_SEED_EFFECTS[effect] and theme.preferSeed then
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
        or DISABLE_EFFECTS[effect]) then
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
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  -- Dig/Fly charge, Rollout/Thrash, Encore: no free choice this turn.
  local forcedId = BattleCompat.forcedMoveId(battle, battler)
  if forcedId then
    local moves = battler.curMoves or battler.moves or {}
    for _, mv in ipairs(moves) do
      if mv.id == forcedId then return mv end
    end
    return { id = forcedId, pp = 1 }
  end
  local unlimited = battle and battle.ruleset and battle.ruleset.enemyUnlimitedPP
  local usable = {}
  local fromEngine = BattleCompat.usableMoves(battle, battler)
  if fromEngine and #fromEngine > 0 then
    usable = fromEngine
  else
    local disabledId = BattleCompat.disabledMoveId(battle, battler)
    for i, mv in ipairs(battler.curMoves or {}) do
      if (not battler.disabledSlot or battler.disabledSlot ~= i)
          and (not disabledId or mv.id ~= disabledId)
          and (unlimited or (mv.pp or 0) > 0) then
        usable[#usable + 1] = mv
      end
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

  local classes = battle.data and (battle.data.ai_classes or battle.data.gen2AiClasses)
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

local function matchupScore(outgoing, incoming)
  -- Outgoing pressure minus half incoming (walls/resists that sponge can
  -- win even with middling offense — matters for Agatha etc.).
  return (outgoing or 0) - math.floor((incoming or 0) * 0.5)
end

local function slotMatchup(battle, mon, player)
  local bat = partyBattler(battle.data, mon)
  if not bat then return 0, 0 end
  local outgoing = bestDamageVs(battle, bat, player)
  local incoming = bestDamageVs(battle, player, bat)
  return matchupScore(outgoing, incoming), incoming
end

function TrainerAi.bestSwitchIndex(battle)
  local player = battle.player
  local data = battle.data
  if not player or not data then return nil, 0, 0 end
  local outCurrent = bestDamageVs(battle, battle.enemy, player)
  local inCurrent = bestDamageVs(battle, player, battle.enemy)
  local current = matchupScore(outCurrent, inCurrent)
  local bestIdx, bestScore = nil, current
  for i, mon in ipairs(battle.enemyParty or {}) do
    if mon.hp > 0 and i ~= battle.enemyIndex then
      local score, incoming = slotMatchup(battle, mon, player)
      -- Don't switch into a KO! Backup must survive player's attack (hp > damage * 1.25).
      if mon.hp > incoming * 1.25 then
        if score > bestScore then
          bestScore = score
          bestIdx = i
        end
      end
    end
  end
  return bestIdx, bestScore, current
end

-- Best healthy party slot to send out (faint replacement). Same matchup
-- math as voluntary elite switches, without a "beat the current mon" margin
-- — the current mon is already down.
function TrainerAi.bestSendOutIndex(battle)
  local player = battle.player
  local data = battle.data
  if not player or not data then return nil end
  local bestIdx, bestScore = nil, nil
  local bestSafe, bestSafeScore = nil, nil
  for i, mon in ipairs(battle.enemyParty or {}) do
    if type(mon) == "table" and (mon.hp or 0) > 0 then
      local score, incoming = slotMatchup(battle, mon, player)
      if not bestIdx or score > bestScore then
        bestIdx, bestScore = i, score
      end
      if mon.hp > incoming * 1.25 then
        if not bestSafe or score > bestSafeScore then
          bestSafe, bestSafeScore = i, score
        end
      end
    end
  end
  return bestSafe or bestIdx
end

-- Elite trainers that can mid-battle switch: pick the same slot a later
-- eliteAction switch would want, so faint send-out does not waste a turn.
function TrainerAi.faintSendOutIndex(battle)
  if not battle then return nil end
  if battle.wild or battle.kind == "wild" then return nil end
  if not (battle.trainer or battle.oppClass or battle.kind == "trainer") then
    return nil
  end
  if TrainerAi.tier(battle) ~= "elite" then return nil end
  return TrainerAi.bestSendOutIndex(battle)
end

local function hideOtherHealthy(party, keepIndex)
  local hidden = {}
  for i, mon in ipairs(party or {}) do
    if i ~= keepIndex and type(mon) == "table" and (mon.hp or 0) > 0 then
      hidden[i] = mon.hp
      mon.hp = 0
    end
  end
  return hidden
end

local function restoreHidden(party, hidden)
  for i, hp in pairs(hidden or {}) do
    if party and party[i] then party[i].hp = hp end
  end
end

-- Run `fn` so engine first-healthy scans land on `keepIndex`. Restores HP
-- before queued send-out UI (pokeballs) runs.
function TrainerAi.withForcedSendOut(battle, fn)
  local keep = battle and TrainerAi.faintSendOutIndex(battle)
  local party = battle and battle.enemyParty
  if not keep or not party or not party[keep] or (party[keep].hp or 0) <= 0 then
    return fn()
  end
  local first
  for i, mon in ipairs(party) do
    if (mon.hp or 0) > 0 then first = i break end
  end
  if first == keep then return fn() end
  local hidden = hideOtherHealthy(party, keep)
  local ok, a, b, c = pcall(fn)
  restoreHidden(party, hidden)
  if not ok then error(a, 0) end
  return a, b, c
end

local function classItem(battle)
  -- Gold trainers carry items on the trainer record; Gen1 uses ai_classes.
  local trainer = battle and battle.trainer
  if trainer and trainer.items then
    for _, item in ipairs(trainer.items) do
      if item then return item end
    end
  end
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
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  BattleCompat.prepareAiBattle(battle)
  local enemy = battle.enemy
  local enemyMon = BattleCompat.mon(enemy)
  if not enemy or not enemyMon then return nil end

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

  -- Absolute KO priority: fall through to move scoring. Gen2 specials are
  -- applied earlier via enemyTrySwitchOrItem wrap (not enemy_action).
  if canKo then
    return nil
  end

  local playerDmg = TrainerAi.playerMaxDamage(battle)
  local aiFaster = TrainerAi.isAiFaster(battle)

  -- Full Heal / status clear when it actually matters and is safe.
  local status = enemyMon.status
  if status and (theme.fullHealUrgency
      or status == "SLP" or status == "sleep"
      or status == "FRZ" or status == "freeze"
      or status == "PAR" or status == "paralyze"
      or status == "BRN" or status == "burn") then
    -- Don't use status item if player will KO AI on this turn anyway.
    if playerDmg < enemyMon.hp and canUseItem(battle, theme) then
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
      if playerDmg >= enemyMon.hp then
        isTrapped = true -- OHKO'd before heal can land
      else
        local maxHp = (enemyMon.stats and enemyMon.stats.hp) or 100
        local postHealHp = math.min(maxHp, enemyMon.hp + math.floor(maxHp * 0.75))
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
    local maxHp = (enemyMon.stats and enemyMon.stats.hp) or 100
    local foeLowThreat = playerDmg < maxHp * 0.25
      or (battle.player and battle.player.mon and (
        battle.player.mon.status == "SLP" or battle.player.mon.status == "sleep"
        or battle.player.mon.status == "FRZ" or battle.player.mon.status == "freeze"))
    if foeLowThreat then
      local item = classItem(battle)
      local xStat = item and X_ITEMS[item]
      if xStat and stageOf(enemy, xStat, battle) < 1 then
        recordItemUsed(battle, item)
        return { special = "aiItem", item = item }
      end
      if item == "GUARD_SPEC" and not BattleCompat.hasMist(battle, enemy) then
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
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  BattleCompat.prepareAiBattle(battle)
  local enemy = battle.enemy
  local enemyMon = BattleCompat.mon(enemy)
  if not enemy or not enemyMon then return nil end

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
    if playerDmg < enemyMon.hp then
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

local function appendLayer(mods, id)
  for _, m in ipairs(mods) do
    if m == id then return end
  end
  mods[#mods + 1] = id
end

--- Apply KR elite/lite specials on Gen2 Battle (items / switches).
function TrainerAi.applyGen2AiAction(battle, act)
  if not battle or not act or not act.special then return false end
  local enemy = battle.enemy
  if not enemy then return false end
  local trainerName = (battle.trainer and battle.trainer.name) or "TRAINER"

  if act.special == "aiSwitch" then
    local target = act.index
    if not target or not battle.enemyParty or not battle.enemyParty[target] then
      return false
    end
    if type(battle.clearVolatile) == "function" then
      pcall(function() battle:clearVolatile(enemy) end)
    end
    local outgoing = enemy
    if type(battle.emit) == "function" then
      battle:emit({ kind = "message",
        text = trainerName .. " withdrew " .. (battle:monName(outgoing) or "POKéMON") .. "!" })
    end
    battle.enemyIndex = target
    battle.enemy = battle.enemyParty[target]
    if type(battle.clearVolatile) == "function" then
      pcall(function() battle:clearVolatile(battle.enemy) end)
    end
    if battle.stages then
      local Battle = require("src.battle.gen2.Battle")
      battle.stages.enemy = Battle.newStages()
    end
    if type(battle.emit) == "function" then
      battle:emit({ kind = "send", side = "enemy", mon = battle.enemy,
        text = trainerName .. " sent out " .. (battle:monName(battle.enemy) or "POKéMON") .. "!" })
    end
    local Runtime = require("src.mods.Runtime")
    Runtime.emit("battle.battler_switched", {
      battle = battle,
      side = type(battle.sideRecord) == "function" and battle:sideRecord(battle.enemy) or nil,
      battler = battle.enemy,
      previous = outgoing,
    })
    if type(battle.breakTrapsOnSend) == "function" then
      pcall(function() battle:breakTrapsOnSend(battle.enemy) end)
    end
    if type(battle.spikesDamage) == "function" then
      pcall(function() battle:spikesDamage(battle.enemy) end)
    end
    battle.enemy.expJustEntered = true
    return true
  end

  if act.special == "aiItem" then
    local item = act.item
    if not item then return false end
    local maxHp = (enemy.stats and enemy.stats.hp) or enemy.maxHp or 1
    local HEAL = {
      FULL_RESTORE = math.huge, MAX_POTION = math.huge,
      HYPER_POTION = 200, SUPER_POTION = 50, POTION = 20,
    }
    local X_STAT = {
      X_ATTACK = "attack", X_DEFEND = "defense", X_SPEED = "speed",
      X_SPECIAL = "specialAttack", X_SP_ATK = "specialAttack",
    }
    if type(battle.heal) == "function" and HEAL[item] then
      local amount = HEAL[item]
      battle:heal(enemy, amount == math.huge and maxHp or amount)
      if item == "FULL_RESTORE" then
        enemy.status = nil
        if type(battle.volatile) == "function" then
          local vol = battle:volatile(enemy)
          if vol then vol.confuseCount = nil end
        end
      end
    elseif item == "FULL_HEAL" then
      enemy.status = nil
      if type(battle.volatile) == "function" then
        local vol = battle:volatile(enemy)
        if vol then vol.confuseCount = nil end
      end
    elseif X_STAT[item] and battle.stages and battle.stages.enemy then
      local key = X_STAT[item]
      local s = battle.stages.enemy
      s[key] = math.min(6, (s[key] or 0) + 1)
    elseif item == "GUARD_SPEC" then
      -- Gen2 mist lives on the volatile / screen side; Gen1 uses battler.mist.
      enemy.mist = true
      if type(battle.volatile) == "function" then
        local vol = battle:volatile(enemy)
        if vol then vol.mist = true end
      end
    else
      return false
    end
    if type(battle.emit) == "function" then
      local itemName = (battle.data and battle.data.items and battle.data.items[item]
        and battle.data.items[item].name) or item
      battle:emit({ kind = "message",
        text = trainerName .. " used " .. itemName .. "!" })
    end
    if battle.aiUses and battle.aiUses > 0 then
      battle.aiUses = battle.aiUses - 1
    end
    return true
  end

  return false
end

--- Shared move picker: attach EXP_* layers and chooseWithMargin.
function TrainerAi.pickScoredMove(mod, battle, rng, battler)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  BattleCompat.prepareAiBattle(battle)
  local enemy = battler or (battle and battle.enemy)
  if not enemy then return nil end
  if battle and not battle.enemy then battle.enemy = enemy end
  local tier = TrainerAi.tier(battle)
  local saved = battle.enemyAIMods
  local mods = {}
  if type(saved) == "table" then
    for i, m in ipairs(saved) do mods[i] = m end
  end
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
  local margin = 1
  if tier == "elite" then
    margin = 0
  elseif tier == "natural" then
    margin = 2
  end
  rng = rng or aiRng(battle)
  local ok, result = pcall(TrainerAi.chooseWithMargin, enemy, rng, battle, margin)
  battle.enemyAIMods = saved
  if not ok then error(result) end
  if result and enemy then
    enemy.expAiLastMoveId = result.id
    local def = battle.data and battle.data.moves and battle.data.moves[result.id]
    if tier ~= "natural" and def then
      TrainerAi.bumpMoveWeight(enemy, result.id, softDecayBump(def, tier))
    end
  end
  return result
end

-- Shared soft preferences (Fake Out / hazards / Taunt) for both gens.
local HAZARD_MOVES = {
  SPIKES = true, STEALTH_ROCK = true, TOXIC_SPIKES = true,
}
local FLUFF_MOVES = {
  GROWL = true, TAIL_WHIP = true, LEER = true, STRING_SHOT = true,
  SAND_ATTACK = true, SMOKESCREEN = true, FLASH = true,
}

local function movePp(mv)
  return type(mv) == "table" and (mv.pp or 1) or 1
end

local function moveIdOf(mv)
  return type(mv) == "table" and mv.id or mv
end

local function foeSideHazards(battle)
  local sides = battle.sides
  if not sides then return nil end
  return sides.player or sides[1]
end

local function hasHazard(side, id)
  if not side or not side.hazards then return false end
  for _, h in ipairs(side.hazards) do
    if h.id == id then return true end
  end
  return false
end

local function preferSharedSetup(battle, chosenId)
  local enemy = battle.enemy
  if not enemy then return chosenId end
  local moves = enemy.curMoves or enemy.moves
  if not moves then return chosenId end

  if enemy.expJustEntered then
    for _, mv in ipairs(moves) do
      local id = moveIdOf(mv)
      if id == "FAKE_OUT" and movePp(mv) > 0 then return id end
    end
  end

  -- Without a concrete choice, only Fake Out is forced above.
  if chosenId == nil then return nil end

  if battle.kind == "trainer" then
    local side = foeSideHazards(battle)
    local want = {
      STEALTH_ROCK = not hasHazard(side, "STEALTH_ROCK"),
      SPIKES = true,
      TOXIC_SPIKES = true,
    }
    if side and side.hazards then
      for _, h in ipairs(side.hazards) do
        if h.id == "SPIKES" then
          want.SPIKES = (h.layers or 1) < 3
        elseif h.id == "TOXIC_SPIKES" then
          want.TOXIC_SPIKES = (h.layers or 1) < 2
        end
      end
    end
    local isFluff = type(chosenId) ~= "string" or FLUFF_MOVES[chosenId]
    if not isFluff and type(chosenId) == "string" then
      local def = battle.data and battle.data.moves and battle.data.moves[chosenId]
      isFluff = def and (not def.power or def.power == 0)
        and not HAZARD_MOVES[chosenId] and chosenId ~= "TAUNT"
    end
    if isFluff then
      for _, mv in ipairs(moves) do
        local id = moveIdOf(mv)
        if HAZARD_MOVES[id] and movePp(mv) > 0 and want[id] then
          return id
        end
      end
      local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
      local foe = battle.player
      if foe and not BattleCompat.status(foe) then
        for _, mv in ipairs(moves) do
          local id = moveIdOf(mv)
          if id == "TAUNT" and movePp(mv) > 0 and not foe.expTauntedTurns then
            return "TAUNT"
          end
        end
      end
    end
  end
  return chosenId
end

-- ------- Register / install -------------------------------------------------

function TrainerAi.register(mod)
  -- Gold Ai.layersFor auto-includes every flagless kind=layer for any
  -- trainer with AI bits. These scorers expect Gen1 view.user/target and
  -- must only run via KR injection (enemyAIMods / pickScoredMove) — gate
  -- with a flag name that is never in Gen2 Ai.FLAGS.
  local krOnly = { kind = "layer", flag = "EXP_KR_ONLY" }
  mod.content.ai_classes:register(TrainerAi.LAYER_NATURAL, {
    kind = krOnly.kind, flag = krOnly.flag,
    score = TrainerAi.scoreNatural,
  })
  mod.content.ai_classes:register(TrainerAi.LAYER_ID, {
    kind = krOnly.kind, flag = krOnly.flag,
    score = TrainerAi.score,
  })
  mod.content.ai_classes:register(TrainerAi.LAYER_TACTICAL, {
    kind = krOnly.kind, flag = krOnly.flag,
    score = TrainerAi.scoreTactical,
  })
  mod.content.ai_classes:register(TrainerAi.LAYER_TACTICAL_LITE, {
    kind = krOnly.kind, flag = krOnly.flag,
    score = TrainerAi.scoreTacticalLite,
  })
end

local function currentMapId(game)
  local ow = game and game.overworld
  return ow and ow.map and ow.map.id or nil
end

function TrainerAi.install(mod)
  if TrainerAI._expansionSmartAi then return end
  local Host = require("mods.Kanto-Reforged.core.host")
  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")

  -- Gen1 engine wiring (metadata, switch-lock, live retarget).
  if Host.isGen1() then
    Gen1Patch.apply(require("src.battle.BattleState"), function(BattleState)
      local originalNewTrainer = BattleState.newTrainer
      if type(originalNewTrainer) == "function" then
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
      end

      local originalNewWild = BattleState.newWild
      if type(originalNewWild) == "function" then
        BattleState.newWild = function(game, species, level, opts)
          local battle = originalNewWild(game, species, level, opts)
          if battle then
            battle.expMapId = currentMapId(game)
            battle.expWildSpecies = species
          end
          return battle
        end
      end

      if not BattleState._krLiveBattlerRetarget and type(BattleState.executeAction) == "function" then
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

      if not BattleState._krGen3SwitchLock and type(BattleState.resolveSwitch) == "function" then
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

      if not BattleState._krEliteFaintSend and type(BattleState.enemyMonFainted) == "function" then
        BattleState._krEliteFaintSend = true
        local originalFaint = BattleState.enemyMonFainted
        BattleState.enemyMonFainted = function(self)
          if not TrainerAi.enabled(mod) then
            return originalFaint(self)
          end
          pcall(BattleCompat.prepareAiBattle, self)
          return TrainerAi.withForcedSendOut(self, function()
            return originalFaint(self)
          end)
        end
      end
    end)

    local originalChoose = TrainerAI.chooseMove
    if type(originalChoose) == "function" then
      TrainerAI.chooseMove = function(battler, rng, battle)
        if not battle or not TrainerAi.enabled(mod) then
          return originalChoose(battler, rng, battle)
        end
        return TrainerAi.pickScoredMove(mod, battle, rng, battler)
          or originalChoose(battler, rng, battle)
      end
    end
  else
    -- Gen2: stamp KR AI metadata when a battle starts.
    mod.events:on("battle.started", function(ev)
      local b = ev and ev.battle
      if not b then return end
      b.kind = ev.kind or (b.wild and "wild" or "trainer")
      b.oppClass = ev.trainerId or b.oppClass
        or (b.trainer and (b.trainer.classId or b.trainer.class or b.trainer.id))
      if b.trainer then
        -- Prefer numeric roster slot for isElite. Keep string id separately —
        -- Gen2 World sets memberId to FALKNER_1 / RIVAL1_1_CHIKORITA.
        local t = b.trainer
        if type(t.member) == "number" then
          b.expPartyIndex = t.member
        elseif type(t.index) == "number" then
          b.expPartyIndex = t.index
        else
          b.expPartyIndex = 1
        end
        b.expMemberId = t.memberId or t.id
      end
      b.expMapId = b.expMapId or currentMapId(mod.activeGame)
        or currentMapId(ev.game)
      b.expAiSwitches = 0
      b.expBattleItemsUsed = 0
      b.expMonItemsUsed = {}
      if b.aiUses == nil then b.aiUses = 99 end
      if b.wild and b.enemy then
        b.expWildSpecies = b.enemy.species
      end
    end)

    -- Elite/lite items & switches before vanilla Ai.chooseItem / switch.
    Gen1Patch.apply(require("src.battle.gen2.Battle"), function(Battle)
      if Battle._krAiSpecialWrap then return end
      Battle._krAiSpecialWrap = true
      local original = Battle.enemyTrySwitchOrItem
      Battle.enemyTrySwitchOrItem = function(self)
        if TrainerAi.enabled(mod) and self.trainer and not self.wild then
          local okPrep = pcall(BattleCompat.prepareAiBattle, self)
          if okPrep then
            local tier = TrainerAi.tier(self)
            if tier == "elite" or tier == "lite" then
              local ok, act = pcall(
                (tier == "elite") and TrainerAi.eliteAction or TrainerAi.liteAction,
                self)
              if ok and act and act.special
                  and TrainerAi.applyGen2AiAction(self, act) then
                return true
              end
            end
          end
        end
        return original(self)
      end

      if not Battle._krEliteFaintSend and type(Battle.resolveFaints) == "function" then
        Battle._krEliteFaintSend = true
        local originalFaints = Battle.resolveFaints
        Battle.resolveFaints = function(self)
          if not TrainerAi.enabled(mod) or not self.trainer or self.wild then
            return originalFaints(self)
          end
          if (self.enemy and (self.enemy.hp or 0) or 0) > 0 then
            return originalFaints(self)
          end
          pcall(BattleCompat.prepareAiBattle, self)
          return TrainerAi.withForcedSendOut(self, function()
            return originalFaints(self)
          end)
        end
      end
    end)
  end

  -- Shared overhaul: both gens use the same enemy_action brain.
  mod.hooks:wrap("battle.enemy_action", function(next, battle)
    if not TrainerAi.enabled(mod) then return next(battle) end
    local okPrep = pcall(BattleCompat.prepareAiBattle, battle)
    if not okPrep then return next(battle) end

    local tier = TrainerAi.tier(battle)
    local gen2 = BattleCompat.isGen2(battle)

    -- Dig/Fly second turn, Rollout/Thrash, Encore — must run before scoring
    -- or Fake Out preference (vanilla Gen2 AI returns chargeMove first).
    local forcedId = BattleCompat.forcedMoveId(battle, battle.enemy)
    if forcedId then
      if gen2 then return forcedId end
      return { id = forcedId, pp = 1 }
    end

    local okForced, forced = pcall(preferSharedSetup, battle, nil)
    if okForced and forced then return forced end

    if not gen2 and (tier == "soft" or tier == "natural") then
      local chosen = next(battle)
      local id = type(chosen) == "table" and (chosen.id or chosen.move) or chosen
      local prefer = preferSharedSetup(battle, id)
      if prefer and prefer ~= id then
        return { id = prefer, pp = 1 }
      end
      return chosen
    end

    local locked = battle.lockedAction and battle:lockedAction(battle.enemy)
    if locked then return locked end

    if tier == "elite" or tier == "lite" then
      local ok, act = pcall(
        (tier == "elite") and TrainerAi.eliteAction or TrainerAi.liteAction,
        battle)
      -- Gen2 specials are consumed in enemyTrySwitchOrItem; ignore here.
      if ok and act and not (gen2 and act.special) then return act end
    end

    local okPick, picked = pcall(TrainerAi.pickScoredMove, mod, battle)
    if not okPick or not picked then return next(battle) end
    local id = preferSharedSetup(battle, picked.id) or picked.id
    if gen2 then return id end
    if id ~= picked.id then
      return { id = id, pp = picked.pp or 1 }
    end
    return picked
  end)

  TrainerAI._expansionSmartAi = true
end

return TrainerAi
