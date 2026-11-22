-- Gen 3 (FireRed / LeafGreen) Wild Encounter Generator & Spawn Randomizer.
-- Strict GBA slot bounds:
--   Grass: 12 slots [20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1]% (Total 100)
--   Water: 5 slots [60, 30, 5, 4, 1]% (Total 100)
--   Old Rod: 2 slots [70, 30]%
--   Good Rod: 3 slots [60, 20, 20]%
--   Super Rod: 5 slots [40, 40, 15, 4, 1]%
--   Rock Smash: 5 slots [60, 30, 5, 4, 1]%

local Host = require("mods.Kanto-Reforged.core.host")
local Rng = require("src.core.game3.rng")

local EncountersGame3 = {}

local ITEM_SUN_STONE = 93
local ITEM_MOON_STONE = 94

-- ============================================================================
-- Complete GBA Species ID Lookup (1..411)
-- ============================================================================
local GBA_SPECIES = {
  -- Gen 1 (1..151)
  BULBASAUR=1, IVYSAUR=2, VENUSAUR=3, CHARMANDER=4, CHARMELEON=5, CHARIZARD=6,
  SQUIRTLE=7, WARTORTLE=8, BLASTOISE=9, CATERPIE=10, METAPOD=11, BUTTERFREE=12,
  WEEDLE=13, KAKUNA=14, BEEDRILL=15, PIDGEY=16, PIDGEOTTO=17, PIDGEOT=18,
  RATTATA=19, RATICATE=20, SPEAROW=21, FEAROW=22, EKANS=23, ARBOK=24,
  PIKACHU=25, RAICHU=26, SANDSHREW=27, SANDSLASH=28, NIDORAN_F=29, NIDORINA=30,
  NIDOQUEEN=31, NIDORAN_M=32, NIDORINO=33, NIDOKING=34, CLEFAIRY=35, CLEFABLE=36,
  VULPIX=37, NINETALES=38, JIGGLYPUFF=39, WIGGLYTUFF=40, ZUBAT=41, GOLBAT=42,
  ODDISH=43, GLOOM=44, VILEPLUME=45, PARAS=46, PARASECT=47, VENONAT=48,
  VENOMOTH=49, DIGLETT=50, DUGTRIO=51, MEOWTH=52, PERSIAN=53, PSYDUCK=54,
  GOLDUCK=55, MANKEY=56, PRIMEAPE=57, GROWLITHE=58, ARCANINE=59, POLIWAG=60,
  POLIWHIRL=61, POLIWRATH=62, ABRA=63, KADABRA=64, ALAKAZAM=65, MACHOP=66,
  MACHOKE=67, MACHAMP=68, BELLSPROUT=69, WEEPINBELL=70, VICTREEBEL=71, TENTACOOL=72,
  TENTACRUEL=73, GEODUDE=74, GRAVELER=75, GOLEM=76, PONYTA=77, RAPIDASH=78,
  SLOWPOKE=79, SLOWBRO=80, MAGNEMITE=81, MAGNETON=82, FARFETCHD=83, DODUO=84,
  DODRIO=85, SEEL=86, DEWGONG=87, GRIMER=88, MUK=89, SHELLDER=90,
  CLOYSTER=91, GASTLY=92, HAUNTER=93, GENGAR=94, ONIX=95, DROWZEE=96,
  HYPNO=97, KRABBY=98, KINGLER=99, VOLTORB=100, ELECTRODE=101, EXEGGCUTE=102,
  EXEGGUTOR=103, CUBONE=104, MAROWAK=105, HITMONLEE=106, HITMONCHAN=107, LICKITUNG=108,
  KOFFING=109, WEEZING=110, RHYHORN=111, RHYDON=112, CHANSEY=113, TANGELA=114,
  KANGASKHAN=115, HORSEA=116, SEADRA=117, GOLDEEN=118, SEAKING=119, STARYU=120,
  STARMIE=121, MR_MIME=122, SCYTHER=123, JYNX=124, ELECTABUZZ=125, MAGMAR=126,
  PINSIR=127, TAUROS=128, MAGIKARP=129, GYARADOS=130, LAPRAS=131, DITTO=132,
  EEVEE=133, VAPOREON=134, JOLTEON=135, FLAREON=136, PORYGON=137, OMANYTE=138,
  OMASTAR=139, KABUTO=140, KABUTOPS=141, AERODACTYL=142, SNORLAX=143, ARTICUNO=144,
  ZAPDOS=145, MOLTRES=146, DRATINI=147, DRAGONAIR=148, DRAGONITE=149, MEWTWO=150, MEW=151,

  -- Gen 2 (152..251)
  CHIKORITA=152, BAYLEEF=153, MEGANIUM=154, CYNDAQUIL=155, QUILAVA=156, TYPHLOSION=157,
  TOTODILE=158, CROCONAW=159, FERALIGATR=160, SENTRET=161, FURRET=162, HOOTHOOT=163,
  NOCTOWL=164, LEDYBA=165, LEDIAN=166, SPINARAK=167, ARIADOS=168, CROBAT=169,
  CHINCHOU=170, LANTURN=171, PICHU=172, CLEFFA=173, IGGLYBUFF=174, TOGEPI=175,
  TOGETIC=176, NATU=177, XATU=178, MAREEP=179, FLAAFFY=180, AMPHAROS=181,
  BELLOSSOM=182, MARILL=183, AZUMARILL=184, SUDOWOODO=185, POLITOED=186, HOPPIP=187,
  SKIPLOOM=188, JUMPLUFF=189, AIPOM=190, SUNKERN=191, SUNFLORA=192, YANMA=193,
  WOOPER=194, QUAGSIRE=195, ESPEON=196, UMBREON=197, MURKROW=198, SLOWKING=199,
  MISDREAVUS=200, UNOWN=201, WOBBUFFET=202, GIRAFARIG=203, PINECO=204, FORRETRESS=205,
  DUNSPARCE=206, GLIGAR=207, STEELIX=208, SNUBBULL=209, GRANBULL=210, QWILFISH=211,
  SCIZOR=212, SHUCKLE=213, HERACROSS=214, SNEASEL=215, TEDDIURSA=216, URSARING=217,
  SLUGMA=218, MAGCARGO=219, SWINUB=220, PILOSWINE=221, CORSOLA=222, REMORAID=223,
  OCTILLERY=224, DELIBIRD=225, MANTINE=226, SKARMORY=227, HOUNDOUR=228, HOUNDOOM=229,
  KINGDRA=230, PHANPY=231, DONPHAN=232, PORYGON2=233, STANTLER=234, SMEARGLE=235,
  TYROGUE=236, HITMONTOP=237, SMOOCHUM=238, ELEKID=239, MAGBY=240, MILTANK=241,
  BLISSEY=242, RAIKOU=243, ENTEI=244, SUICUNE=245, LARVITAR=246, PUPITAR=247,
  TYRANITAR=248, LUGIA=249, HO_OH=250, CELEBI=251,

  -- Gen 3 (277..411)
  TREECKO=277, GROVYLE=278, SCEPTILE=279, TORCHIC=280, COMBUSKEN=281, BLAZIKEN=282,
  MUDKIP=283, MARSHTOMP=284, SWAMPERT=285, POOCHYENA=286, MIGHTYENA=287, ZIGZAGOON=288,
  LINOONE=289, WURMPLE=290, SILCOON=291, BEAUTIFLY=292, CASCOON=293, DUSTOX=294,
  LOTAD=295, LOMBRE=296, LUDICOLO=297, SEEDOT=298, NUZLEAF=299, SHIFTRY=300,
  TAILLOW=301, SWELLOW=302, WINGULL=303, PELIPPER=304, RALTS=305, KIRLIA=306,
  GARDEVOIR=307, SURSKIT=308, MASQUERAIN=309, SHROOMISH=310, BRELOOM=311, SLAKOTH=312,
  VIGOROTH=313, SLAKING=314, NINCADA=315, NINJASK=316, SHEDINJA=317, WHISMUR=318,
  LOUDRED=319, EXPLOUD=320, MAKUHITA=321, HARIYAMA=322, AZURILL=323, NOSEPASS=324,
  SKITTY=325, DELCATTY=326, SABLEYE=327, MAWILE=328, ARON=329, LAIRON=330,
  AGGRON=331, MEDITITE=332, MEDICHAM=333, ELECTRIKE=334, MANECTRIC=335, PLUSLE=336,
  MINUN=337, VOLBEAT=338, ILLUMISE=339, ROSELIA=340, GULPIN=341, SWALOT=342,
  CARVANHA=343, SHARPEDO=344, WAILMER=345, WAILORD=346, NUMEL=347, CAMERUPT=348,
  TORKOAL=349, SPOINK=350, GRUMPIG=351, SPINDA=352, TRAPINCH=353, VIBRAVA=354,
  FLYGON=355, CACNEA=356, CACTURNE=357, SWABLU=358, ALTARIA=359, ZANGOOSE=360,
  SEVIPER=361, LUNATONE=362, SOLROCK=363, BARBOACH=364, WHISCASH=365, CORPHISH=366,
  CRAWDAUNT=367, BALTOY=368, CLAYDOL=369, LILEEP=370, CRADILY=371, ANORITH=372,
  ARMALDO=373, FEEBAS=374, MILOTIC=375, CASTFORM=376, KECLEON=377, SHUPPET=378,
  BANETTE=379, DUSKULL=380, DUSCLOPS=381, TROPIUS=382, CHIMECHO=383, ABSOL=384,
  WYNAUT=385, SNORUNT=386, GLALIE=387, SPHEAL=388, SEALEO=389, WALREIN=390,
  CLAMPERL=391, HUNTAIL=392, GOREBYSS=393, RELICANTH=394, LUVDISC=395, BAGON=396,
  SHELGON=397, SALAMENCE=398, BELDUM=399, METANG=400, METAGROSS=401, REGIROCK=402,
  REGICE=403, REGISTEEL=404, LATIAS=405, LATIOS=406, KYOGRE=407, GROUDON=408,
  RAYQUAZA=409, JIRACHI=410, DEOXYS=411
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

local GBA_SPECIES_NAMES = {}
for name, id in pairs(GBA_SPECIES) do
  GBA_SPECIES_NAMES[id] = name
end

local function toSpeciesName(nameOrId)
  if type(nameOrId) == "string" and not tonumber(nameOrId) then return nameOrId end
  local id = tonumber(nameOrId)
  if not id then return tostring(nameOrId) end
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  if okP and Pokemon and Pokemon.name then
    local okN, n = pcall(Pokemon.name, id)
    if okN and n and n ~= "?????" then return n end
  end
  return GBA_SPECIES_NAMES[id] or tostring(id)
end

local NON_LEGENDARY_POOL = nil
local LEGENDARY_POOL = nil

local function getNonLegendaryPool()
  if NON_LEGENDARY_POOL then return NON_LEGENDARY_POOL end
  local list = {}
  local isLegend = {
    [144] = true, [145] = true, [146] = true, [150] = true, [151] = true,
    [243] = true, [244] = true, [245] = true, [249] = true, [250] = true, [251] = true,
    [402] = true, [403] = true, [404] = true, [405] = true, [406] = true,
    [407] = true, [408] = true, [409] = true, [410] = true, [411] = true
  }
  for id = 1, 411 do
    if (id <= 251 or id >= 277) and not isLegend[id] then
      list[#list + 1] = id
    end
  end
  NON_LEGENDARY_POOL = list
  return list
end

local function getLegendaryPool()
  if LEGENDARY_POOL then return LEGENDARY_POOL end
  LEGENDARY_POOL = {
    144, 145, 146, 150, 151,
    243, 244, 245, 249, 250, 251,
    402, 403, 404, 405, 406, 407, 408, 409, 410, 411
  }
  return LEGENDARY_POOL
end

local MIXED_POOL = nil

-- LEGENDS IN MIX adds legendaries to the full/pure pool. It does not
-- replace the wild tables with a legendary-only set.
local function poolFor(opts)
  opts = opts or {}
  if not (opts.legends or opts.legendsInMix) then
    return getNonLegendaryPool()
  end
  if MIXED_POOL then return MIXED_POOL end
  local pool = {}
  for _, id in ipairs(getNonLegendaryPool()) do pool[#pool + 1] = id end
  for _, id in ipairs(getLegendaryPool()) do pool[#pool + 1] = id end
  MIXED_POOL = pool
  return pool
end

-- ============================================================================
-- Map Encounter Definitions (Mainland Kanto + Sevii 1–7)
-- ============================================================================
local MAP_TABLES = {
  ROUTE1 = {
    aliases = { "3:19", "3_19", "Route1", "FR_ROUTE_1" },
    dexArea = "DEX_AREA_ROUTE_1",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 2, maxLevel = 4, species = "PIDGEY" },
        { minLevel = 2, maxLevel = 4, species = "RATTATA" },
        { minLevel = 2, maxLevel = 4, species = "PIDGEY" },
        { minLevel = 2, maxLevel = 4, species = "RATTATA" },
        { minLevel = 2, maxLevel = 4, species = "SENTRET" },
        { minLevel = 2, maxLevel = 4, species = "SENTRET" },
        { minLevel = 2, maxLevel = 4, species = "SENTRET" },
        { minLevel = 2, maxLevel = 4, species = "SENTRET" },
        { minLevel = 2, maxLevel = 4, species = "POOCHYENA" },
        { minLevel = 2, maxLevel = 4, species = "POOCHYENA" },
        { minLevel = 2, maxLevel = 4, species = "POOCHYENA" },
        { minLevel = 2, maxLevel = 4, species = "POOCHYENA" },
      }
    },
  },
  ROUTE2 = {
    aliases = { "3:20", "3_20", "Route2", "FR_ROUTE_2" },
    dexArea = "DEX_AREA_ROUTE_2",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 3, maxLevel = 5, species = "PIDGEY" },
        { minLevel = 3, maxLevel = 5, species = "RATTATA" },
        { minLevel = 3, maxLevel = 5, species = "PIDGEY" },
        { minLevel = 3, maxLevel = 5, species = "RATTATA" },
        { minLevel = 3, maxLevel = 5, species = "CATERPIE" },
        { minLevel = 3, maxLevel = 5, species = "WEEDLE" },
        { minLevel = 3, maxLevel = 5, species = "CATERPIE" },
        { minLevel = 3, maxLevel = 5, species = "WEEDLE" },
        { minLevel = 3, maxLevel = 5, species = "TAILLOW" },
        { minLevel = 3, maxLevel = 5, species = "TAILLOW" },
        { minLevel = 3, maxLevel = 5, species = "TAILLOW" },
        { minLevel = 3, maxLevel = 5, species = "TAILLOW" },
      }
    },
  },
  VIRIDIAN_FOREST = {
    aliases = { "1:0", "1_0", "ViridianForest", "FR_VIRIDIAN_FOREST" },
    dexArea = "DEX_AREA_VIRIDIAN_FOREST",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 3, maxLevel = 6, species = "CATERPIE" },
        { minLevel = 3, maxLevel = 6, species = "WEEDLE" },
        { minLevel = 3, maxLevel = 6, species = "CATERPIE" },
        { minLevel = 3, maxLevel = 6, species = "WEEDLE" },
        { minLevel = 3, maxLevel = 6, species = "METAPOD" },
        { minLevel = 3, maxLevel = 6, species = "KAKUNA" },
        { minLevel = 3, maxLevel = 6, species = "METAPOD" },
        { minLevel = 3, maxLevel = 6, species = "KAKUNA" },
        { minLevel = 3, maxLevel = 6, species = "WURMPLE" },
        { minLevel = 3, maxLevel = 6, species = "WURMPLE" },
        { minLevel = 3, maxLevel = 5, species = "PIKACHU" },
        { minLevel = 5, maxLevel = 5, species = "BULBASAUR" },
      }
    },
  },
  ROUTE3 = {
    aliases = { "3:21", "3_21", "Route3", "FR_ROUTE_3" },
    dexArea = "DEX_AREA_ROUTE_3",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 6, maxLevel = 9, species = "SPEAROW" },
        { minLevel = 6, maxLevel = 9, species = "PIDGEY" },
        { minLevel = 6, maxLevel = 9, species = "SPEAROW" },
        { minLevel = 6, maxLevel = 9, species = "PIDGEY" },
        { minLevel = 6, maxLevel = 9, species = "NIDORAN_F" },
        { minLevel = 6, maxLevel = 9, species = "NIDORAN_M" },
        { minLevel = 6, maxLevel = 9, species = "NIDORAN_F" },
        { minLevel = 6, maxLevel = 9, species = "NIDORAN_M" },
        { minLevel = 6, maxLevel = 9, species = "JIGGLYPUFF" },
        { minLevel = 6, maxLevel = 9, species = "JIGGLYPUFF" },
        { minLevel = 6, maxLevel = 9, species = "MANKEY" },
        { minLevel = 6, maxLevel = 9, species = "MANKEY" },
      }
    },
  },
  MT_MOON_1F = {
    aliases = { "1:1", "1_1", "MtMoon_1F", "FR_MT_MOON_1F" },
    dexArea = "DEX_AREA_MT_MOON",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 7, maxLevel = 11, species = "ZUBAT" },
        { minLevel = 7, maxLevel = 11, species = "GEODUDE" },
        { minLevel = 7, maxLevel = 11, species = "ZUBAT" },
        { minLevel = 7, maxLevel = 11, species = "GEODUDE" },
        { minLevel = 7, maxLevel = 11, species = "PARAS" },
        { minLevel = 7, maxLevel = 11, species = "WHISMUR" },
        { minLevel = 7, maxLevel = 11, species = "PARAS" },
        { minLevel = 7, maxLevel = 11, species = "WHISMUR" },
        { minLevel = 7, maxLevel = 11, species = "CLEFAIRY" },
        { minLevel = 7, maxLevel = 11, species = "CLEFAIRY" },
        { minLevel = 7, maxLevel = 11, species = "CLEFAIRY" },
        { minLevel = 7, maxLevel = 11, species = "CLEFAIRY" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 15, maxLevel = 25, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 25, species = "GRAVELER" },
        { minLevel = 15, maxLevel = 25, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 25, species = "GRAVELER" },
        { minLevel = 15, maxLevel = 25, species = "SHUCKLE" },
      }
    },
  },
  MT_MOON_B1F = {
    aliases = { "1:2", "1_2", "MtMoon_B1F", "FR_MT_MOON_B1F" },
    dexArea = "DEX_AREA_MT_MOON",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 8, maxLevel = 12, species = "ZUBAT" },
        { minLevel = 8, maxLevel = 12, species = "GEODUDE" },
        { minLevel = 8, maxLevel = 12, species = "ZUBAT" },
        { minLevel = 8, maxLevel = 12, species = "GEODUDE" },
        { minLevel = 8, maxLevel = 12, species = "PARAS" },
        { minLevel = 8, maxLevel = 12, species = "WHISMUR" },
        { minLevel = 8, maxLevel = 12, species = "PARAS" },
        { minLevel = 8, maxLevel = 12, species = "WHISMUR" },
        { minLevel = 8, maxLevel = 12, species = "LUNATONE" },
        { minLevel = 8, maxLevel = 12, species = "LUNATONE" },
        { minLevel = 8, maxLevel = 12, species = "LUNATONE" },
        { minLevel = 8, maxLevel = 12, species = "LUNATONE" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 15, maxLevel = 25, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 25, species = "GRAVELER" },
        { minLevel = 15, maxLevel = 25, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 25, species = "GRAVELER" },
        { minLevel = 15, maxLevel = 25, species = "SHUCKLE" },
      }
    },
  },
  MT_MOON_B2F = {
    aliases = { "1:3", "1_3", "MtMoon_B2F", "FR_MT_MOON_B2F" },
    dexArea = "DEX_AREA_MT_MOON",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 9, maxLevel = 13, species = "ZUBAT" },
        { minLevel = 9, maxLevel = 13, species = "GEODUDE" },
        { minLevel = 9, maxLevel = 13, species = "ZUBAT" },
        { minLevel = 9, maxLevel = 13, species = "GEODUDE" },
        { minLevel = 9, maxLevel = 13, species = "PARAS" },
        { minLevel = 9, maxLevel = 13, species = "CLEFAIRY" },
        { minLevel = 9, maxLevel = 13, species = "PARAS" },
        { minLevel = 9, maxLevel = 13, species = "CLEFAIRY" },
        { minLevel = 9, maxLevel = 13, species = "SOLROCK" },
        { minLevel = 9, maxLevel = 13, species = "SOLROCK" },
        { minLevel = 9, maxLevel = 13, species = "SOLROCK" },
        { minLevel = 9, maxLevel = 13, species = "SOLROCK" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 15, maxLevel = 25, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 25, species = "GRAVELER" },
        { minLevel = 15, maxLevel = 25, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 25, species = "GRAVELER" },
        { minLevel = 15, maxLevel = 25, species = "SHUCKLE" },
      }
    },
  },
  ROUTE4 = {
    aliases = { "3:22", "3_22", "Route4", "FR_ROUTE_4" },
    dexArea = "DEX_AREA_ROUTE_4",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 8, maxLevel = 12, species = "RATTATA" },
        { minLevel = 8, maxLevel = 12, species = "SPEAROW" },
        { minLevel = 8, maxLevel = 12, species = "RATTATA" },
        { minLevel = 8, maxLevel = 12, species = "SPEAROW" },
        { minLevel = 8, maxLevel = 12, species = "EKANS" },
        { minLevel = 8, maxLevel = 12, species = "SANDSHREW" },
        { minLevel = 8, maxLevel = 12, species = "EKANS" },
        { minLevel = 8, maxLevel = 12, species = "SANDSHREW" },
        { minLevel = 8, maxLevel = 12, species = "POOCHYENA" },
        { minLevel = 8, maxLevel = 12, species = "POOCHYENA" },
        { minLevel = 8, maxLevel = 10, species = "CHARMANDER" },
        { minLevel = 10, maxLevel = 10, species = "CHARMANDER" },
      }
    },
  },
  ROUTE5 = {
    aliases = { "3:23", "3_23", "Route5", "FR_ROUTE_5" },
    dexArea = "DEX_AREA_ROUTE_5",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 10, maxLevel = 14, species = "PIDGEY" },
        { minLevel = 10, maxLevel = 14, species = "MEOWTH" },
        { minLevel = 10, maxLevel = 14, species = "PIDGEY" },
        { minLevel = 10, maxLevel = 14, species = "MEOWTH" },
        { minLevel = 10, maxLevel = 14, species = "ODDISH", heldItem = 93 },
        { minLevel = 10, maxLevel = 14, species = "BELLSPROUT" },
        { minLevel = 10, maxLevel = 14, species = "ODDISH", heldItem = 93 },
        { minLevel = 10, maxLevel = 14, species = "BELLSPROUT" },
        { minLevel = 10, maxLevel = 14, species = "SKITTY" },
        { minLevel = 10, maxLevel = 14, species = "SKITTY" },
        { minLevel = 10, maxLevel = 14, species = "ZIGZAGOON" },
        { minLevel = 10, maxLevel = 14, species = "ZIGZAGOON" },
      }
    },
  },
  ROUTE6 = {
    aliases = { "3:24", "3_24", "Route6", "FR_ROUTE_6" },
    dexArea = "DEX_AREA_ROUTE_6",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 11, maxLevel = 15, species = "PIDGEY" },
        { minLevel = 11, maxLevel = 15, species = "MEOWTH" },
        { minLevel = 11, maxLevel = 15, species = "PIDGEY" },
        { minLevel = 11, maxLevel = 15, species = "MEOWTH" },
        { minLevel = 11, maxLevel = 15, species = "ODDISH" },
        { minLevel = 11, maxLevel = 15, species = "BELLSPROUT" },
        { minLevel = 11, maxLevel = 15, species = "ODDISH" },
        { minLevel = 11, maxLevel = 15, species = "BELLSPROUT" },
        { minLevel = 11, maxLevel = 15, species = "PSYDUCK" },
        { minLevel = 11, maxLevel = 15, species = "PSYDUCK" },
        { minLevel = 11, maxLevel = 15, species = "PLUSLE" },
        { minLevel = 11, maxLevel = 15, species = "PLUSLE" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "GOLDUCK" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "SEAKING" },
        { minLevel = 20, maxLevel = 35, species = "BARBOACH" },
        { minLevel = 20, maxLevel = 35, species = "WHISCASH" },
      }
    },
  },
  ROUTE7 = {
    aliases = { "3:25", "3_25", "Route7", "FR_ROUTE_7" },
    dexArea = "DEX_AREA_ROUTE_7",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 17, maxLevel = 20, species = "PIDGEY" },
        { minLevel = 17, maxLevel = 20, species = "MEOWTH" },
        { minLevel = 17, maxLevel = 20, species = "PIDGEY" },
        { minLevel = 17, maxLevel = 20, species = "MEOWTH" },
        { minLevel = 17, maxLevel = 20, species = "GROWLITHE" },
        { minLevel = 17, maxLevel = 20, species = "VULPIX" },
        { minLevel = 17, maxLevel = 20, species = "GROWLITHE" },
        { minLevel = 17, maxLevel = 20, species = "VULPIX" },
        { minLevel = 17, maxLevel = 20, species = "HOUNDOUR" },
        { minLevel = 17, maxLevel = 20, species = "HOUNDOUR" },
        { minLevel = 17, maxLevel = 20, species = "MINUN" },
        { minLevel = 17, maxLevel = 20, species = "MINUN" },
      }
    },
  },
  ROUTE8 = {
    aliases = { "3:26", "3_26", "Route8", "FR_ROUTE_8" },
    dexArea = "DEX_AREA_ROUTE_8",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 17, maxLevel = 20, species = "PIDGEY" },
        { minLevel = 17, maxLevel = 20, species = "MEOWTH" },
        { minLevel = 17, maxLevel = 20, species = "PIDGEY" },
        { minLevel = 17, maxLevel = 20, species = "MEOWTH" },
        { minLevel = 17, maxLevel = 20, species = "EKANS" },
        { minLevel = 17, maxLevel = 20, species = "SANDSHREW" },
        { minLevel = 17, maxLevel = 20, species = "EKANS" },
        { minLevel = 17, maxLevel = 20, species = "SANDSHREW" },
        { minLevel = 17, maxLevel = 20, species = "SPOINK" },
        { minLevel = 17, maxLevel = 20, species = "SPOINK" },
        { minLevel = 17, maxLevel = 20, species = "KADABRA" },
        { minLevel = 17, maxLevel = 20, species = "KADABRA" },
      }
    },
  },
  ROUTE9 = {
    aliases = { "3:27", "3_27", "Route9", "FR_ROUTE_9" },
    dexArea = "DEX_AREA_ROUTE_9",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 14, maxLevel = 17, species = "SPEAROW" },
        { minLevel = 14, maxLevel = 17, species = "RATTATA" },
        { minLevel = 14, maxLevel = 17, species = "SPEAROW" },
        { minLevel = 14, maxLevel = 17, species = "RATTATA" },
        { minLevel = 14, maxLevel = 17, species = "FEAROW" },
        { minLevel = 14, maxLevel = 17, species = "RATICATE" },
        { minLevel = 14, maxLevel = 17, species = "FEAROW" },
        { minLevel = 14, maxLevel = 17, species = "RATICATE" },
        { minLevel = 14, maxLevel = 17, species = "ELECTRIKE" },
        { minLevel = 14, maxLevel = 17, species = "ELECTRIKE" },
        { minLevel = 14, maxLevel = 17, species = "VOLTORB" },
        { minLevel = 14, maxLevel = 17, species = "VOLTORB" },
      }
    },
  },
  ROUTE10 = {
    aliases = { "3:28", "3_28", "Route10", "FR_ROUTE_10" },
    dexArea = "DEX_AREA_ROUTE_10",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 15, maxLevel = 18, species = "SPEAROW" },
        { minLevel = 15, maxLevel = 18, species = "VOLTORB" },
        { minLevel = 15, maxLevel = 18, species = "SPEAROW" },
        { minLevel = 15, maxLevel = 18, species = "VOLTORB" },
        { minLevel = 15, maxLevel = 18, species = "MAGNEMITE" },
        { minLevel = 15, maxLevel = 18, species = "MAREEP" },
        { minLevel = 15, maxLevel = 18, species = "MAGNEMITE" },
        { minLevel = 15, maxLevel = 18, species = "MAREEP" },
        { minLevel = 15, maxLevel = 18, species = "ELECTRIKE" },
        { minLevel = 15, maxLevel = 18, species = "ELECTRIKE" },
        { minLevel = 15, maxLevel = 18, species = "SUDOWOODO" },
        { minLevel = 15, maxLevel = 18, species = "SUDOWOODO" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "GOLDUCK" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "SEAKING" },
        { minLevel = 20, maxLevel = 35, species = "BARBOACH" },
        { minLevel = 20, maxLevel = 35, species = "WHISCASH" },
      }
    },
  },
  ROCK_TUNNEL_1F = {
    aliases = { "1:40", "1_40", "RockTunnel_1F", "FR_ROCK_TUNNEL_1F" },
    dexArea = "DEX_AREA_ROCK_TUNNEL",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 15, maxLevel = 19, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 19, species = "ZUBAT" },
        { minLevel = 15, maxLevel = 19, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 19, species = "ZUBAT" },
        { minLevel = 15, maxLevel = 19, species = "MACHOP" },
        { minLevel = 15, maxLevel = 19, species = "ONIX" },
        { minLevel = 15, maxLevel = 19, species = "MACHOP" },
        { minLevel = 15, maxLevel = 19, species = "ONIX" },
        { minLevel = 15, maxLevel = 19, species = "MAKUHITA" },
        { minLevel = 15, maxLevel = 19, species = "MAKUHITA" },
        { minLevel = 15, maxLevel = 19, species = "MAKUHITA" },
        { minLevel = 15, maxLevel = 19, species = "MAKUHITA" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 15, maxLevel = 25, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 25, species = "GRAVELER" },
        { minLevel = 15, maxLevel = 25, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 25, species = "GRAVELER" },
        { minLevel = 15, maxLevel = 25, species = "SHUCKLE" },
      }
    },
  },
  ROCK_TUNNEL_B1F = {
    aliases = { "1:41", "1_41", "RockTunnel_B1F", "FR_ROCK_TUNNEL_B1F" },
    dexArea = "DEX_AREA_ROCK_TUNNEL",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 16, maxLevel = 20, species = "GEODUDE" },
        { minLevel = 16, maxLevel = 20, species = "GRAVELER" },
        { minLevel = 16, maxLevel = 20, species = "GEODUDE" },
        { minLevel = 16, maxLevel = 20, species = "GRAVELER" },
        { minLevel = 16, maxLevel = 20, species = "ZUBAT" },
        { minLevel = 16, maxLevel = 20, species = "MACHOP" },
        { minLevel = 16, maxLevel = 20, species = "ZUBAT" },
        { minLevel = 16, maxLevel = 20, species = "MACHOP" },
        { minLevel = 16, maxLevel = 20, species = "ONIX" },
        { minLevel = 16, maxLevel = 20, species = "ONIX" },
        { minLevel = 17, maxLevel = 20, species = "ARON" },
        { minLevel = 18, maxLevel = 20, species = "ARON" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 15, maxLevel = 25, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 25, species = "GRAVELER" },
        { minLevel = 15, maxLevel = 25, species = "GEODUDE" },
        { minLevel = 15, maxLevel = 25, species = "GRAVELER" },
        { minLevel = 15, maxLevel = 25, species = "SHUCKLE" },
      }
    },
  },
  POWER_PLANT = {
    aliases = { "1:52", "1_52", "PowerPlant", "FR_POWER_PLANT" },
    dexArea = "DEX_AREA_POWER_PLANT",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 20, maxLevel = 25, species = "MAGNEMITE" },
        { minLevel = 20, maxLevel = 25, species = "VOLTORB" },
        { minLevel = 20, maxLevel = 25, species = "MAGNEMITE" },
        { minLevel = 20, maxLevel = 25, species = "VOLTORB" },
        { minLevel = 20, maxLevel = 25, species = "MAGNETON" },
        { minLevel = 20, maxLevel = 25, species = "ELECTRODE" },
        { minLevel = 20, maxLevel = 25, species = "MAGNETON" },
        { minLevel = 20, maxLevel = 25, species = "ELECTRODE" },
        { minLevel = 20, maxLevel = 25, species = "PIKACHU" },
        { minLevel = 20, maxLevel = 25, species = "PIKACHU" },
        { minLevel = 22, maxLevel = 25, species = "ELECTABUZZ" },
        { minLevel = 24, maxLevel = 26, species = "MANECTRIC" },
      }
    },
  },
  ROUTE11 = {
    aliases = { "3:29", "3_29", "Route11", "FR_ROUTE_11" },
    dexArea = "DEX_AREA_ROUTE_11",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 12, maxLevel = 15, species = "DROWZEE" },
        { minLevel = 12, maxLevel = 15, species = "SPEAROW" },
        { minLevel = 12, maxLevel = 15, species = "DROWZEE" },
        { minLevel = 12, maxLevel = 15, species = "SPEAROW" },
        { minLevel = 12, maxLevel = 15, species = "EKANS" },
        { minLevel = 12, maxLevel = 15, species = "SANDSHREW" },
        { minLevel = 12, maxLevel = 15, species = "EKANS" },
        { minLevel = 12, maxLevel = 15, species = "SANDSHREW" },
        { minLevel = 12, maxLevel = 15, species = "RATTATA" },
        { minLevel = 12, maxLevel = 15, species = "RATTATA" },
        { minLevel = 12, maxLevel = 15, species = "LINOONE" },
        { minLevel = 12, maxLevel = 15, species = "LINOONE" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  DIGLETTS_CAVE = {
    aliases = { "1:37", "1_37", "DiglettsCave_B1F", "FR_DIGLETTS_CAVE_B1F" },
    dexArea = "DEX_AREA_DIGLETTS_CAVE",
    region = "kanto",
    land = {
      rate = 15,
      slots = {
        { minLevel = 15, maxLevel = 22, species = "DIGLETT" },
        { minLevel = 15, maxLevel = 22, species = "DIGLETT" },
        { minLevel = 15, maxLevel = 22, species = "DIGLETT" },
        { minLevel = 15, maxLevel = 22, species = "DIGLETT" },
        { minLevel = 15, maxLevel = 22, species = "DIGLETT" },
        { minLevel = 15, maxLevel = 22, species = "DUGTRIO" },
        { minLevel = 15, maxLevel = 22, species = "DIGLETT" },
        { minLevel = 15, maxLevel = 22, species = "DUGTRIO" },
        { minLevel = 29, maxLevel = 31, species = "NOSEPASS" },
        { minLevel = 29, maxLevel = 31, species = "NOSEPASS" },
        { minLevel = 16, maxLevel = 20, species = "NOSEPASS" },
        { minLevel = 16, maxLevel = 20, species = "NOSEPASS" },
      }
    },
  },
  ROUTE12 = {
    aliases = { "3:30", "3_30", "Route12", "FR_ROUTE_12" },
    dexArea = "DEX_AREA_ROUTE_12",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 22, maxLevel = 26, species = "PIDGEOTTO" },
        { minLevel = 22, maxLevel = 26, species = "VENONAT" },
        { minLevel = 22, maxLevel = 26, species = "PIDGEOTTO" },
        { minLevel = 22, maxLevel = 26, species = "VENONAT" },
        { minLevel = 22, maxLevel = 26, species = "GLOOM" },
        { minLevel = 22, maxLevel = 26, species = "WEEPINBELL" },
        { minLevel = 22, maxLevel = 26, species = "GLOOM" },
        { minLevel = 22, maxLevel = 26, species = "WEEPINBELL" },
        { minLevel = 22, maxLevel = 26, species = "SUNKERN" },
        { minLevel = 22, maxLevel = 26, species = "SUNKERN" },
        { minLevel = 22, maxLevel = 26, species = "CASTFORM" },
        { minLevel = 22, maxLevel = 26, species = "CASTFORM" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "GOLDUCK" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "SEAKING" },
        { minLevel = 20, maxLevel = 35, species = "BARBOACH" },
        { minLevel = 20, maxLevel = 35, species = "WHISCASH" },
      }
    },
  },
  ROUTE13 = {
    aliases = { "3:31", "3_31", "Route13", "FR_ROUTE_13" },
    dexArea = "DEX_AREA_ROUTE_13",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 23, maxLevel = 27, species = "PIDGEOTTO" },
        { minLevel = 23, maxLevel = 27, species = "VENONAT" },
        { minLevel = 23, maxLevel = 27, species = "PIDGEOTTO" },
        { minLevel = 23, maxLevel = 27, species = "VENONAT" },
        { minLevel = 23, maxLevel = 27, species = "GLOOM" },
        { minLevel = 23, maxLevel = 27, species = "WEEPINBELL" },
        { minLevel = 23, maxLevel = 27, species = "GLOOM" },
        { minLevel = 23, maxLevel = 27, species = "WEEPINBELL" },
        { minLevel = 23, maxLevel = 27, species = "FARFETCHD" },
        { minLevel = 23, maxLevel = 27, species = "FARFETCHD" },
        { minLevel = 23, maxLevel = 27, species = "DITTO" },
        { minLevel = 23, maxLevel = 27, species = "DITTO" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "GOLDUCK" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "SEAKING" },
        { minLevel = 20, maxLevel = 35, species = "BARBOACH" },
        { minLevel = 20, maxLevel = 35, species = "WHISCASH" },
      }
    },
  },
  ROUTE14 = {
    aliases = { "3:32", "3_32", "Route14", "FR_ROUTE_14" },
    dexArea = "DEX_AREA_ROUTE_14",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 23, maxLevel = 27, species = "PIDGEOTTO" },
        { minLevel = 23, maxLevel = 27, species = "VENONAT" },
        { minLevel = 23, maxLevel = 27, species = "PIDGEOTTO" },
        { minLevel = 23, maxLevel = 27, species = "VENONAT" },
        { minLevel = 23, maxLevel = 27, species = "GLOOM" },
        { minLevel = 23, maxLevel = 27, species = "WEEPINBELL" },
        { minLevel = 23, maxLevel = 27, species = "GLOOM" },
        { minLevel = 23, maxLevel = 27, species = "WEEPINBELL" },
        { minLevel = 23, maxLevel = 27, species = "VENOMOTH" },
        { minLevel = 23, maxLevel = 27, species = "VENOMOTH" },
        { minLevel = 23, maxLevel = 27, species = "STANTLER" },
        { minLevel = 23, maxLevel = 27, species = "STANTLER" },
      }
    },
  },
  ROUTE15 = {
    aliases = { "3:33", "3_33", "Route15", "FR_ROUTE_15" },
    dexArea = "DEX_AREA_ROUTE_15",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 24, maxLevel = 28, species = "PIDGEOTTO" },
        { minLevel = 24, maxLevel = 28, species = "VENONAT" },
        { minLevel = 24, maxLevel = 28, species = "PIDGEOTTO" },
        { minLevel = 24, maxLevel = 28, species = "VENONAT" },
        { minLevel = 24, maxLevel = 28, species = "GLOOM" },
        { minLevel = 24, maxLevel = 28, species = "WEEPINBELL" },
        { minLevel = 24, maxLevel = 28, species = "GLOOM" },
        { minLevel = 24, maxLevel = 28, species = "WEEPINBELL" },
        { minLevel = 24, maxLevel = 28, species = "MILTANK" },
        { minLevel = 24, maxLevel = 28, species = "MILTANK" },
        { minLevel = 24, maxLevel = 28, species = "TAUROS" },
        { minLevel = 24, maxLevel = 28, species = "TAUROS" },
      }
    },
  },
  ROUTE16 = {
    aliases = { "3:34", "3_34", "Route16", "FR_ROUTE_16" },
    dexArea = "DEX_AREA_ROUTE_16",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 20, maxLevel = 24, species = "DODUO" },
        { minLevel = 20, maxLevel = 24, species = "RATICATE" },
        { minLevel = 20, maxLevel = 24, species = "DODUO" },
        { minLevel = 20, maxLevel = 24, species = "RATICATE" },
        { minLevel = 20, maxLevel = 24, species = "SPEAROW" },
        { minLevel = 20, maxLevel = 24, species = "GRIMER" },
        { minLevel = 20, maxLevel = 24, species = "SPEAROW" },
        { minLevel = 20, maxLevel = 24, species = "GRIMER" },
        { minLevel = 20, maxLevel = 24, species = "GULPIN" },
        { minLevel = 20, maxLevel = 24, species = "GULPIN" },
        { minLevel = 20, maxLevel = 24, species = "SLUGMA" },
        { minLevel = 20, maxLevel = 24, species = "SLUGMA" },
      }
    },
  },
  ROUTE17 = {
    aliases = { "3:35", "3_35", "Route17", "FR_ROUTE_17" },
    dexArea = "DEX_AREA_ROUTE_17",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 24, maxLevel = 28, species = "DODUO" },
        { minLevel = 24, maxLevel = 28, species = "FEAROW" },
        { minLevel = 24, maxLevel = 28, species = "DODUO" },
        { minLevel = 24, maxLevel = 28, species = "FEAROW" },
        { minLevel = 24, maxLevel = 28, species = "RATICATE" },
        { minLevel = 24, maxLevel = 28, species = "GRIMER" },
        { minLevel = 24, maxLevel = 28, species = "RATICATE" },
        { minLevel = 24, maxLevel = 28, species = "GRIMER" },
        { minLevel = 24, maxLevel = 28, species = "MUK" },
        { minLevel = 24, maxLevel = 28, species = "MUK" },
        { minLevel = 24, maxLevel = 28, species = "SLUGMA" },
        { minLevel = 24, maxLevel = 28, species = "SLUGMA" },
      }
    },
  },
  ROUTE18 = {
    aliases = { "3:36", "3_36", "Route18", "FR_ROUTE_18" },
    dexArea = "DEX_AREA_ROUTE_18",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 24, maxLevel = 28, species = "DODUO" },
        { minLevel = 24, maxLevel = 28, species = "FEAROW" },
        { minLevel = 24, maxLevel = 28, species = "DODUO" },
        { minLevel = 24, maxLevel = 28, species = "FEAROW" },
        { minLevel = 24, maxLevel = 28, species = "RATICATE" },
        { minLevel = 24, maxLevel = 28, species = "GRIMER" },
        { minLevel = 24, maxLevel = 28, species = "RATICATE" },
        { minLevel = 24, maxLevel = 28, species = "GRIMER" },
        { minLevel = 24, maxLevel = 28, species = "MILTANK" },
        { minLevel = 24, maxLevel = 28, species = "MILTANK" },
        { minLevel = 24, maxLevel = 28, species = "SKARMORY" },
        { minLevel = 24, maxLevel = 28, species = "SKARMORY" },
      }
    },
  },
  SAFARI_ZONE_CENTER = {
    aliases = { "1:64", "1_64", "SafariZone_Center", "FR_SAFARI_ZONE_CENTER" },
    dexArea = "DEX_AREA_SAFARI_ZONE",
    region = "kanto",
    land = {
      rate = 30,
      slots = {
        { minLevel = 24, maxLevel = 33, species = "RHYHORN" },
        { minLevel = 24, maxLevel = 33, species = "EXEGGCUTE" },
        { minLevel = 24, maxLevel = 33, species = "RHYHORN" },
        { minLevel = 24, maxLevel = 33, species = "EXEGGCUTE" },
        { minLevel = 24, maxLevel = 33, species = "NIDORINO" },
        { minLevel = 24, maxLevel = 33, species = "NIDORINA" },
        { minLevel = 24, maxLevel = 33, species = "NIDORINO" },
        { minLevel = 24, maxLevel = 33, species = "NIDORINA" },
        { minLevel = 24, maxLevel = 33, species = "CHANSEY" },
        { minLevel = 24, maxLevel = 33, species = "CHANSEY" },
        { minLevel = 24, maxLevel = 33, species = "SCYTHER" },
        { minLevel = 24, maxLevel = 33, species = "PINSIR" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 15, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 15, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 15, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 15, maxLevel = 25, species = "DRATINI" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "DRATINI" },
        { minLevel = 20, maxLevel = 35, species = "DRAGONAIR" },
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "FEEBAS" },
      }
    },
  },
  SAFARI_ZONE_EAST = {
    aliases = { "1:65", "1_65", "SafariZone_East", "FR_SAFARI_ZONE_EAST" },
    dexArea = "DEX_AREA_SAFARI_ZONE",
    region = "kanto",
    land = {
      rate = 30,
      slots = {
        { minLevel = 24, maxLevel = 33, species = "DODUO" },
        { minLevel = 24, maxLevel = 33, species = "EXEGGCUTE" },
        { minLevel = 24, maxLevel = 33, species = "DODUO" },
        { minLevel = 24, maxLevel = 33, species = "EXEGGCUTE" },
        { minLevel = 24, maxLevel = 33, species = "NIDORINO" },
        { minLevel = 24, maxLevel = 33, species = "NIDORINA" },
        { minLevel = 24, maxLevel = 33, species = "PARAS" },
        { minLevel = 24, maxLevel = 33, species = "PARASECT" },
        { minLevel = 24, maxLevel = 33, species = "TAUROS" },
        { minLevel = 24, maxLevel = 33, species = "GIRAFARIG" },
        { minLevel = 24, maxLevel = 33, species = "GIRAFARIG" },
        { minLevel = 24, maxLevel = 33, species = "GIRAFARIG" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 15, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 15, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 15, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 15, maxLevel = 25, species = "DRATINI" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "DRATINI" },
        { minLevel = 20, maxLevel = 35, species = "DRAGONAIR" },
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "FEEBAS" },
      }
    },
  },
  SAFARI_ZONE_NORTH = {
    aliases = { "1:66", "1_66", "SafariZone_North", "FR_SAFARI_ZONE_NORTH" },
    dexArea = "DEX_AREA_SAFARI_ZONE",
    region = "kanto",
    land = {
      rate = 30,
      slots = {
        { minLevel = 24, maxLevel = 33, species = "RHYHORN" },
        { minLevel = 24, maxLevel = 33, species = "EXEGGCUTE" },
        { minLevel = 24, maxLevel = 33, species = "RHYHORN" },
        { minLevel = 24, maxLevel = 33, species = "EXEGGCUTE" },
        { minLevel = 24, maxLevel = 33, species = "NIDORINO" },
        { minLevel = 24, maxLevel = 33, species = "NIDORINA" },
        { minLevel = 24, maxLevel = 33, species = "CHANSEY" },
        { minLevel = 24, maxLevel = 33, species = "VENOMOTH" },
        { minLevel = 24, maxLevel = 33, species = "AIPOM" },
        { minLevel = 24, maxLevel = 33, species = "HERACROSS" },
        { minLevel = 24, maxLevel = 33, species = "HERACROSS" },
        { minLevel = 24, maxLevel = 33, species = "HERACROSS" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 15, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 15, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 15, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 15, maxLevel = 25, species = "DRATINI" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "DRATINI" },
        { minLevel = 20, maxLevel = 35, species = "DRAGONAIR" },
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "FEEBAS" },
      }
    },
  },
  SAFARI_ZONE_WEST = {
    aliases = { "1:67", "1_67", "SafariZone_West", "FR_SAFARI_ZONE_WEST" },
    dexArea = "DEX_AREA_SAFARI_ZONE",
    region = "kanto",
    land = {
      rate = 30,
      slots = {
        { minLevel = 24, maxLevel = 33, species = "DODUO" },
        { minLevel = 24, maxLevel = 33, species = "EXEGGCUTE" },
        { minLevel = 24, maxLevel = 33, species = "DODUO" },
        { minLevel = 24, maxLevel = 33, species = "EXEGGCUTE" },
        { minLevel = 24, maxLevel = 33, species = "NIDORINO" },
        { minLevel = 24, maxLevel = 33, species = "NIDORINA" },
        { minLevel = 24, maxLevel = 33, species = "TANGELA" },
        { minLevel = 24, maxLevel = 33, species = "TAUROS" },
        { minLevel = 24, maxLevel = 33, species = "YANMA" },
        { minLevel = 24, maxLevel = 33, species = "TROPIUS" },
        { minLevel = 24, maxLevel = 33, species = "TROPIUS" },
        { minLevel = 24, maxLevel = 33, species = "TROPIUS" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 15, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 15, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 15, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 15, maxLevel = 25, species = "DRATINI" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "DRATINI" },
        { minLevel = 20, maxLevel = 35, species = "DRAGONAIR" },
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "FEEBAS" },
      }
    },
  },
  ROUTE19 = {
    aliases = { "3:37", "3_37", "Route19", "FR_ROUTE_19" },
    dexArea = "DEX_AREA_ROUTE_19",
    region = "kanto",
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  ROUTE20 = {
    aliases = { "3:38", "3_38", "Route20", "FR_ROUTE_20" },
    dexArea = "DEX_AREA_ROUTE_20",
    region = "kanto",
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  ROUTE21 = {
    aliases = { "3:39", "3_39", "Route21", "FR_ROUTE_21" },
    dexArea = "DEX_AREA_ROUTE_21",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 22, maxLevel = 28, species = "PIDGEY" },
        { minLevel = 22, maxLevel = 28, species = "RATTATA" },
        { minLevel = 22, maxLevel = 28, species = "PIDGEY" },
        { minLevel = 22, maxLevel = 28, species = "RATTATA" },
        { minLevel = 22, maxLevel = 28, species = "PIDGEOTTO" },
        { minLevel = 22, maxLevel = 28, species = "RATICATE" },
        { minLevel = 22, maxLevel = 28, species = "PIDGEOTTO" },
        { minLevel = 22, maxLevel = 28, species = "RATICATE" },
        { minLevel = 22, maxLevel = 28, species = "TANGELA" },
        { minLevel = 22, maxLevel = 28, species = "TANGELA" },
        { minLevel = 22, maxLevel = 28, species = "CHINCHOU" },
        { minLevel = 22, maxLevel = 28, species = "CHINCHOU" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  SEAFOAM_ISLANDS_1F = {
    aliases = { "1:68", "1_68", "SeafoamIslands_1F", "FR_SEAFOAM_ISLANDS_1F" },
    dexArea = "DEX_AREA_SEAFOAM_ISLANDS",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 26, maxLevel = 32, species = "ZUBAT" },
        { minLevel = 26, maxLevel = 32, species = "SEEL" },
        { minLevel = 26, maxLevel = 32, species = "ZUBAT" },
        { minLevel = 26, maxLevel = 32, species = "SEEL" },
        { minLevel = 26, maxLevel = 32, species = "GOLBAT" },
        { minLevel = 26, maxLevel = 32, species = "PSYDUCK" },
        { minLevel = 26, maxLevel = 32, species = "GOLBAT" },
        { minLevel = 26, maxLevel = 32, species = "PSYDUCK" },
        { minLevel = 26, maxLevel = 32, species = "SLOWPOKE" },
        { minLevel = 26, maxLevel = 32, species = "SLOWPOKE" },
        { minLevel = 26, maxLevel = 32, species = "SLOWPOKE" },
        { minLevel = 26, maxLevel = 32, species = "SLOWPOKE" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
  },
  SEAFOAM_ISLANDS_B1F = {
    aliases = { "1:69", "1_69", "SeafoamIslands_B1F", "FR_SEAFOAM_ISLANDS_B1F" },
    dexArea = "DEX_AREA_SEAFOAM_ISLANDS",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 27, maxLevel = 33, species = "ZUBAT" },
        { minLevel = 27, maxLevel = 33, species = "SEEL" },
        { minLevel = 27, maxLevel = 33, species = "ZUBAT" },
        { minLevel = 27, maxLevel = 33, species = "SEEL" },
        { minLevel = 27, maxLevel = 33, species = "GOLBAT" },
        { minLevel = 27, maxLevel = 33, species = "PSYDUCK" },
        { minLevel = 27, maxLevel = 33, species = "GOLBAT" },
        { minLevel = 27, maxLevel = 33, species = "PSYDUCK" },
        { minLevel = 27, maxLevel = 33, species = "SLOWPOKE" },
        { minLevel = 27, maxLevel = 33, species = "SLOWPOKE" },
        { minLevel = 27, maxLevel = 33, species = "GOLDUCK" },
        { minLevel = 27, maxLevel = 33, species = "GOLDUCK" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
  },
  SEAFOAM_ISLANDS_B2F = {
    aliases = { "1:70", "1_70", "SeafoamIslands_B2F", "FR_SEAFOAM_ISLANDS_B2F" },
    dexArea = "DEX_AREA_SEAFOAM_ISLANDS",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 28, maxLevel = 34, species = "GOLBAT" },
        { minLevel = 28, maxLevel = 34, species = "SEEL" },
        { minLevel = 28, maxLevel = 34, species = "GOLBAT" },
        { minLevel = 28, maxLevel = 34, species = "SEEL" },
        { minLevel = 28, maxLevel = 34, species = "PSYDUCK" },
        { minLevel = 28, maxLevel = 34, species = "SLOWPOKE" },
        { minLevel = 28, maxLevel = 34, species = "PSYDUCK" },
        { minLevel = 28, maxLevel = 34, species = "SLOWPOKE" },
        { minLevel = 28, maxLevel = 34, species = "SLOWBRO" },
        { minLevel = 28, maxLevel = 34, species = "SLOWBRO" },
        { minLevel = 28, maxLevel = 34, species = "DEWGONG" },
        { minLevel = 28, maxLevel = 34, species = "DEWGONG" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
  },
  SEAFOAM_ISLANDS_B3F = {
    aliases = { "1:71", "1_71", "SeafoamIslands_B3F", "FR_SEAFOAM_ISLANDS_B3F" },
    dexArea = "DEX_AREA_SEAFOAM_ISLANDS",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 29, maxLevel = 35, species = "GOLBAT" },
        { minLevel = 29, maxLevel = 35, species = "SEEL" },
        { minLevel = 29, maxLevel = 35, species = "GOLBAT" },
        { minLevel = 29, maxLevel = 35, species = "SEEL" },
        { minLevel = 29, maxLevel = 35, species = "DEWGONG" },
        { minLevel = 29, maxLevel = 35, species = "PSYDUCK" },
        { minLevel = 29, maxLevel = 35, species = "DEWGONG" },
        { minLevel = 29, maxLevel = 35, species = "PSYDUCK" },
        { minLevel = 29, maxLevel = 35, species = "SWINUB" },
        { minLevel = 29, maxLevel = 35, species = "SWINUB" },
        { minLevel = 29, maxLevel = 35, species = "SNORUNT" },
        { minLevel = 29, maxLevel = 35, species = "SNORUNT" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
  },
  SEAFOAM_ISLANDS_B4F = {
    aliases = { "1:72", "1_72", "SeafoamIslands_B4F", "FR_SEAFOAM_ISLANDS_B4F" },
    dexArea = "DEX_AREA_SEAFOAM_ISLANDS",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 30, maxLevel = 36, species = "GOLBAT" },
        { minLevel = 30, maxLevel = 36, species = "DEWGONG" },
        { minLevel = 30, maxLevel = 36, species = "GOLBAT" },
        { minLevel = 30, maxLevel = 36, species = "DEWGONG" },
        { minLevel = 30, maxLevel = 36, species = "SWINUB" },
        { minLevel = 30, maxLevel = 36, species = "SNORUNT" },
        { minLevel = 30, maxLevel = 36, species = "SWINUB" },
        { minLevel = 30, maxLevel = 36, species = "SNORUNT" },
        { minLevel = 30, maxLevel = 36, species = "SPHEAL" },
        { minLevel = 30, maxLevel = 36, species = "SPHEAL" },
        { minLevel = 32, maxLevel = 36, species = "LAPRAS" },
        { minLevel = 32, maxLevel = 36, species = "LAPRAS" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "SEEL" },
        { minLevel = 25, maxLevel = 35, species = "DEWGONG" },
        { minLevel = 25, maxLevel = 35, species = "SEEL" },
        { minLevel = 25, maxLevel = 35, species = "DEWGONG" },
        { minLevel = 25, maxLevel = 35, species = "LAPRAS" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  POKEMON_MANSION_1F = {
    aliases = { "1:53", "1_53", "PokemonMansion_1F", "FR_POKEMON_MANSION_1F" },
    dexArea = "DEX_AREA_POKEMON_MANSION",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 28, maxLevel = 34, species = "KOFFING" },
        { minLevel = 28, maxLevel = 34, species = "GRIMER" },
        { minLevel = 28, maxLevel = 34, species = "KOFFING" },
        { minLevel = 28, maxLevel = 34, species = "GRIMER" },
        { minLevel = 28, maxLevel = 34, species = "GROWLITHE" },
        { minLevel = 28, maxLevel = 34, species = "VULPIX" },
        { minLevel = 28, maxLevel = 34, species = "GROWLITHE" },
        { minLevel = 28, maxLevel = 34, species = "VULPIX" },
        { minLevel = 28, maxLevel = 34, species = "DITTO" },
        { minLevel = 28, maxLevel = 34, species = "DITTO" },
        { minLevel = 28, maxLevel = 34, species = "DITTO" },
        { minLevel = 28, maxLevel = 34, species = "DITTO" },
      }
    },
  },
  POKEMON_MANSION_2F = {
    aliases = { "1:54", "1_54", "PokemonMansion_2F", "FR_POKEMON_MANSION_2F" },
    dexArea = "DEX_AREA_POKEMON_MANSION",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 29, maxLevel = 35, species = "KOFFING" },
        { minLevel = 29, maxLevel = 35, species = "GRIMER" },
        { minLevel = 29, maxLevel = 35, species = "KOFFING" },
        { minLevel = 29, maxLevel = 35, species = "GRIMER" },
        { minLevel = 29, maxLevel = 35, species = "WEEZING" },
        { minLevel = 29, maxLevel = 35, species = "MUK" },
        { minLevel = 29, maxLevel = 35, species = "WEEZING" },
        { minLevel = 29, maxLevel = 35, species = "MUK" },
        { minLevel = 29, maxLevel = 35, species = "GROWLITHE" },
        { minLevel = 29, maxLevel = 35, species = "GROWLITHE" },
        { minLevel = 29, maxLevel = 35, species = "VULPIX" },
        { minLevel = 29, maxLevel = 35, species = "VULPIX" },
      }
    },
  },
  POKEMON_MANSION_3F = {
    aliases = { "1:55", "1_55", "PokemonMansion_3F", "FR_POKEMON_MANSION_3F" },
    dexArea = "DEX_AREA_POKEMON_MANSION",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 30, maxLevel = 36, species = "KOFFING" },
        { minLevel = 30, maxLevel = 36, species = "GRIMER" },
        { minLevel = 30, maxLevel = 36, species = "KOFFING" },
        { minLevel = 30, maxLevel = 36, species = "GRIMER" },
        { minLevel = 30, maxLevel = 36, species = "WEEZING" },
        { minLevel = 30, maxLevel = 36, species = "MUK" },
        { minLevel = 30, maxLevel = 36, species = "WEEZING" },
        { minLevel = 30, maxLevel = 36, species = "MUK" },
        { minLevel = 30, maxLevel = 36, species = "GROWLITHE" },
        { minLevel = 30, maxLevel = 36, species = "GROWLITHE" },
        { minLevel = 30, maxLevel = 36, species = "VULPIX" },
        { minLevel = 30, maxLevel = 36, species = "MAGMAR" },
      }
    },
  },
  POKEMON_MANSION_B1F = {
    aliases = { "1:56", "1_56", "PokemonMansion_B1F", "FR_POKEMON_MANSION_B1F" },
    dexArea = "DEX_AREA_POKEMON_MANSION",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 30, maxLevel = 36, species = "KOFFING" },
        { minLevel = 30, maxLevel = 36, species = "WEEZING" },
        { minLevel = 30, maxLevel = 36, species = "KOFFING" },
        { minLevel = 30, maxLevel = 36, species = "WEEZING" },
        { minLevel = 30, maxLevel = 36, species = "GRIMER" },
        { minLevel = 30, maxLevel = 36, species = "MUK" },
        { minLevel = 30, maxLevel = 36, species = "GRIMER" },
        { minLevel = 30, maxLevel = 36, species = "MUK" },
        { minLevel = 30, maxLevel = 36, species = "MAGMAR" },
        { minLevel = 30, maxLevel = 36, species = "MAGMAR" },
        { minLevel = 30, maxLevel = 36, species = "DITTO" },
        { minLevel = 30, maxLevel = 36, species = "DITTO" },
      }
    },
  },
  ROUTE22 = {
    aliases = { "3:41", "3_41", "Route22", "FR_ROUTE_22" },
    dexArea = "DEX_AREA_ROUTE_22",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 3, maxLevel = 5, species = "RATTATA" },
        { minLevel = 3, maxLevel = 5, species = "SPEAROW" },
        { minLevel = 3, maxLevel = 5, species = "RATTATA" },
        { minLevel = 3, maxLevel = 5, species = "SPEAROW" },
        { minLevel = 3, maxLevel = 5, species = "NIDORAN_M" },
        { minLevel = 3, maxLevel = 5, species = "NIDORAN_F" },
        { minLevel = 3, maxLevel = 5, species = "NIDORAN_M" },
        { minLevel = 3, maxLevel = 5, species = "NIDORAN_F" },
        { minLevel = 3, maxLevel = 5, species = "MANKEY" },
        { minLevel = 3, maxLevel = 5, species = "MANKEY" },
        { minLevel = 3, maxLevel = 5, species = "POOCHYENA" },
        { minLevel = 3, maxLevel = 5, species = "POOCHYENA" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "GOLDUCK" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "SEAKING" },
        { minLevel = 20, maxLevel = 35, species = "BARBOACH" },
        { minLevel = 20, maxLevel = 35, species = "WHISCASH" },
      }
    },
  },
  ROUTE23 = {
    aliases = { "3:42", "3_42", "Route23", "FR_ROUTE_23" },
    dexArea = "DEX_AREA_ROUTE_23",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 38, maxLevel = 44, species = "FEAROW" },
        { minLevel = 38, maxLevel = 44, species = "ARBOK" },
        { minLevel = 38, maxLevel = 44, species = "FEAROW" },
        { minLevel = 38, maxLevel = 44, species = "ARBOK" },
        { minLevel = 38, maxLevel = 44, species = "SANDSLASH" },
        { minLevel = 38, maxLevel = 44, species = "PRIMEAPE" },
        { minLevel = 38, maxLevel = 44, species = "SANDSLASH" },
        { minLevel = 38, maxLevel = 44, species = "PRIMEAPE" },
        { minLevel = 38, maxLevel = 44, species = "ZANGOOSE" },
        { minLevel = 38, maxLevel = 44, species = "ZANGOOSE" },
        { minLevel = 38, maxLevel = 44, species = "SEVIPER" },
        { minLevel = 38, maxLevel = 44, species = "SEVIPER" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "GOLDUCK" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "SEAKING" },
        { minLevel = 20, maxLevel = 35, species = "BARBOACH" },
        { minLevel = 20, maxLevel = 35, species = "WHISCASH" },
      }
    },
  },
  VICTORY_ROAD_1F = {
    aliases = { "1:49", "1_49", "VictoryRoad_1F", "FR_VICTORY_ROAD_1F" },
    dexArea = "DEX_AREA_VICTORY_ROAD",
    region = "kanto",
    land = {
      rate = 15,
      slots = {
        { minLevel = 38, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 38, maxLevel = 45, species = "GOLBAT" },
        { minLevel = 38, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 38, maxLevel = 45, species = "GOLBAT" },
        { minLevel = 38, maxLevel = 45, species = "MACHOP" },
        { minLevel = 38, maxLevel = 45, species = "MACHOKE" },
        { minLevel = 38, maxLevel = 45, species = "MACHOP" },
        { minLevel = 38, maxLevel = 45, species = "MACHOKE" },
        { minLevel = 38, maxLevel = 45, species = "ONIX" },
        { minLevel = 38, maxLevel = 45, species = "ONIX" },
        { minLevel = 38, maxLevel = 45, species = "MAROWAK" },
        { minLevel = 38, maxLevel = 45, species = "HARIYAMA" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  VICTORY_ROAD_2F = {
    aliases = { "1:50", "1_50", "VictoryRoad_2F", "FR_VICTORY_ROAD_2F" },
    dexArea = "DEX_AREA_VICTORY_ROAD",
    region = "kanto",
    land = {
      rate = 15,
      slots = {
        { minLevel = 39, maxLevel = 46, species = "GRAVELER" },
        { minLevel = 39, maxLevel = 46, species = "GOLBAT" },
        { minLevel = 39, maxLevel = 46, species = "GRAVELER" },
        { minLevel = 39, maxLevel = 46, species = "GOLBAT" },
        { minLevel = 39, maxLevel = 46, species = "MACHOKE" },
        { minLevel = 39, maxLevel = 46, species = "ONIX" },
        { minLevel = 39, maxLevel = 46, species = "MACHOKE" },
        { minLevel = 39, maxLevel = 46, species = "ONIX" },
        { minLevel = 39, maxLevel = 46, species = "MAROWAK" },
        { minLevel = 39, maxLevel = 46, species = "MAROWAK" },
        { minLevel = 39, maxLevel = 46, species = "HARIYAMA" },
        { minLevel = 39, maxLevel = 46, species = "LAIRON" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  VICTORY_ROAD_3F = {
    aliases = { "1:51", "1_51", "VictoryRoad_3F", "FR_VICTORY_ROAD_3F" },
    dexArea = "DEX_AREA_VICTORY_ROAD",
    region = "kanto",
    land = {
      rate = 15,
      slots = {
        { minLevel = 40, maxLevel = 47, species = "GRAVELER" },
        { minLevel = 40, maxLevel = 47, species = "GOLBAT" },
        { minLevel = 40, maxLevel = 47, species = "GRAVELER" },
        { minLevel = 40, maxLevel = 47, species = "GOLBAT" },
        { minLevel = 40, maxLevel = 47, species = "MACHOKE" },
        { minLevel = 40, maxLevel = 47, species = "ONIX" },
        { minLevel = 40, maxLevel = 47, species = "MACHOKE" },
        { minLevel = 40, maxLevel = 47, species = "ONIX" },
        { minLevel = 40, maxLevel = 47, species = "MAROWAK" },
        { minLevel = 40, maxLevel = 47, species = "MAROWAK" },
        { minLevel = 40, maxLevel = 47, species = "LAIRON" },
        { minLevel = 40, maxLevel = 47, species = "MEDICHAM" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  ROUTE24 = {
    aliases = { "3:43", "3_43", "Route24", "FR_ROUTE_24" },
    dexArea = "DEX_AREA_ROUTE_24",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 8, maxLevel = 13, species = "PIDGEY" },
        { minLevel = 8, maxLevel = 13, species = "ODDISH" },
        { minLevel = 8, maxLevel = 13, species = "PIDGEY" },
        { minLevel = 8, maxLevel = 13, species = "ODDISH" },
        { minLevel = 8, maxLevel = 13, species = "BELLSPROUT" },
        { minLevel = 8, maxLevel = 13, species = "ABRA" },
        { minLevel = 8, maxLevel = 13, species = "BELLSPROUT" },
        { minLevel = 8, maxLevel = 13, species = "ABRA" },
        { minLevel = 8, maxLevel = 13, species = "VENONAT" },
        { minLevel = 8, maxLevel = 13, species = "VENONAT" },
        { minLevel = 8, maxLevel = 12, species = "HOPPIP" },
        { minLevel = 10, maxLevel = 12, species = "SQUIRTLE" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "GOLDUCK" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "SEAKING" },
        { minLevel = 20, maxLevel = 35, species = "BARBOACH" },
        { minLevel = 20, maxLevel = 35, species = "WHISCASH" },
      }
    },
  },
  ROUTE25 = {
    aliases = { "3:44", "3_44", "Route25", "FR_ROUTE_25" },
    dexArea = "DEX_AREA_ROUTE_25",
    region = "kanto",
    land = {
      rate = 20,
      slots = {
        { minLevel = 9, maxLevel = 14, species = "PIDGEY" },
        { minLevel = 9, maxLevel = 14, species = "ODDISH" },
        { minLevel = 9, maxLevel = 14, species = "PIDGEY" },
        { minLevel = 9, maxLevel = 14, species = "ODDISH" },
        { minLevel = 9, maxLevel = 14, species = "BELLSPROUT" },
        { minLevel = 9, maxLevel = 14, species = "ABRA" },
        { minLevel = 9, maxLevel = 14, species = "BELLSPROUT" },
        { minLevel = 9, maxLevel = 14, species = "ABRA" },
        { minLevel = 9, maxLevel = 14, species = "VENONAT" },
        { minLevel = 9, maxLevel = 14, species = "VENONAT" },
        { minLevel = 9, maxLevel = 14, species = "HOPPIP" },
        { minLevel = 9, maxLevel = 14, species = "HOPPIP" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "GOLDUCK" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "SEAKING" },
        { minLevel = 20, maxLevel = 35, species = "BARBOACH" },
        { minLevel = 20, maxLevel = 35, species = "WHISCASH" },
      }
    },
  },
  CERULEAN_CAVE_1F = {
    aliases = { "1:72", "1_72", "CeruleanCave_1F", "FR_CERULEAN_CAVE_1F" },
    dexArea = "DEX_AREA_CERULEAN_CAVE",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 50, maxLevel = 60, species = "GOLBAT" },
        { minLevel = 50, maxLevel = 60, species = "MAGNETON" },
        { minLevel = 50, maxLevel = 60, species = "GOLBAT" },
        { minLevel = 50, maxLevel = 60, species = "MAGNETON" },
        { minLevel = 50, maxLevel = 60, species = "ELECTRODE" },
        { minLevel = 50, maxLevel = 60, species = "KADABRA" },
        { minLevel = 50, maxLevel = 60, species = "HYPNO" },
        { minLevel = 50, maxLevel = 60, species = "PARASECT" },
        { minLevel = 50, maxLevel = 60, species = "RHYDON" },
        { minLevel = 50, maxLevel = 60, species = "CHANSEY" },
        { minLevel = 50, maxLevel = 60, species = "DITTO" },
        { minLevel = 50, maxLevel = 60, species = "DITTO" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 45, maxLevel = 55, species = "GOLDUCK" },
        { minLevel = 45, maxLevel = 55, species = "SLOWBRO" },
        { minLevel = 45, maxLevel = 55, species = "GOLDUCK" },
        { minLevel = 45, maxLevel = 55, species = "SLOWBRO" },
        { minLevel = 45, maxLevel = 55, species = "POLIWRATH" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 20, maxLevel = 30, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 30, species = "SEAKING" },
        { minLevel = 20, maxLevel = 30, species = "GYARADOS" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 50, maxLevel = 60, species = "GYARADOS" },
        { minLevel = 50, maxLevel = 60, species = "SEADRA" },
        { minLevel = 50, maxLevel = 60, species = "KINGDRA" },
        { minLevel = 50, maxLevel = 60, species = "WHISCASH" },
        { minLevel = 50, maxLevel = 60, species = "MILOTIC" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  CERULEAN_CAVE_2F = {
    aliases = { "1:73", "1_73", "CeruleanCave_2F", "FR_CERULEAN_CAVE_2F" },
    dexArea = "DEX_AREA_CERULEAN_CAVE",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 52, maxLevel = 62, species = "GOLBAT" },
        { minLevel = 52, maxLevel = 62, species = "MAGNETON" },
        { minLevel = 52, maxLevel = 62, species = "GOLBAT" },
        { minLevel = 52, maxLevel = 62, species = "MAGNETON" },
        { minLevel = 52, maxLevel = 62, species = "ELECTRODE" },
        { minLevel = 52, maxLevel = 62, species = "KADABRA" },
        { minLevel = 52, maxLevel = 62, species = "HYPNO" },
        { minLevel = 52, maxLevel = 62, species = "PARASECT" },
        { minLevel = 52, maxLevel = 62, species = "RHYDON" },
        { minLevel = 52, maxLevel = 62, species = "WOBBUFFET", heldItem = 221 },
        { minLevel = 52, maxLevel = 62, species = "AGGRON" },
        { minLevel = 52, maxLevel = 62, species = "AGGRON" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  CERULEAN_CAVE_B1F = {
    aliases = { "1:74", "1_74", "CeruleanCave_B1F", "FR_CERULEAN_CAVE_B1F" },
    dexArea = "DEX_AREA_CERULEAN_CAVE",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 55, maxLevel = 65, species = "GOLBAT" },
        { minLevel = 55, maxLevel = 65, species = "MAGNETON" },
        { minLevel = 55, maxLevel = 65, species = "GOLBAT" },
        { minLevel = 55, maxLevel = 65, species = "MAGNETON" },
        { minLevel = 55, maxLevel = 65, species = "ELECTRODE" },
        { minLevel = 55, maxLevel = 65, species = "KADABRA" },
        { minLevel = 55, maxLevel = 65, species = "RHYDON" },
        { minLevel = 55, maxLevel = 65, species = "CHANSEY" },
        { minLevel = 55, maxLevel = 65, species = "DITTO" },
        { minLevel = 55, maxLevel = 65, species = "WOBBUFFET", heldItem = 221 },
        { minLevel = 55, maxLevel = 65, species = "AGGRON" },
        { minLevel = 55, maxLevel = 65, species = "AGGRON" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 50, maxLevel = 60, species = "GOLDUCK" },
        { minLevel = 50, maxLevel = 60, species = "SLOWBRO" },
        { minLevel = 50, maxLevel = 60, species = "GOLDUCK" },
        { minLevel = 50, maxLevel = 60, species = "SLOWBRO" },
        { minLevel = 50, maxLevel = 60, species = "POLIWRATH" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 20, maxLevel = 30, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 30, species = "SEAKING" },
        { minLevel = 20, maxLevel = 30, species = "GYARADOS" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 55, maxLevel = 65, species = "GYARADOS" },
        { minLevel = 55, maxLevel = 65, species = "SEADRA" },
        { minLevel = 55, maxLevel = 65, species = "KINGDRA" },
        { minLevel = 55, maxLevel = 65, species = "WHISCASH" },
        { minLevel = 55, maxLevel = 65, species = "MILOTIC" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  POKEMON_TOWER_3F = {
    aliases = { "1:44", "1_44", "PokemonTower_3F", "FR_POKEMON_TOWER_3F" },
    dexArea = "DEX_AREA_POKEMON_TOWER",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 18, maxLevel = 22, species = "GASTLY" },
        { minLevel = 18, maxLevel = 22, species = "CUBONE" },
        { minLevel = 18, maxLevel = 22, species = "GASTLY" },
        { minLevel = 18, maxLevel = 22, species = "CUBONE" },
        { minLevel = 18, maxLevel = 22, species = "MISDREAVUS" },
        { minLevel = 18, maxLevel = 22, species = "MISDREAVUS" },
        { minLevel = 18, maxLevel = 22, species = "MISDREAVUS" },
        { minLevel = 18, maxLevel = 22, species = "MISDREAVUS" },
        { minLevel = 18, maxLevel = 22, species = "MISDREAVUS" },
        { minLevel = 18, maxLevel = 22, species = "MISDREAVUS" },
        { minLevel = 18, maxLevel = 22, species = "MISDREAVUS" },
        { minLevel = 18, maxLevel = 22, species = "MISDREAVUS" },
      }
    },
  },
  POKEMON_TOWER_4F = {
    aliases = { "1:45", "1_45", "PokemonTower_4F", "FR_POKEMON_TOWER_4F" },
    dexArea = "DEX_AREA_POKEMON_TOWER",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 19, maxLevel = 23, species = "GASTLY" },
        { minLevel = 19, maxLevel = 23, species = "HAUNTER" },
        { minLevel = 19, maxLevel = 23, species = "GASTLY" },
        { minLevel = 19, maxLevel = 23, species = "HAUNTER" },
        { minLevel = 19, maxLevel = 23, species = "CUBONE" },
        { minLevel = 19, maxLevel = 23, species = "CUBONE" },
        { minLevel = 19, maxLevel = 23, species = "CUBONE" },
        { minLevel = 19, maxLevel = 23, species = "CUBONE" },
        { minLevel = 19, maxLevel = 23, species = "MISDREAVUS" },
        { minLevel = 19, maxLevel = 23, species = "MISDREAVUS" },
        { minLevel = 19, maxLevel = 23, species = "MISDREAVUS" },
        { minLevel = 19, maxLevel = 23, species = "MISDREAVUS" },
      }
    },
  },
  POKEMON_TOWER_5F = {
    aliases = { "1:46", "1_46", "PokemonTower_5F", "FR_POKEMON_TOWER_5F" },
    dexArea = "DEX_AREA_POKEMON_TOWER",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 20, maxLevel = 24, species = "GASTLY" },
        { minLevel = 20, maxLevel = 24, species = "HAUNTER" },
        { minLevel = 20, maxLevel = 24, species = "GASTLY" },
        { minLevel = 20, maxLevel = 24, species = "HAUNTER" },
        { minLevel = 20, maxLevel = 24, species = "CUBONE" },
        { minLevel = 20, maxLevel = 24, species = "MISDREAVUS" },
        { minLevel = 20, maxLevel = 24, species = "CUBONE" },
        { minLevel = 20, maxLevel = 24, species = "MISDREAVUS" },
        { minLevel = 20, maxLevel = 24, species = "SHUPPET" },
        { minLevel = 20, maxLevel = 24, species = "SHUPPET" },
        { minLevel = 20, maxLevel = 24, species = "SHUPPET" },
        { minLevel = 20, maxLevel = 24, species = "SHUPPET" },
      }
    },
  },
  POKEMON_TOWER_6F = {
    aliases = { "1:47", "1_47", "PokemonTower_6F", "FR_POKEMON_TOWER_6F" },
    dexArea = "DEX_AREA_POKEMON_TOWER",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 21, maxLevel = 25, species = "GASTLY" },
        { minLevel = 21, maxLevel = 25, species = "HAUNTER" },
        { minLevel = 21, maxLevel = 25, species = "GASTLY" },
        { minLevel = 21, maxLevel = 25, species = "HAUNTER" },
        { minLevel = 21, maxLevel = 25, species = "CUBONE" },
        { minLevel = 21, maxLevel = 25, species = "MISDREAVUS" },
        { minLevel = 21, maxLevel = 25, species = "CUBONE" },
        { minLevel = 21, maxLevel = 25, species = "MISDREAVUS" },
        { minLevel = 21, maxLevel = 25, species = "SHUPPET" },
        { minLevel = 21, maxLevel = 25, species = "SHUPPET" },
        { minLevel = 21, maxLevel = 25, species = "SHUPPET" },
        { minLevel = 21, maxLevel = 25, species = "SHUPPET" },
      }
    },
  },
  POKEMON_TOWER_7F = {
    aliases = { "1:48", "1_48", "PokemonTower_7F", "FR_POKEMON_TOWER_7F" },
    dexArea = "DEX_AREA_POKEMON_TOWER",
    region = "kanto",
    land = {
      rate = 10,
      slots = {
        { minLevel = 22, maxLevel = 26, species = "GASTLY" },
        { minLevel = 22, maxLevel = 26, species = "HAUNTER" },
        { minLevel = 22, maxLevel = 26, species = "GASTLY" },
        { minLevel = 22, maxLevel = 26, species = "HAUNTER" },
        { minLevel = 22, maxLevel = 26, species = "CUBONE" },
        { minLevel = 22, maxLevel = 26, species = "MAROWAK" },
        { minLevel = 22, maxLevel = 26, species = "CUBONE" },
        { minLevel = 22, maxLevel = 26, species = "MAROWAK" },
        { minLevel = 22, maxLevel = 26, species = "SHUPPET" },
        { minLevel = 22, maxLevel = 26, species = "SHUPPET" },
        { minLevel = 22, maxLevel = 26, species = "MISDREAVUS" },
        { minLevel = 22, maxLevel = 26, species = "MISDREAVUS" },
      }
    },
  },
  KINDLE_ROAD = {
    aliases = { "3:45", "3_45", "OneIsland_KindleRoad", "FR_ONE_ISLAND_KINDLE_ROAD" },
    dexArea = "DEX_AREA_KINDLE_ROAD",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 34, maxLevel = 40, species = "PONYTA" },
        { minLevel = 34, maxLevel = 40, species = "GEODUDE" },
        { minLevel = 34, maxLevel = 40, species = "PONYTA" },
        { minLevel = 34, maxLevel = 40, species = "GEODUDE" },
        { minLevel = 34, maxLevel = 40, species = "RAPIDASH" },
        { minLevel = 34, maxLevel = 40, species = "GRAVELER" },
        { minLevel = 34, maxLevel = 40, species = "RAPIDASH" },
        { minLevel = 34, maxLevel = 40, species = "GRAVELER" },
        { minLevel = 34, maxLevel = 40, species = "SLUGMA" },
        { minLevel = 34, maxLevel = 40, species = "SLUGMA" },
        { minLevel = 34, maxLevel = 40, species = "MAGCARGO" },
        { minLevel = 34, maxLevel = 40, species = "TORKOAL" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  TREASURE_BEACH = {
    aliases = { "3:46", "3_46", "OneIsland_TreasureBeach", "FR_ONE_ISLAND_TREASURE_BEACH" },
    dexArea = "DEX_AREA_TREASURE_BEACH",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 34, maxLevel = 40, species = "TANGELA" },
        { minLevel = 34, maxLevel = 40, species = "SLOWPOKE" },
        { minLevel = 34, maxLevel = 40, species = "TANGELA" },
        { minLevel = 34, maxLevel = 40, species = "SLOWPOKE" },
        { minLevel = 34, maxLevel = 40, species = "SLOWBRO" },
        { minLevel = 34, maxLevel = 40, species = "PSYDUCK" },
        { minLevel = 34, maxLevel = 40, species = "SLOWBRO" },
        { minLevel = 34, maxLevel = 40, species = "PSYDUCK" },
        { minLevel = 34, maxLevel = 40, species = "GOLDUCK" },
        { minLevel = 34, maxLevel = 40, species = "GOLDUCK" },
        { minLevel = 34, maxLevel = 40, species = "WINGULL" },
        { minLevel = 34, maxLevel = 40, species = "PELIPPER" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  MT_EMBER_EXTERIOR = {
    aliases = { "1:98", "1_98", "MtEmber_Exterior", "FR_MT_EMBER_EXTERIOR" },
    dexArea = "DEX_AREA_MT_EMBER",
    region = "sevii",
    land = {
      rate = 15,
      slots = {
        { minLevel = 38, maxLevel = 46, species = "PONYTA" },
        { minLevel = 38, maxLevel = 46, species = "RAPIDASH" },
        { minLevel = 38, maxLevel = 46, species = "PONYTA" },
        { minLevel = 38, maxLevel = 46, species = "RAPIDASH" },
        { minLevel = 38, maxLevel = 46, species = "MAGMAR" },
        { minLevel = 38, maxLevel = 46, species = "SLUGMA" },
        { minLevel = 38, maxLevel = 46, species = "MAGCARGO" },
        { minLevel = 38, maxLevel = 46, species = "NUMEL" },
        { minLevel = 38, maxLevel = 46, species = "CAMERUPT" },
        { minLevel = 38, maxLevel = 46, species = "TORKOAL" },
        { minLevel = 38, maxLevel = 46, species = "CHIMECHO" },
        { minLevel = 38, maxLevel = 46, species = "CHIMECHO" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  MT_EMBER_RUBY_PATH = {
    aliases = { "1:100", "1_100", "MtEmber_RubyPath_1F", "FR_MT_EMBER_RUBY_PATH_1F" },
    dexArea = "DEX_AREA_MT_EMBER",
    region = "sevii",
    land = {
      rate = 15,
      slots = {
        { minLevel = 40, maxLevel = 48, species = "RAPIDASH" },
        { minLevel = 40, maxLevel = 48, species = "MAGMAR" },
        { minLevel = 40, maxLevel = 48, species = "RAPIDASH" },
        { minLevel = 40, maxLevel = 48, species = "MAGMAR" },
        { minLevel = 40, maxLevel = 48, species = "MAGCARGO" },
        { minLevel = 40, maxLevel = 48, species = "CAMERUPT" },
        { minLevel = 40, maxLevel = 48, species = "MAGCARGO" },
        { minLevel = 40, maxLevel = 48, species = "CAMERUPT" },
        { minLevel = 42, maxLevel = 45, species = "TORKOAL" },
        { minLevel = 42, maxLevel = 45, species = "TORKOAL" },
        { minLevel = 45, maxLevel = 48, species = "BAGON" },
        { minLevel = 45, maxLevel = 48, species = "BAGON" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  CAPE_BRINK = {
    aliases = { "3:47", "3_47", "TwoIsland_CapeBrink", "FR_TWO_ISLAND_CAPE_BRINK" },
    dexArea = "DEX_AREA_CAPE_BRINK",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 35, maxLevel = 42, species = "GOLDUCK" },
        { minLevel = 35, maxLevel = 42, species = "SLOWBRO" },
        { minLevel = 35, maxLevel = 42, species = "GOLDUCK" },
        { minLevel = 35, maxLevel = 42, species = "SLOWBRO" },
        { minLevel = 35, maxLevel = 42, species = "LOMBRE" },
        { minLevel = 35, maxLevel = 42, species = "NUZLEAF" },
        { minLevel = 35, maxLevel = 42, species = "LOMBRE" },
        { minLevel = 35, maxLevel = 42, species = "NUZLEAF" },
        { minLevel = 35, maxLevel = 42, species = "BELLSPROUT" },
        { minLevel = 35, maxLevel = 42, species = "BELLSPROUT" },
        { minLevel = 35, maxLevel = 42, species = "WEEPINBELL" },
        { minLevel = 35, maxLevel = 42, species = "POLIWHIRL" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "PSYDUCK" },
        { minLevel = 10, maxLevel = 25, species = "SLOWPOKE" },
        { minLevel = 10, maxLevel = 25, species = "GOLDUCK" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "SEAKING" },
        { minLevel = 20, maxLevel = 35, species = "BARBOACH" },
        { minLevel = 20, maxLevel = 35, species = "WHISCASH" },
      }
    },
  },
  BOND_BRIDGE = {
    aliases = { "3:48", "3_48", "ThreeIsland_BondBridge", "FR_THREE_ISLAND_BOND_BRIDGE" },
    dexArea = "DEX_AREA_BOND_BRIDGE",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 36, maxLevel = 42, species = "PIDGEOTTO" },
        { minLevel = 36, maxLevel = 42, species = "VENONAT" },
        { minLevel = 36, maxLevel = 42, species = "PIDGEOTTO" },
        { minLevel = 36, maxLevel = 42, species = "VENONAT" },
        { minLevel = 36, maxLevel = 42, species = "VENOMOTH" },
        { minLevel = 36, maxLevel = 42, species = "BELLSPROUT" },
        { minLevel = 36, maxLevel = 42, species = "VENOMOTH" },
        { minLevel = 36, maxLevel = 42, species = "BELLSPROUT" },
        { minLevel = 36, maxLevel = 42, species = "WEEPINBELL" },
        { minLevel = 36, maxLevel = 42, species = "WEEPINBELL" },
        { minLevel = 36, maxLevel = 42, species = "MEOWTH" },
        { minLevel = 36, maxLevel = 42, species = "PERSIAN" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  THREE_ISLE_PORT = {
    aliases = { "3:49", "3_49", "ThreeIsland_ThreeIslePath", "FR_THREE_ISLE_PATH" },
    dexArea = "DEX_AREA_THREE_ISLE_PATH",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 35, maxLevel = 40, species = "DUNSPARCE" },
        { minLevel = 35, maxLevel = 40, species = "PIDGEOTTO" },
        { minLevel = 35, maxLevel = 40, species = "DUNSPARCE" },
        { minLevel = 35, maxLevel = 40, species = "PIDGEOTTO" },
        { minLevel = 35, maxLevel = 40, species = "ZUBAT" },
        { minLevel = 35, maxLevel = 40, species = "ZUBAT" },
        { minLevel = 35, maxLevel = 40, species = "ZUBAT" },
        { minLevel = 35, maxLevel = 40, species = "ZUBAT" },
        { minLevel = 35, maxLevel = 40, species = "GOLBAT" },
        { minLevel = 35, maxLevel = 40, species = "GOLBAT" },
        { minLevel = 35, maxLevel = 40, species = "GOLBAT" },
        { minLevel = 35, maxLevel = 40, species = "GOLBAT" },
      }
    },
  },
  BERRY_FOREST = {
    aliases = { "1:109", "1_109", "ThreeIsland_BerryForest", "FR_THREE_ISLAND_BERRY_FOREST" },
    dexArea = "DEX_AREA_BERRY_FOREST",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 36, maxLevel = 44, species = "DROWZEE" },
        { minLevel = 36, maxLevel = 44, species = "HYPNO" },
        { minLevel = 36, maxLevel = 44, species = "DROWZEE" },
        { minLevel = 36, maxLevel = 44, species = "HYPNO" },
        { minLevel = 36, maxLevel = 44, species = "VENONAT" },
        { minLevel = 36, maxLevel = 44, species = "VENOMOTH" },
        { minLevel = 36, maxLevel = 44, species = "PINSIR" },
        { minLevel = 36, maxLevel = 44, species = "SCYTHER" },
        { minLevel = 36, maxLevel = 44, species = "HERACROSS" },
        { minLevel = 36, maxLevel = 44, species = "BRELOOM" },
        { minLevel = 36, maxLevel = 44, species = "SWALOT" },
        { minLevel = 36, maxLevel = 44, species = "ROSELIA" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 30, maxLevel = 40, species = "PSYDUCK" },
        { minLevel = 30, maxLevel = 40, species = "SLOWPOKE" },
        { minLevel = 30, maxLevel = 40, species = "GOLDUCK" },
        { minLevel = 30, maxLevel = 40, species = "SLOWBRO" },
        { minLevel = 30, maxLevel = 40, species = "SURSKIT" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "POLIWAG" },
        { minLevel = 10, maxLevel = 20, species = "GOLDEEN" },
        { minLevel = 10, maxLevel = 20, species = "CORPHISH" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 20, maxLevel = 35, species = "POLIWHIRL" },
        { minLevel = 20, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 20, maxLevel = 35, species = "SEAKING" },
        { minLevel = 20, maxLevel = 35, species = "BARBOACH" },
        { minLevel = 20, maxLevel = 35, species = "WHISCASH" },
      }
    },
  },
  ICEFALL_CAVE_ENTRANCE = {
    aliases = { "1:110", "1_110", "FourIsland_IcefallCave_Entrance", "FR_FOUR_ISLAND_ICEFALL_CAVE_ENTRANCE" },
    dexArea = "DEX_AREA_ICEFALL_CAVE",
    region = "sevii",
    land = {
      rate = 10,
      slots = {
        { minLevel = 36, maxLevel = 42, species = "ZUBAT" },
        { minLevel = 36, maxLevel = 42, species = "GOLBAT" },
        { minLevel = 36, maxLevel = 42, species = "ZUBAT" },
        { minLevel = 36, maxLevel = 42, species = "GOLBAT" },
        { minLevel = 36, maxLevel = 42, species = "SWINUB" },
        { minLevel = 36, maxLevel = 42, species = "DELIBIRD" },
        { minLevel = 36, maxLevel = 42, species = "SWINUB" },
        { minLevel = 36, maxLevel = 42, species = "DELIBIRD" },
        { minLevel = 36, maxLevel = 42, species = "SNEASEL" },
        { minLevel = 36, maxLevel = 42, species = "SNEASEL" },
        { minLevel = 36, maxLevel = 42, species = "SNEASEL" },
        { minLevel = 36, maxLevel = 42, species = "SNEASEL" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
  },
  ICEFALL_CAVE_1F = {
    aliases = { "1:111", "1_111", "FourIsland_IcefallCave_1F", "FR_FOUR_ISLAND_ICEFALL_CAVE_1F" },
    dexArea = "DEX_AREA_ICEFALL_CAVE",
    region = "sevii",
    land = {
      rate = 10,
      slots = {
        { minLevel = 38, maxLevel = 44, species = "GOLBAT" },
        { minLevel = 38, maxLevel = 44, species = "SWINUB" },
        { minLevel = 38, maxLevel = 44, species = "GOLBAT" },
        { minLevel = 38, maxLevel = 44, species = "SWINUB" },
        { minLevel = 38, maxLevel = 44, species = "PILOSWINE" },
        { minLevel = 38, maxLevel = 44, species = "DELIBIRD" },
        { minLevel = 38, maxLevel = 44, species = "PILOSWINE" },
        { minLevel = 38, maxLevel = 44, species = "DELIBIRD" },
        { minLevel = 38, maxLevel = 44, species = "SNEASEL" },
        { minLevel = 38, maxLevel = 44, species = "SNEASEL" },
        { minLevel = 38, maxLevel = 44, species = "SNORUNT" },
        { minLevel = 38, maxLevel = 44, species = "GLALIE" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
  },
  ICEFALL_CAVE_B1F = {
    aliases = { "1:112", "1_112", "FourIsland_IcefallCave_B1F", "FR_FOUR_ISLAND_ICEFALL_CAVE_B1F" },
    dexArea = "DEX_AREA_ICEFALL_CAVE",
    region = "sevii",
    land = {
      rate = 10,
      slots = {
        { minLevel = 39, maxLevel = 45, species = "GOLBAT" },
        { minLevel = 39, maxLevel = 45, species = "PILOSWINE" },
        { minLevel = 39, maxLevel = 45, species = "GOLBAT" },
        { minLevel = 39, maxLevel = 45, species = "PILOSWINE" },
        { minLevel = 39, maxLevel = 45, species = "DELIBIRD" },
        { minLevel = 39, maxLevel = 45, species = "SNEASEL" },
        { minLevel = 39, maxLevel = 45, species = "DELIBIRD" },
        { minLevel = 39, maxLevel = 45, species = "SNEASEL" },
        { minLevel = 39, maxLevel = 45, species = "SNORUNT" },
        { minLevel = 39, maxLevel = 45, species = "SNORUNT" },
        { minLevel = 39, maxLevel = 45, species = "GLALIE" },
        { minLevel = 39, maxLevel = 45, species = "SEALEO" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
  },
  ICEFALL_CAVE_BACK = {
    aliases = { "1:113", "1_113", "FourIsland_IcefallCave_Back", "FR_FOUR_ISLAND_ICEFALL_CAVE_BACK" },
    dexArea = "DEX_AREA_ICEFALL_CAVE",
    region = "sevii",
    land = {
      rate = 10,
      slots = {
        { minLevel = 40, maxLevel = 46, species = "GOLBAT" },
        { minLevel = 40, maxLevel = 46, species = "PILOSWINE" },
        { minLevel = 40, maxLevel = 46, species = "GOLBAT" },
        { minLevel = 40, maxLevel = 46, species = "PILOSWINE" },
        { minLevel = 40, maxLevel = 46, species = "SNEASEL" },
        { minLevel = 40, maxLevel = 46, species = "GLALIE" },
        { minLevel = 40, maxLevel = 46, species = "SNEASEL" },
        { minLevel = 40, maxLevel = 46, species = "GLALIE" },
        { minLevel = 40, maxLevel = 46, species = "SEALEO" },
        { minLevel = 40, maxLevel = 46, species = "SEALEO" },
        { minLevel = 42, maxLevel = 46, species = "WALREIN" },
        { minLevel = 42, maxLevel = 46, species = "LAPRAS" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "SEALEO" },
        { minLevel = 35, maxLevel = 45, species = "LAPRAS" },
        { minLevel = 35, maxLevel = 45, species = "SEALEO" },
        { minLevel = 35, maxLevel = 45, species = "LAPRAS" },
        { minLevel = 35, maxLevel = 45, species = "WALREIN" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  ROCKET_WAREHOUSE = {
    aliases = { "1:114", "1_114", "FiveIsland_RocketWarehouse", "FR_FIVE_ISLAND_ROCKET_WAREHOUSE" },
    dexArea = "DEX_AREA_FIVE_ISLAND",
    region = "sevii",
    land = {
      rate = 10,
      slots = {
        { minLevel = 38, maxLevel = 44, species = "RATTATA" },
        { minLevel = 38, maxLevel = 44, species = "RATICATE" },
        { minLevel = 38, maxLevel = 44, species = "RATTATA" },
        { minLevel = 38, maxLevel = 44, species = "RATICATE" },
        { minLevel = 38, maxLevel = 44, species = "KOFFING" },
        { minLevel = 38, maxLevel = 44, species = "WEEZING" },
        { minLevel = 38, maxLevel = 44, species = "KOFFING" },
        { minLevel = 38, maxLevel = 44, species = "WEEZING" },
        { minLevel = 38, maxLevel = 44, species = "MAGNEMITE" },
        { minLevel = 38, maxLevel = 44, species = "MAGNEMITE" },
        { minLevel = 38, maxLevel = 44, species = "MAGNETON" },
        { minLevel = 38, maxLevel = 44, species = "MAGNETON" },
      }
    },
  },
  FIVE_ISLE_MEADOW = {
    aliases = { "3:56", "3_56", "FiveIsland_Meadow", "FR_FIVE_ISLAND_MEADOW" },
    dexArea = "DEX_AREA_FIVE_ISLE_MEADOW",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 38, maxLevel = 44, species = "HOPPIP" },
        { minLevel = 38, maxLevel = 44, species = "SKIPLOOM" },
        { minLevel = 38, maxLevel = 44, species = "HOPPIP" },
        { minLevel = 38, maxLevel = 44, species = "SKIPLOOM" },
        { minLevel = 38, maxLevel = 44, species = "SENTRET" },
        { minLevel = 38, maxLevel = 44, species = "FURRET" },
        { minLevel = 38, maxLevel = 44, species = "FLAAFFY" },
        { minLevel = 38, maxLevel = 44, species = "MARILL", heldItem = 220 },
        { minLevel = 38, maxLevel = 44, species = "AZUMARILL" },
        { minLevel = 38, maxLevel = 44, species = "CHIMECHO" },
        { minLevel = 38, maxLevel = 44, species = "MILTANK" },
        { minLevel = 38, maxLevel = 44, species = "MILTANK" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  MEMORIAL_PILLAR = {
    aliases = { "3:57", "3_57", "FiveIsland_MemorialPillar", "FR_FIVE_ISLAND_MEMORIAL_PILLAR" },
    dexArea = "DEX_AREA_MEMORIAL_PILLAR",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 38, maxLevel = 44, species = "HOPPIP" },
        { minLevel = 38, maxLevel = 44, species = "SKIPLOOM" },
        { minLevel = 38, maxLevel = 44, species = "HOPPIP" },
        { minLevel = 38, maxLevel = 44, species = "SKIPLOOM" },
        { minLevel = 38, maxLevel = 44, species = "BELLSPROUT" },
        { minLevel = 38, maxLevel = 44, species = "WEEPINBELL" },
        { minLevel = 38, maxLevel = 44, species = "BELLSPROUT" },
        { minLevel = 38, maxLevel = 44, species = "WEEPINBELL" },
        { minLevel = 38, maxLevel = 44, species = "CHIMECHO" },
        { minLevel = 38, maxLevel = 44, species = "CHIMECHO" },
        { minLevel = 38, maxLevel = 44, species = "CHIMECHO" },
        { minLevel = 38, maxLevel = 44, species = "CHIMECHO" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  RESORT_GORGEOUS = {
    aliases = { "3:54", "3_54", "FiveIsland_ResortGorgeous", "FR_FIVE_ISLAND_RESORT_GORGEOUS" },
    dexArea = "DEX_AREA_RESORT_GORGEOUS",
    region = "sevii",
    water = {
      rate = 4,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "TENTACOOL" },
        { minLevel = 35, maxLevel = 45, species = "WINGULL" },
        { minLevel = 35, maxLevel = 45, species = "PELIPPER" },
        { minLevel = 35, maxLevel = 45, species = "MARILL", heldItem = 220 },
        { minLevel = 35, maxLevel = 45, species = "AZUMARILL" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GYARADOS" },
        { minLevel = 35, maxLevel = 45, species = "SEADRA" },
        { minLevel = 35, maxLevel = 45, species = "QWILFISH" },
        { minLevel = 35, maxLevel = 45, species = "CORSOLA" },
        { minLevel = 35, maxLevel = 45, species = "RELICANTH" },
      }
    },
  },
  WATER_LABYRINTH = {
    aliases = { "3:55", "3_55", "FiveIsland_WaterLabyrinth", "FR_FIVE_ISLAND_WATER_LABYRINTH" },
    dexArea = "DEX_AREA_WATER_LABYRINTH",
    region = "sevii",
    water = {
      rate = 4,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "TENTACOOL" },
        { minLevel = 35, maxLevel = 45, species = "WINGULL" },
        { minLevel = 35, maxLevel = 45, species = "PELIPPER" },
        { minLevel = 35, maxLevel = 45, species = "MARILL", heldItem = 220 },
        { minLevel = 35, maxLevel = 45, species = "AZUMARILL" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  LOST_CAVE = {
    aliases = { "2:12", "2_12", "FiveIsland_LostCave_Entrance", "FR_FIVE_ISLAND_LOST_CAVE_ENTRANCE" },
    dexArea = "DEX_AREA_LOST_CAVE",
    region = "sevii",
    land = {
      rate = 10,
      slots = {
        { minLevel = 38, maxLevel = 48, species = "GASTLY" },
        { minLevel = 38, maxLevel = 48, species = "HAUNTER" },
        { minLevel = 38, maxLevel = 48, species = "GASTLY" },
        { minLevel = 38, maxLevel = 48, species = "HAUNTER" },
        { minLevel = 38, maxLevel = 48, species = "MISDREAVUS" },
        { minLevel = 38, maxLevel = 48, species = "SHUPPET" },
        { minLevel = 38, maxLevel = 48, species = "BANETTE" },
        { minLevel = 38, maxLevel = 48, species = "MURKROW" },
        { minLevel = 38, maxLevel = 48, species = "SABLEYE" },
        { minLevel = 38, maxLevel = 48, species = "MAWILE" },
        { minLevel = 38, maxLevel = 48, species = "DUSCLOPS" },
        { minLevel = 38, maxLevel = 48, species = "DUSCLOPS" },
      }
    },
  },
  WATER_PATH = {
    aliases = { "3:58", "3_58", "SixIsland_WaterPath", "FR_SIX_ISLAND_WATER_PATH" },
    dexArea = "DEX_AREA_WATER_PATH",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 38, maxLevel = 45, species = "SENTRET" },
        { minLevel = 38, maxLevel = 45, species = "FURRET" },
        { minLevel = 38, maxLevel = 45, species = "SENTRET" },
        { minLevel = 38, maxLevel = 45, species = "FURRET" },
        { minLevel = 38, maxLevel = 45, species = "SPEAROW" },
        { minLevel = 38, maxLevel = 45, species = "FEAROW" },
        { minLevel = 38, maxLevel = 45, species = "SPEAROW" },
        { minLevel = 38, maxLevel = 45, species = "FEAROW" },
        { minLevel = 38, maxLevel = 45, species = "ODDISH" },
        { minLevel = 38, maxLevel = 45, species = "ODDISH" },
        { minLevel = 38, maxLevel = 45, species = "GLOOM" },
        { minLevel = 38, maxLevel = 45, species = "LINOONE" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 25, maxLevel = 35, species = "GYARADOS" },
        { minLevel = 25, maxLevel = 35, species = "SEADRA" },
        { minLevel = 25, maxLevel = 35, species = "KINGLER" },
        { minLevel = 25, maxLevel = 35, species = "QWILFISH" },
        { minLevel = 25, maxLevel = 35, species = "CORSOLA" },
      }
    },
  },
  RUIN_VALLEY = {
    aliases = { "3:59", "3_59", "SixIsland_RuinValley", "FR_SIX_ISLAND_RUIN_VALLEY" },
    dexArea = "DEX_AREA_RUIN_VALLEY",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 40, maxLevel = 48, species = "NATU" },
        { minLevel = 40, maxLevel = 48, species = "XATU" },
        { minLevel = 40, maxLevel = 48, species = "NATU" },
        { minLevel = 40, maxLevel = 48, species = "XATU" },
        { minLevel = 40, maxLevel = 48, species = "YANMA" },
        { minLevel = 40, maxLevel = 48, species = "WOBBUFFET", heldItem = 221 },
        { minLevel = 40, maxLevel = 48, species = "DUNSPARCE" },
        { minLevel = 40, maxLevel = 48, species = "CLAYDOL" },
        { minLevel = 40, maxLevel = 48, species = "MEDICHAM" },
        { minLevel = 40, maxLevel = 48, species = "KECLEON" },
        { minLevel = 40, maxLevel = 48, species = "ABSOL" },
        { minLevel = 40, maxLevel = 48, species = "ABSOL" },
      }
    },
  },
  GREEN_PATH = {
    aliases = { "3:60", "3_60", "SixIsland_GreenPath", "FR_SIX_ISLAND_GREEN_PATH" },
    dexArea = "DEX_AREA_GREEN_PATH",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 38, maxLevel = 45, species = "BELLSPROUT" },
        { minLevel = 38, maxLevel = 45, species = "WEEPINBELL" },
        { minLevel = 38, maxLevel = 45, species = "BELLSPROUT" },
        { minLevel = 38, maxLevel = 45, species = "WEEPINBELL" },
        { minLevel = 38, maxLevel = 45, species = "PIDGEOTTO" },
        { minLevel = 38, maxLevel = 45, species = "PSYDUCK" },
        { minLevel = 38, maxLevel = 45, species = "PIDGEOTTO" },
        { minLevel = 38, maxLevel = 45, species = "PSYDUCK" },
        { minLevel = 38, maxLevel = 45, species = "SLOWPOKE" },
        { minLevel = 38, maxLevel = 45, species = "SLOWPOKE" },
        { minLevel = 38, maxLevel = 45, species = "SLOWBRO" },
        { minLevel = 38, maxLevel = 45, species = "SLOWBRO" },
      }
    },
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GYARADOS" },
        { minLevel = 35, maxLevel = 45, species = "SEADRA" },
        { minLevel = 35, maxLevel = 45, species = "QWILFISH" },
        { minLevel = 35, maxLevel = 45, species = "CORSOLA" },
        { minLevel = 35, maxLevel = 45, species = "RELICANTH" },
      }
    },
  },
  OUTCAST_ISLAND = {
    aliases = { "3:61", "3_61", "SixIsland_OutcastIsland", "FR_SIX_ISLAND_OUTCAST_ISLAND" },
    dexArea = "DEX_AREA_OUTCAST_ISLAND",
    region = "sevii",
    water = {
      rate = 4,
      slots = {
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "TENTACOOL" },
        { minLevel = 15, maxLevel = 30, species = "WINGULL" },
        { minLevel = 15, maxLevel = 30, species = "PELIPPER" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 10, maxLevel = 20, species = "MAGIKARP" },
        { minLevel = 10, maxLevel = 20, species = "HORSEA" },
        { minLevel = 10, maxLevel = 20, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GYARADOS" },
        { minLevel = 35, maxLevel = 45, species = "SEADRA" },
        { minLevel = 35, maxLevel = 45, species = "QWILFISH" },
        { minLevel = 35, maxLevel = 45, species = "CORSOLA" },
        { minLevel = 35, maxLevel = 45, species = "RELICANTH" },
      }
    },
  },
  DOTTED_HOLE = {
    aliases = { "1:115", "1_115", "SixIsland_DottedHole_1F", "FR_SIX_ISLAND_DOTTED_HOLE_1F" },
    dexArea = "DEX_AREA_DOTTED_HOLE",
    region = "sevii",
    land = {
      rate = 10,
      slots = {
        { minLevel = 42, maxLevel = 50, species = "BALTOY" },
        { minLevel = 42, maxLevel = 50, species = "CLAYDOL" },
        { minLevel = 42, maxLevel = 50, species = "BALTOY" },
        { minLevel = 42, maxLevel = 50, species = "CLAYDOL" },
        { minLevel = 42, maxLevel = 50, species = "DUSKULL" },
        { minLevel = 42, maxLevel = 50, species = "DUSCLOPS" },
        { minLevel = 42, maxLevel = 50, species = "DUSKULL" },
        { minLevel = 42, maxLevel = 50, species = "DUSCLOPS" },
        { minLevel = 45, maxLevel = 48, species = "BELDUM" },
        { minLevel = 45, maxLevel = 48, species = "BELDUM" },
        { minLevel = 46, maxLevel = 50, species = "BELDUM" },
        { minLevel = 46, maxLevel = 50, species = "BELDUM" },
      }
    },
  },
  ALTERING_CAVE = {
    aliases = { "1:123", "1_123", "SixIsland_AlteringCave", "FR_SIX_ISLAND_ALTERING_CAVE" },
    dexArea = "DEX_AREA_ALTERING_CAVE",
    region = "sevii",
    land = {
      rate = 15,
      slots = {
        { minLevel = 38, maxLevel = 45, species = "MAREEP" },
        { minLevel = 38, maxLevel = 45, species = "PINECO" },
        { minLevel = 38, maxLevel = 45, species = "MAREEP" },
        { minLevel = 38, maxLevel = 45, species = "PINECO" },
        { minLevel = 38, maxLevel = 45, species = "HOUNDOUR" },
        { minLevel = 38, maxLevel = 45, species = "TEDDIURSA" },
        { minLevel = 38, maxLevel = 45, species = "HOUNDOUR" },
        { minLevel = 38, maxLevel = 45, species = "TEDDIURSA" },
        { minLevel = 38, maxLevel = 45, species = "AIPOM" },
        { minLevel = 38, maxLevel = 45, species = "AIPOM" },
        { minLevel = 38, maxLevel = 45, species = "STANTLER" },
        { minLevel = 38, maxLevel = 45, species = "SMEARGLE" },
      }
    },
  },
  CANYON_ENTRANCE = {
    aliases = { "3:63", "3_63", "SevenIsland_CanyonEntrance", "FR_SEVEN_ISLAND_CANYON_ENTRANCE" },
    dexArea = "DEX_AREA_CANYON_ENTRANCE",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 42, maxLevel = 48, species = "PHANPY" },
        { minLevel = 42, maxLevel = 48, species = "DONPHAN" },
        { minLevel = 42, maxLevel = 48, species = "PHANPY" },
        { minLevel = 42, maxLevel = 48, species = "DONPHAN" },
        { minLevel = 42, maxLevel = 48, species = "SPEAROW" },
        { minLevel = 42, maxLevel = 48, species = "FEAROW" },
        { minLevel = 42, maxLevel = 48, species = "GEODUDE" },
        { minLevel = 42, maxLevel = 48, species = "GRAVELER" },
        { minLevel = 42, maxLevel = 48, species = "SUDOWOODO" },
        { minLevel = 42, maxLevel = 48, species = "SPINDA" },
        { minLevel = 42, maxLevel = 48, species = "SPINDA" },
        { minLevel = 42, maxLevel = 48, species = "SPINDA" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  SEVAULT_CANYON = {
    aliases = { "3:64", "3_64", "SevenIsland_SevaultCanyon", "FR_SEVEN_ISLAND_SEVAULT_CANYON" },
    dexArea = "DEX_AREA_SEVAULT_CANYON",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 46, maxLevel = 54, species = "SKARMORY" },
        { minLevel = 46, maxLevel = 54, species = "DONPHAN" },
        { minLevel = 46, maxLevel = 54, species = "SKARMORY" },
        { minLevel = 46, maxLevel = 54, species = "DONPHAN" },
        { minLevel = 46, maxLevel = 54, species = "LARVITAR" },
        { minLevel = 46, maxLevel = 54, species = "PUPITAR" },
        { minLevel = 46, maxLevel = 54, species = "LAIRON" },
        { minLevel = 46, maxLevel = 54, species = "ZANGOOSE" },
        { minLevel = 48, maxLevel = 52, species = "SEVIPER" },
        { minLevel = 48, maxLevel = 52, species = "ABSOL" },
        { minLevel = 50, maxLevel = 54, species = "VIBRAVA" },
        { minLevel = 50, maxLevel = 54, species = "VIBRAVA" },
      }
    },
    rockSmash = {
      rate = 60,
      slots = {
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "GRAVELER" },
        { minLevel = 35, maxLevel = 45, species = "NOSEPASS" },
        { minLevel = 35, maxLevel = 45, species = "SHUCKLE" },
      }
    },
  },
  TANOBY_RUINS = {
    aliases = { "3:65", "3_65", "SevenIsland_TanobyRuins", "FR_SEVEN_ISLAND_TANOBY_RUINS" },
    dexArea = "DEX_AREA_TANOBY_RUINS",
    region = "sevii",
    water = {
      rate = 4,
      slots = {
        { minLevel = 40, maxLevel = 50, species = "TENTACOOL" },
        { minLevel = 40, maxLevel = 50, species = "WINGULL" },
        { minLevel = 40, maxLevel = 50, species = "MANTINE" },
        { minLevel = 40, maxLevel = 50, species = "WAILMER" },
        { minLevel = 40, maxLevel = 50, species = "RELICANTH" },
      }
    },
    oldRod = {
      rate = 70,
      slots = {
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
        { minLevel = 5, maxLevel = 10, species = "MAGIKARP" },
      }
    },
    goodRod = {
      rate = 60,
      slots = {
        { minLevel = 20, maxLevel = 30, species = "REMORAID" },
        { minLevel = 20, maxLevel = 30, species = "HORSEA" },
        { minLevel = 20, maxLevel = 30, species = "KRABBY" },
      }
    },
    superRod = {
      rate = 40,
      slots = {
        { minLevel = 40, maxLevel = 50, species = "OCTILLERY" },
        { minLevel = 40, maxLevel = 50, species = "QWILFISH" },
        { minLevel = 40, maxLevel = 50, species = "RELICANTH" },
        { minLevel = 40, maxLevel = 50, species = "SEADRA" },
        { minLevel = 40, maxLevel = 50, species = "SHARPEDO" },
      }
    },
  },
  MONEAN_CHAMBER = {
    aliases = { "2:27", "2_27", "SevenIsland_TanobyRuins_MoneanChamber", "FR_SevenIsland_TanobyRuins_MoneanChamber" },
    dexArea = "DEX_AREA_TANOBY_CHAMBER",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
      }
    },
  },
  LIPTOO_CHAMBER = {
    aliases = { "2:28", "2_28", "SevenIsland_TanobyRuins_LiptooChamber", "FR_SevenIsland_TanobyRuins_LiptooChamber" },
    dexArea = "DEX_AREA_TANOBY_CHAMBER",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
      }
    },
  },
  WEEPTH_CHAMBER = {
    aliases = { "2:29", "2_29", "SevenIsland_TanobyRuins_WeepthChamber", "FR_SevenIsland_TanobyRuins_WeepthChamber" },
    dexArea = "DEX_AREA_TANOBY_CHAMBER",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
      }
    },
  },
  DILFORD_CHAMBER = {
    aliases = { "2:30", "2_30", "SevenIsland_TanobyRuins_DilfordChamber", "FR_SevenIsland_TanobyRuins_DilfordChamber" },
    dexArea = "DEX_AREA_TANOBY_CHAMBER",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
      }
    },
  },
  SCUFIB_CHAMBER = {
    aliases = { "2:31", "2_31", "SevenIsland_TanobyRuins_ScufibChamber", "FR_SevenIsland_TanobyRuins_ScufibChamber" },
    dexArea = "DEX_AREA_TANOBY_CHAMBER",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
      }
    },
  },
  RIXY_CHAMBER = {
    aliases = { "2:32", "2_32", "SevenIsland_TanobyRuins_RixyChamber", "FR_SevenIsland_TanobyRuins_RixyChamber" },
    dexArea = "DEX_AREA_TANOBY_CHAMBER",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
      }
    },
  },
  VIAPOIS_CHAMBER = {
    aliases = { "2:33", "2_33", "SevenIsland_TanobyRuins_ViapoisChamber", "FR_SevenIsland_TanobyRuins_ViapoisChamber" },
    dexArea = "DEX_AREA_TANOBY_CHAMBER",
    region = "sevii",
    land = {
      rate = 20,
      slots = {
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
        { minLevel = 40, maxLevel = 50, species = "UNOWN" },
      }
    },
  },
}

