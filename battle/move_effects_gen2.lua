-- Gen2/Gold-shaped EXP move effect runners + battle event wiring.
-- Gen1 keeps the full ctx-based MoveEffects.register body.
local Strings = require("src.core.Strings")
local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")

local MoveEffectsGen2 = {}

local function foeSide(battle, attacker)
  if not battle or not battle.sides then return nil end
  if type(battle.sideOf) == "function" then
    local mine = battle:sideOf(attacker)
    if mine == "player" then return battle.sides.enemy or battle.sides[2] end
    if mine == "enemy" then return battle.sides.player or battle.sides[1] end
    -- Numeric / table sides
    if type(mine) == "number" then
      return battle.sides[3 - mine] or battle.sides[mine == 1 and 2 or 1]
    end
  end
  if attacker == battle.player then return battle.sides.enemy or battle.sides[2] end
  return battle.sides.player or battle.sides[1]
end

local function ownSide(battle, attacker)
  if not battle or not battle.sides then return nil end
  if type(battle.sideOf) == "function" then
    local mine = battle:sideOf(attacker)
    if type(mine) == "string" then return battle.sides[mine] end
    if type(mine) == "number" then return battle.sides[mine] end
    return mine
  end
  if attacker == battle.player then return battle.sides.player or battle.sides[1] end
  return battle.sides.enemy or battle.sides[2]
end

local function findHazard(side, id)
  if not side or not side.hazards then return nil end
  for _, h in ipairs(side.hazards) do
    if h.id == id then return h end
  end
  return nil
end

local function sayFail(battle)
  BattleCompat.say(battle, Strings("But it failed!"))
end

local function register(mod, id, record)
  pcall(function()
    if mod.content.move_effects:get(id) then
      mod.content.move_effects:override(id, record)
    else
      mod.content.move_effects:register(id, record)
    end
  end)
end

local function rollChance(battle, percent)
  local Ab = require("mods.Kanto-Reforged.battle.abilities")
  local user = battle and battle._krLastAttacker
  if user and Ab.abilityOf(battle, user) == "SERENE_GRACE" then
    percent = percent * 2
  end
  local roll
  if battle and type(battle.random) == "function" then
    roll = battle.random(100)
  elseif battle and type(battle.rng) == "function" then
    roll = battle.rng(0, 99)
  else
    roll = math.random(0, 99)
  end
  if type(roll) ~= "number" then return false end
  return (math.floor(roll) % 100) < percent
end

