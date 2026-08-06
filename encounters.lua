-- Encounter mixing for Gen 2/3 species into Kanto wild tables.
-- Rules of thumb:
--   * Base forms anywhere their habitat fits, scaled by BST vs route level.
--   * Mid / final forms only when the slot level is at (or above) the
--     evolve-into level, and the route's level band allows that stage.
--   * Legendaries / mythicals stay in rare slots only.

local Encounters = {}

local VANILLA_RARES = {
  CHANSEY = true, DRAGONAIR = true, DRAGONITE = true,
  SCYTHER = true, PINSIR = true, KANGASKHAN = true, TAUROS = true,
}

-- Map → habitats that may contribute + which encounter kinds to patch.
-- Later grassland-ish routes also accept grassland mids/finals once levels allow.
local MAPS = {
  ROUTE_1 = { habitats = { "grassland" }, kinds = { "grass" } },
  ROUTE_2 = { habitats = { "grassland" }, kinds = { "grass" } },
  ROUTE_3 = { habitats = { "grassland" }, kinds = { "grass" } },
  ROUTE_4 = { habitats = { "grassland", "mountain" }, kinds = { "grass" } },
  ROUTE_5 = { habitats = { "urban" }, kinds = { "grass" } },
  ROUTE_6 = { habitats = { "urban", "waters-edge" }, kinds = { "grass" } },
  ROUTE_7 = { habitats = { "urban", "grassland" }, kinds = { "grass" } },
  ROUTE_8 = { habitats = { "urban" }, kinds = { "grass" } },
  ROUTE_9 = { habitats = { "mountain" }, kinds = { "grass" } },
  ROUTE_10 = { habitats = { "mountain" }, kinds = { "grass" } },
  ROUTE_11 = { habitats = { "rough-terrain" }, kinds = { "grass" } },
  ROUTE_12 = { habitats = { "rough-terrain", "grassland", "waters-edge" }, kinds = { "grass" } },
  ROUTE_13 = { habitats = { "rough-terrain", "grassland" }, kinds = { "grass" } },
  ROUTE_14 = { habitats = { "rough-terrain", "grassland" }, kinds = { "grass" } },
  ROUTE_15 = { habitats = { "rough-terrain", "grassland" }, kinds = { "grass" } },
  ROUTE_16 = { habitats = { "rough-terrain", "mountain" }, kinds = { "grass" } },
  ROUTE_17 = { habitats = { "rough-terrain" }, kinds = { "grass" } },
  ROUTE_18 = { habitats = { "rough-terrain" }, kinds = { "grass" } },
  ROUTE_19 = { habitats = { "sea", "waters-edge" }, kinds = { "water" } },
  ROUTE_20 = { habitats = { "sea", "waters-edge" }, kinds = { "water" } },
  ROUTE_21 = { habitats = { "sea", "waters-edge", "grassland" }, kinds = { "grass", "water" } },
  ROUTE_22 = { habitats = { "grassland" }, kinds = { "grass" } },
  ROUTE_23 = { habitats = { "mountain", "grassland", "rough-terrain" }, kinds = { "grass" } },
  ROUTE_24 = { habitats = { "waters-edge", "forest" }, kinds = { "grass" } },
  ROUTE_25 = { habitats = { "waters-edge", "forest" }, kinds = { "grass" } },

  VIRIDIAN_FOREST = { habitats = { "forest" }, kinds = { "grass" } },

  MT_MOON_1F = { habitats = { "cave" }, kinds = { "grass" } },
  MT_MOON_B1F = { habitats = { "cave" }, kinds = { "grass" } },
  MT_MOON_B2F = { habitats = { "cave" }, kinds = { "grass" } },
  ROCK_TUNNEL_1F = { habitats = { "cave" }, kinds = { "grass" } },
  ROCK_TUNNEL_B1F = { habitats = { "cave" }, kinds = { "grass" } },
  VICTORY_ROAD_1F = { habitats = { "cave", "mountain" }, kinds = { "grass" } },
  VICTORY_ROAD_2F = { habitats = { "cave", "mountain" }, kinds = { "grass" } },
  VICTORY_ROAD_3F = { habitats = { "cave", "mountain" }, kinds = { "grass" } },
  CERULEAN_CAVE_1F = { habitats = { "cave", "rare" }, kinds = { "grass" }, rare = true },
  CERULEAN_CAVE_2F = { habitats = { "cave", "rare" }, kinds = { "grass" }, rare = true },
  CERULEAN_CAVE_B1F = { habitats = { "cave", "rare" }, kinds = { "grass" }, rare = true },

  SAFARI_ZONE_EAST = { habitats = { "rare", "grassland", "forest" }, kinds = { "grass" }, rare = true },
  SAFARI_ZONE_NORTH = { habitats = { "rare", "grassland", "forest", "mountain" }, kinds = { "grass" }, rare = true },
  SAFARI_ZONE_WEST = { habitats = { "rare", "grassland", "forest" }, kinds = { "grass" }, rare = true },
  SAFARI_ZONE_CENTER = { habitats = { "rare", "grassland", "forest" }, kinds = { "grass" }, rare = true },
}

