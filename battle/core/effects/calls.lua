local Strings = require("src.core.Strings")
local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Calls = {}

local SLEEP_TALK_BLOCK = {
  SLEEP_TALK = true, COPYCAT = true, ASSIST = true, METRONOME = true,
  MIRROR_MOVE = true, SKETCH = true,
}

local COPYCAT_BLOCK = {
  COPYCAT = true, SLEEP_TALK = true, ASSIST = true, METRONOME = true,
  MIRROR_MOVE = true, SKETCH = true, TRANSFORM = true,
}

local ASSIST_BAN = {
  ASSIST = true, SLEEP_TALK = true, COPYCAT = true, METRONOME = true,
  MIRROR_MOVE = true, SKETCH = true, TRANSFORM = true, COUNTER = true,
  MIRROR_COAT = true, PROTECT = true, DETECT = true, ENDURE = true,
  DESTINY_BOND = true, THIEF = true,
}

local ME_FIRST_BLOCK = {
  ME_FIRST = true, COUNTER = true, MIRROR_COAT = true, PROTECT = true, DETECT = true,
}

function Calls.sleepTalk(ec, _raw)
  if not BattleCompat.hasStatus(ec.user, "SLP", "sleep") then
    ec.adapter:sayFail()
    return nil
  end
  local pool = {}
  for _, mv in ipairs(ec.adapter:preparedMoves(ec.user)) do
    local id = type(mv) == "table" and mv.id or mv
    local pp = type(mv) == "table" and (mv.pp or 1) or 1
    if id and not SLEEP_TALK_BLOCK[id] and pp > 0 then
      pool[#pool + 1] = id
    end
  end
  if #pool == 0 then
    ec.adapter:sayFail()
    return nil
  end
  local rng = ec.rng or ec.adapter:rng()
  local idx = type(rng) == "function" and rng(1, #pool) or math.random(1, #pool)
  return pool[idx]
end

function Calls.copycat(ec, _raw)
  local last = H.lastMove(ec, ec.target)
  if not last or COPYCAT_BLOCK[last] then
    ec.adapter:sayFail()
    return nil
  end
  return last
end

function Calls.assist(ec, _raw)
  local pool = {}
  for _, mon in ipairs(ec.adapter:partyMons(ec.user)) do
    if mon ~= ec.adapter:mon(ec.user) then
      for _, mv in ipairs(mon.moves or {}) do
        if mv.id and not ASSIST_BAN[mv.id] then pool[#pool + 1] = mv.id end
      end
    end
  end
  if #pool == 0 then
    ec.adapter:sayFail()
    return nil
  end
  local rng = ec.rng or ec.adapter:rng()
  local idx = type(rng) == "function" and rng(1, #pool) or math.random(1, #pool)
  return pool[idx]
end

function Calls.naturePower(_ec, _raw)
  return "EARTHQUAKE"
end

function Calls.meFirst(ec, _raw)
  local last = H.lastMove(ec, ec.target)
  if not last or ME_FIRST_BLOCK[last] then
    ec.adapter:sayFail()
    return nil
  end
  ec.user.expMeFirst = true
  return last
end

return Calls
