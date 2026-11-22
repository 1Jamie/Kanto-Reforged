-- Test suite for Kanto Reforged Gen 3 Always-On National Dex decoupling.
-- Verifies that National Dex is fully active for dex viewing, encounters, captures,
-- and evolutions, WITHOUT prematurely modifying story flags 0x840 / 0x404E.

local Dex = require("src.core.game3.dex")
local PokedexData = require("src.core.game3.pokedex_data")
local Evolution = require("src.core.game3.evolution")
local Flags = require("src.core.game3.scripting.flags")
local EvolutionGame3 = require("mods.Kanto-Reforged.pokemon.evolution_game3")

print("--- Testing Decoupled National Dex State ---")

local store = Flags.newStore()
local dex = Dex.new()
local session = {
  national_dex_unlocked = true,
  dex = dex,
  store = store,
  version = "firered",
}
dex.nationalUnlocked = true

local fakeMod = {
  hooks = { wrap = function() end },
  log = { info = function() end }
}
EvolutionGame3.install(fakeMod)

-- 1. PokedexData.isNationalUnlocked should return true
assert(PokedexData.isNationalUnlocked(session, dex) == true, "isNationalUnlocked must return true when dex.nationalUnlocked is set")

-- 2. Critical Guardrail: Story flag 0x840 and variable 0x404E must be UNTOUCHED (clean false/0)
local flag840 = Flags.getFlag(store, nil, 0x840)
local var404E = Flags.getVar(store, nil, 0x404E)
assert(flag840 == false, "FLAG_SYS_NATIONAL_DEX (0x840) must NOT be set at boot! (prevents Oak/Celio story softlocks)")
assert(var404E == 0, "VAR_NATIONAL_DEX (0x404E) must NOT be set at boot! (prevents Oak/Celio story softlocks)")
print("  ✓ National Dex is active while story flags 0x840 and 0x404E remain clean")

print("--- Testing Registration Beyond 151 (Crobat, Torchic) ---")

-- 3. In vanilla locked state, species > 151 are dropped by registerEncounter / registerCapture
-- With our decoupled nationalUnlocked flag, they must register properly:
Dex.registerEncounter(dex, 169, session) -- Crobat
Dex.registerCapture(dex, 169, session)
assert(Dex.isSeen(dex, 169) == true, "Crobat (169) must be marked seen in Dex")
assert(Dex.isCaught(dex, 169) == true, "Crobat (169) must be marked caught in Dex")

Dex.registerEncounter(dex, 255, session) -- Torchic
Dex.registerCapture(dex, 255, session)
assert(Dex.isSeen(dex, 255) == true, "Torchic (255) must be marked seen in Dex")
assert(Dex.isCaught(dex, 255) == true, "Torchic (255) must be marked caught in Dex")

local natSeen = Dex.countSeen(dex, "national")
local natCaught = Dex.countCaught(dex, "national")
assert(natSeen >= 2, "National Dex seen count should include non-Kanto species")
assert(natCaught >= 2, "National Dex caught count should include non-Kanto species")
print(string.format("  ✓ Non-Kanto species registered cleanly (Seen: %d, Caught: %d)", natSeen, natCaught))

print("--- Testing Evolution Across Generations ---")

-- 4. Evolution.nationalAllows must allow evolutions > 151
assert(Evolution.nationalAllows(169, session) == true, "nationalAllows must permit Crobat (169)")
assert(Evolution.nationalAllows(208, session) == true, "nationalAllows must permit Steelix (208)")
assert(Evolution.nationalAllows(255, session) == true, "nationalAllows must permit Torchic (255)")
print("  ✓ All post-Gen 1 evolutions permitted across sessions")

print("--- Testing Town Map Area Lookup Decoupling ---")

local kantoAreas = PokedexData.getWildAreasForSpecies(1, "kanto")
local seviiAreas = PokedexData.getWildAreasForSpecies(201, "sevii")
assert(type(kantoAreas) == "table", "getWildAreasForSpecies for Kanto must return table")
assert(type(seviiAreas) == "table", "getWildAreasForSpecies for Sevii must return table")
print("  ✓ Town Map region-aware Area lookups verified")

print("✓ All Gen 3 National Dex decoupled tests passed successfully!")
