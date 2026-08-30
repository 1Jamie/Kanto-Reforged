# Kanto Reforged — Walkthrough

This is the "when should I poke my head into the new stuff" guide. Vanilla story progression still works the way you remember it. I only call out story beats when something new hangs off them.

If you want full raw tables (recipes, internal module maps, formulas), that's [FEATURES.md](FEATURES.md). This guide is built to be kept open and referenced while you play. Numbers and locations here come straight from the mod code.

---

## Before you start (Options & Setup)

1. Enable **Kanto Reforged** (`Kanto-Reforged`) in the Mods tab or F10 manager. (If playing Gold/Silver/Crystal, also enable `pokegear_cards` for the DexNav card!).
2. Decide these options early:
   - **DEX SCOPE / JOHTO SCOPE**: Gen 1 **KANTO** restricts spawns and trainer mixes to the original 151 (out-of-scope party/PC mons are stashed and returned safely when you swap back). Gen 2 **JOHTO 251** caps Johto grass at dex 251 while Kanto keeps Gen 3 postgame guests.
   - **XP SHARE (SLOT 2)** (default on): fighters get ~70% of the XP pool; party slot 2 gets up to ~30%. Replaces old EXP.ALL behavior while on.
   - **SMARTER AI** (default on): trainers play less dumb (prefer super effective moves, skip failing status). Turn off if you miss classic gen1 randomness.
   - **SWITCH HIT AI**: classic free-hit on switch vs Gen 3 lock (Red shows GEN 1/3; Gen 2 shows GEN 2/3).
   - **FULL SPAWN MIX** (default off): fully random gen1-3 wilds. On Gen 2 this covers Johto and Kanto (with a density pass so Kanto stays full). It rewrites encounter tables, so flip it before a long run if you care.
   - **PURE RANDOM SPAWN** (default off): absolute chaos mode with no habitat or BST restrictions.
   - **LEGENDS IN MIX** (default off): only matters with FULL SPAWN MIX / PURE RANDOM on — lets legendaries/mythicals roll into wild grass (still level-gated).
   - **SP.ATK / SP.DEF** (Red only, default off): special damage and summary UI use separate Sp.Atk / Sp.Def instead of Gen 1 Special. Leave off for classic mechanics.
   - **DEXNAV** (Red only): start-menu label or off. (Gen 2 DexNav is automatically a card on your Pokegear).
   - **SPRITES 1-251** (Red only): boot KR on the Gen 2 ROM whose sprites you want (Gold / Silver / Crystal) so it caches dex 1–251, then load Red and set this toggle to that edition (or **CUSTOM KR**). Hoenn (252+) always stays KR. Details: [README — Gen1 sprite sets](README.md#gen1-sprite-sets-sprites-1-251).
---

# Part 1: Gen 1 (Red / Blue) Walkthrough

One important heads up before anything else: **static legendaries despawn if you run.** Win, catch, or flee all count as "done" for that encounter. Don't soft-open a fight you aren't prepared for.

### Early Game (Pallet through Pewter)

#### Viridian City

1. **Opt-in Level Caps:** Look outside the Poké Mart and head slightly east along the path. There's a kid offering Rare Candies.
   - If you say YES: He tops your bag up to **99** Rare Candies, and soft level caps turn on permanently for that save. At the cap, battle XP drops to +1 and Rare Candies won't push past it. Caps expand as you beat gyms and story milestones (starts at 14 pre-Brock, climbs to 100 post-Champion).
   - If you say NO: Leveling stays 100% vanilla. Decide before you candy your starter to Lv 100!
2. **First Berry Farm visit:** Enter the Viridian Pokémon Center and step on the extra carpet on the right side of the room.

**First farm visit checklist:**
- You receive **3× BERRY** automatically the first time you arrive.
- Talk to the farm girl near the plots for a quick breakdown on planting.
- Talk to the Berry Scholar if you want an in-game reference of what every berry cures.
- Talk to the merchant at the stall and the Soil Expert. Early on the merchant only sells plain BERRY (¥300). Status berries unlock as you earn gym badges.
- Face a plot and press A. Pick a berry from your bag to spend **1** berry and plant it.
- There are **9** plots. Growth is based on steps taken anywhere in the overworld (base is **320** steps). Harvesting yields **2** berries, so replanting nets you +1 every harvest.
- Soil Ranks (talk to the Soil Expert later):
  - Rank 1: Own **5** species → 280 steps.
  - Rank 2: Grass-type in party at **Lv 20+** → 240 steps.
  - Rank 3: **3** different berry types in bag → 192 steps (also speeds up the Juice Blender). Starter BERRY + Cheri + Pecha is enough.

#### Pewter City

1. Beat Brock (Boulder Badge).
2. Warp to the farm from Pewter Center and talk to the Soil Expert. Unlocks **Cheri Berry** and gifts you **3× Cheri**.
3. Plant Cheri, walk your steps, harvest when ripe.
4. Hidden **Hard Stone** in the grass near the Gym / Mart strip (use Item Finder).
5. Pewter **Speech House**: The scholar inside will give you the Regi notes if you have Boulder Badge (or show a fossil mon). You don't need this until the postgame, but grabbing it now saves a trip later.

#### Route 2 Trade House

In the house on Route 2 between Viridian and Pewter, trade **Rattata → Taillow** (nickname SWIFT). It comes holding a **Cleanse Tag**.

#### Mt. Moon

1. Pick Dome or Helix Fossil as usual.
2. On **B2F**, hunt down the hidden **Root Fossil** (Item Finder helps). Revives into Lileep later at Cinnabar Lab.
3. **Postgame only note:** Jirachi sleeps on **B1F**. Before you're Champion it's asleep; after Champion it asks for **5 Heart Scales** to fight.

---

### Mid Game (Cerulean through Celadon)

#### Cerulean City & Route 5

1. Beat Misty (Cascade Badge).
2. Farm → Soil Expert unlocks **Pecha Berry** + gifts **3× Pecha**.
3. **Route 5 Day Care:** The vanilla house is now Gen 3-style:
   - Talk to the Day-Care Man or Lady inside to deposit up to **two** compatible parents (keep at least 1 mon in party; no eggs in daycare).
   - Compatible parents produce an Egg. Walk with it in your party to hatch (hatches at Lv 5). Flame Body / Magma Armor in the party speeds up egg steps.
   - Breeding passes down DVs (Crystal style). No natures/IVs.

#### Underground Path (Route 5 Entrance)

Enter the Underground Path by Route 5. The **Judge** NPC is here. Pick any party mon and he'll read its DV quality, Hidden Power type, and highest `statExp`.

#### Vermilion City

1. Beat Lt. Surge (Thunder Badge).
2. Farm → Soil Expert unlocks **Rawst Berry** + gifts **3× Rawst**.
3. Enter the **Pidgey House** in Vermilion. **Night Eyes** is inside.
4. Put any **Dark-type** in your party and talk to them.
5. First win gives **Blackglasses** (or ¥5000 if already owned). Rematches pay ¥2000.

#### Rock Tunnel

1. On **B1F**, look for a Poké Ball containing a **Focus Band**.
2. **Postgame Regi note:** A hidden ladder on B1F (north wall spur) leads to Regirock's chamber. Needs Regi notes + **3 Rock-types** in your party.

#### Celadon City

- **Hidden Leftovers:** On the soft path / grass directly north of Celadon Mansion. Don't skip this!
- **Celadon Mansion 2F (Celadon Circuit):** Rematchable battle club. Opponents scale with your story progress. First win gives **Choice Band**. Rematches pay good money and have a **30%** chance to drop a Heart Scale.
- **Celadon Mansion 2F (Beast Tracker):** Unlocks after Silph Co.
- **Celadon Mansion 3F (Juice Club Blender):** Unlocked with Rainbow Badge or Soil Rank 1+. Blends 10 status berries into 1 Vitamin (HP Up, Protein, Iron, Carbos, Calcium). Has a step cool-down between uses.
- **Celadon Mansion Roof:** Ho-Oh roosts here later once you have the Rainbow Wing (Lv 50, permanent sun).
- **Celadon Hotel (Snack Scout):** Have your **lead Pokémon hold any berry** (Party → Give). First win gives **Focus Sash**. Rematches gift status berries.
- **Beat Erika (Rainbow Badge):** Farm → Soil Expert unlocks **Aspear Berry** and **Chesto Berry** (gifts 3× each).

#### Route 16 Fly House

With **60+ species owned** in your Pokédex, talk to the NPC in the Route 16 Fly House to receive the **Rainbow Wing** (for Ho-Oh).

#### Lavender Town

- Hidden **Spell Tag** on the path right beside the Pokémon Tower entrance.
- Inside Pokémon Tower **7F**, grab the Poké Ball with **Blackglasses** if you missed it earlier.

---

### Mid–Late Game (Fuchsia through Saffron)

#### Fuchsia City

1. Beat Koga (Soul Badge).
2. Farm → Soil Expert unlocks **Persim Berry** + gifts **3× Persim**.
3. **Bill's Grandpa's House:** Trade **Bellsprout → Seedot** (nickname GLAND, holds **Soothe Bell**).

#### Route 12 & Route 19

1. Go upstairs in the **Route 12 Gate** (north of Silence Bridge). Show a **Water-type Lv 30+** to get the **Silver Wing** (for Lugia).
2. Hidden **Heart Scale** on the Route 12 beach/pier.
3. Another hidden **Heart Scale** on **Route 19** water route.

#### Saffron City

1. Hidden **Twistedspoon** on the central sidewalk south of Silph Co.
2. Black Belt outside Fighting Dojo gives you a **Black Belt** held item.
3. **Saffron Pidgey House (Move Hub):**
   - Relearn: **1 Heart Scale** (level-up moves + egg moves, PP maxed).
   - Tutor: **2 Heart Scales** (elemental punches, Body Slam, Rock Slide, Softboiled, Double-Edge, Substitute, etc.).
   - Delete: Free.
4. Beat Sabrina (Marsh Badge) → Farm unlocks **Lum Berry** + gifts **3× Lum**.

#### Silph Co. & Roaming Beasts

1. Defeat Giovanni at Silph Co.
2. Return to **Celadon Mansion 2F** and talk to the Beast Tracker.
3. Receive the **Roaming Radar**! Raikou, Entei, and Suicune are now roaming Kanto grass routes.
   - Use the Radar from your Bag or Start Menu to see their current route and proximity (HERE / NEXT DOOR / FAR).
   - Entering their map plays their cry, and DexNav adds a ROAM row.
   - Roamers have a 15% flat replace rate on wild encounters on their map. Repels won't block them.

#### Power Plant

1. Pick up the Poké Ball **Metal Coat** while exploring. (Save it for the Cinnabar blacksmith to forge a Life Orb).
2. Registeel chamber is located here postgame (needs Regi notes + 1 Steel-type).

---

### Late Game (Cinnabar through Elite Four)

#### Cinnabar Island

- **Cinnabar Lab (Fossil Room):** Hand Root Fossil or Claw Fossil to the Gen 3 scientist. Leave Cinnabar and come back to receive **Lileep** or **Anorith** (Lv 30).
- **Cinnabar Lab (Metronome Room / Blacksmith):**
  - Metal Coat → **Life Orb** (one-time).
  - 3× Nugget → **Focus Sash** (or 2× Heart Scale if you already have one).
  - Leaf Stone → 5-berry variety pack (repeatable).
- **Cinnabar Lab Main Room (Postgame):** Talk to the scientist after beating the Champion to receive the **Blue Orb** (Kyogre) and **Red Orb** (Groudon).

#### Seafoam Islands & Pokémon Mansion

- **Seafoam 1F:** Hidden **Claw Fossil** (Item Finder helps).
- **Seafoam B1F:** Lugia encounter with Silver Wing (Lv 50, rain).
- **Seafoam B2F:** Regice seal (needs Regi notes + 1 Ice-type).
- **Seafoam B3F:** Kyogre encounter with Blue Orb (Lv 60, rain, postgame).
- **Pokémon Mansion B1F:** Groudon encounter with Red Orb (Lv 60, sun, postgame).

#### Indigo Plateau

1. Defeat the Elite Four and Champion!
2. Talk to the watcher in the **Indigo Plateau Lobby** to activate roaming **Latias** and **Latios** on your Radar.

---

### Gen 1 Postgame Checklist

- [ ] **Ho-Oh:** Celadon Mansion Roof (Rainbow Wing from Route 16 Fly house).
- [ ] **Lugia:** Seafoam Islands B1F (Silver Wing from Route 12 gate).
- [ ] **Kyogre & Groudon:** Seafoam B3F & Mansion B1F (Orbs from Cinnabar Lab post-Champ).
- [ ] **Rayquaza:** Sky Pillar gatekeeper on Route 23 (unlocked after beating both Kyogre & Groudon).
- [ ] **Regis:** Pewter notes → Regirock (Rock Tunnel B1F hidden ladder + 3 Rock-types), Regice (Seafoam B2F + 1 Ice-type), Registeel (Power Plant + 1 Steel-type).
- [ ] **Celebi:** Viridian Forest shrine gatekeeper (post-Champ, sends you to Ilex Shrine).
- [ ] **Deoxys:** Vermilion Dock sailor (post-Champ; requires owning 3 caught legendaries from the classic pool: Raikou, Entei, Suicune, Lugia, Ho-Oh, Kyogre, Groudon, Articuno, Zapdos, Moltres, Mewtwo; gives DNA Key to Birth Island).
- [ ] **Jirachi:** Mt. Moon B1F (post-Champ, sacrifice 5 Heart Scales).
- [ ] **Roamers:** Track down all 3 beasts + Eon duo using the Roaming Radar.

---

# Part 2: Gen 2 (Gold / Silver / Crystal) Walkthrough

Johto wild version exclusives are cross-injected so each cart can catch the bases it was missing (Gold gets Ledyba/Phanpy/…, Silver gets Spinarak/Gligar/…, Crystal gets Mareep/Girafarig/…). Legendary mascot story beats still follow the cart you imported — KR overlays Gen 3 guests onto the active ROM tables rather than forcing one cart's mascot quest onto another.

> [!IMPORTANT]
> **A quick heads up on how Gen 2 works in Kanto Reforged:**
> Vanilla Johto plays almost entirely the same as the classic game (Gold, Silver, or Crystal), with several nice QoL additions built right in (Pokegear DexNav, Berry Farm access, Cherrygrove level caps, Johto badge berry unlocks, Gen 3 wild guests, Moon Stone trade evos, and cross-injected wild exclusives). Story mascots still follow the cart.
> **The massive bulk and meat of Kanto-Reforged's new content in Gen 2 is the fully overhauled Post-Johto Kanto campaign.** 
> Once you step off the S.S. Aqua in Vermilion, Kanto has been rebuilt with a rebalanced level progression, full Gen 3 wild encounter tables, overhauled Gym Leaders and gym trainers, dedicated battle circuits (Nugget Bridge, Saffron Dojo), relocated utility hubs, and a proper ramp up to Red at Mt. Silver.

---

### Johto Arc (New Bark to the Pokémon League)

#### 1. Cherrygrove City & Opt-in Level Caps

On the east side of Cherrygrove City near the path, look for the Youngster NPC offering Rare Candies.
- **Taking the candies** tops you up to 99 Rare Candies and permanently turns on soft level caps. Battle XP soft-stops at the cap, preventing you from overleveling story content.
- **Johto Level Caps Table:**
  | Story Milestone | Level Cap |
  |---|---|
  | Pre-Falkner | 14 |
  | Pre-Bugsy (Zephyr Badge) | 16 |
  | Pre-Whitney (Hive Badge) | 20 |
  | Pre-Morty (Plain Badge) | 25 |
  | Pre-Chuck (Fog Badge) | 30 |
  | Pre-Pryce / Rocket Hideout (Storm Badge) | 32 |
  | Pre-Jasmine (Glacier Badge / Cleared Hideout) | 35 |
  | Pre-Radio Tower (Mineral Badge) | 38 |
  | Pre-Clair (Cleared Radio Tower) | 40 |
  | Pre-Victory Road Rival (Rising Badge) | 44 |
  | Pre-Champion Lance (Beat Victory Road Rival) | 50 |

#### 2. Pokegear DexNav & Party Summary Page 4

- **DexNav Card:** Open your Pokegear at any time to inspect the live wild spawns on your current route (requires `pokegear_cards` mod).
- **Party Summary Page 4:** Open your Pokémon's summary screen and scroll past the pink, green, and blue pages. Page 4 displays their **Gen 3 Ability**, held item, gender glyph, and full ability description.

#### 3. Berry Farm via Johto Pokémon Centers

- Step onto the **stairs tile** in the bottom-right corner of any Johto Pokémon Center to warp directly to the Berry Farm.
- **First Visit:** Get **3× BERRY** free on arrival.
- **Johto Badge Unlocks:** Talk to the Soil Expert as you collect Johto badges to unlock new seeds and get a free 3-pack of each:
  - **Zephyr Badge** → Cheri Berry (cures paralysis)
  - **Hive Badge** → Pecha Berry (cures poison)
  - **Plain Badge** → Rawst Berry (cures burn)
  - **Fog Badge** → Aspear Berry (thaw) & Chesto Berry (wake) + Unlocks Juice Club Blender! (Also unlocks at Soil Rank ≥ 1 if you hit that first)
  - **Storm Badge** → Persim Berry (cures confusion)
  - **Mineral / Glacier Badge** → Lum Berry (cures all status)
- Unlocked berries can be bought anytime from the farm merchant (¥300 BERRY, ¥600 status, ¥2000 Lum).

#### 4. Johto Wild Encounters & Moon Stone Evolutions

- **Wilds:** Johto routes keep all native Gold Pokémon, with curated Gen 3 guests appearing in grassland, forest, mountain, and cave routes (e.g. Ralts, Seedot, Aron, Shroomish, Poochyena, Electrike, Trapinch).
- **Trade Evolution Bypass:** No trading needed! You can use a **Moon Stone** to evolve:
  - Onix → **Steelix**
  - Scyther → **Scizor**
  - Poliwhirl → **Politoed**
  - Slowpoke → **Slowking**
  - Porygon → **Porygon2**
  - Gloom → **Bellossom**
  - Eevee → **Umbreon**
  - Sunkern → **Sunflora**

#### 5. Battle Mechanics Updates

- **XP Bar:** A smooth blue XP bar displays under your active Pokémon's HP bar in battles, supporting widescreen layouts.
- **Freeze Parity:** Freeze uses modern Gen 3 rules: 1-in-5 chance to unfreeze each turn, and any incoming fire-type attack immediately thaws the target.

---

### Kanto Postgame Campaign (The Main Event)

After defeating Champion Lance at Indigo Plateau, board the S.S. Aqua in Olivine City to embark on the overhauled Kanto postgame!

#### 1. Kanto Level Progression & Level Caps

Kanto in Gold is famously known for having flat level 30-40 wild mons and pushover gyms. Kanto Reforged completely rebalances this curve into a proper postgame gauntlet:

| Milestone | Level Cap | Recommended Focus |
|---|---|---|
| Kanto Arrival / First Gyms | 58 | Routes 5–11, Lt. Surge, Janine, Erika |
| 3 Kanto Badges | 64 | Routes 12–19, Misty, Sabrina, Brock, Blaine |
| 7 Kanto Badges | 72 | Viridian Gym, Blue |
| 8 Kanto Badges / Beat Mt. Moon Rival | 85 | Safari clear → Silver → prep for Red |
| Post-Red (Mt. Silver) | 100 | True Endgame |

#### 1b. Rocket campaign spine

TEAM ROCKET fled Johto and dug into soft Kanto. **Blue** (Route 22 + Pokégear calls) drafts you to smash their operation:

1. **Mt. Moon** — toll racket / training camp. Clear the checkpoint.
2. **Rock Tunnel** — supply line to Fuchsia; Blue waits near the south exit.
3. **Safari Zone** — Fuchsia door stays sealed until both caves are clear; Rockets turned the preserve into a rare-mon industry (Secret House boss).
4. **Silver (Mt. Moon B2F)** — personal rival fight after Safari + 8 badges (Lv 75–78, Tyranitar ace).
5. **Red** — Mt. Silver summit.

#### 2. Kanto Berry Farm Access

In all Gen 2 Kanto Pokémon Centers, step onto the **red door mat pair on the south row** to warp straight to the Berry Farm. (Indigo Plateau Center uses the SE stairs).

#### 3. Rebuilt Kanto Wild Spawns

All Kanto outdoor grass routes feature full Gen 3 wild encounter tables scaled to postgame levels (**Lv 28–40+**):
- **Routes 1–4, 22, 28, Viridian Forest:** Grassland & mountain Gen 3 lines (Breloom, Linoone, Swellow, Zangoose, Seviper, Absol, etc.).
- **Routes 5–8, 11 (Arrival zone):** Urban and plains species (Manectric, Swalot, Delcatty, Spoink, Loudred).
- **Routes 12–15 & Silence Bridge:** Coastline & waters-edge spawns (Crawdaunt, Lombre, Pelipper, Whiscash).
- **Cycling Road (Routes 16–18):** Mountain & poison bruisers (Hariyama, Aggron, Weezing, Swalot).
- **Routes 24–25 (Cerulean Cape):** Waters-edge and forest species (Ludicolo, Crawdaunt, Illumise, Volbeat).

#### 4. Overhauled Kanto Gym Circuit

Every Gym Leader brings a fully re-leveled team with Gen 2/3 additions and competitive held berries:

1. **Vermilion Gym — Lt. Surge (Ace Lv 55)**
   - Team: Electrike (52), Ampharos (53), Magneton (53), Electrode (54), Manectric (54), Raichu (55, holds **Chesto Berry**).
2. **Fuchsia Gym — Janine (Ace Lv 56)**
   - Team: Ariados (52), Swalot (53), Weezing (54), Seviper (54), Crobat (55), Venomoth (56, holds **Persim Berry**).
3. **Celadon Gym — Erika (Ace Lv 57)**
   - Team: Roselia (53), Jumpluff (54), Tangela (54), Breloom (55), Victreebel (56), Bellossom (57, holds **Rawst Berry**).
4. **Cerulean Gym — Misty (Ace Lv 61)**
   - Team: Lanturn (57), Golduck (58), Crawdaunt (59), Quagsire (59), Lapras (60), Starmie (61, holds **Pecha Berry**).
5. **Saffron Gym — Sabrina (Ace Lv 62)**
   - Team: Girafarig (58), Mr. Mime (59), Xatu (59), Espeon (60), Gardevoir (61), Alakazam (62, holds **Cheri Berry**).
6. **Pewter Gym — Brock (Ace Lv 62)**
   - Team: Sudowoodo (58), Omastar (59), Kabutops (59), Rhydon (60), Aggron (61), Steelix (62, holds **Berry**).
7. **Seafoam / Cinnabar Gym — Blaine (Ace Lv 63)**
   - Team: Torkoal (59), Camerupt (60), Magcargo (60), Rapidash (61), Houndoom (62), Magmar (63, holds **Persim Berry**).
8. **Viridian Gym — Blue (Ace Lv 72)**
   - Team: Pidgeot (70), Alakazam (70), Tyranitar (70), Gyarados (70), Exeggutor (71), Arcanine (72, holds **Cheri Berry**).

#### 5. Special Battle Circuits & Overworld Hotspots

- **Saffron Fighting Dojo (Levels 60–64):** Re-opened with intense Black Belt battles featuring Hariyama, Breloom, Medicham, Primeape, Hitmonlee, and Hitmonchan.
- **Nugget Bridge Circuit (Route 24/25, Levels 56–60):** Rematch the gauntlet across Route 24 and 25 against Volbeat, Illumise, Zangoose, Seviper, Corphish, and Golduck.
- **Mt. Moon Rival Rematch (Levels 75–78):** After clearing the Safari Rocket occupation and earning 8 Kanto badges, find Silver tucked on **Mt. Moon B2F** — Sneasel, Magneton, Gengar, Alakazam, Crobat, and Tyranitar (78, **Lum Berry**).
- **Safari Rocket dungeon:** Unlocks in Fuchsia only after Mt. Moon + Rock Tunnel Rocket chapters.

#### 6. Relocated Utility NPCs in Gold Kanto

Because Kanto's map layout changes between Gen 1 and Gen 2, utility NPCs are conveniently relocated:
- **Move Hub (Mr. Psychic's House in Saffron City):**
  - Move Relearner: **1 Heart Scale** (full level-up learnset + egg moves, PP maxed).
  - Move Tutor: **2 Heart Scales** (elemental punches, Body Slam, Rock Slide, Softboiled, Double-Edge, Substitute, etc.).
  - Move Deleter: **Free**.
- **Item Smith (Cinnabar Pokémon Center 1F):**
  - With Cinnabar Lab destroyed by the volcano in Gen 2, the Blacksmith set up shop inside Cinnabar Pokecenter!
  - Metal Coat → **Life Orb** (one-time).
  - 3× Nugget → **Focus Sash** (or 2× Heart Scale if you already have one).
  - Leaf Stone → 5-berry variety pack (repeatable).
- **DV / Hidden Power Judge (Underground Path):**
  - Stationed inside the north-south Underground Path connecting Route 5 and Route 6. Inspects DVs, Hidden Power type, and best `statExp`.

#### 7. The Ultimate Showdown: Mt. Silver & Red

With all 8 Kanto Badges and the Mt. Moon Rival conquered, your level cap expands to **100**. Scale Mt. Silver Cave and challenge Red in the ultimate battle!

---

## Where is that again? (Quick Reference)

| What | Gen 1 (Red / Blue) | Gen 2 (Gold / Silver / Crystal) |
|---|---|---|
| **Rare Candy / Level Caps** | Viridian City (east of Mart) | Cherrygrove City (east path) |
| **Berry Farm Access** | Right carpet in any Center | Stairs / south mat in any Center |
| **DexNav** | Start Menu under Pokédex | Pokegear Card (`pokegear_cards`) |
| **Party Ability / Held Screen** | Summary Page 3 | Summary Page 4 |
| **DV / Hidden Power Judge** | Underground Path (Route 5 side) | Underground Path (Route 5/6 tunnel) |
| **Move Hub (Relearn / Tutor / Delete)** | Saffron Pidgey House | Saffron (Mr. Psychic's House) |
| **Item Smith (Life Orb / Focus Sash)** | Cinnabar Lab Metronome Room | Cinnabar Pokémon Center 1F |
| **2-Slot Day Care & Breeding** | Route 5 Day Care | Route 34 Day Care (Vanilla Gen 2) |
| **Celadon Circuit (Choice Band)** | Celadon Mansion 2F | Celadon Mansion 2F |
| **Blender (Vitamins from Berries)** | Celadon Mansion 3F | Celadon Mansion 3F |
| **Snack Scout (Focus Sash)** | Celadon Hotel (lead holds berry) | Celadon Hotel |
| **Night Eyes (Blackglasses)** | Vermilion Pidgey House (Dark lead) | Vermilion Pidgey House |
| **Gen 3 Fossils (Lileep / Anorith)** | Cinnabar Lab Fossil Room | N/A (Gen 1 only) |
| **Roamer Radar (Beasts / Eon)** | Celadon 2F (after Silph) | N/A (Vanilla Pokegear map / Gen 1 Radar) |
| **Sky Pillar (Rayquaza)** | Route 23 Hiker (after Kyogre/Groudon) | N/A (Gen 1 only) |
| **Ilex Shrine (Celebi)** | Viridian Forest Channeler | N/A (Gen 1 only) |
| **Birth Island (Deoxys)** | Vermilion Dock Sailor (3 Legends owned) | N/A (Gen 1 only) |
| **Mt. Moon (Jirachi)** | Mt. Moon B1F (5 Heart Scales) | N/A (Gen 1 only) |

---

## More reading

- [README.md](README.md): overview, options, install steps
- [FEATURES.md](FEATURES.md): full reference (exact numbers, recipes, flags, module architecture)
