-- Gen 3 (FireRed / LeafGreen) Trainer Party Overhauls.
-- 1. Explicit hand-crafted boss overrides (Gym Leaders, E4, Rival Matrix, Giovanni).
-- 2. Programmatic thematic injection for 20+ trainer classes.
-- 3. VS Seeker rematch continuity based on base trainer ID and level-aware scaling.

local TrainersGame3 = {}

local GBA_SPECIES = {
  GEODUDE=74, ONIX=95, SUDOWOODO=185, ARON=329, LAIRON=330, AGGRON=331,
  STARYU=120, STARMIE=121, MARILL=183, AZUMARILL=184, CORPHISH=366, CRAWDAUNT=367,
  VOLTORB=100, RAICHU=26, FLAAFFY=180, AMPHAROS=181, ELECTRIKE=334, MANECTRIC=335,
  VICTREEBEL=71, VILEPLUME=45, BELLOSSOM=182, BRELOOM=311, SHROOMISH=310,
  KOFFING=109, MUK=89, WEEZING=110, CROBAT=169, SEVIPER=361,
  KADABRA=64, ALAKAZAM=65, MR_MIME=122, XATU=178, GARDEVOIR=307, RALTS=305, KIRLIA=306,
  TORKOAL=349, GROWLITHE=58, ARCANINE=59, PONYTA=77, RAPIDASH=78,
  STEELIX=208, TRAPINCH=353, VIBRAVA=354, FLYGON=355, DONPHAN=232, PHANPY=231,
  RHYHORN=111, RHYDON=112, NIDOQUEEN=31, NIDOKING=34, NIDORINO=33,
  DEWGONG=87, CLOYSTER=91, PILOSWINE=221, SLOWBRO=80, WALREIN=390, SEALEO=389, SPHEAL=388, LAPRAS=131,
  HITMONCHAN=107, HITMONLEE=106, MACHAMP=68, HARIYAMA=322, MAKUHITA=321,
  GENGAR=94, GOLBAT=42, HAUNTER=93, BANETTE=379, SHUPPET=378, ARBOK=24,
  GYARADOS=130, DRAGONAIR=148, DRAGONITE=149, AERODACTYL=142, KINGDRA=230, SALAMENCE=398, BAGON=396, SHELGON=397,
  HOUNDOUR=228, HOUNDOOM=229, POOCHYENA=286, MIGHTYENA=287, ZIGZAGOON=288, LINOONE=289,
  SENTRET=161, FURRET=162, TAILLOW=301, SWELLOW=302, WINGULL=303, PELIPPER=304,
  WURMPLE=290, SILCOON=291, BEAUTIFLY=292, CASCOON=293, DUSTOX=294,
  LOTAD=295, LOMBRE=296, LUDICOLO=297, SEEDOT=298, NUZLEAF=299, SHIFTRY=300,
  GULPIN=341, SWALOT=342, CACNEA=356, CACTURNE=357, CARVANHA=343, SHARPEDO=344,
  NUMEL=347, CAMERUPT=348, SWABLU=358, ALTARIA=359, MAREEP=179
}

local function toSpeciesId(nameOrId)
  if type(nameOrId) == "number" then return nameOrId end
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  if okP and Pokemon and Pokemon.speciesFromName then
    local id = Pokemon.speciesFromName(nameOrId)
    if id then return id end
  end
  local clean = tostring(nameOrId):upper():gsub("[%s%-]+", "_")
  return GBA_SPECIES[clean] or nameOrId
end

