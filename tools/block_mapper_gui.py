#!/usr/bin/env python3
r"""
block_mapper_gui.py

Human-in-the-Loop Computer Vision Tool for Gen 1 -> Gen 2 Block ID Translation & Quadrant Assembly.
Features:
- Exact Mt. Moon Wooden Ladder Stairs (#158, #159):
  - Injects the authentic 4-step wooden ladder/stair graphics (matching Mt. Moon B2F 24,23 & Gen 1 Block 83) into Custom Blocks #158 and #159.
  - Generates real wooden stair quadrant pieces in the candidate pool for 1:1 CV matching and 1-click assembly.
  - Visual thumbnail previews show the real wooden stairs directly in the drop-in palette and favorites bar.
- Per-Quadrant Feature Drop-Ins:
  - Cliff walls, wooden stair steps, fences, and paths are applied per-quadrant with auto-advance.
- Live Biased Presentation:
  - Learned preferences are applied immediately when presenting new blocks and quadrants.
- Instant Zero-Lag Adaptive Learning:
  - Base CV scores (SSIM, Sobel, LAB color) are precomputed once at startup.
  - Learned preferences are applied via instantaneous in-memory lookups (0.01ms), eliminating all lag.
- Auto-Save & Resume Session: Automatically persists mapping progress & learned profiles to `.session.json`.
- Direct Block ID Jump Box ([J]): Type any Gen 2 block ID directly.
- Building Exclusion Filter (Enabled by Default): Excludes indoor/building pieces from the candidate pool.
- Quick Favorites Palette (F1–F8 / Alt+1..8): One-tap hot-selection for heavily reused staples.
- Unique Quadrant Deduplication: Crunches redundant quadrant duplicates.
- Dual-Mode: Full Block Match Mode & 4-Quadrant Assembly Mode.
- Collision & Tile Semantics: Assign and edit Gen 2 COLL_* collision attributes per quadrant.
- Full Export: Generates both SAFARI_G1_TO_G2 dictionary and CUSTOM_KANTO_BLOCKS for restore_kanto_dungeons.py.
"""

import os
import sys
import math
import json
import argparse
import subprocess
import numpy as np
from PIL import Image, ImageTk, ImageDraw
import cv2

# Optional Tkinter import
try:
    import tkinter as tk
    from tkinter import ttk, messagebox, filedialog, simpledialog
except ImportError:
    tk = None


# =============================================================================
# Collision Constants, Buildings & Default Favorites
# =============================================================================

COLLISION_PRESETS = [
    {"label": "0x00: Walkable / Path", "val": 0x00, "color": "#81C784"},
    {"label": "0x07: Solid Wall / Tree", "val": 0x07, "color": "#E57373"},
    {"label": "0x18: Tall Grass (Wild Encounters)", "val": 0x18, "color": "#FFD54F"},
    {"label": "0x29: Water / Surf", "val": 0x29, "color": "#64B5F6"},
    {"label": "0xA0: Ledge Down (Hop)", "val": 0xA0, "color": "#BA68C8"},
    {"label": "0xA1: Ledge Left", "val": 0xA1, "color": "#BA68C8"},
    {"label": "0xA2: Ledge Right", "val": 0xA2, "color": "#BA68C8"},
    {"label": "0x70: Door / Warp Carpet Down", "val": 0x70, "color": "#4DB6AC"},
    {"label": "0x71: Gate Entrance Door", "val": 0x71, "color": "#4DB6AC"},
    {"label": "0x78: Warp Carpet Up", "val": 0x78, "color": "#4DB6AC"},
]

# Exclude indoor & building blocks (128..157 are indoor in the sheet; 158/159 are Mt. Moon stairs)
GEN2_BUILDING_BLOCKS = {
    2, 3, 4, 5, 9, 16, 17, 18, 22, 23, 45, 46, 48, 55, 56, 57, 58, 60, 61,
    83, 85, 102, 104, 105, 113, 114, 115, 117, 118, 124, 125, 126, 127, 138,
    140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157
}

GEN1_BUILDING_BLOCKS = {25, 26, 28}
GEN1_STAIR_BLOCKS = {60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 83, 84, 85}

BUILDING_DIRECT_DROPINS = [
    {"label": "🏡 Small House L (#2)", "g2_id": 2},
    {"label": "🏡 Small House R / Door (#3)", "g2_id": 3},
    {"label": "🛖 Small Hut L (#4)", "g2_id": 4},
    {"label": "🛖 Small Hut R / Door (#5)", "g2_id": 5},
    {"label": "🏠 Rest Booth L (#22)", "g2_id": 22},
    {"label": "🏠 Rest Booth R / Door (#23)", "g2_id": 23},
    {"label": "🏡 3-Wide House L (#16)", "g2_id": 16},
    {"label": "🏡 3-Wide House M (#17)", "g2_id": 17},
    {"label": "🏡 3-Wide House R (#18)", "g2_id": 18},
]


# Mt. Moon & Kanto Mountain Feature Presets with Quad references
QUAD_FEATURE_PRESETS = [
    {"label": "🪜 Stairs Down L", "g2_id": 158, "src_q": 2, "coll": 0x00, "coll_tag": "Walk"},
    {"label": "🪜 Stairs Down R", "g2_id": 158, "src_q": 3, "coll": 0x00, "coll_tag": "Walk"},
    {"label": "🪜 Stairs Up L", "g2_id": 159, "src_q": 0, "coll": 0x00, "coll_tag": "Walk"},
    {"label": "🪜 Stairs Up R", "g2_id": 159, "src_q": 1, "coll": 0x00, "coll_tag": "Walk"},
    {"label": "🪨 Cliff Wall", "g2_id": 36, "src_q": 2, "coll": 0x07, "coll_tag": "Solid"},
    {"label": "🪨 Cliff Top", "g2_id": 36, "src_q": 0, "coll": 0x07, "coll_tag": "Solid"},
    {"label": "🦘 Ledge Hop", "g2_id": 42, "src_q": 2, "coll": 0xA0, "coll_tag": "Hop ↓"},
    {"label": "🪵 Wood Fence", "g2_id": 27, "src_q": 0, "coll": 0x07, "coll_tag": "Solid"},
    {"label": "🏜️ Dirt Path", "g2_id": 6, "src_q": 0, "coll": 0x00, "coll_tag": "Walk"},
    {"label": "🌿 Plain Grass", "g2_id": 1, "src_q": 0, "coll": 0x00, "coll_tag": "Walk"},
]

WHOLE_BLOCK_DROPINS = [
    {"label": "Full Stairs Down", "g2_id": 158},
    {"label": "Full Stairs Up", "g2_id": 159},
]

DEFAULT_FAVORITES = [
    {"g2_id": 1, "src_q": 0, "name": "Plain Grass", "coll": 0x00},     # F1
    {"g2_id": 11, "src_q": 0, "name": "Tall Grass", "coll": 0x18},     # F2
    {"g2_id": 15, "src_q": 0, "name": "Solid Tree", "coll": 0x07},     # F3
    {"g2_id": 27, "src_q": 0, "name": "Wood Fence", "coll": 0x07},     # F4
    {"g2_id": 158, "src_q": 2, "name": "Stairs Down L", "coll": 0x00}, # F5
    {"g2_id": 158, "src_q": 3, "name": "Stairs Down R", "coll": 0x00}, # F6
    {"g2_id": 159, "src_q": 0, "name": "Stairs Up L", "coll": 0x00},   # F7
    {"g2_id": 36, "src_q": 2, "name": "Cliff Wall", "coll": 0x07},     # F8
]

QUAD_NAMES = ["Top-Left (TL)", "Top-Right (TR)", "Bottom-Left (BL)", "Bottom-Right (BR)"]
QUAD_SHORT = ["TL", "TR", "BL", "BR"]


# =============================================================================
# Phase 1: Slicing, Quadrant Extraction, Mt. Moon Synthesis & LCM Normalization
# =============================================================================

def calculate_lcm(dim1, dim2):
    return math.lcm(dim1, dim2)


