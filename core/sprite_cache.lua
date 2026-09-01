-- Per-edition Gen2 static battle-pic caches for Gen1 sprite swapping.
-- RETIRED: KR now owns battle art via assets/gs (see core/sprite_resolve.lua).
-- This module remains only so older saves / docs mentioning sprite_source do
-- not hard-error if something still requires it; optionDef always returns nil.
--
-- Historical behavior (no longer wired from main.lua):
-- Each Gen2 boot copied 1–251 fronts/backs into save/mod-derived/.../sprites/<edition>/.

local SpriteCache = {}

SpriteCache.OPTION_KEY = "sprite_source"
SpriteCache.SOURCE_CUSTOM = "custom"
SpriteCache.EDITIONS = { "gold", "silver", "crystal" }

SpriteCache.LABELS = {
  custom = "CUSTOM KR",
  gold = "GOLD",
  silver = "SILVER",
  crystal = "CRYSTAL",
}

--- Always nil — SPRITES 1–251 option removed.
function SpriteCache.optionDef(_mod)
  return nil
end

function SpriteCache.availableEditions(_mod)
  return {}
end

function SpriteCache.source(_mod)
  return SpriteCache.SOURCE_CUSTOM
end

function SpriteCache.captureActiveEdition(_mod)
  return 0
end

function SpriteCache.resolvePath(_mod, _speciesId, _side)
  return nil
end

function SpriteCache.applyToData(_mod, _pokemon_data)
  return 0
end

function SpriteCache.applyLive(_mod)
  return 0
end

function SpriteCache.invalidateAssets()
end

function SpriteCache.onSourceChanged(_mod, _pokemon_data)
end

function SpriteCache.installHook(_mod)
end

-- Kept for tests that still reference basename helpers.
local FRONT_BASE = {
  HO_OH = "hooh",
  FARFETCH_D = "farfetchd",
  MR__MIME = "mrmime",
  NIDORAN_F = "nidoranf",
  NIDORAN_M = "nidoranm",
}

function SpriteCache.frontBase(speciesId)
  if FRONT_BASE[speciesId] then return FRONT_BASE[speciesId] end
  return tostring(speciesId):lower():gsub("_", "")
end

return SpriteCache
