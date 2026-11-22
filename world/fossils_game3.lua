-- Hoenn Fossils (Root & Claw Fossil) + Cinnabar Lab Revival for FRLG in Kanto Reforged.
-- 1) Places Root Fossil in Five Island Lost Cave (Room 10).
-- 2) Places Claw Fossil in Four Island Icefall Cave (Back).
-- 3) Adds Hoenn fossil regeneration specialist in Cinnabar Lab Experiment Room
--    to revive Root Fossil -> Lileep (lv 20) and Claw Fossil -> Anorith (lv 20).

local FossilsGame3 = {}

FossilsGame3.ITEM_ROOT_FOSSIL = 286
FossilsGame3.ITEM_CLAW_FOSSIL = 287

FossilsGame3.SPECIES_LILEEP = 388   -- internal FRLG ID for Lileep
FossilsGame3.SPECIES_ANORITH = 390  -- internal FRLG ID for Anorith

FossilsGame3.MAP_LOST_CAVE = "FR_FIVE_ISLAND_LOST_CAVE_ROOM10"
FossilsGame3.MAP_LOST_CAVE_ALIAS = "FIVE_ISLAND_LOST_CAVE_ROOM10"
FossilsGame3.POS_ROOT = { x = 5, y = 5 }

FossilsGame3.MAP_ICEFALL_CAVE = "FR_FOUR_ISLAND_ICEFALL_CAVE_BACK"
FossilsGame3.MAP_ICEFALL_CAVE_ALIAS = "FOUR_ISLAND_ICEFALL_CAVE_BACK"
FossilsGame3.POS_CLAW = { x = 10, y = 7 }

FossilsGame3.MAP_CINNABAR_LAB = "FR_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM"
FossilsGame3.MAP_CINNABAR_LAB_ALIAS = "CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM"
FossilsGame3.POS_SCIENTIST = { x = 3, y = 4 }

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

local function showYesNo(game, msg, onChoice)
  local okM, Message = pcall(require, "src.ui.game3.message")
  local okC, Choice = pcall(require, "src.ui.game3.choice")
  if okM and Message and Message.show and okC and Choice and Choice.yesNo then
    Message.show(msg, function()
      Choice.yesNo(function(yes)
        if onChoice then onChoice(yes == true or yes == 0) end
      end)
    end)
    return
  end
  local okBox, TextBox = pcall(require, "src.render.TextBox")
  if okBox and TextBox and game and game.stack then
    game.stack:push(TextBox.new(game, msg, nil, { choice = onChoice }))
    return
  end
  if onChoice then onChoice(false) end
end

function FossilsGame3.interactRootFossil(game, mod, session)
  if mod and mod.save and mod.save:get("kr_got_root_fossil", false) then
    return
  end
  local Bag = require("src.core.game3.bag")
  local bag = (session and session.bag) or session
  Bag.add(bag, FossilsGame3.ITEM_ROOT_FOSSIL, 1)
  if mod and mod.save then
    mod.save:set("kr_got_root_fossil", true)
  end
  showMsg(game, "Found a ROOT FOSSIL!\n\nPut the ROOT FOSSIL in the KEY ITEMS pocket.")
end

function FossilsGame3.interactClawFossil(game, mod, session)
  if mod and mod.save and mod.save:get("kr_got_claw_fossil", false) then
    return
  end
  local Bag = require("src.core.game3.bag")
  local bag = (session and session.bag) or session
  Bag.add(bag, FossilsGame3.ITEM_CLAW_FOSSIL, 1)
  if mod and mod.save then
    mod.save:set("kr_got_claw_fossil", true)
  end
  showMsg(game, "Found a CLAW FOSSIL!\n\nPut the CLAW FOSSIL in the KEY ITEMS pocket.")
end

function FossilsGame3.reviveFossil(game, mod, session, fossilItem, speciesId, speciesName)
  local Bag = require("src.core.game3.bag")
  local Party = require("src.core.game3.party")
  local bag = (session and session.bag) or session

  Bag.remove(bag, fossilItem, 1)
  Party.giveMon(session, speciesId, 20, speciesName, { toPC = true })
  showMsg(game, string.format("The fossil regeneration process succeeded!\n\nReceived %s at Level 20!", speciesName))
