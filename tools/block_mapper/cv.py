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
        if exclude_buildings and b_id in GEN2_BUILDING_BLOCKS and b_id not in (120, 121, 158, 159, 160):
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


