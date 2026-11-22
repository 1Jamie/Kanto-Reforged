-- Route DexNav: wild species on the current map.
-- Gen1: START-menu list after the Pokédex.
-- Gen2: POKéGEAR card via optional dep pokegear_cards — Gold's map-tool home.
-- Progressive reveal: ???? (unseen) → name (seen) → per-method levels (owned).
-- Fish-only; Super Rod only for fishing; Old/Good Rod omitted with a
-- conditional footer on fishable maps.
--
-- Mod option `dexnav_mode`:
--   dexnav    — label DEXNAV (default)
--   dexnav_kr — label DEXNAV-KR (disambiguate vs another DexNav mod)
--   off       — hide the entry / card

local DexNav = {}

DexNav.OPTION_KEY = "dexnav_mode"
DexNav.MODE_DEFAULT = "dexnav"
DexNav.MODE_KR = "dexnav_kr"
DexNav.MODE_OFF = "off"
DexNav.OPTION = {
  key = DexNav.OPTION_KEY,
  label = "DEXNAV",
  type = "choice",
  default = DexNav.MODE_DEFAULT,
  choices = {
    { "DEXNAV", DexNav.MODE_DEFAULT },
    { "DEXNAV-KR", DexNav.MODE_KR },
    { "OFF", DexNav.MODE_OFF },
  },
}

-- Labels the Roaming Radar (and similar) can anchor after on the start menu.
DexNav.MENU_LABELS = { "DEXNAV", "DEXNAV-KR" }

local SCREEN = "ExpDexNav"
local METHOD_ORDER = { "grass", "water", "fish", "smash" }
local METHOD_LABEL = { grass = "GRASS", water = "WATER", fish = "FISH", smash = "SMASH" }
local FISHING_NOTE = "No Old/Good Rod."
local NO_WILD = "No wild Pokemon here."
-- Bare ListMenu footer: 1 line at y=136, 2 lines start at y=120 (overlaps row 7).
-- Keep the note to a single glyph-row and shrink visible rows when it shows.
local ROWS_WITH_FOOTER = 6
local ROWS_DEFAULT = 7

-- Pokegear strip: reuse MAP chrome tiles; iconX is auto-assigned by
-- pokegear_cards past the vanilla CLOCK/MAP/PHONE/RADIO columns.
local POKEGEAR_CARD = {
  id = "dexnav",
  label = "DEXNAV",
  icon = 0x40,
}
local POKEGEAR_VISIBLE = 6
local ENGINE_POKEDEX = 11

function DexNav.mode(mod)
  if not mod or not mod.options then return DexNav.MODE_DEFAULT end
  local value = mod.options:get(DexNav.OPTION_KEY)
  if value == DexNav.MODE_KR or value == DexNav.MODE_OFF
      or value == DexNav.MODE_DEFAULT then
    return value
  end
  return DexNav.MODE_DEFAULT
end

function DexNav.menuLabel(mod)
  if DexNav.mode(mod) == DexNav.MODE_KR then return "DEXNAV-KR" end
  return "DEXNAV"
end

function DexNav.hasPokedex(game)
  local save = game and game.save
  if not save and game and game.session then
    save = game.session
  end
  if not save then
    local okRt, Runtime = pcall(require, "src.core.game3.runtime")
    if okRt and Runtime and Runtime.getSession then
      save = Runtime.getSession()
    end
  end
  if not save and _G.game and _G.game.session then
    save = _G.game.session
  end
  if not save then return false end
  if save.pokedexReceived then return true end
  if save.flags and (save.flags.EVENT_GOT_POKEDEX or save.flags.SYS_POKEDEX_GET or save.flags.FLAG_SYS_POKEDEX_GET or save.flags[0x829] or save.flags["0x829"]) then return true end
  if save.engineFlags and save.engineFlags[ENGINE_POKEDEX] then return true end
  local store = save.store
  if store and store.flags and (store.flags.SYS_POKEDEX_GET or store.flags.FLAG_SYS_POKEDEX_GET or store.flags[0x829] or store.flags["0x829"]) then return true end
  local Space = package.loaded["src.core.game3.scripting.space"]
  local liveStore = Space and Space.store
  if liveStore and liveStore.flags and (liveStore.flags.SYS_POKEDEX_GET or liveStore.flags.FLAG_SYS_POKEDEX_GET or liveStore.flags[0x829] or liveStore.flags["0x829"]) then return true end
  return false
