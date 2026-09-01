-- Transform KR Gen1-shaped species records into Gold/Gen2 schema records.
local PokemonGen2 = {}
local BattleSpriteScale = require("mods.Kanto-Reforged.battle.battle_sprite_scale")

local function copyList(list)
  if not list then return nil end
  local out = {}
  for i, row in ipairs(list) do
    out[i] = row
  end
  return out
end

local function toLevelMoves(record)
  local moves = {}
  local seen = {}
  local function add(level, move)
    if not move or seen[move] then return end
    seen[move] = true
    moves[#moves + 1] = { level = level, move = move }
  end
  for _, mv in ipairs(record.evolutionMoves or {}) do
    add(1, mv)
  end
  for _, row in ipairs(record.level1Moves or {}) do
    add(1, row)
  end
  for _, row in ipairs(record.learnset or {}) do
    if row.move then
      add(row.level or 1, row.move)
    end
  end
  return moves
end

local function toEvolutions(record)
  local Gen2Compat = require("mods.Kanto-Reforged.core.gen2_compat")
  local evos = {}
  for _, evo in ipairs(record.evolutions or {}) do
    local into = evo.into or evo.species
    if into then
      local copy = {
        method = Gen2Compat.remapEvoMethod(evo.method),
        level = evo.level,
        item = evo.item,
        into = into,
        time = evo.time,
        comparison = evo.comparison,
      }
      evos[#evos + 1] = copy
    end
  end
  return evos
end

--- Gen2-shaped register payload for a KR species record (dex >= 252).
-- opts.knownMove: optional function(id) -> bool; unknown moves stripped.
function PokemonGen2.toGen2Record(record, opts)
  local spa = record.sp_attack
    or (record.baseStats and record.baseStats.specialAttack)
    or (record.baseStats and record.baseStats.special)
    or 50
  local spd = record.sp_defense
    or (record.baseStats and record.baseStats.specialDefense)
    or spa
  local bs = record.baseStats or {}
  local known = opts and opts.knownMove

  local function keepMove(id)
    return id and (not known or known(id))
  end

  local levelMoves = {}
  for _, row in ipairs(toLevelMoves(record)) do
    if keepMove(row.move) then
      levelMoves[#levelMoves + 1] = row
    end
  end
  if #levelMoves == 0 then
    -- Always leave at least Pound so the record validates / battles.
    levelMoves[1] = { level = 1, move = "POUND" }
  end

  local tmhm = {}
  for _, mv in ipairs(record.tmHm or record.tmhm or {}) do
    if keepMove(mv) then tmhm[#tmhm + 1] = mv end
  end

  local out = {
    id = record.id,
    name = record.name,
    dex = record.dex,
    types = copyList(record.types) or { "NORMAL" },
    baseStats = {
      hp = bs.hp or 50,
      attack = bs.attack or 50,
      defense = bs.defense or 50,
      speed = bs.speed or 50,
      specialAttack = spa,
      specialDefense = spd,
    },
    catchRate = record.catchRate or 45,
    baseExp = record.baseExp or 50,
    growthRate = record.growthRate or "MEDIUM_FAST",
    levelMoves = levelMoves,
    tmhm = tmhm,
    evolutions = toEvolutions(record),
    spriteFront = record.spriteFront,
    spriteBack = record.spriteBack,
    picSize = record.frontSize or record.picSize or 5,
    genderRatio = record.genderRatio,
    eggGroups = copyList(record.eggGroups),
    eggSteps = record.eggSteps,
    eggMoves = nil,
    palette = record.palette,
  }
  -- Flat KR art is Gen1-sized (32×32 backs → Gold back 1.5). Converted
  -- RawSprites gs backs are 48×48 — pass backPx so they stay native on Gen2.
  local backPx = (opts and opts.backPx) or BattleSpriteScale.GEN1.backPx
  BattleSpriteScale.applyGen1RecordToGold(out, record, backPx)
  out._krGoldScaled = true
  -- gs idle strips play via battle/front_anim.lua on every edition; Crystal
  -- MonAnim rows are only for vanilla ROM mons still on Crystal art.
  out.anim = nil
  -- ability is KR-only metadata; include when the registry accepts it (pcall register).
  if record.ability then out.ability = record.ability end
  if record.eggMoves and known then
    local eggs = {}
    for _, mv in ipairs(record.eggMoves) do
      if keepMove(mv) then eggs[#eggs + 1] = mv end
    end
    out.eggMoves = eggs
  elseif record.eggMoves and not known then
    out.eggMoves = copyList(record.eggMoves)
  end
  return out
end

function PokemonGen2.derivedOrFallback(modId, rel, fallback)
  local derived = "save/mod-derived/" .. modId .. "/" .. rel
  -- Derived bake lives under save/; probe via image load (filesystem API is gone).
  local newImageData = love and love.image and love.image.newImageData
  if newImageData then
    local ok = pcall(newImageData, derived)
    if ok then return derived end
  end
  return fallback
end

--- Register Hoenn (252+) for Gen2; patch abilities onto 1–251; never re-register Johto.
-- opts.gen2DataReady: when false, strip learnset moves the ROM cache does not know yet.
-- opts.goldDataReady: legacy alias for gen2DataReady.
function PokemonGen2.registerForGen2(mod, pokemon_data, opts)
  local nReg, nPatch = 0, 0
  local highestDex = 251
  local modId = mod.id or "Kanto-Reforged"
  opts = opts or {}
  local knownMove = nil
  local dataReady = opts.gen2DataReady
  if dataReady == nil then dataReady = opts.goldDataReady end
  if dataReady == false then
    knownMove = function(id)
      return mod.content.moves:get(id) ~= nil
    end
  end

  for id, record in pairs(pokemon_data.species or {}) do
    local dex = record.dex or 0
    if dex > highestDex then highestDex = dex end
    if dex >= 252 then
      local SpriteResolve = require("mods.Kanto-Reforged.core.sprite_resolve")
      local backPx = SpriteResolve.backPxFor(mod, id)
      local g2 = PokemonGen2.toGen2Record(record, {
        knownMove = knownMove,
        backPx = backPx,
      })
      -- Prefer gs paths when converted sprites exist.
      -- pathsOnly=true: g2 already has correct Gold scales from toGen2Record;
      -- re-running the scale conversion would treat Gold values as Gen1 values
      -- and halve them (double-conversion bug).
      SpriteResolve.applyToRecord(mod, id, g2, { pathsOnly = true })
      local ok = pcall(function()
        mod.content.pokemon:register(id, g2)
      end)
      if ok then nReg = nReg + 1 end
    elseif dex >= 1 and dex <= 251 then
      -- Gen2 ROM already has the species; patch KR ability + sprite art.
      local patch = {}
      if record.ability then patch.ability = record.ability end
      local SpriteResolve = require("mods.Kanto-Reforged.core.sprite_resolve")
      local art = SpriteResolve.registryPatch(mod, id)
      if art then
        for k, v in pairs(art) do patch[k] = v end
      end
      if next(patch) then
        local ok = pcall(function()
          mod.content.pokemon:patch(id, patch)
        end)
        if ok then nPatch = nPatch + 1 end
      end
    end
  end

  mod.content.constants:patch("dexSize", highestDex)
  mod.content.constants:patch("dexDigits", math.max(3, #tostring(highestDex)))
  mod.log:info("Gen2 species: registered %d Hoenn, patched %d existing, dexSize=%d",
    nReg, nPatch, highestDex)
  return nReg, nPatch, highestDex
end

-- Compat alias for older call sites / tests.
PokemonGen2.registerForGold = PokemonGen2.registerForGen2

--- Gen1 sprites: prefer converted RawSprites (assets/gs), else flat assets.
-- Gold/Silver/Crystal edition caches are retired — KR owns battle art.
function PokemonGen2.applyGen1DerivedSprites(mod, pokemon_data)
  local SpriteResolve = require("mods.Kanto-Reforged.core.sprite_resolve")
  return SpriteResolve.applyToData(mod, pokemon_data)
end

return PokemonGen2
