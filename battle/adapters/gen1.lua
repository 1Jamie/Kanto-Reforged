-- Gen1 host adapter: BattleState ctx pipeline, battler wrappers, onFaint/sayNext.

local Strings = require("src.core.Strings")
local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local Base = require("mods.Kanto-Reforged.battle.adapters._base")

local Gen1 = { id = "gen1" }

function Gen1.say(adapter, text, ...)
  BattleCompat.say(adapter._battle, text, ...)
end

function Gen1.heal(adapter, battler, amount)
  BattleCompat.heal(battler, amount)
  -- BattleCompat.heal only mutates mon.hp; Gen1 bars chase via drainNext.
  local battle = adapter._battle
  if battle and type(battle.drainNext) == "function" then
    battle:drainNext(battler)
  end
end

-- Optional heal clip for held-item FX (spiral only; see KR_BERRY_HEAL).
function Gen1.healAnim(adapter, battler, animId)
  local battle = adapter._battle
  if not battle or type(battle.animNext) ~= "function" then return end
  local isPlayer = battler and (battler.isPlayer or battler == battle.player)
  battle:animNext(animId or "KR_BERRY_HEAL", isPlayer and true or false)
end

function Gen1.emitFaint(adapter, battler)
  local battle = adapter._battle
  if type(battle.onFaint) == "function" then
    battle:onFaint(battler)
  end
end

function Gen1.isBattleDecided(adapter)
  local battle = adapter._battle
  if battle.over or battle.decided then return true end
  if battle.player and adapter:isFainted(battle.player) then
    if battle.kind == "wild" then return true end
  end
  return false
end

function Gen1.trapSet(_adapter, _battler, _turns, _moveId, _moveName)
  -- Gen1 partial trap: no wrapCount shadow.
end

function Gen1.trapClear(_adapter, _battler)
end

function Gen1.clearSeed(_adapter, battler)
  battler.leechSeeded = nil
end

function Gen1.lastMoveOf(_adapter, battler)
  if not battler then return nil end
  return battler.lastMove
end

function Gen1.volatileGet(_adapter, battler, key)
  return battler and battler[key]
end

function Gen1.volatileSet(_adapter, battler, key, val)
  if battler then battler[key] = val end
end

function Gen1.clearScreens(adapter, battler)
  local battle = adapter._battle
  local cleared = false
  if battler and (battler.reflect or battler.lightScreen) then
    battler.reflect, battler.lightScreen = nil, nil
    cleared = true
  end
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

function Gen1.sayFail(adapter)
  adapter:say(Strings("But, it failed!"))
end

function Gen1.useMove(adapter, user, moveId, target, opts)
  opts = opts or {}
  return adapter:invokeEffect("EXP_" .. moveId .. "_EFFECT", user, target, opts)
    or adapter:invokeEffect(moveId, user, target, opts)
end

function Gen1.new(battle)
  return Base.new(battle, Gen1)
end

return Gen1