EncountersGame3.MAP_TABLES = MAP_TABLES
EncountersGame3.toSpeciesId = toSpeciesId
EncountersGame3.toSpeciesName = toSpeciesName
EncountersGame3.GBA_SPECIES_NAMES = GBA_SPECIES_NAMES

-- Resolve an encounter table for any map key / alias
function EncountersGame3.getTableForMap(mapId, mode, opts)
  opts = opts or {}
  local s = tostring(mapId or "")
  local clean = s:gsub("FR_", ""):gsub("_", ""):upper()

  local found = nil
  for k, def in pairs(MAP_TABLES) do
    if k == clean or k == s then
      found = def
      break
    end
    for _, alias in ipairs(def.aliases or {}) do
      if alias == s or alias == clean or alias:upper() == s:upper() then
        found = def
        break
      end
    end
    if found then break end
  end

  if not found then return nil end

  local res = {}

  local function build_slots(origSlots, rate, count)
    local minL = origSlots[1].minLevel or 3
    local maxL = origSlots[#origSlots].maxLevel or 6

    if mode == "pure_random" then
      local pool = poolFor(opts)
      local seed = opts.seed or 12345
      local slots = {}
      for i = 1, count do
        seed = (seed * 1103515245 + 12345) % 0x7FFFFFFF
        slots[i] = {
          minLevel = minL,
          maxLevel = maxL,
          species = pool[(seed % #pool) + 1]
        }
      end
      return { rate = rate, slots = slots }
    elseif mode == "full_random" then
      local pool = poolFor(opts)
      local legs = (opts.legends or opts.legendsInMix) and getLegendaryPool() or nil
      local slots = {}
      for i = 1, count do
        local orig = origSlots[i] or origSlots[#origSlots]
        local sp
        if legs and i % 4 == 0 then
          sp = legs[((i * 7) % #legs) + 1]
        else
          sp = pool[((i * 19) % #pool) + 1]
        end
        slots[i] = {
          minLevel = orig.minLevel,
          maxLevel = orig.maxLevel,
          species = sp
        }
      end
      return { rate = rate, slots = slots }
    else
      local slots = {}
      for i = 1, count do
        local orig = origSlots[i] or origSlots[#origSlots]
        slots[i] = {
          minLevel = orig.minLevel,
          maxLevel = orig.maxLevel,
          species = toSpeciesId(orig.species),
          heldItem = orig.heldItem
        }
      end
      return { rate = rate, slots = slots }
    end
  end

  if found.land and found.land.slots then
    res.land = build_slots(found.land.slots, found.land.rate, 12)
  end
  if found.water and found.water.slots then
    res.water = build_slots(found.water.slots, found.water.rate, 5)
  end
  if found.oldRod and found.oldRod.slots then
    res.oldRod = build_slots(found.oldRod.slots, found.oldRod.rate, 2)
  end
  if found.goodRod and found.goodRod.slots then
    res.goodRod = build_slots(found.goodRod.slots, found.goodRod.rate, 3)
  end
  if found.superRod and found.superRod.slots then
    res.superRod = build_slots(found.superRod.slots, found.superRod.rate, 5)
  end
  if found.rockSmash and found.rockSmash.slots then
    res.rockSmash = build_slots(found.rockSmash.slots, found.rockSmash.rate, 5)
  end

  return res
end

-- Synchronize active encounter tables to PokedexData wild areas
function EncountersGame3.syncPokedexAreas(mode, opts)
  local okPd, PokedexData = pcall(require, "src.core.game3.pokedex_data")
  if not (okPd and PokedexData and PokedexData.getWildAreasForSpecies) then return end

  local kantoAreas = {}
  local seviiAreas = {}
  local fullAreas = {}

  local function addArea(mapTable, sp, areaKey)
    if not sp or not areaKey then return end
    local spId = toSpeciesId(sp)
    if not spId or spId == 0 then return end

    local list = mapTable[spId] or {}
    local exists = false
    for _, a in ipairs(list) do
      if a == areaKey then exists = true; break end
    end
    if not exists then
      list[#list + 1] = areaKey
      mapTable[spId] = list
    end
  end

  for _, def in pairs(MAP_TABLES) do
    local tableObj = EncountersGame3.getTableForMap(def.aliases[1], mode, opts)
    if tableObj and def.dexArea then
      local isSevii = (def.region == "sevii")
      for _, kind in ipairs({ "land", "water", "oldRod", "goodRod", "superRod", "rockSmash" }) do
        local slotData = tableObj[kind]
        if slotData and slotData.slots then
          for _, slot in ipairs(slotData.slots) do
            if isSevii then
              addArea(seviiAreas, slot.species, def.dexArea)
            else
              addArea(kantoAreas, slot.species, def.dexArea)
            end
            addArea(fullAreas, slot.species, def.dexArea)
          end
        end
      end
    end
  end

  EncountersGame3._dexAreas = { kanto = kantoAreas, sevii = seviiAreas, full = fullAreas }
  EncountersGame3.installDexHooks()
end

-- Populate tables across all aliases in Encounters._tables
function EncountersGame3.apply(mod, mode, opts)
  EncountersGame3.liveMode = mode or "curated"
  EncountersGame3.liveLegends = opts and (opts.legends or opts.legendsInMix) and true or false
  local okE, Encounters = pcall(require, "src.core.game3.encounters")
  if not (okE and Encounters) then return end

  Encounters.ensureLoaded()

  for _, def in pairs(MAP_TABLES) do
    local tableObj = EncountersGame3.getTableForMap(def.aliases[1], mode, opts)
    if tableObj then
      for _, alias in ipairs(def.aliases) do
        local existing = Encounters._tables[alias] or {}
        if tableObj.land then existing.land = tableObj.land end
        if tableObj.water then existing.water = tableObj.water end
        if tableObj.oldRod then existing.oldRod = tableObj.oldRod end
        if tableObj.goodRod then existing.goodRod = tableObj.goodRod end
        if tableObj.superRod then existing.superRod = tableObj.superRod end
        if tableObj.rockSmash then existing.rockSmash = tableObj.rockSmash end
        Encounters._tables[alias] = existing
      end
    end
  end

  -- Sync Pokedex Town Map area lookup
  EncountersGame3.syncPokedexAreas(mode, opts)

  if mod and mod.log then
    mod.log:info("Gen 3 wild encounters applied across Kanto & Sevii (mode: %s)", mode or "curated")
  end
end

-- ============================================================================
-- Installation & Runtime Hook Wrapping
-- ============================================================================
local installed = false
local dexHooksInstalled = false

function EncountersGame3.installDexHooks()
  if dexHooksInstalled then return end
  local okPd, PokedexData = pcall(require, "src.core.game3.pokedex_data")
  local okPx, Pokedex = pcall(require, "src.ui.game3.pokedex")
  local okCh, Chrome = pcall(require, "src.ui.game3.pokedex_chrome")
  if not (okPd and PokedexData and okPx and Pokedex and okCh and Chrome) then return end
  dexHooksInstalled = true

  local origAreas = PokedexData.getWildAreasForSpecies
  function PokedexData.getWildAreasForSpecies(speciesId, regionKey)
    local sp = tonumber(speciesId) or 1
    local bags = EncountersGame3._dexAreas
    if bags then
      if regionKey == "sevii" then return bags.sevii[sp] or {} end
      if regionKey == "kanto" then
        local list = bags.kanto[sp]
        if list and #list > 0 then return list end
      end
      local full = bags.full[sp]
      if full and #full > 0 and regionKey == nil then return full end
    end
    return origAreas(speciesId)
  end

  local origKey = PokedexData.getAreaMapKey
  if type(origKey) == "function" then
    function PokedexData.getAreaMapKey(area)
      local key = origKey(area)
      if Pokedex.isOpen and Pokedex.isOpen() and Pokedex._areaRegion == "sevii" and type(key) == "string" then
        if key == "kanto" then return "sevii" end
        return "kanto"
      end
      return key
    end
  end

  local origMap = Chrome.drawMap
  function Chrome.drawMap(mapKey, ...)
    if mapKey == "kanto" and Pokedex._areaRegion == "sevii" then mapKey = "sevii" end
    return origMap(mapKey, ...)
  end

  local origInput = Pokedex.handleInput
  function Pokedex.handleInput(input)
    if Pokedex.screen == "data" and Pokedex.dataPage == 2 and input and input.wasPressed and input:wasPressed("select") then
      Pokedex._areaRegion = (Pokedex._areaRegion == "sevii") and "kanto" or "sevii"
      return
    end
    return origInput(input)
  end

  local origDraw = Pokedex.draw
  function Pokedex.draw(...)
    origDraw(...)
    if Pokedex.screen == "data" and Pokedex.dataPage == 2 and Pokedex.isOpen and Pokedex.isOpen() then
      Chrome.drawControlInfo("SELECT: REGION", 124, 146)
    end
  end
end

function EncountersGame3.install(mod)
  if installed then return end
  installed = true

  local mode = "curated"
  local legends = false
  if mod and mod.options then
    if mod.options:get("pure_spawn_random") or mod.options:get(Host.optionKey("pure_spawn_random")) then
      mode = "pure_random"
    elseif mod.options:get("full_spawn_random") or mod.options:get(Host.optionKey("full_spawn_random")) then
      mode = "full_random"
    end
    if mod.options:get("legends_in_mix") or mod.options:get(Host.optionKey("legends_in_mix")) then
      legends = true
    end
  end

  local seed = 12345
  if mode == "pure_random" and mod.save and mod.save.get then
    local saved = tonumber(mod.save:get("g3_pure_seed"))
    if saved and saved > 0 then seed = saved end
  end
  EncountersGame3.apply(mod, mode, { seed = seed, legends = legends })

  -- Register encounter.species / encounter.roll hook
  if mod and mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("encounter.species", function(vanilla, enc, ctx)
      if enc and ctx and ctx.mapId then
        local mode = EncountersGame3.liveMode or "curated"
        local legends = EncountersGame3.liveLegends and true or false
        local t = EncountersGame3.getTableForMap(ctx.mapId, mode, { legends = legends })
        if t and t.land and t.land.slots then
          local slotIdx = (Rng.Random() % #t.land.slots) + 1
          local slot = t.land.slots[slotIdx]
          if slot then
            enc.species = slot.species
            enc.speciesId = slot.species
            enc.level = Rng.compat(slot.minLevel, slot.maxLevel)
            enc.item = slot.heldItem
          end
        end
      end
      return enc
    end, 50, "Kanto-Reforged")
  end
end

return EncountersGame3
