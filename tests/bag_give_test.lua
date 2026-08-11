-- BAG GIVE option: holdables get USE/GIVE/TOSS from the bag menu.
return function(T, Data, run)
  local HeldItems = require("mods.Kanto-Reforged.held_items")
  local Pokemon = require("src.pokemon.Pokemon")
  local Menu = require("src.ui.Menu")
  local BagPockets = require("mods.Kanto-Reforged.bag_pockets")
  local Strings = require("src.core.Strings")

  local schema = run.loader.optionSchemas["Kanto-Reforged"]
  local bagGiveOpt
  for _, opt in ipairs(schema or {}) do
    if opt.key == HeldItems.BAG_GIVE_KEY then bagGiveOpt = opt break end
  end
  T.check(bagGiveOpt ~= nil, "BAG GIVE option schema registered")
  T.eq(bagGiveOpt.type, "toggle", "BAG GIVE is a toggle")
  T.eq(bagGiveOpt.default, true, "BAG GIVE defaults on")

  local opts = run.loader.modOptions["Kanto-Reforged"] or {}
  run.loader.modOptions["Kanto-Reforged"] = opts
  local saved = opts[HeldItems.BAG_GIVE_KEY]

  -- giveToMon swaps + consumes bag stock
  do
    local mon = Pokemon.new(Data, "PIKACHU", 20)
    mon.heldItem = "MIRACLE_SEED"
    local game = {
      data = Data,
      save = {
        inventory = { LEFTOVERS = 1, MIRACLE_SEED = 0 },
        bagOrder = { "LEFTOVERS" },
      },
    }
    local ok, err, prev = HeldItems.giveToMon(game, mon, "LEFTOVERS")
    T.eq(ok, true, "giveToMon succeeds")
    T.eq(err, nil, "giveToMon no error")
    T.eq(prev, "MIRACLE_SEED", "giveToMon reports previous hold")
    T.eq(mon.heldItem, "LEFTOVERS", "mon holds Leftovers")
    T.eq(game.save.inventory.LEFTOVERS, nil, "Leftovers removed from bag")
    T.eq(game.save.inventory.MIRACLE_SEED, 1, "old hold returned to bag")
  end

  -- Second give swaps again (no lost items / no double-hold).
  do
    local mon = Pokemon.new(Data, "PIKACHU", 20)
    mon.heldItem = "LEFTOVERS"
    local game = {
      data = Data,
      save = {
        inventory = { FOCUS_BAND = 1, MIRACLE_SEED = 1 },
        bagOrder = { "FOCUS_BAND", "MIRACLE_SEED" },
      },
    }
    local ok = HeldItems.giveToMon(game, mon, "FOCUS_BAND")
    T.eq(ok, true, "second give swaps")
    T.eq(mon.heldItem, "FOCUS_BAND", "mon holds Focus Band only")
    T.eq(game.save.inventory.LEFTOVERS, 1, "Leftovers returned on second give")
    T.eq(game.save.inventory.FOCUS_BAND, nil, "Focus Band left the bag")
    ok = HeldItems.giveToMon(game, mon, "MIRACLE_SEED")
    T.eq(ok, true, "third give swaps")
    T.eq(mon.heldItem, "MIRACLE_SEED", "mon holds Miracle Seed only")
    T.eq(game.save.inventory.FOCUS_BAND, 1, "Focus Band returned on third give")
    T.eq(game.save.inventory.MIRACLE_SEED, nil, "Miracle Seed left the bag")
  end

  -- Full bag: removing the given item frees a slot for the returned hold.
  do
    local Bag = require("src.inventory.Bag")
    local mon = Pokemon.new(Data, "PIKACHU", 20)
    mon.heldItem = "MIRACLE_SEED"
    local inv, order = {}, {}
    local cap = Bag.capacity(Data)
    for i = 1, cap - 1 do
      local fake = "KR_FILL_" .. i
      inv[fake] = 1
      order[#order + 1] = fake
    end
    inv.LEFTOVERS = 1
    order[#order + 1] = "LEFTOVERS"
    local game = { data = Data, save = { inventory = inv, bagOrder = order } }
    T.eq(Bag.slots(game.save), cap, "bag is at capacity before swap")
    local ok, err = HeldItems.giveToMon(game, mon, "LEFTOVERS")
    T.eq(ok, true, "full-bag swap still succeeds")
    T.eq(err, nil, "full-bag swap no error")
    T.eq(mon.heldItem, "LEFTOVERS", "full-bag swap applied hold")
    T.eq(game.save.inventory.MIRACLE_SEED, 1, "full-bag swap returned old hold")
    T.eq(game.save.inventory.LEFTOVERS, nil, "full-bag swap took given item")
  end

  local function fakeBagList(game)
    local factory = Data.screens.BagMenu
    factory = type(factory) == "function" and factory or factory.new
    local list = factory(game, {})
    return list
  end

  local function captureMenu(game, list, itemId)
    local captured
    local orig = Menu.new
    Menu.new = function(g, items, menuOpts)
      Menu.new = orig
      captured = { items = items, opts = menuOpts }
      return orig(g, items, menuOpts)
    end
    list.onChoose({ value = itemId, label = itemId })
    Menu.new = orig
    return captured
  end

  -- Option on: holdable opens USE / GIVE / TOSS
  do
    opts[HeldItems.BAG_GIVE_KEY] = true
    local game = {
      data = Data,
      save = {
        money = 0,
        inventory = { LEFTOVERS = 2, POTION = 1 },
        bagOrder = { "LEFTOVERS", "POTION" },
        player = { name = "RED" },
        party = { Pokemon.new(Data, "PIKACHU", 10) },
      },
      input = { wasPressed = function() return false end },
      stack = {
        push = function() end,
        pop = function() end,
        top = function() return nil end,
      },
    }
    local list = fakeBagList(game)
    T.check(list and list.onChoose, "bag list has onChoose")
    local cap = captureMenu(game, list, "LEFTOVERS")
    T.check(cap ~= nil, "USE/TOSS menu opened for Leftovers")
    T.eq(#cap.items, 3, "holdable menu has three entries")
    local labels = {}
    for _, it in ipairs(cap.items) do labels[#labels + 1] = it.label end
    T.eq(table.concat(labels, "/"),
      table.concat({ Strings("USE"), Strings("GIVE"), Strings("TOSS") }, "/"),
      "holdable submenu is USE/GIVE/TOSS")
  end

  -- Option on: non-holdable stays USE / TOSS
  do
    opts[HeldItems.BAG_GIVE_KEY] = true
    local game = {
      data = Data,
      save = {
        money = 0,
        inventory = { POTION = 1 },
        bagOrder = { "POTION" },
        player = { name = "RED" },
        party = {},
      },
      input = { wasPressed = function() return false end },
      stack = {
        push = function() end,
        pop = function() end,
        top = function() return nil end,
      },
    }
    local list = fakeBagList(game)
    local cap = captureMenu(game, list, "POTION")
    T.check(cap ~= nil, "USE/TOSS menu opened for Potion")
    T.eq(#cap.items, 2, "non-holdable menu stays two entries")
  end

  -- Option off: holdable also USE / TOSS only
  do
    opts[HeldItems.BAG_GIVE_KEY] = false
    T.check(not HeldItems.bagGiveEnabled(HeldItems._mod),
      "BAG GIVE reports off")
    local game = {
      data = Data,
      save = {
        money = 0,
        inventory = { LEFTOVERS = 1 },
        bagOrder = { "LEFTOVERS" },
        player = { name = "RED" },
        party = {},
      },
      input = { wasPressed = function() return false end },
      stack = {
        push = function() end,
        pop = function() end,
        top = function() return nil end,
      },
    }
    local list = fakeBagList(game)
    local cap = captureMenu(game, list, "LEFTOVERS")
    T.check(cap ~= nil, "menu still opens with option off")
    T.eq(#cap.items, 2, "option off: no GIVE row")
  end

  -- Mid-battle bag: no GIVE injection
  do
    opts[HeldItems.BAG_GIVE_KEY] = true
    local game = {
      data = Data,
      save = {
        money = 0,
        inventory = { LEFTOVERS = 1 },
        bagOrder = { "LEFTOVERS" },
        player = { name = "RED" },
        party = { Pokemon.new(Data, "PIKACHU", 10) },
      },
      input = { wasPressed = function() return false end },
      stack = {
        push = function() end,
        pop = function() end,
        top = function() return nil end,
      },
    }
    local factory = Data.screens.BagMenu
    factory = type(factory) == "function" and factory or factory.new
    local list = factory(game, { battle = { kind = "wild" } })
    local openedMenu = false
    local orig = Menu.new
    Menu.new = function(...)
      openedMenu = true
      Menu.new = orig
      return orig(...)
    end
    -- Battle path uses the item immediately (no USE/TOSS menu).
    list.onChoose({ value = "LEFTOVERS", label = "LEFTOVERS" })
    Menu.new = orig
    T.check(not openedMenu, "battle bag skips USE/GIVE/TOSS submenu")
  end

  opts[HeldItems.BAG_GIVE_KEY] = saved
  BagPockets._resetFilter()
end
