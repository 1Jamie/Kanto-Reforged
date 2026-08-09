-- Legendary shrine statics: Lugia, Ho-Oh, weather trio + key item hunters.

local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
local Strings = require("src.core.Strings")

local LegendShrines = {}
LegendShrines.OWNER = "legend_shrines"

-- Ho-Oh perch on the brown roof-house (cells on block row 2).
-- Was (4,5) in the east corridor, which blocked the Eevee door path.
LegendShrines.HO_OH_X = 2
LegendShrines.HO_OH_Y = 4

-- Custom MANSION blocks: brown roof look, walkable feet (tile 1 / 26).
-- Collision uses each cell's bottom-left 8x8 (indices 5,7,13,15 in the 4x4).
-- West cabin block keeps the left wall (74/75); east block adds a stair
-- lip on the corridor edge so you can walk up from (4,4)/(4,5).
local ROOF_WEST = {
  74, 75, 54, 55,
  74, 75,  1, 55,
  74, 75, 54, 55,
  74, 75,  1, 55,
}
local ROOF_EAST = {
  54, 55, 10, 11,
   1, 55, 26, 27,
  54, 55, 10, 11,
   1, 55, 26, 27,
}

function LegendShrines.patchHoOhRoof(mod)
  local Data = require("src.core.Data")
  local mansion = Data.tilesets and Data.tilesets.MANSION
  local baseCount = mansion and mansion.blocks and #mansion.blocks or 72
  local idWest, idEast = baseCount, baseCount + 1

  mod.content.tilesets:patch("MANSION", {
    blocks = { __append = { ROOF_WEST, ROOF_EAST } },
  })

  -- Vanilla CELADON_MANSION_ROOF is 4x6; swap cabin top blocks 33/34.
  mod.content.maps:patch("CELADON_MANSION_ROOF", {
    blocks = {
      69, 59, 28, 27,
      61,  7, 29, 29,
      idWest, idEast, 29, 29,
      37, 38, 29, 29,
      51, 31, 30, 29,
      32, 31, 31, 30,
    },
  })
  return idWest, idEast
end

local function hasItem(save, id)
  return save.inventory and (save.inventory[id] or 0) > 0
end

local function registerKeys(mod)
  for _, row in ipairs({
    { "RAINBOW_WING", "RAINBOW WING" },
    { "SILVER_WING", "SILVER WING" },
    { "RED_ORB", "RED ORB" },
    { "BLUE_ORB", "BLUE ORB" },
  }) do
    mod.content.items:register(row[1], {
      id = row[1], name = row[2], price = 0, keyItem = true, tossable = false,
    })
  end
end

local function staticTalk(species, level, flag, needItem, weather)
  return function(game, ow, npc, done)
    if game.save.flags and game.save.flags[flag] then
      HouseNpcs.pushText(game, Strings("..."), done)
      return
    end
    if needItem and not hasItem(game.save, needItem) then
      HouseNpcs.pushText(game, Strings("A mysterious\npresence..."), done)
      return
    end
    local BattleState = require("src.battle.BattleState")
    local battle = BattleState.newWild(game, species, level)
    if weather then
      battle.weather = weather
      battle.weatherTurns = 255
    end
    battle.onFinish = function(result)
      if result == "win" or result == "caught" or result == "run" then
        game.save.flags = game.save.flags or {}
        game.save.flags[flag] = true
        if ow and ow.toggleObject then
          -- hide via defeatedTrainers style for static objects
          game.save.defeatedTrainers = game.save.defeatedTrainers or {}
          game.save.defeatedTrainers[npc.id] = true
        end
      end
      if ow and ow.afterBattle then ow:afterBattle(result, battle) end
      if done then done() end
    end
    if ow and ow.pushBattle then ow:pushBattle(battle) else game.stack:push(battle) end
  end
end

