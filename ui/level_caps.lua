-- Viridian / Cherrygrove Rare Candy NPC + optional level-cap system.
-- Taking candies from him once permanently enables soft level caps
-- (Radical Red style): at the current story cap, battle XP becomes +1 and
-- you cannot Rare-Candy past it. Caps rise at major fights.
-- Never taking candy leaves vanilla leveling alone.

local Strings = require("src.core.Strings")

local LevelCaps = {}

LevelCaps.SAVE_KEY = "level_caps_on"
LevelCaps.CANDY_STACK = 99
LevelCaps.NPC_NAME = "VIRIDIANCITY_CANDY_GUY"
LevelCaps.TEXT_ID = "TEXT_VIRIDIANCITY_CANDY_GUY"

LevelCaps.NPC_VIRIDIAN = {
  index = 8,
  name = LevelCaps.NPC_NAME,
  sprite = "SPRITE_YOUNGSTER",
  movement = "STAY",
  range = "DOWN",
  text = LevelCaps.TEXT_ID,
  x = 31,
  y = 20,
}

LevelCaps.NPC_CHERRYGROVE = {
  index = 8,
  name = LevelCaps.NPC_NAME,
  sprite = "SPRITE_YOUNGSTER",
  movement = "STAY",
  range = "DOWN",
  text = LevelCaps.TEXT_ID,
  x = 25,
  y = 3,
}

LevelCaps.NPC = LevelCaps.NPC_VIRIDIAN

-- Gen 1 milestones (Kanto)
LevelCaps.MILESTONES_GEN1 = {
  { cap = 14, name = "Pre-Brock" },
  { cap = 16, name = "Pre-Mt. Moon",
    any = { "EVENT_BEAT_BROCK", "BOULDERBADGE" } },
  { cap = 18, name = "Pre-Nugget Bridge",
    any = { "EVENT_GOT_DOME_FOSSIL", "EVENT_GOT_HELIX_FOSSIL" } },
  { cap = 21, name = "Pre-Misty",
    any = { "EVENT_GOT_NUGGET" } },
  { cap = 24, name = "Pre-Surge",
    any = { "EVENT_BEAT_MISTY", "CASCADEBADGE" } },
  { cap = 29, name = "Pre-Erika / Hideout",
    any = { "EVENT_BEAT_LT_SURGE", "THUNDERBADGE" } },
  { cap = 41, name = "Pre-Silph Giovanni", erikaAndHideout = true },
  { cap = 43, name = "Pre-Koga / Sabrina",
    any = { "EVENT_BEAT_SILPH_CO_GIOVANNI" } },
  { cap = 47, name = "Pre-Blaine",
    any = {
      "EVENT_BEAT_KOGA", "SOULBADGE",
      "EVENT_BEAT_SABRINA", "MARSHBADGE",
    } },
  { cap = 50, name = "Pre-Giovanni",
    any = { "EVENT_BEAT_BLAINE", "VOLCANOBADGE" } },
  { cap = 53, name = "Pre-Victory Road",
    any = { "EVENT_BEAT_GIOVANNI", "EARTHBADGE" } },
  { cap = 65, name = "Pre-Champion",
    any = {
      "EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE",
      "EVENT_STARTED_ELITE_4",
      "EVENT_BEAT_LANCE",
    } },
  { cap = 100, name = "Post-game",
    any = { "EVENT_BEAT_CHAMPION_RIVAL" } },
}

LevelCaps.MILESTONES = LevelCaps.MILESTONES_GEN1

-- Gen 2 milestones (Johto Arc)
LevelCaps.MILESTONES_GEN2 = {
  { cap = 14, name = "Pre-Falkner" },
  { cap = 16, name = "Pre-Bugsy",
    any = { "EVENT_BEAT_FALKNER", "ENGINE_ZEPHYRBADGE" } },
  { cap = 20, name = "Pre-Whitney",
    any = { "EVENT_BEAT_BUGSY", "ENGINE_HIVEBADGE" } },
  { cap = 25, name = "Pre-Morty",
    any = { "EVENT_BEAT_WHITNEY", "ENGINE_PLAINBADGE" } },
  { cap = 30, name = "Pre-Chuck",
    any = { "EVENT_BEAT_MORTY", "ENGINE_FOGBADGE" } },
  { cap = 32, name = "Pre-Pryce / Hideout",
    any = { "EVENT_BEAT_CHUCK", "ENGINE_STORMBADGE" } },
  { cap = 35, name = "Pre-Jasmine",
    any = { "EVENT_BEAT_PRYCE", "ENGINE_GLACIERBADGE", "EVENT_CLEARED_ROCKET_HIDEOUT" } },
  { cap = 38, name = "Pre-Radio Tower",
    any = { "EVENT_BEAT_JASMINE", "ENGINE_MINERALBADGE" } },
  { cap = 40, name = "Pre-Clair",
    any = { "EVENT_CLEARED_RADIO_TOWER" } },
  { cap = 44, name = "Pre-Victory Road Rival",
    any = { "EVENT_BEAT_CLAIR", "ENGINE_RISINGBADGE" } },
  { cap = 50, name = "Pre-Champion Lance",
    any = { "EVENT_RIVAL_VICTORY_ROAD" } },
}

