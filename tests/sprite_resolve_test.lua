-- SpriteResolve: gs → flat → nil (ROM/caller).
-- luajit mods/Kanto-Reforged/tests/sprite_resolve_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local Host = require("mods.Kanto-Reforged.core.host")
local SpriteResolve = require("mods.Kanto-Reforged.core.sprite_resolve")
local SpriteCache = require("mods.Kanto-Reforged.core.sprite_cache")
local BattleSpriteScale = require("mods.Kanto-Reforged.battle.battle_sprite_scale")

GameVersion.set("red")
Host.clearForce()

local mod = { id = "Kanto-Reforged" }

T.eq(
  SpriteResolve.gsPath(mod, "ABSOL", "front"),
  "mods/Kanto-Reforged/assets/gs/ABSOL_front.png",
  "gs front path"
)
T.eq(
  SpriteResolve.flatPath(mod, "CHIKORITA", "back"),
  "mods/Kanto-Reforged/assets/chikorita_back.png",
  "flat back path lowercase"
)

-- Priority: gs > flat > nil (no FS probes).
do
  T.eq(
    SpriteResolve.resolvePath(mod, "ABSOL", "front"),
    "mods/Kanto-Reforged/assets/gs/ABSOL_front.png",
    "gs wins when both gs+flat exist"
  )
  T.check(SpriteResolve.hasGs(mod, "ABSOL", "front"), "ABSOL has gs")
  T.check(SpriteResolve.hasFlat(mod, "ABSOL", "front"), "ABSOL also in flat_index")

  -- Bayleef is flat-only in current assets (no RawSprites convert).
  if SpriteResolve.hasFlat(mod, "BAYLEEF", "front")
      and not SpriteResolve.hasGs(mod, "BAYLEEF", "front") then
    T.eq(
      SpriteResolve.resolvePath(mod, "BAYLEEF", "front"),
      "mods/Kanto-Reforged/assets/bayleef_front.png",
      "flat fallback when no gs"
    )
  else
    T.check(true, "BAYLEEF flat-only fixture not present — skip")
  end

  T.eq(SpriteResolve.resolvePath(mod, "NOT_A_MON", "front"), nil,
    "neither gs nor flat → nil (ROM)")
end

-- applyToRecord: gs art + Gen1 48px back scale.
do
  GameVersion.set("red")
  Host.clearForce()
  local rec = { dex = 359, battleScaleBack = 2, anim = { play = { 1 } } }
  SpriteResolve.applyToRecord(mod, "ABSOL", rec)
  T.check(rec.spriteFront:find("assets/gs/ABSOL_front.png", 1, true) ~= nil,
    "apply gs front")
  T.check(rec.spriteBack:find("assets/gs/ABSOL_back.png", 1, true) ~= nil,
    "apply gs back")
  T.eq(rec.anim, nil, "anim cleared for gs front")
  local expected = BattleSpriteScale.gen1ScaleForGoldBack(1, 48)
  T.eq(rec.battleScaleBack, expected, "Gen1 48px back scale")
end

-- applyToRecord: flat-only species keeps flat paths (not ROM).
do
  GameVersion.set("red")
  Host.clearForce()
  if SpriteResolve.hasFlat(mod, "BAYLEEF", "front")
      and not SpriteResolve.hasGs(mod, "BAYLEEF", "front") then
    local rec = {
      dex = 153,
      spriteFront = "assets/generated/battle/front/bayleef.png",
      spriteBack = "assets/generated/battle/back/bayleef_back.png",
    }
    SpriteResolve.applyToRecord(mod, "BAYLEEF", rec)
    T.check(rec.spriteFront:find("assets/bayleef_front.png", 1, true) ~= nil,
      "flat-only front applied over ROM path")
    T.check(rec.spriteBack:find("assets/bayleef_back.png", 1, true) ~= nil,
      "flat-only back applied over ROM path")
  else
    T.check(true, "BAYLEEF flat-only apply skipped")
    T.check(true, "BAYLEEF flat-only back skipped")
  end
end