end

local function absorb(byId, method, slots)
  if not slots then return end
  for _, slot in ipairs(slots) do
    local id = slot.species
    if id then
      local minLv = slot.minLevel or slot.level or 1
      local maxLv = slot.maxLevel or slot.level or minLv
      local entry = byId[id]
      if not entry then
        entry = { id = id, methods = {} }
        byId[id] = entry
      end
      local range = entry.methods[method]
      if not range then
        entry.methods[method] = { min = minLv, max = maxLv }
      else
        if minLv < range.min then range.min = minLv end
        if maxLv > range.max then range.max = maxLv end
      end
    end
  end
end

local function mergeTodSlots(todMap)
  if not todMap then return nil end
  local slots = todMap.slots
  if not slots then return nil end
  -- Gen1 / Gen2 water: flat slot list.
  if slots[1] then return slots end
  -- Gen2 grass: MORN/DAY/NITE tables.
  local out = {}
  for _, tod in ipairs({ "MORN", "DAY", "NITE" }) do
    for _, slot in ipairs(slots[tod] or {}) do
      out[#out + 1] = slot
    end
  end
  return out
end

-- Resolve Gen1-shaped enc + optional fish slots from either host's data.
function DexNav.sourcesForMap(data, mapId)
  if not mapId then return nil, nil end
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local okE, Enc = pcall(require, "mods.Kanto-Reforged.world.encounters_game3")
    if okE and Enc and Enc.getTableForMap then
      local t = Enc.getTableForMap(mapId)
      if t then
        local enc = {}
        if t.land and t.land.slots and #t.land.slots > 0 then
          enc.grass = t.land
        end
        if t.water and t.water.slots and #t.water.slots > 0 then
          enc.water = t.water
        end
        if t.rockSmash and t.rockSmash.slots and #t.rockSmash.slots > 0 then
          enc.smash = t.rockSmash
        end
        local fish = t.superRod and t.superRod.slots
        if not fish and t.goodRod and t.goodRod.slots then
          fish = t.goodRod.slots
        end
        if not enc.grass and not enc.water and not enc.smash then enc = nil end
        return enc, fish
      end
    end
    local enc = data and data.encounters and data.encounters[mapId]
    local fish = data and data.field and data.field.superRod and data.field.superRod[mapId]
    return enc, fish
  end
  if not data then return nil, nil end
  if Host.isGen2() then
    local g2 = data.gen2Encounters
    local grassRow = g2 and g2.grass and g2.grass[mapId]
    local waterRow = g2 and g2.water and g2.water[mapId]
    local enc = {
      grass = { slots = mergeTodSlots(grassRow) or {} },
      water = { slots = (waterRow and waterRow.slots) or {} },
    }
    if #enc.grass.slots == 0 then enc.grass = nil end
    if #(enc.water.slots or {}) == 0 then enc.water = nil end
    if not enc.grass and not enc.water then enc = nil end
    -- Fallback: some boots keep Gen1-shaped data.encounters[mapId].
    if not enc and data.encounters and data.encounters[mapId] then
      enc = data.encounters[mapId]
    end
    return enc, nil
  end
  local enc = data.encounters and data.encounters[mapId]
  local fish = data.field and data.field.superRod and data.field.superRod[mapId]
  return enc, fish
end

-- enc: encounters[mapId] or nil; fishSlots: field.superRod[mapId] or nil
-- Returns sorted array of { id, methods = { grass|water|fish|smash = {min,max} } }
function DexNav.aggregate(enc, fishSlots, pokemon)
  local byId = {}
  if enc then
    if enc.grass then absorb(byId, "grass", enc.grass.slots) end
    if enc.water then absorb(byId, "water", enc.water.slots) end
    if enc.smash then absorb(byId, "smash", enc.smash.slots) end
  end
  absorb(byId, "fish", fishSlots)

  local rows = {}
  for _, entry in pairs(byId) do
    rows[#rows + 1] = entry
  end
  table.sort(rows, function(a, b)
    local da = (pokemon and pokemon[a.id] and pokemon[a.id].dex) or tonumber(a.id) or 9999
    local db = (pokemon and pokemon[b.id] and pokemon[b.id].dex) or tonumber(b.id) or 9999
    if da ~= db then return da < db end
    return tostring(a.id) < tostring(b.id)
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

-- Gen1 uses pokedex.owned; Gold uses pokedex.caught. Accept either.
function DexNav.dexFlags(pokedex)
  pokedex = pokedex or {}
  return {
    seen = pokedex.seen or {},
    owned = pokedex.owned or pokedex.caught or {},
  }
end

function DexNav.formatRow(entry, dex, pokemon)
  dex = DexNav.dexFlags(dex)
  local id = entry.id
  local def = pokemon and (pokemon[id] or (tonumber(id) and pokemon[tonumber(id)]))
  local name = def and def.name
  if not name then
    local Host = require("mods.Kanto-Reforged.core.host")
    if Host.isGen3() then
      local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
      if okP and Pokemon and Pokemon.name then
        local okN, n = pcall(Pokemon.name, id)
        if okN and n and n ~= "?????" then name = n end
      end
      if not name then
        local okE, Enc = pcall(require, "mods.Kanto-Reforged.world.encounters_game3")
        if okE and Enc and Enc.toSpeciesName then
          name = Enc.toSpeciesName(id)
        end
      end
    end
  end
  name = name or tostring(id)

  local isOwned = dex.owned[id]
    or (tonumber(id) and dex.owned[tonumber(id)])
    or (def and def.name and dex.owned[def.name])
    or (type(id) == "string" and dex.owned[id:upper()])
  local isSeen = dex.seen[id]
    or (tonumber(id) and dex.seen[tonumber(id)])
    or (def and def.name and dex.seen[def.name])
    or (type(id) == "string" and dex.seen[id:upper()])

  if isOwned then
    return {
      label = name,
      right = DexNav.formatOwnedMethods(entry.methods),
      value = id,
    }
  end
  if isSeen then
    return { label = name, right = "SEEN", value = id }
  end
  return { label = "????", right = "", value = id }
end

function DexNav.currentMapId(game)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local okMap, Map = pcall(require, "src.core.game3.map")
    if okMap and Map and Map.current then return Map.current end
    if game and game.session and game.session.map then return game.session.map end
    local okRt, Runtime = pcall(require, "src.core.game3.runtime")
    if okRt and Runtime and Runtime.getSession and Runtime.getSession() then
      local s = Runtime.getSession()
      if s.map then return s.map end
    end
    if _G.game and _G.game.session and _G.game.session.map then
      return _G.game.session.map
    end
  end
  if game and game.world and game.world.map and game.world.map.id then
    return game.world.map.id
  end
  if game and game.overworld and game.overworld.map and game.overworld.map.id then
    return game.overworld.map.id
  end
  if game and game.save and game.save.player and game.save.player.map then
    return game.save.player.map
  end
  if game and game.save and game.save.map then
    return game.save.map
  end
  return nil
end

function DexNav.friendlyMapName(mapId)
  if not mapId then return "" end
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local okE, Enc = pcall(require, "mods.Kanto-Reforged.world.encounters_game3")
    if okE and Enc and Enc.MAP_TABLES then
      for k, def in pairs(Enc.MAP_TABLES) do
        if k == mapId or (def.aliases and (def.aliases[1] == mapId or def.aliases[2] == mapId or def.aliases[3] == mapId or def.aliases[4] == mapId)) then
          return k:gsub("(%a+)(%d+)", "%1 %2"):gsub("_", " ")
        end
      end
    end
  end
  return tostring(mapId):gsub("^FR_", ""):gsub("(%a+)(%d+)", "%1 %2"):gsub("_", " ")
end

function DexNav.mapTitle(mapId, mod)
  local prefix = DexNav.menuLabel(mod)
  if not mapId then return prefix end
  return prefix .. " " .. DexNav.friendlyMapName(mapId)
end

function DexNav.roamersHere(mod, mapId)
  if not mapId then return nil end
  local list = {}
  local ok, Roamers = pcall(require, "mods.Kanto-Reforged.roamers")
  if ok and Roamers then
    for _, id in ipairs(Roamers.BEASTS or {}) do
      if Roamers.getLocation(mod, id) == mapId then list[#list + 1] = id end
    end
    for _, id in ipairs(Roamers.EONS or {}) do
      if Roamers.getLocation(mod, id) == mapId then list[#list + 1] = id end
    end
  end
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local session
    local okRt, Runtime = pcall(require, "src.core.game3.runtime")
    if okRt and Runtime and Runtime.getSession then
      session = Runtime.getSession()
    end
    if not session and _G.game and _G.game.session then
      session = _G.game.session
    end
    if session and session.roamer and session.roamer.active then
      local rMap = session.roamer.map
      if rMap and (rMap == mapId or rMap:upper() == tostring(mapId):upper()) then
        local sp = session.roamer.species
        if sp then
          local already = false
          for _, x in ipairs(list) do
            if x == sp then already = true break end
          end
          if not already then list[#list + 1] = sp end
        end
      end
    end
  end
  if #list == 0 then return nil end
  return list
end

function DexNav.buildItems(data, mapId, pokedex, roamers, mod)
  local enc, fish = DexNav.sourcesForMap(data, mapId)
  local rows = DexNav.aggregate(enc, fish, data and data.pokemon)
  local items = {}
  if roamers then
    for _, species in ipairs(roamers) do
      local def = data and data.pokemon and (data.pokemon[species] or (tonumber(species) and data.pokemon[tonumber(species)]))
      local name = def and def.name
      if not name then
        local Host = require("mods.Kanto-Reforged.core.host")
        if Host.isGen3() then
          local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
          if okP and Pokemon and Pokemon.name then
            local okN, n = pcall(Pokemon.name, species)
            if okN and n and n ~= "?????" then name = n end
          end
          if not name then
            local okE, Enc = pcall(require, "mods.Kanto-Reforged.world.encounters_game3")
            if okE and Enc and Enc.toSpeciesName then
              name = Enc.toSpeciesName(species)
            end
          end
        end
      end
      items[#items + 1] = {
        label = name or tostring(species),
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

function DexNav.buildGame3Screen(mod, game, session)
  session = session or (game and game.session)
  if not session then
    local okRt, Runtime = pcall(require, "src.core.game3.runtime")
    if okRt and Runtime and Runtime.getSession then
      session = Runtime.getSession()
    end
  end
  local mapId = DexNav.currentMapId(game)
  local dex = DexNav.dexFlags(session and session.dex or (game and game.save and game.save.pokedex))
  local roamers = DexNav.roamersHere(mod, mapId)
  local items, footer = DexNav.buildItems(game and game.data, mapId, dex, roamers, mod)
  if #items == 0 then
    items = { { label = NO_WILD, right = "", value = nil } }
  end

  local okLm, ListMenu = pcall(require, "src.ui.game3.list_menu")
  local okWin, Window = pcall(require, "src.ui.game3.window")
  local okFont, FrlgFont = pcall(require, "src.ui.game3.frlg_font")

  local maxRows = footer and 5 or 6
  local rightEdge = 220

  for _, it in ipairs(items) do
    it.print = function(item, px, py, selected, idx)
      if okFont and FrlgFont and FrlgFont.draw then
        FrlgFont.draw(item.label or "", px, py, { colors = FrlgFont.COLOR.NORMAL })
        if item.right and item.right ~= "" then
          local rw = (FrlgFont.measure and FrlgFont.measure(item.right)) or (#item.right * 6)
          FrlgFont.draw(item.right, rightEdge - rw, py, { colors = FrlgFont.COLOR.NORMAL })
        end
      end
    end
  end

  local screen = {
    mod = mod,
    game = game,
    session = session,
    mapId = mapId,
    title = DexNav.mapTitle(mapId, mod),
    items = items,
    footer = footer,
    rows = maxRows,
    cursor = 1,
    open = true,
  }

  local lm
  if okLm and ListMenu and ListMenu.new then
    local listTopTile = 4
    local tpl = (okWin and Window and Window.template(2, listTopTile, 26, maxRows * 2))
      or { left = 2, top = listTopTile, w = 26, h = maxRows * 2 }
    lm = ListMenu.new({
      template = tpl,
      frame = "none",
      items = items,
      maxShowed = maxRows,
      rowHeight = 16,
      upTextY = 2,
      cursorX = 0,
      itemX = 10,
      sound = true,
      arrows = true,
      onSelect = function() screen.close() end,
      onCancel = function() screen.close() end,
    })
    screen._listMenu = lm
  end

  function screen.draw(...)
    if not (love and love.graphics) then return end
    if okWin and Window then
      local outerTpl = Window.template(1, 1, 28, 18)
      Window.fill(outerTpl)
      Window.stdFrame(outerTpl)
    end
    if okFont and FrlgFont and FrlgFont.draw then
      FrlgFont.draw(screen.title, 20, 16, { colors = FrlgFont.COLOR.NORMAL })
      if love.graphics.rectangle then
        love.graphics.setColor(FrlgFont.STDPAL[3] or { 0.83, 0.83, 0.80, 1 })
        love.graphics.rectangle("fill", 16, 31, 208, 1)
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
    if lm then lm:draw() end
    if footer and okFont and FrlgFont and FrlgFont.draw then
      local footDividerY = 32 + maxRows * 16 + 2
      if love.graphics.rectangle then
        love.graphics.setColor(FrlgFont.STDPAL[3] or { 0.83, 0.83, 0.80, 1 })
        love.graphics.rectangle("fill", 16, footDividerY, 208, 1)
        love.graphics.setColor(1, 1, 1, 1)
      end
      FrlgFont.draw(footer, 20, footDividerY + 6, { colors = FrlgFont.COLOR.NORMAL })
    end
  end

  function screen.update(dt)
    if lm and lm.update then lm:update(dt) end
  end

  function screen.handleInput(selfOrInput, maybeInput)
    local inp = (type(selfOrInput) == "table" and selfOrInput.wasPressed and selfOrInput)
      or (type(maybeInput) == "table" and maybeInput.wasPressed and maybeInput)
    if not inp then return end

    if inp:wasPressed("b") or inp:wasPressed("start") then
      screen.close()
      return "cancel"
    end

    if lm then
      local res = lm:handleInput(inp)
      if lm.selected then
        local _, idx = lm:selected()
        screen.cursor = idx or 1
      end
      if res then return res end
    else
      if inp:wasPressed("up") then
        screen.cursor = math.max(1, screen.cursor - 1)
        return "move"
      elseif inp:wasPressed("down") then
        screen.cursor = math.min(#items, screen.cursor + 1)
        return "move"
      end
    end

    if inp:wasPressed("a") then
      screen.close()
      return "select"
    end
  end

  function screen.close(...)
    if not screen.open then return end
    screen.open = false
    local okStack, Stack = pcall(require, "src.ui.game3.stack")
    if okStack and Stack and Stack.pop then
      Stack.pop("dexnav")
    end
    local okAudio, Audio = pcall(require, "src.core.game3.audio")
    local okSe, SE = pcall(require, "src.core.game3.se_ids")
    if okAudio and okSe and Audio.playSe and SE.SE_SELECT then
      pcall(Audio.playSe, SE.SE_SELECT)
    end
  end

  function screen.isOpen(...)
    return screen.open
  end

  return screen
end

function DexNav.openGame3(mod, game, session)
  local okStack, Stack = pcall(require, "src.ui.game3.stack")
  if not (okStack and Stack and Stack.push) then return end
  local screen = DexNav.buildGame3Screen(mod, game, session)
  Stack.push("dexnav", screen, { hideBelow = true })
  local okAudio, Audio = pcall(require, "src.core.game3.audio")
  local okSe, SE = pcall(require, "src.core.game3.se_ids")
  if okAudio and okSe and Audio.playSe and SE.SE_WIN_OPEN then
    pcall(Audio.playSe, SE.SE_WIN_OPEN)
  end
  return screen
end

local function buildScreen(mod, game)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    return DexNav.buildGame3Screen(mod, game)
  end
  local mapId = DexNav.currentMapId(game)
  local dex = DexNav.dexFlags(game.save and game.save.pokedex)
  local roamers = DexNav.roamersHere(mod, mapId)
  local items, footer = DexNav.buildItems(game.data, mapId, dex, roamers, mod)
  if #items == 0 then
    items = { { label = NO_WILD, right = "", value = nil } }
  end
  return mod.ui.ListMenu.new(game, DexNav.mapTitle(mapId, mod), items, {
    pageJump = true,
    footer = footer,
    rows = footer and ROWS_WITH_FOOTER or ROWS_DEFAULT,
    onChoose = function(_, menu) menu:close() end,
  })
end

local function refreshPokegearDex(self, mod)
  local game = self.game
  local mapId = DexNav.currentMapId(game)
  local dex = DexNav.dexFlags(game and game.save and game.save.pokedex)
  local items, footer = DexNav.buildItems(
    game and game.data, mapId, dex, DexNav.roamersHere(mod, mapId), mod)
  if #items == 0 then
    items = { { label = NO_WILD, right = "", value = nil } }
  end
  self._krDexNavItems = items
  self._krDexNavFooter = footer
  self._krDexNavCursor = 0
  self._krDexNavScroll = 0
  self._krDexNavMap = mapId
end

local function drawDexNavCard(gear, mod, helpers)
  local Font = require("src.render.Font")
  local Chrome = require("src.ui.gen2.Chrome")
  local H = helpers or {}
  local text = H.text or function(g, str, tx, ty)
    if g.text then g:text(str, tx, ty) else Chrome.print(str, tx, ty) end
  end
  local textbox = H.textbox or function(g, tx, ty, w, h)
    if g.textbox then g:textbox(tx, ty, w, h)
    elseif g.drawPlate then g:drawPlate(tx, ty, w + 2, h + 2) end
  end

  if not gear._krDexNavItems then
    refreshPokegearDex(gear, mod)
  end
  local items = gear._krDexNavItems or {}
  local footer = gear._krDexNavFooter
  local cursor = gear._krDexNavCursor or 0
  local scroll = gear._krDexNavScroll or 0
  local n = #items
  -- Leave a bottom hint row; fishing note steals one more.
  local listRows = footer and (POKEGEAR_VISIBLE - 1) or POKEGEAR_VISIBLE
  local listY = 6

  if H.drawStrip then H.drawStrip(gear)
  elseif gear.drawStrip then gear:drawStrip() end

  local title = DexNav.menuLabel(mod)
  local mapId = gear._krDexNavMap
  local mapShort = mapId and mapId:gsub("_", " ") or ""
  if #mapShort > 16 then mapShort = mapShort:sub(1, 16) end
  text(gear, title, 1, 3)
  if mapShort ~= "" then text(gear, mapShort, 1, 4) end

  -- Cream list plate so ▶ is visible (black cursor on black ground was
  -- invisible — rows just appeared to flash when scrolling).
  textbox(gear, 0, 5, 18, listRows + 1)

  local moreBelow = scroll + listRows < n
  for i = 1, listRows do
    local idx = scroll + i
    local row = items[idx]
    local ty = listY + (i - 1)
    if row then
      local label = row.label or ""
      if #label > 10 then label = label:sub(1, 10) end
      local right = row.right or ""
      if #right > 7 then right = right:sub(1, 7) end
      text(gear, label, 2, ty)
      if right ~= "" then text(gear, right, 12, ty) end
      if (idx - 1) == cursor then
        -- On cream plate: flat black ▶ matches phone / Chrome.List.
        Chrome.cursor(1, ty)
      end
    end
  end

  -- Gold-style ▼ when more below (Chrome.List).
  if moreBelow then
    love.graphics.setColor(0, 0, 0, 1)
    Font.drawCode(Chrome.DOWN_ARROW, 1 * 8, (listY + listRows) * 8)
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Position + mode hint. Strip previews like MAP/PHONE/RADIO; card mode
  -- is for scrolling.
  local pos = n == 0 and "0/0" or ("%d/%d"):format(cursor + 1, n)
  local modeHint = (gear.mode == "card") and "B:BACK" or "A:OPEN"
  local hint = footer and (pos .. " " .. footer) or (pos .. "  " .. modeHint)
  if #hint > 18 then hint = hint:sub(1, 18) end
  text(gear, hint, 1, 16)
end

local function installPokegear(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen2() then return end

  local handle = mod.find and mod.find("pokegear_cards")
  local api = handle and handle.exports
  if not api or api.apiVersion ~= 1 or type(api.register) ~= "function" then
    if mod.log then
      mod.log:warn("DexNav needs pokegear_cards (enable that mod for the "
        .. "Gold Pokegear card)")
    end
    return
  end

  local unreg, err = api.register({
    id = POKEGEAR_CARD.id,
    label = function() return DexNav.menuLabel(mod) end,
    icon = POKEGEAR_CARD.icon,
    -- Prefer auto-layout so other custom cards can share the strip; fall
    -- back to the historical column past RADIO when nothing else is present.
    iconX = nil,
    priority = 40,
    owner = mod.id or "Kanto-Reforged",
    visible = function(gear)
      if DexNav.mode(mod) == DexNav.MODE_OFF then return false end
      return DexNav.hasPokedex(gear.game or { save = gear.save })
    end,
    onHighlight = function(gear)
      if not gear._krDexNavItems then
        refreshPokegearDex(gear, mod)
      end
    end,
    draw = function(gear)
      drawDexNavCard(gear, mod, api.helpers)
    end,
    update = function(gear, input)
      if not gear._krDexNavItems then
        refreshPokegearDex(gear, mod)
      end
      local items = gear._krDexNavItems or {}
      local n = #items
      if n == 0 then return end
      local footer = gear._krDexNavFooter
      local visible = footer and POKEGEAR_VISIBLE - 1 or POKEGEAR_VISIBLE
      local cursor = gear._krDexNavCursor or 0
      local scroll = gear._krDexNavScroll or 0
      if input:wasPressed("up") then
        cursor = (cursor - 1) % n
      elseif input:wasPressed("down") then
        cursor = (cursor + 1) % n
      elseif input:wasPressed("a") then
        -- Read-only browse: A does not close (B backs out via the lib).
        return
      end
      if cursor < scroll then scroll = cursor end
      if cursor >= scroll + visible then scroll = cursor - visible + 1 end
      gear._krDexNavCursor = cursor
      gear._krDexNavScroll = math.max(0, scroll)
    end,
  })

  if not unreg then
    if mod.log then
      mod.log:warn("DexNav Pokegear register failed: %s", tostring(err))
    end
    return
  end
  DexNav._pokegearUnregister = unreg
  if mod.log then
    mod.log:info("DexNav registered as Pokegear card via pokegear_cards")
  end
end

function DexNav.register(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen3() and mod and mod.content and mod.content.screens then
    mod.content.screens:register(SCREEN, {
      new = function(game) return buildScreen(mod, game) end,
    })
  end

  if Host.isGen2() then
    installPokegear(mod)
    return
  end

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    if DexNav.mode(mod) == DexNav.MODE_OFF then return out end
    if not DexNav.hasPokedex(game) then return out end
    local dexNavEntry = {
      id = "dexnav",
      label = DexNav.menuLabel(mod),
      onSelect = function(g, session)
        if Host.isGen3() then
          DexNav.openGame3(mod, g, session)
        else
          mod.ui.push(game, SCREEN)
        end
      end,
    }
    for i, item in ipairs(out) do
      if item.id == "pokedex" or item.label == "POKéDEX" or item.label == "POKEDEX" then
        table.insert(out, i + 1, dexNavEntry)
        return out
      end
    end
    if mod and mod.ui and mod.ui.insertAfter then
      return mod.ui.insertAfter(out, "POKéDEX", dexNavEntry)
    end
    table.insert(out, 2, dexNavEntry)
    return out
  end)
end

return DexNav
