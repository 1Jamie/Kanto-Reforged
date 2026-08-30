#!/usr/bin/env python3
"""Build Gen2-only legendary map data from HITL block mapper exports.

Regirock chamber uses the same CAVERN → TILESET_CAVE mapping as restored dungeons
(tools/cave_g1_to_g2.py). Only the synthetic ladder-niche block (#128) is extra.

Gen1 runtime is unchanged: legend_regis.lua / legend_mythicals.register() keep
native CAVERN / OVERWORLD tilesets and block IDs.
"""

from __future__ import annotations

import importlib.util
import json
import os
from typing import Any

_TOOLS = os.path.dirname(os.path.abspath(__file__))
_MOD = os.path.dirname(_TOOLS)
_LEGEND_MAPS = os.path.join(_TOOLS, "legend_maps")
_OUT = os.path.join(_MOD, "world", "legend_maps_data.lua")

# Gen1 semantic block ids (must match legend_regis.lua / legend_mythicals.lua)
REGI_G1 = {"floor": 1, "wall": 3, "ladder": 62}
# Synthetic block appended by cavern_cave profile (Regirock B1F ladder niche).
REGI_LADDER_NICHE_G1 = 128

MYTH_G1 = {
    "WALL": 15,
    "GRASS": 1,
    "COBBLE": 85,
    "WATER": 67,
    "LEDGE": 26,
    "STUMP": 28,
    "SAND": 10,
}


def _load_export(stem: str) -> dict[str, Any] | None:
    path = os.path.join(_TOOLS, f"{stem}.py")
    if not os.path.isfile(path):
        return None
    spec = importlib.util.spec_from_file_location(stem, path)
    if not spec or not spec.loader:
        return None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.__dict__


def _remap_blocks(blocks: list[int], mapping: dict[int, int]) -> list[int]:
    return [int(mapping.get(int(bid), int(bid))) for bid in blocks]