-- ============================================================================
-- 1. Tier 1: Explicit Boss Roster Injections
-- ============================================================================
local BOSS_OVERRIDES = {
  -- Gym Leaders
  TRAINER_LEADER_BROCK = {
    { species = "GEODUDE", level = 12 },
    { species = "SUDOWOODO", level = 12 },
    { species = "ARON", level = 13 },
    { species = "ONIX", level = 14 },
  },
  TRAINER_LEADER_MISTY = {
    { species = "STARYU", level = 18 },
    { species = "MARILL", level = 19 },
    { species = "CORPHISH", level = 20 },
    { species = "STARMIE", level = 21 },
  },
  TRAINER_LEADER_LT_SURGE = {
    { species = "VOLTORB", level = 21 },
    { species = "FLAAFFY", level = 22 },
    { species = "ELECTABUZZ", level = 23 },
    { species = "RAICHU", level = 24 },
  },
  TRAINER_LEADER_ERIKA = {
    { species = "VICTREEBEL", level = 29 },
    { species = "BELLOSSOM", level = 28 },
    { species = "BRELOOM", level = 28 },
    { species = "VILEPLUME", level = 29 },
  },
  TRAINER_LEADER_KOGA = {
    { species = "KOFFING", level = 37 },
    { species = "MUK", level = 39 },
    { species = "CROBAT", level = 41 },
    { species = "SEVIPER", level = 40 },
    { species = "WEEZING", level = 43 },
  },
  TRAINER_LEADER_SABRINA = {
    { species = "KADABRA", level = 38, moves = { "PSYBEAM", "REFLECT", "RECOVER", "DISABLE" } },
    { species = "MR_MIME", level = 37, moves = { "PSYBEAM", "SHOCK_WAVE", "REFLECT", "BATON_PASS" } },
    { species = "XATU", level = 39, moves = { "PSYBEAM", "AERIAL_ACE", "CONFUSE_RAY", "GIGA_DRAIN" } },
    { species = "GARDEVOIR", level = 41, moves = { "PSYCHIC_M", "CALM_MIND", "SHADOW_BALL", "THIEF" } },
    { species = "ALAKAZAM", level = 43, moves = { "PSYCHIC_M", "CALM_MIND", "RECOVER", "REFLECT" } },
  },
  TRAINER_LEADER_BLAINE = {
    { species = "TORKOAL", level = 40 },
    { species = "GROWLITHE", level = 42 },
    { species = "PONYTA", level = 40 },
    { species = "RAPIDASH", level = 42 },
    { species = "ARCANINE", level = 47 },
  },
  -- Giovanni
  TRAINER_BOSS_GIOVANNI = {
    { species = "ONIX", level = 25 },
    { species = "STEELIX", level = 26 },
    { species = "TRAPINCH", level = 25 },
    { species = "RHYHORN", level = 29 },
  },
  TRAINER_BOSS_GIOVANNI_2 = {
    { species = "NIDORINO", level = 37 },
    { species = "DONPHAN", level = 38 },
    { species = "VIBRAVA", level = 38 },
    { species = "NIDOQUEEN", level = 41 },
  },
  TRAINER_LEADER_GIOVANNI = {
    { species = "RHYHORN", level = 45 },
    { species = "DONPHAN", level = 46 },
    { species = "FLYGON", level = 48 },
    { species = "NIDOKING", level = 49 },
    { species = "RHYDON", level = 50 },
  },
  -- Elite Four
  TRAINER_ELITE_FOUR_LORELEI = {
    { species = "DEWGONG", level = 52 },
    { species = "CLOYSTER", level = 51 },
    { species = "PILOSWINE", level = 53 },
    { species = "SLOWBRO", level = 52 },
    { species = "WALREIN", level = 54 },
    { species = "LAPRAS", level = 54 },
  },
  TRAINER_ELITE_FOUR_BRUNO = {
    { species = "ONIX", level = 51 },
    { species = "HITMONCHAN", level = 53 },
    { species = "HITMONLEE", level = 53 },
    { species = "STEELIX", level = 54 },
    { species = "HARIYAMA", level = 55 },
    { species = "MACHAMP", level = 56 },
  },
  TRAINER_ELITE_FOUR_AGATHA = {
    { species = "GENGAR", level = 54 },
    { species = "GOLBAT", level = 54 },
    { species = "HAUNTER", level = 53 },
    { species = "CROBAT", level = 56 },
    { species = "BANETTE", level = 56 },
    { species = "GENGAR", level = 58 },
  },
  TRAINER_ELITE_FOUR_LANCE = {
    { species = "GYARADOS", level = 56 },
    { species = "DRAGONAIR", level = 54 },
    { species = "AERODACTYL", level = 58 },
    { species = "KINGDRA", level = 58 },
    { species = "SALAMENCE", level = 60 },
    { species = "DRAGONITE", level = 60 },
  },
  -- Sevii Island Bosses & Key Trainers
  TRAINER_CUE_BALL_PAXTON = {
    { species = "WEEZING", level = 39 },
    { species = "MUK", level = 39 },
    { species = "HOUNDOUR", level = 38 },
    { species = "MIGHTYENA", level = 40 },
  },
  [742] = {
    { species = "WEEZING", level = 39 },
    { species = "MUK", level = 39 },
    { species = "HOUNDOUR", level = 38 },
    { species = "MIGHTYENA", level = 40 },
  },
  TRAINER_TEAM_ROCKET_ADMIN = {
    { species = "HOUNDOOM", level = 56 },
    { species = "STEELIX", level = 55 },
    { species = "MUK", level = 55 },
    { species = "CROBAT", level = 56 },
    { species = "CRAWDAUNT", level = 57 },
  },
  [543] = {
    { species = "HOUNDOOM", level = 56 },
    { species = "STEELIX", level = 55 },
    { species = "MUK", level = 55 },
    { species = "CROBAT", level = 56 },
    { species = "CRAWDAUNT", level = 57 },
  },
  TRAINER_TEAM_ROCKET_ADMIN_2 = {
    { species = "SHARPEDO", level = 56 },
    { species = "WEEZING", level = 55 },
    { species = "HOUNDOOM", level = 56 },
    { species = "ARBOK", level = 55 },
    { species = "TYRANITAR", level = 58 },
  },
  [544] = {
    { species = "SHARPEDO", level = 56 },
    { species = "WEEZING", level = 55 },
    { species = "HOUNDOOM", level = 56 },
    { species = "ARBOK", level = 55 },
    { species = "TYRANITAR", level = 58 },
  },
}

