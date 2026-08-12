-- Encounter mixing for Gen 2/3 species into Kanto wild tables.
-- Rules of thumb:
--   * Base forms anywhere their habitat fits, scaled by BST vs route level.
--   * Mid / final forms only when the slot level is at (or above) the
--     evolve-into level, and the route's level band allows that stage.
--   * Legendaries / mythicals stay in rare slots only.
--   * Curated mode finishes with a coverage pass so every non-legendary
--     line is obtainable: catch the base (or an earlier stage), then evolve
--     / breed. Not every mid/final needs its own wild slot.

local Merge = require("src.mods.Merge")

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
  -- Route 11 sits east of Vermilion (Ekans/Sandshrew, Spearow, Drowzee) and
  -- feeds Diglett's Cave — not desert-only. Tag grassland/urban so curated
  -- + coverage actually assign Gen 2/3 instead of leaving Spearow commons.
  ROUTE_11 = {
    habitats = { "rough-terrain", "grassland", "urban" },
    kinds = { "grass" },
  },
  ROUTE_12 = { habitats = { "rough-terrain", "grassland", "waters-edge" }, kinds = { "grass" } },
  ROUTE_13 = { habitats = { "rough-terrain", "grassland" }, kinds = { "grass" } },
  ROUTE_14 = { habitats = { "rough-terrain", "grassland" }, kinds = { "grass" } },
  ROUTE_15 = { habitats = { "rough-terrain", "grassland" }, kinds = { "grass" } },
  ROUTE_16 = { habitats = { "rough-terrain", "mountain" }, kinds = { "grass" } },
  ROUTE_17 = { habitats = { "rough-terrain", "grassland" }, kinds = { "grass" } },
  ROUTE_18 = { habitats = { "rough-terrain", "grassland" }, kinds = { "grass" } },
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
  -- Iconic Diglett/Dugtrio tunnel: keep locals dominant. At most two rare
  -- guest slots (low-frequency Diglett entries); never used as a coverage dump.
  DIGLETTS_CAVE = {
    habitats = { "cave" },
    kinds = { "grass" },
    iconicLocals = true,
    -- Gen 1 layout: slots 1–8 Diglett, 9–10 Dugtrio. Touch only ~5% Digletts.
    guestSlots = { 7, 8 },
    -- Burrowing / magnetic cave dwellers that fit the tunnel thematically.
    guestAllow = { "ARON", "NOSEPASS" },
  },
  ROCK_TUNNEL_1F = { habitats = { "cave", "mountain" }, kinds = { "grass" } },
  ROCK_TUNNEL_B1F = { habitats = { "cave", "mountain" }, kinds = { "grass" } },
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
  SHEDINJA = true, -- only via Nincada evolution (Nincada must stay wild)
}

