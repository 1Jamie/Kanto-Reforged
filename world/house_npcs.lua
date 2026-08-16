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

local function key(map, index)
  return map .. "#" .. tostring(index)
end

function HouseNpcs.resetClaims()
  HouseNpcs._claims = {}
  for _, row in ipairs(HouseNpcs.BASELINE_CLAIMS) do
    HouseNpcs._claims[key(row.map, row.index)] = row.owner
  end
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

function HouseNpcs.npcObject(row)
  return {
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
end

function HouseNpcs.appendNpc(mod, mapId, row, owner)
  HouseNpcs.claim(mapId, row.index, owner or row.name or "house_npcs")
  mod.content.maps:patch(mapId, {
    objects = { __append = { HouseNpcs.npcObject(row) } },
  })
end

-- Register TEXT_* talk handlers. Gen1 → map_scripts; Gen2 → talkTo seam.
function HouseNpcs.registerTalk(textId, handler)
  HouseNpcs._talks[textId] = handler
end

function HouseNpcs.bindTalk(mod, mapId, talkTable)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen1() then
    mod.content.map_scripts:register(mapId, { talk = talkTable })
    return
  end
  for textId, fn in pairs(talkTable or {}) do
    HouseNpcs.registerTalk(textId, fn)
  end
end

-- Gold: wrap OverworldController.talkTo so TEXT_* handlers fire (map_scripts
-- has no Gen2 reader). A true return suppresses the built-in object path.
function HouseNpcs.installTalkDispatch(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen2() or HouseNpcs._talkInstalled then return end
  HouseNpcs._talkInstalled = true
  local OC = require("src.world.OverworldController")
  local prev = OC.talkTo
  OC.talkTo = function(world, npc)
    local d = npc and npc.def
    local key = d and (d.text or d.name)
    local fn = key and HouseNpcs._talks[key]
    if fn then
      local game = (world and world.game)
        or Host.liveGame(mod)
      fn(game, world, npc, function() end)
      return true
    end
    if type(prev) == "function" then
      return prev(world, npc)
    end
    return false
  end
  if mod and mod.log then
    mod.log:info("Gen2 house NPC talkTo dispatch installed")
  end
end

-- Badge check: Gen1 inventory *BADGE; Gold kantoBadges / Johto badges.
function HouseNpcs.hasBadge(save, badge)
  if not save or not badge then return false end
  if save.inventory and (save.inventory[badge] or 0) > 0 then
    return true
  end
  local p = save.player
  if not p then return false end
  local short = badge:gsub("BADGE$", "")
  if p.kantoBadges and p.kantoBadges[short] then
    return true
  end
  if p.badges and (p.badges[badge] or p.badges[short]) then
    return true
  end
  return false
end

function HouseNpcs.pushText(game, msg, done)
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, msg, done))
end

function HouseNpcs.ask(game, msg, onChoice)
  -- Gen 1 YesNoChoice sits on the still-open text box (InitYesNoTextBox-
  -- Parameters). TextBox opts.choice pushes ChoiceBox correctly; the old
  -- ChoiceBox.new(game, {"YES","NO"}, fn) call used the wrong arity and
  -- crashed when confirming (onChoose was a table).
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, msg, nil, { choice = onChoice }))
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

-- Highest usable party level (skips eggs / empty slots). Not lead-only.
function HouseNpcs.highestPartyLevel(game)
  local Breeding = require("mods.Kanto-Reforged.pokemon.breeding")
  local best = 0
  for _, mon in ipairs((game and game.save and game.save.party) or {}) do
    if mon and mon.species and not Breeding.isEgg(mon) then
      local lv = mon.level or 0
      if lv > best then best = lv end
    end
  end
  return best
end

local function resolveScaleGame(game, mod)
  return game
      or HouseNpcs._scaleGame
      or (mod and require("mods.Kanto-Reforged.core.host").liveGame(mod))
end

-- Club / specialist / rematch bracket:
--   Level caps ON  → story soft-cap only (competitive on-cap fights).
--   Level caps OFF → max(soft-cap, highest non-egg party level) so
--                    overleveled teams still get a serious Circuit.
function HouseNpcs.scaleCap(mod, game)
  game = resolveScaleGame(game, mod)
  local soft = HouseNpcs.softCap(mod, game)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen1() and LevelCaps.enabled(mod) then
    return soft
  end
  local partyHigh = HouseNpcs.highestPartyLevel(game)
  if partyHigh > 0 then
    return math.max(soft, partyHigh)
  end
  return soft
end

function HouseNpcs.partyHasType(game, typeId)
  local party = game.save and game.save.party or {}
  local pokemon = game.data and game.data.pokemon or {}
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
  local party = game.save and game.save.party or {}
  local lead = party[1]
  if not lead then return false end
  return HeldItems.isBerry(HeldItems.get(lead))
end

function HouseNpcs.giveItem(game, itemId, qty)
  local Bag = require("src.inventory.Bag")
  return Bag.add(game.save, itemId, qty or 1)
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

function HouseNpcs.startTrainerBattle(game, ow, oppClass, partyIndex, onDone)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then
    return startTrainerBattleGen2(game, ow, oppClass, partyIndex, onDone)
  end
  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
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
