-- Pokédex AREA line for active roamers after first seen.

local Roamers = require("mods.Kanto-Reforged.world.roamers")
local KantoGraph = require("mods.Kanto-Reforged.core.kanto_graph")
local Font = require("src.render.Font")
local Strings = require("src.core.Strings")

local RoamerDex = {}

function RoamerDex.install(mod)
  local DexEntryMenu = require("src.ui.DexEntryMenu")
  if DexEntryMenu._expansionRoamerArea then return end
  local original = DexEntryMenu.render
  DexEntryMenu.render = function(game, def, sprite, forceOwned, trueColor, page, ...)
    original(game, def, sprite, forceOwned, trueColor, page, ...)
    if not def or not def.id or not game then return end
    local seen = game.save and game.save.pokedex and game.save.pokedex.seen
    if not (seen and seen[def.id]) then return end
    local loc = Roamers.getLocation(mod, def.id)
    if not loc then return end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(Strings("AREA  %s", KantoGraph.displayName(loc)), 8, 62)
    love.graphics.setColor(1, 1, 1, 1)
  end
  DexEntryMenu._expansionRoamerArea = true
end

return RoamerDex
