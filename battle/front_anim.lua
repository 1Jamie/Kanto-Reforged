-- GS front idle animation (horizontal or vertical strips) for every host that lacks
-- Crystal MonAnim — and for Crystal too whenever KR gs art has a strip.
-- Crystal's vertical bitmask MonAnim is the fallback ONLY on Crystal edition
-- AND ONLY for species without a gs_anim_index entry (vanilla ROM mons).

local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
local Host = require("mods.Kanto-Reforged.core.host")
local SpriteResolve = require("mods.Kanto-Reforged.core.sprite_resolve")

local FrontAnim = {}

FrontAnim.FPS = 60
-- Crystal AnimateFrontpic runs the play script once per send-out; most species
-- repeat their wiggle twice inside that script.  Match that: two full strip
-- passes, then hold frame 1 (same pose as the static front pic).
FrontAnim.BATTLE_CYCLES = 2

function FrontAnim.battleCycles(meta)
  local n = meta and meta.battleCycles
  if type(n) == "number" and n >= 1 then return math.floor(n) end
  return FrontAnim.BATTLE_CYCLES
end

function FrontAnim.resetState(st)
  st.frame = 1
  st.timer = 0
  st.cycles = 0
  st.done = false
end

function FrontAnim.restartGen2Mon(view, mon)
  if not (view and mon) then return end
  FrontAnim.resetState(FrontAnim.gen2State(view, mon))
end

--- Gen1: no strip playback while the pic is still arriving (intro slide,
-- trainer pic walking off, ball beat, grow-in from the ball).
function FrontAnim.presentationHoldsEnemyGen1(battle, battler)
  if not battle or not battler or battler.isPlayer then return false end
  if (battle.introSlide or 0) > 0 then return true end
  if battle.enemySendingOut then return true end
  local grow = battle.growIn
  if grow and grow.battler == battler then return true end
  local picOff = battle.picOff
  if picOff and picOff.foe then return true end
  return false
end

function FrontAnim.syncGen1Hold(battle, battler)
  local holding = FrontAnim.presentationHoldsEnemyGen1(battle, battler)
  local was = battler._krFrontAnimHeld
  if was and not holding and battler._krFrontAnim then
    FrontAnim.resetState(battler._krFrontAnim)
  end
  battler._krFrontAnimHeld = holding
  return holding
end

--- Gen2: intro slide, trainer frontpic, ball hide, win/faint slides.
function FrontAnim.presentationHoldsEnemyGen2(view, mon)
  if not view or not mon then return true end
  if mon ~= (view.battle and view.battle.enemy) then return false end
  local AnimView = require("src.ui.gen2.BattleAnimView")
  if (view.slideFrame or 0) < AnimView.SLIDE_FRAMES then return true end
  if view.showEnemyTrainer then return true end
  if view.winSliding or view.trainerSlide or view.faintSlide then return true end
  if view.picHidden and view.picHidden.enemy then return true end
  return false
end

function FrontAnim.syncGen2Hold(view, mon)
  local holding = FrontAnim.presentationHoldsEnemyGen2(view, mon)
  view._krFrontAnimHeld = view._krFrontAnimHeld or {}
  local was = view._krFrontAnimHeld[mon]
  if was and not holding then
    FrontAnim.restartGen2Mon(view, mon)
  end
  view._krFrontAnimHeld[mon] = holding
  return holding
end

local function loadIndex()
  package.loaded["mods.Kanto-Reforged.pokemon.gs_anim_index"] = nil
  local ok, t = pcall(require, "mods.Kanto-Reforged.pokemon.gs_anim_index")
  if ok and type(t) == "table" then return t end
  return {}
end

function FrontAnim.meta(speciesId)
  if not speciesId then return nil end
  local m = loadIndex()[speciesId]
  if not m or (m.frameCount or 0) < 2 then return nil end
  return m
end

function FrontAnim.hasAnim(speciesId)
  return FrontAnim.meta(speciesId) ~= nil
end

