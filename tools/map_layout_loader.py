#!/usr/bin/env python3
"""Load Gen1 map block layouts for the live map preview pane."""

from __future__ import annotations

import json
import os
import subprocess
from typing import Any

_MAPS_CACHE: dict[str, Any] | None = None
_MAPS_CACHE_PATH: str | None = None

_TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
LEGEND_MAPS_DIR = os.path.join(_TOOLS_DIR, "legend_maps")


def _repo_roots() -> list[str]:
    here = os.path.dirname(os.path.abspath(__file__))
    mod_root = os.path.dirname(here)
    recomp = os.path.dirname(os.path.dirname(mod_root))
    return [recomp, mod_root, os.getcwd()]


def _find_lua_to_json() -> str | None:
    for root in _repo_roots():
        cand = os.path.join(root, "tools", "lua_to_json.lua")
        if os.path.isfile(cand):
            return cand
    return None


def _find_maps_lua() -> str | None:
    candidates = [
        "data/generated/maps.lua",
        os.path.expanduser("~/.local/share/love/pokemon-love2d/red/data/generated/maps.lua"),
    ]
    for root in _repo_roots():
        candidates.append(os.path.join(root, "data", "generated", "maps.lua"))
    for path in candidates:
        if os.path.isfile(path):
            return path
    return None


def load_lua_json(lua_path: str) -> dict[str, Any] | None:
    tool = _find_lua_to_json()
    if not tool or not os.path.isfile(lua_path):
        return None
    try:
        cwd = os.path.dirname(os.path.dirname(tool))
        proc = subprocess.run(
            ["luajit", tool, lua_path],
            capture_output=True,
            text=True,
            check=True,
            cwd=cwd,
        )
        return json.loads(proc.stdout)
    except Exception as exc:  # noqa: BLE001
        print(f"[map_layout_loader] load failed: {exc}")
        return None


def get_all_maps(force_reload: bool = False) -> dict[str, Any]:
    """Cached Gen1 maps.lua table."""
    global _MAPS_CACHE, _MAPS_CACHE_PATH
    path = _find_maps_lua()
    if not path:
        return {}
    if not force_reload and _MAPS_CACHE is not None and _MAPS_CACHE_PATH == path:
        return _MAPS_CACHE
    data = load_lua_json(path) or {}
    _MAPS_CACHE = data
    _MAPS_CACHE_PATH = path
    return data


def _validate_map_entry(map_id: str, mdef: dict[str, Any]) -> dict[str, Any] | None:
    width = int(mdef.get("width") or 0)
    height = int(mdef.get("height") or 0)
    blocks = list(mdef.get("blocks") or [])
    if not width or not height or not blocks:
        return None
    if len(blocks) != width * height:
        print(
            f"[map_layout_loader] Skip {map_id}: len(blocks)={len(blocks)} "
            f"!= width*height={width * height}"
        )
        return None
    return {
        "map_id": map_id,
        "width": width,
        "height": height,
        "blocks": blocks,
        "tileset": mdef.get("tileset"),
    }


def _legend_map_json_path(map_id: str) -> str:
    return os.path.join(LEGEND_MAPS_DIR, f"{map_id}.json")


def load_legend_map_json(map_id: str) -> dict[str, Any] | None:
    """Load a mod custom legendary room from tools/legend_maps/<id>.json."""
    if not map_id:
        return None
    path = _legend_map_json_path(map_id)
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as exc:  # noqa: BLE001
        print(f"[map_layout_loader] legend map load failed ({map_id}): {exc}")
        return None
    if not isinstance(data, dict):
        return None
    data.setdefault("map_id", map_id)
    return _validate_map_entry(str(data.get("map_id") or map_id), data)