-- ============================================================================
-- 2. Tier 2: Exhaustive 20+ Class Thematic Species Pools (Gen 1–3)
-- ============================================================================
local CLASS_POOLS = {
  ["BUG CATCHER"] = {
    "CATERPIE", "WEEDLE", "LEDYBA", "SPINARAK", "YANMA", "PINECO",
    "SHUCKLE", "HERACROSS", "WURMPLE", "SURSKIT", "NINCADA",
    "VOLBEAT", "ILLUMISE", "PARAS", "VENONAT", "SCYTHER", "PINSIR", "ANORITH"
  },
  ["BIRD KEEPER"] = {
    "PIDGEY", "SPEAROW", "FARFETCHD", "DODUO", "HOOTHOOT", "NATU",
    "MURKROW", "SKARMORY", "TAILLOW", "WINGULL", "SWABLU", "TROPIUS"
  },
  ["HIKER"] = {
    "GEODUDE", "ONIX", "MACHOP", "SUDOWOODO", "DUNSPARCE", "LARVITAR",
    "NOSEPASS", "ARON", "NUMEL", "BALTOY", "RHYHORN", "DIGLETT"
  },
  ["BLACK BELT"] = {
    "MANKEY", "MACHOP", "TYROGUE", "HERACROSS", "MAKUHITA", "MEDITITE"
  },
  ["FISHERMAN"] = {
    "MAGIKARP", "GOLDEEN", "POLIWAG", "REMORAID", "QWILFISH", "CHINCHOU",
    "CORSOLA", "CARVANHA", "BARBOACH", "CORPHISH", "FEEBAS", "RELICANTH", "LUVDISC", "KRABBY"
  },
  ["SWIMMER MALE"] = {
    "TENTACOOL", "SHELLDER", "STARYU", "HORSEA", "KRABBY", "PSYDUCK",
    "WOOPER", "MANTINE", "WINGULL", "WAILMER", "SPHEAL", "CLAMPERL", "SEEL", "LAPRAS"
  },
  ["SWIMMER FEMALE"] = {
    "TENTACOOL", "SHELLDER", "STARYU", "HORSEA", "KRABBY", "PSYDUCK",
    "WOOPER", "MANTINE", "WINGULL", "WAILMER", "SPHEAL", "CLAMPERL", "SEEL", "LAPRAS"
  },
  ["SAILOR"] = {
    "MACHOP", "TENTACOOL", "POLIWAG", "KRABBY", "WINGULL", "SPHEAL", "CORPHISH", "WAILMER"
  },
  ["YOUNGSTER"] = {
    "RATTATA", "SENTRET", "ZIGZAGOON", "POOCHYENA", "EKANS", "SPEAROW",
    "MANKEY", "DUNSPARCE", "AIPOM", "WHISMUR", "SKITTY", "TAILLOW"
  },
  ["LASS"] = {
    "PIDGEY", "JIGGLYPUFF", "CLEFAIRY", "MARILL", "SNUBBULL", "TEDDIURSA",
    "HOPPIP", "SKITTY", "PLUSLE", "MINUN", "ROSELIA", "SWABLU", "SPOINK", "SPINDA", "MAWILE"
  },
  ["CAMPER"] = {
    "SANDSHREW", "NIDORAN_M", "PHANPY", "SHROOMISH", "LOTAD", "SEEDOT",
    "ELECTRIKE", "GULPIN", "NUMEL", "ZANGOOSE", "SEVIPER", "DODUO", "PONYTA"
  },
  ["PICNICKER"] = {
    "SANDSHREW", "NIDORAN_F", "PHANPY", "SHROOMISH", "LOTAD", "SEEDOT",
    "ELECTRIKE", "GULPIN", "NUMEL", "ZANGOOSE", "SEVIPER", "DODUO", "PONYTA"
  },
  ["PSYCHIC"] = {
    "ABRA", "DROWZEE", "MR_MIME", "NATU", "ESPEON", "UNOWN",
    "WOBBUFFET", "GIRAFARIG", "RALTS", "SPOINK", "MEDITITE", "CHIMECHO", "SLOWPOKE"
  },
  ["CHANNELER"] = {
    "GASTLY", "MISDREAVUS", "DUSKULL", "SHUPPET", "SABLEYE"
  },
  ["SUPER NERD"] = {
    "MAGNEMITE", "VOLTORB", "GRIMER", "KOFFING", "PORYGON",
    "MAREEP", "BALTOY", "GULPIN", "LILEEP", "ANORITH", "CASTFORM"
  },
  ["SCIENTIST"] = {
    "MAGNEMITE", "VOLTORB", "GRIMER", "KOFFING", "PORYGON",
    "MAREEP", "BALTOY", "GULPIN", "LILEEP", "ANORITH", "CASTFORM"
  },
  ["GENTLEMAN"] = {
    "GROWLITHE", "VULPIX", "MEOWTH", "PONYTA", "HOUNDOUR", "SNUBBULL",
    "SMEARGLE", "ZIGZAGOON", "ELECTRIKE", "ROSELIA"
  },
  ["BEAUTY"] = {
    "BELLSPROUT", "ODDISH", "TANGELA", "SUNFLORA", "HOPPIP",
    "ROSELIA", "TROPIUS", "ILLUMISE", "MAWILE"
  },
  ["BIKER"] = {
    "KOFFING", "GRIMER", "EKANS", "MACHOP", "GULPIN", "CARVANHA", "POOCHYENA", "HOUNDOUR"
  },
  ["CUE BALL"] = {
    "KOFFING", "GRIMER", "EKANS", "MACHOP", "GULPIN", "CARVANHA", "POOCHYENA", "HOUNDOUR"
  },
  ["TEAM ROCKET GRUNT"] = {
    "ZUBAT", "RATTATA", "EKANS", "KOFFING", "GRIMER", "DROWZEE",
    "MACHOP", "SANDSHREW", "POOCHYENA", "HOUNDOUR", "CARVANHA", "CACNEA", "CORPHISH", "GULPIN"
  },
  ["COOLTRAINER MALE"] = {
    "ARCANINE", "NINETALES", "NIDOKING", "NIDOQUEEN", "RAICHU", "GYARADOS",
    "ALAKAZAM", "MACHAMP", "GOLEM", "GENGAR", "STEELIX", "SCIZOR", "HERACROSS",
    "HOUNDOOM", "KINGDRA", "TYRANITAR", "SWELLOW", "GARDEVOIR", "BRELOOM", "HARIYAMA",
    "AGGRON", "MANECTRIC", "FLYGON", "ALTARIA", "CRAWDAUNT", "MILOTIC", "ABSOL",
    "WALREIN", "SALAMENCE", "METAGROSS"
  },
  ["COOLTRAINER FEMALE"] = {
    "ARCANINE", "NINETALES", "NIDOKING", "NIDOQUEEN", "RAICHU", "GYARADOS",
    "ALAKAZAM", "MACHAMP", "GOLEM", "GENGAR", "STEELIX", "SCIZOR", "HERACROSS",
    "HOUNDOOM", "KINGDRA", "TYRANITAR", "SWELLOW", "GARDEVOIR", "BRELOOM", "HARIYAMA",
    "AGGRON", "MANECTRIC", "FLYGON", "ALTARIA", "CRAWDAUNT", "MILOTIC", "ABSOL",
    "WALREIN", "SALAMENCE", "METAGROSS"
  },
  ["JUGGLER"] = {
    "VOLTORB", "DROWZEE", "MR_MIME", "AIPOM", "SPOINK", "SPINDA", "CHIMECHO", "WOBBUFFET", "LICKITUNG"
  },
  ["RUIN MANIAC"] = {
    "GEODUDE", "ONIX", "CUBONE", "NOSEPASS", "BALTOY", "TRAPINCH", "LILEEP", "ANORITH"
  },
  ["TWINS"] = {
    "PLUSLE", "MINUN", "VOLBEAT", "ILLUMISE", "LUNATONE", "SOLROCK", "ZANGOOSE", "SEVIPER", "MEDITITE", "MAKUHITA"
  }
}

