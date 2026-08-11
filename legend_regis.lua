-- Regi seal static encounters.
-- Regirock lives in a tucked CAVERN chamber reached by a wall ladder on
-- Rock Tunnel B1F (off the main Flash path), matching the custom-room
-- pattern used for Rayquaza / Celebi / Deoxys.

local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
local Strings = require("src.core.Strings")

local LegendRegis = {}
LegendRegis.OWNER = "legend_regis"

-- Custom chamber (index 1104) + B1F ladder niche.
LegendRegis.CHAMBER = "REGIROCK_CHAMBER"
LegendRegis.CHAMBER_INDEX = 1104
-- Ladder SE cell on ROCK_TUNNEL_B1F (odd/odd): north spur wall, not the
-- through-route. Approach from dead-end (19,8), step south onto the ladder.
LegendRegis.LADDER_X = 19
LegendRegis.LADDER_Y = 9
LegendRegis.REGIROCK_X = 7
LegendRegis.REGIROCK_Y = 5

local CAVERN_WALL, CAVERN_FLOOR, CAVERN_LADDER = 3, 1, 62

-- Keep block 32's wall look on W/SW; NE stays the spur floor; SE = ladder
-- (tile 26, same as vanilla Rock Tunnel B1F ladders).
local LADDER_NICHE = {
   4, 41, 41, 41,
  49,  5,  5,  5,
  49,  5, 10, 11,
  40, 16, 26, 27,
}

