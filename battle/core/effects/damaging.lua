local Strings = require("src.core.Strings")
local PartialTrap = require("mods.Kanto-Reforged.battle.partial_trap")
local Rules = require("mods.Kanto-Reforged.battle.core.rules")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Damaging = {}

function Damaging.damageStatSide(ec, _raw)
  local move = ec.move or {}
  local chance = move.statChance or 10
  if ec.adapter:abilityOf(ec.user) == "SERENE_GRACE" then
    chance = chance * 2
  end
  local threshold = math.floor(chance * 256 / 100)
  local rng = ec.rng or ec.adapter:rng()
  if type(rng) == "function" and rng(0, 255) >= threshold then return {} end
  if Rules.substitute.hasSubstitute(ec.target, ec.adapter) then return {} end
  local targetSelf = (move.statTarget or "target") == "user"
  local who = targetSelf and ec.user or ec.target
  return H.applyStages(ec, who, move.statChanges)
end

function Damaging.damageUserStatAfter(ec, _raw)
  local move = ec.move or {}
  if not move.statChanges then return end
  local targetSelf = (move.statTarget or "user") == "user"
  local who = targetSelf and ec.user or ec.target
  H.applyStages(ec, who, move.statChanges)
end

function Damaging.flinchSecondary(ec, _raw)
  if Rules.substitute.hasSubstitute(ec.target, ec.adapter) then return {} end
  ec.target.flinched = true
  return {}
end

function Damaging.secretPowerSecondary(ec, _raw)
  if Rules.substitute.hasSubstitute(ec.target, ec.adapter) then return {} end
  local rng = ec.rng or ec.adapter:rng()
  if type(rng) == "function" and rng(0, 255) >= 77 then return {} end
  if ec.opts and ec.opts.inflict then
    return ec.opts.inflict(ec.target, "PAR", {
      secondary = true, moveType = ec.move and ec.move.type, source = "SECRET_POWER",
    }) or {}
  end
  ec.adapter:applyStatus(ec.target, "paralyze", ec.user,
    { secondary = true, moveType = ec.move and ec.move.type })
  return {}
end

function Damaging.brickBreakAfter(ec, _raw)
  if ec.adapter:clearScreens(ec.target) then
    ec.adapter:say(Strings("The wall shattered!"))
  end
end

function Damaging.falseSwipeChoose(ec, raw)
  local compute = raw.computeDamage or ec.opts.computeDamage
  if type(compute) ~= "function" then return nil end
  local dmg, info = compute()
  local mon = ec.adapter:mon(ec.target)
  if dmg and mon and dmg >= (mon.hp or 0) then
    dmg = math.max(0, (mon.hp or 0) - 1)
  end
  return dmg, info
end

function Damaging.furyCutterAfter(ec, _raw)
  local n = ec.user.expFuryCutter or 0
  ec.user.expFuryCutter = math.min(4, n + 1)
end

function Damaging.furyCutterMiss(ec, _raw)
  ec.user.expFuryCutter = nil
end

function Damaging.smellingSaltsAfter(ec, _raw)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  if not BattleCompat.hasStatus(ec.target, "PAR", "paralyze") then return end
  if ec.adapter:clearStatus(ec.target) then
    ec.adapter:say(Strings("%s was cured\nof paralysis!",
      H.displayName(ec, ec.target)))
  end
end

function Damaging.rolloutAfter(ec, raw)
  local user = ec.user
  local n = (user.expRollout or 0) + 1
  user.expRolloutMove = raw.moveInst or ec.opts.moveInst
  if n >= 5 then
    user.expRollout = nil
    user.expRolloutMove = nil
  else
    user.expRollout = n
  end
end

function Damaging.rolloutMiss(ec, _raw)
  ec.user.expRollout = nil
  ec.user.expRolloutMove = nil
end

function Damaging.fakeOutGate(ec, _raw)
  if not ec.user.expJustEntered then
    return false, Strings("But, it failed!")
  end
  return true
end

function Damaging.fakeOutAfter(ec, _raw)
  if Rules.substitute.hasSubstitute(ec.target, ec.adapter) then return end
  ec.target.flinched = true
end

--- Sucker Punch: fail unless foe is committed to a damaging move and hasn't acted.
function Damaging.suckerPunchGate(ec, _raw)
  local MoveEffects = require("mods.Kanto-Reforged.battle.move_effects")
  local target = ec.target
  if not target then return false, Strings("But, it failed!") end
  if target.expActedThisTurn then
    return false, Strings("But, it failed!")
  end
  local pending = MoveEffects.pendingMoveOf(target)
  if not pending then return false, Strings("But, it failed!") end
  local data = (ec.opts and ec.opts.data)
      or (ec.adapter and ec.adapter.battle and ec.adapter.battle.data)
  local def = data and data.moves and data.moves[pending]
  if not def or (def.power or 0) <= 0 then
    return false, Strings("But, it failed!")
  end
  return true
