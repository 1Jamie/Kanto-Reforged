-- PC box expansion for National Dex (#1–386).
return function(T, Data, run)
  local PcBoxes = require("mods.Kanto-Reforged.pokemon.pc_boxes")
  local Host = require("mods.Kanto-Reforged.core.host")

  T.eq(PcBoxes.COUNT, 24, "KR expands to 24 PC boxes")
  T.eq(PcBoxes.CAPACITY, 20, "KR keeps 20 mons per box")
  T.check(PcBoxes.COUNT * PcBoxes.CAPACITY >= 386,
    "PC capacity covers National Dex #1–386")

  local Boxes = require("src.pokemon.Boxes")
  T.eq(Boxes.COUNT, PcBoxes.COUNT,
    "Boxes.COUNT matches KR expansion after mod load")
  T.eq(Boxes.CAPACITY, PcBoxes.CAPACITY,
    "Boxes.CAPACITY matches KR expansion after mod load")

  if Host.isGen2() then
    local Save = require("src.core.gen2.Save")
    local Boxes2 = require("src.core.gen2.Boxes")
    T.eq(Save.NUM_BOXES, PcBoxes.COUNT, "Gen2 Save.NUM_BOXES expanded")
    T.eq(Boxes2.NUM_BOXES, PcBoxes.COUNT, "Gen2 Boxes.NUM_BOXES expanded")
  else
    T.eq(Data.constants.boxCount, PcBoxes.COUNT,
      "Gen1 constants.boxCount patched (docs / other mods)")
    T.eq(Data.constants.boxSize, PcBoxes.CAPACITY,
      "Gen1 constants.boxSize patched")
  end

  -- Existing 12/14-box saves grow when ensure/growSave runs.
  local save = { boxes = { {}, {}, {} }, currentBox = 2 }
  PcBoxes.growSave(save)
  T.eq(#save.boxes, PcBoxes.COUNT, "growSave allocates missing boxes")
  T.eq(save.currentBox, 2, "growSave keeps currentBox when in range")

  local ensureSave = { boxes = {}, currentBox = 1 }
  for i = 1, 12 do ensureSave.boxes[i] = {} end
  Boxes.ensure(ensureSave)
  T.check(#ensureSave.boxes >= PcBoxes.COUNT
      or (ensureSave.boxes[PcBoxes.COUNT] ~= nil),
    "Boxes.ensure grows past vanilla count after KR wrap")
end
