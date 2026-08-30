#!/usr/bin/env python3
"""Mapping session prep (no Tk) — CV slicing/ranking for the block mapper shell."""

from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Any, Callable

import numpy as np
from PIL import Image

_TOOLS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from block_mapper import cv as cvmod  # noqa: E402
from block_mapper_profiles.common import (  # noqa: E402
    COLLISION_PRESETS as _DEFAULT_COLLISION_PRESETS,
)
from map_layout_loader import load_map_by_id, load_test_map  # noqa: E402
from tileset_block_rebuild import rebuild_blocks_from_tileset, render_block_from_tile_ids  # noqa: E402


@dataclass
class MappingSession:
    profile: dict[str, Any]
    g1_images: list
    g2_images: list
    block_rankings: dict
    base_quad_rankings: dict
    unique_quad_pool: list
    g2_tiles_raw: list
    g2_coll_raw: list
    out_path: str
    dict_name: str
    custom_blocks_name: str
    exclude_buildings: bool
    g2_ts_rec: dict | None = None
    g2_sheet_path: str | None = None
    g2_palette_bake: dict | None = None
    preview_map: dict[str, Any] | None = None
    g1_block_px: int = 32
    g2_block_px: int = 32
    is_dirty: bool = False
    # Live mapping state owned by MapperView but shared for dirty/title
    mapping: dict = field(default_factory=dict)
    custom_blocks: dict = field(default_factory=dict)
    on_dirty_changed: Callable[[bool], None] | None = None

    def mark_dirty(self, dirty: bool = True) -> None:
        if self.is_dirty == dirty:
            return
        self.is_dirty = dirty
        if self.on_dirty_changed:
            self.on_dirty_changed(dirty)

    def clear_dirty(self) -> None:
        self.mark_dirty(False)


def resolve_sheet_path(path_str: str | None) -> str | None:
    if not path_str:
        return None
    if os.path.exists(path_str):
        return os.path.abspath(path_str)
    candidates = [
        os.path.join(_TOOLS_DIR, "blocksets", path_str),
        os.path.join(_TOOLS_DIR, "blocksets", os.path.basename(path_str)),
        os.path.join(_TOOLS_DIR, path_str),
        os.path.join(_TOOLS_DIR, os.path.basename(path_str)),
        os.path.join(os.getcwd(), path_str),
        os.path.join(os.getcwd(), "blocksets", path_str),
    ]
    for c in candidates:
        if os.path.exists(c):
            return os.path.abspath(c)
    return None


def apply_profile_globals(profile: dict) -> None:
    cvmod.GEN2_BUILDING_BLOCKS = set(profile.get("gen2_building_blocks") or set())


def load_lua_json_optional(lua_path: str):
    from map_layout_loader import load_lua_json, _find_lua_to_json

    tool = _find_lua_to_json()
    if tool and os.path.isfile(lua_path):
        data = load_lua_json(lua_path)
        if data is not None:
            return data
    tool_path = os.path.join("tools", "lua_to_json.lua")
    if os.path.exists(tool_path) and os.path.exists(lua_path):
        try:
            proc = subprocess.run(
                ["luajit", tool_path, lua_path], capture_output=True, text=True, check=True
            )
            return json.loads(proc.stdout)
        except Exception:
            return None
    return None


def _enrich_g2_tileset_rec(
    rec: dict | None,
    profile: dict,
    g2_tiles_raw: list,
) -> dict | None:
    """Extend PalMap + apply profile overrides so mapper bake matches restored dungeons."""
    if not rec:
        return rec
    rec = dict(rec)
    pals = list(rec.get("tilePalettes") or [])
    base_len = max(1, len(pals))

    max_tid = 0
    for row in g2_tiles_raw or []:
        for tid in row or []:
            try:
                max_tid = max(max_tid, int(tid))
            except (TypeError, ValueError):
                pass
    need = max(base_len, max_tid + 1, 100)
    while len(pals) < need:
        idx = len(pals)
        pals.append(pals[idx % base_len] if base_len else 1)
    rec["tilePalettes"] = pals

    for tid, slot in (profile.get("g2_tile_palette_overrides") or {}).items():
        idx = int(tid)
        if 0 <= idx < len(pals):
            pals[idx] = int(slot)

    return rec