end

function Damaging.wakeUpSlapAfter(ec, _raw)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  if not BattleCompat.hasStatus(ec.target, "SLP", "sleep") then return end
  if ec.adapter:clearStatus(ec.target) then
    ec.adapter:say(Strings("%s woke up!", H.displayName(ec, ec.target)))
  end
end

function Damaging.metalBurstChoose(ec, _raw)
  local taken = ec.user.expDamageTakenThisTurn or 0
  if taken <= 0 then return nil, Strings("But, it failed!") end
  return math.max(1, math.floor(taken * 1.5)), { crit = false, typeMult = 10 }
end

function Damaging.finalGambitChoose(ec, _raw)
  local userMon = ec.adapter:mon(ec.user)
  if not userMon or (userMon.hp or 0) <= 0 then
    return nil, Strings("But, it failed!")
  end
  local dmg = userMon.hp
  userMon.hp = 0
  if type(ec.adapter.onFaint) == "function" then
    ec.adapter:onFaint(ec.user)
  elseif ec.adapter.battle and type(ec.adapter.battle.onFaint) == "function" then
    ec.adapter.battle:onFaint(ec.user)
  end
  return dmg, { crit = false, typeMult = 10 }
end

function Damaging.lastResortGate(ec, _raw)
  local moves = ec.adapter:preparedMoves(ec.user) or {}
  local used = ec.user.expMovesUsedThisBattle or {}
  local others = 0
  local unused = 0
  for _, mv in ipairs(moves) do
    local id = type(mv) == "table" and mv.id or mv
    if id and id ~= "LAST_RESORT" then
      others = others + 1
      if not used[id] then unused = unused + 1 end
    end
  end
  if others == 0 or unused > 0 then
    return false, Strings("But, it failed!")
  end
  return true
end

function Damaging.belchGate(ec, _raw)
  if not ec.user.expAteBerry then
    return false, Strings("But, it failed!")
  end
  return true
end

function Damaging.naturalGiftAfter(ec, _raw)
  local HeldItems = require("mods.Kanto-Reforged.items.held_items")
  local item = HeldItems.ofBattler and HeldItems.ofBattler(ec.user)
  if item then
    local mon = ec.adapter:mon(ec.user)
    if mon then mon.heldItem = nil end
    if ec.user.heldItem then ec.user.heldItem = nil end
  end
end

function Damaging.naturalGiftGate(ec, _raw)
  local HeldItems = require("mods.Kanto-Reforged.items.held_items")
  local VP = require("mods.Kanto-Reforged.battle.variable_power")
  local item = HeldItems.ofBattler and HeldItems.ofBattler(ec.user)
  if not item or not VP.naturalGift(item) then
    return false, Strings("But, it failed!")
  end
  return true
end

function Damaging.flingGate(ec, _raw)
  local HeldItems = require("mods.Kanto-Reforged.items.held_items")
  local item = HeldItems.ofBattler and HeldItems.ofBattler(ec.user)
  if not item then return false, Strings("But, it failed!") end
  return true
end

function Damaging.flingAfter(ec, _raw)
  local mon = ec.adapter:mon(ec.user)
  if mon then mon.heldItem = nil end
  if ec.user.heldItem then ec.user.heldItem = nil end
end

function Damaging.endeavorChoose(ec, _raw)
  local userMon = ec.adapter:mon(ec.user)
  local targetMon = ec.adapter:mon(ec.target)
  if not userMon or not targetMon then
    return nil, Strings("But, it failed!")
  end
  local uh, th = userMon.hp or 0, targetMon.hp or 0
  if uh >= th then return nil, Strings("But, it failed!") end
  return th - uh, { crit = false, typeMult = 10 }
end

function Damaging.rapidSpinAfter(ec, _raw)
  local side = ec.adapter:ownSide(ec.user)
  if side and side.hazards and #side.hazards > 0 then
    side.hazards = {}
    if side.spikes ~= nil then side.spikes = nil end
    ec.adapter:say(Strings("%s blew away\nentry hazards!",
      H.displayName(ec, ec.user)))
  end
  if ec.adapter:isSeeded(ec.user) then
    ec.adapter:clearSeed(ec.user)
    ec.adapter:say(Strings("%s shed\nLEECH SEED!", H.displayName(ec, ec.user)))
  end
  if ec.user.boundTurns or ec.target.trappingTurns
      or (ec.adapter.trap.get(ec.user) or 0) > 0 then
    ec.user.boundTurns = nil
    ec.target.trappingTurns = nil
    ec.user.expTrapped = nil
    ec.adapter.trap.clear(ec.user)
    PartialTrap.clear(ec.user)
  end
  local move = ec.move or {}
  if move.statChanges then
    H.applyStages(ec, ec.user, move.statChanges)
  end
