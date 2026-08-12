-- Gen2 encounter mixing:
--   curated (default):
--     * Kanto — full Gen3 grass tables (TOD-biased habitat pools, postgame
--       levels). No legendaries / starters / mid-stage cocoons.
--     * Johto — keep Gold natives; inject a couple of habitat-fitting Gen3
--       basics into rare slots, clamped to each species' wild level band.
--   full_random (FULL SPAWN MIX toggle):
--     * All Johto + Kanto grass/water maps reshuffled from Gen 1–3
--       (level/stage gated, legends excluded).
--     * Density pass so both regions keep a solid unique share (Kanto
--       especially, so the second region does not feel hollow).
local EncountersGen2 = {}

-- Gold Kanto outdoor grass maps (postgame bands). Levels biased above Gen1 early-game.
local KANTO_GRASS = {
  ROUTE_1 = { level = 28, habitats = { "grassland" } },
  ROUTE_2 = { level = 28, habitats = { "grassland" } },
  ROUTE_3 = { level = 30, habitats = { "grassland", "mountain" } },
  ROUTE_4 = { level = 32, habitats = { "grassland", "mountain" } },
  ROUTE_5 = { level = 30, habitats = { "urban" } },
  ROUTE_6 = { level = 30, habitats = { "urban", "waters-edge" } },
  ROUTE_7 = { level = 32, habitats = { "urban", "grassland" } },
  ROUTE_8 = { level = 32, habitats = { "urban" } },
  ROUTE_9 = { level = 34, habitats = { "mountain" } },
  ROUTE_10_NORTH = { level = 34, habitats = { "mountain" } },
  ROUTE_10_SOUTH = { level = 34, habitats = { "mountain" } },
  ROUTE_11 = { level = 32, habitats = { "grassland", "urban" } },
  ROUTE_12 = { level = 34, habitats = { "grassland", "waters-edge" } },
  ROUTE_13 = { level = 34, habitats = { "grassland" } },
  ROUTE_14 = { level = 34, habitats = { "grassland" } },
  ROUTE_15 = { level = 34, habitats = { "grassland" } },
  ROUTE_16 = { level = 36, habitats = { "mountain" } },
  ROUTE_17 = { level = 36, habitats = { "grassland" } },
  ROUTE_18 = { level = 36, habitats = { "grassland" } },
  ROUTE_21 = { level = 32, habitats = { "grassland", "sea" } },
  ROUTE_22 = { level = 30, habitats = { "grassland" } },
  ROUTE_24 = { level = 32, habitats = { "waters-edge", "forest" } },
  ROUTE_25 = { level = 32, habitats = { "waters-edge", "forest" } },
  ROUTE_26 = { level = 38, habitats = { "grassland", "mountain" } },
  ROUTE_27 = { level = 38, habitats = { "grassland", "mountain" } },
  ROUTE_28 = { level = 40, habitats = { "mountain" } },
  VIRIDIAN_FOREST = { level = 28, habitats = { "forest" } },
}

