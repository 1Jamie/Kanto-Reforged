-- Resolve KR battle pics: assets/gs → flat assets → caller/ROM.
-- Front idle loops: battle/front_anim.lua (all hosts when gs strips exist).
-- Crystal MonAnim is fallback on Crystal only for ROM-native species.
--
-- Presence is decided from pokemon/gs_index.lua and pokemon/flat_index.lua
-- (written by convert_raw_sprites.py), NOT love.filesystem.getInfo — FS probes
-- missed files on boot and fell through to ROM incorrectly.
-- Crystal MonAnim rows are cleared when gs fronts are applied.

local Host = require("mods.Kanto-Reforged.core.host")
local BattleSpriteScale = require("mods.Kanto-Reforged.battle.battle_sprite_scale")

local SpriteResolve = {}

-- Weather form sheets (CASTFORM_SUNNY_* etc.) are not species ids — CastformFx
-- builds those paths. Normal CASTFORM resolves through gs like any other mon.

local function modIdOf(mod)
  return (mod and mod.id) or "Kanto-Reforged"
end

--- Prefer mod.path (same as castform_fx) when the loader set it.
function SpriteResolve.modPrefix(mod)
  if mod and type(mod.path) == "string" and mod.path ~= "" then
    local p = mod.path
    if p:sub(-1) ~= "/" then p = p .. "/" end
    return p
  end
  return "mods/" .. modIdOf(mod) .. "/"
end

function SpriteResolve.gsPath(mod, speciesId, side)
  if not speciesId then return nil end
  local which = (side == "back") and "back" or "front"
  return SpriteResolve.modPrefix(mod)
    .. "assets/gs/"
    .. tostring(speciesId)
    .. "_"
    .. which
    .. ".png"
end

function SpriteResolve.flatPath(mod, speciesId, side)
  if not speciesId then return nil end
  local which = (side == "back") and "back" or "front"
  return SpriteResolve.modPrefix(mod)
    .. "assets/"
    .. tostring(speciesId):lower()
    .. "_"
    .. which
    .. ".png"
end

local function loadLuaIndex(moduleName)
  local ok, idx = pcall(require, moduleName)
  if ok and type(idx) == "table" then return idx end
  return {}
end

function SpriteResolve.gsIndex()
  SpriteResolve._gsIndex = SpriteResolve._gsIndex
    or loadLuaIndex("mods.Kanto-Reforged.pokemon.gs_index")
  return SpriteResolve._gsIndex
end

function SpriteResolve.flatIndex()
  SpriteResolve._flatIndex = SpriteResolve._flatIndex
    or loadLuaIndex("mods.Kanto-Reforged.pokemon.flat_index")
  return SpriteResolve._flatIndex
end

-- Compat alias used by older call sites / tests.
function SpriteResolve.index()
  return SpriteResolve.gsIndex()
end

function SpriteResolve.hasGs(_mod, speciesId, side)
  if not speciesId then return false end
  local meta = SpriteResolve.gsIndex()[speciesId]
  if not meta then return false end
  if side == "back" then return meta.backW ~= nil end
  return meta.frontW ~= nil
end

function SpriteResolve.hasFlat(_mod, speciesId, side)
  if not speciesId then return false end
  local meta = SpriteResolve.flatIndex()[speciesId]
  if not meta then return false end
  if side == "back" then return meta.back == true end
  return meta.front == true
end

--- Live pokemon.sprite override. Nil → keep caller path (ROM).
-- Priority: gs → flat → nil.
function SpriteResolve.resolvePath(mod, speciesId, side)
  if not speciesId then return nil end
  if SpriteResolve.hasGs(mod, speciesId, side) then
    return SpriteResolve.gsPath(mod, speciesId, side)
  end
  if SpriteResolve.hasFlat(mod, speciesId, side) then
    return SpriteResolve.flatPath(mod, speciesId, side)
  end
  return nil
end

local function sizeTiles(px)
  if not px or px <= 0 then return nil end
  local t = math.floor(px / 8 + 0.5)
  if t < 1 then t = 1 end
  if t > 7 then t = 7 end
  return t
end

local function isGen2Mod(mod)
  local loader = Host.modLoader(mod)
  if loader and loader.generation == 2 then return true end
  return Host.isGen2From(mod) or Host.isGen2()
