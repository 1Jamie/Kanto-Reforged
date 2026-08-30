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
7. [Gen 2 Kanto Rocket campaign](#gen-2-kanto-rocket-campaign)
8. [Restored Gen 2 Kanto dungeons](#restored-gen-2-kanto-dungeons)
9. [Gender](#gender)
10. [Day Care and breeding](#day-care-and-breeding)
11. [Held items](#held-items)
12. [Berry Farm and berry economy](#berry-farm-and-berry-economy)
13. [Bag and party QoL](#bag-and-party-qol)
14. [Level caps](#level-caps)
15. [XP Share (slot 2)](#xp-share-slot-2)
16. [Smarter AI](#smarter-ai)
17. [House NPCs and utility](#house-npcs-and-utility)
18. [Move Hub](#move-hub)
19. [Blacksmith](#blacksmith)
20. [Gen 3 fossils](#gen-3-fossils)
21. [Roaming legendaries](#roaming-legendaries)
22. [Static legendaries and mythicals](#static-legendaries-and-mythicals)
23. [Custom maps](#custom-maps)
24. [Caveats and save notes](#caveats-and-save-notes)
25. [Module map (for modders)](#module-map-for-modders)

---

## Design philosophy

Same idea as the README: if Game Freak had bolted gen2-3 pieces onto Red/Blue and Gold, how would that feel? Stories stay authentic to the originals. Stats stay DVs and `statExp` (no natures/IVs). New overworld art reuses classic sheets where it makes sense (legendaries use `SPRITE_BIRD` / `SPRITE_MONSTER` / `SPRITE_FAIRY` on purpose). Move anims and party icons borrow classic stock. House NPCs are short TextBox / ChoiceBox chats, not bloated quest logs.

---

## Options

Configured in the mod manager / F10 options:

| Option | Default | Effect |
|---|---|---|
| **DEX SCOPE** (Gen1) / **JOHTO SCOPE** (Gen2) | NATIONAL / FULL | Restricts wilds, trainers, and legends. Gen1 **KANTO** locks to the original 151 (out-of-scope party/PC mons are safely stored and restored when switched back). Gen2 **JOHTO 251** caps Johto spawns at dex 251 while Kanto postgame maps (including restored dungeons) keep Gen3 guests. |
| **FULL SPAWN MIX** | Off | Rebuilds wild tables from the full Gen 1–3 pool instead of curated mixes (habitat / level gated, deterministic). On **Gen 2** (Gold/Silver/Crystal), reshuffles Johto and Kanto grass/water (with a density pass so Kanto stays full). Mid-session toggles apply live. |
| **PURE RANDOM SPAWN** | Off | Chaos mode: seeded pick from the whole allowed dex (respects DEX/JOHTO SCOPE). No habitat, stage, or BST gates. Overrides FULL SPAWN MIX when both are on. Rolls once when toggled on and persists across loads; toggle off/on for a new mix. |
| **LEGENDS IN MIX** | Off | When FULL SPAWN MIX or PURE RANDOM SPAWN is on, allow legendaries/mythicals into the wild pool. Curated mode ignores this (including a leftover on after turning FULL/PURE off). |
| **XP SHARE (SLOT 2)** | On | Splits the Gen 1 XP pool: ~70% to fighters, up to ~30% to party slot 2 (never more than a solo share total). Replaces EXP.ALL while enabled. |
| **SMARTER AI** | On | Trainers (and wild scoring hooks) prefer useful damage and skip moves that would fail. |
| **SWITCH HIT AI** | Classic | Free-hit timing when you switch: **CLASSIC** picks after send-out; **GEN 3** locks against the outgoing mon. Same labels on Red and Gold. |
| **BAG GIVE** | On | Allow Give held item from the bag as well as from the party menu. |
| **RULESET** | MODERN (forced) | **Red only.** KR always forces engine `modern_clean` (no 1/256 miss, Focus Energy helps crits, enemies spend PP, Hyper Beam always recharges, end-of-turn residuals) plus Gen3 crit / partial-trap capabilities. The old GEN 1 / `gen1_faithful` toggle is removed; leftover faithful saves migrate to `modern_clean`. Hidden on Gold (native Gen2 rules + same KR Gen3 overlays where applicable). |
| **SP.ATK / SP.DEF** | On | **Red only.** Special moves use separate Sp.Atk / Sp.Def bases (PokeAPI) instead of Gen 1 Special. Summary and Modern UI party/PC detail show both stats (`SAT` / `SDF`). Stages, DVs, and Calcium stay Gen 1 (one shared Special). Hidden on Gold (already split). |
| **EXP BAR** | On | **Red only.** Blue EXP bar under the HP bar in battle (Gen 2 style, widescreen-aware). Hidden on Gold (native bar). |
| **DEXNAV** | DEXNAV | **Red only.** Start-menu label / off. Gold DexNav is a Pokegear card (no rename toggle). |
| **SPRITES 1-251** | CUSTOM KR | **Red only**, and only after at least one Gen 2 cache exists. Boot KR on **Gold / Silver / Crystal** to copy that edition’s static battle pics (dex 1–251) into `save/mod-derived/.../sprites/<edition>/` while that ROM is mounted. Return to Red and choose **CUSTOM KR**, **GOLD**, **SILVER**, and/or **CRYSTAL** (only captured editions appear). Hoenn (252+) always stays KR. Crystal anim sheets are never cached. Mid-session swaps apply live; re-boot each Gen2 column once after a KR update if the set looks incomplete. |

---

## Species, types, and moves

### Species

- Dex **152–386** (Johto + Hoenn) with sprites, learnsets, and Gen 3 abilities.
- Original 151 receive Gen 3 abilities and Emerald-first level-up learnsets / TM/HM from `learnset_gen3.lua` (runtime apply on Red and Gold). Pragmatic L30 TM backports for AI when not naturally level-up.
- On **Gold/Silver/Crystal**, Gen2 **HM06 Whirlpool** compatibility is restored after Gen3 TM/HM apply (Gen3 dropped it as an HM): stock Johto/Kanto learners keep it; Hoenn Water-types that can Surf also gain it.
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

Hundreds of Gen 2–3 moves with custom effects (Rollout, weather, hazards, status berries as bag/held medicine, Hidden Power from DVs, etc.). New moves reuse Gen 1 battle animations (composed or aliased). Doubles-only moves (Helping Hand, Follow Me, etc.) are stripped from learnsets.

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

- **RULESET (Red):** Always **MODERN** (`modern_clean`) with Gen3 crit stages and Gen3 partial trapping. Faithful Gen1 quirks are not offered; old faithful saves are migrated.
- **Physical / special:** Damaging moves use Gen3 type categories (not Gen4 per-move split). Dark/Ghost are special; Fire/Water/Grass/etc. special; Normal/Fighting/etc. physical.
- **Pursuit:** Hits the Pokémon switching out for double power (both hosts), then spends the free-hit turn.
- **Sucker Punch / Me First:** Read the foe’s selected move for the turn (pending-move stash).
- **Variable power:** Natural Gift, Punishment, Gyro Ball, Electro Ball, Grass Knot / Low Kick, Heavy Slam family, Stored Power / Power Trip, Wring Out, Trump Card, Fling, Beat Up, Acrobatics.
- **Doubles-only moves** (Helping Hand, Follow Me, Rage Powder, Ally Switch, Wide/Quick Guard, After You, Quash, Spotlight): stripped from learnsets; leftovers fail.
- **Gen 3 Freeze Parity:** Frozen Pokémon have a 20% (1-in-5) chance to thaw naturally each turn. Furthermore, any damaging fire-type move used against a frozen target immediately unfreezes them.
- **XP Bar:** A smooth blue EXP bar displays below the player Pokémon's HP bar in battle across Gen 1 (matching Gen 2 style) with widescreen support.

---

## Wild encounters and trainers

### Wild Encounters

- **Gen 1 (Red / Blue / Yellow):** Curated mixes: habitats and levels mix Gen 2–3 species into Kanto routes without replacing the whole table. A coverage pass ensures every non-legendary **line** is obtainable. Host version exclusives (e.g. Red gets Sandshrew/Vulpix/…, Blue gets Ekans/Oddish/…) are cross-injected into classic wild slots.
- **Gen 2 (Gold/Silver/Crystal) Johto:** Native Johto tables are preserved with curated Gen 3 guests in rare slots across grasslands, forests, caves, and mountains. Missing Gold/Silver/Crystal wild exclusives are cross-injected (story mascots still follow the cart).
- **Gen 2 (Gold/Silver/Crystal) Kanto outdoors:** Fully rebuilt postgame grass tables featuring Gen 3 lines scaled from **Lv 28 to Lv 40+**.
- **Gen 2 (Gold/Silver/Crystal) restored dungeons:** Separate postgame tables for Viridian Forest / Mt. Moon / Diglett's Cave / Rock Tunnel / Safari / Seafoam / Cerulean Cave (see [Restored Gen 2 Kanto dungeons](#restored-gen-2-kanto-dungeons)); cave bands run roughly mid-40s into the 60s.
- **Full Spawn Mix (Option):** Reshuffles all wild grass/water tables across the entire game from the Gen 1–3 pool.
- Wilds have a ~**5%** chance to hold a berry (rolled only from types you have already unlocked at the farm). Catching the mon keeps `heldItem`; use party **TAKE** to move it to the bag.

![Wild Azurill encounter in a Gen 1 battle UI](screen-shots/wild-azurill.png)

### Trainers

- **Gen 1 (Red / Blue):** Gym leaders and Elite Four get a curated **Gen 2 swap + Gen 3 add**. Ace mons hold a **berry ramp** (plain `BERRY` on Brock → status berries mid-game → Lum on Agatha/Lance). Rival mixes follow **continuity** (mid fights foreshadow a line; League fights debut finals). Tier 2 set pieces (Nugget Bridge, gym trainers, Mt. Moon, **Rocket Hideout / Game Corner basement**, Fighting Dojo, Tower, **Silph Co**, **Pokémon Mansion**, **Victory Road**) get heavier mixes. Giovanni continuity: Hideout Steelix + Trapinch → Silph Donphan + Vibrava → gym Donphan + Flygon.
- **Gen 2 (Gold/Silver/Crystal) Kanto Overhaul:** The entire Kanto postgame circuit is overhauled with competitive 6-Pokémon rosters, Gen 2/3 additions, held berries, and higher level targets aligned to the soft caps (58 → 64 → 72 → 85 → 100):
  - **Lt. Surge (Vermilion):** Levels 52–55 (Ace Raichu holding Chesto Berry).
  - **Janine (Fuchsia):** Levels 52–56 (Ace Venomoth holding Persim Berry).
  - **Erika (Celadon):** Levels 53–57 (Ace Bellossom holding Rawst Berry).
  - **Misty (Cerulean):** Levels 57–61 (Ace Starmie holding Pecha Berry).
  - **Sabrina (Saffron):** Levels 58–62 (Ace Alakazam holding Cheri Berry).
  - **Brock (Pewter):** Levels 58–62 (Ace Steelix holding Berry).
  - **Blaine (Seafoam Gym):** Levels 59–63 (Ace Magmar holding Persim Berry); fought in the restored Seafoam gym room.
  - **Blue (Viridian):** Levels 70–72 (Ace Arcanine holding Cheri Berry).
  - **Fighting Dojo (Saffron):** Levels 60–64 Blackbelts (Hariyama, Breloom, Medicham, Primeape, Hitmons).
  - **Nugget Bridge Circuit (Route 24/25):** Levels 56–60.
  - **Mt. Moon Silver Rematch:** Levels 75–78 (Ace Tyranitar holding Lum Berry), tucked on **Mt. Moon B2F** after Safari clear + 8 Kanto badges.

---

## Gen 2 Kanto Rocket campaign

On Gold/Silver/Crystal, Kanto postgame has a Johto-shaped story spine (layouts stay generated; story is runtime overlays in `world/kanto_campaign.lua`):

1. **Blue (Route 22 + Pokégear)** — Former Champ drafts you; phone calls after gym/chapter milestones.
2. **Mt. Moon** — Rocket **toll racket / training camp** (not Gen1 fossil theft). Clear the checkpoint admin.
3. **Rock Tunnel** — Rocket **supply line** toward Fuchsia + Blue at the south exit.
4. **Safari Zone** — Door in Fuchsia stays **closed** until Moon **and** Tunnel are cleared; then a full Rocket occupation dungeon (Secret House = industry boss). No Game Corner hideout revival.
5. **Silver (Mt. Moon B2F)** — Personal climax after Safari + 8 badges (cap 85).
6. **Red (Mt. Silver)** — Summit (cap 100).

Campaign dialogue is formatted for Gen2's 18×2 overworld box (`Dialogue.overworld` / `\f` page breaks) so text pages with A instead of soft-scrolling past the player.

Fossils in Mt. Moon remain optional loot. Layout regenerations do not wipe campaign overlays.

---

## Restored Gen 2 Kanto dungeons

On **Gold/Silver/Crystal**, Gen 1 Kanto dungeon layouts (blocks, warps, NPCs, items, signs) are injected as `*_KR` maps and overworld mouths are redirected into them. Trainers and wilds are scaled for the postgame curve. **Campaign NPCs/dialogue** live in hand-authored overlays, not the generated data file.

| Area | Notes |
|---|---|
| **Viridian Forest** | Full Gen 1 maze + bug catchers; wilds ~Lv 43–49. |
| **Mt. Moon** | 1F / B1F / B2F; optional fossils; Rocket racket chapter; **Silver** on B2F (gated). Wilds ~Lv 46–50. |
| **Diglett's Cave** | Full tunnel + Route 2 / Route 11 mouths. |
| **Rock Tunnel** | 1F / B1F + linked Poké Center; Rocket supply-line overlay + Blue reveal. |
| **Safari Zone** | Gated from Fuchsia until Moon+Tunnel clear; Rocket occupation; Secret House boss. |
| **Seafoam Islands** | 1F–B4F boulder puzzles; **Blaine's gym** as a dedicated room off 1F; **Articuno** on B4F (Lv 60). |
| **Cerulean Cave** | 1F / 2F / B1F; **Mewtwo** on B1F (Lv 70); wilds ~Lv 59–65 on B1F. |

Related Route 2 gate / trade house pieces ship with the Viridian Forest restore so the classic Forest path works again.

---

## Gender

Every mon gets a gender from Gen 2 rules: Attack DV vs species `genderRate` (female eighths from PokéAPI). Always-male / always-female / genderless lines stay that way.

- Existing saves are **backfilled from DVs on load** (deterministic).
- **♂ / ♀** show in battle HUD names, party menu rows, catch nickname prompt, naming keyboard, PC withdraw/deposit lists, and the summary screen.
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

- **Pockets (Gen 1):** Prefer the optional companion mod `gen1_bag_pockets` (Items, Balls, Key Items, TMs & HMs, capacity **60**). When that mod is installed, KR adds the **Berries** pocket and optional **BAG GIVE**. If `gen1_bag_pockets` is absent, KR still provides the full five-pocket bag + capacity as a fallback.
- **SELECT reorder:** Works inside Items / Balls / Key Items / Berries. TMs & HMs stay sorted (reorder disabled).
- **DexNav:** On the start menu (Red) / Pokegear Card (Gold/Silver/Crystal, via `pokegear_cards` mod) after getting the Pokédex: shows current map species (more detail once seen/caught). Optional **ROAM** row when a roamer is present.
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

### Celadon living district (Gen 1 ambient)

A **district orchestrator** drives Celadon’s commercial strip: NPCs are classified from map data + dialog text ids (lexicon tags), then scheduled into trip/wander slots (roughly a handful concurrent, with multi-start decision beats) with venue activity packs (Dept. Store floors 2–5 + roof, Game Corner, diner, street, plus kitbashed hollow interiors). Safe **WALK** natives are adopted as ambient twins (vanilla body hidden while out); protected/rockets, the diner cook, and KR utility NPCs stay frozen. Active movers walk **arrival-gated** itineraries (live position advances each door/walk segment — the clock never teleports them home mid-aisle). **Doors** use the same approach tiles players do, then handoff-despawn (hide/remove body) and land on the far approach — never idle-camping the mat after. Game Corner gamblers path onto **machine seats** (one exclusive seat each; frozen staff seats reserved). Off-screen segments simulate by duration; on-screen bodies only `stepNow` / spawn-on-enter — no `placeAt` catch-up. **Stay** ends park the twin on the venue map (home stays hidden); only **home** ends reveal the seat and drop the twin. A short boot grace avoids door rushes on load. House/island seats always return home; scatter ambient may relocate and stay. Talk pauses that NPC’s job clock. Aisle columns stay path-forbidden except as a seat goal; maps mark door/clerk/exit **no-idle** tiles so campers get stepped aside. A slow **failsafe** beat recovers stalls and compound door camps without warping. Rare **occasions** pair idle wanderers (café coffee / dates, street spars): spars path to exact fighter marks, spawn OW mon props only once both trainers arrive, despawn those props when the fight dwell ends, then home-end back into normal ambiance.

**Hollow façades (Gen 1 only):** decorative solid bottoms get real doors and kitbashed interiors. The **tall building immediately west of Celadon Mansion** becomes multi-floor apartments (mansion 1F–3F + roof + penthouse kitbash, stairs linked inside the building). The smaller east-row façades are little houses (chief-house kitbash). Café west of the diner, shop on the hotel strip, and a boutique near the prize room round out the row. Hollow NPCs are in the district orch with **personality profiles** (home vs away/work lines, less copy-paste chatter) and a light **friend graph** (named pairs, visit-friend trips, gossip lines). Café / strip shop / boutique **clerks sell** (CELADON BLEND / HOUSE LATTE, corner kit, SCENTED BALM). The café also sells a refillable **THERMOS** (3 sips; cheap top-up when empty — a reason to come back). Chalkboards and hours notes rotate with playtime. Each public hollow keeps one fixture **regular**. Residents linger and run errands in roughly equal measure; street wanderers prefer **cafe / shop** trips, with rarer apartment or friend-house visits. Rooftop view-seekers favor the Dept. Store and mansion roofs. Gold leaves those façades solid.

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
| `pokemon/learnset_gen3.lua` / `tools/gen3_learnsets.py` / `pokemon/gender.lua` / `pokemon/breeding.lua` | Gen3 learnsets (#1–386), gender, Day Care breeding |
| `pokemon/species_scope.lua` / `pokemon/species_palettes.lua` | Dex scope filters (Kanto / Johto 251 / National), Gen 2 palette hooks |
| `battle/trainer_ai.lua` / `battle/trainers.lua` | Smarter AI system, Gen 1 & Gen 2 Gym / Trainer mix overhauls |
| `battle/abilities.lua` / `battle/move_effects.lua` / `battle/move_type_patches.lua` | Gen 3 ability runners, custom move effects, type alignment |
| `world/encounters.lua` / `world/encounters_gen2.lua` | Wild encounter tables for Gen 1 Kanto, Gen 2 Johto, and Gen 2 Kanto postgame |
| `world/restored_dungeons.lua` / `world/restored_dungeons_data.lua` | Restored Gen 1 Kanto dungeon layouts for Gold (generated data + runtime glue) |
| `world/kanto_campaign.lua` / `world/kanto_campaign_content.lua` | Gen2 Kanto Rocket campaign overlays (Blue phone, Moon/Tunnel/Safari, Silver gate) |
| `world/berry_farm.lua` / `world/berry_quests.lua` | Berry Farm map, Pokecenter warps, Soil Expert badge unlocks, Blender |
| `world/house_npcs.lua` / `world/move_hub.lua` / `world/item_smith.lua` | House NPCs, Move Relearner/Tutor hub, Cinnabar Blacksmith |
| `world/ambient/` | Gen1 Celadon living-district orch (venues, classify, timeline pathing) |
| `world/roamers.lua` / `world/roaming_radar.lua` | Roaming beasts / Eon duo mechanics, radar item |
| `world/legend_shrines.lua` / `world/legend_regis.lua` / `world/legend_mythicals.lua` | Custom static encounters (Ho-Oh, Lugia, Regis, Rayquaza, Deoxys, etc.) |
| `items/held_items.lua` / `items/competitive_items.lua` / `items/bag_pockets.lua` | Held item effects, battle items (Choice Band/Life Orb/Focus Sash), Gen1 bag pockets fallback (companion: `gen1_bag_pockets`) |
| `ui/summary_ui.lua` / `ui/dexnav.lua` / `ui/level_caps.lua` / `ui/xp_bar.lua` | Extra summary page (Page 3/4), DexNav start menu / Pokegear, level caps, XP bar |
| `tools/generate_pokemon_mod.py` | Data generator pipeline from PokeAPI |
| `sevii/` (parked) | Sevii ferry/maps/tooling — disabled until `SEVII_ENABLED` |

Tests live under `tests/` and are pulled in by `tests/Kanto-Reforged_test.lua`.

