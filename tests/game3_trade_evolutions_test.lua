-- Test suite for Gen 3 Trade Evolution direct bag item use & consumption safety.

local EvolutionGame3 = require("mods.Kanto-Reforged.pokemon.evolution_game3")
local Evolution = require("src.core.game3.evolution")
local ItemsData = require("src.core.game3.items_data")
local ItemUse = require("src.core.game3.item_use")

print("--- Testing Gen 3 Trade Item Field Use Registration ---")

local fakeMod = {
  hooks = {
    wrap = function(self, hookName, fn)
      -- mock hook registration
    end
  },
  log = { info = function() end }
}
EvolutionGame3.install(fakeMod)

-- 1. Check ItemsData.fieldUseKind for trade items
local tradeItems = {
  { id = 199, name = "ITEM_METAL_COAT" },
  { id = 201, name = "ITEM_DRAGON_SCALE" },
  { id = 187, name = "ITEM_KINGS_ROCK" },
  { id = 218, name = "ITEM_UP_GRADE" },
  { id = 192, name = "ITEM_DEEP_SEA_TOOTH" },
  { id = 193, name = "ITEM_DEEP_SEA_SCALE" },
}

for _, it in ipairs(tradeItems) do
  local kind = ItemsData.fieldUseKind(it.id)
  assert(kind == "evo", string.format("ItemsData.fieldUseKind(%d / %s) must return 'evo', got '%s'", it.id, it.name, tostring(kind)))
  local kindByName = ItemsData.fieldUseKind(it.name)
  assert(kindByName == "evo", string.format("ItemsData.fieldUseKind(%s) must return 'evo', got '%s'", it.name, tostring(kindByName)))
end
print("  ✓ All 6 trade evolution items register as 'evo' for direct Bag USE")

print("--- Testing Eligible Evolution Targets ---")

local session = {
  national_dex_unlocked = true,
  dex = { nationalUnlocked = true }
}

local evoCases = {
  { species = 123, name = "Scyther", item = "ITEM_METAL_COAT", expected = 212, expName = "Scizor" },
  { species = 95,  name = "Onix", item = "ITEM_METAL_COAT", expected = 208, expName = "Steelix" },
  { species = 117, name = "Seadra", item = "ITEM_DRAGON_SCALE", expected = 230, expName = "Kingdra" },
  { species = 137, name = "Porygon", item = "ITEM_UP_GRADE", expected = 233, expName = "Porygon2" },
  { species = 61,  name = "Poliwhirl", item = "ITEM_KINGS_ROCK", expected = 186, expName = "Politoed" },
  { species = 79,  name = "Slowpoke", item = "ITEM_KINGS_ROCK", expected = 199, expName = "Slowking" },
  { species = 373, name = "Clamperl", item = "ITEM_DEEP_SEA_TOOTH", expected = 374, expName = "Huntail" },
  { species = 373, name = "Clamperl", item = "ITEM_DEEP_SEA_SCALE", expected = 375, expName = "Gorebyss" },
  { species = 133, name = "Eevee", item = 93, expected = 196, expName = "Espeon (Sun Stone)" },
  { species = 133, name = "Eevee", item = 94, expected = 197, expName = "Umbreon (Moon Stone)" },
}

for _, c in ipairs(evoCases) do
  local mon = { species = c.species, level = 30 }
  local target = Evolution.itemTarget(mon, c.item, session)
  assert(target == c.expected, string.format("%s + %s must evolve into %s (%d), got %s",
    c.name, tostring(c.item), c.expName, c.expected, tostring(target)))
  print(string.format("  ✓ %s + %s -> %s (%d)", c.name, tostring(c.item), c.expName, c.expected))
end

print("--- Testing Ineligible Target Rejection & Safe Non-Consumption ---")

local ineligibleCases = {
  { species = 25, name = "Pikachu", item = "ITEM_METAL_COAT" },
  { species = 1,  name = "Bulbasaur", item = "ITEM_DRAGON_SCALE" },
  { species = 10, name = "Caterpie", item = "ITEM_UP_GRADE" },
  { species = 129, name = "Magikarp", item = "ITEM_KINGS_ROCK" },
  { species = 133, name = "Eevee", item = "ITEM_DEEP_SEA_TOOTH" },
}

for _, c in ipairs(ineligibleCases) do
  local mon = { species = c.species, level = 25 }
  local target = Evolution.itemTarget(mon, c.item, session)
  assert(target == nil, string.format("%s must NOT evolve with %s (target should be nil, got %s)",
    c.name, c.item, tostring(target)))
end
print("  ✓ All ineligible species correctly rejected with nil evolution target")

-- Verify item non-consumption in ItemUse.useEvolutionStone
local Bag = require("src.core.game3.bag")
local bag = Bag.new()
bag.items = bag.items or {}
Bag.add(bag, 199, 3) -- 3x Metal Coat
assert(Bag.has(bag, 199, 3), "Bag should have 3 Metal Coats before use")

local party = {
  { species = 25, level = 30, hp = 50, maxHp = 50 } -- Pikachu (ineligible)
}
local fakeGame = {
  session = { bag = bag, national_dex_unlocked = true, dex = { nationalUnlocked = true } }
}

local ok, reason = ItemUse.useEvolutionStone(fakeGame.session, party[1], 199, bag)
assert(ok == false, "useEvolutionStone must return false for ineligible mon")
assert(reason == "no_evo", "useEvolutionStone must return 'no_evo'")
assert(Bag.get(bag, 199) == 3, "Metal Coat must NOT be consumed on ineligible Pokémon! (expected 3, got " .. tostring(Bag.get(bag, 199)) .. ")")
print("  ✓ ItemUse safely aborts with 'no_effect' without consuming item on ineligible mon")

print("--- Testing Mart Stocking for Breeding Incenses ---")
local Marts = require("src.core.game3.marts")
Marts._byKey = Marts._byKey or {}
Marts._byKey["celadon_test"] = { items = { 95, 96, 97, 98 } }
Marts._byKey["four_island_test"] = { items = { 2, 19, 22 } }

local celadonItems = Marts.itemsFor("celadon_test")
assert(celadonItems ~= nil, "Celadon test mart must resolve")
local hasSea, hasLax = false, false
for _, id in ipairs(celadonItems) do
  if id == 220 then hasSea = true end
  if id == 221 then hasLax = true end
end
assert(hasSea and hasLax, "Celadon mart must stock Sea Incense (220) and Lax Incense (221)")
print("  ✓ Celadon Dept Store stone clerk stocks Sea Incense & Lax Incense")

local seviiItems = Marts.itemsFor("four_island_test")
assert(seviiItems ~= nil, "Four Island test mart must resolve")
hasSea, hasLax = false, false
for _, id in ipairs(seviiItems) do
  if id == 220 then hasSea = true end
  if id == 221 then hasLax = true end
end
assert(hasSea and hasLax, "Four Island mart must stock Sea Incense (220) and Lax Incense (221)")
print("  ✓ Four Island Mart stocks Sea Incense & Lax Incense")

print("✓ All Gen 3 trade evolution & mart incense tests passed successfully!")