-- Evolution progression tables for level-aware scaling
local EVO_LINES = {
  POOCHYENA = { base = "POOCHYENA", final = "MIGHTYENA", lvl = 18 },
  ZIGZAGOON = { base = "ZIGZAGOON", final = "LINOONE", lvl = 20 },
  SENTRET   = { base = "SENTRET", final = "FURRET", lvl = 15 },
  TAILLOW   = { base = "TAILLOW", final = "SWELLOW", lvl = 22 },
  WINGULL   = { base = "WINGULL", final = "PELIPPER", lvl = 25 },
  MAREEP    = { base = "MAREEP", mid = "FLAAFFY", final = "AMPHAROS", midLvl = 15, lvl = 30 },
  ARON      = { base = "ARON", mid = "LAIRON", final = "AGGRON", midLvl = 32, lvl = 42 },
  ELECTRIKE = { base = "ELECTRIKE", final = "MANECTRIC", lvl = 26 },
  NUMEL     = { base = "NUMEL", final = "CAMERUPT", lvl = 33 },
  SPHEAL    = { base = "SPHEAL", mid = "SEALEO", final = "WALREIN", midLvl = 32, lvl = 44 },
  CARVANHA  = { base = "CARVANHA", final = "SHARPEDO", lvl = 30 },
  CORPHISH  = { base = "CORPHISH", final = "CRAWDAUNT", lvl = 30 },
  TRAPINCH  = { base = "TRAPINCH", mid = "VIBRAVA", final = "FLYGON", midLvl = 35, lvl = 45 },
  SWABLU    = { base = "SWABLU", final = "ALTARIA", lvl = 35 },
  SHROOMISH = { base = "SHROOMISH", final = "BRELOOM", lvl = 23 },
  GULPIN    = { base = "GULPIN", final = "SWALOT", lvl = 26 },
  CACNEA    = { base = "CACNEA", final = "CACTURNE", lvl = 32 },
  HOUNDOUR  = { base = "HOUNDOUR", final = "HOUNDOOM", lvl = 24 },
  SUDOWOODO = { base = "SUDOWOODO", final = "SUDOWOODO", lvl = 99 },
}

