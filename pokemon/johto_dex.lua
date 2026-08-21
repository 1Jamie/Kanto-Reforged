-- Gold NEW / A-Z Pokédex orders: species obtainable in Johto under the live
-- spawn tables (curated guests, FULL/PURE random, JOHTO SCOPE), plus evo /
-- breed lines and unmixed Johto static legends. OLD (national) is untouched.
local JohtoDex = {}

-- Randomizer only remaps wild tables; these Johto statics / roamers stay.
JohtoDex.STATIC_LEGENDS = {
  RAIKOU = true, ENTEI = true, SUICUNE = true,
  LUGIA = true, HO_OH = true, CELEBI = true,
}

local vanillaNewOrder = nil

local function liveData(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local game = Host.liveGame(mod)
  if game and game.data then return game.data end
  local ok, Data = pcall(require, "src.core.Data")
  if ok then return Data end
  return nil
end

local function liveEncounters(mod)
  local data = liveData(mod)
  if data and data.gen2Encounters then return data.gen2Encounters end
  local ok, Data = pcall(require, "src.core.Data")
  if ok and Data and Data.gen2Encounters then return Data.gen2Encounters end
  return nil
end

local function livePokedex(mod)
  local data = liveData(mod)
  if not data then return nil end
  local ok, Data = pcall(require, "src.core.Data")
  -- Prefer a real ROM sheet (has newOrder) over an empty stub on game.data.
  if ok and Data and Data.gen2Pokedex and Data.gen2Pokedex.newOrder
      and #(Data.gen2Pokedex.newOrder or {}) > 0 then
    if not data.gen2Pokedex or not data.gen2Pokedex.newOrder
        or #(data.gen2Pokedex.newOrder or {}) == 0 then
      data.gen2Pokedex = Data.gen2Pokedex
    end
  end
  data.gen2Pokedex = data.gen2Pokedex or {}
  if ok and Data and Data ~= data then
    Data.gen2Pokedex = data.gen2Pokedex
  end
  return data.gen2Pokedex
end

local function isKantoMap(mapId)
  local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
  return SpeciesScope.isKantoMap(mapId)
end

local function addSpecies(set, sp)
  if type(sp) == "string" and sp ~= "" then set[sp] = true end
end

local function collectSlots(set, slots)
  if type(slots) ~= "table" then return end
  -- Grass TOD buckets { MORN=..., DAY=..., NITE=... } or a flat water list.
  if slots[1] and slots[1].species then
    for _, slot in ipairs(slots) do addSpecies(set, slot.species) end
    return
  end
  for _, list in pairs(slots) do
    if type(list) == "table" then
      for _, slot in ipairs(list) do addSpecies(set, slot and slot.species) end
    end
  end
end

local function collectFishGroup(set, group)
  if type(group) ~= "table" then return end
  for _, rod in ipairs({ "old", "good", "super" }) do
    collectSlots(set, group[rod])
  end
end

local function collectTreeSet(set, treeSet)
  if type(treeSet) ~= "table" then return end
  collectSlots(set, treeSet.common)
  collectSlots(set, treeSet.rare)
end

local function loadRomEncounters()
  local ok, Data = pcall(require, "src.core.Data")
  if ok and type(Data) == "table" and Data.gen2Encounters
      and Data.gen2Encounters.grass and Data.gen2Encounters.grass.ROUTE_29 then
    return Data.gen2Encounters
  end
  return nil
end

-- Prefer live tables; if Johto maps are missing (headless Kanto-only patch),
-- overlay onto a ROM scratch copy — never mutate Data.gen2Encounters with ROM
-- rows during boot (FARFETCH_D etc. fail registry resolve).
local function ensureEncounters(mod)
  local enc = liveEncounters(mod)
  if enc and enc.grass and enc.grass.ROUTE_29 then return enc end
  local rom = loadRomEncounters()
  if not rom then return enc end
  if not enc then return rom end
  local view = {
    grass = {},
    water = {},
    fishGroups = enc.fishGroups or rom.fishGroups,
    treeSets = enc.treeSets or rom.treeSets,
    trees = enc.trees or rom.trees,
    rocks = enc.rocks or rom.rocks,
  }
  for mapId, block in pairs(rom.grass or {}) do view.grass[mapId] = block end
  for mapId, block in pairs(enc.grass or {}) do view.grass[mapId] = block end
  for mapId, block in pairs(rom.water or {}) do view.water[mapId] = block end
  for mapId, block in pairs(enc.water or {}) do view.water[mapId] = block end
  return view
end

function JohtoDex.collectJohtoWildSpecies(mod)
  local enc = ensureEncounters(mod)
  local set = {}
  if not enc then return set end

  for _, kind in ipairs({ "grass", "water" }) do
    for mapId, block in pairs(enc[kind] or {}) do
      if not isKantoMap(mapId) and block then
        collectSlots(set, block.slots)
      end
    end
  end

  -- Fishing: map → fishGroup via gen2Maps (or Data.maps).
  local data = liveData(mod)
  local maps = data and (data.gen2Maps or data.maps)
  if maps and enc.fishGroups then
    for mapId, def in pairs(maps) do
      if not isKantoMap(mapId) and type(def) == "table" and def.fishGroup then
        collectFishGroup(set, enc.fishGroups[def.fishGroup])
      end
    end
  end

  if enc.trees and enc.treeSets then
    for mapId, setName in pairs(enc.trees) do
      if not isKantoMap(mapId) then
        collectTreeSet(set, enc.treeSets[setName])
      end
    end
  end
  if enc.rocks and enc.treeSets then
    for mapId, setName in pairs(enc.rocks) do
      if not isKantoMap(mapId) then
        collectTreeSet(set, enc.treeSets[setName])
      end
    end
  end

  return set
end

local function pokemonLookup(mod)
  local data = liveData(mod)
  local okPack, pack = pcall(require, "mods.Kanto-Reforged.pokemon.pokemon_data")
  if not okPack then pack = nil end
  local function get(id)
    if not id then return nil end
    local reg = mod and mod.content and mod.content.pokemon
    if reg and reg.get then
      local rec = reg:get(id)
      if rec then return rec end
    end
    if data and data.pokemon and data.pokemon[id] then
      return data.pokemon[id]
    end
    if pack and pack.species and pack.species[id] then
      return pack.species[id]
    end
    return nil
  end
  return get
end

-- Build parent→children from evolutions[] so we can walk up without evolvesFrom.
local function evoChildrenIndex(get)
  local kids = {}
  local seen = {}
  local queue = {}
  -- Seed from any id we can reach via content / data / pack.
  local function enqueueKnown()
    local data = liveData(nil)
    if data and data.pokemon then
      for id in pairs(data.pokemon) do queue[#queue + 1] = id end
    end
    local okPack, pack = pcall(require, "mods.Kanto-Reforged.pokemon.pokemon_data")
    if okPack and pack and pack.species then
      for id in pairs(pack.species) do queue[#queue + 1] = id end
    end
  end
  enqueueKnown()
  while #queue > 0 do
    local id = table.remove(queue)
    if not seen[id] then
      seen[id] = true
      local rec = get(id)
      for _, evo in ipairs((rec and rec.evolutions) or {}) do
        local child = evo and evo.species
        if child then
          kids[id] = kids[id] or {}
          kids[id][#kids[id] + 1] = child
          if not seen[child] then queue[#queue + 1] = child end
        end
      end
    end
  end
  return kids
end

function JohtoDex.expandObtainable(set, mod)
  local get = pokemonLookup(mod)
  local kids = evoChildrenIndex(get)
  local out = {}
  for sp in pairs(set or {}) do out[sp] = true end

  local function add(sp)
    if not sp or out[sp] then return end
    out[sp] = true
  end

  -- Repeat until closure (short lines; capped).
  for _ = 1, 8 do
    local grew = false
    local snapshot = {}
    for sp in pairs(out) do snapshot[#snapshot + 1] = sp end
    for _, sp in ipairs(snapshot) do
      local rec = get(sp)
      -- Breed baby / prevo
      local from = rec and rec.evolvesFrom
      if from and not out[from] and get(from) then
        add(from)
        grew = true
      end
      -- Also walk kids graph for parents that lack evolvesFrom on children.
      for parent, children in pairs(kids) do
        for _, child in ipairs(children) do
          if child == sp and not out[parent] and get(parent) then
            add(parent)
            grew = true
          end
        end
      end
      -- Forward evolutions
      for _, evo in ipairs((rec and rec.evolutions) or {}) do
        local child = evo and evo.species
        if child and not out[child] and get(child) then
          add(child)
          grew = true
        end
      end
      for _, child in ipairs(kids[sp] or {}) do
        if not out[child] and get(child) then
          add(child)
          grew = true
        end
      end
    end
    if not grew then break end
  end
  return out
end

function JohtoDex.obtainableSet(mod)
  local set = JohtoDex.collectJohtoWildSpecies(mod)
  set = JohtoDex.expandObtainable(set, mod)
  for id in pairs(JohtoDex.STATIC_LEGENDS) do
    set[id] = true
  end
  -- JOHTO 251 scope: NEW must not list Gen3 even if sticky wild slots remain.
  local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
  if SpeciesScope.mode(mod) == SpeciesScope.MODE_JOHTO_NATIVE then
    local get = pokemonLookup(mod)
    local dexSheet = livePokedex(mod)
    for id in pairs(set) do
      if not JohtoDex.STATIC_LEGENDS[id] then
        local rec = get(id)
        local d = (rec and rec.dex)
          or (dexSheet and dexSheet.entries and dexSheet.entries[id]
            and dexSheet.entries[id].dex)
        if d and d > SpeciesScope.JOHTO_MAX_DEX then
          set[id] = nil
        end
      end
    end
  end
  return set
end

function JohtoDex.snapshotVanillaNewOrder(mod)
  if vanillaNewOrder and #vanillaNewOrder >= 200 then return vanillaNewOrder end
  local dex = livePokedex(mod)
  if dex and dex.newOrder and #dex.newOrder >= 200 then
    vanillaNewOrder = {}
    for i, id in ipairs(dex.newOrder) do
      vanillaNewOrder[i] = id
    end
    return vanillaNewOrder
  end
  -- Headless / partial boots: ROM sheet on the Data module (no filesystem).
  local ok, Data = pcall(require, "src.core.Data")
  local poke = ok and Data and Data.gen2Pokedex
  if poke and poke.newOrder and #poke.newOrder >= 200 then
    vanillaNewOrder = {}
    for i, id in ipairs(poke.newOrder) do
      vanillaNewOrder[i] = id
    end
    if dex then
      dex.entries = dex.entries or {}
      for id, row in pairs(poke.entries or {}) do
        if not dex.entries[id] then dex.entries[id] = row end
      end
    end
    return vanillaNewOrder
  end
  if dex and dex.newOrder and #dex.newOrder > 0 then
    vanillaNewOrder = {}
    for i, id in ipairs(dex.newOrder) do
      vanillaNewOrder[i] = id
    end
    return vanillaNewOrder
  end
  return nil
end

function JohtoDex.clearVanillaSnapshot()
  vanillaNewOrder = nil
end

local function entryDex(dex, id)
  local e = dex.entries and dex.entries[id]
  return (e and e.dex) or 0
end

local function entryName(dex, id, get)
  local e = dex.entries and dex.entries[id]
  if e and e.name then return tostring(e.name) end
  local rec = get and get(id)
  return tostring((rec and rec.name) or id)
end

--- Rebuild NEW + A-Z from Johto availability. Entries / OLD left intact.
function JohtoDex.rebuildOrders(mod)
  local dex = livePokedex(mod)
  if not dex then return 0 end
  dex.entries = dex.entries or {}

  -- Capture ROM Johto order before any KR appends (call bind first without append).
  JohtoDex.snapshotVanillaNewOrder(mod)
  local base = vanillaNewOrder
  if not base or #base == 0 then
    -- Fallback: whatever newOrder exists now, take first 251-ish unique.
    base = {}
    for _, id in ipairs(dex.newOrder or {}) do
      base[#base + 1] = id
      if #base >= 251 then break end
    end
    vanillaNewOrder = base
  end

  local avail = JohtoDex.obtainableSet(mod)
  local get = pokemonLookup(mod)

  local newOrder, used = {}, {}
  for _, id in ipairs(base) do
    if avail[id] and dex.entries[id] and not used[id] then
      used[id] = true
      newOrder[#newOrder + 1] = id
    end
  end

  local extras = {}
  for id in pairs(avail) do
    if not used[id] and dex.entries[id] then
      extras[#extras + 1] = id
    end
  end
  table.sort(extras, function(a, b)
    local da, db = entryDex(dex, a), entryDex(dex, b)
    if da ~= db then return da < db end
    return a < b
  end)
  for _, id in ipairs(extras) do
    newOrder[#newOrder + 1] = id
  end

  local alpha = {}
  for i, id in ipairs(newOrder) do alpha[i] = id end
  table.sort(alpha, function(a, b)
    local na, nb = entryName(dex, a, get), entryName(dex, b, get)
    if na ~= nb then return na < nb end
    return a < b
  end)

  dex.newOrder = newOrder
  dex.alphabeticalOrder = alpha

  -- Mirror onto Data module for headless tests that only read that table.
  local ok, Data = pcall(require, "src.core.Data")
  if ok and Data then
    Data.gen2Pokedex = dex
  end

  return #newOrder
end

-- Engine Nests.find reads Gen1 keys (encounters / maps). Gold live wilds are
-- gen2Encounters / gen2Maps — proxy those onto the keys the stock finder uses.
function JohtoDex.installNests(mod)
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  local ok, Nests = pcall(require, "src.core.gen2.Nests")
  if not ok or not Nests or Nests._krJohtoEnc then return end
  Gen1Patch.apply(Nests, function(N)
    if N._krJohtoEnc then return end
    local orig = N.find
    if type(orig) ~= "function" then return end
    N.find = function(data, species, region, save)
      if not data then return orig(data, species, region, save) end
      local enc = data.gen2Encounters or data.encounters
      local maps = data.maps or data.gen2Maps
      local needsProxy = (enc ~= nil and data.encounters ~= enc)
        or (maps ~= nil and data.maps ~= maps)
      if not needsProxy then
        return orig(data, species, region, save)
      end
      local proxy = setmetatable({
        encounters = enc,
        gen2Encounters = enc,
        maps = maps,
        gen2Maps = maps,
      }, { __index = data })
      return orig(proxy, species, region, save)
    end
    N._krJohtoEnc = true
  end)
  if mod and mod.log then
    mod.log:info("Johto dex: AREA nests use gen2Encounters")
  end
end

-- Engine PokedexMenu AREA draws self.gfx.maps (never extracted onto pokedex
-- chrome) and landmarks via data.landmarks. Gold keeps the town map on
-- gen2MenuGfx.pokegear and landmarks under gen2Landmarks.
function JohtoDex.installArea(mod)
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  local ok, PM = pcall(require, "src.ui.gen2.PokedexMenu")
  if not ok or not PM or PM._krAreaMap then return end
  Gen1Patch.apply(PM, function(PokedexMenu)
    if PokedexMenu._krAreaMap then return end
    local Chrome = require("src.ui.gen2.Chrome")
    local TileSheet = require("src.ui.gen2.TileSheet")
    local Nests = require("src.core.gen2.Nests")
    local TILE_BG = 0x32

    function PokedexMenu:playerLandmark()
      local save = self.game and self.game.save
      local mapId = save and save.position and save.position.map
      local maps = self.data and (self.data.maps or self.data.gen2Maps)
      local def = mapId and maps and maps[mapId]
      return def and def.landmark
    end

    function PokedexMenu:townMapGfx()
      if self._townMap then return self._townMap end
      local gear = self.data and self.data.gen2MenuGfx
        and self.data.gen2MenuGfx.pokegear
      if not (gear and gear.maps and gear.tiles) then
        self._townMap = false
        return nil
      end
      self._townMap = {
        maps = gear.maps,
        gfx = gear,
        sheet = TileSheet.new({
          path = gear.tiles,
          wide = gear.tilesWide or 16,
          firstTile = 0,
          paletteFor = function(tile)
            if not gear.palettes then return nil end
            if tile >= 0x60 then return gear.palettes[1] end
            return gear.palettes[(gear.palMap and gear.palMap[tile + 1]) or 1]
          end,
        }),
      }
      return self._townMap
    end

    function PokedexMenu:drawTilemap(cells, sheet)
      if type(cells) ~= "table" then return end
      local prev = self.sheet
      if sheet then self.sheet = sheet end
      local i = 1
      for ty = 0, Chrome.SCREEN_H - 1 do
        for tx = 0, Chrome.SCREEN_W - 1 do
          local id = cells[i]
          if id then self:tile(id, tx, ty) end
          i = i + 1
        end
      end
      self.sheet = prev
    end

    function PokedexMenu:drawArea()
      local row = self:current()
      if not row then return end
      local region = self:areaRegionName()
      local save = self.game and self.game.save
      local nests = Nests.find(self.data, row.species, region, save)

      self:fill(TILE_BG, 0, 0, Chrome.SCREEN_W + 1, Chrome.SCREEN_H)

      local town = self:townMapGfx()
      local maps = (self.gfx and self.gfx.maps) or (town and town.maps)
      local cells = maps and maps[region]
      local mapSheet = (self.gfx and self.gfx.maps and self.sheet)
        or (town and town.sheet)
      if cells then
        self:drawTilemap(cells, mapSheet)
      end

      self:blank(0, 0, Chrome.SCREEN_W, 2)
      self:text(self:monName(row.species) .. "'S NEST", 1, 0)
      self:text(region == "kanto" and "KANTO" or "JOHTO", 1, 1)

      local G = love.graphics
      local table_ = self.data
        and (self.data.landmarks or self.data.gen2Landmarks)
      local byIndex = self.landmarkByIndex
      if not byIndex then
        byIndex = {}
        for _, entry in pairs((table_ and table_.landmarks) or {}) do
          if entry and entry.index then byIndex[entry.index] = entry end
        end
        self.landmarkByIndex = byIndex
      end

      if #nests == 0 then
        self:text("AREA UNKNOWN", 4, 16)
        return
      end

      local on = ((self.areaBlink or 0) % 32) < 20
      if cells and on then
        for _, index in ipairs(nests) do
          local mark = byIndex[index]
          if mark and mark.x and mark.y then
            G.setColor(0, 0, 0, 1)
            G.rectangle("fill", mark.x - 2, mark.y - 2, 5, 5)
            G.setColor(1, 1, 1, 1)
            G.rectangle("fill", mark.x - 1, mark.y - 1, 3, 3)
          end
        end
      end

      local first = byIndex[nests[1]]
      if first and first.name then
        local name = tostring(first.name):gsub("\n", " ")
        self:text(name, 1, 16)
        if #nests > 1 then
          self:text(("+%d"):format(#nests - 1), 17, 16)
        end
      end
    end

    PokedexMenu._krAreaMap = true
  end)
  if mod and mod.log then
    mod.log:info("Johto dex: AREA town map from pokegear + gen2Landmarks")
  end
end

JohtoDex._liveData = liveData
JohtoDex._liveEncounters = liveEncounters
JohtoDex._livePokedex = livePokedex

return JohtoDex
