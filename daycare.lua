-- Gen 3-style Route 5 daycare (Kanto Reforged): two parents, compatibility,
-- eggs. Custom HOUSE interior + Day-Care Lady; overrides talk scripts;
-- monkey-patches overworld steps. Route 5 outdoors is unchanged.

local Breeding = require("mods.Kanto-Reforged.breeding")
local Strings = require("src.core.Strings")

local Daycare = {}

-- Same HOUSE layout as vanilla (table + stools + single doormat). A double
-- mat looked wider than the warps (only x=2,3), so half the rug was dead.
Daycare.BLOCKS = {
  4, 14, 5, 9,
  15, 1, 2, 15,
  15, 12, 13, 15,
  6, 11, 15, 7,
}

Daycare.LADY_TEXT = "TEXT_DAYCARE_LADY"
Daycare.LADY_NAME = "DAYCARE_LADY"

Daycare.GENTLEMAN = {
  index = 1,
  name = "DAYCARE_GENTLEMAN",
  sprite = "SPRITE_GENTLEMAN",
  movement = "STAY",
  range = "RIGHT",
  text = "TEXT_DAYCARE_GENTLEMAN",
  -- Vanilla seat: left of the table.
  x = 2,
  y = 3,
}

Daycare.LADY = {
  index = 2,
  name = Daycare.LADY_NAME,
  sprite = "SPRITE_MIDDLE_AGED_WOMAN",
  movement = "STAY",
  range = "LEFT",
  text = Daycare.LADY_TEXT,
  -- Right side of the room (Blue's House Daisy walking spot).
  x = 6,
  y = 4,
}

local function fillDaycareText(s, subs)
  s = s:gsub("{PLAYER}", subs.player or "")
  s = s:gsub("{RAM:([^}]*)}", function(name) return subs[name] or "" end)
  s = s:gsub("{NUM:([%w_]+)[^}]*}", function(name)
    return tostring(subs[name] or "0")
  end)
  return s
end

local function monName(game, mon)
  if Breeding.isEgg(mon) then return "EGG" end
  local def = game.data.pokemon[mon.species]
  return mon.nickname or (def and def.name) or mon.species
end

local function ensureDaycare(save)
  if type(save.daycare) ~= "table" then
    save.daycare = {}
  end
  return save.daycare
end

local function slotCount(dc)
  local n = 0
  if dc and dc.mon then n = n + 1 end
  if dc and dc.mon2 then n = n + 1 end
  return n
end

local function foldPendingExp(game, dc)
  if not dc then return end
  local steps = dc.steps or 0
  if steps <= 0 then return end
  local function fold(mon)
    if not mon or Breeding.isEgg(mon) then return end
    mon.exp = (mon.exp or 0) + steps
  end
  fold(dc.mon)
  fold(dc.mon2)
  dc.steps = 0
end

local function levelsAndFee(game, mon, depositLevel)
  local Growth = require("src.pokemon.Growth")
  local def = game.data.pokemon[mon.species]
  if depositLevel == nil then depositLevel = mon.level end
  local startLevel = depositLevel
  local newLevel = Growth.levelForExp(def and def.growthRate, mon.exp)
  if newLevel >= 100 then
    newLevel = 100
    if def then
      mon.exp = Growth.expForLevel(def.growthRate, 100)
    end
  end
  local levelsGrown = math.max(0, newLevel - startLevel)
  local fee = 100 + levelsGrown * 100
  return startLevel, newLevel, levelsGrown, fee
end

local function clearIfEmpty(save)
  local dc = save.daycare
  if not dc then return end
  if not dc.mon and not dc.mon2 and not dc.egg then
    save.daycare = nil
  end
end

local function afterParentChange(dc)
  if not dc then return end
  if dc.mon and dc.mon2 then
    Breeding.resetBreedCountdown(dc)
  else
    dc.breedSteps = nil
    -- Keep a waiting egg; losing a parent just stops new eggs.
  end
end

local function retrieveMon(game, done, slotKey, levelKey)
  local TextBox = require("src.render.TextBox")
  local Stats = require("src.pokemon.Stats")
  local Party = require("src.pokemon.Party")
  local Pokemon = require("src.pokemon.Pokemon")
  local t = game.data.text
  local dc = game.save.daycare
  local mon = dc and dc[slotKey]
  if not mon then
    done()
    return
  end

  foldPendingExp(game, dc)
  if dc[levelKey] == nil then dc[levelKey] = mon.level end
  local startLevel, newLevel, levelsGrown, fee =
    levelsAndFee(game, mon, dc[levelKey])
  local playerName = game.save.player and game.save.player.name or "RED"
  local name = monName(game, mon)
  local subs = {
    player = playerName,
    wNameBuffer = name,
    wDayCareMonName = name,
    wDayCareNumLevelsGrown = levelsGrown,
    wDayCareTotalCost = fee,
  }

  local statusText = levelsGrown > 0
    and (t._DaycareGentlemanMonHasGrownText
      or "Your {RAM:wNameBuffer}\nhas grown a lot!\fBy level, it's\ngrown by {NUM:wDayCareNumLevelsGrown, 1, 3}!\fAren't I great?")
    or (t._DaycareGentlemanMonNeedsMoreTimeText
      or "Back already?\nYour {RAM:wNameBuffer}\nneeds some more\ntime with me.")

  game.stack:push(TextBox.new(game, fillDaycareText(statusText, subs), function()
    if #game.save.party >= Party.MAX then
      game.stack:push(TextBox.new(game,
        t._DaycareGentlemanNoRoomForMonText
          or "You have no room\nfor this POKéMON!", done))
      return
    end
    game.stack:push(TextBox.new(game,
      fillDaycareText(
        t._DaycareGentlemanOweMoneyText
          or "You owe me ¥{NUM:wDayCareTotalCost, 2 | LEADING_ZEROES | LEFT_ALIGN}\nfor the return\nof this POKéMON.",
        subs),
      nil, { choice = function(yes)
        if not yes then
          mon.level = startLevel
          game.stack:push(TextBox.new(game,
            (t._DaycareGentlemanAllRightThenText or "All right then,\n")
              .. (t._DaycareGentlemanComeAgainText or "come again."),
            done))
          return
        end
        if (game.save.money or 0) < fee then
          mon.level = startLevel
          game.stack:push(TextBox.new(game,
            t._DaycareGentlemanNotEnoughMoneyText
              or "Hey, you don't\nhave enough ¥!", done))
          return
        end
        game.save.money = game.save.money - fee
        mon.level = newLevel
        local def = game.data.pokemon[mon.species]
        if def then
          mon.stats = Stats.calc(def, mon.level, mon.dvs, mon.statExp)
          mon.hp = mon.stats.hp
          Pokemon.learnMovesFromDayCare(
            game.data, mon, def, startLevel, newLevel)
        end
        table.insert(game.save.party, mon)
        dc[slotKey] = nil
        dc[levelKey] = nil
        afterParentChange(dc)
        clearIfEmpty(game.save)
        game.stack:push(TextBox.new(game,
          t._DaycareGentlemanHeresYourMonText
            or "Thank you! Here's\nyour POKéMON!", function()
          game.stack:push(TextBox.new(game,
            fillDaycareText(
              t._DaycareGentlemanGotMonBackText
                or "{PLAYER} got\n{RAM:wDayCareMonName} back!",
              subs), done))
        end))
      end }))
  end))
end

local function depositMon(game, done)
  local TextBox = require("src.render.TextBox")
  local PartyMenu = require("src.ui.PartyMenu")
  local Gender = require("mods.Kanto-Reforged.gender")
  local t = game.data.text
  local dc = ensureDaycare(game.save)
  local playerName = game.save.player and game.save.player.name or "RED"

  if slotCount(dc) >= 2 then
    game.stack:push(TextBox.new(game,
      "I already have\ntwo POKéMON.\nCome back later.", done))
    return
  end

  if #game.save.party < 2 then
    game.stack:push(TextBox.new(game,
      t._DaycareGentlemanOnlyHaveOneMonText
        or "You only have one\nPOKéMON with you.", done))
    return
  end

  game.stack:push(TextBox.new(game,
    t._DaycareGentlemanWhichMonText or "Which POKéMON\nshould I raise?",
    function()
      game.stack:push(PartyMenu.new(game, {
        pickOnly = true,
        onSwitch = function(mon)
          if Breeding.isEgg(mon) then
            game.stack:push(TextBox.new(game,
              "I can't raise\nan EGG!", done))
            return
          end
          Gender.ensure(game.data, mon)
          for i, m in ipairs(game.save.party) do
            if m == mon then table.remove(game.save.party, i) break end
          end
          local name = monName(game, mon)
          local slotKey, levelKey
          if not dc.mon then
            slotKey, levelKey = "mon", "depositLevel"
          else
            slotKey, levelKey = "mon2", "depositLevel2"
          end
          dc[slotKey] = mon
          dc[levelKey] = mon.level
          dc.steps = dc.steps or 0
          if slotCount(dc) == 2 then
            Breeding.resetBreedCountdown(dc)
          end
          game.stack:push(TextBox.new(game,
            fillDaycareText(
              t._DaycareGentlemanWillLookAfterMonText
                or "Fine, I'll look\nafter {RAM:wNameBuffer}\nfor a while.",
              { player = playerName, wNameBuffer = name }),
            function()
              local extra = ""
              if slotCount(dc) == 2 then
                local compat = Breeding.compatibility(game.data, dc.mon, dc.mon2)
                extra = "\f" .. Breeding.compatibilityLine(compat)
              end
              game.stack:push(TextBox.new(game,
                (t._DaycareGentlemanComeSeeMeInAWhileText
                  or "Come see me in\na while.") .. extra, done))
            end))
        end,
      }))
    end))
end

local function offerEgg(game, done)
  local TextBox = require("src.render.TextBox")
  local Party = require("src.pokemon.Party")
  local dc = game.save.daycare
  if not dc or not dc.egg then
    done()
    return
  end

  game.stack:push(TextBox.new(game,
    "Ah, it's you!\fYour POKéMON had\nan EGG!\fYou want it?",
    nil, { choice = function(yes)
      if not yes then
        game.stack:push(TextBox.new(game,
          "I'll keep it a\nwhile. Come back\nlater.", done))
        return
      end
      if #game.save.party >= Party.MAX then
        game.stack:push(TextBox.new(game,
          "You have no room\nfor this EGG!", done))
        return
      end
      table.insert(game.save.party, dc.egg)
      dc.egg = nil
      if dc.mon and dc.mon2 then
        Breeding.resetBreedCountdown(dc)
      end
      game.stack:push(TextBox.new(game,
        Strings("%s received\nthe EGG!",
          game.save.player and game.save.player.name or "RED"), done))
    end }))
end

local function askTakeWhich(game, done)
  local TextBox = require("src.render.TextBox")
  local dc = game.save.daycare
  if not dc then
    done()
    return
  end
  -- Single occupied slot: take it directly (mon2-only used to crash on dc.mon).
  if dc.mon and not dc.mon2 then
    retrieveMon(game, done, "mon", "depositLevel")
    return
  end
  if dc.mon2 and not dc.mon then
    retrieveMon(game, done, "mon2", "depositLevel2")
    return
  end
  if not dc.mon or not dc.mon2 then
    game.stack:push(TextBox.new(game, "Come again.", done))
    return
  end
  local n1 = monName(game, dc.mon)
  game.stack:push(TextBox.new(game,
    "Take " .. n1 .. "?",
    nil, { choice = function(yes)
      if yes then
        retrieveMon(game, done, "mon", "depositLevel")
        return
      end
      local n2 = monName(game, dc.mon2)
      game.stack:push(TextBox.new(game,
        "Take " .. n2 .. "?",
        nil, { choice = function(yes2)
          if yes2 then
            retrieveMon(game, done, "mon2", "depositLevel2")
          else
            game.stack:push(TextBox.new(game, "Come again.", done))
          end
        end }))
    end }))
end

local function afterStatus(game, done)
  local TextBox = require("src.render.TextBox")
  local dc = game.save.daycare
  if not dc or (not dc.mon and not dc.mon2) then
    depositMon(game, done)
    return
  end

  game.stack:push(TextBox.new(game,
    "Want to take a\nPOKéMON back?",
    nil, { choice = function(yes)
      if yes then
        askTakeWhich(game, done)
        return
      end
      if slotCount(dc) < 2 then
        game.stack:push(TextBox.new(game,
          "Want me to raise\nanother POKéMON?",
          nil, { choice = function(yes2)
            if yes2 then
              depositMon(game, done)
            else
              game.stack:push(TextBox.new(game, "Come again.", done))
            end
          end }))
      else
        game.stack:push(TextBox.new(game, "Come again.", done))
      end
    end }))
end

local function occupiedMenu(game, done)
  local TextBox = require("src.render.TextBox")
  local dc = game.save.daycare
  foldPendingExp(game, dc)

  local lines = {}
  if dc.mon then lines[#lines + 1] = monName(game, dc.mon) end
  if dc.mon2 then lines[#lines + 1] = monName(game, dc.mon2) end
  local status = "I'm raising\n" .. table.concat(lines, "\nand\n") .. "."
  if dc.mon and dc.mon2 then
    local compat = Breeding.compatibility(game.data, dc.mon, dc.mon2)
    status = status .. "\f" .. Breeding.compatibilityLine(compat)
  end

  game.stack:push(TextBox.new(game, status, function()
    if dc.egg then
      offerEgg(game, function()
        afterStatus(game, done)
      end)
      return
    end
    afterStatus(game, done)
  end))
end

local function isLady(npc)
  local d = npc and npc.def
  return d and (d.text == Daycare.LADY_TEXT or d.name == Daycare.LADY_NAME)
end

function Daycare.talkHandler(game, ow, npc, done)
  local TextBox = require("src.render.TextBox")
  local t = game.data.text
  local dc = game.save.daycare

  if dc and dc.egg and not dc.mon and not dc.mon2 then
    offerEgg(game, done)
    return
  end

  if dc and (dc.mon or dc.mon2) then
    occupiedMenu(game, done)
    return
  end

  local intro = isLady(npc)
    and "I'm the DAY-CARE\nLADY.\fI can raise up to\ntwo of your\nPOKéMON.\fWant me to raise\na POKéMON?"
    or "I'm the DAY-CARE\nMAN.\fI can raise up to\ntwo of your\nPOKéMON.\fWant me to raise\na POKéMON?"

  game.stack:push(TextBox.new(game, intro, nil, { choice = function(yes)
      if not yes then
        game.stack:push(TextBox.new(game,
          t._DaycareGentlemanComeAgainText or "Come again.", done))
        return
      end
      depositMon(game, done)
    end }))
end

function Daycare.register(mod)
  -- Vanilla furniture/warps; Blue's House–style duo (gentleman + lady).
  mod.content.maps:patch("DAYCARE", {
    blocks = Daycare.BLOCKS,
    objects = {
      Daycare.GENTLEMAN,
      Daycare.LADY,
    },
  })
  mod.content.map_scripts:register("DAYCARE", {
    priority = 50,
    talk = {
      TEXT_DAYCARE_GENTLEMAN = Daycare.talkHandler,
      [Daycare.LADY_TEXT] = Daycare.talkHandler,
    },
  })
end

local function scrubSlot(save, data, report, key, fromLabel)
  local daycare = save.daycare
  if type(daycare) ~= "table" then return end
  local mon = daycare[key]
  if type(mon) ~= "table" then return end
  local species = mon.species
  if species and data.pokemon and data.pokemon[species] then return end
  if Breeding.isEgg(mon) then
    daycare[key] = nil
  else
    save.orphaned = save.orphaned or { mons = {}, items = {} }
    save.orphaned.mons = save.orphaned.mons or {}
    save.orphaned.mons[#save.orphaned.mons + 1] = mon
    daycare[key] = nil
  end
  report.lostMons[#report.lostMons + 1] =
    { species = species, from = fromLabel }
end

local function showHatchMessages(game, hatched)
  if not game or not game.stack or #hatched == 0 then return end
  local TextBox = require("src.render.TextBox")
  local i = 1
  local function next()
    if i > #hatched then return end
    local baby = hatched[i].mon
    i = i + 1
    local def = game.data.pokemon[baby.species]
    local name = (def and def.name) or baby.species
    game.stack:push(TextBox.new(game,
      Strings("The EGG hatched\ninto %s!", name), next))
  end
  next()
end

function Daycare.install(mod)
  Daycare._mod = mod

  local OverworldState = require("src.world.OverworldController")
  local FieldDefaults = require("src.world.FieldDefaults")
  local Game = require("src.core.Game")
  local Party = require("src.pokemon.Party")
  local SaveData = require("src.core.SaveData")

  if not OverworldState._expDaycareBreedPatch then
    local origOnStep = OverworldState.onStepComplete
    OverworldState.onStepComplete = function(self)
      local dc = Game.save and Game.save.daycare
      -- Vanilla only ticks when daycare.mon is set; cover mon2-only.
      local needMon2Step = dc and dc.mon2 and not dc.mon

      origOnStep(self)

      dc = Game.save and Game.save.daycare
      if needMon2Step and dc and dc.mon2 and not dc.mon then
        dc.steps = (dc.steps or 0)
          + (FieldDefaults.world(Game.data, "daycareExpPerStep") or 1)
      end

      -- Breed countdown / egg roll
      dc = Game.save and Game.save.daycare
      if dc and dc.mon and dc.mon2 and not dc.egg then
        if type(dc.breedSteps) ~= "number" then
          Breeding.resetBreedCountdown(dc)
        end
        dc.breedSteps = (dc.breedSteps or 1) - 1
        if dc.breedSteps <= 0 then
          Breeding.tryCreateDaycareEgg(Game.data, Game.save)
        end
      end

      -- Party egg hatch cycles (Gen 3: 256 steps per cycle)
      if Game.save and Game.save.party then
        Game.save.eggWalkSteps = (Game.save.eggWalkSteps or 0) + 1
        if Game.save.eggWalkSteps >= Breeding.STEPS_PER_CYCLE then
          Game.save.eggWalkSteps = 0
          local hatched = Breeding.tickPartyEggs(Game.data, Game.save, 1)
          if #hatched > 0 then
            showHatchMessages(Game, hatched)
          end
        end
      end
    end
    OverworldState._expDaycareBreedPatch = true
  end

  -- Eggs are never battle leads / field-move users via firstHealthy.
  if not Party._expEggHealthyPatch then
    local origHealthy = Party.firstHealthy
    Party.firstHealthy = function(party)
      for i, mon in ipairs(party or {}) do
        if mon and not Breeding.isEgg(mon) and (mon.hp or 0) > 0 then
          return mon, i
        end
      end
      return nil
    end
    Party._expEggHealthyPatch = true
    -- Keep a reference so tests can reason about vanilla if needed.
    Party._origFirstHealthy = origHealthy
  end

  -- Party submenu: strip Give/field actions on eggs.
  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if not Breeding.isEgg(mon) then return out end
    local filtered = {}
    for _, entry in ipairs(out or {}) do
      local label = entry.label or ""
      if label == "STATS" or label == Strings("STATS") then
        filtered[#filtered + 1] = entry
      end
    end
    if #filtered == 0 then
      filtered[1] = { label = Strings("STATS"), action = "stats" }
    end
    return filtered
  end)

  -- Quarantine mon2 + daycare egg + party eggs after SaveData.validate.
  if not SaveData._expDaycareValidatePatch then
    local origValidate = SaveData.validate
    SaveData.validate = function(save, data)
      local report = origValidate(save, data)
      scrubSlot(save, data, report, "mon2", "daycare")
      if type(save.daycare) == "table" and type(save.daycare.egg) == "table" then
        local egg = save.daycare.egg
        if egg.species and not (data.pokemon and data.pokemon[egg.species]) then
          save.daycare.egg = nil
          report.lostMons[#report.lostMons + 1] =
            { species = egg.species, from = "daycare-egg" }
        end
      end
      for i = #(save.party or {}), 1, -1 do
        local mon = save.party[i]
        if Breeding.isEgg(mon)
            and mon.species
            and not (data.pokemon and data.pokemon[mon.species]) then
          table.remove(save.party, i)
          report.lostMons[#report.lostMons + 1] =
            { species = mon.species, from = "party-egg" }
        end
      end
      clearIfEmpty(save)
      return report
    end
    SaveData._expDaycareValidatePatch = true
  end
end

return Daycare
