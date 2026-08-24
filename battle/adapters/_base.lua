-- Shared adapter builder. Host-specific I/O lives in gen1.lua / gen2.lua.

local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local Rules = require("mods.Kanto-Reforged.battle.core.rules")
local EffectCtx = require("mods.Kanto-Reforged.battle.core.effect_ctx")

local Base = {}

local function findHazard(side, id)
  if not side or not side.hazards then return nil end
  for _, h in ipairs(side.hazards) do
    if h.id == id then return h end
  end
  return nil
end

--- @param battle table live battle object (Gen1 BattleState or Gen2 Battle)
--- @param host table host module (gen1.lua / gen2.lua) with id + host hooks
function Base.new(battle, host)
  local adapter = {
    _battle = battle,
    _host = host.id,
  }
  setmetatable(adapter, { __index = adapter })

  function adapter:mon(battler)
    return BattleCompat.mon(battler)
  end

  function adapter:hp(battler)
    return BattleCompat.hp(battler)
  end

  function adapter:maxHp(battler)
    return BattleCompat.maxHp(battler)
  end

  function adapter:status(battler)
    return BattleCompat.status(battler)
  end

  function adapter:types(battler)
    return BattleCompat.types(battler, battle.data)
  end

  function adapter:stages(battler)
    return BattleCompat.stages(battle, battler)
  end

  function adapter:changeStages(battler, changes)
    return BattleCompat.changeStages(battle, battler, changes)
  end

  function adapter:applyStatus(battler, status, source, opts)
    return BattleCompat.applyStatus(battle, battler, status, source, opts)
  end

  function adapter:applyHpLoss(battler, amount)
    BattleCompat.applyHpLoss(battle, battler, amount)
  end

  function adapter:heal(battler, amount)
    host.heal(self, battler, amount)
  end

  function adapter:say(text, ...)
    host.say(self, text, ...)
  end

  function adapter:displayName(battler)
    return BattleCompat.displayName(battle, battler)
  end

  function adapter:rng()
    return battle.rng or battle.random or math.random
  end

  function adapter:isFainted(battler)
    return (self:hp(battler) or 0) <= 0
  end

  function adapter:isBattleDecided()
    return host.isBattleDecided(self)
  end

  function adapter:activeBattlers()
    local out = {}
    if battle.player then out[#out + 1] = battle.player end
    if battle.enemy then out[#out + 1] = battle.enemy end
    return out
  end

  function adapter:emitFaint(battler)
    host.emitFaint(self, battler)
  end

  function adapter:foeSide(battler)
    if not battle.sides then return nil end
    if type(battle.sideOf) == "function" then
      local mine = battle:sideOf(battler)
      if mine == "player" then return battle.sides.enemy or battle.sides[2] end
      if mine == "enemy" then return battle.sides.player or battle.sides[1] end
      if type(mine) == "number" then
        return battle.sides[3 - mine] or battle.sides[mine == 1 and 2 or 1]
      end
    end
    if battler == battle.player then return battle.sides.enemy or battle.sides[2] end
    return battle.sides.player or battle.sides[1]
  end

  function adapter:ownSide(battler)
    if not battle.sides then return nil end
    if type(battle.sideOf) == "function" then
      local mine = battle:sideOf(battler)
      if type(mine) == "string" then return battle.sides[mine] end
      if type(mine) == "number" then return battle.sides[mine] end
      return mine
    end
    if battler == battle.player then return battle.sides.player or battle.sides[1] end
    return battle.sides.enemy or battle.sides[2]
  end

  adapter.trap = {}
  function adapter.trap.get(battler)
    if not battler then return 0 end
    return battler.expPartialTrapTurns or 0
  end

  function adapter.trap.moveName(battler)
    return battler and battler.expPartialTrapMove or nil
  end

  function adapter.trap.set(battler, turns, moveId, moveName)
    if not battler then return end
    battler.expPartialTrapTurns = turns
    battler.expPartialTrapMoveId = moveId
    battler.expPartialTrapMove = moveName
    host.trapSet(self, battler, turns, moveId, moveName)
  end

  function adapter.trap.clear(battler)
    if not battler then return end
    battler.expPartialTrapTurns = nil
    battler.expPartialTrapMove = nil
    battler.expPartialTrapMoveId = nil
    host.trapClear(self, battler)
  end

  function adapter:isGen2()
    return host.id == "gen2"
  end

  function adapter:foeOf(battler)
    if battler == battle.player then return battle.enemy end
    if battler == battle.enemy then return battle.player end
    return nil
  end

  function adapter:heldItemOf(battler)
    local mon = BattleCompat.mon(battler)
    if not mon then return nil end
    return mon.heldItem or mon.item
  end

  function adapter:speciesOf(battler)
    local mon = BattleCompat.mon(battler)
    return mon and mon.species or nil
  end

  function adapter:abilityOf(battler)
    local Abilities = require("mods.Kanto-Reforged.battle.abilities")
    return Abilities.abilityOf(battle, battler)
  end

  function adapter:hasStatus(battler, ...)
    return BattleCompat.hasStatus(battler, ...)
  end

  function adapter:isSeeded(battler)
    return BattleCompat.isSeeded(battle, battler)
  end

  function adapter:clearSeed(battler)
    if not battler then return end
    battler.leechSeeded = nil
    host.clearSeed(self, battler)
  end

  function adapter:lastMoveOf(battler)
    return host.lastMoveOf(self, battler)
  end

  function adapter:preparedMoves(battler)
    if not battler then return {} end
    return battler.curMoves or battler.moves or {}
  end

  function adapter:partyMons(battler)
    battler = battler or battle.player
    local isPlayer = battler == battle.player
    if battler and battler.isPlayer ~= nil then
      isPlayer = battler.isPlayer
    elseif type(battle.sideOf) == "function" then
      local ok, key = pcall(function() return battle:sideOf(battler) end)
      if ok and key == "player" then isPlayer = true end
      if ok and key == "enemy" then isPlayer = false end
    end
    if isPlayer then
      return battle.party
        or (battle.game and battle.game.save and battle.game.save.party)
        or {}
    end
    return battle.enemyParty or {}
  end

  function adapter:gen3PartialTrapActive()
    local PartialTrap = require("mods.Kanto-Reforged.battle.partial_trap")
    return PartialTrap.active(battle)
  end

  function adapter:fieldGet(key)
    return battle[key]
  end

  function adapter:fieldSet(key, value)
    battle[key] = value
  end

  function adapter:tickWeather()
    local Weather = require("mods.Kanto-Reforged.battle.weather")
    Weather.tick(battle)
  end

  function adapter:setWeather(kind, turns, opts)
    opts = opts or {}
    BattleCompat.setWeather(battle, kind, nil, turns or 5, opts)
    -- Callers that print a weather start line first pass skipForecast, then
    -- Forecast themselves (FRLG: start text → ON_WEATHER / transformed!).
    if opts.skipForecast then return end
    local ok, Abilities = pcall(require, "mods.Kanto-Reforged.battle.abilities")
    if ok and Abilities then
      for _, b in ipairs(self:activeBattlers()) do
        Abilities.updateForecast(battle, b)
      end
    end
  end

  function adapter:onTurnEnded(battler)
    local Abilities = require("mods.Kanto-Reforged.battle.abilities")
    Abilities.onTurnEnded(battle, battler)
  end

  function adapter:tickStatusBerry(battler)
    local HeldItems = require("mods.Kanto-Reforged.items.held_items")
    if HeldItems.tickStatusBerry then
      HeldItems.tickStatusBerry(battle, battler)
    end
  end

  adapter.weather = {}
  function adapter.weather.get()
    local Weather = require("mods.Kanto-Reforged.battle.weather")
    return Weather.current(battle)
  end

  function adapter.weather.set(id, turns, opts)
    BattleCompat.setWeather(battle, id, nil, turns, opts)
  end

  adapter.screen = {}
  function adapter.screen.get(side, key)
    if not side then return nil end
    return side[key] or side["exp" .. key:sub(1, 1) .. key:sub(2):lower() .. "Turns"]
  end

  function adapter.screen.set(side, key, turns)
    if not side then return end
    side["exp" .. key:sub(1, 1) .. key:sub(2):lower() .. "Turns"] = turns
    if key == "reflect" then side.reflect = turns > 0 end
    if key == "lightScreen" then side.lightScreen = turns > 0 end
  end

  adapter.substitute = {}
  function adapter:hasSubstitute(battler)
    return BattleCompat.hasSubstitute(battle, battler)
  end

  function adapter.substitute.blocks(effectKind, target)
    return Rules.substitute.blocks(effectKind, target, battle)
  end

  function adapter:clearScreens(battler)
    return host.clearScreens(self, battler)
  end

  function adapter:isConfused(battler)
    return BattleCompat.isConfused(battle, battler)
  end

  function adapter:applyConfusion(battler, turns, source)
    return BattleCompat.applyConfusion(battle, battler, turns, source)
  end

  function adapter:clearStatus(battler)
    local mon = BattleCompat.mon(battler)
    if not mon then return false end
    if not mon.status then return false end
    mon.status = nil
    mon.statusTurns = nil
    mon.toxicCounter = nil
    return true
  end

  adapter.volatile = {}
  function adapter.volatile.get(battler, key)
    return host.volatileGet(self, battler, key)
  end

  function adapter.volatile.set(battler, key, val)
    host.volatileSet(self, battler, key, val)
  end

  function adapter:findHazard(side, id)
    return findHazard(side, id)
  end

  function adapter:sayFail()
    host.sayFail(self)
  end

  function adapter:invokeEffect(id, user, target, opts)
    local CoreEffects = require("mods.Kanto-Reforged.battle.core.effects")
    if not CoreEffects.has(id) then return false end
    local ctx = EffectCtx.push(self, user, target, opts and opts.move, id,
      self:rng(), opts)
    local ok, err = pcall(CoreEffects.run, id, ctx)
    EffectCtx.pop()
    if not ok then error(err) end
    return true
  end

  function adapter:useMove(user, moveId, target, opts)
    return host.useMove(self, user, moveId, target, opts)
  end

  function adapter:residualRegister(phase, fn)
    local Residuals = require("mods.Kanto-Reforged.battle.core.residuals")
    Residuals.register(phase, fn)
  end

  return adapter
end

return Base