def _load_restore_custom_blocks(attr_name: str | None) -> dict:
    if not attr_name:
        return {}
    restore_path = os.path.join(_TOOLS_DIR, "restore_kanto_dungeons.py")
    if not os.path.isfile(restore_path):
        return {}
    try:
        spec = importlib.util.spec_from_file_location("restore_kanto_dungeons", restore_path)
        if not spec or not spec.loader:
            return {}
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return dict(getattr(mod, attr_name, {}) or {})
    except Exception as exc:  # noqa: BLE001
        print(f"[block_mapper] Could not load {attr_name} from restore: {exc}")
        return {}


def _find_tilesets_lua(game: str) -> str | None:
    home = os.path.expanduser("~/.local/share/love/pokemon-love2d")
    candidates = [
        os.path.join(home, game, "data", "generated", "tilesets.lua"),
        os.path.join(home, "red", "data", "generated", "tilesets.lua") if game == "red" else None,
        "data/generated/tilesets.lua",
    ]
    for root in ("/home/autumn/src/gen1recomp", os.getcwd()):
        candidates.append(os.path.join(root, "data", "generated", "tilesets.lua"))
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    return None


def _palette_bake_for_profile(profile: dict, side: str) -> dict | None:
    if side == "g1":
        tileset_id = profile.get("g1_palette_env") or profile.get("g1_tileset_id")
        if tileset_id and not str(tileset_id).startswith("TILESET_"):
            return {"kind": "gen1", "tileset_id": str(tileset_id)}
        return None
    env = (profile.get("g2_palette_env") or "").upper()
    if not env or env == "NONE":
        return None
    return {
        "kind": "gen2",
        "environment": env,
        "daytime": profile.get("g2_palette_daytime") or "DAY",
        "game": profile.get("g2_game") or profile.get("game") or "gold",
    }


def _rebuild_blocks_for_tileset(
    tileset_id: str,
    game: str,
    tile_size: int,
    max_blocks=None,
    palette_bake: dict | None = None,
):
    from tileset_block_rebuild import find_tileset_image

    ts_path = _find_tilesets_lua(game)
    if not ts_path:
        return None, None, None, None, None
    ts_data = load_lua_json_optional(ts_path)
    if not ts_data or tileset_id not in ts_data:
        return None, None, None, None, None
    rec = ts_data[tileset_id]
    img = find_tileset_image(rec.get("image") or f"{tileset_id.lower()}.png", game=game)
    rebuilt = rebuild_blocks_from_tileset(
        rec,
        image_path=img,
        tile_size=tile_size,
        max_blocks=max_blocks,
        game=game,
        palette_bake=palette_bake,
    )
    tiles = list(rec.get("blocks") or [])
    coll = list(rec.get("collision") or [])
    return tiles, coll, rebuilt, rec, img


def _append_synthetic_g1_blocks(
    g1_raw: list,
    profile: dict,
    *,
    g1_ts_rec: dict | None,
    g1_sheet_path: str | None,
    g1_palette_bake: dict | None,
    g1_tiles_raw: list | None = None,
) -> list:
    """Append profile-defined synthetic Gen1 metatiles (e.g. ladder niche)."""
    synth_defs = profile.get("synthetic_g1_blocks") or []
    if not synth_defs:
        return g1_raw
    if not g1_ts_rec or not g1_sheet_path:
        print("[block_mapper] synthetic_g1_blocks skipped (no G1 tileset rebuild metadata)")
        return g1_raw
    block_px = int(profile.get("g1_block_size") or 32)
    tile_size = int(profile.get("g1_tile_size") or 8)
    out = list(g1_raw)
    tiles_out = list(g1_tiles_raw) if g1_tiles_raw is not None else None
    for spec in synth_defs:
        tiles = list(spec.get("tiles") or [])
        if len(tiles) != 16:
            print(f"[block_mapper] synthetic block '{spec.get('name', '?')}' needs 16 tiles")
            continue
        img = render_block_from_tile_ids(
            tiles,
            g1_ts_rec,
            g1_sheet_path,
            block_px=block_px,
            tile_size=tile_size,
            palette_bake=g1_palette_bake,
            game="red",
        )
        out.append(img)
        if tiles_out is not None:
            tiles_out.append(list(tiles))
        print(f"[block_mapper] Synthetic G1 block #{len(out) - 1}: {spec.get('name', 'custom')}")
    if g1_tiles_raw is not None and tiles_out is not None:
        g1_tiles_raw[:] = tiles_out
    return out


