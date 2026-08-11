-- Quarantine recovery: party/bag before PC dump.
return function(T, Data, run)
  local QR = require("mods.Kanto-Reforged.quarantine_recover")

  -- Orphaned Gen 3 mon + berry return to party/bag when Data knows them.
  local save = {
    party = {
      { species = "RATTATA", level = 5, moves = { { id = "TACKLE", pp = 35 } } },
    },
    inventory = { POKE_BALL = 5 },
    bagOrder = { "POKE_BALL" },
    boxes = { {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {} },
    orphaned = {
      mons = {
        { species = "ZANGOOSE", level = 20, moves = { { id = "SCRATCH", pp = 35 } } },
        { species = "ABSOL", level = 18, moves = { { id = "SCRATCH", pp = 35 } } },
      },
      items = {
        { id = "BERRY", count = 3, from = "inventory" },
        { id = "PECHA_BERRY", count = 1, from = "inventory" },
      },
    },
  }

  T.check(Data.pokemon.ZANGOOSE ~= nil, "Zangoose registered")
  T.check(Data.items.BERRY ~= nil, "BERRY registered")

  local n = QR.restore(save, Data)
  T.eq(n.mons, 2, "both orphaned mons restored to party")
  T.eq(n.items, 2, "both orphaned berry stacks restored to bag")
  T.eq(#save.party, 3, "party is Rattata + Zangoose + Absol")
  T.eq(save.party[2].species, "ZANGOOSE", "Zangoose rejoins party")
  T.eq(save.party[3].species, "ABSOL", "Absol rejoins party")
  T.eq(save.inventory.BERRY, 3, "BERRY back in bag")
  T.eq(save.orphaned, nil, "empty quarantine cleared")

  -- Party full: leftover stays orphaned for engine PC reclaim.
  local full = {
    party = {
      { species = "RATTATA" }, { species = "PIDGEY" }, { species = "SPEAROW" },
      { species = "NIDORAN_M" }, { species = "NIDORAN_F" }, { species = "EEVEE" },
    },
    inventory = {},
    bagOrder = {},
    orphaned = {
      mons = { { species = "ZANGOOSE", level = 10 } },
      items = {},
    },
  }
  local n2 = QR.restore(full, Data)
  T.eq(n2.mons, 0, "full party leaves orphan for PC reclaim")
  T.eq(#full.orphaned.mons, 1, "Zangoose still orphaned when party full")
end
