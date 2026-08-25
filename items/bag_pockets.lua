-- Bag pockets + larger capacity for Kanto Reforged (fallback when
-- gen1_bag_pockets is not installed). Keeps flat save.inventory; filters
-- Bag.order while the bag is open so stock BagMenu USE/TOSS flows keep working.
--
-- When gen1_bag_pockets is present, main.lua skips register and only applies
-- capacity on Gen2 plus a BAG GIVE decorator on the bag mod's export.

local ItemEffects = require("src.inventory.ItemEffects")
local HeldItems = require("mods.Kanto-Reforged.items.held_items")
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

local function pocketIds()
  local ids = {}
  for _, pocket in ipairs(BagPockets.POCKETS) do
    ids[#ids + 1] = pocket.id
  end
  return ids
end

function BagPockets.current()
  return BagPockets.POCKETS[pocketIndex]
end

-- Native Gen1 header aligned with LIST_MENU_BOX (tx=4, tw=16).
local HEADER_X, HEADER_W, HEADER_H, HEADER_Y = 32, 128, 16, 8

local function drawCycleArrow(code, x, y, flip)
  if flip then
    love.graphics.push()
    love.graphics.translate(x + 8, y)
    love.graphics.scale(-1, 1)
    require("src.render.Font").drawCode(code, 0, 0)
    love.graphics.pop()
  else
    require("src.render.Font").drawCode(code, x, y)
  end
end

function BagPockets.drawNativeHeader()
  local Font = require("src.render.Font")
  local Theme = require("src.ui.Theme")
  local label = Strings(BagPockets.current().label)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", HEADER_X, 0, HEADER_W, HEADER_H)

  love.graphics.setColor(0, 0, 0, 1)
  local arrowW, gap = 8, 4
  local labelW = Font.width(label)
  local groupW = arrowW + gap + labelW + gap + arrowW
  local x = HEADER_X + math.floor((HEADER_W - groupW) / 2)

  drawCycleArrow(Theme.cursor, x, HEADER_Y, true)
  Font.draw(label, x + arrowW + gap, HEADER_Y)
  drawCycleArrow(Theme.cursor, x + arrowW + gap + labelW + gap, HEADER_Y, false)

  love.graphics.setColor(1, 1, 1, 1)
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
    local unsellable = (def and def.keyItem) or (type(id) == "string" and id:find("^HM_") ~= nil)
    items[#items + 1] = {
      value = id,
      label = def and def.name or id,
      right = (not unsellable) and ("x" .. tostring(game.save.inventory[id])) or nil,
    }
  end
  items[#items + 1] = { cancel = true, label = Strings("CANCEL") }
  return items
end

local function syncScroll(list)
  local rows = list.rows or 7
  if list.index - list.scroll > rows then
    list.scroll = list.index - rows
  end
  if list.index - list.scroll < 1 then
    list.scroll = list.index - 1
  end
end

local function realBagOrder(save)
  local was = filterActive
  filterActive = false
  local order = originalOrder and originalOrder(save) or Bag.order(save)
  filterActive = was
  return order
end

local function completeSwap(game, list)
  local iA, iB = list.swapIndex, list.index
  list.swapIndex = nil
  if not iA or not iB or iA == iB then return end
  local itemA = list.items[iA]
  local itemB = list.items[iB]
  if not itemA or itemA.cancel or not itemB or itemB.cancel then return end
  local idA, idB = itemA.value, itemB.value
  if not idA or not idB then return end

  local order = realBagOrder(game.save)
  local posA, posB
  for i, id in ipairs(order) do
    if id == idA then posA = i end
    if id == idB then posB = i end
  end
  if not posA or not posB or posA == posB then return end
  order[posA], order[posB] = order[posB], order[posA]
  require("src.core.Sound").play(game.data, "Swap")
  list.items = rebuildRows(game)
end

local function installSelectKey(list, game)
  if BagPockets.current().id == "tmhm" then
    list.onSelectKey = nil
    return
  end
  list.onSelectKey = function(item, l)
    if BagPockets.current().id == "tmhm" then return end
    if not item or item.cancel then return end
    if not l.swapIndex then
      l.swapIndex = l.index
      return
    end
    completeSwap(game, l)
  end
end

local function installSwapOnChoose(list, game)
  if list.__bagPocketsSwapWrapped then return end
  list.__bagPocketsSwapWrapped = true
  local baseOnChoose = list.onChoose
  list.onChoose = function(item, ...)
    if list.swapIndex then
      if item and item.cancel then
        if baseOnChoose then return baseOnChoose(item, ...) end
        return
      end
      if BagPockets.current().id ~= "tmhm" then
        completeSwap(game, list)
        return
      end
      list.swapIndex = nil
    end
    if baseOnChoose then return baseOnChoose(item, ...) end
  end
end

local function applyPocket(list, game, delta)
  BagPockets.cycle(delta or 0)
  list.title = BagPockets.current().label
  list.items = rebuildRows(game)
  list.index = 1
  list.scroll = 0
  list.swapIndex = nil
  list.__pocketIndex = pocketIndex
  list.__pocketIds = pocketIds()
  installSelectKey(list, game)
end

local function getTmHmSortInfo(id, def)
  local kind = nil
  local number = nil

  if def and def.machine then
    kind = def.machine.kind or def.machine.type
    if def.machine.number then
      number = tonumber(def.machine.number)
    elseif def.machine.num then
      number = tonumber(def.machine.num)
    elseif def.machine.id then
      number = tonumber(def.machine.id)
    end
  end

  if not kind and type(id) == "string" then
    local k, numStr = id:match("^(T[M])_?(%d+)")
    if not k then
      k, numStr = id:match("^(H[M])_?(%d+)")
    end
    if k and numStr then
      kind = k
      number = tonumber(numStr)
    end
  end

  if not kind and def and type(def.name) == "string" then
    local k, numStr = def.name:match("^(T[M])%s*_?(%d+)")
    if not k then
      k, numStr = def.name:match("^(H[M])%s*_?(%d+)")
    end
    if k and numStr then
      kind = k
      number = tonumber(numStr)
    end
  end

  if not number and type(id) == "string" then
    number = tonumber(id:match("(%d+)"))
  end

  kind = (kind and tostring(kind):upper()) or "TM"
  number = number or 999

  local groupOrder = (kind == "TM") and 1 or 2
  return groupOrder, number
end

function BagPockets.applyCapacity(mod)
  Bag.CAPACITY = BagPockets.CAPACITY
  mod.content.constants:patch("bagSize", BagPockets.CAPACITY)
end

function BagPockets.register(mod)
  BagPockets.applyCapacity(mod)

  if not originalOrder then
    originalOrder = Bag.order
    Bag.order = function(save)
      local order = originalOrder(save)
      if not filterActive then return order end
      local data = BagPockets._data
      local pocketId = BagPockets.current().id
      local filtered = {}
      for _, id in ipairs(order) do
        if BagPockets.matches(id, data, pocketId) then
          filtered[#filtered + 1] = id
        end
      end

      if pocketId == "tmhm" then
        table.sort(filtered, function(a, b)
          local defA = data and data.items and data.items[a]
          local defB = data and data.items and data.items[b]
          local groupA, numA = getTmHmSortInfo(a, defA)
          local groupB, numB = getTmHmSortInfo(b, defB)
          if groupA ~= groupB then
            return groupA < groupB
          end
          if numA ~= numB then
            return numA < numB
          end
          return a < b
        end)
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
      installSwapOnChoose(list, game)
      installSelectKey(list, game)
      HeldItems.decorateBagMenu(mod, game, list, opts)

      list.__pocketIndex = pocketIndex
      list.__pocketIds = pocketIds()
      list.gen1ModernUi = {
        moveCursor = function(_, delta)
          local n = #list.items
          if n == 0 then return false end
          list.index = math.max(1, math.min(n, (list.index or 1) + (delta or 0)))
          syncScroll(list)
          return true
        end,
        switchPocket = function(_, delta)
          applyPocket(list, game, delta or 0)
          return true
        end,
        select = function(_)
          local item = list.items[list.index]
          if list.onChoose then
            return list.onChoose(item, list)
          end
          return false
        end,
        back = function(_)
          if list.game.stack:top() == list then
            list.game.stack:pop()
          end
          if list.onCancel then list.onCancel() end
          return true
        end,
      }

      local baseUpdate = list.update
      function list:update(dt)
        local input = self.game.input
        if input:wasPressed("left") then
          applyPocket(self, game, -1)
          return
        elseif input:wasPressed("right") then
          applyPocket(self, game, 1)
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

      local baseOnCancel = list.onCancel
      list.onCancel = function()
        filterActive = false
        if baseOnCancel then baseOnCancel() end
      end

      local baseDraw = list.draw
      function list:draw()
        BagPockets.drawNativeHeader()
        baseDraw(self)
      end

      return list
    end,
  })

  mod.log:info("Bag pockets enabled (capacity %d)", BagPockets.CAPACITY)
end

function BagPockets._resetFilter()
  filterActive = false
end

return BagPockets
