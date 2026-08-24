-- Gen 2/3 move effects the Gen 1 engine does not ship.
-- Moves point at these via pokemon_data.lua (effect = "EXP_...").
-- Stat-change payloads live on the move record (statChanges / statChance /
-- statTarget), which the schema preserves as unknown fields.

local Strings = require("src.core.Strings")

local MoveEffects = {}

local CoreInstall = require("mods.Kanto-Reforged.battle.core.install")
local CoreEffects = require("mods.Kanto-Reforged.battle.core.effects")
local EffectsInstall = require("mods.Kanto-Reforged.battle.core.effects.install")
local CtxShim = require("mods.Kanto-Reforged.battle.core.effects._ctx")
local Adapters = require("mods.Kanto-Reforged.battle.adapters")
local EffectCtx = require("mods.Kanto-Reforged.battle.core.effect_ctx")

local function coreRegister(mod, id, kind)
  mod.content.move_effects:register(id, {
    kind = kind or "primary",
    accuracyChecked = true,
    run = function(ctx)
      local msgs = CtxShim.runPrimary(id, ctx, function(ec)
        CoreEffects.run(id, ec)
      end)
      return msgs
    end,
  })
end

local function coreRegisterFull(mod, id, kind)
  local spec = CoreEffects.hooks(id)
  if not spec then return end
  local record = { kind = kind or spec.kind or "full" }
  if spec.accuracyChecked then record.accuracyChecked = true end
  if spec.run then
    record.run = function(ctx)
      return CtxShim.with(id, ctx, function(ec, raw)
        return CoreEffects.runHook(id, "run", ec, raw)
      end)
    end
  end
  for _, name in ipairs({ "afterDamage", "chooseDamage", "gate", "onMiss", "callsMove" }) do
    if spec[name] then
      record[name] = function(ctx)
        return CtxShim.with(id, ctx, function(ec, raw)
          return CoreEffects.runHook(id, name, ec, raw)
        end)
      end
    end
  end
  mod.content.move_effects:register(id, record)
end

local STAT_LABEL = {
  attack = "ATTACK", defense = "DEFENSE", speed = "SPEED",
  special = "SPECIAL", accuracy = "ACCURACY", evasion = "EVADE",
}

-- Gen 3 Hidden Power type order (PSYCHIC_TYPE matches this engine)
local HP_TYPES = {
  "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST", "STEEL",
  "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC_TYPE", "ICE", "DRAGON", "DARK",
}

local function displayName(b)
  return b.isPlayer and b.name or ("Enemy " .. b.name)
end

local function dv(mon, name)
  return (mon.dvs and mon.dvs[name]) or 0
end

local function bit1(n)
  return math.floor((n % 4) / 2)
end

-- Gen 3 formulas; spa/spd both read the Gen1 special DV.
function MoveEffects.hiddenPower(battler)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local mon = BattleCompat.mon(battler) or battler
  local hp = dv(mon, "hp")
  local atk = dv(mon, "attack")
  local def = dv(mon, "defense")
  local spe = dv(mon, "speed")
  local spc = dv(mon, "special")
  if spc == 0 and mon.dvs and mon.dvs.specialAttack then
    spc = mon.dvs.specialAttack
  end
  local a = (hp % 2) + 2 * (atk % 2) + 4 * (def % 2)
      + 8 * (spe % 2) + 16 * (spc % 2) + 32 * (spc % 2)
  local typeIndex = math.floor(a * 15 / 63)
  local b = bit1(hp) + 2 * bit1(atk) + 4 * bit1(def)
      + 8 * bit1(spe) + 16 * bit1(spc) + 32 * bit1(spc)
  local power = math.floor(b * 40 / 63) + 30
  return HP_TYPES[typeIndex + 1] or "FIGHTING", power
end

function MoveEffects.weatherBall(battle)
  local Weather = require("mods.Kanto-Reforged.battle.weather")
  local weather = Weather.current(battle)
  if weather == "SUNNY" then return "FIRE", 100 end
  if weather == "RAINY" then return "WATER", 100 end
  if weather == "SANDSTORM" then return "ROCK", 100 end
  if weather == "HAIL" or weather == "SNOWY" then return "ICE", 100 end
  return "NORMAL", 50
end

-- Gen 3 Flail / Reversal power from remaining HP fraction
function MoveEffects.flailPower(battler)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local hp = BattleCompat.hp(battler)
  local maxHp = BattleCompat.maxHp(battler)
  local n = math.floor(hp * 48 / math.max(1, maxHp))
  if n < 1 then return 200 end
  if n < 5 then return 150 end
  if n < 10 then return 100 end
  if n < 17 then return 80 end
  if n < 33 then return 40 end
  return 20