-- Johto: a few Gen3 guests per grass map (not a full Hoenn reload).
local JOHTO_GUESTS = {
  ROUTE_29 = { level = 4, habitats = { "grassland" }, count = 2 },
  ROUTE_30 = { level = 6, habitats = { "grassland", "forest" }, count = 2 },
  ROUTE_31 = { level = 6, habitats = { "forest" }, count = 2 },
  ROUTE_32 = { level = 8, habitats = { "grassland", "waters-edge" }, count = 2 },
  ROUTE_33 = { level = 8, habitats = { "mountain" }, count = 2 },
  ROUTE_34 = { level = 12, habitats = { "grassland" }, count = 2 },
  ROUTE_35 = { level = 14, habitats = { "grassland", "forest" }, count = 2 },
  ROUTE_36 = { level = 14, habitats = { "grassland" }, count = 2 },
  ROUTE_37 = { level = 16, habitats = { "forest" }, count = 2 },
  ROUTE_38 = { level = 18, habitats = { "grassland" }, count = 2 },
  ROUTE_39 = { level = 18, habitats = { "grassland" }, count = 2 },
  ROUTE_42 = { level = 20, habitats = { "mountain", "waters-edge" }, count = 2 },
  ROUTE_43 = { level = 22, habitats = { "forest", "waters-edge" }, count = 2 },
  ROUTE_44 = { level = 24, habitats = { "mountain" }, count = 2 },
  ROUTE_45 = { level = 26, habitats = { "mountain" }, count = 2 },
  ROUTE_46 = { level = 10, habitats = { "mountain", "grassland" }, count = 2 },
  ILEX_FOREST = { level = 12, habitats = { "forest" }, count = 2 },
  NATIONAL_PARK = { level = 14, habitats = { "grassland", "forest" }, count = 2 },
  VICTORY_ROAD = { level = 40, habitats = { "cave", "mountain" }, count = 2 },
  DARK_CAVE_VIOLET_ENTRANCE = { level = 8, habitats = { "cave" }, count = 2 },
  DARK_CAVE_BLACKTHORN_ENTRANCE = { level = 28, habitats = { "cave" }, count = 2 },
  UNION_CAVE_1F = { level = 10, habitats = { "cave" }, count = 2 },
  SLOWPOKE_WELL_B1F = { level = 10, habitats = { "cave", "waters-edge" }, count = 2 },
}

-- Habitat pools for Kanto full reloads (postgame levels). Still no
-- legendaries / starters / mid-stage cocoons — only wild-sensible forms.
local HABITAT_POOL = {
  grassland = {
    "POOCHYENA", "ZIGZAGOON", "SEEDOT", "RALTS", "WHISMUR", "SKITTY",
    "ELECTRIKE", "PLUSLE", "MINUN", "GULPIN", "SPOINK", "SWABLU",
    "ZANGOOSE", "SEVIPER", "TAILLOW", "VOLBEAT", "ILLUMISE",
  },
  forest = {
    "WURMPLE", "NINCADA", "SHROOMISH", "SEEDOT",
    "SLAKOTH", "TAILLOW", "VOLBEAT", "ILLUMISE",
  },
  mountain = {
    "ARON", "NUMEL", "MAKUHITA", "MEDITITE", "ABSOL", "TRAPINCH",
  },
  urban = {
    "POOCHYENA", "ZIGZAGOON", "SKITTY", "ELECTRIKE", "SPOINK", "SHUPPET",
    "DUSKULL", "PLUSLE", "MINUN",
  },
  ["waters-edge"] = {
    "LOTAD", "SURSKIT", "BARBOACH", "CORPHISH", "CARVANHA",
  },
  sea = { "WINGULL", "CARVANHA", "WAILMER" },
  cave = { "WHISMUR", "ARON", "NOSEPASS", "MAWILE", "SABLEYE", "DUSKULL" },
}

-- Wild level bands (min..max). Johto inject and Kanto slot builds both
-- refuse species outside the route's band so Route 29 never rolls Absol
-- and Victory Road never rolls Zigzagoon.
local WILD_LEVEL = {
  -- early Johto commons
  ZIGZAGOON = { 2, 12 }, POOCHYENA = { 2, 14 }, WURMPLE = { 2, 10 },
  TAILLOW = { 2, 14 }, WINGULL = { 2, 16 }, LOTAD = { 2, 14 },
  SEEDOT = { 2, 14 }, RALTS = { 4, 16 }, WHISMUR = { 4, 16 },
  SHROOMISH = { 4, 16 }, SLAKOTH = { 4, 16 }, NINCADA = { 4, 16 },
  SKITTY = { 4, 16 }, ELECTRIKE = { 4, 16 }, PLUSLE = { 4, 16 },
  MINUN = { 4, 16 }, SURSKIT = { 4, 16 }, ARON = { 5, 20 },
  MAKUHITA = { 6, 20 }, MEDITITE = { 6, 20 },
  -- mid
  GULPIN = { 10, 22 }, SPOINK = { 12, 24 }, SWABLU = { 12, 26 },
  NUMEL = { 12, 26 }, TRAPINCH = { 12, 26 }, VOLBEAT = { 12, 24 },
  ILLUMISE = { 12, 24 }, BARBOACH = { 10, 24 }, CORPHISH = { 10, 24 },
  CARVANHA = { 14, 28 }, SHUPPET = { 14, 28 }, DUSKULL = { 14, 28 },
  NOSEPASS = { 14, 28 }, MAWILE = { 16, 30 }, SABLEYE = { 16, 30 },
  WAILMER = { 16, 32 },
  -- late / postgame
  ZANGOOSE = { 24, 45 }, SEVIPER = { 24, 45 }, ABSOL = { 28, 45 },
}

