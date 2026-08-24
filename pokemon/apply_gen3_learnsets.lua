-- Apply PokeAPI Gen3 learnsets (learnset_gen3.lua) onto registered species.
local ApplyGen3Learnsets = {}

local function copyList(list)
  local out = {}
  for i, v in ipairs(list or {}) do
    out[i] = v
  end
  return out
end

local function appendUnique(list, id)
  for _, existing in ipairs(list) do
    if existing == id then return end
  end
  list[#list + 1] = id
end

function ApplyGen3Learnsets.filterRow(row, knownMove)
  local out = {
    level1Moves = {},
    learnset = {},
    evolutionMoves = {},
    tmhm = {},
  }
  for _, mv in ipairs(row.level1Moves or {}) do
    if knownMove(mv) then out.level1Moves[#out.level1Moves + 1] = mv end
  end
  for _, entry in ipairs(row.learnset or {}) do
    if entry.move and knownMove(entry.move) then
      out.learnset[#out.learnset + 1] = { level = entry.level, move = entry.move }
    end
  end
  for _, mv in ipairs(row.evolutionMoves or {}) do
    if knownMove(mv) then out.evolutionMoves[#out.evolutionMoves + 1] = mv end
  end
  for _, mv in ipairs(row.tmhm or {}) do
    if knownMove(mv) then out.tmhm[#out.tmhm + 1] = mv end
  end
  table.sort(out.tmhm)
  return out
end

function ApplyGen3Learnsets.toLevelMoves(filtered)
  local out = {}
  local seen = {}

  local function add(level, move)
    if not move or seen[move] then return end
    seen[move] = true
    out[#out + 1] = { level = level, move = move }
  end

  for _, mv in ipairs(filtered.evolutionMoves or {}) do
    add(1, mv)
  end
  for _, mv in ipairs(filtered.level1Moves or {}) do
    add(1, mv)
  end
  for _, entry in ipairs(filtered.learnset or {}) do
    add(entry.level or 1, entry.move)
  end

  if #out == 0 then
    out[1] = { level = 1, move = "POUND" }
  end
  return out
end

function ApplyGen3Learnsets.gen1Level1(filtered)
  local level1 = copyList(filtered.level1Moves)
  for _, mv in ipairs(filtered.evolutionMoves or {}) do
    appendUnique(level1, mv)
  end
  if #level1 == 0 then
    level1[1] = "TACKLE"
  end
  return level1
end

function ApplyGen3Learnsets.apply(mod, Host, gen3Table)
  if not (mod and gen3Table and gen3Table.species) then return 0 end

  local knownMove = function(id)
    return id and mod.content.moves:get(id) ~= nil
  end

  local n = 0
  for speciesId, row in pairs(gen3Table.species) do
    local existing = mod.content.pokemon:get(speciesId)
    if existing then
      local dex = existing.dex or 0
      if dex >= 1 and dex <= 386 then
        local filtered = ApplyGen3Learnsets.filterRow(row, knownMove)
        local ok = pcall(function()
          if Host.isGen2() then
            mod.content.pokemon:patch(speciesId, {
              levelMoves = ApplyGen3Learnsets.toLevelMoves(filtered),
              tmhm = filtered.tmhm,
            })
          else
            mod.content.pokemon:patch(speciesId, {
              level1Moves = ApplyGen3Learnsets.gen1Level1(filtered),
              learnset = filtered.learnset,
              evolutionMoves = filtered.evolutionMoves,
              tmhm = filtered.tmhm,
            })
          end
        end)
        if ok then n = n + 1 end
      end
    end
  end
  return n
end

return ApplyGen3Learnsets
