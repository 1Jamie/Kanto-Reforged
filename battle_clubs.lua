-- Celadon Circuit + Dark / Berry specialists (opt-in cap-scaled battles).
-- Gold: stay on Kanto maps only (no Johto remaps).

local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
local Host = require("mods.Kanto-Reforged.host")
local Strings = require("src.core.Strings")

local BattleClubs = {}

BattleClubs.OWNER = "battle_clubs"

local CLUB_CLASS = "OPP_EXP_BATTLE_CLUB"
local DARK_CLASS = "OPP_EXP_DARK_SPECIALIST"
local BERRY_CLASS = "OPP_EXP_BERRY_SPECIALIST"

local CLUB_TEAMS = {
  -- balanced
  {
    { species = "PIDGEOTTO", level = 20 },
    { species = "KADABRA", level = 20 },
    { species = "GROVYLE", level = 20 },
    { species = "HOUNDOOM", level = 20 },
  },
  -- bulky
  {
    { species = "GRAVELER", level = 20 },
    { species = "VAPOREON", level = 20 },
    { species = "STEELIX", level = 20 },
    { species = "BLAZIKEN", level = 20 },
  },
  -- weather-ish
  {
    { species = "VULPIX", level = 20 },
    { species = "CACTURNE", level = 20 },
    { species = "PELIPPER", level = 20 },
    { species = "TYRANITAR", level = 20 },
  },
  -- revenge
  {
    { species = "MACHOKE", level = 20 },
    { species = "SHARPEDO", level = 20 },
    { species = "CROBAT", level = 20 },
    { species = "ABSOL", level = 20 },
  },
}

local DARK_TEAM = {
  { species = "MURKROW", level = 20 },
  { species = "SABLEYE", level = 20 },
  { species = "HOUNDOUR", level = 20 },
  { species = "UMBREON", level = 20 },
}

local BERRY_TEAM = {
  { species = "VILEPLUME", level = 20 },
  { species = "WEEPINBELL", level = 20 },
  { species = "BRELOOM", level = 20 },
  { species = "SHIFTRY", level = 20 },
}

-- Gen1 house maps that do not exist on Gold → nearest Kanto indoor.
local function clubMaps()
  if Host.isGen2() then
    return {
      circuit = "CELADON_MANSION_2F",
      dark = "VERMILION_FISHING_SPEECH_HOUSE",
      berry = "CELADON_CAFE",
    }
  end
  return {
    circuit = "CELADON_MANSION_2F",
    dark = "VERMILION_PIDGEY_HOUSE",
    berry = "CELADON_HOTEL",
  }
end

local function registerTrainers(mod)
  local defClub = {
    id = CLUB_CLASS,
    name = "CIRCUIT HOST",
    baseMoney = 40,
    parties = { CLUB_TEAMS[1], CLUB_TEAMS[2], CLUB_TEAMS[3], CLUB_TEAMS[4] },
  }
  local defDark = {
    id = DARK_CLASS,
    name = "NIGHT EYES",
    baseMoney = 35,
    parties = { DARK_TEAM },
  }
  local defBerry = {
    id = BERRY_CLASS,
    name = "SNACK SCOUT",
    baseMoney = 30,
    parties = { BERRY_TEAM },
  }
  HouseNpcs.registerTrainerDef(CLUB_CLASS, defClub)
  HouseNpcs.registerTrainerDef(DARK_CLASS, defDark)
  HouseNpcs.registerTrainerDef(BERRY_CLASS, defBerry)

  if Host.isGen2() then
    -- Gen2 trainer schema expects class.trainers[].party, not Gen1 parties[][].
    local function asGen2(def)
      local trainers = {}
      for i, party in ipairs(def.parties) do
        trainers[i] = {
          id = def.id .. "_" .. i,
          name = def.name,
          party = party,
        }
      end
      return {
        id = def.id,
        name = def.name,
        baseMoney = def.baseMoney or 0,
        trainers = trainers,
      }
    end
    mod.content.trainers:register(CLUB_CLASS, asGen2(defClub))
    mod.content.trainers:register(DARK_CLASS, asGen2(defDark))
    mod.content.trainers:register(BERRY_CLASS, asGen2(defBerry))
  else
    mod.content.trainers:register(CLUB_CLASS, {
      id = CLUB_CLASS,
      name = "CIRCUIT HOST",
      baseMoney = 40,
      basePic = "OPP_HIKER",
      parties = { CLUB_TEAMS[1], CLUB_TEAMS[2], CLUB_TEAMS[3], CLUB_TEAMS[4] },
    })
    mod.content.trainers:register(DARK_CLASS, {
      id = DARK_CLASS,
      name = "NIGHT EYES",
      baseMoney = 35,
      basePic = "OPP_SUPER_NERD",
      parties = { DARK_TEAM },
    })
    mod.content.trainers:register(BERRY_CLASS, {
      id = BERRY_CLASS,
      name = "SNACK SCOUT",
      baseMoney = 30,
      basePic = "OPP_LASS",
      parties = { BERRY_TEAM },
    })
  end
