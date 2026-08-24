-- Gen 3 partial trapping (Wrap / Bind / Fire Spin / …) on Gen 1.
return function(T, Data, run)
  local PartialTrap = require("mods.Kanto-Reforged.battle.partial_trap")
  local Status = require("src.battle.Status")
  local Host = require("mods.Kanto-Reforged.core.host")

  PartialTrap.install({
    events = { on = function() end },
    log = { info = function() end, warn = function() end },
  })

  T.eq(PartialTrap.chipAmount(80), 5, "partial trap chips 1/16 max HP")
  T.eq(PartialTrap.chipAmount(15), 1, "partial trap chip is at least 1")

  local modern = { ruleset = { name = "MODERN", krGen3PartialTrap = true } }
  T.check(PartialTrap.active(modern), "Gen3 partial trap always enabled")
  T.check(PartialTrap.active({ ruleset = { name = "GEN 1" } }),
    "legacy GEN 1 table still gets Gen3 trap under KR")

  local msgs = {}
  local function say(text) msgs[#msgs + 1] = text end

  local function battler(name, hp, types, isPlayer)
    return {
      name = name,
      isPlayer = isPlayer,
      curTypes = types or { "NORMAL" },
      mon = {
        species = "RATTATA",
        hp = hp,
        stats = { hp = hp },
        types = types or { "NORMAL" },
      },
    }
  end

  -- Apply: victim tagged, trapper not locked into Gen1 multiturn.
  do
    msgs = {}
    local user = battler("Ekans", 40, { "POISON" }, true)
    local target = battler("Rattata", 32, { "NORMAL" }, false)
    local ctx = {
      battle = modern,
      user = user,
      target = target,
      move = { id = "WRAP", name = "WRAP" },
      rng = function() return 3 end,
      say = say,
    }
    PartialTrap.apply(ctx)
    T.eq(target.expPartialTrapTurns, 3, "Wrap sets 2-5 turn trap on victim")
    T.eq(target.expPartialTrapMove, "WRAP", "trap remembers move name")
    T.eq(user.trappingTurns, nil, "trapper is not Gen1-locked")
    T.eq(user.trapDamage, nil, "no Gen1 trapDamage snapshot")
    T.eq(target.boundTurns, nil, "victim is not immobilized")
    T.check(#msgs > 0, "Wrap prints a trap message")
  end

  -- Ghost immunity
  do
    local user = battler("Ekans", 40, { "POISON" }, true)
    local ghost = battler("Gastly", 40, { "GHOST", "POISON" }, false)
    PartialTrap.apply({
      battle = modern, user = user, target = ghost,
      move = { id = "WRAP", name = "WRAP" },
      rng = function() return 2 end, say = function() end,
    })
    T.check(not PartialTrap.isTrapped(ghost), "Ghost is immune to Wrap trap")
  end

  -- Substitute blocks trap
  do
    local user = battler("Ekans", 40, { "POISON" }, true)
    local sub = battler("Rattata", 40, { "NORMAL" }, false)
    sub.substituteHP = 10
    PartialTrap.apply({
      battle = modern, user = user, target = sub,
      move = { id = "BIND", name = "BIND" },
      rng = function() return 2 end, say = function() end,
    })
    T.check(not PartialTrap.isTrapped(sub), "Substitute blocks partial trap")
  end

  -- End-of-turn chip then free (via core residual_handlers).
  do
    local mon = battler("Rattata", 32, { "NORMAL" }, false)
    mon.expPartialTrapTurns = 2
    mon.expPartialTrapMove = "WRAP"
    local msgs = {}
    local adapter = {
      _battle = modern,
      isFainted = function(_, b) return (b.mon.hp or 0) <= 0 end,
      hp = function(_, b) return b.mon.hp end,
      maxHp = function(_, b) return b.mon.stats.hp end,
      hasSubstitute = function() return false end,
      gen3PartialTrapActive = function() return true end,
      applyHpLoss = function(_, b, dmg) b.mon.hp = math.max(0, b.mon.hp - dmg) end,
      say = function(_, text) msgs[#msgs + 1] = text end,
      displayName = function(_, b) return b.name end,
      trap = {
        get = function(b) return b.expPartialTrapTurns or 0 end,
        moveName = function(b) return b.expPartialTrapMove end,
        set = function(b, turns, id, name)
          b.expPartialTrapTurns = turns
          b.expPartialTrapMoveId = id
          b.expPartialTrapMove = name
        end,
        clear = function(b) PartialTrap.clear(b) end,
      },
    }
    PartialTrap.applyResidualChip(adapter, mon)
    T.eq(mon.mon.hp, 30, "first tick chips 1/16 of 32")
    T.eq(mon.expPartialTrapTurns, 1, "turns decrement after chip")
    T.check(msgs[1] and msgs[1]:find("hurt", 1, true), "chip message")

    msgs = {}
    PartialTrap.applyResidualChip(adapter, mon)
    T.eq(mon.mon.hp, 28, "second tick chips again")
    T.check(not PartialTrap.isTrapped(mon), "trap ends after last chip")
    T.check(msgs[2] and msgs[2]:find("freed", 1, true), "freed message")
  end

  -- Core residual phase owns Gen3 trap chip (not Status.residual).
  do
    local Rules = require("mods.Kanto-Reforged.battle.core.rules")
    local mon = battler("Rattata", 48, { "NORMAL" }, false)
    mon.expPartialTrapTurns = 1
    mon.expPartialTrapMove = "FIRE SPIN"
    local msgs = {}
    local adapter = {
      _battle = modern,
      isFainted = function(_, b) return (b.mon.hp or 0) <= 0 end,
      hp = function(_, b) return b.mon.hp end,
      maxHp = function(_, b) return b.mon.stats.hp end,
      hasSubstitute = function() return false end,
      gen3PartialTrapActive = function() return true end,
      applyHpLoss = function(_, b, dmg) b.mon.hp = math.max(0, b.mon.hp - dmg) end,
      say = function(_, text) msgs[#msgs + 1] = text end,
      displayName = function(_, b) return b.name end,
      trap = {
        get = function(b) return b.expPartialTrapTurns or 0 end,
        moveName = function(b) return b.expPartialTrapMove end,
        set = function(b, turns, id, name)
          b.expPartialTrapTurns = turns
          b.expPartialTrapMoveId = id
          b.expPartialTrapMove = name
        end,
        clear = function(b) PartialTrap.clear(b) end,
      },
    }
    PartialTrap.applyResidualChip(adapter, mon)
    T.eq(mon.mon.hp, 45, "core residual applies partial-trap chip")
    T.check(not PartialTrap.isTrapped(mon), "last residual frees the victim")
    T.check(#msgs > 0, "residual returns trap text")
  end

  -- gen3PartialTrapActive adapter hook (no _battle in call sites).
  do
    local mon = battler("Rattata", 32, { "NORMAL" }, false)
    mon.expPartialTrapTurns = 1
    mon.expPartialTrapMove = "WRAP"
    local adapter = {
      gen3PartialTrapActive = function() return true end,
      isFainted = function(_, b) return (b.mon.hp or 0) <= 0 end,
      hp = function(_, b) return b.mon.hp end,
      maxHp = function(_, b) return b.mon.stats.hp end,
      hasSubstitute = function() return false end,
      applyHpLoss = function(_, b, dmg) b.mon.hp = math.max(0, b.mon.hp - dmg) end,
      say = function() end,
      displayName = function(_, b) return b.name end,
      trap = {
        get = function(b) return b.expPartialTrapTurns or 0 end,
        moveName = function(b) return b.expPartialTrapMove end,
        set = function(b, turns, id, name)
          b.expPartialTrapTurns = turns
          b.expPartialTrapMoveId = id
          b.expPartialTrapMove = name
        end,
        clear = function(b) PartialTrap.clear(b) end,
      },
    }
    PartialTrap.applyResidualChip(adapter, mon)
    T.check(not PartialTrap.isTrapped(mon), "gen3PartialTrapActive gate allows chip")
  end

  -- Data.move_effects TRAPPING_EFFECT is patched to Gen3 apply
  do
    local rec = Data.move_effects.TRAPPING_EFFECT
    T.check(rec and rec._krGen3PartialTrap, "TRAPPING_EFFECT patched for Gen3")
    local user = battler("Tentacool", 40, { "WATER", "POISON" }, true)
    local target = battler("Rattata", 64, { "NORMAL" }, false)
    msgs = {}
    rec.afterDamage({
      battle = modern, user = user, target = target,
      move = { id = "WRAP", name = "WRAP" },
      rng = function(a, b)
        if b then return a end
        return 2
      end,
      say = say,
    })
    T.check(PartialTrap.isTrapped(target), "patched afterDamage traps the target")
    T.eq(user.trappingTurns, nil, "patched afterDamage does not lock trapper")
  end

  -- Always Gen3: even a leftover "GEN 1" ruleset table uses KR trap fields.
  do
    local rec = Data.move_effects.TRAPPING_EFFECT
    local user = battler("Ekans", 40, { "POISON" }, true)
    local target = battler("Rattata", 40, { "NORMAL" }, false)
    rec.afterDamage({
      battle = { ruleset = { name = "GEN 1" } }, user = user, target = target,
      move = { id = "WRAP", name = "WRAP" },
      rawDamage = 12,
      rng = function(a, b)
        if b then return a end -- min turns when called as rng(min, max)
        return 2
      end,
      say = function() end,
    })
    T.check(PartialTrap.isTrapped(target),
      "legacy GEN 1 battle still sets Gen3 trap fields")
    T.eq(user.trappingTurns, nil, "trapper is not locked under KR Gen3 trap")
  end

  -- Rapid Spin clears the user's partial trap
  do
    local spin = Data.move_effects.EXP_RAPID_SPIN_EFFECT
    T.check(spin and spin.afterDamage, "Rapid Spin afterDamage present")
    local user = battler("Donphan", 50, { "GROUND" }, true)
    user.expPartialTrapTurns = 3
    user.expPartialTrapMove = "WRAP"
    user.stages = {}
    spin.afterDamage({
      user = user,
      target = battler("Ekans", 40, { "POISON" }, false),
      side = function() return { hazards = {} } end,
      move = { id = "RAPID_SPIN", statChanges = nil },
      say = function() end,
    })
    T.check(not PartialTrap.isTrapped(user), "Rapid Spin clears partial trap")
  end

  if Host.isGen1() then
    local BattleState = require("src.battle.BattleState")
    T.check(BattleState._krGen3PartialTrap,
      "BattleState Gen3 partial-trap hooks installed")
    local locked = BattleState.fightLockedAction({
      ruleset = { krGen3PartialTrap = true },
      enemy = { trappingTurns = 2 },
      player = {},
    }, { isPlayer = true })
    -- Engine would return bound; Gen3 hook must not lock the victim.
    T.eq(locked, nil, "partially trapped victim is not fight-locked")
  end
end
