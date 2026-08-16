
-- tier-2 set pieces (Nugget Bridge light spice, gym trainers, Mt Moon, …), and
-- light trash mixes. Gym/E4: Gen2 swap + Gen3 add (Blaine: Gen3 front only).
-- Rival: continuity (League finals debut at RIVAL3 only). Ace berries on
-- gym/E4 closers.

local Trainers = {}

-- { class, partyIndex (1-based), slotOrAction, species, level? }
-- slotOrAction: 1-based slot index, "add" (insert before ace), or "add_front".
-- Levels default to the slot's vanilla level on swaps; required on adds.
local MIX = {
  -- Gym leaders: Gen2 swap + Gen3 add (before ace), except Blaine
  { "OPP_BROCK", 1, 1, "SUDOWOODO" },
  { "OPP_BROCK", 1, "add", "ARON", 13 },
  { "OPP_MISTY", 1, 1, "MARILL" },
  { "OPP_MISTY", 1, "add", "CORPHISH", 19 },
  { "OPP_LT_SURGE", 1, 1, "FLAAFFY" },
  { "OPP_LT_SURGE", 1, "add", "ELECTRIKE", 20 },
  { "OPP_ERIKA", 1, 2, "BELLOSSOM" },
  { "OPP_ERIKA", 1, "add", "BRELOOM", 26 },
  { "OPP_KOGA", 1, 3, "CROBAT" },
  { "OPP_KOGA", 1, "add", "SEVIPER", 39 },
  { "OPP_SABRINA", 1, 3, "XATU" },
  { "OPP_SABRINA", 1, "add", "GARDEVOIR", 40 },
  -- Blaine: preserve Growlithe→Arcanine and Ponyta→Rapidash; Gen3 lead only
  { "OPP_BLAINE", 1, "add_front", "TORKOAL", 40 },
  { "OPP_GIOVANNI", 3, 2, "DONPHAN" },
  { "OPP_GIOVANNI", 3, "add", "FLYGON", 46 },

  -- Elite Four: one Gen2 swap + one Gen3 before ace
  { "OPP_LORELEI", 1, 1, "PILOSWINE" },
  { "OPP_LORELEI", 1, "add", "WALREIN", 55 },
  { "OPP_BRUNO", 1, 1, "STEELIX" },
  { "OPP_BRUNO", 1, "add", "HARIYAMA", 56 },
  { "OPP_AGATHA", 1, 2, "CROBAT" },
  { "OPP_AGATHA", 1, "add", "BANETTE", 58 },
  { "OPP_LANCE", 1, 1, "KINGDRA" },
  { "OPP_LANCE", 1, "add", "SALAMENCE", 60 },

  -- Rival continuity: Lairon late mid → Aggron League (all 3 paths)
  { "OPP_RIVAL2", 10, 2, "LAIRON" },
  { "OPP_RIVAL2", 11, 2, "LAIRON" },
  { "OPP_RIVAL2", 12, 2, "LAIRON" },
  { "OPP_RIVAL3", 1, 3, "AGGRON" },
  { "OPP_RIVAL3", 2, 3, "AGGRON" },
  { "OPP_RIVAL3", 3, 3, "AGGRON" },

  -- Fire coverage (Blastoise rival): Houndour mid → Houndoom League
  { "OPP_RIVAL2", 4, 2, "HOUNDOUR" },
  { "OPP_RIVAL2", 7, 2, "HOUNDOUR" },
  { "OPP_RIVAL2", 10, 3, "HOUNDOUR" },
  { "OPP_RIVAL3", 1, 4, "HOUNDOOM" },

  -- Water coverage (Venusaur rival): Carvanha mid → Sharpedo League
  { "OPP_RIVAL2", 5, 2, "CARVANHA" },
  { "OPP_RIVAL2", 8, 2, "CARVANHA" },
  { "OPP_RIVAL2", 11, 3, "CARVANHA" },
  { "OPP_RIVAL3", 2, 4, "SHARPEDO" },

  -- Dragon coverage (Charizard rival): Horsea → Seadra → Kingdra League
  { "OPP_RIVAL2", 6, 3, "HORSEA" },
  { "OPP_RIVAL2", 9, 3, "SEADRA" },
  { "OPP_RIVAL2", 12, 4, "SEADRA" },
  { "OPP_RIVAL3", 3, 5, "KINGDRA" },

  -- Trash / route trainers — light one-slot mixes
  { "OPP_BUG_CATCHER", 1, 1, "SPINARAK" },
  { "OPP_BUG_CATCHER", 5, 4, "LEDYBA" },
  { "OPP_HIKER", 1, 1, "ARON" },
  { "OPP_HIKER", 5, 1, "LARVITAR" },
  { "OPP_YOUNGSTER", 1, 2, "MAREEP" },
  { "OPP_LASS", 5, 1, "SEEDOT" },
  { "OPP_LASS", 5, 2, "LOTAD" },
  { "OPP_JR_TRAINER_F", 5, 1, "ROSELIA" },
  { "OPP_ROCKET", 5, 2, "SABLEYE" },
  { "OPP_COOLTRAINER_M", 1, 1, "PUPITAR" },
  { "OPP_COOLTRAINER_F", 6, 1, "BELLOSSOM" },

  -- ===== Tier-2 cherry picks (heavier / full Gen 2–3 parties) =====
  -- Nugget Bridge (Route 24): mostly Gen 1 nostalgia, one Gen 2–3 spice
  -- per mixed fight. Bug Catcher #9 and Jr Trainer #3 stay fully vanilla.
  { "OPP_LASS", 8, 2, "MARILL" },
  { "OPP_YOUNGSTER", 4, 1, "ZIGZAGOON" },
  { "OPP_LASS", 7, 1, "TAILLOW" },
  { "OPP_JR_TRAINER_M", 2, 2, "ARON" },
  { "OPP_ROCKET", 6, 1, "POOCHYENA" },

  -- Pewter Gym Jr Trainer: full rock/ground Gen 2–3
  { "OPP_JR_TRAINER_M", 1, 1, "PHANPY" },
  { "OPP_JR_TRAINER_M", 1, 2, "ARON" },

  -- Cerulean Gym trainers: full water Gen 2–3
  { "OPP_JR_TRAINER_F", 1, 1, "LOTAD" },
  { "OPP_SWIMMER", 1, 1, "CORPHISH" },
  { "OPP_SWIMMER", 1, 2, "CLAMPERL" },

  -- Vermilion Gym: full electric Gen 2–3 on Rocker + Sailor
  { "OPP_ROCKER", 1, 1, "ELECTRIKE" },
  { "OPP_ROCKER", 1, 2, "MAREEP" },
  { "OPP_ROCKER", 1, 3, "PLUSLE" },
  { "OPP_SAILOR", 8, 1, "CHINCHOU" },
  { "OPP_SAILOR", 8, 2, "ELECTRIKE" },

  -- Celadon Gym: full grass Gen 2–3 on a Beauty + Cooltrainer + Lass
  { "OPP_BEAUTY", 1, 1, "SEEDOT" },
  { "OPP_BEAUTY", 1, 2, "ROSELIA" },
  { "OPP_BEAUTY", 1, 3, "LOTAD" },
  { "OPP_BEAUTY", 1, 4, "SHROOMISH" },
  { "OPP_LASS", 17, 1, "SUNKERN" },
  { "OPP_LASS", 17, 2, "ROSELIA" },
  { "OPP_COOLTRAINER_F", 1, 1, "SKIPLOOM" },
  { "OPP_COOLTRAINER_F", 1, 2, "ROSELIA" },
  { "OPP_COOLTRAINER_F", 1, 3, "BAYLEEF" },

  -- Mt Moon Rockets + Super Nerd: heavier dark/bug/poison Gen 2–3
  { "OPP_ROCKET", 1, 1, "POOCHYENA" },
  { "OPP_ROCKET", 1, 2, "MURKROW" },
  { "OPP_ROCKET", 2, 1, "NINCADA" },
  { "OPP_ROCKET", 2, 2, "ZIGZAGOON" },
  { "OPP_ROCKET", 2, 3, "ZUBAT" },
  { "OPP_ROCKET", 3, 1, "SPINARAK" },
  { "OPP_ROCKET", 3, 2, "POOCHYENA" },
  { "OPP_ROCKET", 4, 1, "MIGHTYENA" },
  { "OPP_SUPER_NERD", 2, 1, "GULPIN" },
  { "OPP_SUPER_NERD", 2, 2, "ELECTRIKE" },
  { "OPP_SUPER_NERD", 2, 3, "KOFFING" },

  -- Fighting Dojo Blackbelt #2: full Fighting Gen 3
  { "OPP_BLACKBELT", 2, 1, "MAKUHITA" },
  { "OPP_BLACKBELT", 2, 2, "MEDITITE" },
  { "OPP_BLACKBELT", 2, 3, "HARIYAMA" },

  -- Tower channelers + early Bird Keeper showcase
  { "OPP_CHANNELER", 5, 1, "SHUPPET" },
  { "OPP_CHANNELER", 14, 1, "MISDREAVUS" },
  { "OPP_BIRD_KEEPER", 1, 1, "TAILLOW" },
  { "OPP_BIRD_KEEPER", 1, 2, "SWELLOW" },

  -- ===== Tier-2 pass 2: late gyms, Tower 7F, travel set pieces =====
  -- Saffron Gym Psychic: full Psychic Gen 2–3
  { "OPP_PSYCHIC_TR", 1, 1, "KIRLIA" },
  { "OPP_PSYCHIC_TR", 1, 2, "SPOINK" },
  { "OPP_PSYCHIC_TR", 1, 3, "GIRAFARIG" },
  { "OPP_PSYCHIC_TR", 1, 4, "XATU" },

  -- Fuchsia Gym: Juggler + Tamer heavier poison/psychic Gen 2–3
  { "OPP_JUGGLER", 3, 1, "SPOINK" },
  { "OPP_JUGGLER", 3, 2, "WOBBUFFET" },
  { "OPP_JUGGLER", 3, 3, "KIRLIA" },
  { "OPP_JUGGLER", 3, 4, "SPOINK" },
  { "OPP_TAMER", 2, 1, "SEVIPER" },
  { "OPP_TAMER", 2, 2, "DONPHAN" },
  { "OPP_TAMER", 2, 3, "SEVIPER" },

  -- Cinnabar Gym: fire Gen 2–3 showcase
  { "OPP_SUPER_NERD", 10, 1, "NUMEL" },
  { "OPP_SUPER_NERD", 10, 2, "SLUGMA" },
  { "OPP_SUPER_NERD", 10, 3, "HOUNDOUR" },
  { "OPP_SUPER_NERD", 10, 4, "TORKOAL" },
  { "OPP_BURGLAR", 4, 1, "HOUNDOUR" },
  { "OPP_BURGLAR", 4, 2, "NUMEL" },
  { "OPP_BURGLAR", 4, 3, "MAGCARGO" },

  -- Viridian Gym Blackbelt + Fighting Dojo master (Hitmontop = Gen2 third Hitmon)
  { "OPP_BLACKBELT", 8, 1, "HARIYAMA" },
  { "OPP_BLACKBELT", 8, 2, "MEDITITE" },
  { "OPP_BLACKBELT", 8, 3, "HARIYAMA" },
  { "OPP_BLACKBELT", 1, 2, "HITMONTOP" },

  -- Pokemon Tower 7F Rockets + 6F Channeler gauntlet
  { "OPP_ROCKET", 19, 1, "MURKROW" },
  { "OPP_ROCKET", 19, 2, "ZUBAT" },
  { "OPP_ROCKET", 19, 3, "CROBAT" },
  { "OPP_ROCKET", 20, 1, "GULPIN" },
  { "OPP_ROCKET", 20, 2, "SPOINK" },
  { "OPP_ROCKET", 21, 1, "SPINARAK" },
  { "OPP_ROCKET", 21, 2, "ZIGZAGOON" },
  { "OPP_ROCKET", 21, 3, "MIGHTYENA" },
  { "OPP_ROCKET", 21, 4, "MURKROW" },
  { "OPP_CHANNELER", 19, 1, "SHUPPET" },
  { "OPP_CHANNELER", 19, 2, "DUSKULL" },
  { "OPP_CHANNELER", 19, 3, "MISDREAVUS" },

  -- SS Anne Sailor + Gentleman (avoid Gentleman#3 — shared with Vermilion)
  { "OPP_SAILOR", 4, 1, "CORPHISH" },
  { "OPP_SAILOR", 4, 2, "CLAMPERL" },
  { "OPP_SAILOR", 4, 3, "WINGULL" },
  { "OPP_GENTLEMAN", 5, 1, "HOUNDOUR" },
  { "OPP_GENTLEMAN", 5, 2, "NUMEL" },

  -- Rock Tunnel double-Onix Hiker; Cycling Road Biker; Silph pre-Giovanni
  { "OPP_HIKER", 13, 1, "ONIX" },
  { "OPP_HIKER", 13, 2, "ARON" },
  { "OPP_HIKER", 13, 3, "NOSEPASS" },
  { "OPP_BIKER", 12, 1, "GULPIN" },
  { "OPP_BIKER", 12, 2, "WEEZING" },
  { "OPP_BIKER", 12, 3, "KOFFING" },
  { "OPP_BIKER", 12, 4, "SWALOT" },
  { "OPP_BIKER", 12, 5, "WEEZING" },
  { "OPP_ROCKET", 41, 1, "CUBONE" },
  { "OPP_ROCKET", 41, 2, "SABLEYE" },
  { "OPP_ROCKET", 41, 3, "MAROWAK" },

  -- Victory Road Cooltrainer: Johto starter mids + keep Charizard ace
  { "OPP_COOLTRAINER_M", 5, 1, "BAYLEEF" },
  { "OPP_COOLTRAINER_M", 5, 2, "CROCONAW" },
  { "OPP_COOLTRAINER_M", 5, 3, "QUILAVA" },
}

-- Gen 2 Gym Leaders & Gym Trainers Mix Overhaul
local MIX_GEN2 = {
  -- Lt. Surge (Vermilion Gym - target 55)
  { "OPP_LT_SURGE", 1, 1, "ELECTRIKE", 52 },
  { "OPP_LT_SURGE", 1, 2, "AMPHAROS", 53 },
  { "OPP_LT_SURGE", 1, 3, "MAGNETON", 53 },
  { "OPP_LT_SURGE", 1, "add", "ELECTRODE", 54 },
  { "OPP_LT_SURGE", 1, "add", "MANECTRIC", 54 },
  { "OPP_LT_SURGE", 1, "add", "RAICHU", 55 },

  -- Janine (Fuchsia Gym - target 56)
  { "OPP_KOGA", 1, 1, "ARIADOS", 52 },
  { "OPP_KOGA", 1, 2, "SWALOT", 53 },
  { "OPP_KOGA", 1, 3, "WEEZING", 54 },
  { "OPP_KOGA", 1, "add", "SEVIPER", 54 },
  { "OPP_KOGA", 1, "add", "CROBAT", 55 },
  { "OPP_KOGA", 1, "add", "VENOMOTH", 56 },

  -- Erika (Celadon Gym - target 57)
  { "OPP_ERIKA", 1, 1, "ROSELIA", 53 },
  { "OPP_ERIKA", 1, 2, "JUMPLUFF", 54 },
  { "OPP_ERIKA", 1, 3, "TANGELA", 54 },
  { "OPP_ERIKA", 1, "add", "BRELOOM", 55 },
  { "OPP_ERIKA", 1, "add", "VICTREEBEL", 56 },
  { "OPP_ERIKA", 1, "add", "BELLOSSOM", 57 },

  -- Misty (Cerulean Gym - target 61)
  { "OPP_MISTY", 1, 1, "LANTURN", 57 },
  { "OPP_MISTY", 1, 2, "GOLDUCK", 58 },
  { "OPP_MISTY", 1, "add", "CRAWDAUNT", 59 },
  { "OPP_MISTY", 1, "add", "QUAGSIRE", 59 },
  { "OPP_MISTY", 1, "add", "LAPRAS", 60 },
  { "OPP_MISTY", 1, "add", "STARMIE", 61 },

  -- Sabrina (Saffron Gym - target 62)
  { "OPP_SABRINA", 1, 1, "GIRAFARIG", 58 },
  { "OPP_SABRINA", 1, 2, "MR_MIME", 59 },
  { "OPP_SABRINA", 1, 3, "XATU", 59 },
  { "OPP_SABRINA", 1, "add", "ESPEON", 60 },
  { "OPP_SABRINA", 1, "add", "GARDEVOIR", 61 },
  { "OPP_SABRINA", 1, "add", "ALAKAZAM", 62 },

  -- Brock (Pewter Gym - target 62)
  { "OPP_BROCK", 1, 1, "SUDOWOODO", 58 },
  { "OPP_BROCK", 1, 2, "OMASTAR", 59 },
  { "OPP_BROCK", 1, "add", "KABUTOPS", 59 },
  { "OPP_BROCK", 1, "add", "RHYDON", 60 },
  { "OPP_BROCK", 1, "add", "AGGRON", 61 },
  { "OPP_BROCK", 1, "add", "STEELIX", 62 },

  -- Blaine (Cinnabar Gym - target 63)
  { "OPP_BLAINE", 1, 1, "TORKOAL", 59 },
  { "OPP_BLAINE", 1, 2, "CAMERUPT", 60 },
  { "OPP_BLAINE", 1, 3, "MAGCARGO", 60 },
  { "OPP_BLAINE", 1, "add", "RAPIDASH", 61 },
  { "OPP_BLAINE", 1, "add", "HOUNDOOM", 62 },
  { "OPP_BLAINE", 1, "add", "MAGMAR", 63 },

  -- Blue (Viridian Gym - target 72)
  { "OPP_GIOVANNI", 3, 1, "PIDGEOT", 70 },
  { "OPP_GIOVANNI", 3, 2, "ALAKAZAM", 70 },
  { "OPP_GIOVANNI", 3, 3, "TYRANITAR", 70 },
  { "OPP_GIOVANNI", 3, "add", "GYARADOS", 70 },
  { "OPP_GIOVANNI", 3, "add", "EXEGGUTOR", 71 },
  { "OPP_GIOVANNI", 3, "add", "ARCANINE", 72 },

  -- Kanto Gym Trainers (Levels 50-60 matching gym tiers)
  { "OPP_JR_TRAINER_M", 1, 1, "PHANPY", 56 },
  { "OPP_JR_TRAINER_M", 1, 2, "ARON", 57 },
  { "OPP_JR_TRAINER_F", 1, 1, "LOMBRE", 55 },
  { "OPP_SWIMMER", 1, 1, "CORPHISH", 56 },
  { "OPP_SWIMMER", 1, 2, "CLAMPERL", 57 },
  { "OPP_ROCKER", 1, 1, "MANECTRIC", 50 },
  { "OPP_ROCKER", 1, 2, "FLAAFFY", 51 },
  { "OPP_ROCKER", 1, 3, "PLUSLE", 52 },
  { "OPP_SAILOR", 8, 1, "LANTURN", 51 },
  { "OPP_SAILOR", 8, 2, "ELECTRIKE", 52 },
  { "OPP_BEAUTY", 1, 1, "ROSELIA", 51 },
  { "OPP_BEAUTY", 1, 2, "BRELOOM", 52 },
  { "OPP_BEAUTY", 1, 3, "LOMBRE", 53 },
  { "OPP_PSYCHIC_TR", 1, 1, "KIRLIA", 56 },
  { "OPP_PSYCHIC_TR", 1, 2, "SPOINK", 57 },
  { "OPP_PSYCHIC_TR", 1, 3, "GIRAFARIG", 58 },
  { "OPP_JUGGLER", 3, 1, "SPOINK", 56 },
  { "OPP_JUGGLER", 3, 2, "WOBBUFFET", 57 },
  { "OPP_TAMER", 2, 1, "SEVIPER", 51 },
  { "OPP_TAMER", 2, 2, "DONPHAN", 52 },
  { "OPP_SUPER_NERD", 10, 1, "NUMEL", 57 },
  { "OPP_SUPER_NERD", 10, 2, "CAMERUPT", 58 },
  { "OPP_SUPER_NERD", 10, 3, "TORKOAL", 59 },
  { "OPP_BURGLAR", 4, 1, "HOUNDOOM", 58 },
  { "OPP_BURGLAR", 4, 2, "MAGCARGO", 59 },

  -- Kanto Arrival Zone (Routes 5, 6, 7, 8, 11 — Levels 50-54)
  { "OPP_YOUNGSTER", 1, 1, "LINOONE", 50 },
  { "OPP_YOUNGSTER", 1, 2, "MANECTRIC", 51 },
  { "OPP_PICSICK", 1, 1, "GRANBULL", 51 },
  { "OPP_GAMBLER", 1, 1, "HOUNDOUR", 52 },
  { "OPP_GAMBLER", 1, 2, "LANTURN", 53 },

  -- Eastern Coast & Silence Bridge (Routes 9, 10, 12-15, Rock Tunnel — Levels 54-58)
  { "OPP_BIRD_KEEPER", 1, 1, "PELIPPER", 54 },
  { "OPP_BIRD_KEEPER", 1, 2, "SWELLOW", 55 },
  { "OPP_FISHER", 1, 1, "LANTURN", 55 },
  { "OPP_FISHER", 1, 2, "WHISCASH", 56 },
  { "OPP_HIKER", 1, 1, "CAMERUPT", 56 },
  { "OPP_HIKER", 1, 2, "LAIRON", 57 },
  { "OPP_MANIAC", 1, 1, "ROSELIA", 57 },
  { "OPP_MANIAC", 1, 2, "BRELOOM", 58 },

  -- Western Routes & Cycling Road (Routes 1-4, 16-22, Seafoam — Levels 58-63)
  { "OPP_CUE_BALL", 1, 1, "HARIYAMA", 58 },
  { "OPP_CUE_BALL", 1, 2, "AGGRON", 59 },
  { "OPP_BIKER", 1, 1, "WEEZING", 59 },
  { "OPP_BIKER", 1, 2, "SWALOT", 60 },
  { "OPP_GENTLEMAN", 1, 1, "DODRIO", 60 },
  { "OPP_GENTLEMAN", 1, 2, "SHARPEDO", 61 },

  -- Nugget Bridge Circuit (Route 24/25 — Levels 56-60)
  { "OPP_BUG_CATCHER", 1, 1, "VOLBEAT", 56 },
  { "OPP_BUG_CATCHER", 1, 2, "ILLUMISE", 57 },
  { "OPP_LASS", 1, 1, "ZANGOOSE", 57 },
  { "OPP_LASS", 1, 2, "SEVIPER", 58 },
  { "OPP_ROCKET", 1, 1, "CORPHISH", 59 },
  { "OPP_ROCKET", 1, 2, "GOLDUCK", 60 },

  -- Saffron Fighting Dojo (Levels 60-64)
  { "OPP_BLACKBELT", 1, 1, "HARIYAMA", 60 },
  { "OPP_BLACKBELT", 1, 2, "BRELOOM", 61 },
  { "OPP_BLACKBELT", 2, 1, "MEDICHAM", 62 },
  { "OPP_BLACKBELT", 2, 2, "PRIMEAPE", 63 },
  { "OPP_BLACKBELT", 3, 1, "HITMONLEE", 63 },
  { "OPP_BLACKBELT", 3, 2, "HITMONCHAN", 64 },

  -- Mt. Moon Rival Battle (Levels 75-78)
  { "OPP_RIVAL2", 1, 1, "SNEASEL", 75 },
  { "OPP_RIVAL2", 1, 2, "MAGNETON", 76 },
  { "OPP_RIVAL2", 1, 3, "GENGAR", 76 },
  { "OPP_RIVAL2", 1, 4, "ALAKAZAM", 77 },
  { "OPP_RIVAL2", 1, 5, "GOLBAT", 77 },
  { "OPP_RIVAL2", 1, "add", "TYRANITAR", 78 },
}

-- Ace berries (last slot after MIX adds). Gym + E4 + Rival.
local ACE_BERRIES = {
  { "OPP_BROCK", 1, "BERRY" },
  { "OPP_MISTY", 1, "PECHA_BERRY" },
  { "OPP_LT_SURGE", 1, "CHESTO_BERRY" },
  { "OPP_ERIKA", 1, "RAWST_BERRY" },
  { "OPP_KOGA", 1, "PERSIM_BERRY" },
  { "OPP_SABRINA", 1, "CHERI_BERRY" },
  { "OPP_BLAINE", 1, "PERSIM_BERRY" },
  { "OPP_GIOVANNI", 3, "CHERI_BERRY" },
  { "OPP_LORELEI", 1, "CHERI_BERRY" },
  { "OPP_BRUNO", 1, "CHESTO_BERRY" },
  { "OPP_AGATHA", 1, "LUM_BERRY" },
  { "OPP_LANCE", 1, "LUM_BERRY" },
}

local ACE_BERRIES_GEN2 = {
  { "OPP_LT_SURGE", 1, "CHESTO_BERRY" },
  { "OPP_KOGA", 1, "PERSIM_BERRY" },
  { "OPP_ERIKA", 1, "RAWST_BERRY" },
  { "OPP_MISTY", 1, "PECHA_BERRY" },
  { "OPP_SABRINA", 1, "CHERI_BERRY" },
  { "OPP_BROCK", 1, "BERRY" },
  { "OPP_BLAINE", 1, "PERSIM_BERRY" },
  { "OPP_GIOVANNI", 3, "CHERI_BERRY" },
  { "OPP_RIVAL2", 1, "LUM_BERRY" },
}

Trainers.MIX = MIX
Trainers.MIX_GEN2 = MIX_GEN2
Trainers.ACE_BERRIES = ACE_BERRIES
Trainers.ACE_BERRIES_GEN2 = ACE_BERRIES_GEN2

-- Stock engine schemas only allow { level, species } on trainer party slots.
-- Ace berries (and optional custom moves) need heldItem/moves accepted at
-- patch time, and applied when BattleState.newTrainer builds the enemy party.
-- These used to live as local engine forks; keep them in the mod instead.
function Trainers.extendSchemas()
  local Schemas = require("src.mods.Schemas")
  local f = Schemas.f
  local parties = Schemas.REGISTRIES.trainers
    and Schemas.REGISTRIES.trainers.fields
    and Schemas.REGISTRIES.trainers.fields.parties
  local slotRec = parties and parties.inner and parties.inner.inner
  if not (slotRec and slotRec.kind == "rec" and type(slotRec.fields) == "table") then
    return false
  end
  slotRec.fields.heldItem = f.opt(f.str)
  slotRec.fields.moves = f.opt(f.list(f.str))
  return true
end

local function partyDefFor(game, oppClass, partyIndex)
  local trainer = game and game.data and game.data.trainers and game.data.trainers[oppClass]
  if not trainer then return nil end
  local partyDef = trainer.parties and trainer.parties[partyIndex or 1]
  if not partyDef then return nil end
  local Runtime = require("src.mods.Runtime")
  if Runtime.wantsHook("trainer.party") then
    partyDef = Runtime.call("trainer.party", function(_, _, party)
      return party
    end, oppClass, partyIndex or 1, partyDef) or partyDef
  end
  return partyDef
end

--- Apply slot.heldItem / slot.moves onto a built trainer enemyParty.
--- Safe if the engine already copied them (idempotent).
function Trainers.applySlotExtras(game, battle, oppClass, partyIndex)
  if not battle or type(battle.enemyParty) ~= "table" then return end
  local partyDef = partyDefFor(game, oppClass, partyIndex)
  if not partyDef then return end
  for i, slot in ipairs(partyDef) do
    local mon = battle.enemyParty[i]
    if type(mon) == "table" and type(slot) == "table" then
      if slot.heldItem then
        mon.heldItem = slot.heldItem
      end
      if slot.moves then
        mon.moves = {}
        for _, moveId in ipairs(slot.moves) do
          local mdef = game.data.moves and game.data.moves[moveId]
          mon.moves[#mon.moves + 1] = { id = moveId, pp = mdef and mdef.pp or 0 }
        end
      end
    end
  end
end

function Trainers.install(mod)
  if Trainers._installed then return end
  Trainers._installed = true

  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
  Gen1Patch.apply(require("src.battle.BattleState"), function(BattleState)
    local originalNewTrainer = BattleState.newTrainer
    if type(originalNewTrainer) ~= "function" then return end
    BattleState.newTrainer = function(game, oppClass, partyIndex)
      local battle = originalNewTrainer(game, oppClass, partyIndex)
      Trainers.applySlotExtras(game, battle, oppClass, partyIndex)
      return battle
    end
  end)
end

local function copySlot(slot)
  local copy = {
    level = slot.level,
    species = slot.species,
  }
  if slot.heldItem then copy.heldItem = slot.heldItem end
  if slot.moves then
    copy.moves = {}
    for i, m in ipairs(slot.moves) do copy.moves[i] = m end
  end
  return copy
end

local function copyParties(parties)
  local out = {}
  for pi, party in ipairs(parties or {}) do
    local copy = {}
    for si, slot in ipairs(party) do
      copy[si] = copySlot(slot)
    end
    out[pi] = copy
  end
  return out
end

local baselines

local function classesToCapture()
  local seen, list = {}, {}
  local function note(class)
    if class and not seen[class] then
      seen[class] = true
      list[#list + 1] = class
    end
  end
  for _, row in ipairs(MIX) do note(row[1]) end
  for _, row in ipairs(ACE_BERRIES) do note(row[1]) end
  for _, row in ipairs(MIX_GEN2) do note(row[1]) end
  for _, row in ipairs(ACE_BERRIES_GEN2) do note(row[1]) end
  return list
end

function Trainers.captureBaselines(mod)
  if baselines then return baselines end
  baselines = {}
  for _, class in ipairs(classesToCapture()) do
    local t = mod.content.trainers:get(class)
    if t and t.parties then
      baselines[class] = copyParties(t.parties)
    end
  end
  return baselines
end

function Trainers.clearBaselines()
  baselines = nil
end

local function ensurePatched(patched, snap, class)
  if not patched[class] then
    patched[class] = copyParties(snap[class])
  end
  return patched[class]
end

-- Apply curated swaps from the captured vanilla baselines. Safe to call
-- more than once (rebuilds from snapshot rather than stacking patches).
function Trainers.apply(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local mixList = Host.isGen2() and MIX_GEN2 or MIX
  local aceList = Host.isGen2() and ACE_BERRIES_GEN2 or ACE_BERRIES

  local snap = Trainers.captureBaselines(mod)
  local patched = {}

  for _, row in ipairs(mixList) do
    local class, pi, action, species, level = row[1], row[2], row[3], row[4], row[5]
    local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
    if species and not SpeciesScope.allowsSpeciesId(mod, species, nil) then
      -- Skip out-of-scope MIX rows under Gen1 kanto (rebuild from baseline).
    else
      local base = snap[class]
      if base then
        local parties = ensurePatched(patched, snap, class)
        local party = parties[pi]
        if party then
          if action == "add" then
            if species and level and #party > 0 then
              table.insert(party, #party, { level = level, species = species })
            end
          elseif action == "add_front" then
            if species and level then
              table.insert(party, 1, { level = level, species = species })
            end
          else
            local slot = party[action]
            if slot then
              slot.species = species
              if level then slot.level = level end
            end
          end
        end
      end
    end
  end

  for _, row in ipairs(aceList) do
    local class, pi, item = row[1], row[2], row[3]
    if snap[class] then
      local parties = ensurePatched(patched, snap, class)
      local party = parties[pi]
      if party and #party > 0 then
        party[#party].heldItem = item
      end
    end
  end

  local n = 0
  for class, parties in pairs(patched) do
    local ok = pcall(function()
      mod.content.trainers:patch(class, { parties = parties })
    end)
    if not ok then
      local Data = require("src.core.Data")
      if Data.trainers and Data.trainers[class] then
        Data.trainers[class].parties = parties
      end
    end
    n = n + 1
  end
  return n
end

return Trainers
