package.path = package.path .. ";../../?.lua;../?.lua;./?.lua"

local Host = require("mods.Kanto-Reforged.core.host")
local RoamersGame3 = require("mods.Kanto-Reforged.world.roamers_game3")
local Roamer = require("src.core.game3.roamer")

Host.force(3)
assert(Host.isGen3(), "Host must be forced to Gen 3")

local saveStore = {}
local mockMod = {
  save = {
    get = function(self, k, default)
      if saveStore[k] ~= nil then return saveStore[k] end
      return default
    end,
    set = function(self, k, v)
      saveStore[k] = v
    end,
  },
}

RoamersGame3.install(mockMod)

-- 1. Test IV Preservation (Override of Vanilla Cart Bug)
local fullIvs = { hp = 31, atk = 31, def = 31, spa = 31, spd = 31, spe = 31 }
local testSession = {
  roamer = {
    active = true,
    species = 243,
    level = 50,
    personality = 0x12345678,
    ivs = fullIvs,
    hp = 150,
    status = 0,
    history = { false, false, false },
    map = "FR_ROUTE_1",
  }
}

local cfg = Roamer.config(testSession)
if cfg then
  Roamer._locations[cfg] = {
    { "FR_ROUTE_1", "FR_ROUTE_2" },
    { "FR_ROUTE_3", "FR_ROUTE_4" },
    { "FR_ROUTE_5", "FR_ROUTE_6" },
    { "FR_ROUTE_7", "FR_ROUTE_8" },
    { "FR_ROUTE_9", "FR_ROUTE_10" },
  }
end

-- Instance should return full IVs even with truncateIvs active in profile
local inst = Roamer.instance(testSession)
assert(inst ~= nil, "Roamer instance must be generated")
assert(inst.ivs.def == 31, "Defense IV must be 31 (not truncated to 0)")
assert(inst.ivs.spa == 31, "Sp. Atk IV must be 31 (not truncated to 0)")
assert(inst.ivs.spd == 31, "Sp. Def IV must be 31 (not truncated to 0)")
assert(inst.ivs.spe == 31, "Speed IV must be 31")

-- 2. Test Sequential 3-Beast Cycle: Raikou -> Entei -> Suicune
assert(testSession.roamer.species == 243, "First beast should be Raikou (243)")

-- Simulate battle end where Raikou is caught/defeated (outcome 1 = B_OUTCOME_WON)
Roamer.onBattleEnd(testSession, nil, "won", nil, nil)
assert(testSession.roamer.active == true, "After 1st beast resolved, roamer should be active for 2nd beast")
assert(testSession.roamer.species == 244, "Second beast must be Entei (244), got: " .. tostring(testSession.roamer.species))
assert(testSession.roamer_cycle_count == 2, "Cycle count must be 2")

-- Simulate battle end where Entei is caught/defeated
Roamer.onBattleEnd(testSession, nil, "caught", nil, nil)
assert(testSession.roamer.active == true, "After 2nd beast resolved, roamer should be active for 3rd beast")
assert(testSession.roamer.species == 245, "Third beast must be Suicune (245), got: " .. tostring(testSession.roamer.species))
assert(testSession.roamer_cycle_count == 3, "Cycle count must be 3")

-- Simulate battle end where Suicune is caught/defeated
Roamer.onBattleEnd(testSession, nil, "caught", nil, nil)
assert(testSession.roamer.active == false, "After 3rd beast resolved, roamer cycle must be fully complete (active = false)")
assert(testSession.roamer_cycle_count == 4, "Cycle count must reach 4")

print("game3_roamer_cycle_test passed cleanly!")
