-- Berry Farm: isolated OVERWORLD map with 9 step-grown plots, entered
-- via a door on every Pokémon Center.

local Strings = require("src.core.Strings")
local HeldItems = require("mods.Kanto-Reforged.held_items")

local BerryFarm = {}

BerryFarm.MAP_ID = "BERRY_FARM"
BerryFarm.GROW_STEPS = 320
BerryFarm.PLOT_COUNT = 9
BerryFarm.HARVEST_YIELD = 2

-- Soil rank → effective grow steps (berry_quests sets soil_rank).
BerryFarm.GROW_BY_RANK = { [0] = 320, [1] = 280, [2] = 240, [3] = 192 }

function BerryFarm.growSteps(mod)
  local Host = require("mods.Kanto-Reforged.host")
  local rank = 0
  if mod and mod.save then
    rank = Host.saveGet(mod.save, "soil_rank", 0) or 0
  end
  return BerryFarm.GROW_BY_RANK[rank] or BerryFarm.GROW_STEPS
end

function BerryFarm.ensureUnlocked(mod)
  local Host = require("mods.Kanto-Reforged.host")
  local unlocked = Host.saveGet(mod.save, "unlocked_berries", nil)
  if type(unlocked) ~= "table" then
    unlocked = { BERRY = true }
    Host.saveSet(mod.save, "unlocked_berries", unlocked)
  elseif not unlocked.BERRY then
    unlocked.BERRY = true
    Host.saveSet(mod.save, "unlocked_berries", unlocked)
  end
  return unlocked
end

function BerryFarm.unlockBerry(mod, berryId)
  local Host = require("mods.Kanto-Reforged.host")
  local unlocked = BerryFarm.ensureUnlocked(mod)
  unlocked[berryId] = true
  Host.saveSet(mod.save, "unlocked_berries", unlocked)
end

