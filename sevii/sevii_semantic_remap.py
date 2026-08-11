#!/usr/bin/env python3
"""FRLG → Gen1 layout remap via semantics (behaviors), not tile art.

Recommended approach (layout extraction):
  1. Read FRLG map.bin + metatile_attributes (u32).
  2. Classify each cell into a small category set using MB_* behaviors
     (+ collision / known cliff mids for impassable outdoor rock).
  3. Terrain categories → Gen1 OVERWORLD block IDs (vanilla-proven).
  4. Structural categories (BUILDING/DOOR/SIGN/CAVE) are NOT baked into the
     tile grid as ROCK/MTN/PATH placeholders — they go into a separate
     (x, y, category) list for a stamp pass. Grid cells get PATH/GRASS fill.
  5. LEDGE keeps FRLG jump direction (MB_JUMP_E/W/N/S) as a second field;
     Gen1 hop tiles differ by direction (down/left/right).
  6. Downsample 2×2 cells → 1 Gen1 block; stamp buildings from warps + markers.

This does NOT convert FRLG pixels/tiles. It remaps *where* water, grass,
cliffs, stairs, sand, and buildings are.

Usage:
  python3 sevii_semantic_remap.py
  python3 sevii_semantic_remap.py --outdir tile_mapping/semantic
"""

from __future__ import annotations

import argparse
import json
import os
import struct
import sys
import urllib.request
from collections import Counter, deque
from typing import Any, Optional

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools"))
import tiled_export as te  # noqa: E402

GITHUB = "https://raw.githubusercontent.com/pret/pokefirered/master"
NUM_PRIMARY = 640
CACHE = "/tmp/frlg_tilesets"
LAYOUTS = "/tmp/sevii_layouts"

# ── Gen1 OVERWORLD blocks (vanilla-proven roles) ─────────────────────────────
# Sourced from Cinnabar / Pewter / Route 4 / Route 21 usage, not invention.
G1 = {
    "GRASS": 1,          # short grass / plaza
    "TALL": 11,          # wild tall grass
    "DIRT": 10,          # sand / dirt path
    "PATH": 7,           # walking path
    "COBBLE": 85,        # town cobble
    "WATER": 67,         # ocean body (Route 21 / Cinnabar borderBlock)
    "WATER_S": 107,      # Cinnabar south shoreline (water + rock fringe) — ONLY
                         # when land is directly north; open ocean stays WATER
    "WATER_W": 24,       # west water (pair with CLIFF_W)
    "SHORE": 31,         # land north of water
    "CLIFF_W": 100,      # water-facing cliff (Cinnabar)
    "ROCK": 123,         # walkable rock deck (Cinnabar plateau)
    "LEDGE": 26,         # fallback / north visual (Gen1 has no north hop rule)
    "LEDGE_S": 55,       # hop-down ledgeTile (rom ledge_tiles)
    "LEDGE_W": 39,       # hop-left
    "LEDGE_E": 13,       # hop-right
    "STAIR": 47,         # outdoor stairs
    "TREE": 15,          # blocking tree
    "MTN": 44,           # solid mountain mass
    "FACE": 41,          # cliff face
    "RIDGE": 63,         # platform top rim
    "RIDGE_E": 59,
}

PC = (32, 33, 124, 114)
MART = (32, 33, 124, 115)
HOUSE = (12, 13, 14, 16, 58, 0)

# Stamp definitions — footprint only (never a clearing rectangle).
# has_back_door: when True, north-face door + second warp (Celadon Mansion style).
# warp_face: "door" = on building door tiles; "threshold" = one block south (apron).
BUILDING_DEFS: dict[str, dict[str, Any]] = {
    "pc": {
        "size": (2, 2),
        "rows": ((32, 33), (124, 114)),
        "door_offset": (0, 1),  # top-left of door tile(s) relative to stamp origin
        "warp_face": "door",
        "has_back_door": False,
        "dest": "SEVII_ONE_ISLAND_POKECENTER",
    },
    "mart": {
        "size": (2, 2),
        "rows": ((32, 33), (124, 115)),
        "door_offset": (0, 1),
        "warp_face": "door",
        "has_back_door": False,
        "dest": "SEVII_ONE_ISLAND_MART",
    },
    "house": {
        "size": (3, 2),
        "rows": ((12, 13, 14), (16, 58, 0)),
        "door_offset": (1, 1),
        "warp_face": "door",
        "has_back_door": False,
        # Exteriors only for now — HOUSE1/HOUSE2 maps not registered in maps.lua yet.
        "dest": None,
    },
    "harbor": {
        "size": (3, 2),
        "rows": ((12, 13, 14), (16, 58, 0)),
        "door_offset": (1, 1),
        # Warp on PATH apron south of the wall/door row — not on tile 58.
        "warp_face": "threshold",
        "has_back_door": False,
        "dest": "SEVII_ONE_ISLAND_HARBOR",
    },
}


# FRLG behavior sets
WATER_BEH = {0x10, 0x11, 0x12, 0x13, 0x15, 0x16, 0x17, 0x1A, 0x1B}
# Distinct metatile behaviors — do not flatten away direction.
JUMP_DIR = {
    0x38: "E",  # MB_JUMP_EAST
    0x39: "W",  # MB_JUMP_WEST
    0x3A: "N",  # MB_JUMP_NORTH (Gen1 has no north hop; keep dir for topology)
    0x3B: "S",  # MB_JUMP_SOUTH
}
JUMP_BEH = set(JUMP_DIR)
# All outdoor warp behaviors (arrows included — 0x64 was silently dropped before)
DOOR_BEH = {0x60, 0x62, 0x63, 0x64, 0x65, 0x67, 0x69}
STAIR_BEH = {0x2A}
SIGN_BEH = {0x84, 0x87, 0x88}
MOUNTAIN_TOP_BEH = 0x0C  # MB_MOUNTAIN_TOP — walkable plateau, not water
CLIFF_MIDS = {
    0x070, 0x071, 0x072, 0x073, 0x075, 0x07A, 0x07B, 0x07C, 0x07D,
    0x0B2, 0x0B3, 0x0B4, 0x0B5,
}

# FRLG General tree tops (metatile_labels.h) + full tree bodies on One Island.
# Secondary Sevii foliage (0x286…) are shrubs — not Gen1 TREE walls.
TREE_MIDS = {
    0x00A, 0x00B, 0x00C, 0x00E, 0x00F, 0x013,  # thin/wide tree tops
    *range(0x014, 0x020),  # tree canopy / trunks flanking PC
    *range(0x024, 0x028),  # tree bases
}

# Sevii secondary foliage — small shrubs/bushes, not full trees.
# Map to plaza/grass fill instead of TREE so they don't form a wall.
SHRUB_MIDS = {
    0x286, 0x287, 0x28E, 0x28F, 0x296,
    0x29E, 0x29F,
    0x2A5, 0x2A6, 0x2A7, 0x2AD, 0x2AE, 0x2AF,
}

# Walkable wooden pier tongue (One Island harbor over ocean).
PIER_MIDS = {0x1C5, 0x1C6, 0x1C7, 0x2B4, 0x2B6}  # 0x2B5 is door (SOUTH_ARROW)

# Behaviors the classifier handles explicitly (for unknown-byte asserts).
KNOWN_BEHAVIORS = (
    WATER_BEH | JUMP_BEH | DOOR_BEH | STAIR_BEH | SIGN_BEH
    | {0x00, 0x02, 0x08, 0x21, MOUNTAIN_TOP_BEH}
    | set(range(0x30, 0x38))  # impassable directionals → CLIFF
)

# Unknown-behavior tally (beh → count); cleared per run in remap_map.
UNKNOWN_BEH: Counter = Counter()
UNKNOWN_BEH_SAMPLES: dict[int, list[tuple[int, int, int]]] = {}  # beh → [(mid,x,y),...]

# Gen1 ledge tiles that actually participate in HandleLedges (by facing).
LEDGE_DIR_TO_GEN1 = {
    "S": G1["LEDGE_S"],
    "W": G1["LEDGE_W"],
    "E": G1["LEDGE_E"],
    "N": G1["LEDGE"],  # no rom north-hop rule; visual only
}

