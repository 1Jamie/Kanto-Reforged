-- Gen 2-style EXP bar on the Gen 1 player HUD.
-- Gold already has FillInExpBar; this is Red/Blue/Yellow only.
--
-- Fill sits on the player HUD's $76 underline (tile 10,11 — the L-bracket),
-- drawn inside drawHUDs so TYPE/PP and the command box paint over it.
-- Empty pixels are not drawn (HUD paper + the $76 line show through).

local Growth = require("src.pokemon.Growth")

local BattleExpBar = {}

BattleExpBar.LENGTH_PX = 64
BattleExpBar.CHANNEL_PX = 2
-- $77 corner tile starts at x=144; its vertical stem is on the right.
-- Gold puts a short black nub in that gap so the bar meets the frame.
BattleExpBar.CAP_PX = 4
-- PlacePlayerHUDTiles: $76 run at (10,11)..(17,11), triangle $6F at (9,11).
BattleExpBar.CLASSIC_TX = 10
BattleExpBar.CLASSIC_TY = 11
BattleExpBar.WIDE_PX = 208
BattleExpBar.WIDE_PY = 90
BattleExpBar.WIDE_LENGTH_PX = 64

BattleExpBar.OPTION_KEY = "battle_exp_bar"
BattleExpBar.OPTION = {
  key = BattleExpBar.OPTION_KEY,
  label = "EXP BAR",
  type = "toggle",
  default = true,
}

local MAX_LEVEL = 100
local SOUND_DELAY = 10
-- DMG shade 2 (r≈0.33 → shader c2). Colorized battles recolor this strip
-- to exp-blue after the HUD zone pass; DMG battles use the literal blue.
local SHADE2 = { 85 / 255, 85 / 255, 85 / 255, 1 }
local BLUE = { 0.22, 0.48, 0.95, 1 }
local EXP_PAL = {
  { 255, 255, 255 }, { 140, 190, 255 }, { 50, 110, 220 }, { 0, 0, 0 },
}

function BattleExpBar.enabled(mod)
  mod = mod or BattleExpBar._mod
  if not mod or not mod.options then return true end
  local val = mod.options:get(BattleExpBar.OPTION_KEY)
  if val == nil then return true end
  return val == true
end

local function monExp(mon)
  if not mon then return 0 end
  return mon.exp or mon.experience or 0
end

function BattleExpBar.expPixels(data, mon, level, exp, maxPx)
  maxPx = maxPx or BattleExpBar.LENGTH_PX
  if not (data and mon) then return 0 end
  local def = data.pokemon and data.pokemon[mon.species]
  if not def then return 0 end
  level = math.max(1, math.min(MAX_LEVEL, level or mon.level or 1))
  if level >= MAX_LEVEL then return 0 end
  local rates = data.growth_rates
  local base = Growth.expForLevel(def.growthRate, level, rates)
  local next_ = Growth.expForLevel(def.growthRate, level + 1, rates)
  if not base or not next_ or next_ <= base then return 0 end
  local into = math.max(0, math.min(next_ - base, (exp or monExp(mon)) - base))
  return math.floor(into * maxPx / (next_ - base))
end

function BattleExpBar.latch(battle)
  if not battle then return end
  if not BattleExpBar.enabled(BattleExpBar._mod) then return end
  local isWide = battle and battle.wideLayout and battle:wideLayout()
  local maxLen = isWide and BattleExpBar.WIDE_LENGTH_PX or BattleExpBar.LENGTH_PX
  local mon = battle.player and battle.player.mon
  if not mon then
    battle.krShownExp, battle.krShownLevel, battle.krExpAnim = 0, 1, nil
    return
  end
  battle.krShownLevel = mon.level or 1
  battle.krShownExp = BattleExpBar.expPixels(battle.data, mon, battle.krShownLevel,
                                             monExp(mon), maxLen)
  battle.krExpAnim = nil
end

local function trySfx(battle, name)
  local data = battle and battle.data
  if not data then return end
  pcall(function()
    require("src.core.Sound").play(data, name)
  end)
end

local function tryStopSfx(name)
  pcall(function()
    require("src.core.Sound").stop(name)
  end)
end

function BattleExpBar.queueDrain(battle)
  if not battle then return end
  if not BattleExpBar.enabled(BattleExpBar._mod) then return end
  battle.queue = battle.queue or {}
  battle.nextInsert = (battle.nextInsert or 0) + 1
  -- wait=1 is a fallback: if vanilla dequeues this row, it holds a frame
  -- instead of startMessage with empty text (blank A/B prompt).
  table.insert(battle.queue, battle.nextInsert, { krExpDrain = true, wait = 1 })
end

