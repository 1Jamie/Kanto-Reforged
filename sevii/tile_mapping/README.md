# Gen1 ↔ FRLG mapping — semantic layout extraction

## What we are doing (and not doing)

**Do:** Read FRLG `map.bin` + metatile **behavior** bytes → classify cells into
categories → look up a Gen1 OVERWORLD block per category → first-pass Sevii layouts.

**Don't:** Convert FRLG tile graphics / metatile IDs into Gen1 tile IDs.
Gen1 blocks are 32×32; FRLG metatiles are 16×16. Buildings especially cannot
1:1 — Gen1 HOUSE is a fixed **3×2** stamp; FRLG island houses are multi-metatile.

## Scripts (from `sevii/`)

| Script | Role |
|--------|------|
| [`../sevii_semantic_remap.py`](../sevii_semantic_remap.py) | **Primary** — behavior → category → Gen1 block remap |
| [`../sevii_tile_mapper.py`](../sevii_tile_mapper.py) | Optional atlas dumps for eyeballing Gen1 block IDs |

```bash
cd mods/Kanto-Reforged/sevii
python3 sevii_semantic_remap.py
# outputs → tile_mapping/semantic/
```

## Lookup (vanilla-proven Gen1 blocks)

See [`semantic/semantic_lookup.md`](semantic/semantic_lookup.md).

**Terrain** goes in the block grid. **Structural** (`BUILDING` / `DOOR` / `SIGN` / `CAVE`)
does **not** — those are a separate `(x, y, category)` list so Ruin Valley rock
never gets confused with a building placeholder. Under markers: PATH or GRASS fill.

| Category | Gen1 | Why |
|----------|------|-----|
| WATER | 67 / 107 / 24 | Route 21 / Cinnabar |
| SHORT_GRASS | 1 | Pewter plaza |
| TALL_GRASS | 11 | routes |
| SAND | 10 | desert |
| CLIFF | 44 | Pewter / Route 4 mountain |
| COAST_CLIFF | 100 | Cinnabar west cliff |
| STAIR | 47 | outdoor stairs |
| LEDGE | 55 / 39 / 13 / 26 | by FRLG `MB_JUMP_{S,W,E,N}` dir |
| ROCK_DECK | 123 | walkable Cinnabar deck only |
| TREE | 15 | Viridian tree border |
| PC / MART / HOUSE | stamps from `structural` + warps | 2×2 / 2×2 / 3×2 |

## First-pass Island 1 results

After `sevii_semantic_remap.py`:

- **One Island** `12×10`: PC plateau → `FACE`+`STAIR` drop → houses → `FACE`+`STAIR` → pier/ocean; **0** tall grass; water south/east
- **Treasure Beach**: long surf channel → sand → south cliffs
- **Kindle**: mostly water + cliff spines; tall only where `MB_TALL_GRASS`

Inspect:

- `semantic/SEVII_ONE_ISLAND_gen1.txt` + `.png`
- `semantic/semantic_report.json` (category histograms)

## Next

1. Eyeball the PNGs / ASCII against FRLG screenshots.
2. If a category pick is wrong, change `CATEGORY_TO_GEN1` in `sevii_semantic_remap.py` (one table — not per-map).
3. When satisfied with in-game look, iterate `CATEGORY_TO_GEN1` / stamps.
   Live install (default):

```bash
cd mods/Kanto-Reforged/sevii
python3 sevii_semantic_remap.py          # writes sevii/layout_data.lua
python3 sevii_semantic_remap.py --no-install   # analysis only
```

Full-restart Love after install; ferry Vermilion → One Island.

**Note:** Sevii content is currently **disabled** in `main.lua` (`SEVII_ENABLED = false`).