function LegendShrines.register(mod)
  registerKeys(mod)

  -- Wing hunters
  HouseNpcs.appendNpc(mod, "ROUTE_16_FLY_HOUSE", {
    index = 3, name = "ROUTE16FLYHOUSE_WING_HUNTER",
    sprite = "SPRITE_CHANNELER", text = "TEXT_ROUTE16FLYHOUSE_WING_HUNTER",
    x = 5, y = 5,
  }, LegendShrines.OWNER)

  HouseNpcs.appendNpc(mod, "ROUTE_12_GATE_2F", {
    index = 2, name = "ROUTE12GATE2F_WING_HUNTER",
    sprite = "SPRITE_FISHER", text = "TEXT_ROUTE12GATE2F_WING_HUNTER",
    x = 5, y = 4,
  }, LegendShrines.OWNER)

  HouseNpcs.appendNpc(mod, "CINNABAR_LAB", {
    index = 2, name = "CINNABARLAB_ORB_HUNTER",
    sprite = "SPRITE_SCIENTIST", text = "TEXT_CINNABARLAB_ORB_HUNTER",
    x = 5, y = 4,
  }, LegendShrines.OWNER)

  -- Ho-Oh used to stand in the 1-tile corridor east of the brown roof
  -- house (x=4,y=5), which blocked the only path to the Eevee door.
  -- Open the cabin roof + a stair lip from that corridor, and perch
  -- Ho-Oh on top instead.
  LegendShrines.patchHoOhRoof(mod)
  HouseNpcs.appendNpc(mod, "CELADON_MANSION_ROOF", {
    index = 1, name = "CELADONMANSIONROOF_HO_OH",
    sprite = "SPRITE_BIRD", text = "TEXT_CELADONMANSIONROOF_HO_OH",
    x = LegendShrines.HO_OH_X, y = LegendShrines.HO_OH_Y,
    pokemon = "HO_OH", level = 50,
  }, LegendShrines.OWNER)

  HouseNpcs.appendNpc(mod, "SEAFOAM_ISLANDS_B1F", {
    index = 3, name = "SEAFOAMISLANDSB1F_LUGIA",
    sprite = "SPRITE_BIRD", text = "TEXT_SEAFOAMISLANDSB1F_LUGIA",
    x = 8, y = 6, pokemon = "LUGIA", level = 50,
  }, LegendShrines.OWNER)

  HouseNpcs.appendNpc(mod, "SEAFOAM_ISLANDS_B3F", {
    index = 7, name = "SEAFOAMISLANDSB3F_KYOGRE",
    sprite = "SPRITE_MONSTER", text = "TEXT_SEAFOAMISLANDSB3F_KYOGRE",
    x = 12, y = 8, pokemon = "KYOGRE", level = 60,
  }, LegendShrines.OWNER)

  HouseNpcs.appendNpc(mod, "POKEMON_MANSION_B1F", {
    index = 9, name = "POKEMONMANSIONB1F_GROUDON",
    sprite = "SPRITE_MONSTER", text = "TEXT_POKEMONMANSIONB1F_GROUDON",
    x = 10, y = 10, pokemon = "GROUDON", level = 60,
  }, LegendShrines.OWNER)

  mod.content.map_scripts:register("ROUTE_16_FLY_HOUSE", {
    talk = {
      TEXT_ROUTE16FLYHOUSE_WING_HUNTER = function(game, ow, npc, done)
        if hasItem(game.save, "RAINBOW_WING") then
          HouseNpcs.pushText(game, Strings("Take it to the\nCELADON roof."), done)
          return
        end
        local owned = 0
        for _ in pairs((game.save.pokedex and game.save.pokedex.owned) or {}) do
          owned = owned + 1
        end
        if owned < 60 then
          HouseNpcs.pushText(game, Strings(
            "Show me 60 owned\nPOKéMON first."), done)
          return
        end
        HouseNpcs.giveItem(game, "RAINBOW_WING", 1)
        HouseNpcs.pushText(game, Strings("The RAINBOW WING!\nCeladon roof..."), done)
      end,
    },
  })

  mod.content.map_scripts:register("ROUTE_12_GATE_2F", {
    talk = {
      TEXT_ROUTE12GATE2F_WING_HUNTER = function(game, ow, npc, done)
        if hasItem(game.save, "SILVER_WING") then
          HouseNpcs.pushText(game, Strings("SEAFOAM waits."), done)
          return
        end
        local ok = false
        for _, mon in ipairs(game.save.party or {}) do
          if mon and (mon.level or 0) >= 30 then
            local def = game.data.pokemon[mon.species]
            for _, t in ipairs((def and def.types) or {}) do
              if t == "WATER" then ok = true break end
            end
          end
          if ok then break end
        end
        if not ok then
          HouseNpcs.pushText(game, Strings(
            "Show a WATER-type\nat least Lv 30."), done)
          return
        end
        HouseNpcs.giveItem(game, "SILVER_WING", 1)
        HouseNpcs.pushText(game, Strings("SILVER WING!\nSeek SEAFOAM."), done)
      end,
    },
  })

  mod.content.map_scripts:register("CINNABAR_LAB", {
    talk = {
      TEXT_CINNABARLAB_ORB_HUNTER = function(game, ow, npc, done)
        local flags = game.save.flags or {}
        if not flags.EVENT_BEAT_CHAMPION_RIVAL then
          HouseNpcs.pushText(game, Strings(
            "Return after you\nare CHAMPION."), done)
          return
        end
        if not hasItem(game.save, "BLUE_ORB") then
          HouseNpcs.giveItem(game, "BLUE_ORB", 1)
          HouseNpcs.pushText(game, Strings("A BLUE ORB...\nSeafoam depths."), done)
          return
        end
        if not hasItem(game.save, "RED_ORB") then
          HouseNpcs.giveItem(game, "RED_ORB", 1)
          HouseNpcs.pushText(game, Strings("A RED ORB...\nThe mansion."), done)
          return
        end
        HouseNpcs.pushText(game, Strings("The orbs are with\nyou."), done)
      end,
    },
  })

  mod.content.map_scripts:register("CELADON_MANSION_ROOF", {
    talk = {
      TEXT_CELADONMANSIONROOF_HO_OH = staticTalk("HO_OH", 50, "MOD_EVENT_BEAT_HO_OH", "RAINBOW_WING", "sun"),
    },
  })
  mod.content.map_scripts:register("SEAFOAM_ISLANDS_B1F", {
    talk = {
      TEXT_SEAFOAMISLANDSB1F_LUGIA = staticTalk("LUGIA", 50, "MOD_EVENT_BEAT_LUGIA", "SILVER_WING", "rain"),
    },
  })
  mod.content.map_scripts:register("SEAFOAM_ISLANDS_B3F", {
    talk = {
      TEXT_SEAFOAMISLANDSB3F_KYOGRE = staticTalk("KYOGRE", 60, "MOD_EVENT_BEAT_KYOGRE", "BLUE_ORB", "rain"),
    },
  })
  mod.content.map_scripts:register("POKEMON_MANSION_B1F", {
    talk = {
      TEXT_POKEMONMANSIONB1F_GROUDON = staticTalk("GROUDON", 60, "MOD_EVENT_BEAT_GROUDON", "RED_ORB", "sun"),
    },
  })
end

-- Rayquaza sky pillar map registered from legend_mythicals / custom maps module.

return LegendShrines
