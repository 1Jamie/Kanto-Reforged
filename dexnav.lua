-- Route DexNav: START-menu list of wild species on the current map.
-- Progressive reveal: ???? (unseen) → name (seen) → per-method levels (owned).
-- Text-only; Super Rod only for fishing; Old/Good Rod omitted with a
-- conditional footer on fishable maps.

local DexNav = {}

local SCREEN = "ExpDexNav"
local METHOD_ORDER = { "grass", "water", "fish" }
local METHOD_LABEL = { grass = "GRASS", water = "WATER", fish = "FISH" }
local FISHING_NOTE = "No Old/Good Rod."
local NO_WILD = "No wild Pokemon here."
-- Bare ListMenu footer: 1 line at y=136, 2 lines start at y=120 (overlaps row 7).
-- Keep the note to a single glyph-row and shrink visible rows when it shows.
local ROWS_WITH_FOOTER = 6
local ROWS_DEFAULT = 7

local function absorb(byId, method, slots)
  if not slots then return end
  for _, slot in ipairs(slots) do
    local id = slot.species
    if id then
      local lv = slot.level or 1
      local entry = byId[id]
      if not entry then
        entry = { id = id, methods = {} }
        byId[id] = entry
      end
      local range = entry.methods[method]
      if not range then
        entry.methods[method] = { min = lv, max = lv }
      else
        if lv < range.min then range.min = lv end
        if lv > range.max then range.max = lv end
      end
    end
  end
end

-- enc: encounters[mapId] or nil; fishSlots: field.superRod[mapId] or nil
-- Returns sorted array of { id, methods = { grass|water|fish = {min,max} } }
function DexNav.aggregate(enc, fishSlots, pokemon)
  local byId = {}
  if enc then
    if enc.grass then absorb(byId, "grass", enc.grass.slots) end
    if enc.water then absorb(byId, "water", enc.water.slots) end
  end
  absorb(byId, "fish", fishSlots)

  local rows = {}
  for _, entry in pairs(byId) do
    rows[#rows + 1] = entry
  end
  table.sort(rows, function(a, b)
    local da = (pokemon and pokemon[a.id] and pokemon[a.id].dex) or 9999
    local db = (pokemon and pokemon[b.id] and pokemon[b.id].dex) or 9999
    if da ~= db then return da < db end
    return a.id < b.id
  end)
  return rows
end

-- Footer only when Old/Good Rod omission is relevant (water and/or Super Rod).
function DexNav.showFishingNote(enc, fishSlots)
  if fishSlots and #fishSlots > 0 then return true end
  if enc and enc.water and enc.water.slots and #enc.water.slots > 0 then
    return true
  end
  return false
end

-- Join each present method as its own tag (never collapse identical ranges).
function DexNav.formatOwnedMethods(methods)
  local parts = {}
  for _, key in ipairs(METHOD_ORDER) do
    local range = methods and methods[key]
    if range then
      local label = METHOD_LABEL[key]
      if range.min == range.max then
        parts[#parts + 1] = ("%s %d"):format(label, range.min)
      else
        parts[#parts + 1] = ("%s %d-%d"):format(label, range.min, range.max)
      end
    end
  end
  return table.concat(parts, " / ")
end

function DexNav.formatRow(entry, dex, pokemon)
  dex = dex or { seen = {}, owned = {} }
  local id = entry.id
  local def = pokemon and pokemon[id]
  local name = (def and def.name) or id

  if dex.owned[id] then
    return {
      label = name,
      right = DexNav.formatOwnedMethods(entry.methods),
      value = id,
    }
  end
  if dex.seen[id] then
    return { label = name, right = "SEEN", value = id }
  end
  return { label = "????", right = "", value = id }
end

function DexNav.currentMapId(game)
  if game and game.overworld and game.overworld.map and game.overworld.map.id then
    return game.overworld.map.id
  end
  if game and game.save and game.save.player and game.save.player.map then
    return game.save.player.map
  end
  return nil
end

function DexNav.mapTitle(mapId)
  if not mapId then return "DEXNAV" end
  return "DEXNAV " .. mapId:gsub("_", " ")
end

function DexNav.buildItems(data, mapId, pokedex, roamers)
  local enc = data and data.encounters and data.encounters[mapId]
  local fish = data and data.field and data.field.superRod and data.field.superRod[mapId]
  local rows = DexNav.aggregate(enc, fish, data and data.pokemon)
  local items = {}
  if roamers then
    for _, species in ipairs(roamers) do
      local def = data and data.pokemon and data.pokemon[species]
      items[#items + 1] = {
        label = (def and def.name) or species,
        right = "ROAM",
        value = species,
      }
    end
  end
  for _, entry in ipairs(rows) do
    items[#items + 1] = DexNav.formatRow(entry, pokedex, data and data.pokemon)
  end
  local note = DexNav.showFishingNote(enc, fish)
  return items, note and FISHING_NOTE or nil
end

function DexNav.register(mod)
  mod.content.screens:register(SCREEN, {
    new = function(game)
      local mapId = DexNav.currentMapId(game)
      local dex = (game.save and game.save.pokedex) or { seen = {}, owned = {} }
      local roamers = nil
      local ok, Roamers = pcall(require, "mods.Kanto-Reforged.roamers")
      if ok and Roamers and mapId then
        local list = {}
        for _, id in ipairs(Roamers.BEASTS or {}) do
          if Roamers.getLocation(mod, id) == mapId then list[#list + 1] = id end
        end
        for _, id in ipairs(Roamers.EONS or {}) do
          if Roamers.getLocation(mod, id) == mapId then list[#list + 1] = id end
        end
        if #list > 0 then roamers = list end
      end
      local items, footer = DexNav.buildItems(game.data, mapId, dex, roamers)
      if #items == 0 then
        items = { { label = NO_WILD, right = "", value = nil } }
      end
      return mod.ui.ListMenu.new(game, DexNav.mapTitle(mapId), items, {
        pageJump = true,
        footer = footer,
        rows = footer and ROWS_WITH_FOOTER or ROWS_DEFAULT,
        onChoose = function(_, menu) menu:close() end,
      })
    end,
  })

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    local flags = game and game.save and game.save.flags
    if not (flags and flags.EVENT_GOT_POKEDEX) then
      return out
    end
    return mod.ui.insertAfter(out, "POKéDEX", {
      label = "DEXNAV",
      onSelect = function() mod.ui.push(game, SCREEN) end,
    })
  end)
end

return DexNav
