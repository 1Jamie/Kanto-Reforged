-- Test suite for Gen 3 host detection and manifest configuration.

local Host = require("mods.Kanto-Reforged.core.host")
local GameVersion = require("src.core.GameVersion")

local function runTests()
  print("--- Testing Gen 3 Host Detection ---")

  -- 1. Test Host.force(3)
  Host.force(3)
  assert(Host.generation() == 3, "Host.generation() should be 3 when forced")
  assert(Host.isGen3() == true, "Host.isGen3() should be true")
  assert(Host.isGen1() == false, "Host.isGen1() should be false")
  assert(Host.isGen2() == false, "Host.isGen2() should be false")
  assert(Host.isGame3() == true, "Host.isGame3() should be true")

  -- 2. Test loader generation check
  local fakeModGen3 = {
    loader = { generation = 3 }
  }
  assert(Host.generationFrom(fakeModGen3) == 3, "generationFrom should return 3 for gen3 loader")
  assert(Host.isGen3From(fakeModGen3) == true, "isGen3From should return true")

  -- 3. Test GameVersion detection
  Host.clearForce()
  local oldCurrent = GameVersion.current
  GameVersion.current = "firered"
  assert(Host.isFireRed() == true, "Host.isFireRed() should be true for firered")
  assert(Host.isGen3() == true, "Host.isGen3() should be true when GameVersion is firered")

  GameVersion.current = "leafgreen"
  assert(Host.isLeafGreen() == true, "Host.isLeafGreen() should be true for leafgreen")
  assert(Host.isGen3() == true, "Host.isGen3() should be true when GameVersion is leafgreen")

  GameVersion.current = oldCurrent
  print("✓ Gen 3 Host Detection tests passed!")
end

runTests()
