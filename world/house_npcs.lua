-- Shared helpers for Kanto Reforged house NPCs / object index hygiene.

local LevelCaps = require("mods.Kanto-Reforged.ui.level_caps")
local Strings = require("src.core.Strings")

local HouseNpcs = {}

-- Gen1 sprite ids that do not exist on Gold; remap when Host is Gen2.
HouseNpcs.SPRITE_GEN2 = {
  SPRITE_GIRL = "SPRITE_LASS",
  SPRITE_BRUNETTE_GIRL = "SPRITE_TEACHER",
  SPRITE_HIKER = "SPRITE_POKEFAN_M",
  SPRITE_CHANNELER = "SPRITE_GRANNY",
}

-- Talk handlers keyed by TEXT_* (Gen2 only; Gen1 uses map_scripts).
HouseNpcs._talks = {}
HouseNpcs._talkInstalled = false
-- Optional Gen2 trainer class defs for scripted club fights.
HouseNpcs._trainerDefs = {}

-- Reserved object indices claimed by existing Kanto Reforged modules.
-- New modules MUST register via claim() and never collide.
HouseNpcs.BASELINE_CLAIMS = {
  { map = "VIRIDIAN_CITY", index = 8, owner = "level_caps" },
  { map = "CHERRYGROVE_CITY", index = 8, owner = "level_caps" },
  { map = "CELADON_CITY", index = 10, owner = "overworld_loot" },
  { map = "LAVENDER_TOWN", index = 4, owner = "overworld_loot" },
  { map = "SAFFRON_CITY", index = 16, owner = "overworld_loot" },
  { map = "POWER_PLANT", index = 15, owner = "overworld_loot" },
  { map = "ROCK_TUNNEL_B1F", index = 9, owner = "overworld_loot" },
  { map = "POKEMON_TOWER_7F", index = 5, owner = "overworld_loot" },
  { map = "DAYCARE", index = 1, owner = "daycare" },
  { map = "DAYCARE", index = 2, owner = "daycare" },
  { map = "BERRY_FARM", index = 1, owner = "berry_farm" },
  { map = "BERRY_FARM", index = 2, owner = "berry_farm" },
  { map = "BERRY_FARM", index = 4, owner = "berry_farm" },
  { map = "BERRY_FARM", index = 5, owner = "berry_quests" },
}

HouseNpcs._claims = {}
HouseNpcs._gen3Injections = {}

