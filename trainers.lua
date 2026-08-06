-- Curated Gen 2/3 species swaps into gym leaders, Elite Four, the rival,
-- and a handful of early/mid trash trainers.  One or two slots each —
-- same density as the wild encounter mixer, not a full roster rewrite.

local Trainers = {}

-- { class, partyIndex (1-based), slotIndex (1-based), species, level? }
-- Levels default to the slot's vanilla level when omitted.
local MIX = {
  -- Gym leaders
  { "OPP_BROCK", 1, 1, "ARON" },
  { "OPP_MISTY", 1, 1, "MARILL" },
  { "OPP_LT_SURGE", 1, 1, "ELECTRIKE" },
  { "OPP_ERIKA", 1, 2, "ROSELIA" },
  { "OPP_KOGA", 1, 3, "SEVIPER" },
  { "OPP_SABRINA", 1, 3, "XATU" },
  { "OPP_BLAINE", 1, 1, "HOUNDOUR" },
  { "OPP_BLAINE", 1, 2, "NUMEL" },
  { "OPP_GIOVANNI", 3, 2, "DONPHAN" }, -- gym fight

  -- Elite Four
  { "OPP_LORELEI", 1, 1, "PILOSWINE" },
  { "OPP_BRUNO", 1, 1, "STEELIX" },
  { "OPP_BRUNO", 1, 2, "HITMONTOP" },
  { "OPP_AGATHA", 1, 2, "CROBAT" },
  { "OPP_AGATHA", 1, 3, "MISDREAVUS" },
  { "OPP_LANCE", 1, 1, "KINGDRA" },
  { "OPP_LANCE", 1, 3, "ALTARIA" },

  -- Champion rival (all three starter paths)
  { "OPP_RIVAL3", 1, 3, "AGGRON" },
  { "OPP_RIVAL3", 1, 4, "HOUNDOOM" },
  { "OPP_RIVAL3", 2, 3, "AGGRON" },
  { "OPP_RIVAL3", 2, 4, "SHARPEDO" },
  { "OPP_RIVAL3", 3, 3, "AGGRON" },
  { "OPP_RIVAL3", 3, 5, "KINGDRA" },

  -- Mid rival (Celadon / Pokémon Tower tier)
  { "OPP_RIVAL2", 4, 2, "HOUNDOUR" },
  { "OPP_RIVAL2", 5, 2, "SHARPEDO" },
  { "OPP_RIVAL2", 6, 3, "HOUNDOUR" },

  -- Trash / route trainers (type-themed)
  { "OPP_BUG_CATCHER", 5, 4, "LEDYBA" },
  { "OPP_BUG_CATCHER", 1, 1, "SPINARAK" },
  { "OPP_HIKER", 1, 1, "ARON" },
  { "OPP_HIKER", 5, 1, "LARVITAR" },
  { "OPP_YOUNGSTER", 1, 2, "MAREEP" },
  { "OPP_LASS", 5, 1, "SEEDOT" },
  { "OPP_LASS", 5, 2, "LOTAD" },
  { "OPP_JR_TRAINER_M", 1, 1, "PHANPY" },
  { "OPP_JR_TRAINER_F", 5, 1, "ROSELIA" },
  { "OPP_ROCKET", 1, 2, "MURKROW" },
  { "OPP_ROCKET", 5, 2, "SABLEYE" },
  { "OPP_COOLTRAINER_M", 1, 1, "PUPITAR" },
  { "OPP_COOLTRAINER_F", 6, 1, "BELLOSSOM" },
}

Trainers.MIX = MIX

local function copyParties(parties)
  local out = {}
  for pi, party in ipairs(parties or {}) do
    local copy = {}
    for si, slot in ipairs(party) do
      copy[si] = {
        level = slot.level,
        species = slot.species,
      }
    end
    out[pi] = copy
  end
  return out
end

local baselines

function Trainers.captureBaselines(mod)
  if baselines then return baselines end
  baselines = {}
  local seen = {}
  for _, row in ipairs(MIX) do
    local class = row[1]
    if not seen[class] then
      seen[class] = true
      local t = mod.content.trainers:get(class)
      if t and t.parties then
        baselines[class] = copyParties(t.parties)
      end
    end
  end
  return baselines
end

function Trainers.clearBaselines()
  baselines = nil
end

-- Apply curated swaps from the captured vanilla baselines.  Safe to call
-- more than once (rebuilds from snapshot rather than stacking patches).
function Trainers.apply(mod)
  local snap = Trainers.captureBaselines(mod)
  local patched = {}
  for _, row in ipairs(MIX) do
    local class, pi, si, species, level = row[1], row[2], row[3], row[4], row[5]
    local base = snap[class]
    if base then
      if not patched[class] then
        patched[class] = copyParties(base)
      end
      local parties = patched[class]
      local slot = parties[pi] and parties[pi][si]
      if slot then
        slot.species = species
        if level then slot.level = level end
      end
    end
  end
  local n = 0
  for class, parties in pairs(patched) do
    mod.content.trainers:patch(class, { parties = parties })
    n = n + 1
  end
  return n
end

return Trainers
