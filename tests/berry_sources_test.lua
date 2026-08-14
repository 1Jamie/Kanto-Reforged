-- Pass A berry/mart/farm assertions. Loaded as a function so the parent
-- test file stays under LuaJIT's 200-local limit.
return function(T, Data, HeldItems, run)
  local function martHas(mapLabel, textKey, itemId)
    local entry = Data.text_pointers[mapLabel]
    local mart = entry and entry[textKey] and entry[textKey].mart
    if not mart then return false end
    for _, id in ipairs(mart) do
      if id == itemId then return true end
    end
    return false
  end

  T.check(Data.items.CHERI_BERRY ~= nil, "Cheri Berry registered")
  T.check(Data.items.CHESTO_BERRY ~= nil, "Chesto Berry registered")
  T.check(Data.items.PECHA_BERRY ~= nil, "Pecha Berry registered")
  T.check(Data.items.RAWST_BERRY ~= nil, "Rawst Berry registered")
  T.check(Data.items.ASPEAR_BERRY ~= nil, "Aspear Berry registered")
  T.check(Data.items.PERSIM_BERRY ~= nil, "Persim Berry registered")
  T.check(Data.items.LUM_BERRY ~= nil, "Lum Berry registered")

  -- Berry economy: status berries are farm/wild/loot only, not mart stock.
  T.check(not martHas("ViridianMart", "TEXT_VIRIDIANMART_CLERK", "BERRY"),
    "Viridian mart does not sell BERRY")
  T.check(not martHas("ViridianMart", "TEXT_VIRIDIANMART_CLERK", "CHERI_BERRY"),
    "Viridian mart does not sell CHERI_BERRY")
  T.check(not martHas("ViridianMart", "TEXT_VIRIDIANMART_CLERK", "LUM_BERRY"),
    "Viridian mart does not sell LUM_BERRY")
  T.check(martHas("ViridianMart", "TEXT_VIRIDIANMART_CLERK", "MIRACLE_SEED"),
    "Viridian mart sells Miracle Seed")
  T.check(martHas("PewterMart", "TEXT_PEWTERMART_CLERK", "CHARCOAL"),
    "Pewter mart sells Charcoal")
  T.check(not martHas("CeruleanMart", "TEXT_CERULEANMART_CLERK", "BERRY"),
    "Cerulean mart does not sell BERRY")
  T.check(not martHas("CeruleanMart", "TEXT_CERULEANMART_CLERK", "FOCUS_BAND"),
    "Cerulean mart does not sell Focus Band")
  T.check(not martHas("CeladonMart5F", "TEXT_CELADONMART5F_CLERK1", "FOCUS_BAND"),
    "Celadon 5F does not sell Focus Band")
  T.check(martHas("CeladonMart5F", "TEXT_CELADONMART5F_CLERK1", "MIRACLE_SEED"),
    "Celadon 5F sells type boosters")
  T.check(not martHas("CeladonMart5F", "TEXT_CELADONMART5F_CLERK1", "LEFTOVERS"),
    "Celadon 5F does not sell Leftovers")
  T.check(not martHas("CeladonMart5F", "TEXT_CELADONMART5F_CLERK2", "LEFTOVERS"),
    "Celadon vitamins clerk does not sell Leftovers")

  local BerryFarm = require("mods.Kanto-Reforged.world.berry_farm")
  T.eq(BerryFarm.GROW_STEPS, 320, "Base grow steps are 320")
  T.eq(BerryFarm.GROW_BY_RANK[3], 192, "Soil rank 3 speeds growth")

  local parTarget = {
    mon = { heldItem = "CHERI_BERRY", hp = 40, stats = { hp = 40 }, status = "PAR" },
    name = "User", isPlayer = true,
  }
  HeldItems.tryStatusBerry({ sayNext = function() end, drainNext = function() end },
    parTarget, "PAR")
  T.eq(parTarget.mon.status, nil, "Cheri cures PAR")
  T.eq(parTarget.mon.heldItem, nil, "Cheri is consumed")
  T.eq(parTarget.expLastConsumedItem, "CHERI_BERRY", "Cheri stashed for Recycle")

  local confTarget = {
    mon = { heldItem = "PERSIM_BERRY", hp = 40, stats = { hp = 40 }, status = "PSN" },
    confusedTurns = 3, name = "User", isPlayer = true,
  }
  HeldItems.tryStatusBerry({ sayNext = function() end }, confTarget, "confusion")
  T.eq(confTarget.confusedTurns, nil, "Persim clears confusedTurns")
  T.eq(confTarget.mon.status, "PSN", "Persim leaves mon.status alone")
  T.eq(confTarget.mon.heldItem, nil, "Persim is consumed")

  local wrong = {
    mon = { heldItem = "CHERI_BERRY", hp = 40, stats = { hp = 40 }, status = "BRN" },
    name = "User", isPlayer = true,
  }
  T.check(not HeldItems.tryStatusBerry({}, wrong, "BRN"), "Cheri ignores BRN")
  T.eq(wrong.mon.heldItem, "CHERI_BERRY", "Wrong status does not consume Cheri")

  local wildMon = { species = "PIDGEY" }
  HeldItems.maybeGiveWildHold(wildMon, function() return 0.0 end)
  T.check(HeldItems.isBerry(wildMon.heldItem), "0% roll gives a berry hold")
  T.eq(wildMon.item, wildMon.heldItem, "wild hold syncs mon.item for Gold")
  local wildMon2 = { species = "PIDGEY" }
  HeldItems.maybeGiveWildHold(wildMon2, function() return 0.99 end)
  T.eq(wildMon2.heldItem, nil, "high roll skips wild berry")

  T.check(Data.maps.BERRY_FARM ~= nil, "BERRY_FARM map registered")
  T.eq(Data.maps.BERRY_FARM.tileset, "OVERWORLD", "Farm uses OVERWORLD tileset")
  T.eq(#Data.maps.BERRY_FARM.warps, 2, "Farm has landing + exit warps")
  T.eq(Data.maps.BERRY_FARM.width, 19, "Farm width 19 blocks (yard + lake)")
  T.eq(Data.maps.BERRY_FARM.height, 12, "Farm height 12 blocks")
  -- Plots are plain grass (block 1) on cobble walkways — the soil-patch
  -- sprite (SPRITE_PLOT_SOIL), not the block itself, marks a cell as
  -- farmland now, so there's no dedicated flower-bed block to count.
  local farmBlocks = Data.maps.BERRY_FARM.blocks
  local cobbleBlocks, pathBlocks, treeWallBlocks = 0, 0, 0
  local hasFence, hasLedge, hasWater = false, false, false
  local hasRockTile = false
  local ROCK_TILES = { [97] = true, [98] = true, [99] = true, [24] = true, [25] = true, [31] = true }
  for _, b in ipairs(farmBlocks) do
    if b == 116 then T.check(false, "no flower-bed block 116 left in the farm") end
    if b == 85 then cobbleBlocks = cobbleBlocks + 1 end
    if b == 10 then pathBlocks = pathBlocks + 1 end
    if b == 15 then treeWallBlocks = treeWallBlocks + 1 end
    if b == 111 or b == 110 or b == 109 then hasFence = true end
    if b == 26 then hasLedge = true end
    if b == 67 then hasWater = true end
    if ROCK_TILES[b] then hasRockTile = true end
  end
  T.check(cobbleBlocks >= 20, "Farm has cobble walkways between plots")
  T.eq(pathBlocks, 0, "Farm does not use PATH between plots (invisible vs grass)")
  T.eq(hasFence, true, "Farm uses OVERWORLD fence blocks")
  T.eq(hasLedge, true, "Farm uses ledge scenery")
  T.eq(hasWater, true, "Farm has lake water on the east")
  T.eq(hasRockTile, false, "Farm shore has no rock/boulder tiles")
  T.check(treeWallBlocks >= 19 * 2, "Farm is boxed in by the plain tree wall border")
  T.eq(#Data.maps.BERRY_FARM.objects, 5,
    "Girl + fisher + soil + scholar + merchant on the farm")
  local scholar, merchant
  for _, o in ipairs(Data.maps.BERRY_FARM.objects) do
    if o.name == "BERRY_FARM_SCHOLAR" then scholar = o end
    if o.name == "BERRY_FARM_MERCHANT" then merchant = o end
  end
  T.check(scholar ~= nil, "Berry Scholar NPC present")
  T.eq(scholar and scholar.x, 4, "Scholar x on west strip")
  T.eq(scholar and scholar.y, 8, "Scholar y near plots")
  T.check(merchant ~= nil, "Berry Merchant NPC present")
  T.eq(merchant and merchant.x, 8, "Merchant x on plot path")
  T.eq(merchant and merchant.y, 14, "Merchant y on plot path")
  T.eq(#BerryFarm.SCHOLAR_ENTRIES, 8, "Scholar covers all farm berries")
  T.eq(Data.items.BERRY.price, 300, "Farm berry buy price (not ¥10 mart)")
  T.eq(Data.items.CHERI_BERRY.price, 600, "Status berry farm price")
  T.eq(Data.items.LUM_BERRY.price, 2000, "Lum farm price")

  local BerryQuests = require("mods.Kanto-Reforged.world.berry_quests")
  local Host = require("mods.Kanto-Reforged.core.host")
  T.eq(BerryQuests.UNLOCK_SEED_GIFT, 3, "Unlock gifts 3 berries per type")
  local mod = BerryFarm._mod or require("mods.Kanto-Reforged.ui.level_caps")._mod
  T.check(mod and mod.save, "berry farm has mod save")
  Host.saveSet(mod.save, "unlocked_berries", { BERRY = true })
  Host.saveSet(mod.save, "gifted_berry_seeds", {})
  local fakeGame = {
    save = {
      inventory = { BOULDERBADGE = 1, money = 10000 },
      party = {},
      pokedex = { owned = {} },
    },
    data = Data,
  }
  local newly = BerryQuests.applyBadgeUnlocks(mod, fakeGame, { gift = true })
  T.check(#newly >= 1, "Boulder unlocks Cheri")
  T.eq(fakeGame.save.inventory.CHERI_BERRY, 3, "Cheri unlock gifts 3 berries")
  local stock = BerryFarm.plantableList(mod)
  local hasCheri = false
  for _, id in ipairs(stock) do if id == "CHERI_BERRY" then hasCheri = true end end
  T.check(hasCheri, "Cheri is plantable/buyable after unlock")
  -- Second gift pass must not duplicate
  BerryQuests.applyBadgeUnlocks(mod, fakeGame, { gift = true })
  T.eq(fakeGame.save.inventory.CHERI_BERRY, 3, "unlock berry gift is one-shot")

  -- Host-local badge tracks: Gen1 = Kanto inventory badges only;
  -- Gen2 = Johto player.badges only (never kantoBadges rematches).
  do
    local rows1 = BerryQuests.unlockRows()
    T.eq(rows1[1].badge, "BOULDERBADGE", "Gen1 unlock row starts at Boulder")
    for _, row in ipairs(rows1) do
      T.check(tostring(row.badge):find("BADGE", 1, true) ~= nil,
        "Gen1 unlock badges are *BADGE inventory ids (" .. tostring(row.badge) .. ")")
    end
    T.eq(BerryQuests.blenderBadgeId(), "RAINBOWBADGE", "Gen1 blender wants Rainbow")

    Host.force(2)
    local rows2 = BerryQuests.unlockRows()
    T.eq(rows2[1].badge, "ZEPHYR", "Gen2 unlock row starts at Zephyr")
    for _, row in ipairs(rows2) do
      T.check(tostring(row.badge):find("BADGE", 1, true) == nil,
        "Gen2 unlock badges are Johto short names (" .. tostring(row.badge) .. ")")
      T.check(row.badge ~= "BOULDER" and row.badge ~= "BOULDERBADGE",
        "Gen2 rows never include Kanto Boulder")
    end
    T.eq(BerryQuests.blenderBadgeId(), "FOG", "Gen2 blender wants Fog")

    Host.saveSet(mod.save, "unlocked_berries", { BERRY = true })
    Host.saveSet(mod.save, "gifted_berry_seeds", {})
    -- Gold save with only a Kanto rematch badge must NOT unlock farm berries.
    local goldKantoOnly = {
      save = {
        inventory = {},
        player = {
          badges = {},
          kantoBadges = { BOULDER = true, CASCADE = true, RAINBOW = true },
          money = 10000,
        },
        party = {},
        pokedex = { caught = {} },
      },
      data = Data,
    }
    local goldNewly = BerryQuests.applyBadgeUnlocks(mod, goldKantoOnly, { gift = true })
    T.eq(#goldNewly, 0, "Gold kantoBadges alone unlock no farm berries")
    T.eq(goldKantoOnly.save.inventory.CHERI_BERRY, nil,
      "no Cheri gift from Kanto rematch badges on Gold")

    -- Johto Zephyr unlocks Cheri on Gold.
    goldKantoOnly.save.player.badges.ZEPHYR = true
    goldNewly = BerryQuests.applyBadgeUnlocks(mod, goldKantoOnly, { gift = true })
    T.check(#goldNewly >= 1, "Zephyr unlocks Cheri on Gold")
    T.eq(goldKantoOnly.save.inventory.CHERI_BERRY, 3, "Zephyr gifts 3 Cheri")

    Host.clearForce()
    -- After leaving Gen2 force, Gen1 rows return.
    T.eq(BerryQuests.unlockRows()[1].badge, "BOULDERBADGE",
      "unlockRows returns to Kanto after Host.clearForce")
  end

  -- Host-prefixed mod.save: Red progress must not bleed into Gold keys.
  do
    local iso = {}
    local isoSave = {
      get = function(_, key, default)
        if iso[key] == nil then return default end
        return iso[key]
      end,
      set = function(_, key, value) iso[key] = value end,
    }
    Host.clearForce()
    Host.saveSet(isoSave, "unlocked_berries", { BERRY = true, CHERI_BERRY = true })
    T.check(iso[Host.saveKey("unlocked_berries")] ~= nil, "Gen1 unlock writes g1: key")
    Host.force(2)
    T.eq(Host.saveGet(isoSave, "unlocked_berries", nil), nil,
      "Gen2 read does not see Gen1 unlock table")
    Host.saveSet(isoSave, "unlocked_berries", { BERRY = true })
    T.check(iso["g2:unlocked_berries"] ~= nil, "Gen2 unlock writes g2: key")
    Host.clearForce()
    local g1 = Host.saveGet(isoSave, "unlocked_berries", nil)
    T.check(g1 and g1.CHERI_BERRY, "Gen1 unlock table survives Gen2 writes")
  end

  -- map.entered unlock must not require ev.game (engines never send it).
  do
    Host.saveSet(mod.save, "unlocked_berries", { BERRY = true })
    local prevGame = package.loaded["src.core.Game"]
    package.loaded["src.core.Game"] = {
      save = { inventory = { BOULDERBADGE = 1 } },
    }
    -- Same resolve path berry_quests' map.entered listener uses.
    local game = package.loaded["src.core.Game"] or rawget(_G, "Game")
    BerryQuests.applyBadgeUnlocks(mod, game)
    local unlocked = Host.saveGet(mod.save, "unlocked_berries", {})
    T.check(unlocked.CHERI_BERRY == true,
      "map.entered unlock resolves Game without ev.game")
    package.loaded["src.core.Game"] = prevGame
  end

  T.eq(Data.maps.BERRY_FARM.borderBlock, 15, "Farm border block is the tree wall")
  -- North and south rows fully close the map (yard + lake)
  for x = 0, 18 do
    T.eq(farmBlocks[x + 1], 15, "north wall at col " .. x)
  end
  for x = 9, 18 do
    T.eq(farmBlocks[11 * 19 + x + 1], 15, "south wall closes the lake at col " .. x)
  end
  -- West strip (col 1) is grass on every interior row — no cobble/sand striping
  for y = 1, 10 do
    T.eq(farmBlocks[y * 19 + 2], 1, "west strip grass at row " .. y)
  end
  -- South border has no stray cobble squares — col 1 is grass, col 8 fence-capped
  T.eq(farmBlocks[11 * 19 + 2], 1, "south row col 1 is grass, not cobble")
  T.eq(farmBlocks[11 * 19 + 9], 109, "south row col 8 closes with the fence cap")
  -- Single-block gaps: plot columns are 2 apart (F C F), not 3 (F C C F).
  -- Plot columns are now plain grass (block 1) like everything else — the
  -- soil-patch sprite is what marks them, so this only checks the cobble
  -- gap spacing survived the flower-bed removal.
  local row6 = {}
  for x = 0, 18 do row6[x + 1] = farmBlocks[6 * 19 + x + 1] end
  T.eq(row6[4], 1, "plot col 3 is grass")
  T.eq(row6[5], 85, "single cobble between plot cols")
  T.eq(row6[6], 1, "next plot immediately after one cobble is grass")
  T.eq(row6[10], 1, "grass shore")
  T.eq(row6[12], 67, "open water")
  T.eq(row6[19], 15, "tree wall closes the east edge")
  T.check((farmBlocks[11 * 19] or farmBlocks[#farmBlocks - 5]) ~= 11,
    "Farm is not filled with tall grass")
  T.eq(Data.encounters and Data.encounters.BERRY_FARM, nil, "No wild encounters on berry farm")
  -- Exit is shed door north of landing (player walks up into it)
  T.eq(BerryFarm.EXIT.y, BerryFarm.LANDING.y - 1, "Exit door is north of landing")
  T.eq(#(Data.maps.BERRY_FARM.signs or {}), 0, "No signs; girl explains the farm")
  T.eq(#BerryFarm.PLOT_RECTS, 9, "Nine plot rects for any-facing interact")
  T.eq(BerryFarm.EXIT.y < 8, true, "Shed is in the north half of the farm")

  for _, mapId in ipairs(BerryFarm.ALL_POKECENTERS) do
    local m = Data.maps[mapId]
    T.check(m ~= nil, mapId .. " exists")
    T.eq(#m.warps, 4, mapId .. " has 4 warps after append")
    T.eq(m.warps[1].destMap, "LAST_MAP", mapId .. " warp#1 still LAST_MAP")
    T.eq(m.warps[2].destMap, "LAST_MAP", mapId .. " warp#2 still LAST_MAP")
    T.eq(m.warps[3].destMap, "BERRY_FARM", mapId .. " warp#3 goes to farm")
    T.eq(m.warps[4].destMap, "BERRY_FARM", mapId .. " warp#4 goes to farm")
    T.eq(m.warps[3].x, BerryFarm.PC_DOOR.x, mapId .. " farm mat left x")
    T.eq(m.warps[3].y, BerryFarm.PC_DOOR.y, mapId .. " farm mat left y")
    T.eq(m.warps[4].x, BerryFarm.PC_DOOR_B.x, mapId .. " farm mat right x")
    T.eq(m.warps[4].y, BerryFarm.PC_DOOR_B.y, mapId .. " farm mat right y")
    -- Bottom-right blocks are the same exit-mat pair as the outdoor door
    T.eq(m.blocks[3 * 7 + 4 + 1], 10, mapId .. " farm mat block 10")
    T.eq(m.blocks[3 * 7 + 5 + 1], 11, mapId .. " farm mat block 11")
  end

  local farmBucket = {}
  local fakeMod = {
    save = {
      get = function(_, key, default)
        if farmBucket[key] == nil then return default end
        return farmBucket[key]
      end,
      set = function(_, key, value) farmBucket[key] = value end,
    },
  }
  Host.saveSet(fakeMod.save, "farmSteps", 0)
  Host.saveSet(fakeMod.save, "plots", {
    [2] = { berryId = "CHERI_BERRY", plantedAtSteps = 0 },
  })
  T.check(not BerryFarm.plotReady(fakeMod, 2), "fresh plant not ready")
  T.eq(BerryFarm.plotMarkerSprite(fakeMod, 2), "SPRITE_PLOT_GROWING",
    "freshly planted plot shows the shared growing sprite")
  Host.saveSet(fakeMod.save, "farmSteps", math.floor(BerryFarm.GROW_STEPS * 0.75))
  T.eq(BerryFarm.plotMarkerSprite(fakeMod, 2), "SPRITE_PLOT_GROWING",
    "still-growing plot keeps showing the growing sprite")
  Host.saveSet(fakeMod.save, "farmSteps", BerryFarm.GROW_STEPS)
  T.check(BerryFarm.plotReady(fakeMod, 2), "plant ready after GROW_STEPS")
  T.eq(BerryFarm.plotMarkerSprite(fakeMod, 2), "SPRITE_PLOT_CHERI",
    "ripe Cheri plot shows the Cheri-specific sprite")
  T.eq(BerryFarm.plotMarkerSprite(fakeMod, 1), "SPRITE_PLOT_SOIL",
    "empty plot shows the soil-patch sprite")

  -- Every plot sprite (soil, growing, and each ripe berry) is registered
  -- with a real 16x16 field-object image
  for _, spriteId in ipairs({
    BerryFarm.PLOT_SPRITE_SOIL, BerryFarm.PLOT_SPRITE_GROWING,
    BerryFarm.PLOT_SPRITE_BY_BERRY.BERRY, BerryFarm.PLOT_SPRITE_BY_BERRY.CHERI_BERRY,
    BerryFarm.PLOT_SPRITE_BY_BERRY.CHESTO_BERRY,
    BerryFarm.PLOT_SPRITE_BY_BERRY.PECHA_BERRY, BerryFarm.PLOT_SPRITE_BY_BERRY.RAWST_BERRY,
    BerryFarm.PLOT_SPRITE_BY_BERRY.ASPEAR_BERRY, BerryFarm.PLOT_SPRITE_BY_BERRY.PERSIM_BERRY,
    BerryFarm.PLOT_SPRITE_BY_BERRY.LUM_BERRY,
  }) do
    local def = Data.sprites[spriteId]
    T.check(def ~= nil, spriteId .. " is registered")
    T.eq(def and def.frames, 1, spriteId .. " is a single static frame")
    T.eq(def and def.walker, false, spriteId .. " is not a walker sprite")
  end

  -- No auto-seed: missing plots stay empty (all 9 independent slots)
  local emptyBucket = {}
  local emptyMod = {
    save = {
      get = function(_, key, default)
        if emptyBucket[key] == nil then return default end
        return emptyBucket[key]
      end,
      set = function(_, key, value) emptyBucket[key] = value end,
    },
  }
  BerryFarm.farmSteps(emptyMod)
  local emptyPlots = Host.saveGet(emptyMod.save, "plots", nil)
  T.check(emptyPlots ~= nil, "plots table initialized")
  T.eq(emptyPlots["1"], nil, "plot 1 is not auto-planted")
  T.eq(emptyPlots[1], nil, "plot 1 numeric key also empty")
  T.check(not BerryFarm.plotReady(emptyMod, 1), "empty plot 1 not ready")

  -- Independence: planting/clearing one slot must not touch another
  Host.saveSet(emptyMod.save, "farmSteps", BerryFarm.GROW_STEPS + 10)
  Host.saveSet(emptyMod.save, "plots", {
    ["2"] = { berryId = "CHERI_BERRY", plantedAtSteps = BerryFarm.GROW_STEPS + 10 },
    ["5"] = { berryId = "PECHA_BERRY", plantedAtSteps = 0 },
  })
  T.check(not BerryFarm.plotReady(emptyMod, 2), "plot 2 still growing")
  T.check(BerryFarm.plotReady(emptyMod, 5), "plot 5 ready (older plant)")
  -- clear plot 2 via write path
  local livePlots = Host.saveGet(emptyMod.save, "plots", {})
  livePlots["2"] = nil
  Host.saveSet(emptyMod.save, "plots", livePlots)
  T.check(not BerryFarm.plotReady(emptyMod, 2), "cleared plot 2 stays empty")
  T.check(BerryFarm.plotReady(emptyMod, 5), "plot 5 untouched after clearing 2")
  -- ensureState must not resurrect a free berry into plot 1
  BerryFarm.farmSteps(emptyMod)
  T.check(not BerryFarm.plotReady(emptyMod, 1), "ensureState does not reseed plot 1")
  T.check(BerryFarm.plotReady(emptyMod, 5), "plot 5 still ready after ensureState")

  local Warp = require("src.world.Warp")
  run.loader.modSave["Kanto-Reforged"] = run.loader.modSave["Kanto-Reforged"] or {}
  run.loader.modSave["Kanto-Reforged"][Host.saveKey("returnCenter")] = {
    map = "PEWTER_POKECENTER", x = 9, y = 7,
  }
  local exitWarp = {
    x = BerryFarm.EXIT.x, y = BerryFarm.EXIT.y,
    destMap = "VIRIDIAN_POKECENTER", destWarp = 1,
  }
  local retMap, retX, retY = Warp.destination(Data, exitWarp, nil)
  T.eq(retMap, "PEWTER_POKECENTER", "farm exit returns to saved center")
  T.eq(retX, BerryFarm.RETURN_CELL.x, "farm exit lands on farm mat x")
  T.eq(retY, BerryFarm.RETURN_CELL.y, "farm exit lands on farm mat y")
  T.eq(BerryFarm.RETURN_CELL.x, BerryFarm.PC_DOOR.x, "return cell is farm mat")
  T.eq(BerryFarm.RETURN_CELL.y, BerryFarm.PC_DOOR.y, "return cell is farm mat y")

  -- Route 22 door into the badge-check gate is also (8,5); must not hijack.
  local route22Door = Data.maps.ROUTE_22.warps[1]
  T.eq(route22Door.x, BerryFarm.EXIT.x, "Route 22 gate door shares farm EXIT x")
  T.eq(route22Door.y, BerryFarm.EXIT.y, "Route 22 gate door shares farm EXIT y")
  T.eq(route22Door.destMap, "ROUTE_22_GATE", "Route 22 door targets gate")
  local gateMap, gateX, gateY = Warp.destination(Data, route22Door, nil)
  T.eq(gateMap, "ROUTE_22_GATE", "Route 22 gate door not redirected to returnCenter")
  T.check(gateX ~= nil and gateY ~= nil, "Route 22 gate door still has coords")

  -- Farm is OVERWORLD but must not become lastOutdoor (PC LAST_MAP bug)
  local OverworldState = require("src.world.OverworldController")
  local fakeOw = {
    lastOutdoor = { id = "VIRIDIAN_CITY", x = 23, y = 25 },
  }
  local Game = package.loaded["src.core.Game"]
  local prevSave = Game and Game.save
  if not Game then
    package.loaded["src.core.Game"] = { save = {} }
    Game = package.loaded["src.core.Game"]
  end
  Game.save = Game.save or {}
  Game.save.lastOutdoor = { id = "VIRIDIAN_CITY", x = 23, y = 25 }
  OverworldState.rememberOutdoor(fakeOw, "BERRY_FARM", 8, 6)
  T.eq(fakeOw.lastOutdoor.id, "VIRIDIAN_CITY",
    "rememberOutdoor ignores BERRY_FARM (keeps town)")
  T.eq(Game.save.lastOutdoor.id, "VIRIDIAN_CITY",
    "save.lastOutdoor stays the town after farm leave")

  -- Poisoned LAST_MAP → farm is repaired via savedOutdoor
  run.loader.modSave["Kanto-Reforged"].savedOutdoor = {
    id = "VIRIDIAN_CITY", x = 23, y = 25,
  }
  local pcExit = Data.maps.VIRIDIAN_POKECENTER.warps[1]
  T.eq(pcExit.destMap, "LAST_MAP", "PC exit is LAST_MAP")
  local poisoned = { id = "BERRY_FARM", x = 8, y = 6 }
  local fixMap, fixX, fixY = Warp.destination(Data, pcExit, poisoned)
  T.eq(fixMap, "VIRIDIAN_CITY", "poisoned LAST_MAP to farm redirects to town")
  local townDoor = Data.maps.VIRIDIAN_CITY.warps[pcExit.destWarp]
  T.eq(fixX, townDoor.x, "repaired LAST_MAP uses town door x")
  T.eq(fixY, townDoor.y, "repaired LAST_MAP uses town door y")

  if prevSave ~= nil then
    Game.save = prevSave
  end
end
