-- Test suite for Gen 3 stone evolutions and National Dex unlock bypass.

local EvolutionGame3 = require("mods.Kanto-Reforged.pokemon.evolution_game3")

local function runTests()
  print("--- Testing Gen 3 Evolution Bypasses ---")

  -- Stub mod object
  local fakeMod = {
    log = { info = function() end }
  }

  EvolutionGame3.install(fakeMod)

  local okE, Evolution = pcall(require, "src.core.game3.evolution")
  assert(okE and Evolution, "src.core.game3.evolution must exist")

  -- 1. Test National Dex bypass
  assert(Evolution.nationalAllows(208, nil) == true, "Steelix (Gen 2) should be allowed before postgame")
  assert(Evolution.nationalAllows(169, nil) == true, "Crobat (Gen 2) should be allowed before postgame")
  assert(Evolution.nationalAllows(306, nil) == true, "Aggron (Gen 3) should be allowed before postgame")

  -- 2. Test Stone Evolutions in Pokemon._evolutions
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  assert(okP and Pokemon, "src.core.game3.pokemon must exist")

  -- Test Onix -> Steelix via Moon Stone (item = 94)
  local onixId = 95
  local evos = Pokemon.evolutions(onixId)
  local foundSteelix = false
  for _, evo in ipairs(evos) do
    local method = tonumber(evo.method or evo[1])
    local param = tonumber(evo.param or evo[2])
    local target = tonumber(evo.target or evo[3])
    if method == Evolution.EVO_ITEM and param == 94 and target == 208 then
      foundSteelix = true
      break
    end
  end
  assert(foundSteelix, "Onix must have Moon Stone evolution into Steelix (208)")

  -- Test Eevee -> Umbreon (Moon Stone = 94) and Espeon (Sun Stone = 93)
  local eeveeId = 133
  local eeveeEvos = Pokemon.evolutions(eeveeId)
  local foundUmbreon = false
  local foundEspeon = false
  for _, evo in ipairs(eeveeEvos) do
    local method = tonumber(evo.method or evo[1])
    local param = tonumber(evo.param or evo[2])
    local target = tonumber(evo.target or evo[3])
    if method == Evolution.EVO_ITEM and param == 94 and target == 197 then
      foundUmbreon = true
    end
    if method == Evolution.EVO_ITEM and param == 93 and target == 196 then
      foundEspeon = true
    end
  end
  assert(foundUmbreon, "Eevee must have Moon Stone evolution into Umbreon (197)")
  assert(foundEspeon, "Eevee must have Sun Stone evolution into Espeon (196)")

  -- Test Clamperl -> Gorebyss (Moon Stone = 94) and Huntail (Water Stone = 97)
  local clamperlId = 366
  local clamperlEvos = Pokemon.evolutions(clamperlId)
  local foundGorebyss = false
  local foundHuntail = false
  for _, evo in ipairs(clamperlEvos) do
    local method = tonumber(evo.method or evo[1])
    local param = tonumber(evo.param or evo[2])
    local target = tonumber(evo.target or evo[3])
    if method == Evolution.EVO_ITEM and param == 94 and target == 368 then
      foundGorebyss = true
    end
    if method == Evolution.EVO_ITEM and param == 97 and target == 367 then
      foundHuntail = true
    end
  end
  assert(foundGorebyss, "Clamperl must have Moon Stone evolution into Gorebyss (368)")
  assert(foundHuntail, "Clamperl must have Water Stone evolution into Huntail (367)")

  print("✓ Gen 3 Evolution Bypasses tests passed!")
end

runTests()
