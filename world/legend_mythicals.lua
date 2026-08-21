-- Custom maps (≥1100) + Celebi / Jirachi / Deoxys / Rayquaza.

local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
local Strings = require("src.core.Strings")

local LegendMythicals = {}
LegendMythicals.OWNER = "legend_mythicals"

local WALL, GRASS, COBBLE, WATER, LEDGE, STUMP, SAND = 15, 1, 85, 67, 26, 28, 10

-- Build a sealed OVERWORLD room. Floor fill + optional inner ring.
local function fillRoom(w, h, fn)
  local blocks = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      blocks[#blocks + 1] = fn(x, y, w, h)
    end
  end
  return blocks
end

-- Sky Pillar: cobble plaza with ledge terrace and stump "altar".
local function skyPillarBlocks(w, h)
  return fillRoom(w, h, function(x, y, mw, mh)
    if x == 0 or y == 0 or x == mw - 1 or y == mh - 1 then return WALL end
    -- ledge strip under the north trees
    if y == 1 and x >= 2 and x <= mw - 3 then return LEDGE end
    -- stump altar near center (legendary stands just south)
    if x == 4 and y == 2 then return STUMP end
    if x == 5 and y == 2 then return STUMP end
    -- approach path
    if x == 4 or x == 5 then return COBBLE end
    return GRASS
  end)
end

-- Ilex shrine: grass clearing with stump circle.
local function ilexBlocks(w, h)
  return fillRoom(w, h, function(x, y, mw, mh)
    if x == 0 or y == 0 or x == mw - 1 or y == mh - 1 then return WALL end
    -- stump pair north of the shrine pad
    if (x == 4 or x == 5) and y == 2 then return STUMP end
    if x >= 3 and x <= 6 and y >= 3 and y <= 5 then return COBBLE end
    return GRASS
  end)
end

-- Birth Island: water moat + sand/cobble island (must be walkable without Surf).
local function birthIslandBlocks(w, h)
  return fillRoom(w, h, function(x, y, mw, mh)
    if x == 0 or y == 0 or x == mw - 1 or y == mh - 1 then return WALL end
    -- island platform (blocks 3..6, 2..5)
    local onIsle = x >= 3 and x <= 6 and y >= 2 and y <= 5
    if onIsle then
      if (x == 4 or x == 5) and (y == 3 or y == 4) then return COBBLE end
      return SAND
    end
    return WATER
  end)
end

local function staticBattle(species, level, flag)
  return function(game, ow, npc, done)
    local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
    if not SpeciesScope.allowsSpeciesId(SpeciesScope._mod, species, nil) then
      HouseNpcs.pushText(game, Strings(
        "Something stirs...\f"
          .. "It ignores a KANTO-\nonly DEX."), done)
      return
    end
    if game.save.flags and game.save.flags[flag] then
      HouseNpcs.pushText(game, Strings("..."), done)
      return
    end
    local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
    local battle
    Gen1Patch.apply(require("src.battle.BattleState"), function(bs)
      battle = bs.newWild(game, species, level)
    end)
    if not battle then if done then done() end return end
    battle.onFinish = function(result)
      if result == "win" or result == "caught" or result == "run" then
        game.save.flags = game.save.flags or {}
        game.save.flags[flag] = true
        game.save.defeatedTrainers = game.save.defeatedTrainers or {}
        if npc and npc.id then game.save.defeatedTrainers[npc.id] = true end
      end
      if ow and ow.afterBattle then ow:afterBattle(result, battle) end
      if done then done() end
    end
    if ow and ow.pushBattle then ow:pushBattle(battle) else game.stack:push(battle) end
  end
end

function LegendMythicals.register(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then return end
  mod.content.items:register("DNA_KEY", {
    id = "DNA_KEY", name = "DNA KEY", price = 0, keyItem = true, tossable = false,
  })

  -- SKY_PILLAR_KANT (Rayquaza) — index 1101
  local sw, sh = 10, 8
  mod.content.maps:register("SKY_PILLAR_KANT", {
    id = "SKY_PILLAR_KANT",
    label = "SkyPillarKant",
    index = 1101,
    tileset = "OVERWORLD",
    width = sw, height = sh,
    blocks = skyPillarBlocks(sw, sh),
    borderBlock = WALL,
    warps = {
      { x = 9, y = 12, destMap = "ROUTE_23", destWarp = 1 },
    },
    objects = {
      {
        index = 1, name = "SKYPILLARKANT_RAYQUAZA",
        sprite = "SPRITE_MONSTER", movement = "STAY", range = "DOWN",
        text = "TEXT_SKYPILLARKANT_RAYQUAZA",
        x = 9, y = 7, pokemon = "RAYQUAZA", level = 70,
      },
    },
    signs = {},
  })

  -- Patch Route 23 with a warp object / talk NPC to enter after Kyogre+Groudon
  HouseNpcs.appendNpc(mod, "ROUTE_23", {
    index = 8, name = "ROUTE23_SKY_GATE",
    sprite = "SPRITE_HIKER", text = "TEXT_ROUTE23_SKY_GATE",
    x = 10, y = 20,
  }, LegendMythicals.OWNER)

  -- ILEX_SHRINE_KANT — index 1102
  mod.content.maps:register("ILEX_SHRINE_KANT", {
    id = "ILEX_SHRINE_KANT",
    label = "IlexShrineKant",
    index = 1102,
    tileset = "OVERWORLD",
    width = sw, height = sh,
    blocks = ilexBlocks(sw, sh),
    borderBlock = WALL,
    warps = {
      { x = 9, y = 12, destMap = "VIRIDIAN_FOREST", destWarp = 1 },
    },
    objects = {
      {
        index = 1, name = "ILEXSHRINEKANT_CELEBI",
        sprite = "SPRITE_FAIRY", movement = "STAY", range = "DOWN",
        text = "TEXT_ILEXSHRINEKANT_CELEBI",
        x = 9, y = 7, pokemon = "CELEBI", level = 30,
      },
    },
    signs = {},
  })

  HouseNpcs.appendNpc(mod, "VIRIDIAN_FOREST", {
    index = 9, name = "VIRIDIANFOREST_SHRINE_GATE",
    sprite = "SPRITE_CHANNELER", text = "TEXT_VIRIDIANFOREST_SHRINE_GATE",
    x = 16, y = 20,
  }, LegendMythicals.OWNER)

  -- BIRTH_ISLAND_KANT — index 1103
  mod.content.maps:register("BIRTH_ISLAND_KANT", {
    id = "BIRTH_ISLAND_KANT",
    label = "BirthIslandKant",
    index = 1103,
    tileset = "OVERWORLD",
    width = sw, height = sh,
    blocks = birthIslandBlocks(sw, sh),
    borderBlock = WALL,
    warps = {
      { x = 9, y = 10, destMap = "VERMILION_DOCK", destWarp = 1 },
    },
    objects = {
      {
        index = 1, name = "BIRTHISLANDKANT_DEOXYS",
        sprite = "SPRITE_MONSTER", movement = "STAY", range = "DOWN",
        text = "TEXT_BIRTHISLANDKANT_DEOXYS",
        x = 9, y = 7, pokemon = "DEOXYS_NORMAL", level = 70,
      },
    },
    signs = {},
  })

  HouseNpcs.appendNpc(mod, "VERMILION_DOCK", {
    index = 1, name = "VERMILIONDOCK_SAILOR",
    sprite = "SPRITE_FISHER", text = "TEXT_VERMILIONDOCK_SAILOR",
    x = 14, y = 8,
  }, LegendMythicals.OWNER)

  -- Jirachi on Mt Moon B1F
  HouseNpcs.appendNpc(mod, "MT_MOON_B1F", {
    index = 1, name = "MTMOONB1F_JIRACHI",
    sprite = "SPRITE_FAIRY", text = "TEXT_MTMOONB1F_JIRACHI",
    x = 10, y = 10, pokemon = "JIRACHI", level = 30,
  }, LegendMythicals.OWNER)

  local function champ(game)
    return game.save.flags and game.save.flags.EVENT_BEAT_CHAMPION_RIVAL
  end

  -- Cell coords: land on / exit from the south path of each plaza.
  local LANDINGS = {
    SKY_PILLAR_KANT = { x = 9, y = 12 },
    ILEX_SHRINE_KANT = { x = 9, y = 12 },
    BIRTH_ISLAND_KANT = { x = 9, y = 10 },
  }

  local function saveReturnAndWarp(mod, game, ow, destMap)
    local fromMap, fx, fy
    if ow and ow.map and ow.player then
      fromMap, fx, fy = ow.map.id, ow.player.cellX, ow.player.cellY
    elseif mod.world and mod.world.current then
      local cur = mod.world:current()
      if cur then fromMap, fx, fy = cur.mapId, cur.x, cur.y end
    end
    if fromMap then
      mod.save:set("legend_return_" .. destMap, {
        map = fromMap, x = fx, y = fy,
      })
    end
    local land = LANDINGS[destMap] or { x = 9, y = 12 }
    if mod.world and mod.world.warpTo then
      mod.world:warpTo(destMap, land.x, land.y)
    elseif ow and ow.startWarpTo then
      ow:startWarpTo(destMap, land.x, land.y, "down")
    end
  end

  mod.content.map_scripts:register("ROUTE_23", {
    talk = {
      TEXT_ROUTE23_SKY_GATE = function(game, ow, npc, done)
        local f = game.save.flags or {}
        if not (f.MOD_EVENT_BEAT_KYOGRE and f.MOD_EVENT_BEAT_GROUDON) then
          HouseNpcs.pushText(game, Strings(
            "A path to the sky\nopens after the\vsea and land gods."), done)
          return
        end
        HouseNpcs.ask(game, Strings("Climb the sky\npillar?"), function(yes)
          if not yes then if done then done() end return end
          saveReturnAndWarp(mod, game, ow, "SKY_PILLAR_KANT")
          if done then done() end
        end)
      end,
    },
  })

  mod.content.map_scripts:register("VIRIDIAN_FOREST", {
    talk = {
      TEXT_VIRIDIANFOREST_SHRINE_GATE = function(game, ow, npc, done)
        if not champ(game) then
          HouseNpcs.pushText(game, Strings("A shrine awaits\nthe CHAMPION."), done)
          return
        end
        HouseNpcs.ask(game, Strings("Enter the shrine?"), function(yes)
          if not yes then if done then done() end return end
          saveReturnAndWarp(mod, game, ow, "ILEX_SHRINE_KANT")
          if done then done() end
        end)
      end,
    },
  })

  mod.content.map_scripts:register("VERMILION_DOCK", {
    talk = {
      TEXT_VERMILIONDOCK_SAILOR = function(game, ow, npc, done)
        if not champ(game) then
          HouseNpcs.pushText(game, Strings("Strange island...\nafter the league."), done)
          return
        end
        if not (game.save.inventory and game.save.inventory.DNA_KEY) then
          local legends = 0
          local owned = (game.save.pokedex and game.save.pokedex.owned) or {}
          for _, id in ipairs({
            "RAIKOU", "ENTEI", "SUICUNE", "LUGIA", "HO_OH",
            "KYOGRE", "GROUDON", "ARTICUNO", "ZAPDOS", "MOLTRES", "MEWTWO",
          }) do
            if owned[id] then legends = legends + 1 end
          end
          if legends < 3 then
            HouseNpcs.pushText(game, Strings(
              "Own 3 legendaries\nfirst."), done)
            return
          end
          HouseNpcs.giveItem(game, "DNA_KEY", 1)
          HouseNpcs.pushText(game, Strings("A DNA KEY!\nWant a ride?"), done)
          return
        end
        HouseNpcs.ask(game, Strings("Sail to BIRTH\nISLAND?"), function(yes)
          if not yes then if done then done() end return end
          saveReturnAndWarp(mod, game, ow, "BIRTH_ISLAND_KANT")
          if done then done() end
        end)
      end,
    },
  })

  mod.content.map_scripts:register("SKY_PILLAR_KANT", {
    talk = { TEXT_SKYPILLARKANT_RAYQUAZA = staticBattle("RAYQUAZA", 70, "MOD_EVENT_BEAT_RAYQUAZA") },
  })
  mod.content.map_scripts:register("ILEX_SHRINE_KANT", {
    talk = { TEXT_ILEXSHRINEKANT_CELEBI = staticBattle("CELEBI", 30, "MOD_EVENT_BEAT_CELEBI") },
  })
  mod.content.map_scripts:register("BIRTH_ISLAND_KANT", {
    talk = { TEXT_BIRTHISLANDKANT_DEOXYS = staticBattle("DEOXYS_NORMAL", 70, "MOD_EVENT_BEAT_DEOXYS") },
  })
  mod.content.map_scripts:register("MT_MOON_B1F", {
    talk = {
      TEXT_MTMOONB1F_JIRACHI = function(game, ow, npc, done)
        if not champ(game) then
          HouseNpcs.pushText(game, Strings("A wish sleeps..."), done)
          return
        end
        local scales = (game.save.inventory and game.save.inventory.HEART_SCALE) or 0
        if scales < 5 and not (game.save.flags and game.save.flags.MOD_EVENT_BEAT_JIRACHI) then
          HouseNpcs.pushText(game, Strings(
            "Offer 5 HEART\nSCALES to awaken."), done)
          return
        end
        if scales >= 5 and not (game.save.flags and game.save.flags.MOD_EVENT_BEAT_JIRACHI) then
          local Bag = require("src.inventory.Bag")
          Bag.remove(game.save, "HEART_SCALE", 5)
        end
        return staticBattle("JIRACHI", 30, "MOD_EVENT_BEAT_JIRACHI")(game, ow, npc, done)
      end,
    },
  })
end

LegendMythicals.CUSTOM_MAPS = {
  SKY_PILLAR_KANT = true,
  ILEX_SHRINE_KANT = true,
  BIRTH_ISLAND_KANT = true,
}

LegendMythicals.EXIT_WARPS = {
  {
    x = 9, y = 12, destMap = "ROUTE_23",
    key = "legend_return_SKY_PILLAR_KANT",
    fallback = { map = "ROUTE_23", x = 10, y = 20 },
  },
  {
    x = 9, y = 12, destMap = "VIRIDIAN_FOREST",
    key = "legend_return_ILEX_SHRINE_KANT",
    fallback = { map = "VIRIDIAN_FOREST", x = 16, y = 20 },
  },
  {
    x = 9, y = 10, destMap = "VERMILION_DOCK",
    key = "legend_return_BIRTH_ISLAND_KANT",
    fallback = { map = "VERMILION_DOCK", x = 14, y = 8 },
  },
}

function LegendMythicals.install(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then return end
  local OverworldState = require("src.world.OverworldController")
  if not OverworldState._expansionLegendOutdoor then
    local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
    Gen1Patch.apply(OverworldState, function(ow)
      local origRemember = ow.rememberOutdoor
      if type(origRemember) ~= "function" then return end
      ow.rememberOutdoor = function(self, id, x, y)
        if LegendMythicals.CUSTOM_MAPS[id] then return end
        return origRemember(self, id, x, y)
      end
    end)
    OverworldState._expansionLegendOutdoor = true
  end

  mod.hooks:wrap("warp.destination", function(next, mapId, x, y, ctx)
    local warp = ctx and ctx.warp
    if warp then
      for _, row in ipairs(LegendMythicals.EXIT_WARPS) do
        if warp.x == row.x and warp.y == row.y and warp.destMap == row.destMap then
          local ret = mod.save:get(row.key, nil) or row.fallback
          if ret and ret.map then
            return ret.map, ret.x, ret.y
          end
        end
      end
    end
    return next(mapId, x, y, ctx)
  end)
end

return LegendMythicals