end

function FossilsGame3.talkScientist(game, mod, session)
  local Bag = require("src.core.game3.bag")
  local bag = (session and session.bag) or session
  local hasRoot = Bag.has(bag, FossilsGame3.ITEM_ROOT_FOSSIL, 1)
  local hasClaw = Bag.has(bag, FossilsGame3.ITEM_CLAW_FOSSIL, 1)

  if hasRoot and hasClaw then
    showYesNo(game, "You have both Hoenn fossils!\nRevive the ROOT FOSSIL into LILEEP?\n(Say NO to revive CLAW FOSSIL instead)", function(yes)
      if yes then
        FossilsGame3.reviveFossil(game, mod, session, FossilsGame3.ITEM_ROOT_FOSSIL, FossilsGame3.SPECIES_LILEEP, "LILEEP")
      else
        showYesNo(game, "Revive the CLAW FOSSIL into ANORITH?", function(reviveClaw)
          if reviveClaw then
            FossilsGame3.reviveFossil(game, mod, session, FossilsGame3.ITEM_CLAW_FOSSIL, FossilsGame3.SPECIES_ANORITH, "ANORITH")
          else
            showMsg(game, "Very well. Let me know when you are ready to resurrect your fossil.")
          end
        end)
      end
    end)
    return
  end

  if hasRoot then
    showYesNo(game, "Ah! You brought a ROOT FOSSIL from Hoenn!\nWould you like me to regenerate it into a LILEEP?", function(yes)
      if yes then
        FossilsGame3.reviveFossil(game, mod, session, FossilsGame3.ITEM_ROOT_FOSSIL, FossilsGame3.SPECIES_LILEEP, "LILEEP")
      else
        showMsg(game, "Understood. The fossil will be here whenever you wish to revive it.")
      end
    end)
    return
  end

  if hasClaw then
    showYesNo(game, "Ah! You brought a CLAW FOSSIL from Hoenn!\nWould you like me to regenerate it into an ANORITH?", function(yes)
      if yes then
        FossilsGame3.reviveFossil(game, mod, session, FossilsGame3.ITEM_CLAW_FOSSIL, FossilsGame3.SPECIES_ANORITH, "ANORITH")
      else
        showMsg(game, "Understood. The fossil will be here whenever you wish to revive it.")
      end
    end)
    return
  end

  showMsg(game, "I am a researcher studying ancient Hoenn fossils!\n\n"
    .. "Legend says a ROOT FOSSIL rests deep inside\n"
    .. "the deceptive chambers of Lost Cave,\n"
    .. "and a CLAW FOSSIL is frozen within Icefall Cave.\n\n"
    .. "If you discover either, bring it here\n"
    .. "and I can resurrect it into a living Pokémon!")
end

