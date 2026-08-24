local Strings = require("src.core.Strings")
local Gender = require("mods.Kanto-Reforged.pokemon.gender")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Volatiles = {}

local ENCORE_BLOCK = {
  ENCORE = true, STRUGGLE = true, MIRROR_MOVE = true, METRONOME = true, SKETCH = true,
}

function Volatiles.protect(ctx)
  local user = ctx.user
  local streak = user.expProtectStreak or 0
  if streak > 0 then
    local denom = 2 ^ math.min(streak, 8)
    local rng = ctx.rng or ctx.adapter:rng()
    local roll
    if type(rng) == "function" then
      local ok, v = pcall(rng, 0, denom - 1)
      roll = ok and v or math.random(0, denom - 1)
    else
      roll = math.random(0, denom - 1)
    end
    if roll ~= 0 then return H.sayFail(ctx) end
  end
  user.expProtected = true
  user.expProtectStreak = streak + 1
  ctx.adapter:say(Strings("%s\nprotected itself!", H.displayName(ctx, user)))
end

function Volatiles.endure(ctx)
  ctx.user.expEnduring = true
  ctx.adapter:say(Strings("%s braced\nitself!", H.displayName(ctx, ctx.user)))
end

function Volatiles.encore(ctx)
  local target = ctx.target
  local last = H.lastMove(ctx, target)
  if not last or ENCORE_BLOCK[last] then return H.sayFail(ctx) end
  local has = false
  for _, mv in ipairs(H.preparedMoves(ctx, target)) do
    if mv.id == last and (mv.pp or 0) > 0 then has = true break end
  end
  if not has then return H.sayFail(ctx) end
  target.expEncoreMove = last
  local rng = ctx.rng or ctx.adapter:rng()
  local turns
  if type(rng) == "function" then
    local ok, v = pcall(rng, 2, 6)
    turns = ok and v or math.random(2, 6)
  else
    turns = math.random(2, 6)
  end
  target.expEncoreTurns = turns
  ctx.adapter:say(Strings("%s\ngot an ENCORE!", H.displayName(ctx, target)))
end

function Volatiles.perishSong(ctx)
  for _, b in ipairs({ ctx.user, ctx.target }) do
    if b and ctx.adapter:mon(b) and not b.expPerishTurns then
      if ctx.adapter:abilityOf(b) ~= "SOUNDPROOF" then
        b.expPerishTurns = 4
      end
    end
  end
  ctx.adapter:say(Strings("All affected POKEMON\nwill faint in three\nturns!"))
end

function Volatiles.attract(ctx)
  local target = ctx.target
  if ctx.adapter:abilityOf(target) == "OBLIVIOUS" then return H.sayFail(ctx) end
  if target.expInfatuated then return H.sayFail(ctx) end
  local userMon = ctx.adapter:mon(ctx.user)
  local targetMon = ctx.adapter:mon(target)
  if not Gender.canInfatuate(userMon, targetMon) then return H.sayFail(ctx) end
  target.expInfatuated = true
  for _, m in ipairs(Gender.infatuateMessages(target)) do
    ctx.adapter:say(m)
  end
end

function Volatiles.spite(ctx)
  local target = ctx.target
  local last = H.lastMove(ctx, target)
  if not last then return H.sayFail(ctx) end
  local cut = 0
  for _, mv in ipairs(H.preparedMoves(ctx, target)) do
    if mv.id == last and (mv.pp or 0) > 0 then
      local lost = math.min(mv.pp, 4)
      mv.pp = mv.pp - lost
      cut = lost
      break
    end
  end
  if cut <= 0 then return H.sayFail(ctx) end
  ctx.adapter:say(Strings("Reduced %s's\n%s by %d!",
    H.displayName(ctx, target), last, cut))
end

function Volatiles.torment(ctx)
  if ctx.target.expTormented then return H.sayFail(ctx) end
  ctx.target.expTormented = true
  ctx.adapter:say(Strings("%s was\nsubjected to TORMENT!",
    H.displayName(ctx, ctx.target)))
end

return Volatiles
