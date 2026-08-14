-- Gen 2–3 held items for Kanto Reforged (engine stays Gen1-faithful).
-- Storage: mon.heldItem (string id). Give/Take via ui.party.submenu;
-- optional Give from the bag (BAG GIVE option).

local Strings = require("src.core.Strings")

local HeldItems = {}

HeldItems.WILD_BERRY_CHANCE = 0.05

HeldItems.BAG_GIVE_KEY = "bag_give"
HeldItems.BAG_GIVE_OPTION = {
  key = HeldItems.BAG_GIVE_KEY,
  label = "BAG GIVE",
  type = "toggle",
  default = true,
}

function HeldItems.bagGiveEnabled(mod)
  mod = mod or HeldItems._mod
  if not mod or not mod.options then return true end
  return mod.options:get(HeldItems.BAG_GIVE_KEY) and true or false
end

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
  if not mon then return nil end
  return mon.heldItem or mon.item
end

function HeldItems.set(mon, itemId)
  if not mon then return end
  mon.heldItem = itemId
  mon.item = itemId
end

-- Remove the hold and remember it for Recycle (on the battler when given).
function HeldItems.consume(mon, battler)
  if not mon then return nil end
  local id = mon.heldItem or mon.item
  if not id then return nil end
  mon.heldItem = nil
  mon.item = nil
  if battler then
    battler.expLastConsumedItem = id
  end
  return id
end