--- "horizontal" (frames in a row) or "vertical" (stacked). Uses meta.layout when
--- set; otherwise infers from strip pixel dimensions.
function FrontAnim.stripLayout(meta, stripW, stripH)
  if not meta then return "horizontal" end
  local layout = meta.layout
  if layout == "vertical" or layout == "v" then return "vertical" end
  if layout == "horizontal" or layout == "h" then return "horizontal" end
  local fc = meta.frameCount or 1
  local fw, fh = meta.frontW or 0, meta.frontH or 0
  if fw > 0 and fh > 0 and fc > 0 and stripW and stripH then
    if stripW == fw * fc and stripH == fh then return "horizontal" end
    if stripH == fh * fc and stripW == fw then return "vertical" end
    if stripW >= stripH and stripW >= fw * fc then return "horizontal" end
    if stripH > stripW and stripH >= fh * fc then return "vertical" end
  end
  return "horizontal"
end

--- Top-left pixel offset for a 1-based frame index inside the strip sheet.
function FrontAnim.frameOffset(meta, frame, stripW, stripH)
  local fw, fh = meta.frontW, meta.frontH
  local idx = (frame or 1) - 1
  if FrontAnim.stripLayout(meta, stripW, stripH) == "vertical" then
    return 0, idx * fh
  end
  return idx * fw, 0
end

local function castformSuffix(battle, mon)
  local ok, CastformFx = pcall(require, "mods.Kanto-Reforged.battle.castform_fx")
  if not ok then return nil end
  return CastformFx.activeSuffix(battle, mon, false)
end

--- Species id used to look up strip metadata (Forecast forms).
function FrontAnim.animSpeciesId(speciesId, battle, mon)
  if speciesId == "CASTFORM" then
    local suffix = castformSuffix(battle, mon)
    if suffix then return "CASTFORM_" .. string.upper(suffix) end
  end
  return speciesId
end

--- True when this mon should use KR horizontal strips (all editions).
function FrontAnim.prefersKrAnim(speciesId, battle, mon, mod)
  if not speciesId then return false end
  mod = mod or FrontAnim._mod
  local animId = FrontAnim.animSpeciesId(speciesId, battle, mon)
  if not FrontAnim.meta(animId) then return false end
  if mod then
    if SpriteResolve.hasGs(mod, animId, "front") then return true end
    if animId ~= speciesId and SpriteResolve.hasGs(mod, speciesId, "front") then
      return true
    end
    return false
  end
  return true
end

--- Crystal MonAnim vertical sheets — only when KR strips are absent.
function FrontAnim.allowCrystalNative(speciesId, battle, mon, mod)
  if not Host.isCrystal() then return false end
  return not FrontAnim.prefersKrAnim(speciesId, battle, mon, mod)
end

function FrontAnim.stripPath(mod, speciesId, battle, mon)
  local meta = FrontAnim.meta(FrontAnim.animSpeciesId(speciesId, battle, mon))
  if not meta or not meta.strip then return nil end
  return SpriteResolve.modPrefix(mod) .. meta.strip
end

--- Advance one animation tick; returns true when the displayed frame changed.
function FrontAnim.stepState(st, meta)
  if st.done then return false end
  st.frame = st.frame or 1
  st.timer = (st.timer or 0) + 1
  local ms = (meta.durations and meta.durations[st.frame]) or 100
  local ticks = math.max(1, math.floor(ms * FrontAnim.FPS / 1000 + 0.5))
  if st.timer < ticks then return false end
  st.timer = 0
  local nextFrame = st.frame + 1
  if nextFrame > meta.frameCount then
    st.cycles = (st.cycles or 0) + 1
    if st.cycles >= FrontAnim.battleCycles(meta) then
      st.done = true
      if st.frame ~= 1 then
        st.frame = 1
        return true
      end
      return false
    end
    nextFrame = 1
  end
  if nextFrame == st.frame then return false end
  st.frame = nextFrame
  return true
end

