-- Gen2-only apply for legendary custom maps (mapper export → legend_maps_data.lua).
-- Gen1 keeps native CAVERN/OVERWORLD via legend_regis.register / legend_mythicals.register.

local Host = require("mods.Kanto-Reforged.core.host")
local LegendRegis = require("mods.Kanto-Reforged.world.legend_regis")
local LegendMythicals = require("mods.Kanto-Reforged.world.legend_mythicals")

local LegendMapsApply = {}

function LegendMapsApply.apply(mod)
  if not Host.isGen2() then
    return false
  end
  local ok, data = pcall(require, "mods.Kanto-Reforged.world.legend_maps_data")
  if not ok or not data or not data.enabled then
    return false
  end
  local applied = false
  if data.regi then
    applied = LegendRegis.applyGen2(mod, data.regi) or applied
  end
  if data.mythical then
    applied = LegendMythicals.applyGen2(mod, data.mythical) or applied
  end
  return applied
end

return LegendMapsApply