HouseNpcs.GEN3_MAP_ALIASES = {
  CELADON_MANSION_1F = { "FR_CELADON_CITY_CONDOMINIUMS_1F", "CeladonCity_Condominiums_1F" },
  CELADON_MANSION_2F = { "FR_CELADON_CITY_CONDOMINIUMS_2F", "CeladonCity_Condominiums_2F" },
  CELADON_MANSION_3F = { "FR_CELADON_CITY_CONDOMINIUMS_3F", "CeladonCity_Condominiums_3F" },
  CELADON_MANSION_ROOF = { "FR_CELADON_CITY_CONDOMINIUMS_ROOF", "CeladonCity_Condominiums_Roof" },
  CELADON_MANSION_ROOF_HOUSE = { "FR_CELADON_CITY_CONDOMINIUMS_ROOF_ROOM", "CeladonCity_Condominiums_RoofRoom" },
  UNDERGROUND_PATH_ROUTE_5 = { "FR_UNDERGROUND_PATH_NORTH_ENTRANCE", "UndergroundPath_NorthEntrance" },
  UNDERGROUND_PATH_ROUTE_6 = { "FR_UNDERGROUND_PATH_SOUTH_ENTRANCE", "UndergroundPath_SouthEntrance" },
  UNDERGROUND_PATH_ROUTE_7 = { "FR_UNDERGROUND_PATH_WEST_ENTRANCE", "UndergroundPath_WestEntrance" },
  UNDERGROUND_PATH_ROUTE_8 = { "FR_UNDERGROUND_PATH_EAST_ENTRANCE", "UndergroundPath_EastEntrance" },
  UNDERGROUND_PATH = { "FR_UNDERGROUND_PATH_NORTH_ENTRANCE", "UndergroundPath_NorthEntrance" },
  CELADON_HOTEL = { "FR_CELADON_CITY_HOTEL", "CeladonCity_Hotel" },
  VERMILION_PIDGEY_HOUSE = { "FR_VERMILION_CITY_HOUSE1", "VermilionCity_House1" },
  CINNABAR_LAB_METRONOME_ROOM = { "FR_CINNABAR_ISLAND_POKEMON_LAB_RESEARCH_ROOM", "CinnabarIsland_PokemonLab_ResearchRoom" },
  VIRIDIAN_CITY = { "FR_VIRIDIAN_CITY", "ViridianCity" },
  SAFFRON_PIDGEY_HOUSE = { "FR_SAFFRON_CITY_MR_PSYCHICS_HOUSE", "SaffronCity_MrPsychicsHouse" },
  MR_PSYCHICS_HOUSE = { "FR_SAFFRON_CITY_MR_PSYCHICS_HOUSE", "SaffronCity_MrPsychicsHouse" },
  ROUTE_2_TRADE_HOUSE = { "FR_ROUTE2_HOUSE", "Route2_House" },
  FUCHSIA_BILLS_GRANDPAS_HOUSE = { "FR_FUCHSIA_CITY_HOUSE1", "FuchsiaCity_House1" },
}

HouseNpcs.SPRITE_GEN3_GFX = {
  SPRITE_SCIENTIST = 55,
  SPRITE_HIKER = 56,
  SPRITE_SUPER_NERD = 89,
  SPRITE_BEAUTY = 29,
  SPRITE_YOUNGSTER = 18,
  SPRITE_LASS = 17,
  SPRITE_GIRL = 23,
  SPRITE_BRUNETTE_GIRL = 23,
  SPRITE_GRAMPS = 61,
  SPRITE_POKEFAN_M = 30,
  SPRITE_FISHER = 57,
  SPRITE_BLACK_BELT = 54,
  SPRITE_GENTLEMAN = 61,
  SPRITE_SAILOR = 62,
  SPRITE_NURSE = 64,
  SPRITE_CLERK = 68,
  SPRITE_POKE_BALL = 92,
  SPRITE_BIRD = 92,
}

local function key(map, index)
  return map .. "#" .. tostring(index)
end

function HouseNpcs.resetClaims()
  HouseNpcs._claims = {}
  for _, row in ipairs(HouseNpcs.BASELINE_CLAIMS) do
    HouseNpcs._claims[key(row.map, row.index)] = row.owner
  end
end

function HouseNpcs.resetInjections()
  HouseNpcs._gen3Injections = {}
end

function HouseNpcs.claim(map, index, owner)
  local k = key(map, index)
  local prev = HouseNpcs._claims[k]
  if prev and prev ~= owner then
    error(string.format("object index collision: %s index %s claimed by %s and %s",
      map, tostring(index), prev, owner))
  end
  HouseNpcs._claims[k] = owner
end

function HouseNpcs.claims()
  return HouseNpcs._claims
end

function HouseNpcs.spriteFor(sprite)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() and sprite and HouseNpcs.SPRITE_GEN2[sprite] then
    return HouseNpcs.SPRITE_GEN2[sprite]
  end
  return sprite
end

-- Gold SPRITEMOVEDATA standing bytes (Npc.lua MOVE.STANDING_*).
local GEN2_STAND = { UP = 7, DOWN = 6, LEFT = 8, RIGHT = 9 }

