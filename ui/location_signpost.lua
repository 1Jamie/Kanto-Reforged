-- Location Signpost overlay for Kanto-Reforged (Gen 1 & Gen 2)
-- Displays a Gen 3 style (FireRed/Emerald) area pop-up banner when entering a new location.
-- Supports word-wrapping for building names (e.g. Cherrygrove Pokecenter) and retains floor info for dungeons/towers.

local LocationSignpost = {}

LocationSignpost.OPTION_KEY = "location_signposts"
LocationSignpost.OPTION = {
  key = LocationSignpost.OPTION_KEY,
  label = "LOCATION SIGNPOSTS",
  type = "toggle",
  default = true,
}

local DISPLAY_NAMES = {
  MT_MOON = "MT. MOON",
  POKEMON_TOWER = "POKÉMON TOWER",
  POKEMON_MANSION = "POKÉMON MANSION",
  DIGLETTS_CAVE = "DIGLETT'S CAVE",
  SILPH_CO = "SILPH CO.",
  CELADON_DEPT_STORE = "CELADON DEPT. STORE",
  GOLDENROD_DEPT_STORE = "GOLDENROD DEPT. STORE",
  INDIGO_PLATEAU_LOBBY = "INDIGO PLATEAU",
  UNDERGROUND_PATH = "UNDERGROUND PATH",
  PEWTER_MUSEUM = "PEWTER MUSEUM",
  CINNABAR_LAB = "CINNABAR LAB",
  CELADON_MANSION = "CELADON MANSION",
}

local DUNGEONS_WITH_FLOORS = {
  ROCKET_HIDEOUT = true,
  MT_MOON = true,
  POKEMON_TOWER = true,
  POKEMON_MANSION = true,
  SILPH_CO = true,
  VICTORY_ROAD = true,
  CERULEAN_CAVE = true,
  SEAFOAM_ISLANDS = true,
  ROCK_TUNNEL = true,
  RADIO_TOWER = true,
  LIGHTHOUSE = true,
  BURNED_TOWER = true,
  TIN_TOWER = true,
  SPROUT_TOWER = true,
  ICE_PATH = true,
  UNION_CAVE = true,
  MOUNT_MORTAR = true,
}

local PARENT_MAPS = {
  -- Museums, Labs, Department Stores, Elevators
  MUSEUM_1F = "PEWTER_MUSEUM",
  MUSEUM_2F = "PEWTER_MUSEUM",
  PEWTER_MUSEUM_1F = "PEWTER_MUSEUM",
  PEWTER_MUSEUM_2F = "PEWTER_MUSEUM",
  CELADON_MANSION_1F = "CELADON_MANSION",
  CELADON_MANSION_2F = "CELADON_MANSION",
  CELADON_MANSION_3F = "CELADON_MANSION",
  CELADON_MANSION_ROOF = "CELADON_MANSION",
  CELADON_MANSION_ROOF_HOUSE = "CELADON_MANSION",
  CELADON_MART_ELEVATOR = "CELADON_DEPT_STORE",
  GOLDENROD_DEPT_STORE_ELEVATOR = "GOLDENROD_DEPT_STORE",
  CINNABAR_LAB_TRADE_ROOM = "CINNABAR_LAB",
  CINNABAR_LAB_METRONOME_ROOM = "CINNABAR_LAB",
  CINNABAR_LAB_FOSSIL_ROOM = "CINNABAR_LAB",

  -- Gatehouses & Rest Houses map to outer area to prevent gatehouse pop-up spam
  VIRIDIAN_FOREST_SOUTH_GATE = "VIRIDIAN_FOREST",
  VIRIDIAN_FOREST_NORTH_GATE = "VIRIDIAN_FOREST",
  ROUTE_2_GATE = "ROUTE_2",
  ROUTE_5_GATE = "ROUTE_5",
  ROUTE_6_GATE = "ROUTE_6",
  ROUTE_7_GATE = "ROUTE_7",
  ROUTE_8_GATE = "ROUTE_8",
  ROUTE_11_GATE_1F = "ROUTE_11",
  ROUTE_11_GATE_2F = "ROUTE_11",
  ROUTE_12_GATE_1F = "ROUTE_12",
  ROUTE_12_GATE_2F = "ROUTE_12",
  ROUTE_15_GATE_1F = "ROUTE_15",
  ROUTE_15_GATE_2F = "ROUTE_15",
  ROUTE_16_GATE_1F = "ROUTE_16",
  ROUTE_16_GATE_2F = "ROUTE_16",
  ROUTE_18_GATE_1F = "ROUTE_18",
  ROUTE_18_GATE_2F = "ROUTE_18",
  ROUTE_22_GATE = "ROUTE_22",
  SAFARI_ZONE_GATE = "SAFARI_ZONE",
  SAFARI_ZONE_WEST_REST_HOUSE = "SAFARI_ZONE",
  SAFARI_ZONE_SECRET_HOUSE = "SAFARI_ZONE",
  SAFARI_ZONE_NORTH_REST_HOUSE = "SAFARI_ZONE",
  SAFARI_ZONE_EAST_REST_HOUSE = "SAFARI_ZONE",
  SAFARI_ZONE_CENTER_REST_HOUSE = "SAFARI_ZONE",
}

