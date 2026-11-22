package.path = package.path .. ";../../?.lua;../?.lua;./?.lua"

local Host = require("mods.Kanto-Reforged.core.host")
local LevelCaps = require("mods.Kanto-Reforged.ui.level_caps")
local Bag = require("src.core.game3.bag")
local Exp3 = require("src.core.game3.battle.experience")
local ItemUse = require("src.core.game3.item_use")
local SummaryData = require("src.core.game3.summary_data")

-- Mock mod save
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
  hooks = {
    wrap = function() end,
  },
}

Host.force(3)
assert(Host.isGen3(), "Host must be forced to Gen 3")

LevelCaps.register(mockMod)
LevelCaps.install(mockMod)

-- 1. Test Caps are off by default
saveStore[LevelCaps.SAVE_KEY] = false
assert(not LevelCaps.enabled(mockMod), "Caps should be off by default")
assert(LevelCaps.cap(mockMod, nil, { flags = {} }) == nil, "cap() should be nil when disabled")

-- 2. Test FRLG Story Milestones
local save = { flags = {} }
assert(LevelCaps.capFor(nil, save) == 14, "Gen 3 start cap should be 14")

-- Brock
save.flags[0x820] = true -- FLAG_BADGE01_GET
assert(LevelCaps.capFor(nil, save) == 16, "Gen 3 post-Brock cap should be 16")

-- Mt. Moon fossil
save.flags[0x272] = true -- FLAG_GOT_DOME_FOSSIL
assert(LevelCaps.capFor(nil, save) == 18, "Gen 3 post-Mt Moon cap should be 18")

-- Nugget Bridge
save.flags[0x31] = true -- FLAG_HIDE_NUGGET_BRIDGE_ROCKET
assert(LevelCaps.capFor(nil, save) == 21, "Gen 3 post-Nugget Bridge cap should be 21")

-- Misty
save.flags[0x821] = true -- FLAG_BADGE02_GET
assert(LevelCaps.capFor(nil, save) == 24, "Gen 3 post-Misty cap should be 24")

-- Surge
save.flags[0x822] = true -- FLAG_BADGE03_GET
assert(LevelCaps.capFor(nil, save) == 29, "Gen 3 post-Surge cap should be 29")

-- Non-linear test: defeat Koga BEFORE Erika
local nonLinearSave = { flags = { [0x820] = true, [0x821] = true, [0x822] = true, [0x824] = true } }
assert(LevelCaps.capFor(nil, nonLinearSave) == 47, "Koga beaten before Erika should yield cap 47")

-- Erika
save.flags[0x823] = true -- FLAG_BADGE04_GET
assert(LevelCaps.capFor(nil, save) == 43, "Gen 3 post-Erika cap should be 43")

-- Koga
save.flags[0x824] = true -- FLAG_BADGE05_GET
assert(LevelCaps.capFor(nil, save) == 47, "Gen 3 post-Koga cap should be 47")

-- Sabrina
save.flags[0x825] = true -- FLAG_BADGE06_GET
assert(LevelCaps.capFor(nil, save) == 50, "Gen 3 post-Sabrina cap should be 50")

-- Blaine
save.flags[0x826] = true -- FLAG_BADGE07_GET
assert(LevelCaps.capFor(nil, save) == 53, "Gen 3 post-Blaine cap should be 53")

-- Giovanni
save.flags[0x827] = true -- FLAG_BADGE08_GET
assert(LevelCaps.capFor(nil, save) == 55, "Gen 3 post-Giovanni cap should be 55")

-- Lance / E4
save.flags[0x4BB] = true -- FLAG_DEFEATED_LANCE
assert(LevelCaps.capFor(nil, save) == 65, "Gen 3 post-Lance cap should be 65")

-- Champion / Post-game clear
save.flags[0x82C] = true -- FLAG_SYS_GAME_CLEAR
assert(LevelCaps.capFor(nil, save) == 100, "Gen 3 post-game clear cap should be 100")

-- 3. Test Bag Candy Giving
local testBag = Bag.new()
local session = { bag = testBag, flags = { [0x820] = true } } -- cap 16
local given = LevelCaps.giveCandyStack(session)
assert(given == 99, "Should give 99 rare candies on empty bag, got: " .. tostring(given))
assert(Bag.get(testBag, 68) == 99, "Bag should now have 99 rare candies")

local givenAgain = LevelCaps.giveCandyStack(session)
assert(givenAgain == 0, "Top-up when full should give 0 candies")

-- 4. Enable Caps and Test Exp / Candy Clamping
LevelCaps.enable(mockMod)
assert(LevelCaps.enabled(mockMod), "Caps should now be enabled")

-- Create a test mon at level 16 (which is at cap)
local growth = 0 -- medium fast
local monAtCap = {
  species = 1, -- Bulbasaur
  level = 16,
  growthRate = growth,
  exp = SummaryData.expForLevel(growth, 16),
  maxHp = 40,
  hp = 40,
}

-- Rare candy use should fail at cap
local ok, reason = ItemUse.useRareCandy(session, monAtCap)
assert(not ok, "Rare Candy should be rejected at level cap")
assert(reason == "no_effect", "Rejection reason should be no_effect")
assert(monAtCap.level == 16, "Mon level should remain 16")

-- Exp gain should be clamped to 1 and not level up
local expRes = Exp3.apply(monAtCap, 5000)
assert(monAtCap.level == 16, "Mon level should remain 16 after huge exp gain")
local nextLevelExp = SummaryData.expForLevel(growth, 17)
assert(monAtCap.exp < nextLevelExp, "Mon exp should be pinned below level 17")

-- Test mon below cap leveling up into cap:
local monLow = {
  species = 1,
  level = 14,
  growthRate = growth,
  exp = SummaryData.expForLevel(growth, 14),
  maxHp = 35,
  hp = 35,
}

-- Award massive XP: it should stop at cap (16), not exceed it
local expRes2 = Exp3.apply(monLow, 50000)
assert(monLow.level == 16, "Mon leveling up from below cap should clamp to cap (16), got: " .. tostring(monLow.level))
assert(monLow.exp <= SummaryData.expForLevel(growth, 17) - 1, "Mon exp should not exceed cap + 1 threshold")

-- 5. Test Youngster NPC spawn & collision in Viridian City
local Objects = require("src.core.game3.objects")
local Space = require("src.core.game3.scripting.space")
Space.bundle = {
  events = {
    FR_VIRIDIAN_CITY = {
      objects = {
        { localId = 1, x = 8, y = 26, graphicsId = 27 },
      }
    }
  }
}
Objects.loadMap(nil, "FR_VIRIDIAN_CITY", { midLayout = { width = 48, height = 40 } })
local youngNpc = Objects.find(88)
assert(youngNpc ~= nil, "Youngster NPC (localId=88) must be spawned on FR_VIRIDIAN_CITY")
assert(youngNpc.cellX == 31 and youngNpc.cellY == 20, "Youngster must be at (31, 20)")
assert(youngNpc.sprite == "SPRITE_YOUNGSTER", "Youngster sprite must be SPRITE_YOUNGSTER")
assert(Objects.blocks(31, 20) == true, "Youngster must block tile (31, 20)")

print("game3_level_caps_test passed cleanly!")