LevelCaps.KANTO_BADGES_GEN2 = {
  "ENGINE_BOULDERBADGE",
  "ENGINE_CASCADEBADGE",
  "ENGINE_THUNDERBADGE",
  "ENGINE_RAINBOWBADGE",
  "ENGINE_SOULBADGE",
  "ENGINE_MARSHBADGE",
  "ENGINE_VOLCANOBADGE",
  "ENGINE_EARTHBADGE",
}

-- Gen 3 milestones (FireRed / LeafGreen)
LevelCaps.MILESTONES_GEN3 = {
  { cap = 14, name = "Pre-Brock" },
  { cap = 16, name = "Pre-Mt. Moon", any = { 0x820, "FLAG_BADGE01_GET", 0x4B0, "FLAG_DEFEATED_BROCK", "BOULDERBADGE" } },
  { cap = 18, name = "Pre-Nugget Bridge", any = { 0x272, "FLAG_GOT_DOME_FOSSIL", 0x273, "FLAG_GOT_HELIX_FOSSIL", 0x232, "FLAG_GOT_FOSSIL_FROM_MT_MOON" } },
  { cap = 21, name = "Pre-Misty", any = { 0x31, "FLAG_HIDE_NUGGET_BRIDGE_ROCKET", 0x250, "FLAG_GOT_MASTER_BALL_FROM_SILPH" } },
  { cap = 24, name = "Pre-Surge", any = { 0x821, "FLAG_BADGE02_GET", 0x4B1, "FLAG_DEFEATED_MISTY", "CASCADEBADGE" } },
  { cap = 29, name = "Pre-Erika", any = { 0x822, "FLAG_BADGE03_GET", 0x4B2, "FLAG_DEFEATED_LT_SURGE", "THUNDERBADGE" } },
  { cap = 43, name = "Pre-Koga", any = { 0x823, "FLAG_BADGE04_GET", 0x4B3, "FLAG_DEFEATED_ERIKA", "RAINBOWBADGE" } },
  { cap = 47, name = "Pre-Sabrina", any = { 0x824, "FLAG_BADGE05_GET", 0x4B4, "FLAG_DEFEATED_KOGA", "SOULBADGE" } },
  { cap = 50, name = "Pre-Blaine", any = { 0x825, "FLAG_BADGE06_GET", 0x4B5, "FLAG_DEFEATED_SABRINA", "MARSHBADGE" } },
  { cap = 53, name = "Pre-Giovanni", any = { 0x826, "FLAG_BADGE07_GET", 0x4B6, "FLAG_DEFEATED_BLAINE", "VOLCANOBADGE" } },
  { cap = 55, name = "Pre-Victory Road", any = { 0x827, "FLAG_BADGE08_GET", 0x4B7, "FLAG_DEFEATED_LEADER_GIOVANNI", "EARTHBADGE" } },
  { cap = 65, name = "Pre-Champion", any = { 0x4BB, "FLAG_DEFEATED_LANCE" } },
  { cap = 100, name = "Post-game", any = { 0x82C, "FLAG_SYS_GAME_CLEAR", 0x4BC, "FLAG_DEFEATED_CHAMP" } },
}

local function hasKey(save, key)
  if not save or not key then return false end

  -- 1. Direct save.flags lookup
  if save.flags and save.flags[key] then return true end

  -- 2. Item/Badge lookup in save.inventory or save.player
  if type(key) == "string" and key:find("BADGE", 1, true) then
    if save.inventory and save.inventory[key] then return true end
    if save.player and save.player.kantoBadges and save.player.kantoBadges[key] then return true end
    if save.player and save.player.badges and save.player.badges[key] then return true end
  end

  -- 3. Gen 2 Engine flags (ENGINE_*)
  if save.engineFlags then
    if save.engineFlags[key] then return true end
    local FlagNames = package.loaded["src.core.gen2.FlagNames"]
    if FlagNames and FlagNames.engine and FlagNames.engine[key] then
      local id = FlagNames.engine[key]
      if save.engineFlags[id] then return true end
    end
  end

  -- 4. Gen 2 Event flags (EVENT_*)
  if save.events then
    local FlagNames = package.loaded["src.core.gen2.FlagNames"]
    if FlagNames and FlagNames.events and FlagNames.events[key] then
      local id = FlagNames.events[key]
      if type(save.events.get) == "function" then
        if save.events:get(id) then return true end
      elseif type(save.events) == "table" and save.events[id] then
        return true
      end
    end
  end

  -- 5. Gen 3 flags (Flags.getFlag)
  local okFlags, Flags = pcall(require, "src.core.game3.scripting.flags")
  if okFlags and Flags and Flags.getFlag then
    if Flags.getFlag(save, nil, key) then return true end
    if save.session and Flags.getFlag(save.session, nil, key) then return true end
  end
  if save.flags then
    local num = tonumber(key)
    if num and (save.flags[num] or save.flags[tostring(num)]) then return true end
  end

  return false
