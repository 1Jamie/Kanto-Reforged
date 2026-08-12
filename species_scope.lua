-- Host-aware species-scope (Gen1 KANTO/NATIONAL, Gen2 JOHTO 251/FULL).
-- Stash/restore out-of-scope mons on Gen1; filter spawns/trainers; link fingerprint.

local Host = require("mods.Kanto-Reforged.host")
local Merge = require("src.mods.Merge")
local Strings = require("src.core.Strings")

local SpeciesScope = {}

SpeciesScope.OPTION_KEY = "species_scope"
SpeciesScope.MODE_NATIONAL = "national"
SpeciesScope.MODE_KANTO = "kanto"
SpeciesScope.MODE_JOHTO_NATIVE = "johto_native"

SpeciesScope.STASH_KEY = "species_scope_stash"
SpeciesScope.APPLIED_KEY = "species_scope_applied"

SpeciesScope.KANTO_MAX_DEX = 151
SpeciesScope.JOHTO_MAX_DEX = 251

local FOSSIL_FOR_SPECIES = {
  LILEEP = "ROOT_FOSSIL",
  ANORITH = "CLAW_FOSSIL",
}

local JOHTO_TRAINER_CLASSES = {
  FALKNER = true, BUGSY = true, WHITNEY = true, MORTY = true,
  CHUCK = true, JASMINE = true, PRYCE = true, CLAIR = true,
  WILL = true, KOGA = true, BRUNO = true, KAREN = true, LANCE = true,
}

-- Optional refresh callback set by main.lua: refresh(mod, game, mode)
SpeciesScope._refreshContent = nil
SpeciesScope._mod = nil
SpeciesScope._ignoreOptionEvent = false
SpeciesScope._evoBaselines = nil

local function breedingIsEgg(mon)
  local ok, Breeding = pcall(require, "mods.Kanto-Reforged.breeding")
  if ok and Breeding and Breeding.isEgg then
    return Breeding.isEgg(mon)
  end
  return mon and (mon.isEgg or mon.egg) and true or false
end

function SpeciesScope.optionDef()
  local key = Host.optionKey(SpeciesScope.OPTION_KEY)
  if Host.isGen2() then
    return {
      key = key,
      label = "JOHTO SCOPE",
      type = "choice",
      default = SpeciesScope.MODE_NATIONAL,
      choices = {
        { "JOHTO 251", SpeciesScope.MODE_JOHTO_NATIVE },
        { "FULL", SpeciesScope.MODE_NATIONAL },
      },
    }
  end
  return {
    key = key,
    label = "DEX SCOPE",
    type = "choice",
    default = SpeciesScope.MODE_NATIONAL,
    choices = {
      { "KANTO", SpeciesScope.MODE_KANTO },
      { "NATIONAL", SpeciesScope.MODE_NATIONAL },
    },
  }
end

function SpeciesScope.mode(mod)
  local v = mod and mod.options
    and mod.options:get(Host.optionKey(SpeciesScope.OPTION_KEY))
  if Host.isGen2() then
    if v == SpeciesScope.MODE_JOHTO_NATIVE then
      return SpeciesScope.MODE_JOHTO_NATIVE
    end
    return SpeciesScope.MODE_NATIONAL
  end
  if v == SpeciesScope.MODE_KANTO then
    return SpeciesScope.MODE_KANTO
  end
  return SpeciesScope.MODE_NATIONAL
end

function SpeciesScope.applied(mod)
  return mod.save:get(SpeciesScope.APPLIED_KEY, nil)
end

function SpeciesScope.isKantoMap(mapId)
  local EncountersGen2 = require("mods.Kanto-Reforged.encounters_gen2")
  if EncountersGen2._isKantoMap then
    return EncountersGen2._isKantoMap(mapId)
  end
  return false
end

function SpeciesScope.dexOf(gameOrData, speciesId)
  if not speciesId then return nil end
  local data = gameOrData
  if data and data.data then data = data.data end
  local def = data and data.pokemon and data.pokemon[speciesId]
  if def and def.dex then return def.dex end
  local ok, pokemon_data = pcall(require, "mods.Kanto-Reforged.pokemon_data")
  if ok and pokemon_data and pokemon_data.species and pokemon_data.species[speciesId] then
    return pokemon_data.species[speciesId].dex
  end
  return nil
end

function SpeciesScope.maxDexForMap(mod, mapId)
  local mode = SpeciesScope.mode(mod)
  if Host.isGen1() then
    if mode == SpeciesScope.MODE_KANTO then
      return SpeciesScope.KANTO_MAX_DEX
    end
    return nil -- unlimited / national
  end
  -- Gen2
  if mode == SpeciesScope.MODE_JOHTO_NATIVE then
    if mapId and SpeciesScope.isKantoMap(mapId) then
      return nil -- Kanto maps keep Gen3
    end
    return SpeciesScope.JOHTO_MAX_DEX
  end
  return nil
end

function SpeciesScope.allowsDex(mod, dex, mapId)
  if dex == nil then return true end
  local maxDex = SpeciesScope.maxDexForMap(mod, mapId)
  if not maxDex then return true end
  return dex <= maxDex
end

function SpeciesScope.allowsSpeciesId(mod, speciesId, mapId)
  if not speciesId then return true end
  local dex = SpeciesScope.dexOf(SpeciesScope._game or nil, speciesId)
  if dex == nil and SpeciesScope._mod then
    local content = SpeciesScope._mod.content and SpeciesScope._mod.content.pokemon
    local def = content and content:get(speciesId)
    dex = def and def.dex
  end
  if dex == nil then
    -- Unknown species: Gen1 kanto refuses post-boot guests conservatively only
    -- when we can resolve dex. Allow if unresolved (vanilla ids without dex).
    return true
  end
  return SpeciesScope.allowsDex(mod, dex, mapId)
end

