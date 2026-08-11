-- Extra SummaryMenu page: ability + held item (Gen 2/3 Kanto Reforged fields).
-- Wraps the builtin two-page status screen without editing src/.
--
-- Publishes a read-only page-3 snapshot + advance() for Gen1 Modern UI when
-- that mod is present. Native Gen1 draw/input is unchanged when it is absent.

local Font = require("src.render.Font")
local Strings = require("src.core.Strings")
local TextBox = require("src.render.TextBox")
local HeldItems = require("mods.Kanto-Reforged.held_items")
local AbilityText = require("mods.Kanto-Reforged.ability_text")
local Gender = require("mods.Kanto-Reforged.gender")
local SplitSpecial = require("mods.Kanto-Reforged.split_special")

local SummaryUi = {}

local function abilityLabel(id)
  if not id or id == "" or id == "NONE" then return nil end
  return id:gsub("_", " ")
end

local function heldLabel(mon, data)
  local id = mon and mon.heldItem
  if not id then return nil end
  local def = HeldItems.def(id) or (data.items and data.items[id])
  return def and def.name or id:gsub("_", " ")
end

local function monDisplayName(mon, def)
  local base = mon.nickname or (def and def.name) or "?????"
  return Gender.nameWithGlyph(mon, base)
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
  local def = self.game.data.pokemon[mon.species]
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 72, 8, 88, 8)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(monDisplayName(mon, def), 72, 8)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Compact 5-stat redraw when SP.ATK / SP.DEF is on (fits the Gen1 10x10 box).
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
    { "ATTACK", stats.attack },
    { "DEFENSE", stats.defense },
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
  Font.draw(monDisplayName(mon, def), 72, 8)
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

function SummaryUi.register(mod)
  local Host = require("mods.Kanto-Reforged.host")
  if Host.isGen2() then
    local ok, Builtin = pcall(require, "src.ui.gen2.SummaryMenu")
    if not ok or not Builtin or not Builtin.new then
      mod.log:warn("Gen2 SummaryMenu unavailable; ability overlay skipped")
      return
    end
    mod.content.screens:register("Gen2SummaryMenu", {
      new = function(game, opts)
        local self = Builtin.new(game, opts)
        local baseDraw = self.draw
        function self:draw()
          baseDraw(self)
          -- Pink page: ability name under the status/type block.
          if (self.page or 1) == 1 and self.mon then
            local page = SummaryUi.abilityPage(self.mon, self.game and self.game.data)
            love.graphics.setColor(0, 0, 0, 1)
            Font.draw(Strings("ABILITY/") .. page.ability, 1 * 8, 7 * 8)
            love.graphics.setColor(1, 1, 1, 1)
          end
        end
        return self
      end,
    })
    return
  end

  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
  Gen1Patch.apply(require("src.ui.SummaryMenu"), function(Builtin)
    mod.content.screens:register("SummaryMenu", {
      new = function(game, mon)
        local self = Builtin.new(game, mon)
        self._expMaxPage = 3

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
          else
            drawAbilityPage(self)
          end
        end

        return self
      end,
    })
  end)
end

return SummaryUi
