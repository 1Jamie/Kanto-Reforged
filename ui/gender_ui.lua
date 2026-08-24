-- Gender glyph presentation outside the summary screen (battle HUD, party,
-- catch/nickname, PC lists). Gen 1 only; Gen 2 battle/PC already draw gender
-- in the engine where ported.

local Font = require("src.render.Font")
local Gender = require("mods.Kanto-Reforged.pokemon.gender")
local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
local Strings = require("src.core.Strings")

local GenderUi = {}

local NIDORAN_SPECIES = {
  NIDORAN_M = true,
  NIDORAN_F = true,
}

local function normalizeName(name)
  if type(name) ~= "string" then return "" end
  return name:gsub("^%s+", ""):gsub("%s+$", ""):upper()
end

-- Gen 3 Nidoran rule: no separate symbol when the displayed name is the
-- default species name (gender is already in the species name).
function GenderUi.shouldShow(mon, baseName, data)
  if not mon or not Gender.of(mon) then return false end
  if not mon.species or not NIDORAN_SPECIES[mon.species] then return true end
  local def = data and data.pokemon and data.pokemon[mon.species]
  local speciesName = def and def.name or mon.species
  local shown = baseName
  if shown == nil or shown == "" then
    shown = mon.nickname or speciesName
  end
  return normalizeName(shown) ~= normalizeName(speciesName)
end

function GenderUi.glyph(mon, baseName, data)
  if not GenderUi.shouldShow(mon, baseName, data) then return "" end
  return Gender.glyph(mon)
end

function GenderUi.label(mon, baseName, data)
  baseName = baseName or ""
  local g = GenderUi.glyph(mon, baseName, data)
  if g == "" then return baseName end
  return baseName .. g
end

function GenderUi.drawGlyph(mon, x, y, data)
  local g = GenderUi.glyph(mon, nil, data)
  if g == "" then return end
  Font.draw(g, x, y)
end

-- Party row: fixed column before <LV> (tile 12).
function GenderUi.drawPartyGlyph(mon, x, y, data)
  GenderUi.drawGlyph(mon, x, y, data)
end

-- Naming screen: end of the dash row (Gen 3 DrawGenderIcon placement).
function GenderUi.drawNamingGlyph(mon, maxLen, data)
  maxLen = maxLen or 10
  GenderUi.drawGlyph(mon, 56 + maxLen * 8, 24, data)
end

function GenderUi.pcLabel(game, mon)
  local def = game.data.pokemon[mon.species]
  local base = mon.nickname or def.name
  return Strings("%s :L%d", GenderUi.label(mon, base, game.data), mon.level)
end

local function patchBattleHud(BattleState)
  if BattleState._krGenderHud then return end
  local original = BattleState.drawHUDs
  if type(original) ~= "function" then return end

  BattleState.drawHUDs = function(self, slide)
    local enemyName, playerName
    if self.enemy and self.enemy.mon then
      enemyName = self.enemy.name
      self.enemy.name = GenderUi.label(self.enemy.mon, enemyName, self.data)
    end
    if self.player and self.player.mon then
      playerName = self.player.name
      self.player.name = GenderUi.label(self.player.mon, playerName, self.data)
    end
    original(self, slide)
    if enemyName then self.enemy.name = enemyName end
    if playerName then self.player.name = playerName end
  end
  BattleState._krGenderHud = true
end

local function patchAskNickname(BattleState)
  if BattleState._krGenderNickname then return end
  local original = BattleState.askNicknameUI
  if type(original) ~= "function" then return end

  BattleState.askNicknameUI = function(self, mon, displayName)
    local game = self.game
    self.lockedBall = nil
    self.blankForAskName = true
    local TextBox = require("src.render.TextBox")
    local Screens = require("src.ui.Screens")
    local labeled = GenderUi.label(mon, displayName, self.data)
    local text = self:romText("_DoYouWantToNicknameText",
      "Do you want to\ngive a nickname\nto %s?", labeled)
    local label = game.data.text and game.data.text._DoYouWantToNicknameText
    if label then
      text = label:gsub("\t", "\n"):gsub("{RAM:?[%w_]*}", labeled)
    end
    return TextBox.new(game, text, nil, {
      choice = function(yes)
        self.blankForAskName = false
        if not yes then return end
        pcall(Screens.push, game, "NamingScreen", {
          title = Strings("NICKNAME?"),
          maxLen = 10,
          mon = mon,
          onDone = function(name)
            if name and #name > 0 then mon.nickname = name end
          end,
        })
      end,
    })
  end
  BattleState._krGenderNickname = true
end

local function patchNamingScreen(NamingScreen)
  if NamingScreen._krGenderDraw then return end
  local original_new = NamingScreen.new
  local original_draw = NamingScreen.draw

  NamingScreen.new = function(game, opts)
    local self = original_new(game, opts or {})
    self.mon = opts and opts.mon
    return self
  end

  NamingScreen.draw = function(self)
    original_draw(self)
    if self.choosing or not self.mon then return end
    local data = self.game and self.game.data
    love.graphics.setColor(0, 0, 0, 1)
    GenderUi.drawNamingGlyph(self.mon, self.maxLen, data)
    love.graphics.setColor(1, 1, 1, 1)
  end
  NamingScreen._krGenderDraw = true
end

local function patchPartyMenu(PartyMenu)
  if PartyMenu._krGenderParty then return end
  local original_drawIcon = PartyMenu.drawIcon
  if type(original_drawIcon) ~= "function" then return end

  PartyMenu.drawIcon = function(game, mon, x, y, selected, counter, forceAlt)
    original_drawIcon(game, mon, x, y, selected, counter, forceAlt)
    if mon and x == 8 then
      local data = game and game.data
      love.graphics.setColor(0, 0, 0, 1)
      GenderUi.drawPartyGlyph(mon, 96, y, data)
      love.graphics.setColor(1, 1, 1, 1)
    end
  end
  PartyMenu._krGenderParty = true
end

local function patchListMenu(ListMenu)
  if ListMenu._krGenderPc then return end
  local original_new = ListMenu.new
  if type(original_new) ~= "function" then return end

  ListMenu.new = function(game, title, items, opts)
    opts = opts or {}
    local kind = opts.kind
    if kind == "pc_box_withdraw" or kind == "pc_box_release" then
      local box = require("src.pokemon.Boxes").active(game.save)
      for _, item in ipairs(items or {}) do
        local mon = box[item.value]
        if mon then item.label = GenderUi.pcLabel(game, mon) end
      end
    elseif kind == "pc_box_deposit" then
      for _, item in ipairs(items or {}) do
        local mon = game.save.party[item.value]
        if mon then item.label = GenderUi.pcLabel(game, mon) end
      end
    end
    return original_new(game, title, items, opts)
  end
  ListMenu._krGenderPc = true
end

function GenderUi.register(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then return end

  Gen1Patch.apply(require("src.battle.BattleState"), function(BattleState)
    patchBattleHud(BattleState)
    patchAskNickname(BattleState)
  end)

  Gen1Patch.apply(require("src.ui.NamingScreen"), patchNamingScreen)
  Gen1Patch.apply(require("src.ui.PartyMenu"), patchPartyMenu)
  Gen1Patch.apply(require("src.ui.ListMenu"), patchListMenu)

  mod.log:info("Gender UI patches registered (battle, party, catch, PC)")
end

return GenderUi
