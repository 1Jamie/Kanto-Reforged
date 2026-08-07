# Kanto Reforged — Walkthrough

This is the "when should I poke my head into the new stuff" guide. Vanilla Red/Blue still happens the same way. I only call out story beats when something new hangs off them.

If you want the full tables (recipes, module map, etc.) thats [FEATURES.md](FEATURES.md). This one is meant to be usable while you play. Numbers here come from the actual mod code.

Spoilers for midgame and postgame legendaries are labeled when we get there.

One important heads up before anything else: **static legendaries despawn if you run.** Win, catch, or flee all count as "done" for that encounter. Dont soft-open a fight youre not ready for.

## Before you start

1. Enable **Kanto Reforged** (`Kanto-Reforged`) in the Mods tab or F10 manager.
2. Decide these options early:
   - **XP SHARE (SLOT 2)** (default on): fighters get most of the XP pool, party slot 2 gets a share. Ignores the old EXP.ALL behavior while its on.
   - **SMARTER AI** (default on): trainers play less dumb. Turn off if you want classic gen1 chaos.
   - **FULL SPAWN MIX** (default off): fully random gen1-3 wilds. It rewrites encounter tables, so flip it before a long run if you care.
   - **SP.ATK / SP.DEF** (default off): special damage and the summary use Sp.Atk / Sp.Def instead of Gen 1 Special. Leave off for classic mechanics.
3. After Oak gives you the Pokédex, open the start menu. **DexNav** shows up under Pokédex. It lists whats on the current map (`????` until seen, more detail once owned). If a roamer is here it also shows a ROAM row later.

**Level caps are opt-in.** In Viridian, stand outside the Poké Mart and look east along the path. Theres a kid offering Rare Candies. If you accept:
- He tops you up toward **99** Rare Candies.
- Soft level caps turn on for that save forever (you cannot undo it).
- At the current cap, battle XP soft-stops (+1 style) and Rare Candy wont push past it.
- Caps rise with story milestones (badges and some events), not only gyms. Starts at 14 pre-Brock and climbs to 100 post-Champion.

Say no and leveling stays vanilla. Decide before you dump candies into your starter.

**Berry Farm mats:** every Pokémon Center has an extra carpet on the right side of the floor. Step on it to warp to the farm. The shed door brings you back to that same Center. You can go as soon as you hit Viridian Center.

## Early game (Pallet through Pewter)

### Viridian

1. Talk to the candy kid outside the mart if you want caps (or free candies with the consequences). Skip him if you dont.
2. Enter the Pokémon Center and step on the farm mat on the right.

**First farm visit checklist**

1. You get **3× BERRY** automatically the first time you land (one-time).
2. Talk to the farm girl near the flower beds so planting makes sense.
3. Talk to the Berry Scholar if you want the "what does this berry do" menu.
4. Talk to the merchant at the stall and the Soil Expert. Early on the merchant mostly has plain BERRY (¥300). Status berries unlock with badges.
5. Face a flower bed and press A. Pick a berry from your bag. That spends **1** berry and starts a plant.
6. There are **9** plots. Growth is based on steps you walk anywhere in the overworld (not farm-only). Base is **320** steps. Harvest gives **2** berries, so if you replant one youre netting +1.

Growing is the bulk path. Buying is fine when youre short one to plant. Status berries are **not** in city marts.

Soil ranks (talk Soil Expert again later):
- Rank 1: own **5** species → growth 280 steps
- Rank 2: Grass-type in party at **Lv 20+** → 240 steps
- Rank 3: **3** different berry types in the bag → 192 steps (also cools the blender faster). Plain BERRY counts, so starter BERRY + Cheri + Pecha is enough; you dont need three status berries.

### Pewter

1. Beat Brock (Boulder Badge).
2. Warp to the farm and talk to the Soil Expert. Unlocks **Cheri** and gifts **3× Cheri** once.
3. Optional: plant Cheri, keep walking, harvest when ripe.
4. Hidden **Hard Stone** in the grass near the Gym / Mart strip. Item Finder helps if youre hunting.
5. The little **Speech House** in Pewter (same one with the usual talky NPCs) has a Regi scholar now. Show a fossil mon (Omanyte / Kabuto / Aerodactyl / later Lileep / Anorith / etc.) **or** just having Boulder Badge unlocks the Regi notes. You dont need this until you hunt Regis later, but its easy to do now and forget.

### Route 2 trade house

Same trade house as vanilla, on Route 2 between Viridian and Pewter. Trade **Rattata → Taillow** (nickname SWIFT). It comes holding a **Cleanse Tag**. Optional early Johto mon.

