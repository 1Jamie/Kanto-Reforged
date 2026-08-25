-- Extra SummaryMenu page: ability + held item (Gen 2/3 Kanto Reforged fields).
-- Gen1: wraps the two-page status screen with page 3 (ability/held/gender).
-- Gen2: wraps Gen2SummaryMenu with page 4 after pink/green/blue.
--
-- Publishes a read-only abilityPage() snapshot + Gen1 advance() for Modern UI
-- when that mod is present. Native draw/input is unchanged when it is absent.

local Font = require("src.render.Font")
local Strings = require("src.core.Strings")
local TextBox = require("src.render.TextBox")
local HeldItems = require("mods.Kanto-Reforged.items.held_items")
local AbilityText = require("mods.Kanto-Reforged.battle.ability_text")
local Gender = require("mods.Kanto-Reforged.pokemon.gender")
local GenderUi = require("mods.Kanto-Reforged.ui.gender_ui")
local SplitSpecial = require("mods.Kanto-Reforged.battle.split_special")

local SummaryUi = {}

-- Gen2 stock pages are 1..3; ability is appended as page 4.
SummaryUi.GEN2_ABILITY_PAGE = 4

local function abilityLabel(id)
  if not id or id == "" or id == "NONE" then return nil end
  return id:gsub("_", " ")
end

local function heldLabel(mon, data)
  -- Gen1/mod holds use heldItem; stock Gold party mons use item.
  local id = mon and (mon.heldItem or mon.item)
  if not id then return nil end
  local def = HeldItems.def(id) or (data.items and data.items[id])
  return def and def.name or id:gsub("_", " ")
end

local function monDisplayName(mon, def, data)
  local base = mon.nickname or (def and def.name) or "?????"
  return GenderUi.label(mon, base, data)
end

local function genderLabel(mon)
  local g = Gender.of(mon)
  if g == "M" then return "♂" end
  if g == "F" then return "♀" end
  return "-----"
end

-- Read-only ability/held/gender snapshot for page 3 (native draw + Modern UI).
function SummaryUi.abilityPage(mon, data)
  data = data or {}
  local def = data.pokemon and mon and data.pokemon[mon.species]
  local abilityId = def and def.ability
  local desc = AbilityText.describe(abilityId)
  local pages = TextBox.paginate(desc, 18)
  return {
    gender = genderLabel(mon),
    heldItem = heldLabel(mon, data) or "-----",
    abilityId = abilityId,
    ability = abilityLabel(abilityId) or "-----",
    description = pages[1] or {},
  }
end

-- Wipe + redraw the summary name line with an optional gender glyph.
local function redrawNameWithGender(self)
  local mon = self.mon
  local data = self.game.data
  local def = data.pokemon[mon.species]
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 72, 8, 88, 8)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(monDisplayName(mon, def, data), 72, 8)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Compact 5-stat redraw when SP.ATK / SP.DEF is on (fits the Gen1 10x10 box).
-- Labels share the value column (x=48); ATTACK/DEFENSE overflow into the digits.
local function redrawSplitSpecialStats(self)
  local mon = self.mon
  local def = self.game.data.pokemon[mon.species]
  local stats = mon.stats or {}
  local sp = SplitSpecial.calcSpStats(def, mon)
  -- Wipe interior of stats box (0,8) 10x10 → pixels 0..79 x 64..143
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 8, 72, 64, 64)
  love.graphics.setColor(0, 0, 0, 1)
  local rows = {
    { "ATK.", stats.attack },
    { "DEF.", stats.defense },
    { "SPEED", stats.speed },
    { "SP.ATK", sp and sp.sp_attack or stats.special },
    { "SP.DEF", sp and sp.sp_defense or stats.special },
  }
  for i, s in ipairs(rows) do
    local y = 72 + (i - 1) * 12
    Font.draw(Strings(s[1]), 8, y)
    Font.draw(("%3d"):format(s[2] or 0), 48, y)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Shared header bits mirrored from SummaryMenu (pic / name / dex).