# Town ↔ Kindle connection pairing (single source of truth).
# east_offset on town must equal -west_offset on kindle.
def connection_pair_offsets(town_h: int, kindle_h: int) -> tuple[int, int]:
    delta = kindle_h - town_h
    east_off, west_off = -delta, delta
    assert east_off == -west_off, (east_off, west_off)
    return east_off, west_off


# ── Category taxonomy + Gen1 lookup (terrain only) ───────────────────────────
# Structural cats are collected separately — never written as fake ROCK/MTN/PATH.
TERRAIN_CATEGORIES = [
    "WATER", "TALL_GRASS", "SHORT_GRASS", "TOWN_PATH", "SAND", "PATH", "PIER",
    "TREE", "CLIFF", "COAST_CLIFF", "LEDGE", "STAIR",
    "ROCK_DECK", "BLOCKED",
]

STRUCTURAL_CATEGORIES = {"BUILDING", "DOOR", "SIGN", "CAVE"}

# Fill under structural markers so the map stays walkable until stamps land.
STRUCTURAL_FILL = {
    "BUILDING": "SHORT_GRASS",  # overridden to TOWN_PATH in towns
    "DOOR": "PATH",
    "SIGN": "PATH",
    "CAVE": "PATH",
}

CATEGORY_TO_GEN1: dict[str, int] = {
    "WATER": G1["WATER"],
    "TALL_GRASS": G1["TALL"],
    "SHORT_GRASS": G1["GRASS"],
    "TOWN_PATH": G1["COBBLE"],  # Gen1 town plaza (Pewter/Viridian cobble)
    "SAND": G1["DIRT"],
    "PATH": G1["PATH"],
    "PIER": G1["PATH"],  # wooden pier → Gen1 path (no wood art)
    "TREE": G1["TREE"],
    "CLIFF": G1["MTN"],
    "COAST_CLIFF": G1["CLIFF_W"],
    "LEDGE": G1["LEDGE_S"],  # default south; overridden when dir known
    "STAIR": G1["STAIR"],
    "ROCK_DECK": G1["ROCK"],
    "BLOCKED": G1["MTN"],
}

CATEGORY_NOTES: dict[str, str] = {
    "WATER": "MB_OCEAN_WATER / pond / deep → Gen1 67 (Route 21 / Cinnabar)",
    "TALL_GRASS": "MB_TALL_GRASS 0x02 → Gen1 11",
    "SHORT_GRASS": "MB_NORMAL walkable on routes → Gen1 1",
    "TOWN_PATH": "MB_NORMAL walkable in towns → Gen1 85 cobble (plaza, not wild grass)",
    "SAND": "MB_SAND 0x21 → Gen1 10 dirt",
    "PATH": "carved corridors → Gen1 7",
    "PIER": "FRLG wooden pier mids over ocean → Gen1 7 path",
    "TREE": "General/Sevii tree mids (NOT secondary BUILDING catch-all) → Gen1 15",
    "CLIFF": "cliff mids / solid outdoor rock → Gen1 44 mountain",
    "COAST_CLIFF": "cliff touching ocean → Gen1 100 (Cinnabar west)",
    "LEDGE": "MB_JUMP_{E,W,N,S} → Gen1 13/39/26/55 by direction (not flattened)",
    "STAIR": "MB_ROCK_STAIRS 0x2A → Gen1 47",
    "ROCK_DECK": "MB_MOUNTAIN_TOP 0x0C → Gen1 123 (Cinnabar/Route 10 walkable rock)",
    "BLOCKED": "other impassable → mountain mass",
    "BUILDING": "STRUCTURAL — roofs/walls; trees excluded via TREE_MIDS",
    "DOOR": "STRUCTURAL — not a tile; (x,y) list + PATH fill until stamp",
    "SIGN": "STRUCTURAL — not a tile; (x,y) list + PATH fill",
    "CAVE": "STRUCTURAL — not a tile; (x,y) list + PATH fill until cave stamp",
}

CATEGORIES = TERRAIN_CATEGORIES + sorted(STRUCTURAL_CATEGORIES)

MAPS = {
    "SEVII_ONE_ISLAND": {
        "layout": "OneIsland", "map_json": "OneIsland",
        # 24×20 FRLG → 12×10 blocks; pad_south adds pier breathing room → 12×12.
        "cells": (24, 20), "kind": "town", "v_compress": 1, "pad_south": 2,
        "warps": {"POKEMON_CENTER": "pc", "HOUSE1": "house", "HOUSE2": "house", "HARBOR": "harbor"},
        "add_mart": True,
    },
    "SEVII_ONE_ISLAND_KINDLE_ROAD": {
        "layout": "OneIsland_KindleRoad", "map_json": "OneIsland_KindleRoad",
        # v_compress=1: 140 FRLG rows → 70 Gen1 blocks (2:1 cell only).
        # v_compress=2 was 4:1 and dropped thin paths/ledges into pure ocean.
        "cells": (24, 140), "kind": "route", "v_compress": 1,
    },
    "SEVII_ONE_ISLAND_TREASURE_BEACH": {
        "layout": "OneIsland_TreasureBeach", "map_json": "OneIsland_TreasureBeach",
        "cells": (24, 40), "kind": "route", "v_compress": 1, "beach": True,
    },
}

OCEANISH = {G1["WATER"], G1["WATER_S"], G1["WATER_W"]}
WALKABLE = {
    G1["GRASS"], G1["TALL"], G1["DIRT"], G1["PATH"], G1["COBBLE"],
    G1["ROCK"], G1["SHORE"], G1["STAIR"],
}
LEDGE_BLOCKS = {G1["LEDGE"], G1["LEDGE_S"], G1["LEDGE_W"], G1["LEDGE_E"]}


def fetch(url: str, dest: str) -> None:
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    if os.path.isfile(dest) and os.path.getsize(dest) > 0:
        return
    print(f"  fetch {url}")
    urllib.request.urlretrieve(url, dest)


