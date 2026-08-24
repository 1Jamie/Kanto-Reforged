-- Gender UI labels, Nidoran suppression, and Gen1 presentation patches.
return function(T, Data, run)
  local GenderUi = require("mods.Kanto-Reforged.ui.gender_ui")
  local Gender = require("mods.Kanto-Reforged.pokemon.gender")

  local maleMon = { species = "PIKACHU", nickname = "SPARKY", gender = "M" }
  T.eq(GenderUi.label(maleMon, "SPARKY", Data), "SPARKY♂", "label appends male glyph")
  T.eq(GenderUi.glyph(maleMon, "SPARKY", Data), "♂", "glyph for male")

  local femaleMon = { species = "JIGGLYPUFF", gender = "F" }
  T.eq(GenderUi.label(femaleMon, "JIGGLY", Data), "JIGGLY♀", "label appends female glyph")

  local genderless = { species = "MAGNEMITE", gender = nil }
  T.eq(GenderUi.label(genderless, "MAGNET", Data), "MAGNET", "genderless unchanged")
  T.check(not GenderUi.shouldShow(genderless, "MAGNET", Data), "genderless hidden")

  -- Nidoran: suppress when showing default species name
  local nidoranM = { species = "NIDORAN_M", gender = "M" }
  local nidoranName = Data.pokemon.NIDORAN_M.name
  T.check(not GenderUi.shouldShow(nidoranM, nidoranName, Data),
    "Nidoran M default name suppresses glyph")
  T.eq(GenderUi.label(nidoranM, nidoranName, Data), nidoranName,
    "Nidoran M default label has no suffix")
  T.eq(GenderUi.label(nidoranM, "SPIKE", Data), "SPIKE♂",
    "Nidoran M custom nickname shows glyph")

  local nidoranF = { species = "NIDORAN_F", gender = "F" }
  T.eq(GenderUi.label(nidoranF, "NINA", Data), "NINA♀",
    "Nidoran F custom nickname shows glyph")

  -- PC list label format
  local fakeGame = { data = Data, save = { party = {} } }
  T.check(GenderUi.pcLabel(fakeGame, {
    species = "RATTATA", nickname = "RAT", gender = "F", level = 12,
  }):find("♀", 1, true), "pcLabel includes gender glyph")

  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen1() then
    local BattleState = require("src.battle.BattleState")
    T.check(BattleState._krGenderHud, "BattleState drawHUDs patched")
    T.check(BattleState._krGenderNickname, "BattleState askNicknameUI patched")
    T.check(require("src.ui.PartyMenu")._krGenderParty, "PartyMenu draw patched")
    T.check(require("src.ui.ListMenu")._krGenderPc, "ListMenu PC label patch installed")
    T.check(require("src.ui.NamingScreen")._krGenderDraw, "NamingScreen gender draw patched")
  else
    T.check(true, "Gender UI patches are Gen1-only")
  end

  T.eq(Gender.glyph(maleMon), "♂", "Gender.glyph still works for summary")
end
