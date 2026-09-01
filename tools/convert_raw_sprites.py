#!/usr/bin/env python3
"""Convert sprite sources → Gen1/Gen2 grayscale indexed PNGs under assets/gs.

Standalone only — do NOT import or call generate_pokemon_mod.py.

Sources:
  --source gen12   assets/Gen_01_Kanto + Gen_02_Johto (default --max-dex 251)
  --source hoenn   assets/Gen_03_Hoenn (national 252–386)

Maintenance:
  --prune-gs       drop missing files + post-Gen3 from gs/gs_index

Writes:
  assets/gs/<ID>_front.png / _back.png / _front_anim.png
  assets/gs/palettes/<ID>.json
  pokemon/gs_index.lua
  pokemon/gs_palettes.lua   — runtime table compiled from the JSON palettes
  pokemon/flat_index.lua

Castform Forecast forms (from Gen_03_Hoenn/0351. Castform):
  assets/gs/CASTFORM_{front,back,front_anim}.png     — Normal (DMG)
  assets/gs/CASTFORM_{SUNNY,RAINY,SNOWY}_{front,back,front_anim}.png
  assets/gs/palettes/CASTFORM_{SUNNY,RAINY,SNOWY}.json
      — same DMG + palette pipeline as every other gs mon

JSON paths are mod-relative: assets/gs/... (never mods/<id>/...).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

TOOLS_DIR = Path(__file__).resolve().parent
MOD_ROOT = TOOLS_DIR.parent

DMG_SHADE_RGB = [
    (255, 255, 255),
    (170, 170, 170),
    (85, 85, 85),
    (0, 0, 0),
]

# Folder name → SPECIES_ID when PascalCase→snake is wrong.
DIR_ALIASES = {
    "Mr.Mime": "MR_MIME",
    "Mr. Mime": "MR_MIME",
    "Flabébé": "FLABEBE",
    "Porygon-Z": "PORYGON_Z",
    "Porygon2": "PORYGON2",
    "TypeNull": "TYPE_NULL",
    "Chi-Yu": "CHI_YU",
    "Wo-Chien": "WO_CHIEN",
    "Chien-Pao": "CHIEN_PAO",
    "Ting-Lu": "TING_LU",
    "Ho-Oh": "HO_OH",
    "Ho Oh": "HO_OH",
    "HoOh": "HO_OH",
}

# Regional / alt-form folders we never bake (e.g. Hisui-only sheets in Gen_01/02).
SKIP_FORM_DIR_NAMES = frozenset({"hisui"})

DEFAULT_FORM_NAMES = (
    "Regular",
    "Kanto",
    "Johto",
    "Normal",
    "Plant",
    "Overcast",
    "West",
    "Male",
    "Average",
    "Midday",
    "Amped",
    "FullBelly",
    "IceFace",
    "Meteor",
    "Shield",
    "Aria",
    "Land",
    "Incarnate",
    "Ordinary",
    "Baile",
    "Solo",
    "50",
    "Red",
    "Spring",
    "Altered",
    "A",
)


def skip_form_dir(name: str) -> bool:
    return name.casefold() in SKIP_FORM_DIR_NAMES


def dir_to_species_id(name: str) -> str:
    if name in DIR_ALIASES:
        return DIR_ALIASES[name]
    # PascalCase / digits → UPPER_SNAKE
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name)
    s = s.replace("-", "_").replace(".", "_").replace("'", "")
    s = re.sub(r"_+", "_", s).strip("_")
    return s.upper()


def luma(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return 0.299 * r + 0.587 * g + 0.114 * b


def is_transparent(rgba: tuple[int, ...]) -> bool:
    if len(rgba) < 4:
        return False
    r, g, b, a = rgba[0], rgba[1], rgba[2], rgba[3]
    if a < 16:
        return True
    # GIF matte sometimes stores transparent as yellow with a=0 already handled;
    # also treat near-magenta/yellow zero-alpha leftovers.
    return a == 0


def is_matte_white(rgba: tuple[int, ...], threshold: int = 250) -> bool:
    """Opaque near-white — Gen_03_Hoenn sheets use this as the canvas matte."""
    if len(rgba) < 4:
        return False
    r, g, b, a = rgba[0], rgba[1], rgba[2], rgba[3]
    return a >= 16 and r >= threshold and g >= threshold and b >= threshold


def strip_edge_background(frame: Image.Image, threshold: int = 250) -> Image.Image:
    """Flood-fill near-white (and already-clear) pixels connected to the edge → alpha 0.

    Preserves interior white highlights that are not connected to the canvas border.
    """
    from collections import deque

    img = frame.convert("RGBA").copy()
    w, h = img.size
    px = img.load()
    seen = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
            return
        rgba = px[x, y]
        if is_transparent(rgba) or is_matte_white(rgba, threshold):
            seen[y][x] = True
            q.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        seed(x + 1, y)
        seed(x - 1, y)
        seed(x, y + 1)
        seed(x, y - 1)
    return img


def collect_opaque_colors(img: Image.Image) -> Counter:
    rgba = img.convert("RGBA")
    counts: Counter = Counter()
    for count, color in rgba.getcolors(maxcolors=1_000_000) or []:
        if is_transparent(color):
            continue
        rgb = (color[0], color[1], color[2])
        counts[rgb] += count
    return counts


def load_frames(path: Path) -> tuple[list[Image.Image], list[int]]:
    """Return RGBA frames and durations_ms (default 110)."""
    frames: list[Image.Image] = []
    durations: list[int] = []
    with Image.open(path) as im:
        n = getattr(im, "n_frames", 1) or 1
        for i in range(n):
            if n > 1:
                im.seek(i)
            frames.append(strip_edge_background(im.convert("RGBA")))
            d = im.info.get("duration")
            try:
                durations.append(int(d) if d is not None else 110)
            except (TypeError, ValueError):
                durations.append(110)
    return frames, durations


def load_vertical_strip_frames(path: Path) -> tuple[list[Image.Image], list[int]]:
    """Gen_03_Hoenn front.png is a vertical stack of square frames."""
    with Image.open(path) as im:
        rgba = im.convert("RGBA")
    w, h = rgba.size
    if h > w and w > 0 and h % w == 0:
        n = h // w
        frames = [
            strip_edge_background(rgba.crop((0, i * w, w, (i + 1) * w)))
            for i in range(n)
        ]
    else:
        frames = [strip_edge_background(rgba)]
    durations = [110] * len(frames)
    return frames, durations


def build_shade_map(color_counts: Counter) -> dict[tuple[int, int, int], int]:
    """Map RGB → DMG shade index 0..3 (light→dark)."""
    colors = list(color_counts.keys())
    if not colors:
        return {}

    white = (255, 255, 255)
    black = (0, 0, 0)
    pinned: dict[tuple[int, int, int], int] = {}
    rest = []
    for c in colors:
        if c == white:
            pinned[c] = 0
        elif c == black:
            pinned[c] = 3
        else:
            rest.append(c)

    rest_sorted = sorted(rest, key=luma, reverse=True)
    # Shade 0 is SGB matte white — only exact white may use it.
    free_slots = [i for i in range(4) if i not in pinned.values()]
    if 0 in free_slots and white not in pinned:
        free_slots = [s for s in free_slots if s != 0]
    mapping = dict(pinned)
    for c in rest_sorted:
        if not free_slots:
            target = min(
                mapping.keys(),
                key=lambda k: abs(luma(k) - luma(c)),
            )
            mapping[c] = mapping[target]
        else:
            mapping[c] = free_slots.pop(0)

    # If more than 4 distinct and some unmapped via collapse — already handled.
    # Ensure every counted color maps.
    for c in colors:
        if c not in mapping:
            mapping[c] = min(range(4), key=lambda i: abs(luma(DMG_SHADE_RGB[i]) - luma(c)))
    return mapping


def nearest_shade(rgb: tuple[int, int, int], shade_map: dict) -> int:
    if rgb in shade_map:
        return shade_map[rgb]
    return min(
        shade_map.items(),
        key=lambda kv: abs(luma(kv[0]) - luma(rgb)),
        default=((0, 0, 0), 3),
    )[1]


def frame_to_indexed(frame: Image.Image, shade_map: dict) -> Image.Image:
    w, h = frame.size
    out = Image.new("P", (w, h), 0)
    palette = []
    # Index 0 = transparent
    palette.extend([0, 0, 0])
    for rgb in DMG_SHADE_RGB:
        palette.extend(rgb)
    while len(palette) < 768:
        palette.append(0)
    out.putpalette(palette)
    px = frame.load()
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16:
                op[x, y] = 0
            else:
                shade = nearest_shade((r, g, b), shade_map)
                op[x, y] = shade + 1  # 1..4
    return out


def build_truecolor_order(color_counts: Counter, max_colors: int = 4) -> list[tuple[int, int, int]]:
    """Light→dark RGB list for Forecast form sheets (keep original hues)."""
    colors = list(color_counts.keys())
    if len(colors) <= max_colors:
        return sorted(colors, key=luma, reverse=True)
    # Collapse extras onto nearest kept color by luma, preferring high counts.
    kept = [c for c, _ in color_counts.most_common(max_colors)]
    kept = sorted(kept, key=luma, reverse=True)
    return kept


def frame_to_truecolor_indexed(
    frame: Image.Image,
    color_order: list[tuple[int, int, int]],
) -> Image.Image:
    """Indexed PNG with transparency=0 and original RGB palette entries 1..N."""
    w, h = frame.size
    out = Image.new("P", (w, h), 0)
    palette: list[int] = [0, 0, 0]
    for rgb in color_order:
        palette.extend(rgb)
    while len(palette) < 768:
        palette.append(0)
    out.putpalette(palette)
    px = frame.load()
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16:
                op[x, y] = 0
                continue
            rgb = (r, g, b)
            if rgb in color_order:
                op[x, y] = color_order.index(rgb) + 1
            else:
                nearest = min(color_order, key=lambda c: abs(luma(c) - luma(rgb)))
                op[x, y] = color_order.index(nearest) + 1
    return out


def save_indexed(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, transparency=0)


def make_strip(frames_indexed: list[Image.Image]) -> Image.Image:
    w, h = frames_indexed[0].size
    strip = Image.new("P", (w * len(frames_indexed), h), 0)
    strip.putpalette(frames_indexed[0].getpalette())
    for i, fr in enumerate(frames_indexed):
        strip.paste(fr, (i * w, 0))
    return strip


def _form_has_art(form_dir: Path) -> bool:
    return (
        (form_dir / "front.gif").exists()
        or (form_dir / "front.png").exists()
        or (form_dir / "back.png").exists()
    )


def pick_dex_form_dir(species_dir: Path) -> Path | None:
    """Pick default regional form under a ####. Name dex folder (never Hisui)."""
    if _form_has_art(species_dir):
        return species_dir

    subdirs = [d for d in species_dir.iterdir() if d.is_dir() and not skip_form_dir(d.name)]
    if not subdirs:
        return None

    by_name = {d.name: d for d in subdirs}
    for pref in DEFAULT_FORM_NAMES:
        if skip_form_dir(pref):
            continue
        cand = by_name.get(pref)
        if cand is not None and _form_has_art(cand):
            return cand
    for d in sorted(subdirs):
        if _form_has_art(d):
            return d
    return None


