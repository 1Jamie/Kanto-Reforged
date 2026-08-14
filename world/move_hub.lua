-- Move relearner / tutor / deleter hub in Saffron Pidgey House.

local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
local Strings = require("src.core.Strings")

local MoveHub = {}
MoveHub.OWNER = "move_hub"

MoveHub.TUTOR_MOVES = {
  "THUNDERPUNCH", "FIRE_PUNCH", "ICE_PUNCH", "BODY_SLAM", "MEGA_PUNCH",
  "ROCK_SLIDE", "SWORDS_DANCE", "SEISMIC_TOSS", "COUNTER", "MIMIC",
  "METRONOME", "DOUBLE_EDGE", "SUBSTITUTE", "MEGA_KICK", "SOFTBOILED",
}

local function packedMoves(mon)
  local out = {}
  for _, mv in ipairs(mon.moves or {}) do
    if mv and mv.id then out[#out + 1] = mv end
  end
  return out
end

local function setMoveSlot(game, mon, slot, moveId)
  local def = game.data.moves[moveId]
  local maxPp = def and def.pp or 5
  mon.moves = packedMoves(mon)
  while #mon.moves < slot do
    mon.moves[#mon.moves + 1] = nil
  end
  mon.moves[slot] = { id = moveId, pp = maxPp }
  -- densify
  local dense = {}
  for _, mv in ipairs(mon.moves) do
    if mv and mv.id then dense[#dense + 1] = mv end
  end
  mon.moves = dense
end

local function deleteSlot(mon, slot)
  local moves = packedMoves(mon)
  if #moves <= 1 then return false, "last" end
  if slot < 1 or slot > #moves then return false, "bad" end
  table.remove(moves, slot)
  mon.moves = moves
  return true
end

local function learnsetMoves(game, mon)
  local def = game.data.pokemon[mon.species]
  local seen, list = {}, {}
  local function add(id)
    if id and not seen[id] and game.data.moves[id] then
      seen[id] = true
      list[#list + 1] = id
    end
  end
  if def and def.learnset then
    for _, row in ipairs(def.learnset) do
      if type(row) == "table" then
        add(row.move or row[2] or row.id)
      elseif type(row) == "string" then
        add(row)
      end
    end
  end
  -- Gold: levelMoves is { { level, move }, ... } or similar.
  if def and def.levelMoves then
    for _, row in ipairs(def.levelMoves) do
      if type(row) == "table" then
        add(row.move or row[2] or row.id)
      elseif type(row) == "string" then
        add(row)
      end
    end
  end
  -- egg moves from breeding data if present
  local ok, Breeding = pcall(require, "mods.Kanto-Reforged.breeding")
  if ok and Breeding and Breeding.eggMovesFor then
    for _, id in ipairs(Breeding.eggMovesFor(mon.species) or {}) do
      add(id)
    end
  end
  table.sort(list)
  return list
end

local function takeScales(game, n)
  local Bag = require("src.inventory.Bag")
  local have = (game.save.inventory and game.save.inventory.HEART_SCALE) or 0
  if have < n then return false end
  Bag.remove(game.save, "HEART_SCALE", n)
  return true
end

local function pickParty(game, done, onPick)
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
    HouseNpcs.pushText(game, Strings("No POKéMON."), done)
    return
  end
  local ListMenu = require("src.ui.ListMenu")
  game.stack:push(ListMenu.new(game, Strings("Which POKéMON?"), rows, {
    onChoose = function(row, menu)
      menu:close()
      onPick(party[row.value])
    end,
  }))
end

local function relearnFlow(game, mod, done)
  pickParty(game, done, function(mon)
    if not mon then if done then done() end return end
    local moves = learnsetMoves(game, mon)
    local rows = {}
    for _, id in ipairs(moves) do
      local def = game.data.moves[id]
      rows[#rows + 1] = { label = def and def.name or id, value = id }
    end
    if #rows == 0 then
      HouseNpcs.pushText(game, Strings("Nothing to relearn."), done)
      return
    end
    local ListMenu = require("src.ui.ListMenu")
    game.stack:push(ListMenu.new(game, Strings("Relearn which?"), rows, {
      onChoose = function(row, menu)
        menu:close()
        local moveId = row.value
        local slots = packedMoves(mon)
        local slotRows = {}
        for i, mv in ipairs(slots) do
          local d = game.data.moves[mv.id]
          slotRows[#slotRows + 1] = {
            label = (d and d.name or mv.id),
            value = i,
          }
        end
        if #slots < 4 then
          slotRows[#slotRows + 1] = { label = Strings("(empty)"), value = #slots + 1 }
        end
        game.stack:push(ListMenu.new(game, Strings("Replace which?"), slotRows, {
          onChoose = function(srow, smenu)
            smenu:close()
            if not takeScales(game, 1) then
              HouseNpcs.pushText(game, Strings("Need a HEART SCALE."), done)
              return
            end
            setMoveSlot(game, mon, srow.value, moveId)
            HouseNpcs.pushText(game, Strings("Done!"), done)
          end,
        }))
      end,
    }))
  end)
end

local function tutorFlow(game, mod, done)
  pickParty(game, done, function(mon)
    if not mon then if done then done() end return end
    local rows = {}
    for _, id in ipairs(MoveHub.TUTOR_MOVES) do
      if game.data.moves[id] then
        rows[#rows + 1] = { label = game.data.moves[id].name, value = id }
      end
    end
    local ListMenu = require("src.ui.ListMenu")
    game.stack:push(ListMenu.new(game, Strings("Tutor which?"), rows, {
      onChoose = function(row, menu)
        menu:close()
        local moveId = row.value
        local slots = packedMoves(mon)
        local slotRows = {}
        for i, mv in ipairs(slots) do
          local d = game.data.moves[mv.id]
          slotRows[#slotRows + 1] = { label = d and d.name or mv.id, value = i }
        end
        if #slots < 4 then
          slotRows[#slotRows + 1] = { label = Strings("(empty)"), value = #slots + 1 }
        end
        game.stack:push(ListMenu.new(game, Strings("Replace which?"), slotRows, {
          onChoose = function(srow, smenu)
            smenu:close()
            if not takeScales(game, 2) then
              HouseNpcs.pushText(game, Strings("Need 2 HEART SCALES."), done)
              return
            end
            setMoveSlot(game, mon, srow.value, moveId)
            HouseNpcs.pushText(game, Strings("Tutored!"), done)
          end,
        }))
      end,
    }))
  end)
end

local function deleteFlow(game, mod, done)
  pickParty(game, done, function(mon)
    if not mon then if done then done() end return end
    local slots = packedMoves(mon)
    if #slots <= 1 then
      HouseNpcs.pushText(game, Strings("Can't forget the\nlast move."), done)
      return
    end
    local rows = {}
    for i, mv in ipairs(slots) do
      local d = game.data.moves[mv.id]
      rows[#rows + 1] = { label = d and d.name or mv.id, value = i }
    end
    local ListMenu = require("src.ui.ListMenu")
    game.stack:push(ListMenu.new(game, Strings("Forget which?"), rows, {
      onChoose = function(row, menu)
        menu:close()
        local ok = deleteSlot(mon, row.value)
        if ok then
          HouseNpcs.pushText(game, Strings("Forgotten."), done)
        else
          HouseNpcs.pushText(game, Strings("Can't forget the\nlast move."), done)
        end
      end,
    }))
  end)
end

local function hubTalk(mod)
  return function(game, ow, npc, done)
    local ListMenu = require("src.ui.ListMenu")
    game.stack:push(ListMenu.new(game, Strings("MOVE HUB"), {
      { label = Strings("RELEARN"), value = "relearn" },
      { label = Strings("TUTOR"), value = "tutor" },
      { label = Strings("DELETE"), value = "delete" },
      { label = Strings("CANCEL"), value = "cancel" },
    }, {
      onChoose = function(row, menu)
        menu:close()
        if row.value == "relearn" then
          relearnFlow(game, mod, done)
        elseif row.value == "tutor" then
          tutorFlow(game, mod, done)
        elseif row.value == "delete" then
          deleteFlow(game, mod, done)
        else
          if done then done() end
        end
      end,
    }))
  end
end

function MoveHub.register(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local mapId = Host.isGen2() and "MR_PSYCHICS_HOUSE" or "SAFFRON_PIDGEY_HOUSE"
  local index = Host.isGen2() and 2 or 5

  HouseNpcs.appendNpc(mod, mapId, {
    index = index,
    name = "SAFFRONPIDGEYHOUSE_MOVE_HUB",
    sprite = "SPRITE_HIKER",
    text = "TEXT_SAFFRONPIDGEYHOUSE_MOVE_HUB",
    x = 6, y = 5,
  }, MoveHub.OWNER)

  -- Heart Scale hidden items (Gen1 field registry only).
  if Host.isGen1() then
    mod.content.field:patch("hiddenItems", {
      ROUTE_12 = { { x = 20, y = 55, item = "HEART_SCALE" } },
      ROUTE_19 = { { x = 8, y = 10, item = "HEART_SCALE" } },
      SEAFOAM_ISLANDS_B1F = { { x = 10, y = 8, item = "HEART_SCALE" } },
    })
  end

  HouseNpcs.bindTalk(mod, mapId, {
    TEXT_SAFFRONPIDGEYHOUSE_MOVE_HUB = hubTalk(mod),
  })
end

return MoveHub
