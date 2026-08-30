#!/usr/bin/env python3
"""Emit JSON map layouts for legendary custom rooms (block mapper preview)."""

from __future__ import annotations

import json
import os

_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(_DIR, "legend_maps")

# Gen1 CAVERN (legend_regis.lua)
CAVERN_WALL, CAVERN_FLOOR, CAVERN_LADDER = 3, 1, 62

# Gen1 OVERWORLD (legend_mythicals.lua)
WALL, GRASS, COBBLE, WATER, LEDGE, STUMP, SAND = 15, 1, 85, 67, 26, 28, 10


def _chamber_blocks(w: int, h: int) -> list[int]:
    blocks: list[int] = []
    for y in range(h):
        for x in range(w):
            bid = CAVERN_FLOOR
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                bid = CAVERN_WALL
            elif x == 3 and y == 4:
                bid = CAVERN_LADDER
            blocks.append(bid)
    return blocks


def _fill_room(w: int, h: int, fn) -> list[int]:
    blocks: list[int] = []
    for y in range(h):
        for x in range(w):
            blocks.append(fn(x, y, w, h))
    return blocks


def _sky_pillar_blocks(w: int, h: int) -> list[int]:
    def fn(x, y, mw, mh):
        if x == 0 or y == 0 or x == mw - 1 or y == mh - 1:
            return WALL
        if y == 1 and 2 <= x <= mw - 3:
            return LEDGE
        if x in (4, 5) and y == 2:
            return STUMP
        if x in (4, 5):
            return COBBLE
        return GRASS

    return _fill_room(w, h, fn)


def _ilex_blocks(w: int, h: int) -> list[int]:
    def fn(x, y, mw, mh):
        if x == 0 or y == 0 or x == mw - 1 or y == mh - 1:
            return WALL
        if x in (4, 5) and y == 2:
            return STUMP
        if 3 <= x <= 6 and 3 <= y <= 5:
            return COBBLE
        return GRASS

    return _fill_room(w, h, fn)


def _birth_island_blocks(w: int, h: int) -> list[int]:
    def fn(x, y, mw, mh):
        if x == 0 or y == 0 or x == mw - 1 or y == mh - 1:
            return WALL
        on_isle = 3 <= x <= 6 and 2 <= y <= 5
        if on_isle:
            if x in (4, 5) and y in (3, 4):
                return COBBLE
            return SAND
        return WATER

    return _fill_room(w, h, fn)


def _write_map(path: str, payload: dict) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    cw, ch = 8, 6
    sw, sh = 10, 8

    maps = [
        {
            "map_id": "REGIROCK_CHAMBER",
            "tileset": "CAVERN",
            "width": cw,
            "height": ch,
            "blocks": _chamber_blocks(cw, ch),
            "note": "Regirock seal room (legend_regis.lua)",
        },
        {
            "map_id": "SKY_PILLAR_KANT",
            "tileset": "OVERWORLD",
            "width": sw,
            "height": sh,
            "blocks": _sky_pillar_blocks(sw, sh),
            "note": "Rayquaza plaza (legend_mythicals.lua)",
        },
        {
            "map_id": "ILEX_SHRINE_KANT",
            "tileset": "OVERWORLD",
            "width": sw,
            "height": sh,
            "blocks": _ilex_blocks(sw, sh),
            "note": "Celebi shrine (legend_mythicals.lua)",
        },
        {
            "map_id": "BIRTH_ISLAND_KANT",
            "tileset": "OVERWORLD",
            "width": sw,
            "height": sh,
            "blocks": _birth_island_blocks(sw, sh),
            "note": "Deoxys island (legend_mythicals.lua)",
        },
    ]

    for m in maps:
        out = os.path.join(OUT_DIR, f"{m['map_id']}.json")
        _write_map(out, m)
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