def pick_source_dir(species_dir: Path) -> Path | None:
    """Return directory that holds front/back for the default form."""
    return pick_dex_form_dir(species_dir)


def find_front(src_dir: Path) -> Path | None:
    for name in ("front.gif", "front.png"):
        p = src_dir / name
        if p.exists():
            return p
    return None


def find_back(src_dir: Path) -> Path | None:
    p = src_dir / "back.png"
    return p if p.exists() else None


def palette_ordered(shade_map: dict) -> list[list[int]]:
    """Original colors in DMG shade order 0..3 (first color that mapped to each)."""
    by_slot: dict[int, tuple[int, int, int]] = {}
    # Prefer higher pixel-count colors: caller may pass map only — use luma order of keys
    for rgb, slot in sorted(shade_map.items(), key=lambda kv: (kv[1], -luma(kv[0]))):
        if slot not in by_slot:
            by_slot[slot] = rgb
    out = []
    for i in range(4):
        if i in by_slot:
            out.append(list(by_slot[i]))
        else:
            out.append(list(DMG_SHADE_RGB[i]))
    return out


def convert_species(
    species_dir: Path,
    out_gs: Path,
    species_id: str,
) -> dict | None:
    src_dir = pick_source_dir(species_dir)
    if src_dir is None:
        return None

    front_path = find_front(src_dir)
    back_path = find_back(src_dir)
    if not front_path and not back_path:
        return None

    raw_root = species_dir.parent
    rel = src_dir.relative_to(raw_root).as_posix()
    result: dict = {
        "id": species_id,
        "source": f"RawSprites/{rel}",
        "warnings": [],
    }

    # --- Front ---
    if front_path:
        frames, durations = load_frames(front_path)
        counts: Counter = Counter()
        for fr in frames:
            counts.update(collect_opaque_colors(fr))
        if len(counts) > 4:
            result["warnings"].append(f"front has {len(counts)} opaque colors (expected ≤4)")
        shade_map = build_shade_map(counts)
        indexed_frames = [frame_to_indexed(fr, shade_map) for fr in frames]

        front_out = out_gs / f"{species_id}_front.png"
        save_indexed(indexed_frames[0], front_out)
        fw, fh = indexed_frames[0].size

        front_meta: dict = {
            "static": f"assets/gs/{species_id}_front.png",
            "frameSize": [fw, fh],
        }
        if len(indexed_frames) > 1:
            strip = make_strip(indexed_frames)
            strip_name = f"{species_id}_front_anim.png"
            save_indexed(strip, out_gs / strip_name)
            front_meta["anim"] = {
                "strip": f"assets/gs/{strip_name}",
                "frameCount": len(indexed_frames),
                "durationsMs": durations,
                "loop": True,
            }
        result["front"] = front_meta
        result["palette"] = palette_ordered(shade_map)
        result["_front_size"] = [fw, fh]
        result["_front_frames"] = len(indexed_frames)
    else:
        result["warnings"].append("missing front")

    # --- Back (own shade map; usually same colors) ---
    if back_path:
        bframes, _ = load_frames(back_path)
        bcounts = collect_opaque_colors(bframes[0])
        if len(bcounts) > 4:
            result["warnings"].append(f"back has {len(bcounts)} opaque colors (expected ≤4)")
        # Prefer front palette order when colors match; else rebuild.
        if "palette" in result:
            # Rebuild map but keep front's shade assignment for shared RGBs.
            front_map = {}
            for i, rgb in enumerate(result["palette"]):
                front_map[tuple(rgb)] = i
            b_shade = build_shade_map(bcounts)
            for rgb in b_shade:
                if rgb in front_map:
                    b_shade[rgb] = front_map[rgb]
        else:
            b_shade = build_shade_map(bcounts)
            result["palette"] = palette_ordered(b_shade)

        b_indexed = frame_to_indexed(bframes[0], b_shade)
        back_out = out_gs / f"{species_id}_back.png"
        save_indexed(b_indexed, back_out)
        bw, bh = b_indexed.size
        result["back"] = {
            "static": f"assets/gs/{species_id}_back.png",
            "frameSize": [bw, bh],
        }
        result["_back_size"] = [bw, bh]
    else:
        result["warnings"].append("missing back")

    return result