local function paletteColors(battle, speciesId)
  local PaletteFX = require("src.render.PaletteFX")
  local data = battle and battle.data
  if not data then return nil end
  return PaletteFX.monPal(data, speciesId)
end

local function bakeStrip(path, colors)
  if not path or not colors then return nil end
  if not love or not love.graphics then return nil end
  local Assets = require("src.render.Assets")
  local ok, id = pcall(Assets.imageData, path)
  if not ok or not id then return nil end
  id:mapPixel(function(_, _, r, g, b, a)
    if a == 0 then return r, g, b, a end
    local col = r > 0.83 and colors[1] or r > 0.5 and colors[2]
      or r > 0.17 and colors[3] or colors[4]
    return col[1] / 255, col[2] / 255, col[3] / 255, a
  end)
  return love.graphics.newImage(id)
end

function FrontAnim.quadFor(strip, meta, frame, quads, animId)
  if not strip or not meta or not frame then return nil end
  local iw, ih = strip:getDimensions()
  local layout = FrontAnim.stripLayout(meta, iw, ih)
  local idx = frame
  quads = quads or {}
  local qkey = (animId or "anim") .. ":" .. layout .. ":" .. idx
  local quad = quads[qkey]
  if not quad and love and love.graphics then
    local x, y = FrontAnim.frameOffset(meta, idx, iw, ih)
    local fw, fh = meta.frontW, meta.frontH
    if fw and fh and x + fw <= iw and y + fh <= ih then
      quad = love.graphics.newQuad(x, y, fw, fh, iw, ih)
      quads[qkey] = quad
    end
  end
  return quad, meta.frontW, meta.frontH
end

--- Gen1 draw path: strip + quad for the current frame (never replaces battler.sprite).
function FrontAnim.gen1Frame(battle, battler, mod)
  mod = mod or FrontAnim._mod
  if not battler or battler.isPlayer then return nil end
  if FrontAnim.presentationHoldsEnemyGen1(battle, battler) then return nil end
  if not FrontAnim.shouldAnimateBattler(battle, battler, mod) then return nil end
  local cache = battler._krFrontAnim
  if not cache or not cache.strip or not cache.meta then return nil end
  cache.quads = cache.quads or {}
  local quad, fw, fh = FrontAnim.quadFor(
    cache.strip, cache.meta, cache.frame or 1, cache.quads, cache.animId)
  if not quad then return nil end
  return cache.strip, quad, fw, fh
end

local function drawPic(img, quad, x, y, scale, xscale)
  xscale = xscale or 1
  if quad then
    love.graphics.draw(img, quad, x, y, 0, scale * xscale, scale)
  else
    love.graphics.draw(img, x, y, 0, scale * xscale, scale)
  end
end

local function battlerSpecies(battler)
  return BattleCompat.species(battler)
end

--- Enemy front-pic idle loop (player backs have no strips yet).
function FrontAnim.shouldAnimateBattler(battle, battler, mod)
  if not battler or battler.isPlayer then return false end
  if battler.fainted or battler.substituteHP then return false end
  local cache = battler._krFrontAnim
  if cache and cache.done then return false end
  local species = battlerSpecies(battler)
  return FrontAnim.prefersKrAnim(species, battle, BattleCompat.mon(battler), mod)
end

function FrontAnim.ensureCache(battle, battler, mod)
  local species = battlerSpecies(battler)
  if not species then return nil end
  local mon = BattleCompat.mon(battler)
  if not FrontAnim.prefersKrAnim(species, battle, mon, mod) then return nil end
  local animId = FrontAnim.animSpeciesId(species, battle, mon)
  local meta = FrontAnim.meta(animId)
  if not meta then return nil end

  local cache = battler._krFrontAnim
  if cache and cache.animId ~= animId then
    cache = nil
    battler._krFrontAnim = nil
  end
  if not cache then
    local path = FrontAnim.stripPath(mod, species, battle, mon)
    local colors = paletteColors(battle, species)
    local strip = bakeStrip(path, colors)
    if not strip then return nil end
    cache = {
      animId = animId,
      meta = meta,
      strip = strip,
      frame = 1,
      timer = 0,
      cycles = 0,
      done = false,
      quads = {},
    }
    FrontAnim.resetState(cache)
    battler._krFrontAnim = cache
  end
  return cache
