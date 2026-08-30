# Block mapper profiles

Python modules that configure the Gen1→Gen2 HITL block mapper.

The GUI is an in-app shell (**Setup → Mapper ↔ Map Preview**):

```bash
cd mods/Kanto-Reforged/tools
./run_block_mapper.sh --profile cavern_cave
# or
python3 block_mapper_gui.py --profile safari_kanto
```

| Mode | Purpose |
|------|---------|
| **Setup** | Pick profile / sheets / options, then **Process / Run** (CV prep on a background thread) |
| **Mapper** | HITL block/quad mapping, Export (+ optional restore checkbox) |
| **Map Preview** | Full Gen1\|Gen2 dual pane; pick any map for the profile’s tileset |

Package layout: `tools/block_mapper/{shell,session,cv,views/…}`. Entry: [`../block_mapper_gui.py`](../block_mapper_gui.py).

## Profiles

| Id | Source | Target | Export | Preview tilesets |
|----|--------|--------|--------|------------------|
| `safari_kanto` | Gen1 Safari / FOREST | `TILESET_KANTO` | `safari_g1_to_g2.py` | `FOREST` |
| `forest_kanto` | Gen1 forest sheet | `TILESET_KANTO` | `forest_g1_to_g2.py` | `FOREST` |
| `cavern_cave` | Gen1 `CAVERN` | Gold `TILESET_CAVE` | `cave_g1_to_g2.py` | `CAVERN`, `REGIROCK_CHAMBER`, `ROCK_TUNNEL_B1F` |
| `legend_mythical_overworld` | Gen1 `OVERWORLD` | Gold `TILESET_KANTO` | `legend_mythical_g1_to_g2.py` | `SKY_PILLAR_KANT`, `ILEX_SHRINE_KANT`, `BIRTH_ISLAND_KANT` |

### Gen1 vs Gen2 runtime

- **Gen1 play** (`legend_regis.register` / `legend_mythicals.register`): unchanged native tilesets — `CAVERN` and `OVERWORLD` with original block IDs.
- **Regirock chamber** reuses the same `cave_g1_to_g2.py` cast as restored dungeons (floor `#1`→162, wall `#3`→163, ladder `#62`→222). Map preview includes `REGIROCK_CHAMBER`. The only extra block is synthetic **#128** (Rock Tunnel ladder niche metatile).
- **Block mapper**: left pane = Gen1 source art; export = Gen1 block id → Gen2 block id only.
- **Gen2 apply** (`legend_maps_apply.lua`): reads `world/legend_maps_data.lua` from `apply_legend_mappings.py`. Returns `false` on Gen1.

```bash
./run_block_mapper.sh --profile cavern_cave          # map block #128 ladder niche if not done
./run_block_mapper.sh --profile legend_mythical_overworld
python3 tools/apply_legend_mappings.py
```

## Profile schema (`PROFILE` dict)

Each module exports `PROFILE` via `common.base_profile(...)`, plus optional `synthesize(g1_raw, g2_raw)`.

- `g1_sheet` / `g2_sheet`, `g1_card_sheet` / `g2_card_sheet`
- `g1_block_size` / `g2_block_size`, `g1_tile_size` / `g2_tile_size` (Sevii-ready; no hardcoded 16 in paint loops)
- `g1_tileset_id` / `g2_tileset_id` — rebuild from Red/Gold when sheets missing
- `preview_tilesets` — Gen1 tileset ids for the Map Preview picker (fallback: `[g1_tileset_id]`)
- `test_map_id` — default preview map from host `maps.lua`
- `dict_name` / `custom_blocks_name` / `out`
- favorites / presets / `synthesize`

## UX notes

- **Threading:** Process/Run disables the button, runs `prepare_mapping_session` in a daemon thread, and always `queue.put({ok, …})` (including failures) so the UI never spins forever.
- **Dirty:** unsaved edits set `is_dirty` and append `*` to the window title; leaving for Setup / re-Run prompts export yes/no/cancel.
- **Views:** Setup / Mapper / Preview frames are created once; mode switches use `pack_forget` / `pack`.
- **Preview rendering:** one full-map PIL composite per pane (not one canvas item per block).
- **Export:** Mapper checkbox **Run restore after export** (default off). Mid-session export saves progress; check the box on the final pass.
- **Maps:** `list_maps_for_tilesets` / `load_map_by_id` use canonical `maps.lua` `width`×`height`×`blocks` (`len == w*h`).

## Sheet dumps

Block atlases under `tools/blocksets/` (gitignored). Cave profile rebuilds from Red `CAVERN` / Gold `TILESET_CAVE` when PNGs are absent.

## Restore integration

[`../restore_kanto_dungeons.py`](../restore_kanto_dungeons.py) loads `*_g1_to_g2.py` exports. Caves use Gold `TILESET_CAVE`. Gen1 tilesets still shipped for unmigrated interiors: `POKECENTER` (Rock Tunnel PC), `GYM` (Blaine). `CAVERN` is not distributed.

### Custom graphics missing from Gold sheets

Gold `TILESET_CAVE` has no wooden-sign tiles; `TILESET_KANTO` has stairs but no Gen1 forest/cave-style signs. Ship **16×16 metatile quads** (or optional 16×8 row halves for stairs); restore pastes them onto VRAM tiles from stock Gold PNGs.

| Sources (`overrides/tileset_quads/`) | VRAM tiles | Custom blocks |
|--------------------------------------|------------|---------------|
| `cave_wooden_sign.png` (16×16) | 90–93 | `#120` / `#121` cave signs |
| `wood_stair.png` (16×16; two 16×8 step rows) | 77, 78, 83, 84 | `#158` / `#159` stairs |
| `forest_wooden_sign.png` (16×16) | 96–99 | `#160` outdoor sign |

`tools/tileset_quad_patches.py` splits each 16×16 quad into four 8×8 VRAM tiles (TL, TR, BL, BR) and writes gitignored `overrides/tilesets/{cave,kanto}.png`.

Refresh sign quads from Red ROM art (skips existing hand-made PNGs): `python3 tools/tileset_quad_patches.py extract`

`wood_stair.png` is hand-authored; `extract` will not overwrite it.

Mapper profiles auto-detect Gen1 sign blocks (`42`/`117` cavern; `21`/`22`/`33`/`51` forest) via `gen1_feature_blocks` and expose them on the special bar + F-key favorites.

## Sevii later

Add a profile with appropriate `preview_tilesets` and block sizes. Keep semantic Sevii under `sevii/` separate from this HITL GUI.
