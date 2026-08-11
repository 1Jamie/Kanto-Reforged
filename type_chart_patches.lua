-- Type-chart → Gen3 values on every host (Red and Gold).
-- Dark/Steel/Fairy rows live in types_data.lua; this fixes the classic
-- Gen1 quirks (and re-asserts them on Gold so KR matchups match across
-- versions even if a cache/extract is incomplete).
--
-- Multipliers are ×10 (10 = neutral, 20 = SE, 5 = NVE, 0 = immune).

local M = {}

-- Upsert: override when present, register when missing.
M.GEN3_CLASSIC = {
  -- Ghost hits Psychic (Gen1 immune → Gen2/3 SE)
  { key = "GHOST>PSYCHIC_TYPE", multiplier = 20 },
  -- Bug vs Poison (Gen1 SE → Gen2/3 NVE)
  { key = "BUG>POISON", multiplier = 5 },
  -- Poison vs Bug (Gen1 SE → Gen2/3 neutral)
  { key = "POISON>BUG", multiplier = 10 },
  -- Ice vs Fire (Gen1 missing/neutral → Gen2/3 NVE)
  { key = "ICE>FIRE", multiplier = 5 },
  -- Steel resists Dark / Ghost (types_data had previously left these neutral)
  { key = "DARK>STEEL", multiplier = 5 },
  { key = "GHOST>STEEL", multiplier = 5 },
}

local function upsert(mod, key, multiplier)
  if mod.content.type_chart:get(key) ~= nil then
    mod.content.type_chart:override(key, { multiplier = multiplier })
  else
    mod.content.type_chart:register(key, { multiplier = multiplier })
  end
end

--- Force Gen3 classic matchups on the active host.
function M.apply(mod)
  local n = 0
  for _, row in ipairs(M.GEN3_CLASSIC) do
    local ok, err = pcall(function()
      upsert(mod, row.key, row.multiplier)
    end)
    if ok then
      n = n + 1
    else
      mod.log:warn("type chart patch %s failed: %s", row.key, tostring(err))
    end
  end
  if n > 0 then
    mod.log:info("Applied %d Gen3 type-chart rows (all hosts)", n)
  end
  return n
end

--- Upsert every types_data Dark/Steel/Fairy matchup so Gold and Red share
-- the same modern-type table (Gold ROM may lack Fairy rows; Red registers
-- them fresh — this keeps both identical).
function M.applyModernTypes(mod, types_data)
  if not types_data or not types_data.matchups then return 0 end
  local n = 0
  for _, row in ipairs(types_data.matchups) do
    local a, d = row.attacker, row.defender
    if a == "FAIRY" or d == "FAIRY"
        or a == "DARK" or d == "DARK"
        or a == "STEEL" or d == "STEEL" then
      local key = a .. ">" .. d
      local ok, err = pcall(function()
        upsert(mod, key, row.multiplier)
      end)
      if ok then
        n = n + 1
      else
        mod.log:warn("modern matchup %s failed: %s", key, tostring(err))
      end
    end
  end
  if n > 0 then
    mod.log:info("Upserted %d Dark/Steel/Fairy matchups", n)
  end
  return n
end

return M
