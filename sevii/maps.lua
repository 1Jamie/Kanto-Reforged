-- Sevii maps (indices 1200+). Layouts from sevii_semantic_remap.py
-- (FRLG behaviors → Gen1 OVERWORLD blocks). No FRLG art.

local SeviiMaps = {}

SeviiMaps.IDS = {
  ONE_ISLAND = "SEVII_ONE_ISLAND",
  HARBOR = "SEVII_ONE_ISLAND_HARBOR",
  POKECENTER = "SEVII_ONE_ISLAND_POKECENTER",
  MART = "SEVII_ONE_ISLAND_MART",
  KINDLE_ROAD = "SEVII_ONE_ISLAND_KINDLE_ROAD",
  TREASURE_BEACH = "SEVII_ONE_ISLAND_TREASURE_BEACH",
}

SeviiMaps.INDEX = {
  SEVII_ONE_ISLAND = 1200,
  SEVII_ONE_ISLAND_HARBOR = 1201,
  SEVII_ONE_ISLAND_POKECENTER = 1202,
  SEVII_ONE_ISLAND_MART = 1203,
  SEVII_ONE_ISLAND_KINDLE_ROAD = 1204,
  SEVII_ONE_ISLAND_TREASURE_BEACH = 1205,
}

-- OVERWORLD Sevii maps — never lastOutdoor; never "indoor every-tile" wilds.
SeviiMaps.OUTDOOR = {
  SEVII_ONE_ISLAND = true,
  SEVII_ONE_ISLAND_HARBOR = true,
  SEVII_ONE_ISLAND_KINDLE_ROAD = true,
  SEVII_ONE_ISLAND_TREASURE_BEACH = true,
}

local TREE, WATER = 15, 67

