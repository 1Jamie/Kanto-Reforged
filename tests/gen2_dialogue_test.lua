return function(T)
  local Gen2Dialogue = require("mods.Kanto-Reforged.battle.gen2_dialogue")
  local Dialogue = require("mods.Kanto-Reforged.core.dialogue")

  local refusal = "No! There's no running from a trainer battle!"
  T.check(Gen2Dialogue.needsScroll(refusal),
    "trainer run refusal overflows Gen2 battle box")
  local formatted = Gen2Dialogue.prepare(refusal)
  T.check(formatted:find("\v", 1, true) ~= nil,
    "trainer run refusal gets \\v scroll marker")
  T.check(formatted:find("trainer battle!", 1, true) ~= nil,
    "trainer run refusal keeps final sentence")
  for line in (formatted .. "\n"):gmatch("([^\n\v]+)") do
    T.check(Dialogue.glyphLen(line) <= 18,
      "Gen2 battle line <= 18 columns: " .. line)
  end

  local short = "Can't escape!"
  T.eq(Gen2Dialogue.prepare(short), short, "short lines pass through unchanged")

  local preset = "Enemy FERALIGATR\nused TACKLE!"
  T.eq(Gen2Dialogue.prepare(preset), preset,
    "two-line engine text passes through unchanged")

  Gen2Dialogue.install({ path = "mods/Kanto-Reforged" })
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then
    local BS = require("src.ui.gen2.BattleState")
    T.check(BS._krGen2Dialogue, "Gen2 BattleState dialogue patch installed")
  end
end
