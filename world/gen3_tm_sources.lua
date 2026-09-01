-- Place Emerald TMs on existing mart clerks. No new NPCs, no overworld
-- objects: department stores get the bulk, a few city marts get one each.

local Host = require("mods.Kanto-Reforged.core.host")
local Gen3Tms = require("mods.Kanto-Reforged.items.gen3_tms")

local Gen3TmSources = {}

-- pret pokecrystal constants/mart_constants.asm (0-based martId).
Gen3TmSources.GEN2_MART = {
  VIOLET = 2,
  AZALEA = 3,
  CIANWOOD = 4,
  GOLDENROD_5F_1 = 9,
  GOLDENROD_5F_2 = 10,
  GOLDENROD_5F_3 = 11,
  GOLDENROD_5F_4 = 12,
  OLIVINE = 13,
  ECRUTEAK = 14,
  BLACKTHORN = 17,
  VERMILION = 22,
  CELADON_3F = 25,
  SAFFRON = 30,
}

-- One TM per town. Everything else goes on the department-store TM shelf.
Gen3TmSources.HUNT = {
  FOCUS_PUNCH = {
    gen1 = { map = "PewterMart", text = "TEXT_PEWTERMART_CLERK" },
    gen2 = "CIANWOOD",
  },
  BULK_UP = {
    gen1 = { map = "VermilionMart", text = "TEXT_VERMILIONMART_CLERK" },
    gen2 = "VIOLET",
  },
  CALM_MIND = {
    gen1 = { map = "SaffronMart", text = "TEXT_SAFFRONMART_CLERK" },
    gen2 = "ECRUTEAK",
  },
  DRAGON_CLAW = {
    gen1 = { map = "CinnabarMart", text = "TEXT_CINNABARMART_CLERK" },
    gen2 = "BLACKTHORN",
  },
  HAIL = {
    gen1 = { map = "CeruleanMart", text = "TEXT_CERULEANMART_CLERK" },
    gen2 = "OLIVINE",
  },
  OVERHEAT = {
    gen1 = { map = "FuchsiaMart", text = "TEXT_FUCHSIAMART_CLERK" },
    gen2 = "AZALEA",
  },
  TAUNT = {
    gen1 = { map = "LavenderMart", text = "TEXT_LAVENDERMART_CLERK" },
    gen2 = "VERMILION",
  },
  SKILL_SWAP = {
    gen1 = { map = "IndigoPlateauLobby", text = "TEXT_INDIGOPLATEAULOBBY_CLERK" },
    gen2 = "SAFFRON",
  },
}

-- Celadon 2F clerk 1 is Great Ball / Super Potion; clerk 2 (next to them) is TMs.
Gen3TmSources.GEN1_DEPT = {
  { map = "CeladonMart2F", text = "TEXT_CELADONMART2F_CLERK2" },
}

-- Goldenrod 3F is Battle Collection (X items). TM Corner is 5F; the clerk
-- swaps MART_GOLDENROD_5F_1..4 by badge, so every variant gets the extras.
-- Celadon 3F is the TM Showcase (2F is potions / balls).
Gen3TmSources.GEN2_DEPT = {
  "GOLDENROD_5F_1", "GOLDENROD_5F_2", "GOLDENROD_5F_3", "GOLDENROD_5F_4",
  "CELADON_3F",
}

