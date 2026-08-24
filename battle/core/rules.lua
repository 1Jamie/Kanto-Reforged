-- Pure battle rule decisions (no engine I/O).

local Capabilities = require("mods.Kanto-Reforged.battle.core.capabilities")

local Rules = {}

Rules.PHASE_ORDER = {
  "weather_continue",
  "weather_chip",
  "weather_tick",
  "status_chip",
  "leech_seed",
  "partial_trap_chip",
  "partial_trap_tick",
  "volatiles",
  "held_items",
  "abilities_eot",
}

Rules.FAINT_HALT_PHASES = {
  weather_chip = true,
  status_chip = true,
  leech_seed = true,
  partial_trap_chip = true,
  volatiles = true,
}

-- Field-wide phases run once per turn; others run per active battler.
Rules.FIELD_PHASES = {
  weather_continue = true,
  weather_chip = true,
  weather_tick = true,
}

function Rules.isFieldPhase(phase)
  return Rules.FIELD_PHASES[phase] == true
end

function Rules.phaseOrder()
  return Rules.PHASE_ORDER
end

function Rules.shouldHaltBattlerOnFaint(phase)
  return Rules.FAINT_HALT_PHASES[phase] == true
end

-- Partial trap (Gen3 MODERN)
Rules.partialTrap = {}

function Rules.partialTrap.chipAmount(maxHp)
  local denom = Capabilities.partialTrapChipDenom
  return math.max(1, math.floor((maxHp or 16) / denom))
end

function Rules.partialTrap.rollTurns(rng)
  rng = rng or math.random
  local minT = Capabilities.partialTrapMinTurns
  local maxT = Capabilities.partialTrapMaxTurns
  local span = maxT - minT + 1
  local n
  if type(rng) == "function" then
    local ok, v = pcall(rng, minT, maxT)
    if ok and type(v) == "number" then n = v end
    if not n then
      ok, v = pcall(rng, span)
      if ok and type(v) == "number" then
        n = minT + ((math.floor(v) - 1) % span)
      end
    end
  end
  if type(n) ~= "number" then
    n = minT + math.random(0, span - 1)
  end
  return math.max(minT, math.min(maxT, math.floor(n)))
end

function Rules.partialTrap.active()
  return Capabilities.gen3PartialTrap
end

function Rules.partialTrap.ghostImmune(types)
  for _, t in ipairs(types or {}) do
    if t == "GHOST" then return true end
  end
  return false
end

-- Weather
Rules.weather = {}

function Rules.weather.chipAmount(maxHp)
  return math.max(1, math.floor((maxHp or 16) / Capabilities.weatherChipDenom))
end

Rules.weather.SAND_IMMUNE = { ROCK = true, GROUND = true, STEEL = true }
Rules.weather.HAIL_IMMUNE = { ICE = true }

function Rules.weather.hits(types, kind)
  kind = kind or "SANDSTORM"
  local immune = (kind == "HAIL" or kind == "SNOWY")
    and Rules.weather.HAIL_IMMUNE or Rules.weather.SAND_IMMUNE
  for _, t in ipairs(types or {}) do
    if immune[t] then return false end
  end
  return true
end

function Rules.weather.typeModifier(weather, moveType)
  local mods = {
    SUNNY = { FIRE = 1.5, WATER = 0.5 },
    RAINY = { WATER = 1.5, FIRE = 0.5 },
  }
  local row = weather and mods[weather]
  if row and moveType and row[moveType] then return row[moveType] end
  return 1
end

function Rules.weather.neverMiss(weather, moveId)
  if weather == "RAINY" and moveId == "THUNDER" then return true end
  if (weather == "HAIL" or weather == "SNOWY") and moveId == "BLIZZARD" then return true end
  if weather == "SUNNY" and moveId == "SOLARBEAM" then return true end
  return false
end

function Rules.weather.instantCharge(weather, moveId)
  return moveId == "SOLARBEAM" and weather == "SUNNY"
end

function Rules.weather.healFraction(weather)
  if weather == "SUNNY" then return 2 / 3 end
  if weather == "RAINY" or weather == "SANDSTORM" or weather == "HAIL" or weather == "SNOWY" then
    return 1 / 4
  end
  return 1 / 2
end

