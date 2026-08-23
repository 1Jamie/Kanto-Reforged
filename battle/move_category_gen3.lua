-- Strip Gen4+ per-move physical/special categories so Damage.categoryOf
-- falls through to TypeChart.category(type) (Gen 3 type split).
-- Status moves keep category = "status".

local MoveCategoryGen3 = {}

local function stripRecord(move)
  if not move then return false end
  local cat = move.category
  if cat == "physical" or cat == "special" then
    move.category = nil
    return true
  end
  return false
end

--- Clear categories on a moves table (pokemon_data.moves or Data.moves).
function MoveCategoryGen3.stripTable(moves)
  if type(moves) ~= "table" then return 0 end
  local n = 0
  for _, move in pairs(moves) do
    if stripRecord(move) then n = n + 1 end
  end
  return n
end

--- Apply to live Data.moves after content merge.
function MoveCategoryGen3.apply()
  local ok, Data = pcall(require, "src.core.Data")
  if not ok or type(Data) ~= "table" then return 0 end
  return MoveCategoryGen3.stripTable(Data.moves)
end

function MoveCategoryGen3.resolvedCategory(move)
  if not move then return "physical" end
  if move.category == "status" then return "status" end
  if move.category == "physical" or move.category == "special" then
    return move.category
  end
  local TypeChart = require("src.battle.TypeChart")
  return TypeChart.category(move.type) or "physical"
end

return MoveCategoryGen3