function BerryFarm.plantableList(mod)
  local unlocked = BerryFarm.ensureUnlocked(mod)
  local list = {}
  for _, id in ipairs(HeldItems.BERRY_PACK) do
    if unlocked[id] then list[#list + 1] = id end
  end
  return list
end

-- Farm entrance: same red exit-mat pair as the outdoor door, but on the
-- right side of the south wall (blocks 10+11). Walk south off the mat.
-- Outdoor exit stays warps #1/#2 at (3,7)/(4,7); farm is #3/#4.
BerryFarm.PC_DOOR = { x = 9, y = 7 } -- primary cell (left tile of farm mat)
BerryFarm.PC_DOOR_B = { x = 10, y = 7 }

-- Shared vanilla PC floor with bottom-right 15,15 → exit-mat blocks 10,11
BerryFarm.PC_BLOCKS = {
  32, 16, 1, 2, 12, 13, 13,
  33, 4, 5, 7, 7, 34, 35,
  8, 15, 15, 15, 15, 15, 27,
  14, 10, 11, 14, 10, 11, 14,
}

BerryFarm.ALL_POKECENTERS = {
  "VIRIDIAN_POKECENTER", "PEWTER_POKECENTER", "CERULEAN_POKECENTER",
  "MT_MOON_POKECENTER", "ROCK_TUNNEL_POKECENTER", "VERMILION_POKECENTER",
  "LAVENDER_POKECENTER", "CELADON_POKECENTER", "FUCHSIA_POKECENTER",
  "SAFFRON_POKECENTER", "CINNABAR_POKECENTER",
}

-- Gold Johto 1Fs: east-corner stairs mirroring the shared 2F stairs at (0,7).
-- Warp tiles only fire on warp-collision cells — block 18's LEFT cell — so
-- the farm door is (8,7), not (9,7). South row keeps outdoor mats (17/39).
BerryFarm.ALL_POKECENTERS_GEN2_JOHTO = {
  "CHERRYGROVE_POKECENTER_1F", "VIOLET_POKECENTER_1F", "AZALEA_POKECENTER_1F",
  "GOLDENROD_POKECENTER_1F", "ECRUTEAK_POKECENTER_1F", "OLIVINE_POKECENTER_1F",
  "CIANWOOD_POKECENTER_1F", "MAHOGANY_POKECENTER_1F", "BLACKTHORN_POKECENTER_1F",
  "ROUTE_32_POKECENTER_1F", "SILVER_CAVE_POKECENTER_1F",
}
BerryFarm.PC_DOOR_GEN2_STAIRS = { x = 8, y = 7 }
BerryFarm.PC_BLOCKS_GEN2_JOHTO = {
  1, 2, 3, 19, 8,
  5, 6, 7, 4, 12,
  4, 4, 4, 46, 47,
  18, 17, 39, 4, 18,
}

-- Gold Kanto 1Fs share the Gen2 5×4 pokecenter shell (not Gen1's 7×4), but
-- get a second exit-mat pair on the south row — same "step on the red pad"
-- feel as Gen1 farm mats / the outdoor door. Mat pair 17/39 warps on the
-- RIGHT of 17 and LEFT of 39 → cells (7,7)/(8,7).
BerryFarm.ALL_POKECENTERS_GEN2_KANTO = {
  "VIRIDIAN_POKECENTER_1F", "PEWTER_POKECENTER_1F", "CERULEAN_POKECENTER_1F",
  "ROUTE_10_POKECENTER_1F",
  "VERMILION_POKECENTER_1F", "LAVENDER_POKECENTER_1F", "CELADON_POKECENTER_1F",
  "FUCHSIA_POKECENTER_1F", "SAFFRON_POKECENTER_1F", "CINNABAR_POKECENTER_1F",
}
BerryFarm.PC_DOOR_GEN2_PAD = { x = 7, y = 7 }
BerryFarm.PC_DOOR_GEN2_PAD_B = { x = 8, y = 7 }
-- Vanilla Gold 5×4 PC blocks with south row ending in a second 17/39 mat pair.
BerryFarm.PC_BLOCKS_GEN2_KANTO = {
  1, 2, 3, 19, 8,
  5, 6, 7, 4, 12,
  4, 4, 4, 46, 47,
  18, 17, 39, 17, 39,
}

-- Odd-shaped Indigo lobby (9×7 TILESET_POKECENTER): SE stairs block 18 +
-- warp on its BL collision cell (16,13). Plain floor warps never fire.
-- Vanilla south row ends in floor 04; we rewrite the east cell to stairs.
BerryFarm.ALL_POKECENTERS_GEN2_STAIRS_ONLY = {
  "INDIGO_PLATEAU_POKECENTER_1F",
}
BerryFarm.PC_DOOR_GEN2_INDIGO = { x = 16, y = 13 }
BerryFarm.PC_BLOCKS_GEN2_INDIGO = {
  23, 23, 23, 23, 23, 23, 23, 19, 19,
  23, 23, 23, 23, 23, 23, 23, 18, 4,
  23, 23, 23, 23, 23, 23, 23, 23, 4,
  1, 2, 3, 8, 19, 42, 19, 44, 4,
  5, 6, 7, 12, 4, 5, 5, 5, 4,
  4, 4, 4, 4, 4, 4, 4, 4, 4,
  18, 4, 17, 39, 4, 4, 4, 4, 18,
}

function BerryFarm.isGen2KantoCenter(mapId)
  for _, id in ipairs(BerryFarm.ALL_POKECENTERS_GEN2_KANTO) do
    if id == mapId then return true end
  end
  return false
end

function BerryFarm.gen2DoorFor(mapId)
  if mapId == "INDIGO_PLATEAU_POKECENTER_1F" then
    return BerryFarm.PC_DOOR_GEN2_INDIGO, nil
  end
  if BerryFarm.isGen2KantoCenter(mapId) then
    return BerryFarm.PC_DOOR_GEN2_PAD, BerryFarm.PC_DOOR_GEN2_PAD_B
  end
  return BerryFarm.PC_DOOR_GEN2_STAIRS, nil
end

function BerryFarm.returnCellFor(mapId)
  local a = select(1, BerryFarm.gen2DoorFor(mapId))
  return a or BerryFarm.PC_DOOR_GEN2_STAIRS
end

-- Farm geometry (blocks): 19×12 → 38×24 cells
-- Cobble yard, plain tree-walled border (same as every other OVERWORLD map),
-- plus a lake on the east side you can surf across — no encounters, no
-- fishing spots, just open water boxed in by trees on every side.
BerryFarm.LANDING = { x = 8, y = 6 } -- path south of shed door
BerryFarm.EXIT = { x = 8, y = 5 }    -- house door warp tile
-- Return onto the farm mat (same pad you left from); warp stays inert until
-- you step off, same as any other door arrival.
BerryFarm.RETURN_CELL = { x = 9, y = 7 }

function BerryFarm.returnCell()
  local Host = require("mods.Kanto-Reforged.host")
  if Host.isGen2() then
    return BerryFarm.PC_DOOR_GEN2_STAIRS
  end
  return BerryFarm.RETURN_CELL
end

-- Gen1 OVERWORLD block ids only. Never reuse these on TILESET_JOHTO.
local GEN1_TILES = {
  WALL = 15,
  LEDGE = 26,
  COBBLE = 85,
  GRASS = 1, -- short grass; soil-patch sprite marks plots, not the block
  ROOF_L = 12, ROOF_M = 13, ROOF_R = 14,
  WALL_L = 16, DOOR = 58, WALL_R = 0,
  FENCE_L = 110, FENCE_H = 111, FENCE_R = 109, FENCE_POST = 28,
  STUMP = 52,
  -- No Gen1 "sand": 90s/24/25/31 bake in rocks, so shore is grass→water.
  DEEP = 67, -- open lake (surfable, no encounters)
}

-- TILESET_JOHTO ids (pokecrystal johto_collision.asm). Same yard/lake
-- geometry; Gen2-only — never written into the Gen1 OVERWORLD farm.
local GEN2_TILES = {
  WALL = 0x05,       -- pine tree wall (New Bark / Route border)
  LEDGE = 0x02,      -- path (Gen1 terrace was a hop ledge; skip one-ways)
  COBBLE = 0x02,     -- town path floor
  GRASS = 0x01,      -- open floor under plot sprites
  ROOF_L = 0x18, ROOF_M = 0x1f, ROOF_R = 0x19,
  WALL_L = 0x1c, DOOR = 0x77, WALL_R = 0x1e,
  FENCE_L = 0x05, FENCE_H = 0x05, FENCE_R = 0x05, FENCE_POST = 0x05,
  STUMP = 0x01,
  DEEP = 0x35,       -- open water (Cherrygrove pond)
}

-- Real Gold TILESET_JOHTO (collision quads). Do NOT treat Gen2Compat's
-- Gen1-OVERWORLD stand-in under the same id as Johto — that would mix
-- Gen1 graphics with Gen2 block numbers (or the reverse).
local function johtoTilesetData(mod)
  local Data = require("src.core.Data")
  local fromData = Data.gen2Tilesets and Data.gen2Tilesets.TILESET_JOHTO
  if fromData and type(fromData.collision) == "table" and #fromData.collision >= 64 then
    return fromData
  end
  local ts = mod and mod.content and mod.content.tilesets
    and mod.content.tilesets:get("TILESET_JOHTO")
  if ts and type(ts.collision) == "table" and #ts.collision >= 64 then
    return ts
  end
  return nil
end

local function usesJohtoBlocks(mod, tilesetId)
  local Host = require("mods.Kanto-Reforged.host")
  if not Host.isGen2() then return false end
  if tilesetId and tilesetId ~= "TILESET_JOHTO" and tilesetId ~= "TILESET_JOHTO_MODERN" then
    return false
  end
  return johtoTilesetData(mod) ~= nil
end

local function buildFarmBlocks(T)
  local W, L, C, G = T.WALL, T.LEDGE, T.COBBLE, T.GRASS
  local F = G -- plot cells: same ground; soil sprite marks farmland
  local FL, FH, FR, FP = T.FENCE_L, T.FENCE_H, T.FENCE_R, T.FENCE_POST
  local S, DP = T.STUMP, T.DEEP
  local ROOF_L, ROOF_M, ROOF_R = T.ROOF_L, T.ROOF_M, T.ROOF_R
  local WALL_L, DOOR, WALL_R = T.WALL_L, T.DOOR, T.WALL_R
  -- Width 19: yard cols 0–8, grass buffer 9, shore 10, lake 11–17, wall 18.
  return {
    -- 0: north wall
    W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
    -- 1: west strip + shed roof
    W, G, C, ROOF_L, ROOF_M, ROOF_R, C, S, G, G, G, DP, DP, DP, DP, DP, DP, DP, W,
    -- 2: shed door
    W, G, C, WALL_L, DOOR, WALL_R, C, G, G, G, G, DP, DP, DP, DP, DP, DP, DP, W,
    -- 3: landing
    W, G, C, C, C, C, C, C, C, G, G, DP, DP, DP, DP, DP, DP, DP, W,
    -- 4: terrace (Gen1 ledge → Gen2 plain path)
    W, G, L, L, C, L, L, L, C, G, G, DP, DP, DP, DP, DP, DP, DP, W,
    -- 5: north fence + gate
    W, G, FP, FH, C, FH, FH, FP, C, G, G, DP, DP, DP, DP, DP, DP, DP, W,
    -- 6: plot row 1
    W, G, FL, F, C, F, C, F, FR, G, G, DP, DP, DP, DP, DP, DP, DP, W,
    -- 7: path between rows
    W, G, FL, C, C, C, C, C, FR, G, G, DP, DP, DP, DP, DP, DP, DP, W,
    -- 8: plot row 2
    W, G, FL, F, C, F, C, F, FR, G, G, DP, DP, DP, DP, DP, DP, DP, W,
    -- 9: path
    W, G, FL, C, C, C, C, C, FR, G, G, DP, DP, DP, DP, DP, DP, DP, W,
    -- 10: plot row 3
    W, G, FL, F, C, F, C, F, FR, G, G, DP, DP, DP, DP, DP, DP, DP, W,
    -- 11: south fence + lake shoreline wall
    W, G, FP, FH, FH, FH, FH, FP, FR, W, W, W, W, W, W, W, W, W, W,
  }
end

-- Exported for tests / diagnostics.
BerryFarm.GEN1_TILES = GEN1_TILES
BerryFarm.GEN2_TILES = GEN2_TILES
BerryFarm.usesJohtoBlocks = usesJohtoBlocks
BerryFarm.johtoTilesetData = johtoTilesetData
BerryFarm.buildFarmBlocks = buildFarmBlocks

-- Plots at block cols 3/5/7, rows 6/8/10 — one cobble block between each.
BerryFarm.PLOT_RECTS = {
  { x0 = 6, y0 = 12, x1 = 7, y1 = 13 },
  { x0 = 10, y0 = 12, x1 = 11, y1 = 13 },
  { x0 = 14, y0 = 12, x1 = 15, y1 = 13 },
  { x0 = 6, y0 = 16, x1 = 7, y1 = 17 },
  { x0 = 10, y0 = 16, x1 = 11, y1 = 17 },
  { x0 = 14, y0 = 16, x1 = 15, y1 = 17 },
  { x0 = 6, y0 = 20, x1 = 7, y1 = 21 },
  { x0 = 10, y0 = 20, x1 = 11, y1 = 21 },
  { x0 = 14, y0 = 20, x1 = 15, y1 = 21 },
}

local function markName(plotIndex)
  return ("BERRY_PLOT_MARK_%d"):format(plotIndex)
end

-- Plot art (mods/Kanto-Reforged/assets/plot_*.png) is fetched by
-- generate_pokemon_mod.py from pret/pokeemerald's berry-tree object
-- graphics rather than checked in, same as every Pokémon sprite that
-- script pulls from PokeAPI — see generate_berry_farm_assets() there.
-- The ground itself is plain grass (below); a single marker sprite per
-- plot swaps between a soil patch (empty, so it still reads as farmland
-- instead of lawn), a shared sprout (growing), and the berry-specific ripe
-- tree (ready) — see plotSpriteFor/syncPlotMarkers.
BerryFarm.PLOT_SPRITE_SOIL = "SPRITE_PLOT_SOIL"
BerryFarm.PLOT_SPRITE_GROWING = "SPRITE_PLOT_GROWING"
BerryFarm.PLOT_SPRITE_BY_BERRY = {
  BERRY = "SPRITE_PLOT_BERRY",
  CHERI_BERRY = "SPRITE_PLOT_CHERI",
  CHESTO_BERRY = "SPRITE_PLOT_CHESTO",
  PECHA_BERRY = "SPRITE_PLOT_PECHA",
  RAWST_BERRY = "SPRITE_PLOT_RAWST",
  ASPEAR_BERRY = "SPRITE_PLOT_ASPEAR",
  PERSIM_BERRY = "SPRITE_PLOT_PERSIM",
  LUM_BERRY = "SPRITE_PLOT_LUM",
}

local function registerPlotSprites(mod)
  -- Full-RGBA pokeemerald berry art — not grayscale OW sheets. Gen1 mostly
  -- drew these raw; Gen2's SpriteRenderer remaps every NPC through PAL_OW_*
  -- unless trueColor is set, which turns brown soil into weird green/pink.
  local function sprite(id, file)
    mod.content.sprites:register(id, {
      image = "mods/Kanto-Reforged/assets/" .. file,
      frames = 1,
      walker = false,
      trueColor = true,
      spriteType = "STILL_SPRITE",
    })
  end
  sprite(BerryFarm.PLOT_SPRITE_SOIL, "plot_soil.png")
  sprite(BerryFarm.PLOT_SPRITE_GROWING, "plot_growing.png")
  for berryId, spriteId in pairs(BerryFarm.PLOT_SPRITE_BY_BERRY) do
    sprite(spriteId, "plot_" .. berryId:gsub("_BERRY$", ""):lower() .. ".png")
  end
end

-- Which single sprite a plot shows right now: the bare soil patch while
-- empty, the shared sprout while growing, the berry-specific ripe tree
-- once ready. One marker per plot (never two sprites stacked on the same
-- cell) so there is nothing for the renderer's entity order to fight over.
local function plotSpriteFor(steps, p, growNeed)
  growNeed = growNeed or BerryFarm.GROW_STEPS
  if not p or not p.berryId then return BerryFarm.PLOT_SPRITE_SOIL end
  if (steps - (p.plantedAtSteps or 0)) >= growNeed then
    return BerryFarm.PLOT_SPRITE_BY_BERRY[p.berryId] or BerryFarm.PLOT_SPRITE_BY_BERRY.BERRY
  end
  return BerryFarm.PLOT_SPRITE_GROWING
end

local function plotTextId(i)
  return ("TEXT_BERRY_FARM_PLOT_%d"):format(i)
end

local function plotIndexAt(cx, cy)
  for i, r in ipairs(BerryFarm.PLOT_RECTS) do
    if cx >= r.x0 and cx <= r.x1 and cy >= r.y0 and cy <= r.y1 then
      return i
    end
  end
  return nil
end

local function plotKey(plotIndex)
  return tostring(plotIndex)
end

-- Normalize legacy numeric keys ("1" vs 1) into a string-keyed map.
local function readPlots(raw)
  local out = {}
  if type(raw) ~= "table" then return out end
  for k, v in pairs(raw) do
    if type(v) == "table" and v.berryId then
      local idx = tonumber(k)
      if idx and idx >= 1 and idx <= BerryFarm.PLOT_COUNT then
        out[plotKey(idx)] = {
          berryId = v.berryId,
          plantedAtSteps = v.plantedAtSteps or 0,
        }
      end
    end
  end
  return out
end

local function writePlots(mod, plots)
  -- Always store a fresh string-keyed table so a cleared slot cannot
  -- resurrect from a stale numeric-key alias or a shared reference.
  local Host = require("mods.Kanto-Reforged.host")
  local stored = {}
  for i = 1, BerryFarm.PLOT_COUNT do
    local p = plots[plotKey(i)]
    if p and p.berryId then
      stored[plotKey(i)] = {
        berryId = p.berryId,
        plantedAtSteps = p.plantedAtSteps or 0,
      }
    end
  end
  Host.saveSet(mod.save, "plots", stored)
  return stored
end

local function ensureState(mod)
  local Host = require("mods.Kanto-Reforged.host")
  local steps = Host.saveGet(mod.save, "farmSteps", 0)
  if type(steps) ~= "number" then steps = 0 end
  local plots = readPlots(Host.saveGet(mod.save, "plots", nil))
  -- Persist normalized shape once (migrates legacy [1]=... saves)
  if Host.saveGet(mod.save, "plots", nil) == nil then
    writePlots(mod, plots)
  end
  return steps, plots
end

local function getPlot(plots, plotIndex)
  return plots[plotKey(plotIndex)]
end

local function setPlot(mod, plots, plotIndex, entry)
  plots[plotKey(plotIndex)] = entry
  return writePlots(mod, plots)
end

local function clearPlot(mod, plots, plotIndex)
  plots[plotKey(plotIndex)] = nil
  return writePlots(mod, plots)
end

-- Each plot rect is a full block (2x2 cells); the marker sprites are one
-- cell (16x16), so they're anchored on the rect's bottom-left cell — the
-- engine draws a sprite's top-left 4px above its cell (SpriteRenderer:draw),
-- so anchoring on the *top* cell of a 2-tall rect put the old markers
-- floating half off the plot into the row above it. The bottom cell keeps
-- the sprite's footprint inside the plot itself.
local function plotAnchor(r)
  return r.x0, r.y1
end

-- One marker per plot, spawned at runtime from save state and swapped in
-- place as it grows: soil patch → shared sprout → berry-specific ripe
-- tree. A second sprite stacked on the same cell (an earlier version had
-- a permanent soil layer plus a separate growth overlay) fought the first
-- for draw order every time either got removed/respawned, flickering which
-- one rendered on top — one marker per plot sidesteps that entirely.
local function syncPlotMarkers(mod)
  local world = mod.world
  if not world or not world.overworld then return end
  local ow = world:overworld()
  if not ow or not ow.map or ow.map.id ~= BerryFarm.MAP_ID then return end
  local steps, plots = ensureState(mod)
  local growNeed = BerryFarm.growSteps(mod)
  for i = 1, BerryFarm.PLOT_COUNT do
    local name = markName(i)
    local p = getPlot(plots, i)
    local sprite = plotSpriteFor(steps, p, growNeed)
    local handle = world:npc(BerryFarm.MAP_ID, name)
    local current = handle and handle.npc and handle.npc.def and handle.npc.def.sprite
    if current ~= sprite then
      if handle then world:removeNpc(handle.id) end
      local r = BerryFarm.PLOT_RECTS[i]
      local ax, ay = plotAnchor(r)
      world:spawnNpc(BerryFarm.MAP_ID, {
        name = name,
        sprite = sprite,
        movement = "STAY",
        range = "NONE",
        text = plotTextId(i),
        x = ax,
        y = ay,
      })
    end
  end
end

function BerryFarm.farmSteps(mod)
  local steps = ensureState(mod)
  return steps
end

function BerryFarm.bumpStep(mod)
  mod = mod or BerryFarm._mod
  if not mod then return end
  local Host = require("mods.Kanto-Reforged.host")
  local steps = Host.saveGet(mod.save, "farmSteps", 0)
  if type(steps) ~= "number" then steps = 0 end
  Host.saveSet(mod.save, "farmSteps", steps + 1)
  syncPlotMarkers(mod)
end

function BerryFarm.plotReady(mod, plotIndex)
  local steps, plots = ensureState(mod)
  local p = getPlot(plots, plotIndex)
  if not p or not p.berryId then return false end
  return (steps - (p.plantedAtSteps or 0)) >= BerryFarm.growSteps(mod)
end

function BerryFarm.stepsRemaining(mod, plotIndex)
  local steps, plots = ensureState(mod)
  local p = getPlot(plots, plotIndex)
  if not p or not p.berryId then return 0 end
  local left = BerryFarm.growSteps(mod) - (steps - (p.plantedAtSteps or 0))
  if left < 0 then left = 0 end
  return left
end

-- Which single sprite (soil / shared sprout / berry-specific ripe art) a
-- plot should currently show. Exposed for tests; syncPlotMarkers uses the
-- same plotSpriteFor helper against live save state.
function BerryFarm.plotMarkerSprite(mod, plotIndex)
  local steps, plots = ensureState(mod)
  return plotSpriteFor(steps, getPlot(plots, plotIndex), BerryFarm.growSteps(mod))
end

local function pushText(game, msg, done)
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, msg, done))
end