local function levelBand(species)
  return WILD_LEVEL[species]
end

local function fitsRouteLevel(species, routeLevel)
  local band = levelBand(species)
  if not band then return false end
  routeLevel = routeLevel or 5
  -- Allow a little slack above max so a route tagged level 18 can still
  -- host a species whose wild band tops out at 16.
  return routeLevel >= band[1] and routeLevel <= band[2] + 4
end

local function clampWildLevel(species, level)
  local band = levelBand(species)
  level = math.max(2, math.floor(tonumber(level) or 5))
  if not band then return level end
  if level < band[1] then return band[1] end
  if level > band[2] then return band[2] end
  return level
end

-- Soft TOD bias (Gen3 flavor riding Gen2 MORN/DAY/NITE).
local TOD_PREF = {
  TAILLOW = "day", SWABLU = "day", WINGULL = "day",
  PLUSLE = "day", MINUN = "day", ELECTRIKE = "day",
  NINCADA = "day", ZANGOOSE = "day", NUMEL = "day", TRAPINCH = "day",
  VOLBEAT = "nite", ILLUMISE = "nite",
  POOCHYENA = "nite", SHUPPET = "nite", DUSKULL = "nite",
  SABLEYE = "nite", ABSOL = "nite", GULPIN = "nite",
  SPOINK = "nite", SEVIPER = "nite", BARBOACH = "nite",
  CARVANHA = "nite", MAWILE = "nite",
}

local function normalizeTod(tod)
  if tod == "DARK" or tod == "NITE" then return "NITE" end
  if tod == "MORN" then return "MORN" end
  return "DAY"
end

local function prefOf(species)
  return TOD_PREF[species] or "any"
end

local function fitsTod(species, tod)
  local pref = prefOf(species)
  if pref == "any" then return true end
  tod = normalizeTod(tod)
  if pref == "day" then return tod == "MORN" or tod == "DAY" end
  if pref == "nite" then return tod == "NITE" end
  return true
end