end

function LevelCaps.kantoBadgeCount(save)
  if not save then return 0 end
  local count = 0
  for _, flagKey in ipairs(LevelCaps.KANTO_BADGES_GEN2) do
    if hasKey(save, flagKey) then
      count = count + 1
    end
  end
  return count
end

local function erikaAndHideoutDone(save)
  local erika = hasKey(save, "EVENT_BEAT_ERIKA") or hasKey(save, "RAINBOWBADGE")
  return erika and hasKey(save, "EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI")
end

local function milestoneUnlocked(save, entry)
  if entry.erikaAndHideout then
    return erikaAndHideoutDone(save)
  end
  if entry.all then
    for _, key in ipairs(entry.all) do
      if not hasKey(save, key) then return false end
    end
    return true
  end
  if entry.any then
    for _, key in ipairs(entry.any) do
      if hasKey(save, key) then return true end
    end
    return false
  end
  return true
end

function LevelCaps.enabled(mod)
  return mod and mod.save and mod.save:get(LevelCaps.SAVE_KEY, false) and true or false
end

function LevelCaps.enable(mod)
  mod.save:set(LevelCaps.SAVE_KEY, true)
end

function LevelCaps.capForGen1(data, save)
  local cap = 14
  for _, entry in ipairs(LevelCaps.MILESTONES_GEN1) do
    if milestoneUnlocked(save, entry) and entry.cap > cap then
      cap = entry.cap
    end
  end
  return cap
end

function LevelCaps.capForGen2(data, save)
  local e4Done = hasKey(save, "EVENT_BEAT_ELITE_FOUR")
    or hasKey(save, "EVENT_BEAT_CHAMPION_LANCE")
    or (save and save.engineFlags and save.engineFlags[15])

  local kCount = LevelCaps.kantoBadgeCount(save)

  if e4Done or kCount > 0 then
    if hasKey(save, "EVENT_RED_IN_MT_SILVER") then
      return 100
    elseif hasKey(save, "EVENT_BEAT_RIVAL_IN_MT_MOON") or hasKey(save, "ENGINE_EARTHBADGE") or kCount >= 8 then
      return 85
    elseif kCount >= 7 then
      return 72
    elseif kCount >= 3 then
      return 64
    else
      return 58
    end
  end

  local cap = 14
  for _, entry in ipairs(LevelCaps.MILESTONES_GEN2) do
    if milestoneUnlocked(save, entry) and entry.cap > cap then
      cap = entry.cap
    end
  end
  return cap
end

