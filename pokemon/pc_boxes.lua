-- Expand Bill's PC for National Dex (#1–386).
--
-- Engine note: constants.boxCount / boxSize are seeded in Gen1 Data but
-- Boxes.lua never reads them (COUNT/CAPACITY are module fields). Gen2 has
-- no constants equivalent — Save.NUM_BOXES / Boxes.NUM_BOXES are hardcoded.
-- Same pattern as bag_pockets: mutate the live module fields.

local PcBoxes = {}

-- 24 × 20 = 480 slots (vanilla Gen1 12×20=240, Gen2 14×20=280).
-- Living dex needs ceil(386/20)=20; extras for breeding / duplicates.
PcBoxes.COUNT = 24
PcBoxes.CAPACITY = 20

local applied = false
local gen1UiInstalled = false

local function growBoxes(save, count)
  if not save then return end
  save.boxes = save.boxes or {}
  for i = 1, count do
    save.boxes[i] = save.boxes[i] or {}
  end
  save.currentBox = math.max(1, math.min(count, save.currentBox or 1))
end

local function wrapEnsure(Boxes)
  if not Boxes or Boxes._krExpandedEnsure then return end
  local origEnsure = Boxes.ensure
  if type(origEnsure) ~= "function" then return end
  Boxes._krExpandedEnsure = true
  function Boxes.ensure(save)
    local boxes = origEnsure(save)
    growBoxes(save, PcBoxes.COUNT)
    return save.boxes or boxes
  end
end

function PcBoxes.applyGen1(mod)
  local Boxes = require("src.pokemon.Boxes")
  Boxes.COUNT = PcBoxes.COUNT
  Boxes.CAPACITY = PcBoxes.CAPACITY

  -- Existing saves already have save.boxes; vanilla ensure() only allocates
  -- when the table is nil. Grow in place after COUNT is raised.
  wrapEnsure(Boxes)

  if mod and mod.content and mod.content.constants then
    pcall(function()
      mod.content.constants:patch("boxCount", PcBoxes.COUNT)
      mod.content.constants:patch("boxSize", PcBoxes.CAPACITY)
    end)
  end
end

function PcBoxes.applyGen2(mod)
  local Save = require("src.core.gen2.Save")
  local Boxes2 = require("src.core.gen2.Boxes")
  Save.NUM_BOXES = PcBoxes.COUNT
  Boxes2.NUM_BOXES = PcBoxes.COUNT
  Boxes2.MONS_PER_BOX = PcBoxes.CAPACITY

  -- Facade copies COUNT once; keep it in sync. require() is remapped in the
  -- mod sandbox to the Gen2Compat adapter (COUNT / NUM_BOXES / ensure).
  local Boxes = require("src.pokemon.Boxes")
  Boxes.COUNT = PcBoxes.COUNT
  Boxes.CAPACITY = PcBoxes.CAPACITY
  if Boxes.NUM_BOXES then Boxes.NUM_BOXES = PcBoxes.COUNT end
  if Boxes.MONS_PER_BOX then Boxes.MONS_PER_BOX = PcBoxes.CAPACITY end
  wrapEnsure(Boxes)
end

-- Gen1 CHANGE BOX is a fixed 12-row Menu (th=14). With COUNT>12 it must
-- scroll; Gen2 PcMenu already scrolls over NUM_BOXES.
function PcBoxes.installGen1ChangeBoxUi()
  if gen1UiInstalled then return end
  gen1UiInstalled = true

  local BoxMenu = require("src.ui.BoxMenu")
  local Menu = require("src.ui.Menu")
  local TextBox = require("src.render.TextBox")
  local Font = require("src.render.Font")
  local ListMenu = require("src.ui.ListMenu")
  local Strings = require("src.core.Strings")
  local Boxes = require("src.pokemon.Boxes")
  local Sound = require("src.core.Sound")

  local VISIBLE = 12

  local function changeBoxMenu(game)
    local boxes = Boxes.ensure(game.save)
    local items = {}
    for i = 1, Boxes.COUNT do
      items[i] = {
        label = Strings("BOX%2d", i),
        onSelect = function()
          game.save.currentBox = i
          if game.writeSave then game:writeSave() end
          Sound.play(game.data, "Save")
        end,
      }
    end
    local menu = Menu.new(game, items, {
      tx = 11, ty = 0, tw = 9, th = 14, rowStep = 1, itemY = 1,
      maxVisible = VISIBLE, noSound = true,
    })
    menu.kind = "pc_box_change"
    menu.index = math.max(1, math.min(Boxes.COUNT, game.save.currentBox or 1))
    if menu.clampScroll then menu:clampScroll() end
    local t = game.data.text
    local baseDraw = menu.draw
    function menu:draw()
      Font.drawBox(0, 12, 20, 6)
      love.graphics.setColor(0, 0, 0, 1)
      local y = 112
      for line in ((t._ChooseABoxText or Strings("Choose a\nPOKéMON BOX."))
                   .. "\n"):gmatch("([^\n]*)\n") do
        Font.draw(line, 8, y)
        y = y + 16
      end
      Font.drawBox(0, 0, 11, 4)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(Strings("BOX No."), 8, 16)
      local n = game.save.currentBox or 1
      Font.draw(tostring(n), n >= 10 and 64 or 72, 16)
      baseDraw(self)
      love.graphics.setColor(0, 0, 0, 1)
      local scroll = self.scroll or 0
      local rows = self.maxVisible or VISIBLE
      for row = 1, rows do
        local i = scroll + row
        if boxes[i] and #boxes[i] > 0 then
          ListMenu.drawBall(148, row * 8 + 4)
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
    end
    game.stack:push(menu)
  end

  local function changeBox(game)
    local t = game.data.text
    local ask = TextBox.new(game, t._WhenYouChangeBoxText
      or Strings("When you change a\nPOKéMON BOX, data\vwill be saved.\fIs that okay?"),
      nil, {
      noSound = true,
      choice = function(yes)
        if yes then changeBoxMenu(game) end
      end,
    })
    ask.kind = "pc_box_change"
    game.stack:push(ask)
  end

  local origNew = BoxMenu.new
  function BoxMenu.new(game)
    local menu = origNew(game)
    for _, item in ipairs(menu.items or {}) do
      local label = item.label or ""
      if type(label) == "string" and label:find("CHANGE BOX", 1, true) then
        item.onSelect = function() changeBox(game) end
        break
      end
    end
    return menu
  end
end

function PcBoxes.apply(mod)
  if applied then return end
  applied = true
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2From(mod) or Host.isGen2() then
    PcBoxes.applyGen2(mod)
  else
    PcBoxes.applyGen1(mod)
    PcBoxes.installGen1ChangeBoxUi()
  end
  if mod and mod.log then
    mod.log:info("PC boxes expanded to %d × %d (%d slots)",
      PcBoxes.COUNT, PcBoxes.CAPACITY, PcBoxes.COUNT * PcBoxes.CAPACITY)
  end
end

--- Grow an existing save after COUNT was raised (call on game.ready).
function PcBoxes.growSave(save)
  if not save then return end
  growBoxes(save, PcBoxes.COUNT)
end

return PcBoxes
