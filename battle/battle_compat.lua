-- Dual-gen battle accessors: Gen1 battler wrappers vs Gen2 bare party mons,
-- and KR weather ids (SUNNY/RAINY/…) vs Gold (sun/rain/sandstorm).
local BattleCompat = {}

function BattleCompat.isGen2(battle)
  if not battle then return false end
  -- Live Gold boot.  KR AI may stamp player.mon on a Gold party table;
  -- that must not flip the battle to the Gen 1 weather path (double chip
  -- + clipped "buffeted" text).
  local okH, Host = pcall(require, "mods.Kanto-Reforged.core.host")
  if not okH then
    okH, Host = pcall(require, "mods.Kanto-Reforged.host")
  end
  if okH and Host and Host.isGen2 and Host.isGen2() then return true end
  -- Headless tests: Gold-shaped battles (weatherTurns, no Gen1 wrapper).
  if battle.weather ~= nil or battle.weatherTurns ~= nil then
    if battle.player and battle.player.mon then return false end
    return true
  end
  if battle.stages and type(battle.sideOf) == "function"
      and battle.player and not battle.player.mon then
    return true
  end
  return false
end

--- Underlying party mon table (Gen1: battler.mon, Gen2: battler itself).
function BattleCompat.mon(battler)
  if not battler then return nil end
  if battler.mon then return battler.mon end
  if battler.species or battler.hp ~= nil then return battler end
  return nil
end

function BattleCompat.species(battler)
  local mon = BattleCompat.mon(battler)
  return mon and mon.species
end

function BattleCompat.hp(battler)
  local mon = BattleCompat.mon(battler)
  return mon and mon.hp or 0
end

function BattleCompat.maxHp(battler)
  local mon = BattleCompat.mon(battler)
  if not mon then return 1 end
  return (mon.stats and mon.stats.hp) or mon.maxHp or 1
end

function BattleCompat.status(battler)
  local mon = BattleCompat.mon(battler)
  return mon and mon.status
end

-- Gen1 three-letter codes ↔ Gold lowercase status ids.
local TO_GEN2 = {
  SLP = "sleep", BRN = "burn", PSN = "poison", TOX = "toxic",
  PAR = "paralyze", FRZ = "freeze",
}
local TO_GEN1 = {
  sleep = "SLP", burn = "BRN", poison = "PSN", toxic = "TOX",
  paralyze = "PAR", freeze = "FRZ",
}

function BattleCompat.toGen2Status(status)
  if not status then return nil end
  return TO_GEN2[status] or status
end

function BattleCompat.toGen1Status(status)
  if not status then return nil end
  return TO_GEN1[status] or status
end

function BattleCompat.hasStatus(battler, ...)
  local st = BattleCompat.status(battler)
  if not st then return false end
  for i = 1, select("#", ...) do
    local want = select(i, ...)
    if st == want or st == TO_GEN2[want] or st == TO_GEN1[want] then
      return true
    end
  end
  return false
end

local function sideHasSafeguard(battle, battler)
  if not battle or not battler then return false end
  local side
  if type(battle.sideOf) == "function" and battle.sides then
    local ok, key = pcall(function() return battle:sideOf(battler) end)
    if ok and key then
      side = battle.sides[key]
        or (type(key) == "number" and battle.sides[key])
        or nil
    end
  end
  if not side and battle.sides then
    if battler == battle.player then
      side = battle.sides.player or battle.sides[1]
    else
      side = battle.sides.enemy or battle.sides[2]
    end
  end
  return side and (side.expSafeguardTurns or 0) > 0
end

