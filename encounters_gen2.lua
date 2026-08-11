-- Gen2 encounter mixing:
--   * Kanto — full Gen3 grass tables (TOD-biased habitat pools, postgame
--     levels). No legendaries / starters / mid-stage cocoons.
--   * Johto — keep Gold natives; inject a couple of habitat-fitting Gen3
--     basics into rare slots, clamped to each species' wild level band.
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

function EncountersGen2.apply(mod, _data)
  local nKanto, nJohto = 0, 0
  for mapId, info in pairs(KANTO_GRASS) do
    if patchMap(mod, mapId, info) then nKanto = nKanto + 1 end
  end

  for mapId, info in pairs(JOHTO_GUESTS) do
    -- Kanto full-reload maps win if listed in both.
    if not KANTO_GRASS[mapId] and injectJohtoMap(mod, mapId, info) then
      nJohto = nJohto + 1
    end
  end

  EncountersGen2._mod = mod
  mod.log:info(
    "Gen2 encounters: %d Kanto maps patched (full) + %d Johto maps with Gen3 guests",
    nKanto, nJohto)
  return nKanto + nJohto
end

-- Test/debug helpers.
EncountersGen2._poolFor = poolFor
EncountersGen2._clampWildLevel = clampWildLevel
EncountersGen2._fitsRouteLevel = fitsRouteLevel
EncountersGen2._pickGuests = pickGuests

return EncountersGen2
