local Strings = require("src.core.Strings")
local Rules = require("mods.Kanto-Reforged.battle.core.rules")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Healing = {}

function Healing.refresh(ctx)
  local st = ctx.adapter:status(ctx.user)
  local ok = st == "BRN" or st == "PSN" or st == "PAR"
    or st == "TOX" or st == "burn" or st == "poison"
    or st == "paralyze" or st == "toxic"
  if not ok then return H.sayFail(ctx) end
  if ctx.opts and ctx.opts.cure then
    ctx.opts.cure(ctx.user)
  else
    local mon = ctx.adapter:mon(ctx.user)
    if mon then mon.status = nil end
  end
  ctx.adapter:say(Strings("%s's status\nreturned to normal!",
    H.displayName(ctx, ctx.user)))
end

function Healing.ingrain(ctx)
  if ctx.user.expIngrain then return H.sayFail(ctx) end
  ctx.user.expIngrain = true
  ctx.user.expTrapped = true
  ctx.adapter:say(Strings("%s planted its roots!", H.displayName(ctx, ctx.user)))
end

function Healing.aquaRing(ctx)
  ctx.user.expAquaRing = true
  ctx.adapter:say(Strings("%s surrounded\nitself with a veil of water!",
    H.displayName(ctx, ctx.user)))
end

function Healing.bellyDrum(ctx)
  local mon = ctx.adapter:mon(ctx.user)
  if not mon or not mon.stats then return H.sayFail(ctx) end
  local cost = math.floor(mon.stats.hp / 2)
  if (mon.hp or 0) <= cost then return H.sayFail(ctx) end
  mon.hp = mon.hp - cost
  local stages = ctx.user.stages or ctx.adapter:stages(ctx.user)
  if stages then stages.attack = 6 end
  ctx.user.hazeStatReset = nil
  ctx.adapter:say(Strings("%s cut its own HP\nand maximized\nATTACK!",
    H.displayName(ctx, ctx.user)))
end

function Healing.wish(ctx)
  local side = ctx.adapter:ownSide(ctx.user)
  if not side then return H.sayFail(ctx) end
  for _, tok in ipairs(side.tokens or {}) do
    if tok.id == "EXP_WISH" then return H.sayFail(ctx) end
  end
  side.tokens = side.tokens or {}
  local mon = ctx.adapter:mon(ctx.user)
  local maxHp = mon and mon.stats and mon.stats.hp or ctx.adapter:maxHp(ctx.user)
  local heal = math.max(1, math.floor(maxHp / 2))
  side.tokens[#side.tokens + 1] = {
    id = "EXP_WISH",
    turns = 2,
    heal = heal,
  }
  ctx.adapter:say(Strings("%s made\na WISH!", H.displayName(ctx, ctx.user)))
end

function Healing.healBell(ctx)
  for _, mon in ipairs(ctx.adapter:partyMons(ctx.user)) do
    if mon and mon.status then mon.status = nil end
  end
  ctx.adapter:clearStatus(ctx.user)
  ctx.user.toxicCounter = nil
  local move = ctx.move or {}
  local label = move.id == "AROMATHERAPY" and "A soothing aroma" or "A bell chimed"
  ctx.adapter:say(Strings("%s wafted\nthrough the area!", label))
end

function Healing.painSplit(ctx)
  if Rules.substitute.blocks("pain_split", ctx.target, ctx.adapter) then return H.sayFail(ctx) end
  local userMon = ctx.adapter:mon(ctx.user)
  local targetMon = ctx.adapter:mon(ctx.target)
  if not userMon or not targetMon then return H.sayFail(ctx) end
  local avg = math.floor(((userMon.hp or 0) + (targetMon.hp or 0)) / 2)
  userMon.hp = math.min(userMon.stats.hp, avg)
  targetMon.hp = math.min(targetMon.stats.hp, avg)
  ctx.adapter:say(Strings("The battlers shared\ntheir pain!"))
end

function Healing.swallow(ctx)
  local n = ctx.user.expStockpile or 0
  if n <= 0 then return H.sayFail(ctx) end
  local frac = ({ 4, 2, 1 })[n] or 1
  local mon = ctx.adapter:mon(ctx.user)
  if not mon or not mon.stats then return H.sayFail(ctx) end
  local heal = math.max(1, math.floor(mon.stats.hp / frac))
  ctx.user.expStockpile = nil
  if (ctx.user.expHealBlockTurns or 0) > 0 then
    ctx.adapter:say(Strings("%s can't restore HP\nbecause of HEAL BLOCK!",
      H.displayName(ctx, ctx.user)))
    return
  end
  if (mon.hp or 0) >= mon.stats.hp then return H.sayFail(ctx) end
  mon.hp = math.min(mon.stats.hp, (mon.hp or 0) + heal)
  ctx.adapter:say(Strings("%s regained\nhealth!", H.displayName(ctx, ctx.user)))
end

function Healing.healingWish(ctx)
  local side = ctx.adapter:ownSide(ctx.user)
  if side then side.expHealingWish = true end
  local mon = ctx.adapter:mon(ctx.user)
  if mon then mon.hp = 0 end
  ctx.adapter:emitFaint(ctx.user)
  ctx.adapter:say(Strings("%s's HEALING WISH\ncame true!",
    H.displayName(ctx, ctx.user)))
end

return Healing
