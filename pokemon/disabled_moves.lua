-- Moves kept in Data for old party slots / Sketch leftovers, but stripped
-- from learnsets and egg moves. Singles-only KR: no doubles partners.

local DisabledMoves = {}

DisabledMoves.IDS = {
  HELPING_HAND = true,
  FOLLOW_ME = true,
  RAGE_POWDER = true,
  ALLY_SWITCH = true,
  WIDE_GUARD = true,
  QUICK_GUARD = true,
  AFTER_YOU = true,
  QUASH = true,
  SPOTLIGHT = true,
}

function DisabledMoves.isDisabled(id)
  return id and DisabledMoves.IDS[id] == true
end

--- Drop disabled ids from level-up / TM / egg lists on one species patch.
function DisabledMoves.stripLearnFields(patch)
  if type(patch) ~= "table" then return patch end

  local function keep(id)
    return id and not DisabledMoves.isDisabled(id)
  end

  if patch.level1Moves then
    local out = {}
    for _, mv in ipairs(patch.level1Moves) do
      if keep(mv) then out[#out + 1] = mv end
    end
    patch.level1Moves = out
  end

  if patch.learnset then
    local out = {}
    for _, entry in ipairs(patch.learnset) do
      if entry and keep(entry.move) then out[#out + 1] = entry end
    end
    patch.learnset = out
  end

  if patch.levelMoves then
    local out = {}
    for _, entry in ipairs(patch.levelMoves) do
      if entry and keep(entry.move) then out[#out + 1] = entry end
    end
    patch.levelMoves = out
  end

  if patch.evolutionMoves then
    local out = {}
    for _, mv in ipairs(patch.evolutionMoves) do
      if keep(mv) then out[#out + 1] = mv end
    end
    patch.evolutionMoves = out
  end

  if patch.tmhm then
    local out = {}
    for _, mv in ipairs(patch.tmhm) do
      if keep(mv) then out[#out + 1] = mv end
    end
    patch.tmhm = out
  end

  if patch.eggMoves then
    local out = {}
    for _, mv in ipairs(patch.eggMoves) do
      if keep(mv) then out[#out + 1] = mv end
    end
    patch.eggMoves = out
  end

  return patch
end

--- After learnsets are applied, scrub every registered species.
function DisabledMoves.stripAllSpecies(mod)
  if not (mod and mod.content and mod.content.pokemon) then return 0 end
  local n = 0
  local reg = mod.content.pokemon
  if type(reg.each) ~= "function" then return 0 end
  for speciesId, sp in reg:each() do
    if sp then
      local patch = DisabledMoves.stripLearnFields({
        level1Moves = sp.level1Moves,
        learnset = sp.learnset,
        levelMoves = sp.levelMoves,
        evolutionMoves = sp.evolutionMoves,
        tmhm = sp.tmhm,
        eggMoves = sp.eggMoves,
      })
      local ok = pcall(function()
        mod.content.pokemon:patch(speciesId, patch)
      end)
      if ok then n = n + 1 end
    end
  end
  return n
end

return DisabledMoves