function HouseNpcs.npcObject(row)
  local Host = require("mods.Kanto-Reforged.core.host")
  local obj = {
    index = row.index,
    name = row.name,
    sprite = HouseNpcs.spriteFor(row.sprite),
    movement = row.movement or "STAY",
    range = row.range or "DOWN",
    text = row.text,
    x = row.x,
    y = row.y,
    trainerClass = row.trainerClass,
    trainerParty = row.trainerParty,
    pokemon = row.pokemon,
    level = row.level,
    item = row.item,
  }
  if Host.isGen2() then
    -- Gold rebuildPeople / pooledNpc: always-visible, standing, keep TEXT_*.
    obj.eventFlag = row.eventFlag or 0xFFFF
    obj.hours = row.hours or { -1, -1 }
    obj.type = row.type or 0
    obj.radius = row.radius or { x = 0, y = 0 }
    if type(obj.movement) ~= "number" then
      obj.movement = GEN2_STAND[obj.range] or GEN2_STAND.DOWN
    end
  end
  return obj
end

function HouseNpcs.installGen3Hook(mod)
  if HouseNpcs._gen3HookInstalled then return end
  HouseNpcs._gen3HookInstalled = true

  pcall(function()
    local okObj, Objects = pcall(require, "src.core.game3.objects")
    if okObj and Objects and Objects.loadMap then
      local origLoad = Objects.loadMap
      Objects.loadMap = function(game, mapId, def)
        HouseNpcs.injectGen3(mapId, def)
        return origLoad(game, mapId, def)
      end
    end
  end)

  if mod and mod.events and mod.events.on then
    mod.events:on("map.entered", function(ev)
      if ev and ev.mapId then
        HouseNpcs.injectGen3(ev.mapId)
      end
    end)
  end
end