-- Gen 4+ baby stubs may appear in pokemon_data.evolutions without a species
-- row. Counting them as parents wrongly marks Sudowoodo / Mantine / etc. as
-- mid-stage so curated coverage never places the adult. Vanilla Gen 1 parents
-- (Eevee, Chansey, …) are kept so Gen 2/3 evolutions stay staged correctly.
local SKIP_EVO_PARENTS = {
  BONSLY = true, BUDEW = true, CHINGLING = true, MANTYKE = true,
  MIMEJR = true, MIME_JR = true, HAPPINY = true, MUNCHLAX = true,
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
    if SKIP_EVO_PARENTS[fromId] then return end
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

local function livePatchEncounter(mod, mapId, partial)
  local ok = pcall(function()
    mod.content.encounters:patch(mapId, partial)
  end)
  if ok then return end
  -- Registry is frozen after boot merge (game.ready scope refresh, option
  -- toggles).  Merge slot updates into live Data.encounters — assigning
  -- dest[kind] = block drops rate/buckets and crashes Encounter.roll.
  local Data = require("src.core.Data")
  local dest = Data.encounters[mapId]
  if not dest then
    Data.encounters[mapId] = {}
    dest = Data.encounters[mapId]
  end
  for kind, block in pairs(partial or {}) do
    if type(block) == "table" and type(dest[kind]) == "table" then
      Merge.deepMerge(dest[kind], block, "record")
    else
      dest[kind] = block
    end
  end
end

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
  -- Slot 2 is a high-frequency common (~20%); without it, routes like
  -- Route 11 keep a vanilla Spearow in a very common bucket and feel
  -- unassigned even when slots 3/6/9 were mixed.
  return {
    { index = 2, preferStage = 0, allowRare = false },
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

-- Count Gen 2/3 species currently sitting in mixed maps (for coverage).
local function countGen23Placements(mod, index)
  local counts = {}
  for mapId, mapDef in pairs(MAPS) do
    local enc = mod.content.encounters:get(mapId)
    if enc then
      for _, kind in ipairs(mapDef.kinds) do
        local block = enc[kind]
        if block and block.slots then
          for _, slot in ipairs(block.slots) do
            local id = slot.species
            if id and index.meta[id] then
              counts[id] = (counts[id] or 0) + 1
            end
          end
        end
      end
    end
  end
  return counts
end

-- Extra slot indices used only when the normal curated plan cannot host every
-- stage-0 form. Prefer mid-table commons; never touch vanilla-protected rares.
local COVERAGE_OVERFLOW_SLOTS = { 1, 2, 4, 5, 7, 8, 10 }

-- After the stride-based curated mix, guarantee every non-legendary base form
-- in this pack has at least one wild slot. Mid / final forms do not need their
-- own grass entries when the base is catchable (evolve / breed from there).
-- Legendaries stay rare-slot only; Shedinja stays NEVER_WILD (from Nincada).
--
-- Never demote a Gen 2/3 species that only has one slot. Prefer vanilla
-- commons, then duplicate Gen 2/3 picks.
local function ensureBaseCoverage(mod, index)
  local mapIds = {}
  for id in pairs(MAPS) do mapIds[#mapIds + 1] = id end
  table.sort(mapIds)

  local function habitatMatch(mapDef, habitat)
    for _, hab in ipairs(mapDef.habitats) do
      if hab == habitat then return true end
    end
    return false
  end

  local function stealScore(counts, speciesId)
    if not speciesId or VANILLA_RARES[speciesId] then return -1 end
    local meta = index.meta[speciesId]
    if meta and meta.rare then return -1 end -- keep legendary / mythical slots
    if not meta then return 100 end -- vanilla common
    return counts[speciesId] or 0
  end

  -- minScore: 2 = duplicates only; 1 = allow unique demotion (last resort unused);
  -- 100 threshold via vanilla score.
  local function tryPlace(counts, claimed, speciesId, mapId, kind, slotIndex, slots, avg, maxLv, minScore)
    local key = mapId .. "|" .. kind .. "|" .. slotIndex
    if claimed[key] then return false end
    local slot = slots[slotIndex]
    if not slot then return false end
    local score = stealScore(counts, slot.species)
    if score < minScore then return false end

    local pool = Encounters.eligible(
      index, MAPS[mapId].habitats, slot.level, avg, maxLv, {
        allowRare = false, rareOnly = false, preferStage = 0,
      })
    local ok = false
    for _, id in ipairs(pool) do
      if id == speciesId then ok = true break end
    end
    if not ok then return false end

    local prev = slot.species
    if index.meta[prev] then
      counts[prev] = (counts[prev] or 1) - 1
      if counts[prev] <= 0 then counts[prev] = nil end
    end
    slot.species = speciesId
    applyMinLevel(index, slot, speciesId)
    counts[speciesId] = (counts[speciesId] or 0) + 1
    claimed[key] = true
    return true
  end

  local function missingList(counts)
    local missing = {}
    for id, meta in pairs(index.meta) do
      if meta.stage == 0 and not meta.rare and (counts[id] or 0) == 0 then
        missing[#missing + 1] = id
      end
    end
    table.sort(missing)
    return missing
  end

  local function placeOne(counts, claimed, speciesId, minScore, useOverflow)
    local meta = index.meta[speciesId]
    for _, mapId in ipairs(mapIds) do
      local mapDef = MAPS[mapId]
      -- Never steal Diglett's Cave slots for general cave coverage.
      if not mapDef.iconicLocals and habitatMatch(mapDef, meta.habitat) then
        for _, kind in ipairs(mapDef.kinds) do
          local enc = mod.content.encounters:get(mapId)
          local block = enc and enc[kind]
          local slots = block and block.slots
          if slots and #slots > 0 then
            local avg, maxLv = slotStats(slots)
            local candidates = {}
            local function consider(idx)
              local slot = slots[idx]
              if not slot then return end
              local score = stealScore(counts, slot.species)
              if score >= minScore then
                candidates[#candidates + 1] = { index = idx, score = score }
              end
            end
            local plan = replacementPlan(mapDef, avg, maxLv, slots)
            for _, step in ipairs(plan) do
              if not step.rareOnly then consider(step.index) end
            end
            if useOverflow then
              for _, idx in ipairs(COVERAGE_OVERFLOW_SLOTS) do
                consider(idx)
              end
            end
            table.sort(candidates, function(a, b)
              if a.score ~= b.score then return a.score > b.score end
              return a.index < b.index
            end)
            for _, cand in ipairs(candidates) do
              if tryPlace(counts, claimed, speciesId, mapId, kind, cand.index,
                  slots, avg, maxLv, minScore) then
                livePatchEncounter(mod, mapId, { [kind] = { slots = slots } })
                return true
              end
            end
          end
        end
      end
    end
    return false
  end

  -- Repeat until every base form is placed or a full pass makes no progress.
  for _ = 1, 8 do
    local counts = countGen23Placements(mod, index)
    local missing = missingList(counts)
    if #missing == 0 then return end
    local claimed = {}
    local progress = false
    -- Prefer taking vanilla commons / duplicates on plan + overflow slots.
    for _, speciesId in ipairs(missing) do
      if placeOne(counts, claimed, speciesId, 2, true) then
        progress = true
      end
    end
    if not progress then
      -- Still stuck: take any vanilla common (score 100 already >= 2).
      -- Lower minScore to 100 only via vanilla; use minScore 100 by requiring
      -- vanilla exclusively when duplicates are exhausted.
      for _, speciesId in ipairs(missingList(counts)) do
        if placeOne(counts, claimed, speciesId, 100, true) then
          progress = true
        end
      end
    end
    if not progress then return end
  end
end

-- Iconic maps (Diglett's Cave): keep vanilla locals; swap only guestSlots
-- from a short thematic allowlist. Habitat tags are ignored here — guests
-- are hand-picked for the location (e.g. Aron is "mountain" but belongs).
local function mixIconicGuests(index, mapDef, slots, _avg, _maxLv)
  local allow = mapDef.guestAllow or {}
  local guestIdx = mapDef.guestSlots or {}
  for i, slotIndex in ipairs(guestIdx) do
    local slot = slots[slotIndex]
    if slot and not VANILLA_RARES[slot.species] then
      -- One allowlist entry per guest slot (wrap if fewer guests than slots).
      local chosen = allow[((i - 1) % #allow) + 1]
      if chosen and index.meta[chosen] and not NEVER_WILD[chosen] then
        slot.species = chosen
        applyMinLevel(index, slot, chosen)
      end
    end
  end
end

-- Curated: replace a few slots with Gen 2/3 (default), then cover gaps.
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
        if mapDef.iconicLocals then
          mixIconicGuests(index, mapDef, slots, avg, maxLv)
        else
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
        end
        livePatchEncounter(mod, mapId, { [kind] = { slots = slots } })
      end
    end
  end

  ensureBaseCoverage(mod, index)
end

-- Full mix: every unprotected slot is a pick from Gen 1 locals on that
-- route plus eligible Gen 2/3 forms for the habitat / level band.
-- opts.legendsInMix: include habitat=rare legendaries/mythicals in the pool.
local NATIVE_LEGENDS = {
  "ARTICUNO", "ZAPDOS", "MOLTRES", "MEWTWO", "MEW",
}

local function mixFullRandom(mod, index, opts)
  opts = opts or {}
  local allowLegends = opts.legendsInMix and true or false
  if allowLegends then
    for _, id in ipairs(NATIVE_LEGENDS) do
      if not index.meta[id] then
        index.meta[id] = {
          stage = 0, minLevel = 40, bst = 680, habitat = "rare", rare = true,
        }
      end
    end
  end
  local mapIds = {}
  for id in pairs(MAPS) do mapIds[#mapIds + 1] = id end
  table.sort(mapIds)

  for _, mapId in ipairs(mapIds) do
    local mapDef = MAPS[mapId]
    for _, kind in ipairs(mapDef.kinds) do
      local slots = baselineSlots(mapId, kind)
      if slots and #slots > 0 then
        local avg, maxLv = slotStats(slots)
        if mapDef.iconicLocals then
          mixIconicGuests(index, mapDef, slots, avg, maxLv)
        else
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
                  allowRare = allowLegends,
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
              -- Late enough routes can also roll Gen1 birds / Mewtwo / Mew.
              if allowLegends and (slot.level or 0) >= 40 then
                for _, id in ipairs(NATIVE_LEGENDS) do add(id) end
              end
              -- Rare maps always bias late slots toward legends; with
              -- legendsInMix the whole pool already allows them.
              if mapDef.rare and slotIndex >= 7 and not allowLegends then
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
        end
        livePatchEncounter(mod, mapId, { [kind] = { slots = slots } })
      end
    end
  end
end

-- mode: "curated" (default) or "full_random"
-- opts.legendsInMix: only used for full_random
-- opts.speciesScope: "kanto" strips dex>151 from the mix index
function Encounters.apply(mod, pokemon_data, mode, opts)
  Encounters.captureBaselines(mod)
  local index = Encounters.buildIndex(pokemon_data)
  opts = opts or {}
  if opts.speciesScope == "kanto" then
    local meta, byHabitat = {}, {}
    for id, m in pairs(index.meta or {}) do
      local spec = pokemon_data.species and pokemon_data.species[id]
      local dex = spec and spec.dex
      if not dex or dex <= 151 then
        meta[id] = m
        local hab = m.habitat or "grassland"
        byHabitat[hab] = byHabitat[hab] or {}
        byHabitat[hab][#byHabitat[hab] + 1] = id
      end
    end
    index = { meta = meta, byHabitat = byHabitat, parents = index.parents }
  end
  if mode == "full_random" then
    mixFullRandom(mod, index, opts)
  else
    mixCurated(mod, index)
  end
  return index
end

-- Back-compat alias used by main.lua
function Encounters.mix(mod, pokemon_data, mode, opts)
  return Encounters.apply(mod, pokemon_data, mode or "curated", opts)
end

Encounters.MAPS = MAPS
Encounters.VANILLA_RARES = VANILLA_RARES
Encounters.NEVER_WILD = NEVER_WILD

-- Vanilla Gen 1 sources that unlock pack evolutions without a grass slot:
-- gifts, rods, or mid-stages that evolve from those.
local OUTSIDE_GRASS_ROOTS = {
  EEVEE = true,      -- Celadon Mansion roof gift
  PORYGON = true,    -- Game Corner prize
  POLIWAG = true,    -- Good Rod
  POLIWHIRL = true,  -- from Poliwag (rod) → Politoed
  MAGIKARP = true,   -- Old Rod
  GOLDEEN = true,    -- Good Rod
}

-- True when a pack species (or its earlier evo / gift root) is obtainable
-- without needing that exact form in grass. Used by tests / debugging.
function Encounters.lineObtainable(speciesId, index, wildSet)
  if not speciesId then return false end
  if NEVER_WILD[speciesId] then
    -- Shedinja: special split from Nincada.
    return wildSet and wildSet.NINCADA and true or false
  end
  if wildSet and wildSet[speciesId] then return true end
  local cur, seen = speciesId, {}
  while index and index.parents and index.parents[cur] and not seen[cur] do
    seen[cur] = true
    cur = index.parents[cur]
    if wildSet and wildSet[cur] then return true end
    if OUTSIDE_GRASS_ROOTS[cur] then return true end
  end
  if OUTSIDE_GRASS_ROOTS[speciesId] or OUTSIDE_GRASS_ROOTS[cur] then return true end
  return false
end

return Encounters