end

local function applyFront(mod, id, rec, source, pathsOnly)
  if source == "gs" then
    rec.spriteFront = SpriteResolve.gsPath(mod, id, "front")
    rec.anim = nil
    if not pathsOnly then
      local meta = SpriteResolve.gsIndex()[id]
      local tiles = sizeTiles(meta and meta.frontW)
      if tiles then
        if isGen2Mod(mod) then
          rec.picSize = tiles
        else
          rec.frontSize = tiles
        end
      end
    end
    return true
  end
  if source == "flat" then
    rec.spriteFront = SpriteResolve.flatPath(mod, id, "front")
    return true
  end
  return false
end

local function applyGen2BackScale(rec, backPx)
  rec.battleScaleBack = BattleSpriteScale.goldBackScaleForPx(backPx)
end

local function applyBack(mod, id, rec, source, pathsOnly)
  if source == "gs" then
    rec.spriteBack = SpriteResolve.gsPath(mod, id, "back")
    if not pathsOnly then
      local meta = SpriteResolve.gsIndex()[id]
      local backW = (meta and meta.backW) or BattleSpriteScale.GOLD.backPx
      if Host.isGen1() then
        if backW >= 40 then
          BattleSpriteScale.applyGoldBackOnGen1(rec, backW)
        end
      elseif isGen2Mod(mod) then
        applyGen2BackScale(rec, SpriteResolve.backPxFor(mod, id) or BattleSpriteScale.GEN1.backPx)
      end
    end
    return true
  end
  if source == "flat" then
    rec.spriteBack = SpriteResolve.flatPath(mod, id, "back")
    if not pathsOnly then
      if Host.isGen1() then
        local goldish = BattleSpriteScale.gen1ScaleForGoldBack(1, 48)
        if rec.battleScaleBack ~= nil
            and math.abs((rec.battleScaleBack or 0) - goldish) < 0.01 then
          rec.battleScaleBack = nil
        end
        BattleSpriteScale.applyHoennBackOnGen1(rec)
      elseif isGen2Mod(mod) then
        applyGen2BackScale(rec, SpriteResolve.backPxFor(mod, id) or BattleSpriteScale.GEN1.backPx)
      end
    end
    return true
  end
  return false
end

local function bestSource(mod, id, side)
  if SpriteResolve.hasGs(mod, id, side) then return "gs" end
  if SpriteResolve.hasFlat(mod, id, side) then return "flat" end
  return nil
end

--- Apply best available art onto a species record (gs → flat → leave ROM).
-- Mutates `rec`. Returns true when any path was written.
-- opts.pathsOnly=true: only update sprite paths, skip scale/size mutations.
--   Use this when `rec` is already a converted Gen2 record with correct scales.
function SpriteResolve.applyToRecord(mod, id, rec, opts)
  if type(rec) ~= "table" or not id then return false end
  local pathsOnly = opts and opts.pathsOnly
  local changed = false
  local frontSrc = bestSource(mod, id, "front")
  if frontSrc and applyFront(mod, id, rec, frontSrc, pathsOnly) then
    changed = true
  end
  local backSrc = bestSource(mod, id, "back")
  if backSrc and applyBack(mod, id, rec, backSrc, pathsOnly) then
    changed = true
  end
  return changed
end

--- Patch pokemon_data.species with best art for every known gs/flat id.
function SpriteResolve.applyToData(mod, pokemon_data)
  if not pokemon_data or not pokemon_data.species then return 0 end
  local n = 0
  for id, rec in pairs(pokemon_data.species) do
    if SpriteResolve.applyToRecord(mod, id, rec) then
      n = n + 1
    end
  end
  if mod and mod.log and n > 0 then
    mod.log:info("SpriteResolve: applied art to %d pokemon_data species", n)
  end
  return n
end