function HouseNpcs.injectGen3(mapId, def)
  if not mapId then return end
  local okSp, Space = pcall(require, "src.core.game3.scripting.space")
  if okSp and Space and not Space.bundle and Space.ensureBundle then
    pcall(Space.ensureBundle)
  end

  local okC, MapCatalog = pcall(require, "src.import.gba.map_catalog")
  local engineId = okC and MapCatalog and MapCatalog.pretToEngine and MapCatalog.pretToEngine(mapId)

  local ev = okSp and Space and Space.bundle and Space.bundle.events
    and (Space.bundle.events[mapId] or (engineId and Space.bundle.events[engineId]))
  local evObjs = ev and (ev.objects or ev.objectEvents)

  local toInject = {}
  local seen = {}
  local function addList(list)
    for _, obj in ipairs(list or {}) do
      local k = tostring(obj.localId) .. "@" .. tostring(obj.x) .. "," .. tostring(obj.y)
      if not seen[k] then
        seen[k] = true
        toInject[#toInject + 1] = obj
      end
    end
  end

  addList(HouseNpcs._gen3Injections[mapId])
  if engineId and engineId ~= mapId then
    addList(HouseNpcs._gen3Injections[engineId])
  end
  if mapId:find("^FR_") then
    addList(HouseNpcs._gen3Injections[mapId:gsub("^FR_", "")])
  else
    addList(HouseNpcs._gen3Injections["FR_" .. mapId])
  end
  for origMap, aliases in pairs(HouseNpcs.GEN3_MAP_ALIASES) do
    for _, a in ipairs(aliases) do
      if a == mapId or (engineId and a == engineId) then
        addList(HouseNpcs._gen3Injections[origMap])
        break
      end
    end
  end

  if #toInject == 0 then return end

  for _, custom in ipairs(toInject) do
    if evObjs then
      local exists = false
      for _, o in ipairs(evObjs) do
        if o.localId == custom.localId or (o.x == custom.x and o.y == custom.y) then
          exists = true
          break
        end
      end
      if not exists then
        table.insert(evObjs, custom)
      end
    end
    if def then
      def.objects = def.objects or {}
      local exists = false
      for _, o in ipairs(def.objects) do
        if o.localId == custom.localId or (o.x == custom.x and o.y == custom.y) then
          exists = true
          break
        end
      end
      if not exists then
        table.insert(def.objects, custom)
      end
    end
  end
end

function HouseNpcs.appendNpc(mod, mapId, row, owner)
  HouseNpcs.claim(mapId, row.index, owner or row.name or "house_npcs")
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen3() then
    mod.content.maps:patch(mapId, {
      objects = { __append = { HouseNpcs.npcObject(row) } },
    })
  end

  -- Register for Gen 3 injection
  local targetKeys = {}
  targetKeys[mapId] = true
  if HouseNpcs.GEN3_MAP_ALIASES[mapId] then
    for _, a in ipairs(HouseNpcs.GEN3_MAP_ALIASES[mapId]) do
      targetKeys[a] = true
    end
  end
  if mapId:find("^FR_") then
    targetKeys[mapId:gsub("^FR_", "")] = true
  else
    targetKeys["FR_" .. mapId] = true
  end

  local g3X = row.gen3X or (row.gen3Pos and row.gen3Pos.x) or row.x
  local g3Y = row.gen3Y or (row.gen3Pos and row.gen3Pos.y) or row.y
  local gfx = row.graphicsId or row.graphics or HouseNpcs.SPRITE_GEN3_GFX[row.sprite] or 18

  for tKey in pairs(targetKeys) do
    local g3Obj = {
      localId = row.localId or (80 + (row.index or 1)),
      graphicsId = gfx,
      graphics = gfx,
      movementType = row.movementType or 8,
      movement = row.movement or "STAY",
      range = row.range or "DOWN",
      scriptKey = row.scriptKey or row.text or row.name,
      text = row.text or row.scriptKey or row.name,
      elevation = row.elevation or 3,
      x = g3X,
      y = g3Y,
      name = row.name,
      sprite = row.sprite,
    }
    HouseNpcs._gen3Injections[tKey] = HouseNpcs._gen3Injections[tKey] or {}
    table.insert(HouseNpcs._gen3Injections[tKey], g3Obj)
  end

  pcall(function()
    local okSp, Space = pcall(require, "src.core.game3.scripting.space")
    if okSp and Space and Space.bundle and Space.bundle.events then
      for tKey in pairs(targetKeys) do
        HouseNpcs.injectGen3(tKey)
      end
    end
  end)

  HouseNpcs.installGen3Hook(mod)
end

-- Next free object index for a map. Prefer `preferred` when it does not collide
-- with stock ROM objects (Gold/Silver/Crystal may differ). Falls back to
-- max(preferred, stockCount+1).
function HouseNpcs.nextFreeIndex(mod, mapId, preferred)
  preferred = tonumber(preferred) or 1
  local Host = require("mods.Kanto-Reforged.core.host")
  local game = Host.liveGame(mod)
  local maps = game and game.data and game.data.maps
  if type(maps) ~= "table" then
    local okM, mapsMod = pcall(require, "data.generated.maps")
    if okM and type(mapsMod) == "table" then maps = mapsMod end
  end
  local def = maps and maps[mapId]
  local objs = def and def.objects
  local stock = 0
  if type(objs) == "table" then
    local maxIdx = 0
    local count = 0
    for _, obj in ipairs(objs) do
      count = count + 1
      local idx = obj and tonumber(obj.index)
      if idx and idx > maxIdx then maxIdx = idx end
    end
    stock = math.max(count, maxIdx)
  end
  return math.max(preferred, stock + 1)
end

-- Register TEXT_* talk handlers. Gen1 → map_scripts; Gen2 → talkTo seam.
-- Register TEXT_* talk handlers. Gen1 → map_scripts; Gen2/Gen3 → talk dispatch.
function HouseNpcs.registerTalk(textId, handler)
  HouseNpcs._talks[textId] = handler
end

function HouseNpcs.bindTalk(mod, mapId, talkTable)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen1() then
    mod.content.map_scripts:register(mapId, { talk = talkTable })
  end
  for textId, fn in pairs(talkTable or {}) do
    HouseNpcs.registerTalk(textId, fn)
  end
end

-- Wrap OverworldController.talkTo (Gen2) and world.talk hook (Gen3) so TEXT_* handlers fire.
function HouseNpcs.installTalkDispatch(mod)
  if HouseNpcs._talkInstalled then return end
  HouseNpcs._talkInstalled = true
  local Host = require("mods.Kanto-Reforged.core.host")

  if Host.isGen2() then
    local okOC, OC = pcall(require, "src.world.OverworldController")
    if okOC and OC then
      local prev = OC.talkTo
      OC.talkTo = function(world, npc)
        local d = npc and npc.def
        local key = d and (d.text or d.name)
        local fn = key and HouseNpcs._talks[key]
        if fn then
          local game = (world and world.game) or Host.liveGame(mod)
          fn(game, world, npc, function() end)
          return true
        end
        if type(prev) == "function" then
          return prev(world, npc)
        end
        return false
      end
    end
  end

  if mod and mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("world.talk", function(next, game, eo)
      local d = eo and eo.def
      local key = (d and (d.scriptKey or d.text or d.name)) or (eo and (eo.text or eo.name))
      local fn = key and HouseNpcs._talks[key]
      if fn then
        local lid = eo and (eo.localId or (eo.def and eo.def.localId))
        local okObj, Objects = pcall(require, "src.core.game3.objects")
        if lid and okObj and Objects then
          if Objects.freeze then pcall(Objects.freeze, lid) end
          if Objects.facePlayer then pcall(Objects.facePlayer, lid, game) end
        end
        local finished = false
        local function finish()
          if finished then return end
          finished = true
          if lid and okObj and Objects and Objects.unfreeze then
            pcall(Objects.unfreeze, lid)
          end
        end
        fn(game, nil, eo, finish)
        return true
      end
      return next(game, eo)
    end)
  end
  if mod and mod.log then
    mod.log:info("House NPC talk dispatch installed")
  end
end

-- Badge check: Gen1 inventory *BADGE; Gold kantoBadges / Johto badges; Gen3 flags / badges.
function HouseNpcs.hasBadge(save, badge)
  if not save or not badge then return false end
  if save.inventory and (save.inventory[badge] or 0) > 0 then
    return true
  end
  local p = save.player
  if p then
    local short = tostring(badge):gsub("BADGE$", "")
    if p.kantoBadges and p.kantoBadges[short] then
      return true
    end
    if p.badges and (p.badges[badge] or p.badges[short]) then
      return true
    end
  end
  if save.badges and (save.badges[badge] or (type(badge) == "string" and save.badges[badge:gsub("BADGE$", "")])) then
    return true
  end
  -- Gen 3 flags lookup
  local okF, Flags = pcall(require, "src.core.game3.scripting.flags")
  if okF and Flags and Flags.badgeInfo then
    local info = Flags.badgeInfo(badge)
    if info and info.flag then
      local store = save.flags or save
      if type(store) == "table" and (store[info.flag] or store[string.format("FLAG_BADGE0%d_GET", info.num)]) then
        return true
      end
      if Flags.hasBadge and Flags.hasBadge(store, badge) then
        return true
      end
    end
  end
  return false
end

function HouseNpcs.pushText(game, msg, done)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local okM, Message = pcall(require, "src.ui.game3.message")
    if okM and Message and Message.show then
      Message.show(msg, done)
      return
    end
  end
  if not (game and game.stack and game.stack.push) then
    if done then done() end
    return
  end
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, msg, done))
end