function MoveEffectsGen2.register(mod)
  -- Setup / status-stage moves
  register(mod, "EXP_STAT_CHANGES_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def)
      if not BattleCompat.changeStages(battle, attacker, def.statChanges) then
        sayFail(battle)
      end
    end,
  })

  register(mod, "EXP_STAT_DOWN_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def)
      if not defender or not BattleCompat.changeStages(battle, defender, def.statChanges) then
        sayFail(battle)
      end
    end,
  })

  -- Will-O-Wisp
  register(mod, "EXP_BURN_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not BattleCompat.applyStatus(battle, defender, "burn", attacker) then
        sayFail(battle)
      end
    end,
  })

  -- Taunt
  register(mod, "EXP_TAUNT_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender then return sayFail(battle) end
      defender.expTauntedTurns = 3
      BattleCompat.say(battle, Strings("%s fell for\nthe TAUNT!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  -- Fake Out: first-turn only damaging flinch
  register(mod, "EXP_FAKE_OUT_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def, moveId, sureHit)
      if not attacker or not attacker.expJustEntered then
        return sayFail(battle)
      end
      if not sureHit and type(battle.accuracyRoll) == "function"
          and not battle:accuracyRoll(def, attacker, defender) then
        battle:markMissed()
        BattleCompat.say(battle, Strings("%s's attack missed!",
          BattleCompat.displayName(battle, attacker)))
        return
      end
      if type(battle.hitOnce) == "function" then
        battle:hitOnce(attacker, defender, def, { moveId = moveId })
      end
      if type(battle.volatile) == "function" then
        local vol = battle:volatile(defender)
        if vol then vol.flinched = true end
      else
        defender.flinched = true
      end
      attacker.expJustEntered = nil
    end,
  })

  -- Yawn
  register(mod, "EXP_YAWN_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender or BattleCompat.status(defender) or defender.expYawnTurns then
        return sayFail(battle)
      end
      defender.expYawnTurns = 2
      BattleCompat.say(battle, Strings("%s grew\ndrowsy!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  -- Hazards
  register(mod, "EXP_SPIKES_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local side = foeSide(battle, attacker)
      if not side then return sayFail(battle) end
      side.hazards = side.hazards or {}
      local h = findHazard(side, "SPIKES")
      if h then
        if (h.layers or 1) >= 3 then return sayFail(battle) end
        h.layers = (h.layers or 1) + 1
      else
        side.hazards[#side.hazards + 1] = { id = "SPIKES", layers = 1 }
      end
      -- Also set Gold's boolean spikes so native Rapid Spin can see something.
      side.spikes = true
      BattleCompat.say(battle, Strings("SPIKES scattered\nall around the\nfoe's side!"))
    end,
  })

  register(mod, "EXP_STEALTH_ROCK_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local side = foeSide(battle, attacker)
      if not side then return sayFail(battle) end
      side.hazards = side.hazards or {}
      if findHazard(side, "STEALTH_ROCK") then return sayFail(battle) end
      side.hazards[#side.hazards + 1] = { id = "STEALTH_ROCK" }
      BattleCompat.say(battle, Strings(
        "Pointed stones float\nin the air around\nthe foe's side!"))
    end,
  })

  register(mod, "EXP_TOXIC_SPIKES_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local side = foeSide(battle, attacker)
      if not side then return sayFail(battle) end
      side.hazards = side.hazards or {}
      local h = findHazard(side, "TOXIC_SPIKES")
      if h then
        if (h.layers or 1) >= 2 then return sayFail(battle) end
        h.layers = 2
      else
        side.hazards[#side.hazards + 1] = { id = "TOXIC_SPIKES", layers = 1 }
      end
      BattleCompat.say(battle, Strings(
        "Poison spikes were\nscattered around\nthe foe's side!"))
    end,
  })

  register(mod, "EXP_RAPID_SPIN_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def, moveId, sureHit)
      if type(battle.hitOnce) == "function" and def.power and def.power > 0 then
        if not sureHit and type(battle.accuracyRoll) == "function"
            and not battle:accuracyRoll(def, attacker, defender) then
          battle:markMissed()
          return
        end
        battle:hitOnce(attacker, defender, def, { moveId = moveId })
      end
      local side = ownSide(battle, attacker)
      if side then
        side.hazards = {}
        side.spikes = nil
      end
      BattleCompat.say(battle, Strings("%s blew away\nhazards!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  -- Protect / Endure / Encore / Belly Drum / Spikes-adjacent → prefer natives
  -- via EFFECT_MAP; keep EXP_ stubs only if remap missing.

  register(mod, "EXP_HEAL_BELL_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def)
      local function cure(mon)
        if mon and mon.status then mon.status = nil end
      end
      if attacker == battle.player then
        local party = battle.game and battle.game.save and battle.game.save.party
        for _, mon in ipairs(party or {}) do cure(mon) end
      else
        for _, mon in ipairs(battle.enemyParty or {}) do cure(mon) end
      end
      cure(attacker)
      local label = (def and def.id == "AROMATHERAPY") and "A soothing aroma"
        or "A bell chimed"
      BattleCompat.say(battle, Strings("%s wafted\nthrough the area!", label))
    end,
  })

  register(mod, "EXP_REFRESH_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      if not BattleCompat.hasStatus(attacker, "BRN", "PSN", "PAR", "TOX",
          "burn", "poison", "paralyze", "toxic") then
        return sayFail(battle)
      end
      local mon = BattleCompat.mon(attacker)
      if mon then mon.status = nil end
      BattleCompat.say(battle, Strings("%s's status\nreturned to normal!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_MEAN_LOOK_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if type(battle.volatile) == "function" then
        battle:volatile(attacker).trapsTarget = true
      end
      defender.expTrapped = true
      BattleCompat.say(battle, Strings("%s can't escape\nanymore!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_KNOCK_OFF_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def, moveId, sureHit)
      if type(battle.hitOnce) == "function" then
        if not sureHit and type(battle.accuracyRoll) == "function"
            and not battle:accuracyRoll(def, attacker, defender) then
          battle:markMissed()
          return
        end
        battle:hitOnce(attacker, defender, def, { moveId = moveId })
      end
      local mon = BattleCompat.mon(defender)
      if mon and mon.item then
        local item = mon.item
        mon.item = nil
        mon.heldItem = nil
        BattleCompat.say(battle, Strings("%s knocked off\n%s's %s!",
          BattleCompat.displayName(battle, attacker),
          BattleCompat.displayName(battle, defender), tostring(item)))
      end
    end,
  })

  -- Safeguard (Gold AI knows EFFECT_SAFEGUARD but Battle has no runner)
  register(mod, "EXP_SAFEGUARD_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local side = ownSide(battle, attacker)
      if not side then return sayFail(battle) end
      if (side.expSafeguardTurns or 0) > 0 then return sayFail(battle) end
      side.expSafeguardTurns = 5
      BattleCompat.say(battle, Strings("%s's team became\ncloaked in a\nmystic veil!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  -- Wish: heal half the wisher's max HP after one full turn
  register(mod, "EXP_WISH_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local side = ownSide(battle, attacker)
      if not side then return sayFail(battle) end
      side.tokens = side.tokens or {}
      for _, tok in ipairs(side.tokens) do
        if tok.id == "EXP_WISH" then return sayFail(battle) end
      end
      local heal = math.max(1, math.floor(BattleCompat.maxHp(attacker) / 2))
      side.tokens[#side.tokens + 1] = {
        id = "EXP_WISH", turns = 2, heal = heal,
      }
      BattleCompat.say(battle, Strings("%s made\na WISH!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  -- Pain Split
  register(mod, "EXP_PAIN_SPLIT_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local a, d = BattleCompat.mon(attacker), BattleCompat.mon(defender)
      if not a or not d or (d.hp or 0) <= 0 then return sayFail(battle) end
      local avg = math.floor(((a.hp or 0) + (d.hp or 0)) / 2)
      a.hp = math.min(BattleCompat.maxHp(attacker), avg)
      d.hp = math.min(BattleCompat.maxHp(defender), avg)
      BattleCompat.say(battle, Strings("The battlers shared\ntheir pain!"))
    end,
  })

  -- Psych Up
  register(mod, "EXP_PSYCH_UP_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local from = BattleCompat.stages(battle, defender)
      local to = BattleCompat.stages(battle, attacker)
      if not from or not to then return sayFail(battle) end
      for k in pairs(to) do to[k] = nil end
      for k, v in pairs(from) do to[k] = v end
      BattleCompat.say(battle, Strings("%s copied\nthe foe's stats!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  -- Destiny Bond (Gold AI scores it; Battle has no native runner)
  register(mod, "EXP_DESTINY_BOND_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      attacker.expDestinyBond = true
      BattleCompat.say(battle, Strings("%s is trying to\ntake its foe with it!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_INGRAIN_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      if attacker.expIngrain then return sayFail(battle) end
      attacker.expIngrain = true
      attacker.expTrapped = true
      BattleCompat.say(battle, Strings("%s planted its roots!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_AQUA_RING_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      if attacker.expAquaRing then return sayFail(battle) end
      attacker.expAquaRing = true
      BattleCompat.say(battle, Strings("%s surrounded itself\nwith a veil of water!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_LOCK_ON_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender then return sayFail(battle) end
      defender.expLockedOn = true
      BattleCompat.say(battle, Strings("%s took aim\nat %s!",
        BattleCompat.displayName(battle, attacker),
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_FORESIGHT_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender then return sayFail(battle) end
      -- Same flag Gen1 + main.lua damage/accuracy hooks already honor.
      defender.expIdentified = true
      BattleCompat.say(battle, Strings("%s was identified!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_NIGHTMARE_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender or not BattleCompat.hasStatus(defender, "SLP", "sleep") then
        return sayFail(battle)
      end
      if defender.expNightmare then return sayFail(battle) end
      defender.expNightmare = true
      BattleCompat.say(battle, Strings("%s began having\na NIGHTMARE!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_SWAGGER_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender then return sayFail(battle) end
      BattleCompat.changeStages(battle, defender, {
        { stat = "attack", change = 2 },
      })
      local Ab = require("mods.Kanto-Reforged.battle.abilities")
      if Ab.blocksStatus(battle, defender, "confuse", {}) then
        return
      end
      if type(battle.applyConfusion) == "function" then
        battle:applyConfusion(BattleCompat.mon(defender) or defender)
      elseif type(battle.applyStatus) == "function" then
        battle:applyStatus(BattleCompat.mon(defender) or defender, "confuse")
      end
    end,
  })

  register(mod, "EXP_STOCKPILE_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local n = attacker.expStockpile or 0
      if n >= 3 then return sayFail(battle) end
      attacker.expStockpile = n + 1
      BattleCompat.changeStages(battle, attacker, {
        { stat = "defense", change = 1 },
        { stat = "special", change = 1 },
      })
      BattleCompat.say(battle, Strings("%s stockpiled %d!",
        BattleCompat.displayName(battle, attacker), attacker.expStockpile))
    end,
  })

  register(mod, "EXP_SPIT_UP_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def, moveId, sureHit)
      local n = attacker.expStockpile or 0
      if n <= 0 then return sayFail(battle) end
      attacker.expStockpile = nil
      if not def or type(battle.hitOnce) ~= "function" then return end
      local old = def.power
      def.power = 100 * n
      if not sureHit and type(battle.accuracyRoll) == "function"
          and not battle:accuracyRoll(def, attacker, defender) then
        def.power = old
        battle:markMissed()
        return
      end
      battle:hitOnce(attacker, defender, def, { moveId = moveId })
      def.power = old
    end,
  })

  register(mod, "EXP_SWALLOW_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local n = attacker.expStockpile or 0
      if n <= 0 then return sayFail(battle) end
      local frac = ({ 4, 2, 1 })[n] or 1
      attacker.expStockpile = nil
      local mon = BattleCompat.mon(attacker)
      local maxHp = BattleCompat.maxHp(attacker)
      if not mon or mon.hp >= maxHp then return sayFail(battle) end
      local heal = math.max(1, math.floor(maxHp / frac))
      mon.hp = math.min(maxHp, mon.hp + heal)
      BattleCompat.say(battle, Strings("%s regained\nhealth!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_HEALING_WISH_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local side = ownSide(battle, attacker)
      if side then side.expHealingWish = true end
      local mon = BattleCompat.mon(attacker)
      if mon then mon.hp = 0 end
      BattleCompat.say(battle, Strings("%s's HEALING WISH\ncame true!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_MEMENTO_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if defender then
        BattleCompat.changeStages(battle, defender, {
          { stat = "attack", change = -2 },
          { stat = "special", change = -2 },
        })
      end
      local mon = BattleCompat.mon(attacker)
      if mon then mon.hp = 0 end
      BattleCompat.say(battle, Strings("%s went all out\nand fainted!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_SLEEP_TALK_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not BattleCompat.hasStatus(attacker, "SLP", "sleep") then
        return sayFail(battle)
      end
      local blocked = {
        SLEEP_TALK = true, COPYCAT = true, ASSIST = true, METRONOME = true,
        MIRROR_MOVE = true, SKETCH = true,
      }
      local pool = {}
      for _, mv in ipairs(attacker.moves or {}) do
        local id = type(mv) == "table" and mv.id or mv
        local pp = type(mv) == "table" and (mv.pp or 1) or 1
        if id and not blocked[id] and pp > 0 then
          pool[#pool + 1] = id
        end
      end
      if #pool == 0 then return sayFail(battle) end
      local idx = math.random(1, #pool)
      if type(battle.rng) == "function" then
        idx = battle.rng(1, #pool)
      elseif type(battle.random) == "function" then
        -- Gold BattleRandom: 0..n-1
        local r = battle.random(#pool)
        if type(r) == "number" then
          idx = (math.floor(r) % #pool) + 1
        end
      end
      battle.copyDepth = (battle.copyDepth or 0) + 1
      battle:useMove(attacker, defender, pool[idx])
      battle.copyDepth = (battle.copyDepth or 1) - 1
    end,
  })

  register(mod, "EXP_MAGIC_COAT_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      attacker.expMagicCoat = true
      BattleCompat.say(battle, Strings("%s shrouded\nitself with MAGIC COAT!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  local function itemGet(mon)
    if not mon then return nil end
    return mon.item or mon.heldItem
  end
  local function itemSet(mon, id)
    if not mon then return end
    mon.item = id
    mon.heldItem = id
  end

  register(mod, "EXP_TRICK_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local a, d = BattleCompat.mon(attacker), BattleCompat.mon(defender)
      if not a or not d then return sayFail(battle) end
      local ia, id = itemGet(a), itemGet(d)
      if not ia and not id then return sayFail(battle) end
      itemSet(a, id)
      itemSet(d, ia)
      BattleCompat.say(battle, Strings("%s switched\nitems with its target!",
        BattleCompat.displayName(battle, attacker)))
      local HeldItems = require("mods.Kanto-Reforged.items.held_items")
      if HeldItems.tickStatusBerry then
        pcall(HeldItems.tickStatusBerry, battle, attacker)
        pcall(HeldItems.tickStatusBerry, battle, defender)
      end
    end,
  })

  register(mod, "EXP_ROLE_PLAY_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local Ab = require("mods.Kanto-Reforged.battle.abilities")
      local foeAb = Ab.abilityOf(battle, defender)
      if not foeAb then return sayFail(battle) end
      attacker.expTracedAbility = foeAb
      attacker.expAbilitySuppressed = nil
      BattleCompat.say(battle, Strings("%s copied\n%s's ability!",
        BattleCompat.displayName(battle, attacker),
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_SKILL_SWAP_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local Ab = require("mods.Kanto-Reforged.battle.abilities")
      local a = Ab.abilityOf(battle, attacker)
      local b = Ab.abilityOf(battle, defender)
      if not a and not b then return sayFail(battle) end
      attacker.expTracedAbility = b
      defender.expTracedAbility = a
      attacker.expAbilitySuppressed = nil
      defender.expAbilitySuppressed = nil
      BattleCompat.say(battle, Strings("%s swapped\nabilities with its target!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_WORRY_SEED_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender then return sayFail(battle) end
      defender.expTracedAbility = "INSOMNIA"
      defender.expAbilitySuppressed = nil
      BattleCompat.say(battle, Strings("%s acquired\nINSOMNIA!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_GASTRO_ACID_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender or defender.expAbilitySuppressed then return sayFail(battle) end
      defender.expAbilitySuppressed = true
      defender.expTracedAbility = nil
      BattleCompat.say(battle, Strings("%s's ability\nwas suppressed!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_SIMPLE_BEAM_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender then return sayFail(battle) end
      defender.expTracedAbility = "SIMPLE"
      defender.expAbilitySuppressed = nil
      BattleCompat.say(battle, Strings("%s acquired\nSIMPLE!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_ENTRAINMENT_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local Ab = require("mods.Kanto-Reforged.battle.abilities")
      local a = Ab.abilityOf(battle, attacker)
      if not a or not defender then return sayFail(battle) end
      defender.expTracedAbility = a
      defender.expAbilitySuppressed = nil
      BattleCompat.say(battle, Strings("%s made %s\nmatch its ability!",
        BattleCompat.displayName(battle, attacker),
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_MUD_SPORT_EFFECT", {
    kind = "primary",
    run = function(battle)
      battle.expMudSport = true
      BattleCompat.say(battle, Strings("Electricity's power\nwas weakened!"))
    end,
  })

  register(mod, "EXP_WATER_SPORT_EFFECT", {
    kind = "primary",
    run = function(battle)
      battle.expWaterSport = true
      BattleCompat.say(battle, Strings("Fire's power\nwas weakened!"))
    end,
  })

  register(mod, "EXP_GRUDGE_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      attacker.expGrudge = true
      BattleCompat.say(battle, Strings("%s wants the\nfoe to take a GRUDGE!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_CHARGE_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      attacker.expCharged = true
      BattleCompat.changeStages(battle, attacker, {
        { stat = "special", change = 1 },
      })
      BattleCompat.say(battle, Strings("%s began charging\npower!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_ACUPRESSURE_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local stages = BattleCompat.stages(battle, attacker) or {}
      local stats = {
        "attack", "defense", "speed", "specialAttack", "specialDefense",
        "accuracy", "evasion",
      }
      local pool = {}
      for _, s in ipairs(stats) do
        if (stages[s] or 0) < 6 then pool[#pool + 1] = s end
      end
      if #pool == 0 then return sayFail(battle) end
      local idx = math.random(1, #pool)
      if type(battle.random) == "function" then
        local r = battle.random(#pool)
        if type(r) == "number" then idx = (math.floor(r) % #pool) + 1 end
      end
      BattleCompat.changeStages(battle, attacker, {
        { stat = pool[idx], change = 2 },
      })
    end,
  })

  local function swapStage(a, b, key)
    a[key], b[key] = b[key] or 0, a[key] or 0
  end

  register(mod, "EXP_POWER_SWAP_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local a = BattleCompat.stages(battle, attacker)
      local b = BattleCompat.stages(battle, defender)
      if not a or not b then return sayFail(battle) end
      swapStage(a, b, "attack")
      swapStage(a, b, "specialAttack")
      swapStage(a, b, "special")
      BattleCompat.say(battle, Strings("%s swapped all\nchanges to its\nATTACK and SP. ATK!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_GUARD_SWAP_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local a = BattleCompat.stages(battle, attacker)
      local b = BattleCompat.stages(battle, defender)
      if not a or not b then return sayFail(battle) end
      swapStage(a, b, "defense")
      swapStage(a, b, "specialDefense")
      BattleCompat.say(battle, Strings("%s swapped all\nchanges to its\nDEFENSE and SP. DEF!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_SPEED_SWAP_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local a = BattleCompat.stages(battle, attacker)
      local b = BattleCompat.stages(battle, defender)
      if not a or not b then return sayFail(battle) end
      swapStage(a, b, "speed")
      BattleCompat.say(battle, Strings("%s swapped\nSPEED with its target!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_POWER_TRICK_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local s = BattleCompat.stages(battle, attacker)
      if not s then return sayFail(battle) end
      s.attack, s.defense = s.defense or 0, s.attack or 0
      -- Gen2 has no curStats wrapper; stage swap is the portable Power Trick.
      attacker.expPowerTrick = not attacker.expPowerTrick
      BattleCompat.say(battle, Strings("%s swapped its\nATTACK and DEFENSE!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_LUCKY_CHANT_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local side = ownSide(battle, attacker)
      if not side then return sayFail(battle) end
      if (side.expLuckyChantTurns or 0) > 0 then return sayFail(battle) end
      side.expLuckyChantTurns = 5
      BattleCompat.say(battle, Strings("The LUCKY CHANT\nshielded %s from\ncritical hits!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_TAILWIND_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local side = ownSide(battle, attacker)
      if not side then return sayFail(battle) end
      if (side.expTailwindTurns or 0) > 0 then return sayFail(battle) end
      side.expTailwindTurns = 4
      BattleCompat.say(battle, Strings("The Tailwind blew from\nbehind %s!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_TRICK_ROOM_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      if battle.expTrickRoomTurns and battle.expTrickRoomTurns > 0 then
        battle.expTrickRoomTurns = nil
        BattleCompat.say(battle, Strings("The twisted dimensions\nreturned to normal!"))
        return
      end
      battle.expTrickRoomTurns = 5
      BattleCompat.say(battle, Strings("%s twisted\nthe dimensions!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_RECYCLE_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      local mon = BattleCompat.mon(attacker)
      local last = attacker.expLastConsumedItem
      if not mon or not last or mon.item or mon.heldItem then
        return sayFail(battle)
      end
      mon.item = last
      mon.heldItem = last
      attacker.expLastConsumedItem = nil
      local HeldItems = require("mods.Kanto-Reforged.items.held_items")
      local def = HeldItems.def and HeldItems.def(last)
      BattleCompat.say(battle, Strings("%s found one\n%s!",
        BattleCompat.displayName(battle, attacker),
        (def and def.name) or last))
    end,
  })

  register(mod, "EXP_BESTOW_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local a, d = BattleCompat.mon(attacker), BattleCompat.mon(defender)
      local ia = a and (a.item or a.heldItem)
      local id = d and (d.item or d.heldItem)
      if not a or not ia or not d or id then return sayFail(battle) end
      d.item, d.heldItem = ia, ia
      a.item, a.heldItem = nil, nil
      local HeldItems = require("mods.Kanto-Reforged.items.held_items")
      local def = HeldItems.def and HeldItems.def(ia)
      BattleCompat.say(battle, Strings("%s gave its\n%s!",
        BattleCompat.displayName(battle, attacker),
        (def and def.name) or ia))
      if HeldItems.tickStatusBerry then
        pcall(HeldItems.tickStatusBerry, battle, defender)
      end
    end,
  })

  register(mod, "EXP_IMPRISON_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      attacker.expImprison = true
      BattleCompat.say(battle, Strings("%s sealed\nthe opponent's moves!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_SNATCH_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      attacker.expSnatch = true
      BattleCompat.say(battle, Strings("%s waits for a\ntarget to make a move!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_TORMENT_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender or defender.expTormented then return sayFail(battle) end
      defender.expTormented = true
      defender.expTormentLast = nil
      BattleCompat.say(battle, Strings("%s was\nsubjected to TORMENT!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_EMBARGO_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender then return sayFail(battle) end
      defender.expEmbargoTurns = 5
      BattleCompat.say(battle, Strings("%s can't use\nitems anymore!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_HEAL_BLOCK_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      if not defender then return sayFail(battle) end
      defender.expHealBlockTurns = 5
      BattleCompat.say(battle, Strings("%s was prevented\nfrom healing!",
        BattleCompat.displayName(battle, defender)))
    end,
  })

  register(mod, "EXP_ENDEAVOR_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def, moveId, sureHit)
      local a, d = BattleCompat.mon(attacker), BattleCompat.mon(defender)
      if not a or not d then return sayFail(battle) end
      if (a.hp or 0) >= (d.hp or 0) then return sayFail(battle) end
      local dmg = (d.hp or 0) - (a.hp or 0)
      if type(battle.dealDamage) == "function" then
        if not sureHit and type(battle.accuracyRoll) == "function"
            and not battle:accuracyRoll(def, attacker, defender) then
          battle:markMissed()
          return
        end
        battle:dealDamage(attacker, defender, dmg, { move = def, moveId = moveId })
      elseif type(battle.hitOnce) == "function" then
        local old = def.power
        def.power = 1
        battle:hitOnce(attacker, defender, def, { moveId = moveId })
        def.power = old
        -- Approximate: set foe HP to attacker HP if still higher.
        if (d.hp or 0) > (a.hp or 0) then d.hp = a.hp end
      end
    end,
  })

  register(mod, "EXP_UPROAR_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def, moveId, sureHit)
      if type(battle.hitOnce) == "function" and def and (def.power or 0) > 0 then
        if not sureHit and type(battle.accuracyRoll) == "function"
            and not battle:accuracyRoll(def, attacker, defender) then
          battle:markMissed()
          return
        end
        battle:hitOnce(attacker, defender, def, { moveId = moveId })
      end
      if not attacker.expUproarTurns then
        local turns = 3
        if type(battle.random) == "function" then
          local r = battle.random(4)
          if type(r) == "number" then turns = (math.floor(r) % 4) + 2 end
        end
        attacker.expUproarTurns = turns
        battle.expUproarActive = true
        BattleCompat.say(battle, Strings("%s caused\nan UPROAR!",
          BattleCompat.displayName(battle, attacker)))
      end
    end,
  })

  register(mod, "EXP_PRESENT_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def, moveId, sureHit)
      if not defender then return sayFail(battle) end
      local r = math.random(0, 255)
      if type(battle.random) == "function" then
        local rr = battle.random(256)
        if type(rr) == "number" then r = math.floor(rr) % 256 end
      end
      if r < 51 then
        local mon = BattleCompat.mon(defender)
        local maxHp = BattleCompat.maxHp(defender)
        if mon and not defender.expHealBlockTurns then
          mon.hp = math.min(maxHp, (mon.hp or 0) + 80)
          BattleCompat.say(battle, Strings("%s had its\nHP restored!",
            BattleCompat.displayName(battle, defender)))
        end
        return
      end
      local power = (r < 102) and 40 or (r < 178) and 80 or 120
      if not def or type(battle.hitOnce) ~= "function" then return end
      local old = def.power
      def.power = power
      if not sureHit and type(battle.accuracyRoll) == "function"
          and not battle:accuracyRoll(def, attacker, defender) then
        def.power = old
        battle:markMissed()
        return
      end
      battle:hitOnce(attacker, defender, def, { moveId = moveId })
      def.power = old
    end,
  })

  local function callMove(battle, attacker, defender, moveId)
    if not moveId or type(battle.useMove) ~= "function" then return sayFail(battle) end
    battle.copyDepth = (battle.copyDepth or 0) + 1
    battle:useMove(attacker, defender, moveId)
    battle.copyDepth = (battle.copyDepth or 1) - 1
  end

  local function lastMoveOf(battle, mon)
    if not mon then return nil end
    if type(battle.volatile) == "function" then
      local vol = battle:volatile(mon)
      if vol and vol.lastMove then return vol.lastMove end
    end
    return mon.lastMove
  end

  local CALL_BAN = {
    COPYCAT = true, SLEEP_TALK = true, ASSIST = true, METRONOME = true,
    MIRROR_MOVE = true, SKETCH = true, TRANSFORM = true, ME_FIRST = true,
    COUNTER = true, MIRROR_COAT = true, PROTECT = true, DETECT = true,
    ENDURE = true, DESTINY_BOND = true, THIEF = true, STRUGGLE = true,
    CHATTER = true, NATURE_POWER = true,
  }

  register(mod, "EXP_COPYCAT_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local last = lastMoveOf(battle, defender)
      if not last or CALL_BAN[last] then return sayFail(battle) end
      callMove(battle, attacker, defender, last)
    end,
  })

  register(mod, "EXP_ASSIST_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local sideKey = type(battle.sideOf) == "function" and battle:sideOf(attacker)
      local isPlayer = sideKey == "player" or attacker == battle.player
      local party = isPlayer and (battle.party or (battle.game and battle.game.save
        and battle.game.save.party)) or battle.enemyParty
      local selfMon = BattleCompat.mon(attacker)
      local pool = {}
      for _, mon in ipairs(party or {}) do
        if mon and mon ~= selfMon then
          for _, mv in ipairs(mon.moves or {}) do
            local id = type(mv) == "table" and mv.id or mv
            if id and not CALL_BAN[id] then pool[#pool + 1] = id end
          end
        end
      end
      if #pool == 0 then return sayFail(battle) end
      local idx = math.random(1, #pool)
      if type(battle.random) == "function" then
        local r = battle.random(#pool)
        if type(r) == "number" then idx = (math.floor(r) % #pool) + 1 end
      end
      callMove(battle, attacker, defender, pool[idx])
    end,
  })

  register(mod, "EXP_NATURE_POWER_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      callMove(battle, attacker, defender, "EARTHQUAKE")
    end,
  })

  register(mod, "EXP_ME_FIRST_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local last = lastMoveOf(battle, defender)
      if not last or CALL_BAN[last] then return sayFail(battle) end
      attacker.expMeFirst = true
      callMove(battle, attacker, defender, last)
    end,
  })

  register(mod, "EXP_SKETCH_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local last = lastMoveOf(battle, defender)
      if not last or last == "SKETCH" or last == "STRUGGLE" or last == "CHATTER" then
        return sayFail(battle)
      end
      local slot
      for _, mv in ipairs(attacker.moves or {}) do
        if type(mv) == "table" and mv.id == "SKETCH" then
          slot = mv
          break
        end
      end
      if not slot then return sayFail(battle) end
      local def = battle.data and battle.data.moves and battle.data.moves[last]
      slot.id = last
      slot.pp = def and def.pp or 5
      BattleCompat.say(battle, Strings("%s learned\n%s!",
        BattleCompat.displayName(battle, attacker),
        (def and def.name) or last))
    end,
  })

  register(mod, "EXP_CAMOUFLAGE_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      BattleCompat.setTypes(attacker, { "NORMAL" })
      BattleCompat.say(battle, Strings("%s's type\nchanged to NORMAL!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  register(mod, "EXP_CONVERSION_2_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender)
      local last = lastMoveOf(battle, defender)
      local move = last and battle.data and battle.data.moves and battle.data.moves[last]
      if not move or not move.type then return sayFail(battle) end
      local TypeChart = require("src.battle.TypeChart")
      local candidates = {
        "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE", "FIGHTING",
        "POISON", "GROUND", "FLYING", "PSYCHIC_TYPE", "BUG", "ROCK",
        "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY",
      }
      local best, bestMult = nil, 10
      for _, t in ipairs(candidates) do
        local m = TypeChart.effectiveness(move.type, { t }) or 10
        if m < bestMult then
          bestMult, best = m, t
        end
      end
      if not best or bestMult >= 10 then return sayFail(battle) end
      BattleCompat.setTypes(attacker, { best })
      BattleCompat.say(battle, Strings("%s transformed\ninto the %s type!",
        BattleCompat.displayName(battle, attacker), best))
    end,
  })

  register(mod, "EXP_CAPTIVATE_EFFECT", {
    kind = "primary",
    run = function(battle, attacker, defender, def)
      local okG, Gender = pcall(require, "mods.Kanto-Reforged.gender")
      local a, d = BattleCompat.mon(attacker), BattleCompat.mon(defender)
      if okG and Gender.canInfatuate and not Gender.canInfatuate(a, d) then
        return sayFail(battle)
      end
      local changes = (def and def.statChanges) or {
        { stat = "special", change = -2 },
      }
      BattleCompat.changeStages(battle, defender, changes)
    end,
  })

  register(mod, "EXP_FOLLOW_ME_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      -- Singles stand-in: +2 evasion (same as Gen1 KR).
      BattleCompat.changeStages(battle, attacker, {
        { stat = "evasion", change = 2 },
      })
    end,
  })

  register(mod, "EXP_ALLY_SWITCH_EFFECT", {
    kind = "primary",
    run = function(battle, attacker)
      -- Singles stand-in: Protect this turn (same as Gen1 KR).
      attacker.expProtected = true
      if type(battle.volatile) == "function" then
        local vol = battle:volatile(attacker)
        if vol then vol.protect = true end
      end
      BattleCompat.say(battle, Strings("%s protected\nitself!",
        BattleCompat.displayName(battle, attacker)))
    end,
  })

  -- Smelling Salts / Wake-Up Slap: no `run` so Gen2 deals damage normally;
  -- cure lives in damage_dealt (+ ×2 power bumps in main.lua).
  register(mod, "EXP_WAKE_UP_SLAP_EFFECT", { kind = "primary" })
  -- Spite remapped to Gold EFFECT_SPITE.
  -- VARIABLE_POWER / HAIL handled elsewhere (damage hooks / weather runners).
end

local function applyHazards(battle, battler, side)
  if not battler or not side or not side.hazards then return end
  local mon = BattleCompat.mon(battler)
  if not mon or (mon.hp or 0) <= 0 then return end
  local types = BattleCompat.types(battler)
  local function hasType(id)
    for _, t in ipairs(types) do if t == id then return true end end
    return false
  end

  for _, h in ipairs(side.hazards) do
    if h.id == "STEALTH_ROCK" then
      local TypeChart = require("src.battle.TypeChart")
      local mult = TypeChart.effectiveness("ROCK", types) or 10
      local maxHp = BattleCompat.maxHp(battler)
      local dmg = math.max(1, math.floor(maxHp * mult / 80))
      BattleCompat.applyHpLoss(battle, battler, dmg)
      BattleCompat.say(battle, Strings("Pointed stones dug into\n%s!",
        BattleCompat.displayName(battle, battler)))
    elseif h.id == "SPIKES" and not hasType("FLYING") then
      local layers = h.layers or 1
      local denom = ({ 8, 6, 4 })[math.min(3, layers)] or 8
      local dmg = math.max(1, math.floor(BattleCompat.maxHp(battler) / denom))
      BattleCompat.applyHpLoss(battle, battler, dmg)
    elseif h.id == "TOXIC_SPIKES" then
      if hasType("POISON") then
        -- Absorb toxic spikes
        for i = #side.hazards, 1, -1 do
          if side.hazards[i].id == "TOXIC_SPIKES" then
            table.remove(side.hazards, i)
          end
        end
      elseif not hasType("FLYING") and not hasType("STEEL") then
        local status = (h.layers or 1) >= 2 and "toxic" or "poison"
        BattleCompat.applyStatus(battle, battler, status, nil)
      end
    end
  end
end

local function clearScreens(battle, defender)
  if not battle or not battle.screens or not defender then return false end
  local key = type(battle.sideOf) == "function" and battle:sideOf(defender) or nil
  local side = key and battle.screens[key]
  if not side then return false end
  local shattered = (side.reflect or 0) > 0 or (side.lightScreen or 0) > 0
  side.reflect, side.lightScreen = nil, nil
  return shattered
end

local function tryUTurnSwitch(battle, user)
  if not battle or not user or BattleCompat.hp(user) <= 0 then return end
  local sideKey = type(battle.sideOf) == "function" and battle:sideOf(user) or nil
  if sideKey == "player" or user == battle.player then
    if not battle.pendingSwitch then
      battle.pendingSwitch = true
      if type(battle.emit) == "function" then
        battle:emit({ kind = "choose-switch" })
      end
      BattleCompat.say(battle, Strings("%s went back to\n%s!",
        BattleCompat.displayName(battle, user),
        (battle.game and battle.game.save and battle.game.save.player
          and battle.game.save.player.name) or "the trainer"))
    end
    return
  end
  -- Enemy: auto-switch to first other healthy party member.
  local party = battle.enemyParty
  local cur = battle.enemyIndex
  if not party then return end
  local target
  for i, mon in ipairs(party) do
    if i ~= cur and mon and (mon.hp or 0) > 0 then
      target = i
      break
    end
  end
  if not target then return end
  if type(battle.clearVolatile) == "function" then
    pcall(function() battle:clearVolatile(user) end)
  end
  battle.enemyIndex = target
  battle.enemy = party[target]
  if type(battle.emit) == "function" then
    battle:emit({ kind = "send", side = "enemy", mon = battle.enemy,
      text = "Go! " .. BattleCompat.displayName(battle, battle.enemy) .. "!" })
  end
  battle.enemy.expJustEntered = true
end

local function applyDamageStats(battle, user, target, move, damage)
  if not move or not damage or damage <= 0 then return end
  local effect = move.effect
  if effect == "EXP_DAMAGE_USER_STAT_EFFECT" and move.statChanges then
    local targetSelf = (move.statTarget or "user") == "user"
    local who = targetSelf and user or target
    BattleCompat.changeStages(battle, who, move.statChanges)
  elseif effect == "EXP_DAMAGE_STAT_SIDE_EFFECT" and move.statChanges then
    local chance = move.statChance or 10
    battle._krLastAttacker = user
    if not rollChance(battle, chance) then return end
    local targetSelf = (move.statTarget or "target") == "user"
    local who = targetSelf and user or target
    BattleCompat.changeStages(battle, who, move.statChanges)
  elseif effect == "EXP_FLINCH_SIDE_100" then
    if type(battle.volatile) == "function" then
      local vol = battle:volatile(target)
      if vol then vol.flinched = true end
    else
      target.flinched = true
    end
  elseif effect == "EXP_BRICK_BREAK_EFFECT" then
    if clearScreens(battle, target) then
      BattleCompat.say(battle, Strings("The wall shattered!"))
    end
  elseif effect == "EXP_U_TURN_EFFECT" then
    tryUTurnSwitch(battle, user)
  elseif effect == "EXP_FALSE_SWIPE_EFFECT" then
    -- Remap usually handles this; belt-and-suspenders if stub remains.
    local mon = BattleCompat.mon(target)
    if mon and (mon.hp or 0) <= 0 then
      mon.hp = 1
    end
  elseif effect == "EXP_CLEAR_SMOG_EFFECT" then
    local stages = BattleCompat.stages(battle, target)
    if stages then
      for k in pairs(stages) do stages[k] = 0 end
      BattleCompat.say(battle, Strings("%s's stat changes\nwere removed!",
        BattleCompat.displayName(battle, target)))
    end
  elseif effect == "EXP_SECRET_POWER_EFFECT" then
    battle._krLastAttacker = user
    if not rollChance(battle, 30) then return end
    BattleCompat.applyStatus(battle, target, "paralyze", user,
      { secondary = true, moveType = move.type })
  elseif effect == "EXP_SMELLING_SALTS_EFFECT"
      or (move.id == "SMELLING_SALTS") then
    if BattleCompat.hasStatus(target, "PAR", "paralyze") then
      local mon = BattleCompat.mon(target)
      if mon then mon.status = nil end
      BattleCompat.say(battle, Strings("%s was cured\nof paralysis!",
        BattleCompat.displayName(battle, target)))
    end
  elseif effect == "EXP_WAKE_UP_SLAP_EFFECT"
      or (move.id == "WAKE_UP_SLAP") then
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
  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
  local Abilities = require("mods.Kanto-Reforged.battle.abilities")

  mod.events:on("battle.started", function(ev)
    if not ev.battle then return end
    if ev.battle.player then ev.battle.player.expJustEntered = true end
    if ev.battle.enemy then ev.battle.enemy.expJustEntered = true end
  end)

  mod.events:on("battle.battler_switched", function(ev)
    if not ev.battle or not ev.battler then return end
    local b = ev.battler
    b.expJustEntered = true
    b.expDestinyBond = nil
    b.expIngrain = nil
    b.expAquaRing = nil
    b.expNightmare = nil
    b.expLockedOn = nil
    b.expIdentified = nil
    b.expForesighted = nil
    b.expStockpile = nil
    b.expMagicCoat = nil
    b.expAbilitySuppressed = nil
    b.expTracedAbility = nil
    b.expGrudge = nil
    b.expCharged = nil
    b.expImprison = nil
    b.expSnatch = nil
    b.expTormented = nil
    b.expTormentLast = nil
    b.expEmbargoTurns = nil
    b.expHealBlockTurns = nil
    b.expUproarTurns = nil
    local side = ownSide(ev.battle, b)
    -- Healing Wish: full HP + clear status on the replacement.
    if side and side.expHealingWish then
      side.expHealingWish = nil
      local mon = BattleCompat.mon(b)
      if mon then
        mon.hp = BattleCompat.maxHp(b)
        mon.status = nil
        mon.statusTurns = nil
        mon.toxicCounter = nil
        BattleCompat.say(ev.battle, Strings("The HEALING WISH came true!\n%s recovered!",
          BattleCompat.displayName(ev.battle, b)))
      end
    end
    applyHazards(ev.battle, b, side)
  end)

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

  mod.events:on("battle.turn_ended", function(ev)
    if not ev.battle then return end
    local function tickMon(mon)
      if not mon then return end
      if mon.expTauntedTurns and mon.expTauntedTurns > 0 then
        mon.expTauntedTurns = mon.expTauntedTurns - 1
        if mon.expTauntedTurns <= 0 then mon.expTauntedTurns = nil end
      end
      if mon.expYawnTurns and mon.expYawnTurns > 0 then
        mon.expYawnTurns = mon.expYawnTurns - 1
        if mon.expYawnTurns <= 0 then
          mon.expYawnTurns = nil
          BattleCompat.applyStatus(ev.battle, mon, "sleep", nil)
        end
      end
      if BattleCompat.hp(mon) > 0 and (mon.expIngrain or mon.expAquaRing) then
        local maxHp = BattleCompat.maxHp(mon)
        local m = BattleCompat.mon(mon)
        if m and m.hp < maxHp then
          local heal = math.max(1, math.floor(maxHp / 16))
          m.hp = math.min(maxHp, m.hp + heal)
          BattleCompat.say(ev.battle, Strings("%s restored a little\nHP!",
            BattleCompat.displayName(ev.battle, mon)))
        end
      end
      if mon.expNightmare and BattleCompat.hp(mon) > 0 then
        if not BattleCompat.hasStatus(mon, "SLP", "sleep") then
          mon.expNightmare = nil
        else
          local dmg = math.max(1, math.floor(BattleCompat.maxHp(mon) / 4))
          BattleCompat.applyHpLoss(ev.battle, mon, dmg)
          BattleCompat.say(ev.battle, Strings("%s is locked\nin a NIGHTMARE!",
            BattleCompat.displayName(ev.battle, mon)))
        end
      end
      if mon.expEmbargoTurns and mon.expEmbargoTurns > 0 then
        mon.expEmbargoTurns = mon.expEmbargoTurns - 1
        if mon.expEmbargoTurns <= 0 then mon.expEmbargoTurns = nil end
      end
      if mon.expHealBlockTurns and mon.expHealBlockTurns > 0 then
        mon.expHealBlockTurns = mon.expHealBlockTurns - 1
        if mon.expHealBlockTurns <= 0 then mon.expHealBlockTurns = nil end
      end
      if mon.expUproarTurns and mon.expUproarTurns > 0 then
        mon.expUproarTurns = mon.expUproarTurns - 1
        if mon.expUproarTurns <= 0 then
          mon.expUproarTurns = nil
          -- Clear field flag if neither side is roaring.
          local other = (mon == ev.battle.player) and ev.battle.enemy or ev.battle.player
          if not (other and other.expUproarTurns) then
            ev.battle.expUproarActive = nil
          end
          BattleCompat.say(ev.battle, Strings("%s calmed down!",
            BattleCompat.displayName(ev.battle, mon)))
        end
      end
      mon.expJustEntered = nil
    end
    tickMon(ev.battle.player)
    tickMon(ev.battle.enemy)

    local function tickSide(side, active)
      if not side then return end
      if side.expSafeguardTurns and side.expSafeguardTurns > 0 then
        side.expSafeguardTurns = side.expSafeguardTurns - 1
        if side.expSafeguardTurns <= 0 then
          side.expSafeguardTurns = nil
          BattleCompat.say(ev.battle, Strings("%s is no longer\nprotected by SAFEGUARD!",
            BattleCompat.displayName(ev.battle, active)))
        end
      end
      if side.expLuckyChantTurns and side.expLuckyChantTurns > 0 then
        side.expLuckyChantTurns = side.expLuckyChantTurns - 1
        if side.expLuckyChantTurns <= 0 then side.expLuckyChantTurns = nil end
      end
      if side.expTailwindTurns and side.expTailwindTurns > 0 then
        side.expTailwindTurns = side.expTailwindTurns - 1
        if side.expTailwindTurns <= 0 then side.expTailwindTurns = nil end
      end
      if not side.tokens then return end
      local kept = {}
      for _, tok in ipairs(side.tokens) do
        tok.turns = (tok.turns or 1) - 1
        if tok.turns <= 0 then
          if tok.id == "EXP_WISH" and active and BattleCompat.hp(active) > 0 then
            local mon = BattleCompat.mon(active)
            local maxHp = BattleCompat.maxHp(active)
            if mon and mon.hp < maxHp then
              mon.hp = math.min(maxHp, mon.hp + (tok.heal or math.floor(maxHp / 2)))
              BattleCompat.say(ev.battle, Strings("%s's WISH\ncame true!",
                BattleCompat.displayName(ev.battle, active)))
            end
          end
        else
          kept[#kept + 1] = tok
        end
      end
      side.tokens = kept
    end
    tickSide(ev.battle.sides and (ev.battle.sides.player or ev.battle.sides[1]),
      ev.battle.player)
    tickSide(ev.battle.sides and (ev.battle.sides.enemy or ev.battle.sides[2]),
      ev.battle.enemy)
    if ev.battle.expTrickRoomTurns and ev.battle.expTrickRoomTurns > 0 then
      ev.battle.expTrickRoomTurns = ev.battle.expTrickRoomTurns - 1
      if ev.battle.expTrickRoomTurns <= 0 then
        ev.battle.expTrickRoomTurns = nil
        BattleCompat.say(ev.battle, Strings("The twisted dimensions\nreturned to normal!"))
      end
    end
  end)

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
            local took = attacker.expTookDamageThisTurn
            if not took and type(self.volatile) == "function" then
              local vol = self:volatile(attacker)
              took = vol and (vol.tookThisTurn or 0) > 0
            end
            if took then
              self:emit({ kind = "message",
                text = self:monName(attacker) .. " lost its concentration!" })
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

          local result = originalUse(self, attacker, defender, moveId)

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
            local side = ownSide(self, mon)
            if side and (side.expSafeguardTurns or 0) > 0 then
              self:emit({ kind = "message", text = "But it failed!" })
              return false
            end
          end
          return originalStatus(self, mon, status, source)
        end
        B._krStatusAbilityWrap = true
      end

      -- False Swipe clamp also honors EXP effect id if remap missed.
      -- Damaging Fire hits thaw a frozen target (Gen 3 CheckDefrost).
      if not B._krFalseSwipeWrap then
        local originalDeal = B.dealDamage
        local ME = require("mods.Kanto-Reforged.battle.move_effects")
        B.dealDamage = function(self, attacker, defender, damage, opts)
          local def = opts and opts.move
          if def and def.effect == "EXP_FALSE_SWIPE_EFFECT"
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

  mod.log:info("Gen2 move-effect parity installed (gen3 call-moves/status hits)")
end

return MoveEffectsGen2
