-- Optional Gen 2-style Sp.Atk / Sp.Def split on Gen 1 DVs / statExp.
-- Default OFF: battle and UI use the single Gen 1 SPECIAL stat.
-- When ON: special damage uses separate SpA/SpD bases from PokeAPI
-- (species.sp_attack / sp_defense); summary UI shows both values.
-- Stages, Calcium, and the Special DV stay Gen 1 (one shared special).

local SplitSpecial = {}

SplitSpecial.OPTION_KEY = "split_special"
SplitSpecial.OPTION = {
  key = SplitSpecial.OPTION_KEY,
  label = "SP.ATK / SP.DEF",
  type = "toggle",
  default = false,
}

function SplitSpecial.enabled(mod)
  return mod and mod.options and mod.options:get(SplitSpecial.OPTION_KEY) and true or false
end

-- Gen 1 CalcStat for one non-HP stat.
local function calcOne(base, dv, statExp, level)
  local ev = math.floor(math.min(255, math.ceil(math.sqrt(statExp or 0))) / 4)
  return math.floor(((base + dv) * 2 + ev) * level / 100) + 5
end

-- Returns { sp_attack = n, sp_defense = n } from species bases + mon DVs.
-- Falls back to baseStats.special when spa/spd fields are missing.
function SplitSpecial.calcSpStats(def, mon)
  if not def then return nil end
  mon = mon or {}
  local dvs = mon.dvs or {}
  local statExp = mon.statExp or {}
  local level = mon.level or 1
  local special = def.baseStats and def.baseStats.special
  local baseAtk = def.sp_attack or special
  local baseDef = def.sp_defense or special
  if not baseAtk or not baseDef then return nil end
  local dv = dvs.special or 0
  local ev = statExp.special or 0
  return {
    sp_attack = calcOne(baseAtk, dv, ev, level),
    sp_defense = calcOne(baseDef, dv, ev, level),
  }
end

-- Battle helper: SpA when isAttack, else SpD. Caches on the battler.
-- Without spa/spd bases, returns curStats.special (Gen 1).
function SplitSpecial.getBattleStat(battler, isAttack)
  local mon = battler.mon
  local def = battler.def
  if not def or not (def.sp_attack or def.sp_defense) then
    return battler.curStats.special
  end

  if not battler.sp_attack or not battler.sp_defense then
    local stats = SplitSpecial.calcSpStats(def, mon)
    if not stats then
      return battler.curStats.special
    end
    battler.sp_attack = stats.sp_attack
    battler.sp_defense = stats.sp_defense
  end

  return isAttack and battler.sp_attack or battler.sp_defense
end

-- ---------------------------------------------------------------------------
-- Gen1 Modern UI party/PC detail card still hardcodes ATK/DEF/SPD/SPC.
-- Patch its drawMonDetail (0.8.2 runtime table, or 0.8.1 local via upvalues)
-- so the SPC column becomes SP.A + SP.D when this option is on.
-- ---------------------------------------------------------------------------

local patched = false
-- LuaJIT/Lua 5.1 cannot attach fields to functions; track wraps here.
local wrappedFns = setmetatable({}, { __mode = "k" })

local function findUpvalue(fn, want)
  if type(fn) ~= "function" or not debug or not debug.getupvalue then
    return nil, nil
  end
  local i = 1
  while true do
    local name, val = debug.getupvalue(fn, i)
    if not name then return nil, nil end
    if name == want then return i, val end
    i = i + 1
  end
end