### Mt. Moon

1. Grab Dome or Helix as usual.
2. On **B2F**, hunt a hidden **Root Fossil** while youre down there (Item Finder helps). That becomes Lileep later at the Cinnabar lab. Easy to blast past.
3. **Postgame only:** Jirachi hangs out on **B1F**. Before youre Champion it just says a wish is sleeping and nothing happens, so poking it early is safe. After Champion it wants **5 Heart Scales** to start the fight (those get spent).

## Mid game (Cerulean through Celadon)

### Cerulean / Misty / Route 5

1. Beat Misty (Cascade Badge).
2. Farm → Soil Expert → unlocks **Pecha** + **3× Pecha**.
3. Route 5 Day Care is the same building as vanilla, gen3-style now:
   - Talk to the Day-Care Man or Lady inside.
   - Leave up to **two** parents (keep at least one mon in your party; no depositing Eggs).
   - Compatible parents can produce an Egg. Take it and walk to hatch (level 5).
   - Flame Body / Magma Armor in the party speeds hatching.
   - Inheritance is still DVs. No natures, no IVs.
   - Fee when you withdraw is the usual level-grown formula.

### Underground Path (Route 5 side)

Go into the Underground Path from the Route 5 entrance (the one by the Day Care / toward Cerulean). Theres a **Judge** NPC in there. Pick a party mon. He reads DV words, Hidden Power type, and which `statExp` is highest. No battle, no item. Useful if you care about DVs. Skip if you dont.

### Vermilion

1. Beat Surge (Thunder Badge).
2. Farm → Soil Expert → unlocks **Rawst** + **3× Rawst**.
3. Enter the **Pidgey House** in Vermilion (same house as the old Pidgey guy). **Night Eyes** is in there now.
4. Put any **Dark**-type in the party and talk to them.
5. First win: **Blackglasses** if you dont have them, otherwise ¥5000, plus a hint toward Celadon Mansion. Rematches pay ¥2000.

### Rock Tunnel

1. On **B1F**, keep an eye out for a Poké Ball with a **Focus Band** while youre exploring. Not sold in marts.
2. Later (after Regi notes): theres a Regirock seal on B1F too. Needs notes + **3 Rock-types** in the party. Dont interact until ready (flee despawns it).

### Celadon (this city does a lot)

**Items first**

1. Hidden **Leftovers** on the soft path / grass **north of Celadon Mansion**. Worth the detour. Theres also a gramps near the mansion who basically tells you his Item Finder keeps beeping up that way.
2. Celadon Mart still sells type boosters (5F etc.). It does **not** sell status berries, Leftovers, or Focus Band.

**Celadon Mansion 2F**

1. **Celadon Circuit**: rematch battle club on this floor. Levels scale with your story bracket. First clear → **Choice Band**. Rematches → money, and about a **30%** chance at a Heart Scale. Come back when your team can take a hit.
2. **Beast Tracker** on the same floor: quiet until after Silph. Come back then for Radar + beasts.

**Celadon Mansion 3F**

Juice Club blender (the beauty up there). Needs **Rainbow Badge** or Soil Rank 1+. Turns berries into vitamins at a steep cost (10 status berries → 1 vitamin; Lum craft is 1 of each status + 3 BERRY). After a blend theres a cool-down of **640** farm steps (480 at soil rank 3). Grow a stockpile before you spam it or youll feel broke.

**Roof**

Ho-Oh later, once you have the Rainbow Wing. Level 50, sun weather. Dont open the fight until ready.

**Celadon Hotel**

**Snack Scout** hangs out in the hotel. Your **lead must be holding a berry** (party Give from the field menu). First win → **Focus Sash**. Rematches gift Cheri + Pecha + Rawst. Easy miss if you walk in with nothing held.

**After Erika (Rainbow Badge)**

Farm → Soil Expert → unlocks **Aspear** and **Chesto**, **3× each** once.

### Route 16 Fly House

1. Own about **60** species (Pokédex owned count).
2. Talk to the person in the **Fly House** on Route 16 (the house where you get HM02 Fly).
3. Receive **Rainbow Wing**.
4. Take it to Celadon Mansion roof when you want Ho-Oh.

### Lavender

1. Hidden **Spell Tag** on the path right beside the Pokémon Tower entrance. Item Finder helps. Theres also a channeler in town who hints at it.
2. Inside the Tower, on **7F**, theres a Poké Ball with **Blackglasses** if you didnt get them from Night Eyes.

## Mid–late (Fuchsia through Saffron)

### Fuchsia

