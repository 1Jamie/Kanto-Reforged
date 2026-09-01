-- Retired sprite cache stubs.
-- luajit mods/Kanto-Reforged/tests/sprite_cache_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local Host = require("mods.Kanto-Reforged.core.host")
local SpriteCache = require("mods.Kanto-Reforged.core.sprite_cache")

GameVersion.set("red")
Host.clearForce()

T.eq(SpriteCache.SOURCE_CUSTOM, "custom", "custom id")
T.eq(SpriteCache.OPTION_KEY, "sprite_source", "option key name")
T.eq(SpriteCache.optionDef({ id = "Kanto-Reforged" }), nil,
  "SPRITES option retired on Gen1")
T.eq(#SpriteCache.availableEditions({ id = "Kanto-Reforged" }), 0,
  "no edition caches exposed")

GameVersion.set("gold")
Host.clearForce()
T.eq(SpriteCache.optionDef({ id = "Kanto-Reforged" }), nil,
  "SPRITES option retired on Gen2")

GameVersion.set("red")
Host.clearForce()
T.finish("sprite_cache")