local function resolveScaledSpecies(baseKey, level, baseId)
  local line = EVO_LINES[baseKey]
  if not line then
    -- Handle branching lines
    if baseKey == "WURMPLE" then
      local isBranchA = (baseId % 2 == 0)
      if level < 7 then return "WURMPLE"
      elseif level < 10 then return isBranchA and "SILCOON" or "CASCOON"
      else return isBranchA and "BEAUTIFLY" or "DUSTOX" end
    elseif baseKey == "LOTAD" then
      if level < 14 then return "LOTAD"
      elseif level < 25 then return "LOMBRE"
      else return "LUDICOLO" end
    elseif baseKey == "SEEDOT" then
      if level < 14 then return "SEEDOT"
      elseif level < 25 then return "NUZLEAF"
      else return "SHIFTRY" end
    elseif baseKey == "RALTS" then
      if level < 20 then return "RALTS"
      elseif level < 30 then return "KIRLIA"
      else return "GARDEVOIR" end
    end
    return baseKey
  end

  if line.mid and line.midLvl and level >= line.midLvl and level < line.lvl then
    return line.mid
  elseif level >= line.lvl then
    return line.final
  end
  return line.base
end

-- ============================================================================
-- 3. Rival Matrix Injection Helper
-- ============================================================================
local function isRivalTrainer(name, scriptKey)
  local str = (tostring(name) .. " " .. tostring(scriptKey)):upper()
  return str:find("RIVAL") ~= nil or str:find("CHAMPION") ~= nil
