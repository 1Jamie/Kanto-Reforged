-- Comprehensive test for Kanto Reforged Gen 3 Encounter Tables & Dynamic Dex Mapping.

local EncountersGame3 = require("mods.Kanto-Reforged.world.encounters_game3")
local PokedexData = require("src.core.game3.pokedex_data")

print("--- Testing Gen 3 Encounter Tables & Slot Ratios ---")

local mapCount = 0
local totalSlots = 0
local speciesEncountered = {}

for mapKey, def in pairs(EncountersGame3.MAP_TABLES) do
  mapCount = mapCount + 1
  assert(type(def.aliases) == "table" and #def.aliases > 0, "Map must define aliases: " .. tostring(mapKey))

  -- Verify Land slots (GBA standard: exactly 12 slots)
  if def.land then
    assert(type(def.land.slots) == "table", mapKey .. " land.slots must be table")
    assert(#def.land.slots == 12, mapKey .. " land must have exactly 12 slots, got " .. #def.land.slots)
    assert(def.land.rate and def.land.rate > 0, mapKey .. " land rate must be > 0")
    for idx, s in ipairs(def.land.slots) do
      totalSlots = totalSlots + 1
      local spId = EncountersGame3.toSpeciesId(s.species)
      assert(spId and spId >= 1 and spId <= 411, mapKey .. " invalid species at land slot " .. idx .. ": " .. tostring(s.species))
      assert(s.minLevel and s.maxLevel and s.minLevel <= s.maxLevel, mapKey .. " invalid level range at land slot " .. idx)
      speciesEncountered[spId] = true
    end
  end

  -- Verify Water slots (GBA standard: exactly 5 slots)
  if def.water then
    assert(type(def.water.slots) == "table", mapKey .. " water.slots must be table")
    assert(#def.water.slots == 5, mapKey .. " water must have exactly 5 slots, got " .. #def.water.slots)
    assert(def.water.rate and def.water.rate > 0, mapKey .. " water rate must be > 0")
    for idx, s in ipairs(def.water.slots) do
      totalSlots = totalSlots + 1
      local spId = EncountersGame3.toSpeciesId(s.species)
      assert(spId and spId >= 1 and spId <= 411, mapKey .. " invalid species at water slot " .. idx .. ": " .. tostring(s.species))
      assert(s.minLevel and s.maxLevel and s.minLevel <= s.maxLevel, mapKey .. " invalid level range at water slot " .. idx)
      speciesEncountered[spId] = true
    end
  end

  -- Verify Old Rod slots (GBA standard: exactly 2 slots)
  if def.oldRod then
    assert(type(def.oldRod.slots) == "table", mapKey .. " oldRod.slots must be table")
    assert(#def.oldRod.slots == 2, mapKey .. " oldRod must have exactly 2 slots, got " .. #def.oldRod.slots)
    for idx, s in ipairs(def.oldRod.slots) do
      totalSlots = totalSlots + 1
      local spId = EncountersGame3.toSpeciesId(s.species)
      assert(spId and spId >= 1 and spId <= 411, mapKey .. " invalid species at oldRod slot " .. idx .. ": " .. tostring(s.species))
      speciesEncountered[spId] = true
    end
  end

  -- Verify Good Rod slots (GBA standard: exactly 3 slots)
  if def.goodRod then
    assert(type(def.goodRod.slots) == "table", mapKey .. " goodRod.slots must be table")
    assert(#def.goodRod.slots == 3, mapKey .. " goodRod must have exactly 3 slots, got " .. #def.goodRod.slots)
    for idx, s in ipairs(def.goodRod.slots) do
      totalSlots = totalSlots + 1
      local spId = EncountersGame3.toSpeciesId(s.species)
      assert(spId and spId >= 1 and spId <= 411, mapKey .. " invalid species at goodRod slot " .. idx .. ": " .. tostring(s.species))
      speciesEncountered[spId] = true
    end
  end

  -- Verify Super Rod slots (GBA standard: exactly 5 slots)
  if def.superRod then
    assert(type(def.superRod.slots) == "table", mapKey .. " superRod.slots must be table")
    assert(#def.superRod.slots == 5, mapKey .. " superRod must have exactly 5 slots, got " .. #def.superRod.slots)
    for idx, s in ipairs(def.superRod.slots) do
      totalSlots = totalSlots + 1
      local spId = EncountersGame3.toSpeciesId(s.species)
      assert(spId and spId >= 1 and spId <= 411, mapKey .. " invalid species at superRod slot " .. idx .. ": " .. tostring(s.species))
      speciesEncountered[spId] = true
    end
  end

  -- Verify Rock Smash slots (GBA standard: exactly 5 slots)
  if def.rockSmash then
    assert(type(def.rockSmash.slots) == "table", mapKey .. " rockSmash.slots must be table")
    assert(#def.rockSmash.slots == 5, mapKey .. " rockSmash must have exactly 5 slots, got " .. #def.rockSmash.slots)
    for idx, s in ipairs(def.rockSmash.slots) do
      totalSlots = totalSlots + 1
      local spId = EncountersGame3.toSpeciesId(s.species)
      assert(spId and spId >= 1 and spId <= 411, mapKey .. " invalid species at rockSmash slot " .. idx .. ": " .. tostring(s.species))
      speciesEncountered[spId] = true
    end
  end
end

assert(mapCount == 91, "Expected 91 curated map encounter tables, got " .. mapCount)
print(string.format("  Verified %d map tables, %d total encounter slots", mapCount, totalSlots))

-- Unique wild species placed count
local placedCount = 0
for _ in pairs(speciesEncountered) do placedCount = placedCount + 1 end
print(string.format("  Distinct wild base/mid species placed: %d", placedCount))
assert(placedCount >= 200, "Expected at least 200 distinct wild species placed across Kanto & Sevii, got " .. placedCount)

print("--- Testing Key Regional Content & Endgame Placements ---")

-- 1. Altering Cave Johto mystery pool
local alteringCave = EncountersGame3.MAP_TABLES.ALTERING_CAVE
assert(alteringCave and alteringCave.land, "Altering Cave must define land encounters")
local acSpecies = {}
for _, s in ipairs(alteringCave.land.slots) do
  acSpecies[EncountersGame3.toSpeciesId(s.species)] = true
end
assert(acSpecies[179] == true, "Altering Cave must contain Mareep (179)")
assert(acSpecies[204] == true, "Altering Cave must contain Pineco (204)")
assert(acSpecies[228] == true, "Altering Cave must contain Houndour (228)")
assert(acSpecies[216] == true, "Altering Cave must contain Teddiursa (216)")
assert(acSpecies[190] == true, "Altering Cave must contain Aipom (190)")
assert(acSpecies[234] == true, "Altering Cave must contain Stantler (234)")
assert(acSpecies[235] == true, "Altering Cave must contain Smeargle (235)")
print("  ✓ Altering Cave Johto mystery pool verified")

-- 2. Bagon on Mt. Ember Summit / Ruby Path
local mtEmber = EncountersGame3.MAP_TABLES.MT_EMBER_RUBY_PATH or EncountersGame3.MAP_TABLES.MT_EMBER_EXTERIOR
assert(mtEmber and mtEmber.land, "Mt Ember must have land encounters")
local bagonFound = false
local bagonId = EncountersGame3.toSpeciesId("BAGON")
for _, s in ipairs(mtEmber.land.slots) do
  if EncountersGame3.toSpeciesId(s.species) == bagonId then bagonFound = true end
end
assert(bagonFound, "Bagon must be found on Mt. Ember")
print("  ✓ Bagon verified on Mt. Ember")

-- 3. Beldum in Dotted Hole / Tanoby Chambers
local dottedHole = EncountersGame3.MAP_TABLES.DOTTED_HOLE
assert(dottedHole and dottedHole.land, "Dotted Hole must have land encounters")
local beldumFound = false
local beldumId = EncountersGame3.toSpeciesId("BELDUM")
for _, s in ipairs(dottedHole.land.slots) do
  if EncountersGame3.toSpeciesId(s.species) == beldumId then beldumFound = true end
end
assert(beldumFound, "Beldum must be found in Dotted Hole")
print("  ✓ Beldum verified in Dotted Hole")

-- 4. Tanoby Chambers 2:27 .. 2:33 individual tables for Unown forms
local unownId = EncountersGame3.toSpeciesId("UNOWN")
for m = 27, 33 do
  local chamberKey = "2:" .. m
  local chTable = EncountersGame3.getTableForMap(chamberKey)
  assert(chTable and chTable.land, "Tanoby Chamber " .. chamberKey .. " must have separate encounter table")
  assert(EncountersGame3.toSpeciesId(chTable.land.slots[1].species) == unownId, "Tanoby Chamber must contain Unown (201)")
end
print("  ✓ Tanoby Chambers 2:27..2:33 individual Unown tables verified")

-- 5. Rock Tunnel B1F Aron vs Lairon difficulty curve check
local rtB1F = EncountersGame3.MAP_TABLES.ROCK_TUNNEL_B1F
assert(rtB1F and rtB1F.land, "Rock Tunnel B1F must have land encounters")
local aronId = EncountersGame3.toSpeciesId("ARON")
local laironId = EncountersGame3.toSpeciesId("LAIRON")
local rtAronFound, rtLaironFound = false, false
for _, s in ipairs(rtB1F.land.slots) do
  local sid = EncountersGame3.toSpeciesId(s.species)
  if sid == aronId then rtAronFound = true end
  if sid == laironId then rtLaironFound = true end
end
assert(rtAronFound, "Aron (Lv 16-20) must be present in Rock Tunnel B1F")
assert(not rtLaironFound, "Lairon must NOT be in mid-game Rock Tunnel B1F (reserved for late game)")
print("  ✓ Aron verified in Rock Tunnel B1F (mid-game difficulty curve fair, no under-leveled Lairon)")

-- 6. Baby Incense Held Items on Marill & Wobbuffet
local meadow = EncountersGame3.MAP_TABLES.FIVE_ISLE_MEADOW
local marillSeaIncense = false
for _, s in ipairs(meadow.land.slots) do
  if s.species == "MARILL" and s.heldItem == 220 then
    marillSeaIncense = true
  end
end
assert(marillSeaIncense, "Five Isle Meadow Marill must hold Sea Incense (220)")

local ruinValley = EncountersGame3.MAP_TABLES.RUIN_VALLEY
local wobbuffetLaxIncense = false
for _, s in ipairs(ruinValley.land.slots) do
  if s.species == "WOBBUFFET" and s.heldItem == 221 then
    wobbuffetLaxIncense = true
  end
end
assert(wobbuffetLaxIncense, "Ruin Valley Wobbuffet must hold Lax Incense (221)")
print("  ✓ Sea Incense (220) & Lax Incense (221) verified as wild held items on Marill & Wobbuffet")

-- 7. Rock Smash & Fishing Parity
local greenPath = EncountersGame3.MAP_TABLES.GREEN_PATH
local relicanthSuperRod = false
for _, s in ipairs(greenPath.superRod.slots) do
  if s.species == "RELICANTH" then relicanthSuperRod = true end
end
assert(relicanthSuperRod, "Green Path Super Rod must contain Relicanth")

local seafoamB4F = EncountersGame3.MAP_TABLES.SEAFOAM_ISLANDS_B4F
local laprasSurf = false
for _, s in ipairs(seafoamB4F.water.slots) do
  if s.species == "LAPRAS" then laprasSurf = true end
end
assert(laprasSurf, "Seafoam B4F Surf must contain Lapras")

local kindleRoad = EncountersGame3.MAP_TABLES.KINDLE_ROAD
local shuckleRockSmash = false
for _, s in ipairs(kindleRoad.rockSmash.slots) do
  if s.species == "SHUCKLE" then shuckleRockSmash = true end
end
assert(shuckleRockSmash, "Kindle Road Rock Smash must contain Shuckle")
print("  ✓ Fishing, Surf & Rock Smash slot parity verified (Relicanth, Lapras, Shuckle)")

print("--- Testing Pokedex Town Map Area Dynamic Sync ---")
EncountersGame3.syncPokedexAreas("curated", {})
assert(PokedexData._speciesWildAreasKanto ~= nil, "Kanto wild areas table must be populated")
assert(PokedexData._speciesWildAreasSevii ~= nil, "Sevii wild areas table must be populated")

-- Bulbasaur (1) should have Kanto areas and 0 Sevii areas
local bulbasaurKanto = PokedexData.getWildAreasForSpecies(1, "kanto")
local bulbasaurSevii = PokedexData.getWildAreasForSpecies(1, "sevii")
assert(type(bulbasaurKanto) == "table" and #bulbasaurKanto > 0, "Bulbasaur must have Kanto wild areas")
assert(#bulbasaurSevii == 0, "Bulbasaur must have 0 Sevii wild areas")
print(string.format("  ✓ Bulbasaur mapped to %d Kanto areas, 0 Sevii areas", #bulbasaurKanto))

-- Unown (201) should have Sevii areas and 0 Kanto areas
local unownKanto = PokedexData.getWildAreasForSpecies(201, "kanto")
local unownSevii = PokedexData.getWildAreasForSpecies(201, "sevii")
assert(type(unownSevii) == "table" and #unownSevii > 0, "Unown must have Sevii wild areas")
assert(#unownKanto == 0, "Unown must have 0 Kanto wild areas")
print(string.format("  ✓ Unown mapped to %d Sevii areas, 0 Kanto areas", #unownSevii))
print("  ✓ Regional filter strictly isolates Kanto vs Sevii areas")

print("--- Testing Randomizer Spawn Modes ---")
local fakeMod = { log = { info = function() end } }

-- Pure random without legends
EncountersGame3.apply(fakeMod, "pure_random", { seed = 777, legends = false })
local rndTable = EncountersGame3.getTableForMap("3:19", "pure_random", { seed = 777, legends = false })
assert(#rndTable.land.slots == 12, "Pure random must preserve 12 land slots")
for _, s in ipairs(rndTable.land.slots) do
  -- Mewtwo (150), Mew (151), Lugia (249), Ho-Oh (250), Celebi (251), Kyogre (382), Groudon (383), Rayquaza (384)
  assert(s.species ~= 150 and s.species ~= 151 and s.species ~= 249 and s.species ~= 250 and s.species ~= 384,
    "Pure random without legends must not spawn box legendaries")
end
print("  ✓ Pure random mode preserves GBA slot counts and respects legends toggle")

-- Full random with legends
EncountersGame3.apply(fakeMod, "full_random", { legends = true })
local fullTable = EncountersGame3.getTableForMap("3:19", "full_random", { legends = true })
assert(#fullTable.land.slots == 12, "Full random must preserve 12 land slots")
print("  ✓ Full random with legends verified")

-- Reset back to curated
EncountersGame3.apply(fakeMod, "curated", {})
print("✓ All Gen 3 encounter & dex sync tests passed successfully!")
