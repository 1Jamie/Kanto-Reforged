local Strings = require("src.core.Strings")
local Capabilities = require("mods.Kanto-Reforged.battle.core.capabilities")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Screens = {}

function Screens.safeguard(ctx)
  local side = H.ownSide(ctx)
  if not side then return H.sayFail(ctx) end
  if (side.expSafeguardTurns or 0) > 0 then return H.sayFail(ctx) end
  side.expSafeguardTurns = Capabilities.safeguardDefaultTurns
  ctx.adapter:say(Strings("%s's team became\ncloaked in a\nmystic veil!",
    H.displayName(ctx, ctx.user)))
end

function Screens.tailwind(ctx)
  local side = H.ownSide(ctx)
  if not side then return H.sayFail(ctx) end
  if (side.expTailwindTurns or 0) > 0 then return H.sayFail(ctx) end
  side.expTailwindTurns = Capabilities.tailwindDefaultTurns
  ctx.adapter:say(Strings("The Tailwind blew from\nbehind %s!",
    H.displayName(ctx, ctx.user)))
end

function Screens.trickRoom(ctx)
  local turns = ctx.adapter:fieldGet("expTrickRoomTurns")
  if turns and turns > 0 then
    ctx.adapter:fieldSet("expTrickRoomTurns", nil)
    ctx.adapter:say(Strings("The twisted dimensions\nreturned to normal!"))
    return
  end
  ctx.adapter:fieldSet("expTrickRoomTurns", Capabilities.trickRoomDefaultTurns)
  ctx.adapter:say(Strings("%s twisted\nthe dimensions!",
    H.displayName(ctx, ctx.user)))
end

function Screens.luckyChant(ctx)
  local side = H.ownSide(ctx)
  if not side then return H.sayFail(ctx) end
  side.expLuckyChantTurns = Capabilities.screenDefaultTurns
  ctx.adapter:say(Strings("The LUCKY CHANT\nshielded %s from\ncritical hits!",
    H.displayName(ctx, ctx.user)))
end

return Screens
