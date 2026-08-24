local Strings = require("src.core.Strings")
local Rules = require("mods.Kanto-Reforged.battle.core.rules")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Setup = {}

local function hasType(battler, typeId)
  for _, t in ipairs(battler.curTypes or {}) do
    if t == typeId then return true end
  end
  return false
end

function Setup.meanLook(ctx)
  if ctx.target.expTrapped or hasType(ctx.target, "GHOST") then
    return H.sayFail(ctx)
  end
  if Rules.partialTrap.ghostImmune(ctx.adapter:types(ctx.target)) then
    return H.sayFail(ctx)
  end
  ctx.target.expTrapped = true
  ctx.adapter:say(Strings("%s can no\nlonger escape!",
    H.displayName(ctx, ctx.target)))
end

function Setup.foresight(ctx)
  ctx.target.expIdentified = true
  ctx.adapter:say(Strings("%s was\nidentified!", H.displayName(ctx, ctx.target)))
end

function Setup.lockOn(ctx)
  ctx.target.expLockedOn = true
  ctx.adapter:say(Strings("%s took aim\nat %s!",
    H.displayName(ctx, ctx.user), H.displayName(ctx, ctx.target)))
end

function Setup.nightmare(ctx)
  local st = ctx.adapter:status(ctx.target)
  if st ~= "SLP" and st ~= "sleep" then return H.sayFail(ctx) end
  if ctx.target.expNightmare then return H.sayFail(ctx) end
  ctx.target.expNightmare = true
  ctx.adapter:say(Strings("%s began\nhaving a NIGHTMARE!",
    H.displayName(ctx, ctx.target)))
end

function Setup.destinyBond(ctx)
  ctx.user.expDestinyBond = true
  ctx.adapter:say(Strings("%s is hoping\nto take its attacker\nwith it!",
    H.displayName(ctx, ctx.user)))
end

function Setup.embargo(ctx)
  if (ctx.target.expEmbargoTurns or 0) > 0 then return H.sayFail(ctx) end
  ctx.target.expEmbargoTurns = 5
  ctx.adapter:say(Strings("%s can't use\nitems anymore!",
    H.displayName(ctx, ctx.target)))
end

function Setup.healBlock(ctx)
  if (ctx.target.expHealBlockTurns or 0) > 0 then return H.sayFail(ctx) end
  ctx.target.expHealBlockTurns = 5
  ctx.adapter:say(Strings("%s was prevented\nfrom healing!",
    H.displayName(ctx, ctx.target)))
end

function Setup.magicCoat(ctx)
  ctx.user.expMagicCoat = true
  ctx.adapter:say(Strings("%s shrouded\nitself with MAGIC COAT!",
    H.displayName(ctx, ctx.user)))
end

function Setup.grudge(ctx)
  ctx.user.expGrudge = true
  ctx.adapter:say(Strings("%s wants the\nfoe to take a GRUDGE!",
    H.displayName(ctx, ctx.user)))
end

function Setup.futureSight(ctx)
  local side = ctx.adapter:foeSide(ctx.user)
  if not side then return H.sayFail(ctx) end
  side.tokens = side.tokens or {}
  for _, tok in ipairs(side.tokens) do
    if tok.id == "EXP_FUTURE_SIGHT" then return H.sayFail(ctx) end
  end
  local move = ctx.move or {}
  local mon = ctx.adapter:mon(ctx.user)
  local power = move.power or 120
  local level = mon and mon.level or 50
  local dmg = math.max(1, math.floor(level * power / 50) + 2)
  local label = move.name or "FUTURE SIGHT"
  side.tokens[#side.tokens + 1] = {
    id = "EXP_FUTURE_SIGHT",
    turns = 3,
    damage = dmg,
    label = label,
  }
  ctx.adapter:say(Strings("%s foresaw\nan attack!",
    H.displayName(ctx, ctx.user)))
end

function Setup.curse(ctx)
  local user = ctx.user
  if hasType(user, "GHOST") then
    local mon = ctx.adapter:mon(user)
    if not mon or not mon.stats then return H.sayFail(ctx) end
    local cost = math.max(1, math.floor(mon.stats.hp / 2))
    if (mon.hp or 0) <= cost then return H.sayFail(ctx) end
    if ctx.target.expCursed then return H.sayFail(ctx) end
    mon.hp = mon.hp - cost
    ctx.target.expCursed = true
    ctx.adapter:say(Strings("%s cut its own HP\nand laid a CURSE\non %s!",
      H.displayName(ctx, user), H.displayName(ctx, ctx.target)))
    return
  end
  local changes = {
    { stat = "speed", change = -1 },
    { stat = "attack", change = 1 },
    { stat = "defense", change = 1 },
  }
  if not ctx.adapter:changeStages(user, changes) then return H.sayFail(ctx) end
end

function Setup.mudSport(ctx)
  ctx.adapter:fieldSet("expMudSport", true)
  ctx.adapter:say(Strings("Electricity's power\nwas weakened!"))
end

function Setup.waterSport(ctx)
  ctx.adapter:fieldSet("expWaterSport", true)
  ctx.adapter:say(Strings("Fire's power\nwas weakened!"))
end

