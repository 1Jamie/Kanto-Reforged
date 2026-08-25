-- Pursuit: hit a switching target for double power before they leave.
-- Gen1 hooks resolveSwitch; Gen2 hooks takeTurn. Power ×2 is via
-- battle.expPursuitSwitch, read by the battle.damage wrap in main.lua.

local Pursuit = {}

local function moveIdOf(action)
  if not action or action.special then return nil end
  return action.id or action.move
end

local function knowsPursuit(battler)
  if not battler then return false end
  for _, m in ipairs(battler.curMoves or battler.moves or {}) do
    local id = type(m) == "table" and m.id or m
    if id == "PURSUIT" then return true end
  end
  return false
end

local function oneshotEnemyAction(battle, locked)
  battle.enemyAction = function()
    battle.enemyAction = nil
    return locked
  end
end

--- Gen1: intercept player voluntary switch when foe uses Pursuit.
function Pursuit.installGen1(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen1() then return end
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  local TrainerAi = require("mods.Kanto-Reforged.battle.trainer_ai")

  Gen1Patch.apply(require("src.battle.BattleState"), function(BattleState)
    -- Replaces the old Gen3-only switch-lock wrap (same install site).
    if BattleState._krGen3SwitchLock or type(BattleState.resolveSwitch) ~= "function" then
      return
    end
    BattleState._krGen3SwitchLock = true
    BattleState._krPursuitSwitch = true
    local originalResolveSwitch = BattleState.resolveSwitch
    BattleState.resolveSwitch = function(self, newMon)
      local skipFree = (self.player and self.player.expBatonPass)
          or (self.player and self.player.expWantsSwitch)
          or self.expSkipNextEnemyAction
      if skipFree then
        return originalResolveSwitch(self, newMon)
      end

      local peek = knowsPursuit(self.enemy) or TrainerAi.switchLockGen3(mod)
      if not peek then
        return originalResolveSwitch(self, newMon)
      end

      local locked = self:enemyAction()
      if moveIdOf(locked) == "PURSUIT" then
        self.expPursuitSwitch = true
        self:executeAction(self.enemy, self.player, locked)
        self.expPursuitSwitch = nil
        self.expSkipNextEnemyAction = true
        if self.player and self.player.mon and self.player.mon.hp <= 0 then
          -- Switch cancelled; faint queue handles replacement.
          self.phase = "messages"
          self.afterQueue = "menu"
          self:act(function() self:endOfTurn() end)
          return
        end
        return originalResolveSwitch(self, newMon)
      end

      -- Non-Pursuit: lock the peeked choice onto the free hit (Gen3 timing,
      -- or classic when the foe knows Pursuit and we already rolled).
      oneshotEnemyAction(self, locked)
      return originalResolveSwitch(self, newMon)
    end
  end)
end

--- Gen2: intercept player switch before Battle:switch runs.
function Pursuit.installGen2(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen2() then return end
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  local TrainerAi = require("mods.Kanto-Reforged.battle.trainer_ai")

  Gen1Patch.apply(require("src.battle.gen2.Battle"), function(Battle)
    if Battle._krPursuitSwitch then return end
    Battle._krPursuitSwitch = true

    local origEnemyMove = Battle.enemyMove
    Battle.enemyMove = function(self, ...)
      if self.expPursuitSpent then
        self.expPursuitSpent = nil
        return nil
      end
      if self.expLockedEnemyMove ~= nil then
        local id = self.expLockedEnemyMove
        self.expLockedEnemyMove = nil
        if self.enemy then self.enemy.expPendingMove = id end
        return id
      end
      return origEnemyMove(self, ...)
    end

    local origTake = Battle.takeTurn
    Battle.takeTurn = function(self, action, ...)
      if not action or action.kind ~= "switch" then
        return origTake(self, action, ...)
      end
      if (self.player and (self.player.hp or 0) or 0) <= 0 then
        return origTake(self, action, ...)
      end

      local peek = knowsPursuit(self.enemy) or TrainerAi.switchLockGen3(mod)
      if not peek then
        return origTake(self, action, ...)
      end

      -- Choose while the outgoing mon is still active (before :switch).
      local moveId = self:enemyMove()
      if moveId == "PURSUIT" then
        self.expPursuitSwitch = true
        self:useMove(self.enemy, self.player, "PURSUIT")
        self.expPursuitSwitch = nil
        if (self.player.hp or 0) <= 0 then
          if type(self.takeEvents) == "function" then
            return self:takeEvents()
          end
          return {}
        end
        self.expPursuitSpent = true
        local out = origTake(self, action, ...)
        self.expPursuitSpent = nil
        return out
      end

      if moveId then
        self.expLockedEnemyMove = moveId
      end
      local out = origTake(self, action, ...)
      self.expLockedEnemyMove = nil
      return out
    end
  end)
end

function Pursuit.install(mod)
  Pursuit.installGen1(mod)
  Pursuit.installGen2(mod)
end

return Pursuit
