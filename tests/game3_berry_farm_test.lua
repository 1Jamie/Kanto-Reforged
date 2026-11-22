local Host = require("mods.Kanto-Reforged.core.host")
local BerryFarmGame3 = require("mods.Kanto-Reforged.world.berry_farm_game3")
local BerryQuests = require("mods.Kanto-Reforged.world.berry_quests")
local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
local CollPermissions = require("src.core.CollPermissions")

pcall(function() require("tests.fixture_data.game3_items").install() end)

local function runTests()
  print("--- Testing Gen 3 Berry Farm System ---")

  Host.force(3)

  -- 1. Native GBA Berry constants
  assert(BerryFarmGame3.GBA_BERRIES.CHERI_BERRY == 133, "Cheri Berry GBA ID must be 133")
  assert(BerryFarmGame3.GBA_BERRIES.CHESTO_BERRY == 134, "Chesto Berry GBA ID must be 134")
  assert(BerryFarmGame3.GBA_BERRIES.PECHA_BERRY == 135, "Pecha Berry GBA ID must be 135")
  assert(BerryFarmGame3.GBA_BERRIES.RAWST_BERRY == 136, "Rawst Berry GBA ID must be 136")
  assert(BerryFarmGame3.GBA_BERRIES.ASPEAR_BERRY == 137, "Aspear Berry GBA ID must be 137")
  assert(BerryFarmGame3.GBA_BERRIES.LEPPA_BERRY == 138, "Leppa Berry GBA ID must be 138")
  assert(BerryFarmGame3.GBA_BERRIES.ORAN_BERRY == 139, "Oran Berry GBA ID must be 139")
  assert(BerryFarmGame3.GBA_BERRIES.PERSIM_BERRY == 140, "Persim Berry GBA ID must be 140")
  assert(BerryFarmGame3.GBA_BERRIES.LUM_BERRY == 141, "Lum Berry GBA ID must be 141")
  assert(BerryFarmGame3.GBA_BERRIES.SITRUS_BERRY == 142, "Sitrus Berry GBA ID must be 142")

  -- 2. Mock mod save state
  local mockSave = {}
  local mockMod = {
    save = {
      get = function(self, k, default) return mockSave[k] ~= nil and mockSave[k] or default end,
      set = function(self, k, v) mockSave[k] = v end,
    },
    events = {
      on = function() end,
    },
    hooks = {
      wrap = function() end,
    },
    content = {
      maps = {
        patch = function() end,
        register = function() end,
      },
      sprites = {
        register = function() end,
      },
    },
  }

  BerryFarmGame3.install(mockMod)
  BerryQuests.register(mockMod)

  -- 3. Starter Unlocked Berries
  local unlocked = BerryFarmGame3.ensureUnlocked(mockMod)
  assert(unlocked.ORAN_BERRY == true, "Starter ORAN_BERRY should be unlocked")

  local plantable = BerryFarmGame3.plantableList(mockMod)
  assert(#plantable >= 1 and plantable[1] == "ORAN_BERRY", "ORAN_BERRY is in plantable list")

  -- Unlock Cheri
  BerryFarmGame3.unlockBerry(mockMod, "CHERI_BERRY")
  local plantableAfter = BerryFarmGame3.plantableList(mockMod)
  local hasCheri = false
  for _, b in ipairs(plantableAfter) do
    if b == "CHERI_BERRY" then hasCheri = true end
  end
  assert(hasCheri, "CHERI_BERRY is plantable after unlock")

  -- 4. Inventory Helpers (Bag)
  local gameSave = {
    inventory = {
      ORAN_BERRY = 5,
      [133] = 3, -- Cheri Berry by GBA ID
    }
  }

  assert(BerryFarmGame3.bagGetItemCount(gameSave, "ORAN_BERRY") == 5, "Bag count for ORAN_BERRY is 5")
  assert(BerryFarmGame3.bagGetItemCount(gameSave, "CHERI_BERRY") == 3, "Bag count for CHERI_BERRY (ID 133) is 3")

  local removed = BerryFarmGame3.bagRemoveItem(gameSave, "ORAN_BERRY", 1)
  assert(removed, "Removed 1 ORAN_BERRY")
  assert(BerryFarmGame3.bagGetItemCount(gameSave, "ORAN_BERRY") == 4, "Bag count for ORAN_BERRY is now 4")

  BerryFarmGame3.bagAddItem(gameSave, "CHERI_BERRY", 2)
  assert(BerryFarmGame3.bagGetItemCount(gameSave, "CHERI_BERRY") == 5, "Bag count for CHERI_BERRY is now 5")

  -- 5. Planting & Step Growth per Soil Rank
  Host.saveSet(mockMod.save, "soil_rank", 0)
  assert(BerryFarmGame3.growSteps(mockMod) == 500, "Rank 0 requires 500 steps")
  Host.saveSet(mockMod.save, "soil_rank", 1)
  assert(BerryFarmGame3.growSteps(mockMod) == 438, "Rank 1 requires 438 steps")
  Host.saveSet(mockMod.save, "soil_rank", 2)
  assert(BerryFarmGame3.growSteps(mockMod) == 375, "Rank 2 requires 375 steps")
  Host.saveSet(mockMod.save, "soil_rank", 3)
  assert(BerryFarmGame3.growSteps(mockMod) == 300, "Rank 3 requires 300 steps")

  Host.saveSet(mockMod.save, "soil_rank", 0)
  Host.saveSet(mockMod.save, "farmSteps", 0)
  local plots = {}
  BerryFarmGame3.setPlot(mockMod, plots, 1, {
    berryId = "ORAN_BERRY",
    plantedAtSteps = 0,
  })

  assert(not BerryFarmGame3.plotReady(mockMod, 1), "Plot 1 should not be ready at step 0")
  assert(BerryFarmGame3.stepsRemaining(mockMod, 1) == 500, "Plot 1 should have 500 steps remaining")

  -- Walk the full grow window
  for _ = 1, 500 do
    BerryFarmGame3.bumpStep(mockMod)
  end

  assert(BerryFarmGame3.plotReady(mockMod, 1), "Plot 1 should be ready after 500 steps")
  assert(BerryFarmGame3.stepsRemaining(mockMod, 1) == 0, "Plot 1 should have 0 steps remaining")

  -- 6. Pokécenter Door Coordinates & Layout Override
  assert(BerryFarmGame3.PC_DOOR.x == 3 and BerryFarmGame3.PC_DOOR.y == 8, "PC door is at (3, 8)")
  assert(BerryFarmGame3.RETURN_CELL.x == 3 and BerryFarmGame3.RETURN_CELL.y == 8, "Return cell is at (3, 8)")

  local mockLayout = {
    overrides = {},
    applyOverride = function(self, x, y, mid, coll, elev)
      self.overrides[y * 1024 + x] = { mid = mid, coll = coll, elev = elev }
    end
  }
  BerryFarmGame3.patchPokecenterLayout(mockLayout)
  assert(mockLayout.overrides[8 * 1024 + 3].mid == 707, "Center tile at (3, 8) has mid 707")
  assert(mockLayout.overrides[8 * 1024 + 3].coll == 0, "Top mat tile at (3, 8) has walkable floor coll 0")
  assert(mockLayout.overrides[8 * 1024 + 2].mid == 706, "Left tile at (2, 8) has mid 706")
  assert(mockLayout.overrides[8 * 1024 + 4].mid == 708, "Right tile at (4, 8) has mid 708")
  assert(mockLayout.overrides[9 * 1024 + 3].mid == 27, "Bottom mat tile at (3, 9) has mid 27")
  assert(mockLayout.overrides[9 * 1024 + 3].coll == 114, "Bottom mat tile at (3, 9) has warp coll 114")

  -- 7. BERRY_FARM Map LayoutNative & Prefix Check
  local MapIds = require("src.core.game3.map_ids")
  assert(MapIds.isGame3Map(BerryFarmGame3.MAP_ID), "MAP_ID must pass isGame3Map prefix check")
  local farmLayout = BerryFarmGame3.buildFarmLayout()
  assert(farmLayout ~= nil, "buildFarmLayout returns layout")
  assert(type(farmLayout.collArray) == "function", "layout has collArray method")
  local coll = farmLayout:collArray()
  assert(type(coll) == "table" and #coll == 38 * 24, "collArray returned full grid")

  -- 8. Map Visual Layout & Collision Validations
  -- Cottage roof peak at y=3, door at (7, 7)
  assert(farmLayout:midAt(6, 3) == 641, "Cottage roof top-left at (6, 3)")
  assert(CollPermissions.isWall(farmLayout:collAt(6, 3)), "Cottage roof is impassable wall")
  assert(farmLayout:midAt(7, 7) == 675, "Cottage door at (7, 7)")
  assert(CollPermissions.isLand(farmLayout:collAt(7, 7)), "Cottage door has warp land collision")

  -- Border trees are impassable walls (matching Route 1 / Celadon borders)
  assert(farmLayout:midAt(0, 0) == 28 and CollPermissions.isWall(farmLayout:collAt(0, 0)), "Border tree top-left trunk at (0, 0) is impassable wall")
  assert(farmLayout:midAt(0, 1) == 20 and CollPermissions.isWall(farmLayout:collAt(0, 1)), "Border tree top-left canopy at (0, 1) is impassable wall")
  assert(farmLayout:midAt(5, 0) == 29 and CollPermissions.isWall(farmLayout:collAt(5, 0)), "Border tree trunk from void at (5, 0) is impassable wall")
  assert(farmLayout:midAt(5, 1) == 37 and CollPermissions.isWall(farmLayout:collAt(5, 1)), "Border tree clean canopy top facing farm at (5, 1) is impassable wall")
  assert(farmLayout:midAt(5, 22) == 31 and CollPermissions.isWall(farmLayout:collAt(5, 22)), "Border tree bottom trunk resting on grass at (5, 22) is impassable wall")
  assert(farmLayout:midAt(5, 23) == 21 and CollPermissions.isWall(farmLayout:collAt(5, 23)), "Border tree canopy top into void at (5, 23) is impassable wall")
  assert(CollPermissions.isWall(farmLayout:collAt(37, 23)), "Border tree at (37, 23) is impassable wall")

  -- Pond: top shore, corners, open water 299 inside, and ALL WATER COLLISION
  assert(farmLayout:midAt(22, 4) == 721, "Pond top-left shore corner at (22, 4)")
  assert(farmLayout:midAt(35, 4) == 722, "Pond top-right shore corner at (35, 4)")
  assert(farmLayout:midAt(25, 4) == 291, "Pond top shore at (25, 4)")
  assert(farmLayout:midAt(22, 10) == 298, "Pond left shore at (22, 10)")
  assert(farmLayout:midAt(35, 10) == 300, "Pond right shore at (35, 10)")
  assert(farmLayout:midAt(25, 10) == 299, "Pond interior is open animated water 299 at (25, 10)")
  assert(farmLayout:midAt(30, 15) == 299, "Pond interior is open animated water 299 at (30, 15)")

  assert(CollPermissions.isWater(farmLayout:collAt(22, 4)), "Pond corner (22, 4) has water collision")
  assert(CollPermissions.isWater(farmLayout:collAt(25, 4)), "Pond shore (25, 4) has water collision")
  assert(CollPermissions.isWater(farmLayout:collAt(25, 10)), "Pond interior (25, 10) has water collision")

  -- Perimeter fence: outline with opening gate at (11, 10), pure grass 662 inside
  assert(farmLayout:midAt(4, 10) == 236 and CollPermissions.isWall(farmLayout:collAt(4, 10)), "Fence top-left corner is wall at (4, 10)")
  assert(farmLayout:midAt(19, 10) == 237 and CollPermissions.isWall(farmLayout:collAt(19, 10)), "Fence top-right corner is wall at (19, 10)")
  assert(farmLayout:midAt(10, 10) == 237 and CollPermissions.isWall(farmLayout:collAt(10, 10)), "Fence gate post right at (10, 10)")
  assert(farmLayout:midAt(13, 10) == 236 and CollPermissions.isWall(farmLayout:collAt(13, 10)), "Fence gate post left at (13, 10)")
  assert(farmLayout:midAt(11, 10) == 662 and CollPermissions.isLand(farmLayout:collAt(11, 10)), "Fence gate open at (11, 10)")
  assert(farmLayout:midAt(12, 10) == 662 and CollPermissions.isLand(farmLayout:collAt(12, 10)), "Fence gate open at (12, 10)")
  assert(farmLayout:midAt(4, 20) == 252 and CollPermissions.isWall(farmLayout:collAt(4, 20)), "Fence bottom-left corner is wall at (4, 20)")
  assert(farmLayout:midAt(19, 20) == 253 and CollPermissions.isWall(farmLayout:collAt(19, 20)), "Fence bottom-right corner is wall at (19, 20)")
  assert(farmLayout:midAt(4, 15) == 244 and CollPermissions.isWall(farmLayout:collAt(4, 15)), "Left vertical fence post at (4, 15)")
  assert(farmLayout:midAt(19, 15) == 245 and CollPermissions.isWall(farmLayout:collAt(19, 15)), "Right vertical fence post at (19, 15)")
  assert(farmLayout:midAt(10, 15) == 662 and CollPermissions.isLand(farmLayout:collAt(10, 15)), "Inside garden is clean walkable land at (10, 15)")
  assert(farmLayout:midAt(3, 8) == 662 and CollPermissions.isLand(farmLayout:collAt(3, 8)), "Lawn under scholar is uniform grass 662")
  assert(farmLayout:midAt(13, 8) == 662 and CollPermissions.isLand(farmLayout:collAt(13, 8)), "Lawn outside gate is uniform grass 662")

  -- 9. Map Def Objects, Graphics IDs, and Script Keys
  local farmDef = BerryFarmGame3.buildFarmMapDef(mockMod)
  assert(farmDef.objects ~= nil and #farmDef.objects == 14, "Farm map has 5 NPCs + 9 plot markers = 14 objects")

  local npcsByName = {}
  for _, obj in ipairs(farmDef.objects) do
    npcsByName[obj.name] = obj
  end

  assert(npcsByName.BERRY_FARM_GIRL ~= nil, "Girl NPC exists")
  assert(npcsByName.BERRY_FARM_GIRL.graphicsId == 23, "Girl has GBA graphicsId 23")
  assert(npcsByName.BERRY_FARM_GIRL.scriptKey == "TEXT_BERRY_FARM_GIRL", "Girl has scriptKey")
  assert(npcsByName.BERRY_FARM_GIRL.x == 11 and npcsByName.BERRY_FARM_GIRL.y == 7, "Girl NPC moved 2 steps up to (11, 7) beside cottage")

  assert(npcsByName.BERRY_FARM_FISHER ~= nil, "Fisher NPC exists")
  assert(npcsByName.BERRY_FARM_FISHER.graphicsId == 57, "Fisher has GBA graphicsId 57")
  assert(npcsByName.BERRY_FARM_FISHER.scriptKey == "TEXT_BERRY_FARM_FISHER", "Fisher has scriptKey")

  assert(npcsByName.BERRY_FARM_SOIL_EXPERT ~= nil, "Soil Expert NPC exists")
  assert(npcsByName.BERRY_FARM_SOIL_EXPERT.graphicsId == 55, "Soil Expert has GBA graphicsId 55")
  assert(npcsByName.BERRY_FARM_SOIL_EXPERT.scriptKey == "TEXT_BERRY_FARM_SOIL_EXPERT", "Soil Expert has scriptKey")

  assert(npcsByName.BERRY_FARM_SCHOLAR ~= nil, "Scholar NPC exists")
  assert(npcsByName.BERRY_FARM_SCHOLAR.graphicsId == 55, "Scholar has GBA graphicsId 55")
  assert(npcsByName.BERRY_FARM_SCHOLAR.scriptKey == "TEXT_BERRY_FARM_SCHOLAR", "Scholar has scriptKey")

  assert(npcsByName.BERRY_FARM_MERCHANT ~= nil, "Merchant NPC exists")
  assert(npcsByName.BERRY_FARM_MERCHANT.graphicsId == 68, "Merchant has GBA graphicsId 68")
  assert(npcsByName.BERRY_FARM_MERCHANT.scriptKey == "TEXT_BERRY_FARM_MERCHANT", "Merchant has scriptKey")

  -- Plot markers check
  for i = 1, 9 do
    local mark = npcsByName["BERRY_PLOT_MARK_" .. i]
    assert(mark ~= nil, "Plot marker " .. i .. " exists")
    assert(mark.graphicsId == nil, "Plot marker graphicsId is nil to trigger sprite renderer")
    assert(mark.scriptKey == "TEXT_BERRY_PLOT_" .. i, "Plot marker " .. i .. " has scriptKey")
    assert(mark.sprite:find("SPRITE_PLOT_"), "Plot marker uses SPRITE_PLOT_*")
  end

  -- 10. HouseNpcs.hasBadge for Gen 3
  local testSaveGen3 = {
    flags = {
      [0x820] = true, -- FLAG_BADGE01_GET (Boulder Badge)
      [0x823] = true, -- FLAG_BADGE04_GET (Rainbow Badge)
    }
  }
  assert(HouseNpcs.hasBadge(testSaveGen3, "BOULDERBADGE"), "Boulder Badge detected via Gen 3 flag")
  assert(HouseNpcs.hasBadge(testSaveGen3, "RAINBOWBADGE"), "Rainbow Badge detected via Gen 3 flag")
  assert(not HouseNpcs.hasBadge(testSaveGen3, "CASCADEBADGE"), "Cascade Badge not unlocked")

  -- 11. BerryQuests Badge Unlocks for Gen 3
  local mockGame = {
    save = testSaveGen3,
    data = { items = {}, pokemon = {} },
  }
  local unlockedBefore = BerryFarmGame3.ensureUnlocked(mockMod)
  local newly = BerryQuests.applyBadgeUnlocks(mockMod, mockGame, { gift = true })
  assert(unlockedBefore.CHERI_BERRY == true, "Cheri berry unlocked by Boulder Badge")
  assert(unlockedBefore.ASPEAR_BERRY == true, "Aspear berry unlocked by Rainbow Badge")
  assert(unlockedBefore.CHESTO_BERRY == true, "Chesto berry unlocked by Rainbow Badge")
  -- 12. Plot Planting, Step Growth & Harvesting Test
  Host.saveSet(mockMod.save, "farmSteps", 0)
  local Bag = require("src.core.game3.bag")
  local testBag = Bag.new()
  Bag.add(testBag, 133, 5) -- 5 Cheri Berries
  local testSession = { bag = testBag, map = BerryFarmGame3.MAP_ID, vars = {} }
  local farmGame = { save = testSaveGen3, session = testSession, bag = testBag }
  testSaveGen3.bag = testBag

  -- Clear plot 1
  local _, livePlots = BerryFarmGame3.ensureState(mockMod)
  BerryFarmGame3.clearPlot(mockMod, livePlots, 1)
  assert(BerryFarmGame3.getPlot(livePlots, 1) == nil, "Plot 1 starts empty")
  assert(BerryFarmGame3.plotSpriteFor(0, nil) == BerryFarmGame3.PLOT_SPRITE_SOIL, "Empty plot sprite is soil")

  -- Plant Cheri Berry (133) in Plot 1
  Bag.remove(testBag, 133, 1)
  BerryFarmGame3.setPlot(mockMod, livePlots, 1, {
    berryId = "CHERI_BERRY",
    numericId = 133,
    plantedAtSteps = 0,
  })
  local p1 = BerryFarmGame3.getPlot(livePlots, 1)
  assert(p1 ~= nil and p1.berryId == "CHERI_BERRY", "Plot 1 planted with Cheri Berry")
  assert(Bag.get(testBag, 133) == 4, "Bag now has 4 Cheri Berries")
  assert(BerryFarmGame3.plotReady(mockMod, 1) == false, "Plot 1 is not ready at 0 steps")
  assert(BerryFarmGame3.stepsRemaining(mockMod, 1) == BerryFarmGame3.GROW_STEPS, "Remaining steps equals growNeed")
  assert(BerryFarmGame3.plotSpriteFor(0, p1) == BerryFarmGame3.PLOT_SPRITE_GROWING, "Growing plot sprite")

  -- Advance steps by bumpStep
  for _ = 1, BerryFarmGame3.GROW_STEPS do
    BerryFarmGame3.bumpStep(mockMod)
  end
  assert(BerryFarmGame3.plotReady(mockMod, 1) == true, "Plot 1 is ready after GROW_STEPS")
  assert(BerryFarmGame3.stepsRemaining(mockMod, 1) == 0, "0 steps remaining")
  local ripeSpr = BerryFarmGame3.plotSpriteFor(BerryFarmGame3.GROW_STEPS, p1)
  assert(ripeSpr == "SPRITE_PLOT_CHERI", "Plot sprite matches ripe Cheri Berry")

  -- 13. Plot Talk: Pick Dialog & Interaction Flow
  local talkP1 = BerryFarmGame3.makePlotTalk(mockMod, 1)
  assert(type(talkP1) == "function", "makePlotTalk returns function")

  -- Test mock UI message/choice interception
  local lastPrompt = nil
  local lastChoiceCb = nil
  local Choice = require("src.ui.game3.choice")
  local Message = require("src.ui.game3.message")
  local origShow = Message.show
  local origYesNo = Choice.yesNo

  Message.show = function(msg, cb)
    lastPrompt = msg
    if type(cb) == "function" then
      cb()
    elseif type(cb) == "table" and type(cb.done) == "function" then
      cb.done()
    end
  end

  -- When plot 1 is ripe, talkP1 prompts to pick the Cheri Berry
  Choice.yesNo = function(cb)
    lastChoiceCb = cb
    cb(true) -- User chooses YES to pick
  end

  talkP1(farmGame, nil, nil, function() end)
  assert(lastPrompt:find("soft and loamy state"), "Picking shows harvest sequence ending in soft and loamy state")
  assert(Bag.get(testBag, 133) == 4 + BerryFarmGame3.HARVEST_YIELD, "Bag now contains original berries + yield")
  local _, updatedPlots = BerryFarmGame3.ensureState(mockMod)
  assert(BerryFarmGame3.getPlot(updatedPlots, 1) == nil, "Plot 1 is now empty after picking")

  -- Second interaction with the empty plot: now prompts to plant a berry
  Choice.yesNo = function(cb)
    lastChoiceCb = cb
    cb(false) -- User chooses NO to plant
  end
  lastPrompt = nil
  talkP1(farmGame, nil, nil, function() end)
  assert(lastPrompt:find("Would you like to"), "Interacting with empty soil prompts to plant")

  -- 14. Custom Sprite Registration on game.data & 2x2 Plot Interaction
  local testGameInstance = { data = {} }
  BerryFarmGame3.registerPlotSprites(mockMod, testGameInstance)
  assert(type(testGameInstance.data.sprites) == "table", "game.data.sprites was created")
  assert(testGameInstance.data.sprites.SPRITE_PLOT_SOIL ~= nil, "SPRITE_PLOT_SOIL registered on game.data.sprites")
  assert(testGameInstance.data.sprites.SPRITE_PLOT_GROWING ~= nil, "SPRITE_PLOT_GROWING registered on game.data.sprites")
  assert(testGameInstance.data.sprites.SPRITE_PLOT_CHERI ~= nil, "SPRITE_PLOT_CHERI registered on game.data.sprites")
  assert(testGameInstance.data.gen2Sprites.SPRITE_PLOT_SOIL ~= nil, "SPRITE_PLOT_SOIL registered on game.data.gen2Sprites")

  -- Verify Field.interact handles 2x2 plot cell angles
  local Field = require("src.core.game3.field")
  local Player = require("src.core.game3.player")
  local Map = require("src.core.game3.map")
  Map.current = BerryFarmGame3.MAP_ID
  local talkedPlot = nil
  Message.show = function(msg, cb)
    talkedPlot = msg
    if type(cb) == "function" then
      cb()
    elseif type(cb) == "table" and type(cb.done) == "function" then
      cb.done()
    end
  end

  -- Plot 1 rect: x0=6, y0=12, x1=7, y1=13
  -- Test approaching from top at (6, 11) facing down -> facing cell (6, 12)
  Player.cellX, Player.cellY, Player.facing, Player.moving = 6, 11, "down", false
  local handled = Field.interact(farmGame)
  assert(handled == true, "Field.interact handled facing (6, 12)")

  -- Test approaching from top at (7, 11) facing down -> facing cell (7, 12)
  Player.cellX, Player.cellY, Player.facing, Player.moving = 7, 11, "down", false
  handled = Field.interact(farmGame)
  assert(handled == true, "Field.interact handled facing (7, 12)")

  -- Test approaching from bottom at (6, 14) facing up -> facing cell (6, 13)
  Player.cellX, Player.cellY, Player.facing, Player.moving = 6, 14, "up", false
  handled = Field.interact(farmGame)
  assert(handled == true, "Field.interact handled facing (6, 13)")

  -- Test approaching from bottom at (7, 14) facing up -> facing cell (7, 13)
  Player.cellX, Player.cellY, Player.facing, Player.moving = 7, 14, "up", false
  handled = Field.interact(farmGame)
  assert(handled == true, "Field.interact handled facing (7, 13)")

  -- Test approaching from left at (5, 12) facing right -> facing cell (6, 12)
  Player.cellX, Player.cellY, Player.facing, Player.moving = 5, 12, "right", false
  handled = Field.interact(farmGame)
  assert(handled == true, "Field.interact handled facing (6, 12) from left")

  -- Test approaching from right at (8, 13) facing left -> facing cell (7, 13)
  Player.cellX, Player.cellY, Player.facing, Player.moving = 8, 13, "left", false
  handled = Field.interact(farmGame)
  assert(handled == true, "Field.interact handled facing (7, 13) from right")

  Message.show = origShow

  -- 16. Test openPlantingBerryPouch menu wrapping (PLANT vs CANCEL)
  local mockPouch
  mockPouch = {
    open = false,
    mode = "list",
    cursor = 1,
    actionCursor = 1,
    list = function() return { { id = 139, name = "ORAN BERRY", qty = 3 } } end,
    show = function(session, bag, opts)
      mockPouch.open = true
      mockPouch._onClose = opts and opts.onClose
    end,
    close = function()
      mockPouch.open = false
      if mockPouch._onClose then mockPouch._onClose() end
    end,
    handleInput = function(input)
      if input:wasPressed("a") then mockPouch.mode = "action" end
    end,
    draw = function() end,
  }
  package.loaded["src.ui.game3.berry_pouch"] = mockPouch

  local plantedBerry = nil
  local opened = BerryFarmGame3.openPlantingBerryPouch({}, {}, function(id, row)
    plantedBerry = id
  end, function() end)
  assert(opened == true, "openPlantingBerryPouch opened successfully")

  local mockInputA = { wasPressed = function(self, key) return key == "a" end }
  -- Select CANCEL
  mockPouch.mode = "action"
  mockPouch.actionCursor = 2
  mockPouch.handleInput(mockInputA)
  assert(mockPouch.mode == "list", "Selecting CANCEL returns to list")

  -- Select PLANT
  mockPouch.mode = "action"
  mockPouch.actionCursor = 1
  mockPouch.handleInput(mockInputA)
  assert(plantedBerry == 139, "Selecting PLANT invokes onPlant callback with chosen berry ID")
  assert(mockPouch.open == false, "Pouch is closed after planting")

  package.loaded["src.ui.game3.berry_pouch"] = origPouchPkg

  -- 17. Test Berry Scholar talk & scrolling list menu
  local Choice = require("src.ui.game3.choice")
  local scholarTalk = farmDef.talk.TEXT_BERRY_FARM_SCHOLAR
  assert(scholarTalk ~= nil, "TEXT_BERRY_FARM_SCHOLAR must exist in map talk")

  local scholarDone = false
  scholarTalk(mockGame, nil, nil, function() scholarDone = true end)

  -- Advance message to trigger Choice.multi
  while Message.open and not Choice.active do
    Message.advance()
  end

  assert(Choice.active == true, "Choice should be active for berry selection")
  assert(#Choice.options == 11, "Choice options should have 10 berries + CANCEL")
  assert(Choice.cursor == 1, "Initial cursor at 1")

  -- Move down past maxShowed (5) to verify scrolling
  Choice.move(1, 0) -- 2
  Choice.move(1, 0) -- 3
  Choice.move(1, 0) -- 4
  Choice.move(1, 0) -- 5
  Choice.move(1, 0) -- 6 (scrolled)
  assert(Choice.cursor == 6, "Cursor should be at item 6")

  -- Test wrap-around to CANCEL
  Choice.move(-1, 0) -- 5
  Choice.move(-1, 0) -- 4
  Choice.move(-1, 0) -- 3
  Choice.move(-1, 0) -- 2
  Choice.move(-1, 0) -- 1
  Choice.move(-1, 0) -- wraps up to 11 (CANCEL)
  assert(Choice.cursor == 11, "Cursor should wrap to item 11 (CANCEL)")

  -- Select CANCEL
  Choice.confirm()
  assert(Choice.active == false, "Choice should close after confirm on CANCEL")
  assert(scholarDone == true, "Scholar interaction completes cleanly on CANCEL")

  Host.clearForce()
  print("✓ Gen 3 Berry Farm tests passed!")
end

runTests()
