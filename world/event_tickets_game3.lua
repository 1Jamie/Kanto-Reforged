-- Canonical Event Passes for FireRed / LeafGreen in Kanto Reforged
-- Awards ITEM_MYSTIC_TICKET (Navel Rock Ho-Oh/Lugia) via Celadon Circuit (4th streak win)
-- Awards ITEM_AURORA_TICKET (Birth Island Deoxys) via Sevii Island One researcher after Game Clear
-- Sets GBA ship enable flags so the Seagallop Vermilion ferry natively offers the destinations.

local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")

local EventTicketsGame3 = {}

EventTicketsGame3.ITEM_MYSTIC_TICKET = 370
EventTicketsGame3.ITEM_AURORA_TICKET = 371
EventTicketsGame3.FLAG_ENABLE_SHIP_NAVEL_ROCK = 0x84A
EventTicketsGame3.FLAG_ENABLE_SHIP_BIRTH_ISLAND = 0x84B
EventTicketsGame3.FLAG_RECEIVED_MYSTIC_TICKET = 0x2A8
EventTicketsGame3.FLAG_RECEIVED_AURORA_TICKET = 0x2A7
EventTicketsGame3.FLAG_SYS_GAME_CLEAR = 0x82C

EventTicketsGame3.RESEARCHER_MAP = "FR_ONE_ISLAND_POKEMON_CENTER_1F"
EventTicketsGame3.RESEARCHER_MAP_ALIAS = "ONE_ISLAND_POKEMON_CENTER_1F"
EventTicketsGame3.RESEARCHER_POS = { x = 3, y = 5 }
EventTicketsGame3.TEXT_ID = "TEXT_SEVII_ASTRONOMER"
EventTicketsGame3.OWNER = "event_tickets_game3"

local function getBag(saveOrSession)
  if not saveOrSession then return nil end
  return saveOrSession.bag or saveOrSession
end

