-- gs_palettes (from assets/gs/palettes/*.json) override species_palettes.
-- luajit mods/Kanto-Reforged/tests/gs_palettes_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Host = require("mods.Kanto-Reforged.core.host")
local PaletteGen2 = require("mods.Kanto-Reforged.pokemon.palette_gen2")
local CastformFx = require("mods.Kanto-Reforged.battle.castform_fx")
local GameVersion = require("src.core.GameVersion")

GameVersion.set("gold")
Host.clearForce()
Host.force(2)

local gs = PaletteGen2.loadGsPalettes()
T.check(gs.CASTFORM ~= nil, "gs_palettes has CASTFORM")
T.check(gs.CASTFORM_SUNNY ~= nil, "gs_palettes has CASTFORM_SUNNY")
T.check(gs.CASTFORM_RAINY ~= nil, "gs_palettes has CASTFORM_RAINY")
T.check(gs.CASTFORM_SNOWY ~= nil, "gs_palettes has CASTFORM_SNOWY")
T.eq(gs.CASTFORM_SUNNY[2][1], 255, "sunny mid-light R from JSON")
T.eq(gs.CASTFORM_SUNNY[2][2], 140, "sunny mid-light G from JSON")

local hand = {
  CASTFORM = { { 1, 1, 1 }, { 2, 2, 2 }, { 3, 3, 3 }, { 0, 0, 0 } },
  HAND_ONLY_MON = { { 255, 255, 255 }, { 1, 2, 3 }, { 4, 5, 6 }, { 0, 0, 0 } },
}
local merged = PaletteGen2.prepare(hand)
T.eq(merged.CASTFORM[2][1], 181, "gs CASTFORM overrides hand table")
T.eq(merged.HAND_ONLY_MON[2][1], 4, "hand-only mids sorted by luma")
T.eq(PaletteGen2.colorsFor("CASTFORM_SUNNY")[3][1], 198, "colorsFor sunny dark")

-- applyFormPalette mutates live Gen2 CASTFORM row on a view palettes table.
package.loaded["src.core.Data"] = {
  gen2Palettes = {
    pokemon = {
      CASTFORM = {
        normal = { { 9, 9, 9 }, { 8, 8, 8 } },
        shiny = { { 8, 8, 8 }, { 9, 9, 9 } },
      },
    },
  },
}
local viewPals = { pokemon = {} }
CastformFx.applyFormPalette("rainy", viewPals)
T.eq(viewPals.pokemon.CASTFORM.normal[1][1], 148, "rainy patches view mid1 R")
T.eq(viewPals.pokemon.CASTFORM.normal[1][2], 198, "rainy patches view mid1 G")
T.eq(viewPals.pokemon.CASTFORM.normal[2][1], 66, "rainy patches view mid2 R")

CastformFx.applyFormPalette("sunny")
local entry = package.loaded["src.core.Data"].gen2Palettes.pokemon.CASTFORM
T.eq(entry.normal[1][1], 255, "sunny form patches CASTFORM mid1 R")
T.eq(entry.normal[1][2], 140, "sunny form patches CASTFORM mid1 G")
T.eq(entry.normal[2][1], 198, "sunny form patches CASTFORM mid2 R")

CastformFx.applyFormPalette(nil)
entry = package.loaded["src.core.Data"].gen2Palettes.pokemon.CASTFORM
T.eq(entry.normal[1][1], 181, "clear restores Normal mid1 from gs")

local battle = {
  weather = "rain",
  player = { species = "CASTFORM", _krCastformForm = "sunny" },
  enemy = { species = "RATTATA" },
}
T.eq(CastformFx.activeSuffix(battle, battle.player, true), "rainy",
  "activeSuffix reads Gen2 rain weather")

battle.weather = nil
battle.player._krCastformForm = "rainy"
T.eq(CastformFx.activeSuffix(battle, battle.player, true), nil,
  "clear weather ignores stale _krCastformForm")

T.eq(CastformFx.activeSuffix(nil, { _krCastformForm = "snowy" }, true), "snowy",
  "out of battle still reads committed form")

-- SGB contract: slot 1 white, slot 4 black (Gen1 matte + Gen2 monColors).
local bad = {
  { 255, 236, 200 },
  { 104, 48, 136 },
  { 56, 28, 80 },
  { 0, 0, 0 },
}
local fixed = PaletteGen2.normalizeFourShade(bad)
T.eq(fixed[1][1], 255, "normalize forces white R")
T.eq(fixed[1][2], 255, "normalize forces white G")
T.eq(fixed[2][2], 236, "normalize keeps cream light mid")
T.eq(fixed[3][1], 104, "normalize keeps purple dark mid")
T.eq(fixed[4][3], 0, "normalize forces black B")

local creamSlot0 = {
  { 255, 236, 200 },
  { 104, 48, 136 },
  { 56, 28, 80 },
  { 0, 0, 0 },
}
local aipomFix = PaletteGen2.normalizeFourShade(creamSlot0)
T.eq(aipomFix[1][1], 255, "AIPOM cream slot0 → white anchor")
T.eq(aipomFix[2][2], 236, "AIPOM cream in light mid")
T.eq(aipomFix[3][1], 104, "AIPOM purple in dark mid")

local aipom = PaletteGen2.colorsFor("AIPOM")
T.eq(aipom[1][1], 255, "AIPOM slot 1 is white")
T.eq(aipom[2][2], 236, "AIPOM cream in light mid slot")

Host.clearForce()
T.finish("gs_palettes")