--- Inflict a major status on either generation. Returns true on success.
function BattleCompat.applyStatus(battle, battler, status, source, opts)
  local mon = BattleCompat.mon(battler)
  if not battle or not mon then return false end
  opts = opts or {}
  if sideHasSafeguard(battle, battler) then return false end
  local Abilities = require("mods.Kanto-Reforged.battle.abilities")
  if Abilities.blocksStatus and Abilities.blocksStatus(battle, battler, status, opts) then
    return false
  end
  local g2 = BattleCompat.toGen2Status(status)
  if BattleCompat.isGen2(battle) and type(battle.applyStatus) == "function" then
    -- Skip re-checking abilities inside the Gen2 wrap (see move_effects_gen2).
    battle._krStatusFromCompat = true
    local ok = battle:applyStatus(mon, g2, BattleCompat.mon(source) or source)
    battle._krStatusFromCompat = nil
    return ok and true or false
  end
  local ok, StatusRegistry = pcall(require, "src.battle.StatusRegistry")
  if ok and StatusRegistry and StatusRegistry.inflict and battler.mon then
    local g1 = BattleCompat.toGen1Status(status) or status
    local msgs = StatusRegistry.inflict(battle, battler, g1, {
      secondary = opts.secondary ~= false, source = "KR",
      expSourceBattler = source,
      moveType = opts.moveType,
    })
    for _, m in ipairs(msgs or {}) do BattleCompat.say(battle, m) end
    return msgs ~= nil and #msgs > 0
  end
  if not mon.status then
    mon.status = BattleCompat.isGen2(battle) and g2 or (BattleCompat.toGen1Status(status) or status)
    return true
  end
  return false
end

--- Map KR/Gen1 stage names onto Gold's split special stats.
function BattleCompat.mapStageStat(stat, change)
  if stat == "special" then
    return (change or 0) < 0 and "specialDefense" or "specialAttack"
  end
  return stat
end

function BattleCompat.changeStages(battle, battler, changes)
  if not battle or not battler or not changes then return false end
  local any = false
  for _, sc in ipairs(changes) do
    local delta = sc.change or 0
    local stat = BattleCompat.mapStageStat(sc.stat, delta)
    if stat and delta ~= 0 then
      if type(battle.changeStage) == "function" then
        if battle:changeStage(BattleCompat.mon(battler) or battler, stat, delta) then
          any = true
        end
      else
        local stages = BattleCompat.stages(battle, battler)
        if stages then
          local cur = stages[stat] or 0
          local next = math.max(-6, math.min(6, cur + delta))
          if next ~= cur then
            stages[stat] = next
            any = true
          end
        end
      end
    end
  end
  return any
end

function BattleCompat.types(battler, data)
  if not battler then return { "NORMAL" } end
  if battler.curTypes then return battler.curTypes end
  local mon = BattleCompat.mon(battler)
  if mon and mon.types then return mon.types end
  -- Gen2 party mons often omit .types; resolve from species data.
  local species = mon and mon.species
  local poke = species and data and data.pokemon and data.pokemon[species]
  if poke and poke.types then return poke.types end
  return { "NORMAL" }
end

function BattleCompat.setTypes(battler, types)
  if not battler or not types then return end
  if battler.curTypes ~= nil or battler.mon then
    battler.curTypes = types
  end
  local mon = BattleCompat.mon(battler)
  if mon then mon.types = types end
end

function BattleCompat.stages(battle, battler)
  if not battler then return nil end
  if battler.stages then return battler.stages end
  if battle and battle.stages and type(battle.sideOf) == "function" then
    local ok, side = pcall(function() return battle:sideOf(battler) end)
    if ok and side and battle.stages[side] then
      return battle.stages[side]
    end
  end
  battler.stages = battler.stages or {}
  return battler.stages
end

function BattleCompat.displayName(battle, battler)
  if not battler then return "POKéMON" end
  if battler.isPlayer and battler.name then return battler.name end
  if battler.name and battler.isPlayer == false then
    return "Enemy " .. battler.name
  end
  if battle and type(battle.monName) == "function" then
    local ok, name = pcall(function() return battle:monName(battler) end)
    if ok and name then return name end
  end
  local mon = BattleCompat.mon(battler)
  return (mon and (mon.nickname or mon.species)) or "POKéMON"