function Setup.rolePlay(ctx)
  local foeAb = ctx.adapter:abilityOf(ctx.target)
  if not foeAb then return H.sayFail(ctx) end
  ctx.user.expTracedAbility = foeAb
  ctx.adapter:say(Strings("%s copied\n%s's ability!",
    H.displayName(ctx, ctx.user), H.displayName(ctx, ctx.target)))
end

function Setup.skillSwap(ctx)
  local a = ctx.adapter:abilityOf(ctx.user)
  local b = ctx.adapter:abilityOf(ctx.target)
  if not a and not b then return H.sayFail(ctx) end
  ctx.user.expTracedAbility = b
  ctx.target.expTracedAbility = a
  ctx.adapter:say(Strings("%s swapped\nabilities with its target!",
    H.displayName(ctx, ctx.user)))
end

function Setup.worrySeed(ctx)
  ctx.target.expTracedAbility = "INSOMNIA"
  ctx.adapter:say(Strings("%s acquired\nINSOMNIA!",
    H.displayName(ctx, ctx.target)))
end

function Setup.imprison(ctx)
  ctx.user.expImprison = true
  ctx.adapter:say(Strings("%s sealed\nthe opponent's moves!",
    H.displayName(ctx, ctx.user)))
end

function Setup.snatch(ctx)
  ctx.user.expSnatch = true
  ctx.adapter:say(Strings("%s waits for a\ntarget to make a move!",
    H.displayName(ctx, ctx.user)))
end

function Setup.sketch(ctx)
  local last = H.lastMove(ctx, ctx.target)
  if not last or last == "SKETCH" or last == "STRUGGLE"
      or last == "CHATTER" or last == "SHADOW_FORCE" then
    return H.sayFail(ctx)
  end
  local slot
  for _, mv in ipairs(H.preparedMoves(ctx, ctx.user)) do
    if mv.id == "SKETCH" then slot = mv break end
  end
  if not slot then return H.sayFail(ctx) end
  local data = ctx.opts and ctx.opts.data
  local def = data and data.moves and data.moves[last]
  slot.id = last
  slot.pp = def and def.pp or 5
  local userMon = ctx.adapter:mon(ctx.user)
  if userMon and userMon.moves then
    for _, mv in ipairs(userMon.moves) do
      if mv.id == "SKETCH" then
        mv.id = last
        mv.pp = slot.pp
        break
      end
    end
  end
  ctx.adapter:say(Strings("%s learned\n%s!",
    H.displayName(ctx, ctx.user), def and def.name or last))
end

function Setup.camouflage(ctx)
  ctx.user.curTypes = { "NORMAL" }
  ctx.adapter:say(Strings("%s's type\nchanged to NORMAL!",
    H.displayName(ctx, ctx.user)))
end

function Setup.gastroAcid(ctx)
  if ctx.target.expAbilitySuppressed then return H.sayFail(ctx) end
  ctx.target.expAbilitySuppressed = true
  ctx.target.expTracedAbility = nil
  ctx.adapter:say(Strings("%s's ability\nwas suppressed!",
    H.displayName(ctx, ctx.target)))
end

function Setup.simpleBeam(ctx)
  ctx.target.expTracedAbility = "SIMPLE"
  ctx.target.expAbilitySuppressed = nil
  ctx.adapter:say(Strings("%s acquired\nSIMPLE!",
    H.displayName(ctx, ctx.target)))
end

function Setup.entrainment(ctx)
  local Abilities = require("mods.Kanto-Reforged.battle.abilities")
  local a = ctx.adapter:abilityOf(ctx.user)
  if not a then return H.sayFail(ctx) end
  ctx.target.expTracedAbility = a
  ctx.target.expAbilitySuppressed = nil
  ctx.adapter:say(Strings("%s made %s\nmatch its ability!",
    H.displayName(ctx, ctx.user), H.displayName(ctx, ctx.target)))
end

function Setup.batonPass(ctx)
  local party = ctx.adapter:partyMons(ctx.user)
  local hasOther = false
  local userMon = ctx.adapter:mon(ctx.user)
  for _, mon in ipairs(party) do
    if mon and mon.hp and mon.hp > 0 and mon ~= userMon then
      hasOther = true
      break
    end
  end
  if not hasOther then return H.sayFail(ctx) end
  local stages = {}
  for k, v in pairs(ctx.user.stages or {}) do stages[k] = v end
  ctx.user.expBatonPass = {
    stages = stages,
    confusedTurns = ctx.user.confusedTurns,
    focusEnergy = ctx.user.focusEnergy,
    substituteHP = ctx.user.substituteHP,
    expIngrain = ctx.user.expIngrain,
    expAquaRing = ctx.user.expAquaRing,
    expPerishTurns = ctx.user.expPerishTurns,
    expCursed = ctx.user.expCursed,
    expTrapped = ctx.user.expTrapped,
    leechSeeded = ctx.user.leechSeeded,
  }
  ctx.user.expPendingBatonOpen = true
  ctx.adapter:say(Strings("%s went back!", H.displayName(ctx, ctx.user)))
end

function Setup.allySwitch(ctx)
  ctx.user.expProtected = true
  ctx.adapter:say(Strings("%s protected\nitself!",
    H.displayName(ctx, ctx.user)))
end

return Setup
