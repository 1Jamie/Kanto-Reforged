-- Shared switch-in handling for Gen1 and Gen2 (hazards, volatile reset, Healing Wish).

local Strings = require("src.core.Strings")
local TypeChart = require("src.battle.TypeChart")
local Adapters = require("mods.Kanto-Reforged.battle.adapters")
local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")

local SwitchIn = {}

local INCOMING_CLEAR = {
  "expTrapped",
  "expPartialTrapTurns",
  "expPartialTrapMove",
  "expPartialTrapMoveId",
  "expCursed",
  "expYawnTurns",
  "expDestinyBond",
  "expIngrain",
  "expAquaRing",
  "expStockpile",
  "expInfatuated",
  "expNightmare",
  "expFuryCutter",
  "expRollout",
  "expRolloutMove",
  "expLockedOn",
  "expIdentified",
  "expForesighted",
  "expMagicCoat",
  "expGrudge",
  "expTormented",
  "expTormentLast",
  "expUproarTurns",
  "expUproarMove",
  "expImprison",
  "expSnatch",
  "expCharged",
  "expAbilitySuppressed",
  "expMeFirst",
  "expTracedAbility",
  "expEmbargoTurns",
  "expHealBlockTurns",
}

local function hasType(types, typeId)
  for _, t in ipairs(types or {}) do
    if t == typeId then return true end
  end
  return false
end

local function clearIncoming(battler, pass)
  if not battler then return end
  battler.expJustEntered = true
  for _, key in ipairs(INCOMING_CLEAR) do
    battler[key] = nil
  end
  if pass then
    battler.stages = pass.stages or battler.stages
    battler.confusedTurns = pass.confusedTurns
    battler.focusEnergy = pass.focusEnergy
    battler.substituteHP = pass.substituteHP
    battler.expIngrain = pass.expIngrain
    battler.expAquaRing = pass.expAquaRing
    battler.expPerishTurns = pass.expPerishTurns
    battler.expCursed = pass.expCursed
    battler.expTrapped = pass.expTrapped
    battler.leechSeeded = pass.leechSeeded
  end
end

function SwitchIn.applyHazards(adapter, battler, side)
  if not adapter or not battler or not side or not side.hazards then return end
  if adapter:isFainted(battler) then return end

  local types = adapter:types(battler)
  local grounded = not hasType(types, "FLYING")
    and adapter:abilityOf(battler) ~= "LEVITATE"

  for _, h in ipairs(side.hazards) do
    if h.id == "SPIKES" and grounded then
      local layers = h.layers or 1
      local denom = ({ 8, 6, 4 })[math.min(3, layers)] or 8
      local dmg = math.max(1, math.floor(adapter:maxHp(battler) / denom))
      adapter:applyHpLoss(battler, dmg)
      adapter:say(Strings("%s is hurt\nby SPIKES!", adapter:displayName(battler)))
    elseif h.id == "STEALTH_ROCK" then
      local mult = TypeChart.effectiveness("ROCK", types) or 0
      if mult > 0 then
        local dmg = math.max(1, math.floor(adapter:maxHp(battler) * mult / 80))
        adapter:applyHpLoss(battler, dmg)
        adapter:say(Strings("Pointed stones dug\ninto %s!", adapter:displayName(battler)))
      end
    elseif h.id == "TOXIC_SPIKES" and grounded then
      if hasType(types, "POISON") then
        for i = #side.hazards, 1, -1 do
          if side.hazards[i].id == "TOXIC_SPIKES" then
            table.remove(side.hazards, i)
          end
        end
        adapter:say(Strings("The poison spikes\ndisappeared!"))
      elseif not hasType(types, "STEEL") and not adapter:status(battler) then
        local layers = h.layers or 1
        local toxic = layers >= 2
        local status = toxic and "toxic" or "poison"
        adapter:applyStatus(battler, status, nil, {
          toxic = toxic,
          source = "TOXIC_SPIKES",
        })
      end
    end
    if adapter:isFainted(battler) then
      adapter:emitFaint(battler)
      break
    end
  end
end

function SwitchIn.onBattlerSwitched(ev)
  local battle = ev.battle
  if not battle then return end

  local PartialTrap = require("mods.Kanto-Reforged.battle.partial_trap")
  PartialTrap.clearBattle(battle)

  if ev.previous and ev.previous.mon then
    local Abilities = require("mods.Kanto-Reforged.battle.abilities")
    if Abilities.abilityOf(battle, ev.previous) == "NATURAL_CURE" then
      ev.previous.mon.status = nil
    end
    local other = ev.previous.isPlayer and battle.enemy or battle.player
    if other then other.expInfatuated = nil end
  end

  local battler = ev.battler
  if not battler then return end

  local pass = ev.previous and ev.previous.expBatonPass
  if ev.previous then ev.previous.expBatonPass = nil end
  clearIncoming(battler, pass)

  local adapter = Adapters.forBattle(battle)
  if not adapter then return end

  local side = ev.side or adapter:ownSide(battler)
  if side and side.expHealingWish then
    side.expHealingWish = nil
    local mon = BattleCompat.mon(battler)
    if mon then
      mon.hp = adapter:maxHp(battler)
      mon.status = nil
      mon.statusTurns = nil
      mon.toxicCounter = nil
      battler.toxicCounter = nil
      adapter:say(Strings("The HEALING WISH came true!\n%s recovered!",
        adapter:displayName(battler)))
    end
  end

  if side then
    SwitchIn.applyHazards(adapter, battler, side)
  end
end

function SwitchIn.onBattleStarted(ev)
  if not ev.battle then return end
  for _, b in ipairs({ ev.battle.player, ev.battle.enemy }) do
    if b then
      b.expJustEntered = true
      b.expInfatuated = nil
    end
  end
end

function SwitchIn.install(mod)
  if not mod or not mod.events then return end
  mod.events:on("battle.battler_switched", SwitchIn.onBattlerSwitched)
  mod.events:on("battle.started", SwitchIn.onBattleStarted)
end

return SwitchIn