local function poolFor(habitats, routeLevel)
  local seen, out = {}, {}
  for _, h in ipairs(habitats or {}) do
    for _, sp in ipairs(HABITAT_POOL[h] or {}) do
      if not seen[sp] and fitsRouteLevel(sp, routeLevel) then
        seen[sp] = true
        out[#out + 1] = sp
      end
    end
  end
  return out
end

local function orderForTod(speciesList, tod)
  tod = normalizeTod(tod)
  local match, any, other = {}, {}, {}
  for _, sp in ipairs(speciesList) do
    local pref = prefOf(sp)
    if pref == "any" then
      any[#any + 1] = sp
    elseif fitsTod(sp, tod) then
      match[#match + 1] = sp
    else
      other[#other + 1] = sp
    end
  end
  local out = {}
  for _, sp in ipairs(match) do out[#out + 1] = sp end
  for _, sp in ipairs(any) do out[#out + 1] = sp end
  for _, sp in ipairs(other) do out[#out + 1] = sp end
  return out
end

local function filterRegistered(mod, speciesList)
  local usable = {}
  local registry = mod and mod.content and mod.content.pokemon
  for _, sp in ipairs(speciesList) do
    if not registry then
      usable[#usable + 1] = sp
    elseif registry.get and registry:get(sp) then
      usable[#usable + 1] = sp
    end
  end
  return usable
end

local function todSlots(speciesList, level, tod)
  -- Gen2 grass: 7 slots, odds 30/30/20/10/5/4/1 — named {species, level} records.
  local n = #speciesList
  if n == 0 then return nil end
  local commons = {}
  for _, s in ipairs(speciesList) do
    if prefOf(s) == "any" or fitsTod(s, tod) then
      commons[#commons + 1] = s
    end
  end
  if #commons == 0 then commons = speciesList end
  local full = {}
  for i = 1, 7 do
    local sp = (i <= 3)
      and commons[((i - 1) % #commons) + 1]
      or speciesList[((i - 1) % n) + 1]
    full[i] = {
      species = sp,
      level = clampWildLevel(sp, level + (i % 3) - 1),
    }
  end
  return full
end

local function slotsFor(mod, habitats, level, tod)
  local base = filterRegistered(mod, poolFor(habitats, level))
  if #base == 0 then return nil end
  return todSlots(orderForTod(base, tod), level, tod)
end

local function patchMap(mod, mapId, info)
  local morn = slotsFor(mod, info.habitats, info.level, "MORN")
  local day = slotsFor(mod, info.habitats, info.level, "DAY")
  local nite = slotsFor(mod, info.habitats, info.level, "NITE")
  if not (morn and day and nite) then return false end

  local block = {
    rates = { MORN = 25, DAY = 25, NITE = 25 },
    slots = {
      MORN = morn,
      DAY = day,
      NITE = nite,
    },
  }
  local ok, err = pcall(function()
    mod.content.encounters:patch("grass", { [mapId] = block })
  end)
  if not ok then
    mod.log:warn("encounters_gen2 patch %s failed: %s", mapId, tostring(err))
    return false
  end
  return true
end

local function hashId(s)
  local h = 2166136261
  for i = 1, #s do
    h = (h * 16777619 + s:byte(i)) % 2147483647
  end
  return h
end

-- Stable pick of `count` Gen3 guests for a Johto map. Habitat + wild level
-- band only — no evolved lines, no out-of-place biomes.
local function pickGuests(mod, mapId, info)
  local count = info.count or 2
  local pool = filterRegistered(mod, poolFor(info.habitats, info.level))
  if #pool == 0 then return {} end
  local start = (hashId(mapId) % #pool) + 1
  local out, used = {}, {}
  for i = 0, #pool - 1 do
    local sp = pool[((start - 1 + i) % #pool) + 1]
    if not used[sp] then
      used[sp] = true
      out[#out + 1] = sp
      if #out >= count then break end
    end
  end
  return out
end

local function copySlots(slots)
  if not slots then return nil end
  local out = {}
  for i, slot in ipairs(slots) do
    out[i] = {
      species = slot.species,
      level = slot.level,
    }
  end
  return out
end

-- Keep Gold commons; overwrite the rarest slots with Gen3 guests at a level
-- that fits both the slot and the species' wild band.
local function injectGuests(slots, guests)
  local out = copySlots(slots)
  if not out or #out == 0 or not guests or #guests == 0 then return out end
  local n = math.min(#guests, #out)
  for i = 1, n do
    local idx = #out - n + i
    local sp = guests[i]
    local baseLv = out[idx].level
    out[idx].species = sp
    out[idx].level = clampWildLevel(sp, baseLv)
  end
  return out
end

local function liveGrass(mod)
  local reg = mod and mod.content and mod.content.encounters
  if not (reg and reg.get) then return nil end
  return reg:get("grass")
end

local function liveWater(mod)
  local reg = mod and mod.content and mod.content.encounters
  if not (reg and reg.get) then return nil end
  return reg:get("water")
end

local function injectJohtoMap(mod, mapId, info)
  local grassAll = liveGrass(mod)
  local grass = grassAll and grassAll[mapId]
  if not (grass and grass.slots) then return false end
  local guests = pickGuests(mod, mapId, info)
  if #guests == 0 then return false end

  local block = {
    rates = grass.rates or { MORN = 25, DAY = 25, NITE = 25 },
    slots = {
      MORN = injectGuests(grass.slots.MORN, guests),
      DAY = injectGuests(grass.slots.DAY, guests),
      NITE = injectGuests(grass.slots.NITE, guests),
    },
  }
  local ok, err = pcall(function()
    mod.content.encounters:patch("grass", { [mapId] = block })
  end)
  if not ok then
    mod.log:warn("encounters_gen2 johto inject %s failed: %s", mapId, tostring(err))
    return false
  end
  return true
end

-- Snapshot vanilla Gen2 grass/water once so curated ↔ full_random can toggle.
local baselines = { grass = {}, water = {} }

local function copyGrassBlock(block)
  if not block then return nil end
  local slots = {}
  for _, tod in ipairs({ "MORN", "DAY", "NITE" }) do
    slots[tod] = copySlots(block.slots and block.slots[tod])
  end
  local rates = {}
  for k, v in pairs(block.rates or {}) do rates[k] = v end
  return { rates = rates, slots = slots, map = block.map }
end

local function copyWaterBlock(block)
  if not block then return nil end
  return {
    rate = block.rate,
    map = block.map,
    slots = copySlots(block.slots),
  }
end

local function captureBaselines(mod)
  local grass = liveGrass(mod)
  for mapId, block in pairs(grass or {}) do
    if not baselines.grass[mapId] and block and block.slots then
      baselines.grass[mapId] = copyGrassBlock(block)
    end
  end
  local water = liveWater(mod)
  for mapId, block in pairs(water or {}) do
    if not baselines.water[mapId] and block and block.slots then
      baselines.water[mapId] = copyWaterBlock(block)
    end
  end
end

local function restoreBaselines(mod)
  for mapId, block in pairs(baselines.grass) do
    pcall(function()
      mod.content.encounters:patch("grass", { [mapId] = copyGrassBlock(block) })
    end)
  end
  for mapId, block in pairs(baselines.water) do
    pcall(function()
      mod.content.encounters:patch("water", { [mapId] = copyWaterBlock(block) })
    end)
  end
end

local function applyCurated(mod)
  local nKanto, nJohto = 0, 0
  for mapId, info in pairs(KANTO_GRASS) do
    if patchMap(mod, mapId, info) then nKanto = nKanto + 1 end
  end
  for mapId, info in pairs(JOHTO_GUESTS) do
    if not KANTO_GRASS[mapId] and injectJohtoMap(mod, mapId, info) then
      nJohto = nJohto + 1
    end
  end
  mod.log:info(
    "Gen2 encounters curated: %d Kanto maps + %d Johto guest maps",
    nKanto, nJohto)
  return nKanto + nJohto
end

-- ------- FULL SPAWN MIX (Gen1–3 across Johto + Kanto) -----------------------

local NEVER_WILD = { SHEDINJA = true }

-- Native legends / mythicals that must not roll into grass (Gen3 "rare"
-- habitat is handled via Encounters.buildIndex).
local NO_WILD_LEGEND = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true, LUGIA = true, HO_OH = true,
  CELEBI = true, REGIROCK = true, REGICE = true, REGISTEEL = true,
  LATIAS = true, LATIOS = true, KYOGRE = true, GROUDON = true,
  RAYQUAZA = true, JIRACHI = true, DEOXYS = true,
}

local KANTO_PREFIXES = {
  "VIRIDIAN", "PEWTER", "CERULEAN", "LAVENDER", "VERMILION", "CELADON",
  "FUCHSIA", "SAFFRON", "CINNABAR", "PALLET", "INDIGO",
  "MT_MOON", "ROCK_TUNNEL", "DIGLETT", "POKEMON_TOWER", "SAFARI",
  "SEAFOAM", "POWER_PLANT", "CERULEAN_CAVE", "VICTORY_ROAD",
  "TOHJO", "KANTO",
}

local function isKantoMap(mapId)
  if KANTO_GRASS[mapId] then return true end
  local n = tonumber((mapId:match("^ROUTE_(%d+)")))
  if n then return n <= 28 end
  for _, prefix in ipairs(KANTO_PREFIXES) do
    if mapId == prefix or mapId:sub(1, #prefix + 1) == prefix .. "_"
        or mapId:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

local function habitatsForMap(mapId)
  local info = KANTO_GRASS[mapId] or JOHTO_GUESTS[mapId]
  if info and info.habitats then return info.habitats end
  if mapId:find("CAVE", 1, true) or mapId:find("TUNNEL", 1, true)
      or mapId:find("WELL", 1, true) or mapId:find("MOUNTAIN", 1, true)
      or mapId:find("MORTAR", 1, true) or mapId:find("ICE_PATH", 1, true)
      or mapId:find("DRAGONS_DEN", 1, true) then
    return { "cave", "mountain" }
  end
  if mapId:find("FOREST", 1, true) or mapId:find("PARK", 1, true) then
    return { "forest", "grassland" }
  end
  if mapId:find("LAKE", 1, true) or mapId:find("WATER", 1, true) then
    return { "waters-edge", "sea" }
  end
  return { "grassland", "forest", "urban", "mountain", "waters-edge" }
end

local function bstOf(rec)
  local b = rec and (rec.baseStats or rec.stats) or {}
  return (b.hp or 0) + (b.attack or 0) + (b.defense or 0)
      + (b.speed or 0)
      + (b.special or b.specialAttack or 0)
      + (b.specialDefense or 0)
end

local function buildGoldIndex(mod, pokemon_data, allowLegends)
  local ExpEncounters = require("mods.Kanto-Reforged.encounters")
  local index = ExpEncounters.buildIndex(pokemon_data or { species = {} })
  local reg = mod and mod.content and mod.content.pokemon
  if not (reg and reg.each) then return index end

  for id, rec in reg:each() do
    if NEVER_WILD[id] then
      -- always out
    elseif not index.meta[id] and type(rec) == "table" then
      local dex = rec.dex or rec.pokedex or 0
      if dex >= 1 and dex <= 386 then
        local habitat = rec.habitat or "grassland"
        local isLegend = habitat == "rare" or NO_WILD_LEGEND[id]
        if isLegend and not allowLegends then
          -- excluded from wild mix
        else
          index.meta[id] = {
            stage = 0,
            minLevel = isLegend and 40 or 1,
            bst = bstOf(rec),
            habitat = isLegend and "rare" or habitat,
            rare = isLegend,
          }
          local hab = index.meta[id].habitat
          index.byHabitat[hab] = index.byHabitat[hab] or {}
          index.byHabitat[hab][#index.byHabitat[hab] + 1] = id
        end
      end
    elseif index.meta[id] then
      if NO_WILD_LEGEND[id] or index.meta[id].habitat == "rare" then
        index.meta[id].rare = true
        if allowLegends and (index.meta[id].minLevel or 1) < 40 then
          index.meta[id].minLevel = 40
        end
      end
    end
  end

  -- Restage Gen1/Johto using evo parents already in index when possible.
  if index.parents then
    for id, meta in pairs(index.meta) do
      if not meta.rare then
        local n, cur, seen = 0, id, {}
        while index.parents[cur] and not seen[cur] do
          seen[cur] = true
          cur = index.parents[cur]
          n = n + 1
        end
        if n > meta.stage then meta.stage = n end
      end
    end
  end
  return index
end

local function hashIndex(mapId, slotIndex, n, salt)
  if n <= 0 then return 1 end
  local h = salt or 0
  for i = 1, #mapId do
    h = (h * 33 + mapId:byte(i)) % 2147483647
  end
  h = (h * 31 + slotIndex * 17 + (salt or 0)) % 2147483647
  return (h % n) + 1
end

local function eligibleForSlot(index, habitats, slotLevel, avg, maxLv, allowLegends)
  local ExpEncounters = require("mods.Kanto-Reforged.encounters")
  local routeMaxStage = ExpEncounters.maxStageFor(avg, maxLv)
  local seen, preferred, fallback = {}, {}, {}

  local function consider(id)
    if seen[id] then return end
    local m = index.meta[id]
    if not m then return end
    if m.rare and not allowLegends then return end
    -- Legends ignore evo-stage caps but still need a high enough slot level.
    if not m.rare and m.stage > routeMaxStage then return end
    if slotLevel < (m.minLevel or 1) then return end
    if not m.rare and m.bst > ExpEncounters.bstCap(avg, m.stage) then return end
    seen[id] = true
    preferred[#preferred + 1] = id
  end

  for _, hab in ipairs(habitats or {}) do
    for _, id in ipairs(index.byHabitat[hab] or {}) do
      consider(id)
    end
  end
  if allowLegends then
    for _, id in ipairs(index.byHabitat.rare or {}) do
      consider(id)
    end
  end

  -- Soft habitat miss: still allow any eligible Gen1–3 so early Johto
  -- is not stuck with a tiny Hoenn-only curated pool.
  for id, m in pairs(index.meta) do
    if not seen[id] and m
        and (not m.rare or allowLegends)
        and (m.rare or m.stage <= routeMaxStage)
        and slotLevel >= (m.minLevel or 1)
        and (m.rare or m.bst <= ExpEncounters.bstCap(avg, m.stage)) then
      fallback[#fallback + 1] = id
    end
  end

  if #preferred > 0 then return preferred end
  table.sort(fallback)
  return fallback
end

local function slotAvgMax(slots)
  local sum, n, maxLv = 0, 0, 0
  for _, slot in ipairs(slots or {}) do
    local lv = slot.level or 0
    sum = sum + lv
    n = n + 1
    if lv > maxLv then maxLv = lv end
  end
  return (n > 0 and sum / n or 5), maxLv
end

local function rewriteGrassSlots(index, mapId, slots, allowLegends)
  if not slots or #slots == 0 then return slots end
  local avg, maxLv = slotAvgMax(slots)
  local habitats = habitatsForMap(mapId)
  local out = copySlots(slots)
  for i, slot in ipairs(out) do
    local pool = eligibleForSlot(index, habitats, slot.level or avg, avg, maxLv, allowLegends)
    if #pool > 0 then
      local chosen = pool[hashIndex(mapId, i, #pool, 0xF00D)]
      slot.species = chosen
      local meta = index.meta[chosen]
      if meta and slot.level < meta.minLevel then
        slot.level = meta.minLevel
      end
    end
  end
  return out
end

local function rewriteWaterSlots(index, mapId, slots, allowLegends)
  if not slots or #slots == 0 then return slots end
  local avg, maxLv = slotAvgMax(slots)
  local habitats = { "sea", "waters-edge" }
  local out = copySlots(slots)
  for i, slot in ipairs(out) do
    local pool = eligibleForSlot(index, habitats, slot.level or avg, avg, maxLv, allowLegends)
    if #pool > 0 then
      slot.species = pool[hashIndex(mapId, i, #pool, 0xA11)]
    end
  end
  return out
end

local function patchGrassRandom(mod, index, mapId, base, allowLegends)
  local block = copyGrassBlock(base)
  if not block then return false end
  for _, tod in ipairs({ "MORN", "DAY", "NITE" }) do
    block.slots[tod] = rewriteGrassSlots(
      index, mapId .. ":" .. tod, block.slots[tod], allowLegends)
  end
  local ok, err = pcall(function()
    mod.content.encounters:patch("grass", { [mapId] = block })
  end)
  if not ok then
    mod.log:warn("encounters_gen2 full_random grass %s: %s", mapId, tostring(err))
    return false
  end
  return true
end

local function patchWaterRandom(mod, index, mapId, base, allowLegends)
  local block = copyWaterBlock(base)
  if not block then return false end
  block.slots = rewriteWaterSlots(index, mapId, block.slots, allowLegends)
  local ok, err = pcall(function()
    mod.content.encounters:patch("water", { [mapId] = block })
  end)
  if not ok then
    mod.log:warn("encounters_gen2 full_random water %s: %s", mapId, tostring(err))
    return false
  end
  return true
end

-- Ensure each region hosts a solid share of the pool so Johto and Kanto
-- both feel full (Kanto especially — otherwise postgame feels hollow).
local function enrichRegion(mod, index, mapIds, regionTag, targetShare)
  local grass = liveGrass(mod)
  if not grass then return 0 end

  local placed = {}
  for _, mapId in ipairs(mapIds) do
    local block = grass[mapId]
    local slots = block and block.slots and block.slots.DAY
    for _, slot in ipairs(slots or {}) do
      if slot.species then placed[slot.species] = true end
    end
  end

  local bases = {}
  for id, meta in pairs(index.meta) do
    if meta.stage == 0 and not meta.rare then
      bases[#bases + 1] = id
    end
  end
  table.sort(bases)
  local want = math.max(24, math.floor(#bases * (targetShare or 0.4)))
  local have = 0
  for _ in pairs(placed) do have = have + 1 end
  if have >= want then return 0 end

  local missing = {}
  for _, id in ipairs(bases) do
    if not placed[id] then missing[#missing + 1] = id end
  end

  local injected = 0
  local mi = 1
  for _, mapId in ipairs(mapIds) do
    if mi > #missing then break end
    local block = grass[mapId]
    if block and block.slots then
      local day = copySlots(block.slots.DAY)
      if day and #day >= 2 then
        -- Overwrite the two rarest Day slots; mirror into MORN/NITE.
        for off = 0, 1 do
          if mi > #missing then break end
          local idx = #day - off
          local sp = missing[mi]
          mi = mi + 1
          day[idx].species = sp
          local meta = index.meta[sp]
          if meta and (day[idx].level or 1) < meta.minLevel then
            day[idx].level = meta.minLevel
          end
          injected = injected + 1
          placed[sp] = true
        end
        local morn = copySlots(day)
        local nite = copySlots(day)
        pcall(function()
          mod.content.encounters:patch("grass", {
            [mapId] = {
              rates = block.rates,
              slots = { MORN = morn, DAY = day, NITE = nite },
            },
          })
        end)
      end
    end
    if have + injected >= want then break end
  end
  if injected > 0 then
    mod.log:info("Gen2 full_random: injected %d unique bases into %s for density",
      injected, regionTag)
  end
  return injected
end

local function applyFullRandom(mod, pokemon_data, opts)
  opts = opts or {}
  local allowLegends = opts.legendsInMix and true or false
  local index = buildGoldIndex(mod, pokemon_data, allowLegends)
  local grassMaps, waterMaps = {}, {}
  for mapId in pairs(baselines.grass) do
    grassMaps[#grassMaps + 1] = mapId
  end
  table.sort(grassMaps)
  for mapId in pairs(baselines.water) do
    waterMaps[#waterMaps + 1] = mapId
  end
  table.sort(waterMaps)

  local nGrass, nWater = 0, 0
  for _, mapId in ipairs(grassMaps) do
    if patchGrassRandom(mod, index, mapId, baselines.grass[mapId], allowLegends) then
      nGrass = nGrass + 1
    end
  end
  for _, mapId in ipairs(waterMaps) do
    if patchWaterRandom(mod, index, mapId, baselines.water[mapId], allowLegends) then
      nWater = nWater + 1
    end
  end

  local johto, kanto = {}, {}
  for _, mapId in ipairs(grassMaps) do
    if isKantoMap(mapId) then
      kanto[#kanto + 1] = mapId
    else
      johto[#johto + 1] = mapId
    end
  end
  -- Johto first region density, then Kanto so the second region stays rich.
  enrichRegion(mod, index, johto, "Johto", 0.45)
  enrichRegion(mod, index, kanto, "Kanto", 0.45)

  mod.log:info(
    "Gen2 encounters full_random: %d grass + %d water maps (Johto %d / Kanto %d%s)",
    nGrass, nWater, #johto, #kanto, allowLegends and ", legends on" or "")
  return nGrass + nWater
end

-- mode: "curated" (default) or "full_random"
-- opts.legendsInMix: only used for full_random
function EncountersGen2.apply(mod, pokemon_data, mode, opts)
  mode = mode or "curated"
  captureBaselines(mod)
  restoreBaselines(mod)
  EncountersGen2._mod = mod
  if mode == "full_random" then
    return applyFullRandom(mod, pokemon_data, opts)
  end
  return applyCurated(mod)
end

function EncountersGen2.clearBaselines()
  baselines.grass, baselines.water = {}, {}
end

-- Test/debug helpers.
EncountersGen2._poolFor = poolFor
EncountersGen2._clampWildLevel = clampWildLevel
EncountersGen2._fitsRouteLevel = fitsRouteLevel
EncountersGen2._pickGuests = pickGuests
EncountersGen2._isKantoMap = isKantoMap
EncountersGen2._buildGoldIndex = buildGoldIndex

return EncountersGen2
