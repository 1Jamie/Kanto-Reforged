-- DIY roaming legendaries: beasts + Eon duo.

local KantoGraph = require("mods.Kanto-Reforged.core.kanto_graph")
local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
local Strings = require("src.core.Strings")

local Roamers = {}
Roamers.OWNER = "roamers"

Roamers.BEASTS = { "RAIKOU", "ENTEI", "SUICUNE" }
Roamers.EONS = { "LATIAS", "LATIOS" }

local function state(mod)
  local s = mod.save:get("roamers", nil)
  if type(s) ~= "table" then
    s = { active = {}, locations = {}, beaten = {} }
    mod.save:set("roamers", s)
  end
  s.active = s.active or {}
  s.locations = s.locations or {}
  s.beaten = s.beaten or {}
  return s
end

function Roamers.getLocation(mod, species)
  local s = state(mod)
  if s.beaten[species] or not s.active[species] then return nil end
  return s.locations[species]
end

function Roamers.isActive(mod, species)
  local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
  if SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO then
    return false
  end
  local s = state(mod)
  return s.active[species] and not s.beaten[species]
end

function Roamers.activateBeasts(mod)
  local s = state(mod)
  for _, id in ipairs(Roamers.BEASTS) do
    if not s.beaten[id] then
      s.active[id] = true
      s.locations[id] = KantoGraph.randomGrass()
    end
  end
  mod.save:set("roamers", s)
  mod.save:set("roamers_beasts_on", true)
end

function Roamers.activateEons(mod)
  local s = state(mod)
  for _, id in ipairs(Roamers.EONS) do
    if not s.beaten[id] then
      s.active[id] = true
      s.locations[id] = KantoGraph.randomGrass()
    end
  end
  mod.save:set("roamers", s)
  mod.save:set("roamers_eons_on", true)
end

local function migrateAdjacent(mod)
  local s = state(mod)
  for id, on in pairs(s.active) do
    if on and not s.beaten[id] then
      local cur = s.locations[id]
      s.locations[id] = KantoGraph.randomNeighbor(cur)
    end
  end
  mod.save:set("roamers", s)
end

local function migrateFull(mod)
  local s = state(mod)
  for id, on in pairs(s.active) do
    if on and not s.beaten[id] then
      s.locations[id] = KantoGraph.randomGrass()
    end
  end
  mod.save:set("roamers", s)
end