def _load_g2_tileset_data(profile: dict):
    tileset_id = profile.get("g2_tileset_id") or "TILESET_KANTO"
    tile_size = int(profile.get("g2_tile_size") or 8)
    g2_game = profile.get("g2_game") or profile.get("game") or "gold"
    g2_palette_bake = _palette_bake_for_profile(profile, "g2")
    g2_tiles_raw, g2_coll_raw, rebuilt = None, None, None
    g2_ts_rec, g2_sheet_path = None, None
    for game in (g2_game, "gold", "silver", "crystal"):
        g2_tiles_raw, g2_coll_raw, rebuilt, g2_ts_rec, g2_sheet_path = _rebuild_blocks_for_tileset(
            tileset_id,
            game,
            tile_size,
            profile.get("g2_max_blocks"),
            palette_bake=g2_palette_bake,
        )
        if g2_tiles_raw:
            break
    g2_tiles_raw = g2_tiles_raw or []
    g2_coll_raw = g2_coll_raw or []
    custom = _load_restore_custom_blocks(profile.get("custom_blocks_source"))
    if custom:
        max_id = max([len(g2_tiles_raw) - 1] + list(custom.keys()))
        while len(g2_tiles_raw) <= max_id:
            g2_tiles_raw.append([0] * 16)
            g2_coll_raw.append([0x07] * 4)
        for idx, c_def in custom.items():
            g2_tiles_raw[idx] = list(c_def["tiles"])
            g2_coll_raw[idx] = list(c_def["collision"])
    g2_ts_rec = _enrich_g2_tileset_rec(g2_ts_rec, profile, g2_tiles_raw)
    if rebuilt:
        print(f"[block_mapper] Rebuilt {len(rebuilt)} G2 blocks from Gold '{tileset_id}'")
    return g2_tiles_raw, g2_coll_raw, rebuilt, g2_ts_rec, g2_sheet_path, g2_palette_bake


