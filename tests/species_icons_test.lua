-- Gen 1 menu-icon class mapping for expansion species.
return function(T, Data, run)
  local SpeciesIcons = require("mods.expansion_pack.species_icons")

  T.eq(SpeciesIcons.pickClass({ id = "HERACROSS", types = { "BUG", "FIGHTING" } }),
    "BUG", "Heracross → BUG")
  T.eq(SpeciesIcons.pickClass({ id = "MURKROW", types = { "DARK", "FLYING" } }),
    "BIRD", "Murkrow → BIRD")
  T.eq(SpeciesIcons.pickClass({ id = "CHIKORITA", types = { "GRASS" } }),
    "GRASS", "Chikorita → GRASS")
  T.eq(SpeciesIcons.pickClass({ id = "TOTODILE", types = { "WATER" } }),
    "WATER", "Totodile → WATER")
  T.eq(SpeciesIcons.pickClass({ id = "CYNDAQUIL", types = { "FIRE" } }),
    "QUADRUPED", "Cyndaquil → QUADRUPED")
  T.eq(SpeciesIcons.pickClass({ id = "STEELIX", types = { "STEEL", "GROUND" } }),
    "SNAKE", "Steelix → SNAKE")
  T.eq(SpeciesIcons.pickClass({ id = "RALTS", types = { "PSYCHIC_TYPE", "FAIRY" } }),
    "FAIRY", "Ralts → FAIRY")
  T.eq(SpeciesIcons.pickClass({ id = "GENERIC_PSY", types = { "PSYCHIC_TYPE" } }),
    "MON", "generic Psychic → MON")

  T.check(Data.icons and Data.icons.bySpecies, "icons.bySpecies present")
  T.eq(Data.icons.bySpecies.CHIKORITA, "GRASS", "Chikorita registered in bySpecies")
  T.eq(Data.icons.bySpecies.HERACROSS, "BUG", "Heracross registered in bySpecies")
  T.eq(Data.icons.bySpecies.STEELIX, "SNAKE", "Steelix registered in bySpecies")

  -- Every expansion species got a known class name
  local pd = require("mods.expansion_pack.pokemon_data")
  local valid = {
    GRASS = true, MON = true, WATER = true, BUG = true, BIRD = true,
    QUADRUPED = true, SNAKE = true, FAIRY = true, BALL = true, HELIX = true,
  }
  local missing, bad = 0, 0
  for id in pairs(pd.species) do
    local cls = Data.icons.bySpecies[id]
    if not cls then
      missing = missing + 1
    elseif not valid[cls] then
      bad = bad + 1
    end
  end
  T.eq(missing, 0, "every expansion species has a bySpecies icon")
  T.eq(bad, 0, "every mapped icon is a Gen 1 class name")
end
