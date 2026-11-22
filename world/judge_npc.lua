-- DV / Hidden Power / statExp judge.
-- Gen1: Underground Path (Route 5 entrance). Gold: UNDERGROUND_PATH tunnel.

local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
local Host = require("mods.Kanto-Reforged.core.host")
local MoveEffects = require("mods.Kanto-Reforged.battle.move_effects")
local Strings = require("src.core.Strings")

local JudgeNpc = {}
JudgeNpc.OWNER = "judge_npc"

local function dvWord(n, isGen3)
  n = n or 0
  if isGen3 then
    if n >= 30 then return "outstanding"
    elseif n >= 26 then return "excellent"
    elseif n >= 20 then return "very good"
    elseif n >= 14 then return "decent"
    elseif n >= 8 then return "so-so"
    else return "rather poor"
    end
  else
    if n >= 15 then return "outstanding"
    elseif n >= 13 then return "excellent"
    elseif n >= 10 then return "very good"
    elseif n >= 7 then return "decent"
    elseif n >= 4 then return "so-so"
    else return "rather poor"
    end
  end
end

local function effortLine(mon)
  local se = mon.evs or mon.statExp or {}
  local best, bestV = "none", -1
  for _, key in ipairs({ "hp", "attack", "atk", "defense", "def", "speed", "spe", "special", "spa", "spd" }) do
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
    attack = "ATTACK", atk = "ATTACK",
    defense = "DEFENSE", def = "DEFENSE",
    speed = "SPEED", spe = "SPEED",
    special = "SPECIAL", spa = "SP. ATK", spd = "SP. DEF",
  })[best] or best
  return Strings("It trained hard\nin %s.", label)
end

local function calcHiddenPower(mon)
  if mon.ivs then
    local iv = mon.ivs
    local hp = (iv.hp or 0)
    local atk = (iv.atk or iv.attack or 0)
    local def = (iv.def or iv.defense or 0)
    local spe = (iv.spe or iv.speed or 0)
    local spa = (iv.spa or iv.special or 0)
    local spd = (iv.spd or iv.special or 0)
    local a = (hp % 2) + 2 * (atk % 2) + 4 * (def % 2) + 8 * (spe % 2) + 16 * (spa % 2) + 32 * (spd % 2)
    local typeIndex = math.floor(a * 15 / 63)
    local HP_TYPES = {
      "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST", "STEEL",
      "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC", "ICE", "DRAGON", "DARK"
    }
    return HP_TYPES[typeIndex + 1] or "NORMAL"
  end
  local fakeBattler = { mon = mon }
  local hpType = select(1, MoveEffects.hiddenPower(fakeBattler)) or "NORMAL"
  return hpType
end

local function judgeMon(game, mon)
  local ivs = mon.ivs or mon.dvs or {}
  local isGen3 = mon.ivs ~= nil
  local hpVal = ivs.hp or 0
  local atkVal = ivs.atk or ivs.attack or 0
  local defVal = ivs.def or ivs.defense or 0
  local speVal = ivs.spe or ivs.speed or 0
  local spVal = ivs.spa or ivs.special or 0
  if isGen3 and ivs.spa and ivs.spd then
    spVal = math.floor((ivs.spa + ivs.spd) / 2)
  end

  local hpType = calcHiddenPower(mon)
  local pokemon = (game and game.data and game.data.pokemon) or {}
  local name = mon.nickname
    or (pokemon[mon.species] and pokemon[mon.species].name)
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
    dvWord(hpVal, isGen3),
    dvWord(atkVal, isGen3),
    dvWord(defVal, isGen3),
    dvWord(speVal, isGen3),
    dvWord(spVal, isGen3),
    hpType:gsub("_TYPE", ""),
    effortLine(mon))
end

local function talkHandler(mod)
  return function(game, ow, npc, done)
    local session = (game and game.session)
      or (package.loaded["src.core.game3.runtime"] and package.loaded["src.core.game3.runtime"].getSession and package.loaded["src.core.game3.runtime"].getSession())
      or (package.loaded["src.core.game3.field"] and package.loaded["src.core.game3.field"]._session)
    local party = (game and game.save and game.save.party) or (session and session.party) or {}
    local rows = {}
    local pokemon = (game and game.data and game.data.pokemon) or {}
    local okPoke, Pokemon = pcall(require, "src.core.game3.pokemon")
    for i, mon in ipairs(party) do
      local species = mon and (mon.species or mon.speciesId)
      if mon and species then
        local label = mon.nickname
        if not label and type(species) == "string" and pokemon[species] then
          label = pokemon[species].name
        end
        if not label and okPoke and Pokemon and Pokemon.name then
          label = Pokemon.name(species)
        end
        label = label or tostring(species)
        rows[#rows + 1] = { label = label, value = i }
      end
    end
    if #rows == 0 then
      HouseNpcs.pushText(game, Strings("No POKéMON?"), done)
      return
    end

    local Host = require("mods.Kanto-Reforged.core.host")
    if Host.isGen3() then
      local Choice = require("src.ui.game3.choice")
      local labels = {}
      for _, r in ipairs(rows) do
        labels[#labels + 1] = r.label
      end
      labels[#labels + 1] = "CANCEL"
      Choice.multi(labels, 0, function(idx)
        local chosen = (type(idx) == "number") and rows[idx + 1]
        if chosen then
          local mon = party[chosen.value]
          if mon then
            HouseNpcs.pushText(game, judgeMon(game, mon), done)
            return
          end
        end
        if done then done() end
      end)
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
      onCancel = function(menu)
        menu:close()
        if done then done() end
      end,
    }))
  end
end

function JudgeNpc.register(mod)
  local isG3 = Host.isGen3()
  local mapId = isG3 and "FR_UNDERGROUND_PATH_NORTH_ENTRANCE"
    or (Host.isGen2() and "UNDERGROUND_PATH" or "UNDERGROUND_PATH_ROUTE_5")
  local index = isG3 and 81
    or (Host.isGen2() and HouseNpcs.nextFreeIndex(mod, mapId, 1) or 2)
  -- FRLG entrance: hug west wall at (1,2) so the top hall stays clear.
  local x = isG3 and 1 or (Host.isGen2() and 2 or 5)
  local y = isG3 and 2 or (Host.isGen2() and 10 or 3)

  HouseNpcs.appendNpc(mod, mapId, {
    index = index,
    name = "UNDERGROUNDPATHROUTE5_JUDGE",
    sprite = "SPRITE_SCIENTIST",
    graphicsId = 55,
    text = "TEXT_UNDERGROUNDPATHROUTE5_JUDGE",
    x = x, y = y,
    gen3X = 1, gen3Y = 2,
  }, JudgeNpc.OWNER)

  HouseNpcs.bindTalk(mod, mapId, {
    TEXT_UNDERGROUNDPATHROUTE5_JUDGE = talkHandler(mod),
  })
end

return JudgeNpc
