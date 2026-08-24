-- Shared effect helpers (adapter-only I/O).

local Strings = require("src.core.Strings")
local Helpers = {}

function Helpers.foeSide(ctx)
  return ctx.adapter:foeSide(ctx.user)
end

function Helpers.ownSide(ctx)
  return ctx.adapter:ownSide(ctx.user)
end

function Helpers.findHazard(adapter, side, id)
  if adapter and type(adapter.findHazard) == "function" then
    return adapter:findHazard(side, id)
  end
  if not side or not side.hazards then return nil end
  for _, h in ipairs(side.hazards) do
    if h.id == id then return h end
  end
  return nil
end

function Helpers.sayFail(ctx)
  if ctx.adapter and type(ctx.adapter.sayFail) == "function" then
    ctx.adapter:sayFail()
  elseif ctx.adapter and type(ctx.adapter.say) == "function" then
    ctx.adapter:say("But, it failed!")
  end
end

function Helpers.displayName(ctx, battler)
  return ctx.adapter:displayName(battler or ctx.user)
end

function Helpers.applyStages(ctx, who, changes)
  if ctx.opts and type(ctx.opts.changeStage) == "function" then
    local msgs = {}
    for _, sc in ipairs(changes or {}) do
      local piece = ctx.opts.changeStage(who, sc.stat, sc.change)
      if type(piece) == "table" then
        for _, m in ipairs(piece) do
          msgs[#msgs + 1] = m
          ctx.adapter:say(m)
        end
      elseif piece then
        msgs[#msgs + 1] = piece
        ctx.adapter:say(piece)
      end
    end
    if #msgs == 0 then
      ctx.adapter:sayFail()
    end
    return msgs
  end
  if not ctx.adapter:changeStages(who, changes) then
    ctx.adapter:sayFail()
  end
  return {}
end

function Helpers.hasType(battler, typeId)
  for _, t in ipairs(battler.curTypes or {}) do
    if t == typeId then return true end
  end
  return false
end

function Helpers.lastMove(ec, battler)
  if ec.adapter and type(ec.adapter.lastMoveOf) == "function" then
    return ec.adapter:lastMoveOf(battler)
  end
  return battler and battler.lastMove
end

function Helpers.preparedMoves(ec, battler)
  if ec.adapter and type(ec.adapter.preparedMoves) == "function" then
    return ec.adapter:preparedMoves(battler)
  end
  battler = battler or ec.user
  return battler and (battler.curMoves or battler.moves) or {}
end

return Helpers
