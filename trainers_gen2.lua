-- Gen2 trainer party guests for Gold Kanto leaders / E4 / rival.
local TrainersGen2 = {}

-- classId -> memberId patterns or all members get a Gen3 guest on last slot.
local GUESTS = {
  BROCK = { "ARON", "GEODUDE" },
  MISTY = { "LOTAD", "CORPHISH" },
  FALKNER = { "TAILLOW", "SWABLU" }, -- Johto gym light touch
  BUGSY = { "NINCADA", "SURSKIT" },
  WHITNEY = { "SKITTY", "SPOINK" },
  MORTY = { "SHUPPET", "DUSKULL" },
  CHUCK = { "MAKUHITA", "MEDITITE" },
  JASMINE = { "ARON", "MAWILE" },
  PRYCE = { "SNORUNT", "SPHEAL" },
  CLAIR = { "BAGON", "SWABLU" },
  -- Kanto gym rematch / Gen2 Kanto leaders
  LT_SURGE = { "ELECTRIKE", "PLUSLE" },
  ERIKA = { "SHROOMISH", "ROSELIA" },
  JANINE = { "GULPIN", "SEVIPER" },
  SABRINA = { "RALTS", "SPOINK" },
  BLAINE = { "NUMEL", "TORKOAL" },
  BLUE = { "SLAKING", "AGGRON", "SALAMENCE" },
  WILL = { "GARDEVOIR", "CLAYDOL" },
  KOGA = { "SEVIPER", "CROBAT" },
  BRUNO = { "HARIYAMA", "AGGRON" },
  KAREN = { "ABSOL", "HOUNDOOM" },
  LANCE = { "SALAMENCE", "KINGDRA" },
}

local function copyParty(party)
  local out = {}
  for i, mon in ipairs(party or {}) do
    local row = {}
    for k, v in pairs(mon) do row[k] = v end
    out[i] = row
  end
  return out
end

function TrainersGen2.install(mod)
  mod.hooks:wrap("trainer.party", function(next, classId, memberId, party)
    local result = next(classId, memberId, party)
    local guests = GUESTS[classId]
    if not guests or type(result) ~= "table" or #result == 0 then
      return result
    end
    local SpeciesScope = require("mods.Kanto-Reforged.species_scope")
    -- Rotate guest when a second option exists (still one mon max).
    local guestId = guests[1]
    local mid = tostring(memberId or "")
    if guests[2] and mod.content.pokemon:get(guests[2])
        and (#mid % 2 == 0) then
      guestId = guests[2]
    end
    if not mod.content.pokemon:get(guestId) then
      return result
    end
    if not SpeciesScope.allowsTrainerGuest(mod, classId, guestId) then
      return result
    end
    local out = copyParty(result)
    local last = out[#out]
    local level = (last and last.level) or 50
    -- Avoid dup if already present
    for _, mon in ipairs(out) do
      if mon.species == guestId then return result end
    end
    out[#out + 1] = { level = level, species = guestId }
    return out
  end)
  mod.log:info("Gen2 trainer.party Gen3 guests installed")
end

return TrainersGen2