function HouseNpcs.ask(game, msg, onChoice)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
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
  end
  if not (game and game.stack and game.stack.push) then
    if onChoice then onChoice(false) end
    return
  end
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, msg, nil, { choice = onChoice }))
end

-- Script commands (trade, show_text, …) yield on ctx.runner. Lua talk
-- handlers are not a ScriptRunner tick, so call this instead of Commands.*.
function HouseNpcs.runScript(ow, rows, extra)
  extra = extra or {}
  if ow and ow.runner and type(ow.runner.run) == "function" then
    ow.runner:run(rows, extra)
    return true
  end
  return false
end

-- Story soft-cap from milestone table (even when hard caps are off).
-- On Gold, LevelCaps is not installed — use party level (floor 20).
function HouseNpcs.softCap(mod, game)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then
    return math.max(20, HouseNpcs.highestPartyLevel(game))
  end
  local save = game and game.save
  local data = game and game.data
  if not save or not data then return 20 end
  return LevelCaps.capFor(data, save) or 20
end

function HouseNpcs.getParty(game)
  local party = (game and game.save and game.save.party)
    or (game and game.session and game.session.party)
  if not party then
    local Runtime = package.loaded["src.core.game3.runtime"]
    local s = Runtime and Runtime.getSession and Runtime.getSession()
    party = s and s.party
  end
  return party or {}
