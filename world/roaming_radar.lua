-- Roaming Radar key-item screen + bag/start-menu access.

local KantoGraph = require("mods.Kanto-Reforged.core.kanto_graph")
local Roamers = require("mods.Kanto-Reforged.world.roamers")
local Strings = require("src.core.Strings")
local Host = require("mods.Kanto-Reforged.core.host")

local RoamingRadar = {}
local SCREEN = "ExpRoamingRadar"

local function currentMapId(game)
  if game and game.overworld and game.overworld.map then
    return game.overworld.map.id
  end
  if game and game.save and game.save.player then
    return game.save.player.map
  end
  if game and game.session and game.session.map then
    return game.session.map
  end
  local Map = package.loaded["src.core.game3.map"]
  return Map and Map.current
end

local function radarRows(mod, game)
  local mapId = currentMapId(game)
  local items = {}
  local all = {}
  for _, id in ipairs(Roamers.BEASTS) do all[#all + 1] = id end
  for _, id in ipairs(Roamers.EONS) do all[#all + 1] = id end
  for _, id in ipairs(all) do
    if Roamers.isActive(mod, id) then
      local loc = Roamers.getLocation(mod, id) or "?"
      local prox = "FAR"
      if mapId == loc then
        prox = "HERE"
      elseif mapId and KantoGraph.isAdjacent(mapId, loc) then
        prox = "NEXT DOOR"
      end
      items[#items + 1] = {
        label = id,
        right = KantoGraph.displayName(loc) .. "  " .. prox,
        value = id,
        line = string.format("%s: %s (%s)", id, KantoGraph.displayName(loc), prox),
      }
    end
  end
  return items
end

local function openGen3Radar(mod, game)
  local rows = radarRows(mod, game)
  local lines = {}
  if #rows == 0 then
    lines[1] = "No signals."
  else
    for _, row in ipairs(rows) do
      lines[#lines + 1] = row.line
    end
  end
  local msg = table.concat(lines, "\n")
  local okM, Message = pcall(require, "src.ui.game3.message")
  if okM and Message and Message.show then
    Message.show(msg)
    return
  end
  if mod.ui and mod.ui.push then
    mod.ui.push(game, SCREEN)
  end
end

function RoamingRadar.register(mod)
  if Host.isGen3() then
    -- FRLG: start-menu entry only (no Gen1 bag USE / Screens.TownMap hijack).
    mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
      local out = next(game, items)
      if type(out) ~= "table" then return out end
      if not mod.save:get("got_roaming_radar", false) then return out end
      local DexNav = require("mods.Kanto-Reforged.ui.dexnav")
      local radar = {
        label = Strings("RADAR"),
        onSelect = function() openGen3Radar(mod, game) end,
      }
      for _, label in ipairs(DexNav.MENU_LABELS or { "DEXNAV", "DexNav" }) do
        for i, row in ipairs(out) do
          if row.label == label then
            table.insert(out, i + 1, radar)
            return out
          end
        end
      end
      out[#out + 1] = radar
      return out
    end)
    return
  end

  mod.content.screens:register(SCREEN, {
    new = function(game)
      local items = radarRows(mod, game)
      if #items == 0 then
        items[1] = { label = Strings("No signals."), right = "", value = nil }
      end
      return mod.ui.ListMenu.new(game, Strings("ROAMING RADAR"), items, {
        onChoose = function(_, menu) menu:close() end,
      })
    end,
  })

  -- Bag USE: ItemEffects has no game handle, and BagMenu's useOn is local.
  -- Return "townmap" so BagMenu pushes a screen, then redirect to Radar.
  local ItemEffects = require("src.inventory.ItemEffects")
  if not ItemEffects._expansionRadar then
    local original = ItemEffects.use
    ItemEffects.use = function(data, save, itemId, target, ...)
      if itemId == "ROAMING_RADAR" then
        RoamingRadar._openNext = true
        return "townmap"
      end
      return original(data, save, itemId, target, ...)
    end
    ItemEffects._expansionRadar = true
  end

  local Screens = require("src.ui.Screens")
  if not Screens._expansionRadar then
    local origPush = Screens.push
    Screens.push = function(game, name, ...)
      if name == "TownMap" and RoamingRadar._openNext then
        RoamingRadar._openNext = false
        return origPush(game, SCREEN, ...)
      end
      return origPush(game, name, ...)
    end
    Screens._expansionRadar = true
  end

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    if not mod.save:get("got_roaming_radar", false) then return out end
    local DexNav = require("mods.Kanto-Reforged.ui.dexnav")
    local radar = {
      label = Strings("RADAR"),
      onSelect = function() mod.ui.push(game, SCREEN) end,
    }
    for _, label in ipairs(DexNav.MENU_LABELS) do
      for i, row in ipairs(out) do
        if row.label == label then
          table.insert(out, i + 1, radar)
          return out
        end
      end
    end
    out[#out + 1] = radar
    return out
  end)
end

return RoamingRadar