function SpeciesScope.isOutOfScopeMon(mod, mon, game)
  if not mon then return false end
  -- Eggs: gate on species id when present (hatch target)
  if mon.species then
    if Host.isGen1() and SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO then
      local dex = SpeciesScope.dexOf(game or SpeciesScope._game, mon.species)
      if dex == nil then
        local def = game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
        dex = def and def.dex
      end
      return (dex or 0) > SpeciesScope.KANTO_MAX_DEX
    end
  end
  return false
end

-- Gen2: should this trainer class skip Gen3 guests under johto_native?
function SpeciesScope.skipJohtoTrainerGuest(mod, classId)
  if Host.isGen1() then return false end
  if SpeciesScope.mode(mod) ~= SpeciesScope.MODE_JOHTO_NATIVE then
    return false
  end
  return JOHTO_TRAINER_CLASSES[classId] == true
end

function SpeciesScope.allowsTrainerGuest(mod, classId, speciesId)
  if Host.isGen1() then
    return SpeciesScope.allowsSpeciesId(mod, speciesId, nil)
  end
  if SpeciesScope.skipJohtoTrainerGuest(mod, classId) then
    local dex = SpeciesScope.dexOf(SpeciesScope._game, speciesId)
    if dex and dex > SpeciesScope.JOHTO_MAX_DEX then
      return false
    end
  end
  return true
end

--------------------------------------------------------------------------
-- Notices / option writeback
--------------------------------------------------------------------------

local function notify(game, msg)
  if not msg or msg == "" then return end
  if game and game.stack then
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if ok and TextBox and TextBox.new then
      pcall(function()
        game.stack:push(TextBox.new(game, msg))
      end)
      return
    end
  end
  if SpeciesScope._mod and SpeciesScope._mod.log then
    SpeciesScope._mod.log:info("%s", tostring(msg):gsub("\n", " "))
  end
end

function SpeciesScope.setOptionValue(mod, value)
  local key = Host.optionKey(SpeciesScope.OPTION_KEY)
  local loader = Host.modLoader(mod)
  local game = SpeciesScope._game or rawget(_G, "Game")
  if game and game.mods then
    loader = game.mods
  end
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
    loader.modOptions[mod.id][key] = value
  end
  if game and game.save and game.save.options then
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions[mod.id] =
      game.save.options.modOptions[mod.id] or {}
    game.save.options.modOptions[mod.id][key] = value
  end
end

function SpeciesScope.isOverworldIdle(game)
  if not game then return true end
  if game.battle then return false end
  return true
end

-- True only when a scope flip is allowed. Battle is always blocked.
-- Field menus (party/bag/etc.) block; Manager / overworld are allowed.
function SpeciesScope.canChangeScope(game)
  if not game then
    return true
  end
  if game.battle then
    return false, Strings("Can't change DEX SCOPE\nduring battle.")
  end
  local stack = game.stack
  if not stack then
    return true
  end

  local function eachScreen(fn)
    if type(stack.each) == "function" then
      stack:each(fn)
      return
    end
    local items = stack.items or stack._items
    if type(items) == "table" then
      for _, screen in ipairs(items) do fn(screen) end
      return
    end
    for i = 1, 32 do
      local screen = stack[i]
      if screen == nil then break end
      fn(screen)
    end
  end

  local blocked = false
  eachScreen(function(screen)
    if blocked or not screen then return end
    if screen.isBattle or screen.enemyParty then
      blocked = true
      return
    end
    local name = tostring(screen.__name or screen.name or screen.screenId or "")
    if name:find("Battle", 1, true) then
      blocked = true
      return
    end
    -- Allow overworld + mod manager / options chrome.
    if screen.ow or screen.map or screen.isOverworld then return end
    if screen.screenId == "ManagerState" or screen.isManager then return end
    if name:find("Manager", 1, true) or name:find("Option", 1, true) then
      return
    end
    -- Anything else on the stack (party, bag, PC, textbox mid-script…) locks.
    blocked = true
  end)

  if blocked then
    return false, Strings("Can't change DEX SCOPE\nwhile a menu is open.")
  end
  return true
end

function SpeciesScope.lockReason(game)
  local ok, reason = SpeciesScope.canChangeScope(game)
  if ok then return nil end
  return reason
end

--------------------------------------------------------------------------
-- Bag dry-run helpers
--------------------------------------------------------------------------

local function heldItemId(mon)
  if not mon then return nil end
  return mon.heldItem or mon.item
end

local function clearHeldItem(mon)
  if not mon then return end
  mon.heldItem = nil
  mon.item = nil
end

-- Simulate adding ids (qty 1 each) into a copy of inventory occupancy.
-- Returns neededNewSlots, canFit.
local function countBagSlotsNeeded(save, data, itemIds)
  local Bag = require("src.inventory.Bag")
  -- Track simulated qty per id and free slots per pocket
  local inv = {}
  for id, qty in pairs(save.inventory or {}) do
    inv[id] = qty
  end
  local freeByPocket = {}
  local function freeOf(pocket)
    if freeByPocket[pocket] == nil then
      local cap = Bag.capacity(data, pocket)
      local used = 0
      for id in pairs(inv) do
        if not Bag.isBadge(id) and Bag.pocketOf(id, data) == pocket then
          used = used + 1
        end
      end
      freeByPocket[pocket] = math.max(0, cap - used)
    end
    return freeByPocket[pocket]
  end
  local neededNew = 0
  for _, id in ipairs(itemIds) do
    if id then
      local pocket = Bag.pocketOf(id, data)
      if inv[id] then
        if inv[id] + 1 > 99 then
          return neededNew + 1, false
        end
        inv[id] = inv[id] + 1
      else
        if freeOf(pocket) < 1 then
          neededNew = neededNew + 1
          return neededNew, false
        end
        freeByPocket[pocket] = freeOf(pocket) - 1
        inv[id] = 1
        neededNew = neededNew + 1
      end
    end
  end
  return neededNew, true
end

