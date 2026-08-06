-- One-time overworld placements for expansion held items.
-- Leftovers / Focus Band are intentionally not sold in marts.
--
-- Re-entry: every map below stays reachable after its story gate in Gen 1
-- (cities always; Rock Tunnel after route access; Tower after Lavender;
-- Power Plant after Plant Card). Flash is navigation-only, not a lockout.

local Strings = require("src.core.Strings")

local OverworldLoot = {}

OverworldLoot.BLACK_BELT_GIFT_KEY = "got_black_belt_gift"

-- Hidden items (Item Finder / face-tile). field deep-merge appends these
-- after vanilla rows (e.g. Celadon PP_UP @ 48,15 stays first).
-- Coords verified walkable via Map.defIsWalkableCell; not overlapping
-- existing objects or hidden items.
OverworldLoot.HIDDEN = {
  -- Soft path north of Celadon Mansion (warps ~24,3 / 24,9).
  { map = "CELADON_CITY", x = 20, y = 5, item = "LEFTOVERS" },
  -- Grass near Pewter Gym / Mart strip.
  { map = "PEWTER_CITY", x = 19, y = 18, item = "HARD_STONE" },
  -- Path beside Pokémon Tower entrance (warp 14,5).
  { map = "LAVENDER_TOWN", x = 15, y = 6, item = "SPELL_TAG" },
  -- Central Saffron sidewalk (south of Silph block).
  { map = "SAFFRON_CITY", x = 15, y = 14, item = "TWISTEDSPOON" },
}

-- Visible Poké Balls. index = next free slot after vanilla object count.
OverworldLoot.BALLS = {
  {
    map = "ROCK_TUNNEL_B1F",
    index = 9,
    name = "ROCKTUNNELB1F_FOCUS_BAND",
    text = "TEXT_ROCKTUNNELB1F_FOCUS_BAND",
    item = "FOCUS_BAND",
    x = 22, y = 12,
  },
  {
    map = "POKEMON_TOWER_7F",
    index = 5,
    name = "POKEMONTOWER7F_BLACKGLASSES",
    text = "TEXT_POKEMONTOWER7F_BLACKGLASSES",
    item = "BLACKGLASSES",
    x = 10, y = 15,
  },
  {
    map = "POWER_PLANT",
    index = 15,
    name = "POWERPLANT_METAL_COAT",
    text = "TEXT_POWERPLANT_METAL_COAT",
    item = "METAL_COAT",
    x = 30, y = 28,
  },
}

-- Flavor / gift NPCs (outside Fighting Dojo scripts).
OverworldLoot.NPCS = {
  {
    map = "CELADON_CITY",
    index = 10,
    name = "CELADONCITY_ITEMFINDER_HINT",
    text = "TEXT_CELADONCITY_ITEMFINDER_HINT",
    sprite = "SPRITE_GRAMPS",
    x = 22, y = 11,
    kind = "hint_leftovers",
  },
  {
    map = "LAVENDER_TOWN",
    index = 4,
    name = "LAVENDERTOWN_HOLD_HINT",
    text = "TEXT_LAVENDERTOWN_HOLD_HINT",
    sprite = "SPRITE_CHANNELER",
    x = 11, y = 14,
    kind = "hint_spell_tag",
  },
  {
    map = "SAFFRON_CITY",
    index = 16,
    name = "SAFFRONCITY_BLACK_BELT_GIFT",
    text = "TEXT_SAFFRONCITY_BLACK_BELT_GIFT",
    sprite = "SPRITE_HIKER",
    x = 25, y = 4,
    kind = "gift_black_belt",
  },
}

local function pushText(game, msg, done)
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, msg, done))
end

local function ballObject(row)
  return {
    index = row.index,
    name = row.name,
    sprite = "SPRITE_POKE_BALL",
    movement = "STAY",
    range = "NONE",
    text = row.text,
    item = row.item,
    x = row.x,
    y = row.y,
  }
end

local function npcObject(row)
  return {
    index = row.index,
    name = row.name,
    sprite = row.sprite,
    movement = "STAY",
    range = "DOWN",
    text = row.text,
    x = row.x,
    y = row.y,
  }
end

local function talkLeftoversHint(_mod)
  return function(game, _ow, _npc, done)
    pushText(game, Strings(
      "My ITEMFINDER keeps\nbeeping by the\vmansion...\f"
      .. "Something was left\nbehind in the\vgrass up there."), done)
  end
end

local function talkSpellTagHint(_mod)
  return function(game, _ow, _npc, done)
    pushText(game, Strings(
      "Ghosts hate bright\nholds. A SPELL TAG\vhelps...\f"
      .. "And berries can\nclear a bad status\vin a pinch!"), done)
  end
end

local function talkBlackBeltGift(mod)
  return function(game, _ow, _npc, done)
    if mod.save:get(OverworldLoot.BLACK_BELT_GIFT_KEY, false) then
      pushText(game, Strings(
        "Train with that\nBLACK BELT on!\f"
        .. "Fighting moves hit\nharder with it."), done)
      return
    end
    local Bag = require("src.inventory.Bag")
    if not Bag.add(game.save, "BLACK_BELT", 1) then
      pushText(game, Strings(
        "Your bag is full!\nCome back when\vyou've made room."), done)
      return
    end
    mod.save:set(OverworldLoot.BLACK_BELT_GIFT_KEY, true)
    pushText(game, Strings(
      "You look tough!\nTake this BLACK\vBELT.\f"
      .. "Give it to a\nPOKéMON to hold."), done)
  end
end

local TALK_BY_KIND = {
  hint_leftovers = talkLeftoversHint,
  hint_spell_tag = talkSpellTagHint,
  gift_black_belt = talkBlackBeltGift,
}

function OverworldLoot.register(mod)
  OverworldLoot._mod = mod

  -- Hidden items: one field patch, grouped by map.
  local hiddenByMap = {}
  for _, h in ipairs(OverworldLoot.HIDDEN) do
    local list = hiddenByMap[h.map]
    if not list then
      list = {}
      hiddenByMap[h.map] = list
    end
    list[#list + 1] = { x = h.x, y = h.y, item = h.item }
  end
  mod.content.field:patch("hiddenItems", hiddenByMap)

  -- Balls + NPCs share map patches; collect objects per map.
  local objectsByMap = {}
  local function appendObj(mapId, obj)
    local list = objectsByMap[mapId]
    if not list then
      list = {}
      objectsByMap[mapId] = list
    end
    list[#list + 1] = obj
  end

  for _, row in ipairs(OverworldLoot.BALLS) do
    appendObj(row.map, ballObject(row))
  end
  for _, row in ipairs(OverworldLoot.NPCS) do
    appendObj(row.map, npcObject(row))
  end

  for mapId, objs in pairs(objectsByMap) do
    mod.content.maps:patch(mapId, {
      objects = { __append = objs },
    })
  end

  -- Talk scripts per NPC map.
  local talksByMap = {}
  for _, row in ipairs(OverworldLoot.NPCS) do
    local talk = talksByMap[row.map]
    if not talk then
      talk = {}
      talksByMap[row.map] = talk
    end
    local maker = TALK_BY_KIND[row.kind]
    talk[row.text] = maker(mod)
  end
  for mapId, talk in pairs(talksByMap) do
    mod.content.map_scripts:register(mapId, { talk = talk })
  end
end

return OverworldLoot
