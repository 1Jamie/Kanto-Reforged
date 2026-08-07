-- Regi seal static encounters.

local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
local Strings = require("src.core.Strings")

local LegendRegis = {}
LegendRegis.OWNER = "legend_regis"

local function partyHasType(game, typeId)
  return HouseNpcs.partyHasType(game, typeId)
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
    local BattleState = require("src.battle.BattleState")
    local battle = BattleState.newWild(game, species, level)
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

function LegendRegis.register(mod)
  HouseNpcs.appendNpc(mod, "PEWTER_SPEECH_HOUSE", {
    index = 3, name = "PEWTERSPEECHHOUSE_REGI_SCHOLAR",
    sprite = "SPRITE_SCIENTIST", text = "TEXT_PEWTERSPEECHHOUSE_REGI_SCHOLAR",
    x = 5, y = 4,
  }, LegendRegis.OWNER)

  HouseNpcs.appendNpc(mod, "ROCK_TUNNEL_B1F", {
    index = 10, name = "ROCKTUNNELB1F_REGIROCK",
    sprite = "SPRITE_MONSTER", text = "TEXT_ROCKTUNNELB1F_REGIROCK",
    x = 18, y = 14, pokemon = "REGIROCK", level = 50,
  }, LegendRegis.OWNER)

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
            .. "Rock Tunnel, Seafoam,\nand the Power Plant."), done)
      end,
    },
  })

  mod.content.map_scripts:register("ROCK_TUNNEL_B1F", {
    talk = {
      TEXT_ROCKTUNNELB1F_REGIROCK = sealTalk("REGIROCK", 50, "MOD_EVENT_BEAT_REGIROCK", "ROCK", 3),
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
