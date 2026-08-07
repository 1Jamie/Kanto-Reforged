-- Overworld held-item placements (hidden / balls / NPCs).
return function(T, Data, HeldItems, run)
  local OverworldLoot = require("mods.Kanto-Reforged.overworld_loot")
  local Map = require("src.world.Map")
  local MapScripts = require("src.script.MapScripts")

  local mod = OverworldLoot._mod
  T.check(mod ~= nil and mod.save ~= nil, "overworld loot registered with mod API")

  local function walkable(mapId, x, y)
    local def = Data.maps[mapId]
    local ts = Data.tilesets[def.tileset]
    return Map.defIsWalkableCell(def, ts, x, y)
  end

  local function findObj(mapId, name)
    for _, o in ipairs(Data.maps[mapId].objects or {}) do
      if o.name == name then return o end
    end
    return nil
  end

  local function hiddenHas(mapId, item, x, y)
    local list = Data.field.hiddenItems[mapId] or {}
    for _, h in ipairs(list) do
      if h.item == item and h.x == x and h.y == y then return true end
    end
    return false
  end

  -- Celadon deep-merge: vanilla PP_UP first, then Leftovers appended.
  local celadonHi = Data.field.hiddenItems.CELADON_CITY or {}
  T.check(#celadonHi >= 2, "Celadon has vanilla + mod hidden items")
  T.eq(celadonHi[1].item, "PP_UP", "Celadon PP_UP stays first after merge")
  T.eq(celadonHi[1].x, 48, "Celadon PP_UP x unchanged")
  T.eq(celadonHi[1].y, 15, "Celadon PP_UP y unchanged")
  local leftoversIdx
  for i, h in ipairs(celadonHi) do
    if h.item == "LEFTOVERS" then leftoversIdx = i break end
  end
  T.check(leftoversIdx ~= nil, "Celadon hidden list includes LEFTOVERS")
  T.check(leftoversIdx > 1, "LEFTOVERS is appended after vanilla PP_UP")
  T.eq(celadonHi[leftoversIdx].x, 20, "Leftovers at mansion path x")
  T.eq(celadonHi[leftoversIdx].y, 5, "Leftovers at mansion path y")
  T.check(walkable("CELADON_CITY", 20, 5), "Leftovers tile is walkable/faceable")

  T.check(hiddenHas("PEWTER_CITY", "HARD_STONE", 19, 18), "Pewter Hard Stone hidden")
  T.check(walkable("PEWTER_CITY", 19, 18), "Hard Stone tile walkable")
  T.check(hiddenHas("LAVENDER_TOWN", "SPELL_TAG", 15, 6), "Lavender Spell Tag hidden")
  T.check(walkable("LAVENDER_TOWN", 15, 6), "Spell Tag tile walkable")
  T.check(hiddenHas("SAFFRON_CITY", "TWISTEDSPOON", 15, 14), "Saffron Twistedspoon hidden")
  T.check(walkable("SAFFRON_CITY", 15, 14), "Twistedspoon tile walkable")

  local fb = findObj("ROCK_TUNNEL_B1F", "ROCKTUNNELB1F_FOCUS_BAND")
  T.check(fb ~= nil, "Focus Band ball registered")
  T.eq(fb and fb.item, "FOCUS_BAND", "Focus Band ball item id")
  T.eq(fb and fb.sprite, "SPRITE_POKE_BALL", "Focus Band uses Poké Ball sprite")
  T.check(walkable("ROCK_TUNNEL_B1F", fb.x, fb.y), "Focus Band ball walkable")

  local bg = findObj("POKEMON_TOWER_7F", "POKEMONTOWER7F_BLACKGLASSES")
  T.check(bg ~= nil, "Blackglasses ball registered")
  T.eq(bg and bg.item, "BLACKGLASSES", "Blackglasses ball item id")
  T.check(walkable("POKEMON_TOWER_7F", bg.x, bg.y), "Blackglasses ball walkable")

  local mc = findObj("POWER_PLANT", "POWERPLANT_METAL_COAT")
  T.check(mc ~= nil, "Metal Coat ball registered")
  T.eq(mc and mc.item, "METAL_COAT", "Metal Coat ball item id")
  T.check(walkable("POWER_PLANT", mc.x, mc.y), "Metal Coat ball walkable")

  local hint = findObj("CELADON_CITY", "CELADONCITY_ITEMFINDER_HINT")
  T.check(hint ~= nil, "Celadon Item Finder hint NPC present")
  T.eq(hint and hint.sprite, "SPRITE_GRAMPS", "Celadon hint uses gramps sprite")

  local lav = findObj("LAVENDER_TOWN", "LAVENDERTOWN_HOLD_HINT")
  T.check(lav ~= nil, "Lavender hold-hint NPC present")
  T.eq(lav and lav.sprite, "SPRITE_CHANNELER", "Lavender hint uses channeler")

  local gift = findObj("SAFFRON_CITY", "SAFFRONCITY_BLACK_BELT_GIFT")
  T.check(gift ~= nil, "Saffron Black Belt gift NPC present")
  T.eq(gift and gift.x, 25, "Gift NPC outside Fighting Dojo")
  T.eq(gift and gift.y, 4, "Gift NPC south of dojo door")

  local scripts = MapScripts.get("SAFFRON_CITY")
  T.check(scripts and scripts.talk and scripts.talk["TEXT_SAFFRONCITY_BLACK_BELT_GIFT"],
    "Saffron Black Belt gift talk registered")

  -- One-time Black Belt gift.
  mod.save:set(OverworldLoot.BLACK_BELT_GIFT_KEY, false)
  local bag = { inventory = {}, bagOrder = {} }
  local fakeGame = {
    save = bag,
    stack = {
      push = function(_, box)
        if box and box.onDone then box.onDone() end
      end,
    },
    data = Data,
  }
  local doneCalls = 0
  local talk = scripts.talk["TEXT_SAFFRONCITY_BLACK_BELT_GIFT"]
  talk(fakeGame, nil, nil, function() doneCalls = doneCalls + 1 end)
  T.eq(bag.inventory.BLACK_BELT, 1, "Bag received BLACK_BELT")
  T.check(mod.save:get(OverworldLoot.BLACK_BELT_GIFT_KEY, false), "Gift flag set")
  talk(fakeGame, nil, nil, function() doneCalls = doneCalls + 1 end)
  T.eq(bag.inventory.BLACK_BELT, 1, "Repeat talk does not give another Black Belt")
  T.eq(doneCalls, 2, "Both gift talks complete")

  -- Catalog ids used in loot tables (casing sanity).
  T.check(HeldItems.CATALOG.BLACKGLASSES ~= nil, "BLACKGLASSES catalog id")
  T.check(HeldItems.CATALOG.TWISTEDSPOON ~= nil, "TWISTEDSPOON catalog id")
  T.check(HeldItems.CATALOG.METAL_COAT ~= nil, "METAL_COAT catalog id")
  T.check(HeldItems.CATALOG.LEFTOVERS ~= nil, "LEFTOVERS catalog id")
  T.check(HeldItems.CATALOG.FOCUS_BAND ~= nil, "FOCUS_BAND catalog id")

  T.check(run.loader.modSave, "loader modSave available")
end
