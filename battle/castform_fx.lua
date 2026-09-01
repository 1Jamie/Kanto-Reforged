-- Castform Forecast: fade between weather sprites (Gen 3-style, vanilla+).
-- Gen 1 patches BattleState picFx.fade (same path as Silph Scope ghost reveal).
-- Gen 2 crossfades via pokemon.sprite path picks + drawPic alpha passes, and
-- holds the event queue for TOTAL frames the way Gen 1 waitNext does.
--
-- Art lives under assets/gs/ (DMG grayscale + palette JSON, same as every mon):
--   CASTFORM_{front,back}.png
--   CASTFORM_{SUNNY,RAINY,SNOWY}_{front,back}.png
-- Forecast swaps the live CASTFORM palette row to the form's mid colors
-- from gs_palettes / species_palettes (CASTFORM / CASTFORM_SUNNY / …) so
-- GbcPalette remaps correctly — no trueColor bypass.

local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
local Host = require("mods.Kanto-Reforged.core.host")
local PaletteGen2 = require("mods.Kanto-Reforged.pokemon.palette_gen2")

local CastformFx = {}

CastformFx.FADE_OUT = 16
CastformFx.FADE_IN = 20
CastformFx.TOTAL = CastformFx.FADE_OUT + CastformFx.FADE_IN

local FORM_PALETTE = {
  sunny = "CASTFORM_SUNNY",
  rainy = "CASTFORM_RAINY",
  snowy = "CASTFORM_SNOWY",
}

local function suffixForType(typ)
  if typ == "FIRE" then return "sunny" end
  if typ == "WATER" then return "rainy" end
  if typ == "ICE" then return "snowy" end
  return nil
end

function CastformFx.paletteName(suffix)
  if suffix and FORM_PALETTE[suffix] then return FORM_PALETTE[suffix] end
  return "CASTFORM"
end

--- Resolve which Forecast form sheet/palette is active for a draw.
-- In battle, weather is the source of truth (nil → Normal). Never fall back
-- to a stale mon._krCastformForm after weather ends — that kept rainy/sunny
-- art up and carried into the next fight.
function CastformFx.activeSuffix(battle, mon, back)
  if battle and mon then
    local morphAll = battle._krCastformMorph
    if morphAll then
      local side = back and "player" or "enemy"
      if mon.isPlayer == true or mon == battle.player then
        side = "player"
      elseif mon == battle.enemy then
        side = "enemy"
      elseif not back and mon.isPlayer == false then
        side = "enemy"
      end
      local m = morphAll[side]
      if m and (m.t or 0) < CastformFx.TOTAL then
        if m.drawPass == "old" then return m.oldSuffix end
        if m.drawPass == "new" then return m.newSuffix end
        if (m.t or 0) <= CastformFx.FADE_OUT then return m.oldSuffix end
        return m.newSuffix
      end
    end
    local Weather = require("mods.Kanto-Reforged.battle.weather")
    return BattleCompat.castformSuffix(Weather.current(battle))
  end
  if mon then return mon._krCastformForm end
  return nil
end

--- Write CASTFORM's Gen2 mid-pair (or Gen1 named pack) for `suffix`.
-- `palettesRoot` is optional Gen2 `BattleState.palettes` / `Data.gen2Palettes`.
function CastformFx.applyFormPalette(suffix, palettesRoot)
  local colors = PaletteGen2.colorsFor(CastformFx.paletteName(suffix))
    or PaletteGen2.colorsFor("CASTFORM")
  if type(colors) ~= "table" then return end

  if Host.isGen2() then
    local pair = PaletteGen2.midPair(colors)
    if not pair then return end
    local function patchRoot(root)
      if type(root) ~= "table" then return end
      root.pokemon = root.pokemon or {}
      root.pokemon.CASTFORM = {
        normal = { pair[1], pair[2] },
        shiny = { pair[2], pair[1] },
      }
    end
    patchRoot(palettesRoot)
    local ok, Data = pcall(require, "src.core.Data")
    if ok and Data then patchRoot(Data.gen2Palettes) end
    local mod = CastformFx._mod
    if mod and mod.content and mod.content.palettes then
      local live = mod.content.palettes:get("pokemon")
      if type(live) == "table" then
        live.CASTFORM = {
          normal = { pair[1], pair[2] },
          shiny = { pair[2], pair[1] },
        }
      end
    end
    local game = mod and Host.liveGame and Host.liveGame(mod)
    if game and game.data then patchRoot(game.data.gen2Palettes) end
    return
  end

  local ok, Data = pcall(require, "src.core.Data")
  if ok and Data and Data.palettes and Data.palettes.palettes then
    Data.palettes.palettes.CASTFORM = colors
  end
  local mod = CastformFx._mod
  if mod and mod.content and mod.content.palettes then
    pcall(function()
      mod.content.palettes:register("CASTFORM", colors)
    end)
  end
  local game = mod and Host.liveGame and Host.liveGame(mod)
  if game and game.data and game.data.palettes and game.data.palettes.palettes then
    game.data.palettes.palettes.CASTFORM = colors
  end
