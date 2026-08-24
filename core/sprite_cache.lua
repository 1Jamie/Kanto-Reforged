-- Per-edition Gen2 static battle-pic caches for Gen1 sprite swapping.
-- Each Gen2 boot (gold/silver/crystal) copies 1–251 fronts/backs from the
-- active ROM cache into save/mod-derived/<mod>/sprites/<edition>/.
-- Crystal animated sheets (battle/anim/) are never copied.
-- Gen1 resolves live via the pokemon.sprite hook (Sprites.path) so mid-session
-- swaps work even after content registries freeze.

local GameVersion = require("src.core.GameVersion")
local Host = require("mods.Kanto-Reforged.core.host")
local BattleSpriteScale = require("mods.Kanto-Reforged.battle.battle_sprite_scale")

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

local READY = "ready.png"
local _baselines = nil
local _hookInstalled = false

local function modIdOf(mod)
  return (mod and mod.id) or "Kanto-Reforged"
end

local function derivedRoot(mod)
  return "save/mod-derived/" .. modIdOf(mod) .. "/"
end

local function editionDir(mod, edition)
  return derivedRoot(mod) .. "sprites/" .. edition .. "/"
end

local function readyPath(mod, edition)
  return editionDir(mod, edition) .. READY
end

--- Front file basename under battle/front/ (no .png).
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

local function fs()
  return love and love.filesystem
end

local function ensureDir(path)
  local f = fs()
  if not f or not f.createDirectory then return end
  f.createDirectory(path:gsub("/+$", ""))
end

local function fileExists(path)
  local f = fs()
  if not f then return false end
  return f.getInfo(path) ~= nil
end

function SpriteCache.hasEdition(mod, edition)
  return fileExists(readyPath(mod, edition))
end

