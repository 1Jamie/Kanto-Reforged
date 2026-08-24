-- Gen 3 partial trapping on Gen 1: Bind / Wrap / Fire Spin / Clamp / etc.
-- Victim can act; trapper is not locked; end-of-turn 1/16 chip; no switch/flee;
-- Ghost immune; ends on switch / Rapid Spin / turn count.

local Strings = require("src.core.Strings")
local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
local Host = require("mods.Kanto-Reforged.core.host")
local Rules = require("mods.Kanto-Reforged.battle.core.rules")

local PartialTrap = {}

local TRAP_START = {
  WRAP = "%s was WRAPPED\nby %s!",
  BIND = "%s was BOUND\nby %s!",
  CLAMP = "%s was CLAMPED\nby %s!",
  FIRE_SPIN = "%s became trapped\nin the fiery vortex!",
  WHIRLPOOL = "%s became trapped\nin the vortex!",
  SAND_TOMB = "%s became trapped\nby SAND TOMB!",
  MAGMA_STORM = "%s became trapped\nby MAGMA STORM!",
  INFESTATION = "%s has been\ninfested!",
}

local function displayName(battle, battler)
  return BattleCompat.displayName(battle, battler)
end

local function isGhost(battler, data)
  for _, t in ipairs(BattleCompat.types(battler, data) or {}) do
    if t == "GHOST" then return true end
  end
  return false
end

function PartialTrap.active(_battle)
  return Rules.partialTrap.active()
end

function PartialTrap.isTrapped(battler)
  return battler and type(battler.expPartialTrapTurns) == "number"
    and battler.expPartialTrapTurns > 0
end

function PartialTrap.clear(battler)
  if not battler then return end
  battler.expPartialTrapTurns = nil
  battler.expPartialTrapMove = nil
  battler.expPartialTrapMoveId = nil
end

function PartialTrap.clearBattle(battle)
  if not battle then return end
  PartialTrap.clear(battle.player)
  PartialTrap.clear(battle.enemy)
  if BattleCompat.isGen2(battle) then
    for _, mon in ipairs({ battle.player, battle.enemy }) do
      local vol = BattleCompat.volatile(battle, mon)
      if vol then
        vol.wrapCount, vol.wrapMove, vol.wrapMoveId = nil, nil, nil
      end
    end
  end
end

function PartialTrap.chipAmount(maxHp)
  return Rules.partialTrap.chipAmount(maxHp)
end

function PartialTrap.rollTurns(rng)
  return Rules.partialTrap.rollTurns(rng)
end

function PartialTrap.apply(ctx)
  if not ctx or not ctx.target or not ctx.user then return end
  if not PartialTrap.active(ctx.battle) then return end
  local target, user = ctx.target, ctx.user
  if (BattleCompat.hp(target) or 0) <= 0 then return end
  if target.substituteHP and target.substituteHP > 0 then return end
  if Rules.partialTrap.ghostImmune(BattleCompat.types(target, ctx.battle and ctx.battle.data)) then return end
  if PartialTrap.isTrapped(target) then return end

  local moveId = ctx.move and ctx.move.id
  local moveName = (ctx.move and ctx.move.name) or moveId or "the trap"
  local turns = PartialTrap.rollTurns(ctx.rng or (ctx.battle and ctx.battle.rng))
  PartialTrap.arm(ctx.battle, target, moveId, moveName, turns)

  -- Do not arm Gen 1 multiturn lock fields.
  user.trappingTurns = nil
  user.trapDamage = nil
  user.trapMove = nil
  target.boundTurns = nil

  local fmt = TRAP_START[moveId]
  if fmt then
    if moveId == "FIRE_SPIN" or moveId == "WHIRLPOOL"
        or moveId == "SAND_TOMB" or moveId == "MAGMA_STORM"
        or moveId == "INFESTATION" then
      ctx.say(Strings(fmt, displayName(ctx.battle, target)))
    else
      ctx.say(Strings(fmt,
        displayName(ctx.battle, target), displayName(ctx.battle, user)))
    end
  else
    ctx.say(Strings("%s was trapped!", displayName(ctx.battle, target)))
  end
end

-- End-of-turn partial-trap chip (single owner; called from residual_handlers).
function PartialTrap.applyResidualChip(adapter, battler)
  if not adapter or not battler or adapter:isFainted(battler) then return end
  if not PartialTrap.isTrapped(battler) then return end
  if not adapter:gen3PartialTrapActive() then return end
  if adapter:hasSubstitute(battler) then return end

  local maxHp = adapter:maxHp(battler) or 16
  local dmg = PartialTrap.chipAmount(maxHp)
  local moveName = adapter.trap.moveName(battler) or "the trap"
  adapter:applyHpLoss(battler, dmg)
  adapter:say(Strings("%s is hurt by\n%s!", adapter:displayName(battler), moveName))

  local left = (adapter.trap.get(battler) or 1) - 1
  if left <= 0 then
    adapter.trap.clear(battler)
    adapter:say(Strings("%s was freed from\n%s!",
      adapter:displayName(battler), moveName))
  else
    adapter.trap.set(battler, left, battler.expPartialTrapMoveId, moveName)
  end
end