end

function Damaging.spitUpChoose(ec, raw)
  local n = ec.user.expStockpile or 0
  if n <= 0 then return nil, Strings("But, it failed!") end
  local compute = raw.computeDamage or ec.opts.computeDamage
  if type(compute) ~= "function" then return nil, Strings("But, it failed!") end
  local power = 100 * n
  ec.user.expStockpile = nil
  local move = ec.move or {}
  local old = move.power
  move.power = power
  local dmg, info = compute({})
  move.power = old
  return dmg, info
end

function Damaging.mirrorCoatChoose(ec, _raw)
  local last = ec.adapter:fieldGet("expLastSpecialDamage") or 0
  if last <= 0 then
    return nil, Strings("%s's\nattack missed!", H.displayName(ec, ec.user))
  end
  return math.min(65535, last * 2), { crit = false, typeMult = 10 }
end

function Damaging.focusPunchGate(ec, _raw)
  if ec.user.expTookDamageThisTurn then
    return false, Strings("%s lost its\nconcentration!", H.displayName(ec, ec.user))
  end
  return true
end

function Damaging.uTurnAfter(ec, _raw)
  if ec.user.isPlayer and ec.adapter:hp(ec.user) > 0 then
    ec.user.expWantsSwitch = true
    local trainer = ec.adapter:fieldGet("expTrainerName")
    if not trainer then
      local game = ec.adapter:fieldGet("game")
      trainer = game and game.save and game.save.player and game.save.player.name
    end
    ec.adapter:say(Strings("%s went back to\n%s!", H.displayName(ec, ec.user),
      trainer or "the trainer"))
  end
end

function Damaging.uproarAfter(ec, raw)
  local user = ec.user
  if not user.expUproarTurns then
    local rng = ec.rng or ec.adapter:rng()
    local turns = 3
    if type(rng) == "function" then
      local ok, v = pcall(rng, 2, 5)
      turns = ok and v or math.random(2, 5)
    end
    user.expUproarTurns = turns
    user.expUproarMove = raw.moveInst or ec.opts.moveInst
    ec.adapter:fieldSet("expUproarActive", true)
    ec.adapter:say(Strings("%s caused\nan UPROAR!", H.displayName(ec, user)))
  else
    user.expUproarTurns = user.expUproarTurns - 1
    if user.expUproarTurns <= 0 then
      user.expUproarTurns, user.expUproarMove = nil, nil
      local foe = ec.adapter:foeOf(user)
      if not (foe and foe.expUproarTurns) then
        ec.adapter:fieldSet("expUproarActive", nil)
      end
      ec.adapter:say(Strings("%s calmed down!", H.displayName(ec, user)))
    end
  end
end

function Damaging.presentChoose(ec, raw)
  local rng = ec.rng or ec.adapter:rng()
  local r = type(rng) == "function" and rng(0, 255) or math.random(0, 255)
  if r < 51 then
    local mon = ec.adapter:mon(ec.target)
    if mon then
      mon.hp = math.min(mon.stats.hp, (mon.hp or 0) + 80)
    end
    ec.adapter:say(Strings("%s had its\nHP restored!",
      H.displayName(ec, ec.target)))
    return 0, { crit = false, typeMult = 10 }
  end
  local compute = raw.computeDamage or ec.opts.computeDamage
  if type(compute) ~= "function" then return 0, { crit = false, typeMult = 10 } end
  local power = (r < 102) and 40 or (r < 178) and 80 or 120
  local move = ec.move or {}
  local old = move.power
  move.power = power
  local dmg, info = compute()
  move.power = old
  return dmg, info
end

function Damaging.clearSmogAfter(ec, _raw)
  if not ec.target or not ec.target.stages then return end
  for k in pairs(ec.target.stages) do ec.target.stages[k] = 0 end
  ec.target.hazeStatReset = nil
  ec.adapter:say(Strings("%s's stat changes\nwere removed!",
    H.displayName(ec, ec.target)))
end

function Damaging.knockOffAfter(ec, _raw)
  local HeldItems = require("mods.Kanto-Reforged.items.held_items")
  local mon = ec.adapter:mon(ec.target)
  if not mon or not mon.heldItem then return end
  if Rules.substitute.hasSubstitute(ec.target, ec.adapter) then return end
  local id = HeldItems.consume(mon, ec.target)
  if id then
    local def = HeldItems.def(id)
    ec.adapter:say(Strings("%s knocked off\n%s's %s!",
      H.displayName(ec, ec.user), H.displayName(ec, ec.target),
      def and def.name or id))
  end
end

return Damaging