function HeldItems.ofBattler(battler)
  if not battler then return nil end
  if (battler.expEmbargoTurns or 0) > 0 then return nil end
  local mon = battler.mon or battler
  if mon and (mon.expEmbargoTurns or 0) > 0 then return nil end
  return HeldItems.get(mon)
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
  -- Gold already ships type boosters / leftovers / etc.; only fill gaps.
  -- On Gen2, farm berries need heldEffect so Battle:tickHeldItem can fire.
  local Host = require("mods.Kanto-Reforged.core.host")
  local GEN2_STATUS_HELD = {
    PAR = "HELD_HEAL_PARALYZE",
    SLP = "HELD_HEAL_SLEEP",
    PSN = "HELD_HEAL_POISON",
    BRN = "HELD_HEAL_BURN",
    FRZ = "HELD_HEAL_FREEZE",
    confusion = "HELD_HEAL_CONFUSION",
    any = "HELD_HEAL_STATUS",
  }
  local function gen2HeldFields(rec)
    if rec.holdEffect == "leftovers" then
      return "HELD_LEFTOVERS", 10
    elseif rec.holdEffect == "focus_band" then
      return "HELD_FOCUS_BAND", 30
    elseif rec.holdEffect == "berry" then
      return "HELD_BERRY", rec.heal or 10
    elseif rec.holdEffect == "berry_status" then
      return GEN2_STATUS_HELD[rec.cure], 0
    elseif rec.holdEffect == "type_boost" and rec.boostType then
      local t = rec.boostType == "PSYCHIC_TYPE" and "PSYCHIC" or rec.boostType
      return "HELD_" .. t .. "_BOOST", 10
    end
    return nil, nil
  end

  for id, rec in pairs(HeldItems.CATALOG) do
    local payload = {
      id = rec.id,
      name = rec.name,
      price = rec.price,
      tossable = true,
    }
    if Host.isGen2() then
      local he, hp = gen2HeldFields(rec)
      if he then
        payload.heldEffect = he
        payload.heldParameter = hp
      end
    end
    if not mod.content.items:get(id) then
      mod.content.items:register(id, payload)
    elseif Host.isGen2() and payload.heldEffect then
      local existing = mod.content.items:get(id)
      if existing and not existing.heldEffect then
        mod.content.items:patch(id, {
          heldEffect = payload.heldEffect,
          heldParameter = payload.heldParameter,
        })
      end
    end
  end

  if Host.isGen1() then
    mod.content.link_fields:register("held_item", {
      rev = 1,
      pack = function(mon) return mon.heldItem end,
      unpack = function(mon, v) mon.heldItem = v end,
    })
  end
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
  local Host = require("mods.Kanto-Reforged.core.host")
  local unlocked = Host.saveGet(mod.save, "unlocked_berries", nil)
  if type(unlocked) ~= "table" then return { "BERRY" } end
  local list = {}
  for _, id in ipairs(HeldItems.BERRY_PACK) do
    if unlocked[id] then list[#list + 1] = id end
  end
  if #list == 0 then list[1] = "BERRY" end
  return list
end

local function displayName(b)
  if not b then return "POKéMON" end
  local n = b.name
  if (not n or n == "") and b.mon then
    n = b.mon.nickname or b.mon.species
  end
  n = n or b.species or "POKéMON"
  if b.isPlayer then return n end
  return "Enemy " .. tostring(n)
end

-- Gen3 Pecha/Cheri/… match both engine ids (PSN) and ability strings (poison).
local STATUS_ALIAS = {
  PSN = "PSN", poison = "PSN", toxic = "PSN", TOX = "PSN",
  PAR = "PAR", paralyze = "PAR", paralysis = "PAR",
  BRN = "BRN", burn = "BRN",
  FRZ = "FRZ", freeze = "FRZ",
  SLP = "SLP", sleep = "SLP",
  confusion = "confusion",
}

local function canonStatus(kind)
  return STATUS_ALIAS[kind] or kind
end

local function announceLines(battle, lines)
  if not battle or not lines then return end
  for _, line in ipairs(lines) do
    if type(line) == "string" and line ~= "" then
      if battle.sayNext then
        battle:sayNext(line)
      elseif battle.say then
        battle:say(line)
      elseif battle.emit then
        battle:emit({ kind = "message", text = line })
      end
    end
  end
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

local function monDisplayName(data, mon)
  return mon.nickname or (data.pokemon[mon.species] and data.pokemon[mon.species].name)
    or mon.species or "?????"
end

-- Move one holdable from the bag onto a party mon. Swaps the previous
-- hold back into the bag when present. Returns ok, err, previousId.
-- Removes the bag item first so a full bag can still swap when that
-- remove frees a slot for the returned hold.
function HeldItems.giveToMon(game, mon, itemId)
  local Bag = require("src.inventory.Bag")
  if not game or not mon or not itemId then return false, "bad" end
  if not HeldItems.isHoldable(itemId) then return false, "bad" end
  if (game.save.inventory[itemId] or 0) <= 0 then return false, "empty" end

  local previous = HeldItems.get(mon)
  if previous == itemId then
    return true, nil, previous
  end

  Bag.remove(game.save, itemId, 1)
  if previous then
    if not Bag.add(game.save, previous, 1) then
      Bag.add(game.save, itemId, 1) -- rollback
      return false, "full", previous
    end
  end
  HeldItems.set(mon, itemId)
  return true, nil, previous
end

local function rebuildBagListItems(game, list)
  if not list then return end
  local Bag = require("src.inventory.Bag")
  local items = {}
  for _, id in ipairs(Bag.order(game.save)) do
    local def = game.data.items[id]
    items[#items + 1] = {
      value = id,
      label = def and def.name or id,
      right = "x" .. tostring(game.save.inventory[id]),
    }
  end
  list.items = items
  list.index = math.min(list.index or 1, math.max(1, #items))
  if list.scroll and list.rows and list.index - list.scroll > list.rows then
    list.scroll = list.index - list.rows
  end
  if list.scroll and list.index - list.scroll < 1 then
    list.scroll = math.max(0, list.index - 1)
  end
end

local function giveMessage(data, mon, itemId, previous)
  local name = monDisplayName(data, mon)
  local def = HeldItems.def(itemId)
  local given = def and def.name or itemId
  if previous and previous ~= itemId then
    local prevDef = HeldItems.def(previous)
    local prevName = prevDef and prevDef.name or previous
    return Strings("%s was given\nthe %s.\fThe %s was\nput in the BAG.",
      name, given, prevName)
  end
  return Strings("%s was given\nthe %s.", name, given)
end

function HeldItems.pickMonAndGive(game, itemId, bagList)
  local TextBox = require("src.render.TextBox")
  local Breeding = require("mods.Kanto-Reforged.pokemon.breeding")
  local Host = require("mods.Kanto-Reforged.core.host")
  local Screens = require("src.ui.Screens")

  local function onPick(mon)
    if Breeding.isEgg(mon) then
      game.stack:push(TextBox.new(game, Strings("An EGG can't hold\nan item!")))
      return
    end
    local ok, err, previous = HeldItems.giveToMon(game, mon, itemId)
    if err == "full" then
      game.stack:push(TextBox.new(game, Strings("The bag is full!")))
      return
    end
    if not ok then return end
    rebuildBagListItems(game, bagList)
    game.stack:push(TextBox.new(game, giveMessage(game.data, mon, itemId, previous)))
  end

  Screens.push(game, Host.isGen2() and "Gen2PartyMenu" or "PartyMenu", Host.isGen2() and {
      prompt = "useItem",
      onChoose = function(_index, mon)
        game.stack:pop()
        onPick(mon)
      end,
    } or {
      pickOnly = true,
      onSwitch = onPick,
    })
end

-- Inject GIVE into the bag's USE/TOSS submenu for holdable items when the
-- BAG GIVE option is on (field only — no give mid-battle).
function HeldItems.decorateBagMenu(mod, game, list, opts)
  if not list or type(list.onChoose) ~= "function" then return end
  local battle = opts and opts.battle
  local origOnChoose = list.onChoose
  list.onChoose = function(item)
    local id = item and item.value
    local wantGive = not battle
        and not list.swapIndex
        and id
        and HeldItems.isHoldable(id)
        and HeldItems.bagGiveEnabled(mod)
    if not wantGive then
      return origOnChoose(item)
    end

    local Menu = require("src.ui.Menu")
    local origMenuNew = Menu.new
    Menu.new = function(g, items, menuOpts)
      Menu.new = origMenuNew
      local giveEntry = {
        label = Strings("GIVE"),
        onSelect = function()
          HeldItems.pickMonAndGive(g, id, list)
        end,
      }
      local merged = {}
      if type(items) == "table" and #items >= 2 then
        merged[1] = items[1]
        merged[2] = giveEntry
        for i = 2, #items do
          merged[#merged + 1] = items[i]
        end
      else
        merged[1] = giveEntry
        for _, it in ipairs(items or {}) do
          merged[#merged + 1] = it
        end
      end
      local mo = {}
      if type(menuOpts) == "table" then
        for k, v in pairs(menuOpts) do mo[k] = v end
      end
      -- Grow for the extra row; nudge up so the box stays on-screen.
      mo.th = #merged * (mo.rowStep or 2) + 1
      if mo.ty and mo.ty + mo.th > 18 then
        mo.ty = math.max(0, 18 - mo.th)
      end
      return origMenuNew(g, merged, mo)
    end

    local ok, err = pcall(origOnChoose, item)
    Menu.new = origMenuNew
    if not ok then error(err) end
  end
end

local MAJOR_STATUS = { PAR = true, PSN = true, BRN = true, FRZ = true, SLP = true }

local function berryMatchesCure(def, kind)
  if not def or def.holdEffect ~= "berry_status" then return false end
  kind = canonStatus(kind)
  if def.cure == "any" then
    return kind == "confusion" or MAJOR_STATUS[kind]
  end
  return def.cure == kind
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
    do
      local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
      Gen1Patch.apply(require("src.world.PikachuFollower"), function(follower)
        if type(follower.modifyHappiness) == "function" then
          follower.modifyHappiness(save, "USEDITEM", target)
        end
      end)
    end
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

    do
      local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
      Gen1Patch.apply(require("src.world.PikachuFollower"), function(follower)
        if type(follower.modifyHappiness) == "function" then
          follower.modifyHappiness(save, "USEDITEM", target)
        end
      end)
    end
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
--
-- Gen 3: eat as soon as the status lands (not on the residual poison/burn
-- tick). `opts.collect` returns dialog so the caller can print it AFTER
-- "was poisoned!" — eating inside status_inflicted queued the line in a
-- pcall'd event and a nil-name concat could swallow the page entirely.
function HeldItems.tryStatusBerry(battle, target, kind, opts)
  opts = opts or {}
  if not target or not target.mon then return false end
  local id = target.mon.heldItem
  local def = id and HeldItems.def(id)
  kind = canonStatus(kind)
  local stored = canonStatus(target.mon.status)
  if not berryMatchesCure(def, kind) then return false end

  local clearedStatus, clearedConfusion = false, false
  if def.cure == "any" then
    if kind == "confusion" then
      if not target.confusedTurns then return false end
    elseif stored ~= kind then
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
    if stored ~= kind then return false end
    clearedStatus = clearMajorStatus(target)
  end

  local lines = {
    Strings("%s ate its\n%s!", displayName(target), def.name),
  }
  HeldItems.consume(target.mon, target)
  if opts.collect then
    return true, lines
  end
  announceLines(battle, lines)
  return true, lines
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

-- After StatusRegistry.inflict returns the "was poisoned!" page, append
-- the berry eat line so dialog cannot vanish inside a pcall'd event.
function HeldItems.installStatusBerryOnInflict()
  local StatusRegistry = require("src.battle.StatusRegistry")
  if StatusRegistry._krStatusBerry then return end
  local origInflict = StatusRegistry.inflict
  StatusRegistry.inflict = function(battle, target, status, opts)
    local msgs = origInflict(battle, target, status, opts)
    if type(msgs) == "table" and #msgs > 0 and target then
      local ok, lines = HeldItems.tryStatusBerry(battle, target, status,
        { collect = true })
      if ok and type(lines) == "table" then
        for _, line in ipairs(lines) do
          msgs[#msgs + 1] = line
        end
      end
    end
    return msgs
  end
  StatusRegistry._krStatusBerry = true
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
  HeldItems.set(mon, HeldItems.pickWildBerry(rng))
end

function HeldItems.install(mod)
  HeldItems._mod = mod
  local Host = require("mods.Kanto-Reforged.core.host")
  local Bag = require("src.inventory.Bag")
  local ListMenu = require("src.ui.ListMenu")
  local TextBox = require("src.render.TextBox")

  -- Party GIVE / TAKE (field menu only — not mid-battle switch submenu)
  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(out) ~= "table" then return out end
    if ctx and ctx.battle then return out end

    if HeldItems.get(mon) then
      out[#out + 1] = {
        label = Strings("TAKE"),
        onSelect = function(m, g)
          local id = HeldItems.get(m)
          if not id then return end
          if not Bag.add(g.save, id, 1) then
            g.stack:push(TextBox.new(g, Strings("The bag is full!")))
            return
          end
          HeldItems.set(m, nil)
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
            local ok, err, previous = HeldItems.giveToMon(g, m, id)
            if err == "full" then
              g.stack:push(TextBox.new(g, Strings("The bag is full!")))
              return
            end
            if not ok then return end
            g.stack:push(TextBox.new(g, giveMessage(g.data, m, id, previous)))
          end,
        }))
      end,
    }
    return out
  end)

  if Host.isGen2() then
    -- Gold Battle already ticks Leftovers / HELD_BERRY / status cures via
    -- mon.item + heldEffect. Wire bag USE + wild holds only.
    local ItemEffects = require("src.core.gen2.ItemEffects")
    if not ItemEffects._krBerryBag then
      local originalPartyAction = ItemEffects.partyAction
      ItemEffects.partyAction = function(itemId, data)
        if HeldItems.isBerry(itemId) then
          local def = HeldItems.def(itemId)
          if def and def.holdEffect == "berry" then return "heal" end
          return "status"
        end
        return originalPartyAction(itemId, data)
      end

      local originalUseOnMon = ItemEffects.useOnMon
      ItemEffects.useOnMon = function(itemId, mon, data)
        if HeldItems.isBerry(itemId) then
          local result, msgs = HeldItems.tryBagUse(data, nil, itemId, mon, nil)
          if result == "consumed" then
            return { used = true, text = msgs and msgs[1] }
          end
          if result == "failed" then
            return {
              used = false,
              text = (msgs and msgs[1]) or ItemEffects.TEXT_NO_EFFECT,
            }
          end
        end
        return originalUseOnMon(itemId, mon, data)
      end
      ItemEffects._krBerryBag = true
    end

    mod.events:on("battle.started", function(ev)
      if not ev or ev.kind ~= "wild" or not ev.battle then return end
      local mon = ev.battle.enemy
      if not mon or HeldItems.get(mon) then return end
      local rng = (ev.battle.random and function(n)
        -- Gen2 Battle.random is 0..n-1; maybeGiveWildHold wants [0,1) or 0..99.
        if n then return (ev.battle.random(n + 1) or 0) end
        return (ev.battle.random(100) or 0) / 100
      end) or love.math.random
      HeldItems.maybeGiveWildHold(mon, rng)
    end)
    return
  end

  -- ---- Gen1 battle / bag hooks below ----

  -- Leftovers residual only. Status berries are Gen 3: eat on inflict /
  -- switch-in / item gift, not on the poison/burn HP tick.
  mod.events:on("battle.turn_ended", function(ev)
    if not ev.battle then return end
    local function tick(b)
      if not b or not b.mon or b.mon.hp <= 0 then return end
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

  HeldItems.installStatusBerryOnInflict()

  -- Switch-in / already statused: eat immediately (Gen 3 send-out).
  mod.events:on("battle.battler_switched", function(ev)
    if ev and ev.battle and ev.battler then
      HeldItems.tickStatusBerry(ev.battle, ev.battler)
    end
  end)

  -- Persim: only when confusion was newly applied (not on a failed re-confuse).
  local MoveEffects = require("src.battle.MoveEffects")
  local function appendStatusBerry(battle, target, kind, msgs)
    local ok, lines = HeldItems.tryStatusBerry(battle, target, kind, { collect = true })
    if not ok then return msgs end
    if type(msgs) == "table" and type(lines) == "table" then
      for _, line in ipairs(lines) do
        msgs[#msgs + 1] = line
      end
      return msgs
    end
    announceLines(battle, lines)
    return msgs
  end

  local origConfusePrimary = MoveEffects.primary.CONFUSION_EFFECT
  MoveEffects.primary.CONFUSION_EFFECT = function(battle, user, target)
    local before = target and target.confusedTurns
    local msgs = origConfusePrimary(battle, user, target)
    if target and target.confusedTurns and not before then
      msgs = appendStatusBerry(battle, target, "confusion", msgs)
    end
    return msgs
  end

  local origConfuseSide = MoveEffects.secondary.CONFUSION_SIDE_EFFECT
  MoveEffects.secondary.CONFUSION_SIDE_EFFECT = function(battle, user, target, ...)
    local before = target and target.confusedTurns
    local msgs = origConfuseSide(battle, user, target, ...)
    if target and target.confusedTurns and not before then
      msgs = appendStatusBerry(battle, target, "confusion", msgs)
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
        HeldItems.tryStatusBerry(ctx.battle, ctx.user, "confusion")
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
  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
  Gen1Patch.apply(BattleState, function(bs)
    local original_newWild = bs.newWild
    if type(original_newWild) ~= "function" then return end
    bs.newWild = function(game, species, level, opts)
      local battle = original_newWild(game, species, level, opts)
      if battle and battle.enemy and battle.enemy.mon then
        local rng = (battle.rng and function(...)
          return battle.rng(...)
        end) or love.math.random
        HeldItems.maybeGiveWildHold(battle.enemy.mon, rng)
      end
      return battle
    end
  end)

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