end

function FrontAnim.tickBattler(battle, battler, mod)
  if FrontAnim.syncGen1Hold(battle, battler) then return end
  if not FrontAnim.shouldAnimateBattler(battle, battler, mod) then return end
  local cache = FrontAnim.ensureCache(battle, battler, mod)
  if not cache or cache.done then return end
  FrontAnim.stepState(cache, cache.meta)
end

function FrontAnim.tickBattle(battle, mod)
  if not battle then return end
  for _, b in ipairs({ battle.enemy, battle.player }) do
    if b then FrontAnim.tickBattler(battle, b, mod) end
  end
end

-- Gen2 view: keyed by party mon table (not the Gen1 battler wrapper).
function FrontAnim.gen2State(view, mon)
  view._krFrontAnimMonState = view._krFrontAnimMonState or {}
  local st = view._krFrontAnimMonState[mon]
  if not st then
    st = { frame = 1, timer = 0 }
    view._krFrontAnimMonState[mon] = st
  end
  return st
end

function FrontAnim.gen2Strip(view, mon, mod)
  if not mon or not mon.species then return nil end
  if not FrontAnim.prefersKrAnim(mon.species, view.battle, mon, mod) then
    return nil
  end
  if mon.species == "CASTFORM" then
    local ok, CastformFx = pcall(require, "mods.Kanto-Reforged.battle.castform_fx")
    if ok then
      CastformFx.applyFormPalette(
        CastformFx.activeSuffix(view.battle, mon, false), view.palettes)
    end
  end
  local animId = FrontAnim.animSpeciesId(mon.species, view.battle, mon)
  local meta = FrontAnim.meta(animId)
  if not meta then return nil end

  view._krFrontAnimSheets = view._krFrontAnimSheets or {}
  local sheet = view._krFrontAnimSheets[animId]
  if sheet == nil then
    local path = FrontAnim.stripPath(mod, mon.species, view.battle, mon)
    local Assets = require("src.render.Assets")
    local ok, img = pcall(Assets.image, path)
    sheet = (ok and img) or false
    view._krFrontAnimSheets[animId] = sheet
  end
  if not sheet then return nil end
  return sheet, meta, animId
end

function FrontAnim.gen2Frame(view, mon, mod)
  if not mon or not mon.species then return nil end
  if FrontAnim.syncGen2Hold(view, mon) then return nil end
  local st = FrontAnim.gen2State(view, mon)
  if st.done then return nil end
  local sheet, meta, animId = FrontAnim.gen2Strip(view, mon, mod)
  if not sheet then return nil end
  view._krFrontAnimQuads = view._krFrontAnimQuads or {}
  local quad = FrontAnim.quadFor(
    sheet, meta, st.frame or 1, view._krFrontAnimQuads, animId)
  return sheet, quad, meta.frontW
end

function FrontAnim.tickGen2Mon(view, mon, mod)
  if not mon or not mon.species then return end
  if FrontAnim.syncGen2Hold(view, mon) then return end
  local st = FrontAnim.gen2State(view, mon)
  if st.done then return end
  local _, meta = FrontAnim.gen2Strip(view, mon, mod)
  if not meta then return end
  FrontAnim.stepState(st, meta)
end

function FrontAnim.tickGen2View(view, mod)
  if not view or not view.battle then return end
  FrontAnim.tickGen2Mon(view, view.battle.enemy, mod)
end