-- What each farm berry does (bag use / held). Gen 1-length pages.
BerryFarm.SCHOLAR_ENTRIES = {
  {
    id = "BERRY",
    blurb = "A plain BERRY.\nRestores 10 HP\vwhen used or held.",
  },
  {
    id = "CHERI_BERRY",
    blurb = "CHERI BERRY cures\nparalysis.",
  },
  {
    id = "CHESTO_BERRY",
    blurb = "CHESTO BERRY wakes\na sleeping POKéMON.",
  },
  {
    id = "PECHA_BERRY",
    blurb = "PECHA BERRY cures\npoison.",
  },
  {
    id = "RAWST_BERRY",
    blurb = "RAWST BERRY heals\na burn.",
  },
  {
    id = "ASPEAR_BERRY",
    blurb = "ASPEAR BERRY thaws\na frozen POKéMON.",
  },
  {
    id = "PERSIM_BERRY",
    blurb = "PERSIM BERRY snaps\na POKéMON out of\vconfusion.",
  },
  {
    id = "LUM_BERRY",
    blurb = "LUM BERRY cures any\nstatus problem or\vconfusion.",
  },
}

local function makeScholarTalk()
  return function(game, ow, npc, done)
    local ListMenu = require("src.ui.ListMenu")
    local rows = {}
    for _, entry in ipairs(BerryFarm.SCHOLAR_ENTRIES) do
      local def = HeldItems.def(entry.id) or (game.data.items and game.data.items[entry.id])
      rows[#rows + 1] = {
        label = (def and def.name) or entry.id,
        value = entry,
      }
    end
    pushText(game, Strings(
      "I'm the BERRY\nSCHOLAR!\f"
      .. "Ask me about any\nberry we grow."), function()
      game.stack:push(ListMenu.new(game, Strings("Which berry?"), rows, {
        onChoose = function(row, menu)
          menu:close()
          pushText(game, Strings(row.value.blurb), done)
        end,
        onCancel = function()
          if done then done() end
        end,
      }))
    end)
  end