-- Walk Modern UI's render.hud closure tree for drawMonDetail.
-- 0.8.2: hud -> runtime.drawMonDetail
-- 0.8.1: hud -> drawModernStack -> drawModern -> drawParty/drawBoxPokemonList
--        -> drawMonDetail
local function findDrawMonDetail()
  local Runtime = require("src.mods.Runtime")
  local chain = Runtime.hooks and Runtime.hooks.chains
    and Runtime.hooks.chains["render.hud"]
  if type(chain) ~= "table" then return nil, nil end

  local seen = {}
  local function search(fn, depth)
    if type(fn) ~= "function" or seen[fn] or depth > 6 then return nil end
    seen[fn] = true
    local i = 1
    while true do
      local name, val = debug.getupvalue(fn, i)
      if not name then break end
      if name == "runtime" and type(val) == "table"
          and type(val.drawMonDetail) == "function" then
        return val, "runtime"
      end
      if name == "drawMonDetail" and type(val) == "function" then
        return { parent = fn, index = i, fn = val }, "upvalue"
      end
      if type(val) == "function" and (
          name == "drawModernStack" or name == "drawModern"
          or name == "drawParty" or name == "drawBoxPokemonList") then
        local target, kind = search(val, depth + 1)
        if target then return target, kind end
      end
      i = i + 1
    end
    return nil
  end

  for _, entry in ipairs(chain) do
    if entry.owner == "gen1_modern_ui" and type(entry.callback) == "function" then
      local target, kind = search(entry.callback, 0)
      if target then return target, kind end
    end
  end
  return nil, nil
end

local function wrapDrawMonDetail(original, krMod)
  return function(game, mon, x, y, w, h, theme, context)
    if not SplitSpecial.enabled(krMod) or type(mon) ~= "table" then
      return original(game, mon, x, y, w, h, theme, context)
    end

    local fitIdx, drawFittedText = findUpvalue(original, "drawFittedText")
    if not fitIdx or type(drawFittedText) ~= "function" or not debug.setupvalue then
      return original(game, mon, x, y, w, h, theme, context)
    end

    -- LuaJIT can ignore setupvalue on compiled closures; force interpreter.
    if jit and jit.off then pcall(jit.off, original, true) end

    local _, drawText = findUpvalue(original, "drawText")
    local _, textHeight = findUpvalue(original, "textHeight")

    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    local sp = SplitSpecial.calcSpStats(def, mon)
    local spa = sp and sp.sp_attack
      or (mon.stats and mon.stats.special) or "—"
    local spd = sp and sp.sp_defense
      or (mon.stats and mon.stats.special) or "—"

    local batch = nil
    local pushed = false

    local function drawLabel(text, tx, ty, tw, font)
      if type(drawText) == "function" then
        if font and love and love.graphics and love.graphics.setFont then
          love.graphics.setFont(font)
        end
        drawText(text, tx, ty)
      else
        drawFittedText(text, tx, ty, tw, font)
      end
    end

    local function lineHeight(font)
      if type(textHeight) == "function" and font then
        local okH, hgt = pcall(textHeight, font)
        if okH and type(hgt) == "number" and hgt > 0 then return hgt end
      end
      if font and font.getHeight then
        return font:getHeight() or 16
      end
      return 16
    end

    local function abbrevStat(text, short)
      local value = tostring(text):match("^%S+%s+(.+)$") or text
      return short .. " " .. value
    end

    local function interceptor(text, tx, ty, tw, font)
      if type(text) == "string" then
        if text:match("^ATK ") then
          batch = {
            x = tx, y = ty, tw = tw, font = font,
            atk = text, gap = nil,
          }
          return
        end
        if batch and text:match("^DEF ") then
          batch.def = text
          batch.gap = (tx - batch.x) - batch.tw
          return
        end
        if batch and text:match("^SPD ") then
          batch.spd = text
          return
        end
        if batch and text:match("^SPC ") then
          local gap = batch.gap or 0
          if gap < 0 then gap = 0 end
          local rowW = batch.tw * 4 + gap * 3
          local lineH = lineHeight(batch.font)
          local top = {
            abbrevStat(batch.atk, "ATK."),
            abbrevStat(batch.def, "DEF."),
            abbrevStat(batch.spd, "SPD."),
          }
          local bot = {
            ("SP.A %s"):format(tostring(spa)),
            ("SP.D %s"):format(tostring(spd)),
          }
          local function row(labels, rowY)
            local n = #labels
            local cell = math.max(24, (rowW - gap * (n - 1)) / n)
            for i, label in ipairs(labels) do
              drawLabel(label,
                batch.x + (i - 1) * (cell + gap), rowY, cell, batch.font)
            end
          end
          row(top, batch.y)
          row(bot, batch.y + lineH)
          batch = nil
          -- Shift the rest of drawMonDetail (moves + PP) via the graphics
          -- transform. Editing drawFittedText Y was unreliable under LuaJIT /
          -- shared upvalues; translate always applies to subsequent prints.
          local shift = lineH + math.max(gap, 8)
          if love and love.graphics and love.graphics.push
              and love.graphics.translate then
            love.graphics.push()
            love.graphics.translate(0, shift)
            pushed = true
          end
          return
        end
      end
      if batch then
        drawFittedText(batch.atk, batch.x, batch.y, batch.tw, batch.font)
        batch = nil
      end
      return drawFittedText(text, tx, ty, tw, font)
    end

    debug.setupvalue(original, fitIdx, interceptor)
    local ok, err = pcall(original, game, mon, x, y, w, h, theme, context)
    debug.setupvalue(original, fitIdx, drawFittedText)
    if pushed and love and love.graphics and love.graphics.pop then
      love.graphics.pop()
    end
    if not ok then error(err) end
  end