function LevelCaps.capForGen3(data, save)
  local cap = 14
  local function unlocked(keys)
    for _, k in ipairs(keys) do
      if hasKey(save, k) then return true end
    end
    return false
  end

  if unlocked({ 0x82C, "FLAG_SYS_GAME_CLEAR", 0x4BC, "FLAG_DEFEATED_CHAMP" }) then
    return 100
  end
  if unlocked({ 0x4BB, "FLAG_DEFEATED_LANCE" }) then
    cap = math.max(cap, 65)
  end
  if unlocked({ 0x827, "FLAG_BADGE08_GET", 0x4B7, "FLAG_DEFEATED_LEADER_GIOVANNI", "EARTHBADGE" }) then
    cap = math.max(cap, 55)
  end
  if unlocked({ 0x826, "FLAG_BADGE07_GET", 0x4B6, "FLAG_DEFEATED_BLAINE", "VOLCANOBADGE" }) then
    cap = math.max(cap, 53)
  end
  if unlocked({ 0x825, "FLAG_BADGE06_GET", 0x4B5, "FLAG_DEFEATED_SABRINA", "MARSHBADGE" }) then
    cap = math.max(cap, 50)
  end
  if unlocked({ 0x824, "FLAG_BADGE05_GET", 0x4B4, "FLAG_DEFEATED_KOGA", "SOULBADGE" }) then
    cap = math.max(cap, 47)
  end
  if unlocked({ 0x823, "FLAG_BADGE04_GET", 0x4B3, "FLAG_DEFEATED_ERIKA", "RAINBOWBADGE" }) then
    cap = math.max(cap, 43)
  end
  if unlocked({ 0x822, "FLAG_BADGE03_GET", 0x4B2, "FLAG_DEFEATED_LT_SURGE", "THUNDERBADGE" }) then
    cap = math.max(cap, 29)
  end
  if unlocked({ 0x821, "FLAG_BADGE02_GET", 0x4B1, "FLAG_DEFEATED_MISTY", "CASCADEBADGE" }) then
    cap = math.max(cap, 24)
  end
  if unlocked({ 0x31, "FLAG_HIDE_NUGGET_BRIDGE_ROCKET", 0x250, "FLAG_GOT_MASTER_BALL_FROM_SILPH" }) then
    cap = math.max(cap, 21)
  end
  if unlocked({ 0x272, "FLAG_GOT_DOME_FOSSIL", 0x273, "FLAG_GOT_HELIX_FOSSIL", 0x232, "FLAG_GOT_FOSSIL_FROM_MT_MOON" }) then
    cap = math.max(cap, 18)
  end
  if unlocked({ 0x820, "FLAG_BADGE01_GET", 0x4B0, "FLAG_DEFEATED_BROCK", "BOULDERBADGE" }) then
    cap = math.max(cap, 16)
  end

  return cap
end

function LevelCaps.capFor(data, save)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    return LevelCaps.capForGen3(data, save)
  elseif Host.isGen2() then
    return LevelCaps.capForGen2(data, save)
  end
  return LevelCaps.capForGen1(data, save)
end

function LevelCaps.cap(mod, data, save)
  if not LevelCaps.enabled(mod) then return nil end
  return LevelCaps.capFor(data, save)
end

local function currentSave()
  if LevelCaps._session then return LevelCaps._session end
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local Rt = package.loaded["src.core.game3.runtime"]
    if Rt and Rt.session then return Rt.session end
    if Rt and Rt.getSession then
      local s = Rt.getSession()
      if s then return s end
    end
    local Fld = package.loaded["src.core.game3.field"]
    if Fld and Fld._session then return Fld._session end
  end
  local Game = Host.liveGame(LevelCaps._mod)
  return Game and (Game.session or Game.save)
end

local function currentData()
  local Game = require("mods.Kanto-Reforged.core.host").liveGame(LevelCaps._mod)
  return Game and Game.data
end

local function pushText(game, msg, done)
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, msg, done))
end

local function ask(game, msg, cb)
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, msg, nil, { choice = cb }))
end

local function pinExpAtLevel(data, mon, level)
  local Growth = require("src.pokemon.Growth")
  local speciesDef = data and data.pokemon and data.pokemon[mon and mon.species]
  if not speciesDef or not mon then return end
  local nextExp = Growth.expForLevel(speciesDef.growthRate, (level or mon.level or 1) + 1, data and data.growth_rates)
  local curExp = mon.exp or mon.experience
    or (speciesDef.growthRate and Growth.expForLevel(speciesDef.growthRate, mon.level or 1, data and data.growth_rates))
    or 0
  if nextExp and curExp and curExp >= nextExp then
    mon.exp = nextExp - 1
    if mon.experience ~= nil then
      mon.experience = mon.exp
    end
  end
end

-- Top up RARE_CANDY toward a full stack. Returns qty given (0 if none).
function LevelCaps.giveCandyStack(save)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local Bag = require("src.core.game3.bag")
    local bag = (save and save.bag) or save
    local have = Bag.get(bag, 68) or 0
    local qty = LevelCaps.CANDY_STACK - have
    if qty <= 0 then return 0 end
    if not Bag.add(bag, 68, qty) then return 0 end
    return qty
  end

  local Bag = require("src.inventory.Bag")
  local have = (save.inventory and save.inventory.RARE_CANDY) or 0
  local qty = LevelCaps.CANDY_STACK - have
  if qty <= 0 then return 0 end
  if not Bag.add(save, "RARE_CANDY", qty) then return 0 end
  return qty
end

local function giveCandies(game, mod, done, enableOnSuccess)
  local qty = LevelCaps.giveCandyStack(game.save)
  if qty <= 0 then
    pushText(game, Strings(
      "Your bag can't hold\nany more RARE\vCANDIES!\f"
      .. "Come back when\nyou've made room."), done)
    return
  end
  if enableOnSuccess then
    LevelCaps.enable(mod)
  end
  local cap = LevelCaps.capFor(game.data, game.save)
  pushText(game, Strings(
    "Here! Take %d\nRARE CANDIES!\f"
    .. "Your level cap is\n%d right now.\f"
    .. "Beat the next big\nfight to raise it!",
    qty, cap), done)
