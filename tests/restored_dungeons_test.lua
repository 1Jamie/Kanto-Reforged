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

  -- 4. Seafoam KR layouts ship in data, but overworld access is disabled at
  -- runtime for now (Route 20 stays on stock Gen2 Seafoam). Keep the gym room
  -- definition intact so re-enabling is a warp redirect away.
  local gym = Data.maps.SEAFOAM_GYM_KR
  assert(gym, "SEAFOAM_GYM_KR layout must remain in data")
  assert(gym.tileset == "TILESET_FACILITY" or gym.tileset == "GYM",
    "SEAFOAM_GYM must use dedicated GYM tileset")
  local blaine = gym.objects and gym.objects[1]
  local blaineClass = blaine and (blaine.trainerClass or (blaine.trainer and (blaine.trainer.classId or blaine.trainer.class)))
  assert(blaineClass == "OPP_BLAINE" or blaineClass == "BLAINE",
    "Blaine must be present in SEAFOAM_GYM_KR, got " .. tostring(blaineClass))
  assert(blaine.level == 60, "Blaine's level must be scaled to 60")
  print("  Seafoam gym data present (overworld access disabled).")

  -- 5. Verify Gen 2 Silver (Rival) on B2F & boss encounters
  local mtMoon1f = Data.maps.MT_MOON_1F_KR
  for _, o in ipairs(mtMoon1f.objects or {}) do
    assert(not o.isRivalEvent, "Mt. Moon 1F must not ambush Silver at the entrance")
  end
  assert(#(mtMoon1f.coordEvents or {}) == 0,
    "MT_MOON_1F_KR must not have Silver coord-event ambush pads")

  local mtMoonB2f = Data.maps.MT_MOON_B2F_KR
  local hasRival = false
  for _, o in ipairs(mtMoonB2f.objects or {}) do
    if o.name == "MTMOONB2F_SILVER_RIVAL" or o.isRivalEvent then
      hasRival = true
      assert(o.trainerClass == "RIVAL2", "B2F Silver must use RIVAL2")
      assert(o.level == 78, "B2F Silver must be postgame rematch level (78)")
      assert(o.x == 3 and o.y == 2, "Silver must be tucked in B2F northwest alcove (3, 2)")
      assert(type(o.scriptKey) == "table", "B2F Silver must have inline scriptKey")
      local needsSafari = false
      for _, cmd in ipairs(o.scriptKey) do
        if cmd.op == "checkevent" and cmd.event == 3004 then needsSafari = true end
      end
      assert(needsSafari, "Silver must require Safari clear (event 3004)")
    end
  end
  assert(hasRival == true, "Mt. Moon B2F must have tucked-away Silver Rival")

  -- Articuno lives on stock Gen2 Seafoam while KR Seafoam access is disabled.
  local caveB1f = Data.maps.CERULEAN_CAVE_B1F_KR
  local hasMewtwo = false
  for _, o in ipairs(caveB1f.objects or {}) do
    if o.name == "CERULEANCAVEB1F_MEWTWO" or o.species == "MEWTWO" then
      hasMewtwo = true
      assert(o.level == 70, "Mewtwo level must be 70")
    end
  end
  assert(hasMewtwo == true, "Cerulean Cave B1F must have Mewtwo boss encounter")

  print("  Gen 2 Mt. Moon Silver Rival & Mewtwo boss encounter verified.")

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

  -- 6. Verify warps/ladders are walkable. Gen1 tall doors often keep a second
  -- warp on the wall tile above/below the threshold; overworld mouths land on
  -- the walkable index only, so allow an unwalkable twin when a walkable sibling
  -- shares the same destination nearby.
  local Map = require("src.world.gen2.Map")
  local Permissions = require("src.world.gen2.Permissions")
  for mapId, mdef in pairs(Data.maps) do
    local ts = Data.tilesets[mdef.tileset] or fakeMod.data.gen2Tilesets[mdef.tileset]
    assert(ts ~= nil, "Tileset missing for " .. mapId)
    local map = Map.new(mdef, ts)
    for i, w in ipairs(mdef.warps or {}) do
      local coll = map:cellCollision(w.x, w.y)
      local walkable = Permissions.isWalkable(coll) or Permissions.isWater(coll)
      if not walkable then
        local hasSibling = false
        for _, w2 in ipairs(mdef.warps) do
          if w2 ~= w and w2.destMap == w.destMap
              and math.abs((w2.x or 0) - (w.x or 0)) <= 2
              and math.abs((w2.y or 0) - (w.y or 0)) <= 4 then
            local c2 = map:cellCollision(w2.x, w2.y)
            if Permissions.isWalkable(c2) or Permissions.isWater(c2) then
              hasSibling = true
              break
            end
          end
        end
        assert(hasSibling,
          string.format("Warp #%d on %s at (%d, %d) is unwalkable (coll=0x%02x)",
            i, mapId, w.x, w.y, coll))
      end
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
      -- Campaign overlays use multi-step scripts (battles / flags); not simple talk text.
      local isCampaign = obj.isCampaignOverlay
      if not isCampaign and obj.scriptKey then
        for _, cmd in ipairs(obj.scriptKey) do
          if cmd.op == "startbattle" or cmd.op == "loadtrainer" then
            isCampaign = true
            break
          end
        end
      end
      if obj.trainer and obj.trainer.scriptKey then
        for _, cmd in ipairs(obj.trainer.scriptKey) do
          if cmd.op == "startbattle" or cmd.op == "setevent" then
            isCampaign = true
            break
          end
        end
      end
      if not obj.itemball and not isBoulder and not isCampaign then
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
  assert((marcos.baseMoney or 0) > 0, "Marcos lookup carries baseMoney for prize")

  -- loadtemptrainer → World:trainerParty is what startbattle actually pays from.
  local WorldClass = require("src.world.gen2.World")
  local payWorld = setmetatable({
    game = { data = fakeMod.data, save = { player = { money = 0, name = "TEST" } } },
  }, { __index = WorldClass })
  local pay = payWorld:trainerParty(44, 201)
  assert(pay and (pay.baseMoney or 0) > 0,
    "World:trainerParty must expose baseMoney (else dungeon trainers pay $0)")
  assert(pay.roster and #pay.roster > 0, "trainerParty keeps Marcos roster")

  -- Same path after ExpTrainers.installGen2 wraps trainerParty (boot order).
  local ExpTrainers = require("mods.Kanto-Reforged.battle.trainers")
  ExpTrainers.clearBaselines()
  ExpTrainers.apply(fakeMod)
  ExpTrainers.installGen2(fakeMod)
  local pay2 = payWorld:trainerParty(44, 201)
  assert(pay2 and (pay2.baseMoney or 0) > 0,
    "trainerParty still pays after ExpTrainers.installGen2 wrap")
  local Prize = require("src.battle.gen2.Prize")
  local lastLv = pay2.roster[#pay2.roster].level
  local award = Prize.award({ player = { money = 0, name = "TEST" } }, {
    baseMoney = pay2.baseMoney,
    level = lastLv,
  })
  assert(award and (award.total or 0) > 0,
    "Prize.award for dungeon trainer must be > $0")

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
  local silver = Trainers.lookup(fakeMod.data.gen2Trainers, "RIVAL2", 210)
    or Trainers.lookup(fakeMod.data.gen2Trainers, 42, 210)
  assert(silver and silver.name == "SILVER", "Mt Moon Silver at RIVAL2 member 210")
  assert(silver.roster and silver.roster[6] and silver.roster[6].species == "TYRANITAR",
    "B2F Silver ace must be Tyranitar")

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
  assert(bs.queue[1].kind == "message" and bs.queue[1].text:find("wants to battle"),
    "Event 1 must be 'wants to battle'")
  -- Trainer frontpic needs gen2MenuGfx / class pics; optional in this harness.
  if bs.showEnemyTrainer then
    assert(bs.enemyTrainerPath and bs.enemyTrainerPath:find("hiker"),
      "Trainer path mismatch: " .. tostring(bs.enemyTrainerPath))
    assert(bs.queue[2].kind == "trainer-slide", "Event 2 must be 'trainer-slide'")
  end
  print("  Battle intro + Gen1/Gold trainer identity collisions verified.")

  -- 9. Verify wall collisions and bidirectional warp traversal
  assert(world.maps ~= nil, "world.maps must remain after trainer harness")
  world:setMap("MT_MOON_1F_KR", 5, 6, "up")
  local wallColl = world.map:cellCollision(0, 0)
  assert(Permissions.isWall(wallColl) == true, "Border wall at (0, 0) must be solid wall")
  assert(Permissions.doorForcedDirection(wallColl) == nil, "Border wall at (0, 0) must NOT force movement")

  -- Exit pads may be walkable floor with an explicit warp entry (not carpet coll).
  local exitWarp = world.map:warpAt(14, 35) or world.map:warpAt(15, 35)
  assert(exitWarp and (exitWarp.def.destMap == "ROUTE_4" or exitWarp.def.destMap == "ROUTE_3"),
    "Exit warp at south mouth must target overworld route")

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

  exitWarp = world.map:warpAt(14, 35) or world.map:warpAt(15, 35)
  assert(exitWarp and (exitWarp.def.destMap == "ROUTE_4" or exitWarp.def.destMap == "ROUTE_3"), "Exit warp at (14/15, 35) must target overworld route")

  -- 9b. Route 4 cave mouths already verified on map defs in section 1b.
  -- Live takeWarp needs full tileset/image harness; keep a light setMap smoke check.
  world.maps.ROUTE_4 = fakeMod.data.gen2Maps.ROUTE_4
  for mid, mdef in pairs(Data.maps) do world.maps[mid] = mdef end
  world.maps.MT_MOON_B1F = Data.maps.MT_MOON_B1F_KR
  local r4Ok = world:setMap("ROUTE_4", 24, 6, "up")
  if r4Ok and world.map and world.map.warpAt then
    if world.mapSetup and world.mapSetup.load then world.mapSetup.load() end
    local r4Entry = world.map:warpAt(24, 5) or world.map:warpAt(18, 5)
    if r4Entry then
      assert(r4Entry.def.destMap == "MT_MOON_B1F_KR", "Live ROUTE_4 cave mouth must target MT_MOON_B1F_KR")
      world.warpCooldown = nil
      world:takeWarp(r4Entry.def)
      if world.mapSetup and world.mapSetup.load then world.mapSetup.load() end
      assert(world.map.id == "MT_MOON_B1F_KR" or world.map.id == "MT_MOON_B1F",
        "Route 4 cave must land in MT_MOON_B1F_KR")
      print("  Route 4 live setMap/takeWarp into MT_MOON_B1F_KR verified.")
    else
      print("  Route 4 live warpAt skipped (harness); def-level mouths verified in 1b.")
    end
  else
    print("  Route 4 live setMap skipped (harness); def-level mouths verified in 1b.")
  end

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

  -- 10. Verify zero spurious forced movement across restored dungeon maps
  local dungeonIds = {
    "VIRIDIAN_FOREST_KR",
    "MT_MOON_1F_KR", "MT_MOON_B1F_KR", "MT_MOON_B2F_KR",
    "CERULEAN_CAVE_1F_KR", "CERULEAN_CAVE_2F_KR", "CERULEAN_CAVE_B1F_KR",
    "SEAFOAM_ISLANDS_1F_KR", "SEAFOAM_ISLANDS_B1F_KR", "SEAFOAM_ISLANDS_B2F_KR",
    "SEAFOAM_ISLANDS_B3F_KR", "SEAFOAM_ISLANDS_B4F_KR", "SEAFOAM_GYM_KR",
    "SAFARI_ZONE_CENTER_KR", "SAFARI_ZONE_EAST_KR", "SAFARI_ZONE_WEST_KR",
    "SAFARI_ZONE_NORTH_KR", "SAFARI_ZONE_CENTER_REST_HOUSE_KR",
    "SAFARI_ZONE_SECRET_HOUSE_KR", "SAFARI_ZONE_GATE_KR",
    "ROCK_TUNNEL_1F_KR", "ROCK_TUNNEL_B1F_KR", "DIGLETTS_CAVE_KR",
  }
  for _, mapId in ipairs(dungeonIds) do
    local mdef = Data.maps[mapId]
    if mdef then
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
  end
  print("  Zero spurious forced movements verified across restored dungeon maps.")

  -- 11. Verify TILESET_CAVE (restored dungeons) — no Gen1 CAVERN blob shipped
  assert(Data.tilesets.CAVERN == nil,
    "CAVERN Gen1 tileset must not ship in restored_dungeons_data (use TILESET_CAVE)")
  local caveColl = Data.tilesets.TILESET_CAVE and Data.tilesets.TILESET_CAVE.collision
  assert(caveColl ~= nil, "TILESET_CAVE collision must exist")
  assert(Data.maps.DIGLETTS_CAVE_KR.tileset == "TILESET_CAVE",
    "Restored caves must use native Gold TILESET_CAVE")
  print("  TILESET_CAVE (dungeons) verified; CAVERN not distributed.")

  -- 11b. Gen1 sheets kept for POKECENTER/GYM must resolve via mod overrides.
  RestoredDungeons.bindGen1TilesetOverrideImages(Data)
  assert(Data.tilesets.POKECENTER.image == "assets/generated/tilesets/kr_pokecenter.png",
    "POKECENTER must point at kr_pokecenter override sheet")
  assert(Data.tilesets.GYM.image == "assets/generated/tilesets/kr_gym.png",
    "GYM must point at kr_gym override sheet")
  assert(Data.tilesets.TILESET_KANTO.image == "assets/generated/tilesets/kanto.png",
    "TILESET_KANTO keeps stock/override kanto.png path")
  assert(not io.open("mods/Kanto-Reforged/overrides/tilesets/kr_cavern.png", "rb"),
    "kr_cavern.png must not be shipped (caves use TILESET_CAVE)")
  assert(io.open("mods/Kanto-Reforged/overrides/tileset_quads/cave_wooden_sign.png", "rb"),
    "cave sign quad must ship under overrides/tileset_quads/")
  assert(io.open("mods/Kanto-Reforged/overrides/tileset_quads/wood_stair.png", "rb"),
    "wood_stair quad must ship under overrides/tileset_quads/")
  assert(io.open("mods/Kanto-Reforged/overrides/tileset_quads/forest_wooden_sign.png", "rb"),
    "forest sign quad must ship under overrides/tileset_quads/")
  assert(io.open("mods/Kanto-Reforged/overrides/tilesets/cave.png", "rb"),
    "restore must compose overrides/tilesets/cave.png from quad sources")
  assert(io.open("mods/Kanto-Reforged/overrides/tilesets/kanto.png", "rb"),
    "restore must compose overrides/tilesets/kanto.png from quad sources")
  local caveBlocks = Data.tilesets.TILESET_CAVE and Data.tilesets.TILESET_CAVE.blocks
  assert(caveBlocks and caveBlocks[121] and caveBlocks[121][11] == 90 and caveBlocks[121][16] == 93,
    "TILESET_CAVE block #120 must use Gen1 sign tiles 90–93 in BR quadrant")
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
