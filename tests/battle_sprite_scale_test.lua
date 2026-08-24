-- Unit tests for cross-game battle sprite scale helpers (no Love required).
-- Run from repo root:
--   luajit mods/Kanto-Reforged/tests/battle_sprite_scale_test.lua

package.path = "mods/?.lua;mods/?/init.lua;" .. package.path

local fails = 0
local function eq(a, b, msg)
  local ok = type(a) == "number" and type(b) == "number"
    and math.abs(a - b) < 1e-9
    or a == b
  if not ok then
    fails = fails + 1
    print("FAIL:", msg or "", "got", tostring(a), "expected", tostring(b))
  end
end

local Scale = require("mods.Kanto-Reforged.battle.battle_sprite_scale")
local PokemonGen2 = require("mods.Kanto-Reforged.pokemon.pokemon_gen2")

local f, b = Scale.gen1FromFraction(1, 1)
eq(f, 1, "gen1 normal front"); eq(b, 2, "gen1 normal back")
f, b = Scale.gen1FromFraction(0.65)
eq(f, 0.65, "natu gen1 front"); eq(b, 1.3, "natu gen1 back")

f, b = Scale.defaultsForGen1ArtOnGold()
eq(f, 1, "gold KR front"); eq(b, 1.5, "gold KR back")

f, b = Scale.gen1ToGold(0.65, 1.3)
eq(f, 0.65, "natu gold front"); eq(b, 0.975, "natu gold back")

local out = {}
Scale.applyGen1RecordToGold(out, {})
eq(out.battleScaleFront, nil, "no front when unset")
eq(out.battleScaleBack, 1.5, "back compensated")

out = {}
Scale.applyGen1RecordToGold(out, { battleScaleFront = 0.65 })
eq(out.battleScaleFront, 0.65, "front-only")
eq(out.battleScaleBack, 1.5, "front-only back default")

eq(Scale.gen1ScaleForGoldBack(1), 64 / 48, "48px on gen1")

-- Gold-derived back: convert Gen1-32px absolutes into Gen1-48px API scales
local rec = { battleScaleFront = 0.65, battleScaleBack = 1.3 }
Scale.applyGoldBackOnGen1(rec)
eq(rec.battleScaleBack, 0.65 * 64 / 48, "natu fraction kept on 48px back")
rec = {}
Scale.applyGoldBackOnGen1(rec)
eq(rec.battleScaleBack, 64 / 48, "default gold back on gen1")

local g2 = PokemonGen2.toGen2Record({
  id = "TREECKO", name = "TREECKO", dex = 252,
  types = { "GRASS" },
  baseStats = { hp = 40, attack = 45, defense = 35, speed = 70, special = 65 },
  level1Moves = { "POUND" },
  spriteFront = "a", spriteBack = "b",
})
eq(g2.battleScaleBack, 1.5, "Hoenn back on Gold")
eq(g2.battleScaleFront, nil, "Hoenn front default")

local scaled = PokemonGen2.toGen2Record({
  id = "X", name = "X", dex = 252,
  types = { "NORMAL" },
  baseStats = { hp = 1, attack = 1, defense = 1, speed = 1, special = 1 },
  level1Moves = { "POUND" },
  battleScaleFront = 0.65, battleScaleBack = 1.3,
  spriteFront = "a", spriteBack = "b",
})
eq(scaled.battleScaleFront, 0.65, "scaled front")
eq(scaled.battleScaleBack, 0.975, "scaled back")

-- Gen1 Hoenn default: match Gen2 on-screen without mutating shared data.
local castform = { id = "CASTFORM", dex = 351, battleScaleBack = nil }
local reg = Scale.gen1RegisterCopy(castform)
eq(reg.battleScaleBack, 1.5, "castform gen1 back matches gen2 on-screen")
eq(castform.battleScaleBack, nil, "shared record untouched")
local g2After = PokemonGen2.toGen2Record({
  id = "CASTFORM", name = "CASTFORM", dex = 351,
  types = { "NORMAL" },
  baseStats = { hp = 1, attack = 1, defense = 1, speed = 1, special = 1 },
  level1Moves = { "POUND" },
  spriteFront = "a", spriteBack = "b",
})
eq(g2After.battleScaleBack, 1.5, "gen2 castform still 1.5 after gen1 copy helper")

local authored = { dex = 252, battleScaleBack = 1.3 }
eq(Scale.gen1RegisterCopy(authored), authored, "authored back reused")
eq(authored.battleScaleBack, 1.3, "authored back kept")

local johto = { dex = 177 }
eq(Scale.gen1RegisterCopy(johto), johto, "johto not auto-scaled")

if fails == 0 then
  print("OK battle_sprite_scale tests")
  os.exit(0)
end
print(fails .. " failure(s)")
os.exit(1)
