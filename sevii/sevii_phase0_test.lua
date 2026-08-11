-- Sevii Phase 0: maps, ferry NPC, outdoor blacklist, imported wild shape.
return function(T, Data, run)
  local SeviiMaps = require("mods.Kanto-Reforged.sevii.maps")
  local OverworldState = require("src.world.OverworldController")

  T.eq(Data.maps.SEVII_ONE_ISLAND.index, 1200, "One Island index 1200")
  T.eq(Data.maps.SEVII_ONE_ISLAND_HARBOR.index, 1201, "Harbor index 1201")
  T.eq(Data.maps.SEVII_ONE_ISLAND_POKECENTER.index, 1202, "PC index 1202")
  T.eq(Data.maps.SEVII_ONE_ISLAND_MART.index, 1203, "Mart index 1203")
  T.eq(Data.maps.SEVII_ONE_ISLAND_KINDLE_ROAD.index, 1204, "Kindle Road index 1204")
  T.eq(Data.maps.SEVII_ONE_ISLAND_TREASURE_BEACH.index, 1205, "Treasure Beach index 1205")

  T.eq(Data.maps.SEVII_ONE_ISLAND.tileset, "OVERWORLD", "town OVERWORLD")
  T.eq(Data.maps.SEVII_ONE_ISLAND_HARBOR.tileset, "OVERWORLD", "harbor OVERWORLD pier")
  T.eq(Data.maps.SEVII_ONE_ISLAND_KINDLE_ROAD.tileset, "OVERWORLD", "Kindle OVERWORLD")
  T.eq(Data.maps.SEVII_ONE_ISLAND_TREASURE_BEACH.tileset, "OVERWORLD", "Treasure OVERWORLD")
  local harborSailor
  for _, o in ipairs(Data.maps.SEVII_ONE_ISLAND_HARBOR.objects or {}) do
    if o.name == "SEVII_HARBOR_SAILOR" then harborSailor = o break end
  end
  T.check(harborSailor ~= nil, "harbor sailor present")
  T.check(harborSailor.x ~= 8 or harborSailor.y ~= 6,
    "ferry landing is not on top of harbor sailor")
  T.eq(Data.maps.SEVII_ONE_ISLAND_POKECENTER.tileset, "POKECENTER", "PC tileset")
  T.eq(Data.maps.SEVII_ONE_ISLAND_MART.tileset, "MART", "Mart tileset")

  -- Island 1 graph: town ↔ Kindle / Treasure
  local town = Data.maps.SEVII_ONE_ISLAND
  T.check(town.connections and town.connections.east
    and town.connections.east.map == "SEVII_ONE_ISLAND_KINDLE_ROAD",
    "town east → Kindle Road")
  T.check(town.connections and town.connections.south
    and town.connections.south.map == "SEVII_ONE_ISLAND_TREASURE_BEACH",
    "town south → Treasure Beach")
  T.check(Data.maps.SEVII_ONE_ISLAND_KINDLE_ROAD.connections
    and Data.maps.SEVII_ONE_ISLAND_KINDLE_ROAD.connections.west
    and Data.maps.SEVII_ONE_ISLAND_KINDLE_ROAD.connections.west.map == "SEVII_ONE_ISLAND",
    "Kindle west → town")
  T.check(Data.maps.SEVII_ONE_ISLAND_TREASURE_BEACH.connections
    and Data.maps.SEVII_ONE_ISLAND_TREASURE_BEACH.connections.north
    and Data.maps.SEVII_ONE_ISLAND_TREASURE_BEACH.connections.north.map == "SEVII_ONE_ISLAND",
    "Treasure north → town")

  -- Static warps only (x/y + destMap/destWarp)
  local function checkWarps(mapId)
    for _, w in ipairs(Data.maps[mapId].warps or {}) do
      T.check(type(w.x) == "number" and type(w.y) == "number", mapId .. " warp has x/y")
      T.check(type(w.destMap) == "string", mapId .. " warp destMap")
      T.check(type(w.destWarp) == "number", mapId .. " warp destWarp")
    end
  end
  checkWarps("SEVII_ONE_ISLAND")
  checkWarps("SEVII_ONE_ISLAND_HARBOR")
  checkWarps("SEVII_ONE_ISLAND_POKECENTER")
  checkWarps("SEVII_ONE_ISLAND_MART")
  checkWarps("SEVII_ONE_ISLAND_KINDLE_ROAD")
  checkWarps("SEVII_ONE_ISLAND_TREASURE_BEACH")

  -- Ferry uses Vermilion City gangway sailor + Rainbow Pass (no extra dock NPC)
  T.check(Data.items.RAINBOW_PASS ~= nil, "RAINBOW_PASS key item registered")
  local MapScripts = require("src.script.MapScripts")
  local city = MapScripts.get("VERMILION_CITY")
  T.check(city and city.talk and city.talk.TEXT_VERMILIONCITY_SAILOR1 ~= nil,
    "Sevii hooks gangway sailor talk")
  T.check(city and type(city.onStep) == "function",
    "Sevii hooks Vermilion onStep")

  -- rememberOutdoor blacklist
  local fakeOw = { lastOutdoor = { id = "VERMILION_CITY", x = 1, y = 1 } }
  local Game = package.loaded["src.core.Game"]
  if not Game then
    package.loaded["src.core.Game"] = { save = {} }
    Game = package.loaded["src.core.Game"]
  end
  Game.save = Game.save or {}
  Game.save.lastOutdoor = { id = "VERMILION_CITY", x = 1, y = 1 }
  OverworldState.rememberOutdoor(fakeOw, "SEVII_ONE_ISLAND", 8, 6)
  T.eq(fakeOw.lastOutdoor.id, "VERMILION_CITY",
    "rememberOutdoor ignores SEVII_ONE_ISLAND")
  OverworldState.rememberOutdoor(fakeOw, "SEVII_ONE_ISLAND_HARBOR", 9, 3)
  T.eq(fakeOw.lastOutdoor.id, "VERMILION_CITY",
    "rememberOutdoor ignores SEVII harbor")
  OverworldState.rememberOutdoor(fakeOw, "SEVII_ONE_ISLAND_KINDLE_ROAD", 6, 6)
  T.eq(fakeOw.lastOutdoor.id, "VERMILION_CITY",
    "rememberOutdoor ignores Kindle Road")
  OverworldState.rememberOutdoor(fakeOw, "SEVII_ONE_ISLAND_TREASURE_BEACH", 8, 4)
  T.eq(fakeOw.lastOutdoor.id, "VERMILION_CITY",
    "rememberOutdoor ignores Treasure Beach")

  -- Imported encounters: Kindle + Treasure grass/water length 10
  local EncData = require("mods.Kanto-Reforged.sevii.encounters_data")
  local kindle = EncData.maps.SEVII_ONE_ISLAND_KINDLE_ROAD
  T.check(kindle ~= nil, "Kindle Road in encounters_data")
  if kindle.grass then
    T.eq(#kindle.grass.slots, 10, "Kindle grass is 10 slots")
  end
  if kindle.water then
    T.eq(#kindle.water.slots, 10, "Kindle water is 10 slots")
  end
  local beach = EncData.maps.SEVII_ONE_ISLAND_TREASURE_BEACH
  T.check(beach ~= nil, "Treasure Beach in encounters_data")
  if beach.grass then
    T.eq(#beach.grass.slots, 10, "Treasure grass is 10 slots")
  end
  if beach.water then
    T.eq(#beach.water.slots, 10, "Treasure water is 10 slots")
  end
  -- Registered into live Data when Sevii boot ran
  if Data.encounters then
    T.check(Data.encounters.SEVII_ONE_ISLAND_KINDLE_ROAD ~= nil,
      "Kindle encounters registered")
    T.check(Data.encounters.SEVII_ONE_ISLAND_TREASURE_BEACH ~= nil,
      "Treasure encounters registered")
  end

  local report = io.open("mods/Kanto-Reforged/sevii/import_report.json", "r")
  T.check(report ~= nil, "import_report.json exists")
  if report then
    local rj = report:read("*a")
    report:close()
    T.check(rj:find("padding", 1, true) ~= nil, "import_report notes padding drops")
  end

  T.check(SeviiMaps.OUTDOOR.SEVII_ONE_ISLAND == true, "town marked outdoor")
  T.check(SeviiMaps.OUTDOOR.SEVII_ONE_ISLAND_KINDLE_ROAD == true, "Kindle outdoor")
  T.check(SeviiMaps.OUTDOOR.SEVII_ONE_ISLAND_TREASURE_BEACH == true, "Treasure outdoor")
  T.check(SeviiMaps.INDEX.SEVII_ONE_ISLAND == 1200, "index table")
  T.check(SeviiMaps.INDEX.SEVII_ONE_ISLAND_KINDLE_ROAD == 1204, "Kindle index table")

  -- Layouts are FRLG-derived (1:1 cell coverage via layout_data.lua)
  local Layout = require("mods.Kanto-Reforged.sevii.layout_data")
  T.eq(Data.maps.SEVII_ONE_ISLAND.width, Layout.SEVII_ONE_ISLAND.width, "town width from layout")
  T.eq(Data.maps.SEVII_ONE_ISLAND.height, Layout.SEVII_ONE_ISLAND.height, "town height from layout")
  T.eq(#Data.maps.SEVII_ONE_ISLAND.blocks, Layout.SEVII_ONE_ISLAND.width * Layout.SEVII_ONE_ISLAND.height,
    "town block count")
  -- Town must not paint tall grass (wilds only via water / routes)
  local tall = 0
  for _, b in ipairs(Data.maps.SEVII_ONE_ISLAND.blocks) do
    if b == 11 then tall = tall + 1 end
  end
  T.eq(tall, 0, "One Island town has no tall-grass blocks")
  -- Gen1 PC/Mart exteriors present (not residential roofs alone)
  local hasPc, hasMart = false, false
  for _, b in ipairs(Data.maps.SEVII_ONE_ISLAND.blocks) do
    if b == 114 then hasPc = true end
    if b == 115 then hasMart = true end
  end
  T.check(hasPc, "town has PC exterior (block 114)")
  T.check(hasMart, "town has Mart exterior (block 115)")

  -- Indoor-encounter suppress: Sevii indices ≥37 would otherwise wild on every tile
  T.check(Data.maps.SEVII_ONE_ISLAND_KINDLE_ROAD.index >= 37, "Kindle index in indoor range")
  local rolled = false
  -- Simulate hook if install ran: call encounter.roll wrap via requiring maps install side effect
  -- Direct check of OUTDOOR table used by the hook
  T.check(SeviiMaps.OUTDOOR.SEVII_ONE_ISLAND_KINDLE_ROAD == true,
    "Kindle flagged outdoor for indoor-enc suppress")
end
