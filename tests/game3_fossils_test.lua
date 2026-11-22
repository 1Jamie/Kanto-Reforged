package.path = package.path .. ";../../?.lua;../?.lua;./?.lua"

local Host = require("mods.Kanto-Reforged.core.host")
local FossilsGame3 = require("mods.Kanto-Reforged.world.fossils_game3")
local Bag = require("src.core.game3.bag")
local Party = require("src.core.game3.party")

Host.force(3)
assert(Host.isGen3(), "Host must be forced to Gen 3")

local Pokemon = require("src.core.game3.pokemon")
Pokemon.name = function(species)
  if species == FossilsGame3.SPECIES_LILEEP then return "LILEEP"
  elseif species == FossilsGame3.SPECIES_ANORITH then return "ANORITH"
  else return "POKEMON" end
end

local saveStore = {}
local mockMod = {
  save = {
    get = function(self, k, default)
      if saveStore[k] ~= nil then return saveStore[k] end
      return default
    end,
    set = function(self, k, v)
      saveStore[k] = v
    end,
  },
}

local bag = Bag.new()
local session = { bag = bag, party = {}, flags = {} }
local mockGame = {
  stack = {
    push = function() end,
  }
}

-- 1. Test Root Fossil Pickup in Lost Cave
assert(Bag.get(bag, FossilsGame3.ITEM_ROOT_FOSSIL) == 0, "Initial bag should have 0 Root Fossils")
FossilsGame3.interactRootFossil(mockGame, mockMod, session)
assert(Bag.get(bag, FossilsGame3.ITEM_ROOT_FOSSIL) == 1, "Bag should now have 1 Root Fossil")
assert(mockMod.save:get("kr_got_root_fossil") == true, "Save flag kr_got_root_fossil must be set")

-- Idempotent check: pickup again shouldn't duplicate
FossilsGame3.interactRootFossil(mockGame, mockMod, session)
assert(Bag.get(bag, FossilsGame3.ITEM_ROOT_FOSSIL) == 1, "Second pickup should not award duplicate fossil")

-- 2. Test Claw Fossil Pickup in Icefall Cave
assert(Bag.get(bag, FossilsGame3.ITEM_CLAW_FOSSIL) == 0, "Initial bag should have 0 Claw Fossils")
FossilsGame3.interactClawFossil(mockGame, mockMod, session)
assert(Bag.get(bag, FossilsGame3.ITEM_CLAW_FOSSIL) == 1, "Bag should now have 1 Claw Fossil")
assert(mockMod.save:get("kr_got_claw_fossil") == true, "Save flag kr_got_claw_fossil must be set")

-- 3. Test Cinnabar Lab Revival of Root Fossil -> Lileep (388)
local initialPartyCount = #session.party
FossilsGame3.reviveFossil(mockGame, mockMod, session, FossilsGame3.ITEM_ROOT_FOSSIL, FossilsGame3.SPECIES_LILEEP, "LILEEP")
assert(Bag.get(bag, FossilsGame3.ITEM_ROOT_FOSSIL) == 0, "Root Fossil should be consumed from bag")
assert(#session.party == initialPartyCount + 1, "Party should have +1 Pokémon")
local lileep = session.party[#session.party]
assert(lileep.species == FossilsGame3.SPECIES_LILEEP, "Generated mon must be Lileep (388), got: " .. tostring(lileep.species))
assert(lileep.level == 20, "Lileep should be level 20")

-- 4. Test Cinnabar Lab Revival of Claw Fossil -> Anorith (390)
local partyCountBeforeAnorith = #session.party
FossilsGame3.reviveFossil(mockGame, mockMod, session, FossilsGame3.ITEM_CLAW_FOSSIL, FossilsGame3.SPECIES_ANORITH, "ANORITH")
assert(Bag.get(bag, FossilsGame3.ITEM_CLAW_FOSSIL) == 0, "Claw Fossil should be consumed from bag")
assert(#session.party == partyCountBeforeAnorith + 1, "Party should have +1 Pokémon")
local anorith = session.party[#session.party]
assert(anorith.species == FossilsGame3.SPECIES_ANORITH, "Generated mon must be Anorith (390), got: " .. tostring(anorith.species))
assert(anorith.level == 20, "Anorith should be level 20")

print("game3_fossils_test passed cleanly!")
