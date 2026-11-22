-- Sequential 3-Beast Roamer Cycle + Full 32-bit IV preservation for FRLG in Kanto Reforged.
-- Vanilla FRLG only spawns 1 beast based on the chosen starter and suffers from
-- the vanilla cart bug where roamer IVs are truncated to 8 bits.
-- This module:
-- 1) Preserves full 32-bit IVs (all 6 stats 0..31) for all roaming encounters.
-- 2) Sequentially cycles to the next beast (Raikou -> Entei -> Suicune) upon catch/faint.
-- 3) Offsets each newly spawned beast to start in a later route in the set.

local RoamersGame3 = {}

RoamersGame3.SPECIES_RAIKOU = 243
RoamersGame3.SPECIES_ENTEI = 244
RoamersGame3.SPECIES_SUICUNE = 245

RoamersGame3.NEXT_BEAST = {
  [243] = 244, -- Raikou -> Entei
  [244] = 245, -- Entei -> Suicune
  [245] = 243, -- Suicune -> Raikou
}

local IV_KEYS = { "hp", "atk", "def", "spe", "spa", "spd" }

local function iv_table(src)
  local out = {}
  for i, k in ipairs(IV_KEYS) do
    if type(src) == "number" then
      out[k] = math.floor(src / 2 ^ ((i - 1) * 5)) % 32
    else
      local v = type(src) == "table" and src[k] or 0
      out[k] = (tonumber(v) or 0) % 32
    end
  end
  return out
end

function RoamersGame3.cycleRoamer(session, mod)
  local r = session and session.roamer
  if not r then return false end
  local curSpecies = r.species
  local nextSpecies = RoamersGame3.NEXT_BEAST[curSpecies]
  if not nextSpecies then return false end

  local count = (session.roamer_cycle_count or 1) + 1
  session.roamer_cycle_count = count
  if mod and mod.save then
    mod.save:set("roamer_cycle_count", count)
  end

  if count > 3 then
    -- All 3 beasts have been caught/resolved
    r.active = false
    return false
  end

  local Roamer = require("src.core.game3.roamer")
  local cfg = Roamer.config(session)
  local sets
  if cfg then
    local okSets, res = pcall(Roamer.locationSets, cfg)
    if okSets and type(res) == "table" then sets = res end
  end
  local nextMap
  if sets and #sets > 0 then
    local curIdx = 1
    for i, s in ipairs(sets) do
      if s[1] == r.map then curIdx = i break end
    end
    -- Offset next beast to start 4 routes later in the cycle
    local nextIdx = ((curIdx + 3) % #sets) + 1
    nextMap = sets[nextIdx][1]
  end

  local Rng = require("src.core.game3.rng")
  local personality = Rng.Random32()
  local iv1 = Rng.Random()
  local iv2 = Rng.Random()
  local ivNum = (iv1 % 0x8000) + (iv2 % 0x8000) * 0x8000
  local ivs = iv_table(ivNum)
  local level = cfg and cfg.level or 50
  local Pokemon = require("src.core.game3.pokemon")
  local stats = Pokemon.calcStats(nextSpecies, level, ivs, {}, personality)

  session.roamer = {
    active = true,
    species = nextSpecies,
    level = level,
    status = 0,
    ivs = ivs,
    personality = personality,
    hp = stats.maxHp,
    history = { false, false, false },
    map = nextMap or (sets and sets[1][1]) or false,
  }
  return true
end

function RoamersGame3.install(mod)
  RoamersGame3._mod = mod

  local okR, Roamer = pcall(require, "src.core.game3.roamer")
  if okR and Roamer and not Roamer._krRoamerWrapped then
    -- 1. Full 32-bit IVs override (fixing vanilla FRLG cart bug)
    local origInstanceIvs = Roamer.instanceIvs
    Roamer.instanceIvs = function(ivs, truncated)
      return origInstanceIvs(ivs, false)
    end

    -- 2. Roamer sequential cycle hook
    local origOnBattleEnd = Roamer.onBattleEnd
    Roamer.onBattleEnd = function(session, foeState, battleResult, endReason, battler)
      local r = session and session.roamer
      local wasActive = r and r.active
      origOnBattleEnd(session, foeState, battleResult, endReason, battler)
      if wasActive and session and session.roamer and not session.roamer.active then
        RoamersGame3.cycleRoamer(session, mod)
      end
    end
    Roamer._krRoamerWrapped = true
  end
end

return RoamersGame3
