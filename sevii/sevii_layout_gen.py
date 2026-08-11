#!/usr/bin/env python3
"""Sevii → Gen 1 layout pipeline.

Derived from pret/pokefirered map.bin + map.json. No FRLG art.

Architecture
------------
1. **FRLG semantics** — classify cells via metatile attrs (u32, primary=640).
2. **Region adapt** — border-connected OCEAN; fill inland moats; tag COAST.
3. **Role map + tiers** — explicit FRLG→role→Gen1 table; town terraces from
   STAIR bands (Pewter/Route 4 mountain kit + Cinnabar coast).
4. **Constraints** — stamp buildings; ocean/tier-preserving downsample;
   connection offsets + seam role checks.

Attrs must be read as u32 with NUM_METATILES_IN_PRIMARY=640.

Usage:
  python3 sevii_layout_gen.py [--layouts-dir DIR] [--outdir sevii]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import struct
import urllib.request
from collections import Counter, deque
from typing import Any, Optional

# ── Gen 1 OVERWORLD vocabulary ───────────────────────────────────────────────
# Outdoor elevation = OVERWORLD mountain kit (Pewter / Route 4). Same *role*
# as Mt. Moon CAVERN platforms (deck / face / stairs), different block IDs.
GRASS = 1
TALL = 11
DIRT = 10
COBBLE = 85
WATER = 67
WATER_S = 107
WATER_W = 24
SHORE = 31
CLIFF_W = 100       # water-facing cliff ONLY (pair with WATER_W)
ROCK = 123          # walkable plateau deck
LEDGE = 26
CORNER_SW = 45
CORNER_SE = 30
TREE = 15           # sparse pines only
MTN = 44            # solid cliff mass  (≈ cavern wall)
FACE = 41           # cliff face
RIDGE = 63          # platform top rim (≈ cavern 32–34)
RIDGE_E = 59
STAIR = 47          # walkable break in ledge
PATH = 7

PC = (32, 33, 124, 114)
MART = (32, 33, 124, 115)
HOUSE = (12, 13, 14, 16, 58, 0)
CLIFF = CLIFF_W

# FRLG metatile attrs are u32; primary tileset has 640 metatiles (not 512).
NUM_METATILES_IN_PRIMARY = 640
WATER_BEH = {0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x1A, 0x1B}
JUMP_BEH = {0x38, 0x39, 0x3A, 0x3B}
DOOR_BEH = {0x60, 0x65, 0x67, 0x69}  # includes MB_SOUTH_ARROW_WARP (harbor)
STAIR_BEH = {0x2A}  # MB_ROCK_STAIRS — tier connections on One Island
CLIFF_MIDS = {
    0x071, 0x070, 0x072, 0x073, 0x075, 0x07A, 0x07B, 0x07C, 0x07D,
    0x0B2, 0x0B3, 0x0B4, 0x0B5,
}

GITHUB = "https://raw.githubusercontent.com/pret/pokefirered/master"

ISLAND1 = {
    "SEVII_ONE_ISLAND": {
        "layout": "OneIsland",
        "map_json": "OneIsland",
        "cells": (24, 20),
        "kind": "town",
        "v_compress": 1,
        "warps_of_interest": {
            "POKEMON_CENTER": "pc",
            "HOUSE1": "house",
            "HOUSE2": "house",
            "HARBOR": "harbor",
        },
        "add_mart": True,
    },
    "SEVII_ONE_ISLAND_KINDLE_ROAD": {
        "layout": "OneIsland_KindleRoad",
        "map_json": "OneIsland_KindleRoad",
        "cells": (24, 140),
        "kind": "route",
        "v_compress": 2,
        "path_x": (10, 13),
        "coastal": True,
    },
    "SEVII_ONE_ISLAND_TREASURE_BEACH": {
        "layout": "OneIsland_TreasureBeach",
        "map_json": "OneIsland_TreasureBeach",
        "cells": (24, 40),
        "kind": "route",
        "v_compress": 1,
        "path_x": (10, 13),
        "beach": True,
    },
}

WALKABLE = {GRASS, TALL, DIRT, COBBLE, ROCK, SHORE, PATH, STAIR}
OCEANISH = {WATER, WATER_S, WATER_W}
BLOCKED = {
    CLIFF_W, LEDGE, CORNER_SW, CORNER_SE, TREE,
    MTN, FACE, RIDGE, RIDGE_E, 40, 42, 43, 36, 37, 87,
}

# FRLG signal → semantic role → Gen1 OVERWORLD block (vanilla refs in comments).
# Used by layer3 / build_tiers; dumped into layout_report.json as role_vocab.
ROLE_VOCAB: dict[str, dict[str, Any]] = {
    "OCEAN":     {"block": WATER,   "ref": "Cinnabar", "frlg": "MB_OCEAN_WATER 0x15"},
    "OCEAN_S":   {"block": WATER_S, "ref": "Cinnabar south edge", "frlg": "ocean bottom row"},
    "WATER_W":   {"block": WATER_W, "ref": "Cinnabar west", "frlg": "west of CLIFF_W"},
    "CLIFF_MASS":{"block": MTN,     "ref": "Pewter west", "frlg": "cliff mid / solid hinterland"},
    "FACE":      {"block": FACE,    "ref": "Route 4", "frlg": "cliff abutting deck"},
    "DECK":      {"block": ROCK,    "ref": "Cinnabar deck", "frlg": "walkable terrace floor"},
    "PLAZA":     {"block": GRASS,   "ref": "Pewter plaza", "frlg": "mid-tier ground"},
    "RIDGE":     {"block": RIDGE,   "ref": "Pewter rim", "frlg": "deck south rim"},
    "RIDGE_E":   {"block": RIDGE_E, "ref": "Pewter rim end", "frlg": "east end of ridge"},
    "STAIR":     {"block": STAIR,   "ref": "Pewter/Route 4", "frlg": "MB_ROCK_STAIRS 0x2A"},
    "LEDGE":     {"block": LEDGE,   "ref": "Pewter", "frlg": "MB_JUMP_* / tier drop"},
    "SAND":      {"block": DIRT,    "ref": "beach", "frlg": "MB_SAND 0x21"},
    "TALL":      {"block": TALL,    "ref": "routes", "frlg": "MB_TALL_GRASS 0x02"},
    "CLIFF_W":   {"block": CLIFF_W, "ref": "Cinnabar", "frlg": "coast cliff | ocean"},
    "SHORE":     {"block": SHORE,   "ref": "Cinnabar", "frlg": "land north of ocean"},
    "PIER":      {"block": PATH,    "ref": "path", "frlg": "harbor tongue"},
    "BUILDING":  {"block": ROCK,    "ref": "stamp later", "frlg": "secondary solid"},
}

WALK_REGIONS = {"GROUND", "DOOR", "BUILDING", "SAND", "TALL", "STAIR", "LEDGE", "LAND_ROCK"}
BARRIER_REGIONS = {"OCEAN", "CLIFF", "COAST"}


def fetch(url: str, dest: str) -> None:
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    if os.path.isfile(dest) and os.path.getsize(dest) > 0:
        return
    print(f"  fetch {url}")
    urllib.request.urlretrieve(url, dest)


def load_attrs(path: str) -> list[int]:
    """Load FRLG metatile_attributes.bin (u32 per metatile)."""
    data = open(path, "rb").read()
    return [struct.unpack_from("<I", data, i * 4)[0] for i in range(len(data) // 4)]


def load_map_cells(path: str, w: int, h: int) -> list[tuple[int, int]]:
    data = open(path, "rb").read()
    assert len(data) == w * h * 2, (path, len(data), w * h * 2)
    return [
        ((struct.unpack_from("<H", data, i * 2)[0] & 0x3FF),
         (struct.unpack_from("<H", data, i * 2)[0] >> 10) & 3)
        for i in range(w * h)
    ]


def behavior(mid: int, gen: list[int], sev: list[int]) -> int:
    """Extract MB_* behavior (bits 0-8) from a metatile attribute word."""
    if mid < NUM_METATILES_IN_PRIMARY:
        return gen[mid] & 0x1FF if mid < len(gen) else 0
    idx = mid - NUM_METATILES_IN_PRIMARY
    return sev[idx] & 0x1FF if idx < len(sev) else 0


def layer1_classify(
    cells: list[tuple[int, int]], w: int, h: int,
    gen: list[int], sev: list[int], *, kind: str,
) -> list[str]:
    out: list[str] = []
    for mid, coll in cells:
        b = behavior(mid, gen, sev)
        if b in WATER_BEH:
            out.append("WATER")
        elif b in DOOR_BEH:
            out.append("DOOR")
        elif b == 0x02:
            out.append("TALL")
        elif b == 0x21:
            out.append("SAND")
        elif b in JUMP_BEH:
            out.append("LEDGE")
        elif b in STAIR_BEH:
            out.append("STAIR")
        elif mid >= NUM_METATILES_IN_PRIMARY and coll != 0 and b == 0:
            # Secondary solid tiles: building roofs, pier posts, etc.
            out.append("BUILDING")
        elif mid in CLIFF_MIDS or (coll != 0 and mid < 0x100):
            out.append("CLIFF")
        elif coll != 0:
            out.append("ROCK")
        else:
            out.append("GROUND")
    return out


def flood(labels: list[str], w: int, h: int, seeds: list[int], want: set[str]) -> set[int]:
    seen: set[int] = set()
    q = deque(seeds)
    while q:
        i = q.popleft()
        if i in seen:
            continue
        seen.add(i)
        x, y = i % w, i // w
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                j = ny * w + nx
                if j not in seen and labels[j] in want:
                    q.append(j)
    return seen


def layer2_regions(labels: list[str], w: int, h: int, *, kind: str, report: dict) -> list[str]:
    """Border-connected OCEAN from real FRLG water; fill inland moats only."""
    adapted = list(labels)
    border_water = []
    for x in range(w):
        for y in (0, h - 1):
            i = y * w + x
            if adapted[i] == "WATER":
                border_water.append(i)
    for y in range(h):
        for x in (0, w - 1):
            i = y * w + x
            if adapted[i] == "WATER":
                border_water.append(i)

    ocean = flood(adapted, w, h, border_water, {"WATER"})
    report["ocean_cells"] = len(ocean)
    report["moat_filled"] = 0

    for i, lab in enumerate(adapted):
        if lab == "WATER" and i not in ocean:
            # Decorative inland pools (rare once attrs are correct)
            adapted[i] = "GROUND"
            report["moat_filled"] += 1
        elif lab == "WATER":
            adapted[i] = "OCEAN"

    for i, lab in enumerate(adapted):
        if lab != "CLIFF":
            continue
        x, y = i % w, i // w
        touches_ocean = any(
            0 <= x + dx < w and 0 <= y + dy < h
            and adapted[(y + dy) * w + (x + dx)] == "OCEAN"
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
        )
        adapted[i] = "COAST" if touches_ocean else "CLIFF"
    for i, lab in enumerate(adapted):
        if lab == "ROCK":
            adapted[i] = "LAND_ROCK"

    report["regions"] = dict(Counter(adapted))
    return adapted



def _bbox(indices: list[int], w: int) -> Optional[tuple[int, int, int, int]]:
    if not indices:
        return None
    xs = [i % w for i in indices]
    ys = [i // w for i in indices]
    return min(xs), min(ys), max(xs), max(ys)


def build_tiers(regions: list[str], w: int, h: int) -> dict[str, Any]:
    """Partition town into stair-linked terraces (FRLG One Island A/B/C).

    Stair bands (MB_ROCK_STAIRS rows) are the tier drops. Walkable cells above
    the first band → tier 0 (PC plateau); between bands → mid tiers; below the
    last band → pier tier.
    """
    stair_cells = [i for i, lab in enumerate(regions) if lab == "STAIR"]
    stair_ys = sorted({i // w for i in stair_cells})
    # Merge adjacent stair rows into bands
    bands: list[tuple[int, int]] = []
    for y in stair_ys:
        if bands and y <= bands[-1][1] + 1:
            bands[-1] = (bands[-1][0], y)
        else:
            bands.append((y, y))

    # Tier id per cell (-1 = non-deck)
    tier_of = [-1] * (w * h)
    boundaries = [b[0] for b in bands]  # top row of each stair band

    def tier_for_y(y: int) -> int:
        t = 0
        for by in boundaries:
            if y > by:
                t += 1
            else:
                break
        return t

    deck_cells: dict[int, list[int]] = {}
    for i, lab in enumerate(regions):
        if lab not in WALK_REGIONS and lab not in ("DOOR",):
            continue
        if lab == "OCEAN":
            continue
        y = i // w
        # Pier BUILDING/DOOR below last stair still belongs on lowest tier
        t = tier_for_y(y)
        tier_of[i] = t
        deck_cells.setdefault(t, []).append(i)

    # Stairs belong to the lower tier (they drop onto it)
    for i in stair_cells:
        y = i // w
        t = tier_for_y(y)
        tier_of[i] = t
        if i not in deck_cells.get(t, []):
            deck_cells.setdefault(t, []).append(i)

    tiers_out = []
    for t in sorted(deck_cells):
        bb = _bbox(deck_cells[t], w)
        # Stair band that drops *onto* this tier (band index t-1), if any
        band = bands[t - 1] if 0 < t <= len(bands) else None
        tiers_out.append({
            "id": t,
            "bbox": list(bb) if bb else None,
            "cells": len(deck_cells[t]),
            "stair_band": list(band) if band else None,
        })

    return {
        "bands": bands,
        "tier_of": tier_of,
        "deck_cells": deck_cells,
        "tiers": tiers_out,
        "stair_cells": len(stair_cells),
        "n_tiers": len(deck_cells),
    }


def paint_town_tiers(
    regions: list[str], blocks: list[int], w: int, h: int, tier_info: dict[str, Any],
) -> dict[str, Any]:
    """Paint true Gen1 elevation: Pewter FACE+LEDGE/STAIR drops between FRLG tiers.

    Tier A (PC plateau): ROCK deck, south rim = LEDGE with STAIR breaks.
    Tier B (mid plaza): GRASS, houses; east STAIR to sand; south LEDGE+STAIR to pier.
    Tier C (pier): PATH tongue into OCEAN.
    West/north: MTN/FACE + sparse TREE (FRLG tree line).
    """
    tier_of: list[int] = tier_info["tier_of"]
    deck_cells: dict[int, list[int]] = tier_info["deck_cells"]
    bands: list[tuple[int, int]] = tier_info["bands"]
    info = {
        "n_tiers": tier_info["n_tiers"],
        "bands": bands,
        "tiers": tier_info["tiers"],
        "stair_cells": tier_info["stair_cells"],
        "role_counts": {},
        "method": "pewter_tier_drops",
    }

    # --- 1. Base fill from regions (no tall grass in town) ---
    for i, lab in enumerate(regions):
        y = i // w
        if lab == "OCEAN":
            blocks[i] = WATER_S if y >= h - 1 else WATER
        elif lab == "COAST":
            blocks[i] = CLIFF_W
        elif lab == "CLIFF":
            blocks[i] = MTN
        elif lab == "STAIR":
            blocks[i] = STAIR
        elif lab == "LEDGE":
            blocks[i] = LEDGE
        elif lab == "SAND":
            blocks[i] = DIRT
        elif lab == "TALL":
            blocks[i] = GRASS  # town: never wild grass
        elif lab in ("BUILDING", "DOOR", "LAND_ROCK"):
            blocks[i] = ROCK
        else:
            blocks[i] = GRASS

    # --- 2. West cliff wall (Pewter): MTN | FACE | FACE ---
    for y in range(h):
        for x in range(min(4, w)):
            if regions[y * w + x] not in ("CLIFF", "COAST", "LAND_ROCK"):
                continue
            if x == 0:
                blocks[y * w + x] = MTN
            else:
                blocks[y * w + x] = FACE

    # --- 3. North ridge ---
    for x in range(w):
        if regions[x] in ("CLIFF", "COAST"):
            blocks[x] = RIDGE_E if x >= w - 4 else RIDGE

    # --- 4. Deck fills by tier ---
    top_t = min(deck_cells) if deck_cells else 0
    # Lowest land tier id that still has walkable (pier tongue may be mixed)
    land_tiers = sorted(deck_cells)
    for t, indices in deck_cells.items():
        for i in indices:
            lab = regions[i]
            if lab == "STAIR":
                blocks[i] = STAIR
                continue
            if lab == "SAND":
                blocks[i] = DIRT
                continue
            if t == top_t:
                blocks[i] = ROCK  # PC plateau
            elif lab in ("BUILDING", "DOOR"):
                blocks[i] = ROCK
            else:
                blocks[i] = GRASS  # mid plaza

    # --- 5. Pewter-style drop at each stair band: LEDGE row + STAIR gaps + FACE ---
    for band_i, (y0, y1) in enumerate(bands):
        for y in range(y0, y1 + 1):
            for x in range(w):
                i = y * w + x
                lab = regions[i]
                if lab == "OCEAN":
                    continue
                if lab == "STAIR":
                    blocks[i] = STAIR
                    continue
                # Cliff on the drop row → FACE (vertical wall of upper tier)
                if lab in ("CLIFF", "COAST"):
                    blocks[i] = FACE
                    continue
                # Walkable on drop row → LEDGE (jump) except stair cells
                if lab in WALK_REGIONS or lab in ("GROUND", "BUILDING", "DOOR", "SAND"):
                    # Keep pier path clear on last band if building tongue
                    if band_i == len(bands) - 1 and lab in ("BUILDING", "DOOR"):
                        blocks[i] = PATH
                    else:
                        blocks[i] = LEDGE
        # FACE on cliff immediately ABOVE the band (upper tier south wall)
        if y0 > 0:
            for x in range(w):
                ai = (y0 - 1) * w + x
                if regions[ai] in ("CLIFF", "COAST") and blocks[ai] not in OCEANISH:
                    blocks[ai] = FACE
                # Upper deck south rim: if walkable and not building, LEDGE toward stairs
                if regions[ai] in ("GROUND", "SAND", "BUILDING", "DOOR", "LAND_ROCK"):
                    # only if a stair/ledge is below
                    if regions[y0 * w + x] in ("STAIR", "CLIFF", "COAST", "GROUND", "LEDGE"):
                        if regions[ai] not in ("BUILDING", "DOOR") and blocks[ai] != STAIR:
                            # leave ROCK on PC deck interior; rim becomes ledge only at drop cols
                            if any(
                                regions[y0 * w + xx] == "STAIR"
                                for xx in range(max(0, x - 2), min(w, x + 3))
                            ):
                                pass  # keep deck open above stairs
                            elif tier_of[ai] == top_t and regions[ai] == "GROUND":
                                blocks[ai] = LEDGE

    # Re-assert every FRLG stair cell
    for i, lab in enumerate(regions):
        if lab == "STAIR":
            blocks[i] = STAIR

    # --- 6. Sparse pines against west cliff (FRLG tree line, not forest) ---
    for y in range(2, h - 4):
        for x in (2, 3):
            if regions[y * w + x] == "GROUND" and blocks[y * w + x] == GRASS:
                if (x + y) % 3 == 0:
                    blocks[y * w + x] = TREE

    # --- 7. Pier tongue: PATH from harbor buildings through ocean ---
    pier = [
        (i % w, i // w) for i, lab in enumerate(regions)
        if lab in ("BUILDING", "DOOR") and (i // w) >= h - 5
    ]
    if pier:
        xs = [p[0] for p in pier]
        py = min(p[1] for p in pier)
        mid = (min(xs) + max(xs)) // 2
        for y in range(min(py, h - 3), h):
            for x in range(max(0, mid - 2), min(w, mid + 3)):
                if abs(x - mid) <= 2:
                    blocks[y * w + x] = PATH

    # --- 8. Shoreline / corners ---
    for i, lab in enumerate(regions):
        if lab != "OCEAN":
            continue
        x, y = i % w, i // w
        blocks[i] = WATER_S if y >= h - 1 else WATER
        if y > 0 and regions[(y - 1) * w + x] in WALK_REGIONS:
            ni = (y - 1) * w + x
            if blocks[ni] not in (MTN, FACE, RIDGE, RIDGE_E, PATH, STAIR, LEDGE, CLIFF_W, TREE):
                blocks[ni] = SHORE
    for y in range(h):
        for x in range(w):
            if blocks[y * w + x] not in (SHORE, GRASS, ROCK, PATH, DIRT):
                continue
            if y + 1 < h and blocks[(y + 1) * w + x] in OCEANISH:
                if x == 0:
                    blocks[y * w + x] = CORNER_SW
                elif x == w - 1:
                    blocks[y * w + x] = CORNER_SE

    info["role_counts"] = dict(Counter(
        "OCEAN" if b in OCEANISH else
        "STAIR" if b == STAIR else
        "LEDGE" if b == LEDGE else
        "FACE" if b == FACE else
        "MTN" if b == MTN else
        "DECK" if b == ROCK else
        "PIER" if b == PATH else
        "TREE" if b == TREE else
        "other"
        for b in blocks
    ))
    return info



def apply_town_platforms(regions: list[str], blocks: list[int], w: int, h: int) -> dict[str, Any]:
    """Tier-aware Gen1 paint (replaces single-PC-deck heuristic)."""
    tier_info = build_tiers(regions, w, h)
    return paint_town_tiers(regions, blocks, w, h, tier_info)



def layer3_vocabulary(regions: list[str], w: int, h: int, *, kind: str) -> tuple[list[int], dict]:
    """Map region labels through ROLE_VOCAB; towns get tier platforms."""
    blocks = [GRASS] * (w * h)
    for i, lab in enumerate(regions):
        if lab == "OCEAN":
            blocks[i] = ROLE_VOCAB["OCEAN"]["block"]
        elif lab == "TALL":
            blocks[i] = ROLE_VOCAB["TALL"]["block"]
        elif lab == "SAND":
            blocks[i] = ROLE_VOCAB["SAND"]["block"]
        elif lab == "STAIR":
            blocks[i] = ROLE_VOCAB["STAIR"]["block"]
        elif lab == "LEDGE":
            blocks[i] = ROLE_VOCAB["LEDGE"]["block"]
        elif lab == "COAST":
            blocks[i] = ROLE_VOCAB["CLIFF_W"]["block"] if kind == "route" else ROLE_VOCAB["FACE"]["block"]
        elif lab == "CLIFF":
            blocks[i] = ROLE_VOCAB["CLIFF_MASS"]["block"]
        elif lab in ("LAND_ROCK", "ROCK"):
            blocks[i] = ROLE_VOCAB["DECK"]["block"]
        elif lab in ("BUILDING", "DOOR"):
            blocks[i] = ROLE_VOCAB["BUILDING"]["block"]
        else:
            blocks[i] = ROLE_VOCAB["PLAZA"]["block"]

    plat_info: dict[str, Any] = {}
    if kind == "town":
        plat_info = apply_town_platforms(regions, blocks, w, h)
    elif kind == "route":
        plat_info = paint_route_roles(regions, blocks, w, h)
    return blocks, plat_info


def paint_route_roles(regions: list[str], blocks: list[int], w: int, h: int) -> dict[str, Any]:
    """Coastal routes: preserve ocean/sand/tall; cliff faces + ledges at drops."""
    info: dict[str, Any] = {"ledge_rows": [], "coast_cells": 0}
    for i, lab in enumerate(regions):
        if lab == "OCEAN":
            y = i // w
            blocks[i] = WATER_S if y >= h - 1 else WATER
        elif lab == "COAST":
            blocks[i] = CLIFF_W
            info["coast_cells"] += 1
        elif lab == "CLIFF":
            blocks[i] = MTN
        elif lab == "STAIR":
            blocks[i] = STAIR
        elif lab == "LEDGE":
            blocks[i] = LEDGE
        elif lab == "SAND":
            blocks[i] = DIRT
        elif lab == "TALL":
            blocks[i] = TALL
        elif lab in ("BUILDING", "DOOR", "LAND_ROCK"):
            # Secondary solids on routes are often rocks in water / posts
            x, y = i % w, i // w
            touches_ocean = any(
                0 <= x + dx < w and 0 <= y + dy < h
                and regions[(y + dy) * w + (x + dx)] == "OCEAN"
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
            )
            blocks[i] = ROCK  # walkable rock / islet
            if touches_ocean:
                blocks[i] = ROCK
        else:
            blocks[i] = GRASS

    # Vertical ledge drops: walkable with cliff/mtn immediately north
    ledge_ys = set()
    for y in range(1, h):
        for x in range(w):
            i = y * w + x
            if regions[i] not in ("GROUND", "SAND", "TALL", "LAND_ROCK"):
                continue
            above = regions[(y - 1) * w + x]
            if above in ("CLIFF", "COAST") and blocks[i] not in OCEANISH:
                blocks[i] = LEDGE if blocks[i] != STAIR else STAIR
                # face the cliff above
                if blocks[(y - 1) * w + x] == MTN:
                    blocks[(y - 1) * w + x] = FACE
                ledge_ys.add(y)
    info["ledge_rows"] = sorted(ledge_ys)

    # Shoreline
    for i, lab in enumerate(regions):
        if lab != "OCEAN":
            continue
        x, y = i % w, i // w
        if y > 0 and regions[(y - 1) * w + x] in WALK_REGIONS:
            ni = (y - 1) * w + x
            if blocks[ni] not in (MTN, FACE, RIDGE, PATH, STAIR, LEDGE, CLIFF_W, ROCK):
                blocks[ni] = SHORE
    return info


def compress_vertical(cells: list[Any], w: int, h: int, step: int) -> tuple[list[Any], int]:
    if step <= 1:
        return cells, h
    kept: list[Any] = []
    new_h = 0
    for y in range(0, h - 1, 2 * step):
        for dy in range(2):
            yy = min(y + dy, h - 1)
            kept.extend(cells[yy * w : (yy + 1) * w])
            new_h += 1
    if new_h % 2 == 1:
        kept.extend(cells[(h - 1) * w : h * w])
        new_h += 1
    return kept, new_h


def compress_y_map(h: int, step: int) -> list[int]:
    if step <= 1:
        return list(range(h))
    mapping: list[int] = []
    for y in range(0, h - 1, 2 * step):
        for dy in range(2):
            mapping.append(min(y + dy, h - 1))
    if len(mapping) % 2 == 1:
        mapping.append(h - 1)
    return mapping


def frlg_cell_to_gen1_block_y(cell_y: int, frlg_h: int, v_compress: int) -> int:
    mapping = compress_y_map(frlg_h, v_compress)
    if not mapping:
        return 0
    if cell_y in mapping:
        ci = mapping.index(cell_y)
    else:
        ci = min(range(len(mapping)), key=lambda i: abs(mapping[i] - cell_y))
    return ci // 2


def derive_connection_offset(
    frlg_offset: int,
    direction: str,
    src_cells: tuple[int, int],
    dst_cells: tuple[int, int],
    src_v: int,
    dst_v: int,
) -> int:
    """FRLG metatile offset → Gen1 block offset (dest_block = src_block - offset).

    Picks a source cell C where both C and C-frlg_offset lie on their maps,
    then converts through each map's compress + downsample.
    """
    dir_l = direction.lower()
    src_w, src_h = src_cells
    dst_w, dst_h = dst_cells
    if dir_l in ("left", "right", "east", "west"):
        # Offset applies to Y
        for c in range(src_h):
            d = c - frlg_offset
            if 0 <= d < dst_h:
                return (
                    frlg_cell_to_gen1_block_y(c, src_h, src_v)
                    - frlg_cell_to_gen1_block_y(d, dst_h, dst_v)
                )
        # Fallback: convert offset magnitude through dest scaling at origin
        return -frlg_cell_to_gen1_block_y(abs(frlg_offset), dst_h, dst_v) * (
            1 if frlg_offset >= 0 else -1
        )
    # North/south: offset applies to X (downsample only)
    for c in range(src_w):
        d = c - frlg_offset
        if 0 <= d < dst_w:
            return (c // 2) - (d // 2)
    return -(frlg_offset // 2)


def downsample(cell_blocks: list[int], w: int, h: int) -> tuple[int, int, list[int]]:
    """2×2 → 1 block; preserve ocean, stairs, and tier edges (FACE/RIDGE/LEDGE)."""
    bw, bh = w // 2, h // 2
    prio = {
        WATER: 6, WATER_S: 6, WATER_W: 6, SHORE: 5, COBBLE: 6, PATH: 8, STAIR: 10,
        PC[0]: 11, ROCK: 2, CLIFF_W: 7, MTN: 6, FACE: 8, TREE: 4, TALL: 2,
        GRASS: 1, DIRT: 8, LEDGE: 8, RIDGE: 8, RIDGE_E: 8,
        CORNER_SW: 5, CORNER_SE: 5,
    }
    building = set(PC + MART + HOUSE)
    pathish = {PATH, DIRT, STAIR, COBBLE, GRASS, ROCK, SHORE, TALL}
    hard_land = {MTN, FACE, RIDGE, RIDGE_E, CLIFF_W, TREE, LEDGE}
    tier_edge = {FACE, RIDGE, RIDGE_E, LEDGE, STAIR}
    out: list[int] = []
    for by in range(bh):
        for bx in range(bw):
            quad = [
                cell_blocks[(by * 2 + dy) * w + (bx * 2 + dx)]
                for dy in range(2) for dx in range(2)
            ]
            bld = [q for q in quad if q in building]
            if bld:
                out.append(Counter(bld).most_common(1)[0][0])
                continue
            ocean = [q for q in quad if q in OCEANISH]
            critical = [q for q in quad if q in (PATH, DIRT, STAIR, COBBLE)]
            if ocean and not critical:
                if len(ocean) >= 2 or len(ocean) >= len(quad) - len(ocean):
                    out.append(max(set(ocean), key=lambda t: (ocean.count(t), prio.get(t, 0))))
                    continue
            # Stairs always win (tier links)
            stairs = [q for q in quad if q == STAIR]
            if stairs:
                out.append(STAIR)
                continue
            if critical:
                out.append(max(set(critical), key=lambda t: (critical.count(t), prio.get(t, 0))))
                continue
            # Preserve tier edges over grass majority
            edges = [q for q in quad if q in tier_edge]
            if edges and not ocean:
                out.append(max(set(edges), key=lambda t: (edges.count(t), prio.get(t, 0))))
                continue
            walk = [q for q in quad if q in pathish]
            if walk and any(q in hard_land for q in quad):
                out.append(max(set(walk), key=lambda t: (walk.count(t), prio.get(t, 0))))
                continue
            if ocean:
                out.append(max(set(ocean), key=lambda t: (ocean.count(t), prio.get(t, 0))))
                continue
            out.append(max(set(quad), key=lambda t: (quad.count(t), prio.get(t, 0))))
    return bw, bh, out


def setb(blocks: list[int], w: int, x: int, y: int, v: int) -> None:
    hh = len(blocks) // w
    if 0 <= x < w and 0 <= y < hh:
        blocks[y * w + x] = v


def put_building(blocks: list[int], w: int, bx: int, by: int, kind: str) -> tuple[int, int]:
    if kind == "pc":
        tl, tr, bl, br = PC
        setb(blocks, w, bx, by, tl); setb(blocks, w, bx + 1, by, tr)
        setb(blocks, w, bx, by + 1, bl); setb(blocks, w, bx + 1, by + 1, br)
        return bx, by + 1
    if kind == "mart":
        tl, tr, bl, br = MART
        setb(blocks, w, bx, by, tl); setb(blocks, w, bx + 1, by, tr)
        setb(blocks, w, bx, by + 1, bl); setb(blocks, w, bx + 1, by + 1, br)
        return bx, by + 1
    setb(blocks, w, bx, by, HOUSE[0]); setb(blocks, w, bx + 1, by, HOUSE[1]); setb(blocks, w, bx + 2, by, HOUSE[2])
    setb(blocks, w, bx, by + 1, HOUSE[3]); setb(blocks, w, bx + 1, by + 1, HOUSE[4]); setb(blocks, w, bx + 2, by + 1, HOUSE[5])
    return bx + 1, by + 1


def clear_door_apron(blocks: list[int], w: int, door_bx: int, door_by: int) -> None:
    hh = len(blocks) // w
    # Never erase elevation kit — only open blocked ground in front of doors.
    elev = {LEDGE, STAIR, FACE, RIDGE, RIDGE_E, MTN, CLIFF_W, TREE}
    for dy in range(1, 3):
        for dx in range(-1, 3):
            x, y = door_bx + dx, door_by + dy
            if 0 <= x < w and 0 <= y < hh:
                cur = blocks[y * w + x]
                if cur in elev:
                    continue
                if cur in OCEANISH or cur in BLOCKED:
                    blocks[y * w + x] = PATH


def gen1_constraints(blocks: list[int], w: int, h: int, report: dict) -> None:
    fixes = []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if blocks[i] != LEDGE:
                continue
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and blocks[ny * w + nx] in OCEANISH:
                    blocks[i] = ROCK
                    fixes.append("ledge_on_water")
                    break
    labels = ["OCEAN" if b in OCEANISH else "LAND" for b in blocks]
    seeds = []
    for x in range(w):
        for y in (0, h - 1):
            i = y * w + x
            if labels[i] == "OCEAN":
                seeds.append(i)
    for y in range(h):
        for x in (0, w - 1):
            i = y * w + x
            if labels[i] == "OCEAN":
                seeds.append(i)
    ocean = flood(labels, w, h, seeds, {"OCEAN"})
    for i, lab in enumerate(labels):
        if lab == "OCEAN" and i not in ocean:
            blocks[i] = GRASS
            fixes.append("inland_water")
    report["constraint_fixes"] = dict(Counter(fixes))


def open_edge(blocks: list[int], w: int, h: int, side: str, lo: int, hi: int, fill: int) -> None:
    for i in range(lo, hi + 1):
        if side == "east":
            blocks[i * w + (w - 1)] = fill
        elif side == "west":
            blocks[i * w] = fill
        elif side == "south":
            blocks[(h - 1) * w + i] = fill
        elif side == "north":
            blocks[i] = fill


def layer4_town(
    cell_blocks: list[int], cw: int, ch: int,
    warps: list[dict[str, Any]], spec: dict[str, Any], report: dict,
) -> tuple[int, int, list[int]]:
    bw, bh, blocks = downsample(cell_blocks, cw, ch)
    report["size"] = [bw, bh]
    interest = spec.get("warps_of_interest") or {}
    stamped = []
    pc_block = None
    pending_houses = []
    harbor_warp = None

    for warp in warps:
        dest = str(warp.get("dest_map") or "")
        cx, cy = int(warp["x"]), int(warp["y"])
        bx, by = cx // 2, max(0, cy // 2 - 1)
        kind = None
        for frag, k in interest.items():
            if frag in dest:
                kind = k
                break
        if kind == "harbor":
            harbor_warp = (cx, cy, bx, by)
        elif kind == "house":
            pending_houses.append((cx, cy, bx, by))
        elif kind == "pc":
            bx = max(3, min(cx // 2 - 1, bw - 4))
            by = max(1, min(cy // 2 - 1, 2))
            for dy in range(0, 2):
                for dx in range(0, 2):
                    cur = blocks[(by + dy) * bw + (bx + dx)]
                    if cur in OCEANISH or cur in (LEDGE, STAIR):
                        setb(blocks, bw, bx + dx, by + dy, ROCK)
            door = put_building(blocks, bw, bx, by, "pc")
            clear_door_apron(blocks, bw, door[0], door[1])
            stamped.append({"kind": "pc", "cell": [cx, cy], "block": [bx, by], "door": list(door)})
            pc_block = (bx, by)

    if spec.get("add_mart") and pc_block:
        mx = min(bw - 2, pc_block[0] + 2)
        my = pc_block[1]
        for dy in range(0, 2):
            for dx in range(0, 2):
                cur = blocks[(my + dy) * bw + (mx + dx)]
                if cur in OCEANISH or cur in (LEDGE, STAIR):
                    setb(blocks, bw, mx + dx, my + dy, ROCK)
        door = put_building(blocks, bw, mx, my, "mart")
        clear_door_apron(blocks, bw, door[0], door[1])
        stamped.append({"kind": "mart", "block": [mx, my], "door": list(door), "note": "gen1_qol"})

    reserved = set()
    for s in stamped:
        if "block" not in s:
            continue
        bx, by = s["block"]
        width = 2 if s["kind"] in ("pc", "mart") else 3
        for dy in range(0, 3):
            for dx in range(0, width):
                reserved.add((bx + dx, by + dy))

    for cx, cy, bx, by in pending_houses:
        width = 3
        bx = max(2, min(cx // 2, bw - width))
        by = max(4, min(cy // 2 - 1, 5))

        def overlaps(x0, y0):
            return any((x0 + dx, y0 + dy) in reserved for dy in range(2) for dx in range(width))

        tries = 0
        while overlaps(bx, by) and tries < 8:
            bx = min(bw - width, bx + 1) if cx >= 12 else max(2, bx - 1)
            tries += 1
        for dy in range(0, 2):
            for dx in range(0, width):
                cur = blocks[(by + dy) * bw + (bx + dx)]
                if cur not in (MTN, FACE) or bx + dx >= 3:
                    setb(blocks, bw, bx + dx, by + dy, GRASS)
        door = put_building(blocks, bw, bx, by, "house")
        clear_door_apron(blocks, bw, door[0], door[1])
        for dy in range(0, 2):
            for dx in range(0, width):
                reserved.add((bx + dx, by + dy))
        stamped.append({"kind": "house", "cell": [cx, cy], "block": [bx, by], "door": list(door)})

    if harbor_warp:
        cx, cy, bx, by = harbor_warp
        pier_y = min(bh - 2, max(7, cy // 2))
        mid = bx
        for y in range(pier_y, bh):
            for dx in range(-1, 2):
                x = mid + dx
                if 0 <= x < bw:
                    blocks[y * bw + x] = PATH
        stamped.append({"kind": "harbor", "cell": [cx, cy], "block": [mid, pier_y]})

    report["buildings"] = stamped
    gen1_constraints(blocks, bw, bh, report)
    for s in stamped:
        if "door" in s:
            clear_door_apron(blocks, bw, s["door"][0], s["door"][1])
            dx, dy = s["door"]
            if dy + 1 < bh:
                for ax in range(dx, min(bw, dx + 2)):
                    cur = blocks[(dy + 1) * bw + ax]
                    if cur in (FACE, LEDGE, MTN, RIDGE, RIDGE_E, CLIFF_W, TREE):
                        row = dy + 1
                        if any(blocks[row * bw + xx] == STAIR for xx in range(bw)):
                            blocks[row * bw + ax] = PATH
                        else:
                            blocks[row * bw + ax] = GRASS
    # Open mid-plaza between houses (no ledge/face in the courtyard gap)
    house_doors = [s["door"] for s in stamped if s.get("kind") == "house" and "door" in s]
    if len(house_doors) >= 2:
        y = house_doors[0][1]
        xs = sorted(d[0] for d in house_doors)
        for x in range(xs[0] + 1, xs[-1]):
            if 0 <= x < bw and blocks[y * bw + x] in (LEDGE, FACE):
                blocks[y * bw + x] = GRASS
            if y + 1 < bh and blocks[(y + 1) * bw + x] in (LEDGE, FACE) and x >= 3:
                # don't strip west cliff face
                if blocks[(y + 1) * bw + x] == LEDGE:
                    blocks[(y + 1) * bw + x] = GRASS
    return bw, bh, blocks



def layer4_route(
    cell_blocks: list[int], cw: int, ch: int,
    spec: dict[str, Any], report: dict,
) -> tuple[int, int, list[int]]:
    """Keep FRLG ocean/sand/tall; only carve a land path corridor where land exists."""
    path_x = spec.get("path_x")
    if path_x:
        for y in range(ch):
            for x in range(path_x[0], path_x[1] + 1):
                i = y * cw + x
                # Never paint over surf — FRLG already encodes the water channels.
                if cell_blocks[i] in (TALL, GRASS, DIRT, ROCK):
                    cell_blocks[i] = DIRT if spec.get("beach") else PATH

    v_step = int(spec.get("v_compress") or 1)
    cell_blocks, ch = compress_vertical(cell_blocks, cw, ch, v_step)
    report["v_compress"] = v_step
    bw, bh, blocks = downsample(cell_blocks, cw, ch)
    report["size"] = [bw, bh]

    for i, b in enumerate(blocks):
        if b == TREE:
            blocks[i] = ROCK
        if b == COBBLE:
            blocks[i] = DIRT if spec.get("beach") else PATH

    gen1_constraints(blocks, bw, bh, report)
    return bw, bh, blocks


def lua_table(name: str, blocks: list[int], w: int, h: int) -> str:
    lines = [f"  {name} = {{", f"    width = {w},", f"    height = {h},", "    blocks = {"]
    for y in range(h):
        row = blocks[y * w : (y + 1) * w]
        lines.append("      " + ", ".join(str(b) for b in row) + ",")
    lines += ["    },", "  },"]
    return "\n".join(lines)


def ensure_assets(layouts_dir: str) -> tuple[list[int], list[int]]:
    print("Layer 0: fetch FRLG layout assets")
    for spec in ISLAND1.values():
        lay = spec["layout"]
        fetch(f"{GITHUB}/data/layouts/{lay}/map.bin", f"{layouts_dir}/{lay}.bin")
        mj = spec["map_json"]
        fetch(f"{GITHUB}/data/maps/{mj}/map.json", f"{layouts_dir}/{mj}.map.json")
    fetch(
        f"{GITHUB}/data/tilesets/primary/general/metatile_attributes.bin",
        f"{layouts_dir}/general_attr.bin",
    )
    fetch(
        f"{GITHUB}/data/tilesets/secondary/sevii_islands_123/metatile_attributes.bin",
        f"{layouts_dir}/sevii_attr.bin",
    )
    return (
        load_attrs(f"{layouts_dir}/general_attr.bin"),
        load_attrs(f"{layouts_dir}/sevii_attr.bin"),
    )


def load_frlg_connections(layouts_dir: str, map_json: str) -> list[dict[str, Any]]:
    path = f"{layouts_dir}/{map_json}.map.json"
    with open(path, encoding="utf-8") as f:
        return list(json.load(f).get("connections") or [])


def convert_map(
    map_id: str, spec: dict[str, Any], layouts_dir: str,
    gen: list[int], sev: list[int],
) -> tuple[dict[str, Any], dict[str, Any]]:
    cw, ch = spec["cells"]
    cells = load_map_cells(f"{layouts_dir}/{spec['layout']}.bin", cw, ch)
    report: dict[str, Any] = {
        "id": map_id,
        "frlg_layout": spec["layout"],
        "frlg_cells": [cw, ch],
        "kind": spec["kind"],
        "layers": [
            "frlg_semantics",
            "region_adapt",
            "gen1_vocabulary",
            "tier_platforms" if spec["kind"] == "town" else "route_roles",
            "gen1_constraints",
        ],
    }

    print(f"\n{map_id}")
    print("  1) FRLG semantics")
    labels = layer1_classify(cells, cw, ch, gen, sev, kind=spec["kind"])
    report["semantics"] = dict(Counter(labels))

    print("  2) Region adapt (ocean vs land, fill moats)")
    regions = layer2_regions(labels, cw, ch, kind=spec["kind"], report=report)

    print("  3) Gen 1 vocabulary" + (" + platforms" if spec["kind"] == "town" else ""))
    cell_blocks, plat_info = layer3_vocabulary(regions, cw, ch, kind=spec["kind"])
    report["role_vocab"] = {
        k: {"block": v["block"], "ref": v["ref"], "frlg": v["frlg"]}
        for k, v in ROLE_VOCAB.items()
    }
    if plat_info:
        report["platforms"] = plat_info

    print("  4) Gen 1 constraints + buildings")
    if spec["kind"] == "town":
        with open(f"{layouts_dir}/{spec['map_json']}.map.json", encoding="utf-8") as f:
            warps = list(json.load(f).get("warp_events") or [])
        report["frlg_warps"] = [
            {"x": w["x"], "y": w["y"], "dest": w.get("dest_map")} for w in warps
        ]
        bw, bh, blocks = layer4_town(cell_blocks, cw, ch, warps, spec, report)
    else:
        bw, bh, blocks = layer4_route(cell_blocks, cw, ch, spec, report)

    report["gen1_blocks"] = {str(k): v for k, v in Counter(blocks).items()}
    report["tall_grass"] = blocks.count(TALL)
    report["water"] = sum(1 for b in blocks if b in OCEANISH)
    report["frlg_connections"] = load_frlg_connections(layouts_dir, spec["map_json"])

    access_ok = True
    for s in report.get("buildings") or []:
        if "door" not in s:
            continue
        dx, dy = s["door"]
        sy = dy + 1
        if sy < bh:
            for ax in range(dx, dx + 2):
                if ax < bw and blocks[sy * bw + ax] not in WALKABLE:
                    access_ok = False
    report["door_access_ok"] = access_ok
    return {"width": bw, "height": bh, "blocks": blocks}, report



def _edge_roles(blocks: list[int], w: int, h: int, side: str) -> list[str]:
    """Classify an edge as OCEAN / WALK / BLOCK for seam checks."""
    def role(b: int) -> str:
        if b in OCEANISH:
            return "OCEAN"
        if b in WALKABLE or b in (ROCK, PATH, DIRT, SHORE, STAIR, GRASS, TALL):
            return "WALK"
        return "BLOCK"

    if side == "east":
        return [role(blocks[y * w + (w - 1)]) for y in range(h)]
    if side == "west":
        return [role(blocks[y * w]) for y in range(h)]
    if side == "south":
        return [role(blocks[(h - 1) * w + x]) for x in range(w)]
    if side == "north":
        return [role(blocks[x]) for x in range(w)]
    return []


def check_connection_seams(
    results: dict[str, Any], meta: dict[str, Any],
) -> dict[str, Any]:
    """Verify shared seams agree on ocean vs walk (role match)."""
    pairs = [
        ("SEVII_ONE_ISLAND", "east", "SEVII_ONE_ISLAND_KINDLE_ROAD", "west", "east_offset"),
        ("SEVII_ONE_ISLAND", "south", "SEVII_ONE_ISLAND_TREASURE_BEACH", "north", "south_offset"),
    ]
    out: dict[str, Any] = {}
    for src_id, src_side, dst_id, dst_side, off_key in pairs:
        if src_id not in results or dst_id not in results:
            continue
        src, dst = results[src_id], results[dst_id]
        sw, sh = src["width"], src["height"]
        dw, dh = dst["width"], dst["height"]
        src_edge = _edge_roles(src["blocks"], sw, sh, src_side)
        dst_edge = _edge_roles(dst["blocks"], dw, dh, dst_side)
        offset = int((meta.get(src_id) or {}).get(off_key) or 0)
        # dest_block = src_block - offset  ⇒  align src[i] with dst[i - offset]
        matches = 0
        compared = 0
        mismatches = []
        for i, srole in enumerate(src_edge):
            j = i - offset
            if not (0 <= j < len(dst_edge)):
                continue
            compared += 1
            drole = dst_edge[j]
            # Ocean↔ocean or walk↔walk (block can differ) is OK
            if srole == drole or {srole, drole} <= {"WALK", "BLOCK"}:
                matches += 1
            else:
                mismatches.append({"src": i, "dst": j, "src_role": srole, "dst_role": drole})
        out[f"{src_id}->{dst_id}"] = {
            "compared": compared,
            "matches": matches,
            "seam_ok": compared > 0 and len(mismatches) <= max(1, compared // 4),
            "mismatches": mismatches[:12],
        }
    return out


def build_connection_meta(
    results: dict[str, Any],
    reports: list[dict[str, Any]],
    layouts_dir: str,
) -> dict[str, Any]:
    """Derive Gen1 connection offsets from FRLG map.json + compress ratios."""
    by_id = {r["id"]: r for r in reports}
    meta: dict[str, Any] = {}
    # frlg map name fragment → our id
    frlg_to_id = {
        "MAP_ONE_ISLAND_TREASURE_BEACH": "SEVII_ONE_ISLAND_TREASURE_BEACH",
        "MAP_ONE_ISLAND_KINDLE_ROAD": "SEVII_ONE_ISLAND_KINDLE_ROAD",
        "MAP_ONE_ISLAND": "SEVII_ONE_ISLAND",
    }
    dir_to_key = {
        "right": "east_offset", "left": "west_offset",
        "down": "south_offset", "up": "north_offset",
        "east": "east_offset", "west": "west_offset",
        "south": "south_offset", "north": "north_offset",
    }

    for map_id, spec in ISLAND1.items():
        layout = results[map_id]
        rep = by_id[map_id]
        entry: dict[str, Any] = {
            "width": layout["width"],
            "height": layout["height"],
            "frlg_cells": list(spec["cells"]),
            "v_compress": int(spec.get("v_compress") or 1),
        }
        for conn in rep.get("frlg_connections") or []:
            dest_frlg = conn.get("map") or ""
            dest_id = frlg_to_id.get(dest_frlg)
            if not dest_id or dest_id not in ISLAND1:
                continue
            dst_spec = ISLAND1[dest_id]
            key = dir_to_key.get(str(conn.get("direction") or "").lower())
            if not key:
                continue
            off = derive_connection_offset(
                int(conn.get("offset") or 0),
                str(conn.get("direction")),
                tuple(spec["cells"]),  # type: ignore[arg-type]
                tuple(dst_spec["cells"]),  # type: ignore[arg-type]
                int(spec.get("v_compress") or 1),
                int(dst_spec.get("v_compress") or 1),
            )
            entry[key] = off
            entry[f"{key}_frlg"] = {
                "dest": dest_id,
                "frlg_offset": conn.get("offset"),
                "direction": conn.get("direction"),
            }
        meta[map_id] = entry
    return meta


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--layouts-dir", default="/tmp/sevii_layouts")
    ap.add_argument(
        "--outdir",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "sevii"),
    )
    args = ap.parse_args()

    gen, sev = ensure_assets(args.layouts_dir)
    results: dict[str, Any] = {}
    reports: list[dict[str, Any]] = []

    for map_id, spec in ISLAND1.items():
        layout, report = convert_map(map_id, spec, args.layouts_dir, gen, sev)
        results[map_id] = layout
        reports.append(report)
        print(
            f"  → {layout['width']}x{layout['height']} "
            f"tall={report['tall_grass']} water={report['water']} "
            f"moats_filled={report.get('moat_filled', 0)} "
            f"door_access={report.get('door_access_ok', 'n/a')}"
        )

    meta = build_connection_meta(results, reports, args.layouts_dir)
    seams = check_connection_seams(results, meta)
    for mid, m in meta.items():
        offs = {k: v for k, v in m.items() if k.endswith("_offset")}
        if offs:
            print(f"  meta {mid}: {offs}")
    for key, seam in seams.items():
        print(f"  seam {key}: ok={seam['seam_ok']} "
              f"{seam['matches']}/{seam['compared']}")

    # Emit town warps into meta for maps.lua (cell coords from stamped doors)
    by_id = {r["id"]: r for r in reports}
    town_rep = by_id.get("SEVII_ONE_ISLAND") or {}
    town_warps: list[dict[str, Any]] = []
    for b in town_rep.get("buildings") or []:
        if b.get("kind") == "harbor" and "block" in b:
            bx, by = b["block"]
            town_warps += [
                {"x": bx * 2, "y": by * 2,
                 "destMap": "SEVII_ONE_ISLAND_HARBOR", "destWarp": 1},
                {"x": bx * 2 + 1, "y": by * 2,
                 "destMap": "SEVII_ONE_ISLAND_HARBOR", "destWarp": 1},
            ]
        elif "door" in b and b.get("kind") in ("pc", "mart"):
            dx, dy = b["door"]
            dest = ("SEVII_ONE_ISLAND_POKECENTER" if b["kind"] == "pc"
                    else "SEVII_ONE_ISLAND_MART")
            town_warps += [
                {"x": dx * 2 + 1, "y": dy * 2 + 1, "destMap": dest, "destWarp": 1},
                {"x": dx * 2 + 2, "y": dy * 2 + 1, "destMap": dest, "destWarp": 1},
            ]
    if "SEVII_ONE_ISLAND" in meta:
        meta["SEVII_ONE_ISLAND"]["warps"] = town_warps

    os.makedirs(args.outdir, exist_ok=True)
    meta_lines = ["  meta = {"]
    for mid, m in meta.items():
        meta_lines.append(f"    {mid} = {{")
        for k, v in m.items():
            if k.endswith("_frlg"):
                continue  # keep lua meta lean; full detail in layout_report.json
            if k == "warps" and isinstance(v, list):
                meta_lines.append("      warps = {")
                for w in v:
                    meta_lines.append(
                        "        { "
                        f"x = {w['x']}, y = {w['y']}, "
                        f'destMap = "{w["destMap"]}", destWarp = {w["destWarp"]} '
                        "},"
                    )
                meta_lines.append("      },")
                continue
            if isinstance(v, list):
                meta_lines.append(f"      {k} = {{ {', '.join(str(x) for x in v)} }},")
            else:
                meta_lines.append(f"      {k} = {v},")
        meta_lines.append("    },")
    meta_lines.append("  },")

    parts = [
        "-- Auto-generated by sevii_layout_gen.py",
        "-- FRLG semantics → role map / tiers → Gen1 vocabulary → constraints",
        "return {",
    ]
    for map_id, layout in results.items():
        parts.append(lua_table(map_id, layout["blocks"], layout["width"], layout["height"]))
    parts += ["\n".join(meta_lines), "}", ""]
    out_lua = os.path.join(args.outdir, "layout_data.lua")
    with open(out_lua, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    print(f"\nWrote {out_lua}")

    report_path = os.path.join(args.outdir, "layout_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump({"maps": reports, "meta": meta, "seams": seams}, f, indent=2)
        f.write("\n")
    print(f"Wrote {report_path}")
    _sync_preview_maps_json(args.outdir, reports)


def _sync_preview_maps_json(outdir: str, reports: list[dict[str, Any]]) -> None:
    """Keep map_previews/maps.json aligned with layout_data.lua."""
    root = os.path.dirname(os.path.abspath(outdir))
    preview = os.path.join(root, "map_previews", "maps.json")
    if not os.path.isfile(preview):
        return
    with open(preview, encoding="utf-8") as f:
        maps = json.load(f)
    with open(os.path.join(outdir, "layout_data.lua"), encoding="utf-8") as f:
        lua = f.read()
    by_id = {r["id"]: r for r in reports}
    for mid in ISLAND1:
        m = re.search(
            rf"{mid} = \{{\s*width = (\d+),\s*height = (\d+),\s*blocks = \{{(.*?)\n    \}},",
            lua,
            re.S,
        )
        if not m:
            continue
        w, h = int(m.group(1)), int(m.group(2))
        blocks = [int(x) for x in re.findall(r"\d+", m.group(3))]
        entry = maps.get(mid) or {"id": mid, "tileset": "OVERWORLD"}
        entry.update({"width": w, "height": h, "blocks": blocks})
        if mid == "SEVII_ONE_ISLAND":
            warps: list[dict[str, Any]] = []
            for b in (by_id.get(mid) or {}).get("buildings") or []:
                if b.get("kind") == "harbor" and "block" in b:
                    bx, by = b["block"]
                    warps += [
                        {"x": bx * 2, "y": by * 2,
                         "destMap": "SEVII_ONE_ISLAND_HARBOR", "destWarp": 1},
                        {"x": bx * 2 + 1, "y": by * 2,
                         "destMap": "SEVII_ONE_ISLAND_HARBOR", "destWarp": 1},
                    ]
                elif "door" in b and b.get("kind") in ("pc", "mart"):
                    dx, dy = b["door"]
                    dest = ("SEVII_ONE_ISLAND_POKECENTER" if b["kind"] == "pc"
                            else "SEVII_ONE_ISLAND_MART")
                    warps += [
                        {"x": dx * 2 + 1, "y": dy * 2 + 1,
                         "destMap": dest, "destWarp": 1},
                        {"x": dx * 2 + 2, "y": dy * 2 + 1,
                         "destMap": dest, "destWarp": 1},
                    ]
            entry["warps"] = warps
        maps[mid] = entry
    with open(preview, "w", encoding="utf-8") as f:
        json.dump(maps, f, indent=2)
        f.write("\n")
    print(f"Synced {preview}")


if __name__ == "__main__":
    main()
