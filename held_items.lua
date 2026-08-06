-- Gen 2–3 held items for the expansion pack (engine stays Gen1-faithful).
-- Storage: mon.heldItem (string id). Give/Take via ui.party.submenu.

local Strings = require("src.core.Strings")

local HeldItems = {}

HeldItems.WILD_BERRY_CHANCE = 0.05

-- holdEffect:
--   leftovers | focus_band | berry | berry_status | type_boost
-- boostType: move type for type_boost (×1.1)
-- cure: status id or "confusion" for berry_status
HeldItems.CATALOG = {
  LEFTOVERS = {
    id = "LEFTOVERS", name = "LEFTOVERS", price = 200,
    holdEffect = "leftovers",
  },
  FOCUS_BAND = {
    id = "FOCUS_BAND", name = "FOCUS BAND", price = 200,
    holdEffect = "focus_band",
  },
  BERRY = {
    id = "BERRY", name = "BERRY", price = 300,
    holdEffect = "berry", heal = 10,
  },
  CHERI_BERRY = {
    id = "CHERI_BERRY", name = "CHERI BERRY", price = 600,
    holdEffect = "berry_status", cure = "PAR",
  },
  CHESTO_BERRY = {
    id = "CHESTO_BERRY", name = "CHESTO BERRY", price = 600,
    holdEffect = "berry_status", cure = "SLP",
  },
  PECHA_BERRY = {
    id = "PECHA_BERRY", name = "PECHA BERRY", price = 600,
    holdEffect = "berry_status", cure = "PSN",
  },
  RAWST_BERRY = {
    id = "RAWST_BERRY", name = "RAWST BERRY", price = 600,
    holdEffect = "berry_status", cure = "BRN",
  },
  ASPEAR_BERRY = {
    id = "ASPEAR_BERRY", name = "ASPEAR BERRY", price = 600,
    holdEffect = "berry_status", cure = "FRZ",
  },
  PERSIM_BERRY = {
    id = "PERSIM_BERRY", name = "PERSIM BERRY", price = 600,
    holdEffect = "berry_status", cure = "confusion",
  },
  LUM_BERRY = {
    id = "LUM_BERRY", name = "LUM BERRY", price = 2000,
    holdEffect = "berry_status", cure = "any",
  },
  MIRACLE_SEED = {
    id = "MIRACLE_SEED", name = "MIRACLE SEED", price = 100,
    holdEffect = "type_boost", boostType = "GRASS",
  },
  CHARCOAL = {
    id = "CHARCOAL", name = "CHARCOAL", price = 100,
    holdEffect = "type_boost", boostType = "FIRE",
  },
  MYSTIC_WATER = {
    id = "MYSTIC_WATER", name = "MYSTIC WATER", price = 100,
    holdEffect = "type_boost", boostType = "WATER",
  },
  MAGNET = {
    id = "MAGNET", name = "MAGNET", price = 100,
    holdEffect = "type_boost", boostType = "ELECTRIC",
  },
  NEVERMELTICE = {
    id = "NEVERMELTICE", name = "NEVERMELTICE", price = 100,
    holdEffect = "type_boost", boostType = "ICE",
  },
  BLACK_BELT = {
    id = "BLACK_BELT", name = "BLACK BELT", price = 100,
    holdEffect = "type_boost", boostType = "FIGHTING",
  },
  POISON_BARB = {
    id = "POISON_BARB", name = "POISON BARB", price = 100,
    holdEffect = "type_boost", boostType = "POISON",
  },
  SOFT_SAND = {
    id = "SOFT_SAND", name = "SOFT SAND", price = 100,
    holdEffect = "type_boost", boostType = "GROUND",
  },
  SHARP_BEAK = {
    id = "SHARP_BEAK", name = "SHARP BEAK", price = 100,
    holdEffect = "type_boost", boostType = "FLYING",
  },
  TWISTEDSPOON = {
    id = "TWISTEDSPOON", name = "TWISTEDSPOON", price = 100,
    holdEffect = "type_boost", boostType = "PSYCHIC_TYPE",
  },
  SILVERPOWDER = {
    id = "SILVERPOWDER", name = "SILVERPOWDER", price = 100,
    holdEffect = "type_boost", boostType = "BUG",
  },
  HARD_STONE = {
    id = "HARD_STONE", name = "HARD STONE", price = 100,
    holdEffect = "type_boost", boostType = "ROCK",
  },
  SPELL_TAG = {
    id = "SPELL_TAG", name = "SPELL TAG", price = 100,
    holdEffect = "type_boost", boostType = "GHOST",
  },
  DRAGON_FANG = {
    id = "DRAGON_FANG", name = "DRAGON FANG", price = 100,
    holdEffect = "type_boost", boostType = "DRAGON",
  },
  BLACKGLASSES = {
    id = "BLACKGLASSES", name = "BLACKGLASSES", price = 100,
    holdEffect = "type_boost", boostType = "DARK",
  },
  METAL_COAT = {
    id = "METAL_COAT", name = "METAL COAT", price = 100,
    holdEffect = "type_boost", boostType = "STEEL",
  },
  PINK_BOW = {
    id = "PINK_BOW", name = "PINK BOW", price = 100,
    holdEffect = "type_boost", boostType = "NORMAL",
  },
}

