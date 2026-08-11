-- Sevii Islands Phase 0 entry (called from Kanto-Reforged main.lua).

local Sevii = {}

function Sevii.register(mod)
  local Maps = require("mods.Kanto-Reforged.sevii.maps")
  Maps.register(mod)
  Maps.install(mod)

  local Ferry = require("mods.Kanto-Reforged.sevii.ferry")
  Ferry.register(mod)
  Ferry.install(mod)

  local Encounters = require("mods.Kanto-Reforged.sevii.encounters")
  Encounters.register(mod)

  local Trainers = require("mods.Kanto-Reforged.sevii.trainers")
  Trainers.register(mod)
  Trainers.install(mod)
end

return Sevii
