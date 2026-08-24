-- Castform Forecast: fade between weather sprites (Gen 3-style, vanilla+).
-- Gen 1 patches BattleState picFx.fade (same path as Silph Scope ghost reveal).
-- Gen 2 crossfades via pokemon.sprite path picks + drawPic alpha passes, and
-- holds the event queue for TOTAL frames the way Gen 1 waitNext does.

local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
local Host = require("mods.Kanto-Reforged.core.host")

local CastformFx = {}

CastformFx.FADE_OUT = 16
CastformFx.FADE_IN = 20
CastformFx.TOTAL = CastformFx.FADE_OUT + CastformFx.FADE_IN

local function suffixForType(typ)
  if typ == "FIRE" then return "sunny" end
  if typ == "WATER" then return "rainy" end
  if typ == "ICE" then return "snowy" end
  return nil
end

function CastformFx.assetPath(mod, side, suffix)
  if not mod or not mod.path then return nil end
  local face = (side == "back") and "back" or "front"
  if suffix then
    return mod.path .. "/assets/castform_" .. suffix .. "_" .. face .. ".png"
  end
  return mod.path .. "/assets/castform_" .. face .. ".png"
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

-- Gen2 BattleState:pic / Sprites.path: swap the path and set ctx.trueColor so
-- Gold skips GbcPalette (KR form PNGs are already coloured).  Mutating
-- battler.sprite is a Gen1-only surface.
function CastformFx.resolveSprite(path, ctx, battle, mod)
  if not ctx or ctx.species ~= "CASTFORM" then return path end
  if ctx.kind and ctx.kind ~= "battle" then return path end

  local inMorph, morphSuffix = CastformFx.morphSuffix(battle, ctx)
  local suffix
  if inMorph then
    suffix = morphSuffix
  else
    if battle then
      local Weather = require("mods.Kanto-Reforged.battle.weather")
      suffix = BattleCompat.castformSuffix(Weather.current(battle))
    end
    local mon = ctx.mon
    if suffix == nil and mon then
      suffix = mon._krCastformForm
    end
    if suffix == nil then return path end
    if mon then mon._krCastformForm = suffix end
  end

  ctx.trueColor = true
  return CastformFx.assetPath(mod or CastformFx._mod, ctx.side, suffix) or path
end

local function loadGen1Sprite(battle, battler, path)
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
  if not path or not love or not love.graphics then return nil end
  local ok, img = pcall(love.graphics.newImage, path)
  return ok and img or nil
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
    end
  end
  battle._krCastformMorph = nil
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
  local newSprite = loadGen1Sprite(battle, battler,
    CastformFx.assetPath(mod, isPlayer and "back" or "front", newSuffix))
  if not newSprite then return end
  if oldSprite == newSprite then return end

  if type(battle.startPicMorph) == "function" then
    battle:startPicMorph(battler, newSprite, { oldSprite = oldSprite })
  elseif newSprite then
    battler.sprite = newSprite
  end
end

function CastformFx.drawGen2Morph(view, mon, back, morph, origDrawPic)
  local G = love.graphics
  local t = morph.t or 0
  local out = CastformFx.FADE_OUT
  if t >= CastformFx.TOTAL then
    morph.drawPass = nil
    return origDrawPic(view, mon, back)
  end

  local function drawPass(pass, alpha)
    if alpha <= 0 then return end
    morph.drawPass = pass
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
        }
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
              pf.fade = 1 - m.t / CastformFx.FADE_OUT
            elseif m.t <= CastformFx.TOTAL then
              if not m.swapped then
                m.swapped = true
                battler.sprite = m.newSprite or battler.sprite
              end
              pf.fade = (m.t - CastformFx.FADE_OUT) / CastformFx.FADE_IN
            else
              battler.sprite = m.newSprite or battler.sprite
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
