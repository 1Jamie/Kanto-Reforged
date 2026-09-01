# Kanto Reforged

Gen 2 and 3 content for Red/Blue and Gold/Silver/Crystal on this engine. Same classic story, more Pokemon, moves, abilities, held items, and some bag/party QoL so the extra stuff is easier to use. My goal here was not to bolt on or make things feel weird, but if Game Freak were to do these pieces back in gen1 and gen2, how would they have done it? The features added are attempted to be done in a way to make them feel like they are part of the base games, inspired by some of my favorite things from different generations and rom hacks ive played. I tried my best to make the gen2-3 mons look good and look like they belong by hand-adjusting pixel counts, scaling, and following classic color count rules and style constraints where possible. Hopefully at the end of the day it looks like an almost "alternate history" version of the classic games.

Mod id is `Kanto-Reforged`. Turn it on in the launcher Mods tab or the F10 manager.

Has support for Gen1 Modern UI mod (on Gen1) and Pokegear Cards (on Gen2 — Gold, Silver, and Crystal).

## Current status

**RBY (generation 1 of gen1recomp++):**
Fully functional with the occasional bug still being chased down, but fully playable and all 386 are obtainable.

**Gold / Silver / Crystal (generation 2 of gen1recomp++):**
Gen 2 support is live on Gold, Silver, and Crystal. Core pieces:
- Full Hoenn integration (species dex 252 through 386 registered, sprites scaled, Gen 3 abilities patched onto 1–251).
- Type chart and move typing parity across both generations (Dark, Steel, Fairy matchups; Gen 3 physical/special by type).
- Gen 3 freeze parity (1/5 thaw per turn; fire moves melt frozen targets).
- DexNav via Pokegear card (requires `pokegear_cards`) with live route spawns.
- Party Summary page 4: ability, held item, gender glyph, and ability text.
- Berry Farm in Johto and Kanto Centers (stairs / south mats) with Soil Expert badge unlocks, Berry Scholar, and farm merchant.
- Cherrygrove Rare Candy kid + soft level caps through Johto, Lance, the retuned Kanto circuit, and Red at Mt. Silver.
- **Restored Gen 1 Kanto dungeons** back into Gen 2 (layouts, trainers, items, warps): Viridian Forest, Mt. Moon, Diglett's Cave, Rock Tunnel, Safari Zone (4 zones + Secret House), Seafoam Islands (with a dedicated Blaine gym room), and Cerulean Cave. Wilds/trainers scaled for postgame; Articuno (Seafoam B4F) and Mewtwo (Cerulean Cave B1F) return; Mt. Moon hosts the Silver rematch.
- Kanto outdoor wilds rebuilt with Gen 3 postgame grass tables (~Lv 28–40+ on routes; restored caves higher, roughly mid-40s into the 60s). Johto grass keeps each cart's natives, cross-injects the host's missing Gold/Silver/Crystal wild exclusives, and adds curated Gen 3 guests in rare slots.
- **Retuned Kanto postgame level curve:** gym leaders ~52–72 (Surge → Blue), gym trainees / Fighting Dojo / Nugget Bridge / route trainers matched to that band, dungeon parties in the mid-40s–60s. Soft level caps track it (58 → 64 → 72 → 85 → 100).
- Moon Stone trade-evo bypasses (Steelix, Scizor, Politoed, Slowking, Porygon2, etc.).
- Utility NPCs relocated for Gen 2 Kanto: Move Hub at Mr. Psychic's (Saffron), Item Smith at Cinnabar Center 1F, Judge in the Underground Path.
- Crystal keeps its native gender select / Kris / cart bugfixes; KR does not pull Crystal animated front sheets into Gen1-shared art.
- Battle pics prefer converted **RawSprites** grayscale under `assets/gs/` (fallback: flat `assets/*_{front,back}.png`, then ROM). The old **SPRITES 1-251** Gold/Silver/Crystal cache option is retired.

**Sevii Islands:** On hold. Maps, ferry, and tooling live under `sevii/` but are not loaded (`SEVII_ENABLED = false`). Reserved map ids stay reserved; no Sevii play path until that work resumes.

To install and play, grab the latest `.zip` release and install it into your game's `mods/` directory.

## Battle sprites

Kanto Reforged wholesale replaces Pokémon battle sprites across Gens 1–3 with custom classic-styled art to ensure visual parity with the classic Gen 1/Gen 2 Game Boy aesthetic. All sprites and species data are pre-packaged and hand-authored directly within the mod.

At runtime, `core/sprite_resolve.lua` dynamically resolves battle sprites through three tiers:
- **gs (`assets/gs/`)**: Converted custom sprite sets & animation strips by community artists (**SageDeoxys** and **Nuukiie**).
- **base assets (`assets/`)**: Flat custom fallback sprites created by **1jamie / lady_gaia**, used whenever a species is missing from the `gs` sets and falls through to base assets.
- **ROM**: Fallback to vanilla game battle sprites for remaining base Gen 1 species where custom art is not yet provided.
- Backs stay 48×48; Gen 1 automatically scales back sprites so on-screen proportions match seamlessly.

