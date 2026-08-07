#!/usr/bin/env python3
"""Render Kanto-Reforged custom maps to PNG for visual QA."""

import json
import os
import sys

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools"))

import tiled_export as te  # noqa: E402

OUT_DIR = os.path.join(REPO, "mods", "expansion_pack", "map_previews")
MAPS_JSON = os.path.join(OUT_DIR, "maps.json")
BLOCK_PX = te.BLOCK_PX
CELL_PX = te.CELL_PX


def main():
    with open(MAPS_JSON, encoding="utf-8") as handle:
        maps = json.load(handle)

    tilesets = te.load_generated("tilesets")
    colors = te.PALETTES["dmg"]
    ow = tilesets["OVERWORLD"]
    atlas, columns, _rows = te.build_block_atlas(ow, colors)

    def block_image(block_id):
        if block_id < 0 or block_id >= len(te.as_list(ow.get("blocks"))):
            img = Image.new("RGB", (BLOCK_PX, BLOCK_PX), te.INVALID_TILE_COLOR)
            return img
        ax = (block_id % columns) * BLOCK_PX
        ay = (block_id // columns) * BLOCK_PX
        return atlas.crop((ax, ay, ax + BLOCK_PX, ay + BLOCK_PX))

    reports = []
    for map_id, mdef in maps.items():
        w, h = int(mdef["width"]), int(mdef["height"])
        blocks = te.as_list(mdef["blocks"])
        expected = w * h
        ok = len(blocks) == expected
        img = Image.new("RGB", (w * BLOCK_PX, h * BLOCK_PX), colors[3])
        bad_ids = []
        for i, bid in enumerate(blocks):
            bid = int(bid)
            bx, by = i % w, i // w
            tile = block_image(bid)
            if tile.getpixel((0, 0)) == te.INVALID_TILE_COLOR:
                bad_ids.append(bid)
            img.paste(tile, (bx * BLOCK_PX, by * BLOCK_PX))

        draw = ImageDraw.Draw(img)
        # Mark warps (cell coords) in cyan
        for warp in mdef.get("warps") or []:
            cx, cy = int(warp["x"]), int(warp["y"])
            x0, y0 = cx * CELL_PX, cy * CELL_PX
            draw.rectangle([x0, y0, x0 + CELL_PX - 1, y0 + CELL_PX - 1],
                           outline=(0, 220, 255), width=2)
            draw.line([x0, y0, x0 + CELL_PX - 1, y0 + CELL_PX - 1],
                      fill=(0, 220, 255), width=1)
        # Mark objects in magenta
        for obj in mdef.get("objects") or []:
            cx, cy = int(obj["x"]), int(obj["y"])
            x0, y0 = cx * CELL_PX, cy * CELL_PX
            draw.rectangle([x0, y0, x0 + CELL_PX - 1, y0 + CELL_PX - 1],
                           outline=(255, 0, 200), width=2)

        path = os.path.join(OUT_DIR, "%s.png" % map_id)
        # Upscale 2x for readability
        big = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
        big.save(path)

        unique = sorted(set(int(b) for b in blocks))
        reports.append({
            "id": map_id,
            "path": path,
            "size": "%dx%d blocks (%dx%d px @1x)" % (w, h, img.width, img.height),
            "block_count_ok": ok,
            "expected_blocks": expected,
            "actual_blocks": len(blocks),
            "unique_block_ids": unique,
            "bad_block_ids": sorted(set(bad_ids)),
            "warps": mdef.get("warps") or [],
            "objects": mdef.get("objects") or [],
        })
        print("wrote", path)

    with open(os.path.join(OUT_DIR, "report.json"), "w", encoding="utf-8") as handle:
        json.dump(reports, handle, indent=2)
        handle.write("\n")

    for row in reports:
        print("---", row["id"])
        print(" ", row["size"], "blocks_ok=", row["block_count_ok"])
        print("  unique blocks:", row["unique_block_ids"])
        print("  bad/magenta ids:", row["bad_block_ids"])
        print("  warps:", row["warps"])
        print("  objects:", [(o["name"], o["x"], o["y"]) for o in row["objects"]])


if __name__ == "__main__":
    main()
