#!/usr/bin/env python3
"""Rebuild block RGB previews from a Gen1/Gen2 tileset tile sheet."""

from __future__ import annotations

import json
import os
import subprocess
from functools import lru_cache
from typing import Any

from PIL import Image

_TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
_MOD_ROOT = os.path.dirname(_TOOLS_DIR)


def find_tileset_image(rel_or_name: str, game: str = "gold") -> str | None:
    name = os.path.basename(rel_or_name)
    home = os.path.expanduser("~/.local/share/love/pokemon-love2d")
    candidates = [
        os.path.join(_MOD_ROOT, "overrides", "tilesets", name),
        os.path.join(_MOD_ROOT, "overrides", "tilesets", f"kr_{name}"),
        os.path.join(home, game, "assets", "generated", "tilesets", name),
        os.path.join(home, "assets", "generated", "tilesets", name),
        os.path.join(home, "red", "assets", "generated", "tilesets", name),
        os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))),
            "assets",
            "generated",
            "tilesets",
            name,
        ),
        rel_or_name,
    ]
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


def _resolve_sheet_path(ts_rec: dict[str, Any], image_path: str | None, game: str) -> str | None:
    img_rel = image_path or ts_rec.get("image") or ""
    if img_rel and os.path.isabs(img_rel) and os.path.isfile(img_rel):
        return img_rel
    if img_rel and not os.path.isabs(img_rel):
        name = os.path.basename(img_rel)
        if game == "red":
            hit = find_tileset_image(name, game="red")
        else:
            hit = find_gen2_tileset_image(name, game=game) or find_tileset_image(name, game="red")
        if hit:
            return hit
        if os.path.isfile(img_rel):
            return img_rel
    return None


def _shade_index(r: int) -> int:
    """Match src/render/GbcPalette.lua: floor((1 - r/255) * 3 + 0.5)."""
    return int((1.0 - (r / 255.0)) * 3.0 + 0.5)


def _as_rgb(pixel) -> tuple[int, int, int]:
    if isinstance(pixel, (list, tuple)):
        if len(pixel) >= 3:
            return int(pixel[0]), int(pixel[1]), int(pixel[2])
        if len(pixel) == 1:
            v = int(pixel[0])
            return v, v, v
    return int(pixel), int(pixel), int(pixel)


