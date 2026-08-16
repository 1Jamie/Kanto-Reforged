-- Map Kanto Reforged species onto Gen 1 and Gen 2 party/menu icon classes.
-- Vanilla only ships ~10 shared icon sheets keyed by dex 1–151; anything
-- past that draws blank unless icons.bySpecies / icons.species is filled.

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

-- Aliases mapping Gen 2 ICON_* sheet keys to standard icon classes.
local GEN2_ALIASES = {
  ICON_MONSTER = "MON",
  ICON_PLANT = "GRASS",
  ICON_BUG = "BUG",
  ICON_BIRD = "BIRD",
  ICON_FISH = "WATER",
  ICON_SERPENT = "SNAKE",
  ICON_EQUINE = "QUADRUPED",
  ICON_CLEFAIRY = "FAIRY",
  ICON_DONPHAN = "QUADRUPED",
  ICON_GEODUDE = "MON",
  ICON_SHELLEY = "HELIX",
  ICON_SUDOWOODO = "MON",
  ICON_STANTLER = "QUADRUPED",
  ICON_UNOWN = "FAIRY",
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
  BEAUTIFly = "BUG", DUSTOX = "BUG",
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

local function applyTargetTableFixes(target, speciesTable, isGen2)
  if not target then return end
  target.icons = target.icons or {}
  target.bySpecies = target.bySpecies or {}
  target.species = target.species or {}

  if isGen2 then
    -- Wrap string entries into { image = path } tables so Gen 2 PartyMenu:iconFor
    -- (which accesses entry.image) correctly resolves the image path.
    for k, v in pairs(target.icons) do
      if type(v) == "string" then
        target.icons[k] = { image = v }
      end
    end

    -- Register GEN2_ALIASES so ICON_* sheet lookups in Gold menus resolve to the valid icon
    for iconName, targetClass in pairs(GEN2_ALIASES) do
      if target.icons[targetClass] then
        target.icons[iconName] = target.icons[targetClass]
      end
    end

    for id, def in pairs(speciesTable or {}) do
      local className = SpeciesIcons.pickClass({
        id = id,
        types = def.types,
      })
      if not target.species[id] then
        target.species[id] = className
      end
      if not target.bySpecies[id] then
        target.bySpecies[id] = className
      end
    end
  else
    -- For Gen 1 (Data.icons), keep icons[k] as string filepaths to prevent
    -- string concatenation errors in Gen 1 PartyMenu.drawIcon.
    for k, v in pairs(target.icons) do
      if type(v) == "table" and v.image then
        target.icons[k] = v.image
      end
    end

    for id, def in pairs(speciesTable or {}) do
      local className = SpeciesIcons.pickClass({
        id = id,
        types = def.types,
      })
      -- Only set fallback if no custom entry or override exists
      if target.bySpecies[id] == nil then
        target.bySpecies[id] = className
      end
    end
  end
end

function SpeciesIcons.register(mod, speciesTable)
  local n = 0
  for id, def in pairs(speciesTable or {}) do
    local className = SpeciesIcons.pickClass({
      id = id,
      types = def.types,
    })
    pcall(function()
      mod.content.icons:register(id, className)
    end)
    n = n + 1
  end

  -- Directly fix runtime Data.icons and Data.gen2Icons data structures
  local Data = require("src.core.Data")
  applyTargetTableFixes(Data.icons, speciesTable, false)
  applyTargetTableFixes(Data.gen2Icons, speciesTable, true)

  -- Defensive safety patch for Gen 1 PartyMenu.drawIcon:
  -- When a custom icon is provided by another mod (via pokemon.icon hook, def.icon, or custom path),
  -- ensure it is drawn whole in full color without DMG OBP0 greyscale baking,
  -- without left-half mirroring, and with proper 2-frame animation.
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen1() then
    local ok, PartyMenu = pcall(require, "src.ui.PartyMenu")
    if ok and PartyMenu and PartyMenu.drawIcon and not PartyMenu._krTableIconPatch then
      local origDrawIcon = PartyMenu.drawIcon
      local customIconCache = {}
      PartyMenu.drawIcon = function(game, mon, x, y, selected, counter, forceAlt)
        local icons = game and game.data and game.data.icons
        if not (icons and mon and mon.species) then
          return origDrawIcon(game, mon, x, y, selected, counter, forceAlt)
        end

        local def = game.data.pokemon and game.data.pokemon[mon.species]
        local entry = (icons.bySpecies and icons.bySpecies[mon.species])
                   or (def and def.icon)
        local name, path
        if type(entry) == "string" then
          name = entry
          path = icons.icons and icons.icons[entry]
          if type(path) == "table" then
            path = path.image
            icons.icons[entry] = path
          end
        elseif type(entry) == "table" then
          path = entry.image
        end
        if not path then
          name = def and def.dex and icons.byDex and icons.byDex[def.dex]
          path = name and icons.icons and icons.icons[name]
          if type(path) == "table" then path = path.image end
        end

        local Sprites = require("src.pokemon.Sprites")
        local resolvedPath = Sprites.iconPath(game.data, mon, path, { name = name })

        -- Check if resolvedPath is a custom mod icon (i.e. not the built-in monochrome icon sheet for name)
        local isBuiltIn = name and icons.icons and (resolvedPath == icons.icons[name])
        if resolvedPath and not isBuiltIn then
          local Assets = require("src.core.Assets")
          if customIconCache[resolvedPath] == nil then
            local okImg, img = pcall(love.graphics.newImage, Assets.resolve(resolvedPath))
            customIconCache[resolvedPath] = okImg and img or false
          end
          local img = customIconCache[resolvedPath]
          if img then
            local alt = forceAlt or false
            if selected then
              local px = math.floor((mon.hp or 0) * 48 / math.max(1, (mon.stats and mon.stats.hp) or 1))
              local speed = px >= 27 and 5 or px >= 10 and 16 or 32
              alt = math.floor((counter or 0) / speed) % 2 == 1
            end
            local iw, ih = img:getDimensions()
            local frame = 0
            if ih > 16 then
              frame = alt and ((ih >= 64 and 3) or 1) or 0
            end
            if ih > 16 then
              love.graphics.draw(img, love.graphics.newQuad(0, frame * 16, 16, 16, iw, ih), x, y)
            else
              love.graphics.draw(img, x, y)
            end
            return true
          end
        end

        return origDrawIcon(game, mon, x, y, selected, counter, forceAlt)
      end
      PartyMenu._krTableIconPatch = true
    end
  end

  mod.log:info("Mapped %d species onto menu icon classes", n)
  return n
end

return SpeciesIcons
