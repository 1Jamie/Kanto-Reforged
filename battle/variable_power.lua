-- Variable-power / weight / stage formulas for Gen 2–3 moves.
-- Used by the battle.damage bumpPower wrap in main.lua.

local VariablePower = {}

local WEIGHT_POWER = {
  -- kg thresholds → Grass Knot / Low Kick style power
  { 10, 20 }, { 25, 40 }, { 50, 60 }, { 100, 80 }, { 200, 100 }, { math.huge, 120 },
}

local HEAVY_RATIO = {
  -- user/target weight ratio → Heavy Slam / Heat Crash power
  { 0.5, 40 }, { 1/3, 60 }, { 0.25, 80 }, { 0.2, 100 }, { 0, 120 },
}

-- Gen3 Natural Gift for berries KR actually ships.
local NATURAL_GIFT = {
  BERRY = { type = "NORMAL", power = 80 },
  CHERI_BERRY = { type = "FIRE", power = 80 },
  CHESTO_BERRY = { type = "WATER", power = 80 },
  PECHA_BERRY = { type = "ELECTRIC", power = 80 },
  RAWST_BERRY = { type = "GRASS", power = 80 },
  ASPEAR_BERRY = { type = "ICE", power = 80 },
  PERSIM_BERRY = { type = "GROUND", power = 80 },
  LUM_BERRY = { type = "FLYING", power = 80 },
}

local function monOf(battler)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  return BattleCompat.mon(battler) or battler
end

local function speciesWeight(battle, battler)
  local mon = monOf(battler)
  if not mon or not mon.species then return 50 end
  local data = battle and battle.data
  local def = data and data.pokemon and data.pokemon[mon.species]
  local w = def and def.weight
  if type(w) == "number" and w > 0 then return w end
  -- Fallback: base HP as a rough mass proxy when weight is missing.
  local bs = def and def.baseStats
  return (bs and bs.hp) or 50
end

function VariablePower.weightPower(battle, battler)
  local w = speciesWeight(battle, battler)
  for _, row in ipairs(WEIGHT_POWER) do
    if w < row[1] then return row[2] end
  end
  return 120
end

function VariablePower.heavySlamPower(battle, user, target)
  local uw = speciesWeight(battle, user)
  local tw = math.max(0.1, speciesWeight(battle, target))
  local ratio = tw / uw
  for _, row in ipairs(HEAVY_RATIO) do
    if ratio >= row[1] then return row[2] end
  end
  return 120
end

local function speedOf(battle, battler)
  if not battler then return 1 end
  if battler.curStats and battler.curStats.speed then
    return math.max(1, battler.curStats.speed)
  end
  local mon = monOf(battler)
  if mon and mon.stats and mon.stats.speed then
    return math.max(1, mon.stats.speed)
  end
  if battle and battle.stages and type(battle.statOf) == "function" then
    local ok, v = pcall(function() return battle:statOf(battler, "speed") end)
    if ok and type(v) == "number" then return math.max(1, v) end
  end
  return 1
end

local function partyMonsOf(battle, user)
  if not battle then return {} end
  if user and user.isPlayer ~= false then
    if battle.game and battle.game.save and battle.game.save.party then
      return battle.game.save.party
    end
    if battle.party then return battle.party end
  end
  return battle.enemyParty or {}
end

function VariablePower.gyroBallPower(battle, user, target)
  local us = speedOf(battle, user)
  local ts = speedOf(battle, target)
  return math.max(1, math.min(150, math.floor(25 * ts / us)))
end

function VariablePower.electroBallPower(battle, user, target)
  local us = speedOf(battle, user)
  local ts = speedOf(battle, target)
  local ratio = us / ts
  if ratio >= 4 then return 150 end
  if ratio >= 3 then return 120 end
  if ratio >= 2 then return 80 end
  if ratio >= 1 then return 60 end
  return 40
end

function VariablePower.punishmentPower(battle, target)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local stages = BattleCompat.stages(battle, target) or {}
  local boosts = 0
  for _, key in ipairs({ "attack", "defense", "speed", "special",
      "specialAttack", "specialDefense", "accuracy", "evasion" }) do
    local v = stages[key] or 0
    if v > 0 then boosts = boosts + v end
  end
  return math.min(200, 60 + 20 * boosts)
end

function VariablePower.storedPower(battle, user)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local stages = BattleCompat.stages(battle, user) or {}
  local boosts = 0
  for _, key in ipairs({ "attack", "defense", "speed", "special",
      "specialAttack", "specialDefense", "accuracy", "evasion" }) do
    local v = stages[key] or 0
    if v > 0 then boosts = boosts + v end
  end
  return 20 + 20 * boosts
end

function VariablePower.wringOutPower(battler)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local hp = BattleCompat.hp(battler)
  local maxHp = math.max(1, BattleCompat.maxHp(battler))
  return math.max(1, math.floor(120 * hp / maxHp))
end

function VariablePower.trumpCardPower(moveInst)
  local pp = (moveInst and moveInst.pp) or 5
  if pp <= 1 then return 200 end
  if pp == 2 then return 80 end
  if pp == 3 then return 60 end
  if pp == 4 then return 50 end
  return 40
end

function VariablePower.flingPower(itemId)
  if not itemId then return nil end
  -- Rough Gen3 Fling powers for items KR ships.
  local table_ = {
    BERRY = 10, CHERI_BERRY = 10, CHESTO_BERRY = 10, PECHA_BERRY = 10,
    RAWST_BERRY = 10, ASPEAR_BERRY = 10, PERSIM_BERRY = 10, LUM_BERRY = 10,
    ORAN_BERRY = 10, SITRUS_BERRY = 10,
    FOCUS_BAND = 10, LEFTOVERS = 10, MIRACLE_SEED = 30, MAGNET = 30,
    CHARCOAL = 30, MYSTIC_WATER = 30, BLACK_BELT = 30, HARD_STONE = 100,
    METAL_COAT = 30, SPELL_TAG = 30, TWISTEDSPOON = 30, SILVERPOWDER = 10,
    POISON_BARB = 70, SHARP_BEAK = 50, NEVERMELTICE = 30, SOFT_SAND = 10,
    PINK_BOW = 10, BLACKGLASSES = 30, DRAGON_FANG = 70,
  }
  return table_[itemId] or 30
end

function VariablePower.naturalGift(itemId)
  if not itemId then return nil end
  return NATURAL_GIFT[itemId]
end

function VariablePower.beatUpPower(battle, user)
  local n = 0
  for _, mon in ipairs(partyMonsOf(battle, user)) do
    if mon and (mon.hp or 0) > 0 and not mon.status then
      n = n + 1
    end
  end
  if n <= 0 then n = 1 end
  -- Gen2-ish: 10 BP per healthy non-statused party mon (single combined hit).
  return 10 * n
end

return VariablePower