end

function BattleCompat.say(battle, text)
  if not battle or not text then return end
  if type(battle.sayNext) == "function" then
    battle:sayNext(text)
  elseif type(battle.emit) == "function" then
    battle:emit({ kind = "message", text = tostring(text) })
  end
end

function BattleCompat.getWeather(battle)
  if not battle then return nil end
  if battle._krWeather then return battle._krWeather end
  if BattleCompat.isGen2(battle) then
    local w = battle.weather
    if w == "sun" then return "SUNNY" end
    if w == "rain" then return "RAINY" end
    if w == "sandstorm" then return "SANDSTORM" end
    return nil
  end
  return battle.field and battle.field.weather
end

local GEN2_WEATHER = {
  SUNNY = "sun",
  RAINY = "rain",
  SANDSTORM = "sandstorm",
}

function BattleCompat.setWeather(battle, weather, message, turns, opts)
  if not battle then return end
  if type(turns) == "table" then
    opts = turns
    turns = opts.turns
  end
  opts = opts or {}
  turns = turns or 5
  local prev = BattleCompat.getWeather(battle)
  -- Same weather: Sand Stream still upgrades a 5-turn storm to ability
  -- weather; a move recast does not.
  if prev == weather then
    if opts.fromAbility and weather then
      battle._krAbilityWeather = true
    elseif not opts.fromAbility then
      battle._krAbilityWeather = nil
    end
    if message then BattleCompat.say(battle, message) end
    return
  end

  battle._krAbilityWeather = (opts.fromAbility and weather) and true or nil
  battle.field = battle.field or { tokens = {}, sides = battle.sides }
  battle.field.weather = weather
  battle.field.weatherTurns = weather and turns or nil
  battle._krWeather = nil

  if BattleCompat.isGen2(battle) then
    if weather == "HAIL" or weather == "SNOWY" then
      -- Gold has no hail; keep a KR overlay for Forecast / Weather Ball.
      battle._krWeather = "HAIL"
      battle.weather = nil
      battle.weatherTurns = turns
    elseif weather and GEN2_WEATHER[weather] then
      battle.weather = GEN2_WEATHER[weather]
      battle.weatherTurns = turns
    else
      battle.weather = nil
      battle.weatherTurns = 0
    end
  end

  if message then BattleCompat.say(battle, message) end
end

function BattleCompat.castformSuffix(weather)
  if weather == "SUNNY" then return "sunny" end
  if weather == "RAINY" then return "rainy" end
  if weather == "HAIL" or weather == "SNOWY" then return "snowy" end
  return nil
end

--- Scale a Gen2 damage opts attacker/defender stat (or Gen1 curStats).
function BattleCompat.scaleOffense(ctx, user, isPhysical, factor)
  if not ctx or not factor or factor == 1 then return nil end
  if ctx.opts and ctx.opts.attacker then
    local key = isPhysical and "attack" or "specialAttack"
    local old = ctx.opts.attacker[key]
    if type(old) == "number" then
      ctx.opts.attacker[key] = math.floor(old * factor)
      return function() ctx.opts.attacker[key] = old end
    end
  end
  if user and user.curStats then
    local key = isPhysical and "attack" or "special"
    local old = user.curStats[key]
    if type(old) == "number" then
      user.curStats[key] = math.floor(old * factor)
      return function() user.curStats[key] = old end
    end
  end
  return nil
end

function BattleCompat.scaleDefense(ctx, target, isPhysical, factor)
  if not ctx or not factor or factor == 1 then return nil end
  if ctx.opts and ctx.opts.defender then
    local key = isPhysical and "defense" or "specialDefense"
    local old = ctx.opts.defender[key]
    if type(old) == "number" then
      ctx.opts.defender[key] = math.floor(old * factor)
      return function() ctx.opts.defender[key] = old end
    end
  end
  if target and target.curStats then
    local key = isPhysical and "defense" or "special"
    local old = target.curStats[key]
    if type(old) == "number" then
      target.curStats[key] = math.floor(old * factor)
      return function() target.curStats[key] = old end
    end
  end
  return nil