end

function CastformFx.assetPath(mod, side, suffix)
  if not mod or not mod.path then return nil end
  local face = (side == "back") and "back" or "front"
  if suffix then
    return mod.path .. "/assets/gs/CASTFORM_" .. string.upper(suffix)
      .. "_" .. face .. ".png"
  end
  return mod.path .. "/assets/gs/CASTFORM_" .. face .. ".png"
end

-- Active morph on this side: returns inMorph, suffix (suffix may be nil).
function CastformFx.morphSuffix(battle, ctx)
  if not battle or not ctx then return false end
  local morphAll = battle._krCastformMorph
  if not morphAll then return false end
  local side = (ctx.side == "back") and "player" or "enemy"
  local m = morphAll[side]
  if not m or (m.t or 0) >= CastformFx.TOTAL then return false end
  if m.drawPass == "old" then return true, m.oldSuffix end
  if m.drawPass == "new" then return true, m.newSuffix end
  if (m.t or 0) <= CastformFx.FADE_OUT then return true, m.oldSuffix end
  return true, m.newSuffix
end

-- Gen2 BattleState:pic / Sprites.path: swap path + live CASTFORM palette.
-- Mutating battler.sprite is a Gen1-only surface.
function CastformFx.resolveSprite(path, ctx, battle, mod)
  if not ctx or ctx.species ~= "CASTFORM" then return path end
  if ctx.kind and ctx.kind ~= "battle" then return path end

  local modRef = mod or CastformFx._mod
  local back = ctx.side == "back"
  local suffix = CastformFx.activeSuffix(battle, ctx.mon, back)
  if ctx.mon then
    -- Keep committed form in sync with weather (including clear → nil).
    ctx.mon._krCastformForm = suffix
  end
  CastformFx.applyFormPalette(suffix)
  return CastformFx.assetPath(modRef, ctx.side, suffix) or path
end

local function bakeIndexedImage(path, colors)
  if not path or not colors then return nil end
  if not love or not love.graphics then return nil end
  local Assets = require("src.render.Assets")
  local ok, id = pcall(Assets.imageData, path)
  if not ok or not id then
    local okImg, img = pcall(love.graphics.newImage, path)
    return okImg and img or nil
  end
  local c = colors.colors or colors
  id:mapPixel(function(_, _, r, g, b, a)
    if a == 0 then return r, g, b, a end
    local col = r > 0.83 and c[1] or r > 0.5 and c[2]
      or r > 0.17 and c[3] or c[4]
    return col[1] / 255, col[2] / 255, col[3] / 255, a
  end)
  return love.graphics.newImage(id)
end

local function loadGen1Sprite(battle, battler, path, suffix)
  CastformFx.applyFormPalette(suffix)
  local colors = PaletteGen2.colorsFor(CastformFx.paletteName(suffix))
    or PaletteGen2.colorsFor("CASTFORM")
  if path and colors then
    local img = bakeIndexedImage(path, colors)
    if img then return img end
  end
  if path and love and love.graphics and love.graphics.newImage then
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then return img end
  end
  if battle and type(battle.speciesSprite) == "function" then
    local isPlayer = battler.isPlayer or battler == battle.player
    local ok, spr = pcall(function()
      return battle:speciesSprite("CASTFORM", isPlayer)
    end)
    if ok and spr then return spr end
  end
  local okS, Sprites = pcall(require, "src.pokemon.Sprites")
  if not okS or not Sprites or not Sprites.path then return nil end
  local isPlayer = battler.isPlayer or battler == battle.player
  path = select(1, Sprites.path(battle.data, "CASTFORM",
    isPlayer and "back" or "front",
    { mon = BattleCompat.mon(battler), kind = "battle" }))
  if not path then return nil end
  return bakeIndexedImage(path, colors) or (love and love.graphics
    and select(2, pcall(love.graphics.newImage, path)))
