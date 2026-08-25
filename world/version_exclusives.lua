-- Cross-inject host version exclusives so every cart can catch the bases
-- that other carts in the same generation have in the wild.
-- Lists are public knowledge (Serebii / Bulbapedia); story mascots stay cart-bound.

local Host = require("mods.Kanto-Reforged.core.host")
local Merge = require("src.mods.Merge")

local VersionExclusives = {}

-- Per-host missing bases (evolutions via level / stones).
local MISSING = {
  red = { "SANDSHREW", "VULPIX", "MEOWTH", "BELLSPROUT", "MAGMAR", "PINSIR" },
  blue = { "EKANS", "ODDISH", "MANKEY", "GROWLITHE", "SCYTHER", "ELECTABUZZ" },
  yellow = {
    "WEEDLE", "EKANS", "MEOWTH", "KOFFING", "JYNX", "ELECTABUZZ", "MAGMAR",
  },
  gold = { "VULPIX", "MEOWTH", "LEDYBA", "DELIBIRD", "SKARMORY", "PHANPY" },
  silver = {
    "MANKEY", "GROWLITHE", "SPINARAK", "GLIGAR", "TEDDIURSA", "MANTINE",
  },
  crystal = { "VULPIX", "MANKEY", "MAREEP", "GIRAFARIG", "REMORAID" },
}

-- Classic homes: one grass/water slot each.
-- Gen1: 10-slot grass. Gen2 grass: 7 TOD slots; water: flat slots.
local PLACE = {
  -- Gen1
  EKANS = { map = "ROUTE_11", kind = "grass", slot = 8 },
  SANDSHREW = { map = "ROUTE_11", kind = "grass", slot = 8 },
  ODDISH = { map = "ROUTE_12", kind = "grass", slot = 8 },
  BELLSPROUT = { map = "ROUTE_12", kind = "grass", slot = 8 },
  MANKEY = { map = "ROUTE_5", kind = "grass", slot = 8 },
  MEOWTH = { map = "ROUTE_5", kind = "grass", slot = 8 },
  GROWLITHE = { map = "ROUTE_7", kind = "grass", slot = 8 },
  VULPIX = { map = "ROUTE_7", kind = "grass", slot = 8 },
  SCYTHER = { map = "SAFARI_ZONE_CENTER", kind = "grass", slot = 9 },
  PINSIR = { map = "SAFARI_ZONE_CENTER", kind = "grass", slot = 9 },
  ELECTABUZZ = { map = "POWER_PLANT", kind = "grass", slot = 9 },
  MAGMAR = { map = "POKEMON_MANSION_B1F", kind = "grass", slot = 8 },
  WEEDLE = { map = "VIRIDIAN_FOREST", kind = "grass", slot = 2 },
  KOFFING = { map = "POKEMON_MANSION_B1F", kind = "grass", slot = 2 },
  JYNX = { map = "SEAFOAM_ISLANDS_B4F", kind = "grass", slot = 8 },
  -- Gen2 (Johto / early Kanto; water where classic)
  LEDYBA = { map = "ROUTE_30", kind = "grass", slot = 6 },
  SPINARAK = { map = "ROUTE_30", kind = "grass", slot = 6 },
  MAREEP = { map = "ROUTE_32", kind = "grass", slot = 6 },
  GIRAFARIG = { map = "ROUTE_43", kind = "grass", slot = 6 },
  GLIGAR = { map = "ROUTE_45", kind = "grass", slot = 6 },
  SKARMORY = { map = "ROUTE_45", kind = "grass", slot = 6 },
  TEDDIURSA = { map = "ROUTE_45", kind = "grass", slot = 5 },
  PHANPY = { map = "ROUTE_46", kind = "grass", slot = 6 },
  DELIBIRD = { map = "ICE_PATH_1F", kind = "grass", slot = 6 },
  -- Gen2 uses Johto Route 37 for fox/dog; Route 42 for Mankey; Route 38 Meowth.
  -- (VULPIX/GROWLITHE/MANKEY/MEOWTH keys above are Gen1 maps; Gen2 overrides.)
  MANTINE = { map = "ROUTE_41", kind = "water", slot = 3 },
  REMORAID = { map = "ROUTE_44", kind = "water", slot = 2 },
}

-- Gen2-specific placements for species that also appear in Gen1 PLACE.
local PLACE_GEN2 = {
  VULPIX = { map = "ROUTE_37", kind = "grass", slot = 6 },
  GROWLITHE = { map = "ROUTE_37", kind = "grass", slot = 6 },
  MEOWTH = { map = "ROUTE_38", kind = "grass", slot = 6 },
  MANKEY = { map = "ROUTE_42", kind = "grass", slot = 6 },
}

local function placementFor(species)
  if Host.isGen2() and PLACE_GEN2[species] then
    return PLACE_GEN2[species]
  end
  return PLACE[species]
end

local function copyFlatSlots(slots)
  local out = {}
  for i, slot in ipairs(slots or {}) do
    out[i] = { species = slot.species, level = slot.level }
  end
  return out
end

local function slotHas(slots, species)
  for _, s in ipairs(slots or {}) do
    if s.species == species then return true end
  end
  return false
end

