# Kanto Reforged

Gen 2 and 3 content for Red/Blue and Gold on this engine. Same classic story, more Pokemon, moves, abilities, held items, and some bag/party QoL so the extra stuff is easier to use. My goal here was not to bolt on or make things feel weird, but if Game Freak were to do these pieces back in gen1 and gen2, how would they have done it? The features added are attempted to be done in a way to make them feel like they are part of the base games, inspired by some of my favorite things from different generations and rom hacks ive played. I tried my best in the import pipeline to make the gen2-3 mons look good and look like they belong by scaling them, adjusting pixel counts, and following the color count rules and style constraints where i could. Hopefully at the end of the day it looks like an almost "alternate history" version of the classic games.

Mod id is `Kanto-Reforged`. Turn it on in the launcher Mods tab or the F10 manager.

Has support for Gen1 Modern UI mod (on Gen1) and Pokegear Cards (on Gen2).

## Current status

**RBY (generation 1 of gen1recomp++):**
Fully functional with the occasional bug still being chased down, but fully playable and all 386 are obtainable.

**Gold (generation 2 of gen1recomp++):**
Gen 2 Gold support is live and actively expanding! The core engine integration is solid:
- Full Hoenn integration (species dex 252 through 386 registered, sprites scaled, Gen 3 abilities patched onto 1–251).
- Type chart and move typing parity across both generations (Dark, Steel, Fairy matchups, physical/special types).
- Gen 3 freeze mechanics updated across battles (1/5 thaw rate per turn, fire moves melt frozen targets).
- DexNav integration via Pokegear card (requires `pokegear_cards` mod) showing current route spawns dynamically.
- Party Summary menu gets a dedicated 4th page (after stats/moves) showing ability, held item, gender glyph, and ability descriptions.
- Berry Farm fully operational in Johto and Kanto (accessible from Pokecenter stairs/mats) with Soil Expert Johto badge unlocks, Berry Scholar, and farm merchant.
- Cherrygrove Rare Candy kid and a tailored level cap progression spanning all 8 Johto gyms, E4 Lance, the overhauled Kanto postgame circuit, and Red at Mt. Silver.
- Kanto postgame wild encounters rebuilt with full Gen 3 postgame grass tables; Johto grass gets curated Gen 3 guests.
- Overhauled Kanto Gym Circuit, gym trainers, Fighting Dojo, Nugget Bridge circuit, and Mt. Moon rival with rebalanced level curves and teams.
- Moon Stone evolution bypasses for trade evolutions (Steelix, Scizor, Politoed, Slowking, Porygon2, etc.) so you can get them without trading.
- Relocated utility NPCs in Gold Kanto: Move Hub at Mr. Psychic's house in Saffron, Item Smith at Cinnabar Pokecenter 1F, and DV/HP Judge in the Underground Path.

**Sevii Islands:** On hold. Maps, ferry, and tooling live under `sevii/` but are not loaded (`SEVII_ENABLED = false`). Reserved map ids stay reserved; no Sevii play path until that work resumes.

If you are trying to play, ignore the build instructions below and go to the releases to grab the latest zip. It has custom sprites available in the release that are not in the raw repo. You do not need to generate everything yourself, just install the zip into your game.

## What it looks like

![Party with Johto/Hoenn mons](screen-shots/party-menu.png)

![Wild Azurill in a Gen 1 battle](screen-shots/wild-azurill.png)

![Berry Farm plots](screen-shots/berry-farm.png)

## Features

- Johto and Hoenn species (dex 152 through 386), with sprites, learnsets, and Gen 3 abilities. The original 151 get Gen 3 abilities too, plus some Gen 2/3 moves on learnsets and TMs.
- Dark, Steel, and Fairy types, and a big Gen 2/3 move list (Rollout, weather, hazards, status berries, that kind of thing).
- Curated Gen 2/3 mixes in wilds, gyms, Elite Four, and the rival. Optional FULL SPAWN MIX rolls encounters from the whole Gen 1 through 3 pool (with a density pass so Kanto stays full on Gold).
- Moon Stone evolutions to bypass trade-evolution requirements (Moon Stone evolves Onix→Steelix, Scyther→Scizor, Poliwhirl→Politoed, Slowpoke→Slowking, Porygon→Porygon2, Gloom→Bellossom, Eevee→Umbreon, Sunkern→Sunflora, etc.).
- Held items: berries, Leftovers, Focus Band, type boosters, plus Choice Band / Life Orb / Focus Sash from house NPCs and the blacksmith. Give/Take from the party menu. Berries can be used from the bag. Leftovers and Focus Band are overworld finds. Status berries are not sold in city marts. You plant berries at the farm to grow more, buy unlocked ones from the farm merchant, or find them held on wilds.
- Berry Farm map (accessible via the right carpet in Gen 1 Centers, or the stairs / south pads in Gen 2 Centers). Plant a berry, walk, harvest more. Badge unlocks open new berry types via the Soil Expert. First unlock of each type gifts you 3 so you can plant without eating your last one. Farm merchant sells whatever youve unlocked. Berry Scholar explains effects.