> [!CAUTION]
> All species data, learnsets, and battle sprites are fully hand-authored and pre-packaged in the repository. Do **not** run legacy generation scripts against this mod, as doing so will overwrite and break hand-crafted assets.

## What it looks like

![Party with Johto/Hoenn mons](screen-shots/party-menu.png)

![Wild Azurill in a Gen 1 battle](screen-shots/wild-azurill.png)

![Berry Farm plots](screen-shots/berry-farm.png)

## Features

- Johto and Hoenn species (dex 152 through 386), with sprites, learnsets, and Gen 3 abilities. All dex #1–386 use Gen 3 Emerald-first learnsets (runtime `learnset_gen3.lua`); original 151 also get Gen 3 abilities.
- Dark, Steel, and Fairy types, and a big Gen 2/3 move list (Rollout, weather, hazards, status berries, that kind of thing). Damaging moves use Gen 3 type categories (not Gen 4 per-move split). Pursuit hits switch-outs for double damage. Sucker Punch / Me First read the foe’s selected move. Variable-power moves (Natural Gift, Gyro Ball, etc.) scale properly. Doubles-only moves are stripped.
- Curated Gen 2/3 mixes in wilds, gyms, Elite Four, and the rival. Optional **FULL SPAWN MIX** / **PURE RANDOM SPAWN** reshuffle from the Gen 1–3 pool (Gold density pass keeps Kanto full; **LEGENDS IN MIX** can open the legendary pool).
- **Gold Kanto restored dungeons:** Gen 1 layouts for Viridian Forest, Mt. Moon, Diglett's Cave, Rock Tunnel, Safari Zone, Seafoam (+ Blaine gym), and Cerulean Cave, with postgame-scaled encounters, trainers, Articuno / Mewtwo, and the Mt. Moon Silver fight.
- **Gold Kanto level curve:** gyms, routes, Dojo, Nugget Bridge, and restored dungeon parties retuned as one postgame band (leaders ~52–72; Blue / Silver / Red sit at the top). Opt-in level caps follow the same milestones (Kanto: 58 / 64 / 72 / 85 / 100).
- Moon Stone evolutions to bypass trade-evolution requirements (Onix→Steelix, Scyther→Scizor, Poliwhirl→Politoed, Slowpoke→Slowking, Porygon→Porygon2, Gloom→Bellossom, Eevee→Umbreon, Sunkern→Sunflora, etc.).
- Held items: berries, Leftovers, Focus Band, type boosters, plus Choice Band / Life Orb / Focus Sash from house NPCs and the blacksmith. Give/Take from the party menu (optional **BAG GIVE** from the bag). Berries work from the bag. Leftovers and Focus Band are overworld finds. Status berries are not sold in city marts — plant at the farm, buy unlocked ones from the farm merchant, or TAKE them off wilds.
- Berry Farm map (right carpet in Gen 1 Centers; stairs / south pads in Gen 2 Centers). Plant, walk, harvest. Soil Expert unlocks by badge (gifts 3 of each new type once). Farm merchant sells unlocked berries. Berry Scholar explains effects.

![Celadon Mansion Juice Club blender](screen-shots/juice-blender.png)

