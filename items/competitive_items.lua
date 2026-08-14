-- Choice Band / Life Orb / Focus Sash (+ Heart Scale, trade preloads).

local Strings = require("src.core.Strings")
local HeldItems = require("mods.Kanto-Reforged.items.held_items")

local Competitive = {}

Competitive.ITEMS = {
  CHOICE_BAND = {
    id = "CHOICE_BAND", name = "CHOICE BAND", price = 0,
    holdEffect = "choice_band", tossable = true,
  },
  LIFE_ORB = {
    id = "LIFE_ORB", name = "LIFE ORB", price = 0,
    holdEffect = "life_orb", tossable = true,
  },
  FOCUS_SASH = {
    id = "FOCUS_SASH", name = "FOCUS SASH", price = 0,
    holdEffect = "focus_sash", tossable = true,
  },
  HEART_SCALE = {
    id = "HEART_SCALE", name = "HEART SCALE", price = 100,
    tossable = true,
  },
  SOOTHE_BELL = {
    id = "SOOTHE_BELL", name = "SOOTHE BELL", price = 100,
    holdEffect = "soothe_bell", tossable = true,
  },
  CLEANSE_TAG = {
    id = "CLEANSE_TAG", name = "CLEANSE TAG", price = 100,
    holdEffect = "cleanse_tag", tossable = true,
  },
}

local function displayName(b)
  return b.isPlayer and b.name or ("Enemy " .. b.name)
end

local function clearChoice(battler)
  if battler then battler.expChoiceLock = nil end
end

function Competitive.clearChoiceLocks(battle)
  if not battle then return end
  clearChoice(battle.player)
  clearChoice(battle.enemy)
end

function Competitive.register(mod)
  for id, def in pairs(Competitive.ITEMS) do
    HeldItems.CATALOG[id] = def
    -- Gold may already define HEART_SCALE / similar; skip collisions.
    if not mod.content.items:get(id) then
      mod.content.items:register(id, {
        id = def.id,
        name = def.name,
        price = def.price or 0,
        tossable = def.tossable ~= false,
      })
    end
  end
end

function Competitive.install(mod)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")

  local function holdId(battler)
    local mon = BattleCompat.mon(battler) or battler
    return HeldItems.ofBattler(battler) or HeldItems.get(mon)
  end

  local function monOf(battler)
    return BattleCompat.mon(battler) or (battler and battler.mon) or battler
  end

  -- Atk / damage modifiers
  mod.hooks:wrap("battle.damage", function(next, ctx)
    local dmg, info = next(ctx)
    if not dmg or dmg <= 0 or not ctx then return dmg, info end
    local user = ctx.user
    local move = ctx.move
    if not user or not move then return dmg, info end
    local id = holdId(user)
    local def = id and HeldItems.def(id)
    if not def then return dmg, info end

    if def.holdEffect == "choice_band" and move.category == "physical" then
      dmg = math.floor(dmg * 1.5)
    elseif def.holdEffect == "life_orb" and move.power and move.power > 0 then
      dmg = math.floor(dmg * 1.3)
      user.expLifeOrbPending = true
    end
    return dmg, info
  end)

  -- Choice lock: record first damaging/status move used
  mod.events:on("battle.move_used", function(ev)
    if not ev or not ev.user or not ev.move then return end
    if holdId(ev.user) ~= "CHOICE_BAND" then return end
    if not ev.user.expChoiceLock then
      ev.user.expChoiceLock = ev.move.id
    end
  end)

  mod.events:on("battle.battler_switched", function(ev)
    if ev and ev.battler then clearChoice(ev.battler) end
  end)

  mod.events:on("battle.ended", function(ev)
    Competitive.clearChoiceLocks(ev and ev.battle)
  end)

  -- Life Orb recoil after a connecting damaging move
  mod.events:on("battle.turn_ended", function(ev)
    if not ev or not ev.battle then return end
    local function tick(b)
      if not b or not b.expLifeOrbPending then return end
      b.expLifeOrbPending = nil
      local mon = monOf(b)
      if not mon or holdId(b) ~= "LIFE_ORB" or (mon.hp or 0) <= 0 then return end
      local maxHp = (mon.stats and mon.stats.hp) or mon.maxHp or mon.hp or 1
      local recoil = math.max(1, math.floor(maxHp / 10))
      mon.hp = math.max(0, mon.hp - recoil)
      if ev.battle.sayNext then
        ev.battle:sayNext(Strings("%s is hurt\nby its LIFE ORB!", displayName(b)))
      elseif BattleCompat.say then
        BattleCompat.say(ev.battle, Strings("%s is hurt\nby its LIFE ORB!",
          BattleCompat.displayName(ev.battle, b)))
      end
      if ev.battle.drainNext then ev.battle:drainNext() end
    end
    tick(ev.battle.player)
    tick(ev.battle.enemy)
  end)

  -- Focus Sash / Choice Band BattleState patches are Gen1-only (Gold battle
  -- lives in src/battle/gen2). Damage/event hooks above still apply on both.
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen1() then return end

  -- Focus Sash: first lethal hit from full HP → 1 HP, consume (per-hit).
  -- Later hits in a multi-hit can still faint.
  local BattleState = require("src.battle.BattleState")
  if not BattleState._expansionFocusSash then
    local original_applyDamage = BattleState.applyDamage
    BattleState.applyDamage = function(self, target, dmg)
      if target and target.mon and dmg and dmg > 0 and not target.substituteHP then
        local mon = target.mon
        if mon.heldItem == "FOCUS_SASH"
            and mon.hp == mon.stats.hp
            and dmg >= mon.hp then
          dmg = mon.hp - 1
          mon.heldItem = nil
          if self.sayNext then
            self:sayNext(Strings("%s hung on\nusing its FOCUS SASH!", displayName(target)))
          end
        end
      end
      return original_applyDamage(self, target, dmg)
    end
    BattleState._expansionFocusSash = true
  end

  -- Choice Band: force locked move on Fight confirm when possible
  if not BattleState._expansionChoiceBand then
    local origUpdate = BattleState.update
    BattleState.update = function(self, dt)
      if self.state == "move" and self.player and self.player.expChoiceLock then
        local lock = self.player.expChoiceLock
        local moves = self.player.curMoves or {}
        for i, mv in ipairs(moves) do
          if mv and mv.id == lock then
            self.moveIndex = i
            break
          end
        end
      end
      return origUpdate(self, dt)
    end
    BattleState._expansionChoiceBand = true
  end

  -- Clear choice lock on Roar/Whirlwind forced switch via fainted/switch events
  mod.events:on("battle.fainted", function(ev)
    if ev and ev.battler then clearChoice(ev.battler) end
  end)
end

return Competitive