def prepare_mapping_session(
    profile: dict,
    g1_sheet_path: str | None = None,
    g2_sheet_path: str | None = None,
    out_file: str | None = None,
    exclude_buildings: bool | None = None,
) -> MappingSession:
    """Slice sheets + CV precompute. Raises on failure (caller wraps for queue)."""
    apply_profile_globals(profile)

    g1_sheet_path = g1_sheet_path or resolve_sheet_path(profile.get("g1_sheet"))
    g2_sheet_path = g2_sheet_path or (
        resolve_sheet_path(profile.get("g2_sheet")) if profile.get("g2_sheet") else None
    )
    out_file = out_file or os.path.join(_TOOLS_DIR, profile.get("out") or "g1_to_g2.py")
    if exclude_buildings is None:
        exclude_buildings = bool(profile.get("exclude_buildings", True))

    slice_g1_w = profile.get("g1_block_size") or 32
    slice_g2_w = profile.get("g2_block_size") or 32
    g1_ts_rec = None
    g1_palette_bake = _palette_bake_for_profile(profile, "g1")
    g1_tiles_raw = None

    if g1_sheet_path and os.path.isfile(g1_sheet_path):
        g1_raw = cvmod.slice_sheet(
            g1_sheet_path,
            cols=16,
            block_w=slice_g1_w,
            block_h=slice_g1_w,
            is_card_sheet=bool(profile.get("g1_card_sheet")),
            max_blocks=profile.get("g1_max_blocks") or 128,
        )
    elif profile.get("g1_tileset_id"):
        g1_tiles_raw, _, g1_raw, g1_ts_rec, g1_sheet_path = _rebuild_blocks_for_tileset(
            profile["g1_tileset_id"],
            "red",
            int(profile.get("g1_tile_size") or 8),
            profile.get("g1_max_blocks"),
            palette_bake=g1_palette_bake,
        )
        if not g1_raw:
            raise FileNotFoundError(
                f"Gen1 sheet missing and rebuild of {profile.get('g1_tileset_id')} failed"
            )
        print(f"[block_mapper] Rebuilt {len(g1_raw)} G1 blocks from Red '{profile.get('g1_tileset_id')}'")
    else:
        raise FileNotFoundError(f"Gen 1 sheet not found: {profile.get('g1_sheet')}")

    g1_raw = _append_synthetic_g1_blocks(
        g1_raw,
        profile,
        g1_ts_rec=g1_ts_rec,
        g1_sheet_path=g1_sheet_path,
        g1_palette_bake=g1_palette_bake,
        g1_tiles_raw=g1_tiles_raw,
    )

    g2_tiles_raw, g2_coll_raw, rebuilt_g2, g2_ts_rec, g2_sheet_path, g2_palette_bake = _load_g2_tileset_data(profile)

    # g2_sheet_path is the per-tile atlas (e.g. cave.png) — never slice it as a block sheet.
    g2_block_sheet = g2_sheet_path or resolve_sheet_path(profile.get("g2_sheet"))
    if g2_block_sheet and os.path.isfile(g2_block_sheet) and g2_block_sheet != g2_sheet_path:
        g2_raw = cvmod.slice_sheet(
            g2_block_sheet,
            cols=16,
            block_w=slice_g2_w,
            block_h=slice_g2_w,
            is_card_sheet=bool(profile.get("g2_card_sheet")),
            max_blocks=profile.get("g2_max_blocks") or 160,
        )
    elif rebuilt_g2:
        g2_raw = list(rebuilt_g2)
        print(f"[block_mapper] Using Gold tileset rebuild for G2 ({len(g2_raw)} blocks)")
    else:
        raise FileNotFoundError(
            f"Gen 2 block sheet '{profile.get('g2_sheet')}' not found and tileset rebuild failed"
        )

    synth = profile.get("synthesize")
    if callable(synth):
        synth(g1_raw, g2_raw)
    elif profile.get("id") in ("safari_kanto", "forest_kanto"):
        cvmod.synthesize_mt_moon_custom_stairs(g1_raw, g2_raw)

    if not g1_raw or not g2_raw:
        raise RuntimeError("Failed to extract blocks from sheets")

    w1, _ = g1_raw[0].size
    w2, _ = g2_raw[0].size
    lcm_size = cvmod.calculate_lcm(w1, w2)
    g1_norm = cvmod.normalize_blocks(g1_raw, lcm_size)
    g2_norm = cvmod.normalize_blocks(g2_raw, lcm_size)

    g1_np = [np.array(b) for b in g1_norm]
    g2_np = [np.array(b) for b in g2_norm]

    unique_pool = cvmod.build_unique_quadrant_pool(
        g2_np,
        g2_coll_raw,
        exclude_buildings=exclude_buildings,
        g2_tiles_raw=g2_tiles_raw,
        uniform_tiles=profile.get("g2_pool_uniform_tiles"),
        extra_tile_keys=profile.get("g2_pool_extra_tile_keys"),
        g2_ts_rec=g2_ts_rec,
        g2_sheet_path=g2_sheet_path,
        g2_palette_bake=g2_palette_bake,
        g2_game=profile.get("g2_game") or profile.get("game") or "gold",
        g2_tile_size=int(profile.get("g2_tile_size") or 8),
    )
    print(f"[block_mapper] Unique quads: {len(unique_pool)}")
    base_quad = cvmod.compute_base_quadrant_rankings(g1_np, unique_pool, g1_tiles_raw=g1_tiles_raw)
    block_rank = cvmod.compute_all_block_rankings(g1_np, g2_np)

    preview = load_test_map(profile)
    if preview:
        print(f"[block_mapper] Preview map: {preview['map_id']} ({preview['width']}x{preview['height']})")

    return MappingSession(
        profile=dict(profile),
        g1_images=g1_norm,
        g2_images=g2_norm,
        block_rankings=block_rank,
        base_quad_rankings=base_quad,
        unique_quad_pool=unique_pool,
        g2_tiles_raw=g2_tiles_raw,
        g2_coll_raw=g2_coll_raw,
        g2_ts_rec=g2_ts_rec,
        g2_sheet_path=g2_sheet_path,
        g2_palette_bake=g2_palette_bake,
        out_path=out_file,
        dict_name=profile.get("dict_name") or "G1_TO_G2",
        custom_blocks_name=profile.get("custom_blocks_name") or "CUSTOM_BLOCKS_GENERATED",
        exclude_buildings=exclude_buildings,
        preview_map=preview,
        g1_block_px=w1,
        g2_block_px=w2,
        is_dirty=False,
    )


def preview_tilesets_for_profile(profile: dict) -> list[str]:
    pts = list(profile.get("preview_tilesets") or [])
    if not pts and profile.get("g1_tileset_id"):
        pts = [profile["g1_tileset_id"]]
    return pts
