package.path = "./?.lua;./?/init.lua;" .. package.path
local Host = require("mods.Kanto-Reforged.core.host")
local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
local BattleClubs = require("mods.Kanto-Reforged.battle.battle_clubs")
local JudgeNpc = require("mods.Kanto-Reforged.world.judge_npc")
local BerryQuests = require("mods.Kanto-Reforged.world.berry_quests")
local Roamers = require("mods.Kanto-Reforged.world.roamers")
local ItemSmith = require("mods.Kanto-Reforged.world.item_smith")
local MoveHub = require("mods.Kanto-Reforged.world.move_hub")
local TradesExtra = require("mods.Kanto-Reforged.world.trades_extra")
local BerryFarmGame3 = require("mods.Kanto-Reforged.world.berry_farm_game3")

local function runTests()
  print("--- Testing Gen 3 Utility NPCs ---")

  Host.force(3)
  HouseNpcs.resetClaims()
  HouseNpcs.resetInjections()

  local mockSave = {
    flags = {},
    inventory = {},
  }
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
      items = {
        get = function() return nil end,
        register = function() end,
      },
      trainers = {
        register = function() end,
        patch = function() end,
      },
      field = {
        patch = function() end,
      },
      map_scripts = {
        register = function() end,
      },
    },
  }

  HouseNpcs.installTalkDispatch(mockMod)
  BattleClubs.register(mockMod)
  JudgeNpc.register(mockMod)
  BerryQuests.register(mockMod)
  Roamers.register(mockMod)
  ItemSmith.register(mockMod)
  MoveHub.register(mockMod)
  TradesExtra.register(mockMod)

  -- 1. Verify Gen 3 Injections registered for Underground Path
  local ugInjections = HouseNpcs._gen3Injections["FR_UNDERGROUND_PATH_NORTH_ENTRANCE"]
  assert(ugInjections ~= nil and #ugInjections >= 1, "Underground Path North Entrance must have Gen 3 injections")
  local judgeObj = nil
  for _, obj in ipairs(ugInjections) do
    if obj.name == "UNDERGROUNDPATHROUTE5_JUDGE" then judgeObj = obj break end
  end
  assert(judgeObj ~= nil, "Judge NPC must be injected in Underground Path North Entrance")
  assert(judgeObj.x == 1 and judgeObj.y == 2, "Judge NPC position in Gen 3 should be (1, 2)")
  assert(judgeObj.graphicsId == 55, "Judge NPC should use scientist gfx (55)")

  -- 2. Verify Gen 3 Injections registered for Celadon Mansion 2F
  local condo2fInjections = HouseNpcs._gen3Injections["FR_CELADON_CITY_CONDOMINIUMS_2F"]
  assert(condo2fInjections ~= nil and #condo2fInjections >= 2, "Condo 2F must have at least 2 injections")
  local circuitObj, trackerObj = nil, nil
  for _, obj in ipairs(condo2fInjections) do
    if obj.name == "CELADONMANSION2F_BATTLE_CLUB" then circuitObj = obj end
    if obj.name == "CELADONMANSION2F_BEAST_TRACKER" then trackerObj = obj end
  end
  assert(circuitObj ~= nil, "Celadon Circuit must be injected on Condo 2F")
  assert(circuitObj.x == 2 and circuitObj.y == 7, "Celadon Circuit position should be (2, 7)")
  assert(circuitObj.graphicsId == 56, "Celadon Circuit should use hiker gfx (56)")

  assert(trackerObj ~= nil, "Beast Tracker must be injected on Condo 2F")
  assert(trackerObj.x == 1 and trackerObj.y == 8, "Beast Tracker position should be (1, 8)")
  assert(trackerObj.graphicsId == 89, "Beast Tracker should use super nerd gfx (89)")

  -- 3. Verify Gen 3 Injections registered for Celadon Mansion 3F
  local condo3fInjections = HouseNpcs._gen3Injections["FR_CELADON_CITY_CONDOMINIUMS_3F"]
  assert(condo3fInjections ~= nil and #condo3fInjections >= 1, "Condo 3F must have Blender NPC injected")
  local blenderObj = nil
  for _, obj in ipairs(condo3fInjections) do
    if obj.name == "CELADONMANSION3F_BLENDER" then blenderObj = obj break end
  end
  assert(blenderObj ~= nil, "Blender NPC must be injected on Condo 3F")
  assert(blenderObj.x == 2 and blenderObj.y == 7, "Blender NPC position should be (2, 7)")
  assert(blenderObj.graphicsId == 29, "Blender NPC should use beauty gfx (29)")

  -- 4. Test injectGen3 into mapDef
  local mockDef = { objects = {} }
  HouseNpcs.injectGen3("FR_UNDERGROUND_PATH_NORTH_ENTRANCE", mockDef)
  assert(#mockDef.objects >= 1, "injectGen3 must add objects to def.objects")
  assert(mockDef.objects[1].name == "UNDERGROUNDPATHROUTE5_JUDGE", "First object is Judge")

  -- 5. Test Judge Talk Handler in Gen 3
  local talkJudge = HouseNpcs._talks["TEXT_UNDERGROUNDPATHROUTE5_JUDGE"]
  assert(talkJudge ~= nil, "TEXT_UNDERGROUNDPATHROUTE5_JUDGE talk handler must exist")

  local mockGame = {
    save = {
      party = {
        {
          species = "PIKACHU",
          nickname = "SPARKY",
          level = 25,
          ivs = { hp = 31, atk = 31, def = 31, spe = 31, spa = 31, spd = 31 },
          evs = { hp = 0, atk = 252, def = 0, spe = 252, spa = 0, spd = 0 },
        },
      },
    },
    data = {
      pokemon = {
        PIKACHU = { name = "PIKACHU" },
      },
    },
  }

  local Choice = require("src.ui.game3.choice")
  local Message = require("src.ui.game3.message")
  local origShow = Message.show
  local lastMessage = nil
  Message.show = function(msg, cb)
    lastMessage = msg
    if cb then cb() end
  end

  local doneTalk = false
  talkJudge(mockGame, nil, nil, function() doneTalk = true end)

  assert(Choice.active == true, "Choice menu should be active for picking Pokémon")
  assert(#Choice.options == 2, "Options should be Sparky + CANCEL")

  -- Pick Sparky (option 1)
  Choice.confirm()
  assert(lastMessage ~= nil, "Judge should show message after evaluating Sparky")
  assert(lastMessage:find("SPARKY's potential:"), "Message contains Sparky's potential")
  assert(lastMessage:find("outstanding"), "Message contains outstanding for 31 IVs")
  assert(lastMessage:find("DARK"), "Message contains DARK for all-31 Hidden Power")

  Message.show = origShow

  -- 6. Move Hub injection at Mr. Psychic's
  local hubInjections = HouseNpcs._gen3Injections["FR_SAFFRON_CITY_MR_PSYCHICS_HOUSE"]
  assert(hubInjections ~= nil and #hubInjections >= 1, "Mr Psychic house must have Move Hub injection")
  local hubObj = nil
  for _, obj in ipairs(hubInjections) do
    if obj.name == "SAFFRONPIDGEYHOUSE_MOVE_HUB" then hubObj = obj break end
  end
  assert(hubObj ~= nil, "Move Hub NPC must be injected")
  assert(hubObj.x == 4 and hubObj.y == 4, "Move Hub Gen3 position should be (4, 4)")
  assert(HouseNpcs._talks["TEXT_SAFFRONPIDGEYHOUSE_MOVE_HUB"] ~= nil, "Move Hub talk handler registered")

  -- 7. Extra trades injections
  local route2 = HouseNpcs._gen3Injections["FR_ROUTE2_HOUSE"]
  assert(route2 ~= nil and #route2 >= 1, "Route2_House must have Taillow trade NPC")
  local taillowObj = nil
  for _, obj in ipairs(route2) do
    if obj.name == "ROUTE2TRADEHOUSE_TAILLOW" then taillowObj = obj break end
  end
  assert(taillowObj ~= nil, "Taillow trade NPC injected")
  assert(taillowObj.x == 6 and taillowObj.y == 6, "Taillow trade Gen3 position should be (6, 6) off the table")
  assert(HouseNpcs._talks["TEXT_ROUTE2TRADEHOUSE_TAILLOW"] ~= nil, "Taillow trade talk registered")

  local fuchsia = HouseNpcs._gen3Injections["FR_FUCHSIA_CITY_HOUSE1"]
  assert(fuchsia ~= nil and #fuchsia >= 1, "Fuchsia House1 must have Seedot trade NPC")
  local seedotObj = nil
  for _, obj in ipairs(fuchsia) do
    if obj.name == "FUCHSIABILLSGRANDPASHOUSE_SEEDOT" then seedotObj = obj break end
  end
  assert(seedotObj ~= nil, "Seedot trade NPC injected")
  assert(seedotObj.x == 4 and seedotObj.y == 4, "Seedot trade Gen3 position should be (4, 4) off the table")
  assert(HouseNpcs._talks["TEXT_FUCHSIABILLSGRANDPASHOUSE_SEEDOT"] ~= nil, "Seedot trade talk registered")

  local hotel = HouseNpcs._gen3Injections["FR_CELADON_CITY_HOTEL"]
    or HouseNpcs._gen3Injections["CELADON_HOTEL"]
  local snackObj = nil
  if hotel then
    for _, obj in ipairs(hotel) do
      if obj.name == "CELADONHOTEL_BERRY_SPECIALIST" then snackObj = obj break end
    end
  end
  assert(snackObj ~= nil, "Snack Scout must be injected on Celadon Hotel")
  assert(snackObj.x == 7 and snackObj.y == 6, "Snack Scout Gen3 position should be (7, 6) on lobby floor")

  local indigo = HouseNpcs._gen3Injections["FR_INDIGO_PLATEAU_POKEMON_CENTER_1F"]
  local eonObj = nil
  if indigo then
    for _, obj in ipairs(indigo) do
      if obj.name == "INDIGOPLATEAULOBBY_EON_WATCHER" then eonObj = obj break end
    end
  end
  assert(eonObj ~= nil, "Eon Watcher must be injected on Indigo PC")
  assert(eonObj.x == 8 and eonObj.y == 9, "Eon Watcher Gen3 position should be (8, 9)")

  -- 8. Item ID resolution for smith/club rewards
  assert(BerryFarmGame3.resolveNumericItemId("HEART_SCALE") == 111, "HEART_SCALE → 111")
  assert(BerryFarmGame3.resolveNumericItemId("CHOICE_BAND") == 186, "CHOICE_BAND → 186")
  assert(BerryFarmGame3.resolveNumericItemId("METAL_COAT") == 199, "METAL_COAT → 199")
  assert(BerryFarmGame3.resolveNumericItemId("NUGGET") == 110, "NUGGET → 110")
  assert(BerryFarmGame3.resolveNumericItemId("LIFE_ORB") == 200, "LIFE_ORB aliases to LEFTOVERS")
  assert(BerryFarmGame3.resolveNumericItemId("FOCUS_SASH") == 196, "FOCUS_SASH aliases to FOCUS_BAND")
  assert(BerryFarmGame3.resolveNumericItemId("BLACKGLASSES") == 206, "BLACKGLASSES → BLACK_GLASSES")

  local bagSave = { bag = { items = {} } }
  -- Soft bag mock: bagAdd falls back to inventory when Bag module unavailable / empty
  assert(BerryFarmGame3.bagAddItem(bagSave, "CHOICE_BAND", 1) == true, "bagAddItem CHOICE_BAND")
  assert(BerryFarmGame3.bagGetItemCount(bagSave, "CHOICE_BAND") >= 1
      or BerryFarmGame3.bagGetItemCount(bagSave, 186) >= 1
      or (bagSave.inventory and (bagSave.inventory[186] or 0) >= 1)
      or (bagSave.inventory and (bagSave.inventory.CHOICE_BAND or 0) >= 1),
    "CHOICE_BAND stored after add")

  -- Berry planting opens the FRLG pouch in plant mode so OmniUI can show the bag overlay.
  do
    local BerryPouch = require("src.ui.game3.berry_pouch")
    local captured = nil
    local origShow = BerryPouch.show
    BerryPouch.show = function(session, bag, opts)
      captured = opts
      BerryPouch.open = true
      BerryPouch._session = session
      BerryPouch._bag = bag
      BerryPouch._onClose = opts and opts.onClose
      BerryPouch._plantMode = opts and opts.plant and true or false
      BerryPouch._location = opts and opts.location
      BerryPouch.location = opts and opts.location
      if BerryPouch._plantMode then
        BerryPouch.ACTIONS = { "PLANT", "CANCEL" }
      end
    end
    local session = { bag = { pockets = { BERRY_POUCH = { { id = "ORAN_BERRY", qty = 2 } } } } }
    local opened = BerryFarmGame3.openPlantingBerryPouch(session, session.bag, function() end, function() end)
    assert(opened == true, "openPlantingBerryPouch uses native BerryPouch")
    assert(captured ~= nil, "BerryPouch.show was called")
    assert(captured.plant == true, "Planting pouch is opened with plant=true")
    assert(captured.location == "berry_tree", "Planting pouch location is berry_tree")
    assert(BerryPouch._plantMode == true, "Berry pouch plant mode is set for OmniUI")
    assert(BerryPouch.ACTIONS and BerryPouch.ACTIONS[1] == "PLANT", "Planting pouch exposes PLANT action")
    local okOmni, ModernOverlay = pcall(require, "mods.omni_ui.core.ModernOverlay")
    if okOmni and ModernOverlay and ModernOverlay.isSupported then
      assert(ModernOverlay.isSupported(BerryPouch) == "bag", "OmniUI treats planting pouch as bag, not a blank menu")
    end
    pcall(function() BerryPouch.close() end)
    BerryPouch.show = origShow
    BerryPouch.open = false
    BerryPouch._plantMode = false
    BerryPouch._location = nil
    BerryPouch.location = nil
    BerryPouch.ACTIONS = { "USE", "GIVE", "TOSS", "EXIT" }
  end

  -- Plant yes/no must hold the prompt so OmniUI does not flash a blank A-Close box.
  do
    local Message = require("src.ui.game3.message")
    local Choice = require("src.ui.game3.choice")
    local captured = nil
    local origShow = Message.show
    local origYesNo = Choice.yesNo
    local origClose = Message.close
    local closed = false
    Message.show = function(text, opts)
      captured = { text = text, opts = opts }
    end
    Choice.yesNo = function(cb)
      captured.choiceArmed = true
      if cb then cb(true) end
    end
    Message.close = function()
      closed = true
    end
    local answered = nil
    BerryFarmGame3.showYesNo({}, "plant?", function(yes) answered = yes end)
    assert(type(captured) == "table" and type(captured.opts) == "table", "showYesNo passes Message.show options")
    assert(captured.opts.hold == true, "plant yes/no holds the message while Choice is up")
    assert(type(captured.opts.done) == "function", "plant yes/no starts Choice after the prompt is ready")
    captured.opts.done()
    assert(captured.choiceArmed == true, "hold done opens YES/NO")
    assert(closed == true, "answering YES/NO closes the held message")
    assert(answered == true, "YES/NO result is forwarded")
    Message.show = origShow
    Choice.yesNo = origYesNo
    Message.close = origClose
  end

  Host.clearForce()
  print("✓ Gen 3 Utility NPCs tests passed!")
end

runTests()