HeldItems.BERRY_PACK = {
  "BERRY", "CHERI_BERRY", "CHESTO_BERRY", "PECHA_BERRY", "RAWST_BERRY",
  "ASPEAR_BERRY", "PERSIM_BERRY", "LUM_BERRY",
}

HeldItems.ALL_MART_CLERKS = {
  { "ViridianMart", "TEXT_VIRIDIANMART_CLERK" },
  { "PewterMart", "TEXT_PEWTERMART_CLERK" },
  { "CeruleanMart", "TEXT_CERULEANMART_CLERK" },
  { "VermilionMart", "TEXT_VERMILIONMART_CLERK" },
  { "LavenderMart", "TEXT_LAVENDERMART_CLERK" },
  { "FuchsiaMart", "TEXT_FUCHSIAMART_CLERK" },
  { "SaffronMart", "TEXT_SAFFRONMART_CLERK" },
  { "CinnabarMart", "TEXT_CINNABARMART_CLERK" },
  { "IndigoPlateauLobby", "TEXT_INDIGOPLATEAULOBBY_CLERK" },
  { "CeladonMart2F", "TEXT_CELADONMART2F_CLERK1" },
}

function HeldItems.isHoldable(itemId)
  return HeldItems.CATALOG[itemId] ~= nil
end

function HeldItems.isBerry(itemId)
  local def = HeldItems.CATALOG[itemId]
  return def and (def.holdEffect == "berry" or def.holdEffect == "berry_status")
end

function HeldItems.def(itemId)
  return HeldItems.CATALOG[itemId]
end

function HeldItems.get(mon)
  return mon and mon.heldItem or nil
end

function HeldItems.set(mon, itemId)
  if not mon then return end
  mon.heldItem = itemId
end

-- Remove the hold and remember it for Recycle (on the battler when given).
function HeldItems.consume(mon, battler)
  if not mon or not mon.heldItem then return nil end
  local id = mon.heldItem
  mon.heldItem = nil
  if battler then
    battler.expLastConsumedItem = id
  end
  return id
end

function HeldItems.ofBattler(battler)
  return battler and battler.mon and battler.mon.heldItem or nil
end

