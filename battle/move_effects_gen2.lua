-- Gen2/Gold move effect runners + battle event wiring (engine: Battle.lua dispatch).
-- Gen1 registry/install lives in move_effects.lua (engine: EffectRegistry ctx pipeline).
-- Host routing: battle/adapters/register.lua
local Strings = require("src.core.Strings")
local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local CoreInstall = require("mods.Kanto-Reforged.battle.core.install")
local CoreEffects = require("mods.Kanto-Reforged.battle.core.effects")

local MoveEffectsGen2 = {}

local EffectsInstall = require("mods.Kanto-Reforged.battle.core.effects.install")

local function installRecord(mod, id, record)
  pcall(function()
    if mod.content.move_effects:get(id) then
      mod.content.move_effects:override(id, record)
    else
      mod.content.move_effects:register(id, record)
    end
  end)
end

local function markFailed(battle, msg)
  if msg then BattleCompat.say(battle, msg) end
  if type(battle.markMissed) == "function" then battle:markMissed() end
end

local function gen2ComputeDamage(battle, attacker, defender, def)
  if type(battle.computeDamage) ~= "function" then return nil end
  return function(overrides)
    return battle:computeDamage(attacker, defender, def, overrides)
  end
end

local function runChooseDamage(battle, id, attacker, defender, def, moveId, sureHit, spec)
  if spec.gate then
    local ok, msg = CoreInstall.tryRunHook(battle, id, "gate", attacker, defender, def)
    if ok == false then return markFailed(battle, msg) end
  end
  local power = def and def.power or 0
  if power > 0 and not sureHit and type(battle.accuracyRoll) == "function"
      and not battle:accuracyRoll(def, attacker, defender) then
    if spec.onMiss then
      CoreInstall.tryRunHook(battle, id, "onMiss", attacker, defender, def)
    end
    return markFailed(battle)
  end
  local dmg, info = CoreInstall.tryRunHook(battle, id, "chooseDamage", attacker, defender, def, {
    computeDamage = gen2ComputeDamage(battle, attacker, defender, def),
    moveInst = def,
  })
  if dmg == nil then
    return markFailed(battle, type(info) == "string" and info or nil)
  end
  if type(battle.dealDamage) == "function" then
    battle:dealDamage(attacker, defender, dmg, { move = def, moveId = moveId })
  end
  if spec.afterDamage and dmg > 0 then
    CoreInstall.tryRunHook(battle, id, "afterDamage", attacker, defender, def)
  end
end

local function runCallsMove(battle, id, attacker, defender, def, moveId)
  BattleCompat.prepareAiBattler(battle, attacker)
  local pick = CoreInstall.tryRunHook(battle, id, "callsMove", attacker, defender,
    def or { effect = id, id = moveId })
  if not pick then return end
  if type(battle.useMove) ~= "function" then
    BattleCompat.say(battle, Strings("But it failed!"))
    return
  end
  battle.copyDepth = (battle.copyDepth or 0) + 1
  battle:useMove(attacker, defender, pick)
  battle.copyDepth = (battle.copyDepth or 1) - 1
end

local function runGatedDamage(battle, id, attacker, defender, def, moveId, sureHit, spec)
  local ok, msg = CoreInstall.tryRunHook(battle, id, "gate", attacker, defender, def)
  if ok == false then return markFailed(battle, msg) end
  if not sureHit and type(battle.accuracyRoll) == "function"
      and not battle:accuracyRoll(def, attacker, defender) then
    return markFailed(battle, Strings("%s's attack missed!",
      BattleCompat.displayName(battle, attacker)))
  end
  if type(battle.hitOnce) == "function" then
    -- afterDamage runs via battle.damage_dealt → applyDamageStats
    battle:hitOnce(attacker, defender, def, { moveId = moveId })
  elseif spec.afterDamage then
    CoreInstall.tryRunHook(battle, id, "afterDamage", attacker, defender, def)
  end
  if id == "EXP_FAKE_OUT_EFFECT" and attacker then
    attacker.expJustEntered = nil
  end
end