end

local function showMsgGen3(game, msg, done)
  local okM, Message = pcall(require, "src.ui.game3.message")
  if okM and Message and Message.show then
    Message.show(msg, done)
    return
  end
  local okBox, TextBox = pcall(require, "src.render.TextBox")
  if okBox and TextBox and game and game.stack then
    game.stack:push(TextBox.new(game, msg, done))
    return
  end
  if done then done() end
end

local function showYesNoGen3(game, msg, onChoice)
  local okM, Message = pcall(require, "src.ui.game3.message")
  local okC, Choice = pcall(require, "src.ui.game3.choice")
  if okM and Message and Message.show and okC and Choice and Choice.yesNo then
    Message.show(msg, function()
      Choice.yesNo(function(yes)
        if onChoice then onChoice(yes == true or yes == 0) end
      end)
    end)
    return
  end
  local okBox, TextBox = pcall(require, "src.render.TextBox")
  if okBox and TextBox and game and game.stack then
    game.stack:push(TextBox.new(game, msg, nil, { choice = onChoice }))
    return
  end
  if onChoice then onChoice(false) end
end

function LevelCaps.triggerDialogueGen3(game, mod, session, done)
  local save = session or (game and game.save) or currentSave()
  local function finish()
    local okO, Objects = pcall(require, "src.core.game3.objects")
    if okO and Objects and Objects.unfreeze then Objects.unfreeze(88) end
    local okF, Field = pcall(require, "src.core.game3.field")
    if okF and Field and Field.unlock then Field.unlock() end
    if done then done() end
  end

  if LevelCaps.enabled(mod) then
    showYesNoGen3(game, "Need more RARE CANDIES?\nLevel caps are already on.\nWant another full stack?", function(yes)
      if yes then
        local qty = LevelCaps.giveCandyStack(save)
        if qty <= 0 then
          showMsgGen3(game, "Your bag can't hold any more\nRARE CANDIES! Come back when\nyou've made room.", finish)
        else
          local cap = LevelCaps.capFor(nil, save)
          showMsgGen3(game, string.format("Here! Take %d RARE CANDIES!\nYour level cap is %d right now.\nBeat the next big fight to raise it!", qty, cap), finish)
        end
      else
        showMsgGen3(game, "Alright. Keep training smart!", finish)
      end
    end)
    return
  end

  showYesNoGen3(game, "Hey! I stockpile RARE CANDIES.\nI can give you a full stack...\nBUT if you take them, your POKéMON\nwill be locked to a level cap!\n\nIt rises after big fights--Mt. Moon,\nNugget Bridge, gyms, and more.\nAt the cap they only gain 1 EXP.\n\nThis can't be undone. Still want them?", function(yes)
    if yes then
      LevelCaps.enable(mod)
      local qty = LevelCaps.giveCandyStack(save)
      local cap = LevelCaps.capFor(nil, save)
      showMsgGen3(game, string.format("Here! Take %d RARE CANDIES!\nYour level cap is %d right now.\nBeat the next big fight to raise it!", qty, cap), finish)
    else
      showMsgGen3(game, "No worries. Talk to me if you\nchange your mind. Without the\ncandy, leveling stays normal.", finish)
    end
  end)
end

local function talkHandler(mod)
  return function(game, ow, npc, done)
    if LevelCaps.enabled(mod) then
      ask(game, Strings(
        "Need more RARE\nCANDIES?\f"
        .. "Level caps are\nalready on.\f"
        .. "Want another full\nstack?"), function(yes)
        if yes then
          giveCandies(game, mod, done, false)
        else
          pushText(game, Strings("Alright. Keep\ntraining smart!"), done)
        end
      end)
      return
    end

    ask(game, Strings(
      "Hey! I stockpile\nRARE CANDIES.\f"
      .. "I can give you a\nfull stack...\f"
      .. "BUT if you take\nthem, your POKéMON\v"
      .. "will be locked to\na level cap!\f"
      .. "It rises after big\nfights--Mt. Moon,\v"
      .. "Nugget Bridge,\ngyms, and more.\f"
      .. "At the cap they\nonly gain 1 EXP.\f"
      .. "This can't be\nundone. Still want\vthem?"), function(yes)
      if not yes then
        pushText(game, Strings(
          "No worries. Talk\nto me if you\vchange your mind.\f"
          .. "Without the candy,\nleveling stays\vnormal."), done)
        return
      end
      giveCandies(game, mod, done, true)
    end)
  end
end