end

-- Gen 1 has no friendship; approximate from DVs (max Return ≈ 102)
function MoveEffects.returnPower(battler)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local mon = BattleCompat.mon(battler) or {}
  local dvs = mon.dvs or {}
  local sum = (dvs.hp or 0) + (dvs.attack or 0) + (dvs.defense or 0)
      + (dvs.speed or 0) + (dvs.special or dvs.specialAttack or 0)
  return math.max(1, math.floor(sum * 102 / 75))
end

function MoveEffects.frustrationPower(battler)
  return math.max(1, 102 - MoveEffects.returnPower(battler))
end

-- Gen 2+ sleep: wake in this speed slot and act; still asleep only burns
-- this mon's beat. Sleep Talk / Snore still fire while SLP.
function MoveEffects.sleepBeforeMove(battler, rng, battle)
  local pending = battler.expPendingMove
  battler.sleepTurns = (battler.sleepTurns or 1) - 1
  if battler.sleepTurns <= 0 then
    battler.mon.status = nil
    -- Plain nickname; sayStatusMsg / prefixEnemy adds "Enemy ".
    return true, { Strings("%s\nwoke up!", battler.name) }
  end
  if pending == "SLEEP_TALK" or pending == "SNORE" then
    return true, { Strings("%s\nis fast asleep!", battler.name) }
  end
  return false, { Strings("%s\nis fast asleep!", battler.name) }
end