end

local function applyRivalContinuity(party, levelBand, baseId)
  if not party or #party == 0 then return party end
  local out = {}
  for i, m in ipairs(party) do
    out[i] = {
      species = m.species,
      level = m.level,
      iv = m.iv,
      heldItem = m.heldItem
    }
  end

  local avgLvl = 0
  local top = 0
  for _, m in ipairs(out) do
    local lv = m.level or 10
    avgLvl = avgLvl + lv
    if lv > top then top = lv end
  end
  avgLvl = math.floor(avgLvl / #out)

  -- Oak's lab is one level-5 starter. The extra partner starts on the
  -- later rival fights, which already have more than that single mon.
  if #out == 1 and top <= 5 then return out end

  -- Add Houndour/Houndoom or Aron line depending on starter / slot
  local isHoundourPath = (baseId % 2 == 0)
  local injected = isHoundourPath
    and resolveScaledSpecies("HOUNDOUR", avgLvl, baseId)
    or resolveScaledSpecies("ARON", avgLvl, baseId)

  if #out < 6 then
    out[#out + 1] = {
      species = toSpeciesId(injected),
      level = math.max(1, avgLvl - 1)
    }
  else
    -- Replace 2nd slot
    out[2].species = toSpeciesId(injected)
  end

  return out
end

-- ============================================================================
-- 4. Installation & Hook Wiring
-- ============================================================================
local installed = false

function TrainersGame3.install(mod)
  if installed then return end
  installed = true

  local okT, Trainers = pcall(require, "src.core.game3.scripting.trainers")
  if not (okT and Trainers and Trainers.get) then return end

  local origGet = Trainers.get
  local okV, VsSeekerData = pcall(require, "src.core.game3.vs_seeker_data")

  Trainers.get = function(trainerId)
    local t = origGet(trainerId)
    if not t or not t.party or #t.party == 0 then return t end

    local nameUpper = tostring(t.name or ""):upper()
    local clsUpper = tostring(t.className or ""):upper()
    local scriptUpper = tostring(t.scriptKey or ""):upper()

    -- Check Tier 1: Boss Overrides
    local override = BOSS_OVERRIDES[scriptUpper] or BOSS_OVERRIDES[t.scriptKey]
    if not override then
      if nameUpper == "BROCK" or scriptUpper:find("BROCK") then
        override = BOSS_OVERRIDES.TRAINER_LEADER_BROCK
      elseif nameUpper == "MISTY" or scriptUpper:find("MISTY") then
        override = BOSS_OVERRIDES.TRAINER_LEADER_MISTY
      elseif nameUpper:find("SURGE") or scriptUpper:find("SURGE") then
        override = BOSS_OVERRIDES.TRAINER_LEADER_LT_SURGE
      elseif nameUpper == "ERIKA" or scriptUpper:find("ERIKA") then
        override = BOSS_OVERRIDES.TRAINER_LEADER_ERIKA
      elseif nameUpper == "KOGA" or scriptUpper:find("KOGA") then
        override = BOSS_OVERRIDES.TRAINER_LEADER_KOGA
      elseif nameUpper == "SABRINA" or scriptUpper:find("SABRINA") then
        override = BOSS_OVERRIDES.TRAINER_LEADER_SABRINA
      elseif nameUpper == "BLAINE" or scriptUpper:find("BLAINE") then
        override = BOSS_OVERRIDES.TRAINER_LEADER_BLAINE
      elseif nameUpper == "GIOVANNI" or scriptUpper:find("GIOVANNI") then
        local avgLvl = t.lastLevel or (t.party[1] and t.party[1].level) or 25
        if avgLvl <= 30 or scriptUpper:find("GIOVANNI_1") or scriptUpper == "TRAINER_BOSS_GIOVANNI" then
          override = BOSS_OVERRIDES.TRAINER_BOSS_GIOVANNI
        elseif avgLvl <= 42 or scriptUpper:find("GIOVANNI_2") or scriptUpper == "TRAINER_BOSS_GIOVANNI_2" then
          override = BOSS_OVERRIDES.TRAINER_BOSS_GIOVANNI_2
        else
          override = BOSS_OVERRIDES.TRAINER_LEADER_GIOVANNI
        end
      elseif nameUpper == "LORELEI" or scriptUpper:find("LORELEI") then
        override = BOSS_OVERRIDES.TRAINER_ELITE_FOUR_LORELEI
      elseif nameUpper == "BRUNO" or scriptUpper:find("BRUNO") then
        override = BOSS_OVERRIDES.TRAINER_ELITE_FOUR_BRUNO
      elseif nameUpper == "AGATHA" or scriptUpper:find("AGATHA") then
        override = BOSS_OVERRIDES.TRAINER_ELITE_FOUR_AGATHA
      elseif nameUpper == "LANCE" or scriptUpper:find("LANCE") then
        override = BOSS_OVERRIDES.TRAINER_ELITE_FOUR_LANCE
      end
    end

    if override then
      local newParty = {}
      for i, m in ipairs(override) do
        newParty[i] = {
          species = toSpeciesId(m.species),
          level = m.level or 15,
          iv = 31,
          heldItem = m.heldItem or 0,
          moves = m.moves,
        }
      end
      t.party = newParty
      t.partySize = #newParty
      return t
    end

    -- Check Rival Matrix
    local isRival = (t.class == 81 or t.class == 89 or t.class == 90
      or clsUpper:find("RIVAL") or clsUpper:find("CHAMPION")
      or scriptUpper:find("RIVAL") or scriptUpper:find("CHAMPION")
      or isRivalTrainer(t.name, t.scriptKey))

    if isRival then
      t.party = applyRivalContinuity(t.party, t.lastLevel or 20, t.id or 1)
      t.partySize = #t.party
      return t
    end

    -- Tier 2: Programmatic Route Trainer Injection
    local pool = CLASS_POOLS[clsUpper]
    if not pool then
      if clsUpper:find("BUG") then pool = CLASS_POOLS["BUG CATCHER"]
      elseif clsUpper:find("BIRD") then pool = CLASS_POOLS["BIRD KEEPER"]
      elseif clsUpper:find("HIKER") then pool = CLASS_POOLS["HIKER"]
      elseif clsUpper:find("BLACK") or clsUpper:find("BELT") or clsUpper:find("CRUSH") or clsUpper:find("FIGHT") or clsUpper:find("BATTLE GIRL") then pool = CLASS_POOLS["BLACK BELT"]
      elseif clsUpper:find("FISH") then pool = CLASS_POOLS["FISHERMAN"]
      elseif clsUpper:find("SWIM") or clsUpper:find("SAILOR") or clsUpper:find("TUBER") then pool = CLASS_POOLS["SWIMMER MALE"]
      elseif clsUpper:find("YOUNGSTER") then pool = CLASS_POOLS["YOUNGSTER"]
      elseif clsUpper:find("LASS") then pool = CLASS_POOLS["LASS"]
      elseif clsUpper:find("CAMP") then pool = CLASS_POOLS["CAMPER"]
      elseif clsUpper:find("PICNIC") then pool = CLASS_POOLS["PICNICKER"]
      elseif clsUpper:find("PSYCHIC") then pool = CLASS_POOLS["PSYCHIC"]
      elseif clsUpper:find("CHANNEL") or clsUpper:find("HEX") then pool = CLASS_POOLS["CHANNELER"]
      elseif clsUpper:find("NERD") or clsUpper:find("SCIENTIST") or clsUpper:find("BURGLAR") or clsUpper:find("ENGINEER") then pool = CLASS_POOLS["SUPER NERD"]
      elseif clsUpper:find("GENTLE") or clsUpper:find("LADY") or clsUpper:find("RICH") then pool = CLASS_POOLS["GENTLEMAN"]
      elseif clsUpper:find("BEAUTY") or clsUpper:find("AROMA") then pool = CLASS_POOLS["BEAUTY"]
      elseif clsUpper:find("BIKER") or clsUpper:find("CUE") then pool = CLASS_POOLS["BIKER"]
      elseif clsUpper:find("ROCKET") or clsUpper:find("GRUNT") then pool = CLASS_POOLS["TEAM ROCKET GRUNT"]
      elseif clsUpper:find("COOL") or clsUpper:find("ACE") then pool = CLASS_POOLS["COOLTRAINER MALE"]
      elseif clsUpper:find("JUGGL") or clsUpper:find("TAMER") then pool = CLASS_POOLS["JUGGLER"]
      elseif clsUpper:find("RUIN") or clsUpper:find("MANIAC") then pool = CLASS_POOLS["RUIN MANIAC"]
      elseif clsUpper:find("TWIN") or clsUpper:find("SIS") then pool = CLASS_POOLS["TWINS"]
      end
    end

    if pool and #pool > 0 then
      local baseId = trainerId
      if okV and VsSeekerData and VsSeekerData.byAny then
        local rowIdx = VsSeekerData.byAny[trainerId]
        if rowIdx and VsSeekerData.REMATCHES and VsSeekerData.REMATCHES[rowIdx] then
          baseId = VsSeekerData.REMATCHES[rowIdx][1] or trainerId
        end
      end

      local hash = (baseId * 1103515245 + 12345) % 0x7FFFFFFF
      local chosenBase = pool[(hash % #pool) + 1]
      local avgLvl = t.lastLevel or (t.party[1] and t.party[1].level) or 10
      local scaled = resolveScaledSpecies(chosenBase, avgLvl, baseId)
      local scaledId = toSpeciesId(scaled)

      if scaledId then
        local newParty = {}
        for i, m in ipairs(t.party) do
          newParty[i] = {
            species = m.species,
            level = m.level,
            iv = m.iv,
            heldItem = m.heldItem
          }
        end

        if #newParty < 4 then
          newParty[#newParty + 1] = {
            species = scaledId,
            level = avgLvl
          }
        else
          -- Swap 2nd slot
          newParty[2].species = scaledId
        end

        t.party = newParty
        t.partySize = #newParty
      end
    end

    return t
  end

  if mod and mod.log then
    mod.log:info("Gen 3 expanded trainer rosters & VS Seeker continuity installed")
  end
end

return TrainersGame3
