local Strings = require("src.core.Strings")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Hazards = {}

function Hazards.spikes(ctx)
  local side = H.foeSide(ctx)
  if not side then return H.sayFail(ctx) end
  side.hazards = side.hazards or {}
  local h = H.findHazard(ctx.adapter, side, "SPIKES")
  if h then
    if (h.layers or 1) >= 3 then return H.sayFail(ctx) end
    h.layers = (h.layers or 1) + 1
  else
    side.hazards[#side.hazards + 1] = { id = "SPIKES", layers = 1 }
  end
  side.spikes = true
  ctx.adapter:say(Strings("SPIKES scattered\nall around the\nfoe's side!"))
end

function Hazards.stealthRock(ctx)
  local side = H.foeSide(ctx)
  if not side then return H.sayFail(ctx) end
  side.hazards = side.hazards or {}
  if H.findHazard(ctx.adapter, side, "STEALTH_ROCK") then return H.sayFail(ctx) end
  side.hazards[#side.hazards + 1] = { id = "STEALTH_ROCK" }
  ctx.adapter:say(Strings(
    "Pointed stones float\nin the air around\nthe foe's side!"))
end

function Hazards.toxicSpikes(ctx)
  local side = H.foeSide(ctx)
  if not side then return H.sayFail(ctx) end
  side.hazards = side.hazards or {}
  local h = H.findHazard(ctx.adapter, side, "TOXIC_SPIKES")
  if h then
    if (h.layers or 1) >= 2 then return H.sayFail(ctx) end
    h.layers = 2
  else
    side.hazards[#side.hazards + 1] = { id = "TOXIC_SPIKES", layers = 1 }
  end
  ctx.adapter:say(Strings(
    "Poison spikes were\nscattered around\nthe foe's side!"))
end

return Hazards