-- Gen 3 freeze: 20% thaw before the move (and act that turn). Flame Wheel /
-- Sacred Fire thaw the user. Damaging Fire hits thaw the target.
-- Gen 1 otherwise never thaws, which softlocks under Shadow Tag (GH #2).
MoveEffects.FREEZE_THAW_SIDES = 5

MoveEffects.USER_THAW_MOVES = {
  FLAME_WHEEL = true,
  SACRED_FIRE = true,
}

function MoveEffects.isDamagingFireMove(move)
  if not move then return false end
  if move.type ~= "FIRE" then return false end
  return (move.power or 0) > 0
end

function MoveEffects.pendingMoveOf(battler)
  if not battler then return nil end
  return battler.expPendingMove
    or (battler.mon and battler.mon.expPendingMove)
end

local function rollThaw(rng, battle)
  rng = rng or (battle and battle.rng) or math.random
  local ok, n = pcall(rng, 0, MoveEffects.FREEZE_THAW_SIDES - 1)
  if ok and type(n) == "number" then
    return n == 0
  end
  ok, n = pcall(rng, MoveEffects.FREEZE_THAW_SIDES)
  if ok and type(n) == "number" then
    -- 0..n-1 (Gold BattleRandom) or 1..n (love.math.random(n))
    return n == 0 or n == 1
  end
  ok, n = pcall(rng)
  if ok and type(n) == "number" then
    return (n % MoveEffects.FREEZE_THAW_SIDES) == 0
  end
  return false
end

function MoveEffects.freezeBeforeMove(battler, rng, battle)
  local pending = MoveEffects.pendingMoveOf(battler)
  if pending and MoveEffects.USER_THAW_MOVES[pending] then
    battler.mon.status = nil
    return true, { Strings("%s\nthawed out!", battler.name) }
  end
  if rollThaw(rng, battle) then
    battler.mon.status = nil
    return true, { Strings("%s\nthawed out!", battler.name) }
  end
  return false, { Strings("%s\nis frozen solid!", battler.name) }
end

-- Gold status records: beforeMove(battle, mon, name) -> canAct
function MoveEffects.freezeBeforeMoveGen2(battle, mon, name)
  local pending = mon and mon.expPendingMove
  if pending and MoveEffects.USER_THAW_MOVES[pending] then
    mon.status = nil
    battle:emit({ kind = "message", text = name .. " thawed out!" })
    return true
  end
  local roll
  if battle and type(battle.random) == "function" then
    roll = battle.random(MoveEffects.FREEZE_THAW_SIDES)
  else
    roll = math.random(0, MoveEffects.FREEZE_THAW_SIDES - 1)
  end
  if roll == 0 then
    mon.status = nil
    battle:emit({ kind = "message", text = name .. " thawed out!" })
    return true
  end
  battle:emit({ kind = "message", text = name .. " is frozen solid!" })
  return false
end

function MoveEffects.thawTargetFromFire(battle, target, move)
  if not MoveEffects.isDamagingFireMove(move) then return false end
  local mon = (target and target.mon) or target
  if not mon then return false end
  local st = mon.status
  if st ~= "FRZ" and st ~= "freeze" then return false end
  mon.status = nil
  local name
  if target and target.mon then
    name = target.isPlayer and target.name or ("Enemy " .. target.name)
  elseif battle and type(battle.monName) == "function" then
    name = battle:monName(target)
  else
    name = (target and target.name) or "POKéMON"
  end
  local msg = Strings("Fire defrosted\n%s!", name)
  if battle and battle.sayNext then
    battle:sayNext(msg)
  elseif battle and battle.emit then
    battle:emit({ kind = "message", text = msg })
  end
  return true
end

-- Gen 3 Magnitude: power + strength number
function MoveEffects.magnitudePower(rng)
  local r = (rng or math.random)(0, 99)
  if r < 5 then return 10, 4 end
  if r < 15 then return 30, 5 end
  if r < 35 then return 50, 6 end
  if r < 65 then return 70, 7 end
  if r < 85 then return 90, 8 end
  if r < 95 then return 110, 9 end
  return 150, 10
end

function MoveEffects.applyHazards(battle, battler, side)
  local SwitchIn = require("mods.Kanto-Reforged.battle.switch_in")
  local adapter = Adapters.forBattle(battle)
  if adapter then
    SwitchIn.applyHazards(adapter, battler, side)
  end
end

function MoveEffects.register(mod)
  -- Sleep: Gen 2+ wake-and-attack. Must be a content patch so the post-entry
  -- merge writes it into Data.statuses (install-time edits of Data are wiped).
  mod.content.statuses:patch("SLP", {
    beforeMove = MoveEffects.sleepBeforeMove,
  })
  mod.content.statuses:patch("FRZ", {
    beforeMove = MoveEffects.freezeBeforeMove,
  })

  -- Gen 2+: Steel (and Poison) cannot be poisoned / badly poisoned.
  local function canPoison(target)
    if not target then return false end
    for _, t in ipairs(target.curTypes or {}) do
      if t == "POISON" or t == "STEEL" then return false end
    end
    return true
  end
  mod.content.statuses:patch("PSN", {
    canInflict = canPoison,
  })

  -- Core move effects (primary + full hooks)
  for _, id in ipairs(EffectsInstall.allPrimary()) do
    coreRegister(mod, id)
  end
  for _, id in ipairs(EffectsInstall.allHooks()) do
    coreRegisterFull(mod, id)
  end
end

-- Battle wiring: Encore, Taunt, Attract, Fake Out, hazards, Safeguard,
-- Sturdy, Destiny Bond, Perish Song, residuals.
function MoveEffects.install(mod)
  local BattleState = require("src.battle.BattleState")
  local StatusRegistry = require("src.battle.StatusRegistry")
  local Strings = require("src.core.Strings")
  local Abilities = require("mods.Kanto-Reforged.battle.abilities")
  require("mods.Kanto-Reforged.battle.partial_trap").install(mod)

  local original_fightLocked = BattleState.fightLockedAction
  BattleState.fightLockedAction = function(self, battler)
    local locked = original_fightLocked(self, battler)
    if locked then return locked end
    if battler.expEncoreTurns and battler.expEncoreTurns > 0 and battler.expEncoreMove then
      for _, mv in ipairs(battler.curMoves or {}) do
        if mv.id == battler.expEncoreMove and (mv.pp or 0) > 0 then
          return mv
        end
      end
      battler.expEncoreTurns = nil
      battler.expEncoreMove = nil
    end
    if battler.expUproarTurns and battler.expUproarTurns > 0 and battler.expUproarMove then
      return battler.expUproarMove
    end
    return nil
  end

  -- Rollout / Ice Ball: skip the battle menu like Thrash (forced continuations).
  local original_menuLocked = BattleState.menuLockedAction
  BattleState.menuLockedAction = function(self, battler)
    local locked = original_menuLocked(self, battler)
    if locked then return locked end
    if battler.expRolloutMove and (battler.expRollout or 0) > 0
        and (battler.expRollout or 0) < 5 then
      return battler.expRolloutMove
    end
    return nil
  end

  -- Clear Rollout lock on paralysis / confusion self-hit (same as Thrash).
  -- Also clear invulnerable alongside charging: the engine intentionally
  -- skips the invulnerable clear on full-paralysis interrupts (the famous
  -- Gen 1 Fly/Dig glitch), but that causes a permanent-underground softlock
  -- in this mod.  We always clear both together here so the mon can be hit
  -- normally after the charge is interrupted.
  local original_clearVolatiles = BattleState.clearVolatiles
  BattleState.clearVolatiles = function(self, user, selfHit)
    local wasCharging = user and user.charging
    original_clearVolatiles(self, user, selfHit)
    -- If charging was cleared (i.e. user had it before and lost it), also
    -- clear invulnerable regardless of selfHit so no ghost-underground state.
    if user and wasCharging and not user.charging then
      user.invulnerable = nil
    end
    if user then
      user.expRollout = nil
      user.expRolloutMove = nil
    end
  end

  -- Allow Sleep Talk / Snore while asleep; stash pending move id
  local original_execute = BattleState.executeAction
  BattleState.executeAction = function(self, user, target, action)
    if user and action and action.id then
      user.expPendingMove = action.id
    end
    original_execute(self, user, target, action)
    if user then user.expPendingMove = nil end
  end

  -- Sleep: keep Status.RECORDS in sync (fallback when no battle.data.statuses).
  do
    local Status = require("src.battle.Status")
    if Status.RECORDS and Status.RECORDS.SLP then
      Status.RECORDS.SLP.beforeMove = MoveEffects.sleepBeforeMove
      Status.RECORDS.SLP._expSleepModern = true
      Status.RECORDS.SLP._expSleepTalk = true
    end
    if Status.RECORDS and Status.RECORDS.FRZ then
      Status.RECORDS.FRZ.beforeMove = MoveEffects.freezeBeforeMove
    end
    if Status.RECORDS and Status.RECORDS.PSN then
      Status.RECORDS.PSN.canInflict = function(target)
        if not target then return false end
        for _, t in ipairs(target.curTypes or {}) do
          if t == "POISON" or t == "STEEL" then return false end
        end
        return true
      end
    end
  end

  -- After the loader merge, Data.statuses may still be the pre-patch table
  -- if install ran mid-entry; re-apply once mods finish loading.
  if mod and mod.events and not MoveEffects._expSleepLoadedHook then
    mod.events:on("mods.loaded", function()
      local Data = require("src.core.Data")
      local Status = require("src.battle.Status")
      if Data.statuses and Data.statuses.SLP then
        Data.statuses.SLP.beforeMove = MoveEffects.sleepBeforeMove
      end
      if Status.RECORDS and Status.RECORDS.SLP then
        Status.RECORDS.SLP.beforeMove = MoveEffects.sleepBeforeMove
      end
      if Data.statuses and Data.statuses.FRZ then
        Data.statuses.FRZ.beforeMove = MoveEffects.freezeBeforeMove
      end
      if Status.RECORDS and Status.RECORDS.FRZ then
        Status.RECORDS.FRZ.beforeMove = MoveEffects.freezeBeforeMove
      end
      local function canPoison(target)
        if not target then return false end
        for _, t in ipairs(target.curTypes or {}) do
          if t == "POISON" or t == "STEEL" then return false end
        end
        return true
      end
      if Data.statuses and Data.statuses.PSN then
        Data.statuses.PSN.canInflict = canPoison
      end
      if Status.RECORDS and Status.RECORDS.PSN then
        Status.RECORDS.PSN.canInflict = canPoison
      end
    end)
    MoveEffects._expSleepLoadedHook = true
  end

  -- Hyper Beam recharge path had its own Gen 1 sleep block (always lose the
  -- turn). Match wake-and-attack: still asleep skips; waking continues.
  if not BattleState._expSleepPreRecharge then
    local original_preRecharge = BattleState.preRechargeChecks
    BattleState.preRechargeChecks = function(self, user, target)
      local mon = user and user.mon
      if mon and mon.status == "SLP" then
        user.sleepTurns = (user.sleepTurns or 1) - 1
        if user.sleepTurns <= 0 then
          mon.status = nil
          self:sayNext(Strings("%s\nwoke up!", displayName(user)))
          return false -- woke: continue this speed slot (recharge / move)
        end
        self:statusOnomatopoeia(user, "sleep")
        return true -- still asleep: only this mon's beat is spent
      end
      if mon and mon.status == "FRZ" then
        local canMove, msgs = MoveEffects.freezeBeforeMove(user, self.rng, self)
        for _, m in ipairs(msgs or {}) do
          if self.sayStatusMsg then
            self:sayStatusMsg(user, m)
          else
            self:sayNext(m)
          end
        end
        return not canMove
      end
      return original_preRecharge(self, user, target)
    end
    BattleState._expSleepPreRecharge = true
  end

  local original_perform = BattleState.performMove
  BattleState.performMove = function(self, user, target, moveInst, isCalled)
    local move = self:moveDef(moveInst)
    local function announceFail(msg)
      local enemyUnlimited = not user.isPlayer and self.kind ~= "link"
          and self.ruleset and self.ruleset.enemyUnlimitedPP
      if not isCalled and not enemyUnlimited and not (moveInst and moveInst.struggle) then
        moveInst.pp = math.max(0, (moveInst.pp or 1) - 1)
      end
      self:sayNext(Strings("%s\nused %s!",
        user.isPlayer and user.name or ("Enemy " .. user.name),
        move and move.name or "?"))
      self:sayNext(msg)
    end

    if move and user.expTauntedTurns and user.expTauntedTurns > 0
        and (move.power or 0) == 0 then
      announceFail(Strings("%s can't use\n%s after the TAUNT!",
        user.isPlayer and user.name or ("Enemy " .. user.name), move.name))
      return
    end

    -- Torment: cannot select the same move twice in a row
    if move and user.expTormented and user.expTormentLast == move.id and not isCalled then
      announceFail(Strings("%s can't use the\nsame move twice!",
        user.isPlayer and user.name or ("Enemy " .. user.name)))
      return
    end

    -- Imprison: can't use a move the imprisoner also knows
    if move and target and target.expImprison and not isCalled then
      for _, mv in ipairs(target.curMoves or {}) do
        if mv.id == move.id then
          announceFail(Strings("%s can't use the\nsealed %s!",
            user.isPlayer and user.name or ("Enemy " .. user.name), move.name))
          return
        end
      end
    end
    -- Also check if USER is imprisoned by the foe
    if move and user and not isCalled then
      local foe = user.isPlayer and self.enemy or self.player
      if foe and foe.expImprison then
        for _, mv in ipairs(foe.curMoves or {}) do
          if mv.id == move.id then
            announceFail(Strings("%s can't use the\nsealed %s!",
              user.isPlayer and user.name or ("Enemy " .. user.name), move.name))
            return
          end
        end
      end
    end

    -- Snatch: steal foe's status move
    if move and (move.power or 0) == 0 and target and target.expSnatch and not isCalled
        and move.id ~= "SNATCH" then
      target.expSnatch = nil
      self:sayNext(Strings("%s snatched\n%s's move!",
        target.isPlayer and target.name or ("Enemy " .. target.name),
        user.isPlayer and user.name or ("Enemy " .. user.name)))
      original_perform(self, target, user, moveInst, true)
      return
    end

    -- Damp: block Explosion / Selfdestruct
    if move and (move.effect == "EXPLODE_EFFECT"
        or move.id == "EXPLOSION" or move.id == "SELFDESTRUCT"
        or move.id == "SELF_DESTRUCT") then
      for _, b in ipairs({ self.player, self.enemy }) do
        if Abilities.abilityOf(self, b) == "DAMP" then
          announceFail(Strings("%s cannot use\n%s because of DAMP!",
            user.isPlayer and user.name or ("Enemy " .. user.name),
            move.name))
          return
        end
      end
    end

    -- Soundproof: block sound moves targeting the holder
    if move and target and Abilities.isSoundMove(move.id)
        and Abilities.abilityOf(self, target) == "SOUNDPROOF"
        and user ~= target then
      announceFail(Strings("It doesn't affect\n%s!",
        target.isPlayer and target.name or ("Enemy " .. target.name)))
      return
    end

    -- Magic Coat: bounce status moves
    if move and target and target.expMagicCoat and not isCalled
        and (move.power or 0) == 0 and move.id ~= "MAGIC_COAT"
        and move.id ~= "SKETCH" and move.id ~= "ROLE_PLAY"
        and move.id ~= "SKILL_SWAP" and move.id ~= "PSYCH_UP" then
      target.expMagicCoat = nil
      self:sayNext(Strings("%s bounced the\n%s back!",
        target.isPlayer and target.name or ("Enemy " .. target.name),
        move.name))
      local ppBefore = moveInst and moveInst.pp
      original_perform(self, target, user, moveInst, true)
      if ppBefore and moveInst and moveInst.pp and moveInst.pp == ppBefore
          and not (moveInst.struggle) then
        -- bounced call shouldn't refund; original_perform with isCalled skips PP
        moveInst.pp = math.max(0, (ppBefore or 1) - 1)
      end
      return
    end

    local ppBefore = moveInst and moveInst.pp
    -- Rollout / Ice Ball: PP only on the first hit of a set (like Thrash).
    local rolloutCont = user and moveInst and user.expRolloutMove == moveInst
        and (user.expRollout or 0) > 0
    self.expCurrentMoveDef = move
    original_perform(self, user, target, moveInst, isCalled)
    self.expCurrentMoveDef = nil
    if rolloutCont and moveInst and ppBefore and moveInst.pp and moveInst.pp < ppBefore then
      moveInst.pp = ppBefore
    end

    -- Pressure: extra PP when targeting a Pressure holder
    if ppBefore and moveInst and moveInst.pp and moveInst.pp < ppBefore
        and target and user ~= target and not isCalled
        and Abilities.abilityOf(self, target) == "PRESSURE" then
      moveInst.pp = math.max(0, moveInst.pp - 1)
    end

    -- Torment tracking
    if move and user.expTormented and not isCalled then
      user.expTormentLast = move.id
    end
  end

  local original_inflict = StatusRegistry.inflict
  StatusRegistry.inflict = function(battle, target, status, opts)
    opts = opts or {}
    local side = battle and battle.sideOf and battle:sideOf(target)
    if side and side.expSafeguardTurns and side.expSafeguardTurns > 0 then
      return {}
    end
    local ability = Abilities.abilityOf(battle, target)
    if ability == "INSOMNIA" or ability == "VITAL_SPIRIT" then
      if status == "SLP" then return {} end
    end
    -- Uproar prevents sleep
    if status == "SLP" and battle and battle.expUproarActive then
      return {}
    end
    if ability == "LIMBER" and status == "PAR" then return {} end
    -- Fire / Electric status moves only (not Flame Body / Static secondaries)
    if ability == "FLASH_FIRE" and status == "BRN"
        and opts.moveType == "FIRE" and not opts.secondary then
      return {}
    end
    if ability == "LIGHTNING_ROD" and status == "PAR"
        and opts.moveType == "ELECTRIC" and not opts.secondary then
      return {}
    end
    if ability == "MAGMA_ARMOR" and status == "FRZ" then return {} end
    if ability == "WATER_VEIL" and status == "BRN" then return {} end
    if ability == "IMMUNITY" and status == "PSN" then return {} end
    if ability == "OWN_TEMPO" and status == "CONFUSION" then return {} end

    -- Shield Dust: block secondary statuses from damaging moves
    if opts.secondary and ability == "SHIELD_DUST" then
      return {}
    end

    local msgs = original_inflict(battle, target, status, opts)

    -- Early Bird: halve sleep duration
    if msgs and #msgs > 0 and status == "SLP"
        and Abilities.abilityOf(battle, target) == "EARLY_BIRD"
        and target.sleepTurns then
      target.sleepTurns = math.max(1, math.ceil(target.sleepTurns / 2))
    end

    if msgs and #msgs > 0 and Abilities.abilityOf(battle, target) == "SYNCHRONIZE"
        and (status == "PAR" or status == "BRN" or status == "PSN") then
      local source = opts.expSourceBattler
      if not source and battle then
        source = (target.isPlayer and battle.enemy) or battle.player
      end
      if source and source.mon and not source.mon.status then
        original_inflict(battle, source, status, { secondary = true, source = "SYNCHRONIZE" })
      end
    end
    return msgs
  end

  local original_applyDamage = BattleState.applyDamage
  BattleState.applyDamage = function(self, target, dmg)
    if target and target.mon and not target.substituteHP and dmg and dmg > 0 then
      local ability = Abilities.abilityOf(self, target)
      if ability == "STURDY"
          and target.mon.hp == target.mon.stats.hp
          and dmg >= target.mon.hp then
        dmg = target.mon.hp - 1
        self:sayNext(Strings("%s held on\nusing its STURDY!",
          target.isPlayer and target.name or ("Enemy " .. target.name)))
      elseif target.expEnduring and dmg >= target.mon.hp then
        dmg = target.mon.hp - 1
        self:sayNext(Strings("%s endured\nthe hit!",
          target.isPlayer and target.name or ("Enemy " .. target.name)))
      end
    end
    local beforeHp = target and target.mon and target.mon.hp
    local dealt = original_applyDamage(self, target, dmg)
    if dealt and dealt > 0 and target then
      target.expTookDamageThisTurn = true
      if beforeHp and target.mon and target.mon.hp < beforeHp then
        MoveEffects.thawTargetFromFire(self, target, self.expCurrentMoveDef)
      end
    end
    return dealt
  end

  local original_onFaint = BattleState.onFaint
  BattleState.onFaint = function(self, battler)
    if battler and battler.expGrudge then
      battler.expGrudge = nil
      local foe = battler.isPlayer and self.enemy or self.player
      if foe and foe.lastMove then
        for _, mv in ipairs(foe.curMoves or {}) do
          if mv.id == foe.lastMove then
            mv.pp = 0
            self:sayNext(Strings("%s's %s\nlost all its PP\ndue to the GRUDGE!",
              foe.isPlayer and foe.name or ("Enemy " .. foe.name),
              foe.lastMove))
            break
          end
        end
      end
    end
    if battler and battler.expDestinyBond then
      battler.expDestinyBond = nil
      local foe = battler.isPlayer and self.enemy or self.player
      if foe and foe.mon and foe.mon.hp > 0 and not foe.faintQueued then
        self:sayNext(Strings("%s took\n%s with it!",
          battler.isPlayer and battler.name or ("Enemy " .. battler.name),
          foe.isPlayer and foe.name or ("Enemy " .. foe.name)))
        foe.mon.hp = 0
        original_onFaint(self, foe)
      end
    end
    return original_onFaint(self, battler)
  end

  -- Baton Pass / U-turn: open party after the turn; skip foe free hit on switch
  local original_endOfTurn = BattleState.endOfTurn
  BattleState.endOfTurn = function(self)
    original_endOfTurn(self)
    if self.result then return end
    local p = self.player
    if p and (p.expPendingBatonOpen or p.expWantsSwitch) and p.mon and p.mon.hp > 0 then
      p.expPendingBatonOpen = nil
      self:openParty()
    end
  end

  local original_resolveSwitch = BattleState.resolveSwitch
  BattleState.resolveSwitch = function(self, newMon)
    local skipFree = (self.player and self.player.expBatonPass)
        or (self.player and self.player.expWantsSwitch)
    if self.player then
      self.player.expWantsSwitch = nil
      self.player.expPendingBatonOpen = nil
    end
    if skipFree then
      self.expSkipNextEnemyAction = true
    end
    return original_resolveSwitch(self, newMon)
  end

  -- already wrapped executeAction above; extend skip-free-hit
  local prev_execute = BattleState.executeAction
  BattleState.executeAction = function(self, user, target, action)
    if self.expSkipNextEnemyAction and user and not user.isPlayer then
      self.expSkipNextEnemyAction = nil
      return
    end
    return prev_execute(self, user, target, action)
  end

  -- Clear Body / White Smoke / Hyper Cutter / Keen Eye: block enemy stage drops
  local VanillaME = require("src.battle.MoveEffects")
  local original_changeStage = VanillaME.changeStage
  VanillaME.changeStage = function(battle, who, stat, delta, fromEnemy)
    if fromEnemy and delta < 0 and who and who.mon then
      local ability = Abilities.abilityOf(battle, who)
      if ability == "CLEAR_BODY" or ability == "WHITE_SMOKE" then
        return { Strings("%s's %s\nprevents stat loss!",
          who.isPlayer and who.name or ("Enemy " .. who.name),
          ability:gsub("_", " ")) }
      end
      if ability == "HYPER_CUTTER" and stat == "attack" then
        return { Strings("%s's HYPER CUTTER\nprevents ATTACK loss!",
          who.isPlayer and who.name or ("Enemy " .. who.name)) }
      end
      if ability == "KEEN_EYE" and stat == "accuracy" then
        return { Strings("%s's KEEN EYE\nprevents accuracy loss!",
          who.isPlayer and who.name or ("Enemy " .. who.name)) }
      end
    end
    -- Simple: double stage changes
    if who and Abilities.abilityOf(battle, who) == "SIMPLE" and delta and delta ~= 0 then
      delta = delta * 2
      if delta > 6 then delta = 6 end
      if delta < -6 then delta = -6 end
    end
    return original_changeStage(battle, who, stat, delta, fromEnemy)
  end

  -- Liquid Ooze: drain heals become damage
  local function patchDrain(effectId)
    local Data = require("src.core.Data")
    local rec = Data.move_effects and Data.move_effects[effectId]
    if rec and rec.afterDamage and not rec._expLiquidOoze then
      local old = rec.afterDamage
      rec.afterDamage = function(ctx)
        if Abilities.abilityOf(ctx.battle, ctx.target) == "LIQUID_OOZE" then
          local dmg = math.max(1, math.floor((ctx.rawDamage or 0) / 2))
          ctx.say(Strings("%s sucked up the\nLIQUID OOZE!",
            ctx.user.isPlayer and ctx.user.name or ("Enemy " .. ctx.user.name)))
          ctx.battle:applyDamage(ctx.user, dmg)
          if ctx.user.mon.hp <= 0 then ctx.battle:onFaint(ctx.user) end
          return
        end
        return old(ctx)
      end
      rec._expLiquidOoze = true
    end
  end

  -- Suction Cups: immune to Roar / Whirlwind forced flee
  local function patchSuctionCups()
    local Data = require("src.core.Data")
    local sw = Data.move_effects and Data.move_effects.SWITCH_AND_TELEPORT_EFFECT
    if sw and sw.perform and not sw._expSuctionCups then
      local old = sw.perform
      sw.perform = function(ctx)
        if ctx.move and (ctx.move.id == "ROAR" or ctx.move.id == "WHIRLWIND")
            and Abilities.abilityOf(ctx.battle, ctx.target) == "SUCTION_CUPS" then
          if ctx.battle.cancelMoveAnim then ctx.battle:cancelMoveAnim() end
          ctx.say(Strings("%s anchors itself\nwith SUCTION CUPS!",
            ctx.target.isPlayer and ctx.target.name or ("Enemy " .. ctx.target.name)))
          return
        end
        return old(ctx)
      end
      sw._expSuctionCups = true
    end
  end

  -- Shield Dust / Serene Grace: wrap secondary move-effect runs
  local function patchSecondaries()
    local Data = require("src.core.Data")
    for id, rec in pairs(Data.move_effects or {}) do
      if rec.kind == "secondary" and rec.run and not rec._expShieldSerene then
        local old = rec.run
        local isExp = type(id) == "string" and id:sub(1, 4) == "EXP_"
        rec.run = function(ctx)
          if Abilities.abilityOf(ctx.battle, ctx.target) == "SHIELD_DUST" then
            return {}
          end
          local msgs = old(ctx)
          -- Vanilla secondaries: Serene Grace ≈ true 2× by retrying only when
          -- the first roll produced no effect messages (chance miss).
          -- EXP_* secondaries double their chance parameter themselves.
          if not isExp and (not msgs or #msgs == 0)
              and Abilities.abilityOf(ctx.battle, ctx.user) == "SERENE_GRACE" then
            msgs = old(ctx)
          end
          return msgs or {}
        end
        rec._expShieldSerene = true
      end
    end
  end

  local function patchAbilityEffects()
    patchDrain("DRAIN_HP_EFFECT")
    patchDrain("DREAM_EATER_EFFECT")
    patchSuctionCups()
    patchSecondaries()
  end
  mod.events:on("game.ready", function() patchAbilityEffects() end)
  patchAbilityEffects()

  mod.events:on("battle.move_used", function(ev)
    if not ev.battle or not ev.user then return end
    local user = ev.user
    user.expDestinyBond = nil -- Destiny Bond lasts until you move again
    if ev.move and ev.move.id == "DESTINY_BOND" then
      user.expDestinyBond = true
    end
    user.expActedThisTurn = true
    if user.expEncoreTurns and user.expEncoreTurns > 0 then
      user.expEncoreTurns = user.expEncoreTurns - 1
      if user.expEncoreTurns <= 0 then
        user.expEncoreTurns = nil
        user.expEncoreMove = nil
      end
    end
    -- Reset Fury Cutter when using a different move
    if ev.move and ev.move.id ~= "FURY_CUTTER" then
      user.expFuryCutter = nil
    end
  end)

  mod.events:on("battle.turn_started", function(ev)
    if not ev.battle then return end
    for _, b in ipairs({ ev.battle.player, ev.battle.enemy }) do
      if b then
        b.expTookDamageThisTurn = nil
        b.expActedThisTurn = nil
        b.expMagicCoat = nil
        -- Inner Focus: clear flinch
        if Abilities.abilityOf(ev.battle, b) == "INNER_FOCUS" then
          b.flinched = nil
        end
      end
    end
  end)

  -- EOT volatiles: core/residual_handlers.lua via core/install.lua
end

return MoveEffects
