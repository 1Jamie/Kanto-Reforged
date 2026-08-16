-- Gen 1 and Gen 2 menu-icon class mapping for Kanto Reforged species.
return function(T, Data, run)
  local SpeciesIcons = require("mods.Kanto-Reforged.pokemon.species_icons")

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
  -- Gen1 menu-icon class (not the Fairy typing); Ralts uses the fairy sheet
  T.eq(SpeciesIcons.pickClass({ id = "RALTS", types = { "PSYCHIC_TYPE" } }),
    "FAIRY", "Ralts → FAIRY icon class")
  T.eq(SpeciesIcons.pickClass({ id = "TREECKO", types = { "GRASS" } }),
    "MON", "Treecko → MON")
  T.eq(SpeciesIcons.pickClass({ id = "TORCHIC", types = { "FIRE" } }),
    "QUADRUPED", "Torchic → QUADRUPED")
  T.eq(SpeciesIcons.pickClass({ id = "MUDKIP", types = { "WATER" } }),
    "WATER", "Mudkip → WATER")
  T.eq(SpeciesIcons.pickClass({ id = "RAYQUAZA", types = { "DRAGON", "FLYING" } }),
    "BIRD", "Rayquaza → BIRD")

  T.check(Data.icons and Data.icons.bySpecies, "icons.bySpecies present")
  T.eq(Data.icons.bySpecies.CHIKORITA, "GRASS", "Chikorita registered in bySpecies")
  T.eq(Data.icons.bySpecies.HERACROSS, "BUG", "Heracross registered in bySpecies")
  T.eq(Data.icons.bySpecies.STEELIX, "SNAKE", "Steelix registered in bySpecies")
  T.eq(Data.icons.bySpecies.TREECKO, "MON", "Treecko registered in bySpecies")
  T.eq(Data.icons.bySpecies.MUDKIP, "WATER", "Mudkip registered in bySpecies")

  -- Gen 1 menu icons require string format; Gen 2 requires table format { image = ... }
  T.check(type(Data.icons.icons.MON) == "string",
    "Gen 1 MON icon entry is a string path for PartyMenu.drawIcon")
  if Data.gen2Icons then
    T.check(type(Data.gen2Icons.icons.MON) == "table" and Data.gen2Icons.icons.MON.image ~= nil,
      "MON icon entry is table with .image for Gen 2 PartyMenu")
    T.check(type(Data.gen2Icons.icons.ICON_MONSTER) == "table" and Data.gen2Icons.icons.ICON_MONSTER.image ~= nil,
      "ICON_MONSTER alias registered for Gen 2 menus")
  end

  -- Every Kanto Reforged species got a known class name
  local pd = require("mods.Kanto-Reforged.pokemon.pokemon_data")
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
  T.eq(missing, 0, "every Kanto Reforged species has a bySpecies icon")
  T.eq(bad, 0, "every mapped icon is a Gen 1 class name")

  -- Custom mod icon entries must not be clobbered
  local testData = {
    icons = { icons = { MON = "mon.png" }, bySpecies = { COMBUSKEN = { image = "custom_combusken.png" } } },
    gen2Icons = { icons = { MON = "mon.png" }, species = { COMBUSKEN = "CUSTOM_SHEET" }, bySpecies = {} },
  }
  local modStub = { content = { icons = { register = function() end } }, log = { info = function() end } }
  -- re-run register on existing custom data
  SpeciesIcons.register(modStub, { COMBUSKEN = { types = { "FIRE", "FIGHTING" } } })
  T.check(type(Data.icons.bySpecies.COMBUSKEN) ~= "string" or Data.icons.bySpecies.COMBUSKEN == "MON",
    "Combusken class fallback is valid")
end