function FossilsGame3.register(mod)
  FossilsGame3._mod = mod
  local okData, Data = pcall(require, "src.core.Data")
  if not (okData and Data and Data.maps) then return end

  -- 1. Lost Cave Root Fossil object
  local rootObj = {
    index = 91,
    localId = 91,
    name = "LOST_CAVE_ROOT_FOSSIL",
    sprite = "SPRITE_FOSSIL",
    graphicsId = 98, -- OBJ_EVENT_GFX_FOSSIL
    graphics = 98,
    movementType = 0,
    movement = "STAY",
    range = "NONE",
    scriptKey = "TEXT_LOST_CAVE_ROOT_FOSSIL",
    text = "TEXT_LOST_CAVE_ROOT_FOSSIL",
    elevation = 3,
    x = FossilsGame3.POS_ROOT.x,
    y = FossilsGame3.POS_ROOT.y,
  }
  for _, mKey in ipairs({ FossilsGame3.MAP_LOST_CAVE, FossilsGame3.MAP_LOST_CAVE_ALIAS }) do
    if Data.maps[mKey] then
      Data.maps[mKey].objects = Data.maps[mKey].objects or {}
      table.insert(Data.maps[mKey].objects, rootObj)
    end
  end

  -- 2. Icefall Cave Claw Fossil object
  local clawObj = {
    index = 92,
    localId = 92,
    name = "ICEFALL_CAVE_CLAW_FOSSIL",
    sprite = "SPRITE_FOSSIL",
    graphicsId = 98, -- OBJ_EVENT_GFX_FOSSIL
    graphics = 98,
    movementType = 0,
    movement = "STAY",
    range = "NONE",
    scriptKey = "TEXT_ICEFALL_CAVE_CLAW_FOSSIL",
    text = "TEXT_ICEFALL_CAVE_CLAW_FOSSIL",
    elevation = 3,
    x = FossilsGame3.POS_CLAW.x,
    y = FossilsGame3.POS_CLAW.y,
  }
  for _, mKey in ipairs({ FossilsGame3.MAP_ICEFALL_CAVE, FossilsGame3.MAP_ICEFALL_CAVE_ALIAS }) do
    if Data.maps[mKey] then
      Data.maps[mKey].objects = Data.maps[mKey].objects or {}
      table.insert(Data.maps[mKey].objects, clawObj)
    end
  end

  -- 3. Cinnabar Lab Hoenn Scientist object
  local scientistObj = {
    index = 93,
    localId = 93,
    name = "CINNABAR_HOENN_FOSSIL_SCIENTIST",
    sprite = "SPRITE_SCIENTIST",
    graphicsId = 55, -- OBJ_EVENT_GFX_SCIENTIST
    graphics = 55,
    movementType = 8,
    movement = "LOOK_AROUND",
    range = "DOWN",
    scriptKey = "TEXT_CINNABAR_HOENN_FOSSIL_SCIENTIST",
    text = "TEXT_CINNABAR_HOENN_FOSSIL_SCIENTIST",
    elevation = 3,
    x = FossilsGame3.POS_SCIENTIST.x,
    y = FossilsGame3.POS_SCIENTIST.y,
  }
  for _, mKey in ipairs({ FossilsGame3.MAP_CINNABAR_LAB, FossilsGame3.MAP_CINNABAR_LAB_ALIAS }) do
    if Data.maps[mKey] then
      Data.maps[mKey].objects = Data.maps[mKey].objects or {}
      table.insert(Data.maps[mKey].objects, scientistObj)
    end
  end
end

function FossilsGame3.install(mod)
  FossilsGame3._mod = mod
  FossilsGame3.register(mod)

  local okFld, Field = pcall(require, "src.core.game3.field")
  if okFld and Field and Field.interact and not Field._fossilsInteractWrapped then
    local origInteract = Field.interact
    Field.interact = function(game)
      game = game or Field._game
      local session = (game and game.session) or Field._session
      local curMap = (session and session.map)
      local Map = package.loaded["src.core.game3.map"]
      curMap = curMap or (Map and Map.current)

      local P = package.loaded["src.core.game3.player"]
      if P and not P.moving then
        local fx, fy
        if P.facing == "up" then fx, fy = P.cellX, P.cellY - 1
        elseif P.facing == "down" then fx, fy = P.cellX, P.cellY + 1
        elseif P.facing == "left" then fx, fy = P.cellX - 1, P.cellY
        elseif P.facing == "right" then fx, fy = P.cellX + 1, P.cellY
        end

        if (curMap == FossilsGame3.MAP_LOST_CAVE or curMap == FossilsGame3.MAP_LOST_CAVE_ALIAS)
            and fx == FossilsGame3.POS_ROOT.x and fy == FossilsGame3.POS_ROOT.y then
          FossilsGame3.interactRootFossil(game, mod, session)
          return true
        end

        if (curMap == FossilsGame3.MAP_ICEFALL_CAVE or curMap == FossilsGame3.MAP_ICEFALL_CAVE_ALIAS)
            and fx == FossilsGame3.POS_CLAW.x and fy == FossilsGame3.POS_CLAW.y then
          FossilsGame3.interactClawFossil(game, mod, session)
          return true
        end

        if (curMap == FossilsGame3.MAP_CINNABAR_LAB or curMap == FossilsGame3.MAP_CINNABAR_LAB_ALIAS)
            and fx == FossilsGame3.POS_SCIENTIST.x and fy == FossilsGame3.POS_SCIENTIST.y then
          FossilsGame3.talkScientist(game, mod, session)
          return true
        end
      end

      return origInteract(game)
    end
    Field._fossilsInteractWrapped = true
  end
end

return FossilsGame3