--- Live FRLG scripts read Space.store; also mirror onto session.flags for tests/sidecars.
local function resolveFlagStores(storeOrSession)
  local stores = {}
  local seen = {}
  local function add(s)
    if type(s) == "table" and not seen[s] then
      seen[s] = true
      stores[#stores + 1] = s
    end
  end
  local okSp, Space = pcall(require, "src.core.game3.scripting.space")
  if okSp and Space and Space.store then add(Space.store) end
  if type(storeOrSession) == "table" then
    add(storeOrSession.store)
    add(storeOrSession)
    if type(storeOrSession.flags) == "table" then add(storeOrSession.flags) end
  end
  return stores
end

local function setFlag(storeOrSession, flagId)
  local okFlags, Flags = pcall(require, "src.core.game3.scripting.flags")
  for _, store in ipairs(resolveFlagStores(storeOrSession)) do
    if okFlags and Flags and Flags.setFlag then
      Flags.setFlag(store, nil, flagId, true)
    end
    if store.flags then
      store.flags[flagId] = true
      store.flags[tostring(flagId)] = true
    else
      store[flagId] = true
      store[tostring(flagId)] = true
    end
  end
end

local function hasFlag(storeOrSession, flagId)
  local okFlags, Flags = pcall(require, "src.core.game3.scripting.flags")
  for _, store in ipairs(resolveFlagStores(storeOrSession)) do
    if okFlags and Flags and Flags.getFlag then
      if Flags.getFlag(store, nil, flagId) then return true end
    end
    if store.flags then
      if store.flags[flagId] or store.flags[tostring(flagId)] then return true end
    elseif store[flagId] or store[tostring(flagId)] then
      return true
    end
  end
  return false
end

function EventTicketsGame3.hasMysticTicket(session)
  local Bag = require("src.core.game3.bag")
  local bag = getBag(session)
  return Bag.has(bag, EventTicketsGame3.ITEM_MYSTIC_TICKET, 1)
end

function EventTicketsGame3.hasAuroraTicket(session)
  local Bag = require("src.core.game3.bag")
  local bag = getBag(session)
  return Bag.has(bag, EventTicketsGame3.ITEM_AURORA_TICKET, 1)
end

--- Award Mystic Ticket + set GBA Navel Rock ferry flag
function EventTicketsGame3.awardMysticTicket(mod, session)
  local Bag = require("src.core.game3.bag")
  local bag = getBag(session)
  if EventTicketsGame3.hasMysticTicket(session) then
    setFlag(session, EventTicketsGame3.FLAG_ENABLE_SHIP_NAVEL_ROCK)
    setFlag(session, EventTicketsGame3.FLAG_RECEIVED_MYSTIC_TICKET)
    return false
  end
  Bag.add(bag, EventTicketsGame3.ITEM_MYSTIC_TICKET, 1)
  setFlag(session, EventTicketsGame3.FLAG_ENABLE_SHIP_NAVEL_ROCK)
  setFlag(session, EventTicketsGame3.FLAG_RECEIVED_MYSTIC_TICKET)
  if mod and mod.save then
    mod.save:set("got_mystic_ticket_game3", true)
  end
  return true
end

--- Award Aurora Ticket + set GBA Birth Island ferry flag
function EventTicketsGame3.awardAuroraTicket(mod, session)
  local Bag = require("src.core.game3.bag")
  local bag = getBag(session)
  if EventTicketsGame3.hasAuroraTicket(session) then
    setFlag(session, EventTicketsGame3.FLAG_ENABLE_SHIP_BIRTH_ISLAND)
    setFlag(session, EventTicketsGame3.FLAG_RECEIVED_AURORA_TICKET)
    return false
  end
  Bag.add(bag, EventTicketsGame3.ITEM_AURORA_TICKET, 1)
  setFlag(session, EventTicketsGame3.FLAG_ENABLE_SHIP_BIRTH_ISLAND)
  setFlag(session, EventTicketsGame3.FLAG_RECEIVED_AURORA_TICKET)
  if mod and mod.save then
    mod.save:set("got_aurora_ticket_game3", true)
  end
  return true
end

local function showMsg(game, msg, done)
  local okM, Message = pcall(require, "src.ui.game3.message")
  if okM and Message and Message.show then
    Message.show(msg, done)
    return
  end
  local okBox, TextBox = pcall(require, "src.render.TextBox")
  if okBox and TextBox and game and game.stack then
    game.stack:push(TextBox.new(game, msg, done))
    return
  end
  if done then done() end
end

function EventTicketsGame3.talkResearcher(game, mod, session, done)
  session = session
    or (game and game.session)
    or (game and game.save)
    or (package.loaded["src.core.game3.runtime"]
      and package.loaded["src.core.game3.runtime"].getSession
      and package.loaded["src.core.game3.runtime"].getSession())

  if not hasFlag(session, EventTicketsGame3.FLAG_SYS_GAME_CLEAR) then
    showMsg(game, "I am researching cosmic radiation and\n"
      .. "aurora phenomena in the Sevii Islands...\n\n"
      .. "Only a certified Pokémon Champion\n"
      .. "could withstand the extreme energy of\n"
      .. "the outer islands!", done)
    return
  end

  if not EventTicketsGame3.hasAuroraTicket(session) then
    EventTicketsGame3.awardAuroraTicket(mod, session)
    showMsg(game, "Incredible! You defeated the Elite Four\n"
      .. "and entered the Hall of Fame!\n\n"
      .. "Our sensors detected a powerful cosmic\n"
      .. "anomaly at Birth Island.\n\n"
      .. "Take this AURORA TICKET and board the\n"
      .. "Seagallop ferry to investigate!", done)
    return
  end

  if not EventTicketsGame3.hasMysticTicket(session) then
    EventTicketsGame3.awardMysticTicket(mod, session)
    showMsg(game, "Remarkable progress, Champion!\n\n"
      .. "Deep subterranean readings have also\n"
      .. "surged from Navel Rock.\n\n"
      .. "Take this MYSTIC TICKET to reach the\n"
      .. "sacred perches of Ho-Oh and Lugia!", done)
    return
  end

  showMsg(game, "The triangular monument on Birth Island\n"
    .. "and the deep caverns of Navel Rock\n"
    .. "react to ancient frequencies.\n\n"
    .. "Have you unraveled their mysteries?", done)
end

function EventTicketsGame3.register(mod)
  EventTicketsGame3._mod = mod
  HouseNpcs.appendNpc(mod, EventTicketsGame3.RESEARCHER_MAP, {
    index = 89,
    localId = 89,
    name = "SEVII_ASTRONOMER",
    sprite = "SPRITE_SCIENTIST",
    graphicsId = 55,
    graphics = 55,
    movementType = 8,
    movement = "LOOK_AROUND",
    range = "DOWN",
    scriptKey = EventTicketsGame3.TEXT_ID,
    text = EventTicketsGame3.TEXT_ID,
    elevation = 3,
    x = EventTicketsGame3.RESEARCHER_POS.x,
    y = EventTicketsGame3.RESEARCHER_POS.y,
    gen3X = EventTicketsGame3.RESEARCHER_POS.x,
    gen3Y = EventTicketsGame3.RESEARCHER_POS.y,
  }, EventTicketsGame3.OWNER)

  HouseNpcs.bindTalk(mod, EventTicketsGame3.RESEARCHER_MAP, {
    [EventTicketsGame3.TEXT_ID] = function(game, ow, npc, done)
      EventTicketsGame3.talkResearcher(game, mod, nil, done)
    end,
  })
end

function EventTicketsGame3.install(mod)
  EventTicketsGame3._mod = mod
  EventTicketsGame3.register(mod)
end

return EventTicketsGame3
