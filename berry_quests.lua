-- Berry Blender + Soil Expert (badge berry unlocks, ranks, vitamin crafts).

local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
local BerryFarm = require("mods.Kanto-Reforged.berry_farm")
local Strings = require("src.core.Strings")

local BerryQuests = {}
BerryQuests.OWNER = "berry_quests"

BerryQuests.BADGE_UNLOCKS = {
  { badge = "BOULDERBADGE", berries = { "CHERI_BERRY" } },
  { badge = "CASCADEBADGE", berries = { "PECHA_BERRY" } },
  { badge = "THUNDERBADGE", berries = { "RAWST_BERRY" } },
  { badge = "RAINBOWBADGE", berries = { "ASPEAR_BERRY", "CHESTO_BERRY" } },
  { badge = "SOULBADGE", berries = { "PERSIM_BERRY" } },
  { badge = "MARSHBADGE", berries = { "LUM_BERRY" } },
  { badge = "VOLCANOBADGE", berries = { "LUM_BERRY" } },
}

-- Gold / Crystal: Johto gym order only. Never gate farm unlocks on
-- save.player.kantoBadges (RBY rematches) — those are a separate track.
BerryQuests.BADGE_UNLOCKS_JOHTO = {
  { badge = "ZEPHYR", berries = { "CHERI_BERRY" } },
  { badge = "HIVE", berries = { "PECHA_BERRY" } },
  { badge = "PLAIN", berries = { "RAWST_BERRY" } },
  { badge = "FOG", berries = { "ASPEAR_BERRY", "CHESTO_BERRY" } },
  { badge = "STORM", berries = { "PERSIM_BERRY" } },
  { badge = "MINERAL", berries = { "LUM_BERRY" } },
  { badge = "GLACIER", berries = { "LUM_BERRY" } },
}

-- Blender unlock: 4th story badge (Rainbow / Fog).
BerryQuests.BLENDER_BADGE_GEN1 = "RAINBOWBADGE"
BerryQuests.BLENDER_BADGE_GEN2 = "FOG"

BerryQuests.RECIPES = {
  {
    id = "hp_up",
    label = "HP UP",
    need = { CHERI_BERRY = 10 },
    give = "HP_UP",
  },
  {
    id = "protein",
    label = "PROTEIN",
    need = { RAWST_BERRY = 10 },
    give = "PROTEIN",
  },
  {
    id = "iron",
    label = "IRON",
    need = { PECHA_BERRY = 10 },
    give = "IRON",
  },
  {
    id = "carbos",
    label = "CARBOS",
    need = { ASPEAR_BERRY = 10 },
    give = "CARBOS",
  },
  {
    id = "calcium",
    label = "CALCIUM",
    need = { CHESTO_BERRY = 10 },
    give = "CALCIUM",
  },
  {
    id = "lum",
    label = "LUM BERRY",
    need = {
      CHERI_BERRY = 1, PECHA_BERRY = 1, RAWST_BERRY = 1,
      ASPEAR_BERRY = 1, CHESTO_BERRY = 1, BERRY = 3,
    },
    give = "LUM_BERRY",
  },
}

local function hasBadge(save, badge)
  return HouseNpcs.hasBadge(save, badge)
end

-- Host-local unlock table only — RBY never reads Johto badges; Gold never
-- reads Kanto inventory/rematch badges for farm progression.
function BerryQuests.unlockRows()
  local Host = require("mods.Kanto-Reforged.host")
  if Host.isGen2() then
    return BerryQuests.BADGE_UNLOCKS_JOHTO
  end
  return BerryQuests.BADGE_UNLOCKS
end

function BerryQuests.blenderBadgeId()
  local Host = require("mods.Kanto-Reforged.host")
  if Host.isGen2() then
    return BerryQuests.BLENDER_BADGE_GEN2
  end
  return BerryQuests.BLENDER_BADGE_GEN1
end