-- One tick toward the live battler's exp. Returns true while crawling.
function BattleExpBar.step(battle)
  if not battle then return false end
  if not BattleExpBar.enabled(BattleExpBar._mod) then return false end
  local mon = battle.player and battle.player.mon
  if not mon then return false end
  if battle.krShownExp == nil or battle.krShownLevel == nil then
    BattleExpBar.latch(battle)
    return false
  end
  local isWide = battle and battle.wideLayout and battle:wideLayout()
  local maxLen = isWide and BattleExpBar.WIDE_LENGTH_PX or BattleExpBar.LENGTH_PX
  local toLevel = math.min(MAX_LEVEL, mon.level or 1)
  if (battle.krShownLevel or 1) >= MAX_LEVEL then
    battle.krShownExp = 0
    battle.krExpAnim = nil
    return false
  end
  local target = maxLen
  if (battle.krShownLevel or 1) >= toLevel then
    target = BattleExpBar.expPixels(battle.data, mon, battle.krShownLevel,
                                    monExp(mon), maxLen)
  end
  local shown = battle.krShownExp or 0
  if shown == target and (battle.krShownLevel or 1) >= toLevel then
    battle.krExpAnim = nil
    return false
  end
  local anim = battle.krExpAnim
  if not anim then
    anim = { frames = 3, wait = 0, pixels = 0, delay = SOUND_DELAY }
    battle.krExpAnim = anim
    trySfx(battle, "Sfx_ExpBar")
  end
  if (anim.delay or 0) > 0 then
    anim.delay = anim.delay - 1
    return true
  end
  if shown < target then
    anim.wait = (anim.wait or 0) + 1
    if anim.wait < (anim.frames or 1) then return true end
    anim.wait = 0
    shown = shown + 1
    battle.krShownExp = shown
    anim.pixels = (anim.pixels or 0) + 1
    if anim.pixels % 2 == 0 then
      anim.frames = math.max(1, (anim.frames or 1) - 1)
    end
    if shown < target then return true end
  end
  tryStopSfx("Sfx_ExpBar")
  if (battle.krShownLevel or 1) < toLevel then
    battle.krShownLevel = (battle.krShownLevel or 1) + 1
    battle.krShownExp = 0
    battle.krExpAnim = { frames = 3, wait = 0, pixels = 0, delay = 0 }
    trySfx(battle, "Sfx_HitEndOfExpBar")
    return true
  end
  battle.krExpAnim = nil
  return false
end

function BattleExpBar.needsCrawl(battle)
  if not BattleExpBar.enabled(BattleExpBar._mod) then return false end
  local mon = battle and battle.player and battle.player.mon
  if not mon or battle.krShownExp == nil then return false end
  local isWide = battle and battle.wideLayout and battle:wideLayout()
  local maxLen = isWide and BattleExpBar.WIDE_LENGTH_PX or BattleExpBar.LENGTH_PX
  local toLevel = math.min(MAX_LEVEL, mon.level or 1)
  if (battle.krShownLevel or 1) < toLevel then return true end
  if (battle.krShownLevel or 1) >= MAX_LEVEL then return false end
  return (battle.krShownExp or 0) ~= BattleExpBar.expPixels(
    battle.data, mon, battle.krShownLevel, monExp(mon), maxLen)
end

local function playerHudHidden(battle)
  if not battle or not battle.player or not battle.player.mon then return true end
  if battle.safari or battle.demo or battle.showPlayerBack then return true end
  if battle.introBalls then return true end
  if (battle.introSlide or 0) > 0 then return true end
  if battle.statusHUDVisible and not battle:statusHUDVisible() then return true end
  return false
end

local function fillOrigin(battle)
  if battle and battle.wideLayout and battle:wideLayout() then
    return BattleExpBar.WIDE_PX, BattleExpBar.WIDE_PY
  end
  -- Flush with the $76 underline / $77 corner, not 4px below the bracket.
  return BattleExpBar.CLASSIC_TX * 8, BattleExpBar.CLASSIC_TY * 8 + 1
end

-- Gen 2 FillInExpBar grows from the right end-cap toward the triangle.
local function fillRect(battle, sx, sy)
  local isWide = battle and battle.wideLayout and battle:wideLayout()
  local maxLen = isWide and BattleExpBar.WIDE_LENGTH_PX or BattleExpBar.LENGTH_PX
  local pixels = math.max(0, math.min(maxLen, battle.krShownExp or 0))
  if pixels <= 0 then return nil end
  sx, sy = sx or 0, sy or 0
  local ox, oy = fillOrigin(battle)
  local px = ox + sx + maxLen - pixels
  local py = oy + sy
  local w, h = pixels, BattleExpBar.CHANNEL_PX
  if not isWide and battle.phase == "moveSelect" then
    local clipL = 88 + sx
    if px + w <= clipL then return nil end
    if px < clipL then
      w = w - (clipL - px)
      px = clipL
    end
  end
  local maxPy = (isWide and 144 or 96) + sy
  if py >= maxPy then return nil end
  if py + h > maxPy then h = maxPy - py end
  if w <= 0 or h <= 0 then return nil end
  return px, py, w, h
