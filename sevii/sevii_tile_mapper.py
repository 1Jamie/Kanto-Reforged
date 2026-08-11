#!/usr/bin/env python3
"""Dump Gen1 OVERWORLD + FRLG Sevii tiles for side-by-side mapping.

Purpose
-------
Before inventing Sevii layouts, inventory what Gen1 (Red) OVERWORLD blocks we
actually have, what FRLG metatiles One Island uses, and scaffold a role map.

Outputs (under --outdir, default tile_mapping/):
  gen1_overworld_atlas.png   — all 128 OVERWORLD blocks labeled by ID
  gen1_buildings.png         — PC / MART / HOUSE stamps (current sevii stamps)
  gen1_role_picks.png        — curated Gen1 blocks by role (cliff, water, …)
  frlg_oneisland_metatiles.png — unique metatiles used on One Island map
  frlg_general_atlas.png     — primary tileset metatile strip (sampled)
  mapping_scaffold.json      — roles → gen1 candidates / frlg mids (edit me)
  cv_suggestions.json        — optional --cv histogram matches

Usage:
  python3 sevii_tile_mapper.py
  python3 sevii_tile_mapper.py --cv
  python3 sevii_tile_mapper.py --outdir tile_mapping
"""

from __future__ import annotations

import argparse
import json
import os
import struct
import sys
import urllib.request
from collections import Counter
from typing import Any, Optional

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools"))

import tiled_export as te  # noqa: E402

GITHUB = "https://raw.githubusercontent.com/pret/pokefirered/master"
NUM_PRIMARY_METATILES = 640
NUM_PRIMARY_TILES = 640
CACHE = "/tmp/frlg_tilesets"
LAYOUTS = "/tmp/sevii_layouts"

# Current Sevii stamps (must stay in sync with sevii_layout_gen.py)
PC = (32, 33, 124, 114)
MART = (32, 33, 124, 115)
HOUSE = (12, 13, 14, 16, 58, 0)

# Curated Gen1 OVERWORLD role picks for the comparison sheet
GEN1_ROLE_PICKS: dict[str, list[int]] = {
    "grass_plaza": [1],
    "tall_grass": [11],
    "dirt_sand": [10],
    "path": [7, 85],
    "water": [67, 107, 24],
    "shore": [31, 45, 30],
    "cliff_water_face": [100],
    "mountain_mass": [44, 40],
    "cliff_face": [41],
    "ridge_top": [63, 59, 62],
    "ledge_jump": [26],
    "stair": [47],
    "rock_deck": [123, 87],
    "tree": [15],
    "house_tiles": list(HOUSE),
    "pc_mart_tiles": list(PC + MART),
}