local function appendUnique(list, ids)
  if type(list) ~= "table" then list = {} end
  local seen = {}
  for _, id in ipairs(list) do seen[id] = true end
  for _, id in ipairs(ids or {}) do
    if id and not seen[id] then
      list[#list + 1] = id
      seen[id] = true
    end
  end
  return list
end

function Gen3TmSources.plan(mod)
  local needed = {}
  local Data = package.loaded["src.core.Data"]
  local function hasItem(id)
    if mod and mod.content and mod.content.items and mod.content.items.get then
      if mod.content.items:get(id) then return true end
    end
    return Data and Data.items and Data.items[id] ~= nil
  end
  for _, row in ipairs(Gen3Tms.needed(mod)) do
    local id = Gen3Tms.itemId(row.move)
    if hasItem(id) then
      needed[row.move] = id
    end
  end

  local hunt, used = {}, {}
  for move, spec in pairs(Gen3TmSources.HUNT) do
    local id = needed[move]
    if id then
      hunt[#hunt + 1] = { move = move, item = id, spec = spec }
      used[id] = true
    end
  end
  table.sort(hunt, function(a, b)
    return Gen3Tms.numberOf(a.item) < Gen3Tms.numberOf(b.item)
  end)

  -- Walk MACHINES order so the shelf is TM61, TM63, … not TM_G3_AERIAL_ACE.
  local dept = {}
  for _, row in ipairs(Gen3Tms.needed(mod)) do
    local id = needed[row.move]
    if id and not used[id] then dept[#dept + 1] = id end
  end
  return { hunt = hunt, dept = dept }
end

local function patchGen1Clerk(mod, mapLabel, textKey, ids)
  if not mapLabel or not textKey or not ids or #ids == 0 then return end
  if not (mod.content and mod.content.text_pointers) then return end
  pcall(function()
    mod.content.text_pointers:patch(mapLabel, {
      [textKey] = { mart = { __append = ids } },
    })
  end)
end

local function gen2MartId(key)
  return Gen3TmSources.GEN2_MART[key]
end

function Gen3TmSources.gen2Extras(plan)
  local byId = {}
  local function add(martId, itemId)
    if martId == nil or not itemId then return end
    byId[martId] = byId[martId] or {}
    appendUnique(byId[martId], { itemId })
  end
  for _, key in ipairs(Gen3TmSources.GEN2_DEPT) do
    for _, id in ipairs(plan.dept) do
      add(gen2MartId(key), id)
    end
  end
  for _, row in ipairs(plan.hunt) do
    add(gen2MartId(row.spec.gen2), row.item)
  end
  return byId
end

function Gen3TmSources.applyGen2Lists(lists, byId)
  if type(lists) ~= "table" or type(byId) ~= "table" then return 0 end
  local n = 0
  for martId, ids in pairs(byId) do
    local idx = martId + 1
    if type(lists[idx]) == "table" then
      appendUnique(lists[idx], ids)
      if Gen3Tms.isMachineList(lists[idx]) then
        Gen3Tms.sortIds(lists[idx])
      end
      n = n + 1
    end
  end
  return n
end

function Gen3TmSources.installGen2Inventory(byId)
  if Gen3TmSources._inventoryWrapped then
    Gen3TmSources._gen2ByMartId = byId
    return
  end
  local ok, MartMenu = pcall(require, "src.ui.gen2.MartMenu")
  if not ok or type(MartMenu) ~= "table" or type(MartMenu.inventory) ~= "function" then
    return
  end
  local original = MartMenu.inventory
  MartMenu.inventory = function(marts, martId)
    local list = original(marts, martId)
    local extra = Gen3TmSources._gen2ByMartId and Gen3TmSources._gen2ByMartId[martId or 0]
    if not extra or #extra == 0 then return list end
    local out = {}
    for _, id in ipairs(list or {}) do out[#out + 1] = id end
    appendUnique(out, extra)
    if Gen3Tms.isMachineList(out) then
      Gen3Tms.sortIds(out)
    end
    return out
  end
  Gen3TmSources._inventoryWrapped = true
  Gen3TmSources._gen2ByMartId = byId
end

function Gen3TmSources.register(mod)
  local plan = Gen3TmSources.plan(mod)
  local nHunt, nDept = #plan.hunt, #plan.dept
  if Host.isGen2From(mod) then
    local byId = Gen3TmSources.gen2Extras(plan)
    local data = mod.data or package.loaded["src.core.Data"]
    if data and data.gen2Marts and data.gen2Marts.lists then
      Gen3TmSources.applyGen2Lists(data.gen2Marts.lists, byId)
    end
    Gen3TmSources.installGen2Inventory(byId)
    mod.log:info("Gen3 TM marts: %d dept + %d hunt (Gold/Crystal clerks)", nDept, nHunt)
  else
    local Data = package.loaded["src.core.Data"]
    for _, loc in ipairs(Gen3TmSources.GEN1_DEPT) do
      patchGen1Clerk(mod, loc.map, loc.text, plan.dept)
      local mart = Data and Data.text_pointers and Data.text_pointers[loc.map]
        and Data.text_pointers[loc.map][loc.text]
        and Data.text_pointers[loc.map][loc.text].mart
      if Gen3Tms.isMachineList(mart) then
        Gen3Tms.sortIds(mart)
      end
    end
    for _, row in ipairs(plan.hunt) do
      local loc = row.spec.gen1
      if loc then patchGen1Clerk(mod, loc.map, loc.text, { row.item }) end
    end
    mod.log:info("Gen3 TM marts: %d dept + %d hunt (Red clerks)", nDept, nHunt)
  end
end

return Gen3TmSources
