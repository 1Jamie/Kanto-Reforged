-- Adapter router: pick Gen1 or Gen2 host adapter from the live battle object.

local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local Gen1 = require("mods.Kanto-Reforged.battle.adapters.gen1")
local Gen2 = require("mods.Kanto-Reforged.battle.adapters.gen2")

local Adapters = {}

--- Resolve the host adapter module for a battle (or current process host).
function Adapters.hostFor(battle)
  if battle and BattleCompat.isGen2(battle) then
    return Gen2
  end
  if not battle or not next(battle) then
    local ok, Host = pcall(require, "mods.Kanto-Reforged.core.host")
    if ok and Host and Host.isGen2 and Host.isGen2() then
      return Gen2
    end
  end
  return Gen1
end

function Adapters.forBattle(battle)
  if not battle then return nil end
  return Adapters.hostFor(battle).new(battle)
end

function Adapters.isGen2(battle)
  return BattleCompat.isGen2(battle)
end

Adapters.gen1 = Gen1
Adapters.gen2 = Gen2

return Adapters
