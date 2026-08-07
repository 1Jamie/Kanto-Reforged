-- Cinnabar Lab Metronome Room item blacksmith.

local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
local Strings = require("src.core.Strings")

local ItemSmith = {}
ItemSmith.OWNER = "item_smith"

ItemSmith.EXCHANGES = {
  {
    id = "life_orb",
    label = "METAL COAT → LIFE ORB",
    take = { METAL_COAT = 1 },
    give = "LIFE_ORB",
    once = true,
    flag = "smith_life_orb",
  },
  {
    id = "focus_sash",
    label = "3 NUGGET → FOCUS SASH",
    take = { NUGGET = 3 },
    give = "FOCUS_SASH",
    once = true,
    flag = "smith_focus_sash",
    altGive = "HEART_SCALE",
    altQty = 2,
    altIf = function(game)
      return (game.save.inventory and (game.save.inventory.FOCUS_SASH or 0) > 0)
        or false
    end,
  },
  {
    id = "berries",
    label = "LEAF STONE → BERRIES",
    take = { LEAF_STONE = 1 },
    giveSeeds = true,
    once = false,
  },
}

local function canTake(save, need)
  local inv = save.inventory or {}
  for id, n in pairs(need) do
    if (inv[id] or 0) < n then return false end
  end
  return true
end

local function doTake(save, need)
  local Bag = require("src.inventory.Bag")
  for id, n in pairs(need) do
    Bag.remove(save, id, n)
  end
end

local function talk(mod)
  return function(game, ow, npc, done)
    local rows = {}
    for _, ex in ipairs(ItemSmith.EXCHANGES) do
      if not (ex.once and mod.save:get(ex.flag, false)) then
        rows[#rows + 1] = { label = ex.label, value = ex }
      end
    end
    if #rows == 0 then
      HouseNpcs.pushText(game, Strings("Nothing left to\ntrade today."), done)
      return
    end
    local ListMenu = require("src.ui.ListMenu")
    game.stack:push(ListMenu.new(game, Strings("Trade which?"), rows, {
      onChoose = function(row, menu)
        menu:close()
        local ex = row.value
        if not canTake(game.save, ex.take) then
          HouseNpcs.pushText(game, Strings("You don't have\nthe materials."), done)
          return
        end
        doTake(game.save, ex.take)
        if ex.giveSeeds then
          local berries = { "BERRY", "CHERI_BERRY", "PECHA_BERRY", "RAWST_BERRY", "ASPEAR_BERRY" }
          for i = 1, 5 do
            HouseNpcs.giveItem(game, berries[((i - 1) % #berries) + 1], 1)
          end
          HouseNpcs.pushText(game, Strings("Here's a berry\npack!"), done)
          return
        end
        local giveId, qty = ex.give, 1
        if ex.altIf and ex.altIf(game) then
          giveId, qty = ex.altGive, ex.altQty or 1
        end
        if not HouseNpcs.giveItem(game, giveId, qty) then
          local Bag = require("src.inventory.Bag")
          for id, n in pairs(ex.take) do Bag.add(game.save, id, n) end
          HouseNpcs.pushText(game, Strings("The bag is full!"), done)
          return
        end
        if ex.once and ex.flag then
          mod.save:set(ex.flag, true)
        end
        local def = game.data.items[giveId]
        HouseNpcs.pushText(game, Strings("Traded for\n%s!", def and def.name or giveId), done)
      end,
    }))
  end
end

function ItemSmith.register(mod)
  -- Register DRAGON_SCALE if missing (for future exchanges)
  if not mod.content.items:get("DRAGON_SCALE") then
    mod.content.items:register("DRAGON_SCALE", {
      id = "DRAGON_SCALE", name = "DRAGON SCALE", price = 2100, tossable = true,
    })
  end

  HouseNpcs.appendNpc(mod, "CINNABAR_LAB_METRONOME_ROOM", {
    index = 3,
    name = "CINNABARLABMETRONOMEROOM_SMITH",
    sprite = "SPRITE_SCIENTIST",
    text = "TEXT_CINNABARLABMETRONOMEROOM_SMITH",
    x = 5, y = 5,
  }, ItemSmith.OWNER)

  mod.content.map_scripts:register("CINNABAR_LAB_METRONOME_ROOM", {
    talk = { TEXT_CINNABARLABMETRONOMEROOM_SMITH = talk(mod) },
  })
end

return ItemSmith
