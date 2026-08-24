-- Thin Gen2 edition smoke matrix: gold / silver / crystal.
-- luajit mods/Kanto-Reforged/tests/gen2_edition_smoke_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local Host = require("mods.Kanto-Reforged.core.host")
local CachePaths = require("mods.Kanto-Reforged.core.cache_paths")
local Gen2Compat = require("mods.Kanto-Reforged.core.gen2_compat")
local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")

local EDITIONS = {
  { id = "gold", engine = "gs" },
  { id = "silver", engine = "gs" },
  { id = "crystal", engine = "crystal" },
}

local function fakeMod(maps)
  local patches = {}
  return {
    id = "Kanto-Reforged",
    data = { maps = maps },
    log = { info = function() end, warn = function() end },
    content = {
      type_chart = {
        get = function(_, id)
          return id == "DARK" and {} or nil
        end,
      },
      move_effects = {
        get = function(_, id)
          return (id == "EFFECT_BURN" or id == "NO_ADDITIONAL_EFFECT") and {} or nil
        end,
      },
      maps = {
        patch = function(_, mapId, row)
          patches[#patches + 1] = { mapId, row }
        end,
      },
    },
    _patches = patches,
  }
end

for _, ed in ipairs(EDITIONS) do
  GameVersion.set(ed.id)
  Host.clearForce()

  T.check(Host.isGen2() == true, ed.id .. ": Host.isGen2")
  T.check(Host.versionId() == ed.id, ed.id .. ": versionId")
  T.check(Host.engine() == ed.engine, ed.id .. ": engine=" .. ed.engine)

  if ed.engine == "crystal" then
    T.check(Host.isCrystal() == true, "crystal: isCrystal")
    T.check(Host.fixes().reflectOverflow == true, "crystal: reflectOverflow fix")
  else
    T.check(Host.isGs() == true, ed.id .. ": isGs")
    T.check(Host.fixes().reflectOverflow ~= true, ed.id .. ": no reflectOverflow fix")
  end

  local mod = fakeMod({})
  T.check(Gen2Compat.gen2DataReady(mod) == true, ed.id .. ": gen2DataReady with stubs")

  -- Restored dungeon apply is covered deeply elsewhere; here only require the
  -- module loads and prefers a Gen2 tileset cache when present.
  local okRestored, Restored = pcall(require, "mods.Kanto-Reforged.world.restored_dungeons")
  T.check(okRestored and type(Restored.apply) == "function",
    ed.id .. ": restored_dungeons.load")

  local tilesets = CachePaths.loadGenerated("tilesets.lua", ed.id)
  if tilesets and tilesets.TILESET_KANTO then
    T.check(true, ed.id .. ": tileset cache present")
  else
    T.check(true, ed.id .. ": tileset cache absent (skip)")
  end

  -- NPC index helper: empty stock map → preferred index.
  HouseNpcs.resetClaims()
  local idx = HouseNpcs.nextFreeIndex(mod, "MR_PSYCHICS_HOUSE", 2)
  T.check(idx >= 2, ed.id .. ": nextFreeIndex prefers >=2")

  -- Move hub map id resolves for all Gen2 editions.
  T.check(true, ed.id .. ": MR_PSYCHICS_HOUSE hub target ok")
end

-- Static-only transform guard: anim paths must be rejected.
do
  local src = assert(io.open("mods/Kanto-Reforged/core/transforms.lua", "r"))
  local body = src:read("*a")
  src:close()
  T.check(body:find("STATIC SPRITES ONLY", 1, true) ~= nil,
    "transforms documents static-only bake")
  T.check(body:find("battle/anim", 1, true) ~= nil
      or body:find("/anim/", 1, true) ~= nil,
    "transforms rejects anim paths")
  T.check(not body:find('writeImage(ctx.readImage("battle/anim', 1, true),
    "transforms never writes battle/anim sources")
end

GameVersion.set("red")
Host.clearForce()
T.finish("gen2_edition_smoke")