def ensure_assets() -> tuple[list[int], list[int]]:
    print("Fetch FRLG attrs + layouts")
    for spec in MAPS.values():
        fetch(f"{GITHUB}/data/layouts/{spec['layout']}/map.bin", f"{LAYOUTS}/{spec['layout']}.bin")
        fetch(f"{GITHUB}/data/maps/{spec['map_json']}/map.json", f"{LAYOUTS}/{spec['map_json']}.map.json")
    fetch(
        f"{GITHUB}/data/tilesets/primary/general/metatile_attributes.bin",
        f"{CACHE}/general_attr.bin",
    )
    fetch(
        f"{GITHUB}/data/tilesets/secondary/sevii_islands_123/metatile_attributes.bin",
        f"{CACHE}/sevii_attr.bin",
    )
    gen = [struct.unpack_from("<I", open(f"{CACHE}/general_attr.bin", "rb").read(), i * 4)[0]
           for i in range(NUM_PRIMARY)]
    sev_raw = open(f"{CACHE}/sevii_attr.bin", "rb").read()
    sev = [struct.unpack_from("<I", sev_raw, i * 4)[0] for i in range(len(sev_raw) // 4)]
    return gen, sev


def behavior(mid: int, gen: list[int], sev: list[int]) -> int:
    if mid < NUM_PRIMARY:
        return gen[mid] & 0x1FF if mid < len(gen) else 0
    idx = mid - NUM_PRIMARY
    return sev[idx] & 0x1FF if idx < len(sev) else 0


def load_cells(path: str, w: int, h: int) -> list[tuple[int, int]]:
    data = open(path, "rb").read()
    assert len(data) == w * h * 2, (path, len(data), w * h * 2)
    return [
        (struct.unpack_from("<H", data, i * 2)[0] & 0x3FF,
         (struct.unpack_from("<H", data, i * 2)[0] >> 10) & 3)
        for i in range(w * h)
    ]


def classify_cell(
    mid: int, coll: int, beh: int, *, kind: str, x: int = 0, y: int = 0
) -> tuple[str, Optional[str]]:
    """FRLG cell → (semantic category, optional ledge direction).

    Ledge direction comes from distinct MB_JUMP_{EAST,WEST,NORTH,SOUTH}
    behaviors — never collapsed to a directionless LEDGE alone.

    Unknown behavior bytes are tallied (not silently folded into SHORT_GRASS
    without a trace). Callers should print UNKNOWN_BEH after a map.
    """
    if beh in WATER_BEH:
        return "WATER", None
    if beh == 0x02:
        return "TALL_GRASS", None
    if beh == 0x21:
        return "SAND", None
    if beh in JUMP_DIR:
        return "LEDGE", JUMP_DIR[beh]
    if beh in STAIR_BEH:
        return "STAIR", None
    if beh in DOOR_BEH:
        return "DOOR", None
    if beh in SIGN_BEH:
        return "SIGN", None
    if beh == 0x08:
        return "CAVE", None
    if beh == MOUNTAIN_TOP_BEH:
        return "ROCK_DECK", None
    # Trees BEFORE cliff/building catch-alls (same coll/beh signature otherwise).
    if mid in TREE_MIDS:
        return "TREE", None
    if mid in SHRUB_MIDS:
        # Small Sevii foliage — plaza/grass, not Gen1 tree walls.
        return ("TOWN_PATH" if kind == "town" else "SHORT_GRASS"), None
    if mid in PIER_MIDS and coll == 0:
        return "PIER", None
    # Impassable directionals often decorate cliff edges
    if beh in {0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37}:
        return "CLIFF", None
    # Outdoor cliff graphics — known cliff mids only (not every solid low mid;
    # that rule was eating General tree bodies 0x014–0x027).
    if mid in CLIFF_MIDS:
        return "CLIFF", None
    # Secondary tileset solids: roofs / walls (trees already returned above)
    if mid >= NUM_PRIMARY and coll != 0 and beh == 0:
        return "BUILDING", None
    if coll != 0 and mid < 0x100 and beh == 0:
        # Remaining primary solids that aren't trees/cliffs
        return "BLOCKED", None
    if coll != 0:
        return "BLOCKED", None
    # Walkable with an unrecognized behavior — log, then ground
    if beh not in KNOWN_BEHAVIORS:
        UNKNOWN_BEH[beh] += 1
        samples = UNKNOWN_BEH_SAMPLES.setdefault(beh, [])
        if len(samples) < 6:
            samples.append((mid, x, y))
    # Town plaza vs route grass
    if kind == "town":
        return "TOWN_PATH", None
    return "SHORT_GRASS", None


def split_structural(
    cats: list[str], w: int, h: int, *, kind: str = "route"
) -> tuple[list[str], list[dict[str, Any]]]:
    """Pull BUILDING/DOOR/SIGN/CAVE out of the category grid.

    Returns terrain categories (structural cells replaced with PATH/cobble fill)
    plus an explicit marker list the stamp pass consumes — never guess from
    ROCK/MTN/PATH tile IDs later.
    """
    building_fill = "TOWN_PATH" if kind == "town" else "SHORT_GRASS"
    terrain = list(cats)
    markers: list[dict[str, Any]] = []
    for i, c in enumerate(cats):
        if c not in STRUCTURAL_CATEGORIES:
            continue
        x, y = i % w, i // w
        markers.append({"x": x, "y": y, "category": c, "cell": i})
        if c == "BUILDING":
            terrain[i] = building_fill
        else:
            terrain[i] = STRUCTURAL_FILL.get(c, building_fill)
    return terrain, markers


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


def adapt_regions(cats: list[str], w: int, h: int) -> list[str]:
    """Border-connected water = ocean; inland pools → short grass; coast tag."""
    adapted = list(cats)
    seeds = []
    for x in range(w):
        for y in (0, h - 1):
            i = y * w + x
            if adapted[i] == "WATER":
                seeds.append(i)
    for y in range(h):
        for x in (0, w - 1):
            i = y * w + x
            if adapted[i] == "WATER":
                seeds.append(i)
    ocean = flood(adapted, w, h, seeds, {"WATER"})
    for i, c in enumerate(adapted):
        if c == "WATER" and i not in ocean:
            adapted[i] = "SHORT_GRASS"
        elif c == "WATER":
            adapted[i] = "WATER"
    # Cliff touching ocean → coast cliff
    for i, c in enumerate(adapted):
        if c != "CLIFF":
            continue
        x, y = i % w, i // w
        if any(
            0 <= x + dx < w and 0 <= y + dy < h
            and adapted[(y + dy) * w + (x + dx)] == "WATER"
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
        ):
            adapted[i] = "COAST_CLIFF"
    return adapted


def category_to_block(
    cat: str,
    x: int,
    y: int,
    w: int,
    h: int,
    cats: list[str],
    ledge_dir: Optional[str] = None,
) -> int:
    """Lookup + light context (south shoreline, west water, ledge direction)."""
    def touches_water(xx: int, yy: int) -> bool:
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nx, ny = xx + dx, yy + dy
            if 0 <= nx < w and 0 <= ny < h and cats[ny * w + nx] == "WATER":
                return True
        return False

    if cat == "WATER":
        # 107 is Cinnabar's south shoreline (water + rock fringe). Only use it
        # when land is directly north — open ocean stays plain 67.
        above = cats[(y - 1) * w + x] if y > 0 else "WATER"
        if above != "WATER":
            return G1["WATER_S"]
        if x + 1 < w and cats[y * w + x + 1] == "COAST_CLIFF":
            return G1["WATER_W"]
        return G1["WATER"]
    if cat == "LEDGE":
        return LEDGE_DIR_TO_GEN1.get(ledge_dir or "S", G1["LEDGE_S"])
    if cat in ("SHORT_GRASS", "TOWN_PATH", "SAND", "PATH"):
        # Land/plaza/sand abutting ocean → shore transition.
        if touches_water(x, y):
            return G1["SHORE"]
        return CATEGORY_TO_GEN1[cat]
    if cat == "PIER":
        # Pier stays PATH even when surrounded by water (that's the point).
        return G1["PATH"]
    return CATEGORY_TO_GEN1.get(cat, G1["GRASS"])


def compress_vertical(cells: list[Any], w: int, h: int, step: int) -> tuple[list[Any], int]:
    if step <= 1:
        return cells, h
    kept: list[Any] = []
    new_h = 0
    for y in range(0, h - 1, 2 * step):
        for dy in range(2):
            yy = min(y + dy, h - 1)
            kept.extend(cells[yy * w: (yy + 1) * w])
            new_h += 1
    if new_h % 2 == 1:
        kept.extend(cells[(h - 1) * w: h * w])
        new_h += 1
    return kept, new_h


def compress_y_map(h: int, step: int) -> dict[int, int]:
    """Map original row y → compressed row y (first kept occurrence wins)."""
    if step <= 1:
        return {y: y for y in range(h)}
    mapping: dict[int, int] = {}
    new_y = 0
    for y in range(0, h - 1, 2 * step):
        for dy in range(2):
            yy = min(y + dy, h - 1)
            mapping.setdefault(yy, new_y)
            new_y += 1
    if new_y % 2 == 1:
        mapping.setdefault(h - 1, new_y)
    return mapping


def remap_structural_coords(
    markers: list[dict[str, Any]], y_map: dict[int, int], cell_w: int, cell_h: int
) -> list[dict[str, Any]]:
    """Project FRLG cell markers through vertical compress → Gen1 block coords."""
    # Prefer DOOR over BUILDING when both land in the same block.
    rank = {"DOOR": 0, "CAVE": 1, "SIGN": 2, "BUILDING": 3}
    pending: list[dict[str, Any]] = []
    for m in markers:
        oy = int(m["y"])
        if oy not in y_map:
            # Row dropped by compress — snap to nearest kept neighbor.
            nearest = min(y_map.keys(), key=lambda yy: abs(yy - oy))
            cy = y_map[nearest]
        else:
            cy = y_map[oy]
        cx = int(m["x"])
        if not (0 <= cx < cell_w and 0 <= cy < cell_h):
            continue
        bx, by = cx // 2, cy // 2
        pending.append({
            "category": m["category"],
            "cell": [cx, cy],
            "block": [bx, by],
            "frlg_cell": [int(m["x"]), int(m["y"])],
        })
    pending.sort(key=lambda m: (m["block"][1], m["block"][0], rank.get(m["category"], 9)))
    out: list[dict[str, Any]] = []
    seen_cat: set[tuple[int, int, str]] = set()
    door_blocks: set[tuple[int, int]] = set()
    for m in pending:
        bx, by = m["block"]
        cat = m["category"]
        key = (bx, by, cat)
        if key in seen_cat:
            continue
        if cat == "BUILDING" and (bx, by) in door_blocks:
            continue
        seen_cat.add(key)
        if cat == "DOOR":
            door_blocks.add((bx, by))
        out.append(m)
    return out


def downsample(
    blocks: list[int],
    w: int,
    h: int,
    ledge_dirs: Optional[list[Optional[str]]] = None,
) -> tuple[int, int, list[int], list[Optional[str]]]:
    bw, bh = w // 2, h // 2
    prio = {
        G1["WATER"]: 6, G1["WATER_S"]: 6, G1["WATER_W"]: 6,
        G1["STAIR"]: 10, G1["PATH"]: 8, G1["DIRT"]: 8, G1["COBBLE"]: 8,
        G1["LEDGE"]: 10, G1["LEDGE_S"]: 10, G1["LEDGE_W"]: 10, G1["LEDGE_E"]: 10,
        G1["FACE"]: 7, G1["MTN"]: 6, G1["CLIFF_W"]: 7, G1["RIDGE"]: 7,
        G1["TREE"]: 8, G1["ROCK"]: 3, G1["TALL"]: 3, G1["GRASS"]: 1, G1["SHORE"]: 7,
    }
    building = set(PC + MART + HOUSE)
    dir_prio = {"S": 4, "E": 3, "W": 3, "N": 1}
    out: list[int] = []
    out_dirs: list[Optional[str]] = []
    for by in range(bh):
        for bx in range(bw):
            idxs = [(by * 2 + dy) * w + (bx * 2 + dx) for dy in range(2) for dx in range(2)]
            quad = [blocks[i] for i in idxs]
            bld = [q for q in quad if q in building]
            if bld:
                out.append(Counter(bld).most_common(1)[0][0])
                out_dirs.append(None)
                continue
            if G1["STAIR"] in quad:
                out.append(G1["STAIR"])
                out_dirs.append(None)
                continue
            ocean = [q for q in quad if q in OCEANISH]
            critical = [
                q for q in quad
                if q in (G1["PATH"], G1["DIRT"], G1["COBBLE"], G1["STAIR"], G1["TREE"], G1["SHORE"])
                or q in LEDGE_BLOCKS
            ]
            if ocean and not critical:
                if len(ocean) >= 2:
                    out.append(max(set(ocean), key=lambda t: (ocean.count(t), prio.get(t, 0))))
                    out_dirs.append(None)
                    continue
            if critical:
                pick = max(set(critical), key=lambda t: (critical.count(t), prio.get(t, 0)))
                out.append(pick)
                if pick in LEDGE_BLOCKS and ledge_dirs is not None:
                    cands = [ledge_dirs[i] for i in idxs if ledge_dirs[i]]
                    out_dirs.append(
                        max(cands, key=lambda d: (cands.count(d), dir_prio.get(d or "", 0)))
                        if cands else None
                    )
                else:
                    out_dirs.append(None)
                continue
            if ocean:
                out.append(max(set(ocean), key=lambda t: (ocean.count(t), prio.get(t, 0))))
                out_dirs.append(None)
                continue
            out.append(max(set(quad), key=lambda t: (quad.count(t), prio.get(t, 0))))
            out_dirs.append(None)
    return bw, bh, out, out_dirs


def setb(blocks: list[int], w: int, x: int, y: int, v: int) -> None:
    if 0 <= x < w and 0 <= y < len(blocks) // w:
        blocks[y * w + x] = v


def stamp_footprint(
    blocks: list[int], w: int, bx: int, by: int, kind: str
) -> dict[str, Any]:
    """Write ONLY roof/wall/door tiles — never clear a bounding box of PATH/GRASS.

    Returns stamp metadata including front door and optional back door.
    """
    spec = BUILDING_DEFS[kind]
    rows = spec["rows"]
    for dy, row in enumerate(rows):
        for dx, tile in enumerate(row):
            setb(blocks, w, bx + dx, by + dy, tile)
    dox, doy = spec["door_offset"]
    door = (bx + dox, by + doy)
    out: dict[str, Any] = {
        "kind": kind,
        "block": [bx, by],
        "door": list(door),
        "size": list(spec["size"]),
        "warp_face": spec["warp_face"],
        "has_back_door": bool(spec.get("has_back_door")),
        "dest": spec.get("dest"),
    }
    # Threshold = one block south of the door face (PATH apron / pier mat).
    out["threshold"] = [door[0], door[1] + 1]
    if spec.get("has_back_door"):
        # North-face door: mirror door tile onto the row above the roof? For a
        # 2-row stamp the back door sits on the north edge (roof row), center.
        # Replace center roof with a door-capable tile and record warp.
        back_x = door[0]
        back_y = by  # north face of stamp
        # Use the same door graphic as the front (HOUSE mid / PC bottom-left).
        door_tile = rows[-1][dox] if kind != "pc" else 124
        setb(blocks, w, back_x, back_y, door_tile)
        out["back_door"] = [back_x, back_y]
        out["back_dest"] = spec.get("back_dest")
    return out


def ensure_front_apron(
    blocks: list[int], w: int, h: int, stamp: dict[str, Any], fill: int
) -> None:
    """Make the threshold row walkable without wiping existing PATH/GRASS rings.

    Only replaces non-walkable / ocean under the stamp width — never overwrites
    PATH, GRASS, DIRT, or SHORE that the semantic pass already produced.
    """
    bx, by = stamp["block"]
    sw, sh = stamp["size"]
    ty = by + sh  # first row south of footprint
    if ty >= h:
        return
    preserve = {
        G1["PATH"], G1["GRASS"], G1["TALL"], G1["DIRT"], G1["SHORE"], G1["COBBLE"],
        G1["ROCK"], G1["STAIR"],
    }
    for dx in range(sw):
        x = bx + dx
        if not (0 <= x < w):
            continue
        cur = blocks[ty * w + x]
        if cur in preserve:
            continue
        if cur in OCEANISH or cur not in WALKABLE:
            # Harbor pier may convert ocean → PATH; houses prefer grass fill
            # only when the cell is blocked — leave sand (DIRT) alone (preserve).
            if cur in OCEANISH and stamp["kind"] == "harbor":
                blocks[ty * w + x] = G1["PATH"]
            elif cur not in OCEANISH and cur not in WALKABLE:
                blocks[ty * w + x] = fill


def scrub_orphan_water_s(blocks: list[int], w: int, h: int) -> int:
    """Replace floating WATER_S (107) islets with plain WATER.

    107 is Cinnabar's land→ocean fringe (rocks in the water tile). It should
    only sit next to real land — not as a 1–3 tile rock island in open ocean.
    """
    landish = {
        G1["GRASS"], G1["TALL"], G1["DIRT"], G1["PATH"], G1["COBBLE"],
        G1["ROCK"], G1["SHORE"], G1["STAIR"], G1["MTN"], G1["FACE"],
        G1["CLIFF_W"], G1["RIDGE"], G1["RIDGE_E"], G1["TREE"], G1["LEDGE"],
        G1["LEDGE_S"], G1["LEDGE_W"], G1["LEDGE_E"],
    } | set(PC + MART + HOUSE)
    fixed = 0
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if blocks[i] != G1["WATER_S"]:
                continue
            touches_land = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and blocks[ny * w + nx] in landish:
                    touches_land = True
                    break
            if not touches_land:
                blocks[i] = G1["WATER"]
                fixed += 1
    return fixed


def thin_trees(blocks: list[int], w: int, h: int) -> tuple[int, int]:
    """Keep tree *clusters*, break solid walls.

    Pass 1: isolated trees (0–1 neighbors) → grass.
    Pass 2: in a dense 3×3 (5+ trees), checkerboard-thin extras → grass.
    """
    removed_iso = 0
    for y in range(h):
        for x in range(w):
            if blocks[y * w + x] != G1["TREE"]:
                continue
            neighbors = 0
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and blocks[ny * w + nx] == G1["TREE"]:
                    neighbors += 1
            if neighbors < 2:
                blocks[y * w + x] = G1["GRASS"]
                removed_iso += 1

    removed_dense = 0
    for y in range(h):
        for x in range(w):
            if blocks[y * w + x] != G1["TREE"]:
                continue
            dens = 0
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and blocks[ny * w + nx] == G1["TREE"]:
                        dens += 1
            if dens >= 5 and (x + y) % 2 == 1:
                blocks[y * w + x] = G1["GRASS"]
                removed_dense += 1
    return removed_iso, removed_dense


def add_grass_patches(blocks: list[int], w: int, h: int, building_stamps: list[dict]) -> int:
    """Convert some edge COBBLE/PATH to GRASS for Pewter-style variety.

    On a 12×12 town five stamps cover almost everything if we pad widely —
    only exclude the building footprint itself (+ door apron row), then
    grass-ify cobble/path that touches cliffs/trees/water or sits on the rim.
    """
    footprint: set[tuple[int, int]] = set()
    for s in building_stamps:
        bx, by = s["block"]
        sw, sh = s.get("size") or (2, 2)
        for dy in range(sh + 1):  # footprint + one apron row south of door
            for dx in range(sw):
                nx, ny = bx + dx, by + dy
                if 0 <= nx < w and 0 <= ny < h:
                    footprint.add((nx, ny))

    convertible = {G1["COBBLE"], G1["PATH"]}
    periphery = {
        G1["MTN"], G1["FACE"], G1["CLIFF_W"], G1["TREE"], G1["WATER"],
        G1["WATER_S"], G1["WATER_W"], G1["SHORE"], G1["DIRT"], G1["GRASS"],
    }
    converted = 0
    for y in range(h):
        for x in range(w):
            if blocks[y * w + x] not in convertible:
                continue
            if (x, y) in footprint:
                continue
            on_rim = x <= 1 or y <= 0 or x >= w - 2 or y >= h - 3
            touches_edge = on_rim
            if not touches_edge:
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or blocks[ny * w + nx] in periphery:
                        touches_edge = True
                        break
            # Keep a continuous plaza: only scatter (~half of eligible cells).
            if touches_edge and (x + 2 * y) % 2 == 0:
                blocks[y * w + x] = G1["GRASS"]
                converted += 1
    return converted


def pad_south_ocean(blocks: list[int], w: int, h: int, pad: int) -> tuple[list[int], int]:
    """Append ocean rows so the harbor/pier has room (12×10 → 12×12)."""
    if pad <= 0:
        return blocks, h
    out = list(blocks)
    for _ in range(pad):
        out.extend([G1["WATER"]] * w)
    new_h = h + pad
    for y in range(h, new_h):
        for x in range(w):
            i = y * w + x
            above = out[(y - 1) * w + x]
            if above == G1["PATH"]:
                out[i] = G1["PATH"] if y == h else G1["WATER"]
            elif above not in OCEANISH:
                out[i] = G1["WATER_S"]
            else:
                out[i] = G1["WATER_S"] if y == new_h - 1 else G1["WATER"]
    return out, new_h


def stamp_town(blocks: list[int], bw: int, bh: int, warps: list[dict], spec: dict) -> list[dict]:
    interest = spec.get("warps") or {}
    stamped: list[dict] = []
    pc = None
    houses: list[tuple[int, int, str]] = []  # cx, cy, dest_frag
    harbor = None
    for warp in warps:
        dest = str(warp.get("dest_map") or "")
        cx, cy = int(warp["x"]), int(warp["y"])
        kind = None
        for frag, k in interest.items():
            if frag in dest:
                kind = k
                break
        if kind == "pc":
            bx = max(3, min(cx // 2 - 1, bw - 4))
            by = max(1, min(cy // 2 - 1, 2))
            s = stamp_footprint(blocks, bw, bx, by, "pc")
            s["cell"] = [cx, cy]
            stamped.append(s)
            ensure_front_apron(blocks, bw, bh, s, G1["GRASS"])
            pc = (bx, by)
        elif kind == "house":
            houses.append((cx, cy, dest))
        elif kind == "harbor":
            harbor = (cx, cy)

    if spec.get("add_mart") and pc:
        mx, my = min(bw - 2, pc[0] + 2), pc[1]
        s = stamp_footprint(blocks, bw, mx, my, "mart")
        stamped.append(s)
        ensure_front_apron(blocks, bw, bh, s, G1["GRASS"])

    reserved: set[tuple[int, int]] = set()
    for s in stamped:
        bx, by = s["block"]
        sw, sh = s["size"]
        for dy in range(sh):
            for dx in range(sw):
                reserved.add((bx + dx, by + dy))

    for cx, cy, dest_frag in houses:
        sw, sh = BUILDING_DEFS["house"]["size"]
        bx = max(2, min(cx // 2, bw - sw))
        by = max(4, min(cy // 2 - 1, 5))
        for _ in range(8):
            if not any((bx + dx, by + dy) in reserved for dy in range(sh) for dx in range(sw)):
                break
            bx = min(bw - sw, bx + 1) if cx >= 12 else max(2, bx - 1)
        # Footprint only — do NOT grass-fill the rectangle (that killed side PATH).
        s = stamp_footprint(blocks, bw, bx, by, "house")
        s["cell"] = [cx, cy]
        s["frlg_dest"] = dest_frag  # intentional exterior until interiors land
        stamped.append(s)
        ensure_front_apron(blocks, bw, bh, s, G1["GRASS"])
        for dy in range(sh):
            for dx in range(sw):
                reserved.add((bx + dx, by + dy))

    if harbor:
        cx, cy = harbor
        sw, sh = BUILDING_DEFS["harbor"]["size"]
        mid = cx // 2
        # Sit on the water's edge: door near south, roof above, pier below.
        # With pad_south=2 (12×12), this lands ~rows 7–8 + pier 9–11.
        door_row = min(bh - 3, max(bh - 5, cy // 2 - 1))
        roof_by = max(0, door_row - 1)
        bx = max(1, min(mid - 1, bw - sw))
        s = stamp_footprint(blocks, bw, bx, roof_by, "harbor")
        s["cell"] = [cx, cy]
        s["threshold"] = [s["door"][0], min(bh - 1, s["door"][1] + 1)]
        stamped.append(s)
        # Pier: from just above the door through several rows past the threshold.
        pier_start = max(0, s["door"][1] - 1)
        pier_end = min(bh, s["threshold"][1] + 4)
        for y in range(pier_start, pier_end):
            for dx in range(sw):
                x = bx + dx
                if not (0 <= x < bw):
                    continue
                # Don't overwrite the building footprint itself.
                if roof_by <= y < roof_by + sh and bx <= x < bx + sw:
                    continue
                cur = blocks[y * bw + x]
                if cur in OCEANISH or cur in (
                    G1["SHORE"], G1["COBBLE"], G1["GRASS"], G1["PATH"], G1["DIRT"],
                    G1["WATER_S"],
                ):
                    blocks[y * bw + x] = G1["PATH"]
        ensure_front_apron(blocks, bw, bh, s, G1["PATH"])
        for dy in range(sh):
            for dx in range(sw):
                reserved.add((bx + dx, roof_by + dy))

    return stamped


def remap_ledge_coords(
    ledge_dirs: list[Optional[str]], w: int, h: int, y_map: dict[int, int], cell_h: int
) -> list[dict[str, Any]]:
    """Project FRLG LEDGE cells (with direction) → Gen1 block coords.

    Kept as an explicit list so stamp/collision passes never have to recover
    direction from a flattened tile ID. When multiple dirs land on one block,
    prefer S then E/W then N (Gen1 hop rules).
    """
    dir_rank = {"S": 0, "E": 1, "W": 1, "N": 2}
    best: dict[tuple[int, int], dict[str, Any]] = {}
    for i, d in enumerate(ledge_dirs):
        if not d:
            continue
        ox, oy = i % w, i // w
        if oy not in y_map:
            nearest = min(y_map.keys(), key=lambda yy: abs(yy - oy))
            cy = y_map[nearest]
        else:
            cy = y_map[oy]
        if not (0 <= ox < w and 0 <= cy < cell_h):
            continue
        bx, by = ox // 2, cy // 2
        cand = {
            "x": bx, "y": by, "dir": d,
            "block": LEDGE_DIR_TO_GEN1.get(d, G1["LEDGE_S"]),
            "frlg_cell": [ox, oy],
        }
        key = (bx, by)
        prev = best.get(key)
        if prev is None or dir_rank.get(d, 9) < dir_rank.get(prev["dir"], 9):
            best[key] = cand
    return [best[k] for k in sorted(best.keys(), key=lambda t: (t[1], t[0]))]


def remap_map(map_id: str, spec: dict, gen: list[int], sev: list[int]) -> dict[str, Any]:
    cw, ch = spec["cells"]
    cells = load_cells(f"{LAYOUTS}/{spec['layout']}.bin", cw, ch)
    UNKNOWN_BEH.clear()
    UNKNOWN_BEH_SAMPLES.clear()
    classified = []
    for i, (mid, coll) in enumerate(cells):
        x, y = i % cw, i // cw
        classified.append(
            classify_cell(
                mid, coll, behavior(mid, gen, sev), kind=spec["kind"], x=x, y=y
            )
        )
    cats = [c for c, _ in classified]
    ledge_dirs: list[Optional[str]] = [d for _, d in classified]
    cats = adapt_regions(cats, cw, ch)

    # Structural markers leave the tile grid; fill with cobble/grass underneath.
    raw_hist = dict(Counter(cats))
    terrain_cats, structural_frlg = split_structural(cats, cw, ch, kind=spec["kind"])

    cell_blocks = [
        category_to_block(
            terrain_cats[i], i % cw, i // cw, cw, ch, terrain_cats, ledge_dirs[i]
        )
        for i in range(cw * ch)
    ]

    # No town west-edge MTN/FACE override — that was flattening real cliff/stair
    # semantics. FRLG One Island stairs are mid-map (beh 0x2A), not the west wall;
    # west columns are genuine cliffs and should stay CLIFF→MTN/COAST from lookup.

    v_step = int(spec.get("v_compress") or 1)
    y_map = compress_y_map(ch, v_step)
    cell_blocks, ch2 = compress_vertical(cell_blocks, cw, ch, v_step)
    ledge_c, _ = compress_vertical(ledge_dirs, cw, ch, v_step)
    bw, bh, blocks, _ledge_blocks = downsample(cell_blocks, cw, ch2, ledge_c)

    ledge_cells = sum(1 for d in ledge_dirs if d)
    print(f"  LEDGE cells before downsample: {ledge_cells}")

    # Explicit lists for second pass — never recover from ROCK/MTN/PATH/LEDGE IDs.
    structural = remap_structural_coords(structural_frlg, y_map, cw, ch2)
    ledges = remap_ledge_coords(ledge_dirs, cw, ch, y_map, ch2)
    print(f"  LEDGE blocks after downsample: {len(ledges)}")

    # Paint directional ledge tiles from the marker list (authoritative).
    for L in ledges:
        x, y = L["x"], L["y"]
        if 0 <= x < bw and 0 <= y < bh:
            i = y * bw + x
            if blocks[i] not in OCEANISH and blocks[i] != G1["STAIR"]:
                blocks[i] = L["block"]

    # Pad south before stamping so harbor/pier can sit on the water line.
    pad = int(spec.get("pad_south") or 0)
    if pad:
        blocks, bh = pad_south_ocean(blocks, bw, bh, pad)
        print(f"  pad_south +{pad} → {bw}x{bh}")

    stamped = []
    if spec["kind"] == "town":
        with open(f"{LAYOUTS}/{spec['map_json']}.map.json", encoding="utf-8") as f:
            warps = list(json.load(f).get("warp_events") or [])
        # FRLG One Island warps: PC, HOUSE1, HOUSE2, HARBOR — two mid-island
        # houses are real; harbor is the pier building (HOUSE footprint + pier).
        stamped = stamp_town(blocks, bw, bh, warps, spec)

    # Post-stamp: thin tree walls, edge grass, orphan WATER_S, door aprons.
    iso, dense = thin_trees(blocks, bw, bh)
    if iso or dense:
        print(f"  thin_trees: -{iso} isolated, -{dense} dense → "
              f"{blocks.count(G1['TREE'])} trees left")
    grass_n = add_grass_patches(blocks, bw, bh, stamped) if stamped else 0
    if grass_n:
        print(f"  grass patches: {grass_n} cobble→grass")

    orphan_107 = scrub_orphan_water_s(blocks, bw, bh)
    if orphan_107:
        print(f"  scrubbed {orphan_107} orphan WATER_S (107) → WATER")
    for s in stamped:
        ensure_front_apron(
            blocks, bw, bh, s,
            G1["PATH"] if s["kind"] == "harbor" else G1["COBBLE"],
        )

    unknown = {f"0x{b:02X}": n for b, n in sorted(UNKNOWN_BEH.items())}
    if unknown:
        print(f"  WARN unknown behaviors (not silently ignored): {unknown}")
        for b, samples in sorted(UNKNOWN_BEH_SAMPLES.items()):
            print(f"    0x{b:02X} samples (mid,x,y): {samples}")

    return {
        "id": map_id,
        "frlg_cells": [cw, ch],
        "gen1_size": [bw, bh],
        "category_hist": raw_hist,
        "terrain_hist": dict(Counter(terrain_cats)),
        "structural": structural,
        "structural_frlg_count": len(structural_frlg),
        "ledges": ledges,
        "ledge_dir_hist": dict(Counter(d for d in ledge_dirs if d)),
        "unknown_behaviors": unknown,
        "block_hist": {str(k): v for k, v in Counter(blocks).items()},
        "water": sum(1 for b in blocks if b in OCEANISH),
        "water_s": blocks.count(G1["WATER_S"]),
        "orphan_107_scrubbed": orphan_107,
        "tall": blocks.count(G1["TALL"]),
        "v_compress": v_step,
        "stair": blocks.count(G1["STAIR"]),
        "cliffish": sum(1 for b in blocks if b in (G1["MTN"], G1["FACE"], G1["CLIFF_W"], G1["RIDGE"])),
        "buildings": stamped,
        "width": bw,
        "height": bh,
        "blocks": blocks,
        "categories_cell": cats,  # pre-split (includes structural labels for ASCII)
        "frlg_w": cw,
        "frlg_h": ch,
    }



def ascii_cats(cats: list[str], w: int, h: int, step: int = 1) -> list[str]:
    ch = {
        "WATER": "~", "TALL_GRASS": "T", "SHORT_GRASS": ".", "TOWN_PATH": "=",
        "SAND": "s", "PATH": "=", "PIER": "=", "TREE": "*", "CLIFF": "#",
        "COAST_CLIFF": "C", "LEDGE": "L", "STAIR": "S", "ROCK_DECK": "r",
        "BUILDING": "B", "DOOR": "D", "SIGN": "!", "CAVE": "v", "BLOCKED": "X",
    }
    lines = []
    for y in range(0, h, step):
        lines.append(f"{y:03d} " + "".join(ch.get(cats[y * w + x], "?") for x in range(w)))
    return lines


def ascii_blocks(blocks: list[int], w: int, h: int) -> list[str]:
    ch = {
        67: "~", 107: "~", 24: "~", 1: ".", 11: "#", 10: "s", 7: "=", 85: "=",
        44: "M", 41: "F", 100: "C", 123: "r", 26: "L", 55: "L", 39: "L",
        47: "S", 15: "*",
        63: "R", 59: "E", 31: "o",
        32: "P", 33: "P", 124: "P", 114: "P", 115: "A",
        12: "H", 13: "H", 14: "H", 16: "H", 58: "H", 0: "H",
    }
    return [f"{y:02d} " + "".join(ch.get(blocks[y * w + x], "?") for x in range(w)) for y in range(h)]


def render_preview(blocks: list[int], w: int, h: int, path: str) -> None:
    tilesets = te.load_generated("tilesets")
    ow = tilesets["OVERWORLD"]
    atlas, columns, _ = te.build_block_atlas(ow, te.PALETTES["dmg"])
    img = Image.new("RGB", (w * te.BLOCK_PX, h * te.BLOCK_PX), (0, 0, 0))
    for i, bid in enumerate(blocks):
        bid = int(bid)
        if bid < 0 or bid >= len(te.as_list(ow.get("blocks"))):
            continue
        ax, ay = (bid % columns) * te.BLOCK_PX, (bid // columns) * te.BLOCK_PX
        tile = atlas.crop((ax, ay, ax + te.BLOCK_PX, ay + te.BLOCK_PX))
        bx, by = i % w, i // w
        img.paste(tile, (bx * te.BLOCK_PX, by * te.BLOCK_PX))
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(path)


def write_lookup_doc(outdir: str) -> None:
    rows = []
    for cat in TERRAIN_CATEGORIES:
        rows.append({
            "category": cat,
            "gen1_block": CATEGORY_TO_GEN1[cat],
            "notes": CATEGORY_NOTES.get(cat, ""),
            "kind": "terrain",
        })
    for cat in sorted(STRUCTURAL_CATEGORIES):
        rows.append({
            "category": cat,
            "gen1_block": None,
            "fill": STRUCTURAL_FILL[cat],
            "notes": CATEGORY_NOTES.get(cat, ""),
            "kind": "structural",
        })
    doc = {
        "approach": "layout_extraction_via_behaviors",
        "not": "tile_art_conversion",
        "frlg_source": "metatile behavior bits 0-8 (u32 attrs, primary=640)",
        "gen1_source": "OVERWORLD blocks proven in Cinnabar/Pewter/Route4/Route21",
        "terrain_lookup": {c: CATEGORY_TO_GEN1[c] for c in TERRAIN_CATEGORIES},
        "structural_categories": sorted(STRUCTURAL_CATEGORIES),
        "structural_fill": STRUCTURAL_FILL,
        "ledge_directions": {
            "frlg": {f"0x{k:02X}": v for k, v in JUMP_DIR.items()},
            "gen1_blocks": LEDGE_DIR_TO_GEN1,
            "note": "Gen1 HandleLedges has down/left/right only; N is visual topology",
        },
        "lookup": rows,
        "building_stamps": {
            k: {
                "size": list(v["size"]),
                "rows": [list(r) for r in v["rows"]],
                "warp_face": v["warp_face"],
                "has_back_door": v["has_back_door"],
                "dest": v.get("dest"),
            }
            for k, v in BUILDING_DEFS.items()
        },
        "behavior_rules": [
            "WATER_BEH → WATER",
            "0x02 TALL_GRASS → TALL_GRASS",
            "0x21 SAND → SAND",
            "MB_JUMP_EAST/WEST/NORTH/SOUTH → LEDGE + dir (E/W/N/S)",
            "0x2A ROCK_STAIRS → STAIR",
            "DOOR/WARP/SIGN/CAVE → STRUCTURAL markers (not tile IDs)",
            "cliff mids / solid low mids → CLIFF (→ COAST_CLIFF if touches ocean)",
            "secondary solid coll → BUILDING marker + SHORT_GRASS fill",
            "else walkable → SHORT_GRASS",
        ],
    }
    path = os.path.join(outdir, "semantic_lookup.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    print(f"Wrote {path}")

    md = ["# FRLG → Gen1 semantic lookup", "",
          "Layout extraction via metatile **behaviors**, not tile art.", "",
          "## Terrain → Gen1 blocks", "",
          "| Category | Gen1 block | Notes |",
          "|----------|------------|-------|"]
    for r in rows:
        if r["kind"] != "terrain":
            continue
        md.append(f"| `{r['category']}` | **{r['gen1_block']}** | {r['notes']} |")
    md += ["", "## Structural (not baked into the tile grid)", "",
           "These become `(x, y, category)` markers. Grid cells get a walkable fill "
           "until the stamp pass places real buildings/doors/caves.", "",
           "| Category | Fill under marker | Notes |",
           "|----------|-------------------|-------|"]
    for r in rows:
        if r["kind"] != "structural":
            continue
        md.append(f"| `{r['category']}` | `{r['fill']}` → {CATEGORY_TO_GEN1[r['fill']]} | {r['notes']} |")
    md += ["", "## Ledge direction", "",
           "FRLG encodes jump direction as distinct behaviors "
           "(`MB_JUMP_EAST=0x38` … `MB_JUMP_SOUTH=0x3B`). "
           "That direction is carried as a second field — not flattened.", "",
           "| Dir | FRLG | Gen1 ledgeTile |",
           "|-----|------|----------------|",
           f"| S | `0x3B` | **{LEDGE_DIR_TO_GEN1['S']}** |",
           f"| W | `0x39` | **{LEDGE_DIR_TO_GEN1['W']}** |",
           f"| E | `0x38` | **{LEDGE_DIR_TO_GEN1['E']}** |",
           f"| N | `0x3A` | **{LEDGE_DIR_TO_GEN1['N']}** (visual only; Gen1 has no north hop) |",
           "", "## Building stamps (Gen1)", "",
           "Footprint-only (no bounding-box clear — preserves adjacent PATH/GRASS).",
           "`has_back_door` on a def adds a north-face door + second warp (Celadon-style).",
           "",
           *[
               f"- **{k}** {v['size'][0]}×{v['size'][1]} warp_face=`{v['warp_face']}` "
               f"has_back_door={v['has_back_door']} dest=`{v.get('dest')}`"
               for k, v in BUILDING_DEFS.items()
           ],
           "",
           "House exteriors stamp now; interiors (`SEVII_ONE_ISLAND_HOUSE1/2`) not "
           "registered in maps.lua yet — no front warps until those maps exist.",
           ""]
    with open(os.path.join(outdir, "semantic_lookup.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md))
    print(f"Wrote {os.path.join(outdir, 'semantic_lookup.md')}")


def build_town_warps(buildings: list[dict], bw: int, bh: int) -> list[dict[str, Any]]:
    """Cell-space warps for maps.lua (Gen1: widthCells = width*2).

    warp_face == "door"      → cells on the door block (PC/Mart Gen1 norm)
    warp_face == "threshold" → cells on the PATH apron south of the door
                               (harbor: block (6,9) not wall tile 58)
    has_back_door            → extra warp on north-face door → back_dest
    """
    cw, ch = bw * 2, bh * 2
    town_warps: list[dict[str, Any]] = []

    def add_warp_pair(bx: int, by: int, dest: str, note: str) -> None:
        # Two cells on the north half of the target block (flush to the face above).
        candidates = [
            {"x": bx * 2, "y": by * 2, "destMap": dest, "destWarp": 1},
            {"x": bx * 2 + 1, "y": by * 2, "destMap": dest, "destWarp": 1},
        ]
        for w in candidates:
            if not (0 <= w["x"] < cw and 0 <= w["y"] < ch):
                raise ValueError(
                    f"warp out of cell bounds for {bw}x{bh} blocks "
                    f"(cells {cw}x{ch}): {w} ({note})"
                )
            w["block"] = [bx, by]
            w["note"] = note
            town_warps.append(w)

    for b in buildings:
        dest = b.get("dest")
        if not dest:
            continue  # house exteriors until interiors are registered
        face = b.get("warp_face") or "door"
        if face == "threshold":
            tx, ty = b.get("threshold") or [b["door"][0], b["door"][1] + 1]
            if ty >= bh:
                tx, ty = b["door"]
            add_warp_pair(tx, ty, dest, f"{b['kind']} threshold")
        else:
            dx, dy = b["door"]
            # Match prior PC/Mart convention: cells on south half of door block.
            for w in (
                {"x": dx * 2 + 1, "y": dy * 2 + 1, "destMap": dest, "destWarp": 1},
                {"x": dx * 2 + 2, "y": dy * 2 + 1, "destMap": dest, "destWarp": 1},
            ):
                if not (0 <= w["x"] < cw and 0 <= w["y"] < ch):
                    raise ValueError(f"warp OOB: {w}")
                w["block"] = [w["x"] // 2, w["y"] // 2]
                w["note"] = f"{b['kind']} door"
                town_warps.append(w)

        if b.get("has_back_door") and b.get("back_door") and b.get("back_dest"):
            bx, by = b["back_door"]
            add_warp_pair(bx, by, b["back_dest"], f"{b['kind']} back_door")

    return town_warps


def write_live_layout(results: dict[str, Any], live_path: str) -> None:
    """Install sevii/layout_data.lua consumed by maps.lua."""
    town = results["SEVII_ONE_ISLAND"]
    kindle = results["SEVII_ONE_ISLAND_KINDLE_ROAD"]
    beach = results["SEVII_ONE_ISLAND_TREASURE_BEACH"]
    east_off, west_off = connection_pair_offsets(town["height"], kindle["height"])
    warps = build_town_warps(town.get("buildings") or [], town["width"], town["height"])

    parts = [
        "-- Auto-generated by sevii_semantic_remap.py",
        "-- FRLG behaviors → categories → Gen1 blocks (layout extraction)",
        "-- Warps use CELL coords (widthCells = width*2, heightCells = height*2).",
        "-- structural/ledges also under tile_mapping/semantic/",
        "return {",
    ]
    for map_id in MAPS:
        result = results[map_id]
        parts.append(f"  {map_id} = {{")
        parts.append(f"    width = {result['width']},")
        parts.append(f"    height = {result['height']},")
        parts.append("    blocks = {")
        w, h, blocks = result["width"], result["height"], result["blocks"]
        for y in range(h):
            row = blocks[y * w:(y + 1) * w]
            parts.append("      " + ", ".join(str(b) for b in row) + ",")
        parts += ["    },", "  },"]

    parts.append("  meta = {")
    parts.append("    SEVII_ONE_ISLAND = {")
    parts.append(f"      width = {town['width']},")
    parts.append(f"      height = {town['height']},")
    parts.append(f"      width_cells = {town['width'] * 2},")
    parts.append(f"      height_cells = {town['height'] * 2},")
    parts.append('      warp_coord_space = "cells",  -- NOT blocks; see Map.widthCells')
    parts.append(f"      frlg_cells = {{ {town['frlg_w']}, {town['frlg_h']} }},")
    parts.append("      v_compress = 1,")
    parts.append("      south_offset = 0,")
    parts.append(f"      east_offset = {east_off},  -- = -kindle.west_offset")
    parts.append("      warps = {")
    for w in warps:
        bx, by = w["block"]
        parts.append(
            "        { "
            f"x = {w['x']}, y = {w['y']}, "
            f'destMap = "{w["destMap"]}", destWarp = {w["destWarp"]} '
            f"}},  -- cell; block ({bx},{by})"
        )
    parts += ["      },", "    },"]
    parts.append("    SEVII_ONE_ISLAND_KINDLE_ROAD = {")
    parts.append(f"      width = {kindle['width']},")
    parts.append(f"      height = {kindle['height']},")
    parts.append(f"      width_cells = {kindle['width'] * 2},")
    parts.append(f"      height_cells = {kindle['height'] * 2},")
    parts.append(f"      frlg_cells = {{ {kindle['frlg_w']}, {kindle['frlg_h']} }},")
    parts.append(f"      v_compress = {kindle.get('v_compress', 1)},")
    parts.append(f"      west_offset = {west_off},  -- = -town.east_offset")
    parts.append("    },")
    parts.append("    SEVII_ONE_ISLAND_TREASURE_BEACH = {")
    parts.append(f"      width = {beach['width']},")
    parts.append(f"      height = {beach['height']},")
    parts.append(f"      width_cells = {beach['width'] * 2},")
    parts.append(f"      height_cells = {beach['height'] * 2},")
    parts.append(f"      frlg_cells = {{ {beach['frlg_w']}, {beach['frlg_h']} }},")
    parts.append("      v_compress = 1,")
    parts.append("      north_offset = 0,")
    parts.append("    },")
    parts += ["  },", "}", ""]

    os.makedirs(os.path.dirname(live_path) or ".", exist_ok=True)
    with open(live_path, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    print(f"Wrote live layout {live_path}")
    print(f"  town warps (cell space, map cells "
          f"{town['width']*2}x{town['height']*2}):")
    for w in warps:
        print(f"    cell ({w['x']},{w['y']}) block {w['block']} "
              f"[{w.get('note','')}] → {w['destMap']}")
    print(f"  connection pair: east={east_off} west={west_off} "
          f"(assert east == -west)")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument(
        "--outdir",
        default=os.path.join(here, "tile_mapping", "semantic"),
    )
    ap.add_argument(
        "--install",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Write sevii/layout_data.lua for in-game maps.lua (default: on)",
    )
    ap.add_argument(
        "--live",
        default=os.path.join(here, "sevii", "layout_data.lua"),
        help="Path for installed layout_data.lua",
    )
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)

    gen, sev = ensure_assets()
    write_lookup_doc(args.outdir)

    results = {}
    reports = []
    for map_id, spec in MAPS.items():
        print(f"\n{map_id}")
        result = remap_map(map_id, spec, gen, sev)
        results[map_id] = result
        print(f"  categories: {result['category_hist']}")
        print(f"  structural markers: {len(result['structural'])} "
              f"(frlg cells {result['structural_frlg_count']})")
        if result["ledge_dir_hist"]:
            print(f"  ledge dirs: {result['ledge_dir_hist']}")
        print(f"  gen1 {result['width']}x{result['height']} "
              f"water={result['water']} tall={result['tall']} "
              f"stair={result['stair']} cliffish={result['cliffish']}")
        # ASCII
        lines = ascii_cats(result["categories_cell"], result["frlg_w"], result["frlg_h"],
                           step=1 if result["frlg_h"] <= 40 else 4)
        with open(os.path.join(args.outdir, f"{map_id}_categories.txt"), "w") as f:
            f.write("\n".join(lines) + "\n")
        blines = ascii_blocks(result["blocks"], result["width"], result["height"])
        with open(os.path.join(args.outdir, f"{map_id}_gen1.txt"), "w") as f:
            f.write("\n".join(blines) + "\n")
        with open(os.path.join(args.outdir, f"{map_id}_structural.json"), "w") as f:
            json.dump({
                "structural": result["structural"],
                "ledges": result["ledges"],
            }, f, indent=2)
            f.write("\n")
        print("  gen1 ascii:")
        for ln in blines[:24]:
            print("   ", ln)
        render_preview(
            result["blocks"], result["width"], result["height"],
            os.path.join(args.outdir, f"{map_id}.png"),
        )
        # slim report without huge category arrays
        reports.append({k: v for k, v in result.items() if k not in ("blocks", "categories_cell")})

    # Emit lua-compatible block tables for optional handoff
    lua_path = os.path.join(args.outdir, "semantic_layout_data.lua")
    parts = [
        "-- Semantic first-pass remap (behaviors → Gen1 blocks)",
        "-- structural = stamp targets (not encoded as ROCK/MTN/PATH placeholders)",
        "-- ledges = {x,y,dir} from MB_JUMP_* (direction preserved)",
        "return {",
    ]
    for map_id, result in results.items():
        parts.append(f"  {map_id} = {{")
        parts.append(f"    width = {result['width']},")
        parts.append(f"    height = {result['height']},")
        parts.append("    blocks = {")
        w, h, blocks = result["width"], result["height"], result["blocks"]
        for y in range(h):
            row = blocks[y * w:(y + 1) * w]
            parts.append("      " + ", ".join(str(b) for b in row) + ",")
        parts.append("    },")
        parts.append("    structural = {")
        for m in result["structural"]:
            bx, by = m["block"]
            parts.append(
                f"      {{ x = {bx}, y = {by}, category = \"{m['category']}\" }},"
            )
        parts.append("    },")
        parts.append("    ledges = {")
        for L in result["ledges"]:
            parts.append(
                f"      {{ x = {L['x']}, y = {L['y']}, dir = \"{L['dir']}\" }},"
            )
        parts += ["    },", "  },"]
    parts += ["}", ""]
    with open(lua_path, "w") as f:
        f.write("\n".join(parts))
    print(f"\nWrote {lua_path}")

    report_path = os.path.join(args.outdir, "semantic_report.json")
    with open(report_path, "w") as f:
        json.dump({
            "approach": "behavior_categories_to_gen1_blocks",
            "terrain_lookup": CATEGORY_TO_GEN1,
            "structural_categories": sorted(STRUCTURAL_CATEGORIES),
            "structural_fill": STRUCTURAL_FILL,
            "ledge_dir_to_gen1": LEDGE_DIR_TO_GEN1,
            "maps": reports,
        }, f, indent=2)
        f.write("\n")
    print(f"Wrote {report_path}")

    if args.install:
        write_live_layout(results, args.live)
        print("\nInstalled for in-game. Full-restart Love, ferry from Vermilion.")
    else:
        print("\nDone (no --install). Review semantic_lookup.md + PNGs.")


if __name__ == "__main__":
    main()