def _recolor_tile(tile: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    """Map a 4-shade grayscale tile through a 4-color GBC palette."""
    src = tile.convert("RGBA")
    out = Image.new("RGBA", src.size)
    px = out.load()
    spx = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = spx[x, y]
            if a == 0:
                px[x, y] = (0, 0, 0, 0)
                continue
            shade = _shade_index(r)
            shade = max(0, min(3, shade))
            cr, cg, cb = palette[shade]
            px[x, y] = (cr, cg, cb, 255)
    return out.convert("RGB")


@lru_cache(maxsize=4)
def _load_lua_json_cached(lua_path: str) -> dict[str, Any] | None:
    if not lua_path or not os.path.isfile(lua_path):
        return None
    tool_candidates = [
        os.path.join(os.path.dirname(_TOOLS_DIR), "..", "tools", "lua_to_json.lua"),
        os.path.join(os.path.dirname(os.path.dirname(_MOD_ROOT)), "tools", "lua_to_json.lua"),
        "/home/autumn/src/gen1recomp/tools/lua_to_json.lua",
    ]
    tool = next((c for c in tool_candidates if os.path.isfile(c)), None)
    if not tool:
        return None
    try:
        proc = subprocess.run(
            ["luajit", tool, lua_path],
            capture_output=True,
            text=True,
            check=True,
            cwd=os.path.dirname(os.path.dirname(tool)),
        )
        return json.loads(proc.stdout)
    except Exception:
        return None


def _find_gen1_palettes_lua() -> str | None:
    candidates = [
        os.path.join(os.path.dirname(os.path.dirname(_MOD_ROOT)), "data", "palettes_gbc.lua"),
        "/home/autumn/src/gen1recomp/data/palettes_gbc.lua",
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None


def _find_gen2_palettes_lua(game: str = "gold") -> str | None:
    home = os.path.expanduser("~/.local/share/love/pokemon-love2d")
    candidates = [
        os.path.join(home, game, "data", "generated", "palettes.lua"),
        os.path.join(home, "data", "generated", "palettes.lua"),
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None


def _gen1_palette_for_tile(tileset_id: str, tile_id: int) -> list[tuple[int, int, int]] | None:
    data = _load_lua_json_cached(_find_gen1_palettes_lua() or "")
    if not data:
        return None
    world = data.get("world") or {}
    group_colors = (world.get("groupColors") or {}).get(tileset_id)
    tile_groups = (world.get("tileGroups") or {}).get(tileset_id) or {}
    if not group_colors:
        return None
    group = tile_groups.get(str(tile_id), tile_groups.get(tile_id, 0))
    try:
        group = int(group)
    except (TypeError, ValueError):
        group = 0
    if group < 0 or group >= len(group_colors):
        return None
    pal = group_colors[group]
    return [_as_rgb(c) for c in pal[:4]]


def _gen2_bg_set(environment: str, daytime: str = "DAY", game: str = "gold") -> list[list[tuple[int, int, int]]] | None:
    data = _load_lua_json_cached(_find_gen2_palettes_lua(game) or "")
    if not data:
        return None
    env_row = (data.get("environments") or {}).get(environment)
    if not env_row:
        env_row = (data.get("environments") or {}).get("TOWN")
    if not env_row:
        return None
    indices = env_row.get(daytime) or env_row.get("DAY")
    bg = data.get("bg") or []
    if not indices or not bg:
        return None
    out: list[list[tuple[int, int, int]]] = []
    for idx in indices:
        try:
            pool = bg[int(idx) - 1]
        except (IndexError, TypeError, ValueError):
            pool = [[0, 0, 0]] * 4
        out.append([_as_rgb(c) for c in pool[:4]])
    return out


def _gen2_palette_slot_for_tile(
    ts_rec: dict[str, Any],
    tile_id: int,
    *,
    sheet: Image.Image | None = None,
    tile_size: int = 8,
    tiles_per_row: int = 16,
) -> int:
    """Match mapper bake to atlas mirroring: OOB VRAM ids inherit sheet tile palette."""
    tile_pals = ts_rec.get("tilePalettes") or []
    effective = int(tile_id)
    if sheet is not None:
        effective = _effective_sheet_tile_id(tile_id, sheet, tile_size, tiles_per_row)
    try:
        return int(tile_pals[effective])
    except (IndexError, TypeError, ValueError):
        if tile_pals:
            try:
                return int(tile_pals[effective % len(tile_pals)])
            except (IndexError, TypeError, ValueError):
                pass
        return 1


def _gen2_palette_for_tile(
    ts_rec: dict[str, Any],
    tile_id: int,
    environment: str,
    daytime: str,
    game: str,
    *,
    sheet: Image.Image | None = None,
    tile_size: int = 8,
    tiles_per_row: int = 16,
    palette_slot_override: int | None = None,
) -> list[tuple[int, int, int]] | None:
    bg_set = _gen2_bg_set(environment, daytime, game)
    if not bg_set:
        return None
    if palette_slot_override is not None:
        slot = int(palette_slot_override)
    else:
        slot = _gen2_palette_slot_for_tile(
            ts_rec,
            tile_id,
            sheet=sheet,
            tile_size=tile_size,
            tiles_per_row=tiles_per_row,
        )
    slot = max(1, min(8, slot))
    pal = bg_set[slot - 1]
    return list(pal[:4])


def _sheet_tile_count(sheet: Image.Image, tile_size: int, tiles_per_row: int) -> int:
    sw, sh = sheet.size
    rows = max(1, sh // tile_size)
    cols = max(1, tiles_per_row or (sw // tile_size))
    return cols * rows


def _effective_sheet_tile_id(
    tile_id: int,
    sheet: Image.Image,
    tile_size: int,
    tiles_per_row: int,
) -> int:
    """Resolve VRAM tile id to a sheet index (mirrors OOB ids into the atlas)."""
    tid = int(tile_id)
    sw, sh = sheet.size
    tx = (tid % tiles_per_row) * tile_size
    ty = (tid // tiles_per_row) * tile_size
    if tx + tile_size <= sw and ty + tile_size <= sh:
        return tid
    sheet_tiles = _sheet_tile_count(sheet, tile_size, tiles_per_row)
    if sheet_tiles > 0:
        return tid % sheet_tiles
    return tid


def _sheet_crop_for_tile(
    sheet: Image.Image,
    tile_id: int,
    tile_size: int,
    tiles_per_row: int,
) -> Image.Image | None:
    """Crop a tile from the PNG atlas; mirror VRAM ids into the 96-tile sheet."""
    effective = _effective_sheet_tile_id(tile_id, sheet, tile_size, tiles_per_row)
    tx = (effective % tiles_per_row) * tile_size
    ty = (effective // tiles_per_row) * tile_size
    if tx + tile_size > sheet.width or ty + tile_size > sheet.height:
        return None
    return sheet.crop((tx, ty, tx + tile_size, ty + tile_size))


def _bake_tile(
    sheet: Image.Image,
    tile_id: int,
    tile_size: int,
    tiles_per_row: int,
    palette_bake: dict[str, Any] | None,
    ts_rec: dict[str, Any],
    *,
    palette_slot_override: int | None = None,
) -> Image.Image:
    tile = _sheet_crop_for_tile(sheet, tile_id, tile_size, tiles_per_row)
    if tile is None:
        return Image.new("RGB", (tile_size, tile_size), (32, 32, 32))
    if not palette_bake:
        return tile.convert("RGB")

    kind = palette_bake.get("kind")
    pal: list[tuple[int, int, int]] | None = None
    if kind == "gen1":
        pal = _gen1_palette_for_tile(palette_bake.get("tileset_id") or "", int(tile_id))
    elif kind == "gen2":
        pal = _gen2_palette_for_tile(
            ts_rec,
            int(tile_id),
            palette_bake.get("environment") or "CAVE",
            palette_bake.get("daytime") or "DAY",
            palette_bake.get("game") or "gold",
            sheet=sheet,
            tile_size=tile_size,
            tiles_per_row=tiles_per_row,
            palette_slot_override=palette_slot_override,
        )
    if pal:
        return _recolor_tile(tile, pal)
    return tile.convert("RGB")


def rebuild_blocks_from_tileset(
    ts_rec: dict[str, Any],
    image_path: str | None = None,
    tile_size: int = 8,
    max_blocks: int | None = None,
    *,
    game: str = "gold",
    palette_bake: dict[str, Any] | None = None,
) -> list[Image.Image]:
    """
    Assemble one RGB PIL image per block from tileset.blocks + tileset image.

    Indexed L-mode sheets (Gen1/Gen2 ROM exports) need ``palette_bake`` so
    thumbnails match in-game GBC colours instead of raw greyscale.
    """
    blocks_def = ts_rec.get("blocks") or []
    if not blocks_def:
        return []

    img_rel = _resolve_sheet_path(ts_rec, image_path, game)
    if not img_rel:
        return []

    sheet = Image.open(img_rel)
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
            tile = _bake_tile(sheet, int(tid), tile_size, tiles_per_row, palette_bake, ts_rec)
            block_img.paste(tile, (col * tile_size, row * tile_size))
        out.append(block_img)
    return out


def render_quad_from_tile_ids(
    quad_tile_ids: list[int],
    ts_rec: dict[str, Any],
    image_path: str,
    *,
    quad_px: int = 16,
    tile_size: int = 8,
    palette_bake: dict[str, Any] | None = None,
    game: str = "gold",
    palette_slot_override: int | None = None,
) -> Image.Image:
    """Bake one 2×2-tile quadrant from four 8×8 tile indices."""
    if not image_path or not os.path.isfile(image_path):
        return Image.new("RGB", (quad_px, quad_px), (32, 32, 32))
    sheet = Image.open(image_path)
    tiles_per_row = int(ts_rec.get("tilesPerRow") or (sheet.size[0] // tile_size))
    cell = max(1, quad_px // 2)
    out = Image.new("RGB", (quad_px, quad_px), (0, 0, 0))
    for i, tid in enumerate(list(quad_tile_ids)[:4]):
        tile = _bake_tile(
            sheet,
            int(tid),
            tile_size,
            tiles_per_row,
            palette_bake,
            ts_rec,
            palette_slot_override=palette_slot_override,
        )
        if tile.size != (cell, cell):
            tile = tile.resize((cell, cell), Image.NEAREST)
        out.paste(tile, ((i % 2) * cell, (i // 2) * cell))
    return out


def render_block_from_tile_ids(
    tiles16: list[int],
    ts_rec: dict[str, Any],
    image_path: str,
    *,
    block_px: int = 32,
    tile_size: int = 8,
    palette_bake: dict[str, Any] | None = None,
    game: str = "gold",
) -> Image.Image:
    """Bake one metatile image from 16 tile indices — matches in-game / export, not img_np."""
    if not image_path or not os.path.isfile(image_path):
        return Image.new("RGB", (block_px, block_px), (32, 32, 32))
    sheet = Image.open(image_path)
    tiles_per_row = int(ts_rec.get("tilesPerRow") or (sheet.size[0] // tile_size))
    cell = max(1, block_px // 4)
    out = Image.new("RGB", (block_px, block_px), (0, 0, 0))
    for ti, tid in enumerate(list(tiles16)[:16]):
        col = ti % 4
        row = ti // 4
        tile = _bake_tile(sheet, int(tid), tile_size, tiles_per_row, palette_bake, ts_rec)
        if tile.size != (cell, cell):
            tile = tile.resize((cell, cell), Image.NEAREST)
        out.paste(tile, (col * cell, row * cell))
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
