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

local function listHas(list, id)
  for _, existing in ipairs(list or {}) do
    if existing == id then return true end
  end
  return false
end

local function isWaterType(species)
  local t = species and species.types
  if type(t) ~= "table" then return false end
  for _, id in ipairs(t) do
    if id == "WATER" then return true end
  end
  -- Gen2 host sometimes stores type1/type2
  if species.type1 == "WATER" or species.type2 == "WATER" then return true end
  if species.type == "WATER" then return true end
  return false
end

-- Host TM/HM items still teach that generation's machine moves. Crystal TM31
-- is Mud-Slap and TM02 is Headbutt; Red TM01 is Mega Punch. Emerald's machine
-- list is a different set (Focus Punch, Facade, …). The engine's teach check
-- is "is this item's move in species.tmhm?", so replacing the ROM list with
-- Gen3-only names made every host TM refuse. Keep both.
function ApplyGen3Learnsets.unionHostTmhm(tmhm, existing)
  local out = copyList(tmhm)
  for _, mv in ipairs(existing and existing.tmhm or {}) do
    if mv then appendUnique(out, mv) end
  end
  table.sort(out)
  return out
end

-- Gen3 removed Whirlpool as an HM (tutor-only / tiny level-up set). On a Gen2
-- host HM06 is still required for Johto progression, so restore compatibility:
--   1) Kanto/Johto: keep anyone who already had WHIRLPOOL on the stock Gen2 sheet
--   2) Hoenn (dex 252+): grant it to Water-types that received SURF (Gen2-style
--      water HM companion — Gen3 never put Whirlpool on their machine list)
function ApplyGen3Learnsets.ensureGen2Whirlpool(tmhm, existing)
  local out = copyList(tmhm)
  if listHas(out, "WHIRLPOOL") then
    table.sort(out)
    return out
  end
  local stockHad = listHas(existing and existing.tmhm, "WHIRLPOOL")
  local dex = existing and tonumber(existing.dex) or 0
  if stockHad then
    appendUnique(out, "WHIRLPOOL")
  elseif dex >= 252 and listHas(out, "SURF") and isWaterType(existing) then
    appendUnique(out, "WHIRLPOOL")
  end
  table.sort(out)
  return out
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
  local DisabledMoves = require("mods.Kanto-Reforged.pokemon.disabled_moves")

  local knownMove = function(id)
    return id and mod.content.moves:get(id) ~= nil
      and not DisabledMoves.isDisabled(id)
  end

  local n = 0
  for speciesId, row in pairs(gen3Table.species) do
    local existing = mod.content.pokemon:get(speciesId)
    if existing then
      local dex = existing.dex or 0
      if dex >= 1 and dex <= 386 then
        local filtered = ApplyGen3Learnsets.filterRow(row, knownMove)
        filtered.tmhm = ApplyGen3Learnsets.unionHostTmhm(filtered.tmhm, existing)
        -- Gold, Silver, and Crystal share this TM/HM table and this branch.
        -- Gen3 dropped HM06 Whirlpool; union restores ROM learners, and the
        -- extra grant covers Hoenn Water-types that never had a Gen2 sheet.
        if Host.isGen2() then
          filtered.tmhm = ApplyGen3Learnsets.ensureGen2Whirlpool(filtered.tmhm, existing)
        end
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
