-- Host generation helpers for dual Gen1/Gen2 boot.
-- Prefer GameVersion (real Gold/Red boot). Tests that inject Loader
-- generation=2 without switching version should call Host.force(2) or
-- GameVersion.set("gold") before load.
local GameVersion = require("src.core.GameVersion")

local Host = {}
local forced = nil

function Host.force(generation)
  forced = generation
end

function Host.clearForce()
  forced = nil
end

function Host.generation()
  if forced == 1 or forced == 2 then
    return forced
  end
  -- Engines before Gold support (e.g. 0.1.75) have no GameVersion.generation.
  if type(GameVersion.generation) == "function" then
    return GameVersion.generation()
  end
  if type(GameVersion.isGold) == "function" and GameVersion.isGold() then
    return 2
  end
  return 1
end

function Host.isGen1()
  return Host.generation() == 1
end

function Host.isGen2()
  return Host.generation() == 2
end

function Host.versionId()
  return GameVersion.get()
end

-- Per-host mod.save keys so a Red↔Gold continue cannot poison farm
-- unlocks / return PC coords across generations.
function Host.saveKey(key)
  return (Host.isGen2() and "g2:" or "g1:") .. tostring(key)
end

-- Progress keys may migrate once from the unprefixed legacy form.
-- Return/outdoor warps never migrate (map ids differ between hosts).
local SAVE_MIGRATE = {
  unlocked_berries = true,
  gifted_berry_seeds = true,
  farmSteps = true,
  plots = true,
  soil_rank = true,
  starterGranted = true,
  blender_steps_anchor = true,
}

function Host.saveGet(bucket, key, default)
  if not bucket or type(bucket.get) ~= "function" then return default end
  local hk = Host.saveKey(key)
  local v = bucket:get(hk)
  if v ~= nil then return v end
  if SAVE_MIGRATE[key] then
    local legacy = bucket:get(key)
    if legacy ~= nil then
      if type(bucket.set) == "function" then
        bucket:set(hk, legacy)
      end
      return legacy
    end
  end
  return default
end

function Host.saveSet(bucket, key, value)
  if not bucket or type(bucket.set) ~= "function" then return end
  bucket:set(Host.saveKey(key), value)
end

return Host