local function getYoungObjGen3()
  return {
    index = 88,
    localId = 88,
    name = LevelCaps.NPC_NAME,
    sprite = "SPRITE_YOUNGSTER",
    graphicsId = 18, -- OBJ_EVENT_GFX_YOUNGSTER
    graphics = 18,
    movementType = 8,
    movement = "STAY",
    range = "DOWN",
    scriptKey = LevelCaps.TEXT_ID,
    text = LevelCaps.TEXT_ID,
    elevation = 3,
    x = LevelCaps.NPC_VIRIDIAN.x,
    y = LevelCaps.NPC_VIRIDIAN.y,
  }
end

local function injectYoungsterGen3(targetMapId)
  local young = getYoungObjGen3()
  local targetKeys = targetMapId and { targetMapId } or { "FR_VIRIDIAN_CITY", "VIRIDIAN_CITY", "ViridianCity" }
  local okSp, Space = pcall(require, "src.core.game3.scripting.space")
  if okSp and Space and Space.bundle and Space.bundle.events then
    for _, k in ipairs(targetKeys) do
      local ev = Space.bundle.events[k]
      if ev then
        local objs = ev.objects or ev.objectEvents
        if objs then
          local exists = false
          for _, o in ipairs(objs) do
            if o.localId == young.localId or (o.x == young.x and o.y == young.y) then
              exists = true
              break
            end
          end
          if not exists then
            table.insert(objs, young)
          end
        end
      end
    end
  end
end

LevelCaps.getYoungObjGen3 = getYoungObjGen3
LevelCaps.injectYoungsterGen3 = injectYoungsterGen3

function LevelCaps.register(mod)
  LevelCaps._mod = mod
  local Host = require("mods.Kanto-Reforged.core.host")
  local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
  local isGen3 = Host.isGen3From(mod) or Host.isGen3()
  local isGen2 = Host.isGen2From(mod) or Host.isGen2()
  if isGen3 then
    injectYoungsterGen3()
    local okData, Data = pcall(require, "src.core.Data")
    if okData and Data and Data.maps then
      local youngObj = getYoungObjGen3()
      for _, mKey in ipairs({ "FR_VIRIDIAN_CITY", "VIRIDIAN_CITY", "ViridianCity" }) do
        if Data.maps[mKey] then
          Data.maps[mKey].objects = Data.maps[mKey].objects or {}
          table.insert(Data.maps[mKey].objects, youngObj)
        end
      end
    end
  elseif isGen2 then
    -- In Gen 2, only place in Viridian City (Kanto), hiding from Cherrygrove City (Johto)
    HouseNpcs.appendNpc(mod, "VIRIDIAN_CITY", LevelCaps.NPC_VIRIDIAN, "level_caps")
    HouseNpcs.bindTalk(mod, "VIRIDIAN_CITY", {
      [LevelCaps.TEXT_ID] = talkHandler(mod),
    })
  else
    mod.content.maps:patch("VIRIDIAN_CITY", {
      objects = {
        __append = {
          LevelCaps.NPC_VIRIDIAN,
        },
      },
    })
    mod.content.map_scripts:register("VIRIDIAN_CITY", {
      talk = {
        [LevelCaps.TEXT_ID] = talkHandler(mod),
      },
    })
  end
end