end

local function tickMorph(morphAll)
  if not morphAll then return end
  for side, m in pairs(morphAll) do
    if m and m.holding then
      m.t = (m.t or 0) + 1
    end
  end
end

function CastformFx.finishMorph(battle)
  if not battle or not battle._krCastformMorph then return end
  for side, m in pairs(battle._krCastformMorph) do
    if m then
      local mon = (side == "player") and battle.player or battle.enemy
      if mon then
        mon._krCastformForm = m.newSuffix
      end
      CastformFx.applyFormPalette(m.newSuffix)
    end
  end
  battle._krCastformMorph = nil
end

--- Clear Forecast art/palette leftovers between battles (Gold party mons
-- keep fields unless scrubbed; palette patches outlive the fight).
function CastformFx.resetOutOfBattle(mod)
  CastformFx._mod = mod or CastformFx._mod
  CastformFx.applyFormPalette(nil)
  local game = CastformFx._mod and Host.liveGame and Host.liveGame(CastformFx._mod)
  local party = game and game.save and game.save.party
  for _, mon in ipairs(party or {}) do
    if type(mon) == "table" then
      mon._krCastformForm = nil
    end
  end
end

function CastformFx.play(battle, battler, oldType)
  if not battle or not battler then return end
  if BattleCompat.species(battler) ~= "CASTFORM" then return end
  local mod = CastformFx._mod
  if not mod then return end

  local isPlayer = battler.isPlayer or battler == battle.player
  local sideKey = isPlayer and "player" or "enemy"
  local oldSuffix = suffixForType(oldType)
  local newSuffix = suffixForType((BattleCompat.types(battler)[1]))

  if BattleCompat.isGen2(battle) then
    battle._krCastformMorph = battle._krCastformMorph or {}
    battle._krCastformMorph[sideKey] = {
      t = 0,
      holding = false,
      oldSuffix = oldSuffix,
      newSuffix = newSuffix,
    }
    if type(battle.emit) == "function" then
      battle:emit({ kind = "kr-castform-morph", frames = CastformFx.TOTAL })
    end
    return
  end

  local oldSprite = battler.sprite
  local face = isPlayer and "back" or "front"
  local newPath = CastformFx.assetPath(mod, face, newSuffix)
  local newSprite = loadGen1Sprite(battle, battler, newPath, newSuffix)
  if not newSprite then return end
  if oldSprite == newSprite then
    CastformFx.applyFormPalette(newSuffix)
    return
  end

  if type(battle.startPicMorph) == "function" then
    battle:startPicMorph(battler, newSprite, {
      oldSprite = oldSprite,
      oldSuffix = oldSuffix,
      newSuffix = newSuffix,
    })
  elseif newSprite then
    battler.sprite = newSprite
    CastformFx.applyFormPalette(newSuffix)
  end
end

function CastformFx.drawGen2Morph(view, mon, back, morph, origDrawPic)
  local G = love.graphics
  local t = morph.t or 0
  local out = CastformFx.FADE_OUT
  if t >= CastformFx.TOTAL then
    morph.drawPass = nil
    CastformFx.applyFormPalette(morph.newSuffix, view.palettes)
    return origDrawPic(view, mon, back)
  end

  local function drawPass(pass, alpha)
    if alpha <= 0 then return end
    morph.drawPass = pass
    local suffix = (pass == "old") and morph.oldSuffix or morph.newSuffix
    CastformFx.applyFormPalette(suffix, view.palettes)
    local cr, cg, cb, ca = G.getColor()
    G.setColor(cr, cg, cb, ca * alpha)
    origDrawPic(view, mon, back)
    G.setColor(cr, cg, cb, ca)
  end

  morph.drawPass = nil
  if t <= out then
    drawPass("old", 1 - t / out)
  else
    drawPass("new", (t - out) / CastformFx.FADE_IN)
  end
  morph.drawPass = nil
end

local function morphHoldActive(view)
  return (view._krCastformHold or 0) > 0
end

-- Intro slide / trainer slide must keep running; blocking update broke pic scale.
local function allowMorphHold(view)
  local AnimView = require("src.ui.gen2.BattleAnimView")
  if view.slideFrame < AnimView.SLIDE_FRAMES then return false end
  if view.winSliding or view.trainerSlide or view.faintSlide then return false end
  return true