1. Beat Koga (Soul Badge).
2. Farm → Soil Expert → unlocks **Persim** + **3× Persim**.
3. **Bills Grandpas house** in Fuchsia (same house as the usual "show me a mon" guy): trade **Bellsprout → Seedot** (nickname GLAND, holds **Soothe Bell**).

### Route 12 / 19

1. Go upstairs in the **Route 12 gate** (the gate between Lavender and the fishing pier / Silence Bridge area). Show a **Water-type Lv 30+** in the party → **Silver Wing** (Lugia later).
2. Hidden **Heart Scale** on the Route 12 beach / pier stretch. Item Finder helps.
3. Another on **Route 19** (the surfing route toward Seafoam / Fuchsia). Stock these for the Move Hub.

### Saffron

1. Hidden **Twistedspoon** on the central sidewalk south of the Silph Co. building. Item Finder helps.
2. Outside the **Fighting Dojo**, a Black Belt will gift you a **Black Belt** once (the held item).
3. The **Pidgey House** in Saffron is now the **Move Hub**:
   - Relearn: **1 Heart Scale** (level-up learnset + egg moves, PP filled)
   - Tutor: **2 Heart Scales** (punches, Body Slam, Rock Slide, Softboiled, Double-Edge, Substitute, etc.)
   - Delete: free (cannot delete the last move)
4. Beat Sabrina (Marsh Badge) → farm unlocks **Lum** + **3× Lum**. (Blaines Volcano Badge also unlocks Lum if you take a weird badge order. Earth Badge does **not** unlock a new farm berry.)

### Silph Co.

1. Liberate Silph as usual (beat Silph Giovanni, or otherwise have the Master Ball / that event flag).
2. Return to **Celadon Mansion 2F** and talk to the Beast Tracker.
3. Receive **Roaming Radar** (one-time). Raikou / Entei / Suicune start roaming grass routes.

**How the Radar hunt works**

1. Use Radar from the bag or the start menu **RADAR** entry.
2. It shows each beast’s route plus HERE / NEXT DOOR / FAR.
3. Enter a map theyre on → you hear a cry. DexNav can show a ROAM row on that map. After youve seen one, Pokédex can show a live AREA line while it still roams.
4. Walking between outdoor maps moves them to a neighboring route. Fly / Teleport / blackout fully reshuffles them. Fleeing a battle hops them next door.
5. Each wild encounter on their map has a flat **15%** chance to be replaced by that beast (not "15% of the encounter table"). Level is high (around 50 / soft-cap), so Repel does not block them.
6. Catch or KO ends that species’ roaming. Treat the hunt as optional unless you want them.

### Power Plant

1. While exploring, grab the Poké Ball **Metal Coat**. Save it for the Cinnabar blacksmith if you want Life Orb.
2. Later: Registeel seal is also in the plant. Needs Regi notes + **1 Steel-type** in the party.

## Late game (Cinnabar through Elite Four)

### Cinnabar Lab

**Fossil Room** (same room where you revive Dome / Helix)

1. Hand in Root Fossil (Mt Moon) or Claw Fossil (Seafoam entrance floor) to the gen3 scientist.
2. Leave Cinnabar Island entirely, then come back.
3. Pick up **Lileep** or **Anorith** at Lv 30. Vanilla Dome/Helix flow is unchanged for the gen1 fossils.

**Metronome Room** (the room with the Metronome trade guy) is now also the **blacksmith**

1. Metal Coat → **Life Orb** (once).
2. 3× Nugget → **Focus Sash** (once). If you already have a sash from Snack Scout, you get **2× Heart Scale** instead.
3. Leaf Stone → pack of **5 berries** (BERRY / Cheri / Pecha / Rawst / Aspear). Repeatable if you need planting stock.

**Main lab** (the big room with the usual scientists), **after Champion only**

1. Talk to the scientist who handles the orbs.
2. First talk → **Blue Orb**.
3. Talk again → **Red Orb**.
4. Blue Orb opens Kyogre. Red Orb opens Groudon.

### Seafoam / Mansion

1. **Seafoam 1F** (entrance floor): hidden **Claw Fossil**. Item Finder helps.
2. **B1F:** Lugia if you have the Silver Wing (Lv 50, rain). Also a hidden Heart Scale somewhere on this floor.
3. **B2F:** Regice seal. Notes + **1 Ice-type**.
4. **B3F:** Kyogre if you have the Blue Orb (Lv 60, rain).
5. **Pokémon Mansion B1F:** Groudon if you have the Red Orb (Lv 60, sun).

Beat Blaine if you still need Lum unlocked. Keep farming / blending if you want vitamins for the E4 stretch.

