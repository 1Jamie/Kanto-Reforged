-- Berry Farm implementation for Gen 3 (FireRed & LeafGreen).
-- Recreates the 9-plot step-grown berry farm using native Gen 3 items & mechanics.

local Strings = require("src.core.Strings")

local BerryFarmGame3 = {}

BerryFarmGame3.MAP_ID = "FR_BERRY_FARM"
BerryFarmGame3.MAP_ID_ALIAS = "BERRY_FARM"
BerryFarmGame3.GROW_STEPS = 500
BerryFarmGame3.PLOT_COUNT = 9
BerryFarmGame3.HARVEST_YIELD = 2

BerryFarmGame3.GROW_BY_RANK = { [0] = 500, [1] = 438, [2] = 375, [3] = 300 }

-- Native GBA Berry Item Constants
BerryFarmGame3.GBA_BERRIES = {
  CHERI_BERRY   = 133,
  CHESTO_BERRY  = 134,
  PECHA_BERRY   = 135,
  RAWST_BERRY   = 136,
  ASPEAR_BERRY  = 137,
  LEPPA_BERRY   = 138,
  ORAN_BERRY    = 139,
  PERSIM_BERRY  = 140,
  LUM_BERRY     = 141,
  SITRUS_BERRY  = 142,
}

BerryFarmGame3.BERRY_BY_ID = {}
for name, id in pairs(BerryFarmGame3.GBA_BERRIES) do
  BerryFarmGame3.BERRY_BY_ID[id] = name
end

BerryFarmGame3.BERRY_PACK_GEN3 = {
  "ORAN_BERRY",
  "CHERI_BERRY",
  "CHESTO_BERRY",
  "PECHA_BERRY",
  "RAWST_BERRY",
  "ASPEAR_BERRY",
  "LEPPA_BERRY",
  "PERSIM_BERRY",
  "LUM_BERRY",
  "SITRUS_BERRY",
}

BerryFarmGame3.SCHOLAR_ENTRIES = {
  {
    id = "ORAN_BERRY",
    name = "ORAN BERRY",
    blurb = "ORAN BERRY restores\n10 HP when held or\vused in battle.",
  },
  {
    id = "CHERI_BERRY",
    name = "CHERI BERRY",
    blurb = "CHERI BERRY cures\nparalysis instantly\vwhen held.",
  },
  {
    id = "CHESTO_BERRY",
    name = "CHESTO BERRY",
    blurb = "CHESTO BERRY awakens\na sleeping POKéMON.",
  },
  {
    id = "PECHA_BERRY",
    name = "PECHA BERRY",
    blurb = "PECHA BERRY heals\npoison on contact.",
  },
  {
    id = "RAWST_BERRY",
    name = "RAWST BERRY",
    blurb = "RAWST BERRY heals\na burn instantly.",
  },
  {
    id = "ASPEAR_BERRY",
    name = "ASPEAR BERRY",
    blurb = "ASPEAR BERRY thaws\nout frozen status.",
  },
  {
    id = "LEPPA_BERRY",
    name = "LEPPA BERRY",
    blurb = "LEPPA BERRY restores\n10 PP to a move.",
  },
  {
    id = "PERSIM_BERRY",
    name = "PERSIM BERRY",
    blurb = "PERSIM BERRY snaps\na POKéMON out of\vconfusion.",
  },
  {
    id = "LUM_BERRY",
    name = "LUM BERRY",
    blurb = "LUM BERRY cures all\nstatus conditions\vand confusion!",
  },
  {
    id = "SITRUS_BERRY",
    name = "SITRUS BERRY",
    blurb = "SITRUS BERRY restores\n30 HP when held or\vused.",
  },
}

-- FRLG Pokémon Centers list
BerryFarmGame3.ALL_POKECENTERS_GEN3 = {
  "FR_VIRIDIAN_CITY_POKEMON_CENTER_1F",
  "FR_PEWTER_CITY_POKEMON_CENTER_1F",
  "FR_CERULEAN_CITY_POKEMON_CENTER_1F",
  "FR_ROUTE_4_POKEMON_CENTER_1F",
  "FR_VERMILION_CITY_POKEMON_CENTER_1F",
  "FR_ROUTE_10_POKEMON_CENTER_1F",
  "FR_LAVENDER_TOWN_POKEMON_CENTER_1F",
  "FR_CELADON_CITY_POKEMON_CENTER_1F",
  "FR_FUCHSIA_CITY_POKEMON_CENTER_1F",
  "FR_CINNABAR_ISLAND_POKEMON_CENTER_1F",
  "FR_SAFFRON_CITY_POKEMON_CENTER_1F",
  "FR_INDIGO_PLATEAU_POKEMON_CENTER_1F",
  "FR_ONE_ISLAND_POKEMON_CENTER_1F",
  "FR_TWO_ISLAND_POKEMON_CENTER_1F",
  "FR_THREE_ISLAND_POKEMON_CENTER_1F",
  "FR_FOUR_ISLAND_POKEMON_CENTER_1F",
  "FR_FIVE_ISLAND_POKEMON_CENTER_1F",
  "FR_SIX_ISLAND_POKEMON_CENTER_1F",
  "FR_SEVEN_ISLAND_POKEMON_CENTER_1F",
  -- Pret style names
  "ViridianCity_PokemonCenter_1F",
  "PewterCity_PokemonCenter_1F",
  "CeruleanCity_PokemonCenter_1F",
  "Route4_PokemonCenter_1F",
  "VermilionCity_PokemonCenter_1F",
  "Route10_PokemonCenter_1F",
  "LavenderTown_PokemonCenter_1F",
  "CeladonCity_PokemonCenter_1F",
  "FuchsiaCity_PokemonCenter_1F",
  "CinnabarIsland_PokemonCenter_1F",
  "SaffronCity_PokemonCenter_1F",
  "IndigoPlateau_PokemonCenter_1F",
  "OneIsland_PokemonCenter_1F",
  "TwoIsland_PokemonCenter_1F",
  "ThreeIsland_PokemonCenter_1F",
  "FourIsland_PokemonCenter_1F",
  "FiveIsland_PokemonCenter_1F",
  "SixIsland_PokemonCenter_1F",
  "SevenIsland_PokemonCenter_1F",
  -- Short alias fallbacks
  "VIRIDIAN_POKECENTER",
  "PEWTER_POKECENTER",
  "CERULEAN_POKECENTER",
  "VERMILION_POKECENTER",
  "LAVENDER_POKECENTER",
  "CELADON_POKECENTER",
  "FUCHSIA_POKECENTER",
  "SAFFRON_POKECENTER",
  "CINNABAR_POKECENTER",
}

-- Native FRLG Pokecenter Mat Metatiles
BerryFarmGame3.RED_MAT_MIDS = {
  TOP_L = 706,
  TOP_M = 707, -- warp collision (coll = 114)
  TOP_R = 708,
  BOT_L = 26,
  BOT_M = 27,
  BOT_R = 28,
}

BerryFarmGame3.PC_DOOR = { x = 3, y = 8 }
BerryFarmGame3.LANDING = { x = 7, y = 8 }
BerryFarmGame3.EXIT = { x = 7, y = 7 }
BerryFarmGame3.RETURN_CELL = { x = 3, y = 8 }

BerryFarmGame3.WIDTH = 38
BerryFarmGame3.HEIGHT = 24

BerryFarmGame3.PLOT_RECTS = {
  { x0 = 6, y0 = 12, x1 = 7, y1 = 13 },
  { x0 = 11, y0 = 12, x1 = 12, y1 = 13 },
  { x0 = 16, y0 = 12, x1 = 17, y1 = 13 },
  { x0 = 6, y0 = 15, x1 = 7, y1 = 16 },
  { x0 = 11, y0 = 15, x1 = 12, y1 = 16 },
  { x0 = 16, y0 = 15, x1 = 17, y1 = 16 },
  { x0 = 6, y0 = 18, x1 = 7, y1 = 19 },
  { x0 = 11, y0 = 18, x1 = 12, y1 = 19 },
  { x0 = 16, y0 = 18, x1 = 17, y1 = 19 },
}

BerryFarmGame3.PLOT_SPRITE_SOIL = "SPRITE_PLOT_SOIL"
BerryFarmGame3.PLOT_SPRITE_GROWING = "SPRITE_PLOT_GROWING"
BerryFarmGame3.PLOT_SPRITE_BY_BERRY = {
  BERRY = "SPRITE_PLOT_BERRY",
  CHERI_BERRY = "SPRITE_PLOT_CHERI",
  CHESTO_BERRY = "SPRITE_PLOT_CHESTO",
  PECHA_BERRY = "SPRITE_PLOT_PECHA",
  RAWST_BERRY = "SPRITE_PLOT_RAWST",
  ASPEAR_BERRY = "SPRITE_PLOT_ASPEAR",
  PERSIM_BERRY = "SPRITE_PLOT_PERSIM",
  LUM_BERRY = "SPRITE_PLOT_LUM",
  LEPPA_BERRY = "SPRITE_PLOT_BERRY",
  ORAN_BERRY = "SPRITE_PLOT_BERRY",
  SITRUS_BERRY = "SPRITE_PLOT_BERRY",
}