local function installGen1(mod)
  if not Host.isGen1From(mod) then return end
  local ok, BS = pcall(require, "src.battle.BattleState")
  if not ok or not BS then return end
  Gen1Patch.apply(BS, function(BattleState)
    if BattleState._krFrontAnimInstalled then return end
    local origUpdateFx = BattleState.updateFx
    BattleState.updateFx = function(self)
      FrontAnim.tickBattle(self, mod)
      return origUpdateFx(self)
    end

    -- Gen1: draw anim frames as quads from the strip (same as Gen2).  Never
    -- replace battler.sprite — that drops imageMeta path scale and can bake
    -- the whole strip at full width.
    local origDrawBattlerPic = BattleState.drawBattlerPic
    BattleState.drawBattlerPic = function(self, battler, x, y, scale, shakeX, shakeY)
      local sheet, frameQuad = FrontAnim.gen1Frame(self, battler, mod)
      if sheet and frameQuad and not self:fxFaintActive(battler) then
        shakeX, shakeY = shakeX or 0, shakeY or 0
        if battler.substituteHP and not battler.fainted then
          self:drawSubstituteDoll(battler, shakeX, shakeY)
          return
        end
        if battler.fainted then return end

        local fadePf = self.picFx and self.picFx[battler]
        if fadePf and fadePf.fade then
          local cr, cg, cb, ca = love.graphics.getColor()
          love.graphics.setColor(cr, cg, cb, ca * fadePf.fade)
          drawPic(sheet, frameQuad, x, y, scale)
          love.graphics.setColor(cr, cg, cb, ca)
          return
        end

        local pf = self.picFx and self.picFx[battler]
        if not pf or (not pf.kind and not pf.hidden and not pf.minimized
                      and (pf.ox or 0) == 0 and (pf.oy or 0) == 0) then
          drawPic(sheet, frameQuad, x, y, scale)
          return
        end
      end
      return origDrawBattlerPic(self, battler, x, y, scale, shakeX, shakeY)
    end

    BattleState._krFrontAnimInstalled = true
  end)
end

local function installGen2(mod)
  -- Always patch when the Gen2 battle view module exists (same as
  -- battle_sprite_scale). Host.isGen2() at mod-define time can be stale if
  -- GameVersion was not set yet; loader.generation is not always visible here.
  local ok, BS = pcall(require, "src.ui.gen2.BattleState")
  if not ok or not BS then return end
  Gen1Patch.apply(BS, function(BattleState)
    if BattleState._krFrontAnimInstalled then return end

    local origStart = BattleState.startFrontAnim
    BattleState.startFrontAnim = function(self, mon)
      if mon and FrontAnim.prefersKrAnim(mon.species, self.battle, mon, mod) then
        -- Defer until syncGen2Hold clears (intro slide / trainer pic / etc).
        if not FrontAnim.presentationHoldsEnemyGen2(self, mon) then
          FrontAnim.restartGen2Mon(self, mon)
        end
        self.frontAnim = nil
        return
      end
      if not FrontAnim.allowCrystalNative(mon and mon.species, self.battle, mon, mod) then
        self.frontAnim = nil
        return
      end
      return origStart(self, mon)
    end

    local origStep = BattleState.stepFrontAnim
    BattleState.stepFrontAnim = function(self)
      FrontAnim.tickGen2View(self, mod)
      local mon = self.battle and self.battle.enemy
      if mon and FrontAnim.prefersKrAnim(mon.species, self.battle, mon, mod) then
        return
      end
      if not Host.isCrystal() then return end
      return origStep(self)
    end

    local origFrontFrame = BattleState.frontAnimFrame
    BattleState.frontAnimFrame = function(self, mon)
      if mon and not self.showEnemyTrainer then
        if FrontAnim.prefersKrAnim(mon.species, self.battle, mon, mod) then
          return FrontAnim.gen2Frame(self, mon, mod)
        end
      end
      if not FrontAnim.allowCrystalNative(mon and mon.species, self.battle, mon, mod) then
        return nil
      end
      return origFrontFrame(self, mon)
    end

    BattleState._krFrontAnimInstalled = true
  end)
end

function FrontAnim.install(mod)
  FrontAnim._mod = mod
  installGen1(mod)
  installGen2(mod)
end

return FrontAnim