end

function BattleCompat.heal(battler, amount)
  local mon = BattleCompat.mon(battler)
  if not mon or not amount then return end
  if (battler.expHealBlockTurns or 0) > 0
      or (mon.expHealBlockTurns or 0) > 0 then
    return
  end
  local maxHp = BattleCompat.maxHp(battler)
  mon.hp = math.min(maxHp, (mon.hp or 0) + amount)
end

function BattleCompat.applyHpLoss(battle, battler, amount)
  local mon = BattleCompat.mon(battler)
  if not mon or not amount or amount <= 0 then return end
  if battle and type(battle.applyDamage) == "function" and battler.mon then
    battle:applyDamage(battler, amount)
    return
  end
  mon.hp = math.max(0, (mon.hp or 0) - amount)
  if battle and type(battle.dealDamage) == "function" then
    -- Prefer not double-applying; HP already reduced.
  end
end

-- Ephemeral AI / Gen1-facade fields. On Gold the battler IS the party mon, so
-- leaving these on the table makes them ride into SaveSerializer.encode.
-- `mon` self-alias is the post-rival SAVE crash (party[i].mon == party[i]).
local AI_EPHEMERAL = {
  "curStats", "curTypes", "curMoves", "stages",
  "expProtected", "expEnduring",
}

--- Strip AI facade fields from party mons so Gold saves stay acyclic.
function BattleCompat.scrubPartyMons(party)
  for _, mon in ipairs(party or {}) do
    if type(mon) == "table" then
      -- Self-cycle from prepareAiBattler before the Gen2 guard existed.
      if mon.mon == mon then mon.mon = nil end
      for _, key in ipairs(AI_EPHEMERAL) do
        mon[key] = nil
      end
    end
  end
end

function BattleCompat.scrubBattle(battle)
  if not battle then return end
  BattleCompat.scrubPartyMons(battle.party)
  BattleCompat.scrubPartyMons(battle.enemyParty)
  local game = battle.game
  if game and game.save then
    BattleCompat.scrubPartyMons(game.save.party)
  end
end

--- Attach Gen1-shaped AI fields onto a battler (idempotent). Gen2 party mons
--- become readable by TrainerAi scorers without mutating party stats.
function BattleCompat.prepareAiBattler(battle, battler)
  if not battler then return nil end
  local mon = BattleCompat.mon(battler)
  if not mon then return nil end
  -- Gen1: battler is a wrapper; set .mon once. Gen2: battler IS the party
  -- mon — never write battler.mon = battler (save-file cycle / stack overflow).
  if mon ~= battler and not battler.mon then
    battler.mon = mon
  end
  if not battler.curStats then
    local s = mon.stats or {}
    local spa = s.specialAttack or s.special or 1
    battler.curStats = {
      hp = s.hp or mon.maxHp or 1,
      attack = s.attack or 1,
      defense = s.defense or 1,
      speed = s.speed or 1,
      special = spa,
      specialAttack = spa,
      specialDefense = s.specialDefense or spa,
    }
  end
  if not battler.curTypes then
    battler.curTypes = BattleCompat.types(battler, battle and battle.data)
  end
  if not battler.curMoves then
    battler.curMoves = mon.moves or battler.moves or {}
  end
  local stages = BattleCompat.stages(battle, battler)
  if stages and not battler.stages then
    battler.stages = stages
  elseif stages and BattleCompat.isGen2(battle) then
    -- Keep stages pointer live for Gen2 side tables.
    battler.stages = stages
  end
  return battler
end