- Optional smarter trainer AI, **XP SHARE (SLOT 2)** (~70% to fighters, up to ~30% to party slot 2), and story level caps.
- Opt-in level caps: Rare Candy kid outside Viridian Mart (Gen 1) or in Cherrygrove (Gen 2). Accepting tops you toward 99 Rare Candies and enables soft caps that rise with story / badges.
- DexNav: start menu on Red after the Pokédex; Pokegear card on Gold via `pokegear_cards`.
- Battle sprites: converted RawSprites under `assets/gs/` (fallback flat assets / ROM). Anim strips are stored for a later playback phase.
- Party summary page for ability, held item, and gender glyph (Page 3 on Gen 1, Page 4 on Gen 2 with ability text).
- Optional Gen1 Modern UI support for bag pockets and the summary ability page on Red.
[https://github.com/ArmstrongThomas/gen1-modern-ui/](https://github.com/ArmstrongThomas/gen1-modern-ui/)

![Summary page with ability text](screen-shots/summary-ability.png)

- Gender on every mon from Gen 2 DV rules.
- Bag pockets on Gen 1 via optional `gen1_bag_pockets` (Items, Balls, Key Items, TMs & HMs, capacity 60). KR adds the Berries pocket and **BAG GIVE** when both are enabled; KR alone still ships the full five-pocket fallback.

![Berries pocket](screen-shots/bag-berries.png)
![TMs & HMs pocket](screen-shots/bag-tms.png)

- Optional **EXP BAR** on Gen 1: blue EXP bar under the HP bar (Gen 2 style, widescreen-aware; toggleable).
- Route 5 Day Care: two parents, Eggs, hatching (Gen 1).
- House NPCs: Move Hub (relearn/tutor/delete), Item Smith (Life Orb / Focus Sash / berry packs), DV/Hidden Power Judge.
- Roaming beasts / Eon duo with Radar + Pokédex AREA, plus Gen 2–3 legendary statics in Gen 1.

## Overworld NPCs

Short classic style house NPCs. No natures/IVs; the judge reads DVs / Hidden Power / `statExp`.

- **Celadon Circuit** (Mansion 2F): rematchable club; first clear gives Choice Band.
- **Night Eyes** (Vermilion Pidgey House): Dark-type gate; Blackglasses or money.
- **Snack Scout** (Celadon Hotel): lead must hold a berry; first clear Focus Sash.
- **Judge** (UG Path): DV / Hidden Power / effort read for a party mon (Route 5 side on Gen 1; main tunnel on Gen 2).
- **Trades**: Route 2 house Rattata→Taillow (Cleanse Tag); Fuchsia Bills Grandpa Bellsprout→Seedot (Soothe Bell).
- **Berry economy**: status berries are not sold in city marts. Unlock plant types via badges (Soil Expert). Each unlock gifts 3 of that berry once. Buy more anytime from the farm merchant (¥300 / ¥600 / ¥2000 Lum). Base grow is 320 steps (Soil ranks speed it up). Celadon Mansion 3F blender: 10 berries → 1 vitamin, plus a step cool-down.
- **Move Hub** (Saffron Pidgey House on Gen 1 / Mr. Psychic's House on Gen 2): relearn / tutor / delete; Heart Scale costs where noted.
- **Blacksmith** (Cinnabar Metronome Room on Gen 1 / Cinnabar Pokecenter 1F on Gen 2): Metal Coat→Life Orb, Nuggets→Focus Sash, Leaf Stone→berry pack.
- **Gen 3 fossils** (Gen 1): Root/Claw fossils + Cinnabar lab revive.

Competitive held items (Choice Band, Life Orb, Focus Sash) work in battle: band locks and boosts physical damage, Life Orb recoil, sash survives one lethal hit from full HP.

## Options

Configured in the mod manager / F10 options. Host-scoped keys (spawn/scope) keep Red and Gold settings independent.

- **DEX SCOPE / JOHTO SCOPE** (default NATIONAL / FULL): Gen 1 **KANTO** locks to the original 151 (out-of-scope party/PC mons stash and restore when you switch back). Gen 2 **JOHTO 251** caps Johto wilds at dex 251; Kanto postgame (including restored dungeons) still gets Gen 3 guests.
- **FULL SPAWN MIX** (default off): rebuild wild tables from the Gen 1–3 pool (habitat / level gated). Gold reshuffles Johto + Kanto with a density pass so Kanto stays full. Applies live mid-session.
- **PURE RANDOM SPAWN** (default off): chaos pick from the allowed dex — no habitat / stage / BST gates. Overrides FULL SPAWN MIX when both are on.
- **LEGENDS IN MIX** (default off): with FULL SPAWN MIX or PURE RANDOM SPAWN on, legendaries/mythicals can appear (level-gated). Curated mode ignores this (including a leftover on if you turn FULL/PURE off).
- **XP SHARE (SLOT 2)** (default on): fighters get ~70% of the XP pool; party slot 2 up to ~30% (never more than a solo share total).
- **SMARTER AI** (default on): prefer useful damage, skip moves that would fail.
- **SWITCH HIT AI** (default classic): free-hit timing on switch — **CLASSIC** after send-out vs **GEN 3** lock-on-switch. Same labels on Red and Gold.
- **BAG GIVE** (default on): Give held items from the bag as well as from the party menu.
- **RULESET** (Red only, default MODERN): mirrors OPTIONS → RULESET. **MODERN** cleans Gen 1 quirks and uses Gen 3 crit stages; **GEN 1** keeps faithful quirks. Seeded once when KR is first enabled; either UI stays in sync. Hidden on Gold.
- **SP.ATK / SP.DEF** (Red only, default on): separate Sp.Atk / Sp.Def bases for special damage and summary UI; off keeps Gen 1 single Special. Hidden on Gold (already split).
- **EXP BAR** (Red only, default on): blue EXP bar under the HP bar in battle (widescreen-aware). Hidden on Gold (native bar).
- **DEXNAV** (Red only): start-menu label / off. Gold DexNav is the Pokegear card (no rename toggle).

## Installing in the game

1. Grab the latest `.zip` from releases.
2. Put `Kanto-Reforged/` under the game's `mods/` folder, or install the zip from the launcher.
3. Enable Kanto Reforged (and `pokegear_cards` if playing Gold) and start or continue a save.

## Full guides

- **[WALKTHROUGH.md](WALKTHROUGH.md)**: step-by-step walkthrough for both Gen 1 (Red/Blue) and Gen 2 (Gold), written like youre playing through
- **[FEATURES.md](FEATURES.md)**: full reference (numbers, locations, unlock gates, prices, recipes, module map)

## Credits

- **Data & Foundations:**
  - **PokeAPI** for species, learnsets, moves, and habitat data.
  - **pret/pokered** & **pret/pokecrystal** and the recomp project for the decompilation and base game engine foundations.
  - **gen1recomp++** recomp project for the Gen 1 base.

### Battle Sprite Replacement & Credits

Kanto Reforged wholesale replaces battle sprites across Gens 1–3 with custom retro-styled art to give all Pokémon authentic visual parity with the classic Gen 1 and Gen 2 Game Boy engines.

Sprite asset tiers and resolution rules:
- **`gs` (`assets/gs/`)**: Converted custom sprite sets & animation strips created by community artists (**SageDeoxys** and **Nuukiie**, mapped per `assets/g1-3 credit.csv` plus Kecleon by SageDeoxys).
- **`base assets` (`assets/`)**: Flat custom fallback sprites created by **1jamie / lady_gaia**, credited only when a species is missing in the `gs` sets and falls through to base assets.
- **`ROM`**: Vanilla game battle sprites from Game Freak for remaining base Gen 1 species where custom art is not yet included.

For a standalone reference document, see [SPRITE_CREDITS.md](SPRITE_CREDITS.md).

If you would like to go check out the awesome creators that did the heavy lifting with the art you can find them here! please give them some love for their amazing work <3

- [Nuukiie on X](https://x.com/nuukiie)
- [SageDeoxys on X](https://x.com/SageDeoxys)


AND DO NOT FORGET THE ABSOLUTE LEGEND THAT DID THE HARD WORKING OF GETTING ALL THIS PUT TOGETHER AND GETTING PERMISSONS AND PUTING IT INTO AND ORANIZED PLACE FOR ME!!!! TTiN 


#### Granular Battle Sprite Credits (Dex 1–386)

| Dex | Species | Artist | Source |
| ---: | --- | --- | --- |
| 1 | Bulbasaur | Game Freak (vanilla) | ROM |
| 2 | Ivysaur | Game Freak (vanilla) | ROM |
| 3 | Venusaur | Game Freak (vanilla) | ROM |
| 4 | Charmander | SageDeoxys | gs |
| 5 | Charmeleon | SageDeoxys | gs |
| 6 | Charizard | SageDeoxys | gs |
| 7 | Squirtle | Game Freak (vanilla) | ROM |
| 8 | Wartortle | Game Freak (vanilla) | ROM |
| 9 | Blastoise | Game Freak (vanilla) | ROM |
| 10 | Caterpie | Game Freak (vanilla) | ROM |
| 11 | Metapod | Game Freak (vanilla) | ROM |
| 12 | Butterfree | Game Freak (vanilla) | ROM |
| 13 | Weedle | SageDeoxys | gs |
| 14 | Kakuna | SageDeoxys | gs |
| 15 | Beedrill | SageDeoxys | gs |
| 16 | Pidgey | Game Freak (vanilla) | ROM |
| 17 | Pidgeotto | Game Freak (vanilla) | ROM |
| 18 | Pidgeot | Game Freak (vanilla) | ROM |
| 19 | Rattata | Game Freak (vanilla) | ROM |
| 20 | Raticate | Game Freak (vanilla) | ROM |
| 21 | Spearow | Game Freak (vanilla) | ROM |
| 22 | Fearow | Game Freak (vanilla) | ROM |
| 23 | Ekans | SageDeoxys | gs |
| 24 | Arbok | SageDeoxys | gs |
| 25 | Pikachu | SageDeoxys | gs |
| 26 | Raichu | Nuukiie | gs |
| 27 | Sandshrew | SageDeoxys | gs |
| 28 | Sandslash | Game Freak (vanilla) | ROM |
| 29 | Nidoran♀ | Game Freak (vanilla) | ROM |
| 30 | Nidorina | Game Freak (vanilla) | ROM |
| 31 | Nidoqueen | Game Freak (vanilla) | ROM |
| 32 | Nidoran♂ | Game Freak (vanilla) | ROM |
| 33 | Nidorino | Game Freak (vanilla) | ROM |
| 34 | Nidoking | Game Freak (vanilla) | ROM |
| 35 | Clefairy | SageDeoxys | gs |
| 36 | Clefable | SageDeoxys | gs |
| 37 | Vulpix | Game Freak (vanilla) | ROM |
| 38 | Ninetales | Game Freak (vanilla) | ROM |
| 39 | Jigglypuff | SageDeoxys | gs |
| 40 | Wigglytuff | SageDeoxys | gs |
| 41 | Zubat | SageDeoxys | gs |
| 42 | Golbat | SageDeoxys | gs |
| 43 | Oddish | SageDeoxys | gs |
| 44 | Gloom | SageDeoxys | gs |
| 45 | Vileplume | SageDeoxys | gs |
| 46 | Paras | Game Freak (vanilla) | ROM |
| 47 | Parasect | SageDeoxys | gs |
| 48 | Venonat | Game Freak (vanilla) | ROM |
| 49 | Venomoth | Game Freak (vanilla) | ROM |
| 50 | Diglett | SageDeoxys | gs |
| 51 | Dugtrio | SageDeoxys | gs |
| 52 | Meowth | Nuukiie | gs |
| 53 | Persian | Nuukiie | gs |
| 54 | Psyduck | Game Freak (vanilla) | ROM |
| 55 | Golduck | Game Freak (vanilla) | ROM |
| 56 | Mankey | Game Freak (vanilla) | ROM |
| 57 | Primeape | Game Freak (vanilla) | ROM |
| 58 | Growlithe | SageDeoxys | gs |
| 59 | Arcanine | Game Freak (vanilla) | ROM |
| 60 | Poliwag | Game Freak (vanilla) | ROM |
| 61 | Poliwhirl | Game Freak (vanilla) | ROM |
| 62 | Poliwrath | Game Freak (vanilla) | ROM |
| 63 | Abra | Game Freak (vanilla) | ROM |
| 64 | Kadabra | Game Freak (vanilla) | ROM |
| 65 | Alakazam | Game Freak (vanilla) | ROM |
| 66 | Machop | Game Freak (vanilla) | ROM |
| 67 | Machoke | Game Freak (vanilla) | ROM |
| 68 | Machamp | Game Freak (vanilla) | ROM |
| 69 | Bellsprout | SageDeoxys | gs |
| 70 | Weepinbell | SageDeoxys | gs |
| 71 | Victreebel | SageDeoxys | gs |
| 72 | Tentacool | Game Freak (vanilla) | ROM |
| 73 | Tentacruel | Game Freak (vanilla) | ROM |
| 74 | Geodude | SageDeoxys | gs |
| 75 | Graveler | SageDeoxys | gs |
| 76 | Golem | SageDeoxys | gs |
| 77 | Ponyta | Game Freak (vanilla) | ROM |
| 78 | Rapidash | Game Freak (vanilla) | ROM |
| 79 | Slowpoke | Game Freak (vanilla) | ROM |
| 80 | Slowbro | Game Freak (vanilla) | ROM |
| 81 | Magnemite | SageDeoxys | gs |
| 82 | Magneton | SageDeoxys | gs |
| 83 | Farfetch’d | Game Freak (vanilla) | ROM |
| 84 | Doduo | Game Freak (vanilla) | ROM |
| 85 | Dodrio | Game Freak (vanilla) | ROM |
| 86 | Seel | Game Freak (vanilla) | ROM |
| 87 | Dewgong | Game Freak (vanilla) | ROM |
| 88 | Grimer | Nuukiie | gs |
| 89 | Muk | Nuukiie | gs |
| 90 | Shellder | SageDeoxys | gs |
| 91 | Cloyster | SageDeoxys | gs |
| 92 | Gastly | SageDeoxys | gs |
| 93 | Haunter | SageDeoxys | gs |
| 94 | Gengar | SageDeoxys | gs |
| 95 | Onix | Game Freak (vanilla) | ROM |
| 96 | Drowzee | Game Freak (vanilla) | ROM |
| 97 | Hypno | Game Freak (vanilla) | ROM |
| 98 | Krabby | Game Freak (vanilla) | ROM |
| 99 | Kingler | Game Freak (vanilla) | ROM |
| 100 | Voltorb | SageDeoxys | gs |
| 101 | Electrode | SageDeoxys | gs |
| 102 | Exeggcute | Game Freak (vanilla) | ROM |
| 103 | Exeggutor | Nuukiie | gs |
| 104 | Cubone | Game Freak (vanilla) | ROM |
| 105 | Marowak | Nuukiie | gs |
| 106 | Hitmonlee | Game Freak (vanilla) | ROM |
| 107 | Hitmonchan | Game Freak (vanilla) | ROM |
| 108 | Lickitung | Game Freak (vanilla) | ROM |
| 109 | Koffing | SageDeoxys | gs |
| 110 | Weezing | SageDeoxys | gs |
| 111 | Rhyhorn | Game Freak (vanilla) | ROM |
| 112 | Rhydon | Game Freak (vanilla) | ROM |
| 113 | Chansey | Game Freak (vanilla) | ROM |
| 114 | Tangela | SageDeoxys | gs |
| 115 | Kangaskhan | Game Freak (vanilla) | ROM |
| 116 | Horsea | Game Freak (vanilla) | ROM |
| 117 | Seadra | Game Freak (vanilla) | ROM |
| 118 | Goldeen | Game Freak (vanilla) | ROM |
| 119 | Seaking | Game Freak (vanilla) | ROM |
| 120 | Staryu | Game Freak (vanilla) | ROM |
| 121 | Starmie | Game Freak (vanilla) | ROM |
| 122 | Mr. Mime | SageDeoxys | gs |
| 123 | Scyther | SageDeoxys | gs |
| 124 | Jynx | Game Freak (vanilla) | ROM |
| 125 | Electabuzz | Game Freak (vanilla) | ROM |
| 126 | Magmar | Game Freak (vanilla) | ROM |
| 127 | Pinsir | Game Freak (vanilla) | ROM |
| 128 | Tauros | Game Freak (vanilla) | ROM |
| 129 | Magikarp | SageDeoxys | gs |
| 130 | Gyarados | SageDeoxys | gs |
| 131 | Lapras | SageDeoxys | gs |
| 132 | Ditto | SageDeoxys | gs |
| 133 | Eevee | SageDeoxys | gs |
| 134 | Vaporeon | Game Freak (vanilla) | ROM |
| 135 | Jolteon | Game Freak (vanilla) | ROM |
| 136 | Flareon | Game Freak (vanilla) | ROM |
| 137 | Porygon | SageDeoxys | gs |
| 138 | Omanyte | SageDeoxys | gs |
| 139 | Omastar | Game Freak (vanilla) | ROM |
| 140 | Kabuto | Game Freak (vanilla) | ROM |
| 141 | Kabutops | Game Freak (vanilla) | ROM |
| 142 | Aerodactyl | Game Freak (vanilla) | ROM |
| 143 | Snorlax | SageDeoxys | gs |
| 144 | Articuno | Game Freak (vanilla) | ROM |
| 145 | Zapdos | Game Freak (vanilla) | ROM |
| 146 | Moltres | Game Freak (vanilla) | ROM |
| 147 | Dratini | SageDeoxys | gs |
| 148 | Dragonair | SageDeoxys | gs |
| 149 | Dragonite | SageDeoxys | gs |
| 150 | Mewtwo | SageDeoxys | gs |
| 151 | Mew | SageDeoxys | gs |
| 152 | Chikorita | SageDeoxys | gs |
| 153 | Bayleef | 1jamie / lady_gaia | base assets |
| 154 | Meganium | SageDeoxys | gs |
| 155 | Cyndaquil | 1jamie / lady_gaia | base assets |
| 156 | Quilava | 1jamie / lady_gaia | base assets |
| 157 | Typhlosion | SageDeoxys | gs |
| 158 | Totodile | SageDeoxys | gs |
| 159 | Croconaw | 1jamie / lady_gaia | base assets |
| 160 | Feraligatr | 1jamie / lady_gaia | base assets |
| 161 | Sentret | 1jamie / lady_gaia | base assets |
| 162 | Furret | 1jamie / lady_gaia | base assets |
| 163 | Hoothoot | SageDeoxys | gs |
| 164 | Noctowl | 1jamie / lady_gaia | base assets |
| 165 | Ledyba | 1jamie / lady_gaia | base assets |
| 166 | Ledian | 1jamie / lady_gaia | base assets |
| 167 | Spinarak | 1jamie / lady_gaia | base assets |
| 168 | Ariados | 1jamie / lady_gaia | base assets |
| 169 | Crobat | SageDeoxys | gs |
| 170 | Chinchou | SageDeoxys | gs |
| 171 | Lanturn | 1jamie / lady_gaia | base assets |
| 172 | Pichu | SageDeoxys | gs |
| 173 | Cleffa | SageDeoxys | gs |
| 174 | Igglybuff | SageDeoxys | gs |
| 175 | Togepi | 1jamie / lady_gaia | base assets |
| 176 | Togetic | 1jamie / lady_gaia | base assets |
| 177 | Natu | SageDeoxys | gs |
| 178 | Xatu | SageDeoxys | gs |
| 179 | Mareep | 1jamie / lady_gaia | base assets |
| 180 | Flaaffy | 1jamie / lady_gaia | base assets |
| 181 | Ampharos | 1jamie / lady_gaia | base assets |
| 182 | Bellossom | SageDeoxys | gs |
| 183 | Marill | SageDeoxys | gs |
| 184 | Azumarill | SageDeoxys | gs |
| 185 | Sudowoodo | 1jamie / lady_gaia | base assets |
| 186 | Politoed | 1jamie / lady_gaia | base assets |
| 187 | Hoppip | 1jamie / lady_gaia | base assets |
| 188 | Skiploom | 1jamie / lady_gaia | base assets |
| 189 | Jumpluff | SageDeoxys | gs |
| 190 | Aipom | 1jamie / lady_gaia | base assets |
| 191 | Sunkern | 1jamie / lady_gaia | base assets |
| 192 | Sunflora | 1jamie / lady_gaia | base assets |
| 193 | Yanma | 1jamie / lady_gaia | base assets |
| 194 | Wooper | Nuukiie | gs |
| 195 | Quagsire | SageDeoxys | gs |
| 196 | Espeon | 1jamie / lady_gaia | base assets |
| 197 | Umbreon | 1jamie / lady_gaia | base assets |
| 198 | Murkrow | 1jamie / lady_gaia | base assets |
| 199 | Slowking | 1jamie / lady_gaia | base assets |
| 200 | Misdreavus | 1jamie / lady_gaia | base assets |
| 201 | Unown | SageDeoxys | gs |
| 202 | Wobbuffet | SageDeoxys | gs |
| 203 | Girafarig | 1jamie / lady_gaia | base assets |
| 204 | Pineco | SageDeoxys | gs |
| 205 | Forretress | SageDeoxys | gs |
| 206 | Dunsparce | SageDeoxys | gs |
| 207 | Gligar | 1jamie / lady_gaia | base assets |
| 208 | Steelix | 1jamie / lady_gaia | base assets |
| 209 | Snubbull | 1jamie / lady_gaia | base assets |
| 210 | Granbull | 1jamie / lady_gaia | base assets |
| 211 | Qwilfish | SageDeoxys | gs |
| 212 | Scizor | SageDeoxys | gs |
| 213 | Shuckle | SageDeoxys | gs |
| 214 | Heracross | 1jamie / lady_gaia | base assets |
| 215 | Sneasel | 1jamie / lady_gaia | base assets |
| 216 | Teddiursa | SageDeoxys | gs |
| 217 | Ursaring | SageDeoxys | gs |
| 218 | Slugma | SageDeoxys | gs |
| 219 | Magcargo | SageDeoxys | gs |
| 220 | Swinub | SageDeoxys | gs |
| 221 | Piloswine | SageDeoxys | gs |
| 222 | Corsola | Nuukiie | gs |
| 223 | Remoraid | 1jamie / lady_gaia | base assets |
| 224 | Octillery | 1jamie / lady_gaia | base assets |
| 225 | Delibird | 1jamie / lady_gaia | base assets |
| 226 | Mantine | SageDeoxys | gs |
| 227 | Skarmory | SageDeoxys | gs |
| 228 | Houndour | 1jamie / lady_gaia | base assets |
| 229 | Houndoom | 1jamie / lady_gaia | base assets |
| 230 | Kingdra | 1jamie / lady_gaia | base assets |
| 231 | Phanpy | SageDeoxys | gs |
| 232 | Donphan | 1jamie / lady_gaia | base assets |
| 233 | Porygon2 | SageDeoxys | gs |
| 234 | Stantler | 1jamie / lady_gaia | base assets |
| 235 | Smeargle | SageDeoxys | gs |
| 236 | Tyrogue | 1jamie / lady_gaia | base assets |
| 237 | Hitmontop | 1jamie / lady_gaia | base assets |
| 238 | Smoochum | 1jamie / lady_gaia | base assets |
| 239 | Elekid | 1jamie / lady_gaia | base assets |
| 240 | Magby | 1jamie / lady_gaia | base assets |
| 241 | Miltank | 1jamie / lady_gaia | base assets |
| 242 | Blissey | 1jamie / lady_gaia | base assets |
| 243 | Raikou | 1jamie / lady_gaia | base assets |
| 244 | Entei | 1jamie / lady_gaia | base assets |
| 245 | Suicune | 1jamie / lady_gaia | base assets |
| 246 | Larvitar | SageDeoxys | gs |
| 247 | Pupitar | SageDeoxys | gs |
| 248 | Tyranitar | SageDeoxys | gs |
| 249 | Lugia | 1jamie / lady_gaia | base assets |
| 250 | Ho-Oh | 1jamie / lady_gaia | base assets |
| 251 | Celebi | SageDeoxys | gs |
| 252 | Treecko | Nuukiie | gs |
| 253 | Grovyle | Nuukiie | gs |
| 254 | Sceptile | Nuukiie | gs |
| 255 | Torchic | Nuukiie | gs |
| 256 | Combusken | Nuukiie | gs |
| 257 | Blaziken | Nuukiie | gs |
| 258 | Mudkip | Nuukiie | gs |
| 259 | Marshtomp | Nuukiie | gs |
| 260 | Swampert | Nuukiie | gs |
| 261 | Poochyena | Nuukiie | gs |
| 262 | Mightyena | Nuukiie | gs |
| 263 | Zigzagoon | Nuukiie | gs |
| 264 | Linoone | Nuukiie | gs |
| 265 | Wurmple | Nuukiie | gs |
| 266 | Silcoon | Nuukiie | gs |
| 267 | Beautifly | Nuukiie | gs |
| 268 | Cascoon | Nuukiie | gs |
| 269 | Dustox | Nuukiie | gs |
| 270 | Lotad | Nuukiie | gs |
| 271 | Lombre | Nuukiie | gs |
| 272 | Ludicolo | Nuukiie | gs |
| 273 | Seedot | Nuukiie | gs |
| 274 | Nuzleaf | Nuukiie | gs |
| 275 | Shiftry | Nuukiie | gs |
| 276 | Taillow | Nuukiie | gs |
| 277 | Swellow | Nuukiie | gs |
| 278 | Wingull | Nuukiie | gs |
| 279 | Pelipper | Nuukiie | gs |
| 280 | Ralts | Nuukiie | gs |
| 281 | Kirlia | Nuukiie | gs |
| 282 | Gardevoir | Nuukiie | gs |
| 283 | Surskit | Nuukiie | gs |
| 284 | Masquerain | Nuukiie | gs |
| 285 | Shroomish | Nuukiie | gs |
| 286 | Breloom | Nuukiie | gs |
| 287 | Slakoth | Nuukiie | gs |
| 288 | Vigoroth | Nuukiie | gs |
| 289 | Slaking | Nuukiie | gs |
| 290 | Nincada | Nuukiie | gs |
| 291 | Ninjask | Nuukiie | gs |
| 292 | Shedinja | Nuukiie | gs |
| 293 | Whismur | Nuukiie | gs |
| 294 | Loudred | Nuukiie | gs |
| 295 | Exploud | Nuukiie | gs |
| 296 | Makuhita | Nuukiie | gs |
| 297 | Hariyama | Nuukiie | gs |
| 298 | Azurill | Nuukiie | gs |
| 299 | Nosepass | Nuukiie | gs |
| 300 | Skitty | Nuukiie | gs |
| 301 | Delcatty | Nuukiie | gs |
| 302 | Sableye | Nuukiie | gs |
| 303 | Mawile | Nuukiie | gs |
| 304 | Aron | Nuukiie | gs |
| 305 | Lairon | Nuukiie | gs |
| 306 | Aggron | Nuukiie | gs |
| 307 | Meditite | Nuukiie | gs |
| 308 | Medicham | Nuukiie | gs |
| 309 | Electrike | Nuukiie | gs |
| 310 | Manectric | Nuukiie | gs |
| 311 | Plusle | Nuukiie | gs |
| 312 | Minun | Nuukiie | gs |
| 313 | Volbeat | Nuukiie | gs |
| 314 | Illumise | Nuukiie | gs |
| 315 | Roselia | Nuukiie | gs |
| 316 | Gulpin | Nuukiie | gs |
| 317 | Swalot | Nuukiie | gs |
| 318 | Carvanha | Nuukiie | gs |
| 319 | Sharpedo | Nuukiie | gs |
| 320 | Wailmer | Nuukiie | gs |
| 321 | Wailord | Nuukiie | gs |
| 322 | Numel | Nuukiie | gs |
| 323 | Camerupt | Nuukiie | gs |
| 324 | Torkoal | Nuukiie | gs |
| 325 | Spoink | Nuukiie | gs |
| 326 | Grumpig | Nuukiie | gs |
| 327 | Spinda | Nuukiie | gs |
| 328 | Trapinch | Nuukiie | gs |
| 329 | Vibrava | Nuukiie | gs |
| 330 | Flygon | Nuukiie | gs |
| 331 | Cacnea | Nuukiie | gs |
| 332 | Cacturne | Nuukiie | gs |
| 333 | Swablu | Nuukiie | gs |
| 334 | Altaria | Nuukiie | gs |
| 335 | Zangoose | Nuukiie | gs |
| 336 | Seviper | Nuukiie | gs |
| 337 | Lunatone | Nuukiie | gs |
| 338 | Solrock | Nuukiie | gs |
| 339 | Barboach | Nuukiie | gs |
| 340 | Whiscash | Nuukiie | gs |
| 341 | Corphish | Nuukiie | gs |
| 342 | Crawdaunt | Nuukiie | gs |
| 343 | Baltoy | SageDeoxys | gs |
| 344 | Claydol | SageDeoxys | gs |
| 345 | Lileep | SageDeoxys | gs |
| 346 | Cradily | SageDeoxys | gs |
| 347 | Anorith | SageDeoxys | gs |
| 348 | Armaldo | 1jamie / lady_gaia | base assets |
| 349 | Feebas | SageDeoxys | gs |
| 350 | Milotic | 1jamie / lady_gaia | base assets |
| 351 | Castform | SageDeoxys | gs |
| 352 | Kecleon | SageDeoxys | gs |
| 353 | Shuppet | SageDeoxys | gs |
| 354 | Banette | 1jamie / lady_gaia | base assets |
| 355 | Duskull | 1jamie / lady_gaia | base assets |
| 356 | Dusclops | 1jamie / lady_gaia | base assets |
| 357 | Tropius | 1jamie / lady_gaia | base assets |
| 358 | Chimecho | SageDeoxys | gs |
| 359 | Absol | SageDeoxys | gs |
| 360 | Wynaut | SageDeoxys | gs |
| 361 | Snorunt | Nuukiie | gs |
| 362 | Glalie | Nuukiie | gs |
| 363 | Spheal | 1jamie / lady_gaia | base assets |
| 364 | Sealeo | 1jamie / lady_gaia | base assets |
| 365 | Walrein | 1jamie / lady_gaia | base assets |
| 366 | Clamperl | 1jamie / lady_gaia | base assets |
| 367 | Huntail | 1jamie / lady_gaia | base assets |
| 368 | Gorebyss | 1jamie / lady_gaia | base assets |
| 369 | Relicanth | SageDeoxys | gs |
| 370 | Luvdisc | SageDeoxys | gs |
| 371 | Bagon | SageDeoxys | gs |
| 372 | Shelgon | SageDeoxys | gs |
| 373 | Salamence | SageDeoxys | gs |
| 374 | Beldum | 1jamie / lady_gaia | base assets |
| 375 | Metang | 1jamie / lady_gaia | base assets |
| 376 | Metagross | 1jamie / lady_gaia | base assets |
| 377 | Regirock | SageDeoxys | gs |
| 378 | Regice | SageDeoxys | gs |
| 379 | Registeel | SageDeoxys | gs |
| 380 | Latias | 1jamie / lady_gaia | base assets |
| 381 | Latios | 1jamie / lady_gaia | base assets |
| 382 | Kyogre | 1jamie / lady_gaia | base assets |
| 383 | Groudon | 1jamie / lady_gaia | base assets |
| 384 | Rayquaza | 1jamie / lady_gaia | base assets |
| 385 | Jirachi | SageDeoxys | gs |
| 386 | Deoxys | SageDeoxys | gs |

