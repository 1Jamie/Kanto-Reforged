-- Sprite cache helpers (edition availability + Gen1 option shape).
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

-- Gen1 option hidden when no caches.
local opt = SpriteCache.optionDef({ id = "Kanto-Reforged" })
T.check(opt == nil, "no SPRITES option without caches")

-- Fake a gold ready marker via love.filesystem if present; otherwise skip.
local f = love and love.filesystem
if f and f.createDirectory and f.write then
  local dir = "save/mod-derived/Kanto-Reforged/sprites/gold"
  f.createDirectory(dir)
  f.write(dir .. "/ready.png", "ok")
  local opt2 = SpriteCache.optionDef({ id = "Kanto-Reforged" })
  T.check(opt2 ~= nil, "SPRITES option appears with gold cache")
  T.eq(opt2.key, "sprite_source", "option key")
  T.check(#opt2.choices >= 2, "custom + gold choices")
  local eds = SpriteCache.availableEditions({ id = "Kanto-Reforged" })
  T.check(#eds >= 1 and eds[1] == "gold", "availableEditions lists gold")
else
  T.check(true, "love.filesystem absent — skip ready-marker checks")
end

-- Gen2 hides the option.
GameVersion.set("gold")
Host.clearForce()
T.check(SpriteCache.optionDef({ id = "Kanto-Reforged" }) == nil,
  "Gen2 boot: no SPRITES 1-251 option")

GameVersion.set("red")
Host.clearForce()
T.finish("sprite_cache")
