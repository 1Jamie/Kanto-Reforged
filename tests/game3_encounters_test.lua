-- Test suite for Gen 3 encounter tables, 12-slot math, and randomizer modes.

local EncountersGame3 = require("mods.Kanto-Reforged.world.encounters_game3")

local function runTests()
  print("--- Testing Gen 3 Wild Encounters ---")

  -- 1. Test Curated Encounter Generation on Route 1 (3:19)
  local r1 = EncountersGame3.getTableForMap("3:19", "curated")
  assert(r1 ~= nil, "Route 1 table must be generated")
  assert(r1.land ~= nil, "Route 1 must have land encounters")
  assert(#r1.land.slots == 12, "Route 1 land slots must be exactly 12 (GBA rate math requirement)")
  assert(r1.land.rate == 20, "Route 1 rate should be 20")

  -- 2. Test Sun Stone Held Item on Early Grass (Route 5: 3:23)
  local r5 = EncountersGame3.getTableForMap("3:23", "curated")
  assert(r5 ~= nil, "Route 5 table must be generated")
  assert(#r5.land.slots == 12, "Route 5 land slots must be exactly 12")
  local hasSunStone = false
  for _, slot in ipairs(r5.land.slots) do
    if slot.heldItem == 93 then
      hasSunStone = true
      break
    end
  end
  assert(hasSunStone, "Route 5 should have grass spawns with Sun Stone held item for early Espeon path")

  -- 3. Test Pure Random Mode
  local r1Random = EncountersGame3.getTableForMap("3:19", "pure_random", { seed = 99999 })
  assert(r1Random ~= nil, "Random table must be generated")
  assert(#r1Random.land.slots == 12, "Random land slots must be exactly 12")

  -- 4. Test Full Random Mode
  local r1Full = EncountersGame3.getTableForMap("3:19", "full_random")
  assert(r1Full ~= nil, "Full random table must be generated")
  assert(#r1Full.land.slots == 12, "Full random land slots must be exactly 12")

  -- 5. Test Surf (Water) slots on Route 6 (3:24)
  local r6 = EncountersGame3.getTableForMap("3:24", "curated")
  assert(r6 ~= nil and r6.water ~= nil, "Route 6 must have water encounters")
  assert(#r6.water.slots == 5, "Route 6 water slots must be exactly 5")

  print("✓ Gen 3 Wild Encounters tests passed!")
end

runTests()
