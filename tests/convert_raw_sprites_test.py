#!/usr/bin/env python3
"""Unit tests for convert_raw_sprites shade map + strip metadata."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

TOOLS = Path(__file__).resolve().parents[1] / "tools"
sys.path.insert(0, str(TOOLS))
import convert_raw_sprites as C  # noqa: E402


def _vertical_strip(frames: list[Image.Image]) -> Image.Image:
    w, h = frames[0].size
    strip = Image.new("RGBA", (w, h * len(frames)), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (0, i * h))
    return strip


def _sample_frame(fill: tuple[int, int, int, int]) -> Image.Image:
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    px = im.load()
    for y in range(48):
        for x in range(48):
            if 10 <= x < 38 and 10 <= y < 38:
                px[x, y] = fill
            elif x == 10 or y == 10:
                px[x, y] = (0, 0, 0, 255)
            elif 12 <= x < 20 and 12 <= y < 20:
                px[x, y] = (255, 255, 255, 255)
    return im


class ConvertRawSpritesTest(unittest.TestCase):
    def test_dir_aliases(self):
        self.assertEqual(C.dir_to_species_id("Absol"), "ABSOL")
        self.assertEqual(C.dir_to_species_id("Mr.Mime"), "MR_MIME")
        self.assertEqual(C.dir_to_species_id("Porygon-Z"), "PORYGON_Z")
        self.assertEqual(C.dir_to_species_id("TypeNull"), "TYPE_NULL")
        self.assertEqual(C.dir_to_species_id("Flabébé"), "FLABEBE")

    def test_shade_map_four_colors(self):
        from collections import Counter

        counts = Counter(
            {
                (255, 255, 255): 10,
                (184, 120, 144): 8,
                (48, 48, 120): 6,
                (0, 0, 0): 4,
            }
        )
        m = C.build_shade_map(counts)
        self.assertEqual(m[(255, 255, 255)], 0)
        self.assertEqual(m[(0, 0, 0)], 3)
        self.assertEqual(m[(184, 120, 144)], 1)
        self.assertEqual(m[(48, 48, 120)], 2)

    def test_skip_hisui_form_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "0211. Qwilfish"
            hisui = root / "Hisui"
            johto = root / "Johto"
            hisui.mkdir(parents=True)
            johto.mkdir(parents=True)
            _vertical_strip([_sample_frame((255, 0, 0, 255))]).save(hisui / "front.png")
            _vertical_strip([_sample_frame((0, 0, 255, 255))]).save(johto / "front.png")
            picked = C.pick_dex_form_dir(root)
            self.assertIsNotNone(picked)
            self.assertEqual(picked.name, "Johto")

    def test_parse_dex_dir_mr_mime(self):
        parsed = C.parse_dex_dir_name("0122. Mr. Mime")
        self.assertEqual(parsed, (122, "MR_MIME"))

    def test_normalize_four_shade_cream_in_slot0(self):
        # Cream in shade-0 position must not push purple into the tan slot.
        out = C.normalize_four_shade(
            [
                [255, 236, 200],
                [104, 48, 136],
                [56, 28, 80],
                [0, 0, 0],
            ]
        )
        self.assertEqual(out[0], [255, 255, 255])
        self.assertEqual(out[1], [255, 236, 200])
        self.assertEqual(out[2], [104, 48, 136])
        self.assertEqual(out[3], [0, 0, 0])

    def test_build_shade_map_skips_slot0_for_body(self):
        from collections import Counter

        counts = Counter(
            {
                (255, 236, 200): 50,
                (104, 48, 136): 40,
                (0, 0, 0): 10,
            }
        )
        m = C.build_shade_map(counts)
        self.assertEqual(m[(255, 236, 200)], 1)
        self.assertEqual(m[(104, 48, 136)], 2)

    def test_gen12_strip_and_json_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            species = root / "assets" / "Gen_02_Johto" / "0152. Chikorita"
            species.mkdir(parents=True)
            frames = [
                _sample_frame((184, 120, 144, 255)),
                _sample_frame((48, 48, 120, 255)),
            ]
            _vertical_strip(frames).save(species / "front.png")
            back = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
            bp = back.load()
            for y in range(16, 32):
                for x in range(16, 32):
                    bp[x, y] = (184, 120, 144, 255)
            back.save(species / "back.png")

            rc = C.main(["--outdir", str(root)])
            self.assertEqual(rc, 0)
            front = root / "assets" / "gs" / "CHIKORITA_front.png"
            strip = root / "assets" / "gs" / "CHIKORITA_front_anim.png"
            back_out = root / "assets" / "gs" / "CHIKORITA_back.png"
            meta = root / "assets" / "gs" / "palettes" / "CHIKORITA.json"
            self.assertTrue(front.exists())
            self.assertTrue(strip.exists())
            self.assertTrue(back_out.exists())
            self.assertTrue(meta.exists())
            self.assertEqual(Image.open(front).size, (48, 48))
            self.assertEqual(Image.open(strip).size, (96, 48))
            self.assertEqual(Image.open(front).mode, "P")
            doc = json.loads(meta.read_text())
            self.assertEqual(doc["front"]["static"], "assets/gs/CHIKORITA_front.png")
            self.assertTrue(doc["front"]["static"].startswith("assets/gs/"))
            self.assertFalse(doc["front"]["static"].startswith("mods/"))
            self.assertEqual(doc["front"]["anim"]["frameCount"], 2)
            self.assertEqual(doc["front"]["anim"]["durationsMs"], [110, 110])
            self.assertIn("Gen_02_Johto", doc["source"])
            idx = (root / "pokemon" / "gs_index.lua").read_text()
            self.assertIn("CHIKORITA", idx)
            self.assertIn("frames = 2", idx)


if __name__ == "__main__":
    unittest.main()