end

local function resolveScaleGame(game, mod)
  return game
      or HouseNpcs._scaleGame
      or (mod and require("mods.Kanto-Reforged.core.host").liveGame(mod))
end

-- Highest usable party level (skips eggs / empty slots). Not lead-only.
function HouseNpcs.highestPartyLevel(game)
  game = resolveScaleGame(game, nil)
  local Breeding = require("mods.Kanto-Reforged.pokemon.breeding")
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  local party = HouseNpcs.getParty(game)
  local best = 0
  for _, mon in ipairs(party) do
    local isEgg = Breeding.isEgg(mon) or (okP and Pokemon and Pokemon.isEgg and Pokemon.isEgg(mon))
    if mon and (mon.species or mon.speciesId) and not isEgg then
      local lv = tonumber(mon.level or mon.lvl) or 0
      if lv > best then best = lv end
    end
  end
  return best
end

-- Club / specialist / rematch bracket:
--   Level caps ON  → story soft-cap (competitive on-cap fights).
--                    If post-game (soft-cap >= 100), scale to party.
--   Level caps OFF → party's highest level (floor 20, ceiling 100).
function HouseNpcs.scaleCap(mod, game)
  game = resolveScaleGame(game, mod)
  local partyHigh = HouseNpcs.highestPartyLevel(game)
  local capsOn = LevelCaps.enabled(mod)

  if capsOn then
    local soft = HouseNpcs.softCap(mod, game)
    if soft >= 100 and partyHigh > 0 then
      return math.min(100, math.max(20, partyHigh))
    end
    return soft
  end

  if partyHigh > 0 then
    return math.min(100, math.max(20, partyHigh))
  end
  return HouseNpcs.softCap(mod, game)
end

function HouseNpcs.partyHasType(game, typeId)
  local party = HouseNpcs.getParty(game)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
    if okP and Pokemon and Pokemon.types then
      local TypeNames = {
        [0] = "NORMAL", [1] = "FIGHTING", [2] = "FLYING", [3] = "POISON", [4] = "GROUND",
        [5] = "ROCK", [6] = "BUG", [7] = "GHOST", [8] = "STEEL", [9] = "MYSTERY",
        [10] = "FIRE", [11] = "WATER", [12] = "GRASS", [13] = "ELECTRIC", [14] = "PSYCHIC",
        [15] = "ICE", [16] = "DRAGON", [17] = "DARK"
      }
      for _, mon in ipairs(party) do
        local sp = mon and (mon.species or mon.speciesId)
        if sp then
          local t1, t2 = Pokemon.types(sp)
          if TypeNames[t1] == typeId or TypeNames[t2] == typeId then return true end
        end
      end
    end
  end
  local pokemon = game and game.data and game.data.pokemon or {}
  for _, mon in ipairs(party) do
    if mon and mon.species then
      local def = pokemon[mon.species]
      local types = def and (def.types or { def.type1, def.type2 }) or {}
      for _, t in ipairs(types) do
        if t == typeId then return true end
      end
      if def and (def.type1 == typeId or def.type2 == typeId) then
        return true
      end
    end
  end
  return false