local function drawHeader(self)
  local mon = self.mon
  local game = self.game
  local data = game.data
  local def = data.pokemon[mon.species]
  local HudTiles = require("src.render.HudTiles")

  if self.sprite then
    local pw, ph = self.sprite:getDimensions()
    local py = math.max(0, 56 - ph)
    love.graphics.draw(self.sprite, 8 + pw, py, 0, -1, 1)
    if self.spriteTrueColor then
      require("src.render.PaletteFX").markTrueColor(8, py, pw, ph)
    end
  end
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(monDisplayName(mon, def, data), 72, 8)
  HudTiles.statusTile(0x74, 8, 56)
  Font.drawCode(0xF2, 16, 56)
  Font.draw(("%03d"):format(def and def.dex or 0), 24, 56)
end

local function drawAbilityPage(self)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  drawHeader(self)

  local mon = self.mon
  local data = self.game.data
  local page = SummaryUi.abilityPage(mon, data)
  local HudTiles = require("src.render.HudTiles")

  -- Same right-edge bracket the other pages use around the info column.
  for i = 0, 5 do HudTiles.statusTile(0x78, 152, (8 + i) * 8) end
  HudTiles.statusTile(0x77, 152, 56)
  for i = 1, 10 do HudTiles.statusTile(0x76, 152 - i * 8, 56) end
  HudTiles.statusTile(0x6F, 152 - 88, 56)

  love.graphics.setColor(0, 0, 0, 1)

  -- Top info column: gender + held item (STATUS/ slot on page 1).
  Font.draw(Strings("GENDER/"), 72, 24)
  Font.draw(page.gender, 80, 32)
  Font.draw(Strings("ITEM/"), 72, 40)
  Font.draw(page.heldItem, 80, 48)

  -- Ability + description fill the bottom box (types already on page 1).
  Font.drawBox(0, 8, 20, 10)
  Font.draw(Strings("ABILITY/"), 8, 72)
  Font.draw(page.ability, 16, 80)

  local lines = page.description or {}
  local maxLines = 5
  for i = 1, math.min(#lines, maxLines) do
    Font.draw(lines[i], 8, 88 + (i - 1) * 8)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

-- Gen2 lower half for page 4: gender / held item / ability + description.
-- Upper half (pic, name, page arrows) stays on drawUpperHalf.
local function drawGen2AbilityLower(self)
  local Chrome = require("src.ui.gen2.Chrome")
  local page = SummaryUi.abilityPage(self.mon, self.game and self.game.data)

  Chrome.print(Strings("GENDER/"), 0, 8)
  Chrome.print(page.gender, 8, 8)
  Chrome.print(Strings("ITEM/"), 0, 10)
  Chrome.print(page.heldItem, 6, 10)
  Chrome.print(Strings("ABILITY/"), 0, 12)
  Chrome.print(page.ability, 1, 13)

  local lines = page.description or {}
  for i = 1, math.min(#lines, 4) do
    Chrome.print(lines[i], 1, 14 + i - 1)
  end
end

local function wrapGen2Summary(Builtin, game, opts)
  local self = Builtin.new(game, opts)
  local maxPage = SummaryUi.GEN2_ABILITY_PAGE
  local abilityPage = SummaryUi.GEN2_ABILITY_PAGE
  local pinkPage = Builtin.PINK_PAGE or 1
  local greenPage = Builtin.GREEN_PAGE or 2

  function self:turnPage(delta)
    local page = self.page + delta
    if page > maxPage then page = pinkPage end
    if page < pinkPage then page = maxPage end
    self.page = page
  end

  -- Four 2x2 squares between the ◀ / ▶ arrows (stock uses three).
  function self:drawPageIndicators()
    local columns = { 11, 13, 15, 17 }
    for i, tx in ipairs(columns) do
      self:drawPageSquare(tx, 5, i == self.page)
    end
  end

  local baseDrawPanel = self.drawPanel
  function self:drawPanel()
    local mon = self.mon
    if self.page == abilityPage and not self.moveDetail
        and not (type(mon) == "table" and mon.isEgg) then
      local wasBattle = Font.useBattleExtra(true)
      local Chrome = require("src.ui.gen2.Chrome")
      Chrome.clear()
      self:drawUpperHalf()
      drawGen2AbilityLower(self)
      Font.useBattleExtra(wasBattle)
      love.graphics.setColor(1, 1, 1, 1)
      return
    end
    return baseDrawPanel(self)
  end

  -- Mirror stock update, but A closes on the ability page (not blue).
  function self:update(_dt)
    local input = self.game and self.game.input
    if not input then return end
    if self.moveDetail then
      self:updateMoveDetail(input)
      return
    end
    if type(self.mon) == "table" and self.mon.isEgg then
      if input:wasPressed("a") or input:wasPressed("b") then
        self:close()
      elseif input:wasPressed("up") then
        self:switchMon(-1)
      elseif input:wasPressed("down") then
        self:switchMon(1)
      end
      return
    end
    if input:wasPressed("b") then
      self:close()
      return
    end
    if input:wasPressed("left") then
      self:turnPage(-1)
      return
    end
    if input:wasPressed("right") then
      self:turnPage(1)
      return
    end
    if input:wasPressed("a") then
      if self.page == abilityPage then
        self:close()
      else
        self:turnPage(1)
      end
      return
    end
    if input:wasPressed("up") then
      self:switchMon(-1)
      return
    end
    if input:wasPressed("down") then
      self:switchMon(1)
      return
    end
    if input:wasPressed("select") and self.page == greenPage then
      self.moveDetail = true
      self.moveIndex = 1
    end
  end

  -- Green page ITEM row: prefer heldItem when stock item is empty.
  local baseItemName = self.itemName
  function self:itemName()
    local name = baseItemName(self)
    if name then return name end
    local mon = self.mon or {}
    local id = mon.heldItem
    if not id then return nil end
    local def = self.items and self.items[id]
    if not def then def = HeldItems.def(id) end
    return (def and def.name) or id
  end

  return self
end

-- Exposed for tests / Gold registration.
SummaryUi.wrapGen2Summary = wrapGen2Summary

-- Exposed so optional companion mods (e.g. HiddenStats) can draw extra
-- native summary pages using the same header (pic / name / dex).
SummaryUi.drawHeader = drawHeader

function SummaryUi.register(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then
    local ok, Builtin = pcall(require, "src.ui.gen2.SummaryMenu")
    if not ok or not Builtin or not Builtin.new then
      mod.log:warn("Gen2 SummaryMenu unavailable; ability page skipped")
      return
    end
    mod.content.screens:register("Gen2SummaryMenu", {
      new = function(game, opts)
        return wrapGen2Summary(Builtin, game, opts)
      end,
    })
    return
  end

  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  Gen1Patch.apply(require("src.ui.SummaryMenu"), function(Builtin)
    mod.content.screens:register("SummaryMenu", {
      new = function(game, mon)
        local self = Builtin.new(game, mon)
        -- HiddenStats (optional companion mod) supplies a 4th page; without
        -- it the summary stays the stock 3 pages.
        local hiddenStats = mod.find and mod.find("hidden_stats")
        local hasExtraPage = hiddenStats and hiddenStats.exports
          and type(hiddenStats.exports.drawSummaryPage) == "function"
        self._expMaxPage = hasExtraPage and 4 or 3

        -- Same A/B page flow, callable from Gen1 Modern UI semantic actions.
        function self:advance()
          if self.page < self._expMaxPage then
            self.page = self.page + 1
          else
            self.game.stack:pop()
          end
        end

        function self:update(_dt)
          local input = self.game.input
          if input:wasPressed("a") or input:wasPressed("b") then
            self:advance()
          end
        end

        local baseDraw = Builtin.draw
        function self:draw()
          if self.page <= 2 then
            baseDraw(self)
            redrawNameWithGender(self)
            if self.page == 1 and SplitSpecial.enabled(mod) then
              redrawSplitSpecialStats(self)
            end
          elseif self.page == 3 then
            drawAbilityPage(self)
          else
            hiddenStats.exports.drawSummaryPage(self, SummaryUi)
          end
        end

        return self
      end,
    })
  end)
end

return SummaryUi
