-- Remap pre-KR save map IDs to restored *_KR dungeon maps.
-- Saves from before restored layouts were tagged still store stock names
-- (VIRIDIAN_FOREST, CERULEAN_CAVE_1F, …). Run on save.loading so continue
-- loads the Gen 1 layouts instead of gutted Gen 2 stubs.

local Host = require("mods.Kanto-Reforged.core.host")

local Migration = {}

local LEGACY_TO_KR = nil

local EXTRA_ALIASES = {
  MOUNT_MOON = "MT_MOON_1F_KR",
  MT_MOON = "MT_MOON_1F_KR",
  MOUNT_MOON_1F = "MT_MOON_1F_KR",
  MOUNT_MOON_B1F = "MT_MOON_B1F_KR",
  MOUNT_MOON_B2F = "MT_MOON_B2F_KR",
  CERULEAN_CAVE = "CERULEAN_CAVE_1F_KR",
  ROCK_TUNNEL = "ROCK_TUNNEL_1F_KR",
  SAFARI_ZONE = "SAFARI_ZONE_GATE_KR",
  SAFARI = "SAFARI_ZONE_GATE_KR",
  SEAFOAM = "SEAFOAM_ISLANDS_1F_KR",
  SEAFOAM_ISLANDS = "SEAFOAM_ISLANDS_1F_KR",
}

local function ensureLookup()
  if LEGACY_TO_KR then return LEGACY_TO_KR end
  local ok, Data = pcall(require, "mods.Kanto-Reforged.world.restored_dungeons_data")
  local map = {}
  if ok and Data and type(Data.maps) == "table" then
    for mapId in pairs(Data.maps) do
      if type(mapId) == "string" and mapId:find("_KR$") then
        map[mapId:sub(1, -4)] = mapId
      end
    end
  end
  for legacy, kr in pairs(EXTRA_ALIASES) do
    map[legacy] = kr
  end
  LEGACY_TO_KR = map
  return map
end

function Migration.remapMapId(mapId)
  if type(mapId) ~= "string" or mapId:find("_KR$") then
    return mapId
  end
  return ensureLookup()[mapId] or mapId
end

local function remapField(tbl, key)
  if not (tbl and tbl[key]) then return false end
  local newId = Migration.remapMapId(tbl[key])
  if newId == tbl[key] then return false end
  tbl[key] = newId
  return true
end

function Migration.migrate(save)
  if not Host.isGen2() or type(save) ~= "table" then
    return false
  end
  ensureLookup()
  local changed = false

  if save.position then changed = remapField(save.position, "map") or changed end
  if save.player then changed = remapField(save.player, "map") or changed end
  if save.lastHeal then changed = remapField(save.lastHeal, "map") or changed end
  if save.backupWarp then changed = remapField(save.backupWarp, "map") or changed end
  if save.lastOutdoor then changed = remapField(save.lastOutdoor, "id") or changed end

  if type(save.mapScenes) == "table" then
    local newScenes = {}
    local scenesChanged = false
    for k, v in pairs(save.mapScenes) do
      local nk = Migration.remapMapId(k)
      if nk ~= k then scenesChanged = true end
      if newScenes[nk] == nil then
        newScenes[nk] = v
      end
    end
    if scenesChanged then
      save.mapScenes = newScenes
      changed = true
    end
  end

  return changed
end

function Migration.install(mod)
  mod.events:on("save.loading", function(ev)
    if not Host.isGen2() then return end
    local save = ev and ev.raw
    if not save then return end
    if Migration.migrate(save) and mod.log then
      mod.log:info("Migrated pre-KR restored dungeon map IDs in save")
    end
  end)
end

return Migration
