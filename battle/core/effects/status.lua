local Strings = require("src.core.Strings")
local Rules = require("mods.Kanto-Reforged.battle.core.rules")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Status = {}

function Status.burn(ctx)
  if Rules.substitute.blocks("burn", ctx.target, ctx.adapter) then return H.sayFail(ctx) end
  if ctx.opts and ctx.opts.inflict then
    local msgs = ctx.opts.inflict(ctx.target, "BRN", {
      moveType = ctx.move and ctx.move.type, source = ctx.move and ctx.move.id,
    })
    if type(msgs) ~= "table" or #msgs == 0 then return H.sayFail(ctx) end
    for _, m in ipairs(msgs) do ctx.adapter:say(m) end
    return
  end
  if ctx.adapter:applyStatus(ctx.target, "burn", ctx.user,
      { moveType = ctx.move and ctx.move.type }) then
    ctx.adapter:say(Strings("%s was burned!", H.displayName(ctx, ctx.target)))
  else
    H.sayFail(ctx)
  end
end

function Status.taunt(ctx)
  if Rules.substitute.blocks("taunt", ctx.target, ctx.adapter) then return H.sayFail(ctx) end
  ctx.target.expTauntedTurns = 3
  ctx.adapter:say(Strings("%s fell for\nthe TAUNT!", H.displayName(ctx, ctx.target)))
end

function Status.yawn(ctx)
  if Rules.substitute.blocks("yawn", ctx.target, ctx.adapter) then return H.sayFail(ctx) end
  if ctx.adapter:status(ctx.target) then return H.sayFail(ctx) end
  if ctx.target.expYawnTurns then return H.sayFail(ctx) end
  ctx.target.expYawnTurns = 2
  ctx.adapter:say(Strings("%s grew\ndrowsy!", H.displayName(ctx, ctx.target)))
end

return Status