-- Vanilla Safari / late rares must not be clobbered when cross-injecting
-- the counterpart exclusive (Red Pinsir must not erase Scyther, etc.).
local PROTECTED = {
  CHANSEY = true, DRAGONAIR = true, DRAGONITE = true,
  SCYTHER = true, PINSIR = true, KANGASKHAN = true, TAUROS = true,
}

local function writeSlot(slots, index, species)
  if not slots or #slots == 0 then return false end
  local function canOverwrite(slot)
    if not slot or not slot.species then return true end
    if slot.species == species then return true end
    return not PROTECTED[slot.species]
  end
  local preferred = math.min(math.max(index or #slots, 1), #slots)
  local candidates = { preferred }
  for i = #slots, 1, -1 do
    if i ~= preferred then candidates[#candidates + 1] = i end
  end
  for _, idx in ipairs(candidates) do
    if canOverwrite(slots[idx]) then
      local level = slots[idx].level or 5
      slots[idx] = { species = species, level = level }
      return true
    end
  end
  return false
end

-- ------- Gen1 (flat map → grass/water) --------------------------------------

local function gen1Get(mod, mapId)
  local ok, enc = pcall(function()
    return mod.content.encounters:get(mapId)
  end)
  if ok and enc then return enc end
  local Data = require("src.core.Data")
  return Data.encounters and Data.encounters[mapId]
end

local function gen1Patch(mod, mapId, kind, slots)
  local partial = { [kind] = { slots = slots } }
  local ok = pcall(function()
    mod.content.encounters:patch(mapId, partial)
  end)
  if ok then return end
  local Data = require("src.core.Data")
  Data.encounters = Data.encounters or {}
  local dest = Data.encounters[mapId]
  if not dest then
    Data.encounters[mapId] = {}
    dest = Data.encounters[mapId]
  end
  for k, block in pairs(partial) do
    if type(block) == "table" and type(dest[k]) == "table" then
      Merge.deepMerge(dest[k], block, "record")
    else
      dest[k] = block
    end
  end
end

local function injectGen1(mod, species, place)
  local enc = gen1Get(mod, place.map)
  local block = enc and enc[place.kind]
  if not (block and block.slots and #block.slots > 0) then
    return false
  end
  if slotHas(block.slots, species) then
    return true
  end
  local slots = copyFlatSlots(block.slots)
  if not writeSlot(slots, place.slot, species) then
    return false
  end
  gen1Patch(mod, place.map, place.kind, slots)
  return true
end

-- ------- Gen2 (grass TOD / water) -------------------------------------------

local function gen2Root(mod)
  local game = mod and Host.liveGame(mod)
  local root = game and game.data and game.data.gen2Encounters
  if root then return root end
  local Data = require("src.core.Data")
  Data.gen2Encounters = Data.gen2Encounters or {}
  return Data.gen2Encounters
end

local function gen2Patch(mod, kind, mapId, block)
  pcall(function()
    mod.content.encounters:patch(kind, { [mapId] = block })
  end)
  local root = gen2Root(mod)
  root[kind] = root[kind] or {}
  root[kind][mapId] = block
  root[kind]["KR_" .. mapId] = block
end

local function injectGen2Grass(mod, species, place)
  local root = gen2Root(mod)
  local grass = root.grass and root.grass[place.map]
  if not (grass and grass.slots) then
    return false
  end
  for _, tod in ipairs({ "MORN", "DAY", "NITE" }) do
    if slotHas(grass.slots[tod], species) then
      return true
    end
  end
  local slots = {}
  local rates = {}
  for k, v in pairs(grass.rates or {}) do rates[k] = v end
  for _, tod in ipairs({ "MORN", "DAY", "NITE" }) do
    local copy = copyFlatSlots(grass.slots[tod])
    writeSlot(copy, place.slot, species)
    slots[tod] = copy
  end
  gen2Patch(mod, "grass", place.map, {
    rates = rates,
    slots = slots,
    map = grass.map or place.map,
  })
  return true
end

local function injectGen2Water(mod, species, place)
  local root = gen2Root(mod)
  local water = root.water and root.water[place.map]
  if not (water and water.slots and #water.slots > 0) then
    return false
  end
  if slotHas(water.slots, species) then
    return true
  end
  local slots = copyFlatSlots(water.slots)
  writeSlot(slots, place.slot, species)
  gen2Patch(mod, "water", place.map, {
    rate = water.rate,
    map = water.map or place.map,
    slots = slots,
  })
  return true
end

local function injectGen2(mod, species, place)
  if place.kind == "water" then
    return injectGen2Water(mod, species, place)
  end
  return injectGen2Grass(mod, species, place)
end

function VersionExclusives.apply(mod)
  local vid = Host.versionId()
  local list = MISSING[vid]
  if not list then return 0 end

  local n = 0
  for _, species in ipairs(list) do
    local place = placementFor(species)
    if place then
      local ok
      if Host.isGen2() then
        ok = injectGen2(mod, species, place)
      else
        ok = injectGen1(mod, species, place)
      end
      if ok then n = n + 1 end
    end
  end
  if mod and mod.log and n > 0 then
    mod.log:info("version exclusives: injected %d missing bases for %s", n, vid)
  end
  return n
end

-- Test/debug exports
VersionExclusives.MISSING = MISSING
VersionExclusives.PLACE = PLACE
VersionExclusives.PLACE_GEN2 = PLACE_GEN2
VersionExclusives.placementFor = placementFor

return VersionExclusives