function BerryFarmGame3.registerPlotSprites(mod, gameRef)
  local function registerDef(id, def)
    pcall(function()
      local okFv, FieldView = pcall(require, "src.core.game3.field_view")
      if okFv and FieldView and FieldView.registerSprite then
        FieldView.registerSprite(id, def)
      end
    end)
    pcall(function()
      local okData, Data = pcall(require, "src.core.Data")
      if okData and Data then
        Data.sprites = Data.sprites or {}
        Data.sprites[id] = def
      end
    end)
    pcall(function()
      local Host = require("mods.Kanto-Reforged.core.host")
      local games = {}
      if gameRef and type(gameRef) == "table" then games[#games + 1] = gameRef end
      local lg = Host.liveGame(mod)
      if lg and type(lg) == "table" then games[#games + 1] = lg end
      local Rt = package.loaded["src.core.game3.runtime"]
      if Rt and Rt._game and type(Rt._game) == "table" then games[#games + 1] = Rt._game end
      local Fld = package.loaded["src.core.game3.field"]
      if Fld and Fld._game and type(Fld._game) == "table" then games[#games + 1] = Fld._game end

      for _, g in ipairs(games) do
        g.data = g.data or {}
        g.data.sprites = g.data.sprites or {}
        g.data.sprites[id] = def
        g.data.gen2Sprites = g.data.gen2Sprites or {}
        g.data.gen2Sprites[id] = def
      end
    end)
  end

  local function sprite(id, file)
    local def = {
      image = "mods/Kanto-Reforged/assets/" .. file,
      frames = 1,
      frameWidth = 16,
      frameHeight = 16,
      anchorX = 8,
      anchorY = 16,
      walker = false,
      trueColor = true,
      spriteType = "STILL_SPRITE",
    }
    registerDef(id, def)
  end

  sprite(BerryFarmGame3.PLOT_SPRITE_SOIL, "plot_soil.png")
  sprite(BerryFarmGame3.PLOT_SPRITE_GROWING, "plot_growing.png")
  sprite("SPRITE_PLOT_BERRY", "plot_berry.png")
  sprite("SPRITE_PLOT_CHERI", "plot_cheri.png")
  sprite("SPRITE_PLOT_CHESTO", "plot_chesto.png")
  sprite("SPRITE_PLOT_PECHA", "plot_pecha.png")
  sprite("SPRITE_PLOT_RAWST", "plot_rawst.png")
  sprite("SPRITE_PLOT_ASPEAR", "plot_aspear.png")
  sprite("SPRITE_PLOT_PERSIM", "plot_persim.png")
  sprite("SPRITE_PLOT_LUM", "plot_lum.png")

  -- Trigger native GBA OW sprite prefetch for the farm NPCs (23=Woman1, 55=Scientist, 57=Fisher, 68=Clerk)
  pcall(function()
    local okOw, OwSprites = pcall(require, "src.core.game3.ow_sprites")
    if okOw and OwSprites then
      for _, gid in ipairs({ 23, 55, 57, 68 }) do
        if OwSprites.prefetch then OwSprites.prefetch(gid, 0) end
        if OwSprites.get then OwSprites.get(gid) end
      end
    end
  end)
end

function BerryFarmGame3.plotSpriteFor(steps, p, growNeed)
  growNeed = growNeed or BerryFarmGame3.GROW_STEPS
  if not p or not p.berryId then return BerryFarmGame3.PLOT_SPRITE_SOIL end
  if (steps - (p.plantedAtSteps or 0)) >= growNeed then
    return BerryFarmGame3.PLOT_SPRITE_BY_BERRY[p.berryId] or BerryFarmGame3.PLOT_SPRITE_BY_BERRY.BERRY
  end
  return BerryFarmGame3.PLOT_SPRITE_GROWING
end

local function plotKey(idx)
  return tostring(idx)
end

function BerryFarmGame3.growSteps(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local rank = 0
  if mod and mod.save then
    rank = Host.saveGet(mod.save, "soil_rank", 0) or 0
  end
  return BerryFarmGame3.GROW_BY_RANK[rank] or BerryFarmGame3.GROW_STEPS
end

function BerryFarmGame3.ensureUnlocked(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local unlocked = Host.saveGet(mod.save, "unlocked_berries", nil)
  if type(unlocked) ~= "table" then
    unlocked = { ORAN_BERRY = true }
    Host.saveSet(mod.save, "unlocked_berries", unlocked)
  elseif not unlocked.ORAN_BERRY and not unlocked.BERRY then
    unlocked.ORAN_BERRY = true
    Host.saveSet(mod.save, "unlocked_berries", unlocked)
  end
  return unlocked
end

function BerryFarmGame3.unlockBerry(mod, berryId)
  local Host = require("mods.Kanto-Reforged.core.host")
  local unlocked = BerryFarmGame3.ensureUnlocked(mod)
  unlocked[berryId] = true
  Host.saveSet(mod.save, "unlocked_berries", unlocked)
end

function BerryFarmGame3.plantableList(mod)
  local unlocked = BerryFarmGame3.ensureUnlocked(mod)
  local list = {}
  for _, id in ipairs(BerryFarmGame3.BERRY_PACK_GEN3) do
    if unlocked[id] or (id == "ORAN_BERRY" and unlocked.BERRY) then
      list[#list + 1] = id
    end
  end
  return list
end

local function readPlots(raw)
  local out = {}
  if type(raw) ~= "table" then return out end
  for k, v in pairs(raw) do
    if type(v) == "table" and v.berryId then
      local idx = tonumber(k)
      if idx and idx >= 1 and idx <= BerryFarmGame3.PLOT_COUNT then
        local bId = v.berryId
        if bId == "BERRY" then bId = "ORAN_BERRY" end
        out[plotKey(idx)] = {
          berryId = bId,
          numericId = v.numericId or BerryFarmGame3.GBA_BERRIES[bId],
          plantedAtSteps = v.plantedAtSteps or 0,
        }
      end
    end
  end
  return out
end

local function writePlots(mod, plots)
  local Host = require("mods.Kanto-Reforged.core.host")
  local stored = {}
  for i = 1, BerryFarmGame3.PLOT_COUNT do
    local p = plots[plotKey(i)]
    if p and p.berryId then
      stored[plotKey(i)] = {
        berryId = p.berryId,
        numericId = p.numericId or BerryFarmGame3.GBA_BERRIES[p.berryId],
        plantedAtSteps = p.plantedAtSteps or 0,
      }
    end
  end
  Host.saveSet(mod.save, "plots", stored)
  return stored
end

local function ensureState(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local steps = Host.saveGet(mod.save, "farmSteps", 0)
  if type(steps) ~= "number" then steps = 0 end
  local plots = readPlots(Host.saveGet(mod.save, "plots", nil))
  if Host.saveGet(mod.save, "plots", nil) == nil then
    writePlots(mod, plots)
  end
  return steps, plots
end

BerryFarmGame3.ensureState = ensureState

function BerryFarmGame3.getPlot(plots, plotIndex)
  return plots[plotKey(plotIndex)]
end

function BerryFarmGame3.setPlot(mod, plots, plotIndex, entry)
  plots[plotKey(plotIndex)] = entry
  return writePlots(mod, plots)
end

function BerryFarmGame3.clearPlot(mod, plots, plotIndex)
  plots[plotKey(plotIndex)] = nil
  return writePlots(mod, plots)
end

function BerryFarmGame3.plotReady(mod, plotIndex)
  local steps, plots = ensureState(mod)
  local p = BerryFarmGame3.getPlot(plots, plotIndex)
  if not p or not p.berryId then return false end
  return (steps - (p.plantedAtSteps or 0)) >= BerryFarmGame3.growSteps(mod)
end

function BerryFarmGame3.stepsRemaining(mod, plotIndex)
  local steps, plots = ensureState(mod)
  local p = BerryFarmGame3.getPlot(plots, plotIndex)
  if not p or not p.berryId then return 0 end
  local left = BerryFarmGame3.growSteps(mod) - (steps - (p.plantedAtSteps or 0))
  return math.max(0, left)
end

function BerryFarmGame3.bumpStep(mod)
  mod = mod or BerryFarmGame3._mod
  if not mod then return end
  local Host = require("mods.Kanto-Reforged.core.host")
  local steps = Host.saveGet(mod.save, "farmSteps", 0) or 0
  Host.saveSet(mod.save, "farmSteps", steps + 1)
end

local function resolveBag(save)
  if type(save) ~= "table" then return nil end
  if save.pockets then return save end
  if type(save.bag) == "table" and save.bag.pockets then return save.bag end
  local Field = package.loaded["src.core.game3.field"]
  if Field and Field._session and Field._session.bag then
    return Field._session.bag
  end
  return nil
end

-- Gen4 KR rewards → closest native FRLG hold items (cart has no Life Orb / Focus Sash).
BerryFarmGame3.KR_ITEM_ALIASES = {
  LIFE_ORB = 200,       -- LEFTOVERS
  FOCUS_SASH = 196,     -- FOCUS_BAND
  BLACKGLASSES = 206,   -- BLACK_GLASSES
  BLACK_GLASSES = 206,
}

local function resolveNumericItemId(itemId)
  if itemId == nil then return nil end
  local num = BerryFarmGame3.GBA_BERRIES[itemId] or tonumber(itemId)
  if num then return num end
  local key = tostring(itemId):upper():gsub("%s+", "_"):gsub("^ITEM_", "")
  if BerryFarmGame3.KR_ITEM_ALIASES[key] then
    return BerryFarmGame3.KR_ITEM_ALIASES[key]
  end
  -- Prefer pret constants (no ROM pack required). ItemsData pack is optional.
  local okC, Items = pcall(require, "src.core.game3.constants.firered.items")
  if okC and Items then
    local byName = Items.byName
    if type(byName) == "table" then
      local n = byName["ITEM_" .. key] or byName[key]
      if n then return n end
    end
    local n = Items["ITEM_" .. key] or Items[key]
    if n then return n end
  end
  local okId, ItemsData = pcall(require, "src.core.game3.items_data")
  if okId and ItemsData then
    local byHost = ItemsData.BY_HOST and ItemsData.BY_HOST[key]
    if byHost and byHost.frlg then return byHost.frlg end
    if ItemsData.toNumericId then
      local ok, n = pcall(ItemsData.toNumericId, itemId)
      if ok and n then return n end
      ok, n = pcall(ItemsData.toNumericId, key)
      if ok and n then return n end
    end
  end
  return nil
end

BerryFarmGame3.resolveNumericItemId = resolveNumericItemId

local function bagGetItemCount(save, itemId)
  if type(save) ~= "table" then return 0 end
  local numId = resolveNumericItemId(itemId)
  local bag = resolveBag(save)
  local okBag, Bag = pcall(require, "src.core.game3.bag")
  -- Host API is Bag.get (no Bag.count). Pocket bags are the live FRLG path.
  if okBag and Bag and Bag.get and bag and numId then
    local c = Bag.get(bag, numId)
    if c and c > 0 then return c end
  end

  local inv = save.inventory or (save.bag and save.bag.berries) or save.bag
  if type(inv) ~= "table" then return 0 end
  local count = (inv[itemId] or 0)
  if numId and inv[numId] then
    count = count + inv[numId]
  end
  return count
end

local function bagRemoveItem(save, itemId, qty)
  qty = qty or 1
  if type(save) ~= "table" then return false end
  local numId = resolveNumericItemId(itemId)
  local bag = resolveBag(save)
  local okBag, Bag = pcall(require, "src.core.game3.bag")
  if okBag and Bag and Bag.remove and bag and numId then
    if Bag.remove(bag, numId, qty) then
      return true
    end
  end

  local inv = save.inventory or (save.bag and save.bag.berries) or save.bag
  if type(inv) == "table" then
    if inv[itemId] and inv[itemId] >= qty then
      inv[itemId] = inv[itemId] - qty
      if inv[itemId] <= 0 then inv[itemId] = nil end
      return true
    elseif numId and inv[numId] and inv[numId] >= qty then
      inv[numId] = inv[numId] - qty
      if inv[numId] <= 0 then inv[numId] = nil end
      return true
    end
  end
  return false
end

local function bagAddItem(save, itemId, qty)
  qty = qty or 1
  if type(save) ~= "table" then return false end
  local numId = resolveNumericItemId(itemId)
  local bag = resolveBag(save)
  local okBag, Bag = pcall(require, "src.core.game3.bag")
  if okBag and Bag and Bag.add and bag and numId then
    if Bag.add(bag, numId, qty) then
      return true
    end
  end

  local inv = save.inventory or (save.bag and save.bag.berries) or save.bag
  if type(inv) ~= "table" then
    if type(save.inventory) == "nil" and type(save.bag) == "nil" then
      save.inventory = {}
      inv = save.inventory
    end
  end
  if type(inv) == "table" then
    if numId then
      inv[numId] = (inv[numId] or 0) + qty
      return true
    else
      inv[itemId] = (inv[itemId] or 0) + qty
      return true
    end
  end
  return false
end

BerryFarmGame3.bagGetItemCount = bagGetItemCount
BerryFarmGame3.bagRemoveItem = bagRemoveItem
BerryFarmGame3.bagAddItem = bagAddItem

local function showMsg(game, msg, done)
  local okM, Message = pcall(require, "src.ui.game3.message")
  if okM and Message and Message.show then
    Message.show(msg, done)
    return
  end
  local okBox, TextBox = pcall(require, "src.render.TextBox")
  if okBox and TextBox and game and game.stack then
    game.stack:push(TextBox.new(game, msg, done))
    return
  end
  if done then done() end
end

local function showYesNo(game, msg, onChoice)
  local okM, Message = pcall(require, "src.ui.game3.message")
  local okC, Choice = pcall(require, "src.ui.game3.choice")
  if okM and Message and Message.show and okC and Choice and Choice.yesNo then
    -- Keep the prompt on screen (hold) while YES/NO is up. Closing the
    -- message first leaves OmniUI drawing Choice as a blank "A Close" box.
    Message.show(msg, {
      hold = true,
      done = function()
        Choice.yesNo(function(yes)
          if Message.close then Message.close() end
          if onChoice then onChoice(yes == true or yes == 0) end
        end)
      end,
    })
    return
  end
  local okBox, TextBox = pcall(require, "src.render.TextBox")
  if okBox and TextBox and game and game.stack then
    game.stack:push(TextBox.new(game, msg, nil, { choice = onChoice }))
    return
  end
  if onChoice then onChoice(false) end
end

BerryFarmGame3.showYesNo = showYesNo

local function showListMenu(game, title, rows, onPick, onCancel)
  local okC, Choice = pcall(require, "src.ui.game3.choice")
  local okM, Message = pcall(require, "src.ui.game3.message")
  local okWin, Window = pcall(require, "src.ui.game3.window")
  local okFont, FrlgFont = pcall(require, "src.ui.game3.frlg_font")

  if okC and Choice and okM and Message and Message.show and okWin and Window and okFont and FrlgFont then
    local labels = {}
    for _, r in ipairs(rows) do
      labels[#labels + 1] = r.label or r.name or tostring(r.value or "")
    end
    labels[#labels + 1] = "CANCEL"
    local n = #labels

    Message.show(title, function()
      local maxShowed = math.min(5, n)
      local cursor = 1
      local scroll = 0
      local frames = 0

      local origMove = Choice.move
      local origConfirm = Choice.confirm
      local origCancel = Choice.cancel
      local origDraw = Choice.draw
      local isWrapped = true

      local function restore()
        if not isWrapped then return end
        isWrapped = false
        Choice.move = origMove
        Choice.confirm = origConfirm
        Choice.cancel = origCancel
        Choice.draw = origDraw
      end

      local function playSelectSe()
        pcall(function()
          local Audio = require("src.core.game3.audio")
          local SE = require("src.core.game3.se_ids")
          if Audio and Audio.playSe and SE and SE.SE_SELECT then
            Audio.playSe(SE.SE_SELECT)
          end
        end)
      end

      Choice.active = true
      Choice.kind = "multi"
      Choice.options = labels
      Choice.cursor = 1

      Choice.move = function(dy, dx)
        local delta = dy or 0
        if delta == 0 and dx then delta = dx end
        if delta == 0 then return end

        if delta > 0 then
          if cursor < n then
            cursor = cursor + 1
            if cursor > scroll + maxShowed then
              scroll = cursor - maxShowed
            end
          else
            cursor = 1
            scroll = 0
          end
          playSelectSe()
        elseif delta < 0 then
          if cursor > 1 then
            cursor = cursor - 1
            if cursor <= scroll then
              scroll = cursor - 1
            end
          else
            cursor = n
            scroll = n - maxShowed
          end
          playSelectSe()
        end
        Choice.cursor = cursor
      end

      Choice.confirm = function()
        playSelectSe()
        restore()
        Choice.active = false
        Choice.kind = nil
        Choice.options = nil
        local chosenIdx = cursor
        if chosenIdx > 0 and chosenIdx <= #rows then
          if onPick then onPick(rows[chosenIdx]) end
        else
          if onCancel then onCancel() end
        end
      end

      Choice.cancel = function()
        playSelectSe()
        restore()
        Choice.active = false
        Choice.kind = nil
        Choice.options = nil
        if onCancel then onCancel() end
      end

      -- Geometry calculation: keep window fully on screen above dialogue box
      local maxLabelLen = 0
      for _, lab in ipairs(labels) do
        local l = FrlgFont.measure(lab)
        if l > maxLabelLen then maxLabelLen = l end
      end
      local contentTiles = math.ceil((maxLabelLen + 32) / 8)
      local tw = math.max(14, math.min(20, contentTiles))
      local th = maxShowed * 2 + 2 -- 5 items * 2 + 2 = 12 tiles
      local tx = 30 - tw - 1       -- Right aligned with 1-tile margin
      local ty = 1                 -- Row 1, so ty + th = 13 (leaves 2 tiles before dialogue at 15)

      local tpl = Window.template(tx, ty, tw, th)

      Choice.draw = function()
        if not Choice.active then return end
        frames = frames + 1

        -- 1. Draw complete frame
        Window.stdFrame(tpl)

        -- 2. Draw visible items
        local ox = tx * 8
        local leftPx = ox + 8
        for i = 1, maxShowed do
          local itemIdx = scroll + i
          if itemIdx <= n then
            local lab = labels[itemIdx]
            local rowY = (ty + 1) * 8 + (i - 1) * 16
            if itemIdx == cursor then
              Window.cursorPx(leftPx, rowY)
            end
            FrlgFont.draw(lab, leftPx + 8, rowY, { colors = FrlgFont.COLOR.NORMAL })
          end
        end

        -- 3. Draw scroll arrows if list exceeds maxShowed
        if n > maxShowed then
          local okLm, ListMenu = pcall(require, "src.ui.game3.list_menu")
          if okLm and ListMenu and ListMenu.drawScrollArrows then
            ListMenu.drawScrollArrows(tpl, scroll > 0, scroll < n - maxShowed, frames)
          else
            local cx = (tx + tw / 2) * 8
            if scroll > 0 then
              FrlgFont.drawGlyph(FrlgFont.CHAR_UP_ARROW, cx - 4, ty * 8 + 2, { colors = FrlgFont.COLOR.NORMAL })
            end
            if scroll < n - maxShowed then
              FrlgFont.drawGlyph(FrlgFont.CHAR_DOWN_ARROW, cx - 4, (ty + th) * 8 - 10, { colors = FrlgFont.COLOR.NORMAL })
            end
          end
        end
      end
    end)
    return
  end
  local okMenu, ListMenu = pcall(require, "src.ui.ListMenu")
  if okMenu and ListMenu and game and game.stack then
    game.stack:push(ListMenu.new(game, Strings(title), rows, {
      onChoose = function(row, menu)
        if menu and menu.close then menu:close() end
        if onPick then onPick(row) end
      end,
      onCancel = onCancel,
    }))
    return
  end
  if onCancel then onCancel() end
end

local function openBerryShop(game, stock, done)
  local okShop, ShopMenu = pcall(require, "src.ui.game3.shop_menu")
  if okShop and ShopMenu and ShopMenu.show then
    local items = {}
    for _, id in ipairs(stock) do
      local numId = BerryFarmGame3.GBA_BERRIES[id]
      items[#items + 1] = numId or id
    end
    -- Specialty breeding incenses (accessible from any Pokecenter PC)
    items[#items + 1] = 220 -- ITEM_SEA_INCENSE (for Azurill breeding)
    items[#items + 1] = 221 -- ITEM_LAX_INCENSE (for Wynaut breeding)

    local session = (game and game.session) or (game and game.save)
      or (package.loaded["src.core.game3.runtime"] and package.loaded["src.core.game3.runtime"].session)
      or (package.loaded["src.core.game3.field"] and package.loaded["src.core.game3.field"]._session)
    ShopMenu.show({
      items = items,
      session = session,
      onClose = done,
    })
    return
  end
  local okMenu, ListMenu = pcall(require, "src.ui.ListMenu")
  if okMenu and ListMenu and game and game.stack then
    local rows = {}
    for _, id in ipairs(stock) do
      rows[#rows + 1] = {
        label = id:gsub("_", " ") .. " - ¥200",
        value = id,
      }
    end
    rows[#rows + 1] = {
      label = "SEA INCENSE - ¥1000",
      value = 220,
    }
    rows[#rows + 1] = {
      label = "LAX INCENSE - ¥1000",
      value = 221,
    }
    game.stack:push(ListMenu.new(game, Strings("Buy Berries"), rows, {
      onChoose = function(row, menu)
        menu:close()
        bagAddItem(game.save, row.value, 1)
        local valName = (type(row.value) == "number") and ((row.value == 220 and "SEA INCENSE") or (row.value == 221 and "LAX INCENSE")) or tostring(row.value):gsub("_", " ")
        showMsg(game, Strings("Bought 1 %s!", valName), done)
      end,
      onCancel = done,
    }))
    return
  end
  if done then done() end
end

local function plotIndexAt(cx, cy)
  for i, r in ipairs(BerryFarmGame3.PLOT_RECTS) do
    if cx >= r.x0 and cx <= r.x1 and cy >= r.y0 and cy <= r.y1 then
      return i
    end
  end
  return nil
end

local function openPlantingBerryPouch(session, bag, onPlant, onCancel)
  local okPouch, BerryPouch = pcall(require, "src.ui.game3.berry_pouch")
  if not (okPouch and BerryPouch and BerryPouch.show and bag) then
    return false
  end

  local okWin, Window = pcall(require, "src.ui.game3.window")
  local okFont, FrlgFont = pcall(require, "src.ui.game3.frlg_font")
  local okItems, ItemsData = pcall(require, "src.core.game3.items_data")
  local okRom, RomText = pcall(require, "src.core.game3.rom_text")
  local SE_SELECT = 5
  pcall(function()
    local okSe, SE = pcall(require, "src.core.game3.se_ids")
    if okSe and SE and SE.SE_SELECT then SE_SELECT = SE.SE_SELECT end
  end)

  local function playSe(id)
    pcall(function()
      local Audio = require("src.core.game3.audio")
      if Audio and Audio.playSe then Audio.playSe(id) end
    end)
  end

  local isWrapped = true
  local origHandleInput = BerryPouch.handleInput
  local origDraw = BerryPouch.draw
  local origClose = BerryPouch.close
  local origActions = BerryPouch.ACTIONS

  local function restorePouch()
    if not isWrapped then return end
    isWrapped = false
    BerryPouch.handleInput = origHandleInput
    BerryPouch.draw = origDraw
    BerryPouch.close = origClose
    BerryPouch.ACTIONS = origActions
    BerryPouch._plantMode = false
    BerryPouch._location = nil
    BerryPouch.location = nil
  end

  BerryPouch.close = function()
    restorePouch()
    origClose()
    if onCancel then
      local cb = onCancel
      onCancel = nil
      cb()
    end
  end

  BerryPouch.handleInput = function(input)
    if BerryPouch.mode == "action" then
      local rows = BerryPouch.list and BerryPouch.list() or {}
      local row = rows[BerryPouch.cursor]

      if input:wasPressed("up") or input:wasPressed("down") then
        BerryPouch.actionCursor = (BerryPouch.actionCursor == 1) and 2 or 1
        playSe(SE_SELECT)
      elseif input:wasPressed("a") then
        playSe(SE_SELECT)
        if BerryPouch.actionCursor == 1 then
          -- PLANT
          local chosenRow = row
          onCancel = nil
          restorePouch()
          BerryPouch.close()
          if onPlant and chosenRow then
            onPlant(chosenRow.id, chosenRow)
          end
          return
        else
          -- CANCEL: return to berry list
          BerryPouch.mode = "list"
          return
        end
      elseif input:wasPressed("b") then
        playSe(SE_SELECT)
        BerryPouch.mode = "list"
        return
      end
      return
    end

    return origHandleInput(input)
  end

  BerryPouch.draw = function()
    if not BerryPouch.open then return end
    if BerryPouch.mode == "action" then
      local rows = BerryPouch.list and BerryPouch.list() or {}
      local sel = rows[BerryPouch.cursor]
      if sel and okWin and Window and okFont and FrlgFont then
        -- Render list mode background and contents so 4-item action menu is suppressed
        BerryPouch.mode = "list"
        origDraw()
        BerryPouch.mode = "action"

        local bName = sel.name or (okItems and ItemsData and ItemsData.displayName and ItemsData.displayName(sel.id)) or tostring(sel.id)

        -- WIN 6: Selected message
        Window.stdFrame(Window.template(6, 15, 14, 4))
        local selMsg = (okRom and RomText and RomText.box and RomText.box("gText_Var1IsSelected", { stringVars = { bName } }))
          or (bName .. " is selected.")
        FrlgFont.draw(selMsg, 52, 124, { colors = FrlgFont.COLOR.NORMAL, linePitch = 14 })

        -- 2-item Action Menu (WIN: tilemapLeft=22, tilemapTop=15, width=7, height=4)
        Window.stdFrame(Window.template(22, 15, 7, 4))
        local rowY1 = 124
        local rowY2 = 140
        if BerryPouch.actionCursor == 1 then
          Window.cursorPx(177, rowY1)
        else
          Window.cursorPx(177, rowY2)
        end
        FrlgFont.draw("PLANT", 185, rowY1, { colors = FrlgFont.COLOR.NORMAL })
        FrlgFont.draw("CANCEL", 185, rowY2, { colors = FrlgFont.COLOR.NORMAL })
        return
      end
    end

    return origDraw()
  end

  BerryPouch.show(session, bag, {
    plant = true,
    location = "berry_tree",
    onClose = function()
      restorePouch()
      if onCancel then
        local cb = onCancel
        onCancel = nil
        cb()
      end
    end,
  })
  BerryPouch._plantMode = true
  BerryPouch._location = "berry_tree"
  BerryPouch.location = "berry_tree"
  BerryPouch.ACTIONS = { "PLANT", "CANCEL" }
  return true
end

BerryFarmGame3.openPlantingBerryPouch = openPlantingBerryPouch

local function makePlotTalk(mod, plotIndex)
  return function(game, ow, npc, done)
    local steps, plots = ensureState(mod)
    local p = BerryFarmGame3.getPlot(plots, plotIndex)
    local session = (game and game.session) or (game and game.save) or (package.loaded["src.core.game3.field"] and package.loaded["src.core.game3.field"]._session)
    local bag = resolveBag(session) or resolveBag(game and game.save) or (session and session.bag)

    if not p or not p.berryId then
      local okBag, Bag = pcall(require, "src.core.game3.bag")
      local berryList = {}
      if okBag and Bag and bag and Bag.listPocket then
        berryList = Bag.listPocket(bag, "BERRY_POUCH") or {}
      end
      local totalBerries = #berryList
      if totalBerries == 0 then
        for _, id in ipairs(BerryFarmGame3.BERRY_PACK_GEN3) do
          if bagGetItemCount(game and game.save, id) > 0 then
            totalBerries = totalBerries + 1
          end
        end
      end

      if totalBerries == 0 then
        showMsg(game, Strings(
          "It's soft, loamy soil.\f"
          .. "Plant berries here\nand walk around to\vgrow them!"), done)
        return
      end

      showYesNo(game, Strings(
        "It's soft, loamy soil.\nWould you like to\vplant a BERRY?"), function(yes)
        if not yes then
          if done then done() end
          return
        end

        local opened = openPlantingBerryPouch(session, bag, function(chosenBerryId, row)
          if not chosenBerryId then
            if done then done() end
            return
          end
          local numId = tonumber(chosenBerryId) or (row and tonumber(row.id))
          local okData, ItemsData = pcall(require, "src.core.game3.items_data")
          local berryName = (okData and numId and ItemsData.displayName(numId))
            or (row and row.name)
            or tostring(chosenBerryId)
          local constName = (numId and BerryFarmGame3.BERRY_BY_ID[numId]) or tostring(chosenBerryId)

          bagRemoveItem(game and game.save, chosenBerryId, 1)

          local _, live = ensureState(mod)
          local Host = require("mods.Kanto-Reforged.core.host")
          BerryFarmGame3.setPlot(mod, live, plotIndex, {
            berryId = constName,
            numericId = numId,
            plantedAtSteps = Host.saveGet(mod.save, "farmSteps", 0),
          })
          BerryFarmGame3.syncPlotMarkers(mod)

          showMsg(game, Strings("Planted the\n%s in the soft soil!", berryName), done)
        end, function()
          if done then done() end
        end)

        if not opened then
          local rows = {}
          for _, id in ipairs(BerryFarmGame3.BERRY_PACK_GEN3) do
            local n = bagGetItemCount(game and game.save, id)
            if n > 0 then
              rows[#rows + 1] = {
                value = id,
                label = id:gsub("_", " ") .. " x" .. tostring(n),
                name = id:gsub("_", " "),
              }
            end
          end
          showListMenu(game, "Plant which berry?", rows, function(row)
            local id = row.value
            bagRemoveItem(game and game.save, id, 1)
            local _, live = ensureState(mod)
            local Host = require("mods.Kanto-Reforged.core.host")
            BerryFarmGame3.setPlot(mod, live, plotIndex, {
              berryId = id,
              numericId = BerryFarmGame3.GBA_BERRIES[id],
              plantedAtSteps = Host.saveGet(mod.save, "farmSteps", 0),
            })
            BerryFarmGame3.syncPlotMarkers(mod)
            showMsg(game, Strings("Planted the\n%s!", id:gsub("_", " ")), done)
          end, done)
        end
      end)
      return
    end

    if not BerryFarmGame3.plotReady(mod, plotIndex) then
      local need = BerryFarmGame3.growSteps(mod)
      local left = BerryFarmGame3.stepsRemaining(mod, plotIndex)
      local okData, ItemsData = pcall(require, "src.core.game3.items_data")
      local numId = p.numericId or BerryFarmGame3.GBA_BERRIES[p.berryId]
      local berryName = (okData and numId and ItemsData.displayName(numId)) or p.berryId:gsub("_", " ")
      local BerryFarm = require("mods.Kanto-Reforged.world.berry_farm")
      showMsg(game, Strings(
        "%s\nis growing nicely!\f%s",
        berryName, BerryFarm.growthPhrase(need - left, need)), done)
      return
    end

    local yield = BerryFarmGame3.HARVEST_YIELD
    local numId = p.numericId or BerryFarmGame3.GBA_BERRIES[p.berryId]
    local okData, ItemsData = pcall(require, "src.core.game3.items_data")
    local berryName = (okData and numId and ItemsData.displayName(numId)) or p.berryId:gsub("_", " ")
    local playerName = (session and (session.name or session.playerName)) or (game and game.save and game.save.playerName) or "PLAYER"

    showYesNo(game, Strings(
      "There are %d %s!\nWould you like to\vpick the %s?",
      yield, berryName, berryName), function(yes)
      if not yes then
        showMsg(game, Strings("The %s\nwere left on the plant.", berryName), done)
        return
      end

      if not bagAddItem(game and game.save, numId or p.berryId, yield) then
        showMsg(game, Strings("Your BERRY POUCH\nis full! The %s\ncouldn't be picked.", berryName), done)
        return
      end

      local _, live = ensureState(mod)
      BerryFarmGame3.clearPlot(mod, live, plotIndex)
      BerryFarmGame3.syncPlotMarkers(mod)

      showMsg(game, Strings(
        "%s picked the\n%d %s!\f"
        .. "%s put away the\n%s in the\vBERRY POUCH.\f"
        .. "The soil returned to\nits soft and loamy state.",
        playerName, yield, berryName,
        playerName, berryName), done)
    end)
  end
end

BerryFarmGame3.makePlotTalk = makePlotTalk

local function makeScholarTalk()
  return function(game, ow, npc, done)
    local rows = {}
    for _, entry in ipairs(BerryFarmGame3.SCHOLAR_ENTRIES) do
      rows[#rows + 1] = {
        label = entry.name,
        value = entry,
      }
    end
    showMsg(game, Strings(
      "I'm the BERRY\nSCHOLAR!\f"
      .. "Ask me about any\nberry we grow."), function()
      showListMenu(game, "Which berry?", rows, function(row)
        showMsg(game, Strings(row.value.blurb), done)
      end, done)
    end)
  end
end

local function makeSoilExpertTalk(mod)
  return function(game, ow, npc, done)
    local Host = require("mods.Kanto-Reforged.core.host")
    local BerryQuests = require("mods.Kanto-Reforged.world.berry_quests")
    local newly = BerryQuests.applyBadgeUnlocks(mod, game, { gift = true })
    local rank = Host.saveGet(mod.save, "soil_rank", 0) or 0
    local msg = Strings("I study berry soil.\f")
    if #newly > 0 then
      msg = msg .. Strings(
        "New berries unlocked\nfrom your badges!\f"
          .. "I packed %dx of each.\f"
          .. "Buy more at the\nstall anytime!\f",
        BerryQuests.UNLOCK_SEED_GIFT)
    end

    local dex = (game and game.session and game.session.pokedex) or (game and game.save and game.save.pokedex) or {}
    local owned = dex.owned or dex.caught or {}
    local caughtCount = 0
    for _ in pairs(owned) do caughtCount = caughtCount + 1 end

    local party = (game and game.session and game.session.party) or (game and game.save and game.save.party) or {}
    local pokemon = (game and game.data and game.data.pokemon) or {}
    local hasGrass20 = false
    for _, mon in ipairs(party) do
      if mon and (mon.level or 0) >= 20 then
        local def = pokemon[mon.species]
        local types = def and (def.types or { def.type1, def.type2 }) or {}
        for _, t in ipairs(types) do
          if t == "GRASS" then hasGrass20 = true break end
        end
      end
    end

    local berryTypes = 0
    local curSave = (game and game.save) or (game and game.session)
    for _, id in ipairs(BerryFarmGame3.BERRY_PACK_GEN3) do
      if bagGetItemCount(curSave, id) > 0 then
        berryTypes = berryTypes + 1
      end
    end

    if rank < 1 and caughtCount >= 5 then
      Host.saveSet(mod.save, "soil_rank", 1)
      rank = 1
      msg = msg .. Strings("Rank 1! Berries\ngrow a bit faster.\f")
    elseif rank < 2 and hasGrass20 then
      Host.saveSet(mod.save, "soil_rank", 2)
      rank = 2
      msg = msg .. Strings("Rank 2! Even\nfaster growth.\f")
    elseif rank < 3 and berryTypes >= 3 then
      Host.saveSet(mod.save, "soil_rank", 3)
      rank = 3
      msg = msg .. Strings("Rank 3! Top soil\nand cooler blender.\f")
    else
      msg = msg .. Strings("Current soil rank:\n%d\fKeep collecting!", rank)
    end
    showMsg(game, msg, done)
  end
end

local function makeMerchantTalk(mod)
  return function(game, ow, npc, done)
    local BerryQuests = require("mods.Kanto-Reforged.world.berry_quests")
    BerryQuests.applyBadgeUnlocks(mod, game, { gift = true })
    local stock = BerryFarmGame3.plantableList(mod)
    if #stock == 0 then
      showMsg(game, Strings(
        "No berries in stock\nyet.\fTalk to the soil\nexpert after gyms!"), done)
      return
    end
    showMsg(game, Strings(
      "Berry stall!\f"
        .. "I sell berries you\nhave unlocked.\f"
        .. "Growing more on the\nplots is cheaper."), function()
      openBerryShop(game, stock, done)
    end)
  end
end

function BerryFarmGame3.isPokecenter1F(mapId)
  if not mapId then return false end
  for _, id in ipairs(BerryFarmGame3.ALL_POKECENTERS_GEN3) do
    if id == mapId then return true end
  end
  local upper = tostring(mapId):upper()
  return (upper:find("POKECENTER") or upper:find("POKEMON_CENTER")) and (upper:find("1F") or not upper:find("2F"))
end

function BerryFarmGame3.isBerryFarmMap(mapId)
  return mapId == BerryFarmGame3.MAP_ID or mapId == BerryFarmGame3.MAP_ID_ALIAS
end

function BerryFarmGame3.patchPokecenterLayout(layout)
  if not layout or not layout.applyOverride then return end
  local M = BerryFarmGame3.RED_MAT_MIDS
  -- Top row (y=8): walkable floor mat visuals, not warp trigger (coll = 0)
  layout:applyOverride(2, 8, M.TOP_L, 0, 0)
  layout:applyOverride(3, 8, M.TOP_M, 0, 0)
  layout:applyOverride(4, 8, M.TOP_R, 0, 0)
  -- Bottom row (y=9): warp trigger into row below (coll = 114)
  layout:applyOverride(2, 9, M.BOT_L, 114, 0)
  layout:applyOverride(3, 9, M.BOT_M, 114, 0)
  layout:applyOverride(4, 9, M.BOT_R, 114, 0)
end

function BerryFarmGame3.patchPokecenterDef(mapDef)
  if not mapDef then return end
  if mapDef.midLayout then
    BerryFarmGame3.patchPokecenterLayout(mapDef.midLayout)
  end
  mapDef.warps = mapDef.warps or {}
  local hasWarp = false
  for _, w in ipairs(mapDef.warps) do
    if (w.x == 3 and w.y == 9) or (w.destMap == BerryFarmGame3.MAP_ID) then
      hasWarp = true
      break
    end
  end
  if not hasWarp then
    for _, x in ipairs({ 2, 3, 4 }) do
      table.insert(mapDef.warps, {
        x = x,
        y = 9,
        destMap = BerryFarmGame3.MAP_ID,
        destWarp = 1,
      })
    end
  end
end

function BerryFarmGame3.patchActiveMap(mapId)
  if not BerryFarmGame3.isPokecenter1F(mapId) then return end
  local okMap, Map = pcall(require, "src.core.game3.map")
  if okMap and Map then
    local curDef = Map.currentDef and Map.currentDef()
    if curDef then BerryFarmGame3.patchPokecenterDef(curDef) end
    if Map._def then BerryFarmGame3.patchPokecenterDef(Map._def) end
    if Map._currentDef then BerryFarmGame3.patchPokecenterDef(Map._currentDef) end
  end
end

local function repairLayout(layout)
  if not layout then return nil end
  local LayoutNative = require("src.core.game3.layout_native")
  setmetatable(layout, LayoutNative)
  layout.collArray = layout.collArray or LayoutNative.collArray
  layout.cellAt = layout.cellAt or LayoutNative.cellAt
  layout.midAt = layout.midAt or LayoutNative.midAt
  layout.collAt = layout.collAt or LayoutNative.collAt
  layout.elevAt = layout.elevAt or LayoutNative.elevAt
  layout.applyOverride = layout.applyOverride or LayoutNative.applyOverride
  layout.clearOverrides = layout.clearOverrides or LayoutNative.clearOverrides
  for k, v in pairs(LayoutNative) do
    if type(v) == "function" then
      layout[k] = v
    end
  end
  return layout
end

BerryFarmGame3.repairLayout = repairLayout

function BerryFarmGame3.buildFarmLayout()
  local LayoutNative = require("src.core.game3.layout_native")
  local w, h = BerryFarmGame3.WIDTH, BerryFarmGame3.HEIGHT
  local cells = {}

  for cy = 0, h - 1 do
    for cx = 0, w - 1 do
      local mid = 662 -- Pallet outdoor grass
      local coll = 0x00 -- 0x00 = Land (walkable)

      local isBorder = (cx <= 1 or cx >= w - 2 or cy <= 1 or cy >= h - 2)
      local isCottage = (cx >= 6 and cx <= 10 and cy >= 3 and cy <= 7)
      local isPond = (cx >= 22 and cx <= 35 and cy >= 4 and cy <= 19)

      if isBorder then
        if cy == 0 then
          -- Top-most border row: trunks continuing from top void
          mid = (cx % 2 == 0) and 28 or 29
        elseif cy == 1 then
          -- Top border delimiter: authentic pine tree canopy tops facing the farm grass at cy=2
          if cx <= 1 or cx >= w - 2 then
            mid = (cx % 2 == 0) and 20 or 21
          elseif cx == 2 then
            mid = 38 -- Top-left inner canopy corner
          elseif cx == w - 3 then
            mid = 39 -- Top-right inner canopy corner
          else
            mid = (cx % 2 == 0) and 36 or 37 -- Clean pine canopy tops facing south
          end
        elseif cy == h - 2 then
          -- Bottom border delimiter: authentic pine tree trunks resting on the farm grass at cy=21
          if cx <= 1 then
            mid = (cx == 0) and 28 or 31
          elseif cx >= w - 2 then
            mid = (cx == w - 2) and 30 or 29
          else
            mid = (cx % 2 == 0) and 30 or 31 -- Clean tree trunks resting on grass
          end
        elseif cy == h - 1 then
          -- Bottom-most border row: canopy tops continuing downward into bottom void
          mid = (cx % 2 == 0) and 20 or 21
        elseif cx <= 1 then
          -- Left border
          if cy % 2 == 0 then
            mid = (cx == 0) and 28 or 31 -- Left trunk on grass
          else
            mid = (cx == 0) and 20 or 23 -- Left canopy
          end
        elseif cx >= w - 2 then
          -- Right border
          if cy % 2 == 0 then
            mid = (cx == w - 2) and 30 or 29 -- Right trunk on grass
          else
            mid = (cx == w - 2) and 22 or 21 -- Right canopy
          end
        end
        coll = 0x07 -- 0x07 = Wall (impassable)
      elseif isCottage then
        if cy == 3 then
          local roofRow = { [6] = 641, [7] = 642, [8] = 642, [9] = 642, [10] = 643 }
          mid = roofRow[cx] or 642
          coll = 0x07
        elseif cy == 4 then
          local roofRow = { [6] = 649, [7] = 650, [8] = 650, [9] = 650, [10] = 651 }
          mid = roofRow[cx] or 650
          coll = 0x07
        elseif cy == 5 then
          local roofRow = { [6] = 657, [7] = 659, [8] = 658, [9] = 658, [10] = 660 }
          mid = roofRow[cx] or 658
          coll = 0x07
        elseif cy == 6 then
          local wallRow = { [6] = 664, [7] = 665, [8] = 666, [9] = 667, [10] = 668 }
          mid = wallRow[cx] or 665
          coll = 0x07
        elseif cy == 7 then
          if cx == BerryFarmGame3.EXIT.x then
            mid = 675 -- Farmhouse door with warp
            coll = 0x71 -- warp collision (113/114)
          else
            local wallRow = { [6] = 672, [7] = 675, [8] = 674, [9] = 673, [10] = 676 }
            mid = wallRow[cx] or 673
            coll = 0x07
          end
        end
      elseif isPond then
        if cy == 4 then
          mid = (cx == 22) and 721 or ((cx == 35) and 722 or 291)
        elseif cx == 22 then
          mid = 298 -- Left water edge
        elseif cx == 35 then
          mid = 300 -- Right water edge
        else
          mid = 299 -- Open animated water
        end
        coll = 0x29 -- 0x29 = Water (surfable water collision)
      -- Garden fence outline (x=4..19, y=10..20) using authentic Gen 3 white picket fence
      elseif cy == 10 and cx >= 4 and cx <= 19 then
        if cx == 11 or cx == 12 then
          mid = 662 -- Opening gate (walkable grass)
          coll = 0x00
        elseif cx == 4 then
          mid = 236 -- White picket fence top-left corner post
          coll = 0x07
        elseif cx == 10 then
          mid = 237 -- White picket fence gate post (right end before opening)
          coll = 0x07
        elseif cx == 13 then
          mid = 236 -- White picket fence gate post (left end after opening)
          coll = 0x07
        elseif cx == 19 then
          mid = 237 -- White picket fence top-right corner post
          coll = 0x07
        else
          mid = 231 -- White picket fence horizontal
          coll = 0x07
        end
      elseif cy == 20 and cx >= 4 and cx <= 19 then
        if cx == 4 then
          mid = 252 -- White picket fence bottom-left corner
          coll = 0x07
        elseif cx == 19 then
          mid = 253 -- White picket fence bottom-right corner
          coll = 0x07
        else
          mid = 231 -- White picket fence horizontal
          coll = 0x07
        end
      elseif cx == 4 and cy >= 11 and cy <= 19 then
        mid = 244 -- Clean left vertical white picket fence on grass
        coll = 0x07
      elseif cx == 19 and cy >= 11 and cy <= 19 then
        mid = 245 -- Clean right vertical white picket fence on grass
        coll = 0x07
      end

      cells[#cells + 1] = { mid = mid, coll = coll, elev = 0 }
    end
  end

  local decoded = {
    width = w,
    height = h,
    trueWidth = w,
    trueHeight = h,
    borderWidth = 2,
    borderHeight = 2,
    borderMids = { 28, 29, 20, 21 },
    cells = cells,
  }

  local layout = LayoutNative.fromDecoded(decoded, BerryFarmGame3.MAP_ID, "pallet_outdoor")
  return repairLayout(layout)
end

function BerryFarmGame3.buildFarmMapDef(mod)
  mod = mod or BerryFarmGame3._mod
  local farmLayout = BerryFarmGame3.buildFarmLayout()
  local destCenter = "FR_VIRIDIAN_CITY_POKEMON_CENTER_1F"

  local steps = 0
  local plots = {}
  local growNeed = BerryFarmGame3.GROW_STEPS
  if mod then
    steps, plots = ensureState(mod)
    growNeed = BerryFarmGame3.growSteps(mod)
  end

  local talk = {
    TEXT_BERRY_FARM_GIRL = function(game, ow, npc, done)
      showMsg(game, Strings(
        "Welcome to the\nBERRY FARM!\f"
        .. "Flower beds grow\nberries here.\f"
        .. "Face a bed and\npress A to plant.\f"
        .. "Walk around, then\ncome back later.\f"
        .. "Harvest when it's\nready!\f"
        .. "The shed door\ntakes you back to\f"
        .. "the POKéMON CENTER\nyou were at."), done)
    end,
    TEXT_BERRY_FARM_FISHER = function(game, ow, npc, done)
      showMsg(game, Strings(
        "Nice spot for a\nfarm, huh?\f"
        .. "You can SURF the\nlake if you want.\f"
        .. "Nothing's out\nthere to find."), done)
    end,
    TEXT_BERRY_FARM_SOIL_EXPERT = makeSoilExpertTalk(mod),
    TEXT_BERRY_FARM_SCHOLAR = makeScholarTalk(),
    TEXT_BERRY_FARM_MERCHANT = makeMerchantTalk(mod),
  }

  for i = 1, BerryFarmGame3.PLOT_COUNT do
    talk["TEXT_BERRY_PLOT_" .. i] = makePlotTalk(mod, i)
  end

  local objects = {
    {
      index = 1,
      localId = 1,
      name = "BERRY_FARM_GIRL",
      sprite = "SPRITE_WOMAN_1",
      graphicsId = 23, -- OBJ_EVENT_GFX_WOMAN_1
      graphics = 23,
      movementType = 8,
      movement = "LOOK_AROUND",
      range = "DOWN",
      scriptKey = "TEXT_BERRY_FARM_GIRL",
      text = "TEXT_BERRY_FARM_GIRL",
      elevation = 3,
      x = 11,
      y = 7,
    },
    {
      index = 2,
      localId = 2,
      name = "BERRY_FARM_FISHER",
      sprite = "SPRITE_FISHERMAN",
      graphicsId = 57, -- OBJ_EVENT_GFX_FISHER
      graphics = 57,
      movementType = 8,
      movement = "LOOK_AROUND",
      range = "RIGHT",
      scriptKey = "TEXT_BERRY_FARM_FISHER",
      text = "TEXT_BERRY_FARM_FISHER",
      elevation = 3,
      x = 21,
      y = 11,
    },
    {
      index = 3,
      localId = 3,
      name = "BERRY_FARM_SOIL_EXPERT",
      sprite = "SPRITE_SCIENTIST",
      graphicsId = 55, -- OBJ_EVENT_GFX_SCIENTIST
      graphics = 55,
      movementType = 8,
      movement = "LOOK_AROUND",
      range = "DOWN",
      scriptKey = "TEXT_BERRY_FARM_SOIL_EXPERT",
      text = "TEXT_BERRY_FARM_SOIL_EXPERT",
      elevation = 3,
      x = 16,
      y = 8,
    },
    {
      index = 4,
      localId = 4,
      name = "BERRY_FARM_SCHOLAR",
      sprite = "SPRITE_SCIENTIST",
      graphicsId = 55, -- OBJ_EVENT_GFX_SCIENTIST
      graphics = 55,
      movementType = 8,
      movement = "LOOK_AROUND",
      range = "RIGHT",
      scriptKey = "TEXT_BERRY_FARM_SCHOLAR",
      text = "TEXT_BERRY_FARM_SCHOLAR",
      elevation = 3,
      x = 3,
      y = 8,
    },
    {
      index = 5,
      localId = 5,
      name = "BERRY_FARM_MERCHANT",
      sprite = "SPRITE_CLERK",
      graphicsId = 68, -- OBJ_EVENT_GFX_CLERK
      graphics = 68,
      movementType = 8,
      movement = "LOOK_AROUND",
      range = "DOWN",
      scriptKey = "TEXT_BERRY_FARM_MERCHANT",
      text = "TEXT_BERRY_FARM_MERCHANT",
      elevation = 3,
      x = 8,
      y = 14,
    },
  }

  -- 9 Plot marker objects using custom plot sprites
  for i = 1, BerryFarmGame3.PLOT_COUNT do
    local r = BerryFarmGame3.PLOT_RECTS[i]
    local p = BerryFarmGame3.getPlot(plots, i)
    local spr = BerryFarmGame3.plotSpriteFor(steps, p, growNeed)
    objects[#objects + 1] = {
      index = 10 + i,
      localId = 10 + i,
      name = "BERRY_PLOT_MARK_" .. i,
      sprite = spr,
      graphicsId = nil,
      graphics = nil,
      movementType = 0,
      movement = "STAY",
      range = "NONE",
      scriptKey = "TEXT_BERRY_PLOT_" .. i,
      text = "TEXT_BERRY_PLOT_" .. i,
      elevation = 3,
      x = r.x0,
      y = r.y0,
    }
  end

  return {
    id = BerryFarmGame3.MAP_ID,
    label = "BerryFarm",
    index = 1100,
    tileset = "outdoor",
    pair = "pallet_outdoor",
    width = BerryFarmGame3.WIDTH,
    height = BerryFarmGame3.HEIGHT,
    midLayout = farmLayout,
    talk = talk,
    warps = {
      {
        x = BerryFarmGame3.LANDING.x,
        y = BerryFarmGame3.LANDING.y,
        destMap = destCenter,
        destWarp = 1,
      },
      {
        x = BerryFarmGame3.EXIT.x,
        y = BerryFarmGame3.EXIT.y,
        destMap = destCenter,
        destWarp = 1,
      },
    },
    objects = objects,
  }
end

function BerryFarmGame3.syncPlotMarkers(mod, gameRef)
  mod = mod or BerryFarmGame3._mod
  if not mod then return end
  BerryFarmGame3.registerPlotSprites(mod, gameRef)
  local steps, plots = ensureState(mod)
  local growNeed = BerryFarmGame3.growSteps(mod)
  local okO, Objects = pcall(require, "src.core.game3.objects")
  if okO and Objects then
    local function updateEo(eo)
      local name = (eo.def and eo.def.name) or eo.name
      if name and name:match("^BERRY_PLOT_MARK_%d+$") then
        local idx = tonumber(name:match("%d+"))
        if idx then
          local p = BerryFarmGame3.getPlot(plots, idx)
          local spr = BerryFarmGame3.plotSpriteFor(steps, p, growNeed)
          eo.sprite = spr
          if eo.def then
            eo.def.sprite = spr
            eo.def.graphicsId = nil
            eo.def.graphics = nil
          end
          eo.graphicsId = nil
        end
      end
    end

    if Objects._byId then
      for _, eo in pairs(Objects._byId) do
        updateEo(eo)
      end
    end
    if Objects.forDraw then
      for _, eo in ipairs(Objects.forDraw()) do
        updateEo(eo)
      end
    end
  end
  local okFv, FieldView = pcall(require, "src.core.game3.field_view")
  if okFv and FieldView and FieldView._spriteCache then
    for k in pairs(FieldView._spriteCache) do
      if tostring(k):find("SPRITE_PLOT_") then
        FieldView._spriteCache[k] = nil
      end
    end
  end
end

function BerryFarmGame3.register(mod)
  BerryFarmGame3.ensureUnlocked(mod)
  BerryFarmGame3.registerPlotSprites(mod)

  local farmMapDef = BerryFarmGame3.buildFarmMapDef(mod)

  if mod and mod.content and mod.content.maps then
    pcall(function()
      if mod.content.maps.register then
        mod.content.maps:register(BerryFarmGame3.MAP_ID, farmMapDef)
        mod.content.maps:register(BerryFarmGame3.MAP_ID_ALIAS, farmMapDef)
      end
    end)

    -- Patch all Gen 3 Pokécenters to append the farm door warps on row below (y=9)
    for _, centerId in ipairs(BerryFarmGame3.ALL_POKECENTERS_GEN3) do
      pcall(function()
        local newWarps = {}
        for _, x in ipairs({ 2, 3, 4 }) do
          newWarps[#newWarps + 1] = {
            x = x,
            y = 9,
            destMap = BerryFarmGame3.MAP_ID,
            destWarp = 1,
          }
        end
        mod.content.maps:patch(centerId, {
          warps = {
            __append = newWarps,
          },
        })
      end)
    end
  end

  -- Bind map directly onto Game3 Data registry if live
  local okData, Data = pcall(require, "src.core.Data")
  if okData and Data and Data.maps then
    Data.maps[BerryFarmGame3.MAP_ID] = farmMapDef
    Data.maps[BerryFarmGame3.MAP_ID_ALIAS] = farmMapDef
  end
end

function BerryFarmGame3.install(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local LayoutNative = require("src.core.game3.layout_native")
  BerryFarmGame3._mod = mod
  ensureState(mod)
  BerryFarmGame3.register(mod)

  local function syncFarmMapOnGame(game)
    local okData, Data = pcall(require, "src.core.Data")
    local farmMapDef = BerryFarmGame3.buildFarmMapDef(mod)

    if game and game.data then
      game.data.maps = game.data.maps or {}
      game.data.maps[BerryFarmGame3.MAP_ID] = farmMapDef
      game.data.maps[BerryFarmGame3.MAP_ID_ALIAS] = farmMapDef
    end

    if okData and Data and Data.maps then
      Data.maps[BerryFarmGame3.MAP_ID] = farmMapDef
      Data.maps[BerryFarmGame3.MAP_ID_ALIAS] = farmMapDef
    end

    BerryFarmGame3.registerPlotSprites(mod, game)
    BerryFarmGame3.syncPlotMarkers(mod, game)
  end

  -- Defensively wrap Collision.bindMap to guarantee midLayout is healthy & Pokécenters have warps + overrides
  local okColl, Collision = pcall(require, "src.core.game3.collision")
  if okColl and Collision and Collision.bindMap and not Collision._berryFarmWrapped then
    local origBindMap = Collision.bindMap
    Collision.bindMap = function(game, mapId, mapDef)
      if BerryFarmGame3.isBerryFarmMap(mapId) then
        mapDef = BerryFarmGame3.buildFarmMapDef(mod)
        if game and game.data and game.data.maps then
          game.data.maps[mapId] = mapDef
          game.data.maps[BerryFarmGame3.MAP_ID] = mapDef
          game.data.maps[BerryFarmGame3.MAP_ID_ALIAS] = mapDef
        end
      elseif mapDef and mapDef.midLayout then
        repairLayout(mapDef.midLayout)
      end

      if BerryFarmGame3.isPokecenter1F(mapId) and mapDef then
        BerryFarmGame3.patchPokecenterDef(mapDef)
      end

      local res = origBindMap(game, mapId, mapDef)

      if BerryFarmGame3.isPokecenter1F(mapId) then
        Collision._warps = Collision._warps or {}
        local farmWarp = { x = 3, y = 9, destMap = BerryFarmGame3.MAP_ID, destWarp = 1 }
        for _, x in ipairs({ 2, 3, 4 }) do
          Collision._warps[9 * 1024 + x] = farmWarp
          if Collision._grid and Collision._widthCells and Collision._widthCells > 0 then
            local idx = 9 * Collision._widthCells + x + 1
            Collision._grid[idx] = 114
          end
        end
      end

      return res
    end
    Collision._berryFarmWrapped = true
  end

  -- Defensively wrap Collision.tryWarpAt to guarantee instant warp when stepping on the mat
  if okColl and Collision and Collision.tryWarpAt and not Collision._berryFarmTryWarpWrapped then
    local origTryWarpAt = Collision.tryWarpAt
    Collision.tryWarpAt = function(game, cx, cy, facing, opts)
      local curMap = (game and game.currentMap) or (Collision._mapId)
      if BerryFarmGame3.isPokecenter1F(curMap) and (cx >= 2 and cx <= 4) and (cy == 9) then
        local Warp = require("src.core.game3.warp")
        if not Warp.isBusy() then
          local Runtime = package.loaded["src.core.game3.runtime"]
          local m = Runtime and Runtime._mod or mod
          local g = game or (Runtime and Runtime._game)
          Host.saveSet(mod.save, "returnCenter", {
            map = curMap,
            x = BerryFarmGame3.RETURN_CELL.x,
            y = BerryFarmGame3.RETURN_CELL.y,
          })
          syncFarmMapOnGame(g)
          Warp.request(m, g, BerryFarmGame3.MAP_ID, BerryFarmGame3.LANDING.x, BerryFarmGame3.LANDING.y, "down", {
            fade = true,
            door = false,
            doorX = cx,
            doorY = cy,
          })
          return true
        end
      elseif BerryFarmGame3.isBerryFarmMap(curMap) and (cx == BerryFarmGame3.EXIT.x and cy == BerryFarmGame3.EXIT.y) then
        local Warp = require("src.core.game3.warp")
        if not Warp.isBusy() then
          local Runtime = package.loaded["src.core.game3.runtime"]
          local m = Runtime and Runtime._mod or mod
          local g = game or (Runtime and Runtime._game)
          local ret = Host.saveGet(mod.save, "returnCenter", nil)
          local destMap = (ret and ret.map) or "FR_VIRIDIAN_CITY_POKEMON_CENTER_1F"
          local destX = (ret and ret.x) or BerryFarmGame3.RETURN_CELL.x
          local destY = (ret and ret.y) or BerryFarmGame3.RETURN_CELL.y
          Warp.request(m, g, destMap, destX, destY, "up", {
            fade = true,
            door = false,
            doorX = cx,
            doorY = cy,
          })
          return true
        end
      end
      return origTryWarpAt(game, cx, cy, facing, opts)
    end
    Collision._berryFarmTryWarpWrapped = true
  end

  -- Defensively wrap Map.load to ensure farm map def is present on game.data
  local okMap, Map = pcall(require, "src.core.game3.map")
  if okMap and Map and Map.load and not Map._berryFarmWrapped then
    local origLoad = Map.load
    Map.load = function(m, g, mapId, opts)
      if BerryFarmGame3.isBerryFarmMap(mapId) then
        local def = BerryFarmGame3.buildFarmMapDef(mod)
        if g and g.data then
          g.data.maps = g.data.maps or {}
          g.data.maps[BerryFarmGame3.MAP_ID] = def
          g.data.maps[BerryFarmGame3.MAP_ID_ALIAS] = def
          g.data.maps[mapId] = def
        end
        local okData, Data = pcall(require, "src.core.Data")
        if okData and Data and Data.maps then
          Data.maps[BerryFarmGame3.MAP_ID] = def
          Data.maps[BerryFarmGame3.MAP_ID_ALIAS] = def
          Data.maps[mapId] = def
        end
        BerryFarmGame3.registerPlotSprites(mod, g)
        BerryFarmGame3.syncPlotMarkers(mod, g)
      elseif BerryFarmGame3.isPokecenter1F(mapId) then
        if g and g.data and g.data.maps and g.data.maps[mapId] then
          BerryFarmGame3.patchPokecenterDef(g.data.maps[mapId])
        end
      end
      return origLoad(m, g, mapId, opts)
    end
    Map._berryFarmWrapped = true
  end

  -- Wrap Field.interact so that facing ANY tile of a 2x2 plot triggers the plot interaction
  local okFld, Field = pcall(require, "src.core.game3.field")
  if okFld and Field and Field.interact and not Field._berryFarmInteractWrapped then
    local origInteract = Field.interact
    Field.interact = function(game)
      game = game or Field._game
      local curMap = (game and game.session and game.session.map) or (Map and Map.current)
      if BerryFarmGame3.isBerryFarmMap(curMap) then
        local P = package.loaded["src.core.game3.player"]
        if P and not P.moving then
          local fx, fy
          if P.facing == "up" then fx, fy = P.cellX, P.cellY - 1
          elseif P.facing == "down" then fx, fy = P.cellX, P.cellY + 1
          elseif P.facing == "left" then fx, fy = P.cellX - 1, P.cellY
          elseif P.facing == "right" then fx, fy = P.cellX + 1, P.cellY
          end
          if fx and fy then
            local idx = plotIndexAt(fx, fy)
            if idx then
              local talkFn = makePlotTalk(mod, idx)
              talkFn(game, nil, nil, function() end)
              return true
            end
          end
        end
      end
      return origInteract(game)
    end
    Field._berryFarmInteractWrapped = true
  end

  local function grantStarterBerry(game)
    if not game or not game.save then return end
    BerryFarmGame3.ensureUnlocked(mod)
    if Host.saveGet(mod.save, "starterGranted", false) then return end
    bagAddItem(game.save, "ORAN_BERRY", 3)
    Host.saveSet(mod.save, "starterGranted", true)
  end

  -- Warp destination tracking
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("warp.destination", function(next, mapId, x, y, ctx)
      local Game = Host.liveGame(mod) or (ctx and ctx.data and { data = ctx.data, save = mod.save })
      if Game then syncFarmMapOnGame(Game) end
      local fromMap = ctx and ctx.lastMap
      local warp = ctx and ctx.warp

      -- Entering Berry Farm (either by target mapId == FR_BERRY_FARM/BERRY_FARM or stepping into row below PC door)
      if BerryFarmGame3.isBerryFarmMap(mapId) or (warp and BerryFarmGame3.isBerryFarmMap(warp.map))
          or (BerryFarmGame3.isPokecenter1F(fromMap) and (x >= 2 and x <= 4) and (y == 9)) then
        if fromMap and BerryFarmGame3.isPokecenter1F(fromMap) then
          Host.saveSet(mod.save, "returnCenter", {
            map = fromMap,
            x = BerryFarmGame3.RETURN_CELL.x,
            y = BerryFarmGame3.RETURN_CELL.y,
          })
        end
        if Game then syncFarmMapOnGame(Game) end
        return BerryFarmGame3.MAP_ID, BerryFarmGame3.LANDING.x, BerryFarmGame3.LANDING.y
      elseif BerryFarmGame3.isBerryFarmMap(fromMap) or (fromMap and BerryFarmGame3.isBerryFarmMap(fromMap)) then
        -- Leaving Berry Farm
        local ret = Host.saveGet(mod.save, "returnCenter", nil)
        if ret and ret.map then
          return ret.map, ret.x or BerryFarmGame3.RETURN_CELL.x, ret.y or BerryFarmGame3.RETURN_CELL.y
        else
          return "FR_VIRIDIAN_CITY_POKEMON_CENTER_1F", BerryFarmGame3.RETURN_CELL.x, BerryFarmGame3.RETURN_CELL.y
        end
      end
      return next(mapId, x, y, ctx)
    end)

    mod.hooks:wrap("world.talk", function(next, game, eo)
      local name = (eo and eo.def and eo.def.name) or (eo and eo.name)
      local curMap = (game and game.session and game.session.map) or (Map and Map.current) or (game and game.currentMap)
      if BerryFarmGame3.isBerryFarmMap(curMap) or (name and name:find("BERRY_")) then
        local def = BerryFarmGame3.buildFarmMapDef(mod)
        local tId = (eo and eo.def and eo.def.text) or (eo and eo.text) or (eo and eo.def and eo.def.scriptKey)
        local fn = def.talk and def.talk[tId]
        if not fn and name and name:match("^BERRY_PLOT_MARK_(%d+)$") then
          local idx = tonumber(name:match("^BERRY_PLOT_MARK_(%d+)$"))
          if idx then fn = makePlotTalk(mod, idx) end
        end
        if fn then
          local lid = eo.localId or (eo.def and eo.def.localId) or 0
          local Objects = package.loaded["src.core.game3.objects"]
          if Objects and lid > 0 then
            Objects.freeze(lid)
            Objects.facePlayer(lid, game)
          end
          fn(game, nil, eo, function()
            if Objects and lid > 0 then
              Objects.unfreeze(lid)
            end
          end)
          return true
        end
      end
      return next(game, eo)
    end)
  end

  -- Step events hook for plot growth & map hydration
  if mod.events and mod.events.on then
    mod.events:on("game.ready", function(ev)
      if ev and ev.game then
        syncFarmMapOnGame(ev.game)
      end
    end)
    mod.events:on("world.stepped", function(ev)
      BerryFarmGame3.bumpStep(mod)
      local Game = Host.liveGame(mod)
      BerryFarmGame3.syncPlotMarkers(mod, Game)
      local Player = package.loaded["src.core.game3.player"]
      local curMap = (Game and Game.session and Game.session.map) or (Map and Map.current) or (Game and Game.currentMap)
      if Player and curMap and BerryFarmGame3.isPokecenter1F(curMap) then
        if Player.cellX >= 2 and Player.cellX <= 4 and (Player.cellY == 9) then
          local Collision = package.loaded["src.core.game3.collision"]
          if Collision and Collision.tryWarpAt then
            Collision.tryWarpAt(Game, Player.cellX, Player.cellY, Player.facing)
          end
        end
      end
    end)
    mod.events:on("player.step", function(ev)
      BerryFarmGame3.bumpStep(mod)
      local Game = Host.liveGame(mod)
      BerryFarmGame3.syncPlotMarkers(mod, Game)
    end)
    mod.events:on("map.entered", function(ev)
      local Game = Host.liveGame(mod)
      if Game then syncFarmMapOnGame(Game) end
      if ev and ev.mapId then
        BerryFarmGame3.patchActiveMap(ev.mapId)
        if BerryFarmGame3.isBerryFarmMap(ev.mapId) then
          BerryFarmGame3.syncPlotMarkers(mod, Game)
        end
      end
    end)
    mod.events:on("player.warped", function(ev)
      local Game = Host.liveGame(mod)
      if Game then syncFarmMapOnGame(Game) end
      if ev and ev.toMap then
        BerryFarmGame3.patchActiveMap(ev.toMap)
        if BerryFarmGame3.isBerryFarmMap(ev.toMap) then
          grantStarterBerry(Game)
          BerryFarmGame3.syncPlotMarkers(mod, Game)
        end
      end
    end)
    mod.events:on("world.interacted", function(ev)
      if not ev or not BerryFarmGame3.isBerryFarmMap(ev.mapId) then return end
      local idx = plotIndexAt(ev.x, ev.y)
      if not idx and ev.target then
        local name = (type(ev.target) == "table" and ev.target.def and ev.target.def.name) or (type(ev.target) == "table" and ev.target.name)
        if name and name:match("^BERRY_PLOT_MARK_(%d+)$") then
          idx = tonumber(name:match("^BERRY_PLOT_MARK_(%d+)$"))
        end
      end
      if not idx then return end
      local Game = Host.liveGame(mod)
      if Game then
        makePlotTalk(mod, idx)(Game, nil, nil, function() end)
      end
    end)
  end

  -- Game3 StepEvents hook for overworld step-based berry growth anywhere in the world
  pcall(function()
    local okStep, StepEvents = pcall(require, "src.core.game3.step_events")
    if okStep and StepEvents and StepEvents.onStepTaken and not StepEvents._krBerryFarmHook then
      StepEvents._krBerryFarmHook = true
      local origOnStepTaken = StepEvents.onStepTaken
      StepEvents.onStepTaken = function(session, game)
        origOnStepTaken(session, game)
        BerryFarmGame3.bumpStep(mod)
        BerryFarmGame3.syncPlotMarkers(mod)
      end
    end
  end)
end

return BerryFarmGame3
