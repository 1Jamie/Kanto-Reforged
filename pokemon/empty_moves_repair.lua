-- Repair party/PC/daycare mons that were saved with an empty moveset.
-- The Gen2 Hoenn register-after-patch bug left caught Gen3 mons with no
-- moves and nothing to learn. Only fill slots that have zero known moves;
-- never overwrite a partial or custom set (TMs, breeding, Sketch leftovers).

local EmptyMovesRepair = {}

local function isEgg(mon)
  return type(mon) == "table" and mon.isEgg == true
end

local function moveId(slot)
  if type(slot) == "string" then return slot end
  if type(slot) == "table" then return slot.id or slot.move end
  return nil
end

function EmptyMovesRepair.hasMoves(mon)
  if type(mon) ~= "table" then return false end
  for _, slot in ipairs(mon.moves or {}) do
    if moveId(slot) then return true end
  end
  return false
end

-- Last four level-up moves at `level`, matching a wild/gift encounter.
function EmptyMovesRepair.idsAtLevel(data, species, level)
  if not (data and data.pokemon and species) then return {} end
  local def = data.pokemon[species]
  if not def then return {} end
  level = math.max(1, tonumber(level) or 1)

  local ids = {}
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then
    local ok, Mon = pcall(require, "src.battle.gen2.Mon")
    if ok and Mon and Mon.movesAtLevel then
      for _, slot in ipairs(Mon.movesAtLevel(def, level, data.moves) or {}) do
        local id = moveId(slot)
        if id then ids[#ids + 1] = id end
      end
    end
  else
    local Pokemon = require("src.pokemon.Pokemon")
    local ok, got = pcall(Pokemon.movesAtLevel, def, level)
    if ok then
      for _, id in ipairs(got or {}) do
        if id then ids[#ids + 1] = id end
      end
    else
      -- Def missing level1Moves/learnset: still try Gen2-shaped levelMoves.
      local seen = {}
      for _, entry in ipairs(def.levelMoves or {}) do
        local id = entry and entry.move
        if id and (entry.level or 1) <= level and not seen[id] then
          seen[id] = true
          ids[#ids + 1] = id
          if #ids > 4 then table.remove(ids, 1) end
        end
      end
    end
  end

  local out = {}
  for _, id in ipairs(ids) do
    if data.moves and data.moves[id] then
      out[#out + 1] = id
    end
  end
  while #out > 4 do
    table.remove(out, 1)
  end
  return out
end

function EmptyMovesRepair.fillMon(data, mon)
  if not mon or isEgg(mon) or EmptyMovesRepair.hasMoves(mon) then
    return false
  end
  local ids = EmptyMovesRepair.idsAtLevel(data, mon.species, mon.level)
  if #ids == 0 then return false end
  local slots = {}
  for _, id in ipairs(ids) do
    local mdef = data.moves[id]
    local pp = mdef and mdef.pp or 0
    slots[#slots + 1] = { id = id, pp = pp, maxPp = pp }
  end
  mon.moves = slots
  return true
end

function EmptyMovesRepair.repairSave(data, save)
  if not data or not save then return 0 end
  local n = 0
  local function touch(mon)
    if EmptyMovesRepair.fillMon(data, mon) then n = n + 1 end
  end
  for _, mon in ipairs(save.party or {}) do touch(mon) end
  for _, box in ipairs(save.boxes or {}) do
    for _, mon in ipairs(box or {}) do touch(mon) end
  end
  local dc = save.daycare
  if type(dc) == "table" then
    touch(dc.mon)
    touch(dc.mon2)
  end
  return n
end

function EmptyMovesRepair.install(mod)
  local function run(ev)
    local game = (ev and ev.game) or (mod and mod.activeGame)
    local save = (ev and ev.save) or (game and game.save)
    local data = (game and game.data) or require("src.core.Data")
    if data and save then
      local n = EmptyMovesRepair.repairSave(data, save)
      if n > 0 and mod and mod.log then
        mod.log:info("Filled empty movesets on %d Pokémon (last 4 at level)", n)
      end
    end
  end
  -- game.ready sees the new-game skeleton; CONTINUE replaces the save after.
  mod.events:on("game.ready", run)
  mod.events:on("save.loaded", run)
end

return EmptyMovesRepair
