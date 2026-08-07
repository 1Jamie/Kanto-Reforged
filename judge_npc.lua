-- DV / Hidden Power / statExp judge on Underground Path Route 5.

local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
local MoveEffects = require("mods.Kanto-Reforged.move_effects")
local Strings = require("src.core.Strings")

local JudgeNpc = {}
JudgeNpc.OWNER = "judge_npc"

local function dvWord(n)
  n = n or 0
  if n >= 15 then return "outstanding"
  elseif n >= 13 then return "excellent"
  elseif n >= 10 then return "very good"
  elseif n >= 7 then return "decent"
  elseif n >= 4 then return "so-so"
  else return "rather poor"
  end
end

local function effortLine(mon)
  local se = mon.statExp or {}
  local best, bestV = "none", -1
  for _, key in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
    local v = se[key] or 0
    if v > bestV then
      bestV = v
      best = key
    end
  end
  if bestV <= 0 then
    return "It hasn't trained\nmuch yet."
  end
  local label = ({
    hp = "HP",
    attack = "ATTACK",
    defense = "DEFENSE",
    speed = "SPEED",
    special = "SPECIAL",
  })[best] or best
  return Strings("It trained hard\nin %s.", label)
end

local function judgeMon(game, mon)
  local dvs = mon.dvs or {}
  local fakeBattler = { mon = mon }
  local hpType = select(1, MoveEffects.hiddenPower(fakeBattler)) or "NORMAL"
  local name = mon.nickname
    or (game.data.pokemon[mon.species] and game.data.pokemon[mon.species].name)
    or mon.species
  return Strings(
    "%s's potential:\f"
      .. "HP %s\n"
      .. "ATTACK %s\n"
      .. "DEFENSE %s\f"
      .. "SPEED %s\n"
      .. "SPECIAL %s\f"
      .. "HIDDEN POWER:\n%s\f"
      .. "%s",
    name,
    dvWord(dvs.hp),
    dvWord(dvs.attack),
    dvWord(dvs.defense),
    dvWord(dvs.speed),
    dvWord(dvs.special),
    hpType:gsub("_TYPE", ""),
    effortLine(mon))
end

local function talkHandler(mod)
  return function(game, ow, npc, done)
    local party = game.save.party or {}
    local rows = {}
    for i, mon in ipairs(party) do
      if mon and mon.species then
        local label = mon.nickname
          or (game.data.pokemon[mon.species] and game.data.pokemon[mon.species].name)
          or mon.species
        rows[#rows + 1] = { label = label, value = i }
      end
    end
    if #rows == 0 then
      HouseNpcs.pushText(game, Strings("No POKéMON?"), done)
      return
    end
    local ListMenu = require("src.ui.ListMenu")
    game.stack:push(ListMenu.new(game, Strings("Judge which?"), rows, {
      onChoose = function(row, menu)
        menu:close()
        local mon = party[row.value]
        if not mon then
          if done then done() end
          return
        end
        HouseNpcs.pushText(game, judgeMon(game, mon), done)
      end,
    }))
  end
end

function JudgeNpc.register(mod)
  HouseNpcs.appendNpc(mod, "UNDERGROUND_PATH_ROUTE_5", {
    index = 2,
    name = "UNDERGROUNDPATHROUTE5_JUDGE",
    sprite = "SPRITE_SCIENTIST",
    text = "TEXT_UNDERGROUNDPATHROUTE5_JUDGE",
    x = 5, y = 3,
  }, JudgeNpc.OWNER)

  mod.content.map_scripts:register("UNDERGROUND_PATH_ROUTE_5", {
    talk = {
      TEXT_UNDERGROUNDPATHROUTE5_JUDGE = talkHandler(mod),
    },
  })
end

return JudgeNpc
