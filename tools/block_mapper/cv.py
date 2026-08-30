#!/usr/bin/env python3
"""CV / sheet slicing helpers for the block mapper (no Tk)."""

from __future__ import annotations

import math
import os
import sys

import cv2
import numpy as np
from PIL import Image

_TOOLS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

# Building exclusion set is mutated via apply_profile_globals in session
GEN2_BUILDING_BLOCKS = set()

# Gold TILESET_CAVE walkable flat floors: light t1 vs dark t62 (same pal 6, darker 2bpp).
FLAT_CAVE_FLOOR_LIGHT = (1, 1, 1, 1)
FLAT_CAVE_FLOOR_DARK = (62, 62, 62, 62)
FLAT_CAVE_FLOOR_DARK_EXPORT = 62
FLAT_CAVE_FLOOR_IDENTITIES = (
    FLAT_CAVE_FLOOR_LIGHT,
    FLAT_CAVE_FLOOR_DARK,
)
FLAT_CAVE_FLOOR_LUMA = {
    FLAT_CAVE_FLOOR_LIGHT: 96.0,
    FLAT_CAVE_FLOOR_DARK: 45.0,
}
# Gen1 CAVERN corner tiles that mean “flat walkable floor”, not fuzzy dither or walls.
G1_CAVERN_LIGHT_FLOOR_TILES = {5}
G1_CAVERN_DARK_FLOOR_TILES = {16, 23, 32}
G1_CAVERN_FLOOR_TILES = G1_CAVERN_LIGHT_FLOOR_TILES | G1_CAVERN_DARK_FLOOR_TILES
# Above this gray std the quad has visible texture — never auto-pick t1/t62 flats.
TEXTURED_QUAD_STD = 36.0
SYNTHETIC_G2_ID_BASE = 8000

# =============================================================================
# Phase 1: Slicing, Quadrant Extraction, Mt. Moon Synthesis & LCM Normalization
# =============================================================================

def calculate_lcm(dim1, dim2):
    return math.lcm(dim1, dim2)


