# Kanto Reforged — Full Feature Guide

Numbers, locations, unlock gates, recipes. The short overview and install steps are in [README.md](README.md). The play-through style guide is [WALKTHROUGH.md](WALKTHROUGH.md).

Mod id: `Kanto-Reforged`. Enable it in the launcher Mods tab or the F10 manager. This mod sets `affects_link`, so both sides need matching mods for link play.

---

## Table of contents

1. [Design philosophy](#design-philosophy)
2. [Options](#options)
3. [Species, types, and moves](#species-types-and-moves)
4. [Trade Evolution Bypasses (Moon Stone)](#trade-evolution-bypasses-moon-stone)
5. [Abilities and Battle Mechanics](#abilities-and-battle-mechanics)
6. [Wild encounters and trainers](#wild-encounters-and-trainers)
7. [Gender](#gender)
8. [Day Care and breeding](#day-care-and-breeding)
9. [Held items](#held-items)
10. [Berry Farm and berry economy](#berry-farm-and-berry-economy)
11. [Bag and party QoL](#bag-and-party-qol)
12. [Level caps](#level-caps)
13. [XP Share (slot 2)](#xp-share-slot-2)
14. [Smarter AI](#smarter-ai)
15. [House NPCs and utility](#house-npcs-and-utility)
16. [Move Hub](#move-hub)
17. [Blacksmith](#blacksmith)
18. [Gen 3 fossils](#gen-3-fossils)
19. [Roaming legendaries](#roaming-legendaries)
20. [Static legendaries and mythicals](#static-legendaries-and-mythicals)
21. [Custom maps](#custom-maps)
22. [Caveats and save notes](#caveats-and-save-notes)
23. [Module map (for modders)](#module-map-for-modders)

---

## Design philosophy

Same idea as the README: if Game Freak had bolted gen2-3 pieces onto Red/Blue and Gold, how would that feel? Stories stay authentic to the originals. Stats stay DVs and `statExp` (no natures/IVs). New overworld art reuses classic sheets where it makes sense (legendaries use `SPRITE_BIRD` / `SPRITE_MONSTER` / `SPRITE_FAIRY` on purpose). Move anims and party icons borrow classic stock. House NPCs are short TextBox / ChoiceBox chats, not bloated quest logs.

---

## Options

Configured in the mod manager / F10 options:

| Option | Default | Effect |
|---|---|---|
| **DEX SCOPE** (Gen1) / **JOHTO SCOPE** (Gen2) | NATIONAL / FULL | Restricts wilds, trainers, and legends. Gen1 **KANTO** locks to the original 151 (out-of-scope party/PC mons are safely stored and restored when switched back). Gen2 **JOHTO 251** caps Johto spawns at dex 251 while Kanto postgame maps keep Gen3 guests. |
| **FULL SPAWN MIX** | Off | Rebuilds wild tables from the full Gen 1–3 pool instead of curated mixes (habitat / level gated, deterministic). On **Gold**, reshuffles Johto and Kanto grass/water (with a density pass so Kanto stays full). Mid-session toggles apply live. |
| **PURE RANDOM SPAWN** | Off | Chaos mode: seeded pick from the whole allowed dex (respects DEX/JOHTO SCOPE). No habitat, stage, or BST gates. Overrides FULL SPAWN MIX when both are on. Rolls once when toggled on and persists across loads; toggle off/on for a new mix. |
| **LEGENDS IN MIX** | Off | When FULL SPAWN MIX or PURE RANDOM SPAWN is on, allow legendaries/mythicals into the wild pool. Curated mode ignores this. |
| **XP SHARE (SLOT 2)** | On | Splits the Gen 1 XP pool: ~70% to fighters, up to ~30% to party slot 2 (never more than a solo share total). Replaces EXP.ALL while enabled. |
| **SMARTER AI** | On | Trainers (and wild scoring hooks) prefer useful damage and skip moves that would fail. |
| **SWITCH HIT AI** | Classic | Free-hit timing when you switch: classic picks after send-out; Gen 3 locks against the outgoing mon. Labels are **GEN 1 / GEN 3** on Red, **GEN 2 / GEN 3** on Gold. |
| **RULESET** | MODERN | **Red only.** Mirrors the engine OPTIONS → RULESET. **MODERN** (`modern_clean`): no 1/256 miss on 100% moves, Focus Energy helps crits, enemies spend PP, Hyper Beam always recharges, end-of-turn residuals, Gen3 crit stages. **GEN 1** (`gen1_faithful`): classic quirks. Seeded to MODERN once when KR is first enabled; flipping either UI keeps both in sync. Hidden on Gold (native Gen2 rules). |
| **SP.ATK / SP.DEF** | On | **Red only.** Special moves use separate Sp.Atk / Sp.Def bases (PokeAPI) instead of Gen 1 Special. Summary and Modern UI party/PC detail show both stats (`SAT` / `SDF`). Stages, DVs, and Calcium stay Gen 1 (one shared Special). Hidden on Gold (already split). |
| **DEXNAV** | DEXNAV | **Red only.** Start-menu label / off. Gold DexNav is a Pokegear card (no rename toggle). |

---

## Species, types, and moves

### Species

- Dex **152–386** (Johto + Hoenn) with sprites, learnsets, and Gen 3 abilities.
- Original 151 also receive Gen 3 ability assignments and selected Gen 2/3 learnset / TM backports.
- Pokédex size extended to **386**.
- Special evolution methods for branching lines (e.g. Tyrogue ATK/DEF/BAL, Wurmple A/B).
- Friendship / time / location evolutions are approximated to fit classic triggers.

![Party menu with Gen 3 species and Gen 1 icon classes](screen-shots/party-menu.png)

### Types

Custom types registered with matchups:
- **Dark**
- **Steel**
- **Fairy**

Type-chart quirks are patched to Gen2/Gen3 values on **both** Red and Gold (`type_chart_patches.lua`): Ghost hits Psychic, Bug/Poison are no longer mutual SE, Ice is weak into Fire. Dark/Steel/Fairy matchups are upserted on Gold so they match Red’s table.

### Moves

Hundreds of Gen 2–3 moves with custom effects (Rollout, weather, hazards, status berries as bag/held medicine, Hidden Power from DVs, etc.). New moves reuse Gen 1 battle animations (composed or aliased).

Vanilla Gen1 move types are patched to Gen3 on **both** hosts (`move_type_patches.lua`): Bite→Dark, Gust→Flying, Karate Chop→Fighting, Sand-Attack→Ground. Gen6 Fairy retcons on Gen2 moves (Charm, Sweet Kiss, Moonlight) stay **Normal** to match Gen3 (same policy as species typings).

Shedinja’s max HP is clamped to **1** at runtime.

---

## Trade Evolution Bypasses (Moon Stone)

To eliminate the need for link trading to evolve certain species, several trade and item-trade evolutions can be triggered directly by using a **Moon Stone** on the Pokémon:

| Base Pokémon | Evolution | Method |
|---|---|---|
| Onix | Steelix | Use Moon Stone |
| Scyther | Scizor | Use Moon Stone |
| Poliwhirl | Politoed | Use Moon Stone |
| Slowpoke | Slowking | Use Moon Stone |
| Porygon | Porygon2 | Use Moon Stone |
| Gloom | Bellossom | Use Moon Stone |
| Eevee | Umbreon | Use Moon Stone |
| Sunkern | Sunflora | Use Moon Stone |
| Clamperl | Huntail | Use Moon Stone |
| Clamperl | Gorebyss | Use Water Stone |

---

## Abilities and Battle Mechanics

### Abilities

- Gen 3 abilities on new, Johto, and Kanto species. Battle hooks cover common cases (e.g. Wonder Guard, type immunities, status prevention, Intimidate, speed boosts, etc.).
- Cute Charm / Attract / Captivate interact with the gender system.

![Summary page showing ability name + text (and gender glyph)](screen-shots/summary-ability.png)

### Battle Mechanics

- **RULESET (Red):** Defaults to **MODERN** (engine `modern_clean`) with Gen3-ish quirks and crit stages. Flip to **GEN 1** in the mod Manager or OPTIONS → RULESET to keep classic Gen1 quirks; the two UIs stay synced.
- **Physical / special:** Damaging moves use Gen3 type categories (not Gen4 per-move split). Dark/Ghost are special; Fire/Water/Grass/etc. special; Normal/Fighting/etc. physical.
- **Gen 3 Freeze Parity:** Frozen Pokémon have a 20% (1-in-5) chance to thaw naturally each turn. Furthermore, any damaging fire-type move used against a frozen target immediately unfreezes them.
- **XP Bar:** A smooth blue EXP bar displays below the player Pokémon's HP bar in battle across Gen 1 (matching Gen 2 style) with widescreen support.

---

## Wild encounters and trainers

### Wild Encounters

- **Gen 1 (Red / Blue):** Curated mixes: habitats and levels mix Gen 2–3 species into Kanto routes without replacing the whole table. A coverage pass ensures every non-legendary **line** is obtainable.
- **Gen 2 (Gold) Johto:** Native Johto tables are preserved with curated Gen 3 guests in rare slots across grasslands, forests, caves, and mountains.
- **Gen 2 (Gold) Kanto:** Fully rebuilt postgame grass tables featuring Gen 3 lines scaled from **Lv 28 to Lv 40+**.
- **Full Spawn Mix (Option):** Reshuffles all wild grass/water tables across the entire game from the Gen 1–3 pool.
- Wilds have a ~**5%** chance to hold a berry (rolled only from types you have already unlocked at the farm). Catching the mon keeps `heldItem`; use party **TAKE** to move it to the bag.

![Wild Azurill encounter in a Gen 1 battle UI](screen-shots/wild-azurill.png)

### Trainers

- **Gen 1 (Red / Blue):** Gym leaders and Elite Four get a curated **Gen 2 swap + Gen 3 add**. Ace mons hold a **berry ramp** (plain `BERRY` on Brock → status berries mid-game → Lum on Agatha/Lance). Rival mixes follow **continuity** (mid fights foreshadow a line; League fights debut finals). Tier 2 set pieces (Nugget Bridge, gym trainers, Mt. Moon, Fighting Dojo, Tower, Silph, Victory Road) get heavier mixes.
- **Gen 2 (Gold) Kanto Overhaul:** The entire Kanto postgame circuit is overhauled with competitive 6-Pokémon rosters, Gen 2/3 additions, held berries, and higher level targets:
  - **Lt. Surge (Vermilion):** Levels 52–55 (Ace Raichu holding Chesto Berry).
  - **Janine (Fuchsia):** Levels 52–56 (Ace Venomoth holding Persim Berry).
  - **Erika (Celadon):** Levels 53–57 (Ace Bellossom holding Rawst Berry).
  - **Misty (Cerulean):** Levels 57–61 (Ace Starmie holding Pecha Berry).
  - **Sabrina (Saffron):** Levels 58–62 (Ace Alakazam holding Cheri Berry).
  - **Brock (Pewter):** Levels 58–62 (Ace Steelix holding Berry).
  - **Blaine (Cinnabar / Seafoam):** Levels 59–63 (Ace Magmar holding Persim Berry).
  - **Blue (Viridian):** Levels 70–72 (Ace Arcanine holding Cheri Berry).
  - **Fighting Dojo (Saffron):** Levels 60–64 Blackbelts (Hariyama, Breloom, Medicham, Primeape, Hitmons).
  - **Nugget Bridge Circuit (Route 24/25):** Levels 56–60.
  - **Mt. Moon Rival Rematch:** Levels 75–78 (Ace Tyranitar holding Lum Berry).

---

## Gender

Every mon gets a gender from Gen 2 rules: Attack DV vs species `genderRate` (female eighths from PokéAPI). Always-male / always-female / genderless lines stay that way.

- Existing saves are **backfilled from DVs on load** (deterministic).
- Summary / nickname can show ♂ / ♀.
- Attract and Cute Charm use opposite-gender infatuation (Cute Charm at Gen 3’s 1/3 rate).
- Captivate only hits the opposite gender.
- Cute Charm lead biases wild genders (~2/3 opposite), Emerald-style.

---

## Day Care and breeding

Route 5 Day Care house (same building as vanilla) becomes Gen 3-style in Gen 1. (Gen 2 uses its native Route 34 Day Care).

![Route 5 Day Care](screen-shots/daycare.png)

### Basics

- Up to **two** parents (keep at least one mon in the party).
- Talk to Day-Care Man or Lady to deposit, check, pay the level-based fee, or take an Egg.
- Hatch by walking (level 5). Flame Body / Magma Armor in the party speeds hatching.

### Compatibility

- Same species, opposite gender → best odds.
- Shared egg group, opposite gender → lower.
- Ditto + breedable partner → works (two Ditto does not).
- Undiscovered / non-breedable → no Egg.

### Inheritance (Gen 1-shaped)

- Species from mother (or non-Ditto parent).
- DVs: Crystal-style mix (Defense / Special tend to come from one parent).
- Egg moves can come from the father when the baby can learn them.
- **No** Everstone, Natures, or IVs.

---

## Held items

### Catalog highlights

| Item | Notes |
|---|---|
| Berries (`BERRY`, Cheri…Lum) | Bag use + held; see berry section |
| Leftovers | Residual heal; **overworld find**, not mart |
| Focus Band | Chance to survive; **Poké Ball find** |
| Type boosters | ×1.1 for matching move type; marts + some finds |
| Choice Band | ×1.5 physical; locks move; battle club reward |
| Life Orb | ×1.3 damage + recoil; blacksmith |
| Focus Sash | Survive one lethal hit from full HP (per hit; multi-hit can still KO); snack scout / blacksmith |
| Heart Scale | Move Hub currency |
| Soothe Bell / Cleanse Tag | Trade preloads |
| Rainbow Wing / Silver Wing / Red Orb / Blue Orb / DNA Key / Roaming Radar | Key items for legendaries |

Party menu **GIVE** / **TAKE** (field only).

### Overworld loot (one-time)

**Hidden (Item Finder / face tile):**

| Where | Item |
|---|---|
| Soft path / grass north of Celadon Mansion | Leftovers |
| Grass near Pewter Gym / Mart strip | Hard Stone |
| Path beside Pokémon Tower entrance | Spell Tag |
| Central Saffron sidewalk south of Silph | Twistedspoon |

**Visible balls:**

| Where | Item |
|---|---|
| Rock Tunnel B1F (Poké Ball while exploring) | Focus Band |
| Pokémon Tower 7F | Blackglasses |
| Power Plant (Poké Ball while exploring) | Metal Coat |

---

## Berry Farm and berry economy

There are no separate "seeds." You plant a berry, it grows, you harvest more berries. Same item goes in the bag, on a mon, or in the dirt.

![Berry Farm plots growing](screen-shots/berry-farm.png)

### Access

- **Gen 1 Centers:** Extra carpet on the **right side** of any Pokémon Center.
- **Gen 2 Johto Centers:** Stairs tile in the **bottom-right corner** of any Johto Pokémon Center.
- **Gen 2 Kanto Centers:** Red door mat pair on the **south row** of any Kanto Pokémon Center.
- **Gen 2 Indigo Plateau:** SE stairs tile.
- Shed door on the farm returns you to that exact same Center.

### NPCs on the farm

| NPC | Role |
|---|---|
| Farm girl | How planting works |
| Fisher | Flavor; lake is surfable scenery (no wilds) |
| Soil Expert | Badge unlocks + soil ranks; gifts starter packs |
| Berry Scholar | Menu explaining what each berry does |
| Merchant | Shop: buy any **unlocked** berry |

### Obtaining berries

1. **First farm visit:** 3× `BERRY` gifted once.
2. **Badge unlocks:** unlock that plant type + **3×** of that berry once per type.
3. **Farm merchant:** buy unlocked berries anytime:
   - `BERRY` ¥300
   - Status berries ¥600
   - `LUM_BERRY` ¥2000
4. **Harvest:** yield **2** per ripe plot (net +1 if you replant one).
5. **Wild held:** ~5% among unlocked types; catch and TAKE.
6. **Blacksmith:** Leaf Stone → 5 berries (repeatable mix).
7. **Battle rematches:** Snack Scout gifts Cheri + Pecha + Rawst; Circuit rematches can drop a Heart Scale (30%).

### Badge → Plant Unlock Tables

**Gen 1 (Kanto Badges):**

| Badge | Unlocks |
|---|---|
| Boulder | Cheri |
| Cascade | Pecha |
| Thunder | Rawst |
| Rainbow | Aspear + Chesto |
| Soul | Persim |
| Marsh or Volcano | Lum |
| Earth | *(no new berry)* |

**Gen 2 (Johto Badges):**

| Badge | Unlocks |
|---|---|
| Zephyr | Cheri |
| Hive | Pecha |
| Plain | Rawst |
| Fog | Aspear + Chesto |
| Storm | Persim |
| Mineral or Glacier | Lum |
| Rising | *(no new berry)* |

### Growth

- **9** plots. Face a bed + A to plant (spends 1 berry).
- Growth uses the global `farmSteps` counter (any overworld tile step). Base **320** steps per plant.
- Soil ranks: 0→320, 1→280, 2→240, 3→192 steps.
- Rank gates:
  - Rank 1: ≥ **5** Pokédex owned
  - Rank 2: Grass-type in party at **Lv ≥ 20**
  - Rank 3: ≥ **3** berry types in the bag (starter BERRY + Cheri + Pecha is enough)

### Berry effects (Scholar)

| Berry | Effect |
|---|---|
| BERRY | Restore 10 HP (use or held) |
| Cheri | Cure paralysis |
| Chesto | Wake from sleep |
| Pecha | Cure poison |
| Rawst | Heal burn |
| Aspear | Thaw freeze |
| Persim | Cure confusion |
| Lum | Cure any status or confusion |

### Blender (Celadon Mansion 3F)

Gate: Rainbow Badge (Gen 1) / Fog Badge (Gen 2) **or** Soil Rank ≥ 1.

![Juice Club blender on Celadon Mansion 3F](screen-shots/juice-blender.png)

| Recipe | Cost | Output |
|---|---|---|
| HP UP | 10× Cheri | 1× HP UP |
| Protein | 10× Rawst | 1× Protein |
| Iron | 10× Pecha | 1× Iron |
| Carbos | 10× Aspear | 1× Carbos |
| Calcium | 10× Chesto | 1× Calcium |
| Lum craft | 1 each Cheri/Pecha/Rawst/Aspear/Chesto + 3× BERRY | 1× Lum |

Step cool-down between crafts: **640** farm steps (480 at soil rank 3).

---

## Bag and party QoL

- **Pockets (Gen 1):** Items, Balls, Key Items, TMs & HMs, Berries. Bag capacity **60**.
- **DexNav:** On the start menu (Red) / Pokegear Card (Gold, via `pokegear_cards` mod) after getting the Pokédex: shows current map species (more detail once seen/caught). Optional **ROAM** row when a roamer is present.
- **Summary Menu:**
  - **Gen 1:** Page 3 displays ability, held item, and gender glyph.
  - **Gen 2:** Page 4 displays ability, held item, gender glyph, and ability description text.
- **Optional [Gen1 Modern UI](https://github.com/ArmstrongThomas/gen1-modern-ui):** Supported on Red.

![DexNav (Cerulean City)](screen-shots/dexnav.png)
![Berries pocket](screen-shots/bag-berries.png)
![TMs & HMs pocket](screen-shots/bag-tms.png)

---

## Level caps

**Opt-in only.** Talk to the Rare Candy youngster outside the Viridian Poké Mart (Gen 1) or in Cherrygrove City (Gen 2). Taking **any** amount permanently enables soft caps:

- Tops your Rare Candies toward **99**.
- At the current cap, battle XP becomes +1-style soft stop and Rare Candy cannot push past it.

### Gen 1 Milestones (Kanto)

| Cap | Milestone |
|---|---|
| 14 | Pre-Brock |
| 16 | Pre-Mt. Moon (Brock / Boulder) |
| 18 | Pre-Nugget Bridge (got Dome or Helix fossil) |
| 21 | Pre-Misty (`EVENT_GOT_NUGGET`) |
| 24 | Pre-Surge (Misty / Cascade) |
| 29 | Pre-Erika / Hideout (Surge / Thunder) |
| 41 | Pre-Silph Giovanni (Erika **and** Hideout Giovanni) |
| 43 | Pre-Koga / Sabrina (Silph Giovanni) |
| 47 | Pre-Blaine (Koga/Soul **or** Sabrina/Marsh) |
| 50 | Pre-Giovanni (Blaine / Volcano) |
| 53 | Pre-Victory Road (Giovanni / Earth) |
| 65 | Pre-Champion (Route 22 rival 2nd / E4 started / Lance) |
| 100 | Post-game (Champion rival) |

### Gen 2 Milestones (Johto + Kanto)

| Cap | Milestone |
|---|---|
| 14 | Pre-Falkner |
| 16 | Pre-Bugsy (Zephyr Badge) |
| 20 | Pre-Whitney (Hive Badge) |
| 25 | Pre-Morty (Plain Badge) |
| 30 | Pre-Chuck (Fog Badge) |
| 32 | Pre-Pryce / Rocket Hideout (Storm Badge) |
| 35 | Pre-Jasmine (Glacier Badge / Cleared Hideout) |
| 38 | Pre-Radio Tower (Mineral Badge) |
| 40 | Pre-Clair (Cleared Radio Tower) |
| 44 | Pre-Victory Road Rival (Rising Badge) |
| 50 | Pre-Champion Lance (Beat Victory Road Rival) |
| 58 | Kanto Arrival (0–2 Kanto Badges) |
| 64 | 3–6 Kanto Badges |
| 72 | 7 Kanto Badges |
| 85 | 8 Kanto Badges / Beat Mt. Moon Rival |
| 100 | Post-Red (Mt. Silver) |

---

## XP Share (slot 2)

When the option is on, the Gen 1 XP pool is split so active fighters get ~70% of it and party **slot 2** can receive up to ~30% without inflating past roughly a solo-kill total. Replaces EXP.ALL while enabled.

---

## Smarter AI

Four rungs: **natural** (common wilds), **soft** (route trash + threat wilds), **lite** (gyms / serious classes), **elite** (leaders / E4 / rivals). Soft/lite react to HP, speed, and existing status with small nudges. Soft KO reads stay conservative so trash fights do not dump status for a guessed KO. Threat wilds use soft via scary maps, roamers, or iconic species. Decaying weights cool status/setup after use; near-best mixing avoids locking one attack. Trainer bag items share a battle budget.

---

## House NPCs and utility

All short classic-style dialogues. The judge reads DVs / Hidden Power / statExp.

### Celadon Circuit (Celadon Mansion 2F)

Rematchable battle club. 4 rotating teams by streak. First win → **Choice Band**. Rematches → money (`ace × 40`) and a flat **30%** chance at a Heart Scale. Same floor: **Beast Tracker** (roamers / Radar after Silph).

### Night Eyes (Vermilion Pidgey House)

Requires a **Dark**-type in the party. First clear → Blackglasses (or ¥5000 if you already have them) + hint toward the Circuit. Rematches → ¥2000.

### Snack Scout (Celadon Hotel)

Lead must **hold a berry**. First clear → **Focus Sash**. Rematches → 1× Cheri + Pecha + Rawst.

### Judge (Underground Path)

- **Gen 1:** Underground Path (Route 5 side).
- **Gen 2:** Underground Path (Route 5/6 tunnel).
- Reads DV words, Hidden Power type, and highest statExp.

### Extra trades (Gen 1)

| Location | Give → Get | Held on received |
|---|---|---|
| Route 2 Trade House | Rattata → Taillow (“SWIFT”) | Cleanse Tag |
| Fuchsia Bill’s Grandpa’s House | Bellsprout → Seedot (“GLAND”) | Soothe Bell |

---

## Move Hub

- **Gen 1:** Saffron Pidgey House.
- **Gen 2:** Saffron City (Mr. Psychic's House).

| Service | Cost | Notes |
|---|---|---|
| Relearn | 1 Heart Scale | Level-up learnset ∪ egg moves; sets PP to max |
| Tutor | 2 Heart Scales | Curated list (punches, Body Slam, Rock Slide, Softboiled, Double-Edge, Substitute, …) |
| Delete | Free | Cannot delete the last move; packs slots left |

---

## Blacksmith

- **Gen 1:** Cinnabar Lab Metronome Room.
- **Gen 2:** Cinnabar Pokémon Center 1F.

| Exchange | Notes |
|---|---|
| Metal Coat → Life Orb | One-shot |
| 3× Nugget → Focus Sash | One-shot; if you already have a sash → 2× Heart Scale instead |
| Leaf Stone → berry pack | Repeatable: BERRY, Cheri, Pecha, Rawst, Aspear (1 each) |

---

## Gen 3 fossils (Gen 1)

| Fossil | Where | Revives to |
|---|---|---|
| Root Fossil | Mt Moon B2F hidden | Lileep Lv 30 |
| Claw Fossil | Seafoam 1F hidden | Anorith Lv 30 |

Extra scientist in **Cinnabar Lab Fossil Room** handles Gen 3 revive. Hand the fossil in, **leave Cinnabar Island**, then return to pick up the mon.

---

## Roaming legendaries (Gen 1)

### Beasts (Raikou / Entei / Suicune)
- After Silph progress, talk to **Beast Tracker** (Celadon Mansion 2F) for **Roaming Radar**.

### Eon duo (Latias / Latios)
- After Champion, talk to watcher in **Indigo Plateau Lobby**.

---

## Static legendaries and mythicals (Gen 1)

One-shot statics. **Win, catch, or flee** all count as completed, so fleeing despawns them permanently.

| Species | Location | Gate / key | Level |
|---|---|---|---|
| Ho-Oh | Celadon Mansion roof | Rainbow Wing (Route 16 Fly House: 60 owned) | 50 (sun) |
| Lugia | Seafoam B1F | Silver Wing (Route 12 Gate upstairs: Water ≥Lv30) | 50 (rain) |
| Kyogre | Seafoam B3F | Blue Orb (Cinnabar Lab scientist, post-Champion) | 60 (rain) |
| Groudon | Pokémon Mansion B1F | Red Orb (same scientist, second talk) | 60 (sun) |
| Regirock | Rock Tunnel B1F hidden ladder → `REGIROCK_CHAMBER` | Pewter scholar notes + **3 Rock-types** in party | 50 |
| Regice | Seafoam B2F | Notes + **1 Ice-type** | 50 |
| Registeel | Power Plant | Notes + **1 Steel-type** | 50 |
| Rayquaza | Sky Pillar (custom) | Beat Kyogre **and** Groudon; hiker gate on Route 23 | 70 |
| Celebi | Ilex Shrine (custom) | Champion; channeler gate in Viridian Forest | 30 |
| Deoxys | Birth Island (custom) | Champion + DNA Key (Vermilion Dock sailor; requires **3 caught legendaries** from: Raikou, Entei, Suicune, Lugia, Ho-Oh, Kyogre, Groudon, Articuno, Zapdos, Moltres, Mewtwo) | 70 |
| Jirachi | Mt Moon B1F | Champion + spend **5 Heart Scales** to start | 30 |

---

## Custom maps

| Map | Index | Purpose |
|---|---|---|
| `BERRY_FARM` | 1100 | Berry plots + NPCs |
| `SKY_PILLAR_KANT` | 1101 | Rayquaza |
| `ILEX_SHRINE_KANT` | 1102 | Celebi |
| `BIRTH_ISLAND_KANT` | 1103 | Deoxys |
| `REGIROCK_CHAMBER` | 1104 | Regirock (ladder from Rock Tunnel B1F) |

---

## Caveats and save notes

- Friendship / time / location evolutions are fudged for Gen 1.
- Move anims and menu icons are reused classic art on purpose.
- DexNav Super Rod note: Super Rod respects the DEX SCOPE habitat filter. Old Rod and Good Rod draw from global pools regardless of scope, so they can surface out-of-scope species.
- FULL SPAWN MIX rewrites tables. Set it before a long save.
- Level caps stay off until you accept Rare Candies.
- Static legendaries despawn on flee as well as catch/KO.
- Link play needs matching mods on both sides.
- Gen 1 `.sav` export/import will drop post-151 mons and Eggs.

---

## Module map (for modders)

The codebase is organized into domain-specific subdirectories:

| Subdirectory / File | Responsibility |
|---|---|
| `core/host.lua` / `core/gen2_compat.lua` / `core/options.lua` | Host generation shims, Gen 2 infrastructure seeding, mod options |
| `pokemon/pokemon_data.lua` / `pokemon/pokemon_gen2.lua` | Species definitions, Hoenn Gen 2 record converters, base stats |
| `pokemon/learnset_patches.lua` / `pokemon/gender.lua` / `pokemon/breeding.lua` | Learnsets, Gen 2 DV gender calculations, Day Care breeding logic |
| `pokemon/species_scope.lua` / `pokemon/species_palettes.lua` | Dex scope filters (Kanto / Johto 251 / National), Gen 2 palette hooks |
| `battle/trainer_ai.lua` / `battle/trainers.lua` | Smarter AI system, Gen 1 & Gen 2 Gym / Trainer mix overhauls |
| `battle/abilities.lua` / `battle/move_effects.lua` / `battle/move_type_patches.lua` | Gen 3 ability runners, custom move effects, type alignment |
| `world/encounters.lua` / `world/encounters_gen2.lua` | Wild encounter tables for Gen 1 Kanto, Gen 2 Johto, and Gen 2 Kanto postgame |
| `world/berry_farm.lua` / `world/berry_quests.lua` | Berry Farm map, Pokecenter warps, Soil Expert badge unlocks, Blender |
| `world/house_npcs.lua` / `world/move_hub.lua` / `world/item_smith.lua` | House NPCs, Move Relearner/Tutor hub, Cinnabar Blacksmith |
| `world/roamers.lua` / `world/roaming_radar.lua` | Roaming beasts / Eon duo mechanics, radar item |
| `world/legend_shrines.lua` / `world/legend_regis.lua` / `world/legend_mythicals.lua` | Custom static encounters (Ho-Oh, Lugia, Regis, Rayquaza, Deoxys, etc.) |
| `items/held_items.lua` / `items/competitive_items.lua` / `items/bag_pockets.lua` | Held item effects, battle items (Choice Band/Life Orb/Focus Sash), bag pockets |
| `ui/summary_ui.lua` / `ui/dexnav.lua` / `ui/level_caps.lua` / `ui/xp_bar.lua` | Extra summary page (Page 3/4), DexNav start menu / Pokegear, level caps, XP bar |
| `tools/generate_pokemon_mod.py` | Data generator pipeline from PokeAPI |
| `sevii/` (parked) | Sevii ferry/maps/tooling — disabled until `SEVII_ENABLED` |

Tests live under `tests/` and are pulled in by `tests/Kanto-Reforged_test.lua`.