function BattleCompat.prepareAiBattle(battle)
  if not battle then return end
  if battle.data and battle.data.type_chart then
    local ok, TypeChart = pcall(require, "src.battle.TypeChart")
    if ok and TypeChart and TypeChart.load then
      pcall(TypeChart.load, battle.data)
    end
  end
  BattleCompat.prepareAiBattler(battle, battle.player)
  BattleCompat.prepareAiBattler(battle, battle.enemy)
  if battle.kind == nil then
    battle.kind = battle.wild and "wild" or "trainer"
  end
  if not battle.oppClass and battle.trainer then
    battle.oppClass = battle.trainer.classId or battle.trainer.class
      or battle.trainer.id
  end
  if battle.expPartyIndex == nil and battle.trainer then
    -- Prefer numeric roster index. Gen2 World puts memberId as a string id
    -- (FALKNER_1); that must not replace the party slot used by isElite.
    local t = battle.trainer
    if type(t.member) == "number" then
      battle.expPartyIndex = t.member
    elseif type(t.index) == "number" then
      battle.expPartyIndex = t.index
    else
      battle.expPartyIndex = 1
    end
    if t.memberId or t.id then
      battle.expMemberId = t.memberId or t.id
    end
  end
  -- Gen2 has no wAICount; treat as always allowed for elite move brain.
  if BattleCompat.isGen2(battle) and battle.aiUses == nil then
    battle.aiUses = 99
  end
end

--- Gen2 volatile table for a battler (nil-safe).
function BattleCompat.volatile(battle, battler)
  if not battle or not battler then return nil end
  if type(battle.volatile) == "function" then
    local ok, vol = pcall(function() return battle:volatile(battler) end)
    if ok then return vol end
  end
  return battler.volatile
end

function BattleCompat.isConfused(battle, battler)
  if not battler then return false end
  if battler.confusedTurns and battler.confusedTurns > 0 then return true end
  local vol = BattleCompat.volatile(battle, battler)
  return vol and (vol.confuseCount or 0) > 0
end

function BattleCompat.isSeeded(battle, battler)
  if not battler then return false end
  if battler.leechSeeded then return true end
  local vol = BattleCompat.volatile(battle, battler)
  return vol and vol.leechSeed and true or false
end

function BattleCompat.hasSubstitute(battle, battler)
  if not battler then return false end
  if battler.substituteHP and battler.substituteHP > 0 then return true end
  local vol = BattleCompat.volatile(battle, battler)
  return vol and vol.substitute and true or false
end

function BattleCompat.hasMist(battle, battler)
  if not battler then return false end
  if battler.mist then return true end
  local vol = BattleCompat.volatile(battle, battler)
  return vol and vol.mist and true or false
end

function BattleCompat.disabledMoveId(battle, battler)
  if not battler then return nil end
  if battler.disabledSlot and battler.curMoves and battler.curMoves[battler.disabledSlot] then
    return battler.curMoves[battler.disabledSlot].id
  end
  local vol = BattleCompat.volatile(battle, battler)
  return vol and vol.disabled or nil
end

--- Screen / side field flag. key: lightScreen, reflect, mist, focusEnergy, expSafeguard.
function BattleCompat.hasScreen(battle, battler, key)
  if not battler or not key then return false end
  if battler[key] then return true end
  if key == "focusEnergy" then
    local vol = BattleCompat.volatile(battle, battler)
    if vol and vol.focusEnergy then return true end
  end
  if key == "mist" then return BattleCompat.hasMist(battle, battler) end
  if not battle then return false end
  local sideKey
  if type(battle.sideOf) == "function" then
    local ok, side = pcall(function() return battle:sideOf(battler) end)
    if ok then sideKey = side end
  end
  if not sideKey then
    sideKey = (battler == battle.player) and "player" or "enemy"
  end
  local screens = battle.screens and battle.screens[sideKey]
  if screens then
    if key == "lightScreen" and screens.lightScreen then return true end
    if key == "reflect" and screens.reflect then return true end
    if key == "expSafeguard" and (screens.safeguard or screens.expSafeguard) then
      return true
    end
  end
  local sides = battle.sides and battle.sides[sideKey]
  if sides and key == "expSafeguard" and (sides.expSafeguardTurns or 0) > 0 then
    return true
  end
  return false
