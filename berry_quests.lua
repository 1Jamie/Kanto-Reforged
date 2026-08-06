-- Berry Blender + Soil Expert (badge berry unlocks, ranks, vitamin crafts).

local HouseNpcs = require("mods.expansion_pack.house_npcs")
local BerryFarm = require("mods.expansion_pack.berry_farm")
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
  return save.inventory and (save.inventory[badge] or 0) > 0
end

function BerryQuests.applyBadgeUnlocks(mod, game, opts)
  opts = opts or {}
  local save = game and game.save
  if not save then return {} end
  local newly = {}
  local gifted = mod.save:get("gifted_berry_seeds", nil)
  if type(gifted) ~= "table" then gifted = {} end
  for _, row in ipairs(BerryQuests.BADGE_UNLOCKS) do
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
    mod.save:set("gifted_berry_seeds", gifted)
  end
  return newly
end

-- Gift a starter pack when a berry type first unlocks (so eating one
-- doesn't soft-lock planting). Merchant on the farm sells more afterward.
BerryQuests.UNLOCK_SEED_GIFT = 3

local function merchantStock(mod)
  return BerryFarm.plantableList(mod)
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
      local ShopMenu = require("src.ui.ShopMenu")
      game.stack:push(ShopMenu.new(game, stock, done))
    end)
  end
end

local function blenderGateOk(mod, game)
  if hasBadge(game.save, "RAINBOWBADGE") then return true end
  return (mod.save:get("soil_rank", 0) or 0) >= 1
end

local function blenderStepNeed(mod)
  local rank = mod.save:get("soil_rank", 0) or 0
  if rank >= 3 then return 480 end
  return 640
end

local function blenderReady(mod)
  local steps = mod.save:get("farmSteps", 0) or 0
  local anchor = mod.save:get("blender_steps_anchor", nil)
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

local function blenderTalk(mod)
  return function(game, ow, npc, done)
    if not blenderGateOk(mod, game) then
      HouseNpcs.pushText(game, Strings(
        "We're still testing\njuice recipes...\f"
          .. "Come back after the\nRAINBOW BADGE!"), done)
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
      rows[#rows + 1] = { label = rec.label, value = rec }
    end
    local ListMenu = require("src.ui.ListMenu")
    game.stack:push(ListMenu.new(game, Strings("Blend what?"), rows, {
      onChoose = function(row, menu)
        menu:close()
        local rec = row.value
        if not canAfford(game.save, rec.need) then
          HouseNpcs.pushText(game, Strings("Not enough berries."), done)
          return
        end
        takeNeed(game.save, rec.need)
        if not HouseNpcs.giveItem(game, rec.give, 1) then
          -- refund on bag full
          local Bag = require("src.inventory.Bag")
          for id, n in pairs(rec.need) do Bag.add(game.save, id, n) end
          HouseNpcs.pushText(game, Strings("The bag is full!"), done)
          return
        end
        mod.save:set("blender_steps_anchor", mod.save:get("farmSteps", 0) or 0)
        HouseNpcs.pushText(game, Strings("Blended a\n%s!", rec.label), done)
      end,
    }))
  end
end

local function countOwnedSpecies(save)
  local owned = save.pokedex and save.pokedex.owned or {}
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
  local HeldItems = require("mods.expansion_pack.held_items")
  local n = 0
  local inv = save.inventory or {}
  for _, id in ipairs(HeldItems.BERRY_PACK) do
    if (inv[id] or 0) > 0 then n = n + 1 end
  end
  return n
end

local function soilTalk(mod)
  return function(game, ow, npc, done)
    local newly = BerryQuests.applyBadgeUnlocks(mod, game, { gift = true })
    local rank = mod.save:get("soil_rank", 0) or 0
    local msg = Strings("I study berry soil.\f")
    if #newly > 0 then
      msg = msg .. Strings(
        "New berries unlocked\nfrom your badges!\f"
          .. "I packed %dx of each.\f"
          .. "Buy more at the\nstall anytime!",
        BerryQuests.UNLOCK_SEED_GIFT)
    end

    if rank < 1 and countOwnedSpecies(game.save) >= 5 then
      mod.save:set("soil_rank", 1)
      rank = 1
      msg = msg .. Strings("Rank 1! Berries\ngrow a bit faster.\f")
    elseif rank < 2 and hasGrassLevel(game, 20) then
      mod.save:set("soil_rank", 2)
      rank = 2
      msg = msg .. Strings("Rank 2! Even\nfaster growth.\f")
    elseif rank < 3 and berryTypesInBag(game.save) >= 3 then
      mod.save:set("soil_rank", 3)
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

  mod.content.map_scripts:register("CELADON_MANSION_3F", {
    talk = { TEXT_CELADONMANSION3F_BLENDER = blenderTalk(mod) },
  })
  mod.content.map_scripts:register("BERRY_FARM", {
    talk = {
      TEXT_BERRY_FARM_SOIL_EXPERT = soilTalk(mod),
      TEXT_BERRY_FARM_MERCHANT = merchantTalk(mod),
    },
  })

  -- Auto-unlock berries when badges are earned (on map enter farm or talk).
  mod.events:on("map.entered", function(ev)
    if not ev or not ev.game then return end
    BerryQuests.applyBadgeUnlocks(mod, ev.game)
  end)
end

return BerryQuests