end

-- Transparent empty track; blue fill from the right; black nub from the
-- bar's start to the HUD frame (Gold's end-cap, not a full black track).
function BattleExpBar.drawFill(battle, color)
  if not BattleExpBar.enabled(BattleExpBar._mod) then return end
  if playerHudHidden(battle) then return end
  if battle.krShownExp == nil then BattleExpBar.latch(battle) end
  local G = love and love.graphics
  if not G or not G.rectangle then return end
  local isWide = battle and battle.wideLayout and battle:wideLayout()
  local fx = battle and battle.fx
  local sx = (fx and fx.shakeX) or 0
  local sy = (fx and fx.shakeY) or 0
  if sx == 0 and sy == 0 and fx and fx.shake and fx.shake > 0 then
    sx = (battle.frame or 0) % 4 < 2 and 2 or -2
  end

  if isWide then
    -- Right-aligned 64px capsule under numeric HP 54/ 54 (x=208..272, y=90)
    local ox = BattleExpBar.WIDE_PX + sx
    local oy = BattleExpBar.WIDE_PY + sy
    local trackW = BattleExpBar.WIDE_LENGTH_PX
    local trackH = 4

    -- 1px Black capsule outline
    G.setColor(0, 0, 0, 1)
    G.rectangle("fill", ox, oy, trackW, trackH)

    -- Subtle inner empty track background
    G.setColor(1, 1, 1, 0.85)
    G.rectangle("fill", ox + 1, oy + 1, trackW - 2, trackH - 2)

    -- Sleek 2px blue EXP fill inside capsule (right-aligned, fills Right -> Left)
    local fraction = math.max(0, math.min(1, (battle.krShownExp or 0) / trackW))
    local maxFill = trackW - 2
    local fillW = math.floor(fraction * maxFill)
    if fillW > 0 then
      local fillX = ox + trackW - 1 - fillW
      G.setColor(BLUE)
      G.rectangle("fill", fillX, oy + 1, fillW, trackH - 2)
    end
    G.setColor(1, 1, 1, 1)
    return
  end

  local ox, oy = fillOrigin(battle)
  local maxLen = BattleExpBar.LENGTH_PX
  if BattleExpBar.CAP_PX > 0 then
    G.setColor(0, 0, 0, 1)
    G.rectangle("fill", ox + maxLen, oy, BattleExpBar.CAP_PX, BattleExpBar.CHANNEL_PX)
  end
  local px, py, w, h = fillRect(battle, 0, 0)
  if px then
    G.setColor(color or BLUE)
    G.rectangle("fill", px, py, w, h)
  end
  G.setColor(1, 1, 1, 1)
end

-- Recolor the fill strip to blue after the HUD's GREENBAR zone pass.
-- Clipped so the TYPE/PP box (0,8) 11x5 and the command box at row 12
-- are not painted over.
function BattleExpBar.recolorFill(battle, src, sx, sy)
  if not BattleExpBar.enabled(BattleExpBar._mod) then return end
  if playerHudHidden(battle) then return end
  local isWide = battle and battle.wideLayout and battle:wideLayout()
  if isWide then return end
  local G = love and love.graphics
  if not (G and src and G.setScissor) then return end
  local px, py, w, h = fillRect(battle, sx, sy)
  if not px then return end
  local PaletteFX = require("src.render.PaletteFX")
  local shader = PaletteFX.shader()
  if not shader then return end
  G.setShader(shader)
  PaletteFX.sendColors(shader, EXP_PAL)
  G.setColor(1, 1, 1, 1)
  G.setScissor(px, py, w, h)
  G.draw(src, sx or 0, sy or 0)
  G.setScissor()
  G.setShader()
end