end

--- Map Gen1 "special" stage name onto Gen2 specialAttack when needed.
function BattleCompat.stageStat(stat, battle)
  if stat == "special" and BattleCompat.isGen2(battle) then
    return "specialAttack"
  end
  return stat
end

--- Forced / locked move id: Gen2 charge (Dig/Fly), Rollout/Thrash, Encore;
--- Gen1 lockedAction.
function BattleCompat.forcedMoveId(battle, battler)
  if not battle or not battler then return nil end
  if BattleCompat.isGen2(battle) then
    -- Dig/Fly second turn is not in forcedMove(); vanilla enemy AI returns it
    -- before usableMoves scoring (Battle.lua enemy choose).
    local vol = BattleCompat.volatile(battle, battler)
    if vol and vol.chargeMove then return vol.chargeMove end
    if type(battle.forcedMove) == "function" then
      local ok, id = pcall(function() return battle:forcedMove(battler) end)
      if ok and id then return id end
    end
    return nil
  end
  if type(battle.lockedAction) == "function" then
    local ok, act = pcall(function() return battle:lockedAction(battler) end)
    if ok and act then
      return type(act) == "table" and (act.id or act.move) or act
    end
  end
  return nil
end

-- The action object enemy_action must return.  Gen1 ChargeEffect releases
-- only when `user.charging == moveInst` (identity).  A fresh `{id=DIG}`
-- table re-charges forever and leaves Dig/Fly invulnerable (softlock).
function BattleCompat.forcedAction(battle, battler)
  if not battle or not battler then return nil end
  if BattleCompat.isGen2(battle) then
    return BattleCompat.forcedMoveId(battle, battler)
  end
  if type(battle.lockedAction) == "function" then
    local ok, act = pcall(function() return battle:lockedAction(battler) end)
    if ok and act then return act end
  end
  local id = BattleCompat.forcedMoveId(battle, battler)
  if not id then return nil end
  if type(id) == "table" then return id end
  for _, mv in ipairs(battler.curMoves or battler.moves or {}) do
    if mv.id == id then return mv end
  end
  return { id = id, pp = 1 }
end

--- Moves the AI may legally pick this turn.
function BattleCompat.usableMoves(battle, battler)
  if not battler then return {} end
  if BattleCompat.isGen2(battle) and type(battle.usableMoves) == "function" then
    local ok, moves = pcall(function() return battle:usableMoves(battler) end)
    if ok and moves and #moves > 0 then return moves end
  end
  local out = {}
  local disabledId = BattleCompat.disabledMoveId(battle, battler)
  for i, mv in ipairs(battler.curMoves or battler.moves or {}) do
    if (not battler.disabledSlot or battler.disabledSlot ~= i)
        and (not disabledId or mv.id ~= disabledId)
        and (mv.pp or 0) > 0 then
      out[#out + 1] = mv
    end
  end
  return out
end

function BattleCompat.install(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen1() then
    local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
    pcall(function()
      Gen1Patch.apply(require("src.battle.BattleState"), function(BattleState)
        if BattleState._krGen3BoundFix then return end
        local origFightLocked = BattleState.fightLockedAction
        function BattleState:fightLockedAction(battler)
          local lock = origFightLocked(self, battler)
          if lock and type(lock) == "table" and lock.special == "bound" then
            -- Gen 3 partial trapping parity: BIND/WRAP/CLAMP/FIRE_SPIN do NOT lock out move selection
            return nil
          end
          return lock
        end
        BattleState._krGen3BoundFix = true
      end)
    end)
  end
end

return BattleCompat
