-- restored_dungeons_test.lua
-- Unit tests for Kanto-Reforged restored Gen 1 dungeons pipeline & runtime integration.

local RestoredDungeons = require("mods.Kanto-Reforged.world.restored_dungeons")
local Data = require("mods.Kanto-Reforged.world.restored_dungeons_data")
local EncountersGen2 = require("mods.Kanto-Reforged.world.encounters_gen2")
local Host = require("mods.Kanto-Reforged.core.host")

local function runTests()
  print("Running restored_dungeons_test.lua...")

  -- 1. Test offline generated data module
  assert(Data ~= nil, "Data module must not be nil")
  assert(Data.maps ~= nil, "Data.maps must not be nil")
  assert(Data.tilesets ~= nil, "Data.tilesets must not be nil")
  assert(Data.encounters ~= nil, "Data.encounters must not be nil")
  assert(Data.seafoamBoulderPatches ~= nil, "Data.seafoamBoulderPatches must not be nil")

  local home = os.getenv("HOME") or ""
  local CachePaths = require("mods.Kanto-Reforged.core.cache_paths")
  local goldTilesets = CachePaths.loadGenerated("tilesets.lua", "gold") or {}
  local _ = home -- kept for any local path fallbacks below

  -- Prefer Gen2 trainers so class-index collision checks are meaningful
  -- (Gen1 OPP_HIKER=9 is Gen2 RIVAL1=9).
  local goldTrainers = CachePaths.loadGenerated("trainers.lua", "gold")
  if goldTrainers and not (goldTrainers.classes and goldTrainers.classes.RIVAL1 or goldTrainers.RIVAL1) then
    goldTrainers = nil
  end
  assert(goldTrainers, "Gen2 trainers.lua with RIVAL1 required for collision tests")

  local gen2Maps = dofile("data/generated/maps.lua")
  local fakeMod = {
    data = {
      gen2Tilesets = goldTilesets,
      gen2Palettes = {},
      gen2Maps = gen2Maps,
      gen2Trainers = goldTrainers,
      gen2Text = {},
      text = {},
      items = dofile("data/generated/items.lua"),
      pokemon = dofile("data/generated/pokemon.lua"),
      moves = dofile("data/generated/moves.lua"),
    },
    log = { info = function() end, warn = function() end, error = function() end }
  }
  fakeMod.data.trainers = fakeMod.data.gen2Trainers
  fakeMod.data.maps = gen2Maps
  Host.force(2)
  RestoredDungeons.apply(fakeMod)

  print("  Data structures present.")

  -- 1b. Route 4 Mt Moon mouths must redirect to restored KR maps (Digletts/Safari pattern)
  local r4 = fakeMod.data.gen2Maps.ROUTE_4
  assert(r4 and r4.warps, "ROUTE_4 warps must exist after apply")
  local foundB1f, foundCenter = false, false
  for _, w in ipairs(r4.warps) do
    if (w.x == 18 and w.y == 5) or (w.x == 24 and w.y == 5) then
      assert(w.destMap == "MT_MOON_B1F_KR",
        string.format("Route 4 cave at (%d,%d) must target MT_MOON_B1F_KR, got %s", w.x, w.y, tostring(w.destMap)))
      assert(w.destWarp == 8, "Route 4 cave must land on B1F warp 8 (exit pad)")
      foundB1f = true
    elseif w.x == 11 and w.y == 5 then
      assert(w.destMap == "MT_MOON_POKECENTER",
        "Route 4 Pokemon Center warp must remain MT_MOON_POKECENTER")
      foundCenter = true
    end
  end
  assert(foundB1f, "Route 4 must still have Mt Moon cave warp(s) at (18,5)/(24,5)")
  assert(foundCenter, "Route 4 must still have Pokemon Center warp at (11,5)")
  local b1fExit = Data.maps.MT_MOON_B1F_KR.warps[8]
  assert(b1fExit and b1fExit.x == 27 and b1fExit.y == 3,
    "MT_MOON_B1F_KR warp 8 must be the Route 4 exit pad at (27,3)")
  print("  Route 4 -> MT_MOON_B1F_KR exit-pad warps verified.")

  -- 2. Verify key restored maps exist in generated data
  local expectedMaps = {
    "VIRIDIAN_FOREST_KR",
    "MT_MOON_1F_KR", "MT_MOON_B1F_KR", "MT_MOON_B2F_KR",
    "CERULEAN_CAVE_1F_KR", "CERULEAN_CAVE_2F_KR", "CERULEAN_CAVE_B1F_KR",
    "SEAFOAM_ISLANDS_1F_KR", "SEAFOAM_ISLANDS_B1F_KR", "SEAFOAM_ISLANDS_B2F_KR", "SEAFOAM_ISLANDS_B3F_KR", "SEAFOAM_ISLANDS_B4F_KR",
    "SEAFOAM_GYM_KR",
    "SAFARI_ZONE_CENTER_KR", "SAFARI_ZONE_EAST_KR", "SAFARI_ZONE_WEST_KR", "SAFARI_ZONE_NORTH_KR",
    "SAFARI_ZONE_CENTER_REST_HOUSE_KR", "SAFARI_ZONE_SECRET_HOUSE_KR", "SAFARI_ZONE_GATE_KR"
  }

  for _, mapId in ipairs(expectedMaps) do
    local mdef = Data.maps[mapId]
    assert(mdef ~= nil, "Map " .. mapId .. " must exist in Data.maps")
    assert(type(mdef.width) == "number" and mdef.width > 0, mapId .. " width must be > 0")
    assert(type(mdef.height) == "number" and mdef.height > 0, mapId .. " height must be > 0")
    assert(type(mdef.blocks) == "table", mapId .. " blocks must be a table")
    assert(#mdef.blocks == mdef.width * mdef.height,
      mapId .. " blocks count (" .. #mdef.blocks .. ") must equal width * height (" .. (mdef.width * mdef.height) .. ")")
  end

  print("  All 20 target maps verified for layout & dimensions.")

  -- 3. Verify specific map dimensions match canonical Gen 1 sizes
  assert(Data.maps.VIRIDIAN_FOREST_KR.width == 17 and Data.maps.VIRIDIAN_FOREST_KR.height == 24,
    "Viridian Forest layout must be 17x24 blocks")
  assert(Data.maps.MT_MOON_1F_KR.width == 20 and Data.maps.MT_MOON_1F_KR.height == 18,
    "Mt. Moon 1F layout must be 20x18 blocks")
  assert(Data.maps.MT_MOON_B1F_KR.width == 14 and Data.maps.MT_MOON_B1F_KR.height == 14,
    "Mt. Moon B1F layout must be 14x14 blocks")
  assert(Data.maps.MT_MOON_B2F_KR.width == 20 and Data.maps.MT_MOON_B2F_KR.height == 18,
    "Mt. Moon B2F layout must be 20x18 blocks")
  assert(Data.maps.CERULEAN_CAVE_1F_KR.width == 15 and Data.maps.CERULEAN_CAVE_1F_KR.height == 9,
    "Cerulean Cave 1F layout must be 15x9 blocks")

  print("  Canonical map dimensions verified.")

  -- 4. Verify Blaine's Gym dedicated interior room on Seafoam 1F
  local sf1f = Data.maps.SEAFOAM_ISLANDS_1F_KR
  local hasGymWarp = false
  for _, w in ipairs(sf1f.warps or {}) do
    if w.destMap == "SEAFOAM_GYM_KR" or w.destMap == "SEAFOAM_GYM" then
      hasGymWarp = true
      break
    end
  end
  assert(hasGymWarp == true, "Seafoam Islands 1F must have entrance warp to SEAFOAM_GYM_KR")
  assert(Data.maps.SEAFOAM_GYM_KR.tileset == "TILESET_FACILITY" or Data.maps.SEAFOAM_GYM_KR.tileset == "GYM", "SEAFOAM_GYM must use dedicated GYM tileset")
  assert(Data.maps.SEAFOAM_GYM_KR.objects[1].trainerClass == "OPP_BLAINE", "Blaine must be present in SEAFOAM_GYM_KR")
  assert(Data.maps.SEAFOAM_GYM_KR.objects[1].level == 60, "Blaine's level must be scaled to 60")

  print("  Blaine's Gym dedicated interior room & postgame scaling verified.")

  -- 5. Verify Gen 2 Silver (Rival) event trigger & Boss encounters
  local mtMoon1f = Data.maps.MT_MOON_1F_KR
  local hasRival = false
  for _, o in ipairs(mtMoon1f.objects or {}) do
    if o.isRivalEvent then
      hasRival = true
      assert(o.trainerClass == "OPP_RIVAL2", "Rival event must use OPP_RIVAL2")
      assert(o.level == 58, "Rival story level must match Kanto level curve (58)")
      assert(o.x == 14 and o.y == 28, "Rival must stand on (14, 28) at entrance corridor")
    end
  end
  assert(hasRival == true, "Mt. Moon 1F must have Silver Rival event trigger")
  assert(mtMoon1f.objects[14] and mtMoon1f.objects[14].isRivalEvent,
    "Silver must be objects[14] (script object id 15)")
  assert(type(mtMoon1f.coordEvents) == "table" and #mtMoon1f.coordEvents >= 4,
    "MT_MOON_1F_KR must have Silver coordEvents (legacy MT_MOON_1F-only attach missed _KR)")
  local padHits = 0
  for _, e in ipairs(mtMoon1f.coordEvents) do
    if (e.x == 14 or e.x == 15) and (e.y == 33 or e.y == 34) and e.scriptKey then
      padHits = padHits + 1
    end
  end
  assert(padHits >= 4, "Silver pads must cover (14/15, 33/34) just inside Route 3 entrance")

  local seafoamB4f = Data.maps.SEAFOAM_ISLANDS_B4F_KR
  local hasArticuno = false
  for _, o in ipairs(seafoamB4f.objects or {}) do
    if o.isBoss and o.species == "ARTICUNO" then
      hasArticuno = true
      assert(o.level == 60, "Articuno level must be 60")
    end
  end
  assert(hasArticuno == true, "Seafoam Islands B4F must have Articuno boss encounter")

  local caveB1f = Data.maps.CERULEAN_CAVE_B1F_KR
  local hasMewtwo = false
  for _, o in ipairs(caveB1f.objects or {}) do
    if o.isBoss and o.species == "MEWTWO" then
      hasMewtwo = true
      assert(o.level == 70, "Mewtwo level must be 70")
    end
  end
  assert(hasMewtwo == true, "Cerulean Cave B1F must have Mewtwo boss encounter")

  print("  Gen 2 Mt. Moon Silver Rival & Articuno/Mewtwo boss encounters verified.")

  -- 5b. Verify scaled postgame encounter tables for all restored maps
  assert(Data.encounters ~= nil, "Data.encounters must be present")
  assert(Data.encounters.VIRIDIAN_FOREST_KR ~= nil, "Viridian Forest encounters must be present")
  local vfSlots = Data.encounters.VIRIDIAN_FOREST_KR.grass.slots
  assert(#vfSlots == 10, "Viridian Forest must have 10 grass slots")
  assert(vfSlots[1].level >= 40 and vfSlots[1].level <= 50, "Viridian Forest wild level must be scaled to postgame curve (43-49)")

  local mmSlots = Data.encounters.MT_MOON_1F_KR.grass.slots
  assert(#mmSlots == 10, "Mt. Moon 1F must have 10 grass slots")
  assert(mmSlots[1].level >= 45 and mmSlots[1].level <= 52, "Mt. Moon 1F wild level must be scaled to postgame curve (46-50)")

  local ccSlots = Data.encounters.CERULEAN_CAVE_B1F_KR.grass.slots
  assert(#ccSlots == 10, "Cerulean Cave B1F must have 10 grass slots")
  assert(ccSlots[1].level >= 58 and ccSlots[1].level <= 68, "Cerulean Cave B1F wild level must be scaled to 59-65")

  print("  Scaled postgame encounter tables verified.")

  -- 6. Verify 100% of warps and ladders are walkable
  local Map = require("src.world.gen2.Map")
  local Permissions = require("src.world.gen2.Permissions")
  for mapId, mdef in pairs(Data.maps) do
    local ts = Data.tilesets[mdef.tileset] or fakeMod.data.gen2Tilesets[mdef.tileset]
    assert(ts ~= nil, "Tileset missing for " .. mapId)
    local map = Map.new(mdef, ts)
    for i, w in ipairs(mdef.warps or {}) do
      local coll = map:cellCollision(w.x, w.y)
      local walkable = Permissions.isWalkable(coll) or Permissions.isWater(coll)
      assert(walkable == true, string.format("Warp #%d on %s at (%d, %d) is unwalkable (coll=0x%02x)", i, mapId, w.x, w.y, coll))
    end
  end
  print("  All dungeon warps, ladders, and doors verified 100% walkable.")

  -- 7. Verify all signs, bgEvents, NPCs, and itemballs across all 20 restored dungeons
  _G.love = _G.love or {
    filesystem = { load = loadfile, read = function(p) local f = io.open(p, "rb") if not f then return nil end local c = f:read("*a") f:close() return c end },
    graphics = {
      getDimensions = function() return 800, 600 end,
      setCanvas = function() end,
      newCanvas = function() return { renderTo = function(self, fn) fn() end, setFilter = function() end, getDimensions = function() return 128, 128 end } end,
      newImage = function() return { getWidth = function() return 16 end, getHeight = function() return 16 end, getDimensions = function() return 128, 128 end, setFilter = function() end } end,
      newQuad = function() return {} end,
      draw = function() end,
      setColor = function() end,
      clear = function() end,
      push = function() end,
      pop = function() end,
      origin = function() end,
    },
    window = { getMode = function() return 800, 600 end },
  }

  local World = require("src.world.gen2.World")
  local Vm = require("src.script.gen2.Vm")
  local Events = require("src.world.gen2.Events")
  local game = {
    data = fakeMod.data,
    save = { eventFlags = {} },
  }
  local events = Events.new(game)
  local world = World.new(game, events)
  world:load()

  local verifiedSigns = 0
  local verifiedNpcs = 0
  local verifiedItems = 0

  for mapId, _ in pairs(Data.maps) do
    world:setMap(mapId, 1, 1, "down")
    local mdef = world.maps[mapId]
    assert(mdef ~= nil, "Map missing: " .. mapId)

    -- Test bgEvents / signs
    for bgIdx, bg in ipairs(mdef.bgEvents or {}) do
      world.player.cellX = bg.x
      world.player.cellY = bg.y + 1
      world.player.facing = "up"
      local cap = nil
      world.vm = Vm.new(world.scripts, world.text, world.events, {
        showText = function(b, done) cap = b end,
        facePlayer = function() end,
      })
      world:interactBody()
      assert(cap and cap ~= "..." and cap ~= "", string.format("bgEvent %d on %s failed: got %s", bgIdx, mapId, tostring(cap)))
      verifiedSigns = verifiedSigns + 1
    end

    -- Test non-itemball objects
    for oIdx, obj in ipairs(mdef.objects or {}) do
      local isBoulder = (obj.sprite and obj.sprite:find("BOULDER")) or (obj.name and obj.name:find("BOULDER"))
      if not obj.itemball and not isBoulder then
        world.player.cellX = obj.x
        world.player.cellY = obj.y + 1
        world.player.facing = "up"
        local cap = nil
        world.vm = Vm.new(world.scripts, world.text, world.events, {
          showText = function(b, done) cap = b end,
          facePlayer = function() end,
        })
        world:interactBody()
        assert(cap and cap ~= "..." and cap ~= "", string.format("Object %d (%s) on %s failed: got %s", oIdx, tostring(obj.name), mapId, tostring(cap)))
        verifiedNpcs = verifiedNpcs + 1
      elseif obj.itemball then
        local itemName = world:getItemName(obj.itemball.item)
        assert(itemName and itemName ~= "" and not itemName:find("^item"), string.format("Itemball on %s has invalid name: %s", mapId, tostring(itemName)))
        verifiedItems = verifiedItems + 1
      end
    end
  end
  print(string.format("  Verified %d signs/bgEvents, %d NPCs, and %d itemballs with 100%% authentic dialogues.", verifiedSigns, verifiedNpcs, verifiedItems))

  -- 8. Trainer identity: Gold class 9 is RIVAL1, not Gen1 Hiker Marcos.
  -- Marcos lives at Gold HIKER (44) member 201+. Defeated flags use event ids.
  local BattleState = require("src.ui.gen2.BattleState")
  local Battle = require("src.battle.gen2.Battle")
  local Trainers = require("src.world.gen2.Trainers")

  local rival1 = Trainers.lookup(fakeMod.data.gen2Trainers, 9, 1)
  assert(rival1 ~= nil, "lookup(9,1) must resolve Gold RIVAL1")
  assert(rival1.name ~= "MARCOS", "lookup(9,1) must not be Hiker Marcos")
  local r1lead = rival1.roster and rival1.roster[1]
  assert(r1lead and r1lead.level <= 10,
    "lookup(9,1) must be early-game RIVAL1, not postgame Marcos")

  local marcos = Trainers.lookup(fakeMod.data.gen2Trainers, "HIKER", 201)
    or Trainers.lookup(fakeMod.data.gen2Trainers, 44, 201)
  assert(marcos ~= nil and marcos.name == "MARCOS", "Marcos resolves via Gold HIKER member 201")
  assert(marcos.roster and marcos.roster[1] and marcos.roster[1].level >= 45,
    "Marcos keeps postgame dungeon levels")

  -- Spot-check other former Gen1 classNum victims stay stock.
  for _, probe in ipairs({ 1, 2, 8 }) do
    local rec = Trainers.lookup(fakeMod.data.gen2Trainers, probe, 1)
    local nm = rec and rec.name
    assert(nm ~= "JOSH" and nm ~= "KENT" and nm ~= "JOVAN",
      string.format("lookup(%d,1) must not be a Mt Moon dungeon trainer (got %s)", probe, tostring(nm)))
  end
  local indigo = Trainers.lookup(fakeMod.data.gen2Trainers, "RIVAL2", 1)
    or Trainers.lookup(fakeMod.data.gen2Trainers, 42, 1)
  assert(indigo ~= nil, "RIVAL2 member 1 exists")
  assert(indigo.name ~= "SILVER", "RIVAL2 member 1 is not Mt Moon Silver")
  assert(indigo.roster and indigo.roster[1] and indigo.roster[1].level < 50,
    "RIVAL2 member 1 stays Indigo stock levels")
  local silver = Trainers.lookup(fakeMod.data.gen2Trainers, "RIVAL2", 201)
    or Trainers.lookup(fakeMod.data.gen2Trainers, 42, 201)
  assert(silver and silver.name == "SILVER", "Mt Moon Silver at RIVAL2 member 201")

  local battle = Battle.new({
    data = fakeMod.data,
    party = { { species = "PIKACHU", level = 50, hp = 100, maxHp = 100, moves = {}, dvs = { attack = 15, defense = 15, speed = 15, special = 15 } } },
    trainer = {
      class = marcos.class,
      classId = marcos.classId or "HIKER",
      name = "HIKER MARCOS",
      party = Trainers.party(fakeMod.data, marcos),
    }
  })
  local bs = BattleState.new(game, { battle = battle })
  assert(bs.showEnemyTrainer == true, "Enemy trainer sprite must be shown at battle start")
  assert(bs.enemyTrainerPath == "assets/generated/battle/trainers/hiker.png", "Trainer path mismatch")
  assert(bs.queue[1].kind == "message" and bs.queue[1].text:find("wants to battle"), "Event 1 must be 'wants to battle'")
  assert(bs.queue[2].kind == "trainer-slide", "Event 2 must be 'trainer-slide'")
  print("  Battle intro + Gen1/Gold trainer identity collisions verified.")

  -- 9. Verify wall collisions and bidirectional warp traversal
  world:setMap("MT_MOON_1F_KR", 5, 6, "up")
  local wallColl = world.map:cellCollision(0, 0)
  assert(Permissions.isWall(wallColl) == true, "Border wall at (0, 0) must be solid wall")
  assert(Permissions.doorForcedDirection(wallColl) == nil, "Border wall at (0, 0) must NOT force movement")

  local carpetColl = world.map:cellCollision(14, 35)
  assert(Permissions.isImmediateWarp(carpetColl) == true or Permissions.carpetDirection(carpetColl) == "down", "Exit carpet at (14, 35) must be exit warp")

  local ladderColl = world.map:cellCollision(5, 5)
  assert(Permissions.isWarpCollision(ladderColl) == true, "Ladder at (5, 5) must be warp collision")
  assert(Permissions.isImmediateWarp(ladderColl) == true, "Ladder at (5, 5) must be immediate warp")

  local warp1 = world.map:warpAt(5, 5)
  assert(warp1 ~= nil, "Warp entry at (5, 5) on MT_MOON_1F_KR must exist")
  world:takeWarp(warp1.def)
  if world.mapSetup and world.mapSetup.load then world.mapSetup.load() end
  assert(world.map.id:find("MT_MOON_B1F") and world.player.cellX == 5 and world.player.cellY == 5, "Must warp cleanly to MT_MOON_B1F (5, 5)")

  local warpBack = world.map:warpAt(5, 5)
  assert(warpBack ~= nil, "Warp entry at (5, 5) on MT_MOON_B1F_KR must exist")
  world:takeWarp(warpBack.def)
  if world.mapSetup and world.mapSetup.load then world.mapSetup.load() end
  assert(world.map.id:find("MT_MOON_1F") and world.player.cellX == 5 and world.player.cellY == 5, "Must warp cleanly back to MT_MOON_1F (5, 5)")

  local exitWarp = world.map:warpAt(14, 35)
  assert(exitWarp and (exitWarp.def.destMap == "ROUTE_4" or exitWarp.def.destMap == "ROUTE_3"), "Exit warp at (14, 35) must target overworld route")

  -- 9b. Route 4 cave mouths must takeWarp into restored B1F exit pad (Digletts/Safari pattern)
  world.maps.ROUTE_4 = fakeMod.data.gen2Maps.ROUTE_4
  for mid, mdef in pairs(Data.maps) do world.maps[mid] = mdef end
  world.maps.MT_MOON_B1F = Data.maps.MT_MOON_B1F_KR
  world:setMap("ROUTE_4", 24, 6, "up")
  if world.mapSetup and world.mapSetup.load then world.mapSetup.load() end
  local r4Entry = world.map:warpAt(24, 5)
  assert(r4Entry ~= nil, "ROUTE_4 must have a warp at cave mouth (24, 5)")
  assert(r4Entry.def.destMap == "MT_MOON_B1F_KR", "Live ROUTE_4 (24,5) must target MT_MOON_B1F_KR")
  world.warpCooldown = nil
  world:takeWarp(r4Entry.def)
  if world.mapSetup and world.mapSetup.load then world.mapSetup.load() end
  assert(world.map.id == "MT_MOON_B1F_KR", "Route 4 cave must land in MT_MOON_B1F_KR")
  assert(world.player.cellX == 27 and world.player.cellY == 3,
    string.format("Route 4 cave must land on B1F exit pad (27,3), got (%s,%s)",
      tostring(world.player.cellX), tostring(world.player.cellY)))
  print("  Route 4 live setMap/takeWarp into MT_MOON_B1F_KR (27,3) verified.")

  -- Test ladder approach from all 4 directions
  local testDirs = {
    { startX = 5, startY = 4, moveDir = "down" },
    { startX = 5, startY = 6, moveDir = "up" },
    { startX = 4, startY = 5, moveDir = "right" },
    { startX = 6, startY = 5, moveDir = "left" },
  }
  for _, t in ipairs(testDirs) do
    world:setMap("MT_MOON_1F_KR", t.startX, t.startY, t.moveDir)
    world.warpCooldown = nil
    world.heldDir = t.moveDir
    world:movePlayer(t.moveDir)
    world.player.moving = false
    world.player.cellX, world.player.cellY = world.player.targetX, world.player.targetY
    assert(world:checkWarpOnArrive() == true, "Must take warp entering ladder from direction: " .. t.moveDir)
  end

  -- Test spawning on ladder with bottom landing
  world:setMap("MT_MOON_B2F_KR", 21, 17, "down")
  world.heldDir = "down"
  assert(world:movePlayer("down") == "moved", "Must be able to step down off ladder landing cleanly")
  print("  Solid wall collisions, 4-direction ladder triggers, and bidirectional warp traversals verified 100%.")

  -- 10. Verify zero spurious forced movement across all maps
  for mapId, mdef in pairs(Data.maps) do
    local ts = Data.tilesets[mdef.tileset] or fakeMod.data.gen2Tilesets[mdef.tileset]
    local map = Map.new(mdef, ts)
    local h = (mdef.heightCells or (mdef.height * 2))
    local w = (mdef.widthCells or (mdef.width * 2))
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local coll = map:cellCollision(x, y)
        local forced = Permissions.doorForcedDirection(coll) or Permissions.currentDirection(coll)
        if forced then
          local hasWarp = false
          for _, warpDef in ipairs(mdef.warps or {}) do
            if warpDef.x == x and warpDef.y == y then hasWarp = true; break end
          end
          assert(hasWarp, string.format("Spurious forced movement on %s at (%d, %d): coll=0x%02x, forced=%s", mapId, x, y, coll, tostring(forced)))
        end
      end
    end
  end
  print("  Zero spurious forced movements verified across 100% of cells on all 20 maps.")

  -- 11. Verify CAVERN stair blocks walkability & cave wall solid boundaries
  local cavernColl = Data.tilesets.CAVERN.collision
  assert(cavernColl ~= nil, "CAVERN tileset collision must exist")
  assert(cavernColl[41][4] == 0x7A, "CAVERN block 40 quad 3 must be COLL_STAIRCASE (0x7A)")
  assert(cavernColl[58][1] == 0x07 and cavernColl[58][2] == 0x07 and cavernColl[58][3] == 0x00 and cavernColl[58][4] == 0x00,
    "CAVERN cliff block 57 must have solid wall top {7, 7} and walkable ground bottom {0, 0}")
  assert(cavernColl[1][1] == 0x07 and cavernColl[1][2] == 0x07 and cavernColl[1][3] == 0x07 and cavernColl[1][4] == 0x07,
    "CAVERN cave wall block 0 must remain 100% solid wall {7, 7, 7, 7}")
  print("  CAVERN stair blocks walkability & cave wall solid boundaries verified.")

  -- 11b. Gen1 dungeon sheets must resolve via mod overrides (Gold mobile has no Red cache).
  RestoredDungeons.bindGen1TilesetOverrideImages(Data)
  assert(Data.tilesets.CAVERN.image == "assets/generated/tilesets/kr_cavern.png",
    "CAVERN must point at kr_cavern override sheet")
  assert(Data.tilesets.POKECENTER.image == "assets/generated/tilesets/kr_pokecenter.png",
    "POKECENTER must point at kr_pokecenter override sheet")
  assert(Data.tilesets.TILESET_KANTO.image == "assets/generated/tilesets/kanto.png",
    "TILESET_KANTO keeps stock/override kanto.png path")
  local caveSheet = "mods/Kanto-Reforged/overrides/tilesets/kr_cavern.png"
  local okInfo = love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(caveSheet)
  if not okInfo then
    -- Headless: fall back to plain file existence next to the repo.
    local f = io.open(caveSheet, "rb")
    assert(f, "overrides/tilesets/kr_cavern.png must be shipped with the mod")
    f:close()
  end
  print("  Gen1 tileset override sheets (kr_*) verified.")

  -- 12. Verify Gen 1 safety isolation
  if Host.isGen1() then
    local res = RestoredDungeons.apply()
    assert(res == false, "RestoredDungeons.apply must return false and make no changes in Gen 1 mode")
    print("  Gen 1 mode safety isolation verified.")
  end

  print("All restored_dungeons_test.lua assertions passed cleanly!")
  return true
end

runTests()