end

-- Unwrap prior SP.ATK/SP.DEF party wrappers so reloads install the latest logic
-- on the raw Modern UI drawMonDetail (not a stale nested wrap).
local function unwrapDrawMonDetail(fn)
  local cur = fn
  for _ = 1, 8 do
    if type(cur) ~= "function" then return cur end
    local _, maybeSS = findUpvalue(cur, "SplitSpecial")
    if maybeSS == nil then return cur end
    local _, inner = findUpvalue(cur, "original")
    if type(inner) ~= "function" then return cur end
    cur = inner
  end
  return cur
end

local function applyWrap(target, kind, krMod)
  if kind == "runtime" then
    local original = unwrapDrawMonDetail(target.drawMonDetail)
    if type(original) ~= "function" then return false end
    local wrapped = wrapDrawMonDetail(original, krMod)
    wrappedFns[wrapped] = true
    wrappedFns[original] = true
    target.drawMonDetail = wrapped
    target._expSplitSpecialPartyPatch = true
    return true
  end
  if kind == "upvalue" then
    local original = unwrapDrawMonDetail(target.fn)
    if type(original) ~= "function" then return false end
    local wrapped = wrapDrawMonDetail(original, krMod)
    wrappedFns[wrapped] = true
    wrappedFns[original] = true
    debug.setupvalue(target.parent, target.index, wrapped)
    return true
  end
  return false
end

-- Returns true when the Modern UI party/PC detail card was patched.
function SplitSpecial.patchModernUiPartyDetail(mod)
  if patched then return true end
  if not mod or not debug or not debug.getupvalue then return false end

  local target, kind = findDrawMonDetail()
  if not target then return false end
  if applyWrap(target, kind, mod) then
    patched = true
    if mod.log and mod.log.info then
      mod.log:info("Modern UI party detail patched for SP.ATK / SP.DEF (%s)",
        tostring(kind))
    end
    return true
  end
  return false
end

-- Install once Modern UI's render.hud wrap exists (load order varies).
function SplitSpecial.installModernUiPartyPatch(mod)
  if SplitSpecial.patchModernUiPartyDetail(mod) then return true end
  if not mod or not mod.hooks then return false end
  if mod._expSplitSpecialHudWatch then return false end
  mod._expSplitSpecialHudWatch = true
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    if not patched then
      SplitSpecial.patchModernUiPartyDetail(mod)
    end
    return next(game, viewport)
  end, -50)
  return false
end

return SplitSpecial