def _load_legend_json(map_id: str) -> dict[str, Any] | None:
    path = os.path.join(_LEGEND_MAPS, f"{map_id}.json")
    if not os.path.isfile(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _remap_name_table(names: dict[str, int], mapping: dict[int, int]) -> dict[str, int]:
    return {k: int(mapping.get(int(v), int(v))) for k, v in names.items()}


def _rock_tunnel_patch_index() -> int:
    bx, by, width = 9, 4, 20
    return by * width + bx + 1


def _load_cave_export() -> tuple[dict[int, int], dict[int, dict]]:
    cave_mod = _load_export("cave_g1_to_g2") or {}
    cave_map = {int(k): int(v) for k, v in (cave_mod.get("CAVE_G1_TO_G2") or {}).items()}
    cave_custom = {int(k): v for k, v in (cave_mod.get("CUSTOM_CAVE_BLOCKS_GENERATED") or {}).items()}
    return cave_map, cave_custom


def build_data() -> dict[str, Any]:
    cave_map, cave_custom = _load_cave_export()
    myth_mod = _load_export("legend_mythical_g1_to_g2") or {}
    myth_map: dict[int, int] = {int(k): int(v) for k, v in (myth_mod.get("LEGEND_MYTHICAL_G1_TO_G2") or {}).items()}

    regi_core_ready = {REGI_G1["floor"], REGI_G1["wall"], REGI_G1["ladder"]}.issubset(cave_map.keys())
    ladder_g2 = cave_map.get(REGI_LADDER_NICHE_G1)
    regi_ready = regi_core_ready and ladder_g2 is not None
    myth_ready = set(MYTH_G1.values()).issubset(myth_map.keys())

    regi: dict[str, Any] | None = None
    if regi_ready:
        chamber_src = _load_legend_json("REGIROCK_CHAMBER")
        niche_tiles = None
        ladder_id = int(ladder_g2)
        if ladder_id in cave_custom:
            niche_tiles = list(cave_custom[ladder_id].get("tiles") or [])
        regi = {
            "tileset": "TILESET_CAVE",
            "g1Tileset": "CAVERN",
            "caveMapping": "cave_g1_to_g2.py",
            "blocks": _remap_name_table(
                {"floor": REGI_G1["floor"], "wall": REGI_G1["wall"], "ladder": REGI_G1["ladder"]},
                cave_map,
            ),
            "ladderNicheBlock": ladder_id,
            "ladderNicheTiles": niche_tiles,
            "rockTunnelPatch": {
                "map": "ROCK_TUNNEL_B1F",
                "blockIndex": _rock_tunnel_patch_index(),
            },
        }
        if chamber_src:
            regi["chamber"] = {
                "width": int(chamber_src["width"]),
                "height": int(chamber_src["height"]),
                "blocks": _remap_blocks(list(chamber_src["blocks"]), cave_map),
                "borderBlock": int(cave_map[REGI_G1["wall"]]),
            }

    mythical: dict[str, Any] | None = None
    if myth_ready:
        g2_blocks = _remap_name_table(MYTH_G1, myth_map)
        maps: dict[str, Any] = {}
        for map_id in ("SKY_PILLAR_KANT", "ILEX_SHRINE_KANT", "BIRTH_ISLAND_KANT"):
            src = _load_legend_json(map_id)
            if not src:
                continue
            maps[map_id] = {
                "width": int(src["width"]),
                "height": int(src["height"]),
                "blocks": _remap_blocks(list(src["blocks"]), myth_map),
                "borderBlock": int(g2_blocks["WALL"]),
            }
        mythical = {
            "tileset": "TILESET_KANTO",
            "g1Tileset": "OVERWORLD",
            "blocks": g2_blocks,
            "maps": maps,
        }

    enabled = bool(regi and mythical and len(mythical.get("maps") or {}) == 3)
    return {
        "enabled": enabled,
        "regi": regi,
        "mythical": mythical,
        "notes": (
            "Regirock uses cave_g1_to_g2.py (same as restored dungeons). "
            "Gen1 play keeps CAVERN/OVERWORLD via legend_*.register()."
        ),
    }


def _lua_val(v: Any, indent: int = 0) -> str:
    sp = "  " * indent
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        if not v:
            return "{}"
        if all(isinstance(x, int) for x in v):
            parts = ",\n".join(f"{sp}  {x}" for x in v)
            return "{\n" + parts + ",\n" + sp + "}"
        inner = ", ".join(_lua_val(x, indent + 1) for x in v)
        return "{" + inner + "}"
    if isinstance(v, dict):
        lines = [f"{sp}{{"]
        for k, val in v.items():
            key = k if k.isidentifier() else f'["{k}"]'
            lines.append(f"{sp}  {key} = {_lua_val(val, indent + 1)},")
        lines.append(f"{sp}}}")
        return "\n".join(lines)
    return json.dumps(v)


def write_lua(data: dict[str, Any]) -> None:
    body = _lua_val(data, 0)
    text = (
        "-- legend_maps_data.lua\n"
        "-- Generated by tools/apply_legend_mappings.py\n"
        "-- Gen2-only: Gen1 keeps native CAVERN/OVERWORLD via legend_*.register().\n\n"
        f"return {body}\n"
    )
    os.makedirs(os.path.dirname(_OUT), exist_ok=True)
    with open(_OUT, "w", encoding="utf-8") as f:
        f.write(text)


def main() -> None:
    data = build_data()
    write_lua(data)
    status = "enabled" if data.get("enabled") else "pending (finish mapper exports)"
    print(f"Wrote {_OUT} [{status}]")

    cave_map, _ = _load_cave_export()
    myth_mod = _load_export("legend_mythical_g1_to_g2") or {}
    myth_have = {int(k) for k in (myth_mod.get("LEGEND_MYTHICAL_G1_TO_G2") or {})}

    if data.get("regi"):
        print("  regi: ready (via cave_g1_to_g2.py)")
    else:
        core = {REGI_G1["floor"], REGI_G1["wall"], REGI_G1["ladder"]}
        missing_core = sorted(core - set(cave_map.keys()))
        missing_ladder = [] if REGI_LADDER_NICHE_G1 in cave_map else [REGI_LADDER_NICHE_G1]
        if missing_core:
            print(f"  regi: cave export missing blocks {missing_core}")
        if missing_ladder:
            print(
                "  regi: map synthetic block #128 (ladder niche) in cavern_cave profile, "
                "re-export cave_g1_to_g2.py"
            )

    if data.get("mythical"):
        print("  mythical: ready for Gen2 apply")
    else:
        need = sorted(set(MYTH_G1.values()) - myth_have)
        print(f"  mythical: waiting on OVERWORLD blocks {need}")


if __name__ == "__main__":
    main()
