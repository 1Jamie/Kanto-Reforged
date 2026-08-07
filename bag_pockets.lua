-- Bag pockets + larger capacity for Kanto Reforged.
-- Keeps flat save.inventory; filters Bag.order while the bag is open so the
-- stock BagMenu USE/TOSS flows keep working.

local ItemEffects = require("src.inventory.ItemEffects")
local HeldItems = require("mods.Kanto-Reforged.held_items")
local Bag = require("src.inventory.Bag")
local Strings = require("src.core.Strings")

local BagPockets = {}

BagPockets.CAPACITY = 60

BagPockets.POCKETS = {
  { id = "items",   label = "ITEMS" },
  { id = "balls",   label = "BALLS" },
  { id = "key",     label = "KEY ITEMS" },
  { id = "tmhm",    label = "TMs & HMs" },
  { id = "berries", label = "BERRIES" },
}

local pocketIndex = 1
local filterActive = false
local originalOrder

function BagPockets.current()
  return BagPockets.POCKETS[pocketIndex]
end

function BagPockets.classify(id, def)
  if not id then return "items" end
  if HeldItems.isBerry(id) then return "berries" end
  if def and def.machine then return "tmhm" end
  if type(id) == "string" and (id:find("^TM_") or id:find("^HM_")) then
    return "tmhm"
  end
  if def and def.keyItem then return "key" end
  if ItemEffects.isBall(id) then return "balls" end
  if def and def.ball then return "balls" end
  return "items"
end

function BagPockets.matches(id, data, pocketId)
  pocketId = pocketId or BagPockets.current().id
  local def = data and data.items and data.items[id]
  return BagPockets.classify(id, def) == pocketId
end

function BagPockets.cycle(delta)
  local n = #BagPockets.POCKETS
  pocketIndex = ((pocketIndex - 1 + delta) % n) + 1
end

function BagPockets.setIndex(i)
  pocketIndex = math.max(1, math.min(#BagPockets.POCKETS, i or 1))
end

local function rebuildRows(game)
  local items = {}
  for _, id in ipairs(Bag.order(game.save)) do
    local def = game.data.items[id]
    items[#items + 1] = {
      value = id,
      label = def and def.name or id,
      right = "x" .. tostring(game.save.inventory[id]),
    }
  end
  return items
end

function BagPockets.register(mod)
  Bag.CAPACITY = BagPockets.CAPACITY
  mod.content.constants:patch("bagSize", BagPockets.CAPACITY)

  if not originalOrder then
    originalOrder = Bag.order
    Bag.order = function(save)
      local order = originalOrder(save)
      if not filterActive then return order end
      -- game pointer is stashed on the wrap so we can read item defs
      local data = BagPockets._data
      local pocketId = BagPockets.current().id
      local filtered = {}
      for _, id in ipairs(order) do
        if BagPockets.matches(id, data, pocketId) then
          filtered[#filtered + 1] = id
        end
      end
      return filtered
    end
  end

  mod.content.screens:register("BagMenu", {
    new = function(game, opts)
      BagPockets._data = game.data
      filterActive = true
      BagPockets.setIndex(pocketIndex)

      local Builtin = require("src.ui.BagMenu")
      local list = Builtin.new(game, opts)
      list.title = BagPockets.current().label
      -- SELECT reorder is ambiguous across filtered views; leave unused.
      list.onSelectKey = nil

      local baseUpdate = list.update
      function list:update(dt)
        local input = self.game.input
        if input:wasPressed("left") then
          BagPockets.cycle(-1)
          self.title = BagPockets.current().label
          self.items = rebuildRows(game)
          self.index = 1
          self.scroll = 0
          self.swapIndex = nil
          return
        elseif input:wasPressed("right") then
          BagPockets.cycle(1)
          self.title = BagPockets.current().label
          self.items = rebuildRows(game)
          self.index = 1
          self.scroll = 0
          self.swapIndex = nil
          return
        end
        baseUpdate(self, dt)
      end

      local baseClose = list.close
      function list:close()
        filterActive = false
        if baseClose then return baseClose(self) end
        self.game.stack:pop()
      end

      -- B / empty-list cancel path pops without close(); clear filter there too.
      local baseOnCancel = list.onCancel
      list.onCancel = function()
        filterActive = false
        if baseOnCancel then baseOnCancel() end
      end

      local baseDraw = list.draw
      function list:draw()
        baseDraw(self)
        -- Tiny pocket hint under the money line (left/right).
        love.graphics.setColor(0, 0, 0, 1)
        local Font = require("src.render.Font")
        Font.draw(Strings("< >"), 8, 128)
        love.graphics.setColor(1, 1, 1, 1)
      end

      return list
    end,
  })

  mod.log:info("Bag pockets enabled (capacity %d)", BagPockets.CAPACITY)
end

-- Tests / callers can force the filter off.
function BagPockets._resetFilter()
  filterActive = false
end

return BagPockets