-- Gen2: gs back stays native scale; anim cleared.
do
  GameVersion.set("gold")
  Host.clearForce()
  local rec = { dex = 25, anim = { sheet = "x" } }
  SpriteResolve.applyToRecord(mod, "PIKACHU", rec)
  T.check(rec.spriteFront:find("assets/gs/PIKACHU_front.png", 1, true) ~= nil,
    "Gen2 apply sets PIKACHU gs front")
  T.eq(rec.anim, nil, "Gen2 clears ROM anim for gs front")
  T.eq(rec.battleScaleBack, 1, "Gen2 48px back scale is 1")
end

-- Gen2: flat 32px backs must scale to 1.5 even when ROM record had battleScaleBack=1.
do
  GameVersion.set("gold")
  Host.clearForce()
  if SpriteResolve.hasFlat(mod, "AIPOM", "back")
      and not SpriteResolve.hasGs(mod, "AIPOM", "back") then
    local rec = { dex = 190, battleScaleBack = 1, anim = { sheet = "x" } }
    SpriteResolve.applyToRecord(
      { id = "Kanto-Reforged", _loader = { generation = 2 } },
      "AIPOM",
      rec
    )
    T.check(rec.spriteBack:find("assets/aipom_back.png", 1, true) ~= nil,
      "Gen2 flat AIPOM back path")
    T.eq(rec.battleScaleBack, 1.5, "Gen2 flat 32px back overrides ROM scale 1")
  else
    T.check(true, "AIPOM flat-only fixture not present — skip")
  end
end

-- Gen2 pic scale: derive from species index (gs 48→1, flat 32→1.5).
do
  GameVersion.set("gold")
  Host.clearForce()
  mod.path = "mods/Kanto-Reforged"
  T.eq(
    SpriteResolve.goldBackScaleForSpecies(mod, "TYPHLOSION"),
    1.5,
    "flat typhlosion back scales 32px to 1.5"
  )
  T.eq(
    SpriteResolve.goldBackScaleForSpecies(mod, "MEGANIUM"),
    1,
    "gs meganium 48px back stays at 1"
  )
  T.check(
    SpriteResolve.hasKrBack(mod, "TYPHLOSION"),
    "TYPHLOSION has KR flat back in index"
  )
  T.eq(SpriteResolve.backPxFor(mod, "TYPHLOSION"), 32, "TYPHLOSION backPx from flat_index")
  T.eq(SpriteResolve.backPxFor(mod, "MEGANIUM"), 48, "MEGANIUM backPx from gs_index")
  T.eq(SpriteResolve.backPxFor(mod, "NOT_A_MON"), nil, "unknown species has no backPx")
end

-- applyGoldBackScales stamps live game.data.pokemon tables.
do
  GameVersion.set("gold")
  Host.clearForce()
  local g2mod = { id = "Kanto-Reforged", path = "mods/Kanto-Reforged" }
  local live = {
    TYPHLOSION = { dex = 157, battleScaleBack = 1 },
    PIKACHU = { dex = 25, battleScaleBack = 1 },
  }
  local n = SpriteResolve.applyGoldBackScales(g2mod, live)
  T.check(n >= 2, "applyGoldBackScales touches indexed species")
  T.eq(live.TYPHLOSION.battleScaleBack, 1.5, "live TYPHLOSION stamped 1.5")
  T.eq(live.PIKACHU.battleScaleBack, 1, "live PIKACHU gs back stays 1")
end

-- applyBackPathScales stamps game.data.battle_sprite_scales for flat backs.
do
  GameVersion.set("gold")
  Host.clearForce()
  local g2mod = { id = "Kanto-Reforged", path = "mods/Kanto-Reforged" }
  local data = {}
  local n = SpriteResolve.applyBackPathScales(g2mod, data)
  T.check(n >= 1, "applyBackPathScales touches flat_index backs")
  local path = SpriteResolve.flatPath(g2mod, "TYPHLOSION", "back")
  T.eq(data.battle_sprite_scales.kr_flat_back_TYPHLOSION.path, path,
    "TYPHLOSION path scale entry")
  T.eq(data.battle_sprite_scales.kr_flat_back_TYPHLOSION.scale, 1.5,
    "TYPHLOSION flat back path scale 1.5")
  local BS = require("src.ui.gen2.BattleState")
  local view = {
    game = { data = data },
    pokemon = { TYPHLOSION = { battleScaleBack = 1 } },
    showPlayerTrainer = false,
    imageScale = BS.imageScale,
  }
  setmetatable(view, { __index = BS })
  T.eq(view:picScale(path, { species = "TYPHLOSION" }, true), 1.5,
    "vanilla picScale reads path scale from game.data")