local function roamerOnMap(mod, mapId)
  local s = state(mod)
  local found = {}
  for id, on in pairs(s.active) do
    if on and not s.beaten[id] and s.locations[id] == mapId then
      found[#found + 1] = id
    end
  end
  return found
end

function Roamers.register(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then return end
  local isG3 = Host.isGen3()
  local mansionMap = isG3 and "FR_CELADON_CITY_CONDOMINIUMS_2F" or "CELADON_MANSION_2F"

  HouseNpcs.appendNpc(mod, mansionMap, {
    index = 2,
    name = "CELADONMANSION2F_BEAST_TRACKER",
    sprite = "SPRITE_SUPER_NERD",
    graphicsId = 89,
    text = "TEXT_CELADONMANSION2F_BEAST_TRACKER",
    -- SW of the meeting room so the east stair hall stays clear.
    x = 1, y = 8,
    gen3X = 1, gen3Y = 8,
  }, Roamers.OWNER)

  if mod and mod.content and mod.content.items and mod.content.items.register then
    mod.content.items:register("ROAMING_RADAR", {
      id = "ROAMING_RADAR", name = "ROAMING RADAR", price = 0,
      keyItem = true, tossable = false,
    })
  end

  local trackerTalk = function(game, ow, npc, done)
    local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
    if SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO then
      HouseNpcs.pushText(game, Strings(
        "Beasts? On a KANTO-\nonly DEX?\f"
          .. "Switch to NATIONAL\nif you want them."), done)
      return
    end
    local save = (game and game.save) or (game and game.session) or {}
    local flags = save.flags or {}
    local silph = flags.EVENT_BEAT_SILPH_CO_GIOVANNI
      or flags.EVENT_GOT_MASTER_BALL
      or (save.inventory and save.inventory.MASTER_BALL)
      -- FRLG: FLAG_HIDE_SILPH_ROCKETS = 0x53 (0x825 is Marsh Badge, not Silph).
      or (Host.isGen3() and (flags[0x53] or flags.FLAG_HIDE_SILPH_ROCKETS))
    if not silph and not mod.save:get("roamers_beasts_on", false) then
      HouseNpcs.pushText(game, Strings(
        "Strange beasts are\nstirring...\f"
          .. "Come back after\nSILPH CO."), done)
      return
    end
    if not mod.save:get("got_roaming_radar", false) then
      HouseNpcs.giveItem(game, "ROAMING_RADAR", 1)
      mod.save:set("got_roaming_radar", true)
      Roamers.activateBeasts(mod)
      HouseNpcs.pushText(game, Strings(
        "Take this ROAMING\nRADAR!\f"
          .. "RAIKOU, ENTEI, and\nSUICUNE roam Kanto."), done)
    else
      HouseNpcs.pushText(game, Strings(
        "Check the RADAR\nfrom the bag.\f"
          .. "Fly reshuffles them."), done)
    end
  end

  if Host.isGen1() then
    mod.content.map_scripts:register("CELADON_MANSION_2F", {
      talk = {
        TEXT_CELADONMANSION2F_BEAST_TRACKER = trackerTalk,
      },
    })
  end
  HouseNpcs.bindTalk(mod, mansionMap, {
    TEXT_CELADONMANSION2F_BEAST_TRACKER = trackerTalk,
  })

  -- Eon watcher at Indigo lobby
  local indigoMap = isG3 and "FR_INDIGO_PLATEAU_POKEMON_CENTER_1F" or "INDIGO_PLATEAU_LOBBY"
  HouseNpcs.appendNpc(mod, indigoMap, {
    index = 6,
    name = "INDIGOPLATEAULOBBY_EON_WATCHER",
    sprite = "SPRITE_GIRL",
    graphicsId = 23,
    text = "TEXT_INDIGOPLATEAULOBBY_EON_WATCHER",
    -- Gen1 (10,6) is solid wall on FRLG Indigo PC; open lobby floor west of desk.
    x = isG3 and 8 or 10,
    y = isG3 and 9 or 6,
    gen3X = 8, gen3Y = 9,
  }, Roamers.OWNER)

  local eonTalk = function(game, ow, npc, done)
    local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
    if SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO then
      HouseNpcs.pushText(game, Strings(
        "Eon POKéMON skip\nKANTO-scope trainers.\f"
          .. "Try NATIONAL if you\nwant a chase."), done)
      return
    end
    local save = (game and game.save) or (game and game.session) or {}
    local flags = save.flags or {}
    local champ = flags.EVENT_BEAT_CHAMPION_RIVAL
      or (Host.isGen3() and (flags[0x82c] or flags.FLAG_SYS_GAME_CLEAR))
    if not champ then
      HouseNpcs.pushText(game, Strings(
        "Eon POKéMON appear\nafter the CHAMPION."), done)
      return
    end
    if not mod.save:get("roamers_eons_on", false) then
      Roamers.activateEons(mod)
      HouseNpcs.pushText(game, Strings(
        "LATIAS and LATIOS\nare roaming!\f"
          .. "Your RADAR sees\nthem too."), done)
    else
      HouseNpcs.pushText(game, Strings("Keep hunting."), done)
    end
  end

  if Host.isGen1() then
    mod.content.map_scripts:register("INDIGO_PLATEAU_LOBBY", {
      talk = {
        TEXT_INDIGOPLATEAULOBBY_EON_WATCHER = eonTalk,
      },
    })
  end
  HouseNpcs.bindTalk(mod, indigoMap, {
    TEXT_INDIGOPLATEAULOBBY_EON_WATCHER = eonTalk,
  })
end

function Roamers.install(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then return end
  Roamers._mod = mod
  mod.events:on("game.ready", function(ev)
    if ev and ev.game and ev.game.data then
      KantoGraph.build(ev.game.data)
    end
  end)
  mod.events:on("mods.loaded", function()
    local game = Host.liveGame(mod)
    if game and game.data then KantoGraph.build(game.data) end
  end)

  -- Foot vs fly migration
  mod.events:on("player.warped", function(ev)
    if not ev then return end
    local reason = ev.reason or ev.kind or ""
    local fly = reason == "fly" or reason == "teleport" or reason == "blackout"
      or ev.fly or ev.teleport or ev.blackout
    if fly then
      migrateFull(mod)
    elseif ev.fromMap and ev.toMap and ev.fromMap ~= ev.toMap then
      -- connection / foot transition between maps
      if not tostring(ev.toMap):find("POKECENTER", 1, true)
          and not tostring(ev.toMap):find("HOUSE", 1, true) then
        migrateAdjacent(mod)
      end
    end
  end)

  -- Field cry cue
  mod.events:on("map.entered", function(ev)
    if not ev or not ev.mapId then return end
    local found = roamerOnMap(mod, ev.mapId)
    if #found == 0 then return end
    local Sound = require("src.core.Sound")
    local game = ev.game or Host.liveGame(mod)
    if game and game.data then
      Sound.playCry(game.data, found[1])
    end
  end)

  -- Inject via encounter.species AFTER roll so we can force a roamer
  -- (Repel still sees high level). Prefer species hook so vanilla roll RNG
  -- is preserved when no roamer.
  mod.hooks:wrap("encounter.species", function(next, enc, ctx)
    local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
    if SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO then
      return next(enc, ctx)
    end
    local mapId = ctx and ctx.mapId
    if mapId then
      local found = roamerOnMap(mod, mapId)
      if #found > 0 and love.math.random() < 0.15 then
        local species = found[love.math.random(1, #found)]
        local game = Host.liveGame(mod)
        local ace = 50
        if game then ace = math.max(50, HouseNpcs.scaleCap(mod, game) - 2) end
        return { species = species, level = ace }
      end
    end
    return next(enc, ctx)
  end)

  -- Mark beaten / migrate on flee
  mod.events:on("battle.started", function(ev)
    if not ev or not ev.battle or ev.battle.kind ~= "wild" then return end
    local enemy = ev.battle.enemy and ev.battle.enemy.mon
    if not enemy or not enemy.species then return end
    local s = state(mod)
    if s.active and s.active[enemy.species] then
      ev.battle.expRoamer = true
      ev.battle.expWildSpecies = enemy.species
    end
  end)

  mod.events:on("battle.ended", function(ev)
    if not ev or not ev.battle or ev.battle.kind ~= "wild" then return end
    local enemy = ev.battle.enemy and ev.battle.enemy.mon
    if not enemy then return end
    local s = state(mod)
    if not s.active[enemy.species] then return end
    if ev.result == "caught" or ev.result == "win" then
      s.beaten[enemy.species] = true
      s.active[enemy.species] = false
      mod.save:set("roamers", s)
    elseif ev.result == "run" then
      s.locations[enemy.species] = KantoGraph.randomNeighbor(s.locations[enemy.species])
      mod.save:set("roamers", s)
    end
  end)
end

return Roamers