end

function CastformFx.install(mod)
  CastformFx._mod = mod
  if Host.isGen1() then
    Gen1Patch.apply(require("src.battle.BattleState"), function(BS)
      if BS._krCastformFx then return end

      function BS:startPicMorph(battler, newSprite, opts)
        opts = opts or {}
        self.picMorph = self.picMorph or {}
        self.picMorph[battler] = {
          t = 0,
          newSprite = newSprite,
          oldSprite = opts.oldSprite or battler.sprite,
          oldSuffix = opts.oldSuffix,
          newSuffix = opts.newSuffix,
        }
        CastformFx.applyFormPalette(opts.oldSuffix)
        if type(self.waitNext) == "function" then
          self:waitNext(CastformFx.TOTAL)
        end
      end

      local origUpdateFx = BS.updateFx
      BS.updateFx = function(self)
        if self.picMorph then
          for battler, m in pairs(self.picMorph) do
            m.t = (m.t or 0) + 1
            local pf = self:picFxFor(battler)
            if m.t <= CastformFx.FADE_OUT then
              battler.sprite = m.oldSprite or battler.sprite
              CastformFx.applyFormPalette(m.oldSuffix)
              pf.fade = 1 - m.t / CastformFx.FADE_OUT
            elseif m.t <= CastformFx.TOTAL then
              if not m.swapped then
                m.swapped = true
                battler.sprite = m.newSprite or battler.sprite
                CastformFx.applyFormPalette(m.newSuffix)
              end
              pf.fade = (m.t - CastformFx.FADE_OUT) / CastformFx.FADE_IN
            else
              battler.sprite = m.newSprite or battler.sprite
              CastformFx.applyFormPalette(m.newSuffix)
              pf.fade = nil
              self.picMorph[battler] = nil
            end
          end
        end
        return origUpdateFx(self)
      end
      BS._krCastformFx = true
    end)
  end

  if Host.isGen2() then
    Gen1Patch.apply(require("src.ui.gen2.BattleState"), function(BS)
      if BS._krCastformFx then return end

      local origDrawPic = BS.drawPic
      BS.drawPic = function(self, mon, back)
        if mon and mon.species == "CASTFORM" then
          local suffix = CastformFx.activeSuffix(self.battle, mon, back)
          -- Patch the view's own palettes table — drawPic reads self.palettes,
          -- which is not always the same object as Data.gen2Palettes.
          CastformFx.applyFormPalette(suffix, self.palettes)
        end
        local morphAll = self.battle and self.battle._krCastformMorph
        local side = back and "player" or "enemy"
        local morph = morphAll and morphAll[side]
        if morph and morph.holding and mon and mon.species == "CASTFORM"
            and (morph.t or 0) < CastformFx.TOTAL then
          return CastformFx.drawGen2Morph(self, mon, back, morph, function(v, m, b)
            origDrawPic(v, m, b)
          end)
        end
        return origDrawPic(self, mon, back)
      end

      local origAdvance = BS.advanceQueue
      BS.advanceQueue = function(self)
        local head = self.queue and self.queue[1]
        if head and head.kind == "kr-castform-morph" then
          table.remove(self.queue, 1)
          local morphAll = self.battle and self.battle._krCastformMorph
          if morphAll then
            for _, m in pairs(morphAll) do
              if m then
                m.holding = true
                m.t = m.t or 0
              end
            end
          end
          self._krCastformHold = head.frames or CastformFx.TOTAL
          return
        end
        return origAdvance(self)
      end

      local origUpdate = BS.update
      BS.update = function(self, dt)
        if morphHoldActive(self) and allowMorphHold(self) then
          tickMorph(self.battle and self.battle._krCastformMorph)
          self._krCastformHold = self._krCastformHold - 1
          if self._krCastformHold <= 0 then
            self._krCastformHold = nil
            CastformFx.finishMorph(self.battle)
            return origAdvance(self)
          end
          return
        end
        if morphHoldActive(self) and not allowMorphHold(self) then
          tickMorph(self.battle and self.battle._krCastformMorph)
          self._krCastformHold = self._krCastformHold - 1
          if self._krCastformHold <= 0 then
            self._krCastformHold = nil
            CastformFx.finishMorph(self.battle)
          end
        end
        return origUpdate(self, dt)
      end
      BS._krCastformFx = true
    end)
  end
end

return CastformFx
