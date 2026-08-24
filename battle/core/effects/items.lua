local Strings = require("src.core.Strings")
local HeldItems = require("mods.Kanto-Reforged.items.held_items")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Items = {}

function Items.trick(ctx)
  local a = ctx.adapter:mon(ctx.user)
  local b = ctx.adapter:mon(ctx.target)
  if not a or not b then return H.sayFail(ctx) end
  if not a.heldItem and not b.heldItem then return H.sayFail(ctx) end
  a.heldItem, b.heldItem = b.heldItem, a.heldItem
  ctx.adapter:say(Strings("%s switched\nitems with its target!",
    H.displayName(ctx, ctx.user)))
  ctx.adapter:tickStatusBerry(ctx.user)
  ctx.adapter:tickStatusBerry(ctx.target)
end

function Items.recycle(ctx)
  local last = ctx.user.expLastConsumedItem
  local mon = ctx.adapter:mon(ctx.user)
  if not last or (mon and mon.heldItem) then return H.sayFail(ctx) end
  mon.heldItem = last
  ctx.user.expLastConsumedItem = nil
  local def = HeldItems.def(last)
  ctx.adapter:say(Strings("%s found one\n%s!",
    H.displayName(ctx, ctx.user), def and def.name or last))
end

function Items.bestow(ctx)
  local a = ctx.adapter:mon(ctx.user)
  local b = ctx.adapter:mon(ctx.target)
  if not a or not a.heldItem or not b or b.heldItem then return H.sayFail(ctx) end
  b.heldItem = a.heldItem
  a.heldItem = nil
  local def = HeldItems.def(b.heldItem)
  ctx.adapter:say(Strings("%s gave its\n%s!",
    H.displayName(ctx, ctx.user), def and def.name or b.heldItem))
  ctx.adapter:tickStatusBerry(ctx.target)
end

return Items