# Role scaffold: what FRLG One Island needs → Gen1 candidates to judge by eye
MAPPING_ROLES: list[dict[str, Any]] = [
    {
        "role": "OCEAN",
        "frlg": "MB_OCEAN_WATER 0x15 (e.g. mid 0x12b)",
        "gen1_candidates": [67, 107, 24],
        "notes": "Cinnabar water; pair 100|24 for west cliff",
        "pick": None,
    },
    {
        "role": "CLIFF_MASS",
        "frlg": "brown cliff mids 0x071/0x07c…",
        "gen1_candidates": [44, 40],
        "notes": "Pewter/Route 4 mountain fill",
        "pick": None,
    },
    {
        "role": "CLIFF_FACE",
        "frlg": "cliff abutting walkable deck",
        "gen1_candidates": [41],
        "notes": "Vertical face beside plaza",
        "pick": None,
    },
    {
        "role": "RIDGE",
        "frlg": "top of cliff / platform rim",
        "gen1_candidates": [63, 59, 62],
        "notes": "South-facing platform lip",
        "pick": None,
    },
    {
        "role": "STAIR",
        "frlg": "MB_ROCK_STAIRS 0x2A",
        "gen1_candidates": [47],
        "notes": "Outdoor stairs (Pewter/Route 4)",
        "pick": None,
    },
    {
        "role": "LEDGE",
        "frlg": "jump / tier drop rim",
        "gen1_candidates": [26],
        "notes": "One-way down; use with STAIR breaks",
        "pick": None,
    },
    {
        "role": "DECK",
        "frlg": "walkable plateau (PC tier)",
        "gen1_candidates": [123, 87, 1],
        "notes": "123=Cinnabar rock; 87=inland top; 1=grass plaza",
        "pick": None,
    },
    {
        "role": "SAND",
        "frlg": "MB_SAND 0x21",
        "gen1_candidates": [10],
        "notes": "Dirt/sand stand-in",
        "pick": None,
    },
    {
        "role": "TREE_BORDER",
        "frlg": "conifer rows on west/north",
        "gen1_candidates": [15],
        "notes": "Sparse border only — not a forest wall",
        "pick": None,
    },
    {
        "role": "PIER",
        "frlg": "wooden dock tongue",
        "gen1_candidates": [7, 85, 10],
        "notes": "Path/cobble/dirt; Gen1 has no wood pier art",
        "pick": None,
    },
    {
        "role": "HOUSE",
        "frlg": "One Island purple-roof house (~multi metatile)",
        "gen1_candidates": list(HOUSE),
        "gen1_stamp": "3x2 HOUSE (12,13,14 / 16,58,0)",
        "notes": "FRLG house is larger; Gen1 stamp is fixed 3×2 blocks",
        "pick": None,
    },
    {
        "role": "POKECENTER",
        "frlg": "Network Center (large orange roof)",
        "gen1_candidates": list(PC),
        "gen1_stamp": "2x2 PC (32,33 / 124,114)",
        "notes": "Gen1 PC is smaller than FRLG Network Center",
        "pick": None,
    },
    {
        "role": "MART",
        "frlg": "none on FRLG One Island (Gen1 QoL)",
        "gen1_candidates": list(MART),
        "gen1_stamp": "2x2 MART (32,33 / 124,115)",
        "notes": "Optional adjacent to PC",
        "pick": None,
    },
]


def fetch(url: str, dest: str) -> None:
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    if os.path.isfile(dest) and os.path.getsize(dest) > 0:
        return
    print(f"  fetch {url}")
    urllib.request.urlretrieve(url, dest)


def ensure_frlg_gfx() -> None:
    pairs = [
        ("general_tiles.png", "data/tilesets/primary/general/tiles.png"),
        ("general_metatiles.bin", "data/tilesets/primary/general/metatiles.bin"),
        ("general_attr.bin", "data/tilesets/primary/general/metatile_attributes.bin"),
        ("sevii_tiles.png", "data/tilesets/secondary/sevii_islands_123/tiles.png"),
        ("sevii_metatiles.bin", "data/tilesets/secondary/sevii_islands_123/metatiles.bin"),
        ("sevii_attr.bin", "data/tilesets/secondary/sevii_islands_123/metatile_attributes.bin"),
    ]
    for name, path in pairs:
        fetch(f"{GITHUB}/{path}", f"{CACHE}/{name}")
    # One Island layout for "used metatiles"
    fetch(f"{GITHUB}/data/layouts/OneIsland/map.bin", f"{LAYOUTS}/OneIsland.bin")