end

local function scaleHook(mod)
  mod.hooks:wrap("trainer.party", function(next, oppClass, partyIndex, partyDef)
    local party = next(oppClass, partyIndex, partyDef)
    if oppClass ~= CLUB_CLASS and oppClass ~= DARK_CLASS and oppClass ~= BERRY_CLASS then
      return party
    end
    local ace = HouseNpcs.scaleCap(mod, nil)
    return HouseNpcs.scaleParty(party, ace)
  end)
end

local function afterClubWin(game, mod, first)
  if first and not mod.save:get("got_choice_band", false) then
    if HouseNpcs.giveItem(game, "CHOICE_BAND", 1) then
      mod.save:set("got_choice_band", true)
      return Strings("You earned a\nCHOICE BAND!\fCome back anytime.")
    end
  end
  local ace = HouseNpcs.scaleCap(mod, game)
  local money = ace * 40
  game.save.money = (game.save.money or 0) + money
  local extra = ""
  if love.math.random() < 0.3 then
    if HouseNpcs.giveItem(game, "HEART_SCALE", 1) then
      extra = "\fYou also got a\nHEART SCALE!"
    end
  end
  return Strings("Nice fight!\nWon ¥%d.%s", money, extra)
end

local function clubTalk(mod)
  return function(game, ow, npc, done)
    HouseNpcs.ask(game, Strings(
      "Welcome to the\nCELADON CIRCUIT!\f"
      .. "Want a serious\nbattle?"), function(yes)
      if not yes then
        HouseNpcs.pushText(game, Strings("Come back when\nyou're ready."), done)
        return
      end
      local streak = mod.save:get("battle_club_streak", 0)
      local partyIndex = (streak % 4) + 1
      HouseNpcs.startTrainerBattle(game, ow, CLUB_CLASS, partyIndex, function(result)
        if result == "win" then
          local first = not mod.save:get("battle_club_cleared", false)
          mod.save:set("battle_club_cleared", true)
          mod.save:set("battle_club_streak", streak + 1)
          HouseNpcs.pushText(game, afterClubWin(game, mod, first), done)
        else
          if done then done() end
        end
      end)
    end)
  end
end

