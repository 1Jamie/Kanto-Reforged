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

local function hasKey(save, key)
  if not save or not key then return false end

  -- 1. Direct save.flags lookup
  if save.flags and save.flags[key] then return true end

  -- 2. Item/Badge lookup in save.inventory or save.player
  if key:find("BADGE", 1, true) then
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

function LevelCaps.capFor(data, save)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then
    return LevelCaps.capForGen2(data, save)
  end
  return LevelCaps.capForGen1(data, save)
end

function LevelCaps.cap(mod, data, save)
  if not LevelCaps.enabled(mod) then return nil end
  return LevelCaps.capFor(data, save)
end

local function currentSave()
  local Game = require("mods.Kanto-Reforged.core.host").liveGame(LevelCaps._mod)
  return Game and Game.save
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
  local speciesDef = data.pokemon[mon.species]
  if not speciesDef then return end
  local nextExp = Growth.expForLevel(speciesDef.growthRate, level + 1)
  if nextExp and mon.exp >= nextExp then
    mon.exp = nextExp - 1
  end
end

-- Top up RARE_CANDY toward a full stack. Returns qty given (0 if none).
function LevelCaps.giveCandyStack(save)
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

function LevelCaps.register(mod)
  LevelCaps._mod = mod
  local Host = require("mods.Kanto-Reforged.core.host")
  local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
  if Host.isGen2() then
    HouseNpcs.appendNpc(mod, "CHERRYGROVE_CITY", LevelCaps.NPC_CHERRYGROVE, "level_caps")
    HouseNpcs.appendNpc(mod, "VIRIDIAN_CITY", LevelCaps.NPC_VIRIDIAN, "level_caps")
    HouseNpcs.bindTalk(mod, "CHERRYGROVE_CITY", {
      [LevelCaps.TEXT_ID] = talkHandler(mod),
    })
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

  local Experience = require("src.battle.Experience")
  if not Experience._expansionLevelCaps then
    local Growth = require("src.pokemon.Growth")
    local original = Experience.apply
    Experience.apply = function(data, mon, defeatedDef, level, isTrainer,
                                  numParticipants, traded)
      local preLevel = mon and mon.level or 0
      local levels, gained = original(data, mon, defeatedDef, level, isTrainer,
                                      numParticipants, traded)
      local m = LevelCaps._mod
      if not m or not LevelCaps.enabled(m) then
        return levels, gained
      end
      local save = currentSave()
      if not save or not mon then return levels, gained end
      local cap = LevelCaps.capFor(data, save)
      local speciesDef = data.pokemon[mon.species]
      if not speciesDef then return levels, gained end

      if preLevel > cap then
        mon.level = preLevel
        pinExpAtLevel(data, mon, preLevel)
        return {}, gained
      end

      if mon.level > cap then
        mon.level = cap
        mon.exp = Growth.expForLevel(speciesDef.growthRate, cap)
        local kept = {}
        for _, lv in ipairs(levels) do
          if lv <= cap then kept[#kept + 1] = lv end
        end
        levels = kept
      elseif mon.level == cap then
        pinExpAtLevel(data, mon, cap)
      end
      return levels, gained
    end
    Experience._expansionLevelCaps = true
  end

  local ItemEffects = require("src.inventory.ItemEffects")
  if not ItemEffects._expansionLevelCaps then
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
end

return LevelCaps
