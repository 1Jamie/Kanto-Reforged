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
| `cavern_cave` | Gen1 `CAVERN` | Gold `TILESET_CAVE` | `cave_g1_to_g2.py` | `CAVERN` |

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

[`../restore_kanto_dungeons.py`](../restore_kanto_dungeons.py) loads `*_g1_to_g2.py` exports. Caves stay `keep_gen1` until ids are added to `CAVE_REMAP_MAPS`.

### Custom graphics missing from Gold sheets

Gold `TILESET_CAVE` has no wooden-sign tiles; `TILESET_KANTO` has stairs but no Gen1 forest/cave-style signs. Overrides mirror the Safari wooden-stairs pattern:

| Override | Patched tiles | Source | Custom blocks |
|----------|---------------|--------|---------------|
| `overrides/tilesets/cave.png` | 90–93 | Gen1 `CAVERN` 14/15/30/31 | `#120` floor+sign, `#121` water+sign |
| `overrides/tilesets/kanto.png` | 77–84 stairs; **96–99** sign (extra row, 128×56) | Gen1 `FOREST` 33/34/49/50 | `#158`/`#159` stairs, `#160` outdoor sign |

Reference crops: `tools/exact_stair_16x16.png`, `tools/exact_sign_16x16.png`, `tools/exact_outdoor_sign_16x16.png`.

Mapper profiles auto-detect Gen1 sign blocks (`42`/`117` cavern; `21`/`22`/`33`/`51` forest) via `gen1_feature_blocks` and expose them on the special bar + F-key favorites.

## Sevii later

Add a profile with appropriate `preview_tilesets` and block sizes. Keep semantic Sevii under `sevii/` separate from this HITL GUI.