def write_palette_json(path: Path, result: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    doc = {
        "id": result["id"],
        "source": result.get("source"),
        "palette": result.get("palette"),
        "front": result.get("front"),
        "back": result.get("back"),
    }
    if result.get("warnings"):
        doc["warnings"] = result["warnings"]
    path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")


def write_gs_index(path: Path, entries: dict[str, dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lua_id = re.compile(r"^[A-Z][A-Z0-9_]*$")
    lines = [
        "-- Generated by tools/convert_raw_sprites.py. DO NOT EDIT.",
        "-- Compact index of assets/gs battle pics (sizes + anim frame counts).",
        "return {",
    ]
    for sid in sorted(entries.keys()):
        if not lua_id.match(sid):
            raise ValueError(f"invalid Lua species id {sid!r}")
        e = entries[sid]
        parts = []
        if "frontW" in e:
            parts.append(f"frontW = {e['frontW']}")
            parts.append(f"frontH = {e['frontH']}")
        if "backW" in e:
            parts.append(f"backW = {e['backW']}")
            parts.append(f"backH = {e['backH']}")
        if e.get("frames", 1) > 1:
            parts.append(f"frames = {e['frames']}")
        lines.append(f"  {sid} = {{ {', '.join(parts)} }},")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def write_flat_index(path: Path, assets_dir: Path) -> int:
    """Scan assets/*_{front,back}.png (not under gs/) into flat_index.lua."""
    fronts: dict[str, tuple[int, int]] = {}
    backs: dict[str, tuple[int, int]] = {}
    if assets_dir.is_dir():
        for p in assets_dir.glob("*_front.png"):
            stem = p.name[: -len("_front.png")].upper()
            try:
                with Image.open(p) as im:
                    fronts[stem] = im.size
            except OSError:
                fronts[stem] = (0, 0)
        for p in assets_dir.glob("*_back.png"):
            stem = p.name[: -len("_back.png")].upper()
            try:
                with Image.open(p) as im:
                    backs[stem] = im.size
            except OSError:
                backs[stem] = (0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "-- Generated by tools/convert_raw_sprites.py (flat asset scan). DO NOT EDIT.",
        "-- Species with machine-clamped PNGs under assets/ (not assets/gs/).",
        "return {",
    ]
    for sid in sorted(fronts.keys() | backs.keys()):
        parts = []
        if sid in fronts:
            fw, fh = fronts[sid]
            parts.append("front = true")
            if fw > 0 and fh > 0:
                parts.append(f"frontW = {fw}")
                parts.append(f"frontH = {fh}")
        if sid in backs:
            bw, bh = backs[sid]
            parts.append("back = true")
            if bw > 0 and bh > 0:
                parts.append(f"backW = {bw}")
                parts.append(f"backH = {bh}")
        lines.append(f"  {sid} = {{ {', '.join(parts)} }},")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    return len(fronts.keys() | backs.keys())


SGB_WHITE = (255, 255, 255)
SGB_BLACK = (0, 0, 0)


def _is_white(rgb: tuple[int, int, int]) -> bool:
    return rgb == SGB_WHITE


def _is_black(rgb: tuple[int, int, int]) -> bool:
    return rgb == SGB_BLACK


def extract_mid_shades(rgb4: list) -> tuple[list[int], list[int]]:
    """Two brightest non-white/non-black colors, for SGB slots 1 and 2."""
    mids: list[tuple[int, int, int]] = []
    for c in rgb4[:4]:
        if not (isinstance(c, (list, tuple)) and len(c) >= 3):
            continue
        rgb = (int(c[0]), int(c[1]), int(c[2]))
        if _is_white(rgb) or _is_black(rgb):
            continue
        mids.append(rgb)
    mids.sort(key=luma, reverse=True)
    if len(mids) >= 2:
        a, b = mids[0], mids[1]
        return [a[0], a[1], a[2]], [b[0], b[1], b[2]]
    if len(mids) == 1:
        return [mids[0][0], mids[0][1], mids[0][2]], list(DMG_SHADE_RGB[2])
    return list(DMG_SHADE_RGB[1]), list(DMG_SHADE_RGB[2])


def normalize_four_shade(rgb4: list) -> list:
    """Gen1/Gen2 engines pin shade 0 to white and shade 3 to black."""
    if len(rgb4) < 4:
        return rgb4
    light, dark = extract_mid_shades(rgb4)
    return [list(SGB_WHITE), light, dark, list(SGB_BLACK)]


def write_gs_palettes_lua(path: Path, pal_dir: Path) -> int:
    """Compact runtime table from assets/gs/palettes/*.json (id → 4 RGB triples).

    Runtime requires this (same pattern as gs_index) — JSON alone was never loaded.
    """
    entries: dict[str, list] = {}
    if pal_dir.is_dir():
        for p in sorted(pal_dir.glob("*.json")):
            try:
                doc = json.loads(p.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            sid = str(doc.get("id") or p.stem).upper()
            pal = doc.get("palette")
            if not isinstance(pal, list) or len(pal) < 4:
                continue
            rgb4 = []
            ok = True
            for c in pal[:4]:
                if not (isinstance(c, (list, tuple)) and len(c) >= 3):
                    ok = False
                    break
                rgb4.append([int(c[0]), int(c[1]), int(c[2])])
            if ok:
                entries[sid] = normalize_four_shade(rgb4)
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "-- Generated by tools/convert_raw_sprites.py from assets/gs/palettes/*.json.",
        "-- DO NOT EDIT. Runtime palette source for gs battle art (overrides",
        "-- species_palettes.lua when both define the same id).",
        "return {",
    ]
    for sid in sorted(entries.keys()):
        cols = entries[sid]
        parts = ", ".join(
            "{" + ", ".join(str(n) for n in rgb) + "}" for rgb in cols
        )
        lines.append(f"  {sid} = {{ {parts} }},")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    return len(entries)


def write_gs_anim_index(path: Path, pal_dir: Path) -> int:
    """Runtime anim metadata from assets/gs/palettes/*.json front.anim blocks."""
    entries: dict[str, dict] = {}
    if pal_dir.is_dir():
        for p in sorted(pal_dir.glob("*.json")):
            try:
                doc = json.loads(p.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            sid = str(doc.get("id") or p.stem).upper()
            front = doc.get("front") or {}
            anim = front.get("anim")
            if not isinstance(anim, dict):
                continue
            fc = int(anim.get("frameCount") or 0)
            if fc < 2:
                continue
            fs = front.get("frameSize") or []
            fw = int(fs[0]) if len(fs) >= 1 else 0
            fh = int(fs[1]) if len(fs) >= 2 else 0
            strip = anim.get("strip")
            if not (strip and fw > 0 and fh > 0):
                continue
            durs = anim.get("durationsMs") or []
            durations = [int(x) for x in durs[:fc]]
            while len(durations) < fc:
                durations.append(durations[-1] if durations else 100)
            entries[sid] = {
                "strip": str(strip),
                "frameCount": fc,
                "frontW": fw,
                "frontH": fh,
                "durations": durations,
                "loop": bool(anim.get("loop", True)),
            }
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "-- Generated by tools/convert_raw_sprites.py from assets/gs/palettes/*.json.",
        "-- DO NOT EDIT. Horizontal front_anim strips + per-frame timing (ms).",
        "return {",
    ]
    for sid in sorted(entries.keys()):
        e = entries[sid]
        dur = ", ".join(str(n) for n in e["durations"])
        loop = "true" if e["loop"] else "false"
        lines.append(
            f"  {sid} = {{ strip = {e['strip']!r}, frameCount = {e['frameCount']}, "
            f"frontW = {e['frontW']}, frontH = {e['frontH']}, "
            f"durations = {{ {dur} }}, loop = {loop} }},"
        )
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    return len(entries)


def refresh_gs_palettes_lua(outdir: Path) -> int:
    n = write_gs_palettes_lua(
        outdir / "pokemon" / "gs_palettes.lua",
        outdir / "assets" / "gs" / "palettes",
    )
    write_gs_anim_index(
        outdir / "pokemon" / "gs_anim_index.lua",
        outdir / "assets" / "gs" / "palettes",
    )
    return n


def load_pokeapi_name_to_dex() -> dict[str, int]:
    """Map SPECIES_ID / English name → national dex (cache covers 1–386)."""
    cache = Path(os.path.expanduser("~")) / "src/gen1recomp/tools/.cache/pokeapi/species"
    # Prefer repo-relative cache next to this mod's parent gen1recomp.
    alt = MOD_ROOT.parent.parent / "tools" / ".cache" / "pokeapi" / "species"
    if alt.is_dir():
        cache = alt
    out: dict[str, int] = {}
    if not cache.is_dir():
        return out
    for p in cache.glob("*.json"):
        try:
            s = json.loads(p.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        dex = int(s["id"])
        api = str(s.get("name") or "").upper().replace("-", "_")
        if api:
            out[api] = dex
        for n in s.get("names") or []:
            if (n.get("language") or {}).get("name") == "en":
                en = re.sub(r"[^A-Za-z0-9]+", "_", n.get("name") or "").strip("_").upper()
                if en:
                    out[en] = dex
                break
    # Common engine aliases
    out.setdefault("MR_MIME", 122)
    out.setdefault("FARFETCH_D", 83)
    out.setdefault("NIDORAN_F", 29)
    out.setdefault("NIDORAN_M", 32)
    out.setdefault("HO_OH", 250)
    out.setdefault("PORYGON2", 233)
    return out


def parse_gs_index(path: Path) -> dict[str, dict]:
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    entries: dict[str, dict] = {}
    for m in re.finditer(r"^\s+([A-Z0-9_]+)\s*=\s*\{([^}]*)\}", text, re.M):
        sid, body = m.group(1), m.group(2)
        e: dict = {}
        for key in ("frontW", "frontH", "backW", "backH", "frames"):
            mm = re.search(rf"{key}\s*=\s*(\d+)", body)
            if mm:
                e[key] = int(mm.group(1))
        entries[sid] = e
    return entries


def remove_gs_species(out_gs: Path, sid: str) -> None:
    for name in (
        f"{sid}_front.png",
        f"{sid}_back.png",
        f"{sid}_front_anim.png",
    ):
        p = out_gs / name
        if p.exists():
            p.unlink()
    pal = out_gs / "palettes" / f"{sid}.json"
    if pal.exists():
        pal.unlink()


def gs_files_present(out_gs: Path, sid: str, entry: dict) -> bool:
    """True when every indexed artifact for this species exists on disk."""
    if entry.get("frontW") and not (out_gs / f"{sid}_front.png").exists():
        return False
    if entry.get("backW") and not (out_gs / f"{sid}_back.png").exists():
        return False
    if int(entry.get("frames") or 1) > 1 and not (
        out_gs / f"{sid}_front_anim.png"
    ).exists():
        return False
    return True


def prune_gs_keep_gen12(
    outdir: Path,
    keep_max_dex: int = 386,
    dry_run: bool = False,
) -> tuple[int, int, int]:
    """Drop missing files + anything above keep_max_dex from gs + index.

    Default keep_max_dex=386 keeps Gen1–3. Post-Gen3 (unk / >386) is removed.
    Does not re-convert art.
    """
    out_gs = outdir / "assets" / "gs"
    idx_path = outdir / "pokemon" / "gs_index.lua"
    entries = parse_gs_index(idx_path)
    name_to_dex = load_pokeapi_name_to_dex()
    keep: dict[str, dict] = {}
    missing = 0
    post = 0
    for sid, entry in sorted(entries.items()):
        if not gs_files_present(out_gs, sid, entry):
            missing += 1
            print(f"PRUNE missing-files {sid}")
            if not dry_run:
                remove_gs_species(out_gs, sid)
            continue
        dex = name_to_dex.get(sid)
        if dex is None or dex > keep_max_dex:
            post += 1
            tag = "unk" if dex is None else str(dex)
            print(f"PRUNE out-of-range {sid} (dex={tag})")
            if not dry_run:
                remove_gs_species(out_gs, sid)
            continue
        keep[sid] = entry
    if not dry_run:
        write_gs_index(idx_path, keep)
        write_flat_index(outdir / "pokemon" / "flat_index.lua", outdir / "assets")
        refresh_gs_palettes_lua(outdir)
    print(
        f"Prune done: kept={len(keep)} removed_missing={missing} "
        f"removed_post={post}"
    )
    return len(keep), missing, post


def parse_dex_dir_name(name: str) -> tuple[int, str] | None:
    """'0252. Treecko' → (252, 'TREECKO'); '0122. Mr. Mime' → (122, 'MR_MIME')."""
    m = re.match(r"^(\d+)\.\s*(.+)$", name.strip())
    if not m:
        return None
    dex = int(m.group(1))
    raw = m.group(2).strip()
    sid = DIR_ALIASES.get(raw) or dir_to_species_id(raw)
    return dex, sid


parse_hoenn_dir_name = parse_dex_dir_name  # backwards compat


def convert_frames_and_back(
    frames: list[Image.Image],
    durations: list[int],
    back_img: Image.Image | None,
    out_gs: Path,
    species_id: str,
    source_label: str,
) -> dict:
    """Shared grayscale bake for Gen_01/02/03 dex-folder sprite trees."""
    frames = [strip_edge_background(fr) for fr in frames]
    if back_img is not None:
        back_img = strip_edge_background(back_img)
    result: dict = {
        "id": species_id,
        "source": source_label,
        "warnings": [],
    }
    counts: Counter = Counter()
    for fr in frames:
        counts.update(collect_opaque_colors(fr))
    if len(counts) > 4:
        result["warnings"].append(f"front has {len(counts)} opaque colors (expected ≤4)")
    shade_map = build_shade_map(counts)
    indexed_frames = [frame_to_indexed(fr, shade_map) for fr in frames]
    save_indexed(indexed_frames[0], out_gs / f"{species_id}_front.png")
    fw, fh = indexed_frames[0].size
    front_meta: dict = {
        "static": f"assets/gs/{species_id}_front.png",
        "frameSize": [fw, fh],
    }
    if len(indexed_frames) > 1:
        strip_name = f"{species_id}_front_anim.png"
        save_indexed(make_strip(indexed_frames), out_gs / strip_name)
        front_meta["anim"] = {
            "strip": f"assets/gs/{strip_name}",
            "frameCount": len(indexed_frames),
            "durationsMs": durations,
            "loop": True,
        }
    result["front"] = front_meta
    result["palette"] = palette_ordered(shade_map)
    result["_front_size"] = [fw, fh]
    result["_front_frames"] = len(indexed_frames)

    if back_img is not None:
        bcounts = collect_opaque_colors(back_img)
        if len(bcounts) > 4:
            result["warnings"].append(f"back has {len(bcounts)} opaque colors")
        front_map = {tuple(rgb): i for i, rgb in enumerate(result["palette"])}
        b_shade = build_shade_map(bcounts)
        for rgb in list(b_shade):
            if rgb in front_map:
                b_shade[rgb] = front_map[rgb]
        b_indexed = frame_to_indexed(back_img, b_shade)
        save_indexed(b_indexed, out_gs / f"{species_id}_back.png")
        bw, bh = b_indexed.size
        result["back"] = {
            "static": f"assets/gs/{species_id}_back.png",
            "frameSize": [bw, bh],
        }
        result["_back_size"] = [bw, bh]
    else:
        result["warnings"].append("missing back")
    return result


def convert_dex_folder_species(
    species_dir: Path,
    out_gs: Path,
    species_id: str,
    source_tree: str,
) -> dict | None:
    """Flat layout or form subdirs (Kanto/Johto/Regular — never Hisui)."""
    src = pick_dex_form_dir(species_dir)
    if src is None:
        return None
    front_path = src / "front.png"
    back_path = src / "back.png"
    if not front_path.exists() and not back_path.exists():
        return None
    frames: list[Image.Image] = []
    durations: list[int] = []
    if front_path.exists():
        frames, durations = load_vertical_strip_frames(front_path)
    back_img = None
    if back_path.exists():
        with Image.open(back_path) as im:
            back_img = im.convert("RGBA").copy()
    if not frames and back_img is None:
        return None
    if not frames:
        frames = [Image.new("RGBA", back_img.size, (0, 0, 0, 0))]
        durations = [110]
    label = f"{source_tree}/{species_dir.name}"
    if src != species_dir:
        label += f"/{src.name}"
    return convert_frames_and_back(
        frames,
        durations,
        back_img,
        out_gs,
        species_id,
        label,
    )


def convert_hoenn_species(species_dir: Path, out_gs: Path, species_id: str) -> dict | None:
    return convert_dex_folder_species(species_dir, out_gs, species_id, "Gen_03_Hoenn")


# Weather form folders → assets/gs/CASTFORM_{SUFFIX}_*.png (Normal is CASTFORM_*).
CASTFORM_WEATHER_FORMS = (
    ("Sunny", "SUNNY"),
    ("Rainy", "RAINY"),
    ("Snowy", "SNOWY"),
)


def convert_castform_weather_forms(
    outdir: Path,
    castform_dir: Path | None = None,
    dry_run: bool = False,
) -> int:
    """Bake Gen_03 Castform Sunny/Rainy/Snowy → assets/gs/CASTFORM_{FORM}_*.

    Same DMG grayscale + palette JSON pipeline as every other gs mon.
    Normal is CASTFORM_* from convert_hoenn_species.
    Not added to gs_index — CastformFx builds paths from the weather suffix.
    """
    castform_dir = (
        castform_dir
        or (outdir / "assets" / "Gen_03_Hoenn" / "0351. Castform")
    ).resolve()
    if not castform_dir.is_dir():
        print(f"Castform forms not found: {castform_dir}", file=sys.stderr)
        return 0

    out_gs = outdir / "assets" / "gs"
    pal_dir = out_gs / "palettes"
    out_gs.mkdir(parents=True, exist_ok=True)
    pal_dir.mkdir(parents=True, exist_ok=True)
    written = 0

    for form_name, form_id in CASTFORM_WEATHER_FORMS:
        src = castform_dir / form_name
        if not src.is_dir():
            print(f"SKIP Castform form missing: {form_name}")
            continue
        stem = f"CASTFORM_{form_id}"
        front_path = src / "front.png"
        back_path = src / "back.png"

        if dry_run:
            print(f"DRY forecast {form_name} → assets/gs/{stem}_* (dmg)")
            continue

        frames: list[Image.Image] = []
        durations: list[int] = []
        if front_path.exists():
            frames, durations = load_vertical_strip_frames(front_path)
        back_img = None
        if back_path.exists():
            with Image.open(back_path) as im:
                back_img = im.convert("RGBA").copy()
        if not frames and back_img is None:
            print(f"SKIP Castform {form_name} (no art)")
            continue
        if not frames:
            frames = [Image.new("RGBA", back_img.size, (0, 0, 0, 0))]
            durations = [110]

        result = convert_frames_and_back(
            frames,
            durations,
            back_img,
            out_gs,
            stem,
            f"Gen_03_Hoenn/{castform_dir.name}/{form_name}",
        )
        write_palette_json(pal_dir / f"{stem}.json", result)
        written += 1
        if result.get("front"):
            written += 1
        if result.get("back"):
            written += 1
        if result.get("front", {}).get("anim"):
            written += 1
        print(f"OK  forecast {form_name} (dmg+palette) → gs/{stem}_*")

    # Drop legacy assets/castform_*.png if present (moved into gs/).
    assets = outdir / "assets"
    if assets.is_dir() and not dry_run:
        for p in assets.glob("castform*.png"):
            p.unlink()
            print(f"RM   legacy {p.name}")

    print(f"Castform weather forms written under assets/gs/ (+ palettes)")
    if not dry_run:
        n = refresh_gs_palettes_lua(outdir)
        print(f"gs_palettes.lua refreshed ({n} ids)")
    return written


def move_kecleon_into_hoenn(outdir: Path, dry_run: bool = False) -> Path | None:
    """RawSprites/Kecleon → Gen_03_Hoenn/0352. Kecleon (vertical front strip)."""
    raw = outdir / "assets" / "RawSprites" / "Kecleon"
    hoenn = outdir / "assets" / "Gen_03_Hoenn"
    dest = hoenn / "0352. Kecleon"
    if not raw.is_dir():
        print("Kecleon not in RawSprites — skip move")
        return dest if dest.is_dir() else None
    src = raw / "Regular"
    if not src.is_dir():
        src = pick_source_dir(raw) or raw
    front = find_front(src)
    back = find_back(src)
    if not front and not back:
        print("Kecleon has no front/back — skip move")
        return None
    print(f"MOVE RawSprites/Kecleon → {dest.relative_to(outdir)}")
    if dry_run:
        return dest
    dest.mkdir(parents=True, exist_ok=True)
    if front:
        frames, _ = load_frames(front)
        w, h = frames[0].size
        strip = Image.new("RGBA", (w, h * len(frames)), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            strip.paste(fr, (0, i * h))
        strip.save(dest / "front.png")
    if back:
        with Image.open(back) as im:
            im.convert("RGBA").save(dest / "back.png")
    # Remove RawSprites tree for Kecleon
    import shutil

    shutil.rmtree(raw)
    return dest


def convert_gen12_tree(
    outdir: Path,
    kanto_dir: Path | None = None,
    johto_dir: Path | None = None,
    dry_run: bool = False,
    only: str | None = None,
    max_dex: int = 251,
) -> int:
    """Bake Gen_01_Kanto + Gen_02_Johto → assets/gs (national dex ≤ max_dex)."""
    assets = outdir / "assets"
    kanto_dir = (kanto_dir or (assets / "Gen_01_Kanto")).resolve()
    johto_dir = (johto_dir or (assets / "Gen_02_Johto")).resolve()

    roots: list[tuple[str, Path]] = []
    if kanto_dir.is_dir():
        roots.append(("Gen_01_Kanto", kanto_dir))
    else:
        print(f"WARN Gen_01_Kanto not found: {kanto_dir}", file=sys.stderr)
    if johto_dir.is_dir():
        roots.append(("Gen_02_Johto", johto_dir))
    else:
        print(f"WARN Gen_02_Johto not found: {johto_dir}", file=sys.stderr)
    if not roots:
        print("No Gen_01_Kanto or Gen_02_Johto directory found", file=sys.stderr)
        return 1

    out_gs = outdir / "assets" / "gs"
    pal_dir = out_gs / "palettes"
    out_gs.mkdir(parents=True, exist_ok=True)
    pal_dir.mkdir(parents=True, exist_ok=True)

    name_to_dex = load_pokeapi_name_to_dex()
    index_entries = parse_gs_index(outdir / "pokemon" / "gs_index.lua")
    if only is None:
        # Refresh Gen1/2 rows from this run; keep Gen3+ already baked under assets/gs.
        index_entries = {
            sid: e
            for sid, e in index_entries.items()
            if (name_to_dex.get(sid) or 9999) > max_dex
            and gs_files_present(out_gs, sid, e)
        }
    else:
        index_entries = {
            sid: e
            for sid, e in index_entries.items()
            if gs_files_present(out_gs, sid, e)
        }

    converted = 0
    skipped = 0
    warned = 0

    for source_tree, root in roots:
        dirs = sorted(d for d in root.iterdir() if d.is_dir())
        if only:
            dirs = [d for d in dirs if only in d.name]
        for species_dir in dirs:
            parsed = parse_dex_dir_name(species_dir.name)
            if not parsed:
                print(f"SKIP bad name {species_dir.name}")
                continue
            dex, sid = parsed
            if dex < 1 or dex > max_dex:
                skipped += 1
                if dry_run:
                    print(f"SKIP {species_dir.name} dex={dex} (>{max_dex})")
                continue
            if dry_run:
                form = pick_dex_form_dir(species_dir)
                print(
                    f"DRY {source_tree}/{species_dir.name} → {sid} dex={dex} "
                    f"form={form.name if form else None}"
                )
                continue
            result = convert_dex_folder_species(species_dir, out_gs, sid, source_tree)
            if result is None:
                skipped += 1
                print(f"SKIP {sid} (no non-Hisui art)")
                continue

            write_palette_json(pal_dir / f"{sid}.json", result)
            entry: dict = {}
            if "_front_size" in result:
                entry["frontW"], entry["frontH"] = result["_front_size"]
                entry["frames"] = result.get("_front_frames", 1)
            if "_back_size" in result:
                entry["backW"], entry["backH"] = result["_back_size"]
            index_entries[sid] = entry
            converted += 1
            if result.get("warnings"):
                warned += 1
                print(f"OK  {sid} (#{dex})  WARN {'; '.join(result['warnings'])}")
            else:
                frames = result.get("_front_frames", 1)
                extra = f" anim={frames}" if frames > 1 else ""
                print(f"OK  {sid} (#{dex}){extra}")

    if not dry_run:
        write_gs_index(outdir / "pokemon" / "gs_index.lua", index_entries)
        n_flat = write_flat_index(
            outdir / "pokemon" / "flat_index.lua", outdir / "assets"
        )
        n_pal = refresh_gs_palettes_lua(outdir)
        print(
            f"Gen1/2 convert done: converted={converted} skipped={skipped} "
            f"warned={warned} index={len(index_entries)} flat_index={n_flat} "
            f"gs_palettes={n_pal} → {out_gs}"
        )
    else:
        print(f"Gen1/2 dry-run: would convert from {len(roots)} tree(s)")
    return converted


def convert_hoenn_tree(
    outdir: Path,
    hoenn_dir: Path | None = None,
    dry_run: bool = False,
    only: str | None = None,
) -> int:
    """Bake Gen_03_Hoenn → assets/gs and merge into gs_index (keep ≤251)."""
    hoenn_dir = (hoenn_dir or (outdir / "assets" / "Gen_03_Hoenn")).resolve()
    if not hoenn_dir.is_dir():
        print(f"Gen_03_Hoenn not found: {hoenn_dir}", file=sys.stderr)
        return 0
    out_gs = outdir / "assets" / "gs"
    pal_dir = out_gs / "palettes"
    out_gs.mkdir(parents=True, exist_ok=True)
    pal_dir.mkdir(parents=True, exist_ok=True)

    # Start from existing index: keep Gen1/2 always; when converting the full
    # Hoenn tree drop old Gen3 rows so they refresh; --only merges one species.
    name_to_dex = load_pokeapi_name_to_dex()
    merged = parse_gs_index(outdir / "pokemon" / "gs_index.lua")
    if only is None:
        merged = {
            sid: e
            for sid, e in merged.items()
            if (name_to_dex.get(sid) or 9999) <= 251
            and gs_files_present(out_gs, sid, e)
        }
    else:
        merged = {
            sid: e
            for sid, e in merged.items()
            if gs_files_present(out_gs, sid, e)
        }

    converted = 0
    dirs = sorted([d for d in hoenn_dir.iterdir() if d.is_dir()])
    if only:
        dirs = [d for d in dirs if only in d.name]
    for species_dir in dirs:
        parsed = parse_hoenn_dir_name(species_dir.name)
        if not parsed:
            print(f"SKIP bad hoenn name {species_dir.name}")
            continue
        dex, sid = parsed
        if dex < 252 or dex > 386:
            print(f"SKIP {species_dir.name} dex={dex} (not Gen3)")
            continue
        if dry_run:
            print(f"DRY hoenn {species_dir.name} → {sid}")
            continue
        result = convert_hoenn_species(species_dir, out_gs, sid)
        if result is None:
            print(f"SKIP {sid} (no art)")
            continue
        write_palette_json(pal_dir / f"{sid}.json", result)
        entry: dict = {}
        if "_front_size" in result:
            entry["frontW"], entry["frontH"] = result["_front_size"]
            entry["frames"] = result.get("_front_frames", 1)
        if "_back_size" in result:
            entry["backW"], entry["backH"] = result["_back_size"]
        merged[sid] = entry
        converted += 1
        frames = result.get("_front_frames", 1)
        extra = f" anim={frames}" if frames > 1 else ""
        warn = f" WARN {result['warnings']}" if result.get("warnings") else ""
        print(f"OK  {sid} (#{dex}){extra}{warn}")

    if not dry_run:
        write_gs_index(outdir / "pokemon" / "gs_index.lua", merged)
        write_flat_index(outdir / "pokemon" / "flat_index.lua", outdir / "assets")
        refresh_gs_palettes_lua(outdir)
    print(f"Hoenn convert done: {converted} species; index size={len(merged)}")

    # Forecast form sheets (Normal/Sunny/Rainy/Snowy) — always when Castform
    # is in this run (full tree or --only Castform).
    if only is None or "Castform" in only or "CASTFORM" in only.upper():
        convert_castform_weather_forms(outdir, dry_run=dry_run)
    return converted


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--outdir",
        type=Path,
        default=MOD_ROOT,
        help="Mod root (default: parent of tools/)",
    )
    ap.add_argument(
        "--source",
        choices=("gen12", "hoenn"),
        default="gen12",
        help="gen12=Gen_01_Kanto+Gen_02_Johto; hoenn=Gen_03_Hoenn",
    )
    ap.add_argument(
        "--kanto-dir",
        type=Path,
        default=None,
        help="Gen_01_Kanto directory (default: <outdir>/assets/Gen_01_Kanto)",
    )
    ap.add_argument(
        "--johto-dir",
        type=Path,
        default=None,
        help="Gen_02_Johto directory (default: <outdir>/assets/Gen_02_Johto)",
    )
    ap.add_argument(
        "--hoenn-dir",
        type=Path,
        default=None,
        help="Gen_03_Hoenn directory (default: <outdir>/assets/Gen_03_Hoenn)",
    )
    ap.add_argument(
        "--max-dex",
        type=int,
        default=251,
        help="When --source gen12, only convert national dex ≤ this (default 251)",
    )
    ap.add_argument(
        "--prune-gs",
        action="store_true",
        help="Remove missing + post-Gen2 entries from assets/gs and gs_index",
    )
    ap.add_argument(
        "--move-kecleon",
        action="store_true",
        help="Move RawSprites/Kecleon into Gen_03_Hoenn/0352. Kecleon",
    )
    ap.add_argument("--only", type=str, default=None, help="Convert a single folder name")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument(
        "--castform-forecast",
        action="store_true",
        help="Only bake Castform weather forms into assets/gs/CASTFORM_{SUNNY,RAINY,SNOWY}_*",
    )
    args = ap.parse_args(argv)

    outdir: Path = args.outdir.resolve()
    argv_list = list(argv if argv is not None else sys.argv[1:])
    explicit_source = any(
        a == "--source" or a.startswith("--source=") for a in argv_list
    )

    if args.castform_forecast:
        convert_castform_weather_forms(outdir, dry_run=args.dry_run)
        return 0

    if args.prune_gs:
        prune_gs_keep_gen12(outdir, keep_max_dex=386, dry_run=args.dry_run)

    if args.move_kecleon:
        move_kecleon_into_hoenn(outdir, dry_run=args.dry_run)

    if args.source == "hoenn":
        convert_hoenn_tree(
            outdir,
            hoenn_dir=args.hoenn_dir,
            dry_run=args.dry_run,
            only=args.only,
        )
        return 0

    # --prune-gs / --move-kecleon alone must NOT rebuild Gen1/2.
    if (args.prune_gs or args.move_kecleon) and not explicit_source:
        return 0

    convert_gen12_tree(
        outdir,
        kanto_dir=args.kanto_dir,
        johto_dir=args.johto_dir,
        dry_run=args.dry_run,
        only=args.only,
        max_dex=args.max_dex,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