end

local function makePlotTalk(mod, plotIndex)
  return function(game, ow, npc, done)
    local Bag = require("src.inventory.Bag")
    local ListMenu = require("src.ui.ListMenu")
    local steps, plots = ensureState(mod)
    local p = getPlot(plots, plotIndex)

    if not p or not p.berryId then
      local rows = {}
      local plantable = {}
      for _, id in ipairs(BerryFarm.plantableList(mod)) do
        plantable[id] = true
      end
      for _, id in ipairs(HeldItems.BERRY_PACK) do
        local n = (game.save.inventory and game.save.inventory[id]) or 0
        if n > 0 and plantable[id] then
          local def = HeldItems.def(id)
          rows[#rows + 1] = {
            value = id,
            label = def and def.name or id,
            right = "x" .. tostring(n),
          }
        end
      end
      if #rows == 0 then
        pushText(game, Strings(
          "This flower bed\nis empty.\f"
            .. "Buy berries at the\nstall, or harvest\vmore from plots!"), done)
        return
      end
      pushText(game, Strings("Plant which\nberry?"), function()
        game.stack:push(ListMenu.new(game, Strings("Plant which?"), rows, {
          onChoose = function(row, list)
            list:close()
            local id = row.value
            if (game.save.inventory[id] or 0) <= 0 then
              done()
              return
            end
            -- Re-read state at confirm time (avoid stale closure table)
            local _, live = ensureState(mod)
            Bag.remove(game.save, id, 1)
            setPlot(mod, live, plotIndex, {
              berryId = id,
              plantedAtSteps = require("mods.Kanto-Reforged.host")
                .saveGet(mod.save, "farmSteps", 0),
            })
            syncPlotMarkers(mod)
            local def = HeldItems.def(id)
            pushText(game, Strings("Planted the\n%s!", def and def.name or id), done)
          end,
          onCancel = done,
        }))
      end)
      return
    end

    if not BerryFarm.plotReady(mod, plotIndex) then
      local left = BerryFarm.stepsRemaining(mod, plotIndex)
      local def = HeldItems.def(p.berryId)
      -- Keep each page to 2 lines even with long berry names (soft-wrap).
      pushText(game, Strings(
        "%s\nis growing...\f"
        .. "%d steps left.",
        def and def.name or p.berryId, left), done)
      return
    end

    local def = HeldItems.def(p.berryId)
    local yield = BerryFarm.HARVEST_YIELD
    if not Bag.add(game.save, p.berryId, yield) then
      pushText(game, Strings("The bag is full!"), done)
      return
    end
    local _, live = ensureState(mod)
    clearPlot(mod, live, plotIndex)
    syncPlotMarkers(mod)
    pushText(game, Strings("Harvested %d\n%s!", yield, def and def.name or p.berryId), done)
  end
