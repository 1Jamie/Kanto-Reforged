# Kanto Reforged — Full Feature Guide

Numbers, locations, unlock gates, recipes. The short overview and install steps are in [README.md](README.md). The play-through style guide is [WALKTHROUGH.md](WALKTHROUGH.md).

Mod id: `Kanto-Reforged`. Enable it in the launcher Mods tab or the F10 manager. This mod sets `affects_link`, so both sides need matching mods for link play.

---

## Table of contents

1. [Design philosophy](#design-philosophy)
2. [Options](#options)
3. [Species, types, and moves](#species-types-and-moves)
4. [Abilities](#abilities)
5. [Wild encounters and trainers](#wild-encounters-and-trainers)
6. [Gender](#gender)
7. [Day Care and breeding](#day-care-and-breeding)
8. [Held items](#held-items)
9. [Berry Farm and berry economy](#berry-farm-and-berry-economy)
10. [Bag and party QoL](#bag-and-party-qol)
11. [Level caps](#level-caps)
12. [XP Share (slot 2)](#xp-share-slot-2)
13. [Smarter AI](#smarter-ai)
14. [House NPCs and utility](#house-npcs-and-utility)
15. [Move Hub](#move-hub)
16. [Blacksmith](#blacksmith)
17. [Gen 3 fossils](#gen-3-fossils)
18. [Roaming legendaries](#roaming-legendaries)
19. [Static legendaries and mythicals](#static-legendaries-and-mythicals)
20. [Custom maps](#custom-maps)
21. [Caveats and save notes](#caveats-and-save-notes)
22. [Module map (for modders)](#module-map-for-modders)

---

## Design philosophy

Same idea as the README: if Game Freak had bolted gen2-3 pieces onto Red/Blue, how would that feel? Story stays Kanto. Stats stay DVs and `statExp` (no natures/IVs). New overworld art reuses gen1 sheets where it makes sense (legendaries use `SPRITE_BIRD` / `SPRITE_MONSTER` / `SPRITE_FAIRY` on purpose). Move anims and party icons borrow gen1 stock. House NPCs are short TextBox / ChoiceBox chats, not quest logs.

---

## Options

Configured in the mod manager / F10 options:

| Option | Default | Effect |
|---|---|---|
| **FULL SPAWN MIX** | Off | Rebuilds wild tables from the full Gen 1–3 pool instead of curated mixes. Flip **before** a long session; it rewrites encounter data. |
| **XP SHARE (SLOT 2)** | On | Splits the Gen 1 XP pool: ~70% to fighters, up to ~30% to party slot 2 (never more than a solo share total). Replaces EXP.ALL while enabled. |
| **SMARTER AI** | On | Trainers (and wild scoring hooks) prefer useful damage and skip moves that would fail. |
| **SP.ATK / SP.DEF** | Off | Special moves use separate Sp.Atk / Sp.Def bases (PokeAPI) instead of Gen 1 Special. Summary and Modern UI party/PC detail show both stats (`SAT` / `SDF`). Stages, DVs, and Calcium stay Gen 1 (one shared Special). |

---

## Species, types, and moves

### Species

- Dex **152–386** (Johto + Hoenn) with sprites, learnsets, and Gen 3 abilities.
- Original 151 also receive Gen 3 ability assignments and selected Gen 2/3 learnset / TM backports.
- Pokédex size extended to **386**.
- Special evolution methods for branching lines (e.g. Tyrogue ATK/DEF/BAL, Wurmple A/B).
- Friendship / time / location evolutions are approximated to fit Gen 1 triggers.

![Party menu with Gen 3 species and Gen 1 icon classes](screen-shots/party-menu.png)

### Types

Custom types registered with matchups:

- **Dark**
- **Steel**
- **Fairy**

### Moves

Hundreds of Gen 2–3 moves with custom effects (Rollout, weather, hazards, status berries as bag/held medicine, Hidden Power from DVs, etc.). New moves reuse Gen 1 battle animations (composed or aliased).

Shedinja’s max HP is clamped to **1** at runtime.

---

## Abilities

Gen 3 abilities on new and Kanto species. Battle hooks cover common cases (e.g. Wonder Guard, type immunities, status prevention). Some abilities / move stubs are still unfinished; see `mod.card` known notes.

Cute Charm / Attract / Captivate interact with the gender system (below).

![Summary page showing ability name + text (and gender glyph)](screen-shots/summary-ability.png)

---

## Wild encounters and trainers

### Wilds

Default mode is **curated**: habitats and levels mix Gen 2–3 species into Kanto routes without replacing the whole table. A coverage pass then ensures every non-legendary **line** is obtainable (catch the base — or a gift/rod root — then evolve / breed); mid and final forms do not all need their own grass slots. Optional **FULL SPAWN MIX** randomizes from Gen 1–3.

Wilds can hold berries (~**5%** chance). The berry is rolled only from types you have already **unlocked** for the farm. Catching the mon keeps `heldItem`; use party **TAKE** to move it to the bag.

![Wild Azurill encounter in a Gen 1 battle UI](screen-shots/wild-azurill.png)

### Trainers

Curated one-slot (or small) Gen 2–3 mixes into gyms, Elite Four, rival, and selected classes. Not full gym redesigns. See `trainers.lua` / `trainer_ai.lua`.

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

Route 5 Day Care house (same building as vanilla) becomes Gen 3-style with this mod. Outdoors Route 5 is unchanged.

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

### Line quirks

- Nidoran♀ / Illumise eggs: 50/50 species flip.
- Incense-only babies are not fully supported yet → breed Marill / Wobbuffet instead of Azurill / Wynaut, etc.
- Gen 4 babies clamp to the Gen 1–3 form this pack ships.

### Saves

Prefer Lua save slots. Exporting to a Gen 1 `.sav` and importing back **drops** Johto/Hoenn mons and Eggs.

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

**NPCs:** gramps near Celadon Mansion (Item Finder hint for Leftovers); channeler in Lavender (Spell Tag / berries flavor); Black Belt outside Fighting Dojo (one-time Black Belt gift).

City marts sell type boosters (Viridian/Pewter starters shelf; Celadon 5F). They do **not** sell status berries or Leftovers / Focus Band.

---

## Berry Farm and berry economy

There are no separate "seeds." You plant a berry, it grows, you harvest more berries. Same item goes in the bag, on a mon, or in the dirt.

![Berry Farm plots growing](screen-shots/berry-farm.png)

### Access

Every Pokémon Center has an extra carpet on the **right side** of the floor. Step on it to warp in; the shed door returns you to that same Center. Map id `BERRY_FARM` (index **1100**). Lake is surfable scenery with **no** wilds / fishing.

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
2. **Badge unlocks** (talk to Soil Expert or merchant with `gift`): unlock that plant type + **3×** of that berry once per type.
3. **Farm merchant:** buy unlocked berries anytime:
   - `BERRY` ¥300
   - Status berries ¥600
   - `LUM_BERRY` ¥2000
4. **Harvest:** yield **2** per ripe plot (net +1 if you replant one).
5. **Wild held:** ~5% among unlocked types; catch and TAKE.
6. **Blacksmith:** Leaf Stone → 5 berries (repeatable mix).
7. **Battle rematches:** Snack Scout gifts Cheri + Pecha + Rawst; Circuit rematches can drop a Heart Scale (30%).

Growing on plots is cheaper than buying when you need bulk (blender vitamins, etc.).

### Badge → plant unlock

| Badge | Unlocks |
|---|---|
| Boulder | Cheri |
| Cascade | Pecha |
| Thunder | Rawst |
| Rainbow | Aspear + Chesto |
| Soul | Persim |
| Marsh or Volcano | Lum |
| Earth | *(no new berry)* |

### Growth

- **9** plots. Face a bed + A to plant (spends 1 berry).
- Growth uses the global `farmSteps` counter (any overworld tile step, not farm-only).
- Base **320** steps per plant.
- Soil ranks: 0→320, 1→280, 2→240, 3→192 steps.
- Rank gates:
  - Rank 1: ≥ **5** Pokédex owned
  - Rank 2: Grass-type in party at **Lv ≥ 20**
  - Rank 3: ≥ **3** berry types in the bag (plain `BERRY` counts; starter BERRY + Cheri + Pecha is enough)

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

Gate: Rainbow Badge **or** Soil Rank ≥ 1.

![Juice Club blender on Celadon Mansion 3F](screen-shots/juice-blender.png)

| Recipe | Cost | Output |
|---|---|---|
| HP UP | 10× Cheri | 1× HP UP |
| Protein | 10× Rawst | 1× Protein |
| Iron | 10× Pecha | 1× Iron |
| Carbos | 10× Aspear | 1× Carbos |
| Calcium | 10× Chesto | 1× Calcium |
| Lum craft | 1 each Cheri/Pecha/Rawst/Aspear/Chesto + 3× BERRY | 1× Lum |

Step cool-down between crafts: **640** farm steps (480 at soil rank 3). No berry-printing recipes except that single Lum craft.

---

## Bag and party QoL

- **Pockets:** Items, Balls, Key Items, TMs & HMs, Berries.
- Bag capacity **60**.
- **DexNav** on the start menu after you have the Pokédex: current map species (more detail once seen/caught). Footer notes Super Rod on fishable maps. If a roamer is on this map, an optional **ROAM** row appears. Mod setting **DEXNAV**: `DEXNAV` (default), `DEXNAV-KR` (rename to tell it apart from another DexNav mod), or `OFF` (hide KR’s entry).
- **Summary** page shows ability, held item, and gender glyph.
- **Optional [Gen1 Modern UI](https://github.com/ArmstrongThomas/gen1-modern-ui):** when that mod is installed, bag pockets and the summary ability page use its presenters; DexNav and party Give/Take keep working through the existing start-menu / party submenu hooks. With Modern UI absent, all of this still draws and plays as stock Gen 1 UI.

![DexNav (Cerulean City)](screen-shots/dexnav.png)

![Berries pocket](screen-shots/bag-berries.png)

![TMs & HMs pocket](screen-shots/bag-tms.png)

---

## Level caps

**Opt-in only.** Viridian youngster east of the Poké Mart on the path. Taking **any** amount permanently enables soft caps:

- Tops your Rare Candies toward **99** (`99 − owned`).
- At the current cap, battle XP becomes +1-style soft stop and Rare Candy cannot push past it.
- Caps rise with story milestones (not only gym badges):

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

Never taking candy = vanilla leveling.

House battle clubs scale opponent levels from the same milestone table even when hard caps are off (soft bracket).

---

## XP Share (slot 2)

When the option is on, the Gen 1 XP pool is split so active fighters get most of it and party **slot 2** can receive a share without inflating past roughly a solo-kill total. Details in `modern_xp_share.lua`.

---

## Smarter AI

Prefers damage that works, devalues setup/status when they would fail or are already applied, etc. Can be turned off in options.

---

## House NPCs and utility

All short Gen 1-style dialogues. No Natures/IV judge, only DVs / Hidden Power / statExp. Club levels scale from the soft-cap bracket even if you never took the Viridian candies.

### Celadon Circuit (Celadon Mansion 2F)

Rematchable battle club. 4 rotating teams by streak. First win → **Choice Band**. Rematches → money (`ace × 40`) and a flat **30%** chance at a Heart Scale.

Same floor: **Beast Tracker** (roamers / Radar after Silph).

### Night Eyes (Vermilion Pidgey House)

Requires a **Dark**-type in the party. First clear → Blackglasses (or ¥5000 if you already have them) + hint toward the Circuit. Rematches → ¥2000.

### Snack Scout (Celadon Hotel)

Lead must **hold a berry**. First clear → **Focus Sash**. Rematches → 1× Cheri + Pecha + Rawst.

### Judge (Underground Path, Route 5 entrance)

Pick a party mon → DV words, Hidden Power type, and which statExp is highest.

### Extra trades

| Location | Give → Get | Held on received |
|---|---|---|
| Route 2 Trade House | Rattata → Taillow (“SWIFT”) | Cleanse Tag |
| Fuchsia Bill’s Grandpa’s House | Bellsprout → Seedot (“GLAND”) | Soothe Bell |

---

## Move Hub

**Saffron Pidgey House.** RELEARN / TUTOR / DELETE.

| Service | Cost | Notes |
|---|---|---|
| Relearn | 1 Heart Scale | Level-up learnset ∪ egg moves; sets PP to max |
| Tutor | 2 Heart Scales | Curated list (punches, Body Slam, Mega Punch/Kick, Rock Slide, Softboiled, Double-Edge, Substitute, …) |
| Delete | Free | Cannot delete the last move; packs slots left |

**Heart Scale finds:** Route 12 beach, Route 19, Seafoam B1F (plus Circuit rematch 30%).

---

## Blacksmith

**Cinnabar Lab Metronome Room.**

| Exchange | Notes |
|---|---|
| Metal Coat → Life Orb | One-shot |
| 3× Nugget → Focus Sash | One-shot; if you already have a sash → 2× Heart Scale instead |
| Leaf Stone → berry pack | Repeatable: BERRY, Cheri, Pecha, Rawst, Aspear (1 each) |

---

## Gen 3 fossils

| Fossil | Where | Revives to |
|---|---|---|
| Root Fossil | Mt Moon B2F hidden | Lileep Lv 30 |
| Claw Fossil | Seafoam 1F hidden | Anorith Lv 30 |

Extra scientist in **Cinnabar Lab Fossil Room** handles Gen 3 revive (vanilla Dome/Helix flow stays for Gen 1 fossils). Hand the fossil in, **leave Cinnabar Island**, then return to pick up the mon.

---

## Roaming legendaries

### Beasts (Raikou / Entei / Suicune)

- After Silph progress, talk to **Beast Tracker** (Celadon Mansion 2F).
- Receive **Roaming Radar** key item; beasts activate on grass routes.

### Eon duo (Latias / Latios)

- After Champion, talk to watcher in **Indigo Plateau Lobby**.

### Behavior

- Foot travel between outdoor maps → migrate to an **adjacent** route.
- Fly / Teleport / blackout → **full** reroll.
- Flee → hop to a neighbor.
- Catch or KO → that species stops roaming.
- Cry plays on map enter when one is here.
- On a map with a roamer: each wild encounter has a flat **15%** chance to be replaced by that beast (not table composition). Level is `max(50, softCap − 2)`, so Repel does not block the hunt.

### Tracking UI

- **Radar** (bag USE or start menu after you have it): species, route name, HERE / NEXT DOOR / FAR.
- **DexNav**: ROAM row only if the beast is on the *current* map.
- **Pokédex**: after first `seen`, entry can show live **AREA** route while still roaming.

---

## Static legendaries and mythicals

One-shot statics. **Win, catch, or flee** all set the beat flag and hide the object, so fleeing despawns them permanently. Overworld sprites are Gen 1 bird/monster/fairy sheets on purpose.

| Species | Location | Gate / key | Level |
|---|---|---|---|
| Ho-Oh | Celadon Mansion roof | Rainbow Wing (Route 16 Fly House: 60 owned) | 50 (sun) |
| Lugia | Seafoam B1F | Silver Wing (Route 12 Gate upstairs: Water ≥Lv30) | 50 (rain) |
| Kyogre | Seafoam B3F | Blue Orb (Cinnabar Lab scientist, post-Champion, first talk) | 60 (rain) |
| Groudon | Pokémon Mansion B1F | Red Orb (same scientist, second talk) | 60 (sun) |
| Regirock | Rock Tunnel B1F | Pewter scholar notes + **3 Rock-types** in party | 50 |
| Regice | Seafoam B2F | Notes + **1 Ice-type** | 50 |
| Registeel | Power Plant | Notes + **1 Steel-type** | 50 |
| Rayquaza | Sky Pillar (custom) | Beat Kyogre **and** Groudon; hiker gate on Route 23 | 70 |
| Celebi | Ilex Shrine (custom) | Champion; channeler gate in Viridian Forest | 30 |
| Deoxys | Birth Island (custom) | Champion + DNA Key (Vermilion Dock sailor) | 70 |
| Jirachi | Mt Moon B1F | Champion + spend **5 Heart Scales** to start | 30 |

**Regi notes:** Pewter Speech House scholar. Show a fossil mon (Omanyte / Kabuto / Aerodactyl / Lileep / Anorith / Cradily / Armaldo) **or** have Boulder Badge.

**DNA Key:** sailor at Vermilion Dock. Need Champion + own **3** from: Raikou, Entei, Suicune, Lugia, Ho-Oh, Kyogre, Groudon, Articuno, Zapdos, Moltres, Mewtwo.

**Jirachi early poke:** before Champion it only says a wish is sleeping. No fight, no Heart Scale spend. Scales are only consumed when the fight actually starts after Champion.

---

## Custom maps

| Map | Index | Purpose |
|---|---|---|
| `BERRY_FARM` | 1100 | Berry plots + NPCs |
| `SKY_PILLAR_KANT` | 1101 | Rayquaza |
| `ILEX_SHRINE_KANT` | 1102 | Celebi |
| `BIRTH_ISLAND_KANT` | 1103 | Deoxys |

Legendary custom maps save return coordinates on enter and exit via warp hooks so you cannot soft-lock. They are not remembered as `lastOutdoor` (same class of fix as the Berry Farm PC door).

---

## Caveats and save notes

- Friendship / time / location evolutions are fudged for Gen 1.
- Move anims and menu icons are reused Gen 1 art on purpose.
- DexNav Super Rod note: Old/Good Rod are global pools.
- FULL SPAWN MIX rewrites tables. Set it before a long save.
- Level caps stay off until you accept Viridian candies.
- Static legendaries despawn on flee as well as catch/KO.
- Link play needs matching mods on both sides.
- Gen 1 `.sav` export/import will drop post-151 mons and Eggs.

---

## Module map (for modders)

| File | Responsibility |
|---|---|
| `main.lua` | Boot order, types/moves/species registration, options |
| `pokemon_data.lua` / patches | Generated species, abilities, learnsets, gender, breeding |
| `types_data.lua` | Dark / Steel / Fairy |
| `move_effects.lua` / `move_anims.lua` | Effects + anim aliases |
| `encounters.lua` / `trainers.lua` / `trainer_ai.lua` | Wilds + trainer mixes + AI |
| `held_items.lua` / `competitive_items.lua` / `overworld_loot.lua` | Items + finds |
| `berry_farm.lua` / `berry_quests.lua` | Farm map, merchant, blender, soil |
| `gender.lua` / `breeding.lua` / `daycare.lua` | Gender + eggs |
| `level_caps.lua` / `modern_xp_share.lua` / `split_special.lua` | Caps + slot-2 XP + optional SpA/SpD |
| `special_stat_patches.lua` | Generated Kanto SpA/SpD for the split toggle |
| `bag_pockets.lua` / `dexnav.lua` / `summary_ui.lua` / `gen1_modern_ui_adapter.lua` | QoL UI (+ optional Modern UI) |
| `house_npcs.lua` | Object-index claims + shared NPC helpers |
| `battle_clubs.lua` / `judge_npc.lua` / `trades_extra.lua` | Clubs, judge, trades |
| `move_hub.lua` / `item_smith.lua` / `fossils_gen3.lua` | Tutor hub, smith, fossils |
| `roamers.lua` / `roaming_radar.lua` / `roamer_dex.lua` / `kanto_graph.lua` | Roamers |
| `legend_shrines.lua` / `legend_regis.lua` / `legend_mythicals.lua` | Statics + custom maps |

Tests live under `tests/` and are pulled in by `tests/Kanto-Reforged_test.lua`.

Map PNG previews (optional QA): `map_previews/` via `render_map_previews.py`.