local function eachIndexedId()
  local seen = {}
  local list = {}
  for id in pairs(SpriteResolve.gsIndex()) do
    if not seen[id] then
      seen[id] = true
      list[#list + 1] = id
    end
  end
  for id in pairs(SpriteResolve.flatIndex()) do
    if not seen[id] then
      seen[id] = true
      list[#list + 1] = id
    end
  end
  return list
end

local function buildPatch(mod, id)
  local patch = {}
  local frontSrc = bestSource(mod, id, "front")
  if frontSrc == "gs" then
    patch.spriteFront = SpriteResolve.gsPath(mod, id, "front")
    local meta = SpriteResolve.gsIndex()[id]
    local tiles = sizeTiles(meta and meta.frontW)
    if tiles then
      if isGen2Mod(mod) then
        patch.picSize = tiles
      else
        patch.frontSize = tiles
      end
    end
  elseif frontSrc == "flat" then
    patch.spriteFront = SpriteResolve.flatPath(mod, id, "front")
  end

  local backSrc = bestSource(mod, id, "back")
  if backSrc == "gs" then
    patch.spriteBack = SpriteResolve.gsPath(mod, id, "back")
    if Host.isGen1() then
      local meta = SpriteResolve.gsIndex()[id]
      local backW = (meta and meta.backW) or BattleSpriteScale.GOLD.backPx
      if backW >= 40 then
        local tmp = {}
        BattleSpriteScale.applyGoldBackOnGen1(tmp, backW)
        patch.battleScaleBack = tmp.battleScaleBack
      end
    elseif isGen2Mod(mod) then
      patch.battleScaleBack = SpriteResolve.goldBackScaleForSpecies(mod, id)
    end
  elseif backSrc == "flat" then
    patch.spriteBack = SpriteResolve.flatPath(mod, id, "back")
    if isGen2Mod(mod) then
      patch.battleScaleBack = SpriteResolve.goldBackScaleForSpecies(mod, id)
    end
  end

  if next(patch) then return patch end
  return nil
end

--- Content-registry patch for one species (paths + Gen2 battleScaleBack).
function SpriteResolve.registryPatch(mod, id)
  return buildPatch(mod, id)
end

--- Gen2: register flat KR back paths in battle_sprite_scales (32px → 1.5).
-- Engine picScale checks image-level scale before species battleScaleBack;
-- this survives even when the picScale monkey-patch is lost after hot reload.
function SpriteResolve.registerBackPathScales(mod)
  local reg = mod and mod.content and mod.content.battle_sprite_scales
  if not reg or reg.frozen then return 0 end
  local n = 0
  for id, meta in pairs(SpriteResolve.flatIndex()) do
    if meta.back then
      local path = SpriteResolve.flatPath(mod, id, "back")
      local scale = BattleSpriteScale.goldBackScaleForPx(meta.backW or 32)
      local key = "kr_flat_back_" .. id
      local ok = pcall(function()
        reg:register(key, { path = path, scale = scale })
      end)
      if ok then
        n = n + 1
      elseif mod and mod.log then
        mod.log:warn("registerBackPathScales %s failed", id)
      end
    end
  end
  if mod and mod.log and n > 0 then
    mod.log:info("SpriteResolve: registered %d flat back path scales", n)
  end
  return n
end

--- Stamp battle_sprite_scales on live game.data (post-merge / battle time).
function SpriteResolve.applyBackPathScales(mod, data)
  if type(data) ~= "table" then return 0 end
  local scales = data.battle_sprite_scales
  if type(scales) ~= "table" then
    scales = {}
    data.battle_sprite_scales = scales
  end
  local n = 0
  for id, meta in pairs(SpriteResolve.flatIndex()) do
    if meta.back then
      local path = SpriteResolve.flatPath(mod, id, "back")
      local scale = BattleSpriteScale.goldBackScaleForPx(meta.backW or 32)
      scales["kr_flat_back_" .. id] = { path = path, scale = scale }
      n = n + 1
    end
  end
  return n
end

--- Write gs/flat art into mod.content.pokemon before the registry freezes.
function SpriteResolve.patchRegistry(mod)
  local reg = mod and mod.content and mod.content.pokemon
  if not reg or reg.frozen then return 0 end
  local n = 0
  for _, id in ipairs(eachIndexedId()) do
    local patch = buildPatch(mod, id)
    if patch then
      if SpriteResolve.hasGs(mod, id, "front") then
        patch.anim = nil
      end
      local ok, err = pcall(function()
        reg:patch(id, patch)
      end)
      if ok then
        n = n + 1
      elseif mod and mod.log then
        mod.log:warn("patchRegistry %s: %s", id, tostring(err))
      end
    end
  end
  if mod and mod.log and n > 0 then
    mod.log:info("SpriteResolve: patched %d species in content registry", n)
  end
  SpriteResolve.registerBackPathScales(mod)
  return n
end

--- Stamp battleScaleBack on every indexed KR back species in a live table.
function SpriteResolve.applyGoldBackScales(mod, pokemonTable)
  if type(pokemonTable) ~= "table" then return 0 end
  local n = 0
  for id, rec in pairs(pokemonTable) do
    if type(rec) == "table" then
      local scale = SpriteResolve.goldBackScaleForSpecies(mod, id)
      if scale then
        rec.battleScaleBack = scale
        n = n + 1
      end
    end
  end
  return n
end

--- Patch live Data / content registry. Safe to call more than once.
function SpriteResolve.applyLive(mod)
  local n = 0

  local reg = mod and mod.content and mod.content.pokemon
  if reg and not reg.frozen then
    for _, id in ipairs(eachIndexedId()) do
      local patch = buildPatch(mod, id)
      if patch then
        local ok = pcall(function()
          reg:patch(id, patch)
        end)
        if ok then n = n + 1 end
      end
    end
  end

  local Data = nil
  do
    local ok, data = pcall(require, "src.core.Data")
    if ok and type(data) == "table" then Data = data end
  end
  -- Direct patch of live Data.pokemon / game.data.pokemon.
  -- Scale is only applied if rec._krGoldScaled is false (preventing double-conversion).
  if type(Data) == "table" and type(Data.pokemon) == "table" then
    for id, rec in pairs(Data.pokemon) do
      if type(rec) == "table" and SpriteResolve.applyToRecord(mod, id, rec) then
        n = n + 1
      end
    end
  end

  local game = mod and Host.liveGame and Host.liveGame(mod)
  local gPokemon = game and game.data and game.data.pokemon
  if type(gPokemon) == "table" and gPokemon ~= (Data and Data.pokemon) then
    for id, rec in pairs(gPokemon) do
      if type(rec) == "table" and SpriteResolve.applyToRecord(mod, id, rec) then
        n = n + 1
      end
    end
    SpriteResolve.applyGoldBackScales(mod, gPokemon)
  end
  if game and game.data then
    SpriteResolve.applyBackPathScales(mod, game.data)
  end

  if mod and mod.log and n > 0 then
    mod.log:info("SpriteResolve: applied art (%d patch ops)", n)
  end
  return n
end

function SpriteResolve.invalidateIndex()
  SpriteResolve._gsIndex = nil
  SpriteResolve._flatIndex = nil
  package.loaded["mods.Kanto-Reforged.pokemon.gs_index"] = nil
  package.loaded["mods.Kanto-Reforged.pokemon.gs_anim_index"] = nil
  package.loaded["mods.Kanto-Reforged.pokemon.flat_index"] = nil
end

function SpriteResolve.invalidateAssets()
  SpriteResolve.invalidateIndex()
  local ok, Assets = pcall(require, "src.render.Assets")
  if ok and Assets and Assets.flush then
    pcall(Assets.flush)
  end
end

function SpriteResolve.backPxFor(mod, speciesId)
  if SpriteResolve.hasGs(mod, speciesId, "back") then
    local meta = SpriteResolve.gsIndex()[speciesId]
    return (meta and meta.backW) or BattleSpriteScale.GOLD.backPx
  end
  if SpriteResolve.hasFlat(mod, speciesId, "back") then
    local meta = SpriteResolve.flatIndex()[speciesId]
    return (meta and meta.backW) or BattleSpriteScale.GEN1.backPx
  end
  return nil
end

--- True when KR provides a back sprite for this species (gs or flat index).
function SpriteResolve.hasKrBack(mod, speciesId)
  return SpriteResolve.hasGs(mod, speciesId, "back")
    or SpriteResolve.hasFlat(mod, speciesId, "back")
end

--- Gen2 battleScaleBack from species index only (gs 48px→1, flat 32px→1.5).
-- Does not inspect paths, assets, or ROM tables — gs_index / flat_index are
-- the source of truth (written by convert_raw_sprites.py).
function SpriteResolve.goldBackScaleForSpecies(mod, speciesId)
  local backPx = SpriteResolve.backPxFor(mod, speciesId)
  if not backPx then return nil end
  return BattleSpriteScale.goldBackScaleForPx(backPx)
end

return SpriteResolve
