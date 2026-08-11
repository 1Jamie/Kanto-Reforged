-- Register generated Sevii wild tables (from sevii_import.py).

local SeviiEncounters = {}

function SeviiEncounters.register(mod)
  local ok, data = pcall(require, "mods.Kanto-Reforged.sevii.encounters_data")
  if not ok or not data or not data.maps then
    mod.log:warn("sevii encounters_data.lua missing; run sevii_import.py")
    return
  end
  -- Only register wilds for authored outdoor maps (importer emits all Sevii).
  local active = {
    SEVII_ONE_ISLAND = true,
    SEVII_ONE_ISLAND_KINDLE_ROAD = true,
    SEVII_ONE_ISLAND_TREASURE_BEACH = true,
  }
  for mapId, entry in pairs(data.maps) do
    if active[mapId] then
      local payload = {}
      if entry.grass then payload.grass = entry.grass end
      if entry.water then payload.water = entry.water end
      if next(payload) then
        mod.content.encounters:register(mapId, payload)
      end
    end
  end
end

return SeviiEncounters