-- Soft-cap battle XP and pin EXP so +1 never accumulates into a level-up.
function LevelCaps.install(mod)
  LevelCaps._mod = mod

  mod.hooks:wrap("exp.gain", function(next, ctx)
    local gained = next(ctx)
    if not LevelCaps.enabled(mod) then return gained end
    local save = currentSave()
    local data = currentData() or (ctx and ctx.data)
    if not save or not data or not ctx or not ctx.mon then return gained end
    local cap = LevelCaps.capFor(data, save)
    if ctx.mon.level >= cap then
      return 1
    end
    return gained
  end)

  local okExp, Experience = pcall(require, "src.battle.Experience")
  if okExp and Experience and not Experience._expansionLevelCaps then
    local Growth = require("src.pokemon.Growth")
    local original = Experience.apply
    -- Forward opts and the deferred `steps` third return so awardExp's
    -- applyShare (`#steps`) does not crash under the soft cap wrap.
    Experience.apply = function(data, mon, defeatedDef, level, isTrainer,
                                  numParticipants, traded, opts)
      if mon then
        if not mon.exp then
          local speciesDef = data and data.pokemon and data.pokemon[mon.species]
          local growthRate = speciesDef and speciesDef.growthRate
          mon.exp = mon.experience
            or (growthRate and Growth.expForLevel(growthRate, mon.level or 1, data and data.growth_rates))
            or 0
        end
        if mon.experience ~= nil and mon.exp ~= nil then
          mon.experience = mon.exp
        end
      end
      local preLevel = mon and mon.level or 0
      local levels, gained, steps = original(data, mon, defeatedDef, level,
        isTrainer, numParticipants, traded, opts)
      steps = steps or {}
      local m = LevelCaps._mod
      if not m or not LevelCaps.enabled(m) then
        return levels, gained, steps
      end
      local save = currentSave()
      if not save or not mon then return levels, gained, steps end
      local cap = LevelCaps.capFor(data, save)
      local speciesDef = data and data.pokemon and data.pokemon[mon.species]
      if not speciesDef then return levels, gained, steps end

      local defer = opts and opts.defer
      if preLevel > cap then
        if not defer then mon.level = preLevel end
        pinExpAtLevel(data, mon, preLevel)
        return {}, gained, {}
      end

      local kept, keptSteps = {}, {}
      for i, lv in ipairs(levels) do
        if lv <= cap then
          kept[#kept + 1] = lv
          if steps[i] then keptSteps[#keptSteps + 1] = steps[i] end
        end
      end

      if not defer then
        if mon.level > cap then
          mon.level = cap
          mon.exp = Growth.expForLevel(speciesDef.growthRate, cap)
          if #keptSteps > 0 then
            local last = keptSteps[#keptSteps]
            mon.stats, mon.hp = last.stats, last.hp
          end
        elseif mon.level == cap then
          pinExpAtLevel(data, mon, cap)
        end
      elseif #kept < #levels or preLevel == cap
          or (#kept > 0 and kept[#kept] == cap) then
        pinExpAtLevel(data, mon, (#kept > 0 and kept[#kept]) or cap)
      end
      return kept, gained, keptSteps
    end
    Experience._expansionLevelCaps = true
  end

  local okItemEffects, ItemEffects = pcall(require, "src.inventory.ItemEffects")
  if okItemEffects and ItemEffects and not ItemEffects._expansionLevelCaps then
    local originalUse = ItemEffects.use
    ItemEffects.use = function(data, save, itemId, target, ...)
      local m = LevelCaps._mod
      if m and LevelCaps.enabled(m) and itemId == "RARE_CANDY" and target then
        local cap = LevelCaps.capFor(data, save)
        if target.level >= cap then
          return "failed", { Strings("It won't have\nany effect.") }
        end
      end
      return originalUse(data, save, itemId, target, ...)
    end
    ItemEffects._expansionLevelCaps = true
  end

  -- Gen 3 Objects.loadMap wrap to guarantee Youngster is present on Viridian City
  local okObj, Objects = pcall(require, "src.core.game3.objects")
  if okObj and Objects and Objects.loadMap and not Objects._krLevelCapsWrapped then
    local origLoadMap = Objects.loadMap
    Objects.loadMap = function(game, mapId, mapDef)
      if mapId == "FR_VIRIDIAN_CITY" or mapId == "VIRIDIAN_CITY" or mapId == "ViridianCity" then
        injectYoungsterGen3(mapId)
        if mapDef and mapDef.objects then
          local young = getYoungObjGen3()
          local exists = false
          for _, o in ipairs(mapDef.objects) do
            if o.localId == young.localId or (o.x == young.x and o.y == young.y) then
              exists = true
              break
            end
          end
          if not exists then
            table.insert(mapDef.objects, young)
          end
        end
      end
      local res = origLoadMap(game, mapId, mapDef)
      if mapId == "FR_VIRIDIAN_CITY" or mapId == "VIRIDIAN_CITY" or mapId == "ViridianCity" then
        local young = getYoungObjGen3()
        if not Objects._byId[young.localId] then
          local eo = Objects.spawnFromTemplate and Objects.spawnFromTemplate(young, mapId)
          if eo then
            Objects._byId[young.localId] = eo
            table.insert(Objects._order, young.localId)
          end
        end
      end
      return res
    end
    Objects._krLevelCapsWrapped = true
  end

  -- Gen 3 world.talk hook
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("world.talk", function(next, game, eo)
      local lid = eo and (eo.localId or (eo.def and eo.def.localId))
      local name = eo and (eo.name or (eo.def and eo.def.name))
      local text = eo and (eo.text or (eo.def and (eo.def.text or eo.def.scriptKey)))
      if lid == 88 or name == LevelCaps.NPC_NAME or text == LevelCaps.TEXT_ID then
        local okO, Objects = pcall(require, "src.core.game3.objects")
        if okO and Objects and Objects.freeze and Objects.facePlayer then
          Objects.freeze(88)
          Objects.facePlayer(88, game)
        end
        local session = (game and game.session) or (package.loaded["src.core.game3.field"] and package.loaded["src.core.game3.field"]._session)
        LevelCaps.triggerDialogueGen3(game, mod, session, function()
          if okO and Objects and Objects.unfreeze then Objects.unfreeze(88) end
        end)
        return true
      end
      return next(game, eo)
    end)
  end

  -- Gen 3 field interact wrap
  local okFld, Field = pcall(require, "src.core.game3.field")
  if okFld and Field and Field.interact and not Field._levelCapsInteractWrapped then
    local origInteract = Field.interact
    Field.interact = function(game)
      game = game or Field._game
      local session = (game and game.session) or Field._session
      local curMap = (session and session.map)
      local Map = package.loaded["src.core.game3.map"]
      curMap = curMap or (Map and Map.current)
      if curMap == "FR_VIRIDIAN_CITY" or curMap == "VIRIDIAN_CITY" or curMap == "ViridianCity" then
        local P = package.loaded["src.core.game3.player"]
        if P and not P.moving then
          local fx, fy
          if P.facing == "up" then fx, fy = P.cellX, P.cellY - 1
          elseif P.facing == "down" then fx, fy = P.cellX, P.cellY + 1
          elseif P.facing == "left" then fx, fy = P.cellX - 1, P.cellY
          elseif P.facing == "right" then fx, fy = P.cellX + 1, P.cellY
          end
          if fx == LevelCaps.NPC_VIRIDIAN.x and fy == LevelCaps.NPC_VIRIDIAN.y then
            local okO, Objects = pcall(require, "src.core.game3.objects")
            if okO and Objects and Objects.freeze and Objects.facePlayer then
              Objects.freeze(88)
              Objects.facePlayer(88, game)
            end
            Field.lock()
            LevelCaps.triggerDialogueGen3(game, mod, session, function()
              if okO and Objects and Objects.unfreeze then Objects.unfreeze(88) end
              Field.unlock()
            end)
            return true
          end
        end
      end
      return origInteract(game)
    end
    Field._levelCapsInteractWrapped = true
  end

  -- Gen 3 Experience.apply wrap
  local okExp3, Exp3 = pcall(require, "src.core.game3.battle.experience")
  if okExp3 and Exp3 and not Exp3._levelCapsWrapped then
    local origExpApply = Exp3.apply
    Exp3.apply = function(mon, amount)
      if not LevelCaps.enabled(mod) then
        return origExpApply(mon, amount)
      end
      local save = (mon and mon._session) or LevelCaps._session or currentSave()
      local cap = LevelCaps.capFor(nil, save)
      local curLevel = tonumber(mon and mon.level) or 1
      if curLevel >= cap then
        amount = math.min(amount, 1)
      end
      local res = origExpApply(mon, amount)
      if res and mon then
        if mon.level > cap then
          mon.level = cap
          local okSd, SummaryData = pcall(require, "src.core.game3.summary_data")
          if okSd and SummaryData then
            local growth = Exp3.growthRate(mon)
            mon.exp = SummaryData.expForLevel(growth, cap)
          end
          local okPkmn, Pokemon = pcall(require, "src.core.game3.pokemon")
          if okPkmn and Pokemon and Pokemon.applyStats then
            Pokemon.applyStats(mon)
          end
        elseif mon.level == cap then
          local okSd, SummaryData = pcall(require, "src.core.game3.summary_data")
          if okSd and SummaryData then
            local growth = Exp3.growthRate(mon)
            local nextLevelExp = SummaryData.expForLevel(growth, cap + 1)
            if mon.exp >= nextLevelExp then
              mon.exp = nextLevelExp - 1
            end
          end
        end
        if res.toLevel and res.toLevel > cap then
          res.toLevel = cap
          local filtered = {}
          for _, lv in ipairs(res.levels or {}) do
            if lv <= cap then filtered[#filtered + 1] = lv end
          end
          res.levels = filtered
        end
      end
      return res
    end
    Exp3._levelCapsWrapped = true
  end

  -- Gen 3 ItemUse.useRareCandy wrap
  local okItemUse, ItemUse = pcall(require, "src.core.game3.item_use")
  if okItemUse and ItemUse and not ItemUse._levelCapsWrapped then
    local origRareCandy = ItemUse.useRareCandy
    ItemUse.useRareCandy = function(session, mon)
      if session then LevelCaps._session = session end
      if LevelCaps.enabled(mod) and mon then
        local cap = LevelCaps.capFor(nil, session or currentSave())
        local curLevel = tonumber(mon.level) or 1
        if curLevel >= cap then
          return false, "no_effect", "It won't have any effect."
        end
      end
      return origRareCandy(session, mon)
    end
    ItemUse._levelCapsWrapped = true
  end
end

return LevelCaps
