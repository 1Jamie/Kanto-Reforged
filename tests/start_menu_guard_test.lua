local Host = require("mods.Kanto-Reforged.core.host")
local SaveData = require("src.core.SaveData")
local Screens = require("src.ui.Screens")

-- Mock a minimal mod object
local mod = {
  id = "Kanto-Reforged",
  options = {
    get = function() return nil end,
  },
  save = {
    get = function() return nil end,
    set = function() end,
  },
  log = {
    info = function() end,
    warn = function() end,
    error = function() end,
  },
}

-- Ensure engine shims are installed
Host.installEngineShims(mod)

-- Test 1: SaveData.getPlayTimeSeconds
assert(type(SaveData.getPlayTimeSeconds) == "function", "SaveData.getPlayTimeSeconds should be a function")

local g1Save = { playTime = 3665 }
assert(SaveData.getPlayTimeSeconds(g1Save) == 3665, "Gen 1 playTime number extraction failed")

local g2Save = { playTime = { hours = 1, minutes = 1, seconds = 5, frames = 30 } }
assert(SaveData.getPlayTimeSeconds(g2Save) == 3665, "Gen 2 playTime table extraction failed")

local g3Save = { playtime = { hours = 2, minutes = 30, seconds = 0 } }
assert(SaveData.getPlayTimeSeconds(g3Save) == 9000, "Gen 3 playtime table extraction failed")

local emptySave = {}
assert(SaveData.getPlayTimeSeconds(emptySave) == 0, "Empty save playTime extraction failed")

-- Test 2: Screens.push / Screens.build routing on Gen 2
Host.force(2)

local fakeGame2 = {
  generation = 2,
  stack = {},
  data = {},
  save = {
    player = { name = "GOLD" },
    playTime = { hours = 1, minutes = 0, seconds = 0 },
    inventory = {},
    party = {},
  },
}
function fakeGame2.stack:push(inst)
  self[#self + 1] = inst
end

local inst = Screens.push(fakeGame2, "StartMenu")
assert(inst ~= nil, "Screens.push returned nil")
assert(inst.screenId == "Gen2StartMenu", "Expected Gen2StartMenu screenId, got " .. tostring(inst.screenId))

-- Test 3: StartMenu.new directly on Gen 2
local StartMenu = require("src.ui.StartMenu")
local startInst = StartMenu.new(fakeGame2)
assert(startInst ~= nil, "StartMenu.new returned nil")
assert(startInst.screenId == "Gen2StartMenu", "Expected StartMenu.new to return Gen2StartMenu, got " .. tostring(startInst.screenId))

Host.clearForce()
print("start_menu_guard_test: all assertions passed!")