-- Crit (Gen3 stage ladder)
Rules.crit = {}

local STAGE_NUM = { [0] = 1, [1] = 2, [2] = 4, [3] = 1, [4] = 1 }
local STAGE_DEN = { [0] = 16, [1] = 8, [2] = 4, [3] = 3, [4] = 2 }

local HIGH_CRIT = {
  KARATE_CHOP = true, RAZOR_LEAF = true, CRABHAMMER = true, SLASH = true,
  AEROBLAST = true, AIR_CUTTER = true, ATTACK_ORDER = true, BLAZE_KICK = true,
  CROSS_CHOP = true, DRILL_RUN = true, LEAF_BLADE = true, NIGHT_SLASH = true,
  POISON_TAIL = true, PSYCHO_CUT = true, SHADOW_CLAW = true, SPACIAL_REND = true,
  STONE_EDGE = true,
}

function Rules.crit.stage(attacker, moveId, highCrit)
  if not Capabilities.gen3Crit then return 0 end
  local stage = 0
  if attacker and (attacker.focusEnergy or attacker.expFocusEnergy) then
    stage = stage + 2
  end
  if highCrit == nil then highCrit = HIGH_CRIT[moveId] end
  if highCrit then stage = stage + 1 end

  -- Held items (Gen3): Scope Lens +1; Lucky Punch (Chansey) +2; Stick (Farfetch'd) +2.
  local mon = attacker and (attacker.mon or attacker) or nil
  local item = mon and (mon.heldItem or mon.item) or nil
  local species = mon and mon.species or nil
  if item == "SCOPE_LENS" then
    stage = stage + 1
  elseif item == "LUCKY_PUNCH" and species == "CHANSEY" then
    stage = stage + 2
  elseif (item == "STICK" or item == "LEEK")
      and (species == "FARFETCHD" or species == "FARFETCH_D") then
    stage = stage + 2
  end

  if stage > 4 then stage = 4 end
  return stage
end

-- Gold Battle:roller() is (n) -> 0..n-1. love.math.random is (lo, hi) or (n) -> 1..n.
-- Calling the Gold roller as (0, den-1) passes n=0 and always returns 0, i.e. every hit crits.
local function rollZeroTo(rng, den)
  if den <= 1 then return 0 end
  if type(rng) ~= "function" then
    return math.random(0, den - 1)
  end
  local nparams = 0
  if debug and debug.getinfo then
    local info = debug.getinfo(rng, "u")
    nparams = info and info.nparams or 0
  end
  if nparams == 1 then
    local a = rng(den)
    if type(a) == "number" then return a % den end
  else
    local ok, a = pcall(rng, 0, den - 1)
    if ok and type(a) == "number" then return a end
  end
  return math.random(0, den - 1)
end

function Rules.crit.roll(attacker, moveId, highCrit, rng)
  local stage = Rules.crit.stage(attacker, moveId, highCrit)
  local num = STAGE_NUM[stage] or 1
  local den = STAGE_DEN[stage] or 2
  return rollZeroTo(rng, den) < num
end

function Rules.crit.active()
  return Capabilities.gen3Crit
end

-- Substitute guard (Gen1 substituteHP; Gen2 volatile.substitute via battle)
Rules.substitute = {}

function Rules.substitute.hasSubstitute(battler, battleOrAdapter)
  if not battler then return false end
  if battleOrAdapter and type(battleOrAdapter.hasSubstitute) == "function" then
    return battleOrAdapter:hasSubstitute(battler)
  end
  local battle = battleOrAdapter
  if battle and battle._battle then
    battle = battle._battle
  end
  if battle then
    local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
    return BattleCompat.hasSubstitute(battle, battler)
  end
  return (battler.substituteHP or 0) > 0
end

function Rules.substitute.blocks(effectKind, target, battleOrAdapter)
  if not Rules.substitute.hasSubstitute(target, battleOrAdapter) then return false end
  local blocked = {
    status = true,
    stat_drop = true,
    taunt = true,
    yawn = true,
    burn = true,
    attract = true,
    pain_split = true,
  }
  return blocked[effectKind] == true
end

-- Screens / side timers
Rules.screens = {}
Rules.screens.DEFAULT_TURNS = Capabilities.screenDefaultTurns

return Rules
