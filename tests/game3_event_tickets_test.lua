package.path = package.path .. ";../../?.lua;../?.lua;./?.lua"

pcall(function() require("tests.fixture_data.game3_items").install() end)

local Host = require("mods.Kanto-Reforged.core.host")
local EventTickets = require("mods.Kanto-Reforged.world.event_tickets_game3")
local Bag = require("src.core.game3.bag")

Host.force(3)
assert(Host.isGen3(), "Host must be forced to Gen 3")

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
local session = { bag = bag, flags = {} }

-- 1. Test Mystic Ticket Award
assert(not EventTickets.hasMysticTicket(session), "Should not have Mystic Ticket initially")
assert(not session.flags[0x84A], "Navel Rock flag should not be set initially")

local awardedMystic = EventTickets.awardMysticTicket(mockMod, session)
assert(awardedMystic, "First award of Mystic Ticket should succeed")
assert(EventTickets.hasMysticTicket(session), "Should now have Mystic Ticket")
assert(Bag.has(bag, 370, 1), "Bag should contain ITEM_MYSTIC_TICKET (370)")
assert(session.flags[0x84A], "FLAG_ENABLE_SHIP_NAVEL_ROCK (0x84A) should be set")
assert(session.flags[0x2A8], "FLAG_RECEIVED_MYSTIC_TICKET should be set")
assert(mockMod.save:get("got_mystic_ticket_game3"), "Mod save should record got_mystic_ticket_game3")

-- Second award should be idempotent and return false
local awardedMysticAgain = EventTickets.awardMysticTicket(mockMod, session)
assert(not awardedMysticAgain, "Second award should return false")
assert(Bag.get(bag, 370) == 1, "Bag should still only have 1 Mystic Ticket")

-- 2. Test Aurora Ticket Award
assert(not EventTickets.hasAuroraTicket(session), "Should not have Aurora Ticket initially")
assert(not session.flags[0x84B], "Birth Island flag should not be set initially")

local awardedAurora = EventTickets.awardAuroraTicket(mockMod, session)
assert(awardedAurora, "First award of Aurora Ticket should succeed")
assert(EventTickets.hasAuroraTicket(session), "Should now have Aurora Ticket")
assert(Bag.has(bag, 371, 1), "Bag should contain ITEM_AURORA_TICKET (371)")
assert(session.flags[0x84B], "FLAG_ENABLE_SHIP_BIRTH_ISLAND (0x84B) should be set")
assert(session.flags[0x2A7], "FLAG_RECEIVED_AURORA_TICKET should be set")
assert(mockMod.save:get("got_aurora_ticket_game3"), "Mod save should record got_aurora_ticket_game3")

-- 3. Test Researcher flow
local freshBag = Bag.new()
local preGameClearSession = { bag = freshBag, flags = {} }
local lastMsg = nil
local mockGame = {
  stack = {
    push = function(self, box)
      lastMsg = box and box.text or "dialogue"
    end
  }
}

-- Pre-clear should deny ticket
EventTickets.talkResearcher(mockGame, mockMod, preGameClearSession, function() end)
assert(not EventTickets.hasAuroraTicket(preGameClearSession), "Should not award before Game Clear")

-- Post-clear should grant Aurora ticket on first talk
preGameClearSession.flags[0x82C] = true -- FLAG_SYS_GAME_CLEAR
EventTickets.talkResearcher(mockGame, mockMod, preGameClearSession, function() end)
assert(EventTickets.hasAuroraTicket(preGameClearSession), "Should award Aurora Ticket after Game Clear")
assert(preGameClearSession.flags[0x84B], "Birth Island ferry flag must be set")

-- Second talk should grant Mystic ticket
EventTickets.talkResearcher(mockGame, mockMod, preGameClearSession, function() end)
assert(EventTickets.hasMysticTicket(preGameClearSession), "Should award Mystic Ticket on second talk")
assert(preGameClearSession.flags[0x84A], "Navel Rock ferry flag must be set")

-- Third talk should grant no more tickets
EventTickets.talkResearcher(mockGame, mockMod, preGameClearSession, function() end)
assert(Bag.get(preGameClearSession.bag, 370) == 1, "Should still have 1 Mystic Ticket")
assert(Bag.get(preGameClearSession.bag, 371) == 1, "Should still have 1 Aurora Ticket")

-- HouseNpcs injection path (visible NPC on One Island PC)
local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
HouseNpcs.resetClaims()
HouseNpcs.resetInjections()
EventTickets.register(mockMod)
local inj = HouseNpcs._gen3Injections["FR_ONE_ISLAND_POKEMON_CENTER_1F"]
  or HouseNpcs._gen3Injections["ONE_ISLAND_POKEMON_CENTER_1F"]
assert(inj and #inj >= 1, "Sevii astronomer must be Gen3-injected")
assert(inj[1].x == 3 and inj[1].y == 5, "Astronomer stands at (3, 5)")
assert(HouseNpcs._talks["TEXT_SEVII_ASTRONOMER"] ~= nil, "Astronomer talk handler bound")

print("game3_event_tickets_test passed cleanly!")
