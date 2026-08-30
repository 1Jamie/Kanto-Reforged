#!/usr/bin/env python3
"""Compose Gen2 tileset override sheets from stock ROM PNGs + isolated quad art.

Ship sources under overrides/tileset_quads/:

  Sign: one 16×16 metatile quad PNG (Gen1 sign block corner)
  Stair: one 16×16 metatile quad PNG (two 16×8 step rows stacked vertically)

Metatile quads are 2×2 tiles (TL, TR, BL, BR). Do NOT mirror 8×16 portrait
strips horizontally — that scrambles the TL/TR/BL/BR split when pasted to VRAM.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Callable

from PIL import Image

from tileset_block_rebuild import find_gen2_tileset_image, find_tileset_image, rebuild_blocks_from_tileset

_MOD_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_QUAD_DIR = os.path.join(_MOD_ROOT, "overrides", "tileset_quads")
_OUT_DIR = os.path.join(_MOD_ROOT, "overrides", "tilesets")

TILE_SIZE = 8
TILES_PER_ROW = 16
QUAD_SIZE = (16, 16)
ROW_HALF_SIZE = (16, 8)


@dataclass(frozen=True)
class MetatileQuadPatch:
    """Assembled 16×16 metatile quad pasted onto four VRAM tile indices."""

    tile_ids: tuple[int, int, int, int]  # TL, TR, BL, BR
    assemble: Callable[[], Image.Image]


def _quad_path(name: str) -> str:
    return os.path.join(_QUAD_DIR, name)


def _load_png(name: str, expected: tuple[int, int]) -> Image.Image:
    path = _quad_path(name)
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Missing tileset quad source: {path}")
    im = Image.open(path).convert("L")
    if im.size != expected:
        raise ValueError(f"{path} must be {expected[0]}×{expected[1]}, got {im.size}")
    return im


def _load_full_quad(name: str) -> Image.Image:
    return _load_png(name, QUAD_SIZE)


def _assemble_stair_from_row_halves(top_name: str, bottom_name: str) -> Image.Image:
    """Stack two 16×8 step rows into one TL/TR/BL/BR metatile quad."""
    top = _load_png(top_name, ROW_HALF_SIZE)
    bottom = _load_png(bottom_name, ROW_HALF_SIZE)
    quad = Image.new("L", QUAD_SIZE)
    quad.paste(top, (0, 0))
    quad.paste(bottom, (0, 8))
    return quad


def assemble_cave_sign() -> Image.Image:
    return _load_full_quad("cave_wooden_sign.png")


def assemble_forest_sign() -> Image.Image:
    return _load_full_quad("forest_wooden_sign.png")


def assemble_wood_stair() -> Image.Image:
    if os.path.isfile(_quad_path("wood_stair.png")):
        return _load_full_quad("wood_stair.png")
    return _assemble_stair_from_row_halves("wood_stair_top.png", "wood_stair_bottom.png")


CAVE_PATCHES = (
    MetatileQuadPatch((90, 91, 92, 93), assemble_cave_sign),
)

# Unused VRAM slot: dark speckled floor (t1 2bpp shifted one shade darker @ pal 6).
CAVE_DARK_FLOOR_TILE = 62
CAVE_DARK_FLOOR_SOURCE_TILE = 1

KANTO_PATCHES = (
    MetatileQuadPatch((77, 78, 83, 84), assemble_wood_stair),
    MetatileQuadPatch((96, 97, 98, 99), assemble_forest_sign),
)

# Custom Kanto stair metatiles (see restore_kanto_dungeons CUSTOM_KANTO_BLOCKS).
STAIR_BLOCK_158_TILES = (
    17, 17, 17, 17, 17, 17, 17, 17, 77, 78, 77, 78, 83, 84, 83, 84
)
STAIR_BLOCK_159_TILES = (
    77, 78, 77, 78, 83, 84, 83, 84, 17, 17, 17, 17, 17, 17, 17, 17
)
STAIR_VRAM_TILES = (77, 78, 83, 84)
STAIR_VRAM_PALETTE_SLOT = 1


def _paste_tile(sheet: Image.Image, tile_id: int, tile: Image.Image) -> None:
    tx = (int(tile_id) % TILES_PER_ROW) * TILE_SIZE
    ty = (int(tile_id) // TILES_PER_ROW) * TILE_SIZE
    if tx + TILE_SIZE > sheet.width or ty + TILE_SIZE > sheet.height:
        raise ValueError(
            f"Tile {tile_id} at ({tx},{ty}) exceeds sheet {sheet.size}"
        )
    sheet.paste(tile, (tx, ty))


def _darken_tile_greyscale(tile: Image.Image) -> Image.Image:
    """Shift Gen2 2bpp grey levels one shade darker (matches G1 dark cave floor luma)."""
    src = tile.convert("L")
    out = Image.new("L", src.size)
    spx = src.load()
    dpx = out.load()
    for y in range(src.height):
        for x in range(src.width):
            v = int(spx[x, y])
            if v >= 200:
                dpx[x, y] = 170
            elif v >= 120:
                dpx[x, y] = 85
            else:
                dpx[x, y] = 0
    return out


def _clone_vram_tile_darkened(sheet: Image.Image, src_id: int, dst_id: int) -> None:
    """Copy tile graphics to a new VRAM id with 2bpp shifted one shade darker."""
    tx = (int(src_id) % TILES_PER_ROW) * TILE_SIZE
    ty = (int(src_id) // TILES_PER_ROW) * TILE_SIZE
    tile = _darken_tile_greyscale(sheet.crop((tx, ty, tx + TILE_SIZE, ty + TILE_SIZE)))
    _paste_tile(sheet, dst_id, tile)


def paste_metatile_quad(sheet: Image.Image, patch: MetatileQuadPatch) -> None:
    """Paste assembled quad sub-tiles onto VRAM ids (TL, TR, BL, BR order)."""
    quad = patch.assemble()
    for i, tile_id in enumerate(patch.tile_ids):
        sub = quad.crop(
            (
                (i % 2) * TILE_SIZE,
                (i // 2) * TILE_SIZE,
                (i % 2) * TILE_SIZE + TILE_SIZE,
                (i // 2) * TILE_SIZE + TILE_SIZE,
            )
        )
        _paste_tile(sheet, tile_id, sub)


def _required_sheet_rows(patches: tuple[MetatileQuadPatch, ...]) -> int:
    max_tid = max(t for p in patches for t in p.tile_ids)
    return (max_tid // TILES_PER_ROW) + 1


def build_patched_sheet(
    sheet_name: str,
    patches: tuple[MetatileQuadPatch, ...],
    *,
    game: str = "gold",
) -> Image.Image:
    stock_path = find_gen2_tileset_image(sheet_name, game=game)
    if not stock_path:
        raise FileNotFoundError(
            f"Cannot locate stock Gen2 tileset PNG for {sheet_name!r} "
            f"(run the game once to populate ~/.local/share/love/pokemon-love2d/)"
        )
    sheet = Image.open(stock_path).convert("L")
    need_h = _required_sheet_rows(patches) * TILE_SIZE
    if sheet.height < need_h:
        extended = Image.new("L", (sheet.width, need_h), 0)
        extended.paste(sheet, (0, 0))
        sheet = extended
    for patch in patches:
        paste_metatile_quad(sheet, patch)
    if sheet_name == "cave.png":
        _clone_vram_tile_darkened(sheet, CAVE_DARK_FLOOR_SOURCE_TILE, CAVE_DARK_FLOOR_TILE)
    return sheet


def _load_gold_tileset_rec(tileset_id: str, *, game: str = "gold") -> tuple[dict, str] | tuple[None, None]:
    """Load Gen2 tileset.lua entry + path to tilesets.lua."""
    import json
    import subprocess

    home = os.path.expanduser("~/.local/share/love/pokemon-love2d")
    ts_path = None
    for g in (game, "gold", "silver", "crystal"):
        cand = os.path.join(home, g, "data", "generated", "tilesets.lua")
        if os.path.isfile(cand):
            ts_path = cand
            break
    if not ts_path:
        return None, None
    tool = os.path.join(os.path.dirname(os.path.dirname(_MOD_ROOT)), "tools", "lua_to_json.lua")
    proc = subprocess.run(
        ["luajit", tool, ts_path],
        capture_output=True,
        text=True,
        cwd=os.path.dirname(tool),
        check=True,
    )
    data = json.loads(proc.stdout)
    rec = data.get(tileset_id)
    if not isinstance(rec, dict):
        return None, None
    return dict(rec), ts_path


def render_stair_block_previews(g2_raw_blocks, *, game: str = "gold") -> bool:
    """Bake mapper previews for custom blocks #158/#159 from shipped wood_stair.png."""
    if not g2_raw_blocks:
        return False
    if not os.path.isfile(_quad_path("wood_stair.png")):
        return False

    write_mod_tileset_overrides(game=game)

    from tileset_block_rebuild import find_tileset_image, render_block_from_tile_ids

    kpath = find_tileset_image("kanto.png", game=game)
    rec, _ = _load_gold_tileset_rec("TILESET_KANTO", game=game)
    if not kpath or not rec:
        return False

    pals = list(rec.get("tilePalettes") or [])
    while len(pals) < 100:
        pals.append(STAIR_VRAM_PALETTE_SLOT)
    for tid in STAIR_VRAM_TILES:
        pals[tid] = STAIR_VRAM_PALETTE_SLOT
    rec["tilePalettes"] = pals

    bw, bh = g2_raw_blocks[0].size
    palette_bake = {"kind": "gen2", "tileset_id": "TILESET_KANTO", "env": "ROUTE"}
    for block_id, tiles in (
        (158, STAIR_BLOCK_158_TILES),
        (159, STAIR_BLOCK_159_TILES),
    ):
        img = render_block_from_tile_ids(
            list(tiles),
            rec,
            kpath,
            block_px=bw,
            palette_bake=palette_bake,
            game=game,
        )
        while len(g2_raw_blocks) <= block_id:
            g2_raw_blocks.append(Image.new("RGB", (bw, bh), (0, 0, 0)))
        g2_raw_blocks[block_id] = img
    return True


