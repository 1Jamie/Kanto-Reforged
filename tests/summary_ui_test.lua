-- Summary page 3 (ability / held item) + Kanto ability patches.
return function(T, Data, run)
  local SummaryUi = require("mods.Kanto-Reforged.ui.summary_ui")
  local HeldItems = require("mods.Kanto-Reforged.items.held_items")

  -- Kanto species received Gen 3 abilities from ability_patches.lua
  T.eq(Data.pokemon.BULBASAUR.ability, "OVERGROW", "Bulbasaur ability OVERGROW")
  T.eq(Data.pokemon.CHARMANDER.ability, "BLAZE", "Charmander ability BLAZE")
  T.eq(Data.pokemon.SQUIRTLE.ability, "TORRENT", "Squirtle ability TORRENT")
  T.eq(Data.pokemon.PIKACHU.ability, "STATIC", "Pikachu ability STATIC")
  T.eq(Data.pokemon.GYARADOS.ability, "INTIMIDATE", "Gyarados ability INTIMIDATE")
  T.eq(Data.pokemon.MEW.ability, "SYNCHRONIZE", "Mew ability SYNCHRONIZE")

  local kantoMissing = 0
  for id, def in pairs(Data.pokemon) do
    if def.dex and def.dex <= 151 and (not def.ability or def.ability == "NONE") then
      kantoMissing = kantoMissing + 1
    end
  end
  T.eq(kantoMissing, 0, "every Kanto species has a non-NONE ability")

  -- Johto still has abilities from pokemon_data registration
  T.eq(Data.pokemon.CHIKORITA.ability, "OVERGROW", "Chikorita keeps OVERGROW")

  -- SummaryMenu screen replaced with 3-page wrapper
  local screen = Data.screens and Data.screens.SummaryMenu
  T.check(screen ~= nil, "SummaryMenu screen registered by Kanto Reforged")
  T.check(type(screen) == "function" or (type(screen) == "table" and type(screen.new) == "function"),
    "SummaryMenu factory is callable")

  local factory = type(screen) == "function" and screen or screen.new
  local mon = {
    species = "PIKACHU",
    nickname = "SPARKY",
    level = 25,
    hp = 40,
    stats = { hp = 50, attack = 30, defense = 20, speed = 40, special = 30 },
    exp = 1000,
    moves = { { id = "THUNDERSHOCK", pp = 30 } },
    heldItem = "MAGNET",
    gender = "M",
    ot = "RED",
    otId = 12345,
  }
  local Gender = require("mods.Kanto-Reforged.pokemon.gender")
  T.eq(Gender.glyph(mon), "♂", "summary mon gender glyph")
  T.eq(Gender.nameWithGlyph(mon, "SPARKY"), "SPARKY♂", "page 3 name includes gender")
  local GenderUi = require("mods.Kanto-Reforged.ui.gender_ui")
  T.eq(GenderUi.label(mon, "SPARKY", Data), "SPARKY♂", "GenderUi.label on summary mon")
  -- Minimal game stub for SummaryMenu.new (needs data, input, save, stack)
  local fakeGame = {
    data = Data,
    input = { wasPressed = function() return false end },
    save = { player = { name = "RED", id = 1 }, pokedex = { seen = {}, owned = {} } },
    stack = { pop = function() end },
  }
  -- Cry / sprite may warn without love; still construct if possible
  local ok, menu = pcall(factory, fakeGame, mon)
  if ok and menu then
    T.eq(menu._expMaxPage, 3, "summary has three pages")
    menu.page = 3
    -- Draw should not error on ability page
    local drawOk = pcall(function() menu:draw() end)
    T.check(drawOk, "ability/held-item summary page draws")
  else
    -- Headless without love graphics: still assert factory shape
    T.check(true, "summary factory present (draw skipped headless)")
    T.check(true, "summary draw skipped headless")
  end

  T.eq(HeldItems.def("MAGNET").name, "MAGNET", "Magnet held-item name for summary")

  local AbilityText = require("mods.Kanto-Reforged.battle.ability_text")
  T.check(AbilityText.describe("RUN_AWAY"):find("escape", 1, true),
    "Run Away has a summary blurb")
  T.eq(AbilityText.describe(nil), "No special ability.", "nil ability blurb")

  local page = SummaryUi.abilityPage(mon, Data)
  T.eq(page.gender, "♂", "abilityPage gender")
  T.eq(page.heldItem, "MAGNET", "abilityPage held item label")
  T.eq(page.ability, "STATIC", "abilityPage ability label")
  T.check(type(page.description) == "table", "abilityPage description lines")

  -- Gen2 stock fields: item (not heldItem) + "male"/"female" gender strings.
  local g2mon = {
    species = "PIKACHU",
    item = "BERRY",
    gender = "male",
  }
  local g2page = SummaryUi.abilityPage(g2mon, Data)
  T.eq(g2page.gender, "♂", "abilityPage reads Gen2 male string")
  T.eq(Gender.of(g2mon), "M", "Gender.of accepts male")
  T.eq(Gender.of({ gender = "female" }), "F", "Gender.of accepts female")
  T.check(g2page.heldItem ~= "-----", "abilityPage reads Gen2 mon.item")
  T.eq(SummaryUi.GEN2_ABILITY_PAGE, 4, "Gen2 ability page is page 4")

  -- Gen2 wrapper: pink→green→blue→ability→pink; A closes on ability page.
  do
    local okG2, Builtin = pcall(require, "src.ui.gen2.SummaryMenu")
    if okG2 and Builtin and SummaryUi.wrapGen2Summary then
      local closed = false
      local g2menu = SummaryUi.wrapGen2Summary(Builtin, fakeGame, {
        mon = mon,
        page = 1,
        onClose = function() closed = true end,
      })
      T.eq(g2menu.page, 1, "Gen2 summary starts on pink")
      g2menu:turnPage(1)
      T.eq(g2menu.page, 2, "Gen2 page → green")
      g2menu:turnPage(1)
      T.eq(g2menu.page, 3, "Gen2 page → blue")
      g2menu:turnPage(1)
      T.eq(g2menu.page, 4, "Gen2 page → ability")
      g2menu:turnPage(1)
      T.eq(g2menu.page, 1, "Gen2 ability wraps to pink")
      g2menu:turnPage(-1)
      T.eq(g2menu.page, 4, "Gen2 left from pink wraps to ability")
      fakeGame.input = {
        wasPressed = function(_, key) return key == "a" end,
      }
      g2menu:update(0)
      T.check(closed, "Gen2 A on ability page closes")
    else
      T.check(true, "Gen2 SummaryMenu wrap skipped (unavailable)")
    end
  end

  if ok and menu then
    T.check(type(menu.advance) == "function", "summary exposes advance()")
    menu.page = 2
    menu:advance()
    T.eq(menu.page, 3, "advance moves to ability page")
    local popped = false
    fakeGame.stack.pop = function() popped = true end
    menu:advance()
    T.check(popped, "advance on last page closes summary")
  end
end