end

function HouseNpcs.leadHoldsBerry(game)
  local HeldItems = require("mods.Kanto-Reforged.items.held_items")
  local party = HouseNpcs.getParty(game)
  local lead = party[1]
  if not lead then return false end
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local item = lead.heldItem or lead.item
    local okB, Berry = pcall(require, "src.core.game3.berry")
    if okB and Berry and Berry.isBerry and item then
      return Berry.isBerry(item)
    end
  end
  return HeldItems.isBerry(HeldItems.get(lead))
end

function HouseNpcs.giveItem(game, itemId, qty)
  if not game then return false end
  local save = game.save or game.session
  if not save then
    local Runtime = package.loaded["src.core.game3.runtime"]
    save = Runtime and Runtime.getSession and Runtime.getSession()
  end
  if not save then return false end
  -- Keep game.save filled so downstream Gen3 bag helpers stay consistent.
  if not game.save then game.save = save end
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local BerryFarmGame3 = require("mods.Kanto-Reforged.world.berry_farm_game3")
    return BerryFarmGame3.bagAddItem(save, itemId, qty or 1)
  end
  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if okBag and Bag and Bag.add then
    local res = Bag.add(save, itemId, qty or 1)
    if res then return true end
  end
  local BerryFarmGame3 = require("mods.Kanto-Reforged.world.berry_farm_game3")
  return BerryFarmGame3.bagAddItem(save, itemId, qty or 1)
end