### Victory Road / Indigo

1. Beat the Champion.
2. In the **Indigo Plateau Lobby** (the Pokémon Center / lobby before the E4), talk to the eon watcher.
3. Latias / Latios start roaming. Same Radar / DexNav / cry rules as the beasts.

## Postgame (spoilers)

Do these in any order once youre Champion (some need keys from earlier). Remember: fleeing a static despawns it.

### Finish roamers

Use Radar until catch or KO. Optional.

### Ho-Oh / Lugia / weather duo

1. Rainbow Wing (Route 16 Fly House, 60 owned) → Celadon Mansion roof Ho-Oh.
2. Silver Wing (Route 12 gate upstairs, Water Lv30+) → Seafoam B1F Lugia.
3. Blue Orb → Seafoam B3F Kyogre.
4. Red Orb → Mansion B1F Groudon.

### Regis

1. Pewter Speech House scholar → Regi notes (fossil mon or Boulder Badge).
2. Rock Tunnel B1F: Regirock, **3 Rock-types** in party.
3. Seafoam B2F: Regice, **1 Ice-type**.
4. Power Plant: Registeel, **1 Steel-type**.

### Rayquaza

1. Beat **both** Kyogre and Groudon (catch or KO flags).
2. On **Route 23** (the badge-check road up to Victory Road / Indigo), talk to the hiker gatekeeper. He sends you to Sky Pillar.
3. Rayquaza is waiting inside, Lv 70.

### Celebi

1. Must be Champion.
2. In **Viridian Forest**, talk to the channeler gatekeeper. She sends you to the Ilex Shrine.
3. Celebi is waiting inside, Lv 30.

### Deoxys

1. Own **3** legendaries from this list: Raikou, Entei, Suicune, Lugia, Ho-Oh, Kyogre, Groudon, Articuno, Zapdos, Moltres, Mewtwo.
2. Go to the **Vermilion Dock** (where the S.S. Anne used to be) and talk to the sailor.
3. He gives the **DNA Key** and sends you to Birth Island.
4. Deoxys is waiting there, Lv 70.

### Jirachi

1. Must be Champion.
2. Return to **Mt Moon B1F**.
3. Offering starts the fight and **consumes 5 Heart Scales**. Have them ready. Lv 30.

Legendary overworld sprites look like gen1 birds / monsters / fairies on purpose. Reused sheets so they fit the world.

## If you just want a sane first run

1. Farm early. After every gym, talk to the Soil Expert, plant the new berries, keep walking.
2. Decide level caps in Viridian before you overlevel.
3. Grab Leftovers (north of Celadon Mansion) and Focus Band (Rock Tunnel B1F) when youre nearby.
4. Fight Celadon Circuit once for Choice Band when your team can handle rematch scaling.
5. Do Snack Scout with a berry held for Focus Sash (or buy one later with Nuggets at the smith).
6. After Silph, turn Radar on and hunt roamers if you feel like it.
7. Save Metal Coat for Life Orb. Stock Heart Scales before Move Hub spam.
8. Postgame: orbs → weather duo → Sky Pillar → Regis / mythicals when youre bored.

## Where is that again

| What | Where |
|---|---|
| Level-cap candies | Viridian, east of the Poké Mart on the path |
| Berry Farm | Extra carpet on the right side of any Pokémon Center |
| Judge | Underground Path from the Route 5 entrance |
| Day Care (2-slot) | Route 5 Day Care house |
| Night Eyes | Vermilion Pidgey House |
| Circuit + Beast Tracker | Celadon Mansion 2F |
| Blender | Celadon Mansion 3F |
| Ho-Oh | Celadon Mansion roof |
| Snack Scout | Celadon Hotel |
| Rainbow Wing | Route 16 Fly House (60 owned) |
| Silver Wing | Route 12 gate upstairs (Water Lv30+) |
| Move Hub | Saffron Pidgey House |
| Blacksmith | Cinnabar Lab Metronome Room |
| Gen 3 fossils | Cinnabar Lab Fossil Room |
| Orbs | Cinnabar Lab main room, post-Champ |
| Roaming Radar | Beast Tracker after Silph |
| Eon duo start | Indigo Plateau Lobby, after Champ |
| DNA Key / Deoxys | Sailor at Vermilion Dock |
| Rayquaza gate | Hiker on Route 23 |
| Celebi gate | Channeler in Viridian Forest |
| Jirachi | Mt Moon B1F |

## More reading

- [README.md](README.md): overview, options, install
- [FEATURES.md](FEATURES.md): full reference (numbers, recipes, flags)