def list_legend_maps_for_tilesets(tileset_ids) -> list[dict[str, Any]]:
    """Return sorted summaries for JSON legendary rooms matching tileset_ids."""
    wanted = {str(t) for t in (tileset_ids or []) if t}
    if not wanted or not os.path.isdir(LEGEND_MAPS_DIR):
        return []
    out: list[dict[str, Any]] = []
    for fname in sorted(os.listdir(LEGEND_MAPS_DIR)):
        if not fname.endswith(".json"):
            continue
        map_id = fname[:-5]
        validated = load_legend_map_json(map_id)
        if not validated:
            continue
        if validated.get("tileset") not in wanted:
            continue
        out.append(
            {
                "map_id": validated["map_id"],
                "width": validated["width"],
                "height": validated["height"],
                "tileset": validated["tileset"],
                "source": "legend_json",
            }
        )
    return out


def list_maps_for_tilesets(tileset_ids, *, profile: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    """Return sorted map summaries whose tileset is in tileset_ids."""
    wanted = {str(t) for t in (tileset_ids or []) if t}
    if not wanted:
        return []
    seen: set[str] = set()
    out: list[dict[str, Any]] = []

    extra_ids = list((profile or {}).get("preview_map_ids") or [])
    for map_id in extra_ids:
        validated = load_legend_map_json(map_id) or load_map_by_id(map_id)
        if validated and validated["map_id"] not in seen:
            seen.add(validated["map_id"])
            out.append(
                {
                    "map_id": validated["map_id"],
                    "width": validated["width"],
                    "height": validated["height"],
                    "tileset": validated.get("tileset"),
                    "source": "profile",
                }
            )

    for map_id, mdef in sorted(get_all_maps().items()):
        if not isinstance(mdef, dict):
            continue
        ts = mdef.get("tileset")
        if ts not in wanted:
            continue
        validated = _validate_map_entry(map_id, mdef)
        if validated and validated["map_id"] not in seen:
            seen.add(validated["map_id"])
            out.append(
                {
                    "map_id": validated["map_id"],
                    "width": validated["width"],
                    "height": validated["height"],
                    "tileset": validated["tileset"],
                    "source": "maps_lua",
                }
            )

    for row in list_legend_maps_for_tilesets(wanted):
        if row["map_id"] in seen:
            continue
        seen.add(row["map_id"])
        out.append(row)

    return sorted(out, key=lambda r: r["map_id"])


def list_preview_maps_for_profile(profile: dict[str, Any]) -> list[dict[str, Any]]:
    """Maps available in Map Preview for a block mapper profile."""
    pts = list(profile.get("preview_tilesets") or [])
    if not pts and profile.get("g1_tileset_id"):
        pts = [profile["g1_tileset_id"]]
    return list_maps_for_tilesets(pts, profile=profile)


def load_map_by_id(map_id: str) -> dict[str, Any] | None:
    """Load width/height/blocks for a map id (legend JSON, then host maps.lua)."""
    if not map_id:
        return None
    legend = load_legend_map_json(map_id)
    if legend:
        return legend
    maps = get_all_maps()
    mdef = maps.get(map_id)
    if not isinstance(mdef, dict):
        print(f"[map_layout_loader] Map '{map_id}' not found")
        return None
    return _validate_map_entry(map_id, mdef)


def load_test_map(profile: dict[str, Any]) -> dict[str, Any] | None:
    """
    Return {width, height, blocks, map_id} for the profile's test map.

    Resolution order:
      1. profile['test_map_json'] path (local JSON dump)
      2. Host Gen1 maps.lua entry profile['test_map_id']
    """
    json_path = profile.get("test_map_json")
    if json_path:
        if not os.path.isabs(json_path):
            json_path = os.path.join(os.path.dirname(__file__), json_path)
        if os.path.isfile(json_path):
            with open(json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            width = int(data["width"])
            height = int(data["height"])
            blocks = list(data["blocks"])
            if len(blocks) != width * height:
                print("[map_layout_loader] test_map_json size mismatch")
                return None
            return {
                "map_id": data.get("map_id") or data.get("id") or "local",
                "width": width,
                "height": height,
                "blocks": blocks,
                "tileset": data.get("tileset"),
            }

    map_id = profile.get("test_map_id")
    if not map_id:
        return None
    return load_map_by_id(map_id)