![Celadon Mansion Juice Club blender](screen-shots/juice-blender.png)

- Optional smarter trainer AI, slot-2 XP Share (70% pool to fighters, up to 30% to party slot 2, never more than a solo share total), and story level caps.
- Opt-in level cap system: talk to the Rare Candy kid outside the Viridian Mart (Gen 1) or in Cherrygrove City (Gen 2). Saying yes tops you up to 99 Rare Candies and locks in level caps that expand with story milestones and gym badges to prevent overleveling.
- DexNav: On Gen 1 Red, appears on the start menu after getting the Pokédex. On Gen 2 Gold, it's a dedicated Pokegear card via the `pokegear_cards` mod.
- Party summary page for ability, held item, and gender glyph (Page 3 on Gen 1, Page 4 on Gen 2).
- Optional Gen1 Modern UI support for bag pockets and the summary ability page on Red.
[https://github.com/ArmstrongThomas/gen1-modern-ui/](https://github.com/ArmstrongThomas/gen1-modern-ui/)

![Summary page with ability text](screen-shots/summary-ability.png)

- Gender on every mon calculated from Gen 2 DV rules.
- Bag pockets on Gen 1: Items, Balls, Key Items, TMs & HMs, Berries. Bag capacity bumped to 60.

![Berries pocket](screen-shots/bag-berries.png)
![TMs & HMs pocket](screen-shots/bag-tms.png)

- Blue XP bar under the HP bar (Gen 1 gets an XP bar matching Gen 2 style, with widescreen support).
- Route 5 Day Care supports two parents, Eggs, and hatching (Gen 1).
- House NPCs for utility (Move Hub for relearn/tutor/delete, Item Smith for Life Orb / Focus Sash / berry packs, DV/Hidden Power Judge).
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

- **DEX SCOPE / JOHTO SCOPE**: Gen 1 **KANTO** locks to the original 151 (out-of-scope party/PC mons are safely stored and restored when switched back). Gen 2 **JOHTO 251** restricts Johto wild tables to dex 251 while Kanto postgame keeps Gen 3 guests.
- **FULL SPAWN MIX** (default off): random Gen 1 through 3 wild tables (Red: Kanto routes; Gold: Johto + Kanto, with a density pass so Kanto stays full).
- **PURE RANDOM SPAWN** (default off): full chaos mode with no habitat or BST constraints.
- **LEGENDS IN MIX** (default off): with FULL SPAWN MIX or PURE RANDOM on, legendaries/mythicals can appear in wild tables (level-gated).
- **XP SHARE (SLOT 2)** (default on): fighters split 70% of the XP pool; party slot 2 gets up to 30% (clamped below actives).
- **SMARTER AI** (default on): prefer useful damage, skip moves that would fail.
- **SWITCH HIT AI**: classic free-hit timing vs Gen 3 lock-on-switch (labels GEN 1/3 on Red, GEN 2/3 on Gold).
- **SP.ATK / SP.DEF** (Red only, default off): use separate Special Attack / Special Defense from PokeAPI for special damage and summary UI; off keeps Gen 1 single Special.
- **DEXNAV** (Red only): start-menu label / off (Gold uses Pokegear card).

## Generating the data files

Sprites, `pokemon_data.lua`, ability/learnset/gender/breeding patches, and berry farm art come from `generate_pokemon_mod.py`. It hits PokeAPI (and a couple public sprite sources). Run it from inside the mod folder if you're building from source.

You need Python 3, `requests`, and `Pillow`, plus network on the first run.

```bash
python3 -m pip install requests Pillow
```

### Linux and macOS

```bash
cd mods/Kanto-Reforged   # or wherever the mod lives
python3 tools/generate_pokemon_mod.py
```

### Windows

Install Python 3 from python.org and tick "Add Python to PATH". Then in Command Prompt or PowerShell:

```bat
cd path\to\Kanto-Reforged
py -m pip install requests Pillow
py tools\generate_pokemon_mod.py
```

## Installing in the game

1. Grab the latest `.zip` from releases.
2. Put `Kanto-Reforged/` under the game's `mods/` folder, or install the zip from the launcher.
3. Enable Kanto Reforged (and `pokegear_cards` if playing Gold) and start or continue a save.

## Full guides

- **[WALKTHROUGH.md](WALKTHROUGH.md)**: step-by-step walkthrough for both Gen 1 (Red/Blue) and Gen 2 (Gold), written like youre playing through
- **[FEATURES.md](FEATURES.md)**: full reference (numbers, locations, unlock gates, prices, recipes, module map)

## Credits

PokeAPI for species/moves/habitat data. pret/pokered and pret/pokecrystal and this recomp project for the base game foundations. recomp project for the Gen 1 base.