local function register(mod, id, record)
  if CoreEffects.has(id) then
    record = {
      kind = record and record.kind or "primary",
      run = function(battle, attacker, defender, def)
        BattleCompat.prepareAiBattler(battle, attacker)
        BattleCompat.prepareAiBattler(battle, defender)
        CoreInstall.tryRunEffect(battle, id, attacker, defender, def,
          battle.rng or battle.random)
      end,
    }
  end
  installRecord(mod, id, record)
end

local function registerHook(mod, id)
  local spec = CoreEffects.hooks(id)
  if not spec then return end

  if spec.callsMove then
    register(mod, id, {
      kind = "primary",
      run = function(battle, attacker, defender, def, moveId)
        runCallsMove(battle, id, attacker, defender, def, moveId)
      end,
    })
  elseif spec.chooseDamage then
    register(mod, id, {
      kind = "primary",
      run = function(battle, attacker, defender, def, moveId, sureHit)
        runChooseDamage(battle, id, attacker, defender, def, moveId, sureHit, spec)
      end,
    })
  elseif spec.gate and spec.afterDamage then
    register(mod, id, {
      kind = "primary",
      run = function(battle, attacker, defender, def, moveId, sureHit)
        runGatedDamage(battle, id, attacker, defender, def, moveId, sureHit, spec)
      end,
    })
  else
    -- afterDamage / gate-only / empty: fall through to normal damage path.
    register(mod, id, { kind = spec.kind or "primary" })
  end
end

function MoveEffectsGen2.register(mod)
  for _, id in ipairs(EffectsInstall.allPrimary()) do
    register(mod, id, { kind = "primary" })
  end
  for _, id in ipairs(EffectsInstall.allHooks()) do
    registerHook(mod, id)
  end
  -- Smelling Salts / Wake-Up Slap: damage path + damage_dealt hook.
  register(mod, "EXP_WAKE_UP_SLAP_EFFECT", { kind = "primary" })
end

local function applyDamageStats(battle, user, target, move, damage)
  if not move then return end
  local effect = move.effect
  if effect and damage and damage > 0 and CoreEffects.hasHooks(effect) then
    local spec = CoreEffects.hooks(effect)
    if spec and spec.afterDamage then
      CoreInstall.tryRunHook(battle, effect, "afterDamage", user, target, move)
      return
    end
    if spec and spec.run and spec.kind == "secondary" then
      CoreInstall.tryRunHook(battle, effect, "run", user, target, move)
      return
    end
  end
  if not damage or damage <= 0 then return end
  if effect == "EXP_WAKE_UP_SLAP_EFFECT" or move.id == "WAKE_UP_SLAP" then
    if BattleCompat.hasStatus(target, "SLP", "sleep") then
      local mon = BattleCompat.mon(target)
      if mon then
        mon.status = nil
        mon.statusTurns = nil
      end
      BattleCompat.say(battle, Strings("%s woke up!",
        BattleCompat.displayName(battle, target)))
    end
  end
end