local function chamberBlocks(w, h)
  local blocks = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local id = CAVERN_FLOOR
      if x == 0 or y == 0 or x == w - 1 or y == h - 1 then
        id = CAVERN_WALL
      elseif x == 3 and y == 4 then
        -- SE cell (7,9): return ladder to Rock Tunnel
        id = CAVERN_LADDER
      end
      blocks[#blocks + 1] = id
    end
  end
  return blocks
end

local function countType(game, typeId)
  local n = 0
  local pokemon = game.data.pokemon or {}
  for _, mon in ipairs(game.save.party or {}) do
    if mon and mon.species then
      local def = pokemon[mon.species]
      for _, t in ipairs((def and def.types) or {}) do
        if t == typeId then n = n + 1 break end
      end
    end
  end
  return n
end

local function sealTalk(species, level, flag, needType, needCount)
  needCount = needCount or 1
  return function(game, ow, npc, done)
    if not (game.save.flags and game.save.flags.MOD_REGI_NOTES) then
      HouseNpcs.pushText(game, Strings(
        "An ancient seal...\f"
          .. "A scholar in PEWTER\nmight know more."), done)
      return
    end
    if game.save.flags and game.save.flags[flag] then
      HouseNpcs.pushText(game, Strings("The seal is quiet."), done)
      return
    end
    if countType(game, needType) < needCount then
      HouseNpcs.pushText(game, Strings(
        "The seal wants\n%s-type POKéMON.", needType), done)
      return
    end
    local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
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
        if npc and npc.id then
          game.save.defeatedTrainers[npc.id] = true
        end
      end
      if ow and ow.afterBattle then ow:afterBattle(result, battle) end
      if done then done() end
    end
    if ow and ow.pushBattle then ow:pushBattle(battle) else game.stack:push(battle) end
  end
end

function LegendRegis.patchRockTunnelLadder(mod)
  local Data = require("src.core.Data")
  local cavern = Data.tilesets and Data.tilesets.CAVERN
  local baseCount = cavern and cavern.blocks and #cavern.blocks or 128
  local nicheId = baseCount

  mod.content.tilesets:patch("CAVERN", {
    blocks = { __append = { LADDER_NICHE } },
  })

  -- Block (9,4) → cells (18–19, 8–9). Sparse patch keeps the other 359.
  local bx, by = 9, 4
  local map = Data.maps and Data.maps.ROCK_TUNNEL_B1F
  local width = (map and map.width) or 20
  local blockIndex = by * width + bx + 1

  mod.content.maps:patch("ROCK_TUNNEL_B1F", {
    blocks = { [blockIndex] = nicheId },
    warps = {
      __append = {
        {
          x = LegendRegis.LADDER_X,
          y = LegendRegis.LADDER_Y,
          destMap = LegendRegis.CHAMBER,
          destWarp = 1,
        },
      },
    },
  })
  return nicheId, blockIndex
end

function LegendRegis.registerChamber(mod)
  local cw, ch = 8, 6
  mod.content.maps:register(LegendRegis.CHAMBER, {
    id = LegendRegis.CHAMBER,
    label = "RegirockChamber",
    index = LegendRegis.CHAMBER_INDEX,
    tileset = "CAVERN",
    width = cw,
    height = ch,
    blocks = chamberBlocks(cw, ch),
    borderBlock = CAVERN_WALL,
    warps = {
      {
        x = 7,
        y = 9,
        destMap = "ROCK_TUNNEL_B1F",
        -- Vanilla B1F has 4 warps; our ladder is __append'd as #5.
        destWarp = 5,
      },
    },
    objects = {
      {
        index = 1,
        name = "REGIROCKCHAMBER_REGIROCK",
        sprite = "SPRITE_MONSTER",
        movement = "STAY",
        range = "DOWN",
        text = "TEXT_REGIROCKCHAMBER_REGIROCK",
        x = LegendRegis.REGIROCK_X,
        y = LegendRegis.REGIROCK_Y,
        pokemon = "REGIROCK",
        level = 50,
      },
    },
    signs = {},
  })
end

function LegendRegis.register(mod)
  local Host = require("mods.Kanto-Reforged.host")
  if Host.isGen2() then return end
  HouseNpcs.appendNpc(mod, "PEWTER_SPEECH_HOUSE", {
    index = 3, name = "PEWTERSPEECHHOUSE_REGI_SCHOLAR",
    sprite = "SPRITE_SCIENTIST", text = "TEXT_PEWTERSPEECHHOUSE_REGI_SCHOLAR",
    x = 5, y = 4,
  }, LegendRegis.OWNER)

  LegendRegis.patchRockTunnelLadder(mod)
  LegendRegis.registerChamber(mod)

  HouseNpcs.appendNpc(mod, "SEAFOAM_ISLANDS_B2F", {
    index = 3, name = "SEAFOAMISLANDSB2F_REGICE",
    sprite = "SPRITE_MONSTER", text = "TEXT_SEAFOAMISLANDSB2F_REGICE",
    x = 10, y = 8, pokemon = "REGICE", level = 50,
  }, LegendRegis.OWNER)

  HouseNpcs.appendNpc(mod, "POWER_PLANT", {
    index = 16, name = "POWERPLANT_REGISTEEL",
    sprite = "SPRITE_MONSTER", text = "TEXT_POWERPLANT_REGISTEEL",
    x = 20, y = 20, pokemon = "REGISTEEL", level = 50,
  }, LegendRegis.OWNER)

  mod.content.map_scripts:register("PEWTER_SPEECH_HOUSE", {
    talk = {
      TEXT_PEWTERSPEECHHOUSE_REGI_SCHOLAR = function(game, ow, npc, done)
        local ok = false
        for _, mon in ipairs(game.save.party or {}) do
          if mon and (mon.species == "OMANYTE" or mon.species == "KABUTO"
              or mon.species == "AERODACTYL" or mon.species == "LILEEP"
              or mon.species == "ANORITH" or mon.species == "CRADILY"
              or mon.species == "ARMALDO") then
            ok = true
            break
          end
        end
        -- Also allow rock tunnel access flag / boulder badge as soft gate
        if not ok and game.save.inventory and game.save.inventory.BOULDERBADGE then
          ok = true
        end
        if not ok then
          HouseNpcs.pushText(game, Strings(
            "Bring a fossil mon\nor earn the BOULDER\vBADGE."), done)
          return
        end
        game.save.flags = game.save.flags or {}
        game.save.flags.MOD_REGI_NOTES = true
        HouseNpcs.pushText(game, Strings(
          "SEAL NOTES...\f"
            .. "A hidden ladder in\nRock Tunnel, then\vSeafoam and the\nPower Plant."), done)
      end,
    },
  })

  mod.content.map_scripts:register(LegendRegis.CHAMBER, {
    talk = {
      TEXT_REGIROCKCHAMBER_REGIROCK =
        sealTalk("REGIROCK", 50, "MOD_EVENT_BEAT_REGIROCK", "ROCK", 3),
    },
  })
  mod.content.map_scripts:register("SEAFOAM_ISLANDS_B2F", {
    talk = {
      TEXT_SEAFOAMISLANDSB2F_REGICE = sealTalk("REGICE", 50, "MOD_EVENT_BEAT_REGICE", "ICE", 1),
    },
  })
  mod.content.map_scripts:register("POWER_PLANT", {
    talk = {
      TEXT_POWERPLANT_REGISTEEL = sealTalk("REGISTEEL", 50, "MOD_EVENT_BEAT_REGISTEEL", "STEEL", 1),
    },
  })
end

return LegendRegis