end

function BerryFarm.register(mod)
  local Host = require("mods.Kanto-Reforged.host")
  local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
  registerPlotSprites(mod)
  -- Width 19: farm yard cols 0–8, grass buffer col 9, shore col 10,
  -- lake cols 11–17, tree wall closes the east edge at col 18.
  local width, height = 19, 12
  -- Gen1: OVERWORLD + GEN1_TILES only (custom plot sprites on top).
  -- Gen2: TILESET_JOHTO + GEN2_TILES when Gold tilesets are present.
  -- Never label a Gen1 stand-in as TILESET_JOHTO for this map.
  local tileset = "OVERWORLD"
  local destCenter = "VIRIDIAN_POKECENTER"
  local tilePack = GEN1_TILES
  if Host.isGen2() then
    destCenter = "VIRIDIAN_POKECENTER_1F"
    if not (mod.content.maps:get(destCenter)) then
      destCenter = BerryFarm.MAP_ID
    end
    local realJohto = johtoTilesetData(mod)
    if realJohto then
      tileset = "TILESET_JOHTO"
      tilePack = GEN2_TILES
      local cur = mod.content.tilesets:get(tileset)
      if not (cur and type(cur.collision) == "table" and #cur.collision >= 64) then
        pcall(function()
          if cur then
            mod.content.tilesets:override(tileset, realJohto)
          else
            mod.content.tilesets:register(tileset, realJohto)
          end
        end)
      end
    end
    -- No Gold Johto cache: keep OVERWORLD + GEN1_TILES (matched pair) rather
    -- than inventing a fake TILESET_JOHTO from Red's sheet.
  end
  local WALL = tilePack.WALL
  local blocks = buildFarmBlocks(tilePack)

  local talk = {
    TEXT_BERRY_FARM_GIRL = function(game, ow, npc, done)
      -- Text box shows 2 lines; use \f between pages (button each time).
      -- Never put 3+ \n lines on one page — that auto-scrolls.
      pushText(game, Strings(
        "Welcome to the\nBERRY FARM!\f"
        .. "Flower beds grow\nberries here.\f"
        .. "Face a bed and\npress A to plant.\f"
        .. "Buy berries at the\nstall anytime!\f"
        .. "Walk around, then\ncome back later.\f"
        .. "Harvest when it's\nready!\f"
        .. "The shed door\ntakes you back.\f"
        .. "Back to the last\nPOKéMON CENTER."), done)
    end,
    TEXT_BERRY_FARM_FISHER = function(game, ow, npc, done)
      pushText(game, Strings(
        "Nice spot for a\nfarm, huh?\f"
        .. "You can SURF the\nlake if you want.\f"
        .. "Nothing's out\nthere to find."), done)
    end,
    TEXT_BERRY_FARM_SCHOLAR = makeScholarTalk(),
  }

  for i = 1, #BerryFarm.PLOT_RECTS do
    talk[plotTextId(i)] = makePlotTalk(mod, i)
  end

  mod.content.maps:register(BerryFarm.MAP_ID, {
    id = BerryFarm.MAP_ID,
    label = "BerryFarm",
    index = 1100,
    tileset = tileset,
    width = width,
    height = height,
    blocks = blocks,
    borderBlock = WALL,
    warps = {
      {
        x = BerryFarm.LANDING.x,
        y = BerryFarm.LANDING.y,
        destMap = destCenter,
        destWarp = 1,
      },
      {
        x = BerryFarm.EXIT.x,
        y = BerryFarm.EXIT.y,
        destMap = destCenter,
        destWarp = 1,
      },
    },
    objects = {
      {
        index = 1,
        name = "BERRY_FARM_GIRL",
        sprite = HouseNpcs.spriteFor("SPRITE_BRUNETTE_GIRL"),
        movement = "STAY",
        range = "DOWN",
        text = "TEXT_BERRY_FARM_GIRL",
        x = 12,
        y = 7,
      },
      {
        index = 2,
        name = "BERRY_FARM_FISHER",
        sprite = "SPRITE_FISHER",
        movement = "STAY",
        range = "RIGHT",
        text = "TEXT_BERRY_FARM_FISHER",
        x = 19,
        y = 13,
      },
      {
        index = 4,
        name = "BERRY_FARM_SCHOLAR",
        sprite = "SPRITE_SUPER_NERD",
        movement = "STAY",
        range = "RIGHT",
        text = "TEXT_BERRY_FARM_SCHOLAR",
        -- West strip by the plots (clear of girl / soil / fisher).
        x = 4,
        y = 8,
      },
    },
    signs = {},
  })

  local Host = require("mods.Kanto-Reforged.host")
  if Host.isGen1() then
    mod.content.map_scripts:register(BerryFarm.MAP_ID, {
      talk = talk,
      onEnter = function(game, ow)
        syncPlotMarkers(mod)
      end,
      onInteract = function(game, ow, fx, fy)
        local idx = plotIndexAt(fx, fy)
        if not idx then return false end
        makePlotTalk(mod, idx)(game, ow, nil, function() end)
        return true
      end,
    })

    for _, mapId in ipairs(BerryFarm.ALL_POKECENTERS) do
      mod.content.maps:patch(mapId, {
        blocks = BerryFarm.PC_BLOCKS,
        warps = {
          __append = {
            {
              x = BerryFarm.PC_DOOR.x,
              y = BerryFarm.PC_DOOR.y,
              destMap = BerryFarm.MAP_ID,
              destWarp = 1,
            },
            {
              x = BerryFarm.PC_DOOR_B.x,
              y = BerryFarm.PC_DOOR_B.y,
              destMap = BerryFarm.MAP_ID,
              destWarp = 1,
            },
          },
        },
      })
    end
  else
    HouseNpcs.bindTalk(mod, BerryFarm.MAP_ID, talk)

    local function appendFarmWarps(mapId, a, b)
      local rows = {
        {
          x = a.x, y = a.y,
          destMap = BerryFarm.MAP_ID,
          destWarp = 1,
        },
      }
      if b then
        rows[#rows + 1] = {
          x = b.x, y = b.y,
          destMap = BerryFarm.MAP_ID,
          destWarp = 1,
        }
      end
      mod.content.maps:patch(mapId, {
        warps = { __append = rows },
      })
    end

    -- Johto: east stairs block (same metatile as 2F stairs) + warp on its
    -- warp-collision cell (8,7). Plain warp on floor tiles never fires.
    for _, mapId in ipairs(BerryFarm.ALL_POKECENTERS_GEN2_JOHTO) do
      pcall(function()
        mod.content.maps:patch(mapId, {
          blocks = BerryFarm.PC_BLOCKS_GEN2_JOHTO,
          warps = {
            __append = {
              {
                x = BerryFarm.PC_DOOR_GEN2_STAIRS.x,
                y = BerryFarm.PC_DOOR_GEN2_STAIRS.y,
                destMap = BerryFarm.MAP_ID,
                destWarp = 1,
              },
            },
          },
        })
      end)
    end
    for _, mapId in ipairs(BerryFarm.ALL_POKECENTERS_GEN2_STAIRS_ONLY) do
      pcall(function()
        local door = BerryFarm.gen2DoorFor(mapId)
        mod.content.maps:patch(mapId, {
          blocks = BerryFarm.PC_BLOCKS_GEN2_INDIGO,
          warps = {
            __append = {
              {
                x = door.x,
                y = door.y,
                destMap = BerryFarm.MAP_ID,
                destWarp = 1,
              },
            },
          },
        })
      end)
    end
    -- Kanto: exit-mat pair + south-row block rewrite (pad look).
    for _, mapId in ipairs(BerryFarm.ALL_POKECENTERS_GEN2_KANTO) do
      pcall(function()
        mod.content.maps:patch(mapId, {
          blocks = BerryFarm.PC_BLOCKS_GEN2_KANTO,
          warps = {
            __append = {
              {
                x = BerryFarm.PC_DOOR_GEN2_PAD.x,
                y = BerryFarm.PC_DOOR_GEN2_PAD.y,
                destMap = BerryFarm.MAP_ID,
                destWarp = 1,
              },
              {
                x = BerryFarm.PC_DOOR_GEN2_PAD_B.x,
                y = BerryFarm.PC_DOOR_GEN2_PAD_B.y,
                destMap = BerryFarm.MAP_ID,
                destWarp = 1,
              },
            },
          },
        })
      end)
    end
  end
end

function BerryFarm.install(mod)
  local Host = require("mods.Kanto-Reforged.host")
  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
  BerryFarm._mod = mod
  ensureState(mod)

  local function grantStarterBerry(game)
    if not game or not game.save then return end
    BerryFarm.ensureUnlocked(mod)
    if Host.saveGet(mod.save, "starterGranted", false) then return end
    local Bag = require("src.inventory.Bag")
    Bag.add(game.save, "BERRY", 3)
    Host.saveSet(mod.save, "starterGranted", true)
  end

  if Host.isGen1() then
    -- Never remember the farm as the outdoor side (PC LAST_MAP poison).
    Gen1Patch.apply(require("src.world.OverworldController"), function(OverworldState)
      if OverworldState._berryFarmRememberOutdoor then return end
      local origRemember = OverworldState.rememberOutdoor
      if type(origRemember) ~= "function" then return end
      OverworldState.rememberOutdoor = function(self, id, x, y)
        if id == BerryFarm.MAP_ID then return end
        return origRemember(self, id, x, y)
      end
      OverworldState._berryFarmRememberOutdoor = true
    end)
  end

  local function currentOutdoor()
    local Game = package.loaded["src.core.Game"]
    local lo = Game and Game.save and Game.save.lastOutdoor
    if lo and lo.id and lo.id ~= BerryFarm.MAP_ID then
      return { id = lo.id, x = lo.x, y = lo.y }
    end
    return nil
  end

  mod.events:on("player.warped", function(ev)
    if not ev or ev.toMap ~= BerryFarm.MAP_ID then return end
    local from = ev.fromMap
    if type(from) == "string" and from:find("POKECENTER", 1, true) then
      local cell = BerryFarm.returnCellFor(from)
      Host.saveSet(mod.save, "returnCenter", {
        map = from,
        x = cell.x,
        y = cell.y,
      })
    end
    local outdoor = currentOutdoor()
    if outdoor then
      Host.saveSet(mod.save, "savedOutdoor", outdoor)
    end
    local Game = package.loaded["src.core.Game"]
    grantStarterBerry(Game)
    if Host.isGen2() then
      syncPlotMarkers(mod)
    end
  end)

  mod.hooks:wrap("warp.destination", function(next, mapId, x, y, ctx)
    local warp = ctx and ctx.warp

    if warp and warp.x == BerryFarm.EXIT.x and warp.y == BerryFarm.EXIT.y
        and type(warp.destMap) == "string"
        and warp.destMap:find("POKECENTER", 1, true) then
      local ret = Host.saveGet(mod.save, "returnCenter", nil)
      if ret and ret.map then
        local cell = BerryFarm.returnCellFor(ret.map)
        return ret.map, ret.x or cell.x, ret.y or cell.y
      end
    end

    if mapId == BerryFarm.MAP_ID and warp and warp.destMap == "LAST_MAP" then
      local saved = Host.saveGet(mod.save, "savedOutdoor", nil) or currentOutdoor()
      if saved and saved.id and saved.id ~= BerryFarm.MAP_ID then
        local destDef = ctx.data and ctx.data.maps and ctx.data.maps[saved.id]
        local dw = destDef and destDef.warps and destDef.warps[warp.destWarp]
        if dw then
          return saved.id, dw.x, dw.y
        end
        return saved.id, saved.x, saved.y
      end
    end

    return next(mapId, x, y, ctx)
  end)

  if Host.isGen1() then
    Gen1Patch.apply(require("src.world.Player"), function(Player)
      if Player._berryFarmStepHook then return end
      local origUpdate = Player.update
      if type(origUpdate) ~= "function" then return end
      Player.update = function(self, ...)
        local landed = origUpdate(self, ...)
        if landed then
          BerryFarm.bumpStep(BerryFarm._mod)
        end
        return landed
      end
      Player._berryFarmStepHook = true
    end)
  else
    -- Gold: step growth + plot interact via world events (no map_scripts).
    mod.events:on("world.stepped", function(ev)
      BerryFarm.bumpStep(mod)
    end)
    mod.events:on("map.entered", function(ev)
      if ev and ev.mapId == BerryFarm.MAP_ID then
        syncPlotMarkers(mod)
      end
    end)
    mod.events:on("world.interacted", function(ev)
      if not ev or ev.mapId ~= BerryFarm.MAP_ID then return end
      local idx = plotIndexAt(ev.x, ev.y)
      if not idx then return end
      local Game = package.loaded["src.core.Game"]
      if Game then
        makePlotTalk(mod, idx)(Game, nil, nil, function() end)
      end
    end)
  end
end

return BerryFarm