function MoveEffectsGen2.install(mod)
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  local Abilities = require("mods.Kanto-Reforged.battle.abilities")
  local Adapters = require("mods.Kanto-Reforged.battle.adapters")

  -- Gen3 partial trap on Gold: suppress native wrap chip, arm expPartialTrap fields.
  require("mods.Kanto-Reforged.battle.partial_trap").install(mod)

  mod.events:on("battle.damage_dealt", function(ev)
    if not ev.battle then return end
    local target = ev.target or ev.defender
    local damage = ev.damage or ev.amount or 0
    if target and damage > 0 then
      target.expTookDamageThisTurn = true
    end
    if ev.move then
      applyDamageStats(ev.battle, ev.user or ev.attacker, target, ev.move, damage)
    end
  end)

  mod.events:on("battle.turn_started", function(ev)
    if not ev.battle then return end
    for _, mon in ipairs({ ev.battle.player, ev.battle.enemy }) do
      if mon then mon.expTookDamageThisTurn = nil end
    end
  end)

  mod.events:on("battle.move_used", function(ev)
    if not ev.user then return end
    -- Destiny Bond lasts only until the user moves again.
    if not (ev.move and ev.move.id == "DESTINY_BOND") then
      ev.user.expDestinyBond = nil
    else
      ev.user.expDestinyBond = true
    end
  end)

  mod.events:on("battle.fainted", function(ev)
    if not ev.battle or not ev.battler then return end
    local battler = ev.battler
    if battler.expDestinyBond then
      battler.expDestinyBond = nil
      local foe = (battler == ev.battle.player) and ev.battle.enemy or ev.battle.player
      local foeMon = BattleCompat.mon(foe)
      if foeMon and (foeMon.hp or 0) > 0 then
        BattleCompat.say(ev.battle, Strings("%s took\n%s with it!",
          BattleCompat.displayName(ev.battle, battler),
          BattleCompat.displayName(ev.battle, foe)))
        foeMon.hp = 0
      end
    end
    if battler.expGrudge then
      battler.expGrudge = nil
      local foe = (battler == ev.battle.player) and ev.battle.enemy or ev.battle.player
      if foe and foe.moves then
        local last
        if type(ev.battle.volatile) == "function" then
          local vol = ev.battle:volatile(foe)
          last = vol and vol.lastMove
        end
        last = last or foe.lastMove
        if last then
          for _, mv in ipairs(foe.moves) do
            if type(mv) == "table" and mv.id == last then
              mv.pp = 0
              BattleCompat.say(ev.battle, Strings("%s's %s\nlost all its PP!",
                BattleCompat.displayName(ev.battle, foe), last))
              break
            end
          end
        end
      end
    end
  end)

  -- EOT volatiles: core/residual_handlers.lua via core/install.lua

  -- Synchronize: copy PAR/BRN/PSN back to the source.
  mod.events:on("battle.status_inflicted", function(ev)
    if not ev.battle or not ev.target or not ev.status then return end
    if Abilities.abilityOf(ev.battle, ev.target) ~= "SYNCHRONIZE" then return end
    local st = BattleCompat.toGen2Status(ev.status) or ev.status
    if st ~= "paralyze" and st ~= "burn" and st ~= "poison" then return end
    local source = ev.source
    if not source then
      source = (ev.target == ev.battle.player) and ev.battle.enemy or ev.battle.player
    end
    if not source or BattleCompat.status(source) then return end
    if Abilities.blocksStatus(ev.battle, source, st, { fromAbility = true }) then return end
    BattleCompat.applyStatus(ev.battle, source, st, ev.target, { fromAbility = true })
  end)

  pcall(function()
    local Battle = require("src.battle.gen2.Battle")
    Gen1Patch.apply(Battle, function(B)
      -- Focus Punch priority (Gen 3: -3).
      if B.PRIORITY then
        B.PRIORITY.EXP_FOCUS_PUNCH_EFFECT = -3
      end

      -- Pending move id so sleep can allow Sleep Talk / Snore.
      if not B._krPendingMoveWrap then
        local origTake = B.takeTurn
        B.takeTurn = function(self, action, ...)
          if self.player and action and action.kind == "move" then
            self.player.expPendingMove = action.move or action.id
          end
          local out = origTake(self, action, ...)
          if self.player then self.player.expPendingMove = nil end
          if self.enemy then self.enemy.expPendingMove = nil end
          return out
        end
        local origEnemy = B.enemyMove
        B.enemyMove = function(self, ...)
          local id = origEnemy(self, ...)
          if self.enemy then self.enemy.expPendingMove = id end
          return id
        end
        B._krPendingMoveWrap = true
      end

      -- Taunt + Focus Punch + Imprison + Snatch gates.
      if not B._krTauntWrap then
        local originalUse = B.useMove
        B.useMove = function(self, attacker, defender, moveId)
          local def = self:moveDef(moveId)
          local isCalled = (self.copyDepth or 0) > 0

          if attacker and attacker.expTauntedTurns and attacker.expTauntedTurns > 0 then
            if def and (not def.power or def.power == 0) then
              self:emit({ kind = "message",
                text = self:monName(attacker) .. " can't use " .. (def.name or moveId)
                  .. " after the TAUNT!" })
              return
            end
          end

          -- Torment: cannot select the same move twice in a row.
          if not isCalled and attacker and attacker.expTormented
              and attacker.expTormentLast == moveId then
            self:emit({ kind = "message",
              text = self:monName(attacker) .. " can't use the same move twice!" })
            return
          end

          if def and def.effect == "EXP_FOCUS_PUNCH_EFFECT" then
            if not attacker.expTookDamageThisTurn and type(self.volatile) == "function" then
              local vol = self:volatile(attacker)
              if vol and (vol.tookThisTurn or 0) > 0 then
                attacker.expTookDamageThisTurn = true
              end
            end
            local ok, msg = CoreInstall.tryRunHook(self, def.effect, "gate",
              attacker, defender, def)
            if ok == false then
              self:emit({ kind = "message",
                text = msg or (self:monName(attacker) .. " lost its concentration!") })
              return
            end
          end

          -- Imprison: can't use a move the imprisoner also knows.
          if def and not isCalled then
            local other = (attacker == self.player) and self.enemy or self.player
            if other and other.expImprison then
              for _, mv in ipairs(other.moves or {}) do
                local id = type(mv) == "table" and mv.id or mv
                if id == moveId then
                  self:emit({ kind = "message",
                    text = self:monName(attacker) .. " can't use the sealed "
                      .. (def.name or moveId) .. "!" })
                  return
                end
              end
            end
          end

          -- Damp: block Explosion / Selfdestruct.
          if def and (moveId == "EXPLOSION" or moveId == "SELFDESTRUCT"
              or moveId == "SELF_DESTRUCT") then
            for _, mon in ipairs({ self.player, self.enemy }) do
              if Abilities.abilityOf(self, mon) == "DAMP" then
                self:emit({ kind = "message",
                  text = self:monName(attacker) .. " cannot use "
                    .. (def.name or moveId) .. " because of DAMP!" })
                return
              end
            end
          end

          -- Soundproof: block sound moves targeting the holder (status + damage).
          if def and defender and attacker ~= defender
              and Abilities.isSoundMove(moveId)
              and Abilities.abilityOf(self, defender) == "SOUNDPROOF" then
            self:emit({ kind = "message",
              text = "It doesn't affect " .. self:monName(defender) .. "!" })
            return
          end

          -- Snatch: steal the foe's status move.
          if def and not isCalled and (not def.power or def.power == 0)
              and moveId ~= "SNATCH" and defender and defender.expSnatch then
            defender.expSnatch = nil
            self:emit({ kind = "message",
              text = self:monName(defender) .. " snatched "
                .. self:monName(attacker) .. "'s move!" })
            self.copyDepth = (self.copyDepth or 0) + 1
            local out = originalUse(self, defender, attacker, moveId)
            self.copyDepth = (self.copyDepth or 1) - 1
            return out
          end

          -- Magic Coat: bounce status moves (match Gen1 KR).
          if def and not isCalled and defender and defender.expMagicCoat
              and (not def.power or def.power == 0)
              and moveId ~= "MAGIC_COAT" and moveId ~= "SKETCH"
              and moveId ~= "ROLE_PLAY" and moveId ~= "SKILL_SWAP"
              and moveId ~= "PSYCH_UP" then
            defender.expMagicCoat = nil
            self:emit({ kind = "message",
              text = self:monName(defender) .. " bounced the "
                .. (def.name or moveId) .. " back!" })
            self.copyDepth = (self.copyDepth or 0) + 1
            local out = originalUse(self, defender, attacker, moveId)
            self.copyDepth = (self.copyDepth or 1) - 1
            -- Bounced call skips PP; debit the original attacker.
            if attacker.moves then
              for _, mv in ipairs(attacker.moves) do
                local id = type(mv) == "table" and mv.id or mv
                if id == moveId and type(mv) == "table" and mv.pp then
                  mv.pp = math.max(0, mv.pp - 1)
                  break
                end
              end
            end
            return out
          end

          local oldChance
          if def and type(def.effectChance) == "number" and def.effectChance > 0
              and Abilities.abilityOf(self, attacker) == "SERENE_GRACE" then
            oldChance = def.effectChance
            def.effectChance = math.min(100, oldChance * 2)
          end
          local okUse, result = pcall(originalUse, self, attacker, defender, moveId)
          if oldChance then def.effectChance = oldChance end
          if not okUse then error(result) end

          -- Pressure: extra PP when targeting a Pressure holder.
          if not isCalled and def and defender and attacker ~= defender
              and Abilities.abilityOf(self, defender) == "PRESSURE"
              and attacker.moves then
            for _, mv in ipairs(attacker.moves) do
              local id = type(mv) == "table" and mv.id or mv
              if id == moveId and type(mv) == "table" and mv.pp then
                -- useMove already spent 1; spend one more.
                mv.pp = math.max(0, mv.pp - 1)
                break
              end
            end
          end

          if attacker and attacker.expTormented and not isCalled then
            attacker.expTormentLast = moveId
          end
          return result
        end
        B._krTauntWrap = true
      end

      -- Heal Block: refuse Battle:heal.
      if not B._krHealBlockWrap then
        local originalHeal = B.heal
        B.heal = function(self, mon, amount)
          if mon and (mon.expHealBlockTurns or 0) > 0 then
            self:emit({ kind = "message",
              text = self:monName(mon) .. " can't restore HP!" })
            return 0
          end
          return originalHeal(self, mon, amount)
        end
        B._krHealBlockWrap = true
      end

      -- Ability + Safeguard gates on every status inflict (natives + EXP).
      if not B._krStatusAbilityWrap then
        local originalStatus = B.applyStatus
        B.applyStatus = function(self, mon, status, source)
          if not self._krStatusFromCompat then
            if Abilities.blocksStatus(self, mon, status, {}) then
              local name = self:monName(mon)
              local ab = Abilities.abilityOf(self, mon)
              if ab then
                self:emit({ kind = "message",
                  text = name .. "'s " .. ab:gsub("_", " ") .. " prevented it!" })
              end
              return false
            end
            local adapter = Adapters.forBattle(self)
            local side = adapter and adapter:ownSide(mon)
            if side and (side.expSafeguardTurns or 0) > 0 then
              self:emit({ kind = "message", text = "But it failed!" })
              return false
            end
          end
          return originalStatus(self, mon, status, source)
        end
        B._krStatusAbilityWrap = true
      end

      -- Damaging Fire hits thaw a frozen target (Gen 3 CheckDefrost).
      if not B._krFalseSwipeWrap then
        local originalDeal = B.dealDamage
        local ME = require("mods.Kanto-Reforged.battle.move_effects")
        B.dealDamage = function(self, attacker, defender, damage, opts)
          local def = opts and opts.move
          if def and def.effect == "EFFECT_FALSE_SWIPE"
              and type(damage) == "number"
              and damage >= (defender.hp or 0) then
            damage = math.max(0, (defender.hp or 0) - 1)
          end
          local before = defender and defender.hp
          local dealt = originalDeal(self, attacker, defender, damage, opts)
          if dealt and dealt > 0 and defender and before and defender.hp < before then
            local move = def
            if type(move) == "string" then
              move = self.data and self.data.moves and self.data.moves[move]
            end
            if not move and opts and opts.moveId and self.data and self.data.moves then
              move = self.data.moves[opts.moveId]
            end
            ME.thawTargetFromFire(self, defender, move)
          end
          return dealt
        end
        B._krFalseSwipeWrap = true
      end
    end)
  end)

  -- Gen 3 freeze: 20% thaw + act, Flame Wheel / Sacred Fire thaw the user.
  pcall(function()
    local ME = require("mods.Kanto-Reforged.battle.move_effects")
    mod.content.statuses:patch("freeze", {
      beforeMovePriority = 30,
      beforeMove = ME.freezeBeforeMoveGen2,
    })
  end)

  -- Sleep Talk / Snore while asleep (Gen2 content statuses; Gen1 keeps its own).
  pcall(function()
    mod.content.statuses:patch("sleep", {
      beforeMovePriority = 40,
      beforeMove = function(battle, mon, name)
        mon.statusTurns = (mon.statusTurns or 1) - 1
        if mon.statusTurns <= 0 then
          mon.status = nil
          mon.statusTurns = nil
          battle:emit({ kind = "message", text = name .. " woke up!" })
          return true
        end
        local pending = mon.expPendingMove
        if pending == "SLEEP_TALK" or pending == "SNORE" then
          battle:emit({ kind = "message", text = name .. " is fast asleep!" })
          return true
        end
        battle:emit({ kind = "message", text = name .. " is fast asleep!" })
        return false
      end,
    })
  end)

  mod.log:info("Gen2 move effects: core primary + hook install")
end

return MoveEffectsGen2
