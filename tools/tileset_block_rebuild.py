#!/usr/bin/env python3
"""Rebuild Gen2 block RGB previews from a Gold tileset tile sheet."""

from __future__ import annotations

import os
from typing import Any

from PIL import Image


def find_tileset_image(rel_or_name: str, game: str = "gold") -> str | None:
    name = os.path.basename(rel_or_name)
    home = os.path.expanduser("~/.local/share/love/pokemon-love2d")
    candidates = [
        os.path.join(home, game, "assets", "generated", "tilesets", name),
        os.path.join(home, "assets", "generated", "tilesets", name),
        os.path.join(home, "red", "assets", "generated", "tilesets", name),
        # gen1recomp checkout
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))),
                     "assets", "generated", "tilesets", name),
        rel_or_name,
    ]
    # Also walk up from this file to find gen1recomp/assets
    here = os.path.abspath(__file__)
    for _ in range(6):
        here = os.path.dirname(here)
        candidates.append(os.path.join(here, "assets", "generated", "tilesets", name))
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    return None


def find_gold_tileset_image(rel_or_name: str) -> str | None:
    """Prefer Gold, then other Gen2 caches (Silver/Crystal), then legacy roots."""
    for game in ("gold", "silver", "crystal"):
        hit = find_tileset_image(rel_or_name, game=game)
        if hit:
            return hit
    return None


def find_gen2_tileset_image(rel_or_name: str, game: str | None = None) -> str | None:
    """Resolve a Gen2 tileset sheet for the given edition (or any Gen2)."""
    if game:
        hit = find_tileset_image(rel_or_name, game=game)
        if hit:
            return hit
    return find_gold_tileset_image(rel_or_name)


def rebuild_blocks_from_tileset(
    ts_rec: dict[str, Any],
    image_path: str | None = None,
    tile_size: int = 8,
    max_blocks: int | None = None,
) -> list[Image.Image]:
    """
    Assemble one RGB PIL image per block from tileset.blocks + tileset image.

    Gold sheets are typically already colour-baked for the default env; using them
    for TILESET_CAVE avoids judging cave contrast under route colours.
    """
    blocks_def = ts_rec.get("blocks") or []
    if not blocks_def:
        return []

    img_rel = image_path or ts_rec.get("image") or ""
    if img_rel and not os.path.isabs(img_rel):
        img_rel = find_gold_tileset_image(img_rel) or find_tileset_image(img_rel, "red") or img_rel
    if not img_rel or not os.path.isfile(img_rel):
        return []

    sheet = Image.open(img_rel).convert("RGB")
    sw, sh = sheet.size
    tiles_per_row = int(ts_rec.get("tilesPerRow") or (sw // tile_size))
    out: list[Image.Image] = []
    limit = len(blocks_def) if max_blocks is None else min(len(blocks_def), max_blocks)

    for bi in range(limit):
        tiles = blocks_def[bi]
        block_img = Image.new("RGB", (tile_size * 4, tile_size * 4), (0, 0, 0))
        for ti, tid in enumerate(tiles[:16]):
            col = ti % 4
            row = ti // 4
            tx = (int(tid) % tiles_per_row) * tile_size
            ty = (int(tid) // tiles_per_row) * tile_size
            if tx + tile_size <= sw and ty + tile_size <= sh:
                tile = sheet.crop((tx, ty, tx + tile_size, ty + tile_size))
            else:
                tile = Image.new("RGB", (tile_size, tile_size), (32, 32, 32))
            block_img.paste(tile, (col * tile_size, row * tile_size))
        out.append(block_img)
    return out


def hex_to_rgb(color: str) -> tuple[int, int, int]:
    c = color.lstrip("#")
    return int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)


def draw_collision_overlay(img: Image.Image, coll_quads: list[int], color_by_val: dict[int, str], alpha: int = 110) -> Image.Image:
    """Overlay translucent collision colours on the four quadrants of a block image."""
    from PIL import ImageDraw

    out = img.convert("RGBA")
    overlay = Image.new("RGBA", out.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    w, h = out.size
    hw, hh = w // 2, h // 2
    rects = [
        (0, 0, hw - 1, hh - 1),
        (hw, 0, w - 1, hh - 1),
        (0, hh, hw - 1, h - 1),
        (hw, hh, w - 1, h - 1),
    ]
    for i, rect in enumerate(rects):
        if i >= len(coll_quads):
            break
        val = int(coll_quads[i])
        hex_col = color_by_val.get(val, "#9E9E9E")
        r, g, b = hex_to_rgb(hex_col)
        draw.rectangle(rect, fill=(r, g, b, alpha))
    return Image.alpha_composite(out, overlay).convert("RGB")