end

-- Gen2 registry patch: flat 32px → battleScaleBack 1.5 before freeze.
do
  local Registry = require("src.mods.Registry")
  local reg = Registry.new("pokemon")
  local g2mod = {
    id = "Kanto-Reforged",
    path = "mods/Kanto-Reforged",
    _loader = { generation = 2 },
    log = { info = function() end, warn = function() end },
    content = { pokemon = reg },
  }
  GameVersion.set("gold")
  Host.clearForce()
  local patch = SpriteResolve.registryPatch(g2mod, "TYPHLOSION")
  T.check(patch ~= nil, "TYPHLOSION registry patch exists")
  T.eq(patch.battleScaleBack, 1.5, "TYPHLOSION flat back scale in registry patch")
  T.check(
    patch.spriteBack:find("typhlosion_back.png", 1, true) ~= nil,
    "TYPHLOSION flat back path in patch"
  )
  SpriteResolve.patchRegistry(g2mod)
  local merged = reg:get("TYPHLOSION")
  T.check(merged ~= nil, "registry fold has TYPHLOSION")
  T.eq(merged.battleScaleBack, 1.5, "merged TYPHLOSION battleScaleBack")
end

GameVersion.set("red")
Host.clearForce()

T.eq(SpriteCache.optionDef(mod), nil, "sprite cache option retired")
T.eq(#SpriteCache.availableEditions(mod), 0, "no editions")
T.eq(SpriteCache.resolvePath(mod, "PIKACHU", "front"), nil, "cache resolve nil")

-- Castform: Normal is gs; weather forms are gs/CASTFORM_{SUNNY,RAINY,SNOWY}_*.
do
  GameVersion.set("red")
  Host.clearForce()
  mod.path = "mods/Kanto-Reforged"
  T.check(SpriteResolve.hasGs(mod, "CASTFORM", "front"), "CASTFORM in gs_index")
  T.eq(
    SpriteResolve.resolvePath(mod, "CASTFORM", "front"),
    "mods/Kanto-Reforged/assets/gs/CASTFORM_front.png",
    "resolvePath returns gs CASTFORM front"
  )
  local rec = {
    dex = 351,
    spriteFront = "mods/Kanto-Reforged/assets/castform_front.png",
    spriteBack = "mods/Kanto-Reforged/assets/castform_back.png",
    battleScaleBack = 1.5,
  }
  SpriteResolve.applyToRecord(mod, "CASTFORM", rec)
  T.check(rec.spriteFront:find("assets/gs/CASTFORM_front.png", 1, true) ~= nil,
    "CASTFORM remapped to gs front")
  T.check(rec.spriteBack:find("assets/gs/CASTFORM_back.png", 1, true) ~= nil,
    "CASTFORM remapped to gs back")
  T.check(rec.battleScaleBack ~= nil, "CASTFORM Gen1 back scale set")
  local CastformFx = require("mods.Kanto-Reforged.battle.castform_fx")
  local ctx = { species = "CASTFORM", side = "front", kind = "battle" }
  local base = CastformFx.resolveSprite(rec.spriteFront, ctx, nil, mod)
  T.check(base:find("assets/gs/CASTFORM_front.png", 1, true), "clear-weather CastformFx base")
  package.loaded["mods.Kanto-Reforged.battle.weather"] = {
    current = function() return "RAINY" end,
  }
  local ctx2 = { species = "CASTFORM", side = "front", kind = "battle", mon = {} }
  local rainy = CastformFx.resolveSprite(rec.spriteFront, ctx2, {}, mod)
  T.check(rainy:find("CASTFORM_RAINY_front", 1, true), "rainy form sheet in gs")
  T.eq(CastformFx.paletteName("rainy"), "CASTFORM_RAINY", "rainy palette name")
  T.check(ctx2.trueColor ~= true, "rainy does not force trueColor")
end

T.finish("sprite_resolve")
