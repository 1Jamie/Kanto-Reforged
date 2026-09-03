-- Empty moveset repair for saves caught during the Hoenn register bug.
return function(T, Data, run)
  local Repair = require("mods.Kanto-Reforged.pokemon.empty_moves_repair")

  T.check(not Repair.hasMoves({ moves = {} }), "empty table has no moves")
  T.check(not Repair.hasMoves({ moves = { { pp = 0 } } }), "slot without id has no moves")
  T.check(Repair.hasMoves({ moves = { { id = "TACKLE" } } }), "one id counts")

  local species = Data.pokemon.RALTS and "RALTS"
    or (Data.pokemon.TREECKO and "TREECKO")
    or "PIKACHU"
  local def = Data.pokemon[species]
  T.check(def ~= nil, "repair test has a species")

  local ids = Repair.idsAtLevel(Data, species, 50)
  T.check(#ids >= 1, "idsAtLevel returns at least one known move")
  T.check(#ids <= 4, "idsAtLevel keeps at most four")
  for _, id in ipairs(ids) do
    T.check(Data.moves[id] ~= nil, "repaired move is registered: " .. tostring(id))
  end

  local empty = { species = species, level = 20, moves = {} }
  T.check(Repair.fillMon(Data, empty), "fills a 0-move mon")
  T.check(Repair.hasMoves(empty), "mon has moves after fill")
  T.check(#empty.moves <= 4, "fill writes at most four slots")

  local keep = { species = species, level = 20, moves = { { id = "TACKLE", pp = 35 } } }
  T.check(not Repair.fillMon(Data, keep), "does not overwrite an existing move")
  T.eq(keep.moves[1].id, "TACKLE", "existing move unchanged")

  local egg = { species = species, level = 5, isEgg = true, moves = {} }
  T.check(not Repair.fillMon(Data, egg), "does not fill eggs")

  local save = {
    party = { { species = species, level = 10, moves = {} } },
    boxes = { { { species = species, level = 15, moves = {} } } },
    daycare = { mon = { species = species, level = 12, moves = {} } },
  }
  T.eq(Repair.repairSave(Data, save), 3, "repairs party, box, and daycare")
end