def slice_sheet(img_path, cols=16, block_w=32, block_h=32, max_blocks=None, is_card_sheet=False, pad_x=24, pad_y=64, cell_w=112, cell_h=132):
    img = Image.open(img_path).convert("RGB")
    blocks = []

    if is_card_sheet:
        card_b_size = 96
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
                block_crop = img.crop((bx, by, bx + card_b_size, by + card_b_size))
                blocks.append(block_crop)
                if max_blocks and len(blocks) >= max_blocks:
                    return blocks
            row += 1
    else:
        w, h = img.size
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
    """
    Synthesizes authentic visual graphics for Custom Blocks #158 (Stairs Down) and #159 (Stairs Up)
    using the real wooden ladder stairs from Gen 1 Block 83 / Mt. Moon B2F (24, 23) and the brown cliff plateau from Block #36.
    """
    # Extract the exact 4-step wooden ladder/stair quadrant from Gen 1 Block 83 BR
    if len(g1_raw_blocks) > 83 and len(g2_raw_blocks) > 36:
        g1_83 = g1_raw_blocks[83]
        gw, gh = g1_83.size
        wood_stair_right = g1_83.crop((gw // 2, gh // 2, gw, gh))
        wood_stair_left = wood_stair_right.transpose(Image.FLIP_LEFT_RIGHT)

        b36 = g2_raw_blocks[36]
        bw, bh = b36.size
        cliff_top_left = b36.crop((0, 0, bw // 2, bh // 2))
        cliff_top_right = b36.crop((bw // 2, 0, bw, bh // 2))

        # Resize stair pieces to match G2 block dimensions
        target_qw, target_qh = bw // 2, bh // 2
        wood_stair_left = wood_stair_left.resize((target_qw, target_qh), Image.NEAREST)
        wood_stair_right = wood_stair_right.resize((target_qw, target_qh), Image.NEAREST)

        # Block 158: Top is cliff plateau top (#36), Bottom is wooden ladder stairs
        b158 = Image.new("RGB", (bw, bh))
        b158.paste(cliff_top_left, (0, 0))
        b158.paste(cliff_top_right, (target_qw, 0))
        b158.paste(wood_stair_left, (0, target_qh))
        b158.paste(wood_stair_right, (target_qw, target_qh))

        # Block 159: Top is wooden ladder stairs, Bottom is cliff plateau top (#36)
        b159 = Image.new("RGB", (bw, bh))
        b159.paste(wood_stair_left, (0, 0))
        b159.paste(wood_stair_right, (target_qw, 0))
        b159.paste(cliff_top_left, (0, target_qh))
        b159.paste(cliff_top_right, (target_qw, target_qh))

        while len(g2_raw_blocks) <= 159:
            g2_raw_blocks.append(Image.new("RGB", (bw, bh), (0, 0, 0)))

        g2_raw_blocks[158] = b158
        g2_raw_blocks[159] = b159
        print("Synthesized authentic Mt. Moon Wooden Ladder Stairs (#158 Stairs Down, #159 Stairs Up) into Gen 2 pool!")


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


# =============================================================================
# Phase 2: Deduplication, Building Filter & Fast CV Scoring
# =============================================================================

def get_sobel_magnitude(gray):
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    return cv2.magnitude(gx, gy)


def build_unique_quadrant_pool(g2_blocks_np, g2_coll_list=None, exclude_buildings=True):
    n2 = len(g2_blocks_np)
    g2_quads = [extract_quadrants(b) for b in g2_blocks_np]

    unique_dict = {}
    unique_pool = []

    for b_id in range(n2):
        if exclude_buildings and b_id in GEN2_BUILDING_BLOCKS and b_id not in (158, 159):
            continue

        for q_idx in range(4):
            q_arr = g2_quads[b_id][q_idx]
            c_byte = g2_coll_list[b_id][q_idx] if g2_coll_list and b_id < len(g2_coll_list) else 0x00
            q_key = (q_arr.tobytes(), c_byte)

            if q_key not in unique_dict:
                entry = {
                    "uid": len(unique_pool),
                    "g2_id": b_id,
                    "src_q": q_idx,
                    "img_np": q_arr,
                    "coll": c_byte,
                    "occurrences": [(b_id, q_idx)]
                }
                unique_dict[q_key] = entry
                unique_pool.append(entry)
            else:
                unique_dict[q_key]["occurrences"].append((b_id, q_idx))

    return unique_pool


def compute_base_quadrant_rankings(g1_blocks_np, unique_g2_quads):
    n1 = len(g1_blocks_np)
    g1_quads = [extract_quadrants(b) for b in g1_blocks_np]

    ksize = (9, 9)
    sigma = 1.2
    C1 = (0.01 * 255.0) ** 2
    C2 = (0.03 * 255.0) ** 2

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
            "img_np": q_arr,
            "gray": gray,
            "lab": lab,
            "sobel": sobel,
            "std": std,
            "mu": mu,
            "mu_sq": mu_sq,
            "s_sq": s_sq,
        })

    base_rankings = {}

    for i in range(n1):
        base_rankings[i] = {}
        for q_pos in range(4):
            q_arr1 = g1_quads[i][q_pos]
            gray1 = cv2.cvtColor(q_arr1, cv2.COLOR_RGB2GRAY).astype(np.float32)
            lab1 = cv2.cvtColor(q_arr1, cv2.COLOR_RGB2LAB).astype(np.float32)
            sobel1 = get_sobel_magnitude(gray1)
            norm_e1 = np.linalg.norm(sobel1)
            std1 = float(np.std(gray1))
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
                        "ssim": 1.0, "edge": 1.0, "color": 1.0
                    })
                    continue
                elif is_blank1 != is_blank2:
                    cand_scores.append({
                        "uid": item["uid"], "g2_id": item["g2_id"], "src_q": item["src_q"],
                        "coll": item["coll"], "occurrences": item["occurrences"],
                        "img_np": item["img_np"], "base_score": 0.0,
                        "ssim": 0.0, "edge": 0.0, "color": 0.0
                    })
                    continue

                mu1_mu2 = mu1 * item["mu"]
                sigma12 = cv2.GaussianBlur(gray1 * item["gray"], ksize, sigma) - mu1_mu2
                denom = (mu1_sq + item["mu_sq"] + C1) * (s1_sq + item["s_sq"] + C2)
                ssim = float(np.mean(((2.0 * mu1_mu2 + C1) * (2.0 * sigma12 + C2)) / denom))

                denom_e = norm_e1 * np.linalg.norm(item["sobel"])
                edge_sim = float(np.sum(sobel1 * item["sobel"]) / denom_e) if denom_e > 1e-6 else 0.0

                dL = np.abs(lab1[:, :, 0] - item["lab"][:, :, 0])
                dAB = np.sqrt((lab1[:, :, 1] - item["lab"][:, :, 1]) ** 2 + (lab1[:, :, 2] - item["lab"][:, :, 2]) ** 2)
                color_sim = float(np.exp(-np.mean(0.35 * dL + 0.65 * dAB) / 22.0))

                total = 0.40 * ssim + 0.30 * edge_sim + 0.30 * color_sim + pos_bonus
                cand_scores.append({
                    "uid": item["uid"],
                    "g2_id": item["g2_id"],
                    "src_q": item["src_q"],
                    "coll": item["coll"],
                    "occurrences": item["occurrences"],
                    "img_np": item["img_np"],
                    "base_score": total,
                    "ssim": ssim,
                    "edge": edge_sim,
                    "color": color_sim,
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


# =============================================================================
# Phase 3: The Human-in-the-Loop GUI with Authentic Wooden Ladder Stairs
# =============================================================================

class BlockMapperApp:
    def __init__(self, root, g1_images, g2_images, block_rankings, base_quad_rankings, unique_quad_pool, g2_tiles_raw=None, g2_coll_raw=None, out_path="SAFARI_G1_TO_G2_mapping.py", session_path=None, dict_name="SAFARI_G1_TO_G2"):
        self.root = root
        self.root.title("Pokémon Block ID Translation & Mt. Moon Quadrant Assembly Tool")
        self.root.geometry("1240x960")
        self.root.minsize(1060, 840)

        self.g1_images = g1_images
        self.g2_images = g2_images
        self.g1_np = [np.array(b) for b in g1_images]
        self.g2_np = [np.array(b) for b in g2_images]
        self.block_rankings = block_rankings
        self.base_quad_rankings = base_quad_rankings
        self.unique_quad_pool = unique_quad_pool
        self.g2_tiles_raw = g2_tiles_raw or []
        self.g2_coll_raw = g2_coll_raw or []
        self.out_path = out_path
        self.session_path = session_path or (os.path.splitext(out_path)[0] + ".session.json")
        self.dict_name = dict_name

        self.total_g1 = len(g1_images)
        self.total_g2 = len(g2_images)
        self.total_unique_quads = len(unique_quad_pool)

        self.favorites = self.load_favorites()
        self.learned_memory = {}

        self.mode = "QUAD"
        self.mapping = {}
        self.custom_blocks = {}
        self.next_custom_id = max(160, self.total_g2)

        self.current_g1_idx = 0
        self.active_quad_pos = 0
        self.current_quad_cand_idx = 0

        self.preview_size = 196
        self.quad_size = 92
        self.thumb_size = 56
        self.fav_thumb_size = 46
        self.dropin_thumb_size = 42
        self.thumb_window_size = 8

        self.tk_cache = {}

        self.g1_quad_keys = [[extract_quadrants(b)[q].tobytes() for q in range(4)] for b in self.g1_np]
        self.quad_user_modified = {i: set() for i in range(self.total_g1)}

        self.assembled_quads = {
            i: [
                self.get_ranked_candidates(i, 0)[0],
                self.get_ranked_candidates(i, 1)[0],
                self.get_ranked_candidates(i, 2)[0],
                self.get_ranked_candidates(i, 3)[0]
            ] for i in range(self.total_g1)
        }

        self.quad_shortlists = {i: {q: [] for q in range(4)} for i in range(self.total_g1)}

        self.load_session()

        self.build_styles()
        self.build_ui()
        self.bind_events()
        self.update_view()

    def get_ranked_candidates(self, g1_id, q_pos):
        base_list = self.base_quad_rankings[g1_id][q_pos]
        q_key = self.g1_quad_keys[g1_id][q_pos]
        learned_uid = self.learned_memory.get(q_key)

        if learned_uid is None:
            sorted_cands = sorted(base_list, key=lambda x: x["base_score"], reverse=True)
            res = []
            for c in sorted_cands:
                item = dict(c)
                item["score"] = item["base_score"]
                item["is_learned"] = False
                res.append(item)
            return res

        cands = []
        for item in base_list:
            c = dict(item)
            if c["uid"] == learned_uid:
                c["score"] = c["base_score"] + 2.0
                c["is_learned"] = True
            else:
                c["score"] = c["base_score"]
                c["is_learned"] = False
            cands.append(c)

        cands.sort(key=lambda x: x["score"], reverse=True)
        return cands

    def record_learned_choice(self, g1_id, q_pos, chosen_cand):
        q_key = self.g1_quad_keys[g1_id][q_pos]
        uid = chosen_cand.get("uid")
        if uid is not None:
            self.learned_memory[q_key] = uid
        self.quad_user_modified[g1_id].add(q_pos)

    def load_favorites(self):
        fav_path = os.path.expanduser("~/.block_mapper_favorites.json")
        if os.path.exists(fav_path):
            try:
                with open(fav_path, "r") as f:
                    favs = json.load(f)
                    if len(favs) == 8:
                        return favs
            except Exception:
                pass
        return list(DEFAULT_FAVORITES)

    def save_favorites_to_disk(self):
        fav_path = os.path.expanduser("~/.block_mapper_favorites.json")
        try:
            with open(fav_path, "w") as f:
                json.dump(self.favorites, f, indent=2)
        except Exception:
            pass

    def load_session(self):
        if os.path.exists(self.session_path):
            try:
                with open(self.session_path, "r") as f:
                    data = json.load(f)
                    if "mapping" in data:
                        self.mapping = {int(k): v for k, v in data["mapping"].items()}
                    if "custom_blocks" in data:
                        self.custom_blocks = {int(k): v for k, v in data["custom_blocks"].items()}
                    if "next_custom_id" in data:
                        self.next_custom_id = data["next_custom_id"]
                    if "learned_memory" in data:
                        self.learned_memory = {bytes.fromhex(k): v for k, v in data["learned_memory"].items() if v < len(self.unique_quad_pool)}
                    if "last_g1_idx" in data:
                        self.current_g1_idx = min(self.total_g1 - 1, data["last_g1_idx"])
                    for i in range(self.total_g1):
                        if i not in self.mapping:
                            self.current_g1_idx = i
                            break
                    print(f"Resumed session: {len(self.mapping)} / {self.total_g1} blocks mapped. ({len(self.learned_memory)} learned quad rules). Starting at Block #{self.current_g1_idx}.")
            except Exception as e:
                print(f"Session load warning: {e}")

    def auto_save_session(self):
        try:
            export_data = {
                "mapping": {int(k): v for k, v in self.mapping.items()},
                "custom_blocks": {int(k): v for k, v in self.custom_blocks.items()},
                "next_custom_id": self.next_custom_id,
                "last_g1_idx": self.current_g1_idx,
                "learned_memory": {k.hex(): v for k, v in self.learned_memory.items()}
            }
            with open(self.session_path, "w") as f:
                json.dump(export_data, f, indent=2, sort_keys=True)
        except Exception:
            pass

    def build_styles(self):
        style = ttk.Style()
        style.theme_use("clam")
        self.root.configure(bg="#181A20")

        style.configure("TFrame", background="#181A20")
        style.configure("Card.TFrame", background="#222530", relief="ridge")
        style.configure("Shortlist.TFrame", background="#1D2029", relief="solid", borderwidth=1)
        style.configure("Fav.TFrame", background="#17222D", relief="solid", borderwidth=1)
        style.configure("Building.TFrame", background="#2D1F17", relief="solid", borderwidth=1)
        style.configure("Special.TFrame", background="#202318", relief="solid", borderwidth=1)
        style.configure("TLabel", background="#181A20", foreground="#E0E0E0", font=("Helvetica", 10))
        style.configure("Title.TLabel", font=("Helvetica", 14, "bold"), foreground="#FFFFFF")
        style.configure("Header.TLabel", font=("Helvetica", 11, "bold"), foreground="#64B5F6")
        style.configure("CardHeader.TLabel", background="#222530", font=("Helvetica", 12, "bold"), foreground="#90CAF9")
        style.configure("CardSub.TLabel", background="#222530", font=("Helvetica", 10), foreground="#B0B4C0")
        style.configure("CardBadge.TLabel", background="#222530", font=("Helvetica", 10, "bold"), foreground="#FFB74D")
        style.configure("FavHeader.TLabel", background="#17222D", font=("Helvetica", 10, "bold"), foreground="#4DD0E1")
        style.configure("BuildingHeader.TLabel", background="#2D1F17", font=("Helvetica", 10, "bold"), foreground="#FF8A65")
        style.configure("SpecialHeader.TLabel", background="#202318", font=("Helvetica", 10, "bold"), foreground="#C5E1A5")

        style.configure("Approve.TButton", font=("Helvetica", 11, "bold"), foreground="#FFFFFF", background="#2E7D32")
        style.map("Approve.TButton", background=[("active", "#388E3C")])

        style.configure("Candidate.TButton", font=("Helvetica", 10, "bold"), foreground="#FFFFFF", background="#E65100")
        style.map("Candidate.TButton", background=[("active", "#F57C00")])

        style.configure("Fav.TButton", font=("Helvetica", 9, "bold"), foreground="#FFFFFF", background="#00838F")
        style.map("Fav.TButton", background=[("active", "#0097A7")])

        style.configure("Nav.TButton", font=("Helvetica", 9), background="#333748", foreground="#E0E0E0")
        style.map("Nav.TButton", background=[("active", "#464C62")])

        style.configure("ActiveTab.TButton", font=("Helvetica", 10, "bold"), background="#1565C0", foreground="#FFFFFF")
        style.map("ActiveTab.TButton", background=[("active", "#1976D2")])

    def build_ui(self):
        # 1. Top Header Bar
        top_frame = ttk.Frame(self.root)
        top_frame.pack(fill="x", padx=16, pady=(10, 3))

        self.lbl_progress = ttk.Label(top_frame, text="Progress: 0 / 0", style="Header.TLabel")
        self.lbl_progress.pack(side="left")

        self.progress_bar = ttk.Progressbar(top_frame, orient="horizontal", length=200, mode="determinate")
        self.progress_bar.pack(side="left", padx=8)

        self.lbl_unique_badge = ttk.Label(top_frame, text=f"🌿 {self.total_unique_quads} Clean Quads (incl. Mt. Moon Wooden Stairs)", font=("Helvetica", 9, "bold"), foreground="#A5D6A7")
        self.lbl_unique_badge.pack(side="left", padx=4)

        self.lbl_learned_badge = ttk.Label(top_frame, text="🧠 0 Rules Learned", font=("Helvetica", 9, "bold"), foreground="#FFD54F")
        self.lbl_learned_badge.pack(side="left", padx=4)

        ttk.Button(top_frame, text="🔍 Jump [J]", style="Nav.TButton", command=self.prompt_jump_to_g2_block).pack(side="left", padx=4)
        ttk.Button(top_frame, text="📂 Load Session", style="Nav.TButton", command=self.prompt_load_session).pack(side="left", padx=4)

        btn_save = ttk.Button(top_frame, text="💾 Save Dict (Ctrl+S)", style="Nav.TButton", command=self.save_mapping)
        btn_save.pack(side="right")

        # 2. ⭐ Quick Favorites Palette (F1–F8)
        fav_bar = ttk.Frame(self.root, style="Fav.TFrame", padding=4)
        fav_bar.pack(fill="x", padx=16, pady=2)

        fb_header = ttk.Frame(fav_bar, style="Fav.TFrame")
        fb_header.pack(fill="x")
        ttk.Label(fb_header, text="⭐ Quick Favorites (Hotkeys F1–F8 / Alt+1..8 to apply | Press [F] to pin):", style="FavHeader.TLabel").pack(side="left", padx=4)

        self.fav_container = ttk.Frame(fav_bar, style="Fav.TFrame")
        self.fav_container.pack(fill="x", pady=2)

        self.fav_slots = []
        for s in range(8):
            ff = tk.Frame(self.fav_container, bg="#101920", bd=1, relief="ridge", cursor="hand2")
            ff.pack(side="left", padx=2, expand=True)

            fc = tk.Canvas(ff, width=self.fav_thumb_size, height=self.fav_thumb_size, bg="#0D1318", highlightthickness=0)
            fc.pack(pady=1, padx=1)

            fl = tk.Label(ff, text=f"F{s+1}: --", bg="#101920", fg="#4DD0E1", font=("Helvetica", 8, "bold"))
            fl.pack(pady=1)

            def make_fav_click(slot=s):
                return lambda e: self.apply_favorite_slot(slot)

            def make_fav_context(slot=s):
                return lambda e: self.pin_current_to_favorite(slot)

            ff.bind("<Button-1>", make_fav_click(s))
            fc.bind("<Button-1>", make_fav_click(s))
            fl.bind("<Button-1>", make_fav_click(s))
            ff.bind("<Button-3>", make_fav_context(s))
            fc.bind("<Button-3>", make_fav_context(s))
            fl.bind("<Button-3>", make_fav_context(s))

            self.fav_slots.append({"frame": ff, "canvas": fc, "label": fl})

        # 3. 🏛️ Building & 🪜 Mt. Moon Wooden Ladder Stairs Visual Drop-In Bar
        self.building_bar = ttk.Frame(self.root, style="Building.TFrame", padding=4)
        bb_header = ttk.Frame(self.building_bar, style="Building.TFrame")
        bb_header.pack(fill="x")
        self.lbl_building_notice = ttk.Label(bb_header, text="🏛️ Gen 1 Building Block Detected (Click visual card for Direct Drop-In):", style="BuildingHeader.TLabel")
        self.lbl_building_notice.pack(side="left", padx=4)

        self.building_cards_container = ttk.Frame(self.building_bar, style="Building.TFrame")
        self.building_cards_container.pack(fill="x", pady=2)
        self.building_cards = []
        for drop in BUILDING_DIRECT_DROPINS:
            bf = tk.Frame(self.building_cards_container, bg="#1E140F", bd=1, relief="ridge", cursor="hand2")
            bf.pack(side="left", padx=3, expand=True)

            bc = tk.Canvas(bf, width=self.dropin_thumb_size, height=self.dropin_thumb_size, bg="#150E0A", highlightthickness=0)
            bc.pack(pady=1, padx=1)

            bl = tk.Label(bf, text=drop["label"], bg="#1E140F", fg="#FFAB91", font=("Helvetica", 8, "bold"))
            bl.pack(pady=1)

            def make_bdrop_action(gid=drop["g2_id"]):
                return lambda e: self.apply_direct_block_dropin(gid)

            bf.bind("<Button-1>", make_bdrop_action(drop["g2_id"]))
            bc.bind("<Button-1>", make_bdrop_action(drop["g2_id"]))
            bl.bind("<Button-1>", make_bdrop_action(drop["g2_id"]))
            self.building_cards.append({"frame": bf, "canvas": bc, "label": bl, "g2_id": drop["g2_id"]})

        self.special_bar = ttk.Frame(self.root, style="Special.TFrame", padding=4)
        sb_header = ttk.Frame(self.special_bar, style="Special.TFrame")
        sb_header.pack(fill="x")
        self.lbl_special_notice = ttk.Label(sb_header, text="🪜 Mt. Moon Wooden Ladder Stairs & Features (Click piece to apply & advance):", style="SpecialHeader.TLabel")
        self.lbl_special_notice.pack(side="left", padx=4)

        # Row 1: Per-Quadrant Drop-In Visual Thumbnail Cards
        self.special_cards_container = ttk.Frame(self.special_bar, style="Special.TFrame")
        self.special_cards_container.pack(fill="x", pady=2)
        self.special_quad_cards = []
        for q_drop in QUAD_FEATURE_PRESETS:
            qf = tk.Frame(self.special_cards_container, bg="#191F14", bd=1, relief="ridge", cursor="hand2")
            qf.pack(side="left", padx=2, expand=True)

            qc = tk.Canvas(qf, width=self.dropin_thumb_size, height=self.dropin_thumb_size, bg="#10150D", highlightthickness=0)
            qc.pack(pady=1, padx=1)

            ql = tk.Label(qf, text=f"{q_drop['label']}\n#{q_drop['g2_id']} ({QUAD_SHORT[q_drop['src_q']]})", bg="#191F14", fg="#C5E1A5", font=("Helvetica", 7, "bold"), justify="center")
            ql.pack(pady=1)

            def make_qdrop_action(gid=q_drop["g2_id"], sq=q_drop["src_q"], col=q_drop["coll"]):
                return lambda e: self.apply_quad_feature_preset(gid, sq, col)

            qf.bind("<Button-1>", make_qdrop_action(q_drop["g2_id"], q_drop["src_q"], q_drop["coll"]))
            qc.bind("<Button-1>", make_qdrop_action(q_drop["g2_id"], q_drop["src_q"], q_drop["coll"]))
            ql.bind("<Button-1>", make_qdrop_action(q_drop["g2_id"], q_drop["src_q"], q_drop["coll"]))

            self.special_quad_cards.append({"frame": qf, "canvas": qc, "label": ql, "data": q_drop})

        # Row 2: Whole Block Drop-Ins with Full Block Visual Previews
        self.special_whole_box = ttk.Frame(self.special_bar, style="Special.TFrame")
        self.special_whole_box.pack(fill="x", pady=2)
        ttk.Label(self.special_whole_box, text="⭐ Full Block Drop-Ins:", font=("Helvetica", 8, "bold"), foreground="#C5E1A5", background="#202318").pack(side="left", padx=4)

        self.special_whole_cards = []
        for w_drop in WHOLE_BLOCK_DROPINS:
            wf = tk.Frame(self.special_whole_box, bg="#132415", bd=1, relief="ridge", cursor="hand2")
            wf.pack(side="left", padx=4)

            wc = tk.Canvas(wf, width=32, height=32, bg="#0E1A0F", highlightthickness=0)
            wc.pack(side="left", padx=2, pady=1)

            wl = tk.Label(wf, text=f"⭐ {w_drop['label']} (#{w_drop['g2_id']})", bg="#132415", fg="#A5D6A7", font=("Helvetica", 8, "bold"))
            wl.pack(side="left", padx=4, pady=1)

            def make_wdrop_action(gid=w_drop["g2_id"]):
                return lambda e: self.apply_direct_block_dropin(gid)

            wf.bind("<Button-1>", make_wdrop_action(w_drop["g2_id"]))
            wc.bind("<Button-1>", make_wdrop_action(w_drop["g2_id"]))
            wl.bind("<Button-1>", make_wdrop_action(w_drop["g2_id"]))
            self.special_whole_cards.append({"frame": wf, "canvas": wc, "label": wl, "g2_id": w_drop["g2_id"]})

        # 4. Main Workspace
        workspace = ttk.Frame(self.root)
        workspace.pack(fill="both", expand=True, padx=16, pady=4)

        # --- Target Gen 1 Card (Left) ---
        g1_card = ttk.Frame(workspace, style="Card.TFrame", padding=10)
        g1_card.pack(side="left", fill="both", expand=True, padx=(0, 4))

        ttk.Label(g1_card, text="Target: Gen 1 Block", style="CardHeader.TLabel").pack(pady=(0, 2))
        self.lbl_g1_id = ttk.Label(g1_card, text="ID: 0 (0x00)", style="CardSub.TLabel")
        self.lbl_g1_id.pack(pady=(0, 4))

        self.canvas_g1 = tk.Canvas(g1_card, width=self.preview_size, height=self.preview_size, bg="#101114", highlightthickness=1, highlightbackground="#3F4456")
        self.canvas_g1.pack(pady=4)

        self.lbl_g1_status = ttk.Label(g1_card, text="Status: Unconfirmed", style="CardBadge.TLabel")
        self.lbl_g1_status.pack(pady=2)

        # --- Active Quadrant Workspace (Center) ---
        center_card = ttk.Frame(workspace, style="Card.TFrame", padding=10)
        center_card.pack(side="left", fill="both", expand=True, padx=4)

        ttk.Label(center_card, text="Active Quadrant Candidate", style="CardHeader.TLabel").pack(pady=(0, 2))

        tab_box = ttk.Frame(center_card, style="Card.TFrame")
        tab_box.pack(fill="x", pady=4)
        self.quad_tab_buttons = []
        for q in range(4):
            btn = ttk.Button(tab_box, text=f"[{q+1}] {QUAD_SHORT[q]}", style="Nav.TButton", width=7, command=lambda pos=q: self.set_active_quad(pos))
            btn.pack(side="left", padx=2, expand=True)
            self.quad_tab_buttons.append(btn)

        q_view_box = ttk.Frame(center_card, style="Card.TFrame")
        q_view_box.pack(fill="x", pady=4)

        self.canvas_quad_active = tk.Canvas(q_view_box, width=self.quad_size, height=self.quad_size, bg="#101114", highlightthickness=1, highlightbackground="#FFB74D")
        self.canvas_quad_active.pack(side="left", padx=6)

        q_info_box = ttk.Frame(q_view_box, style="Card.TFrame")
        q_info_box.pack(side="left", fill="both", expand=True, padx=4)

        self.lbl_quad_rank = ttk.Label(q_info_box, text="Rank: #1", font=("Helvetica", 10, "bold"), foreground="#FFB74D", background="#222530")
        self.lbl_quad_rank.pack(anchor="w")
        self.lbl_quad_src = ttk.Label(q_info_box, text="Primary: G2 Block #15 (TL)", style="CardSub.TLabel")
        self.lbl_quad_src.pack(anchor="w")
        self.lbl_quad_also = ttk.Label(q_info_box, text="Also in: #50, #51, #108...", font=("Helvetica", 9), foreground="#81D4FA", background="#222530")
        self.lbl_quad_also.pack(anchor="w")
        self.lbl_quad_score = ttk.Label(q_info_box, text="Score: 0.00 (SSIM: 0.00, Color: 0.00)", font=("Helvetica", 9), foreground="#90CAF9", background="#222530")
        self.lbl_quad_score.pack(anchor="w")

        coll_box = ttk.Frame(center_card, style="Card.TFrame")
        coll_box.pack(fill="x", pady=4)

        ttk.Label(coll_box, text="Quadrant Collision Semantics:", font=("Helvetica", 10, "bold"), foreground="#FFD54F", background="#222530").pack(anchor="w")
        self.cbo_collision = ttk.Combobox(coll_box, values=[p["label"] for p in COLLISION_PRESETS], state="readonly", font=("Helvetica", 9))
        self.cbo_collision.pack(fill="x", pady=2)
        self.cbo_collision.bind("<<ComboboxSelected>>", self.on_collision_selected)

        q_nav_box = ttk.Frame(center_card, style="Card.TFrame")
        q_nav_box.pack(fill="x", pady=4)
        ttk.Button(q_nav_box, text="◀ Prev [←]", style="Nav.TButton", command=self.prev_candidate).pack(side="left", padx=2, expand=True)
        ttk.Button(q_nav_box, text="Next [→] ▶", style="Nav.TButton", command=self.next_candidate).pack(side="left", padx=2, expand=True)
        ttk.Button(q_nav_box, text="★ Shortlist [ \\ ]", style="Candidate.TButton", command=self.toggle_current_as_candidate).pack(side="left", padx=2, expand=True)
        ttk.Button(q_nav_box, text="⭐ Pin Fav [F]", style="Fav.TButton", command=self.pin_current_to_favorite).pack(side="left", padx=2, expand=True)

        # --- Live Assembled Block (Right) ---
        g2_assembled_card = ttk.Frame(workspace, style="Card.TFrame", padding=10)
        g2_assembled_card.pack(side="left", fill="both", expand=True, padx=(4, 0))

        ttk.Label(g2_assembled_card, text="Live Assembled Gen 2 Block", style="CardHeader.TLabel").pack(pady=(0, 2))
        self.lbl_assembled_id = ttk.Label(g2_assembled_card, text="Matches: Custom Block #129", style="CardSub.TLabel")
        self.lbl_assembled_id.pack(pady=(0, 4))

        self.canvas_assembled = tk.Canvas(g2_assembled_card, width=self.preview_size, height=self.preview_size, bg="#101114", highlightthickness=1, highlightbackground="#64B5F6")
        self.canvas_assembled.pack(pady=4)

        self.lbl_assembled_coll_summary = ttk.Label(g2_assembled_card, text="Collision: [0x00, 0x07, 0x00, 0x07]", font=("Helvetica", 9), foreground="#A5D6A7", background="#222530")
        self.lbl_assembled_coll_summary.pack(pady=2)

        # 5. Shortlist Strip (Per Quadrant)
        self.shortlist_frame = ttk.Frame(self.root, style="Shortlist.TFrame", padding=4)
        self.shortlist_frame.pack(fill="x", padx=16, pady=2)

        sl_header = ttk.Frame(self.shortlist_frame, style="Shortlist.TFrame")
        sl_header.pack(fill="x")
        self.lbl_shortlist_status = ttk.Label(sl_header, text="★ Shortlisted Quads (Press \\ to add, 1-8 to pick):", font=("Helvetica", 9, "bold"), foreground="#FFD54F", background="#1D2029")
        self.lbl_shortlist_status.pack(side="left", padx=4)

        self.shortlist_btn_container = ttk.Frame(self.shortlist_frame, style="Shortlist.TFrame")
        self.shortlist_btn_container.pack(fill="x", pady=2)
        self.shortlist_slots = []
        for s in range(8):
            sf = tk.Frame(self.shortlist_btn_container, bg="#121316", bd=1, relief="ridge", cursor="hand2")
            sf.pack(side="left", padx=2, expand=True)
            sc = tk.Canvas(sf, width=40, height=40, bg="#101114", highlightthickness=0)
            sc.pack(pady=1, padx=1)
            sl = tk.Label(sf, text="--", bg="#121316", fg="#FFD54F", font=("Helvetica", 8, "bold"))
            sl.pack(pady=1)

            def make_sl_handler(slot=s):
                return lambda e: self.pick_shortlist_slot(slot)

            sf.bind("<Button-1>", make_sl_handler(s))
            sc.bind("<Button-1>", make_sl_handler(s))
            sl.bind("<Button-1>", make_sl_handler(s))
            self.shortlist_slots.append({"frame": sf, "canvas": sc, "label": sl, "cand": None})

        # 6. Sliding Window Candidates Thumbnails
        thumb_bar = ttk.Frame(self.root, style="Card.TFrame", padding=4)
        thumb_bar.pack(fill="x", padx=16, pady=2)

        th_header = ttk.Frame(thumb_bar, style="Card.TFrame")
        th_header.pack(fill="x")
        self.lbl_thumb_title = ttk.Label(th_header, text="Unique Candidate Window (Click to preview):", style="CardSub.TLabel")
        self.lbl_thumb_title.pack(side="left", padx=4)

        th_nav = ttk.Frame(th_header, style="Card.TFrame")
        th_nav.pack(side="right")
        ttk.Button(th_nav, text="◀ Prev 8", style="Nav.TButton", command=self.jump_prev_8).pack(side="left", padx=2)
        ttk.Button(th_nav, text="Next 8 ▶", style="Nav.TButton", command=self.jump_next_8).pack(side="left", padx=2)

        self.thumb_container = ttk.Frame(thumb_bar, style="Card.TFrame")
        self.thumb_container.pack(fill="x", pady=2)

        self.thumb_buttons = []
        for k in range(self.thumb_window_size):
            t_frame = tk.Frame(self.thumb_container, bg="#181A20", bd=1, relief="ridge", cursor="hand2")
            t_frame.pack(side="left", padx=2, expand=True)

            t_canv = tk.Canvas(t_frame, width=self.thumb_size, height=self.thumb_size, bg="#101114", highlightthickness=0)
            t_canv.pack(pady=1, padx=1)

            t_lbl = tk.Label(t_frame, text=f"#{k+1}", bg="#181A20", fg="#E0E0E0", font=("Helvetica", 8))
            t_lbl.pack(pady=1)

            def make_handler(slot=k):
                return lambda e: self.select_window_slot(slot)

            t_frame.bind("<Button-1>", make_handler(k))
            t_canv.bind("<Button-1>", make_handler(k))
            t_lbl.bind("<Button-1>", make_handler(k))

            self.thumb_buttons.append({"frame": t_frame, "canvas": t_canv, "label": t_lbl})

        # 7. Bottom Action Bar
        bot_bar = ttk.Frame(self.root)
        bot_bar.pack(fill="x", padx=16, pady=(4, 10))

        ttk.Button(bot_bar, text="◀ Prev Block [P]", style="Nav.TButton", command=self.prev_g1_block).pack(side="left", padx=4)
        ttk.Button(bot_bar, text="Skip Block [N]", style="Nav.TButton", command=self.next_g1_block).pack(side="left", padx=4)

        self.btn_approve = ttk.Button(bot_bar, text="✔ Next Quad / Confirm [Enter]", style="Approve.TButton", padding=(20, 8), command=self.handle_enter_action)
        self.btn_approve.pack(side="right", padx=6)

        ttk.Button(bot_bar, text="Next Quad [Tab]", style="Nav.TButton", padding=(10, 8), command=self.next_quad_tab).pack(side="right", padx=4)

    def bind_events(self):
        self.root.bind("<Return>", lambda e: self.handle_enter_action())
        self.root.bind("<KP_Enter>", lambda e: self.handle_enter_action())
        self.root.bind("<backslash>", lambda e: self.toggle_current_as_candidate())
        self.root.bind("|", lambda e: self.toggle_current_as_candidate())
        self.root.bind("<space>", lambda e: self.next_candidate())
        self.root.bind("<Right>", lambda e: self.next_candidate())
        self.root.bind("<Left>", lambda e: self.prev_candidate())
        self.root.bind("<Tab>", lambda e: (self.next_quad_tab(), "break")[1])
        self.root.bind("<Next>", lambda e: self.jump_next_8())
        self.root.bind("<Prior>", lambda e: self.jump_prev_8())
        self.root.bind("f", lambda e: self.pin_current_to_favorite())
        self.root.bind("F", lambda e: self.pin_current_to_favorite())
        self.root.bind("j", lambda e: self.prompt_jump_to_g2_block())
        self.root.bind("J", lambda e: self.prompt_jump_to_g2_block())
        self.root.bind("p", lambda e: self.prev_g1_block())
        self.root.bind("P", lambda e: self.prev_g1_block())
        self.root.bind("n", lambda e: self.next_g1_block())
        self.root.bind("N", lambda e: self.next_g1_block())
        self.root.bind("<Control-s>", lambda e: self.save_mapping())
        self.root.bind("<Control-S>", lambda e: self.save_mapping())

        for f_idx in range(8):
            fn_key = f"<F{f_idx + 1}>"
            alt_key = f"<Alt-Key-{f_idx + 1}>"
            self.root.bind(fn_key, lambda e, s=f_idx: self.apply_favorite_slot(s))
            self.root.bind(alt_key, lambda e, s=f_idx: self.apply_favorite_slot(s))

        for n in range(1, 9):
            self.root.bind(str(n), lambda e, k=n-1: self.on_number_key(k))

    def prompt_jump_to_g2_block(self):
        val = simpledialog.askstring("Jump to Gen 2 Block", f"Enter Gen 2 Block ID (0–{self.total_g2 - 1}):\n(e.g., 158 for Stairs Down, 159 for Stairs Up, 36 for Cliff, 27 for Fence)", parent=self.root)
        if not val or not val.isdigit():
            return
        g2_id = int(val)
        if 0 <= g2_id < self.total_g2:
            res = messagebox.askyesno("Apply Mode", f"Map ENTIRE Gen 1 Block #{self.current_g1_idx} directly to Gen 2 #{g2_id}?\n\n(Click 'No' to just apply Quad {QUAD_SHORT[self.active_quad_pos]} from Block #{g2_id})")
            if res:
                self.apply_direct_block_dropin(g2_id)
            else:
                q_img = self.get_quad_image(g2_id, self.active_quad_pos)
                c_byte = self.g2_coll_raw[g2_id][self.active_quad_pos] if g2_id < len(self.g2_coll_raw) else 0x00
                chosen = {
                    "uid": None,
                    "g2_id": g2_id,
                    "src_q": self.active_quad_pos,
                    "coll": c_byte,
                    "img_np": np.array(q_img),
                    "score": 1.0
                }
                for u in self.unique_quad_pool:
                    if u["g2_id"] == g2_id and u["src_q"] == self.active_quad_pos:
                        chosen["uid"] = u["uid"]
                        break
                self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = chosen
                self.record_learned_choice(self.current_g1_idx, self.active_quad_pos, chosen)
                self.advance_quad_or_block()

    def prompt_load_session(self):
        path = filedialog.askopenfilename(
            title="Load Session File",
            filetypes=[("Session JSON", "*.session.json"), ("JSON File", "*.json"), ("All Files", "*.*")]
        )
        if path and os.path.exists(path):
            self.session_path = path
            self.load_session()
            self.update_view()
            messagebox.showinfo("Session Loaded", f"Resumed progress: {len(self.mapping)} blocks mapped.\nStarting at Block #{self.current_g1_idx}.")

    def apply_direct_block_dropin(self, g2_id):
        self.mapping[self.current_g1_idx] = g2_id
        for q in range(4):
            for u in self.unique_quad_pool:
                if u["g2_id"] == g2_id and u["src_q"] == q:
                    self.record_learned_choice(self.current_g1_idx, q, u)
                    break
        self.auto_save_session()
        if self.current_g1_idx < self.total_g1 - 1:
            self.current_g1_idx += 1
            self.active_quad_pos = 0
            self.current_quad_cand_idx = 0
            self.update_view()
        else:
            self.update_view()
            if messagebox.askyesno("Complete!", f"Finished all {self.total_g1} blocks!\nWould you like to export now?"):
                self.save_mapping()

    def apply_quad_feature_preset(self, g2_id, src_q, coll=0x00):
        """Applies a single quadrant feature preset (e.g. Stair step, cliff top) to active quad and advances."""
        q_img = self.get_quad_image(g2_id, src_q)
        chosen = {
            "uid": None,
            "g2_id": g2_id,
            "src_q": src_q,
            "coll": coll,
            "img_np": np.array(q_img),
            "score": 1.0
        }
        for u in self.unique_quad_pool:
            if u["g2_id"] == g2_id and u["src_q"] == src_q:
                chosen["uid"] = u["uid"]
                break
        self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = chosen
        self.record_learned_choice(self.current_g1_idx, self.active_quad_pos, chosen)
        self.advance_quad_or_block()

    def apply_favorite_slot(self, slot):
        if slot < len(self.favorites):
            fav = self.favorites[slot]
            g2_id = fav["g2_id"]
            src_q = fav.get("src_q", 0)
            coll = fav.get("coll", 0x00)

            q_img = self.get_quad_image(g2_id, src_q)
            chosen = {
                "uid": None,
                "g2_id": g2_id,
                "src_q": src_q,
                "coll": coll,
                "img_np": np.array(q_img),
                "score": 1.0
            }
            for u in self.unique_quad_pool:
                if u["g2_id"] == g2_id and u["src_q"] == src_q:
                    chosen["uid"] = u["uid"]
                    break
            self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = chosen
            self.record_learned_choice(self.current_g1_idx, self.active_quad_pos, chosen)
            self.advance_quad_or_block()

    def pin_current_to_favorite(self, target_slot=None):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if not cands:
            return
        cur_cand = cands[self.current_quad_cand_idx]
        g2_id = cur_cand["g2_id"]
        src_q = cur_cand["src_q"]
        coll = cur_cand.get("coll", 0x00)

        if target_slot is None:
            slot_str = simpledialog.askstring("Pin Favorite", f"Pin G2 #{g2_id} ({QUAD_SHORT[src_q]}) to which Favorite Slot (1-8)?", parent=self.root)
            if not slot_str or not slot_str.isdigit():
                return
            target_slot = int(slot_str) - 1

        if 0 <= target_slot < 8:
            name = f"B#{g2_id}"
            self.favorites[target_slot] = {
                "g2_id": g2_id,
                "src_q": src_q,
                "name": name,
                "coll": coll
            }
            self.save_favorites_to_disk()
            self.update_view()

    def set_active_quad(self, pos):
        self.active_quad_pos = pos
        self.current_quad_cand_idx = 0
        self.update_view()

    def next_quad_tab(self):
        self.active_quad_pos = (self.active_quad_pos + 1) % 4
        self.current_quad_cand_idx = 0
        self.update_view()

    def on_number_key(self, slot):
        sl = self.quad_shortlists[self.current_g1_idx][self.active_quad_pos]
        if sl and slot < len(sl):
            self.pick_shortlist_slot(slot)
        else:
            self.select_window_slot(slot)

    def on_collision_selected(self, event=None):
        idx = self.cbo_collision.current()
        if idx >= 0:
            val = COLLISION_PRESETS[idx]["val"]
            self.assembled_quads[self.current_g1_idx][self.active_quad_pos]["coll"] = val
            self.quad_user_modified[self.current_g1_idx].add(self.active_quad_pos)
            self.update_view()

    def toggle_current_as_candidate(self):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if not cands:
            return
        cur_cand = dict(cands[self.current_quad_cand_idx])
        sl = self.quad_shortlists[self.current_g1_idx][self.active_quad_pos]

        match_idx = None
        for i, item in enumerate(sl):
            if item.get("uid") == cur_cand.get("uid"):
                match_idx = i
                break
        if match_idx is not None:
            sl.pop(match_idx)
        else:
            sl.append(cur_cand)
            self.current_quad_cand_idx = (self.current_quad_cand_idx + 1) % len(cands)
        self.update_view()

    def pick_shortlist_slot(self, slot):
        sl = self.quad_shortlists[self.current_g1_idx][self.active_quad_pos]
        if slot < len(sl):
            chosen = dict(sl[slot])
            self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = chosen
            self.record_learned_choice(self.current_g1_idx, self.active_quad_pos, chosen)
            self.advance_quad_or_block()

    def handle_enter_action(self):
        sl = self.quad_shortlists[self.current_g1_idx][self.active_quad_pos]
        if len(sl) > 1:
            self.open_shortlist_picker()
        else:
            if sl:
                chosen = dict(sl[0])
            else:
                cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
                chosen = dict(cands[self.current_quad_cand_idx]) if cands else None
            if chosen:
                self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = chosen
                self.record_learned_choice(self.current_g1_idx, self.active_quad_pos, chosen)
            self.advance_quad_or_block()

    def open_shortlist_picker(self):
        sl = self.quad_shortlists[self.current_g1_idx][self.active_quad_pos]
        if not sl:
            return
        top = tk.Toplevel(self.root)
        top.title(f"Pick Candidate for Quad {QUAD_SHORT[self.active_quad_pos]}")
        top.geometry("640x270")
        top.configure(bg="#181A20")
        top.transient(self.root)
        top.grab_set()

        tk.Label(top, text=f"Select from your {len(sl)} shortlisted candidates for {QUAD_NAMES[self.active_quad_pos]}:", font=("Helvetica", 11, "bold"), bg="#181A20", fg="#FFD54F").pack(pady=10)
        cand_box = tk.Frame(top, bg="#181A20")
        cand_box.pack(fill="x", padx=12, pady=6)

        for idx, item in enumerate(sl):
            cf = tk.Frame(cand_box, bg="#222530", bd=2, relief="ridge", cursor="hand2")
            cf.pack(side="left", padx=4, expand=True)

            q_img = Image.fromarray(item["img_np"]).resize((60, 60), Image.NEAREST)
            tk_c = ImageTk.PhotoImage(q_img)
            self.tk_cache[f"modal_{idx}"] = tk_c

            canv = tk.Canvas(cf, width=60, height=60, bg="#101114", highlightthickness=0)
            canv.pack(pady=2, padx=2)
            canv.create_image(30, 30, image=tk_c)

            lbl = tk.Label(cf, text=f"[{idx+1}] #{item['g2_id']}", font=("Helvetica", 9, "bold"), bg="#222530", fg="#FFFFFF")
            lbl.pack(pady=1)

            def select_fn(cand=item):
                top.destroy()
                self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = dict(cand)
                self.record_learned_choice(self.current_g1_idx, self.active_quad_pos, cand)
                self.advance_quad_or_block()

            cf.bind("<Button-1>", lambda e, f=select_fn: f())
            canv.bind("<Button-1>", lambda e, f=select_fn: f())
            lbl.bind("<Button-1>", lambda e, f=select_fn: f())
            top.bind(str(idx + 1), lambda e, f=select_fn: f())

        top.bind("<Escape>", lambda e: top.destroy())

    def advance_quad_or_block(self):
        if self.active_quad_pos < 3:
            self.active_quad_pos += 1
            self.current_quad_cand_idx = 0
            self.update_view()
        else:
            self.finalize_block_mapping(self.current_g1_idx)
            self.auto_save_session()
            if self.current_g1_idx < self.total_g1 - 1:
                self.current_g1_idx += 1
                self.active_quad_pos = 0
                self.current_quad_cand_idx = 0
                self.update_view()
            else:
                self.update_view()
                if messagebox.askyesno("Complete!", f"Finished all {self.total_g1} blocks!\nWould you like to export now?"):
                    self.save_mapping()

    def finalize_block_mapping(self, g1_id):
        quads = self.assembled_quads[g1_id]
        if quads[0]["g2_id"] == quads[1]["g2_id"] == quads[2]["g2_id"] == quads[3]["g2_id"] and \
           quads[0]["src_q"] == 0 and quads[1]["src_q"] == 1 and quads[2]["src_q"] == 2 and quads[3]["src_q"] == 3:
            self.mapping[g1_id] = quads[0]["g2_id"]
        else:
            cid = self.next_custom_id
            self.next_custom_id += 1
            self.mapping[g1_id] = cid

            tiles_16 = self.get_assembled_tiles(g1_id)
            coll_4 = [q["coll"] for q in quads]
            self.custom_blocks[cid] = {
                "tiles": tiles_16,
                "collision": coll_4,
                "source_g1": g1_id
            }

    def get_assembled_tiles(self, g1_id):
        quads = self.assembled_quads[g1_id]
        def extract_quad_tiles(b_id, q_pos):
            if b_id == 158:
                if q_pos in (0, 1): return [17, 17, 17, 17]
                else: return [77, 78, 83, 84]
            elif b_id == 159:
                if q_pos in (0, 1): return [77, 78, 83, 84]
                else: return [17, 17, 17, 17]
            if b_id < len(self.g2_tiles_raw):
                b = self.g2_tiles_raw[b_id]
                if q_pos == 0: return [b[0], b[1], b[4], b[5]]
                elif q_pos == 1: return [b[2], b[3], b[6], b[7]]
                elif q_pos == 2: return [b[8], b[9], b[12], b[13]]
                elif q_pos == 3: return [b[10], b[11], b[14], b[15]]
            return [0, 0, 0, 0]


        tl = extract_quad_tiles(quads[0]["g2_id"], quads[0]["src_q"])
        tr = extract_quad_tiles(quads[1]["g2_id"], quads[1]["src_q"])
        bl = extract_quad_tiles(quads[2]["g2_id"], quads[2]["src_q"])
        br = extract_quad_tiles(quads[3]["g2_id"], quads[3]["src_q"])
        return assemble_16_tiles(tl, tr, bl, br)

    def get_quad_image(self, g2_id, q_pos):
        if g2_id < len(self.g2_images):
            g2_np = np.array(self.g2_images[g2_id])
            q_np = extract_quadrants(g2_np)[q_pos]
            return Image.fromarray(q_np)
        return Image.new("RGB", (48, 48), (0, 0, 0))

    def get_block_image(self, g2_id):
        if g2_id < len(self.g2_images):
            return self.g2_images[g2_id]
        return Image.new("RGB", (48, 48), (0, 0, 0))

    def update_view(self):
        mapped_count = len(self.mapping)
        self.lbl_progress.config(text=f"Gen 1 Block {self.current_g1_idx} / {self.total_g1 - 1}  ({mapped_count}/{self.total_g1} mapped)")
        self.progress_bar["maximum"] = self.total_g1
        self.progress_bar["value"] = self.current_g1_idx + 1

        self.lbl_learned_badge.config(text=f"🧠 {len(self.learned_memory)} Learned Rules")

        is_building = self.current_g1_idx in GEN1_BUILDING_BLOCKS
        is_stair_or_cliff = self.current_g1_idx in GEN1_STAIR_BLOCKS

        if is_building:
            self.special_bar.pack_forget()
            self.building_bar.pack(fill="x", padx=16, pady=2, before=self.shortlist_frame)
            self.lbl_building_notice.config(text=f"🏛️ Gen 1 Block #{self.current_g1_idx} is a Building -> Click visual card for Direct Drop-In:")
            # Render building thumbnails
            for card in self.building_cards:
                b_img = self.get_block_image(card["g2_id"]).resize((self.dropin_thumb_size, self.dropin_thumb_size), Image.NEAREST)
                tk_b = ImageTk.PhotoImage(b_img)
                self.tk_cache[f"bdrop_{card['g2_id']}"] = tk_b
                card["canvas"].delete("all")
                card["canvas"].create_image(self.dropin_thumb_size // 2, self.dropin_thumb_size // 2, image=tk_b)
        elif is_stair_or_cliff:
            self.building_bar.pack_forget()
            self.special_bar.pack(fill="x", padx=16, pady=2, before=self.shortlist_frame)
            self.lbl_special_notice.config(text=f"🪜 Gen 1 Block #{self.current_g1_idx} (Mt. Moon Stairs/Cliff) -> Click piece to apply to {QUAD_SHORT[self.active_quad_pos]} & advance:")
            # Render special quadrant cards
            for idx, card in enumerate(self.special_quad_cards):
                d = card["data"]
                q_img = self.get_quad_image(d["g2_id"], d["src_q"]).resize((self.dropin_thumb_size, self.dropin_thumb_size), Image.NEAREST)
                tk_sq = ImageTk.PhotoImage(q_img)
                self.tk_cache[f"sqdrop_{idx}"] = tk_sq
                card["canvas"].delete("all")
                card["canvas"].create_image(self.dropin_thumb_size // 2, self.dropin_thumb_size // 2, image=tk_sq)
            # Render whole block drop-ins
            for card in self.special_whole_cards:
                wb_img = self.get_block_image(card["g2_id"]).resize((32, 32), Image.NEAREST)
                tk_wb = ImageTk.PhotoImage(wb_img)
                self.tk_cache[f"swdrop_{card['g2_id']}"] = tk_wb
                card["canvas"].delete("all")
                card["canvas"].create_image(16, 16, image=tk_wb)
        else:
            self.building_bar.pack_forget()
            self.special_bar.pack_forget()

        # 1. Update ⭐ Favorites Palette Display
        for s in range(8):
            f_obj = self.fav_slots[s]
            if s < len(self.favorites):
                fav = self.favorites[s]
                f_img = self.get_quad_image(fav["g2_id"], fav.get("src_q", 0)).resize((self.fav_thumb_size, self.fav_thumb_size), Image.NEAREST)
                tk_f = ImageTk.PhotoImage(f_img)
                self.tk_cache[f"fav_{s}"] = tk_f
                f_obj["canvas"].delete("all")
                f_obj["canvas"].create_image(self.fav_thumb_size // 2, self.fav_thumb_size // 2, image=tk_f)
                f_obj["label"].config(text=f"F{s+1}: #{fav['g2_id']}")

        # 2. Target Gen 1 Preview with Active Quadrant Highlight Border
        g1_base = self.g1_images[self.current_g1_idx].resize((self.preview_size, self.preview_size), Image.NEAREST)
        draw_g1 = ImageDraw.Draw(g1_base)
        half = self.preview_size // 2
        qx0 = 0 if self.active_quad_pos in (0, 2) else half
        qy0 = 0 if self.active_quad_pos in (0, 1) else half
        draw_g1.rectangle([qx0, qy0, qx0 + half - 1, qy0 + half - 1], outline="#FFB74D", width=3)

        tk_g1 = ImageTk.PhotoImage(g1_base)
        self.tk_cache["g1_main"] = tk_g1
        self.canvas_g1.delete("all")
        self.canvas_g1.create_image(self.preview_size // 2, self.preview_size // 2, image=tk_g1)
        self.lbl_g1_id.config(text=f"ID: {self.current_g1_idx}  (0x{self.current_g1_idx:02X})")

        if self.current_g1_idx in self.mapping:
            tgt = self.mapping[self.current_g1_idx]
            self.lbl_g1_status.config(text=f"Status: ✔ Mapped to G2 #{tgt}", foreground="#66BB6A")
        else:
            self.lbl_g1_status.config(text="Status: ⏳ In Progress", foreground="#FFB74D")

        # 3. Quadrant Tabs Styling
        for q in range(4):
            btn = self.quad_tab_buttons[q]
            if q == self.active_quad_pos:
                btn.configure(style="ActiveTab.TButton")
            else:
                btn.configure(style="Nav.TButton")

        # 4. Active Quadrant Candidate Preview (Instant Lookups)
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if not cands:
            cands = [{"g2_id": 0, "src_q": 0, "score": 0.0, "coll": 0x00, "ssim": 0.0, "color": 0.0, "occurrences": []}]
        if self.current_quad_cand_idx >= len(cands):
            self.current_quad_cand_idx = 0

        cur_cand = cands[self.current_quad_cand_idx]

        # Sync active assembled quad choice with current candidate
        self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = dict(cur_cand)

        # For any untouched/unmodified quadrants on this block, also keep them synced with latest Rank #1 learned candidates
        for q in range(4):
            if q != self.active_quad_pos and q not in self.quad_user_modified[self.current_g1_idx]:
                q_top = self.get_ranked_candidates(self.current_g1_idx, q)
                if q_top:
                    self.assembled_quads[self.current_g1_idx][q] = dict(q_top[0])

        q_img = Image.fromarray(cur_cand["img_np"]).resize((self.quad_size, self.quad_size), Image.NEAREST)
        tk_q = ImageTk.PhotoImage(q_img)
        self.tk_cache["active_quad"] = tk_q
        self.canvas_quad_active.delete("all")
        self.canvas_quad_active.create_image(self.quad_size // 2, self.quad_size // 2, image=tk_q)

        if cur_cand.get("is_learned"):
            self.lbl_quad_rank.config(text=f"Candidate #{self.current_quad_cand_idx + 1} of {len(cands)}  🧠 Learned Preference!", foreground="#81C784")
        else:
            self.lbl_quad_rank.config(text=f"Candidate #{self.current_quad_cand_idx + 1} of {len(cands)}", foreground="#FFB74D")

        self.lbl_quad_src.config(text=f"Primary: G2 Block #{cur_cand['g2_id']} ({QUAD_SHORT[cur_cand['src_q']]})")

        occs = cur_cand.get("occurrences", [])
        if len(occs) > 1:
            other_blocks = [f"#{b}({QUAD_SHORT[q]})" for b, q in occs[1:6]]
            extra_count = len(occs) - 6
            extra_txt = f" +{extra_count} more" if extra_count > 0 else ""
            self.lbl_quad_also.config(text=f"Also in: {', '.join(other_blocks)}{extra_txt}")
        else:
            self.lbl_quad_also.config(text="Unique to this block only")

        self.lbl_quad_score.config(text=f"Score: {cur_cand['score']:.3f} (SSIM: {cur_cand.get('ssim', 0):.2f}, Col: {cur_cand.get('color', 0):.2f})")

        coll_val = self.assembled_quads[self.current_g1_idx][self.active_quad_pos]["coll"]
        matched_cbo_idx = 0
        for idx, p in enumerate(COLLISION_PRESETS):
            if p["val"] == coll_val:
                matched_cbo_idx = idx
                break
        self.cbo_collision.current(matched_cbo_idx)

        # 5. Live Assembled Block Preview
        quads = self.assembled_quads[self.current_g1_idx]
        q0_img = quads[0]["img_np"]
        q1_img = quads[1]["img_np"]
        q2_img = quads[2]["img_np"]
        q3_img = quads[3]["img_np"]
        assembled_np = assemble_quadrants_image(q0_img, q1_img, q2_img, q3_img)

        assembled_pil = Image.fromarray(assembled_np).resize((self.preview_size, self.preview_size), Image.NEAREST)
        draw_as = ImageDraw.Draw(assembled_pil)

        half_p = self.preview_size // 2
        draw_as.line([(half_p, 0), (half_p, self.preview_size)], fill="#444856", width=1)
        draw_as.line([(0, half_p), (self.preview_size, half_p)], fill="#444856", width=1)

        coll_str = [f"0x{q['coll']:02X}" for q in quads]
        self.lbl_assembled_coll_summary.config(text=f"Collision: [{', '.join(coll_str)}]")

        if quads[0]["g2_id"] == quads[1]["g2_id"] == quads[2]["g2_id"] == quads[3]["g2_id"] and \
           quads[0]["src_q"] == 0 and quads[1]["src_q"] == 1 and quads[2]["src_q"] == 2 and quads[3]["src_q"] == 3:
            self.lbl_assembled_id.config(text=f"Matches Existing Gen 2 Block #{quads[0]['g2_id']}", foreground="#66BB6A")
        else:
            self.lbl_assembled_id.config(text="✨ Custom Assembled Block (New ID)", foreground="#FFB74D")

        tk_as = ImageTk.PhotoImage(assembled_pil)
        self.tk_cache["assembled_main"] = tk_as
        self.canvas_assembled.delete("all")
        self.canvas_assembled.create_image(self.preview_size // 2, self.preview_size // 2, image=tk_as)

        # 6. Shortlist UI Update
        sl = self.quad_shortlists[self.current_g1_idx][self.active_quad_pos]
        if sl:
            self.lbl_shortlist_status.config(text=f"★ Shortlist for {QUAD_SHORT[self.active_quad_pos]} ({len(sl)} quads) — Press [Enter] to choose or [1-{len(sl)}]:")
        else:
            self.lbl_shortlist_status.config(text=f"★ Shortlist for {QUAD_SHORT[self.active_quad_pos]} is empty — Press [ \\ ] on any guess to shortlist:")

        for s in range(len(self.shortlist_slots)):
            s_obj = self.shortlist_slots[s]
            if s < len(sl):
                cand = sl[s]
                s_img = Image.fromarray(cand["img_np"]).resize((40, 40), Image.NEAREST)
                tk_s = ImageTk.PhotoImage(s_img)
                self.tk_cache[f"sl_{s}"] = tk_s
                s_obj["canvas"].delete("all")
                s_obj["canvas"].create_image(20, 20, image=tk_s)
                s_obj["label"].config(text=f"[{s+1}] #{cand['g2_id']}")
                s_obj["frame"].config(bg="#E65100", bd=2)
                s_obj["cand"] = cand
            else:
                s_obj["canvas"].delete("all")
                s_obj["label"].config(text="--")
                s_obj["frame"].config(bg="#121316", bd=1)
                s_obj["cand"] = None

        # 7. Sliding Window Candidates Thumbnails
        total_cands = len(cands)
        win_start = self.get_window_start(total_cands)
        win_end = min(total_cands, win_start + self.thumb_window_size)
        self.lbl_thumb_title.config(text=f"{QUAD_SHORT[self.active_quad_pos]} Unique Candidates #{win_start + 1} to #{win_end} of {total_cands}:")

        for slot in range(self.thumb_window_size):
            cand_pos = win_start + slot
            t_obj = self.thumb_buttons[slot]
            if cand_pos < total_cands:
                cand = cands[cand_pos]
                t_img = Image.fromarray(cand["img_np"]).resize((self.thumb_size, self.thumb_size), Image.NEAREST)
                tk_t = ImageTk.PhotoImage(t_img)
                self.tk_cache[f"thumb_{slot}"] = tk_t
                t_obj["canvas"].delete("all")
                t_obj["canvas"].create_image(self.thumb_size // 2, self.thumb_size // 2, image=tk_t)

                t_obj["label"].config(text=f"#{cand_pos + 1}: #{cand['g2_id']}({QUAD_SHORT[cand['src_q']]})")
                if cand_pos == self.current_quad_cand_idx:
                    t_obj["frame"].config(bg="#FFB74D", bd=2)
                else:
                    t_obj["frame"].config(bg="#222530", bd=1)
            else:
                t_obj["canvas"].delete("all")
                t_obj["label"].config(text="--")
                t_obj["frame"].config(bg="#181A20", bd=1)

    def get_window_start(self, total_cands):
        half = self.thumb_window_size // 2
        start = max(0, self.current_quad_cand_idx - half)
        if start + self.thumb_window_size > total_cands:
            start = max(0, total_cands - self.thumb_window_size)
        return start

    def select_window_slot(self, slot):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        win_start = self.get_window_start(len(cands))
        target_idx = win_start + slot
        if target_idx < len(cands):
            self.current_quad_cand_idx = target_idx
            self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = dict(cands[target_idx])
            self.quad_user_modified[self.current_g1_idx].add(self.active_quad_pos)
            self.update_view()

    def next_candidate(self):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if cands:
            self.current_quad_cand_idx = (self.current_quad_cand_idx + 1) % len(cands)
            self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = dict(cands[self.current_quad_cand_idx])
            self.quad_user_modified[self.current_g1_idx].add(self.active_quad_pos)
            self.update_view()

    def prev_candidate(self):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if cands:
            self.current_quad_cand_idx = (self.current_quad_cand_idx - 1 + len(cands)) % len(cands)
            self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = dict(cands[self.current_quad_cand_idx])
            self.quad_user_modified[self.current_g1_idx].add(self.active_quad_pos)
            self.update_view()

    def jump_next_8(self):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if cands:
            self.current_quad_cand_idx = min(len(cands) - 1, self.current_quad_cand_idx + 8)
            self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = dict(cands[self.current_quad_cand_idx])
            self.quad_user_modified[self.current_g1_idx].add(self.active_quad_pos)
            self.update_view()

    def jump_prev_8(self):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if cands:
            self.current_quad_cand_idx = max(0, self.current_quad_cand_idx - 8)
            self.assembled_quads[self.current_g1_idx][self.active_quad_pos] = dict(cands[self.current_quad_cand_idx])
            self.quad_user_modified[self.current_g1_idx].add(self.active_quad_pos)
            self.update_view()

    def prev_g1_block(self):
        if self.current_g1_idx > 0:
            self.current_g1_idx -= 1
            self.active_quad_pos = 0
            self.current_quad_cand_idx = 0
            self.update_view()

    def next_g1_block(self):
        if self.current_g1_idx < self.total_g1 - 1:
            self.current_g1_idx += 1
            self.active_quad_pos = 0
            self.current_quad_cand_idx = 0
            self.update_view()

    def save_mapping(self):
        file_path = self.out_path
        if not file_path:
            file_path = filedialog.asksaveasfilename(
                defaultextension=".py",
                filetypes=[("Python Script", "*.py"), ("JSON File", "*.json"), ("Text File", "*.txt")],
                initialfile="SAFARI_G1_TO_G2_mapping.py"
            )
        if not file_path:
            return

        for i in range(self.total_g1):
            if i not in self.mapping:
                self.finalize_block_mapping(i)

        lines = [
            f"# Generated Block Translation Dictionary ({len(self.mapping)} / {self.total_g1} blocks mapped)",
            f"{self.dict_name} = {{"
        ]

        keys = sorted(self.mapping.keys())
        for k in keys:
            v = self.mapping[k]
            lines.append(f"    {k}: {v},")
        lines.append("}\n")

        lines.append("# Custom Assembled Kanto Blocks for restore_kanto_dungeons.py")
        lines.append("CUSTOM_KANTO_BLOCKS_GENERATED = {")
        for cid in sorted(self.custom_blocks.keys()):
            c_info = self.custom_blocks[cid]
            t_str = ", ".join(str(x) for x in c_info["tiles"])
            c_str = ", ".join(f"0x{x:02X}" for x in c_info["collision"])
            lines.append(f"    {cid}: {{")
            lines.append(f'        "tiles": [{t_str}],')
            lines.append(f'        "collision": [{c_str}]')
            lines.append(f"    }}, # Assembled for Gen 1 Block #{c_info.get('source_g1', cid)}")
        lines.append("}\n")

        with open(file_path, "w") as f:
            f.write("\n".join(lines))

        self.auto_save_session()

        json_path = os.path.splitext(file_path)[0] + ".json"
        export_data = {
            "mapping": self.mapping,
            "custom_blocks": self.custom_blocks
        }
        with open(json_path, "w") as f:
            json.dump(export_data, f, indent=2, sort_keys=True)

        messagebox.showinfo("Export Successful", f"Saved {len(self.mapping)} mappings & {len(self.custom_blocks)} custom blocks to:\n{file_path}\n({json_path})")


# =============================================================================
# Pipeline Orchestrator
# =============================================================================

def load_lua_json_optional(lua_path):
    tool_path = os.path.join("tools", "lua_to_json.lua")
    if os.path.exists(tool_path) and os.path.exists(lua_path):
        try:
            proc = subprocess.run(["luajit", tool_path, lua_path], capture_output=True, text=True, check=True)
            return json.loads(proc.stdout)
        except Exception:
            return None
    return None


def run_pipeline(g1_sheet_path, g2_sheet_path, out_file="SAFARI_G1_TO_G2_mapping.py", exclude_buildings=True, dict_name="SAFARI_G1_TO_G2"):
    print("=" * 70)
    print("Phase 1: Slicing, Mt. Moon Wooden Stairs Synthesis & Normalization")
    print("=" * 70)

    is_g1_card = ("gen1_safari_blocks.png" in g1_sheet_path or "forest_blocks_sheet.png" in g1_sheet_path)
    is_g2_card = ("gen2_kanto_blocks.png" in g2_sheet_path or "kanto_all_blocks.png" in g2_sheet_path)

    g1_raw_blocks = slice_sheet(g1_sheet_path, cols=16, is_card_sheet=is_g1_card, max_blocks=128)
    g2_raw_blocks = slice_sheet(g2_sheet_path, cols=16, is_card_sheet=is_g2_card, max_blocks=160)

    # Injects the exact 4-step wooden ladder stairs (from Gen 1 Block 83 / Mt. Moon B2F 24,23) into visual slots #158 and #159
    synthesize_mt_moon_custom_stairs(g1_raw_blocks, g2_raw_blocks)

    print(f"Extracted {len(g1_raw_blocks)} Gen 1 blocks and {len(g2_raw_blocks)} Gen 2 blocks.")
    w1, h1 = g1_raw_blocks[0].size
    w2, h2 = g2_raw_blocks[0].size
    lcm_size = calculate_lcm(w1, w2)
    print(f"Target LCM Size: {lcm_size}x{lcm_size} (Quadrant size: {lcm_size//2}x{lcm_size//2})")

    g1_norm_blocks = normalize_blocks(g1_raw_blocks, lcm_size)
    g2_norm_blocks = normalize_blocks(g2_raw_blocks, lcm_size)

    g2_tiles_raw = []
    g2_coll_raw = []
    gold_ts_path = os.path.expanduser("~/.local/share/love/pokemon-love2d/gold/data/generated/tilesets.lua")
    if os.path.exists(gold_ts_path):
        ts_data = load_lua_json_optional(gold_ts_path)
        if ts_data and "TILESET_KANTO" in ts_data:
            g2_tiles_raw = list(ts_data["TILESET_KANTO"].get("blocks", []))
            g2_coll_raw = list(ts_data["TILESET_KANTO"].get("collision", []))
            try:
                import importlib.util
                kanto_tools_path = os.path.abspath(
                    os.path.join(os.path.dirname(__file__), "..", "mods", "Kanto-Reforged", "tools", "restore_kanto_dungeons.py")
                )
                if os.path.exists(kanto_tools_path):
                    spec = importlib.util.spec_from_file_location("restore_kanto_dungeons", kanto_tools_path)
                    if spec and spec.loader:
                        rkd_mod = importlib.util.module_from_spec(spec)
                        spec.loader.exec_module(rkd_mod)
                        custom_blocks = getattr(rkd_mod, "CUSTOM_KANTO_BLOCKS", {})
                        while len(g2_tiles_raw) <= 165:
                            g2_tiles_raw.append([0] * 16)
                            g2_coll_raw.append([0x07] * 4)
                        for idx, c_def in custom_blocks.items():
                            g2_tiles_raw[idx] = list(c_def["tiles"])
                            g2_coll_raw[idx] = list(c_def["collision"])
            except Exception:
                pass

    print("\n" + "=" * 70)
    print("Phase 2: Deduplication, Building Filter & Multi-Feature Precomputations")
    print("=" * 70)

    g1_np = [np.array(b) for b in g1_norm_blocks]
    g2_np = [np.array(b) for b in g2_norm_blocks]

    unique_quad_pool = build_unique_quadrant_pool(g2_np, g2_coll_raw, exclude_buildings=exclude_buildings)
    filter_status = "Enabled (Clean Nature/Terrain Pool)" if exclude_buildings else "Disabled"
    print(f"Building Exclusion Filter: {filter_status}")
    print(f"Crunched pool size: {len(unique_quad_pool)} unique nature & terrain quadrants.")

    print("Precomputing base 4-quadrant rankings (once at startup)...")
    base_quad_rankings = compute_base_quadrant_rankings(g1_np, unique_quad_pool)
    print("Computing whole-block rankings...")
    block_rankings = compute_all_block_rankings(g1_np, g2_np)
    print("Precomputation complete!")

    print("\n" + "=" * 70)
    print("Phase 3: Launching Fast Zero-Lag GUI with Exact Mt. Moon Wooden Stairs")
    print("=" * 70)

    if tk is None:
        print("Error: Tkinter is required for Phase 3 GUI.")
        return

    session_path = os.path.splitext(out_file)[0] + ".session.json"

    root = tk.Tk()
    app = BlockMapperApp(
        root=root,
        g1_images=g1_norm_blocks,
        g2_images=g2_norm_blocks,
        block_rankings=block_rankings,
        base_quad_rankings=base_quad_rankings,
        unique_quad_pool=unique_quad_pool,
        g2_tiles_raw=g2_tiles_raw,
        g2_coll_raw=g2_coll_raw,
        out_path=out_file,
        session_path=session_path,
        dict_name=dict_name
    )
    root.mainloop()


def resolve_sheet_path(path_str):
    if os.path.exists(path_str):
        return os.path.abspath(path_str)
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(script_dir, "blocksets", path_str),
        os.path.join(script_dir, "blocksets", os.path.basename(path_str)),
        os.path.join(script_dir, path_str),
        os.path.join(script_dir, os.path.basename(path_str)),
        os.path.join(os.getcwd(), path_str),
        os.path.join(os.getcwd(), "blocksets", path_str),
        os.path.join(os.getcwd(), "mods", "Kanto-Reforged", "tools", "blocksets", os.path.basename(path_str)),
        os.path.join(os.getcwd(), "mods", "Kanto-Reforged", "tools", os.path.basename(path_str)),
    ]
    for c in candidates:
        if os.path.exists(c):
            return os.path.abspath(c)
    return None


def main():
    parser = argparse.ArgumentParser(description="Human-in-the-Loop Block ID Translation & Quadrant Assembly Tool")
    parser.add_argument("--g1", default="gen1_safari_blocks.png", help="Path to Gen 1 blockset sheet")
    parser.add_argument("--g2", default="gen2_kanto_blocks.png", help="Path to Gen 2 blockset sheet")
    parser.add_argument("--out", default="safari_g1_to_g2.py", help="Output file path for generated dictionary")
    parser.add_argument("--dict-name", default="SAFARI_G1_TO_G2", help="Python dictionary name in export")
    parser.add_argument("--include-buildings", action="store_true", help="Include building pieces in the quadrant pool (default: excluded)")

    args = parser.parse_args()

    g1_resolved = resolve_sheet_path(args.g1)
    if not g1_resolved:
        print(f"Error: Gen 1 sheet '{args.g1}' not found.")
        sys.exit(1)

    g2_resolved = resolve_sheet_path(args.g2)
    if not g2_resolved:
        print(f"Error: Gen 2 sheet '{args.g2}' not found.")
        sys.exit(1)

    # Output path default resolution
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if not os.path.isabs(args.out):
        out_resolved = os.path.join(script_dir, args.out)
    else:
        out_resolved = args.out

    print(f"Gen 1 Sheet: {g1_resolved}")
    print(f"Gen 2 Sheet: {g2_resolved}")
    print(f"Output File: {out_resolved}")

    run_pipeline(
        g1_sheet_path=g1_resolved,
        g2_sheet_path=g2_resolved,
        out_file=out_resolved,
        exclude_buildings=not args.include_buildings,
        dict_name=args.dict_name
    )


if __name__ == "__main__":
    main()