function BerryQuests.applyBadgeUnlocks(mod, game, opts)
  opts = opts or {}
  local Host = require("mods.Kanto-Reforged.host")
  local save = game and game.save
  if not save then return {} end
  local newly = {}
  local gifted = Host.saveGet(mod.save, "gifted_berry_seeds", nil)
  if type(gifted) ~= "table" then gifted = {} end
  for _, row in ipairs(BerryQuests.unlockRows()) do
    if hasBadge(save, row.badge) then
      for _, berry in ipairs(row.berries) do
        local unlocked = BerryFarm.ensureUnlocked(mod)
        if not unlocked[berry] then
          BerryFarm.unlockBerry(mod, berry)
          newly[#newly + 1] = berry
        end
        if opts.gift and not gifted[berry] then
          if HouseNpcs.giveItem(game, berry, BerryQuests.UNLOCK_SEED_GIFT) then
            gifted[berry] = true
          end
        end
      end
    end
  end
  if opts.gift then
    Host.saveSet(mod.save, "gifted_berry_seeds", gifted)
  end
  return newly
end

-- Gift a starter pack when a berry type first unlocks (so eating one
-- doesn't soft-lock planting). Merchant on the farm sells more afterward.
BerryQuests.UNLOCK_SEED_GIFT = 3

local function merchantStock(mod)
  return BerryFarm.plantableList(mod)
end

-- Gen1 ShopMenu reads save.money; Gold keeps ¥ on save.player.money, so a
-- buy compare (nil < price) hard-crashes. Use Gen2MartMenu on Gold.
function BerryQuests.openShop(game, stock, done)
  local Host = require("mods.Kanto-Reforged.host")
  if Host.isGen2() then
    local Screens = require("src.ui.Screens")
    Screens.push(game, "Gen2MartMenu", {
      save = game.save,
      items = game.data and game.data.items,
      -- martId 0 → lists[1]; synthetic shelf from unlocked farm berries.
      marts = { lists = { stock } },
      martType = "STANDARD",
      martId = 0,
      text = game.world and game.world.text,
      onClose = function()
        if game.stack then game.stack:pop() end
        if done then done() end
      end,
    })
    return
  end
  local ShopMenu = require("src.ui.ShopMenu")
  game.stack:push(ShopMenu.new(game, stock, done))
end

local function merchantTalk(mod)
  return function(game, ow, npc, done)
    BerryQuests.applyBadgeUnlocks(mod, game, { gift = true })
    local stock = merchantStock(mod)
    if #stock == 0 then
      HouseNpcs.pushText(game, Strings(
        "No berries in stock\nyet.\fTalk to the soil\nexpert after gyms!"), done)
      return
    end
    HouseNpcs.pushText(game, Strings(
      "Berry stall!\f"
        .. "I sell berries you\nhave unlocked.\f"
        .. "Growing more on the\nplots is cheaper."), function()
      BerryQuests.openShop(game, stock, done)
    end)
  end
end

local function blenderGateOk(mod, game)
  local Host = require("mods.Kanto-Reforged.host")
  if hasBadge(game.save, BerryQuests.blenderBadgeId()) then return true end
  return (Host.saveGet(mod.save, "soil_rank", 0) or 0) >= 1
end

local function blenderGateHint()
  local Host = require("mods.Kanto-Reforged.host")
  if Host.isGen2() then
    return Strings(
      "We're still testing\njuice recipes...\f"
        .. "Come back after the\nFOG BADGE!")
  end
  return Strings(
    "We're still testing\njuice recipes...\f"
      .. "Come back after the\nRAINBOW BADGE!")
end

local function blenderStepNeed(mod)
  local Host = require("mods.Kanto-Reforged.host")
  local rank = Host.saveGet(mod.save, "soil_rank", 0) or 0
  if rank >= 3 then return 480 end
  return 640
end

local function blenderReady(mod)
  local Host = require("mods.Kanto-Reforged.host")
  local steps = Host.saveGet(mod.save, "farmSteps", 0) or 0
  local anchor = Host.saveGet(mod.save, "blender_steps_anchor", nil)
  if anchor == nil then return true end
  return steps >= (anchor + blenderStepNeed(mod))
end

local function canAfford(save, need)
  local inv = save.inventory or {}
  for id, n in pairs(need) do
    if (inv[id] or 0) < n then return false end
  end
  return true
end

local function takeNeed(save, need)
  local Bag = require("src.inventory.Bag")
  for id, n in pairs(need) do
    Bag.remove(save, id, n)
  end
end

local function itemName(data, id)
  local def = data and data.items and data.items[id]
  return (def and def.name) or id
end

--- Sorted "Nx NAME" lines for a recipe's berry cost.
function BerryQuests.formatNeedLines(data, need)
  local rows = {}
  for id, n in pairs(need or {}) do
    rows[#rows + 1] = { id = id, n = n, name = itemName(data, id) }
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  local lines = {}
  for _, row in ipairs(rows) do
    lines[#lines + 1] = string.format("%dx %s", row.n, row.name)
  end
  return lines
end

function BerryQuests.formatRecipePrompt(data, rec)
  local lines = BerryQuests.formatNeedLines(data, rec.need)
  -- Paginate for the 2-line text box: title, then cost pages, then confirm.
  local parts = { rec.label }
  if #lines == 1 then
    parts[#parts + 1] = "Needs:\n" .. lines[1]
  else
    parts[#parts + 1] = "Needs:"
    for i = 1, #lines, 2 do
      local a = lines[i]
      local b = lines[i + 1]
      parts[#parts + 1] = b and (a .. "\n" .. b) or a
    end
  end
  parts[#parts + 1] = string.format("Make one %s?", rec.label)
  return Strings(table.concat(parts, "\f"))
end

local function craftRecipe(mod, game, rec, done)
  if not canAfford(game.save, rec.need) then
    HouseNpcs.pushText(game, Strings("Not enough berries."), done)
    return
  end
  takeNeed(game.save, rec.need)
  if not HouseNpcs.giveItem(game, rec.give, 1) then
    local Bag = require("src.inventory.Bag")
    for id, n in pairs(rec.need) do Bag.add(game.save, id, n) end
    HouseNpcs.pushText(game, Strings("The bag is full!"), done)
    return
  end
  local Host = require("mods.Kanto-Reforged.host")
  Host.saveSet(mod.save, "blender_steps_anchor", Host.saveGet(mod.save, "farmSteps", 0) or 0)
  HouseNpcs.pushText(game, Strings("Blended a\n%s!", rec.label), done)
end

local function blenderTalk(mod)
  return function(game, ow, npc, done)
    if not blenderGateOk(mod, game) then
      HouseNpcs.pushText(game, blenderGateHint(), done)
      return
    end
    if not blenderReady(mod) then
      HouseNpcs.pushText(game, Strings(
        "The blender needs\ntime to cool.\f"
          .. "Walk more, then\ncome back!"), done)
      return
    end
    local rows = {}
    for _, rec in ipairs(BerryQuests.RECIPES) do
      local mark = canAfford(game.save, rec.need) and "" or " ×"
      rows[#rows + 1] = {
        label = rec.label .. mark,
        value = rec,
      }
    end
    local ListMenu = require("src.ui.ListMenu")
    game.stack:push(ListMenu.new(game, Strings("Blend what?"), rows, {
      onCancel = function()
        if done then done() end
      end,
      onChoose = function(row, menu)
        menu:close()
        local rec = row.value
        local prompt = BerryQuests.formatRecipePrompt(game.data, rec)
        HouseNpcs.ask(game, prompt, function(yes)
          if not yes then
            HouseNpcs.pushText(game, Strings("Maybe later."), done)
            return
          end
          craftRecipe(mod, game, rec, done)
        end)
      end,
    }))
  end
end

local function countOwnedSpecies(save)
  -- Gen1 pokedex.owned; Gold pokedex.caught.
  local dex = save and save.pokedex or {}
  local owned = dex.owned or dex.caught or {}
  local n = 0
  for _ in pairs(owned) do n = n + 1 end
  return n
end

local function hasGrassLevel(game, minLv)
  local pokemon = game.data.pokemon or {}
  for _, mon in ipairs(game.save.party or {}) do
    if mon and (mon.level or 0) >= minLv then
      local def = pokemon[mon.species]
      local types = def and def.types or {}
      for _, t in ipairs(types) do
        if t == "GRASS" then return true end
      end
    end
  end
  return false
end

local function berryTypesInBag(save)
  local HeldItems = require("mods.Kanto-Reforged.held_items")
  local n = 0
  local inv = save.inventory or {}
  for _, id in ipairs(HeldItems.BERRY_PACK) do
    if (inv[id] or 0) > 0 then n = n + 1 end
  end
  return n
end

local function soilTalk(mod)
  return function(game, ow, npc, done)
    local Host = require("mods.Kanto-Reforged.host")
    local newly = BerryQuests.applyBadgeUnlocks(mod, game, { gift = true })
    local rank = Host.saveGet(mod.save, "soil_rank", 0) or 0
    local msg = Strings("I study berry soil.\f")
    if #newly > 0 then
      msg = msg .. Strings(
        "New berries unlocked\nfrom your badges!\f"
          .. "I packed %dx of each.\f"
          .. "Buy more at the\nstall anytime!",
        BerryQuests.UNLOCK_SEED_GIFT)
    end

    if rank < 1 and countOwnedSpecies(game.save) >= 5 then
      Host.saveSet(mod.save, "soil_rank", 1)
      rank = 1
      msg = msg .. Strings("Rank 1! Berries\ngrow a bit faster.\f")
    elseif rank < 2 and hasGrassLevel(game, 20) then
      Host.saveSet(mod.save, "soil_rank", 2)
      rank = 2
      msg = msg .. Strings("Rank 2! Even\nfaster growth.\f")
    elseif rank < 3 and berryTypesInBag(game.save) >= 3 then
      Host.saveSet(mod.save, "soil_rank", 3)
      rank = 3
      msg = msg .. Strings("Rank 3! Top soil\nand cooler blender.\f")
    else
      msg = msg .. Strings("Current soil rank:\n%d\fKeep collecting!", rank)
    end
    HouseNpcs.pushText(game, msg, done)
  end
end

function BerryQuests.register(mod)
  HouseNpcs.appendNpc(mod, "CELADON_MANSION_3F", {
    index = 5,
    name = "CELADONMANSION3F_BLENDER",
    sprite = "SPRITE_BEAUTY",
    text = "TEXT_CELADONMANSION3F_BLENDER",
    x = 3, y = 8,
  }, BerryQuests.OWNER)

  -- Soil expert on berry farm — avoid girl at (12,7)
  HouseNpcs.appendNpc(mod, "BERRY_FARM", {
    index = 3,
    name = "BERRY_FARM_SOIL_EXPERT",
    sprite = "SPRITE_SCIENTIST",
    text = "TEXT_BERRY_FARM_SOIL_EXPERT",
    x = 16, y = 8,
  }, BerryQuests.OWNER)

  -- Berry stall: buy any unlocked berry (restock if you ate your gifts).
  HouseNpcs.appendNpc(mod, "BERRY_FARM", {
    index = 5,
    name = "BERRY_FARM_MERCHANT",
    sprite = "SPRITE_GIRL",
    text = "TEXT_BERRY_FARM_MERCHANT",
    x = 8, y = 14,
  }, BerryQuests.OWNER)

  HouseNpcs.bindTalk(mod, "CELADON_MANSION_3F", {
    TEXT_CELADONMANSION3F_BLENDER = blenderTalk(mod),
  })
  HouseNpcs.bindTalk(mod, "BERRY_FARM", {
    TEXT_BERRY_FARM_SOIL_EXPERT = soilTalk(mod),
    TEXT_BERRY_FARM_MERCHANT = merchantTalk(mod),
  })

  -- Auto-unlock berries when badges are earned (on map enter farm or talk).
  mod.events:on("map.entered", function(ev)
    -- Engines emit mapId/map/fromMapId/via — never ev.game.
    local game = ev and ev.game
    if not game then
      local ok, SS = pcall(require, "mods.Kanto-Reforged.species_scope")
      if ok and SS and SS._game then game = SS._game end
    end
    if not game then
      game = package.loaded["src.core.Game"] or rawget(_G, "Game")
    end
    if not game then return end
    BerryQuests.applyBadgeUnlocks(mod, game)
  end)
end

return BerryQuests
