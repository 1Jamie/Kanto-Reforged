-- Test suite for LocationSignpost overlay module in Kanto-Reforged
local T = require("tests.modkit")
local LocationSignpost = require("mods.Kanto-Reforged.ui.location_signpost")

-- 1. Test cleanAreaName
T.eq(LocationSignpost.cleanAreaName("PALLET_TOWN"), "PALLET TOWN", "Pallet Town name")
T.eq(LocationSignpost.cleanAreaName("ROUTE_1"), "ROUTE 1", "Route 1 name")
T.eq(LocationSignpost.cleanAreaName("VIRIDIAN_CITY"), "VIRIDIAN CITY", "Viridian City name")
T.eq(LocationSignpost.cleanAreaName("MT_MOON_1F"), "MT. MOON 1F", "Mt Moon 1F dungeon name")
T.eq(LocationSignpost.cleanAreaName("MT_MOON_B2F"), "MT. MOON B2F", "Mt Moon B2F dungeon name")
T.eq(LocationSignpost.cleanAreaName("POKEMON_TOWER_3F"), "POKÉMON TOWER 3F", "Pokemon Tower 3F dungeon name")
T.eq(LocationSignpost.cleanAreaName("VIRIDIAN_POKECENTER_1F"), "VIRIDIAN POKECENTER", "Pokecenter building name with floor stripped")
T.eq(LocationSignpost.cleanAreaName("BERRY_FARM"), "BERRY FARM", "Berry Farm name")

-- 2. Test accent colors
local colRoute = LocationSignpost.getAccentColor("ROUTE 1", "ROUTE_1")
T.check(colRoute ~= nil and #colRoute == 3, "Route accent color")

local colTown = LocationSignpost.getAccentColor("PALLET TOWN", "PALLET_TOWN")
T.check(colTown ~= nil and #colTown == 3, "Town accent color")

local colCave = LocationSignpost.getAccentColor("MT. MOON", "MT_MOON_1F")
T.check(colCave ~= nil and #colCave == 3, "Cave accent color")

-- 3. Test save gate
local noSaveGame = { overworld = { map = { id = "PALLET_TOWN" } } }
T.eq(LocationSignpost.isOverworldActive(noSaveGame), false, "Game without save returns false")

-- 4. Test state transition lifecycle
LocationSignpost._currentArea = nil
LocationSignpost._animState = "idle"

local mockGame1 = {
  save = { player = { map = "PALLET_TOWN" }, party = { { species = "BULBASAUR" } } },
  overworld = { map = { id = "PALLET_TOWN" } },
}
LocationSignpost.update(mockGame1)

T.eq(LocationSignpost._animState, "enter", "Entering Pallet Town sets animState enter")
T.eq(LocationSignpost._displayTitle, "PALLET TOWN", "Display title is PALLET TOWN")

-- Same area update should not re-trigger enter
LocationSignpost.update(mockGame1)
T.eq(LocationSignpost._animState, "enter", "Same area preserves current animation state")

-- Changing to Route 1
local mockGame2 = {
  save = { player = { map = "ROUTE_1" }, party = { { species = "BULBASAUR" } } },
  overworld = { map = { id = "ROUTE_1" } },
}
LocationSignpost.update(mockGame2)
T.eq(LocationSignpost._animState, "enter", "Changing area triggers enter state")
T.eq(LocationSignpost._displayTitle, "ROUTE 1", "Display title is ROUTE 1")

-- 5. Test Pokecenter floor transitions (1F <-> 2F does NOT re-trigger)
LocationSignpost._animState = "idle"
LocationSignpost._currentArea = "CHERRYGROVE POKECENTER"

local pc1F = {
  save = { player = { map = "CHERRYGROVE_POKECENTER_1F" }, party = { { species = "CYNDAQUIL" } } },
  world = { map = { id = "CHERRYGROVE_POKECENTER_1F" }, player = { px = 1, py = 1 } },
}
LocationSignpost.update(pc1F)
T.eq(LocationSignpost._animState, "idle", "Pokecenter 1F matching current area stays idle")

local pc2F = {
  save = { player = { map = "POKECENTER_2F" }, party = { { species = "CYNDAQUIL" } } },
  world = { map = { id = "POKECENTER_2F" }, player = { px = 1, py = 1 } },
}
LocationSignpost.update(pc2F)
T.eq(LocationSignpost._animState, "idle", "Pokecenter 2F transition does NOT re-trigger overlay")

-- 6. Test Pokecenter 2F -> Berry Farm transition (DOES trigger BERRY FARM)
local farmGame = {
  save = { player = { map = "BERRY_FARM" }, party = { { species = "CYNDAQUIL" } } },
  world = { map = { id = "BERRY_FARM" }, player = { px = 1, py = 1 } },
}
LocationSignpost.update(farmGame)
T.eq(LocationSignpost._animState, "enter", "Stepping into Berry Farm triggers enter state")
T.eq(LocationSignpost._displayTitle, "BERRY FARM", "Display title is BERRY FARM")

-- 7. Test Underground Path Entrance -> Tunnel transition
LocationSignpost._animState = "idle"
LocationSignpost._currentArea = "ROUTE 5"

local pathEntrance = {
  save = { player = { map = "UNDERGROUND_PATH_ROUTE_5_ENTRANCE" }, party = { { species = "BULBASAUR" } } },
  overworld = { map = { id = "UNDERGROUND_PATH_ROUTE_5_ENTRANCE" } },
}
LocationSignpost.update(pathEntrance)
T.eq(LocationSignpost._animState, "enter", "Entering Underground Path entrance building triggers overlay")
T.eq(LocationSignpost._displayTitle, "UNDERGROUND PATH", "Title is UNDERGROUND PATH")

LocationSignpost._animState = "idle"
local pathTunnel = {
  save = { player = { map = "UNDERGROUND_PATH_ROUTE_5" }, party = { { species = "BULBASAUR" } } },
  overworld = { map = { id = "UNDERGROUND_PATH_ROUTE_5" } },
}
LocationSignpost.update(pathTunnel)
T.eq(LocationSignpost._animState, "idle", "Going down stairs to Underground Path tunnel does NOT re-trigger overlay")

-- 8. Test Dungeon Floor transition (Rocket Hideout B1F -> B2F DOES re-trigger)
LocationSignpost._animState = "idle"
LocationSignpost._currentArea = "ROCKET HIDEOUT B1F"

local hideoutB2F = {
  save = { player = { map = "ROCKET_HIDEOUT_B2F" }, party = { { species = "BULBASAUR" } } },
  overworld = { map = { id = "ROCKET_HIDEOUT_B2F" } },
}
LocationSignpost.update(hideoutB2F)
T.eq(LocationSignpost._animState, "enter", "Changing floors in Rocket Hideout triggers overlay")
T.eq(LocationSignpost._displayTitle, "ROCKET HIDEOUT B2F", "Title is ROCKET HIDEOUT B2F")

print("All LocationSignpost transition unit tests passed!")