def _save_quad_png(name: str, image: Image.Image, *, expected: tuple[int, int]) -> None:
    path = _quad_path(name)
    if os.path.isfile(path):
        print(f"[tileset_quad_patches] Keeping hand-made {path}")
        return
    if image.size != expected:
        raise ValueError(f"{name} must be {expected[0]}×{expected[1]}, got {image.size}")
    image.save(path)
    print(f"[tileset_quad_patches] Wrote {path}")


def write_mod_tileset_overrides(*, game: str = "gold") -> dict[str, str]:
    os.makedirs(_OUT_DIR, exist_ok=True)
    written: dict[str, str] = {}
    for sheet_name, patches in (
        ("cave.png", CAVE_PATCHES),
        ("kanto.png", KANTO_PATCHES),
    ):
        out_path = os.path.join(_OUT_DIR, sheet_name)
        sheet = build_patched_sheet(sheet_name, patches, game=game)
        sheet.save(out_path)
        written[sheet_name] = out_path
        print(
            f"[tileset_quad_patches] Wrote {out_path} "
            f"({sheet.width}×{sheet.height}, {len(patches)} quad patch(es))"
        )
    return written


def _paste_tile_on_sheet(sheet: Image.Image, tile_id: int, dest: Image.Image, ox: int, oy: int) -> None:
    tx = (int(tile_id) % TILES_PER_ROW) * TILE_SIZE
    ty = (int(tile_id) // TILES_PER_ROW) * TILE_SIZE
    dest.paste(sheet.crop((tx, ty, tx + TILE_SIZE, ty + TILE_SIZE)), (ox, oy))


def _quad_from_block_corner(sheet: Image.Image, block_tiles: list, q_pos: int) -> Image.Image:
    from block_mapper.cv import extract_quad_tile_ids

    tids = extract_quad_tile_ids(block_tiles, q_pos)
    quad = Image.new("L", QUAD_SIZE)
    for i, tid in enumerate(tids):
        _paste_tile_on_sheet(sheet, tid, quad, (i % 2) * TILE_SIZE, (i // 2) * TILE_SIZE)
    return quad


def _row_from_gen1_tiles(sheet: Image.Image, left_tid: int, right_tid: int) -> Image.Image:
    """One metatile row = two 8×8 tiles side by side (16×8 landscape half)."""
    row = Image.new("L", ROW_HALF_SIZE)
    _paste_tile_on_sheet(sheet, left_tid, row, 0, 0)
    _paste_tile_on_sheet(sheet, right_tid, row, 8, 0)
    return row


def extract_quad_sources_from_gen1() -> None:
    """Refresh overrides/tileset_quads/ from Red CAVERN + FOREST tile sheets."""
    import json
    import subprocess

    os.makedirs(_QUAD_DIR, exist_ok=True)
    cavern_path = find_tileset_image("cavern.png", game="red")
    forest_path = find_tileset_image("forest.png", game="red")
    if not cavern_path or not forest_path:
        raise FileNotFoundError("Red CAVERN/FOREST tile sheets required for extract")

    cavern_sheet = Image.open(cavern_path).convert("L")
    forest_sheet = Image.open(forest_path).convert("L")

    tool = os.path.join(
        os.path.dirname(os.path.dirname(_MOD_ROOT)), "tools", "lua_to_json.lua"
    )
    lua = os.path.expanduser(
        "~/.local/share/love/pokemon-love2d/red/data/generated/tilesets.lua"
    )
    proc = subprocess.run(
        ["luajit", tool, lua],
        capture_output=True,
        text=True,
        cwd=os.path.dirname(tool),
        check=True,
    )
    ts_data = json.loads(proc.stdout)

    # Cave wooden sign: block #42 BR (tiles 14/15 top row, 30/31 bottom row).
    cave_sign = _quad_from_block_corner(cavern_sheet, ts_data["CAVERN"]["blocks"][42], 3)
    _save_quad_png("cave_wooden_sign.png", cave_sign, expected=QUAD_SIZE)

    # Forest wooden sign: block #21 BL (tiles 33/34 top row, 49/50 bottom row).
    forest_sign = _quad_from_block_corner(forest_sheet, ts_data["FOREST"]["blocks"][21], 2)
    _save_quad_png("forest_wooden_sign.png", forest_sign, expected=QUAD_SIZE)

    # Stairs ship as hand-made overrides/tileset_quads/wood_stair.png (16×16).
    # Gen1 CAVERN block #35 TR is the wrong source (sign/floor vertical split).
    if not os.path.isfile(_quad_path("wood_stair.png")):
        print(
            "[tileset_quad_patches] wood_stair.png missing — create 16×16 stair quad by hand "
            "or restore from version control"
        )

    # Drop legacy portrait-column sources (8×16 left/right assembly was wrong for stairs).
    for legacy in (
        "cave_wooden_sign_left.png",
        "cave_wooden_sign_right.png",
        "forest_wooden_sign_left.png",
        "forest_wooden_sign_right.png",
        "wood_stair_half.png",
    ):
        path = _quad_path(legacy)
        if os.path.isfile(path):
            os.remove(path)
            print(f"[tileset_quad_patches] Removed legacy {path}")


def list_quad_sources() -> list[str]:
    if not os.path.isdir(_QUAD_DIR):
        return []
    return sorted(
        f
        for f in os.listdir(_QUAD_DIR)
        if f.endswith(".png") and os.path.isfile(os.path.join(_QUAD_DIR, f))
    )


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "extract":
        extract_quad_sources_from_gen1()
    else:
        write_mod_tileset_overrides()