local function harborBlocks(w, h)
  local T, G, C, D, W = 15, 1, 85, 10, 67
  local blocks = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local b
      if x == 0 or x == w - 1 or y == h - 1 then
        b = W
      elseif y == 0 then
        b = T
      elseif y <= 2 and x >= 2 and x <= w - 3 then
        b = C
      elseif y == 3 and x >= 3 and x <= w - 4 then
        b = D
      else
        b = W
      end
      blocks[#blocks + 1] = b
    end
  end
  return blocks
end

local PC_BLOCKS = {
  32, 16, 1, 2, 12, 13, 13, 33, 4, 5, 7, 7, 34, 35, 8, 15, 15, 15, 15, 15, 27, 14, 10, 11, 14,
  15, 15, 14,
}
local MART_BLOCKS = {
  18, 19, 19, 9, 22, 15, 20, 20, 24, 25, 21, 21, 23, 26, 11, 15,
}

function SeviiMaps.register(mod)
  local ok, Layout = pcall(require, "mods.Kanto-Reforged.sevii.layout_data")
  if not ok or not Layout or not Layout.SEVII_ONE_ISLAND then
    error("sevii/layout_data.lua missing — run sevii_semantic_remap.py")
  end

  local town = Layout.SEVII_ONE_ISLAND
  local kindle = Layout.SEVII_ONE_ISLAND_KINDLE_ROAD
  local beach = Layout.SEVII_ONE_ISLAND_TREASURE_BEACH
  local meta = Layout.meta or {}
  local townMeta = meta.SEVII_ONE_ISLAND or {}
  local kindleMeta = meta.SEVII_ONE_ISLAND_KINDLE_ROAD or {}

  mod.content.maps:register("SEVII_ONE_ISLAND", {
    id = "SEVII_ONE_ISLAND",
    label = "SeviiOneIsland",
    index = 1200,
    tileset = "OVERWORLD",
    width = town.width,
    height = town.height,
    blocks = town.blocks,
    borderBlock = WATER,
    -- Warps from layout_data meta (generated from stamped doors) when present
    warps = townMeta.warps or {
      { x = 13, y = 5, destMap = "SEVII_ONE_ISLAND_POKECENTER", destWarp = 1 },
      { x = 14, y = 5, destMap = "SEVII_ONE_ISLAND_POKECENTER", destWarp = 1 },
      { x = 17, y = 5, destMap = "SEVII_ONE_ISLAND_MART", destWarp = 1 },
      { x = 18, y = 5, destMap = "SEVII_ONE_ISLAND_MART", destWarp = 1 },
      { x = 12, y = 16, destMap = "SEVII_ONE_ISLAND_HARBOR", destWarp = 1 },
      { x = 13, y = 16, destMap = "SEVII_ONE_ISLAND_HARBOR", destWarp = 1 },
    },
    objects = {
      {
        index = 1, name = "SEVII_ONE_ISLAND_OLD_MAN",
        sprite = "SPRITE_GRAMPS", movement = "WALK", range = "ANY_DIR",
        text = "TEXT_SEVII_ONE_ISLAND_SIGN",
        x = 14, y = 12,
      },
    },
    signs = {},
    connections = {
      east = {
        map = "SEVII_ONE_ISLAND_KINDLE_ROAD",
        offset = townMeta.east_offset or -(kindle.height - town.height),
      },
      south = { map = "SEVII_ONE_ISLAND_TREASURE_BEACH", offset = 0 },
    },
  })

  local hw, hh = 10, 6
  mod.content.maps:register("SEVII_ONE_ISLAND_HARBOR", {
    id = "SEVII_ONE_ISLAND_HARBOR",
    label = "SeviiOneIslandHarbor",
    index = 1201,
    tileset = "OVERWORLD",
    width = hw,
    height = hh,
    blocks = harborBlocks(hw, hh),
    borderBlock = WATER,
    warps = {
      { x = 8, y = 2, destMap = "SEVII_ONE_ISLAND", destWarp = 5 },
      { x = 9, y = 2, destMap = "SEVII_ONE_ISLAND", destWarp = 5 },
    },
    objects = {
      {
        index = 1, name = "SEVII_HARBOR_SAILOR",
        sprite = "SPRITE_SAILOR", movement = "STAY", range = "DOWN",
        text = "TEXT_SEVII_HARBOR_SAILOR",
        x = 12, y = 6,
      },
    },
    signs = {},
    connections = {},
  })

  mod.content.maps:register("SEVII_ONE_ISLAND_POKECENTER", {
    id = "SEVII_ONE_ISLAND_POKECENTER",
    label = "SeviiOneIslandPokecenter",
    index = 1202,
    tileset = "POKECENTER",
    width = 7,
    height = 4,
    blocks = PC_BLOCKS,
    borderBlock = 0,
    warps = {
      { x = 3, y = 7, destMap = "SEVII_ONE_ISLAND", destWarp = 1 },
      { x = 4, y = 7, destMap = "SEVII_ONE_ISLAND", destWarp = 1 },
    },
    objects = {
      {
        index = 1, name = "SEVII_ONE_PC_NURSE",
        sprite = "SPRITE_NURSE", movement = "STAY", range = "DOWN",
        text = "TEXT_SEVII_ONE_PC_NURSE",
        x = 3, y = 1,
      },
    },
    signs = {},
    connections = {},
  })

  mod.content.maps:register("SEVII_ONE_ISLAND_MART", {
    id = "SEVII_ONE_ISLAND_MART",
    label = "SeviiOneIslandMart",
    index = 1203,
    tileset = "MART",
    width = 4,
    height = 4,
    blocks = MART_BLOCKS,
    borderBlock = 0,
    warps = {
      { x = 3, y = 7, destMap = "SEVII_ONE_ISLAND", destWarp = 3 },
      { x = 4, y = 7, destMap = "SEVII_ONE_ISLAND", destWarp = 3 },
    },
    objects = {
      {
        index = 1, name = "SEVII_ONE_MART_CLERK",
        sprite = "SPRITE_CLERK", movement = "STAY", range = "RIGHT",
        text = "TEXT_SEVII_ONE_MART_CLERK",
        x = 0, y = 5,
      },
    },
    signs = {},
    connections = {},
  })

  mod.content.maps:register("SEVII_ONE_ISLAND_KINDLE_ROAD", {
    id = "SEVII_ONE_ISLAND_KINDLE_ROAD",
    label = "SeviiKindleRoad",
    index = 1204,
    tileset = "OVERWORLD",
    width = kindle.width,
    height = kindle.height,
    blocks = kindle.blocks,
    borderBlock = WATER,
    warps = {},
    objects = {
      {
        index = 1, name = "SEVII_KINDLE_SIGN",
        sprite = "SPRITE_YOUNGSTER", movement = "STAY", range = "LEFT",
        text = "TEXT_SEVII_KINDLE_SIGN",
        x = 10, y = kindle.height * 2 - 8,
      },
    },
    signs = {},
    connections = {
      west = {
        map = "SEVII_ONE_ISLAND",
        offset = kindleMeta.west_offset or (kindle.height - town.height),
      },
    },
  })

  mod.content.maps:register("SEVII_ONE_ISLAND_TREASURE_BEACH", {
    id = "SEVII_ONE_ISLAND_TREASURE_BEACH",
    label = "SeviiTreasureBeach",
    index = 1205,
    tileset = "OVERWORLD",
    width = beach.width,
    height = beach.height,
    blocks = beach.blocks,
    borderBlock = WATER,
    warps = {},
    objects = {
      {
        index = 1, name = "SEVII_TREASURE_BOY",
        sprite = "SPRITE_YOUNGSTER", movement = "WALK", range = "ANY_DIR",
        text = "TEXT_SEVII_TREASURE_BOY",
        x = 12, y = 10,
      },
    },
    signs = {},
    connections = {
      north = { map = "SEVII_ONE_ISLAND", offset = 0 },
    },
  })

  mod.content.text_pointers:register("SeviiOneIsland", {
    TEXT_SEVII_ONE_ISLAND_SIGN = { text = "_SeviiOneIslandSign" },
  })
  mod.content.text:register("_SeviiOneIslandSign", "ONE ISLAND\nKnot Island")

  mod.content.text_pointers:register("SeviiOneIslandPokecenter", {
    TEXT_SEVII_ONE_PC_NURSE = { nurse = true },
  })
  mod.content.text_pointers:register("SeviiOneIslandMart", {
    TEXT_SEVII_ONE_MART_CLERK = {
      mart = {
        "POKE_BALL", "GREAT_BALL", "ULTRA_BALL",
        "POTION", "SUPER_POTION", "HYPER_POTION",
        "ANTIDOTE", "PARLYZ_HEAL", "AWAKENING", "BURN_HEAL", "ICE_HEAL",
        "ESCAPE_ROPE", "REPEL", "SUPER_REPEL",
      },
    },
  })
  mod.content.text_pointers:register("SeviiOneIslandHarbor", {
    TEXT_SEVII_HARBOR_SAILOR = { text = "_SeviiHarborSailor" },
  })
  mod.content.text:register("_SeviiHarborSailor",
    "Ready to sail\nback to KANTO?")

  mod.content.text_pointers:register("SeviiKindleRoad", {
    TEXT_SEVII_KINDLE_SIGN = { text = "_SeviiKindleSign" },
  })
  mod.content.text:register("_SeviiKindleSign",
    "KINDLE ROAD\nMt. Ember ahead")

  mod.content.text_pointers:register("SeviiTreasureBeach", {
    TEXT_SEVII_TREASURE_BOY = { text = "_SeviiTreasureBoy" },
  })
  mod.content.text:register("_SeviiTreasureBoy",
    "I dig for treasure\nin the sand!")
end

function SeviiMaps.install(mod)
  local OverworldState = require("src.world.OverworldController")
  if not OverworldState._seviiRememberOutdoor then
    local origRemember = OverworldState.rememberOutdoor
    OverworldState.rememberOutdoor = function(self, id, x, y)
      if SeviiMaps.OUTDOOR[id] then return end
      return origRemember(self, id, x, y)
    end
    OverworldState._seviiRememberOutdoor = true
  end

  -- Map indices ≥ firstIndoorMap (37) normally roll wilds on EVERY tile
  -- (caves/buildings). Sevii outdoor maps use 1200+ so they hit that path
  -- and caused encounters on cobble/dirt. Kill indoor terrain rolls there.
  if not SeviiMaps._indoorEncHooked then
    local origRoll = OverworldState.rollEncounter
    OverworldState.rollEncounter = function(self, encDef, terrain)
      if terrain == "indoor" and self.map and SeviiMaps.OUTDOOR[self.map.id] then
        return nil
      end
      return origRoll(self, encDef, terrain)
    end
    SeviiMaps._indoorEncHooked = true
  end
end

return SeviiMaps