def slice_sheet(
    img_path,
    cols=16,
    block_w=32,
    block_h=32,
    max_blocks=None,
    is_card_sheet=False,
    pad_x=24,
    pad_y=64,
    cell_w=112,
    cell_h=132,
    card_block_size=96,
):
    """Slice a block atlas. block_w/block_h are pixel sizes (parametric for Sevii/FRLG)."""
    img = Image.open(img_path).convert("RGB")
    blocks = []

    if is_card_sheet:
        total_w, total_h = img.size
        row = 0
        while True:
            y0 = pad_y + row * cell_h
            if y0 + cell_h > total_h:
                break
            for col in range(cols):
                x0 = pad_x + col * cell_w
                if x0 + cell_w > total_w:
                    break
                bx = x0 + 8
                by = y0 + 26
                block_crop = img.crop((bx, by, bx + card_block_size, by + card_block_size))
                blocks.append(block_crop)
                if max_blocks and len(blocks) >= max_blocks:
                    return blocks
            row += 1
    else:
        w, h = img.size
        # Auto-detect grid cell size when sheet is a simple atlas
        if block_w is None or block_h is None:
            block_w = block_h = 32 if w >= 32 else 16
        grid_cols = cols if cols else (w // block_w)
        grid_rows = h // block_h
        for r in range(grid_rows):
            for c in range(grid_cols):
                x = c * block_w
                y = r * block_h
                if x + block_w <= w and y + block_h <= h:
                    block_crop = img.crop((x, y, x + block_w, y + block_h))
                    blocks.append(block_crop)
                    if max_blocks and len(blocks) >= max_blocks:
                        return blocks

    return blocks


def synthesize_mt_moon_custom_stairs(g1_raw_blocks, g2_raw_blocks):
    """Preview custom blocks #158/#159 from shipped wood_stair.png on composed kanto.png."""
    from tileset_quad_patches import render_stair_block_previews

    if render_stair_block_previews(g2_raw_blocks):
        print(
            "Loaded custom stair blocks (#158 Stairs Down, #159 Stairs Up) "
            "from overrides/tileset_quads/wood_stair.png"
        )


def normalize_blocks(blocks, target_size):
    normalized = []
    for b in blocks:
        if b.size != (target_size, target_size):
            norm_b = b.resize((target_size, target_size), Image.NEAREST)
        else:
            norm_b = b
        normalized.append(norm_b)
    return normalized


def extract_quadrants(img_np):
    h, w = img_np.shape[:2]
    hh, hw = h // 2, w // 2
    return [
        img_np[0:hh, 0:hw],   # 0: TL
        img_np[0:hh, hw:w],   # 1: TR
        img_np[hh:h, 0:hw],   # 2: BL
        img_np[hh:h, hw:w],   # 3: BR
    ]


def assemble_quadrants_image(q0, q1, q2, q3):
    top = np.hstack([q0, q1])
    bot = np.hstack([q2, q3])
    return np.vstack([top, bot])


def assemble_16_tiles(tl_tiles, tr_tiles, bl_tiles, br_tiles):
    return [
        tl_tiles[0], tl_tiles[1], tr_tiles[0], tr_tiles[1],
        tl_tiles[2], tl_tiles[3], tr_tiles[2], tr_tiles[3],
        bl_tiles[0], bl_tiles[1], br_tiles[0], br_tiles[1],
        bl_tiles[2], bl_tiles[3], br_tiles[2], br_tiles[3],
    ]


def extract_quad_tile_ids(block_tiles, q_pos):
    """Return the four 8×8 tile indices for one quadrant of a 16-tile metatile."""
    if not block_tiles or len(block_tiles) < 16:
        return [0, 0, 0, 0]
    b = block_tiles
    if q_pos == 0:
        return [int(b[0]), int(b[1]), int(b[4]), int(b[5])]
    if q_pos == 1:
        return [int(b[2]), int(b[3]), int(b[6]), int(b[7])]
    if q_pos == 2:
        return [int(b[8]), int(b[9]), int(b[12]), int(b[13])]
    return [int(b[10]), int(b[11]), int(b[14]), int(b[15])]


def quad_tile_key(g2_tiles_raw, g2_id, src_q, coll=None):
    """Visual identity for baked quads: four tile indices (collision is separate)."""
    if g2_tiles_raw and 0 <= int(g2_id) < len(g2_tiles_raw):
        tiles = extract_quad_tile_ids(g2_tiles_raw[g2_id], src_q)
        return tuple(int(t) for t in tiles)
    return None


def quad_pool_identity(entry):
    """Hashable pool/dedupe identity: tile corners plus optional palette slot."""
    if isinstance(entry, dict):
        tile_key = entry.get("tile_key")
        palette_slot = entry.get("palette_slot")
        if tile_key is not None:
            key = tuple(int(t) for t in tile_key)
            if palette_slot is not None:
                return (key, int(palette_slot))
            return key
        return (int(entry.get("g2_id", 0)), int(entry.get("src_q", 0)))
    return entry


def _parse_uniform_tile_spec(spec):
    if isinstance(spec, dict):
        tiles = spec.get("tiles")
        if tiles is not None:
            tile_key = tuple(int(t) for t in tiles)
        else:
            tid = int(spec.get("tile", 1))
            tile_key = (tid, tid, tid, tid)
        export_tile = spec.get("export_tile")
        palette_slot = spec.get("palette_slot")
        g2_id = spec.get("g2_id")
        if g2_id is None:
            base = int(export_tile) if export_tile is not None else tile_key[0]
            g2_id = SYNTHETIC_G2_ID_BASE + base
        return {
            "tile_key": tile_key,
            "palette_slot": int(palette_slot) if palette_slot is not None else None,
            "export_tile": int(export_tile) if export_tile is not None else None,
            "g2_id": int(g2_id),
            "label": spec.get("label"),
        }
    tid = int(spec)
    return {
        "tile_key": (tid, tid, tid, tid),
        "palette_slot": None,
        "export_tile": None,
        "g2_id": SYNTHETIC_G2_ID_BASE + tid,
        "label": None,
    }


def _collision_for_tile_key(tile_key, g2_tiles_raw=None, g2_coll_list=None):
    key = tuple(int(t) for t in tile_key)
    if g2_tiles_raw and g2_coll_list:
        for b_id, block in enumerate(g2_tiles_raw):
            if b_id >= len(g2_coll_list):
                break
            for q in range(4):
                if tuple(extract_quad_tile_ids(block, q)) == key:
                    return int(g2_coll_list[b_id][q]) & 0xFF
    uniq = set(key)
    if len(uniq) == 1:
        t = next(iter(uniq))
        if t == 20:
            return 0x29
        return 0x00
    if key == (12, 13, 28, 29):
        return 0x07
    return 0x07


def inject_synthetic_tile_quads(
    unique_pool,
    unique_dict,
    *,
    uniform_tiles=None,
    extra_tile_keys=None,
    g2_ts_rec=None,
    g2_sheet_path=None,
    g2_palette_bake=None,
    g2_game="gold",
    g2_tile_size=8,
    g2_tiles_raw=None,
    g2_coll_list=None,
):
    """Add baked quads that exist on the sheet but never appear in ROM metatile corners."""
    if not (g2_ts_rec and g2_sheet_path):
        return 0
    from tileset_block_rebuild import render_quad_from_tile_ids

    added = 0
    specs = [_parse_uniform_tile_spec(s) for s in (uniform_tiles or ())]
    for key in extra_tile_keys or ():
        specs.append(_parse_uniform_tile_spec({"tiles": key}))

    for spec in specs:
        identity = quad_pool_identity(spec)
        if identity in unique_dict:
            continue
        bake_kwargs = {}
        if spec.get("palette_slot") is not None:
            bake_kwargs["palette_slot_override"] = spec["palette_slot"]
        key = spec["tile_key"]
        img = render_quad_from_tile_ids(
            list(key),
            g2_ts_rec,
            g2_sheet_path,
            quad_px=16,
            tile_size=int(g2_tile_size or 8),
            palette_bake=g2_palette_bake,
            game=g2_game or "gold",
            **bake_kwargs,
        )
        img_np = np.array(img.convert("RGB"))
        coll = _collision_for_tile_key(key, g2_tiles_raw, g2_coll_list)
        entry = {
            "uid": len(unique_pool),
            "g2_id": spec["g2_id"],
            "src_q": 0,
            "tile_key": key,
            "synthetic": True,
            "img_np": img_np,
            "coll": coll,
            "occurrences": [(spec["g2_id"], 0)],
        }
        if spec.get("palette_slot") is not None:
            entry["palette_slot"] = spec["palette_slot"]
        if spec.get("export_tile") is not None:
            entry["export_tile"] = spec["export_tile"]
        unique_dict[identity] = entry
        unique_pool.append(entry)
        added += 1
    return added


def build_unique_quadrant_pool(
    g2_blocks_np,
    g2_coll_list=None,
    exclude_buildings=True,
    g2_tiles_raw=None,
    *,
    uniform_tiles=None,
    extra_tile_keys=None,
    g2_ts_rec=None,
    g2_sheet_path=None,
    g2_palette_bake=None,
    g2_game="gold",
    g2_tile_size=8,
):
    n2 = len(g2_blocks_np)
    g2_quads = [extract_quadrants(b) for b in g2_blocks_np]

    unique_dict = {}
    unique_pool = []

    for b_id in range(n2):
        if exclude_buildings and b_id in GEN2_BUILDING_BLOCKS and b_id not in (120, 121, 158, 159, 160):
            continue

        for q_idx in range(4):
            q_arr = g2_quads[b_id][q_idx]
            c_byte = g2_coll_list[b_id][q_idx] if g2_coll_list and b_id < len(g2_coll_list) else 0x00
            tile_key = quad_tile_key(g2_tiles_raw, b_id, q_idx)
            if tile_key is not None:
                q_key = tile_key
            else:
                q_key = (q_arr.tobytes(), c_byte)

            if q_key not in unique_dict:
                entry = {
                    "uid": len(unique_pool),
                    "g2_id": b_id,
                    "src_q": q_idx,
                    "img_np": q_arr,
                    "coll": c_byte,
                    "occurrences": [(b_id, q_idx)],
                }
                if tile_key is not None:
                    entry["tile_key"] = tile_key
                unique_dict[q_key] = entry
                unique_pool.append(entry)
            else:
                entry = unique_dict[q_key]
                entry["occurrences"].append((b_id, q_idx))
                if c_byte != entry.get("coll"):
                    variants = entry.setdefault("coll_variants", {entry["coll"]})
                    variants.add(c_byte)

    inject_synthetic_tile_quads(
        unique_pool,
        unique_dict,
        uniform_tiles=uniform_tiles,
        extra_tile_keys=extra_tile_keys,
        g2_ts_rec=g2_ts_rec,
        g2_sheet_path=g2_sheet_path,
        g2_palette_bake=g2_palette_bake,
        g2_game=g2_game,
        g2_tile_size=g2_tile_size,
        g2_tiles_raw=g2_tiles_raw,
        g2_coll_list=g2_coll_list,
    )
    if uniform_tiles:
        injected = []
        for spec in (_parse_uniform_tile_spec(s) for s in uniform_tiles):
            label = spec.get("label")
            if label:
                injected.append(label)
            elif spec.get("export_tile") is not None:
                injected.append(f"t{spec['export_tile']}(pal{spec['palette_slot']})")
            else:
                injected.append(f"t{spec['tile_key'][0]}")
        if injected:
            print(f"[block_mapper] Injected synthetic floor quads: {', '.join(injected)}")

    return unique_pool


def quad_has_tile_ids(g2_tiles_raw, g2_id, src_q, tile_ids):
    if g2_id >= len(g2_tiles_raw):
        return False
    q_tiles = extract_quad_tile_ids(g2_tiles_raw[g2_id], src_q)
    bad = set(tile_ids or ())
    return any(t in bad for t in q_tiles)


# =============================================================================
# Phase 2: Deduplication, Building Filter & Fast CV Scoring
# =============================================================================

def get_sobel_magnitude(gray):
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    return cv2.magnitude(gx, gy)


# Tiles that should not appear in a uniform wall/floor G1 quad match.
_G1_UNIFORM_FLOOR_TILES = {1, 62}
_G1_UNIFORM_SPECIAL_TILES = {20, 23, 83, 90, 91, 92, 93}


def _is_low_res_quad(q_arr) -> bool:
    h, w = q_arr.shape[:2]
    return max(h, w) <= 24


def _quad_pixel_metrics(q1_rgb, q1_lab, q2_rgb, q2_lab):
    """Direct 256-pixel (16×16) comparison — Gaussian SSIM is unreliable at this size."""
    diff = q1_rgb.astype(np.float32) - q2_rgb.astype(np.float32)
    mad = float(np.mean(np.abs(diff)))
    pixel_sim = float(np.exp(-mad / 42.0))
    mse = float(np.mean(diff ** 2))
    mse_sim = float(np.exp(-mse / 2500.0))
    dL = np.abs(q1_lab[:, :, 0] - q2_lab[:, :, 0])
    dAB = np.sqrt((q1_lab[:, :, 1] - q2_lab[:, :, 1]) ** 2 + (q1_lab[:, :, 2] - q2_lab[:, :, 2]) ** 2)
    color_sim = float(np.exp(-np.mean(0.35 * dL + 0.65 * dAB) / 22.0))
    h, w = q1_rgb.shape[:2]
    if h >= 8 and w >= 8:
        gray1 = cv2.cvtColor(q1_rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)
        gray2 = cv2.cvtColor(q2_rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)
        th, tw = max(1, h // 2), max(1, w // 2)
        cell_mad = 0.0
        for r in range(2):
            for c in range(2):
                y0, x0 = r * th, c * tw
                cell_mad += abs(
                    float(gray1[y0 : y0 + th, x0 : x0 + tw].mean())
                    - float(gray2[y0 : y0 + th, x0 : x0 + tw].mean())
                )
        cell_sim = float(np.exp(-(cell_mad / 4.0) / 18.0))
    else:
        cell_sim = color_sim
    return pixel_sim, mse_sim, color_sim, cell_sim, mad


def _tile_corner_adjustment(g1_tile_key, cand_tile_key):
    """Nudge score using Red metatile corner indices when available."""
    if not g1_tile_key or not cand_tile_key:
        return 0.0
    g1k = tuple(int(t) for t in g1_tile_key)
    cand = tuple(int(t) for t in cand_tile_key)
    adj = 0.05 * sum(1 for a, b in zip(g1k, cand) if a == b)
    if len(set(g1k)) == 1:
        g1t = g1k[0]
        if len(set(cand)) == 1:
            adj += 0.12
        g1_in_cand = sum(1 for t in cand if t == g1t)
        if g1_in_cand:
            adj += 0.10 + 0.06 * g1_in_cand
        elif g1t not in _G1_UNIFORM_FLOOR_TILES:
            adj -= 0.10
        if g1t not in _G1_UNIFORM_FLOOR_TILES and any(t in _G1_UNIFORM_FLOOR_TILES for t in cand):
            adj -= 0.25
        if any(t >= 200 or t in _G1_UNIFORM_SPECIAL_TILES for t in cand):
            adj -= 0.22
        if g1t < 200:
            exotic = sum(1 for t in cand if t >= 200 or t in _G1_UNIFORM_SPECIAL_TILES)
            adj -= 0.10 * exotic
    return adj


def _g1_floor_shade_adjustment(g1_tile_key, cand_tile_key, std1):
    """Light G1 floor tiles -> G2 t1; dark G1 floor tiles -> G2 t62; textured -> neither."""
    cand = tuple(cand_tile_key or ())
    if cand not in FLAT_CAVE_FLOOR_IDENTITIES:
        return 0.0
    if std1 > TEXTURED_QUAD_STD:
        return -0.70
    if not g1_tile_key:
        return 0.0
    g1k = tuple(int(t) for t in g1_tile_key)
    uniq = set(g1k)
    if len(uniq) > 1 or not uniq <= G1_CAVERN_FLOOR_TILES:
        return -0.65
    g1t = next(iter(uniq))
    if g1t in G1_CAVERN_LIGHT_FLOOR_TILES:
        return 0.45 if cand == FLAT_CAVE_FLOOR_LIGHT else -0.50
    if g1t in G1_CAVERN_DARK_FLOOR_TILES:
        return 0.45 if cand == FLAT_CAVE_FLOOR_DARK else -0.50
    return 0.0


def compute_base_quadrant_rankings(g1_blocks_np, unique_g2_quads, g1_tiles_raw=None):
    n1 = len(g1_blocks_np)
    g1_quads = [extract_quadrants(b) for b in g1_blocks_np]

    # Full-block SSIM can use a wider kernel; 16×16 quads use pixel metrics instead.
    ksize = (9, 9)
    sigma = 1.2
    C1 = (0.01 * 255.0) ** 2
    C2 = (0.03 * 255.0) ** 2
    low_res = _is_low_res_quad(g1_quads[0][0]) if g1_quads else True

    g2_processed = []
    for item in unique_g2_quads:
        q_arr = item["img_np"]
        gray = cv2.cvtColor(q_arr, cv2.COLOR_RGB2GRAY).astype(np.float32)
        lab = cv2.cvtColor(q_arr, cv2.COLOR_RGB2LAB).astype(np.float32)
        sobel = get_sobel_magnitude(gray)
        std = float(np.std(gray))
        mu = cv2.GaussianBlur(gray, ksize, sigma)
        mu_sq = mu ** 2
        s_sq = cv2.GaussianBlur(gray ** 2, ksize, sigma) - mu_sq

        g2_processed.append({
            "uid": item["uid"],
            "g2_id": item["g2_id"],
            "src_q": item["src_q"],
            "coll": item["coll"],
            "occurrences": item["occurrences"],
            "tile_key": item.get("tile_key"),
            "palette_slot": item.get("palette_slot"),
            "export_tile": item.get("export_tile"),
            "img_np": q_arr,
            "gray": gray,
            "lab": lab,
            "sobel": sobel,
            "std": std,
            "mu": mu,
            "mu_sq": mu_sq,
            "s_sq": s_sq,
            "mean": float(np.mean(gray)),
        })

    base_rankings = {}

    for i in range(n1):
        base_rankings[i] = {}
        for q_pos in range(4):
            q_arr1 = g1_quads[i][q_pos]
            gray1 = cv2.cvtColor(q_arr1, cv2.COLOR_RGB2GRAY).astype(np.float32)
            lab1 = cv2.cvtColor(q_arr1, cv2.COLOR_RGB2LAB).astype(np.float32)
            std1 = float(np.std(gray1))
            mean1 = float(np.mean(gray1))
            g1_tile_key = quad_tile_key(g1_tiles_raw, i, q_pos) if g1_tiles_raw else None

            mu1 = mu1_sq = s1_sq = sobel1 = norm_e1 = None
            if not low_res:
                sobel1 = get_sobel_magnitude(gray1)
                norm_e1 = np.linalg.norm(sobel1)
                mu1 = cv2.GaussianBlur(gray1, ksize, sigma)
                mu1_sq = mu1 ** 2
                s1_sq = cv2.GaussianBlur(gray1 ** 2, ksize, sigma) - mu1_sq

            cand_scores = []
            for item in g2_processed:
                pos_bonus = 0.05 if any(occ[1] == q_pos for occ in item["occurrences"]) else 0.0

                is_blank1 = (std1 < 1.0)
                is_blank2 = (item["std"] < 1.0)
                if is_blank1 and is_blank2:
                    cand_scores.append({
                        "uid": item["uid"], "g2_id": item["g2_id"], "src_q": item["src_q"],
                        "coll": item["coll"], "occurrences": item["occurrences"],
                        "img_np": item["img_np"], "base_score": 1.0,
                        "ssim": 1.0, "edge": 1.0, "color": 1.0, "pixel": 1.0,
                    })
                    continue
                elif is_blank1 != is_blank2:
                    cand_scores.append({
                        "uid": item["uid"], "g2_id": item["g2_id"], "src_q": item["src_q"],
                        "coll": item["coll"], "occurrences": item["occurrences"],
                        "img_np": item["img_np"], "base_score": 0.0,
                        "ssim": 0.0, "edge": 0.0, "color": 0.0, "pixel": 0.0,
                    })
                    continue

                if low_res:
                    pixel_sim, mse_sim, color_sim, cell_sim, _mad = _quad_pixel_metrics(
                        q_arr1, lab1, item["img_np"], item["lab"]
                    )
                    ssim = mse_sim
                    edge_sim = cell_sim
                    total = (
                        0.40 * pixel_sim
                        + 0.15 * mse_sim
                        + 0.20 * color_sim
                        + 0.10 * cell_sim
                        + pos_bonus
                    )
                    total += _tile_corner_adjustment(g1_tile_key, item.get("tile_key"))
                    total += _g1_floor_shade_adjustment(g1_tile_key, item.get("tile_key"), std1)
                else:
                    mu1_mu2 = mu1 * item["mu"]
                    sigma12 = cv2.GaussianBlur(gray1 * item["gray"], ksize, sigma) - mu1_mu2
                    denom = (mu1_sq + item["mu_sq"] + C1) * (s1_sq + item["s_sq"] + C2)
                    ssim = float(np.mean(((2.0 * mu1_mu2 + C1) * (2.0 * sigma12 + C2)) / denom))

                    denom_e = norm_e1 * np.linalg.norm(item["sobel"])
                    edge_sim = float(np.sum(sobel1 * item["sobel"]) / denom_e) if denom_e > 1e-6 else 0.0

                    dL = np.abs(lab1[:, :, 0] - item["lab"][:, :, 0])
                    dAB = np.sqrt(
                        (lab1[:, :, 1] - item["lab"][:, :, 1]) ** 2
                        + (lab1[:, :, 2] - item["lab"][:, :, 2]) ** 2
                    )
                    color_sim = float(np.exp(-np.mean(0.35 * dL + 0.65 * dAB) / 22.0))
                    pixel_sim = color_sim
                    total = 0.40 * ssim + 0.30 * edge_sim + 0.30 * color_sim + pos_bonus

                # Flat G2 floor quads look identical once baked; deprioritize when G1 has texture.
                if std1 > 4.0 and item["std"] < 2.5:
                    total -= min(0.25, (std1 - 4.0) * 0.03)
                lum_diff = abs(mean1 - item["mean"])
                floor_id = quad_pool_identity(item)
                if std1 < TEXTURED_QUAD_STD and floor_id in FLAT_CAVE_FLOOR_IDENTITIES:
                    # Prefer the correct flat floor shade (light t1 vs dark t62).
                    total += max(0.0, 0.65 - lum_diff / 35.0)
                    if lum_diff > 18.0:
                        total -= min(0.55, (lum_diff - 18.0) / 50.0)
                elif lum_diff > 8.0:
                    total -= min(0.45, lum_diff / 90.0)
                cand_scores.append({
                    "uid": item["uid"],
                    "g2_id": item["g2_id"],
                    "src_q": item["src_q"],
                    "coll": item["coll"],
                    "occurrences": item["occurrences"],
                    "coll_variants": item.get("coll_variants"),
                    "tile_key": item.get("tile_key"),
                    "palette_slot": item.get("palette_slot"),
                    "export_tile": item.get("export_tile"),
                    "img_np": item["img_np"],
                    "base_score": total,
                    "ssim": ssim,
                    "edge": edge_sim,
                    "color": color_sim,
                    "pixel": pixel_sim,
                })

            base_rankings[i][q_pos] = cand_scores

    return base_rankings


def compute_all_block_rankings(g1_blocks_np, g2_blocks_np):
    n1, n2 = len(g1_blocks_np), len(g2_blocks_np)
    target_size = g1_blocks_np[0].shape[0]
    grays1 = [cv2.cvtColor(b, cv2.COLOR_RGB2GRAY).astype(np.float32) for b in g1_blocks_np]
    grays2 = [cv2.cvtColor(b, cv2.COLOR_RGB2GRAY).astype(np.float32) for b in g2_blocks_np]
    labs1 = [cv2.cvtColor(b, cv2.COLOR_RGB2LAB).astype(np.float32) for b in g1_blocks_np]
    labs2 = [cv2.cvtColor(b, cv2.COLOR_RGB2LAB).astype(np.float32) for b in g2_blocks_np]

    stds1 = [float(np.std(g)) for g in grays1]
    stds2 = [float(np.std(g)) for g in grays2]
    sobel1 = [get_sobel_magnitude(g) for g in grays1]
    sobel2 = [get_sobel_magnitude(g) for g in grays2]

    ksize = (11, 11)
    sigma = 1.5
    C1, C2 = (0.01 * 255.0) ** 2, (0.03 * 255.0) ** 2
    mu1_list = [cv2.GaussianBlur(g, ksize, sigma) for g in grays1]
    mu2_list = [cv2.GaussianBlur(g, ksize, sigma) for g in grays2]
    mu1_sq_list = [m ** 2 for m in mu1_list]
    mu2_sq_list = [m ** 2 for m in mu2_list]
    s1_sq_list = [cv2.GaussianBlur(g ** 2, ksize, sigma) - m2 for g, m2 in zip(grays1, mu1_sq_list)]
    s2_sq_list = [cv2.GaussianBlur(g ** 2, ksize, sigma) - m2 for g, m2 in zip(grays2, mu2_sq_list)]

    quad_size = max(1, target_size // 4)
    rankings = {}

    for i in range(n1):
        g1, m1, m1_sq, s1_sq = grays1[i], mu1_list[i], mu1_sq_list[i], s1_sq_list[i]
        lab1, e1, norm_e1 = labs1[i], sobel1[i], np.linalg.norm(sobel1[i])
        is_blank1 = (stds1[i] < 1.0)
        scores = []

        for j in range(n2):
            g2, m2, m2_sq, s2_sq = grays2[j], mu2_list[j], mu2_sq_list[j], s2_sq_list[j]
            lab2, e2 = labs2[j], sobel2[j]
            is_blank2 = (stds2[j] < 1.0)

            if is_blank1 and is_blank2:
                scores.append({"g2_id": j, "score": 1.0, "ssim": 1.0, "edge": 1.0, "color": 1.0})
                continue
            elif is_blank1 != is_blank2:
                scores.append({"g2_id": j, "score": 0.0, "ssim": 0.0, "edge": 0.0, "color": 0.0})
                continue

            mu1_mu2 = m1 * m2
            sigma12 = cv2.GaussianBlur(g1 * g2, ksize, sigma) - mu1_mu2
            denom = ((m1_sq + m2_sq + C1) * (s1_sq + s2_sq + C2))
            ssim = float(np.mean(((2.0 * mu1_mu2 + C1) * (2.0 * sigma12 + C2)) / denom))

            denom_e = (norm_e1 * np.linalg.norm(e2))
            edge_sim = float(np.sum(e1 * e2) / denom_e) if denom_e > 1e-6 else 0.0

            dL = np.abs(lab1[:, :, 0] - lab2[:, :, 0])
            dAB = np.sqrt((lab1[:, :, 1] - lab2[:, :, 1]) ** 2 + (lab1[:, :, 2] - lab2[:, :, 2]) ** 2)
            color_sim = float(np.exp(-np.mean(0.35 * dL + 0.65 * dAB) / 22.0))

            q_diff = 0.0
            for r in range(4):
                for c in range(4):
                    q1 = lab1[r * quad_size:(r + 1) * quad_size, c * quad_size:(c + 1) * quad_size]
                    q2 = lab2[r * quad_size:(r + 1) * quad_size, c * quad_size:(c + 1) * quad_size]
                    q_diff += np.linalg.norm(np.mean(q1, axis=(0, 1)) - np.mean(q2, axis=(0, 1)))
            quad_sim = float(np.exp(-q_diff / (16.0 * 18.0)))

            total = 0.35 * ssim + 0.25 * edge_sim + 0.20 * color_sim + 0.20 * quad_sim
            scores.append({"g2_id": j, "score": total, "ssim": ssim, "edge": edge_sim, "color": color_sim})

        scores.sort(key=lambda x: x["score"], reverse=True)
        rankings[i] = scores

    return rankings


