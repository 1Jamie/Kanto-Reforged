-- Roaming Radar key-item screen + bag/start-menu access.

local KantoGraph = require("mods.expansion_pack.kanto_graph")
local Roamers = require("mods.expansion_pack.roamers")
local Strings = require("src.core.Strings")

local RoamingRadar = {}
local SCREEN = "ExpRoamingRadar"

function RoamingRadar.register(mod)
  mod.content.screens:register(SCREEN, {
    new = function(game)
      local items = {}
      local mapId = nil
      if game.overworld and game.overworld.map then
        mapId = game.overworld.map.id
      elseif game.save and game.save.player then
        mapId = game.save.player.map
      end
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
          }
        end
      end
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
    local inserted = mod.ui.insertAfter(out, "DEXNAV", {
      label = Strings("RADAR"),
      onSelect = function() mod.ui.push(game, SCREEN) end,
    })
    if inserted then return inserted end
    out[#out + 1] = {
      label = Strings("RADAR"),
      onSelect = function() mod.ui.push(game, SCREEN) end,
    }
    return out
  end)
end

return RoamingRadar