function HouseNpcs.scaleParty(party, aceLevel)
  local out = {}
  for i, slot in ipairs(party or {}) do
    local delta = (i == #party) and 0 or math.min(5, (#party - i) + 1)
    local lv = math.max(2, (aceLevel or slot.level or 10) - delta)
    out[i] = {
      species = slot.species,
      level = lv,
      moves = slot.moves,
    }
  end
  return out
end

function HouseNpcs.registerTrainerDef(oppClass, def)
  HouseNpcs._trainerDefs[oppClass] = def
end

local function partyRowsFor(oppClass, partyIndex)
  local def = HouseNpcs._trainerDefs[oppClass]
  if not def then return nil, nil end
  local rows = def.parties and def.parties[partyIndex or 1]
  return rows, def
end

local function startTrainerBattleGen2(game, ow, oppClass, partyIndex, onDone)
  local rows, def = partyRowsFor(oppClass, partyIndex)
  if not rows then
    error("no Gen2 trainer def for " .. tostring(oppClass))
  end
  HouseNpcs._scaleGame = game
  local ace = HouseNpcs.scaleCap(nil, game)
  HouseNpcs._scaleGame = nil
  local scaled = HouseNpcs.scaleParty(rows, ace)
  local Mon = require("src.battle.gen2.Mon")
  local party = {}
  for _, slot in ipairs(scaled) do
    local mon = Mon.new(game.data, slot.species, slot.level)
    if mon then party[#party + 1] = mon end
  end
  local world = ow
  if not (world and world.startBattle) then
    world = game and game.world
  end
  if not (world and world.startBattle) then
    error("World:startBattle unavailable")
  end
  world:startBattle({
    trainer = {
      name = def.name or "TRAINER",
      className = def.name or "TRAINER",
      party = party,
      -- Club payouts are handled in talk callbacks; avoid double money.
      baseMoney = 0,
    },
  }, function(outcome)
    if onDone then onDone(outcome == "lose" and "lose" or "win") end
  end)
end

local function startTrainerBattleGen3(game, ow, oppClass, partyIndex, onDone)
  local rows, def = partyRowsFor(oppClass, partyIndex)
  if not rows then
    error("no trainer def for " .. tostring(oppClass))
  end
  HouseNpcs._scaleGame = game
  local ace = HouseNpcs.scaleCap(nil, game)
  HouseNpcs._scaleGame = nil
  local scaled = HouseNpcs.scaleParty(rows, ace)

  local party = {}
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  for _, slot in ipairs(scaled) do
    local sp = slot.species
    if type(sp) == "string" and okP and Pokemon and Pokemon.speciesFromName then
      sp = Pokemon.speciesFromName(sp) or sp
    end
    party[#party + 1] = {
      species = sp,
      level = slot.level,
      moves = slot.moves,
      ivs = { hp = 15, atk = 15, def = 15, spe = 15, spa = 15, spd = 15 },
      evs = { hp = 0, atk = 0, def = 0, spe = 0, spa = 0, spd = 0 },
    }
  end

  local lead = party[1] or {}
  local trainerPic = 23 -- Hiker sprite
  if oppClass == "OPP_EXP_DARK_SPECIALIST" then
    trainerPic = 39 -- Super Nerd
  elseif oppClass == "OPP_EXP_BERRY_SPECIALIST" then
    trainerPic = 15 -- Lass
  end
  local trainerTitle = (def and def.name) or "TRAINER"

  local okB, Bridge = pcall(require, "src.core.game3.battle_bridge")
  local Runtime = package.loaded["src.core.game3.runtime"]
  local g = game or (Runtime and Runtime._game)
  local foe = {
    species = lead.species,
    level = lead.level,
    moves = lead.moves,
    ivs = lead.ivs,
    evs = lead.evs,
    party = party,
    trainerClass = 23,
    trainerClassName = trainerTitle,
    trainerName = trainerTitle,
    trainerPic = trainerPic,
    trainerPicId = trainerPic,
    frontierTrainer = {
      class = 23,
      className = trainerTitle,
      name = trainerTitle,
      pic = trainerPic,
    },
  }
  local battleOpts = {
    wild = false,
    frontierTrainer = foe.frontierTrainer,
    trainerClassName = trainerTitle,
    trainerName = trainerTitle,
    trainerPicId = trainerPic,
    done = function(outcome)
      if onDone then onDone(outcome == "win" and "win" or "lose") end
    end,
  }
  if okB and Bridge and Bridge.start then
    Bridge.start(Runtime and Runtime._mod or nil, g, foe, battleOpts)
  else
    if onDone then onDone("win") end
  end
end

function HouseNpcs.startTrainerBattle(game, ow, oppClass, partyIndex, onDone)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    return startTrainerBattleGen3(game, ow, oppClass, partyIndex, onDone)
  end
  if Host.isGen2() then
    return startTrainerBattleGen2(game, ow, oppClass, partyIndex, onDone)
  end
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  -- trainer.party hooks cannot see `game`; stash for scaleCap during build.
  HouseNpcs._scaleGame = game
  local battle
  Gen1Patch.apply(require("src.battle.BattleState"), function(bs)
    local ok, result = pcall(bs.newTrainer, game, oppClass, partyIndex or 1)
    HouseNpcs._scaleGame = nil
    if not ok then error(result) end
    battle = result
  end)
  if not battle then
    HouseNpcs._scaleGame = nil
    error("BattleState.newTrainer unavailable")
  end
  battle.onFinish = function(result)
    if ow and ow.afterBattle then
      ow:afterBattle(result, battle)
    end
    if onDone then onDone(result) end
  end
  if ow and ow.pushBattle then
    ow:pushBattle(battle)
  else
    game.stack:push(battle)
  end
end

function HouseNpcs.clearDefeated(game, npcId)
  if not game.save.defeatedTrainers then
    game.save.defeatedTrainers = {}
  end
  game.save.defeatedTrainers[npcId] = nil
end

HouseNpcs.resetClaims()

return HouseNpcs