def font(size: int = 10) -> ImageFont.ImageFont:
    for path in (
        "/usr/share/fonts/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/TTF/DejaVuSans.ttf",
    ):
        if os.path.isfile(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def label_block(img: Image.Image, text: str, xy: tuple[int, int] = (1, 1)) -> None:
    draw = ImageDraw.Draw(img)
    # Shadow for readability on light/dark tiles
    draw.text((xy[0] + 1, xy[1] + 1), text, fill=(0, 0, 0), font=font(9))
    draw.text(xy, text, fill=(255, 255, 0), font=font(9))


def gen1_block_image(atlas: Image.Image, columns: int, block_id: int) -> Image.Image:
    ax = (block_id % columns) * te.BLOCK_PX
    ay = (block_id // columns) * te.BLOCK_PX
    return atlas.crop((ax, ay, ax + te.BLOCK_PX, ay + te.BLOCK_PX)).copy()


def dump_gen1_overworld(outdir: str, atlas: Image.Image, columns: int, n_blocks: int) -> None:
    """Labeled atlas: every OVERWORLD block with decimal ID."""
    rows = (n_blocks + columns - 1) // columns
    cell = te.BLOCK_PX + 12  # room for label strip
    out = Image.new("RGB", (columns * cell, rows * cell), (16, 16, 16))
    draw = ImageDraw.Draw(out)
    for i in range(n_blocks):
        col, row = i % columns, i // columns
        tile = gen1_block_image(atlas, columns, i)
        x, y = col * cell, row * cell
        out.paste(tile, (x, y))
        draw.rectangle([x, y + te.BLOCK_PX, x + te.BLOCK_PX - 1, y + cell - 1], fill=(32, 32, 32))
        draw.text((x + 2, y + te.BLOCK_PX + 1), str(i), fill=(255, 220, 80), font=font(9))
    path = os.path.join(outdir, "gen1_overworld_atlas.png")
    out.save(path)
    print(f"Wrote {path} ({n_blocks} blocks)")


def dump_gen1_buildings(outdir: str, atlas: Image.Image, columns: int) -> None:
    """PC 2×2, MART 2×2, HOUSE 3×2 side by side."""
    stamps = [
        ("PC 2x2", PC, 2, 2),
        ("MART 2x2", MART, 2, 2),
        ("HOUSE 3x2", HOUSE, 3, 2),
    ]
    gap = 8
    widths = [w * te.BLOCK_PX for _, _, w, _ in stamps]
    total_w = sum(widths) + gap * (len(stamps) + 1)
    total_h = 2 * te.BLOCK_PX + 28
    out = Image.new("RGB", (total_w, total_h), (24, 24, 24))
    draw = ImageDraw.Draw(out)
    x = gap
    for title, ids, bw, bh in stamps:
        draw.text((x, 2), title, fill=(200, 200, 200), font=font(11))
        draw.text((x, 14), str(ids), fill=(140, 140, 140), font=font(8))
        for i, bid in enumerate(ids):
            bx, by = i % bw, i // bw
            tile = gen1_block_image(atlas, columns, bid)
            label_block(tile, str(bid))
            out.paste(tile, (x + bx * te.BLOCK_PX, 26 + by * te.BLOCK_PX))
        x += bw * te.BLOCK_PX + gap
    path = os.path.join(outdir, "gen1_buildings.png")
    out.save(path)
    print(f"Wrote {path}")


def dump_gen1_role_picks(outdir: str, atlas: Image.Image, columns: int) -> None:
    roles = list(GEN1_ROLE_PICKS.items())
    cols = 4
    row_h = te.BLOCK_PX + 36
    rows = (len(roles) + cols - 1) // cols
    cell_w = 200
    out = Image.new("RGB", (cols * cell_w, rows * row_h), (20, 20, 20))
    draw = ImageDraw.Draw(out)
    for ri, (role, ids) in enumerate(roles):
        c, r = ri % cols, ri // cols
        x0, y0 = c * cell_w + 4, r * row_h + 2
        draw.text((x0, y0), role, fill=(180, 220, 255), font=font(10))
        for j, bid in enumerate(ids[:6]):
            tile = gen1_block_image(atlas, columns, bid)
            label_block(tile, str(bid))
            out.paste(tile, (x0 + j * (te.BLOCK_PX + 2), y0 + 14))
    path = os.path.join(outdir, "gen1_role_picks.png")
    out.save(path)
    print(f"Wrote {path}")


def load_frlg_tile_sheet(png_path: str) -> Image.Image:
    im = Image.open(png_path)
    if im.mode == "P":
        im = im.convert("RGBA")
    else:
        im = im.convert("RGBA")
    return im


def frlg_tile_from_sheet(sheet: Image.Image, tile_index: int, tiles_per_row: int = 16) -> Image.Image:
    """8×8 tile; tile_index is raw index into the tileset sheet."""
    tx = (tile_index % tiles_per_row) * 8
    ty = (tile_index // tiles_per_row) * 8
    return sheet.crop((tx, ty, tx + 8, ty + 8))


def render_frlg_metatile(
    mid: int,
    gen_mt: bytes,
    sev_mt: bytes,
    gen_sheet: Image.Image,
    sev_sheet: Image.Image,
) -> Image.Image:
    """Composite one 16×16 FRLG metatile (bottom then top layer).

    Tile indices in metatiles.bin are absolute across primary+secondary:
    tid < 640 → general sheet; else → sevii sheet at tid-640.
    """
    if mid < NUM_PRIMARY_METATILES:
        data, off = gen_mt, mid * 16
    else:
        data = sev_mt
        off = (mid - NUM_PRIMARY_METATILES) * 16
        if off + 16 > len(data):
            return Image.new("RGBA", (16, 16), (255, 0, 255, 255))

    entries = struct.unpack_from("<8H", data, off)
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for layer in (0, 1):
        for slot in range(4):
            e = entries[layer * 4 + slot]
            tid = e & 0x3FF
            hflip = bool(e & 0x400)
            vflip = bool(e & 0x800)
            if tid < NUM_PRIMARY_TILES:
                tile = frlg_tile_from_sheet(gen_sheet, tid)
            else:
                tile = frlg_tile_from_sheet(sev_sheet, tid - NUM_PRIMARY_TILES)
            if hflip:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
            if vflip:
                tile = tile.transpose(Image.FLIP_TOP_BOTTOM)
            px, py = (slot % 2) * 8, (slot // 2) * 8
            if layer == 0:
                img.paste(tile, (px, py))
            else:
                img.alpha_composite(tile.convert("RGBA"), (px, py))
    return img


def load_one_island_mids() -> list[int]:
    path = f"{LAYOUTS}/OneIsland.bin"
    data = open(path, "rb").read()
    mids = []
    for i in range(len(data) // 2):
        cell = struct.unpack_from("<H", data, i * 2)[0]
        mids.append(cell & 0x3FF)
    return mids


def behavior_of(mid: int, gen_attr: list[int], sev_attr: list[int]) -> int:
    if mid < NUM_PRIMARY_METATILES:
        return gen_attr[mid] & 0x1FF if mid < len(gen_attr) else 0
    idx = mid - NUM_PRIMARY_METATILES
    return sev_attr[idx] & 0x1FF if idx < len(sev_attr) else 0


def dump_frlg_oneisland_metatiles(outdir: str) -> dict[str, Any]:
    gen_mt = open(f"{CACHE}/general_metatiles.bin", "rb").read()
    sev_mt = open(f"{CACHE}/sevii_metatiles.bin", "rb").read()
    gen_sheet = load_frlg_tile_sheet(f"{CACHE}/general_tiles.png")
    sev_sheet = load_frlg_tile_sheet(f"{CACHE}/sevii_tiles.png")
    gen_attr = [
        struct.unpack_from("<I", open(f"{CACHE}/general_attr.bin", "rb").read(), i * 4)[0]
        for i in range(NUM_PRIMARY_METATILES)
    ]
    sev_raw = open(f"{CACHE}/sevii_attr.bin", "rb").read()
    sev_attr = [struct.unpack_from("<I", sev_raw, i * 4)[0] for i in range(len(sev_raw) // 4)]

    mids = load_one_island_mids()
    counts = Counter(mids)
    # Sort: most used first, but keep stable id order within ties
    unique = sorted(counts.keys(), key=lambda m: (-counts[m], m))

    scale = 3  # 16→48 for readability
    cols = 16
    cell = 16 * scale + 14
    rows = (len(unique) + cols - 1) // cols
    out = Image.new("RGB", (cols * cell, rows * cell), (18, 18, 18))
    draw = ImageDraw.Draw(out)
    catalog = []
    for i, mid in enumerate(unique):
        mt = render_frlg_metatile(mid, gen_mt, sev_mt, gen_sheet, sev_sheet)
        big = mt.resize((16 * scale, 16 * scale), Image.NEAREST).convert("RGB")
        c, r = i % cols, i // cols
        x, y = c * cell, r * cell
        out.paste(big, (x, y))
        beh = behavior_of(mid, gen_attr, sev_attr)
        label = f"{mid:03X}\nb={beh:02X}\n×{counts[mid]}"
        draw.rectangle([x, y + 16 * scale, x + 16 * scale - 1, y + cell - 1], fill=(28, 28, 28))
        draw.text((x + 1, y + 16 * scale), f"{mid:03X}", fill=(255, 220, 80), font=font(8))
        draw.text((x + 1, y + 16 * scale + 10), f"b{beh:02X} n{counts[mid]}", fill=(160, 160, 160), font=font(7))
        catalog.append({
            "mid": mid,
            "hex": f"0x{mid:03x}",
            "behavior": beh,
            "count": counts[mid],
            "tileset": "general" if mid < NUM_PRIMARY_METATILES else "sevii_123",
        })

    path = os.path.join(outdir, "frlg_oneisland_metatiles.png")
    out.save(path)
    print(f"Wrote {path} ({len(unique)} unique metatiles on One Island)")

    cat_path = os.path.join(outdir, "frlg_oneisland_metatiles.json")
    with open(cat_path, "w", encoding="utf-8") as f:
        json.dump({"map": "OneIsland", "unique": len(unique), "metatiles": catalog}, f, indent=2)
        f.write("\n")
    print(f"Wrote {cat_path}")
    return {"unique": unique, "counts": counts, "catalog": catalog}


def dump_frlg_general_sample(outdir: str, limit: int = 256) -> None:
    """First N primary metatiles as a quick palette overview."""
    gen_mt = open(f"{CACHE}/general_metatiles.bin", "rb").read()
    sev_mt = open(f"{CACHE}/sevii_metatiles.bin", "rb").read()
    gen_sheet = load_frlg_tile_sheet(f"{CACHE}/general_tiles.png")
    sev_sheet = load_frlg_tile_sheet(f"{CACHE}/sevii_tiles.png")
    scale, cols = 2, 32
    cell = 16 * scale + 2
    rows = (limit + cols - 1) // cols
    out = Image.new("RGB", (cols * cell, rows * cell), (12, 12, 12))
    for mid in range(limit):
        mt = render_frlg_metatile(mid, gen_mt, sev_mt, gen_sheet, sev_sheet)
        big = mt.resize((16 * scale, 16 * scale), Image.NEAREST).convert("RGB")
        c, r = mid % cols, mid // cols
        out.paste(big, (c * cell, r * cell))
    path = os.path.join(outdir, "frlg_general_atlas.png")
    out.save(path)
    print(f"Wrote {path} (first {limit} primary metatiles)")


def avg_rgb(img: Image.Image) -> tuple[float, float, float]:
    small = img.convert("RGB").resize((8, 8), Image.NEAREST)
    px = list(small.getdata())
    n = len(px)
    return (sum(p[0] for p in px) / n, sum(p[1] for p in px) / n, sum(p[2] for p in px) / n)


def hist_features(img: Image.Image, bins: int = 8) -> list[float]:
    small = img.convert("RGB").resize((16, 16), Image.NEAREST)
    px = list(small.getdata())
    hist = [0.0] * (bins * 3)
    for r, g, b in px:
        hist[r * bins // 256] += 1
        hist[bins + g * bins // 256] += 1
        hist[2 * bins + b * bins // 256] += 1
    s = sum(hist) or 1.0
    return [v / s for v in hist]


def cv_suggest(
    outdir: str,
    atlas: Image.Image,
    columns: int,
    frlg_info: dict[str, Any],
) -> None:
    """Cheap RGB-hist distance: each frequent FRLG mid → top Gen1 block IDs."""
    gen_mt = open(f"{CACHE}/general_metatiles.bin", "rb").read()
    sev_mt = open(f"{CACHE}/sevii_metatiles.bin", "rb").read()
    gen_sheet = load_frlg_tile_sheet(f"{CACHE}/general_tiles.png")
    sev_sheet = load_frlg_tile_sheet(f"{CACHE}/sevii_tiles.png")

    gen1_feats = []
    for bid in range(128):
        img = gen1_block_image(atlas, columns, bid).resize((16, 16), Image.NEAREST)
        gen1_feats.append((bid, hist_features(img), avg_rgb(img)))

    # Focus on top-used One Island metatiles
    top = sorted(frlg_info["catalog"], key=lambda e: -e["count"])[:40]
    suggestions = []
    for entry in top:
        mid = entry["mid"]
        mt = render_frlg_metatile(mid, gen_mt, sev_mt, gen_sheet, sev_sheet)
        # Upscale metatile to ~block size for fairer compare
        mt16 = mt.resize((16, 16), Image.NEAREST).convert("RGB")
        hf = hist_features(mt16)
        ar = avg_rgb(mt16)

        def dist(item: tuple) -> float:
            _bid, h, a = item
            hd = sum((x - y) ** 2 for x, y in zip(hf, h))
            ad = sum((x - y) ** 2 for x, y in zip(ar, a)) / (255.0 ** 2)
            return hd + 0.15 * ad

        ranked = sorted(gen1_feats, key=dist)[:5]
        suggestions.append({
            "frlg_mid": mid,
            "frlg_hex": f"0x{mid:03x}",
            "behavior": entry["behavior"],
            "count": entry["count"],
            "gen1_top": [{"block": b, "score": round(dist((b, h, a)), 4)} for b, h, a in ranked],
        })

    path = os.path.join(outdir, "cv_suggestions.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"method": "rgb_hist+avg", "suggestions": suggestions}, f, indent=2)
        f.write("\n")
    print(f"Wrote {path} (top {len(suggestions)} FRLG mids → Gen1 guesses)")

    # Visual strip: FRLG mid | gen1 top3
    scale = 2
    row_h = max(16 * scale, te.BLOCK_PX) + 18
    out = Image.new("RGB", (520, len(suggestions) * row_h), (16, 16, 16))
    draw = ImageDraw.Draw(out)
    for i, sug in enumerate(suggestions):
        y = i * row_h
        mt = render_frlg_metatile(sug["frlg_mid"], gen_mt, sev_mt, gen_sheet, sev_sheet)
        out.paste(mt.resize((16 * scale, 16 * scale), Image.NEAREST).convert("RGB"), (4, y + 2))
        draw.text((40, y + 2), f"{sug['frlg_hex']} b{sug['behavior']:02X} ×{sug['count']}", fill=(220, 220, 220), font=font(9))
        for j, g in enumerate(sug["gen1_top"][:3]):
            tile = gen1_block_image(atlas, columns, g["block"])
            label_block(tile, str(g["block"]))
            out.paste(tile, (40 + j * (te.BLOCK_PX + 4), y + 14))
    vpath = os.path.join(outdir, "cv_suggestions.png")
    out.save(vpath)
    print(f"Wrote {vpath}")


def write_scaffold(outdir: str, frlg_info: dict[str, Any]) -> None:
    # Attach top FRLG mids by behavior into scaffold for convenience
    by_beh: dict[int, list[dict]] = {}
    for e in frlg_info["catalog"]:
        by_beh.setdefault(e["behavior"], []).append(e)

    payload = {
        "version": 1,
        "gen1_tileset": "OVERWORLD",
        "gen1_block_px": te.BLOCK_PX,
        "gen1_note": "Each block is 4×4 of 8×8 tiles (32×32). Buildings are multi-block stamps.",
        "frlg_note": "FRLG metatiles are 16×16 (2×2 of 8×8) with two layers. One Island uses general + sevii_islands_123.",
        "building_stamps": {
            "PC": {"size": [2, 2], "blocks": list(PC)},
            "MART": {"size": [2, 2], "blocks": list(MART)},
            "HOUSE": {"size": [3, 2], "blocks": list(HOUSE)},
        },
        "roles": MAPPING_ROLES,
        "frlg_oneisland_behavior_histogram": {
            str(k): len(v) for k, v in sorted(by_beh.items())
        },
        "howto": [
            "1. Open gen1_overworld_atlas.png and gen1_buildings.png",
            "2. Open frlg_oneisland_metatiles.png (what One Island actually uses)",
            "3. For each role in mapping_scaffold.json, set pick to the best Gen1 block ID (or stamp name)",
            "4. Optional: run with --cv and use cv_suggestions.png as a starting hint only",
            "5. Feed picks into sevii_layout_gen.py ROLE_VOCAB",
        ],
    }
    path = os.path.join(outdir, "mapping_scaffold.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")
    print(f"Wrote {path}")


def write_readme(outdir: str) -> None:
    text = """# Gen1 ↔ FRLG Sevii tile mapping

Generated by `sevii_tile_mapper.py`.

## Files

| File | What |
|------|------|
| `gen1_overworld_atlas.png` | All 128 Red OVERWORLD blocks with IDs |
| `gen1_buildings.png` | Current PC / MART / HOUSE stamps (sizes!) |
| `gen1_role_picks.png` | Curated Gen1 candidates by role |
| `frlg_oneisland_metatiles.png` | Unique FRLG metatiles on One Island |
| `frlg_general_atlas.png` | Sample of primary FRLG metatiles |
| `mapping_scaffold.json` | **Edit this** — set `pick` per role |
| `cv_suggestions.*` | Optional cheap auto-guesses (`--cv`) |

## Scale reality check

- Gen1 **block** = 32×32 (4×4 tiles). HOUSE stamp = **3×2 blocks**.
- FRLG **metatile** = 16×16. An FRLG house is many metatiles → larger than Gen1 HOUSE.
- We cannot 1:1 pixel-match buildings; we map **roles** (cliff face, stair, deck, house stamp).

## Workflow

```bash
python3 mods/Kanto-Reforged/sevii_tile_mapper.py --cv
# eyeball PNGs, fill mapping_scaffold.json "pick" fields
```
"""
    path = os.path.join(outdir, "README.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"Wrote {path}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument(
        "--outdir",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "tile_mapping"),
    )
    ap.add_argument("--cv", action="store_true", help="Write histogram-based Gen1 suggestions")
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)

    print("Layer: Gen1 OVERWORLD")
    tilesets = te.load_generated("tilesets")
    ow = tilesets["OVERWORLD"]
    colors = te.PALETTES["dmg"]
    atlas, columns, _rows = te.build_block_atlas(ow, colors)
    n_blocks = len(te.as_list(ow.get("blocks")))
    dump_gen1_overworld(args.outdir, atlas, columns, n_blocks)
    dump_gen1_buildings(args.outdir, atlas, columns)
    dump_gen1_role_picks(args.outdir, atlas, columns)

    print("Layer: FRLG tileset graphics")
    ensure_frlg_gfx()
    frlg_info = dump_frlg_oneisland_metatiles(args.outdir)
    dump_frlg_general_sample(args.outdir)

    write_scaffold(args.outdir, frlg_info)
    write_readme(args.outdir)

    if args.cv:
        print("Layer: CV suggestions")
        cv_suggest(args.outdir, atlas, columns, frlg_info)

    print("\nDone. Open tile_mapping/ and fill mapping_scaffold.json picks.")


if __name__ == "__main__":
    main()
