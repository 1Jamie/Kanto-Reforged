-- Gen2 host adapter: Battle model, bare party mons, emit/dealDamage/useMove.

local Strings = require("src.core.Strings")
local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local Base = require("mods.Kanto-Reforged.battle.adapters._base")

local Gen2 = { id = "gen2" }

function Gen2.say(adapter, text, ...)
  BattleCompat.say(adapter._battle, text, ...)
end

function Gen2.heal(_adapter, battler, amount)
  BattleCompat.heal(battler, amount)
end

function Gen2.emitFaint(adapter, battler)
  local battle = adapter._battle
  if type(battle.emit) == "function" then
    battle:emit({ kind = "fainted", battler = battler,
      mon = adapter:mon(battler) })
  end
end

function Gen2.isBattleDecided(adapter)
  local battle = adapter._battle
  if battle.over or battle.decided then return true end
  if battle.player and adapter:isFainted(battle.player) then
    if battle.kind == "wild" then return true end
  end
  return false
end

function Gen2.trapSet(adapter, battler, turns, moveId, moveName)
  local vol = BattleCompat.volatile(adapter._battle, battler)
  if not vol then return end
  if turns and turns > 0 then
    vol.wrapCount = 1
    vol.wrapMove = moveName
    vol.wrapMoveId = moveId
  else
    vol.wrapCount, vol.wrapMove, vol.wrapMoveId = nil, nil, nil
  end
end

function Gen2.trapClear(adapter, battler)
  local vol = BattleCompat.volatile(adapter._battle, battler)
  if vol then
    vol.wrapCount, vol.wrapMove, vol.wrapMoveId = nil, nil, nil
  end
end

function Gen2.clearSeed(adapter, battler)
  battler.leechSeeded = nil
  local vol = BattleCompat.volatile(adapter._battle, battler)
  if vol then vol.leechSeed = nil end
end

function Gen2.lastMoveOf(adapter, battler)
  if not battler then return nil end
  local vol = BattleCompat.volatile(adapter._battle, battler)
  if vol and vol.lastMove then return vol.lastMove end
  return battler.lastMove
end

function Gen2.volatileGet(adapter, battler, key)
  local vol = BattleCompat.volatile(adapter._battle, battler)
  return vol and vol[key]
end

function Gen2.volatileSet(adapter, battler, key, val)
  local vol = BattleCompat.volatile(adapter._battle, battler)
  if vol then vol[key] = val end
end

function Gen2.clearScreens(adapter, battler)
  local battle = adapter._battle
  local cleared = false
  if battle.screens and type(battle.sideOf) == "function" then
    local ok, key = pcall(function() return battle:sideOf(battler) end)
    local side = ok and key and battle.screens[key]
    if side and ((side.reflect or 0) > 0 or (side.lightScreen or 0) > 0) then
      side.reflect, side.lightScreen = nil, nil
      cleared = true
    end
  end
  return cleared
end

function Gen2.sayFail(adapter)
  adapter:say(Strings("But it failed!"))
end

function Gen2.useMove(adapter, user, moveId, target, opts)
  opts = opts or {}
  local battle = adapter._battle
  if type(battle.useMove) == "function" then
    return battle:useMove(user, moveId, target, opts)
  end
  return adapter:invokeEffect("EXP_" .. moveId .. "_EFFECT", user, target, opts)
    or adapter:invokeEffect(moveId, user, target, opts)
end

function Gen2.new(battle)
  return Base.new(battle, Gen2)
end

return Gen2