local function freePcSlots(save)
  local Boxes = require("src.pokemon.Boxes")
  local boxes = Boxes.ensure(save)
  local free = 0
  for i = 1, Boxes.COUNT do
    free = free + (Boxes.CAPACITY - #(boxes[i] or {}))
  end
  return free
end

local function depositToPc(save, mon)
  local Boxes = require("src.pokemon.Boxes")
  return Boxes.deposit(save, mon)
end

local function rewindToDeposit(game, mon, depositLevel)
  if not mon or breedingIsEgg(mon) then return mon end
  local Growth = require("src.pokemon.Growth")
  local Stats = require("src.pokemon.Stats")
  local level = depositLevel or mon.level or 1
  mon.level = level
  local def = game.data.pokemon[mon.species]
  if def then
    mon.exp = Growth.expForLevel(def.growthRate, level)
    mon.stats = Stats.calc(def, mon.level, mon.dvs, mon.statExp)
    mon.hp = mon.stats and mon.stats.hp or mon.hp
  end
  return mon
end

--------------------------------------------------------------------------
-- Stash schema
--------------------------------------------------------------------------

local function getStash(mod)
  local s = mod.save:get(SpeciesScope.STASH_KEY, nil)
  if type(s) ~= "table" then
    s = { version = 1, mode = "kanto", entries = {} }
  end
  s.entries = s.entries or {}
  return s
end

local function setStash(mod, stash)
  if not stash then
    mod.save:set(SpeciesScope.STASH_KEY, nil)
    return
  end
  local hasEntries = stash.entries and #stash.entries > 0
  local dex = stash.dex
  local hasDex = type(dex) == "table" and (
    (dex.seen and next(dex.seen) ~= nil)
    or (dex.owned and next(dex.owned) ~= nil))
  if not hasEntries and not hasDex then
    mod.save:set(SpeciesScope.STASH_KEY, nil)
  else
    mod.save:set(SpeciesScope.STASH_KEY, stash)
  end
end

-- Remember Johto/Hoenn seen/owned flags while KANTO hides them from the
-- list. SaveData.validate can also drop flags for species briefly missing
-- from data.pokemon — the snapshot is the source of truth on restore.
local function snapshotOutOfScopeDex(mod, game, stash)
  local save = game and game.save
  local dex = save and save.pokedex
  if type(dex) ~= "table" then return end
  stash.dex = stash.dex or { seen = {}, owned = {} }
  for _, key in ipairs({ "seen", "owned" }) do
    stash.dex[key] = stash.dex[key] or {}
    local bucket = dex[key]
    if type(bucket) == "table" then
      for id, on in pairs(bucket) do
        if on then
          local d = SpeciesScope.dexOf(game, id)
          if d and d > SpeciesScope.KANTO_MAX_DEX then
            stash.dex[key][id] = true
          end
        end
      end
    end
  end
end

local function restoreStashedDex(game, stash)
  local save = game and game.save
  if not save then return 0 end
  save.pokedex = save.pokedex or { seen = {}, owned = {} }
  local dex = save.pokedex
  dex.seen = dex.seen or {}
  dex.owned = dex.owned or {}
  local n = 0
  local snap = stash and stash.dex
  if type(snap) ~= "table" then return 0 end
  for _, key in ipairs({ "seen", "owned" }) do
    for id, on in pairs(snap[key] or {}) do
      if on and not dex[key][id] then
        dex[key][id] = true
        n = n + 1
      elseif on then
        dex[key][id] = true
      end
    end
  end
  return n
end

local function markDexForMon(save, mon)
  if not save or not mon or not mon.species then return end
  if breedingIsEgg(mon) then return end
  save.pokedex = save.pokedex or { seen = {}, owned = {} }
  save.pokedex.seen = save.pokedex.seen or {}
  save.pokedex.owned = save.pokedex.owned or {}
  save.pokedex.seen[mon.species] = true
  save.pokedex.owned[mon.species] = true
end

-- Any mon you still have must stay registered after a scope flip.
local function resyncDexFromCollection(mod, game, stash)
  local save = game and game.save
  if not save then return end
  for _, mon in ipairs(save.party or {}) do
    markDexForMon(save, mon)
  end
  local Boxes = require("src.pokemon.Boxes")
  local boxes = Boxes.ensure(save)
  for bi = 1, Boxes.COUNT do
    for _, mon in ipairs(boxes[bi] or {}) do
      markDexForMon(save, mon)
    end
  end
  local dc = save.daycare
  if type(dc) == "table" then
    markDexForMon(save, dc.mon)
    markDexForMon(save, dc.mon2)
    markDexForMon(save, dc.egg)
  end
  for _, entry in ipairs((stash and stash.entries) or {}) do
    markDexForMon(save, entry.mon)
  end
end

--------------------------------------------------------------------------
-- Fossil async revert
--------------------------------------------------------------------------

local function pendingFossilItem(mod, save)
  local flags = save.flags or {}
  if not (flags.MOD_LAB_GEN3_REVIVING or flags.MOD_LAB_GEN3_HANDING) then
    local species = mod.save:get("lab_gen3_species", nil)
    if not species then return nil end
  end
  local species = mod.save:get("lab_gen3_species", nil)
  if species and FOSSIL_FOR_SPECIES[species] then
    return FOSSIL_FOR_SPECIES[species], species
  end
  -- Fallback if species key missing but flags set
  if flags.MOD_LAB_GEN3_REVIVING or flags.MOD_LAB_GEN3_HANDING then
    return "CLAW_FOSSIL", nil
  end
  return nil
end

local function clearFossilJob(mod, save)
  save.flags = save.flags or {}
  save.flags.MOD_LAB_GEN3_REVIVING = nil
  save.flags.MOD_LAB_GEN3_HANDING = nil
  mod.save:set("lab_gen3_species", nil)
end

--------------------------------------------------------------------------
-- Daycare evacuate + stash dry-run / apply
--------------------------------------------------------------------------

local function collectOutOfScopeFromPartyBoxes(game, mod)
  local list = {}
  local save = game.save
  for i, mon in ipairs(save.party or {}) do
    if mon and SpeciesScope.isOutOfScopeMon(mod, mon, game) then
      list[#list + 1] = { mon = mon, from = "party", slot = i }
    end
  end
  local Boxes = require("src.pokemon.Boxes")
  local boxes = Boxes.ensure(save)
  for bi = 1, Boxes.COUNT do
    local box = boxes[bi] or {}
    for si, mon in ipairs(box) do
      if mon and SpeciesScope.isOutOfScopeMon(mod, mon, game) then
        list[#list + 1] = {
          mon = mon, from = "box", boxIndex = bi, slot = si,
        }
      end
    end
  end
  return list
end

local function dryRunEnterKanto(mod, game)
  local save = game.save
  local data = game.data
  local itemsToBag = {}
  local notices = {}

  -- Fossil return
  local fossilItem = pendingFossilItem(mod, save)
  if fossilItem then
    itemsToBag[#itemsToBag + 1] = fossilItem
  end

  -- Daycare: count PC needs for in-scope, stash for out-of-scope, held items
  local dc = save.daycare
  local pcNeeded = 0
  local function considerDaycareMon(mon, depositLevel, from)
    if not mon then return end
    local copy = Merge.deepCopy(mon)
    rewindToDeposit(game, copy, depositLevel)
    local item = heldItemId(copy)
    if item and not breedingIsEgg(copy) then
      itemsToBag[#itemsToBag + 1] = item
    end
    if SpeciesScope.isOutOfScopeMon(mod, copy, game) then
      -- stash — no PC
    else
      pcNeeded = pcNeeded + 1
    end
  end
  if type(dc) == "table" then
    considerDaycareMon(dc.mon, dc.depositLevel, "daycare")
    considerDaycareMon(dc.mon2, dc.depositLevel2, "daycare-mon2")
    if dc.egg then
      considerDaycareMon(dc.egg, nil, "daycare-egg")
    end
  end

  local partyBox = collectOutOfScopeFromPartyBoxes(game, mod)
  for _, row in ipairs(partyBox) do
    local item = heldItemId(row.mon)
    if item and not breedingIsEgg(row.mon) then
      itemsToBag[#itemsToBag + 1] = item
    end
  end

  local _, bagOk = countBagSlotsNeeded(save, data, itemsToBag)
  if not bagOk then
    local need = #itemsToBag
    -- Recount precise new-slot shortfall for message
    local neededNew = select(1, countBagSlotsNeeded(save, data, itemsToBag))
    if neededNew < 1 then neededNew = need end
    return false, "bag_full", Strings(
      "Can't switch to KANTO.\nBag full — free space\nfor %d held items.",
      neededNew)
  end

  if pcNeeded > freePcSlots(save) then
    return false, "pc_full", Strings(
      "Can't switch to KANTO.\nPC is full — free a\nbox slot first.")
  end

  -- Empty party check: surviving in-scope party + in-scope PC + daycare→PC
  local inScopeParty = 0
  for _, mon in ipairs(save.party or {}) do
    if mon and not SpeciesScope.isOutOfScopeMon(mod, mon, game) then
      inScopeParty = inScopeParty + 1
    end
  end
  local inScopePc = 0
  local Boxes = require("src.pokemon.Boxes")
  local boxes = Boxes.ensure(save)
  for bi = 1, Boxes.COUNT do
    for _, mon in ipairs(boxes[bi] or {}) do
      if mon and not SpeciesScope.isOutOfScopeMon(mod, mon, game) then
        inScopePc = inScopePc + 1
      end
    end
  end
  -- daycare in-scope become PC
  local daycareInScope = pcNeeded
  if inScopeParty == 0 and (inScopePc + daycareInScope) == 0 then
    return false, "empty_party", Strings(
      "Can't switch to KANTO.\nKeep at least one\nKanto Pokémon in\nyour party or PC.")
  end

  return true, nil, nil, {
    itemsToBag = itemsToBag,
    fossilItem = fossilItem,
    partyBox = partyBox,
    notices = notices,
  }
end

local function applyEnterKanto(mod, game, plan)
  local save = game.save
  local Bag = require("src.inventory.Bag")
  local stash = getStash(mod)
  stash.mode = "kanto"
  -- Capture National dex progress for post-151 before anything else can
  -- drop those flags (validate, list rebuild, etc.).
  snapshotOutOfScopeDex(mod, game, stash)
  local fossilReturned = false

  -- Fossil revert
  if plan.fossilItem then
    Bag.add(save, plan.fossilItem, 1, game.data)
    clearFossilJob(mod, save)
    fossilReturned = true
  end

  -- Daycare evacuate first
  local dc = save.daycare
  if type(dc) == "table" then
    local function evacuate(mon, depositLevel, from)
      if not mon then return end
      local copy = Merge.deepCopy(mon)
      rewindToDeposit(game, copy, depositLevel)
      local item = heldItemId(copy)
      if item and not breedingIsEgg(copy) then
        Bag.add(save, item, 1, game.data)
        clearHeldItem(copy)
      end
      if SpeciesScope.isOutOfScopeMon(mod, copy, game) then
        stash.entries[#stash.entries + 1] = {
          mon = copy, from = from,
        }
      else
        depositToPc(save, copy)
      end
    end
    evacuate(dc.mon, dc.depositLevel, "daycare")
    evacuate(dc.mon2, dc.depositLevel2, "daycare-mon2")
    if dc.egg then
      evacuate(dc.egg, nil, "daycare-egg")
    end
    save.daycare = {}
  end

  -- Party / box stash (iterate boxes high→low so indices stay valid)
  local Boxes = require("src.pokemon.Boxes")
  local boxes = Boxes.ensure(save)
  for bi = Boxes.COUNT, 1, -1 do
    local box = boxes[bi] or {}
    for si = #box, 1, -1 do
      local mon = box[si]
      if mon and SpeciesScope.isOutOfScopeMon(mod, mon, game) then
        local copy = Merge.deepCopy(mon)
        local item = heldItemId(copy)
        if item and not breedingIsEgg(copy) then
          Bag.add(save, item, 1, game.data)
          clearHeldItem(copy)
        end
        stash.entries[#stash.entries + 1] = {
          mon = copy, from = "box", boxIndex = bi, slot = si,
        }
        table.remove(box, si)
      end
    end
  end

  for i = #(save.party or {}), 1, -1 do
    local mon = save.party[i]
    if mon and SpeciesScope.isOutOfScopeMon(mod, mon, game) then
      local copy = Merge.deepCopy(mon)
      local item = heldItemId(copy)
      if item and not breedingIsEgg(copy) then
        Bag.add(save, item, 1, game.data)
        clearHeldItem(copy)
      end
      stash.entries[#stash.entries + 1] = {
        mon = copy, from = "party", slot = i,
      }
      table.remove(save.party, i)
    end
  end

  -- Ensure party non-empty
  if #(save.party or {}) == 0 then
    boxes = Boxes.ensure(save)
    local moved = false
    for bi = 1, Boxes.COUNT do
      local box = boxes[bi]
      for si, mon in ipairs(box or {}) do
        if mon and not SpeciesScope.isOutOfScopeMon(mod, mon, game) then
          table.insert(save.party, mon)
          table.remove(box, si)
          moved = true
          break
        end
      end
      if moved then break end
    end
  end

  setStash(mod, stash)
  return fossilReturned
end

local function applyRestoreNational(mod, game)
  local stash = getStash(mod)
  local remaining = {}
  local restored = 0
  local scattered = 0
  local stillStored = 0
  local Boxes = require("src.pokemon.Boxes")
  local Party = require("src.pokemon.Party")

  for _, entry in ipairs(stash.entries or {}) do
    local mon = Merge.deepCopy(entry.mon)
    local placed = false
    local wasScatter = false
    local placedBox, placedSlot = nil, nil

    if entry.from == "box" and entry.boxIndex then
      local boxes = Boxes.ensure(game.save)
      local box = boxes[entry.boxIndex]
      if box and #box < Boxes.CAPACITY then
        local want = entry.slot
        if type(want) == "number" and want >= 1 and want <= #box + 1 then
          table.insert(box, want, mon)
          placedSlot = want
        else
          table.insert(box, mon)
          placedSlot = #box
          wasScatter = true
        end
        placedBox = entry.boxIndex
        placed = true
        if placedSlot ~= entry.slot then
          wasScatter = true
        end
      end
    end

    if not placed and entry.from == "party" then
      if #(game.save.party or {}) < (Party.MAX or 6) then
        if Party.add then
          placed = Party.add(game.save.party, mon) and true or false
        else
          table.insert(game.save.party, mon)
          placed = true
        end
      end
    end

    if not placed then
      if #(game.save.party or {}) < (Party.MAX or 6) then
        if Party.add then
          placed = Party.add(game.save.party, mon) and true or false
        else
          table.insert(game.save.party, mon)
          placed = true
        end
        if placed and entry.from == "box" then wasScatter = true end
      end
    end

    if not placed then
      local boxes = Boxes.ensure(game.save)
      local bi = depositToPc(game.save, mon)
      if bi then
        placed = true
        placedBox = bi
        placedSlot = #(boxes[bi] or {})
        if entry.from == "box" then
          if entry.boxIndex ~= bi or entry.slot ~= placedSlot then
            wasScatter = true
          end
        end
      end
    end

    if placed then
      restored = restored + 1
      if wasScatter then scattered = scattered + 1 end
    else
      remaining[#remaining + 1] = entry
      stillStored = stillStored + 1
    end
  end

  stash.entries = remaining
  -- Put Johto/Hoenn dex flags back, then ensure every mon you still hold
  -- (party / PC / leftover stash) is marked owned again.
  restoreStashedDex(game, stash)
  resyncDexFromCollection(mod, game, stash)
  if stash.dex then stash.dex = nil end
  setStash(mod, stash)

  local msg
  if stillStored > 0 then
    msg = Strings(
      "Restored %d Pokémon.\n%d still in storage\n(PC full).",
      restored, stillStored)
  elseif scattered > 0 then
    msg = Strings(
      "Some Pokémon could not\nreturn to their old\nBOX slots — check the PC.")
  end
  return restored, scattered, stillStored, msg
end

--------------------------------------------------------------------------
-- Dex size + evo strip
--------------------------------------------------------------------------

function SpeciesScope.captureEvoBaselines(mod, force)
  if SpeciesScope._evoBaselines and not force then return end
  SpeciesScope._evoBaselines = {}
  local ok, pokemon_data = pcall(require, "mods.Kanto-Reforged.pokemon_data")
  if not ok or not pokemon_data or not pokemon_data.evolutions then return end
  for speciesId in pairs(pokemon_data.evolutions) do
    local existing = mod.content.pokemon:get(speciesId)
    if existing and existing.evolutions then
      SpeciesScope._evoBaselines[speciesId] = Merge.deepCopy(existing.evolutions)
    end
  end
end

local function writeConstant(mod, key, value)
  -- Content is frozen after boot; patch usually fails. Always write the live
  -- Data.constants table so mid-session KANTO↔NATIONAL flips update dexSize.
  pcall(function()
    mod.content.constants:patch(key, value)
  end)
  local data = (SpeciesScope._game and SpeciesScope._game.data)
    or require("src.core.Data")
  if data and data.constants then
    data.constants[key] = value
  end
end

local function writePokemonField(mod, speciesId, fields)
  local ok = pcall(function()
    mod.content.pokemon:patch(speciesId, fields)
  end)
  if ok then return end
  local data = (SpeciesScope._game and SpeciesScope._game.data)
    or require("src.core.Data")
  local def = data and data.pokemon and data.pokemon[speciesId]
  if not def then return end
  for k, v in pairs(fields) do
    def[k] = v
  end
end

function SpeciesScope.applyEvoScope(mod, mode)
  if Host.isGen2() then return end
  SpeciesScope.captureEvoBaselines(mod)
  if not SpeciesScope._evoBaselines then return end
  if mode == SpeciesScope.MODE_KANTO then
    for speciesId, evos in pairs(SpeciesScope._evoBaselines) do
      local filtered = {}
      for _, evo in ipairs(evos) do
        local target = evo.species or evo.into
        if SpeciesScope.allowsSpeciesId(mod, target, nil) then
          filtered[#filtered + 1] = Merge.deepCopy(evo)
        end
      end
      writePokemonField(mod, speciesId, { evolutions = filtered })
    end
  else
    for speciesId, evos in pairs(SpeciesScope._evoBaselines) do
      writePokemonField(mod, speciesId, { evolutions = Merge.deepCopy(evos) })
    end
  end
end

function SpeciesScope.applyDexSize(mod, mode)
  if Host.isGen2() then return end
  if mode == SpeciesScope.MODE_KANTO then
    writeConstant(mod, "dexSize", SpeciesScope.KANTO_MAX_DEX)
    writeConstant(mod, "dexDigits", 3)
  else
    local highest = SpeciesScope.KANTO_MAX_DEX
    local pokemon_data = require("mods.Kanto-Reforged.pokemon_data")
    for _, record in pairs(pokemon_data.species or {}) do
      if record.dex and record.dex > highest then highest = record.dex end
    end
    writeConstant(mod, "dexSize", highest)
    writeConstant(mod, "dexDigits", math.max(3, #tostring(highest)))
  end
end

-- Clamp owned count for display helpers / tests
function SpeciesScope.countOwnedInScope(game, mod)
  local dex = game.save.pokedex or { owned = {} }
  local owned = dex.owned or {}
  local maxDex = SpeciesScope.KANTO_MAX_DEX
  if not (Host.isGen1() and SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO) then
    maxDex = (game.data.constants and game.data.constants.dexSize) or maxDex
  end
  local n = 0
  for id, on in pairs(owned) do
    if on then
      local d = SpeciesScope.dexOf(game, id)
      if d and d <= maxDex then n = n + 1 end
    end
  end
  return n, maxDex
end

function SpeciesScope.countSeenInScope(game, mod)
  local dex = game.save.pokedex or { seen = {} }
  local seen = dex.seen or {}
  local maxDex = SpeciesScope.KANTO_MAX_DEX
  if not (Host.isGen1() and SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO) then
    maxDex = (game.data.constants and game.data.constants.dexSize) or maxDex
  end
  local n = 0
  for id, on in pairs(seen) do
    if on then
      local d = SpeciesScope.dexOf(game, id)
      if d and d <= maxDex then n = n + 1 end
    end
  end
  return n, maxDex
end

-- Owned count for quest gates (wing hunter, etc.): always in-scope under kanto.
function SpeciesScope.ownedCountForGates(game, mod)
  mod = mod or SpeciesScope._mod
  if game and mod then
    return select(1, SpeciesScope.countOwnedInScope(game, mod))
  end
  local owned = (game and game.save and game.save.pokedex and game.save.pokedex.owned) or {}
  local n = 0
  for _ in pairs(owned) do n = n + 1 end
  return n
end

function SpeciesScope.invalidateCurrentMap(game)
  if not game then return end
  local mapId = game.mapId
    or (game.overworld and game.overworld.map and game.overworld.map.id)
    or (game.world and game.world.mapId)
  local world = game.world or (game.mods and game.mods.world)
  if game.ow and game.ow.map and game.ow.map.id then
    mapId = mapId or game.ow.map.id
  end
  -- WorldAPI lives on mod.world when provided by loader
  local api = SpeciesScope._mod and SpeciesScope._mod.world
  if api and api.invalidateMap and mapId then
    pcall(function() api:invalidateMap(mapId) end)
    return
  end
  if game.mods and game.mods.world and game.mods.world.invalidateMap and mapId then
    pcall(function() game.mods.world:invalidateMap(mapId) end)
  end
end

--------------------------------------------------------------------------
-- Content refresh + transition
--------------------------------------------------------------------------

function SpeciesScope.refresh(mod, game, mode)
  mode = mode or SpeciesScope.mode(mod)
  SpeciesScope.applyDexSize(mod, mode)
  -- Evo strip only after baselines were captured post-patch (see main.lua).
  if SpeciesScope._evoBaselines then
    SpeciesScope.applyEvoScope(mod, mode)
  end
  if SpeciesScope._refreshContent then
    SpeciesScope._refreshContent(mod, game, mode)
  end
  if game then
    SpeciesScope.invalidateCurrentMap(game)
  end
end

--- Apply transition to toMode. Returns ok, errCode, errMessage.
function SpeciesScope.applyTransition(mod, game, toMode)
  toMode = toMode or SpeciesScope.mode(mod)
  local fromMode = SpeciesScope.applied(mod) or SpeciesScope.MODE_NATIONAL
  if fromMode == toMode then
    SpeciesScope.refresh(mod, game, toMode)
    return true
  end

  if game then
    local allowed, reason = SpeciesScope.canChangeScope(game)
    if not allowed then
      return false, "busy", reason or Strings("Can't change DEX SCOPE.")
    end
  end

  if Host.isGen1() then
    if toMode == SpeciesScope.MODE_KANTO then
      local ok, err, msg, plan = dryRunEnterKanto(mod, game)
      if not ok then
        return false, err, msg
      end
      local fossilReturned = applyEnterKanto(mod, game, plan)
      SpeciesScope.refresh(mod, game, toMode)
      mod.save:set(SpeciesScope.APPLIED_KEY, toMode)
      if fossilReturned then
        notify(game, Strings(
          "Your fossil was returned.\nRevival is paused in\nKANTO scope."))
      end
      return true
    elseif toMode == SpeciesScope.MODE_NATIONAL then
      local _, _, _, msg = applyRestoreNational(mod, game)
      SpeciesScope.refresh(mod, game, toMode)
      mod.save:set(SpeciesScope.APPLIED_KEY, toMode)
      if msg then notify(game, msg) end
      return true, nil, msg
    end
  else
    -- Gen2: no stash
    SpeciesScope.refresh(mod, game, toMode)
    mod.save:set(SpeciesScope.APPLIED_KEY, toMode)
    return true
  end

  SpeciesScope.refresh(mod, game, toMode)
  mod.save:set(SpeciesScope.APPLIED_KEY, toMode)
  return true
end

function SpeciesScope.ensureBoot(mod, game)
  SpeciesScope._game = game
  local mode = SpeciesScope.mode(mod)
  local applied = SpeciesScope.applied(mod)
  if Host.isGen1() and mode == SpeciesScope.MODE_KANTO then
    -- Reconcile live out-of-scope mons
    if applied ~= SpeciesScope.MODE_KANTO then
      local ok, err, msg = SpeciesScope.applyTransition(mod, game, mode)
      if not ok then
        SpeciesScope._ignoreOptionEvent = true
        SpeciesScope.setOptionValue(mod, SpeciesScope.MODE_NATIONAL)
        SpeciesScope._ignoreOptionEvent = false
        notify(game, msg)
        SpeciesScope.refresh(mod, game, SpeciesScope.MODE_NATIONAL)
        mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
        return false, err, msg
      end
      return true
    end
  elseif Host.isGen1() and mode == SpeciesScope.MODE_NATIONAL
      and applied == SpeciesScope.MODE_KANTO then
    -- Option says national but applied kanto — restore
    SpeciesScope.applyTransition(mod, game, mode)
    return true
  end
  SpeciesScope.refresh(mod, game, mode)
  mod.save:set(SpeciesScope.APPLIED_KEY, mode)
  return true
end

function SpeciesScope.onOptionsChanged(mod, game, ev)
  if SpeciesScope._ignoreOptionEvent then return end
  if not ev or ev.mod ~= mod.id
      or not Host.optionEventIs(ev.key, SpeciesScope.OPTION_KEY) then
    return
  end
  SpeciesScope._game = game or SpeciesScope._game or rawget(_G, "Game")
  game = SpeciesScope._game

  local toMode = SpeciesScope.mode(mod)
  local prev = SpeciesScope.applied(mod) or SpeciesScope.MODE_NATIONAL

  -- Defense in depth: setOption should already have blocked unsafe flips.
  local allowed, reason = SpeciesScope.canChangeScope(game)
  if not allowed then
    SpeciesScope._ignoreOptionEvent = true
    SpeciesScope.setOptionValue(mod, prev)
    SpeciesScope._ignoreOptionEvent = false
    notify(game, reason or Strings("Can't change DEX SCOPE."))
    return
  end

  local ok, err, msg = SpeciesScope.applyTransition(mod, game, toMode)
  if not ok then
    SpeciesScope._ignoreOptionEvent = true
    SpeciesScope.setOptionValue(mod, prev)
    SpeciesScope._ignoreOptionEvent = false
    notify(game, msg or Strings("Can't change DEX SCOPE."))
  end
end

--------------------------------------------------------------------------
-- Link fingerprint + eligible reasons
--------------------------------------------------------------------------

function SpeciesScope.installLink(mod)
  mod.hooks:wrap("link.fingerprint", function(nxt, data, mods)
    local fp = nxt(data, mods)
    local mode = SpeciesScope.mode(mod)
    return tostring(fp) .. "|scope:" .. tostring(mode)
  end)

  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
  Gen1Patch.apply(require("src.link.Fingerprint"), function(FP)
    local origRecords = FP.records
    if type(origRecords) ~= "function" then return end
    FP.records = function(data, kind, generation)
      local map = origRecords(data, kind, generation)
      if kind ~= "pokemon" then return map end
      if not (Host.isGen1() and SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO) then
        return map
      end
      local filtered = {}
      for id, hash in pairs(map or {}) do
        local def = data and data.pokemon and data.pokemon[id]
        local dex = def and def.dex
        if not dex or dex <= SpeciesScope.KANTO_MAX_DEX then
          filtered[id] = hash
        end
      end
      return filtered
    end
  end)

  Gen1Patch.apply(require("src.link.Protocol"), function(P)
    local orig = P.eligibleParty
    if type(orig) ~= "function" then return end
    P.eligibleParty = function(party, myRecords, theirRecords)
      local eligible, reasons = orig(party, myRecords, theirRecords)
      local peerKanto = false
      -- Heuristic: peer records missing many of our post-151 while we have them
      -- → show KANTO scope copy when reason is "not on the other game" for
      -- species we know are post-151.
      for i, mon in ipairs(party or {}) do
        if reasons[i] == "not on the other game" and mon and mon.species then
          local def = SpeciesScope._game and SpeciesScope._game.data
            and SpeciesScope._game.data.pokemon
            and SpeciesScope._game.data.pokemon[mon.species]
          local dex = def and def.dex
          if dex and dex > SpeciesScope.KANTO_MAX_DEX then
            reasons[i] = "Other player is on\nKANTO scope."
          end
        end
      end
      return eligible, reasons
    end
  end)

  -- Battle refuse message when subset due to scope: Handshake already blocks
  -- battle on subset. Annotate describe if possible.
  Gen1Patch.apply(require("src.link.Handshake"), function(H)
    local origDescribe = H.describe
    if type(origDescribe) ~= "function" then return end
    H.describe = function(localHello, remoteHello, verdict, mode)
      local lines = origDescribe(localHello, remoteHello, verdict, mode)
      if verdict == "subset" and mode == "battle" then
        local a = tostring(localHello and localHello.fingerprint or "")
        local b = tostring(remoteHello and remoteHello.fingerprint or "")
        if a:find("scope:", 1, true) or b:find("scope:", 1, true) then
          if (a:find("scope:kanto", 1, true) or b:find("scope:kanto", 1, true))
              and a ~= b then
            return {
              "DEX SCOPE doesn't match.",
              "Both players need the",
              "same KANTO/NATIONAL",
              "setting to battle.",
            }
          end
        end
      end
      return lines
    end
  end)
end

-- Safety: stash any out-of-scope party mon that slipped in under kanto
function SpeciesScope.stashLiveOutOfScope(mod, game, reasonMsg)
  if Host.isGen2() then return false end
  if SpeciesScope.mode(mod) ~= SpeciesScope.MODE_KANTO then return false end
  if not game or not game.save then return false end
  local ok, err, msg, plan = dryRunEnterKanto(mod, game)
  if not ok then
    notify(game, msg)
    return false
  end
  -- Only stash party/box outliers without full daycare if already applied
  applyEnterKanto(mod, game, plan)
  notify(game, reasonMsg or Strings(
    "Out-of-scope Pokémon\nwere moved to storage."))
  return true
end

function SpeciesScope.install(mod)
  SpeciesScope._mod = mod
  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")

  if Host.isGen1() then
    -- Keep KR seen/owned flags across SaveData.validate even if a species is
    -- briefly absent from data.pokemon (scope flips / partial loads).
    local SaveData = require("src.core.SaveData")
    if not SaveData._krScopeDexPreserve then
      local origValidate = SaveData.validate
      SaveData.validate = function(save, data)
        local preserved = { seen = {}, owned = {} }
        local dex = save and save.pokedex
        local packOk, pack = pcall(require, "mods.Kanto-Reforged.pokemon_data")
        local species = packOk and pack and pack.species
        if type(dex) == "table" and type(species) == "table" then
          for _, key in ipairs({ "seen", "owned" }) do
            if type(dex[key]) == "table" then
              for id, on in pairs(dex[key]) do
                if on and species[id] then
                  preserved[key][id] = true
                end
              end
            end
          end
        end
        local report = origValidate(save, data)
        if type(dex) == "table" then
          dex.seen = dex.seen or {}
          dex.owned = dex.owned or {}
          for _, key in ipairs({ "seen", "owned" }) do
            for id, on in pairs(preserved[key]) do
              if on then dex[key][id] = true end
            end
          end
        end
        return report
      end
      SaveData._krScopeDexPreserve = true
    end
  end
  if Host.isGen1() then
    Gen1Patch.apply(require("src.world.OverworldController"), function(OW)
      local target = OW.OverworldState or OW
      if type(target.objectVisible) ~= "function" then return end
      local orig = target.objectVisible
      target.objectVisible = function(save, mapId, obj)
        if not orig(save, mapId, obj) then return false end
        if obj and obj.pokemon then
          if not SpeciesScope.allowsSpeciesId(mod, obj.pokemon, mapId) then
            return false
          end
        end
        return true
      end
    end)

    -- Hard-lock: refuse to even write species_scope outside valid states.
    Gen1Patch.apply(require("src.mods.ManagerState"), function(MS)
      if MS._krScopeLock then return end
      local origSet = MS.setOption
      if type(origSet) ~= "function" then return end
      MS.setOption = function(self, modId, key, value)
        if Host.optionEventIs(key, SpeciesScope.OPTION_KEY) and modId == mod.id
            and not SpeciesScope._ignoreOptionEvent then
          local game = self.game or SpeciesScope._game or rawget(_G, "Game")
          local allowed, reason = SpeciesScope.canChangeScope(game)
          if not allowed then
            notify(game, reason)
            return
          end
        end
        return origSet(self, modId, key, value)
      end
      MS._krScopeLock = true
    end)

    -- Dex footer / list already limited by dexSize; clamp footer counts too
    -- when owned flags include post-151 ids (belt-and-suspenders).
    Gen1Patch.apply(require("src.ui.PokedexMenu"), function(PM)
      if PM._krScopeOwned then return end
      local origNew = PM.new
      if type(origNew) ~= "function" then return end
      PM.new = function(game, opts)
        local menu = origNew(game, opts)
        if Host.isGen1()
            and SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO
            and menu and menu.footer then
          local ownedN = select(1, SpeciesScope.countOwnedInScope(game, mod))
          local seenN = select(1, SpeciesScope.countSeenInScope(game, mod))
          -- Keep OWN ≤ SEEN for display sanity.
          if ownedN > seenN then seenN = ownedN end
          menu.footer = Strings("SEEN %3d  OWN %3d", seenN, ownedN)
        end
        return menu
      end
      PM._krScopeOwned = true
    end)
  end

  SpeciesScope.installLink(mod)

  mod.events:on("pokemon.received", function(ev)
    if not ev or not ev.mon then return end
    if SpeciesScope.mode(mod) ~= SpeciesScope.MODE_KANTO then return end
    if not SpeciesScope.isOutOfScopeMon(mod, ev.mon, SpeciesScope._game) then
      return
    end
    local game = SpeciesScope._game or rawget(_G, "Game")
    if game then
      SpeciesScope.stashLiveOutOfScope(mod, game, Strings(
        "Out-of-scope Pokémon\nwere moved to storage."))
    end
  end)

  mod.events:on("trade.completed", function(ev)
    if SpeciesScope.mode(mod) ~= SpeciesScope.MODE_KANTO then return end
    local game = SpeciesScope._game or rawget(_G, "Game")
    if game then
      SpeciesScope.stashLiveOutOfScope(mod, game, Strings(
        "Out-of-scope Pokémon\nwere moved to storage."))
    end
  end)

  mod.events:on("game.ready", function(ev)
    if ev and ev.game then
      SpeciesScope._game = ev.game
      SpeciesScope.ensureBoot(mod, ev.game)
    end
  end)
end

-- Test helpers
SpeciesScope._dryRunEnterKanto = dryRunEnterKanto
SpeciesScope._countBagSlotsNeeded = countBagSlotsNeeded
SpeciesScope._pendingFossilItem = pendingFossilItem
SpeciesScope.FOSSIL_FOR_SPECIES = FOSSIL_FOR_SPECIES
SpeciesScope.JOHTO_TRAINER_CLASSES = JOHTO_TRAINER_CLASSES
SpeciesScope._applyRestoreNational = applyRestoreNational

return SpeciesScope