function HeldItems.typeBoostIds()
  local ids = {}
  for id, rec in pairs(HeldItems.CATALOG) do
    if rec.holdEffect == "type_boost" then
      ids[#ids + 1] = id
    end
  end
  table.sort(ids)
  return ids
end

function HeldItems.register(mod)
  for id, rec in pairs(HeldItems.CATALOG) do
    mod.content.items:register(id, {
      id = rec.id,
      name = rec.name,
      price = rec.price,
      tossable = true,
    })
  end

  mod.content.link_fields:register("held_item", {
    rev = 1,
    pack = function(mon) return mon.heldItem end,
    unpack = function(mon, v) mon.heldItem = v end,
  })
end

function HeldItems.registerMarts(mod)
  -- Berries are farm/loot/wild only (not sold). Type boosters stay in marts.
  local starters = { "MIRACLE_SEED", "CHARCOAL", "MYSTIC_WATER" }
  for _, row in ipairs({
    { "ViridianMart", "TEXT_VIRIDIANMART_CLERK" },
    { "PewterMart", "TEXT_PEWTERMART_CLERK" },
  }) do
    mod.content.text_pointers:patch(row[1], {
      [row[2]] = { mart = starters },
    })
  end

  -- Celadon 5F X-clerk: type boosters only (Leftovers / Focus Band are
  -- one-time overworld finds — see overworld_loot.lua).
  local celadonShelf = HeldItems.typeBoostIds()
  mod.content.text_pointers:patch("CeladonMart5F", {
    TEXT_CELADONMART5F_CLERK1 = { mart = celadonShelf },
  })
end

-- Wild berries only from unlocked plant types (berry economy).
function HeldItems.unlockedBerryList(mod)
  if not mod or not mod.save then return { "BERRY" } end
  local unlocked = mod.save:get("unlocked_berries", nil)
  if type(unlocked) ~= "table" then return { "BERRY" } end
  local list = {}
  for _, id in ipairs(HeldItems.BERRY_PACK) do
    if unlocked[id] then list[#list + 1] = id end
  end
  if #list == 0 then list[1] = "BERRY" end
  return list
end

local function displayName(b)
  return b.isPlayer and b.name or ("Enemy " .. b.name)
end

local function bagHoldables(save)
  local rows = {}
  local inv = save.inventory or {}
  local ids = {}
  for id in pairs(HeldItems.CATALOG) do
    if (inv[id] or 0) > 0 then ids[#ids + 1] = id end
  end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local def = HeldItems.CATALOG[id]
    rows[#rows + 1] = {
      value = id,
      label = def.name,
      right = "x" .. tostring(inv[id]),
    }
  end
  return rows
end

local MAJOR_STATUS = { PAR = true, PSN = true, BRN = true, FRZ = true, SLP = true }

local function berryMatchesCure(def, kind)
  if not def or def.holdEffect ~= "berry_status" then return false end
  if def.cure == "any" then
    return kind == "confusion" or MAJOR_STATUS[kind]
  end
  return def.cure == kind
end

local function monDisplayName(data, mon)
  return mon.nickname or (data.pokemon[mon.species] and data.pokemon[mon.species].name)
    or mon.species or "?????"
end

local function cureActiveToxic(battle, mon)
  if not battle then return end
  for _, b in ipairs({ battle.player, battle.enemy }) do
    if b and b.mon == mon then b.toxicCounter = nil end
  end
end

local function activeBattlerFor(battle, mon)
  if not battle or not mon then return nil end
  for _, b in ipairs({ battle.player, battle.enemy }) do
    if b and b.mon == mon then return b end
  end
  return nil
end

-- Bag / pause-menu USE (party mon as target). Returns nil if itemId is not a
-- bag-usable berry so ItemEffects can fall through.
-- Mirrors vanilla medicine: "consumed" / "failed" + message list (+ healedFrom).
function HeldItems.tryBagUse(data, save, itemId, target, battle)
  local def = HeldItems.def(itemId)
  if not def then return nil end
  if def.holdEffect ~= "berry" and def.holdEffect ~= "berry_status" then
    return nil
  end

  local noEffect = function()
    return "failed", { Strings("It won't have\nany effect.") }
  end

  if not target then return noEffect() end

  if def.holdEffect == "berry" then
    local heal = def.heal or 10
    if target.hp <= 0 or target.hp >= target.stats.hp then
      return noEffect()
    end
    require("src.world.PikachuFollower")
      .modifyHappiness(save, "USEDITEM", target)
    local before = target.hp
    target.hp = math.min(target.stats.hp, target.hp + heal)
    require("src.core.Sound").play(data, "Heal_HP")
    return "consumed",
      { Strings("%s's HP\nwas restored!", monDisplayName(data, target)) },
      { healedFrom = before }
  end

  -- berry_status
  local battler = activeBattlerFor(battle, target)
  local curedStatus, curedConfusion = false, false

  if def.cure == "confusion" then
    if not battler or not battler.confusedTurns then return noEffect() end
    battler.confusedTurns = nil
    curedConfusion = true
  elseif def.cure == "any" then
    if target.status and MAJOR_STATUS[target.status] then
      target.status = nil
      cureActiveToxic(battle, target)
      curedStatus = true
    end
    if battler and battler.confusedTurns then
      battler.confusedTurns = nil
      curedConfusion = true
    end
    if not curedStatus and not curedConfusion then return noEffect() end
  else
    -- Specific major status (PAR / PSN / …)
    if not target.status or target.status ~= def.cure then return noEffect() end
    target.status = nil
    cureActiveToxic(battle, target)
    curedStatus = true
  end

  require("src.world.PikachuFollower")
    .modifyHappiness(save, "USEDITEM", target)
  require("src.core.Sound").play(data, "Heal_Ailment")
  if curedConfusion and not curedStatus then
    return "consumed", {
      Strings("%s's\nstatus returned\nto normal!", monDisplayName(data, target)),
    }
  end
  return "consumed", {
    Strings("%s's\nstatus returned\nto normal!", monDisplayName(data, target)),
  }
end

local function clearMajorStatus(target)
  local st = target.mon.status
  if not st then return false end
  target.mon.status = nil
  if st == "SLP" then target.sleepTurns = nil end
  if st == "PSN" then target.toxicCounter = nil end
  return true
end

-- Status / confusion berry: cure when the matching affliction is present.
-- Lum (cure = "any") clears major status and confusion in one consume.
function HeldItems.tryStatusBerry(battle, target, kind)
  if not target or not target.mon then return false end
  local id = target.mon.heldItem
  local def = id and HeldItems.def(id)
  if not berryMatchesCure(def, kind) then return false end

  local clearedStatus, clearedConfusion = false, false
  if def.cure == "any" then
    -- Trigger must match an affliction that is actually present.
    if kind == "confusion" then
      if not target.confusedTurns then return false end
    elseif target.mon.status ~= kind then
      return false
    end
    clearedStatus = clearMajorStatus(target)
    if target.confusedTurns then
      target.confusedTurns = nil
      clearedConfusion = true
    end
    if not clearedStatus and not clearedConfusion then return false end
  elseif kind == "confusion" then
    if not target.confusedTurns then return false end
    target.confusedTurns = nil
    clearedConfusion = true
  else
    if target.mon.status ~= kind then return false end
    clearedStatus = clearMajorStatus(target)
  end

  HeldItems.consume(target.mon, target)
  if battle and battle.sayNext then
    if clearedConfusion and not clearedStatus then
      battle:sayNext(Strings("%s's %s\nsnapped it out of\vconfusion!",
        displayName(target), def.name))
    else
      battle:sayNext(Strings("%s's %s\ncured its status!",
        displayName(target), def.name))
    end
  end
  return true
end

-- If a battler already has a status/confusion that its held berry cures
-- (Trick / Bestow / switch-in), fire it now.
function HeldItems.tickStatusBerry(battle, target)
  if not target or not target.mon then return false end
  if target.mon.status then
    if HeldItems.tryStatusBerry(battle, target, target.mon.status) then
      return true
    end
  end
  if target.confusedTurns then
    return HeldItems.tryStatusBerry(battle, target, "confusion")
  end
  return false
end

function HeldItems.pickWildBerry(rng)
  rng = rng or love.math.random
  local pack = HeldItems.unlockedBerryList(HeldItems._mod)
  local roll
  if type(rng) == "function" then
    -- love.math.random style: rng(lo, hi) or rng() in [0,1)
    local ok, a = pcall(rng, 1, #pack)
    if ok and type(a) == "number" then
      roll = a
    else
      local r = rng()
      roll = 1 + math.floor((type(r) == "number" and r or 0) * #pack)
    end
  else
    roll = 1
  end
  if roll < 1 then roll = 1 end
  if roll > #pack then roll = #pack end
  return pack[roll]
end

function HeldItems.maybeGiveWildHold(mon, rng)
  if not mon then return end
  rng = rng or love.math.random
  local roll
  if type(rng) == "function" then
    local ok, a = pcall(rng)
    if ok and type(a) == "number" and a < 1 then
      roll = a
    else
      local ok2, b = pcall(rng, 0, 99)
      roll = (ok2 and b or 0) / 100
    end
  else
    roll = 1
  end
  if roll >= HeldItems.WILD_BERRY_CHANCE then return end
  mon.heldItem = HeldItems.pickWildBerry(rng)
end

function HeldItems.install(mod)
  HeldItems._mod = mod
  local Bag = require("src.inventory.Bag")
  local ListMenu = require("src.ui.ListMenu")
  local TextBox = require("src.render.TextBox")

  -- Party GIVE / TAKE (field menu only — not mid-battle switch submenu)
  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(out) ~= "table" then return out end
    if ctx and ctx.battle then return out end

    if mon.heldItem then
      out[#out + 1] = {
        label = Strings("TAKE"),
        onSelect = function(m, g)
          local id = m.heldItem
          if not id then return end
          if not Bag.add(g.save, id, 1) then
            g.stack:push(TextBox.new(g, Strings("The bag is full!")))
            return
          end
          m.heldItem = nil
          local def = HeldItems.def(id)
          g.stack:push(TextBox.new(g, Strings("Took the\n%s.", def and def.name or id)))
        end,
      }
    end

    out[#out + 1] = {
      label = Strings("GIVE"),
      onSelect = function(m, g)
        local rows = bagHoldables(g.save)
        if #rows == 0 then
          g.stack:push(TextBox.new(g, Strings("No items to give!")))
          return
        end
        g.stack:push(ListMenu.new(g, Strings("Give which?"), rows, {
          onChoose = function(row, list)
            list:close()
            local id = row.value
            if not HeldItems.isHoldable(id) then return end
            if (g.save.inventory[id] or 0) <= 0 then return end
            if m.heldItem then
              if not Bag.add(g.save, m.heldItem, 1) then
                g.stack:push(TextBox.new(g, Strings("The bag is full!")))
                return
              end
            end
            Bag.remove(g.save, id, 1)
            m.heldItem = id
            local def = HeldItems.def(id)
            g.stack:push(TextBox.new(g, Strings("%s was given\nthe %s.",
              m.nickname or (g.data.pokemon[m.species] and g.data.pokemon[m.species].name)
                or m.species,
              def and def.name or id)))
          end,
        }))
      end,
    }
    return out
  end)

  -- Leftovers residual + status berries that were given mid-status
  mod.events:on("battle.turn_ended", function(ev)
    if not ev.battle then return end
    local function tick(b)
      if not b or not b.mon or b.mon.hp <= 0 then return end
      HeldItems.tickStatusBerry(ev.battle, b)
      local id = b.mon.heldItem
      local def = id and HeldItems.def(id)
      if not def or def.holdEffect ~= "leftovers" then return end
      if b.mon.hp >= b.mon.stats.hp then return end
      local heal = math.max(1, math.floor(b.mon.stats.hp / 16))
      b.mon.hp = math.min(b.mon.stats.hp, b.mon.hp + heal)
      if ev.battle.sayNext then
        ev.battle:sayNext(Strings("%s restored a little\nHP using its LEFTOVERS!",
          displayName(b)))
      end
      if ev.battle.drainNext then ev.battle:drainNext() end
    end
    tick(ev.battle.player)
    tick(ev.battle.enemy)
  end)

  -- HP Berry is hooked from applyDamage below (covers moves, confusion
  -- self-hits, recoil, trap ticks — not only EffectRegistry's damage_dealt).

  -- Status berries: only on status_inflicted (single fire)
  mod.events:on("battle.status_inflicted", function(ev)
    if not ev.battle or not ev.target or not ev.status then return end
    HeldItems.tryStatusBerry(ev.battle, ev.target, ev.status)
  end)

  -- Persim: only when confusion was newly applied (not on a failed re-confuse).
  local MoveEffects = require("src.battle.MoveEffects")
  local function afterConfuse(battle, target)
    HeldItems.tryStatusBerry(battle, target, "confusion")
  end

  local origConfusePrimary = MoveEffects.primary.CONFUSION_EFFECT
  MoveEffects.primary.CONFUSION_EFFECT = function(battle, user, target)
    local before = target and target.confusedTurns
    local msgs = origConfusePrimary(battle, user, target)
    if target and target.confusedTurns and not before then
      afterConfuse(battle, target)
    end
    return msgs
  end

  local origConfuseSide = MoveEffects.secondary.CONFUSION_SIDE_EFFECT
  MoveEffects.secondary.CONFUSION_SIDE_EFFECT = function(battle, user, target, ...)
    local before = target and target.confusedTurns
    local msgs = origConfuseSide(battle, user, target, ...)
    if target and target.confusedTurns and not before then
      afterConfuse(battle, target)
    end
    return msgs
  end

  local thrashRec = MoveEffects.full and MoveEffects.full.THRASH_PETAL_DANCE_EFFECT
  if thrashRec and thrashRec.afterDamage then
    local origAfter = thrashRec.afterDamage
    thrashRec.afterDamage = function(ctx)
      local had = ctx.user and ctx.user.confusedTurns
      origAfter(ctx)
      if ctx.user and ctx.user.confusedTurns and not had then
        afterConfuse(ctx.battle, ctx.user)
      end
    end
  end

  -- Focus Band + HP Berry (pinch heal).  Berry runs only when mon.hp
  -- actually dropped so Substitute hits do not eat a held Berry.
  local BattleState = require("src.battle.BattleState")
  local original_applyDamage = BattleState.applyDamage
  BattleState.applyDamage = function(self, target, dmg)
    dmg = HeldItems.focusBandClamp(self, target, dmg)
    local before = target and target.mon and target.mon.hp or 0
    local dealt = original_applyDamage(self, target, dmg)
    if dealt and dealt > 0 and target and target.mon and target.mon.hp < before then
      HeldItems.afterDamage({
        battle = self,
        target = target,
      }, dealt)
    end
    return dealt
  end

  -- Damage drains pin stopAt so multi-hit bars step correctly.  HP Berry
  -- heals the model immediately (before the queue runs), which made
  -- stopAt < mon.hp and skipped the damage dip — the following heal drain
  -- then looked like a no-op.  Honor stopAt while shownHP is still above it.
  if not BattleState._expansionBerryDrainFloor then
    BattleState.stepHPDrain = function(self)
      local busy = false
      for _, b in ipairs({ self.player, self.enemy }) do
        if b and b.shownHP then
          local goal = b.mon.hp
          if b.drainFloor ~= nil then
            if b.shownHP > b.drainFloor then
              -- Still draining down to this hit's pin (berry may already
              -- have raised mon.hp above the floor).
              goal = b.drainFloor
            elseif b.drainFloor > goal and b.shownHP >= b.drainFloor then
              -- Multi-hit: later hits already lowered mon.hp below this floor.
              goal = b.drainFloor
            end
          end
          if b.shownHP ~= goal then
            local step = math.max(1, b.mon.stats.hp) / 96
            if b.shownHP > goal then
              b.shownHP = math.max(goal, b.shownHP - step)
            else
              b.shownHP = math.min(goal, b.shownHP + step)
            end
            busy = busy or b.shownHP ~= goal
          end
        end
      end
      return busy
    end
    BattleState._expansionBerryDrainFloor = true
  end

  -- Wild berry holds
  local original_newWild = BattleState.newWild
  BattleState.newWild = function(game, species, level, opts)
    local battle = original_newWild(game, species, level, opts)
    if battle and battle.enemy and battle.enemy.mon then
      local rng = (battle.rng and function(...)
        return battle.rng(...)
      end) or love.math.random
      HeldItems.maybeGiveWildHold(battle.enemy.mon, rng)
    end
    return battle
  end

  -- Bag / pause-menu USE: berries act like later-gen medicine (party target).
  local ItemEffects = require("src.inventory.ItemEffects")
  if not ItemEffects._expansionBerryBag then
    local originalNeedsTarget = ItemEffects.needsTarget
    ItemEffects.needsTarget = function(id, itemDef)
      if HeldItems.isBerry(id) then return true end
      return originalNeedsTarget(id, itemDef)
    end

    local originalHealsHP = ItemEffects.healsHP
    ItemEffects.healsHP = function(id)
      if originalHealsHP(id) then return true end
      local def = HeldItems.def(id)
      return def ~= nil and def.holdEffect == "berry"
    end

    local originalUse = ItemEffects.use
    ItemEffects.use = function(data, save, itemId, target, battle, ...)
      local result, msgs, extra = HeldItems.tryBagUse(data, save, itemId, target, battle)
      if result then return result, msgs, extra end
      return originalUse(data, save, itemId, target, battle, ...)
    end
    ItemEffects._expansionBerryBag = true
  end
end

-- Damage pipeline helpers (called from main.lua battle.damage wrap)
function HeldItems.modifyDamage(damage, ctx)
  if not damage or damage <= 0 then return damage end
  local user = ctx.user
  local move = ctx.move
  local id = HeldItems.ofBattler(user)
  local def = id and HeldItems.def(id)
  if def and def.holdEffect == "type_boost" and move and move.type == def.boostType then
    damage = math.max(1, math.floor(damage * 11 / 10))
  end
  return damage
end

function HeldItems.afterDamage(ctx, damage)
  local target = ctx.target
  if not target or not target.mon or not damage or damage <= 0 then return end
  local id = target.mon.heldItem
  local def = id and HeldItems.def(id)
  if not def then return end

  if def.holdEffect == "berry"
      and target.mon.hp > 0
      and target.mon.hp * 2 <= target.mon.stats.hp then
    local heal = def.heal or 10
    target.mon.hp = math.min(target.mon.stats.hp, target.mon.hp + heal)
    HeldItems.consume(target.mon, target)
    if ctx.battle and ctx.battle.sayNext then
      ctx.battle:sayNext(Strings("%s's %s\nrestored health!",
        displayName(target), def.name))
    end
    if ctx.battle and ctx.battle.drainNext then
      ctx.battle:drainNext(target)
    end  end
end

function HeldItems.focusBandClamp(battle, target, dmg)
  if not target or not target.mon or not dmg or dmg <= 0 then return dmg end
  if target.substituteHP then return dmg end
  local id = target.mon.heldItem
  local def = id and HeldItems.def(id)
  if not def or def.holdEffect ~= "focus_band" then return dmg end
  if dmg < target.mon.hp then return dmg end
  local rng = battle.rng or love.math.random
  if rng(0, 99) < 10 then
    dmg = target.mon.hp - 1
    if battle.sayNext then
      battle:sayNext(Strings("%s hung on\nusing its FOCUS BAND!", displayName(target)))
    end
  end
  return dmg
end

return HeldItems
