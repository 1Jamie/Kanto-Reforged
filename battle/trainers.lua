
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

  -- Route 23 / Victory Road Cooltrainer M #9: swap Dugtrio to Flygon (Ground/Dragon alternative)
  { "OPP_COOLTRAINER_M", 9, 2, "FLYGON" },
}

-- Gen 2 Gym Leaders & Gym Trainers Mix Overhaul
local MIX_GEN2 = {
  -- Mt. Moon Rival (parties 1, 2, 3 - target 58-62)
  { "OPP_RIVAL2", 1, 1, "SNEASEL", 58 },
  { "OPP_RIVAL2", 1, 2, "MAGNETON", 59 },
  { "OPP_RIVAL2", 1, 3, "GENGAR", 59 },
  { "OPP_RIVAL2", 1, 4, "ALAKAZAM", 60 },
  { "OPP_RIVAL2", 1, 5, "CROBAT", 60 },
  { "OPP_RIVAL2", 1, "add", "MEGANIUM", 62 },

  { "OPP_RIVAL2", 2, 1, "SNEASEL", 58 },
  { "OPP_RIVAL2", 2, 2, "MAGNETON", 59 },
  { "OPP_RIVAL2", 2, 3, "GENGAR", 59 },
  { "OPP_RIVAL2", 2, 4, "ALAKAZAM", 60 },
  { "OPP_RIVAL2", 2, 5, "CROBAT", 60 },
  { "OPP_RIVAL2", 2, "add", "TYPHLOSION", 62 },

  { "OPP_RIVAL2", 3, 1, "SNEASEL", 58 },
  { "OPP_RIVAL2", 3, 2, "MAGNETON", 59 },
  { "OPP_RIVAL2", 3, 3, "GENGAR", 59 },
  { "OPP_RIVAL2", 3, 4, "ALAKAZAM", 60 },
  { "OPP_RIVAL2", 3, 5, "CROBAT", 60 },
  { "OPP_RIVAL2", 3, "add", "FERALIGATR", 62 },

  -- Late-Game Boss & Elite Rematch Rival (parties 4-6 & custom 10-12 - target 75-78)
  { "OPP_RIVAL2", 4, 1, "SNEASEL", 75 },
  { "OPP_RIVAL2", 4, 2, "MAGNETON", 76 },
  { "OPP_RIVAL2", 4, 3, "GENGAR", 76 },
  { "OPP_RIVAL2", 4, 4, "ALAKAZAM", 77 },
  { "OPP_RIVAL2", 4, 5, "CROBAT", 77 },
  { "OPP_RIVAL2", 4, "add", "MEGANIUM", 78 },

  { "OPP_RIVAL2", 5, 1, "SNEASEL", 75 },
  { "OPP_RIVAL2", 5, 2, "MAGNETON", 76 },
  { "OPP_RIVAL2", 5, 3, "GENGAR", 76 },
  { "OPP_RIVAL2", 5, 4, "ALAKAZAM", 77 },
  { "OPP_RIVAL2", 5, 5, "CROBAT", 77 },
  { "OPP_RIVAL2", 5, "add", "TYPHLOSION", 78 },

  { "OPP_RIVAL2", 6, 1, "SNEASEL", 75 },
  { "OPP_RIVAL2", 6, 2, "MAGNETON", 76 },
  { "OPP_RIVAL2", 6, 3, "GENGAR", 76 },
  { "OPP_RIVAL2", 6, 4, "ALAKAZAM", 77 },
  { "OPP_RIVAL2", 6, 5, "CROBAT", 77 },
  { "OPP_RIVAL2", 6, "add", "FERALIGATR", 78 },

  { "OPP_RIVAL2", 10, 1, "SNEASEL", 75 },
  { "OPP_RIVAL2", 10, 2, "MAGNETON", 76 },
  { "OPP_RIVAL2", 10, 3, "GENGAR", 76 },
  { "OPP_RIVAL2", 10, 4, "ALAKAZAM", 77 },
  { "OPP_RIVAL2", 10, 5, "CROBAT", 77 },
  { "OPP_RIVAL2", 10, "add", "MEGANIUM", 78 },

  { "OPP_RIVAL2", 11, 1, "SNEASEL", 75 },
  { "OPP_RIVAL2", 11, 2, "MAGNETON", 76 },
  { "OPP_RIVAL2", 11, 3, "GENGAR", 76 },
  { "OPP_RIVAL2", 11, 4, "ALAKAZAM", 77 },
  { "OPP_RIVAL2", 11, 5, "CROBAT", 77 },
  { "OPP_RIVAL2", 11, "add", "TYPHLOSION", 78 },

  { "OPP_RIVAL2", 12, 1, "SNEASEL", 75 },
  { "OPP_RIVAL2", 12, 2, "MAGNETON", 76 },
  { "OPP_RIVAL2", 12, 3, "GENGAR", 76 },
  { "OPP_RIVAL2", 12, 4, "ALAKAZAM", 77 },
  { "OPP_RIVAL2", 12, 5, "CROBAT", 77 },
  { "OPP_RIVAL2", 12, "add", "FERALIGATR", 78 },

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

  -- Mt. Moon Rival Battle (Levels 58-62)
  { "OPP_RIVAL2", 1, 1, "SNEASEL", 58 },
  { "OPP_RIVAL2", 1, 2, "MAGNETON", 59 },
  { "OPP_RIVAL2", 1, 3, "GENGAR", 59 },
  { "OPP_RIVAL2", 1, 4, "ALAKAZAM", 60 },
  { "OPP_RIVAL2", 1, 5, "CROBAT", 60 },
  { "OPP_RIVAL2", 1, "add", "TYRANITAR", 62 },
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

-- Ace berries already live on GEN2_FULL_PARTIES rows; kept for tests / docs.
local ACE_BERRIES_GEN2 = {
  { "LT_SURGE", 1, "CHESTO_BERRY" },
  { "JANINE", 1, "PERSIM_BERRY" },
  { "ERIKA", 1, "RAWST_BERRY" },
  { "MISTY", 1, "PECHA_BERRY" },
  { "SABRINA", 1, "CHERI_BERRY" },
  { "BROCK", 1, "BERRY" },
  { "BLAINE", 1, "PERSIM_BERRY" },
  { "BLUE", 1, "CHERI_BERRY" },
}

-- Gold Kanto overworld gym leaders. Keys are Gold class ids (no OPP_),
-- members are trainers[].index. Party rows use Gen2 `item` (not Gen1 heldItem).
-- Rival / Fighting Dojo / restored-dungeon bosses stay in restored_dungeons.lua.
local GEN2_FULL_PARTIES = {
  LT_SURGE = {
    [1] = {
      { species = "ELECTRIKE", level = 52 },
      { species = "AMPHAROS", level = 53 },
      { species = "MAGNETON", level = 53 },
      { species = "ELECTRODE", level = 54 },
      { species = "MANECTRIC", level = 54 },
      { species = "RAICHU", level = 55, item = "CHESTO_BERRY" },
    }
  },
  -- Fuchsia Gym is Janine in Gold (OPP_KOGA in the Gen1 walkthrough draft).
  JANINE = {
    [1] = {
      { species = "ARIADOS", level = 52 },
      { species = "SWALOT", level = 53 },
      { species = "WEEZING", level = 54 },
      { species = "SEVIPER", level = 54 },
      { species = "CROBAT", level = 55 },
      { species = "VENOMOTH", level = 56, item = "PERSIM_BERRY" },
    }
  },
  ERIKA = {
    [1] = {
      { species = "ROSELIA", level = 53 },
      { species = "JUMPLUFF", level = 54 },
      { species = "TANGELA", level = 54 },
      { species = "BRELOOM", level = 55 },
      { species = "VICTREEBEL", level = 56 },
      { species = "BELLOSSOM", level = 57, item = "RAWST_BERRY" },
    }
  },
  MISTY = {
    [1] = {
      { species = "LANTURN", level = 57 },
      { species = "GOLDUCK", level = 58 },
      { species = "CRAWDAUNT", level = 59 },
      { species = "QUAGSIRE", level = 59 },
      { species = "LAPRAS", level = 60 },
      { species = "STARMIE", level = 61, item = "PECHA_BERRY" },
    }
  },
  SABRINA = {
    [1] = {
      { species = "GIRAFARIG", level = 58 },
      { species = "MR_MIME", level = 59 },
      { species = "XATU", level = 59 },
      { species = "ESPEON", level = 60 },
      { species = "GARDEVOIR", level = 61 },
      { species = "ALAKAZAM", level = 62, item = "CHERI_BERRY" },
    }
  },
  BROCK = {
    [1] = {
      { species = "SUDOWOODO", level = 58 },
      { species = "OMASTAR", level = 59 },
      { species = "KABUTOPS", level = 59 },
      { species = "RHYDON", level = 60 },
      { species = "AGGRON", level = 61 },
      { species = "STEELIX", level = 62, item = "BERRY" },
    }
  },
  BLAINE = {
    [1] = {
      { species = "TORKOAL", level = 59 },
      { species = "CAMERUPT", level = 60 },
      { species = "MAGCARGO", level = 60 },
      { species = "RAPIDASH", level = 61 },
      { species = "HOUNDOOM", level = 62 },
      { species = "MAGMAR", level = 63, item = "PERSIM_BERRY" },
    }
  },
  -- Viridian Gym is Blue in Gold (OPP_GIOVANNI party 3 in the Gen1 draft).
  BLUE = {
    [1] = {
      { species = "PIDGEOT", level = 70 },
      { species = "ALAKAZAM", level = 70 },
      { species = "TYRANITAR", level = 70 },
      { species = "GYARADOS", level = 70 },
      { species = "EXEGGUTOR", level = 71 },
      { species = "ARCANINE", level = 72, item = "CHERI_BERRY" },
    }
  },
}

-- Gold Kanto gym *trainee* members (class index + member from gym maps).
-- Do not use Gen1 party indexes — those collide with Johto trainers.
local GEN2_GYM_TRAINER_PARTIES = {
  -- Pewter: CAMPER Jerry
  CAMPER = {
    [18] = {
      { species = "PHANPY", level = 56 },
      { species = "ARON", level = 57 },
      { species = "SANDSLASH", level = 58 },
    },
  },
  -- Cerulean
  SWIMMERF = {
    [18] = {
      { species = "LOMBRE", level = 55 },
      { species = "GOLDUCK", level = 57 },
    },
    [19] = {
      { species = "CORPHISH", level = 56 },
      { species = "CLAMPERL", level = 57 },
      { species = "SEAKING", level = 58 },
    },
  },
  SWIMMERM = {
    [21] = {
      { species = "CORPHISH", level = 56 },
      { species = "CLAMPERL", level = 57 },
      { species = "SEADRA", level = 58 },
    },
  },
  -- Vermilion
  GUITARIST = {
    [2] = {
      { species = "MANECTRIC", level = 50 },
      { species = "FLAAFFY", level = 51 },
      { species = "PLUSLE", level = 52 },
      { species = "MAGNETON", level = 53 },
    },
  },
  GENTLEMAN = {
    [3] = {
      { species = "LANTURN", level = 51 },
      { species = "ELECTRIKE", level = 52 },
      { species = "FLAAFFY", level = 53 },
    },
  },
  JUGGLER = {
    [3] = {
      { species = "ELECTRODE", level = 52 },
      { species = "ELECTRODE", level = 52 },
      { species = "ELECTRIKE", level = 53 },
      { species = "MANECTRIC", level = 54 },
    },
  },
  -- Celadon
  BEAUTY = {
    [14] = {
      { species = "ROSELIA", level = 51 },
      { species = "BRELOOM", level = 52 },
      { species = "LOMBRE", level = 53 },
      { species = "BELLOSSOM", level = 54 },
    },
  },
  LASS = {
    [9] = {
      { species = "SUNKERN", level = 51 },
      { species = "ROSELIA", level = 52 },
      { species = "JUMPLUFF", level = 54 },
    },
  },
  PICNICKER = {
    [19] = {
      { species = "SEEDOT", level = 52 },
      { species = "ROSELIA", level = 53 },
      { species = "EXEGGUTOR", level = 55 },
    },
  },
  TWINS = {
    [5] = {
      { species = "SKIPLOOM", level = 52 },
      { species = "ROSELIA", level = 52 },
    },
    [6] = {
      { species = "ROSELIA", level = 52 },
      { species = "SKIPLOOM", level = 52 },
    },
  },
  -- Saffron
  PSYCHIC_T = {
    [2] = {
      { species = "KIRLIA", level = 56 },
      { species = "SPOINK", level = 57 },
      { species = "GIRAFARIG", level = 58 },
    },
    [11] = {
      { species = "KIRLIA", level = 55 },
      { species = "XATU", level = 56 },
      { species = "MR_MIME", level = 57 },
    },
  },
  MEDIUM = {
    [6] = {
      { species = "SHUPPET", level = 55 },
      { species = "DUSKULL", level = 56 },
      { species = "HYPNO", level = 57 },
    },
    [7] = {
      { species = "MISDREAVUS", level = 55 },
      { species = "SPOINK", level = 56 },
      { species = "SLOWBRO", level = 58 },
    },
  },
}



-- Auto-curated Gold Kanto overworld (non-gym) trainer parties.
-- Members taken from Kanto map trainer objects; levels follow postgame curve.
local GEN2_KANTO_ROUTE_PARTIES = {
  BIKER = {
    -- DWAYNE (ROUTE_8)
    [3] = {
      { species = "MAGCARGO", level = 49 },
      { species = "WEEZING", level = 50 },
      { species = "MAGCARGO", level = 51 },
      { species = "CROBAT", level = 52 },
    },
    -- HARRIS (ROUTE_8)
    [4] = {
      { species = "HOUNDOOM", level = 50 },
      { species = "FLAREON", level = 51 },
      { species = "WEEZING", level = 52 },
    },
    -- ZEKE (ROUTE_8)
    [5] = {
      { species = "MAGMAR", level = 50 },
      { species = "WEEZING", level = 51 },
      { species = "SWALOT", level = 52 },
    },
    -- CHARLES (ROUTE_17)
    [6] = {
      { species = "CROBAT", level = 55 },
      { species = "WEEZING", level = 56 },
      { species = "CHARIZARD", level = 57 },
      { species = "MUK", level = 58 },
    },
    -- RILEY (ROUTE_17)
    [7] = {
      { species = "WEEZING", level = 56 },
      { species = "CROBAT", level = 57 },
      { species = "MAGCARGO", level = 58 },
    },
    -- JOEL (ROUTE_17)
    [8] = {
      { species = "SWALOT", level = 56 },
      { species = "MAGMAR", level = 57 },
      { species = "HOUNDOOM", level = 58 },
    },
    -- GLENN (ROUTE_17)
    [9] = {
      { species = "MUK", level = 55 },
      { species = "WEEZING", level = 56 },
      { species = "MAGMAR", level = 57 },
      { species = "MAGCARGO", level = 58 },
    },
  },
  BIRD_KEEPER = {
    -- HANK (ROUTE_4)
    [8] = {
      { species = "SWELLOW", level = 56 },
      { species = "PIDGEOT", level = 57 },
      { species = "FEAROW", level = 58 },
    },
    -- ROY (ROUTE_14)
    [9] = {
      { species = "PELIPPER", level = 53 },
      { species = "FEAROW", level = 54 },
      { species = "DODRIO", level = 55 },
    },
    -- BORIS (ROUTE_18)
    [10] = {
      { species = "NOCTOWL", level = 55 },
      { species = "DODRIO", level = 56 },
      { species = "PELIPPER", level = 57 },
      { species = "PIDGEOT", level = 58 },
    },
    -- BOB (ROUTE_18)
    [11] = {
      { species = "FEAROW", level = 56 },
      { species = "NOCTOWL", level = 57 },
      { species = "SKARMORY", level = 58 },
    },
    -- JOSE (ROUTE_27)
    [14] = {
      { species = "SKARMORY", level = 58 },
      { species = "FARFETCHD", level = 59 },
      { species = "PELIPPER", level = 60 },
    },
    -- PERRY (ROUTE_13)
    [15] = {
      { species = "XATU", level = 53 },
      { species = "FARFETCHD", level = 54 },
      { species = "NOCTOWL", level = 55 },
    },
    -- BRET (ROUTE_13)
    [16] = {
      { species = "SWELLOW", level = 53 },
      { species = "PIDGEOT", level = 54 },
      { species = "FEAROW", level = 55 },
    },
  },
  BUG_CATCHER = {
    -- ROB (ROUTE_2)
    [2] = {
      { species = "BEEDRILL", level = 56 },
      { species = "SCIZOR", level = 57 },
      { species = "VOLBEAT", level = 58 },
    },
    -- ED (ROUTE_2)
    [3] = {
      { species = "BUTTERFREE", level = 55 },
      { species = "BEEDRILL", level = 56 },
      { species = "LEDIAN", level = 57 },
      { species = "ILLUMISE", level = 58 },
    },
    -- DOUG (ROUTE_2)
    [12] = {
      { species = "BUTTERFREE", level = 56 },
      { species = "ARIADOS", level = 57 },
      { species = "ILLUMISE", level = 58 },
    },
  },
  CAMPER = {
    -- LLOYD (ROUTE_25)
    [6] = {
      { species = "GOLEM", level = 55 },
      { species = "NIDOKING", level = 56 },
      { species = "AGGRON", level = 57 },
    },
    -- DEAN (ROUTE_9)
    [7] = {
      { species = "DONPHAN", level = 53 },
      { species = "GOLDUCK", level = 54 },
      { species = "NIDOKING", level = 55 },
    },
    -- SID (ROUTE_9)
    [8] = {
      { species = "SANDSLASH", level = 52 },
      { species = "DUGTRIO", level = 53 },
      { species = "PRIMEAPE", level = 54 },
      { species = "MAROWAK", level = 55 },
    },
  },
  COOLTRAINERF = {
    -- JOYCE (ROUTE_26)
    [8] = {
      { species = "MILOTIC", level = 58 },
      { species = "RAICHU", level = 59 },
      { species = "BLASTOISE", level = 60 },
    },
    -- BETH (ROUTE_26)
    [9] = {
      { species = "SALAMENCE", level = 58 },
      { species = "RAPIDASH", level = 59 },
      { species = "VENUSAUR", level = 60 },
    },
    -- REENA (ROUTE_27)
    [10] = {
      { species = "GARDEVOIR", level = 57 },
      { species = "STARMIE", level = 58 },
      { species = "NIDOQUEEN", level = 59 },
      { species = "RAPIDASH", level = 60 },
    },
    -- MEGAN (ROUTE_27)
    [11] = {
      { species = "BLASTOISE", level = 57 },
      { species = "VENUSAUR", level = 58 },
      { species = "GARDEVOIR", level = 59 },
      { species = "STARMIE", level = 60 },
    },
    -- QUINN (ROUTE_1)
    [14] = {
      { species = "STARMIE", level = 56 },
      { species = "VENUSAUR", level = 57 },
      { species = "SALAMENCE", level = 58 },
    },
  },
  COOLTRAINERM = {
    -- JAKE (ROUTE_26)
    [9] = {
      { species = "AGGRON", level = 58 },
      { species = "PARASECT", level = 59 },
      { species = "SCIZOR", level = 60 },
    },
    -- GAVEN (ROUTE_26)
    [10] = {
      { species = "TYRANITAR", level = 57 },
      { species = "VICTREEBEL", level = 58 },
      { species = "KINGLER", level = 59 },
      { species = "URSARING", level = 60 },
    },
    -- BLAKE (ROUTE_27)
    [11] = {
      { species = "KINGDRA", level = 57 },
      { species = "MAGNETON", level = 58 },
      { species = "QUAGSIRE", level = 59 },
      { species = "ARCANINE", level = 60 },
    },
    -- BRIAN (ROUTE_27)
    [12] = {
      { species = "SCIZOR", level = 58 },
      { species = "SANDSLASH", level = 59 },
      { species = "SALAMENCE", level = 60 },
    },
  },
  FIREBREATHER = {
    -- OTIS (ROUTE_3)
    [1] = {
      { species = "HOUNDOOM", level = 55 },
      { species = "MAGMAR", level = 56 },
      { species = "WEEZING", level = 57 },
      { species = "MAGCARGO", level = 58 },
    },
    -- BURT (ROUTE_3)
    [4] = {
      { species = "WEEZING", level = 56 },
      { species = "TORKOAL", level = 57 },
      { species = "MAGMAR", level = 58 },
    },
  },
  FISHER = {
    -- ARNOLD (ROUTE_21)
    [3] = {
      { species = "GYARADOS", level = 56 },
      { species = "TENTACRUEL", level = 57 },
      { species = "QUAGSIRE", level = 58 },
    },
    -- KYLE (ROUTE_12)
    [4] = {
      { species = "OCTILLERY", level = 52 },
      { species = "SEAKING", level = 53 },
      { species = "POLIWRATH", level = 54 },
      { species = "TENTACRUEL", level = 55 },
    },
    -- MARTIN (ROUTE_12)
    [13] = {
      { species = "OCTILLERY", level = 53 },
      { species = "QWILFISH", level = 54 },
      { species = "TENTACRUEL", level = 55 },
    },
    -- STEPHEN (ROUTE_12)
    [14] = {
      { species = "WHISCASH", level = 52 },
      { species = "QWILFISH", level = 53 },
      { species = "TENTACRUEL", level = 54 },
      { species = "KINGDRA", level = 55 },
    },
    -- BARNEY (ROUTE_12)
    [15] = {
      { species = "QUAGSIRE", level = 52 },
      { species = "GYARADOS", level = 53 },
      { species = "OCTILLERY", level = 54 },
      { species = "LANTURN", level = 55 },
    },
    -- SCOTT (ROUTE_26)
    [21] = {
      { species = "GYARADOS", level = 57 },
      { species = "QWILFISH", level = 58 },
      { species = "QWILFISH", level = 59 },
      { species = "QUAGSIRE", level = 60 },
    },
  },
  HIKER = {
    -- TIM (ROUTE_9)
    [13] = {
      { species = "RHYDON", level = 52 },
      { species = "GOLEM", level = 53 },
      { species = "RHYDON", level = 54 },
      { species = "STEELIX", level = 55 },
    },
    -- SIDNEY (ROUTE_9)
    [15] = {
      { species = "MACHAMP", level = 53 },
      { species = "DUGTRIO", level = 54 },
      { species = "CAMERUPT", level = 55 },
    },
    -- KENNY (ROUTE_13)
    [16] = {
      { species = "STEELIX", level = 52 },
      { species = "SANDSLASH", level = 53 },
      { species = "GOLEM", level = 54 },
      { species = "NOSEPASS", level = 55 },
    },
    -- JIM (ROUTE_10_SOUTH)
    [17] = {
      { species = "AGGRON", level = 53 },
      { species = "MACHAMP", level = 54 },
      { species = "RHYDON", level = 55 },
    },
  },
  LASS = {
    -- LAURA (ROUTE_25)
    [7] = {
      { species = "GRANBULL", level = 54 },
      { species = "BELLOSSOM", level = 55 },
      { species = "PIDGEOT", level = 56 },
      { species = "WIGGLYTUFF", level = 57 },
    },
    -- SHANNON (ROUTE_25)
    [8] = {
      { species = "BELLOSSOM", level = 54 },
      { species = "PARASECT", level = 55 },
      { species = "BELLOSSOM", level = 56 },
      { species = "ROSELIA", level = 57 },
    },
    -- ELLEN (ROUTE_25)
    [11] = {
      { species = "ROSELIA", level = 55 },
      { species = "WIGGLYTUFF", level = 56 },
      { species = "GRANBULL", level = 57 },
    },
  },
  PICNICKER = {
    -- HOPE (ROUTE_4)
    [6] = {
      { species = "RAICHU", level = 56 },
      { species = "AMPHAROS", level = 57 },
      { species = "GRANBULL", level = 58 },
    },
    -- SHARON (ROUTE_4)
    [7] = {
      { species = "LINOONE", level = 56 },
      { species = "FURRET", level = 57 },
      { species = "AMPHAROS", level = 58 },
    },
    -- HEIDI (ROUTE_9)
    [13] = {
      { species = "BELLOSSOM", level = 53 },
      { species = "JUMPLUFF", level = 54 },
      { species = "BRELOOM", level = 55 },
    },
    -- EDNA (ROUTE_9)
    [14] = {
      { species = "RAICHU", level = 53 },
      { species = "NIDOQUEEN", level = 54 },
      { species = "GRANBULL", level = 55 },
    },
  },
  POKEFANM = {
    -- ROBERT (ROUTE_10_SOUTH)
    [3] = {
      { species = "GRANBULL", level = 53 },
      { species = "QUAGSIRE", level = 54 },
      { species = "BLISSEY", level = 55 },
    },
    -- JOSHUA (ROUTE_13)
    [4] = {
      { species = "AZUMARILL", level = 52 },
      { species = "RAICHU", level = 53 },
      { species = "AZUMARILL", level = 54 },
      { species = "QUAGSIRE", level = 55 },
    },
    -- CARTER (ROUTE_14)
    [5] = {
      { species = "SNORLAX", level = 52 },
      { species = "VENUSAUR", level = 53 },
      { species = "CHARIZARD", level = 54 },
      { species = "RAICHU", level = 55 },
    },
    -- TREVOR (ROUTE_14)
    [6] = {
      { species = "BLISSEY", level = 53 },
      { species = "GOLDUCK", level = 54 },
      { species = "SLOWKING", level = 55 },
    },
    -- ALEX (ROUTE_13)
    [12] = {
      { species = "SNORLAX", level = 52 },
      { species = "NIDOKING", level = 53 },
      { species = "SLOWKING", level = 54 },
      { species = "RAICHU", level = 55 },
    },
  },
  PSYCHIC_T = {
    -- HERMAN (ROUTE_11)
    [3] = {
      { species = "ALAKAZAM", level = 49 },
      { species = "EXEGGUTOR", level = 50 },
      { species = "GIRAFARIG", level = 51 },
      { species = "STARMIE", level = 52 },
    },
    -- FIDEL (ROUTE_11)
    [4] = {
      { species = "GARDEVOIR", level = 50 },
      { species = "XATU", level = 51 },
      { species = "GRUMPIG", level = 52 },
    },
    -- RICHARD (ROUTE_26)
    [9] = {
      { species = "XATU", level = 58 },
      { species = "ESPEON", level = 59 },
      { species = "GARDEVOIR", level = 60 },
    },
    -- GILBERT (ROUTE_27)
    [10] = {
      { species = "GIRAFARIG", level = 57 },
      { species = "STARMIE", level = 58 },
      { species = "EXEGGUTOR", level = 59 },
      { species = "WOBBUFFET", level = 60 },
    },
  },
  SCHOOLBOY = {
    -- KIPP (ROUTE_15)
    [2] = {
      { species = "ELECTABUZZ", level = 52 },
      { species = "ELECTRODE", level = 53 },
      { species = "MAGNETON", level = 54 },
      { species = "PORYGON2", level = 55 },
    },
    -- JOHNNY (ROUTE_15)
    [4] = {
      { species = "JYNX", level = 52 },
      { species = "VICTREEBEL", level = 53 },
      { species = "JYNX", level = 54 },
      { species = "XATU", level = 55 },
    },
    -- DANNY (ROUTE_1)
    [5] = {
      { species = "PORYGON2", level = 55 },
      { species = "JYNX", level = 56 },
      { species = "ELECTABUZZ", level = 57 },
      { species = "ALAKAZAM", level = 58 },
    },
    -- TOMMY (ROUTE_15)
    [6] = {
      { species = "ESPEON", level = 53 },
      { species = "XATU", level = 54 },
      { species = "ELECTABUZZ", level = 55 },
    },
    -- DUDLEY (ROUTE_25)
    [7] = {
      { species = "XATU", level = 55 },
      { species = "BELLOSSOM", level = 56 },
      { species = "MAGNETON", level = 57 },
    },
    -- JOE (ROUTE_25)
    [8] = {
      { species = "ALAKAZAM", level = 55 },
      { species = "TANGELA", level = 56 },
      { species = "JYNX", level = 57 },
    },
    -- BILLY (ROUTE_15)
    [9] = {
      { species = "ELECTABUZZ", level = 52 },
      { species = "PARASECT", level = 53 },
      { species = "ELECTABUZZ", level = 54 },
      { species = "PORYGON2", level = 55 },
    },
  },
  SUPER_NERD = {
    -- SAM (ROUTE_8)
    [6] = {
      { species = "MUK", level = 50 },
      { species = "MUK", level = 51 },
      { species = "ELECTRODE", level = 52 },
    },
    -- TOM (ROUTE_8)
    [7] = {
      { species = "MAGNETON", level = 49 },
      { species = "MAGNETON", level = 50 },
      { species = "PORYGON2", level = 51 },
      { species = "CLAYDOL", level = 52 },
    },
    -- PAT (ROUTE_25)
    [8] = {
      { species = "PORYGON2", level = 55 },
      { species = "PORYGON", level = 56 },
      { species = "WEEZING", level = 57 },
    },
  },
  SWIMMERF = {
    -- DAWN (ROUTE_19)
    [12] = {
      { species = "CRAWDAUNT", level = 56 },
      { species = "SEAKING", level = 57 },
      { species = "MILOTIC", level = 58 },
    },
    -- NICOLE (ROUTE_20)
    [14] = {
      { species = "SEAKING", level = 55 },
      { species = "MARILL", level = 56 },
      { species = "DEWGONG", level = 57 },
      { species = "AZUMARILL", level = 58 },
    },
    -- LORI (ROUTE_20)
    [15] = {
      { species = "MILOTIC", level = 56 },
      { species = "STARMIE", level = 57 },
      { species = "LAPRAS", level = 58 },
    },
    -- NIKKI (ROUTE_21)
    [17] = {
      { species = "AZUMARILL", level = 55 },
      { species = "DEWGONG", level = 56 },
      { species = "LANTURN", level = 57 },
      { species = "CRAWDAUNT", level = 58 },
    },
  },
  SWIMMERM = {
    -- HAROLD (ROUTE_19)
    [1] = {
      { species = "QUAGSIRE", level = 56 },
      { species = "OCTILLERY", level = 57 },
      { species = "SHARPEDO", level = 58 },
    },
    -- JEROME (ROUTE_19)
    [14] = {
      { species = "KINGDRA", level = 55 },
      { species = "SHARPEDO", level = 56 },
      { species = "TENTACRUEL", level = 57 },
      { species = "QUAGSIRE", level = 58 },
    },
    -- TUCKER (ROUTE_19)
    [15] = {
      { species = "POLITOED", level = 56 },
      { species = "CLOYSTER", level = 57 },
      { species = "OCTILLERY", level = 58 },
    },
    -- CAMERON (ROUTE_20)
    [17] = {
      { species = "QUAGSIRE", level = 56 },
      { species = "MARILL", level = 57 },
      { species = "SHARPEDO", level = 58 },
    },
    -- SETH (ROUTE_21)
    [18] = {
      { species = "OCTILLERY", level = 55 },
      { species = "QUAGSIRE", level = 56 },
      { species = "OCTILLERY", level = 57 },
      { species = "GYARADOS", level = 58 },
    },
  },
  TEACHER = {
    -- COLETTE (ROUTE_15)
    [1] = {
      { species = "AIPOM", level = 53 },
      { species = "CLEFABLE", level = 54 },
      { species = "GARDEVOIR", level = 55 },
    },
    -- HILLARY (ROUTE_15)
    [2] = {
      { species = "MAROWAK", level = 53 },
      { species = "AIPOM", level = 54 },
      { species = "GRANBULL", level = 55 },
    },
  },
  YOUNGSTER = {
    -- WARREN (ROUTE_3)
    [9] = {
      { species = "GRANBULL", level = 56 },
      { species = "FEAROW", level = 57 },
      { species = "FURRET", level = 58 },
    },
    -- JIMMY (ROUTE_3)
    [10] = {
      { species = "AZUMARILL", level = 56 },
      { species = "RATICATE", level = 57 },
      { species = "GRANBULL", level = 58 },
    },
    -- OWEN (ROUTE_11)
    [11] = {
      { species = "LINOONE", level = 50 },
      { species = "ARCANINE", level = 51 },
      { species = "AZUMARILL", level = 52 },
    },
    -- JASON (ROUTE_11)
    [12] = {
      { species = "FURRET", level = 50 },
      { species = "SANDSLASH", level = 51 },
      { species = "LINOONE", level = 52 },
    },
  },
}

Trainers.MIX = MIX
Trainers.MIX_GEN2 = MIX_GEN2
Trainers.ACE_BERRIES = ACE_BERRIES
Trainers.ACE_BERRIES_GEN2 = ACE_BERRIES_GEN2
Trainers.GEN2_FULL_PARTIES = GEN2_FULL_PARTIES
Trainers.GEN2_GYM_TRAINER_PARTIES = GEN2_GYM_TRAINER_PARTIES
Trainers.GEN2_KANTO_ROUTE_PARTIES = GEN2_KANTO_ROUTE_PARTIES

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

  -- Scan all enemy party mons to ensure none are left with ONLY Dig or charge moves as offensive option
  for i, mon in ipairs(battle.enemyParty) do
    if type(mon) == "table" and mon.moves then
      local hasDig = false
      local hasOtherAttackingMove = false
      for _, mv in ipairs(mon.moves) do
        local mId = type(mv) == "table" and mv.id or mv
        local mdef = game.data and game.data.moves and game.data.moves[mId]
        if mId == "DIG" then
          hasDig = true
        elseif mdef and (mdef.power or 0) > 0 and mdef.id ~= "DIG" and mdef.effect ~= "CHARGE_EFFECT" and mdef.effect ~= "FLY_EFFECT" then
          hasOtherAttackingMove = true
        end
      end

      -- If mon only has DIG as its single offensive move (e.g. Diglett with [DIG, GROWL]),
      -- inject a valid alternative direct attack (SCRATCH / FURY_SWIPES) into its movepool.
      if hasDig and not hasOtherAttackingMove then
        local altMove = (mon.level or 1) >= 15 and "FURY_SWIPES" or "SCRATCH"
        local mdef = game.data and game.data.moves and game.data.moves[altMove]
        table.insert(mon.moves, 1, { id = altMove, pp = mdef and mdef.pp or 15 })
      end
    end
  end

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

  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
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
  local item = slot.item or slot.heldItem
  local copy = {
    level = slot.level,
    species = slot.species,
  }
  if item then
    copy.item = item
    copy.heldItem = item
  end
  if slot.moves then
    copy.moves = {}
    for i, m in ipairs(slot.moves) do copy.moves[i] = m end
  end
  return copy
end

local function copySlotGen2(slot)
  local copy = {
    level = slot.level,
    species = slot.species,
  }
  local item = slot.item or slot.heldItem
  if item then copy.item = item end
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
  for class in pairs(GEN2_FULL_PARTIES) do note(class) end
  for class in pairs(GEN2_GYM_TRAINER_PARTIES) do note(class) end
  for class in pairs(GEN2_KANTO_ROUTE_PARTIES) do note(class) end
  return list
end

function Trainers.captureBaselines(mod)
  if baselines then return baselines end
  baselines = {}
  local data = (mod and mod.data) or (_G.game and _G.game.data)
  for _, class in ipairs(classesToCapture()) do
    local t = mod and mod.content and mod.content.trainers and mod.content.trainers:get(class)
    if not t and data then
      local baseName = class:gsub("^OPP_", "")
      local trTable = data.gen2Trainers or data.trainers
      local classes = trTable and (trTable.classes or trTable)
      if classes and (classes[class] or classes[baseName]) then
        t = classes[class] or classes[baseName]
      end
    end
    if t and (t.parties or t.trainers) then
      local parties = t.parties or {}
      if #parties == 0 and t.trainers then
        parties = {}
        for pi, tr in ipairs(t.trainers) do
          parties[pi] = tr.party or tr
        end
      end
      baselines[class] = copyParties(parties)
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

local function partyHasItem(party)
  for _, slot in ipairs(party or {}) do
    if slot.item or slot.heldItem then return true end
  end
  return false
end

local function gen2TrainerTables(data)
  local out = {}
  if not data then return out end
  local function note(tbl)
    if type(tbl) ~= "table" then return end
    local classes = (tbl.classes and type(tbl.classes) == "table") and tbl.classes or tbl
    if type(classes) == "table" then out[#out + 1] = classes end
  end
  note(data.gen2Trainers)
  if data.trainers and data.trainers ~= data.gen2Trainers then
    note(data.trainers)
  end
  return out
end

local function indexGen2Rosters(rosterMap)
  local byKey = {}
  for classId, members in pairs(rosterMap or {}) do
    for member, party in pairs(members) do
      local roster = {}
      for si, slot in ipairs(party) do
        roster[si] = copySlotGen2(slot)
      end
      byKey[string.format("%s_%s", classId, tostring(member))] = {
        classId = classId,
        member = tonumber(member) or member,
        roster = roster,
      }
    end
  end
  return byKey
end

-- Write curated Gold parties into live trainer tables (same contract as
-- restored_dungeons: classes[CLASS].trainers[member].party with `item`).
local function applyGen2Rosters(mod, rosterMap)
  local data = (mod and mod.data) or (_G.game and _G.game.data)
  local targets = gen2TrainerTables(data)
  local okCore, coreData = pcall(require, "src.core.Data")
  if okCore and coreData then
    for _, classes in ipairs(gen2TrainerTables(coreData)) do
      targets[#targets + 1] = classes
    end
  end
  if _G.game and _G.game.data and _G.game.data ~= data then
    for _, classes in ipairs(gen2TrainerTables(_G.game.data)) do
      targets[#targets + 1] = classes
    end
  end

  local n = 0
  local seen = {}
  for _, classes in ipairs(targets) do
    if not seen[classes] then
      seen[classes] = true
      rawset(classes, "_byIndex", nil)
      if data and data.gen2Trainers then
        rawset(data.gen2Trainers, "_byIndex", nil)
      end
      for classId, members in pairs(rosterMap) do
        local entry = classes[classId]
        if type(entry) == "table" and type(entry.trainers) == "table" then
          for member, party in pairs(members) do
            local row = entry.trainers[member]
            if type(row) == "table" then
              local partyCopy = {}
              for si, slot in ipairs(party) do
                partyCopy[si] = copySlotGen2(slot)
              end
              row.party = partyCopy
              if partyHasItem(partyCopy) then
                local tt = row.trainerType
                if not tt or tt == "TRAINERTYPE_NORMAL" then
                  row.trainerType = "TRAINERTYPE_ITEM"
                elseif tt == "TRAINERTYPE_MOVES" then
                  row.trainerType = "TRAINERTYPE_ITEM_MOVES"
                end
              end
              n = n + 1
            end
          end
          rawset(entry, "_byIndex", nil)
          pcall(function()
            if mod and mod.content and mod.content.trainers then
              mod.content.trainers:patch(classId, {
                trainers = entry.trainers,
              })
            end
          end)
        end
      end
    end
  end
  return n
end

-- Apply curated swaps from the captured vanilla baselines. Safe to call
-- more than once (rebuilds from snapshot rather than stacking patches).
function Trainers.apply(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local isGen2 = Host.isGen2()

  if isGen2 then
    -- Gold overworld: authoritative class+member rosters (dungeon pattern).
    -- Do NOT run Gen1 MIX_GEN2 OPP_* / parties[][] patches — those miss Gold's
    -- Trainers.lookup → trainers[].party path and can clobber Johto members.
    local rosterMap = {}
    local function mergeRosters(src)
      for classId, members in pairs(src) do
        rosterMap[classId] = rosterMap[classId] or {}
        for member, party in pairs(members) do
          local copy = {}
          for si, slot in ipairs(party) do
            copy[si] = copySlotGen2(slot)
          end
          rosterMap[classId][member] = copy
        end
      end
    end
    mergeRosters(GEN2_FULL_PARTIES)
    mergeRosters(GEN2_GYM_TRAINER_PARTIES)
    mergeRosters(GEN2_KANTO_ROUTE_PARTIES)

    for _, row in ipairs(ACE_BERRIES_GEN2) do
      local classId, member, item = row[1], row[2], row[3]
      local party = rosterMap[classId] and rosterMap[classId][member]
      if party and #party > 0 and item then
        party[#party].item = item
      end
    end

    Trainers._gen2RosterByKey = indexGen2Rosters(rosterMap)
    applyGen2Rosters(mod, rosterMap)
    local classes = 0
    for _ in pairs(rosterMap) do classes = classes + 1 end
    Trainers._gen2ClassCount = classes
    return classes
  end

  local mixList = MIX
  local aceList = ACE_BERRIES

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
  local data = (mod and mod.data) or (_G.game and _G.game.data)
  for class, parties in pairs(patched) do
    pcall(function()
      mod.content.trainers:patch(class, { parties = parties })
    end)
    if data then
      local function syncTable(tbl)
        if not tbl then return end
        local baseName = class:gsub("^OPP_", "")
        local container = (tbl.classes and type(tbl.classes) == "table") and tbl.classes or tbl
        local target = container[class] or container[baseName]
        if not target then
          target = { id = baseName, name = baseName }
          container[class] = target
          container[baseName] = target
        end
        target.parties = parties
        local tList = {}
        for pi, party in pairs(parties) do
          if type(party) == "table" then
            tList[pi] = {
              id = string.format("%s_%d", baseName, pi),
              name = target.name or baseName,
              party = party,
            }
          end
        end
        target.trainers = tList
        if tbl.classes then
          rawset(tbl, "_byIndex", nil)
        end
      end

      syncTable(data.gen2Trainers)
      syncTable(data.trainers)
    end
    n = n + 1
  end
  return n
end

local function resolveGen2ClassId(trainerData, class)
  if type(class) == "string" then
    return class:gsub("^OPP_", "")
  end
  local ok, G2Trainers = pcall(require, "src.world.gen2.Trainers")
  local cache = nil
  if ok and G2Trainers and G2Trainers.classIndex and trainerData then
    cache = G2Trainers.classIndex(trainerData)
  end
  local entry = cache and cache[class]
  if type(entry) == "table" then
    return entry.id or entry.name
  end
  return tostring(class)
end

-- Mirror restored_dungeons: own Trainers.lookup / World:trainerParty so curated
-- overworld rosters win even if something reloads stock trainer tables.
function Trainers.installGen2(mod)
  if Trainers._gen2Installed then return end
  Trainers._gen2Installed = true

  local okTrainers, G2Trainers = pcall(require, "src.world.gen2.Trainers")
  if okTrainers and G2Trainers and G2Trainers.lookup then
    local origLookup = G2Trainers.lookup
    function G2Trainers.lookup(trainerData, class, member)
      member = tonumber(member) or 1
      local byKey = Trainers._gen2RosterByKey
      if byKey then
        local classId = resolveGen2ClassId(trainerData, class)
        local custom = byKey[string.format("%s_%s", tostring(classId), tostring(member))]
          or byKey[string.format("%s_%s", tostring(class), tostring(member))]
        if custom and custom.roster then
          local entry = nil
          if trainerData then
            local cache = G2Trainers.classIndex and G2Trainers.classIndex(trainerData)
            entry = cache and (cache[class] or cache[classId])
          end
          local memberRow = entry and entry.trainers and entry.trainers[member]
          return {
            class = class,
            classId = custom.classId or classId or tostring(class),
            className = (entry and entry.name) or tostring(custom.classId or class),
            member = member,
            id = (memberRow and memberRow.id)
              or string.format("%s_%s", tostring(custom.classId or class), tostring(member)),
            name = (memberRow and memberRow.name)
              or (entry and entry.name) or tostring(custom.classId or class),
            trainerType = partyHasItem(custom.roster) and "TRAINERTYPE_ITEM" or "TRAINERTYPE_NORMAL",
            roster = custom.roster,
            attributes = entry and entry.attributes or {},
            items = (function()
              local out = {}
              for _, id in ipairs((entry and entry.items) or {}) do out[#out + 1] = id end
              return out
            end)(),
            baseMoney = entry and entry.baseMoney or 25,
          }
        end
      end
      return origLookup(trainerData, class, member)
    end
  end

  local okWorld, World = pcall(require, "src.world.gen2.World")
  if okWorld and World and World.trainerParty then
    local origTrainerParty = World.trainerParty
    function World:trainerParty(class, member)
      member = tonumber(member) or 1
      local byKey = Trainers._gen2RosterByKey
      if byKey then
        local trainerData = self.game and self.game.data and self.game.data.trainers
        local classId = resolveGen2ClassId(trainerData, class)
        local custom = byKey[string.format("%s_%s", tostring(classId), tostring(member))]
          or byKey[string.format("%s_%s", tostring(class), tostring(member))]
        if custom and custom.roster then
          local roster = {}
          for si, slot in ipairs(custom.roster) do
            roster[si] = {
              species = slot.species,
              level = slot.level,
              item = slot.item,
            }
          end
          return {
            class = class,
            classId = custom.classId or classId,
            className = custom.classId or classId,
            name = custom.classId or classId,
            member = member,
            roster = roster,
            trainerType = partyHasItem(roster) and "TRAINERTYPE_ITEM" or "TRAINERTYPE_NORMAL",
            attributes = {},
            items = {},
          }
        end
      end
      return origTrainerParty(self, class, member)
    end
  end

  if mod and mod.log then
    mod.log:info("Gen2 overworld trainer party lookup installed")
  end
end

function Trainers.hasGen2Override(classId)
  local byKey = Trainers._gen2RosterByKey
  if not byKey or not classId then return false end
  local id = tostring(classId):gsub("^OPP_", "")
  for key in pairs(byKey) do
    if key:sub(1, #id + 1) == id .. "_" then return true end
  end
  return false
end

return Trainers
