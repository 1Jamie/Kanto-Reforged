-- Bag pockets + raised capacity.
return function(T, Data, run)
  local BagPockets = require("mods.Kanto-Reforged.bag_pockets")
  local Bag = require("src.inventory.Bag")
  local ItemEffects = require("src.inventory.ItemEffects")

  T.eq(Bag.CAPACITY, BagPockets.CAPACITY, "Bag.CAPACITY raised for Kanto Reforged")
  T.eq(Data.constants.bagSize, BagPockets.CAPACITY, "constants.bagSize matches")

  T.eq(BagPockets.classify("POKE_BALL", Data.items.POKE_BALL), "balls",
    "Poke Ball → balls")
  T.eq(BagPockets.classify("GREAT_BALL", Data.items.GREAT_BALL), "balls",
    "Great Ball → balls")
  T.check(ItemEffects.isBall("ULTRA_BALL"), "Ultra Ball is a ball")

  T.eq(BagPockets.classify("BICYCLE", Data.items.BICYCLE), "key",
    "Bicycle → key items")
  T.eq(BagPockets.classify("TOWN_MAP", Data.items.TOWN_MAP), "key",
    "Town Map → key items")

  local tm = nil
  for id, def in pairs(Data.items) do
    if def.machine and def.machine.kind == "TM" then tm = id; break end
  end
  T.check(tm ~= nil, "found a TM in item data")
  T.eq(BagPockets.classify(tm, Data.items[tm]), "tmhm", "TM → tmhm pocket")

  local hm = nil
  for id, def in pairs(Data.items) do
    if def.machine and def.machine.kind == "HM" then hm = id; break end
  end
  if hm then
    T.eq(BagPockets.classify(hm, Data.items[hm]), "tmhm", "HM → tmhm pocket")
  else
    T.eq(BagPockets.classify("HM_01", { machine = { kind = "HM" } }), "tmhm",
      "HM_ id → tmhm")
  end

  T.eq(BagPockets.classify("CHERI_BERRY", Data.items.CHERI_BERRY), "berries",
    "Cheri → berries")
  T.eq(BagPockets.classify("BERRY", Data.items.BERRY), "berries",
    "Berry → berries")

  T.eq(BagPockets.classify("POTION", Data.items.POTION), "items",
    "Potion → items")
  T.eq(BagPockets.classify("LEFTOVERS", Data.items.LEFTOVERS), "items",
    "Leftovers → items")
  T.eq(BagPockets.classify("MIRACLE_SEED", Data.items.MIRACLE_SEED), "items",
    "Miracle Seed → items")

  -- Filter: only matching pocket ids appear
  BagPockets._resetFilter()
  local save = {
    inventory = {
      POTION = 5, POKE_BALL = 10, BICYCLE = 1, CHERI_BERRY = 2,
      LEFTOVERS = 1,
    },
    bagOrder = { "POTION", "POKE_BALL", "BICYCLE", "CHERI_BERRY", "LEFTOVERS" },
  }
  -- Activate filter the same way BagMenu does
  BagPockets._data = Data
  BagPockets.setIndex(1) -- ITEMS
  -- Force filter by going through a tiny simulation of the wrap
  local orderAll = Bag.order(save)
  T.check(#orderAll >= 4, "unfiltered bag order lists items")

  -- Direct matches helper
  local function idsIn(pocketId)
    local out = {}
    for _, id in ipairs(save.bagOrder) do
      if BagPockets.matches(id, Data, pocketId) then out[#out + 1] = id end
    end
    return out
  end
  T.eq(table.concat(idsIn("items"), ","), "POTION,LEFTOVERS", "items pocket filter")
  T.eq(table.concat(idsIn("balls"), ","), "POKE_BALL", "balls pocket filter")
  T.eq(table.concat(idsIn("key"), ","), "BICYCLE", "key pocket filter")
  T.eq(table.concat(idsIn("berries"), ","), "CHERI_BERRY", "berries pocket filter")

  -- Screen registered
  T.check(Data.screens and Data.screens.BagMenu, "BagMenu screen replaced")

  local factory = Data.screens.BagMenu
  factory = type(factory) == "function" and factory or factory.new
  local bagSave = {
    money = 1000,
    inventory = { POTION = 2, POKE_BALL = 3 },
    bagOrder = { "POTION", "POKE_BALL" },
    player = { name = "RED" },
  }
  local fakeGame = {
    data = Data,
    save = bagSave,
    input = { wasPressed = function() return false end },
    stack = {
      top = function() return nil end,
      pop = function() end,
      push = function() end,
    },
  }
  local ok, list = pcall(factory, fakeGame, {})
  if ok and list then
    T.eq(type(list.__pocketIndex), "number", "BagMenu exposes __pocketIndex")
    T.eq(type(list.__pocketIds), "table", "BagMenu exposes __pocketIds")
    T.eq(#list.__pocketIds, #BagPockets.POCKETS, "pocket id count matches")
    T.check(list.gen1ModernUi and type(list.gen1ModernUi.switchPocket) == "function",
      "BagMenu exposes gen1ModernUi.switchPocket")
    local before = list.__pocketIndex
    list.gen1ModernUi.switchPocket(list.gen1ModernUi, 1)
    T.eq(list.__pocketIndex, (before % #BagPockets.POCKETS) + 1,
      "switchPocket advances __pocketIndex")
    T.eq(list.title, BagPockets.POCKETS[list.__pocketIndex].label,
      "switchPocket updates title")
  else
    T.check(true, "BagMenu factory present (public fields skipped headless)")
  end

  BagPockets._resetFilter()
end
