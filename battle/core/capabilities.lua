-- Single source of truth for battle rules (always Gen3 MODERN).

local Capabilities = {
  gen3Crit = true,
  gen3PartialTrap = true,
  residualAfterMove = false,
  weatherChipDenom = 16,
  partialTrapChipDenom = 16,
  partialTrapMinTurns = 2,
  partialTrapMaxTurns = 5,
  screenDefaultTurns = 5,
  safeguardDefaultTurns = 5,
  tailwindDefaultTurns = 4,
  trickRoomDefaultTurns = 5,
}

function Capabilities.get()
  return Capabilities
end

return Capabilities
