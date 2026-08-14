-- Map Kanto Reforged species onto Gen 1 party/menu icon classes.
-- Vanilla only ships ~10 shared icon sheets keyed by dex 1–151; anything
-- past that draws blank unless icons.bySpecies is filled.

local SpeciesIcons = {}

-- Gen 1 class names (must match data.generated.icons.icons keys).
local CLASS = {
  GRASS = "GRASS",
  MON = "MON",
  WATER = "WATER",
  BUG = "BUG",
  BIRD = "BIRD",
  QUADRUPED = "QUADRUPED",
  SNAKE = "SNAKE",
  FAIRY = "FAIRY",
  BALL = "BALL",
  HELIX = "HELIX",
}

-- Overrides where type heuristics would pick the wrong silhouette.
local EXPLICIT = {
  -- Snakes / serpentine
  EKANS = "SNAKE", ARBOK = "SNAKE",
  ONIX = "SNAKE", STEELIX = "SNAKE",
  DUNSPARCE = "SNAKE",
  SEVIPER = "SNAKE",
  GYARADOS = "SNAKE",
  DRATINI = "SNAKE", DRAGONAIR = "SNAKE", DRAGONITE = "SNAKE",
  BAGON = "SNAKE", SHELGON = "MON", SALAMENCE = "BIRD",
  -- Ball / orb
  VOLTORB = "BALL", ELECTRODE = "BALL",
  MAGNEMITE = "BALL", MAGNETON = "BALL",
  FORRETRESS = "BALL",
  CASTFORM = "BALL",
  -- Helix / shell
  SHUCKLE = "HELIX",
  OMANYTE = "HELIX", OMASTAR = "HELIX",
  KABUTO = "HELIX", KABUTOPS = "HELIX",
  CORSOLA = "HELIX",
  CLAMPERL = "HELIX",
  -- Birds that aren't typed Flying-first
  MURKROW = "BIRD", HONCHKROW = "BIRD",
  NATU = "BIRD", XATU = "BIRD",
  SKIPLOOM = "BIRD", JUMPLUFF = "BIRD", -- floaters; plant+bird vibe
  -- Fairy-ish / small mammals
  PICHU = "FAIRY", CLEFFA = "FAIRY", IGGLYBUFF = "FAIRY",
  TOGEPI = "FAIRY", TOGETIC = "FAIRY", TOGEKISS = "FAIRY",
  MARILL = "FAIRY", AZUMARILL = "FAIRY", AZURILL = "FAIRY",
  SNUBBULL = "FAIRY", GRANBULL = "FAIRY",
  -- Bugs
  LEDYBA = "BUG", LEDIAN = "BUG",
  SPINARAK = "BUG", ARIADOS = "BUG",
  YANMA = "BUG",
  PINECO = "BUG",
  HERACROSS = "BUG",
  WURMPLE = "BUG", SILCOON = "BUG", CASCOON = "BUG",
  BEAUTIFLY = "BUG", DUSTOX = "BUG",
  SURSKIT = "BUG", MASQUERAIN = "BUG",
  NINCADA = "BUG", NINJASK = "BUG", SHEDINJA = "BUG",
  VOLBEAT = "BUG", ILLUMISE = "BUG",
  -- Grass plants
  CHIKORITA = "GRASS", BAYLEEF = "GRASS", MEGANIUM = "GRASS",
  BELLOSSOM = "GRASS",
  SUNKERN = "GRASS", SUNFLORA = "GRASS",
  LOTAD = "GRASS", LOMBRE = "GRASS", LUDICOLO = "GRASS",
  SEEDOT = "GRASS", NUZLEAF = "GRASS", SHIFTRY = "GRASS",
  SHROOMISH = "GRASS", BRELOOM = "GRASS",
  CACNEA = "GRASS", CACTURNE = "GRASS",
  TROPIUS = "GRASS",
  -- Water
  TOTODILE = "WATER", CROCONAW = "WATER", FERALIGATR = "WATER",
  MUDKIP = "WATER", MARSHTOMP = "WATER", SWAMPERT = "WATER",
  -- Fire quadrupeds / starters
  CYNDAQUIL = "QUADRUPED", QUILAVA = "QUADRUPED", TYPHLOSION = "QUADRUPED",
  TORCHIC = "QUADRUPED", COMBUSKEN = "MON", BLAZIKEN = "MON",
  -- Humanoid / bipedal default MON
  TREECKO = "MON", GROVYLE = "MON", SCEPTILE = "MON",
  RALTS = "FAIRY", KIRLIA = "FAIRY", GARDEVOIR = "FAIRY", GALLADE = "MON",
  ABRA = "MON", KADABRA = "MON", ALAKAZAM = "MON",
  MACHOP = "MON", MACHOKE = "MON", MACHAMP = "MON",
  HAUNTER = "MON", GENGAR = "MON",
  -- Quadrupeds
  MAREEP = "QUADRUPED", FLAAFFY = "QUADRUPED", AMPHAROS = "MON",
  ESPEON = "QUADRUPED", UMBREON = "QUADRUPED",
  HOUNDOUR = "QUADRUPED", HOUNDOOM = "QUADRUPED",
  NUMEL = "QUADRUPED", CAMERUPT = "QUADRUPED",
  ABSOL = "QUADRUPED",
  LARVITAR = "QUADRUPED", PUPITAR = "QUADRUPED", TYRANITAR = "MON",
}

local function hasType(types, want)
  for _, t in ipairs(types or {}) do
    if t == want then return true end
  end
  return false
end

function SpeciesIcons.pickClass(species)
  if not species or not species.id then return CLASS.MON end
  local explicit = EXPLICIT[species.id]
  if explicit then return explicit end

  local types = species.types or {}
  local primary = types[1]

  if hasType(types, "BUG") then return CLASS.BUG end
  if hasType(types, "FLYING") then return CLASS.BIRD end
  if primary == "GRASS" then return CLASS.GRASS end
  if primary == "WATER" then return CLASS.WATER end
  if primary == "DRAGON" then return CLASS.SNAKE end
  if hasType(types, "FAIRY") then return CLASS.FAIRY end
  -- Pikachu-line style: pure Electric uses the fairy sheet in Gen 1
  if primary == "ELECTRIC" and not hasType(types, "STEEL") then
    return CLASS.FAIRY
  end
  if hasType(types, "STEEL") and hasType(types, "ELECTRIC") then
    return CLASS.BALL
  end
  if primary == "ROCK" and hasType(types, "WATER") then return CLASS.HELIX end
  if primary == "FIRE" then return CLASS.QUADRUPED end
  if primary == "NORMAL" then return CLASS.QUADRUPED end
  return CLASS.MON
end

function SpeciesIcons.register(mod, speciesTable)
  local n = 0
  for id, def in pairs(speciesTable or {}) do
    local className = SpeciesIcons.pickClass({
      id = id,
      types = def.types,
    })
    mod.content.icons:register(id, className)
    n = n + 1
  end
  mod.log:info("Mapped %d species onto Gen 1 menu icon classes", n)
  return n
end

return SpeciesIcons
