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
  if GameVersion.get() == "gold" or (type(GameVersion.isGold) == "function" and GameVersion.isGold()) then
    return 2
  end
  if _G.game and (_G.game.generation == 2 or _G.game.isGold) then
    return 2
  end
  -- NOTE: do NOT probe package.loaded["src.core.Game2"] here.
  -- Game2 is cached by Lua's require system for the lifetime of the process;
  -- if Gold was booted first in the launcher, this would falsely return 2
  -- for Red.  GameVersion.generation() below is the authoritative check.
  if type(GameVersion.generation) == "function" and GameVersion.generation() == 2 then
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

-- Live Game without _G or package (both absent / private under Grandma's
-- Kitchen). Prefer the loader facade; require still resolves engine modules
-- and honors test stubs already in the engine's package.loaded.
function Host.liveGame(mod)
  if mod and mod.game then return mod.game end
  if Host.isGen2() then
    -- src.core.Game is the Gen1 singleton and has no Gold save. Prefer the
    -- loader-injected Game2 instance via mod.game; if missing, there is no
    -- safe global fallback.
    return nil
  end
  local ok, Game = pcall(require, "src.core.Game")
  if ok and type(Game) == "table" then return Game end
  return nil
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
  -- Dex sidecar / scope progress (may predate g1:/g2: prefixes).
  pokedex_flags = true,
  species_scope_stash = true,
  species_scope_applied = true,
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

-- Options that rewrite host-specific world content. Manager still shows one
-- row per boot; the stored key is g1:/g2: so Red and Gold stay independent.
-- Battle-feel toggles (XP Share, AI, …) stay shared / unprefixed.
Host.SCOPED_OPTIONS = {
  species_scope = true,
  full_spawn_random = true,
  pure_spawn_random = true,
  legends_in_mix = true,
}

function Host.optionKey(logical)
  if Host.SCOPED_OPTIONS[logical] then
    return Host.saveKey(logical)
  end
  return logical
end

function Host.optionEventIs(key, logical)
  return key == Host.optionKey(logical)
end

-- Loader that owns modOptions for this facade (needed during entry, before
-- game.mods is assigned). Prefer an explicit stash, then the options.get
-- upvalue, then game.mods.
function Host.modLoader(mod)
  if mod and mod._loader then return mod._loader end
  local get = mod and mod.options and mod.options.get
  if type(get) == "function" and debug and debug.getupvalue then
    local i = 1
    while true do
      local name, val = debug.getupvalue(get, i)
      if not name then break end
      if name == "loader" then
        if mod then mod._loader = val end
        return val
      end
      i = i + 1
    end
  end
  local game = Host.liveGame(mod)
  return game and game.mods
end

-- Flush this mod's option bucket to top-level options.modOptions (what
-- Loader reads on every boot). Safe on Red and Gold.
function Host.persistModOptions(mod)
  if not mod then return end
  local SaveData = require("src.core.SaveData")
  local game = Host.liveGame(mod)
  local loader = Host.modLoader(mod) or (game and game.mods)
  local live = loader and loader.modOptions and loader.modOptions[mod.id]
  if type(live) ~= "table" then return end

  if game and game.save and game.save.options then
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions[mod.id] = live
  end
  if game and game.options then
    game.options.modOptions = game.options.modOptions or {}
    game.options.modOptions[mod.id] = live
  end

  local file = SaveData.loadOptions()
  file.modOptions = file.modOptions or {}
  file.modOptions[mod.id] = live
  SaveData.saveOptions(file)

  if game and type(game.writeOptions) == "function" then
    pcall(function() game:writeOptions() end)
  elseif game and type(game.persistOptions) == "function" then
    pcall(function() game:persistOptions() end)
  end
end

-- Engine gaps KR fills without shipping engine patches:
--   * Game2 has persistOptions but Manager calls writeOptions (Gen1 API)
--   * Game:writeOptions can persist a stale save.options.modOptions copy
--   * Gold Save.saveOptions stashes under options.gold; Loader reads
--     top-level options.modOptions
function Host.installEngineShims(mod)
  if Host._engineShims then return end
  Host._engineShims = true
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")

  pcall(function()
    local Game2 = require("src.core.Game2")
    if type(Game2) == "table" and type(Game2.writeOptions) ~= "function"
        and type(Game2.persistOptions) == "function" then
      function Game2:writeOptions()
        return self:persistOptions()
      end
    end
  end)

  if Host.isGen1() then
    pcall(function()
      Gen1Patch.apply(require("src.core.Game"), function(Game)
        if Game._krWriteOpts then return end
        local orig = Game.writeOptions
        if type(orig) ~= "function" then return end
        function Game:writeOptions()
          if self.mods and self.mods.modOptions and self.save
              and self.save.options then
            self.save.options.modOptions = self.mods.modOptions
          end
          return orig(self)
        end
        Game._krWriteOpts = true
      end)
    end)
  end

  pcall(function()
    Gen1Patch.apply(require("src.core.gen2.Save"), function(Save)
        if Save._krModOptsLift then return end
        local orig = Save.saveOptions
        if type(orig) ~= "function" then return end
        Save.saveOptions = function(options, fs)
          if type(options) ~= "table" then return orig(options, fs) end
          local ok, SaveData = pcall(require, "src.core.SaveData")
          if not ok then return orig(options, fs) end
          local file = SaveData.loadOptions(fs) or {}
          local block = {}
          for key, value in pairs(options) do block[key] = value end
          file[Save.OPTIONS_KEY] = block
          if type(options.modOptions) == "table" then
            file.modOptions = file.modOptions or {}
            for modId, bucket in pairs(options.modOptions) do
              if type(bucket) == "table" then
                file.modOptions[modId] = file.modOptions[modId] or {}
                for k, v in pairs(bucket) do
                  file.modOptions[modId][k] = v
                end
              end
            end
          end
          SaveData.saveOptions(file, fs)
          return true
        end
        Save._krModOptsLift = true
      end)
    end)

  if mod and mod.log then
    mod.log:info("Host: installed option-persistence engine shims")
  end
end

-- One-time copy from unprefixed legacy keys into the current host bucket.
function Host.migrateScopedOptions(mod)
  if not mod then return end
  local loader = Host.modLoader(mod)
  local bucket = loader and loader.modOptions and loader.modOptions[mod.id]
  if not bucket then
    if not loader then return end
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
    bucket = loader.modOptions[mod.id]
  end
  local game = Host.liveGame(mod)
  local saveBucket = game and game.save and game.save.options
    and game.save.options.modOptions and game.save.options.modOptions[mod.id]
  local migrated = false
  for logical in pairs(Host.SCOPED_OPTIONS) do
    local hk = Host.optionKey(logical)
    if bucket[hk] == nil and bucket[logical] ~= nil then
      bucket[hk] = bucket[logical]
      migrated = true
    end
    if saveBucket and saveBucket[hk] == nil and saveBucket[logical] ~= nil then
      saveBucket[hk] = saveBucket[logical]
      migrated = true
    end
  end
  if migrated then
    Host.persistModOptions(mod)
  end
end

return Host