local NEVER_WILD = {
  SHEDINJA = true, -- only via Nincada evolution
}

local function baseStatTotal(spec)
  local b = spec.baseStats or {}
  return (b.hp or 0) + (b.attack or 0) + (b.defense or 0)
      + (b.speed or 0) + (b.special or 0)
end

-- Build parent→child graph, stage (0/1/2+), and earliest wild level.
function Encounters.buildIndex(pokemon_data)
  local parents = {}
  local minInto = {}

  local function noteEvo(fromId, evo)
    if not evo or not evo.species then return end
    parents[evo.species] = fromId
    if evo.method == "LEVEL" and evo.level then
      local prev = minInto[evo.species]
      if not prev or evo.level < prev then
        minInto[evo.species] = evo.level
      end
    end
  end

  for id, spec in pairs(pokemon_data.species) do
    for _, evo in ipairs(spec.evolutions or {}) do
      noteEvo(id, evo)
    end
  end
  if pokemon_data.evolutions then
    for fromId, evos in pairs(pokemon_data.evolutions) do
      for _, evo in ipairs(evos) do
        noteEvo(fromId, evo)
      end
    end
  end

  local function stageOf(id)
    local n, cur, seen = 0, id, {}
    while parents[cur] and not seen[cur] do
      seen[cur] = true
      cur = parents[cur]
      n = n + 1
    end
    return n
  end

  local meta = {}
  local byHabitat = {}
  for id, spec in pairs(pokemon_data.species) do
    if not NEVER_WILD[id] then
      local stage = stageOf(id)
      local minLevel = minInto[id]
      if not minLevel and stage > 0 then
        -- Stone / trade / friendship: wild floor by stage
        minLevel = (stage >= 2) and 30 or 20
      end
      local habitat = spec.habitat or "grassland"
      local rare = (habitat == "rare")
      meta[id] = {
        stage = stage,
        minLevel = minLevel or 1,
        bst = baseStatTotal(spec),
        habitat = habitat,
        rare = rare,
      }
      byHabitat[habitat] = byHabitat[habitat] or {}
      byHabitat[habitat][#byHabitat[habitat] + 1] = id
    end
  end

  for _, list in pairs(byHabitat) do
    table.sort(list, function(a, b)
      local ma, mb = meta[a], meta[b]
      if ma.stage ~= mb.stage then return ma.stage < mb.stage end
      if ma.bst ~= mb.bst then return ma.bst < mb.bst end
      return a < b
    end)
  end

  return { meta = meta, byHabitat = byHabitat, parents = parents }
end

-- How far along the evo line this route's level band can support.
function Encounters.maxStageFor(avgLevel, maxLevel)
  if avgLevel >= 32 or maxLevel >= 40 then return 2 end
  if avgLevel >= 14 or maxLevel >= 18 then return 1 end
  return 0
end

function Encounters.bstCap(avgLevel, stage)
  if stage >= 2 then return 680 end
  if stage == 1 then return 320 + math.floor(avgLevel * 8) end
  return 180 + math.floor(avgLevel * 40)
end

local function slotStats(slots)
  local sum, n, maxLv = 0, 0, 0
  for _, slot in ipairs(slots) do
    local lv = slot.level or 0
    sum = sum + lv
    n = n + 1
    if lv > maxLv then maxLv = lv end
  end
  return (n > 0 and sum / n or 5), maxLv
end

-- preferStage: 0 favors bases, 2 favors finals among eligible.
function Encounters.eligible(index, habitats, slotLevel, avgLevel, maxLevel, opts)
  opts = opts or {}
  local allowRare = opts.allowRare
  local rareOnly = opts.rareOnly
  local preferStage = opts.preferStage or 0
  local routeMaxStage = Encounters.maxStageFor(avgLevel, maxLevel)
  local seen, pool = {}, {}

  for _, hab in ipairs(habitats) do
    for _, id in ipairs(index.byHabitat[hab] or {}) do
      if not seen[id] then
        seen[id] = true
        local m = index.meta[id]
        local ok = m ~= nil
        if ok and m.rare and not allowRare then ok = false end
        if ok and rareOnly and not m.rare then ok = false end
        if ok and m.stage > routeMaxStage then ok = false end
        if ok and slotLevel < m.minLevel then ok = false end
        if ok and m.bst > Encounters.bstCap(avgLevel, m.stage) then ok = false end
        if ok then pool[#pool + 1] = id end
      end
    end
  end

  if #pool == 0 then return pool end

  local function band(stage)
    local out = {}
    for _, id in ipairs(pool) do
      if index.meta[id].stage == stage then out[#out + 1] = id end
    end
    return out
  end

  local preferred = band(preferStage)
  if #preferred > 0 then return preferred end
  for delta = 1, 2 do
    preferred = band(preferStage - delta)
    if #preferred > 0 then return preferred end
    preferred = band(preferStage + delta)
    if #preferred > 0 then return preferred end
  end
  return pool
end

function Encounters.pick(pool, pickIndex)
  if not pool or #pool == 0 then return nil end
  return pool[((pickIndex - 1) % #pool) + 1]
end

-- Stable hash pick so a given map/slot always resolves the same species
-- for a given pool size (tests + reproducible wild tables per boot).
local function hashIndex(mapId, slotIndex, n, salt)
  if n <= 0 then return 1 end
  local h = salt or 0
  for i = 1, #mapId do
    h = (h * 33 + mapId:byte(i)) % 2147483647
  end
  h = (h * 31 + slotIndex * 17) % 2147483647
  return (h % n) + 1
end

local function copySlots(slots)
  local out = {}
  for i, slot in ipairs(slots) do
    out[i] = { level = slot.level, species = slot.species }
  end
  return out
end

-- Snapshot vanilla encounter tables once, before any Gen 2/3 mixing.
-- Re-applying modes always starts from this baseline.
local baselines = {}

function Encounters.captureBaselines(mod)
  for mapId, mapDef in pairs(MAPS) do
    if not baselines[mapId] then
      local enc = mod.content.encounters:get(mapId)
      if enc then
        local snap = {}
        for _, kind in ipairs(mapDef.kinds) do
          local src = enc[kind]
          if src and src.slots then
            snap[kind] = {
              rate = src.rate,
              slots = copySlots(src.slots),
            }
          end
        end
        baselines[mapId] = snap
      end
    end
  end
end

function Encounters.clearBaselines()
  baselines = {}
end

local function baselineSlots(mapId, kind)
  local snap = baselines[mapId] and baselines[mapId][kind]
  if not snap then return nil end
  return copySlots(snap.slots), snap.rate
end

-- Replacement slots: common / uncommon / rare-ish (Gen 1 10-slot layout).
-- On rare maps, two slots are reserved for legendary/mythical habitat;
-- skip vanilla-protected rares (Chansey, Kangaskhan, …) when choosing them.
local function replacementPlan(mapDef, avgLevel, maxLevel, slots)
  if mapDef.rare then
    local plan = {
      { index = 3, preferStage = (avgLevel >= 20) and 1 or 0, allowRare = false },
      { index = 6, preferStage = (avgLevel >= 24) and 1 or 0, allowRare = false },
    }
    local rareCandidates = { 9, 10, 8, 7, 5, 4, 2, 1 }
    for _, idx in ipairs(rareCandidates) do
      local slot = slots[idx]
      if slot and not VANILLA_RARES[slot.species] then
        plan[#plan + 1] = {
          index = idx, preferStage = 0, allowRare = true, rareOnly = true,
        }
        if #plan >= 4 then break end
      end
    end
    return plan
  end
  local mid = (avgLevel >= 14 or maxLevel >= 18) and 1 or 0
  local late = (avgLevel >= 32 or maxLevel >= 40) and 2 or mid
  return {
    { index = 3, preferStage = 0, allowRare = false },
    { index = 6, preferStage = mid, allowRare = false },
    { index = 9, preferStage = late, allowRare = false },
  }
end

local function applyMinLevel(index, slot, speciesId)
  local meta = index.meta[speciesId]
  if meta and slot.level < meta.minLevel then
    slot.level = meta.minLevel
  end
end

-- Curated: replace a few slots with Gen 2/3 (default).
local function mixCurated(mod, index)
  local mapIds = {}
  for id in pairs(MAPS) do mapIds[#mapIds + 1] = id end
  table.sort(mapIds)

  for mapOrder, mapId in ipairs(mapIds) do
    local mapDef = MAPS[mapId]
    for _, kind in ipairs(mapDef.kinds) do
      local slots = baselineSlots(mapId, kind)
      if slots and #slots > 0 then
        local avg, maxLv = slotStats(slots)
        local plan = replacementPlan(mapDef, avg, maxLv, slots)
        for planIdx, step in ipairs(plan) do
          local slot = slots[step.index]
          if slot and not VANILLA_RARES[slot.species] then
            local pool = Encounters.eligible(
              index, mapDef.habitats, slot.level, avg, maxLv, {
                allowRare = step.allowRare,
                rareOnly = step.rareOnly,
                preferStage = step.preferStage,
              })
            local pickIndex = planIdx + (mapOrder - 1) * 3
            local chosen = Encounters.pick(pool, pickIndex)
            if chosen then
              slot.species = chosen
              applyMinLevel(index, slot, chosen)
            end
          end
        end
        mod.content.encounters:patch(mapId, { [kind] = { slots = slots } })
      end
    end
  end
end

-- Full mix: every unprotected slot is a pick from Gen 1 locals on that
-- route plus eligible Gen 2/3 forms for the habitat / level band.
local function mixFullRandom(mod, index)
  local mapIds = {}
  for id in pairs(MAPS) do mapIds[#mapIds + 1] = id end
  table.sort(mapIds)

  for _, mapId in ipairs(mapIds) do
    local mapDef = MAPS[mapId]
    for _, kind in ipairs(mapDef.kinds) do
      local slots = baselineSlots(mapId, kind)
      if slots and #slots > 0 then
        local avg, maxLv = slotStats(slots)
        -- Gen 1 locals from the vanilla table (unique, skip protected rares)
        local locals, seen = {}, {}
        for _, slot in ipairs(slots) do
          if slot.species and not VANILLA_RARES[slot.species]
              and not seen[slot.species] then
            seen[slot.species] = true
            locals[#locals + 1] = slot.species
          end
        end

        for slotIndex, slot in ipairs(slots) do
          if not VANILLA_RARES[slot.species] then
            local gen23 = Encounters.eligible(
              index, mapDef.habitats, slot.level, avg, maxLv, {
                allowRare = false,
                rareOnly = false,
                preferStage = Encounters.maxStageFor(avg, maxLv),
              })
            local pool, poolSeen = {}, {}
            local function add(id)
              if id and not poolSeen[id] then
                poolSeen[id] = true
                pool[#pool + 1] = id
              end
            end
            for _, id in ipairs(locals) do add(id) end
            for _, id in ipairs(gen23) do add(id) end
            if mapDef.rare and slotIndex >= 7 then
              local rares = Encounters.eligible(
                index, mapDef.habitats, slot.level, avg, maxLv, {
                  allowRare = true, rareOnly = true, preferStage = 0,
                })
              if #rares > 0 then
                pool, poolSeen = {}, {}
                for _, id in ipairs(rares) do add(id) end
                for _, id in ipairs(gen23) do add(id) end
              end
            end
            if #pool > 0 then
              local chosen = pool[hashIndex(mapId, slotIndex, #pool, 0xC0FFEE)]
              slot.species = chosen
              applyMinLevel(index, slot, chosen)
            end
          end
        end
        mod.content.encounters:patch(mapId, { [kind] = { slots = slots } })
      end
    end
  end
end

-- mode: "curated" (default) or "full_random"
function Encounters.apply(mod, pokemon_data, mode)
  Encounters.captureBaselines(mod)
  local index = Encounters.buildIndex(pokemon_data)
  if mode == "full_random" then
    mixFullRandom(mod, index)
  else
    mixCurated(mod, index)
  end
  return index
end

-- Back-compat alias used by main.lua
function Encounters.mix(mod, pokemon_data, mode)
  return Encounters.apply(mod, pokemon_data, mode or "curated")
end

Encounters.MAPS = MAPS
Encounters.VANILLA_RARES = VANILLA_RARES

return Encounters
