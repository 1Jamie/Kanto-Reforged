local Strings = require("src.core.Strings")
local Rules = require("mods.Kanto-Reforged.battle.core.rules")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Stats = {}

function Stats.statChanges(ctx)
  local move = ctx.move or {}
  local changes = move.statChanges
  if not changes then return H.sayFail(ctx) end
  local target = (move.statTarget == "foe") and ctx.target or ctx.user
  if not ctx.adapter:changeStages(target, changes) then return H.sayFail(ctx) end
end

function Stats.statDown(ctx)
  local move = ctx.move or {}
  local changes = move.statChanges
  if not changes then return H.sayFail(ctx) end
  if not ctx.adapter:changeStages(ctx.target, changes) then return H.sayFail(ctx) end
end

function Stats.swagger(ctx)
  local target = ctx.target
  if Rules.substitute.blocks("stat_drop", target, ctx.adapter) then return H.sayFail(ctx) end
  if ctx.adapter:isConfused(target) then return H.sayFail(ctx) end
  ctx.adapter:changeStages(target, { { stat = "attack", change = 2 } })
  if ctx.adapter:abilityOf(target) == "OWN_TEMPO" then return end
  if ctx.adapter:applyConfusion(target, nil, ctx.user) and not ctx.adapter:isGen2() then
    ctx.adapter:say(Strings("%s became\nconfused!", H.displayName(ctx, target)))
  end
end

function Stats.psychUp(ctx)
  local target = ctx.target
  if not target or not target.stages then return H.sayFail(ctx) end
  ctx.user.stages = ctx.user.stages or {}
  for stat, val in pairs(target.stages) do
    ctx.user.stages[stat] = val
  end
  ctx.user.hazeStatReset = nil
  ctx.adapter:say(Strings("%s copied\nthe foe's stats!",
    H.displayName(ctx, ctx.user)))
end

function Stats.captivate(ctx)
  local Gender = require("mods.Kanto-Reforged.pokemon.gender")
  local userMon = ctx.adapter:mon(ctx.user)
  local targetMon = ctx.adapter:mon(ctx.target)
  if not Gender.canInfatuate(userMon, targetMon) then return H.sayFail(ctx) end
  local changes = ctx.move.statChanges or { { stat = "special", change = -2 } }
  H.applyStages(ctx, ctx.target, changes)
end

function Stats.acupressure(ctx)
  local stats = { "attack", "defense", "speed", "special", "accuracy", "evasion" }
  local pool = {}
  for _, s in ipairs(stats) do
    if (ctx.user.stages[s] or 0) < 6 then pool[#pool + 1] = s end
  end
  if #pool == 0 then return H.sayFail(ctx) end
  local rng = ctx.rng or ctx.adapter:rng()
  local idx = type(rng) == "function" and rng(1, #pool) or math.random(1, #pool)
  H.applyStages(ctx, ctx.user, { { stat = pool[idx], change = 2 } })
end

function Stats.stockpile(ctx)
  local n = ctx.user.expStockpile or 0
  if n >= 3 then return H.sayFail(ctx) end
  ctx.user.expStockpile = n + 1
  H.applyStages(ctx, ctx.user, {
    { stat = "defense", change = 1 },
    { stat = "special", change = 1 },
  })
  ctx.adapter:say(Strings("%s stockpiled %d!",
    H.displayName(ctx, ctx.user), ctx.user.expStockpile))
end

function Stats.powerTrick(ctx)
  local s = ctx.user.stages or {}
  s.attack, s.defense = s.defense or 0, s.attack or 0
  local cs = ctx.user.curStats
  if cs then cs.attack, cs.defense = cs.defense, cs.attack end
  ctx.user.hazeStatReset = nil
  ctx.adapter:say(Strings("%s swapped its\nATTACK and DEFENSE!",
    H.displayName(ctx, ctx.user)))
end

function Stats.powerSwap(ctx)
  local a, b = ctx.user.stages, ctx.target.stages
  if not a or not b then return H.sayFail(ctx) end
  a.attack, b.attack = b.attack or 0, a.attack or 0
  a.special, b.special = b.special or 0, a.special or 0
  ctx.user.hazeStatReset, ctx.target.hazeStatReset = nil, nil
  ctx.adapter:say(Strings("%s swapped all\nchanges to its\nATTACK and SP. ATK!",
    H.displayName(ctx, ctx.user)))
end

function Stats.guardSwap(ctx)
  local a, b = ctx.user.stages, ctx.target.stages
  if not a or not b then return H.sayFail(ctx) end
  a.defense, b.defense = b.defense or 0, a.defense or 0
  ctx.user.hazeStatReset, ctx.target.hazeStatReset = nil, nil
  ctx.adapter:say(Strings("%s swapped all\nchanges to its\nDEFENSE!",
    H.displayName(ctx, ctx.user)))
end

function Stats.speedSwap(ctx)
  local a, b = ctx.user.stages, ctx.target.stages
  if not a or not b then return H.sayFail(ctx) end
  a.speed, b.speed = b.speed or 0, a.speed or 0
  local ca, cb = ctx.user.curStats, ctx.target.curStats
  if ca and cb then ca.speed, cb.speed = cb.speed, ca.speed end
  ctx.user.hazeStatReset, ctx.target.hazeStatReset = nil, nil
  ctx.adapter:say(Strings("%s swapped\nSPEED with its target!",
    H.displayName(ctx, ctx.user)))
end

function Stats.charge(ctx)
  ctx.user.expCharged = true
  H.applyStages(ctx, ctx.user, { { stat = "special", change = 1 } })
  ctx.adapter:say(Strings("%s began\ncharging power!",
    H.displayName(ctx, ctx.user)))
end

function Stats.followMe(ctx)
  H.applyStages(ctx, ctx.user, { { stat = "evasion", change = 2 } })
end

function Stats.conversion2(ctx)
  local last = H.lastMove(ctx, ctx.target)
  local data = ctx.opts and ctx.opts.data
  local move = last and data and data.moves and data.moves[last]
  if not move or not move.type then return H.sayFail(ctx) end
  local TypeChart = require("src.battle.TypeChart")
  local candidates = {
    "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE", "FIGHTING",
    "POISON", "GROUND", "FLYING", "PSYCHIC_TYPE", "BUG", "ROCK",
    "GHOST", "DRAGON", "DARK", "STEEL",
  }
  local best, bestMult = nil, 10
  for _, t in ipairs(candidates) do
    local m = TypeChart.effectiveness(move.type, { t })
    if m < bestMult then bestMult, best = m, t end
  end
  if not best or bestMult >= 10 then return H.sayFail(ctx) end
  ctx.user.curTypes = { best }
  ctx.adapter:say(Strings("%s transformed\ninto the %s type!",
    H.displayName(ctx, ctx.user), best))
end

function Stats.memento(ctx)
  H.applyStages(ctx, ctx.target, {
    { stat = "attack", change = -2 },
    { stat = "special", change = -2 },
  })
  local mon = ctx.adapter:mon(ctx.user)
  if mon then mon.hp = 0 end
  ctx.adapter:emitFaint(ctx.user)
  ctx.adapter:say(Strings("%s went all out\nand fainted!",
    H.displayName(ctx, ctx.user)))
end

return Stats