function SpriteCache.availableEditions(mod)
  local out = {}
  for _, id in ipairs(SpriteCache.EDITIONS) do
    if SpriteCache.hasEdition(mod, id) then
      out[#out + 1] = id
    end
  end
  return out
end

function SpriteCache.source(mod)
  local v = mod and mod.options and mod.options:get(SpriteCache.OPTION_KEY)
  if v == nil or v == "" then return SpriteCache.SOURCE_CUSTOM end
  if v == SpriteCache.SOURCE_CUSTOM then return v end
  if SpriteCache.hasEdition(mod, v) then return v end
  return SpriteCache.SOURCE_CUSTOM
end

function SpriteCache.optionDef(mod)
  if not Host.isGen1From(mod) then return nil end
  local choices = {
    { SpriteCache.LABELS.custom, SpriteCache.SOURCE_CUSTOM },
  }
  for _, id in ipairs(SpriteCache.availableEditions(mod)) do
    choices[#choices + 1] = { SpriteCache.LABELS[id] or id:upper(), id }
  end
  if #choices <= 1 then return nil end
  return {
    key = SpriteCache.OPTION_KEY,
    label = "SPRITES 1-251",
    type = "choice",
    default = SpriteCache.SOURCE_CUSTOM,
    choices = choices,
  }
end

local function writeReadyMarker(mod, edition)
  local f = fs()
  if not f then return end
  local dir = editionDir(mod, edition)
  ensureDir(dir)
  if love and love.image and love.image.newImageData then
    local img = love.image.newImageData(1, 1)
    img:setPixel(0, 0, 1, 1, 1, 1)
    f.write(readyPath(mod, edition), img:encode("png"))
  else
    f.write(readyPath(mod, edition), "ok")
  end
end

local function isStaticBattleRel(rel)
  if type(rel) ~= "string" then return false end
  if rel:find("/anim/", 1, true) or rel:find("^anim/", 1) then return false end
  return true
end

--- Copy static 1–251 battle pics from the active Gen2 cache into this edition.
-- Walks assets/generated/battle/front (full dex), not KR pokemon_data (Johto+
-- only). Never copies battle/anim/.
function SpriteCache.captureActiveEdition(mod)
  if not Host.isGen2() then return 0 end
  local edition = GameVersion.get()
  if edition ~= "gold" and edition ~= "silver" and edition ~= "crystal" then
    return 0
  end
  local f = fs()
  if not f or not f.getDirectoryItems then return 0 end

  local dir = editionDir(mod, edition)
  ensureDir(dir)

  local n = 0
  local fronts = f.getDirectoryItems("assets/generated/battle/front") or {}
  for _, name in ipairs(fronts) do
    if type(name) == "string" and name:match("%.png$") and isStaticBattleRel(name) then
      local stem = name:gsub("%.png$", "")
      local frontSrc = "assets/generated/battle/front/" .. name
      if fileExists(frontSrc) then
        local bytes = f.read(frontSrc)
        if bytes then
          -- Key by ROM basename (pikachu, hooh, farfetchd) so resolve matches.
          f.write(dir .. stem .. "_front.png", bytes)
          n = n + 1
        end
      end
      local backSrc = "assets/generated/battle/back/" .. stem .. "_back.png"
      if fileExists(backSrc) then
        local bytes = f.read(backSrc)
        if bytes then
          f.write(dir .. stem .. "_back.png", bytes)
          n = n + 1
        end
      end
    end
  end

  writeReadyMarker(mod, edition)
  if mod and mod.log then
    mod.log:info("Sprite cache %s: captured %d static files (no anim)", edition, n)
  end
  return n
end

--- Absolute derived path for a species/side, or nil.
function SpriteCache.derivedPath(mod, edition, speciesId, side)
  if not speciesId or not edition then return nil end
  local base = SpriteCache.frontBase(speciesId)
  local which = (side == "back") and "back" or "front"
  local candidates = {
    editionDir(mod, edition) .. base .. "_" .. which .. ".png",
    -- Legacy capture named files by raw species lower (ho_oh_front).
    editionDir(mod, edition) .. tostring(speciesId):lower() .. "_" .. which .. ".png",
  }
  for _, p in ipairs(candidates) do
    if fileExists(p) then return p end
  end
  return nil
end

--- Live path override for pokemon.sprite hook. Nil → keep caller path.
-- Only reads save/mod-derived caches captured while that Gen2 edition was
-- the mounted boot — never reaches into gold|/silver|/crystal| asset trees
-- from a Red session (version mounts fail outside desktop).
function SpriteCache.resolvePath(mod, speciesId, side)
  if not Host.isGen1() then return nil end
  local source = SpriteCache.source(mod)
  if source == SpriteCache.SOURCE_CUSTOM then return nil end
  -- Only redirect 1–251; Gen3 stays on KR art.
  local dex = nil
  do
    local ok, Data = pcall(require, "src.core.Data")
    local rec = ok and Data.pokemon and Data.pokemon[speciesId]
    dex = rec and (rec.dex or rec.pokedex)
  end
  if dex and (dex < 1 or dex > 251) then return nil end
  return SpriteCache.derivedPath(mod, source, speciesId, side)
end

local function captureBaselines(pokemon_data)
  if _baselines then return end
  _baselines = {}
  for id, rec in pairs(pokemon_data.species or {}) do
    _baselines[id] = {
      front = rec.spriteFront,
      back = rec.spriteBack,
    }
  end
end

--- Apply selected source onto pokemon_data.species (dex ≤ 251 KR rows).
function SpriteCache.applyToData(mod, pokemon_data)
  if not pokemon_data or not pokemon_data.species then return 0 end
  captureBaselines(pokemon_data)
  local source = SpriteCache.source(mod)
  local n = 0
  for id, rec in pairs(pokemon_data.species) do
    local dex = rec.dex or 0
    if dex >= 1 and dex <= 251 then
      local base = _baselines[id]
      if source == SpriteCache.SOURCE_CUSTOM then
        if base then
          rec.spriteFront = base.front
          rec.spriteBack = base.back
          n = n + 1
        end
      else
        local front = SpriteCache.derivedPath(mod, source, id, "front")
        local back = SpriteCache.derivedPath(mod, source, id, "back")
        if front then rec.spriteFront = front; n = n + 1
        elseif base then rec.spriteFront = base.front end
        if back then
          rec.spriteBack = back
          BattleSpriteScale.applyGoldBackOnGen1(rec)
        elseif base then
          rec.spriteBack = base.back
        end
      end
    end
  end
  if mod and mod.log then
    mod.log:info("Gen1 sprites 1–251 data: source=%s (%d)", source, n)
  end
  return n
end

function SpriteCache.applyLive(mod)
  local ok, Data = pcall(require, "src.core.Data")
  if not ok or type(Data) ~= "table" or type(Data.pokemon) ~= "table" then
    return 0
  end
  SpriteCache._liveBaselines = SpriteCache._liveBaselines or {}
  for id, rec in pairs(Data.pokemon) do
    if type(rec) == "table" and not SpriteCache._liveBaselines[id] then
      local dex = rec.dex or rec.pokedex or 0
      if dex >= 1 and dex <= 251 then
        SpriteCache._liveBaselines[id] = {
          front = rec.spriteFront,
          back = rec.spriteBack,
        }
      end
    end
  end

  local source = SpriteCache.source(mod)
  local n = 0
  for id, rec in pairs(Data.pokemon) do
    if type(rec) == "table" then
      local dex = rec.dex or rec.pokedex or 0
      if dex >= 1 and dex <= 251 then
        if source == SpriteCache.SOURCE_CUSTOM then
          local base = SpriteCache._liveBaselines[id]
          if base then
            rec.spriteFront = base.front
            rec.spriteBack = base.back
            n = n + 1
          end
        else
          local front = SpriteCache.derivedPath(mod, source, id, "front")
          local back = SpriteCache.derivedPath(mod, source, id, "back")
          if front then rec.spriteFront = front; n = n + 1 end
          if back then
            rec.spriteBack = back
            BattleSpriteScale.applyGoldBackOnGen1(rec)
          end
        end
      end
    end
  end
  return n
end

function SpriteCache.invalidateAssets()
  local ok, Assets = pcall(require, "src.render.Assets")
  if ok and Assets and Assets.invalidate then
    pcall(Assets.invalidate)
  end
  local okS, SpriteRenderer = pcall(require, "src.render.SpriteRenderer")
  if okS and SpriteRenderer and SpriteRenderer.invalidate then
    pcall(SpriteRenderer.invalidate)
  end
end

--- Install live pokemon.sprite redirect (Gen1). Call once from main.
function SpriteCache.installHook(mod)
  if _hookInstalled or not mod or not mod.hooks then return end
  _hookInstalled = true
  mod.hooks:wrap("pokemon.sprite", function(next, path, ctx)
    local species = ctx and ctx.species
    local side = ctx and ctx.side
    local alt = SpriteCache.resolvePath(mod, species, side)
    if alt then return alt end
    return next(path, ctx)
  end)
end

--- Full refresh after option change.
function SpriteCache.onSourceChanged(mod, pokemon_data)
  if pokemon_data then SpriteCache.applyToData(mod, pokemon_data) end
  SpriteCache.applyLive(mod)
  SpriteCache.invalidateAssets()
  if mod and mod.log then
    mod.log:info("Sprite source now %s", SpriteCache.source(mod))
  end
end

return SpriteCache