local function darkTalk(mod)
  return function(game, ow, npc, done)
    if not HouseNpcs.partyHasType(game, "DARK") then
      HouseNpcs.pushText(game, Strings(
        "Show me darkness...\f"
        .. "Bring a DARK-type\nand I'll battle."), done)
      return
    end
    HouseNpcs.ask(game, Strings("A DARK-type!\nShall we battle?"), function(yes)
      if not yes then
        HouseNpcs.pushText(game, Strings("Shame."), done)
        return
      end
      HouseNpcs.startTrainerBattle(game, ow, DARK_CLASS, 1, function(result)
        if result ~= "win" then
          if done then done() end
          return
        end
        local msg
        if not mod.save:get("got_dark_specialist_clear", false) then
          mod.save:set("got_dark_specialist_clear", true)
          local inv = game.save.inventory or {}
          if (inv.BLACKGLASSES or 0) <= 0 and HouseNpcs.giveItem(game, "BLACKGLASSES", 1) then
            msg = Strings(
              "Take these\nBLACKGLASSES!\f"
              .. "Celadon Mansion's\nmeeting room hosts\vserious battles.")
          else
            game.save.money = (game.save.money or 0) + 5000
            msg = Strings(
              "Here's ¥5000!\f"
              .. "Celadon Mansion's\nmeeting room hosts\vserious battles.")
          end
        else
          game.save.money = (game.save.money or 0) + 2000
          msg = Strings("Good rematch!\nWon ¥2000.")
        end
        HouseNpcs.pushText(game, msg, done)
      end)
    end)
  end
end

local function berryTalk(mod)
  return function(game, ow, npc, done)
    if not HouseNpcs.leadHoldsBerry(game) then
      HouseNpcs.pushText(game, Strings(
        "Have your lead hold\na BERRY, then we\vcan battle!"), done)
      return
    end
    HouseNpcs.ask(game, Strings("A berry snack!\nBattle me?"), function(yes)
      if not yes then
        HouseNpcs.pushText(game, Strings("Aw, okay."), done)
        return
      end
      HouseNpcs.startTrainerBattle(game, ow, BERRY_CLASS, 1, function(result)
        if result ~= "win" then
          if done then done() end
          return
        end
        if not mod.save:get("got_focus_sash", false) then
          mod.save:set("got_focus_sash", true)
          HouseNpcs.giveItem(game, "FOCUS_SASH", 1)
          HouseNpcs.pushText(game, Strings("You earned a\nFOCUS SASH!"), done)
        else
          local berries = { "CHERI_BERRY", "PECHA_BERRY", "RAWST_BERRY" }
          for _, id in ipairs(berries) do
            HouseNpcs.giveItem(game, id, 1)
          end
          HouseNpcs.pushText(game, Strings("Have some berries\nfor the rematch!"), done)
        end
      end)
    end)
  end
end

function BattleClubs.register(mod)
  registerTrainers(mod)
  scaleHook(mod)

  local maps = clubMaps()

  HouseNpcs.appendNpc(mod, maps.circuit, {
    index = 1,
    name = "CELADONMANSION2F_BATTLE_CLUB",
    sprite = "SPRITE_HIKER",
    text = "TEXT_CELADONMANSION2F_BATTLE_CLUB",
    -- Meeting-room floor (left), not the east hall (x=6/7).
    x = 2, y = 5,
  }, BattleClubs.OWNER)

  HouseNpcs.appendNpc(mod, maps.dark, {
    index = Host.isGen2() and 10 or 4,
    name = "VERMILIONPIDGEYHOUSE_DARK_SPECIALIST",
    sprite = "SPRITE_SUPER_NERD",
    text = "TEXT_VERMILIONPIDGEYHOUSE_DARK_SPECIALIST",
    x = 6, y = 5,
  }, BattleClubs.OWNER)

  HouseNpcs.appendNpc(mod, maps.berry, {
    index = Host.isGen2() and 10 or 4,
    name = "CELADONHOTEL_BERRY_SPECIALIST",
    sprite = "SPRITE_GIRL",
    text = "TEXT_CELADONHOTEL_BERRY_SPECIALIST",
    x = 6, y = 5,
  }, BattleClubs.OWNER)

  HouseNpcs.bindTalk(mod, maps.circuit, {
    TEXT_CELADONMANSION2F_BATTLE_CLUB = clubTalk(mod),
  })
  HouseNpcs.bindTalk(mod, maps.dark, {
    TEXT_VERMILIONPIDGEYHOUSE_DARK_SPECIALIST = darkTalk(mod),
  })
  HouseNpcs.bindTalk(mod, maps.berry, {
    TEXT_CELADONHOTEL_BERRY_SPECIALIST = berryTalk(mod),
  })
end

return BattleClubs
