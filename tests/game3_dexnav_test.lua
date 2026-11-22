-- Test suite for DexNav in Gen 3 (FireRed / LeafGreen).

package.path = package.path .. ";../../?.lua;../?.lua;./?.lua"

local Host = require("mods.Kanto-Reforged.core.host")
local DexNav = require("mods.Kanto-Reforged.ui.dexnav")
local EncountersGame3 = require("mods.Kanto-Reforged.world.encounters_game3")

local function runTests()
  print("--- Testing Gen 3 DexNav ---")

  Host.force(3)

  -- 1. Test sourcesForMap with Gen 3 tables
  local enc1, fish1 = DexNav.sourcesForMap(nil, "ROUTE_1")
  assert(enc1 ~= nil, "ROUTE_1 should have encounter table")
  assert(enc1.grass ~= nil, "ROUTE_1 should have grass encounters")
  assert(enc1.water == nil, "ROUTE_1 should not have water")
  assert(enc1.smash == nil, "ROUTE_1 should not have rock smash")
  assert(fish1 == nil, "ROUTE_1 should not have fishing slots")

  local encAlias, fishAlias = DexNav.sourcesForMap(nil, "3:19")
  assert(encAlias ~= nil and encAlias.grass ~= nil, "3:19 alias should resolve Route 1 encounters")

  local enc21, fish21 = DexNav.sourcesForMap(nil, "ROUTE_21")
  assert(enc21 ~= nil, "ROUTE_21 should have encounter table")
  assert(enc21.grass ~= nil, "ROUTE_21 should have grass encounters")
  assert(enc21.water ~= nil, "ROUTE_21 should have water encounters")
  assert(fish21 ~= nil and #fish21 > 0, "ROUTE_21 should have fishing slots")

  local encMoon, fishMoon = DexNav.sourcesForMap(nil, "MT_MOON_1F")
  assert(encMoon ~= nil, "MT_MOON_1F should have encounters")
  assert(encMoon.grass ~= nil, "MT_MOON_1F should have grass/cave encounters")
  assert(encMoon.smash ~= nil, "MT_MOON_1F should have rock smash encounters")

  local encNone, fishNone = DexNav.sourcesForMap(nil, "NONEXISTENT_MAP")
  assert(encNone == nil and fishNone == nil, "Nonexistent map should return nil")

  -- 2. Test showFishingNote
  assert(DexNav.showFishingNote(enc1, fish1) == false, "Route 1 should not show fishing note")
  assert(DexNav.showFishingNote(enc21, fish21) == true, "Route 21 should show fishing note")
  assert(DexNav.showFishingNote({ water = { slots = { { species = 72, level = 5 } } } }, nil) == true,
    "Water-only map should show fishing note")

  -- 3. Test absorb and level ranges
  local byId = {}
  local fakeSlots = {
    { species = 16, minLevel = 2, maxLevel = 4 },
    { species = 16, minLevel = 3, maxLevel = 6 },
    { species = 19, minLevel = 3, maxLevel = 3 },
  }
  -- Test with Gen 3 aggregate
  local agg = DexNav.aggregate({ grass = { slots = fakeSlots } }, nil, nil)
  assert(#agg == 2, "2 distinct species aggregated")
  assert(agg[1].id == 16, "Pidgey (#16) sorted first")
  assert(agg[1].methods.grass.min == 2, "Pidgey minLevel should expand to 2")
  assert(agg[1].methods.grass.max == 6, "Pidgey maxLevel should expand to 6")
  assert(agg[2].id == 19, "Rattata (#19) sorted second")
  assert(agg[2].methods.grass.min == 3 and agg[2].methods.grass.max == 3, "Rattata level is 3")

  -- 4. Test formatOwnedMethods with multi-method
  local multiMethods = {
    grass = { min = 7, max = 11 },
    smash = { min = 5, max = 10 },
  }
  local fmt = DexNav.formatOwnedMethods(multiMethods)
  assert(fmt:find("GRASS 7%-11") ~= nil, "Owned string includes grass: " .. fmt)
  assert(fmt:find("SMASH 5%-10") ~= nil, "Owned string includes smash: " .. fmt)

  -- 5. Test formatRow: unseen vs seen vs owned
  local entry = { id = 16, methods = { grass = { min = 2, max = 5 } } }
  local unseen = DexNav.formatRow(entry, { seen = {}, owned = {} }, nil)
  assert(unseen.label == "????", "Unseen row label is ????")
  assert(unseen.right == "", "Unseen row right is empty")

  local seen = DexNav.formatRow(entry, { seen = { [16] = true }, owned = {} }, nil)
  assert(seen.label:upper() == "PIDGEY", "Seen row shows species name: " .. tostring(seen.label))
  assert(seen.right == "SEEN", "Seen row right is SEEN")

  local owned = DexNav.formatRow(entry, { seen = { [16] = true }, owned = { [16] = true } }, nil)
  assert(owned.label:upper() == "PIDGEY", "Owned row shows species name")
  assert(owned.right:find("GRASS 2%-5") ~= nil, "Owned row right shows method levels: " .. tostring(owned.right))

  -- 6. Test hasPokedex
  assert(DexNav.hasPokedex(nil) == false, "nil game has no pokedex")
  assert(DexNav.hasPokedex({ save = { flags = {} } }) == false, "empty flags has no pokedex")
  assert(DexNav.hasPokedex({ save = { flags = { [0x829] = true } } }) == true, "0x829 has pokedex")
  assert(DexNav.hasPokedex({ save = { flags = { SYS_POKEDEX_GET = true } } }) == true, "SYS_POKEDEX_GET has pokedex")
  assert(DexNav.hasPokedex({ session = { flags = { FLAG_SYS_POKEDEX_GET = true } } }) == true, "FLAG_SYS_POKEDEX_GET has pokedex")
  assert(DexNav.hasPokedex({ save = { pokedexReceived = true } }) == true, "pokedexReceived has pokedex")
  assert(DexNav.hasPokedex({ save = { flags = { EVENT_GOT_POKEDEX = true } } }) == true, "EVENT_GOT_POKEDEX has pokedex")

  -- 7. Test friendlyMapName and mapTitle
  assert(DexNav.friendlyMapName("3:19"):upper() == "ROUTE 1", "3:19 friendly name is Route 1")
  assert(DexNav.friendlyMapName("FR_ROUTE_1"):upper() == "ROUTE 1", "FR_ROUTE_1 friendly name is Route 1")
  assert(DexNav.friendlyMapName("VIRIDIAN_FOREST"):upper() == "VIRIDIAN FOREST", "Viridian Forest friendly name")
  local title = DexNav.mapTitle("ROUTE_1", nil)
  assert(title:find("DEXNAV") ~= nil and title:find("ROUTE 1") ~= nil, "mapTitle includes DEXNAV and route: " .. title)

  -- 8. Test start menu hook
  local fakeMod = {
    options = {
      get = function(_, k)
        if k == DexNav.OPTION_KEY then return DexNav.MODE_DEFAULT end
        return nil
      end,
    },
    hooks = {
      wrap = function(self, name, fn)
        self[name] = fn
      end,
    },
    ui = {
      insertAfter = function(items, anchor, item)
        table.insert(items, item)
        return items
      end,
    },
  }

  DexNav.register(fakeMod)
  assert(fakeMod.hooks["ui.start_menu.items"] ~= nil, "ui.start_menu.items hook should be registered")

  local hookFn = fakeMod.hooks["ui.start_menu.items"]
  local startItems = {
    { id = "pokedex", label = "POKéDEX" },
    { id = "pokemon", label = "POKéMON" },
    { id = "bag", label = "BAG" },
    { id = "save", label = "SAVE" },
    { id = "option", label = "OPTION" },
    { id = "exit", label = "EXIT" },
  }

  -- When no pokedex flag, hook leaves menu unchanged
  local outNoDex = hookFn(function(_, items) return items end, { save = { flags = {} } }, { unpack(startItems) })
  local foundDexNav = false
  for _, item in ipairs(outNoDex) do
    if item.id == "dexnav" then foundDexNav = true end
  end
  assert(foundDexNav == false, "DexNav should not be present without pokedex")

  -- When pokedex flag is set, DexNav is inserted immediately after pokedex
  local outWithDex = hookFn(function(_, items) return items end,
    { save = { flags = { [0x829] = true } } },
    { unpack(startItems) })
  assert(#outWithDex == #startItems + 1, "Menu should have 1 additional item")
  assert(outWithDex[1].id == "pokedex", "Item 1 is pokedex")
  assert(outWithDex[2].id == "dexnav", "Item 2 is dexnav")
  assert(outWithDex[2].label == "DEXNAV", "DexNav label is DEXNAV")
  assert(type(outWithDex[2].onSelect) == "function", "DexNav has onSelect function")
  assert(outWithDex[3].id == "pokemon", "Item 3 is pokemon")

  -- Test mode DEXNAV-KR
  fakeMod.options.get = function(_, k)
    if k == DexNav.OPTION_KEY then return DexNav.MODE_KR end
  end
  local outKr = hookFn(function(_, items) return items end,
    { save = { flags = { [0x829] = true } } },
    { unpack(startItems) })
  assert(outKr[2].label == "DEXNAV-KR", "DexNav label is DEXNAV-KR in dexnav_kr mode")

  -- Test mode OFF
  fakeMod.options.get = function(_, k)
    if k == DexNav.OPTION_KEY then return DexNav.MODE_OFF end
  end
  local outOff = hookFn(function(_, items) return items end,
    { save = { flags = { [0x829] = true } } },
    { unpack(startItems) })
  assert(#outOff == #startItems, "DexNav should be omitted in off mode")

  -- 9. Test buildGame3Screen
  local game = {
    session = {
      map = "ROUTE_1",
      dex = { seen = { [16] = true }, owned = { [16] = true } },
    },
  }
  local screen = DexNav.buildGame3Screen(fakeMod, game)
  assert(screen ~= nil, "buildGame3Screen returns screen object")
  assert(#screen.items > 0, "screen has wild items for Route 1")
  assert(screen.items[1].label:upper() == "PIDGEY", "first item is Pidgey")
  assert(screen.items[1].right:find("GRASS") ~= nil, "Pidgey shows grass method")
  assert(screen.footer == nil, "Route 1 has no footer")
  assert(screen:isOpen() == true, "screen starts open")

  -- Test screen input handling (colon call with B)
  local fakeInputB = {
    wasPressed = function(_, k) return k == "b" end,
    isDown = function() return false end,
  }
  local cancelRes = screen:handleInput(fakeInputB)
  assert(cancelRes == "cancel", "B button cancels and returns 'cancel'")
  assert(screen:isOpen() == false, "screen is closed after B")

  -- Test screen input handling (dot call convention from hud.lua with Start)
  local screen2 = DexNav.buildGame3Screen(fakeMod, game)
  local fakeInputStart = {
    wasPressed = function(_, k) return k == "start" end,
    isDown = function() return false end,
  }
  local startRes = screen2.handleInput(fakeInputStart)
  assert(startRes == "cancel", "Start button cancels via dot call")
  assert(screen2:isOpen() == false, "screen is closed after Start")

  -- Test screen input handling with A button
  local screen3 = DexNav.buildGame3Screen(fakeMod, game)
  local fakeInputA = {
    wasPressed = function(_, k) return k == "a" end,
    isDown = function() return false end,
  }
  local aRes = screen3.handleInput(fakeInputA)
  assert(aRes == "select", "A button selects and returns 'select'")
  assert(screen3:isOpen() == false, "screen is closed after A")

  -- Test cursor navigation with Down and Up
  local screen4 = DexNav.buildGame3Screen(fakeMod, game)
  assert(screen4.cursor == 1, "initial cursor is 1")
  local fakeInputDown = {
    wasPressed = function(_, k) return k == "down" end,
    isDown = function(_, k) return k == "down" end,
  }
  local downRes = screen4.handleInput(fakeInputDown)
  assert(downRes == "move", "Down button moves selection")
  assert(screen4.cursor == 2, "cursor moved to 2")

  local fakeInputUp = {
    wasPressed = function(_, k) return k == "up" end,
    isDown = function(_, k) return k == "up" end,
  }
  local upRes = screen4.handleInput(fakeInputUp)
  assert(upRes == "move", "Up button moves selection")
  assert(screen4.cursor == 1, "cursor moved back to 1")

  Host.clearForce()
  print("✓ Gen 3 DexNav tests passed successfully!")
end

runTests()
