-- Gen3 learnset parity checks (loaded from Kanto-Reforged_test.lua).
return function(T, Data)
  local Pokemon = require("src.pokemon.Pokemon")

  local function learnsetLevel(species, move)
    for _, entry in ipairs(Data.pokemon[species].learnset or {}) do
      if entry.move == move then return entry.level end
    end
    return nil
  end

  local function level1Has(species, move)
    for _, mv in ipairs(Data.pokemon[species].level1Moves or {}) do
      if mv == move then return true end
    end
    return false
  end

  local function tmhmKnown(species)
    for _, mv in ipairs(Data.pokemon[species].tmhm or {}) do
      T.check(Data.moves[mv] ~= nil, species .. " tmhm move registered: " .. mv)
    end
  end

  -- Emerald timing (not ROM L19 Dig / L15 Growl)
  T.eq(learnsetLevel("DIGLETT", "GROWL"), 5, "Diglett Growl L5 (Gen3)")
  T.eq(learnsetLevel("DIGLETT", "MAGNITUDE"), 9, "Diglett Magnitude L9")
  T.eq(learnsetLevel("DIGLETT", "DIG"), 17, "Diglett Dig L17 (not ROM L19)")
  T.check(level1Has("DIGLETT", "SCRATCH"), "Diglett L1 Scratch")

  local digMoves = Pokemon.movesAtLevel(Data.pokemon.DIGLETT, 19)
  local digHasScratch, digHasMag = false, false
  for _, id in ipairs(digMoves) do
    if id == "SCRATCH" then digHasScratch = true end
    if id == "MAGNITUDE" then digHasMag = true end
  end
  T.check(digHasScratch and digHasMag, "Diglett L19 movesAtLevel includes Scratch + Magnitude")

  T.eq(learnsetLevel("PIKACHU", "IRON_TAIL"), 30, "Pikachu Iron Tail L30 backport")
  T.eq(learnsetLevel("CHIKORITA", "RAZOR_LEAF"), 8, "Chikorita Razor Leaf L8 (Emerald)")
  T.eq(learnsetLevel("CHARMANDER", "SMOKESCREEN"), 13, "Charmander Smokescreen L13 (Emerald)")

  -- No FRLG-only Metal Claw on Charmander in Emerald-first table
  T.check(learnsetLevel("CHARMANDER", "METAL_CLAW") == nil,
    "Charmander has no Metal Claw level-up (Emerald, not FRLG)")

  tmhmKnown("DIGLETT")
  tmhmKnown("PIKACHU")

  -- ApplyGen3 folds evolutionMoves into Gen1 level1Moves when present
  local ApplyGen3 = require("mods.Kanto-Reforged.pokemon.apply_gen3_learnsets")
  local folded = ApplyGen3.gen1Level1({
    level1Moves = { "TACKLE" },
    evolutionMoves = { "BITE" },
    learnset = {},
  })
  local hasBite = false
  for _, mv in ipairs(folded) do
    if mv == "BITE" then hasBite = true end
  end
  T.check(hasBite, "gen1Level1 folds evolutionMoves into level1Moves")

  local g2 = ApplyGen3.toLevelMoves({
    level1Moves = { "TACKLE" },
    evolutionMoves = { "BITE" },
    learnset = { { level = 10, move = "SLASH" } },
  })
  T.eq(g2[1].move, "BITE", "toLevelMoves puts evolution move first at L1")
end
