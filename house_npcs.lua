-- Shared helpers for Kanto Reforged house NPCs / object index hygiene.

local LevelCaps = require("mods.Kanto-Reforged.level_caps")
local Strings = require("src.core.Strings")

local HouseNpcs = {}

-- Reserved object indices claimed by existing Kanto Reforged modules.
-- New modules MUST register via claim() and never collide.
HouseNpcs.BASELINE_CLAIMS = {
  { map = "VIRIDIAN_CITY", index = 8, owner = "level_caps" },
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

function HouseNpcs.npcObject(row)
  return {
    index = row.index,
    name = row.name,
    sprite = row.sprite,
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

-- Soft bracket even when hardcore caps are off (same milestone table).
function HouseNpcs.scaleCap(mod, game)
  local save = game and game.save
  local data = game and game.data
  if not save or not data then return 20 end
  return LevelCaps.capFor(data, save) or 20
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
  local HeldItems = require("mods.Kanto-Reforged.held_items")
  local party = game.save and game.save.party or {}
  local lead = party[1]
  if not lead or not lead.heldItem then return false end
  return HeldItems.isBerry(lead.heldItem)
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

function HouseNpcs.startTrainerBattle(game, ow, oppClass, partyIndex, onDone)
  local BattleState = require("src.battle.BattleState")
  local battle = BattleState.newTrainer(game, oppClass, partyIndex or 1)
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