local function patchTrappingEffect()
  local Data = require("src.core.Data")
  local rec = Data.move_effects and Data.move_effects.TRAPPING_EFFECT
  if not rec or rec._krGen3PartialTrap then return end

  local oldAfter = rec.afterDamage
  local oldBefore = rec.beforeAccuracy

  rec.beforeAccuracy = function(ctx)
    if PartialTrap.active(ctx.battle) then
      -- Gen 3: still cancel Hyper Beam recharge on the target.
      if ctx.target then ctx.target.mustRecharge = nil end
      return
    end
    if oldBefore then return oldBefore(ctx) end
  end

  rec.afterDamage = function(ctx, ...)
    if PartialTrap.active(ctx.battle) then
      PartialTrap.apply(ctx)
      return
    end
    if oldAfter then return oldAfter(ctx, ...) end
  end

  rec._krGen3PartialTrap = true

  -- Keep the Lua table used before Data merge in sync when present.
  pcall(function()
    local ME = require("src.battle.MoveEffects")
    if ME.full and ME.full.TRAPPING_EFFECT then
      ME.full.TRAPPING_EFFECT.beforeAccuracy = rec.beforeAccuracy
      ME.full.TRAPPING_EFFECT.afterDamage = rec.afterDamage
    end
    if ME.RECORDS and ME.RECORDS.TRAPPING_EFFECT then
      ME.RECORDS.TRAPPING_EFFECT.beforeAccuracy = rec.beforeAccuracy
      ME.RECORDS.TRAPPING_EFFECT.afterDamage = rec.afterDamage
    end
  end)
end

function PartialTrap.arm(battle, target, moveId, moveName, turns)
  if not target then return end
  turns = turns or PartialTrap.rollTurns(battle and battle.rng)
  target.expPartialTrapTurns = turns
  target.expPartialTrapMove = moveName or moveId or "the trap"
  target.expPartialTrapMoveId = moveId
  if BattleCompat.isGen2(battle) then
    local vol = BattleCompat.volatile(battle, target)
    if vol then
      vol.wrapCount = 1
      vol.wrapMove = target.expPartialTrapMove
      vol.wrapMoveId = moveId
    end
  else
    target.boundTurns = nil
  end
end

function PartialTrap.install(mod)
  if Host.isGen1() then
    Gen1Patch.apply(require("src.battle.BattleState"), function(BattleState)
      if BattleState._krGen3PartialTrap then return end

      local origFight = BattleState.fightLockedAction
      BattleState.fightLockedAction = function(self, battler)
        if PartialTrap.active(self) then
          local lock = origFight(self, battler)
          if lock and type(lock) == "table" then
            if lock.special == "bound" or lock.special == "trapping" then
              return nil
            end
          end
          return lock
        end
        return origFight(self, battler)
      end

      local origOpen = BattleState.openParty
      if type(origOpen) == "function" then
        BattleState.openParty = function(self)
          if PartialTrap.active(self) and PartialTrap.isTrapped(self.player) then
            self:say(Strings("%s can't be\nrecalled!",
              displayName(self, self.player)))
            self.phase = "messages"
            self.afterQueue = "menu"
            return
          end
          return origOpen(self)
        end
      end

      local origResolve = BattleState.resolveSwitch
      if type(origResolve) == "function" then
        BattleState.resolveSwitch = function(self, newMon)
          PartialTrap.clearBattle(self)
          return origResolve(self, newMon)
        end
      end

      BattleState._krGen3PartialTrap = true
    end)

    -- Chip moved to core residual_handlers (battle.turn_ended). Do not double-tick.
    do
      local Status = require("src.battle.Status")
      if not Status._krGen3PartialTrapResidual then
        Status._krGen3PartialTrapResidual = true
      end
    end

    local function applyPatches()
      patchTrappingEffect()
    end
    applyPatches()
    if mod and mod.events then
      mod.events:on("game.ready", applyPatches)
    end
    return
  end

  -- Gen2 / Gold: convert native EFFECT_TRAP_TARGET into Gen3 trap fields,
  -- suppress tickWrap chip, keep wrapCount=1 shadow for canSwitch/flee.
  if not Host.isGen2() then return end
  Gen1Patch.apply(require("src.battle.gen2.Battle"), function(Battle)
    if Battle._krGen3PartialTrap then return end

    local origTickWrap = Battle.tickWrap
    Battle.tickWrap = function(self, mon)
      if PartialTrap.active(self) then
        local vol = self:volatile(mon)
        if PartialTrap.isTrapped(mon) then
          if vol then vol.wrapCount = 1 end
        elseif vol then
          vol.wrapCount, vol.wrapMove, vol.wrapMoveId = nil, nil, nil
        end
        return
      end
      return origTickWrap(self, mon)
    end

    local origUse = Battle.useMove
    Battle.useMove = function(self, attacker, defender, moveId, ...)
      local def = type(self.moveDef) == "function" and self:moveDef(moveId) or nil
      local out = origUse(self, attacker, defender, moveId, ...)
      if PartialTrap.active(self) and def and def.effect == "EFFECT_TRAP_TARGET"
          and defender then
        local vol = self:volatile(defender)
        if vol and vol.wrapCount and not PartialTrap.isTrapped(defender) then
          PartialTrap.arm(self, defender, vol.wrapMoveId or moveId, vol.wrapMove)
        elseif PartialTrap.isTrapped(defender) and vol then
          vol.wrapCount = 1
        end
      end
      return out
    end

    local origBreak = Battle.breakTrapsOnSend or Battle.clearVolatile
    if type(Battle.breakTrapsOnSend) == "function" then
      local prev = Battle.breakTrapsOnSend
      Battle.breakTrapsOnSend = function(self, ...)
        PartialTrap.clearBattle(self)
        return prev(self, ...)
      end
    end

    Battle._krGen3PartialTrap = true
  end)
end

return PartialTrap
