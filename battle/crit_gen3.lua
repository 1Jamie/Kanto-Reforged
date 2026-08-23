-- Gen 3 critical-hit stage ladder (Ruby/Sapphire/Emerald / FR/LG).
-- Used when the active ruleset has krGen3Crit (KR's modern_clean patch).

local CritGen3 = {}

-- Stage → chance out of 16 / denominator for a clear fraction.
-- 0: 1/16, 1: 1/8, 2: 1/4, 3: 1/3, 4+: 1/2
local STAGE_NUM = { [0] = 1, [1] = 2, [2] = 4, [3] = 1, [4] = 1 }
local STAGE_DEN = { [0] = 16, [1] = 8, [2] = 4, [3] = 3, [4] = 2 }

local HIGH_CRIT = {
  KARATE_CHOP = true, RAZOR_LEAF = true, CRABHAMMER = true, SLASH = true,
  AEROBLAST = true, AIR_CUTTER = true, ATTACK_ORDER = true, BLAZE_KICK = true,
  CROSS_CHOP = true, DRILL_RUN = true, KARATE_CHOP = true, LEAF_BLADE = true,
  NIGHT_SLASH = true, POISON_TAIL = true, PSYCHO_CUT = true, SHADOW_CLAW = true,
  SPACIAL_REND = true, STONE_EDGE = true,
}

function CritGen3.stage(attacker, moveId, highCrit)
  local stage = 0
  if attacker and attacker.focusEnergy then
    stage = stage + 2
  end
  if highCrit == nil then
    highCrit = HIGH_CRIT[moveId]
  end
  if highCrit then
    stage = stage + 1
  end
  if stage > 4 then stage = 4 end
  return stage
end

function CritGen3.roll(ctx)
  local attacker = ctx.attacker
  local moveId = ctx.moveId
  local highCrit = ctx.highCrit
  local rng = ctx.rng or love.math.random
  local stage = CritGen3.stage(attacker, moveId, highCrit)
  local num = STAGE_NUM[stage] or 1
  local den = STAGE_DEN[stage] or 2
  -- Uniform roll in [0, den): success when roll < num
  local roll
  if type(rng) == "function" then
    -- Engine battle rng is often rng(lo, hi) inclusive.
    local ok, a = pcall(rng, 0, den - 1)
    if ok and type(a) == "number" then
      roll = a
    else
      roll = math.random(0, den - 1)
    end
  else
    roll = math.random(0, den - 1)
  end
  return roll < num
end

function CritGen3.rulesetWants(ruleset)
  if not ruleset then return false end
  if ruleset.krGen3Crit then return true end
  -- Fallback if patch did not land but id is still modern_clean
  return ruleset.name == "MODERN" or ruleset.name == "modern_clean"
end

return CritGen3
