-- Cinnabar item blacksmith.
-- Gen1: lab Metronome room. Gold: Cinnabar Pokémon Center (lab is gone).

local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
local Host = require("mods.Kanto-Reforged.core.host")
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
      local Host = require("mods.Kanto-Reforged.core.host")
      local save = game and (game.save or game.session)
      if Host.isGen3() then
        local BerryFarmGame3 = require("mods.Kanto-Reforged.world.berry_farm_game3")
        -- FOCUS_SASH aliases to FOCUS_BAND on FRLG.
        return BerryFarmGame3.bagGetItemCount(save, "FOCUS_SASH") > 0
          or BerryFarmGame3.bagGetItemCount(save, "FOCUS_BAND") > 0
      end
      return (save and save.inventory and (save.inventory.FOCUS_SASH or 0) > 0)
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
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local BerryFarmGame3 = require("mods.Kanto-Reforged.world.berry_farm_game3")
    for id, n in pairs(need) do
      if BerryFarmGame3.bagGetItemCount(save, id) < n then return false end
    end
    return true
  end
  local inv = save.inventory or {}
  for id, n in pairs(need) do
    if (inv[id] or 0) < n then return false end
  end
  return true
end

local function doTake(save, need)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local BerryFarmGame3 = require("mods.Kanto-Reforged.world.berry_farm_game3")
    for id, n in pairs(need) do
      BerryFarmGame3.bagRemoveItem(save, id, n)
    end
    return
  end
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

    local Host = require("mods.Kanto-Reforged.core.host")
    if Host.isGen3() then
      local Choice = require("src.ui.game3.choice")
      local labels = {}
      for _, r in ipairs(rows) do
        labels[#labels + 1] = r.label
      end
      labels[#labels + 1] = "CANCEL"
      Choice.multi(labels, 0, function(idx)
        local chosen = (type(idx) == "number") and rows[idx + 1]
        if chosen then
          local ex = chosen.value
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
            local save = game.save or game.session
            if Host.isGen3() then
              local BerryFarmGame3 = require("mods.Kanto-Reforged.world.berry_farm_game3")
              for id, n in pairs(ex.take) do
                BerryFarmGame3.bagAddItem(save, id, n)
              end
            else
              local Bag = require("src.inventory.Bag")
              for id, n in pairs(ex.take) do Bag.add(save, id, n) end
            end
            HouseNpcs.pushText(game, Strings("The bag is full!"), done)
            return
          end
          if ex.once and ex.flag then
            mod.save:set(ex.flag, true)
          end
          local def = game.data and game.data.items and game.data.items[giveId]
          HouseNpcs.pushText(game, Strings("Traded for\n%s!", def and def.name or giveId), done)
        else
          if done then done() end
        end
      end)
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
        local def = game.data and game.data.items and game.data.items[giveId]
        HouseNpcs.pushText(game, Strings("Traded for\n%s!", def and def.name or giveId), done)
      end,
    }))
  end
end

function ItemSmith.register(mod)
  if mod and mod.content and mod.content.items and mod.content.items.get and not mod.content.items:get("DRAGON_SCALE") then
    mod.content.items:register("DRAGON_SCALE", {
      id = "DRAGON_SCALE", name = "DRAGON SCALE", price = 2100, tossable = true,
    })
  end

  local isG3 = Host.isGen3()
  local mapId = isG3 and "FR_CINNABAR_ISLAND_POKEMON_LAB_RESEARCH_ROOM"
    or (Host.isGen2() and "CINNABAR_POKECENTER_1F" or "CINNABAR_LAB_METRONOME_ROOM")
  local index = Host.isGen2()
    and HouseNpcs.nextFreeIndex(mod, mapId, 4)
    or (isG3 and 83 or 3)
  local x = Host.isGen2() and 1 or 5
  local y = Host.isGen2() and 3 or 5

  HouseNpcs.appendNpc(mod, mapId, {
    index = index,
    name = "CINNABARLABMETRONOMEROOM_SMITH",
    sprite = "SPRITE_SCIENTIST",
    graphicsId = 55,
    text = "TEXT_CINNABARLABMETRONOMEROOM_SMITH",
    x = x, y = y,
    gen3X = 5, gen3Y = 5,
  }, ItemSmith.OWNER)

  HouseNpcs.bindTalk(mod, mapId, {
    TEXT_CINNABARLABMETRONOMEROOM_SMITH = talk(mod),
  })
end

return ItemSmith