function BattleExpBar.install(mod)
  BattleExpBar._mod = mod
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen1() then return end

  local Font = require("src.render.Font")
  if not Font._krExpBarBox then
    Font._krExpBarBox = true
    local originalDrawBox = Font.drawBox
    Font.drawBox = function(tx, ty, tw, th, ...)
      if tx == 23 and ty == 7 and tw == 15 and th == 5 and BattleExpBar.enabled(BattleExpBar._mod) then
        th = 6
      end
      return originalDrawBox(tx, ty, tw, th, ...)
    end
  end

  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
  Gen1Patch.apply(require("src.battle.BattleState"), function(BattleState)
    if BattleState._krExpBar then return end
    BattleState._krExpBar = true

    local originalDrawHUDs = BattleState.drawHUDs
    BattleState.drawHUDs = function(self, slide)
      originalDrawHUDs(self, slide)
      if not BattleExpBar.enabled(BattleExpBar._mod) then return end
      if not (self.wideLayout and self:wideLayout()) then
        local colorized = self.colorMode and self:colorMode()
        BattleExpBar.drawFill(self, colorized and SHADE2 or BLUE)
      end
    end

    local originalZone = BattleState.drawZonePass
    BattleState.drawZonePass = function(self, src, sx, sy)
      originalZone(self, src, sx, sy)
      if not BattleExpBar.enabled(BattleExpBar._mod) then return end
      if not (self.wideLayout and self:wideLayout()) then
        BattleExpBar.recolorFill(self, src, sx or 0, sy or 0)
      end
    end

    local originalUpdate = BattleState.update
    BattleState.update = function(self, dt)
      if BattleExpBar.enabled(BattleExpBar._mod) then
        BattleExpBar.step(self)
      end
      return originalUpdate(self, dt)
    end

    local originalQueue = BattleState.updateQueue
    BattleState.updateQueue = function(self)
      if not BattleExpBar.enabled(BattleExpBar._mod) then
        return originalQueue(self)
      end
      if self.krExpHold then
        if BattleExpBar.needsCrawl(self) then return true end
        self.krExpHold = nil
      end
      -- Vanilla finishes HP drain then falls through and dequeues the next
      -- row in the same call. If that row is {krExpDrain}, startMessage
      -- opens a blank prompt. Finish the drain here first, then steal.
      local next = self.queue and self.queue[1]
      if self.draining and next and next.krExpDrain and not self.current then
        if self:stepHPDrain() then return true end
        self.draining = nil
        if self.player then self.player.drainFloor = nil end
        if self.enemy then self.enemy.drainFloor = nil end
      end
      local item = self.queue and self.queue[1]
      if item and item.krExpDrain and not self.current
          and not self.draining and not self.animPlaying
          and not (self.waitFrames and self.waitFrames > 0)
          and not self.waitingSound
          and not self.waitingUI then
        table.remove(self.queue, 1)
        self.krExpHold = true
        return true
      end
      return originalQueue(self)
    end

    local originalAward = BattleState.awardExp
    if type(originalAward) == "function" then
      BattleState.awardExp = function(self)
        originalAward(self)
        if not BattleExpBar.enabled(BattleExpBar._mod) then return end
        if BattleExpBar.needsCrawl(self) and not self.krExpHold then
          local queued = false
          for _, it in ipairs(self.queue or {}) do
            if it.krExpDrain then queued = true break end
          end
          if not queued then BattleExpBar.queueDrain(self) end
        end
      end
    end

    local originalSayNext = BattleState.sayNext
    BattleState.sayNext = function(self, ...)
      originalSayNext(self, ...)
      if not BattleExpBar.enabled(BattleExpBar._mod) then return end
      if (self.krExpPending or 0) > 0 then
        self.krExpPending = self.krExpPending - 1
        BattleExpBar.queueDrain(self)
      end
    end

    local originalNewWild = BattleState.newWild
    BattleState.newWild = function(...)
      local battle = originalNewWild(...)
      if battle and BattleExpBar.enabled(BattleExpBar._mod) then
        BattleExpBar.latch(battle)
      end
      return battle
    end
    local originalNewTrainer = BattleState.newTrainer
    BattleState.newTrainer = function(...)
      local battle = originalNewTrainer(...)
      if battle and BattleExpBar.enabled(BattleExpBar._mod) then
        BattleExpBar.latch(battle)
      end
      return battle
    end
  end)

  mod.hooks:wrap("battle.overlay", function(next, battle)
    next(battle)
    if not BattleExpBar.enabled(mod) then return end
    if battle and battle.wideLayout and battle:wideLayout() then
      BattleExpBar.drawFill(battle, BLUE)
    end
  end)

  mod.events:on("battle.started", function(ev)
    if not BattleExpBar.enabled(mod) then return end
    if ev and ev.battle then BattleExpBar.latch(ev.battle) end
  end)
  mod.events:on("battle.battler_switched", function(ev)
    if not BattleExpBar.enabled(mod) then return end
    if ev and ev.battle and ev.battler and ev.battler.isPlayer then
      BattleExpBar.latch(ev.battle)
    end
  end)
  mod.events:on("battle.exp_gained", function(ev)
    if not BattleExpBar.enabled(mod) then return end
    local battle = ev and ev.battle
    if not battle then return end
    local active = battle.player and battle.player.mon
    if not active or (active.level or 1) >= MAX_LEVEL then return end
    if not BattleExpBar.needsCrawl(battle) then return end
    battle.krExpPending = (battle.krExpPending or 0) + 1
  end)
end

return BattleExpBar