LocationSignpost._currentArea = nil
LocationSignpost._displayTitle = ""
LocationSignpost._accentColor = { 0.90, 0.70, 0.16 }
LocationSignpost._animState = "idle"
LocationSignpost._animTimer = 0
LocationSignpost._lastTime = nil

local ENTER_DUR = 0.35
local HOLD_DUR = 2.0
local EXIT_DUR = 0.40

function LocationSignpost.isOverworldActive(game)
  if not game or type(game) ~= "table" then return false end
  local save = game.save
  if not save or type(save) ~= "table" then return false end
  if not save.player and not (save.party and #save.party > 0) then return false end

  -- Gen 1 state check: overworld is a StateStack state; top MUST be game.overworld
  if game.overworld then
    if not game.overworld.map then return false end
    if game.stack and type(game.stack.top) == "function" then
      local top = game.stack:top()
      if top ~= game.overworld then return false end
    end
    if game.overworld.text or game.overworld.menu or game.overworld.battle then return false end
    return true
  end

  -- Gen 2 state check: overworld is free roam when stack:top() is NIL
  if game.world then
    if not game.world.map or not game.world.player then return false end
    if game.stack and type(game.stack.top) == "function" then
      local top = game.stack:top()
      if top ~= nil then return false end
    end
    if game.world.menu or game.world.textbox or game.world.battle then return false end
    return true
  end

  return false
end

local POKECENTER_2F_MAPS = {
  POKECENTER_2F = true,
  TRADE_CENTER = true,
  COLOSSEUM = true,
  TIME_CAPSULE = true,
  CABLE_CLUB = true,
}

function LocationSignpost.cleanAreaName(mapId)
  if not mapId or mapId == "" then return nil end
  if mapId:find("UNDERGROUND_PATH") then return "UNDERGROUND PATH" end
  if mapId:find("DIGLETTS_CAVE") then return "DIGLETT'S CAVE" end

  -- Generic Pokecenter 2F / Trade / Cable maps: preserve parent Pokecenter title if coming from a Pokecenter
  if POKECENTER_2F_MAPS[mapId] then
    if LocationSignpost._currentArea and LocationSignpost._currentArea:find("POKECENTER") then
      return LocationSignpost._currentArea
    end
    return "POKECENTER"
  end

  local isDungeonFloor = false
  for dungeonKey, _ in pairs(DUNGEONS_WITH_FLOORS) do
    if mapId:find(dungeonKey) then
      isDungeonFloor = true
      break
    end
  end

  local floorSuffix = ""
  if isDungeonFloor then
    floorSuffix = mapId:match("_(%d+F)$") or mapId:match("_(B%d+F)$") or ""
    if floorSuffix ~= "" then floorSuffix = " " .. floorSuffix end
  end

  if PARENT_MAPS[mapId] then mapId = PARENT_MAPS[mapId] end

  local base = mapId:gsub("_%d+F$", ""):gsub("_B%d+F$", ""):gsub("_REST_HOUSE$", ""):gsub("_GATE$", "")
  local name = DISPLAY_NAMES[base] or DISPLAY_NAMES[mapId] or base:gsub("_", " ")

  if isDungeonFloor and floorSuffix ~= "" then
    if not name:find("%d+F$") then
      name = name .. floorSuffix
    end
  end

  return name
end

function LocationSignpost.getAccentColor(areaName, mapId)
  if areaName:find("ROUTE") then return { 0.12, 0.72, 0.42 } end -- emerald green
  if areaName:find("TOWN") or areaName:find("CITY") then return { 0.92, 0.70, 0.16 } end -- amber gold
  if areaName:find("FOREST") or areaName:find("WOODS") then return { 0.15, 0.65, 0.28 } end -- forest green
  if areaName:find("CAVE") or areaName:find("TUNNEL") or areaName:find("MT") then return { 0.60, 0.38, 0.82 } end -- purple/crystal
  if areaName:find("ISLAND") or areaName:find("BEACH") then return { 0.18, 0.60, 0.82 } end -- cyan/ocean
  return { 0.82, 0.42, 0.22 }
end

function LocationSignpost.formatTitleLines(title, maxW)
  maxW = maxW or 124
  local FontModule = nil
  pcall(function() FontModule = require("src.render.Font") end)
  local getW = function(str)
    return (FontModule and FontModule.width and FontModule.width(str)) or (#str * 8)
  end

  local fullW = getW(title)
  if fullW <= maxW then
    return { title }, fullW
  end

  local words = {}
  for w in title:gmatch("%S+") do
    words[#words + 1] = w
  end

  if #words <= 1 then
    return { title }, fullW
  end

  local lines = {}
  local currentLine = ""
  for _, word in ipairs(words) do
    local testLine = (currentLine == "") and word or (currentLine .. " " .. word)
    if getW(testLine) <= maxW then
      currentLine = testLine
    else
      if currentLine ~= "" then
        lines[#lines + 1] = currentLine
      end
      currentLine = word
    end
  end
  if currentLine ~= "" then
    lines[#lines + 1] = currentLine
  end

  local maxLineW = 0
  for _, line in ipairs(lines) do
    local lw = getW(line)
    if lw > maxLineW then maxLineW = lw end
  end

  return lines, maxLineW
end

function LocationSignpost.update(game)
  if not LocationSignpost.isOverworldActive(game) then
    LocationSignpost._currentArea = nil
    LocationSignpost._animState = "idle"
    LocationSignpost._animTimer = 0
    return
  end

  local mapId = nil
  if game and game.overworld and game.overworld.map then
    mapId = game.overworld.map.id
  elseif game and game.world and game.world.map then
    mapId = game.world.map.id
  elseif game and game.save and game.save.player then
    mapId = game.save.player.map
  end

  local areaName = LocationSignpost.cleanAreaName(mapId)
  if areaName and areaName ~= "" and areaName ~= LocationSignpost._currentArea then
    LocationSignpost._currentArea = areaName
    LocationSignpost._displayTitle = areaName
    LocationSignpost._accentColor = LocationSignpost.getAccentColor(areaName, mapId)
    LocationSignpost._animState = "enter"
    LocationSignpost._animTimer = 0
  end

  local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
  local dt = 0.016
  if LocationSignpost._lastTime then
    dt = math.min(0.1, math.max(0.001, now - LocationSignpost._lastTime))
  end
  LocationSignpost._lastTime = now

  if LocationSignpost._animState == "enter" then
    LocationSignpost._animTimer = LocationSignpost._animTimer + dt
    if LocationSignpost._animTimer >= ENTER_DUR then
      LocationSignpost._animState = "hold"
      LocationSignpost._animTimer = 0
    end
  elseif LocationSignpost._animState == "hold" then
    LocationSignpost._animTimer = LocationSignpost._animTimer + dt
    if LocationSignpost._animTimer >= HOLD_DUR then
      LocationSignpost._animState = "exit"
      LocationSignpost._animTimer = 0
    end
  elseif LocationSignpost._animState == "exit" then
    LocationSignpost._animTimer = LocationSignpost._animTimer + dt
    if LocationSignpost._animTimer >= EXIT_DUR then
      LocationSignpost._animState = "idle"
      LocationSignpost._animTimer = 0
    end
  end
end

function LocationSignpost.optionDef()
  local Host = require("mods.Kanto-Reforged.core.host")
  return {
    key = Host.optionKey(LocationSignpost.OPTION_KEY),
    label = "LOCATION SIGNPOSTS",
    type = "toggle",
    default = true,
  }
end
LocationSignpost.OPTION = LocationSignpost.optionDef()

function LocationSignpost.draw(mod, game, viewport)
  local Host = require("mods.Kanto-Reforged.core.host")
  local optKey = Host.optionKey(LocationSignpost.OPTION_KEY)
  if not mod or not mod.options or mod.options:get(optKey) == false then
    return
  end

  LocationSignpost.update(game)

  if LocationSignpost._animState == "idle" or not love or not love.graphics then
    return
  end

  local G = love.graphics
  local state = LocationSignpost._animState
  local timer = LocationSignpost._animTimer

  local alpha = 1.0
  local yOffset = 0

  if state == "enter" then
    local progress = math.min(1.0, timer / ENTER_DUR)
    progress = 1 - (1 - progress)^3
    alpha = progress
    yOffset = -32 * (1 - progress)
  elseif state == "hold" then
    alpha = 1.0
    yOffset = 0
  elseif state == "exit" then
    local progress = math.min(1.0, timer / EXIT_DUR)
    progress = progress^3
    alpha = 1.0 - progress
    yOffset = -32 * progress
  end

  -- DPI-aware scaling & viewport translation across all platforms (Desktop, Mobile, Steam Deck, Retina/High-DPI)
  local dpiX = (viewport and viewport.dpiX) or (love and love.window and love.window.getDPIScale and love.window.getDPIScale()) or 1
  local dpiY = (viewport and viewport.dpiY) or dpiX

  local gameX = (viewport and viewport.gameX) or 0
  local gameY = (viewport and viewport.gameY) or 0

  local scaleX = 1
  local scaleY = 1
  if viewport and viewport.gameWidth and viewport.gameHeight and viewport.gameWidth > 0 and viewport.gameHeight > 0 then
    scaleX = viewport.gameWidth / 160
    scaleY = viewport.gameHeight / 144
  elseif viewport and viewport.scale and viewport.scale > 0 then
    scaleX = viewport.scale / dpiX
    scaleY = viewport.scale / dpiY
  elseif game and type(game.fitScale) == "function" then
    local fit = game:fitScale()
    scaleX = fit / dpiX
    scaleY = fit / dpiY
  end

  local title = LocationSignpost._displayTitle or ""
  local accent = LocationSignpost._accentColor or { 0.92, 0.70, 0.16 }

  -- Format lines & word-wrap if text exceeds 124px width in 160x144 space
  local lines, maxLineW = LocationSignpost.formatTitleLines(title, 124)
  local lineCount = #lines

  local bannerW = math.min(150, math.max(90, maxLineW + 24))
  local bannerH = (lineCount > 1) and 28 or 20
  local bannerX = math.max(5, math.floor((160 - bannerW) / 2))
  local bannerY = 6 + yOffset

  G.push("all")
  G.translate(gameX, gameY)
  G.scale(scaleX, scaleY)

  -- 1. Outer Drop Shadow
  G.setColor(0, 0, 0, 0.40 * alpha)
  if G.rectangle then
    G.rectangle("fill", bannerX + 2, bannerY + 2, bannerW, bannerH, 4, 4)
  end

  -- 2. Outer Dark Slate Frame Border
  G.setColor(0.12, 0.16, 0.24, 0.95 * alpha)
  if G.rectangle then
    G.rectangle("fill", bannerX, bannerY, bannerW, bannerH, 4, 4)
  end

  -- 3. Plaque Interior Fill (Crisp Cream/Ivory for 100% text legibility)
  G.setColor(0.95, 0.94, 0.88, 0.96 * alpha)
  if G.rectangle then
    G.rectangle("fill", bannerX + 1, bannerY + 1, bannerW - 2, bannerH - 2, 3, 3)
  end

  -- 4. Left Accent Bar (Vibrant Category Color)
  G.setColor(accent[1], accent[2], accent[3], 0.95 * alpha)
  if G.rectangle then
    G.rectangle("fill", bannerX + 3, bannerY + 3, 4, bannerH - 6, 2, 2)
  end

  -- 5. Inner Trim Outline
  G.setColor(0.80, 0.78, 0.70, 0.60 * alpha)
  if G.rectangle then
    G.rectangle("line", bannerX + 1, bannerY + 1, bannerW - 2, bannerH - 2, 3, 3)
  end

  -- 6. Location Title Text (Single-line or Word-Wrapped Multi-line)
  local FontModule = nil
  pcall(function() FontModule = require("src.render.Font") end)

  G.setColor(1, 1, 1, alpha)
  if lineCount == 1 then
    if FontModule and FontModule.draw then
      FontModule.draw(lines[1], bannerX + 13, bannerY + 6)
    else
      G.print(lines[1], bannerX + 13, bannerY + 5)
    end
  else
    if FontModule and FontModule.draw then
      FontModule.draw(lines[1], bannerX + 13, bannerY + 4)
      FontModule.draw(lines[2], bannerX + 13, bannerY + 15)
    else
      G.print(lines[1], bannerX + 13, bannerY + 3)
      G.print(lines[2], bannerX + 13, bannerY + 14)
    end
  end

  G.pop()
end

function LocationSignpost.install(mod)
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    next(game, viewport)
    pcall(LocationSignpost.draw, mod, game, viewport)
  end)

  mod.log:info("Gen 3 Location Signpost overlay registered")
end

return LocationSignpost
