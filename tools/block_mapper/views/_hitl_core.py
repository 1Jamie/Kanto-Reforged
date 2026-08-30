#!/usr/bin/env python3
"""HITL block/quad mapper core (extracted from legacy BlockMapperApp)."""

from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageTk

try:
    import tkinter as tk
    from tkinter import ttk, messagebox, filedialog, simpledialog
except ImportError:
    tk = None

_TOOLS_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from block_mapper import cv as cvmod
from block_mapper_profiles.common import COLLISION_COLOR_BY_VAL, COLLISION_PRESETS as _DEFAULT_COLLISION_PRESETS
from tileset_block_rebuild import draw_collision_overlay, render_quad_from_tile_ids

# Profile-driven chrome (set via apply_chrome)
COLLISION_PRESETS = list(_DEFAULT_COLLISION_PRESETS)
GEN1_BUILDING_BLOCKS = set()
GEN1_STAIR_BLOCKS = set()
FEATURE_BAR_TITLE = "Special Features (Click piece to apply & advance):"
BUILDING_DIRECT_DROPINS = []
QUAD_FEATURE_PRESETS = []
WHOLE_BLOCK_DROPINS = []
DEFAULT_FAVORITES = []
QUAD_NAMES = ["Top-Left (TL)", "Top-Right (TR)", "Bottom-Left (BL)", "Bottom-Right (BR)"]
QUAD_SHORT = ["TL", "TR", "BL", "BR"]


def apply_chrome(profile: dict):
    global COLLISION_PRESETS, GEN1_BUILDING_BLOCKS, GEN1_STAIR_BLOCKS, FEATURE_BAR_TITLE
    global BUILDING_DIRECT_DROPINS, QUAD_FEATURE_PRESETS, WHOLE_BLOCK_DROPINS, DEFAULT_FAVORITES
    COLLISION_PRESETS = list(profile.get("collision_presets") or _DEFAULT_COLLISION_PRESETS)
    GEN1_BUILDING_BLOCKS = set(profile.get("gen1_building_blocks") or set())
    GEN1_STAIR_BLOCKS = set(profile.get("gen1_feature_blocks") or set())
    FEATURE_BAR_TITLE = profile.get("feature_bar_title") or "Special Features (Click piece to apply & advance):"
    BUILDING_DIRECT_DROPINS = list(profile.get("building_dropins") or [])
    QUAD_FEATURE_PRESETS = list(profile.get("quad_presets") or [])
    WHOLE_BLOCK_DROPINS = list(profile.get("whole_block_dropins") or [])
    DEFAULT_FAVORITES = list(profile.get("favorites") or [])


def extract_quadrants(img_np):
    return cvmod.extract_quadrants(img_np)


def assemble_quadrants_image(q0, q1, q2, q3):
    return cvmod.assemble_quadrants_image(q0, q1, q2, q3)


def assemble_16_tiles(tl, tr, bl, br):
    return cvmod.assemble_16_tiles(tl, tr, bl, br)

class _HitlMapper:
    def __init__(
        self,
        root,
        g1_images,
        g2_images,
        block_rankings,
        base_quad_rankings,
        unique_quad_pool,
        g2_tiles_raw=None,
        g2_coll_raw=None,
        g2_ts_rec=None,
        g2_sheet_path=None,
        g2_palette_bake=None,
        out_path="SAFARI_G1_TO_G2_mapping.py",
        session_path=None,
        dict_name="SAFARI_G1_TO_G2",
        custom_blocks_name="CUSTOM_KANTO_BLOCKS_GENERATED",
        profile=None,
        test_map=None,
        g1_block_px=32,
        g2_block_px=32,
        **kwargs,
    ):
        self.profile = profile or {}
        self.root = root
        self.ui = kwargs.get("ui_parent") or root
        self.shell = kwargs.get("shell")
        self.session_obj = kwargs.get("session_obj")
        self.on_mapping_changed = kwargs.get("on_mapping_changed")
        # title/geometry owned by BlockMapperShell

        self.g1_images = g1_images
        self.g2_images = g2_images
        self.g1_np = [np.array(b) for b in g1_images]
        self.g2_np = [np.array(b) for b in g2_images]
        self.block_rankings = block_rankings
        self.base_quad_rankings = base_quad_rankings
        self.unique_quad_pool = unique_quad_pool
        self.g2_tiles_raw = g2_tiles_raw or []
        self.g2_coll_raw = g2_coll_raw or []
        self.g2_ts_rec = g2_ts_rec
        self.g2_sheet_path = g2_sheet_path
        self.g2_palette_bake = g2_palette_bake
        self.out_path = out_path
        self.session_path = session_path or (os.path.splitext(out_path)[0] + ".session.json")
        self.dict_name = dict_name
        self.custom_blocks_name = custom_blocks_name
        self.g1_block_px = g1_block_px or 32
        self.g2_block_px = g2_block_px or 32
        self.test_map = test_map
        self.show_collision_overlay = tk.BooleanVar(master=root, value=False)
        self.map_preview_zoom = 1
        self._map_preview_job = None

        self.total_g1 = len(g1_images)
        self.total_g2 = len(g2_images)
        self.total_unique_quads = len(unique_quad_pool)
        self.water_tile_ids = set(self.profile.get("g2_water_tiles") or ())
        self.water_collisions = set(self.profile.get("g2_water_collisions") or (0x29,))

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
        self.coll_color_by_val = {
            p["val"]: p.get("color", "#9E9E9E") for p in COLLISION_PRESETS
        }
        self.coll_color_by_val.update(COLLISION_COLOR_BY_VAL)

        self.g1_quad_keys = [[extract_quadrants(b)[q].tobytes() for q in range(4)] for b in self.g1_np]
        self.quad_user_modified = {i: set() for i in range(self.total_g1)}
        # Per-quad collision locks: once the user sets collision (combobox / favorite
        # with coll / feature preset), it sticks across candidate browsing and
        # update_view refreshes until cleared or overwritten by another explicit set.
        self.quad_coll_lock = {i: {} for i in range(self.total_g1)}

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
        self._apply_prefill_from_export()

        self.build_styles()
        self.build_ui()
        self.bind_events()
        self.update_view()

    def _candidate_tile_key(self, cand):
        if cand.get("tile_key") or cand.get("palette_slot") is not None:
            return cvmod.quad_pool_identity(cand)
        key = cvmod.quad_tile_key(
            self.g2_tiles_raw,
            int(cand.get("g2_id", 0)),
            int(cand.get("src_q", 0)),
        )
        if key is not None:
            return key
        return (
            int(cand.get("g2_id", 0)),
            int(cand.get("src_q", 0)),
        )

    def _quad_tiles_for(self, quad_or_cand):
        export_tile = quad_or_cand.get("export_tile")
        if export_tile is not None:
            t = int(export_tile)
            return [t, t, t, t]
        if quad_or_cand.get("tile_key"):
            return [int(t) for t in quad_or_cand["tile_key"]]
        g2_id = int(quad_or_cand.get("g2_id", 0))
        src_q = int(quad_or_cand.get("src_q", 0))
        if g2_id == 158:
            if src_q in (0, 1):
                return [17, 17, 17, 17]
            return [77, 78, 83, 84]
        if g2_id == 159:
            if src_q in (0, 1):
                return [77, 78, 83, 84]
            return [17, 17, 17, 17]
        if g2_id == 160:
            if src_q == 0:
                return [96, 97, 98, 99]
            return [35, 35, 35, 35]
        if g2_id < len(self.g2_tiles_raw):
            return cvmod.extract_quad_tile_ids(self.g2_tiles_raw[g2_id], src_q)
        return [0, 0, 0, 0]

    def _pool_entry_for(self, g2_id, src_q, tile_key=None, palette_slot=None, export_tile=None):
        g2_id = int(g2_id)
        src_q = int(src_q)
        if tile_key is not None or palette_slot is not None or export_tile is not None:
            want = cvmod.quad_pool_identity(
                {
                    "tile_key": tile_key,
                    "palette_slot": palette_slot,
                    "export_tile": export_tile,
                }
            )
            for u in self.unique_quad_pool:
                if cvmod.quad_pool_identity(u) == want:
                    return u
        for u in self.unique_quad_pool:
            if u.get("g2_id") == g2_id and u.get("src_q") == src_q:
                return u
        key = cvmod.quad_tile_key(self.g2_tiles_raw, g2_id, src_q)
        if key:
            for u in self.unique_quad_pool:
                if tuple(u.get("tile_key") or ()) == key and u.get("palette_slot") is None:
                    return u
        return None

    def _chosen_from_g2_quad(self, g2_id, src_q, coll, tile_key=None, palette_slot=None, export_tile=None):
        pool_u = self._pool_entry_for(
            g2_id,
            src_q,
            tile_key=tile_key,
            palette_slot=palette_slot,
            export_tile=export_tile,
        )
        if pool_u:
            chosen = dict(pool_u)
            chosen["coll"] = int(coll) & 0xFF
            chosen["img_np"] = self._cand_preview_np(chosen)
            chosen["score"] = 1.0
            return chosen
        stub = {"g2_id": int(g2_id), "src_q": int(src_q), "coll": int(coll) & 0xFF}
        if tile_key is not None:
            stub["tile_key"] = tuple(int(t) for t in tile_key)
        if palette_slot is not None:
            stub["palette_slot"] = int(palette_slot)
        if export_tile is not None:
            stub["export_tile"] = int(export_tile)
        stub["img_np"] = self._cand_preview_np(stub)
        stub["score"] = 1.0
        return stub

    def _dedupe_ranked_candidates(self, cands):
        """One row per baked tile quad; keep best score (matches on-screen preview)."""
        best_by_key = {}
        order = []
        for c in cands:
            key = self._candidate_tile_key(c)
            prev = best_by_key.get(key)
            if prev is None or float(c.get("score", 0)) > float(prev.get("score", 0)):
                best_by_key[key] = c
                if prev is None:
                    order.append(key)
        return [best_by_key[k] for k in order]

    def _g1_quad_luma_stats(self, g1_id, q_pos):
        g1q = cvmod.extract_quadrants(self.g1_np[g1_id])[q_pos]
        gray = g1q[:, :, 0] if len(g1q.shape) == 3 else g1q
        return float(np.mean(gray)), float(np.std(gray))

    def _learned_rule_for_quad(self, g1_id, q_pos):
        """Return a validated learned {uid, g2_id, src_q, coll, tile_key?} for this G1 quad pixels."""
        q_key = self.g1_quad_keys[g1_id][q_pos]
        raw = self.learned_memory.get(q_key)
        if raw is None:
            return None
        if isinstance(raw, int):
            rule = {"uid": int(raw), "g2_id": 0, "src_q": 0, "coll": 0x00}
        else:
            rule = {
                "g2_id": int(raw.get("g2_id", 0)),
                "src_q": int(raw.get("src_q", 0)),
                "coll": int(raw.get("coll", 0x00)) & 0xFF,
            }
            if raw.get("uid") is not None:
                rule["uid"] = int(raw["uid"])
            if raw.get("tile_key"):
                rule["tile_key"] = [int(t) for t in raw["tile_key"]]
            if raw.get("palette_slot") is not None:
                rule["palette_slot"] = int(raw["palette_slot"])
            if raw.get("export_tile") is not None:
                rule["export_tile"] = int(raw["export_tile"])

        # User-taught rules carry tile_key — trust them over CV luma gates (e.g. t22
        # wall for fuzzy G1 dither reads ~23 lum units off but is intentional).
        if isinstance(raw, dict) and rule.get("tile_key"):
            return rule

        g1_mean, g1_std = self._g1_quad_luma_stats(g1_id, q_pos)
        match_item = None
        uid = rule.get("uid")
        for item in self.base_quad_rankings[g1_id][q_pos]:
            if uid is not None and item.get("uid") == uid:
                match_item = item
                break
            if rule.get("g2_id") == item.get("g2_id") and rule.get("src_q") == item.get("src_q"):
                match_item = item
                if uid is None and item.get("uid") is not None:
                    rule["uid"] = int(item["uid"])
                break

        if match_item is not None and match_item.get("img_np") is not None:
            cand_mean = float(np.mean(match_item["img_np"]))
            if abs(g1_mean - cand_mean) > 22.0:
                return None
            if g1_std < cvmod.TEXTURED_QUAD_STD:
                ident = cvmod.quad_pool_identity(match_item)
                wrong_floor = (
                    (g1_mean < 68 and ident == cvmod.FLAT_CAVE_FLOOR_LIGHT)
                    or (g1_mean >= 68 and ident == cvmod.FLAT_CAVE_FLOOR_DARK)
                )
                if wrong_floor:
                    return None
        elif not rule.get("g2_id") and uid is None:
            return None
        return rule

    def _chosen_from_learned_rule(self, g1_id, q_pos, rule):
        coll = int(rule.get("coll", 0x00)) & 0xFF
        tile_key = rule.get("tile_key")
        return self._chosen_from_g2_quad(
            int(rule.get("g2_id", 0)),
            int(rule.get("src_q", 0)),
            coll,
            tile_key=tuple(tile_key) if tile_key else None,
            palette_slot=rule.get("palette_slot"),
            export_tile=rule.get("export_tile"),
        )

    def _save_learned_rule(self, g1_id, q_pos, chosen_cand, *, coll=None):
        """Remember tile + collision for this exact G1 quad pixel pattern (all blocks)."""
        q_key = self.g1_quad_keys[g1_id][q_pos]
        if coll is None:
            coll = self.quad_coll_lock[g1_id].get(q_pos, chosen_cand.get("coll", 0x00))
        rule = {
            "g2_id": int(chosen_cand.get("g2_id", 0)),
            "src_q": int(chosen_cand.get("src_q", 0)),
            "coll": int(coll) & 0xFF,
        }
        uid = chosen_cand.get("uid")
        if uid is not None:
            rule["uid"] = int(uid)
        if chosen_cand.get("tile_key"):
            rule["tile_key"] = [int(t) for t in chosen_cand["tile_key"]]
        if chosen_cand.get("palette_slot") is not None:
            rule["palette_slot"] = int(chosen_cand["palette_slot"])
        if chosen_cand.get("export_tile") is not None:
            rule["export_tile"] = int(chosen_cand["export_tile"])
        self.learned_memory[q_key] = rule

    def _ensure_learned_present(self, cands, g1_id, q_pos):
        """Keep the learned mapping at rank #1 even when dedupe dropped its uid row."""
        rule = self._learned_rule_for_quad(g1_id, q_pos)
        if not rule:
            return cands
        learned = self._chosen_from_learned_rule(g1_id, q_pos, rule)
        learned["is_learned"] = True
        learned["score"] = float(learned.get("score", 1.0)) + 3.0
        rest = [
            c
            for c in cands
            if not (
                c.get("g2_id") == learned.get("g2_id")
                and c.get("src_q") == learned.get("src_q")
            )
        ]
        return [learned] + rest

    def _ensure_flat_floors_present(self, cands, g1_id, q_pos):
        """Guarantee light/dark t1 floor quads are always in the browse list."""
        if self.profile.get("id") != "cavern_cave":
            return cands
        present = {self._candidate_tile_key(c) for c in cands}
        prepend = []
        for fk in cvmod.FLAT_CAVE_FLOOR_IDENTITIES:
            if fk in present:
                continue
            for u in self.unique_quad_pool:
                if cvmod.quad_pool_identity(u) == fk:
                    entry = dict(u)
                    for c in self.base_quad_rankings[g1_id][q_pos]:
                        if c.get("uid") == u.get("uid"):
                            for key in ("base_score", "ssim", "edge", "color", "pixel"):
                                if key in c:
                                    entry[key] = c[key]
                            break
                    entry.setdefault("base_score", 0.0)
                    entry.setdefault("score", entry["base_score"])
                    entry.setdefault("ssim", 0.0)
                    entry.setdefault("color", 0.0)
                    entry.setdefault("pixel", entry.get("ssim", 0.0))
                    prepend.append(entry)
                    present.add(fk)
                    break
        if not prepend:
            return cands
        tail = [c for c in cands if self._candidate_tile_key(c) not in {self._candidate_tile_key(p) for p in prepend}]
        return prepend + tail

    def _pin_flat_cave_floors(self, cands, g1_id, q_pos):
        if self.profile.get("id") != "cavern_cave" or not cands:
            return cands
        g1_mean, g1_std = self._g1_quad_luma_stats(g1_id, q_pos)
        if g1_std > cvmod.TEXTURED_QUAD_STD:
            return cands
        floor_keys = sorted(
            cvmod.FLAT_CAVE_FLOOR_IDENTITIES,
            key=lambda fk: abs(cvmod.FLAT_CAVE_FLOOR_LUMA.get(fk, g1_mean) - g1_mean),
        )
        pinned = []
        rest = list(cands)
        for fk in floor_keys:
            for idx, cand in enumerate(rest):
                if self._candidate_tile_key(cand) == fk:
                    pinned.append(rest.pop(idx))
                    break
        if not pinned:
            return cands
        seen = {self._candidate_tile_key(c) for c in pinned}
        tail = [c for c in rest if self._candidate_tile_key(c) not in seen]
        return pinned + tail

    def get_ranked_candidates(self, g1_id, q_pos):
        base_list = self.base_quad_rankings[g1_id][q_pos]
        learned_rule = self._learned_rule_for_quad(g1_id, q_pos)
        learned_uid = learned_rule.get("uid") if learned_rule else None

        if learned_uid is None and learned_rule is None:
            sorted_cands = sorted(base_list, key=lambda x: x["base_score"], reverse=True)
            res = []
            for c in sorted_cands:
                item = dict(c)
                item["score"] = item["base_score"]
                item["is_learned"] = False
                if self._candidate_has_hidden_water(item):
                    item["has_water_tiles"] = True
                    item["score"] -= 2.0
                else:
                    item["has_water_tiles"] = False
                res.append(item)
            res.sort(key=lambda x: x["score"], reverse=True)
            out = self._pin_flat_cave_floors(self._dedupe_ranked_candidates(res), g1_id, q_pos)
            out = self._ensure_flat_floors_present(out, g1_id, q_pos)
            return self._ensure_learned_present(out, g1_id, q_pos)

        cands = []
        for item in base_list:
            c = dict(item)
            learned_hit = learned_rule and (
                (learned_uid is not None and c.get("uid") == learned_uid)
                or (
                    c.get("g2_id") == learned_rule.get("g2_id")
                    and c.get("src_q") == learned_rule.get("src_q")
                )
            )
            if learned_hit:
                c["score"] = c["base_score"] + 2.0
                c["is_learned"] = True
            else:
                c["score"] = c["base_score"]
                c["is_learned"] = False
            if self._candidate_has_hidden_water(c):
                c["has_water_tiles"] = True
                c["score"] -= 2.0
            else:
                c["has_water_tiles"] = False
            cands.append(c)

        cands.sort(key=lambda x: x["score"], reverse=True)
        out = self._pin_flat_cave_floors(self._dedupe_ranked_candidates(cands), g1_id, q_pos)
        out = self._ensure_flat_floors_present(out, g1_id, q_pos)
        return self._ensure_learned_present(out, g1_id, q_pos)

    def _candidate_has_hidden_water(self, cand, coll=None):
        if not self.water_tile_ids:
            return False
        coll = self.water_collisions if coll is None else coll
        if int(cand.get("coll", 0)) & 0xFF in coll:
            return False
        tiles = self._quad_tiles_for(cand)
        return any(int(t) in self.water_tile_ids for t in tiles)

    def _serialize_assembled_quads(self):
        out = {}
        for g1, quads in self.assembled_quads.items():
            out[str(g1)] = [
                {
                    "g2_id": int(q.get("g2_id", 0)),
                    "src_q": int(q.get("src_q", 0)),
                    "coll": int(q.get("coll", 0)) & 0xFF,
                    "uid": q.get("uid"),
                    **(
                        {"tile_key": [int(t) for t in q["tile_key"]]}
                        if q.get("tile_key")
                        else {}
                    ),
                    **(
                        {"palette_slot": int(q["palette_slot"])}
                        if q.get("palette_slot") is not None
                        else {}
                    ),
                    **(
                        {"export_tile": int(q["export_tile"])}
                        if q.get("export_tile") is not None
                        else {}
                    ),
                }
                for q in quads
            ]
        return out

    def _restore_assembled_quads(self, data):
        if not isinstance(data, dict):
            return
        for g1s, quads in data.items():
            try:
                g1 = int(g1s)
            except (TypeError, ValueError):
                continue
            if g1 < 0 or g1 >= self.total_g1 or not isinstance(quads, list) or len(quads) != 4:
                continue
            restored = []
            for q in quads:
                if not isinstance(q, dict):
                    break
                entry = {
                    "g2_id": int(q.get("g2_id", 0)),
                    "src_q": int(q.get("src_q", 0)),
                    "coll": int(q.get("coll", 0)) & 0xFF,
                    "uid": q.get("uid"),
                    "score": 1.0,
                }
                if q.get("tile_key"):
                    entry["tile_key"] = tuple(int(t) for t in q["tile_key"])
                if q.get("palette_slot") is not None:
                    entry["palette_slot"] = int(q["palette_slot"])
                if q.get("export_tile") is not None:
                    entry["export_tile"] = int(q["export_tile"])
                if entry["uid"] is not None:
                    try:
                        entry["uid"] = int(entry["uid"])
                    except (TypeError, ValueError):
                        entry["uid"] = None
                restored.append(entry)
            if len(restored) == 4:
                self.assembled_quads[g1] = [self._hydrate_quad_entry(q) for q in restored]

    def _hydrate_quad_entry(self, entry):
        """Ensure a quadrant dict has img_np (session JSON omits it)."""
        out = dict(entry)
        uid = out.get("uid")
        if uid is not None:
            for u in self.unique_quad_pool:
                if u.get("uid") != uid:
                    continue
                out["g2_id"] = int(u["g2_id"])
                out["src_q"] = int(u["src_q"])
                if u.get("tile_key") and not out.get("tile_key"):
                    out["tile_key"] = tuple(int(t) for t in u["tile_key"])
                if u.get("palette_slot") is not None and out.get("palette_slot") is None:
                    out["palette_slot"] = int(u["palette_slot"])
                if u.get("export_tile") is not None and out.get("export_tile") is None:
                    out["export_tile"] = int(u["export_tile"])
                if u.get("occurrences"):
                    out["occurrences"] = list(u["occurrences"])
                break
        img = out.get("img_np")
        if img is None:
            out["img_np"] = self._cand_preview_np(out)
        return out

    def _resolve_quad_assembly(self, g1_id, q_pos):
        """Pick assembled quad: user pin > learned rule > CV rank #1."""
        if q_pos in self.quad_user_modified[g1_id]:
            return self._hydrate_quad_entry(
                self.apply_locked_collision(g1_id, q_pos, self.assembled_quads[g1_id][q_pos])
            )
        learned_rule = self._learned_rule_for_quad(g1_id, q_pos)
        if learned_rule:
            if learned_rule.get("coll") is not None:
                self.lock_quad_collision(g1_id, q_pos, learned_rule["coll"])
            chosen = self._chosen_from_learned_rule(g1_id, q_pos, learned_rule)
            return self._hydrate_quad_entry(
                self.apply_locked_collision(g1_id, q_pos, chosen)
            )
        cands = self.get_ranked_candidates(g1_id, q_pos)
        if cands:
            return self._hydrate_quad_entry(
                self.apply_locked_collision(g1_id, q_pos, cands[0])
            )
        return self._hydrate_quad_entry(self.assembled_quads[g1_id][q_pos])

    def record_learned_choice(self, g1_id, q_pos, chosen_cand):
        self._save_learned_rule(g1_id, q_pos, chosen_cand)
        self.quad_user_modified[g1_id].add(q_pos)
        self.auto_save_session()

    def lock_quad_collision(self, g1_id, q_pos, coll):
        """Pin collision for a quadrant so refreshes / candidate swaps cannot wipe it."""
        self.quad_coll_lock[g1_id][q_pos] = int(coll) & 0xFF
        # Do NOT mark user_modified here — that freezes the piece graphic.
        # Collision lock alone is enough to survive candidate browsing.

    def apply_locked_collision(self, g1_id, q_pos, chosen):
        """Return a copy of chosen with locked collision applied when present."""
        out = dict(chosen)
        locked = self.quad_coll_lock[g1_id].get(q_pos)
        if locked is not None:
            out["coll"] = locked
        return out

    def find_cand_index(self, cands, chosen):
        """Index of chosen in the ranked list for thumb highlight sync.

        Match uid or (g2_id, src_q) only — not bare tile_key, because deduped
        candidates collapse many blocks onto one row and would highlight the
        wrong block while the pinned preview shows another source block.
        """
        if not cands or not chosen:
            return None
        uid = chosen.get("uid")
        g2 = chosen.get("g2_id")
        sq = chosen.get("src_q")
        if uid is not None:
            for i, c in enumerate(cands):
                if c.get("uid") != uid:
                    continue
                if g2 is not None and sq is not None:
                    if c.get("g2_id") == g2 and c.get("src_q") == sq:
                        return i
                else:
                    return i
        if g2 is not None and sq is not None:
            for i, c in enumerate(cands):
                if c.get("g2_id") == g2 and c.get("src_q") == sq:
                    return i
        return None

    def set_assembled_quad(self, g1_id, q_pos, chosen, *, lock_coll=False):
        """Install a quadrant choice; optionally lock its collision as authoritative."""
        chosen = dict(chosen)
        if lock_coll:
            self.lock_quad_collision(g1_id, q_pos, chosen.get("coll", 0x00))
        else:
            chosen = self.apply_locked_collision(g1_id, q_pos, chosen)
            self.quad_user_modified[g1_id].add(q_pos)
        self.assembled_quads[g1_id][q_pos] = self._hydrate_quad_entry(chosen)

    def browse_candidate_to(self, idx):
        """Move the candidate cursor. Does not learn / freeze — preview follows idx."""
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if not cands:
            return
        self.current_quad_cand_idx = idx % len(cands)
        # Leave piece-sticky so update_view syncs graphics from the cursor again.
        # Collision locks (if any) still apply on top.
        self.quad_user_modified[self.current_g1_idx].discard(self.active_quad_pos)
        self.update_view()

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

    def _apply_prefill_from_export(self):
        """Seed simple 1:1 mappings from an existing export (e.g. cave → legend regi)."""
        spec = self.profile.get("prefill_from")
        if not spec:
            return
        if isinstance(spec, (list, tuple)):
            if len(spec) < 2:
                return
            module_stem, dict_name = spec[0], spec[1]
            custom_name = spec[2] if len(spec) > 2 else None
        else:
            return
        tools_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        path = os.path.join(tools_dir, f"{module_stem}.py")
        if not os.path.isfile(path):
            print(f"[block_mapper] prefill export not found: {path}")
            return
        try:
            import importlib.util

            spec_mod = importlib.util.spec_from_file_location(module_stem, path)
            if not spec_mod or not spec_mod.loader:
                return
            mod = importlib.util.module_from_spec(spec_mod)
            spec_mod.loader.exec_module(mod)
            exported = getattr(mod, dict_name, None) or {}
            custom = getattr(mod, custom_name, None) if custom_name else None
            for g1_id, g2_id in exported.items():
                g1 = int(g1_id)
                if g1 >= self.total_g1 or g1 in self.mapping:
                    continue
                self.mapping[g1] = int(g2_id)
            if isinstance(custom, dict):
                for cid, info in custom.items():
                    self.custom_blocks[int(cid)] = dict(info)
            print(f"[block_mapper] Prefilled {len(self.mapping)} mappings from {module_stem}")
        except Exception as exc:  # noqa: BLE001
            print(f"[block_mapper] prefill failed: {exc}")

    def _sanitize_restored_pin_state(self):
        """Drop pin flags where assembled matches rank #1 (session restore used to pin all four)."""
        for g1 in range(self.total_g1):
            pinned = self.quad_user_modified.get(g1)
            if not pinned:
                continue
            for q in list(pinned):
                cands = self.get_ranked_candidates(g1, q)
                if not cands:
                    continue
                assembled = self._hydrate_quad_entry(self.assembled_quads[g1][q])
                top = cands[0]
                same_tiles = self._candidate_tile_key(assembled) == self._candidate_tile_key(top)
                same_src = (
                    assembled.get("g2_id") == top.get("g2_id")
                    and assembled.get("src_q") == top.get("src_q")
                )
                if same_tiles and same_src:
                    pinned.discard(q)

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
                        pool_len = len(self.unique_quad_pool)
                        loaded_rules = {}
                        for k, v in data["learned_memory"].items():
                            try:
                                q_key = bytes.fromhex(k)
                            except ValueError:
                                continue
                            if isinstance(v, int):
                                if v < pool_len:
                                    loaded_rules[q_key] = {"uid": int(v), "g2_id": 0, "src_q": 0, "coll": 0x00}
                            elif isinstance(v, dict):
                                uid = v.get("uid")
                                if uid is not None and int(uid) >= pool_len:
                                    continue
                                rule = {
                                    "g2_id": int(v.get("g2_id", 0)),
                                    "src_q": int(v.get("src_q", 0)),
                                    "coll": int(v.get("coll", 0x00)) & 0xFF,
                                }
                                if uid is not None:
                                    rule["uid"] = int(uid)
                                if v.get("tile_key"):
                                    rule["tile_key"] = [int(t) for t in v["tile_key"]]
                                if v.get("palette_slot") is not None:
                                    rule["palette_slot"] = int(v["palette_slot"])
                                if v.get("export_tile") is not None:
                                    rule["export_tile"] = int(v["export_tile"])
                                loaded_rules[q_key] = rule
                        self.learned_memory = loaded_rules
                    if "last_g1_idx" in data:
                        self.current_g1_idx = min(self.total_g1 - 1, data["last_g1_idx"])
                    if "quad_coll_lock" in data:
                        for gk, locks in data["quad_coll_lock"].items():
                            g1 = int(gk)
                            if g1 in self.quad_coll_lock:
                                self.quad_coll_lock[g1] = {int(q): int(c) & 0xFF for q, c in locks.items()}
                                # Collision locks alone — do not freeze piece graphics.
                    if "quad_user_modified" in data:
                        for gk, qs in data["quad_user_modified"].items():
                            g1 = int(gk)
                            if g1 in self.quad_user_modified:
                                self.quad_user_modified[g1] = {int(q) for q in qs}
                    if "assembled_quads" in data:
                        self._restore_assembled_quads(data["assembled_quads"])
                    self._sanitize_restored_pin_state()
                    for i in range(self.total_g1):
                        if i not in self.mapping:
                            self.current_g1_idx = i
                            break
                    self.current_quad_cand_idx = 0
                    cands = self.get_ranked_candidates(
                        self.current_g1_idx, self.active_quad_pos
                    )
                    if self.active_quad_pos in self.quad_user_modified[self.current_g1_idx]:
                        sync_idx = self.find_cand_index(
                            cands,
                            self.assembled_quads[self.current_g1_idx][self.active_quad_pos],
                        )
                        if sync_idx is not None:
                            self.current_quad_cand_idx = sync_idx
                    # Re-apply locks onto current assembled defaults
                    for g1, locks in self.quad_coll_lock.items():
                        for q, coll in locks.items():
                            if g1 < len(self.assembled_quads) and q < 4:
                                self.assembled_quads[g1][q] = dict(self.assembled_quads[g1][q])
                                self.assembled_quads[g1][q]["coll"] = coll
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
                "learned_memory": {k.hex(): v for k, v in self.learned_memory.items()},
                "quad_coll_lock": {
                    str(g1): {str(q): c for q, c in locks.items()}
                    for g1, locks in self.quad_coll_lock.items()
                    if locks
                },
                "assembled_quads": self._serialize_assembled_quads(),
                "quad_user_modified": {
                    str(g1): sorted(qs) for g1, qs in self.quad_user_modified.items() if qs
                },
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
        top_frame = ttk.Frame(self.ui)
        top_frame.pack(fill="x", padx=16, pady=(10, 3))

        self.lbl_progress = ttk.Label(top_frame, text="Progress: 0 / 0", style="Header.TLabel")
        self.lbl_progress.pack(side="left")

        self.progress_bar = ttk.Progressbar(top_frame, orient="horizontal", length=200, mode="determinate")
        self.progress_bar.pack(side="left", padx=8)

        pal_env = self.profile.get("g2_palette_env") or "?"
        pal_time = self.profile.get("g2_palette_daytime") or "DAY"
        self.lbl_unique_badge = ttk.Label(
            top_frame,
            text=f"{self.total_unique_quads} Unique Quads | profile={self.profile.get('id', '?')} | bake={pal_env}/{pal_time}",
            font=("Helvetica", 9, "bold"),
            foreground="#A5D6A7",
        )
        self.lbl_unique_badge.pack(side="left", padx=4)

        self.lbl_learned_badge = ttk.Label(top_frame, text="0 Rules Learned", font=("Helvetica", 9, "bold"), foreground="#FFD54F")
        self.lbl_learned_badge.pack(side="left", padx=4)

        ttk.Checkbutton(
            top_frame,
            text="Collision Overlay [C]",
            variable=self.show_collision_overlay,
            command=self.on_collision_overlay_toggled,
        ).pack(side="left", padx=8)

        ttk.Button(top_frame, text="Jump [J]", style="Nav.TButton", command=self.prompt_jump_to_g2_block).pack(side="left", padx=4)
        ttk.Button(top_frame, text="Load Session", style="Nav.TButton", command=self.prompt_load_session).pack(side="left", padx=4)

        self.run_restore_after_export = tk.BooleanVar(master=self.root, value=False)
        ttk.Checkbutton(
            top_frame,
            text="Run restore after export",
            variable=self.run_restore_after_export,
        ).pack(side="right", padx=8)

        btn_save = ttk.Button(top_frame, text="Export (Ctrl+S)", style="Nav.TButton", command=self.save_mapping)
        btn_save.pack(side="right")

        # 2. ⭐ Quick Favorites Palette (F1–F8)
        # Must parent under self.ui (MapperView), not the Tk root — otherwise shell
        # re-runs leave orphan strips on root that never receive update_view().
        fav_bar = ttk.Frame(self.ui, style="Fav.TFrame", padding=4)
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
        self.building_bar = ttk.Frame(self.ui, style="Building.TFrame", padding=4)
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

        self.special_bar = ttk.Frame(self.ui, style="Special.TFrame", padding=4)
        sb_header = ttk.Frame(self.special_bar, style="Special.TFrame")
        sb_header.pack(fill="x")
        self.lbl_special_notice = ttk.Label(sb_header, text=FEATURE_BAR_TITLE, style="SpecialHeader.TLabel")
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

            def make_qdrop_action(
                gid=q_drop["g2_id"],
                sq=q_drop["src_q"],
                col=q_drop["coll"],
                tkey=q_drop.get("tile_key"),
                pslot=q_drop.get("palette_slot"),
                etile=q_drop.get("export_tile"),
            ):
                return lambda e: self.apply_quad_feature_preset(
                    gid,
                    sq,
                    col,
                    tile_key=tkey,
                    palette_slot=pslot,
                    export_tile=etile,
                )

            qf.bind("<Button-1>", make_qdrop_action())
            qc.bind("<Button-1>", make_qdrop_action())
            ql.bind("<Button-1>", make_qdrop_action())

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
        workspace = ttk.Frame(self.ui)
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

        ttk.Label(coll_box, text="Quadrant Collision (locks on change — survives candidate swaps):", font=("Helvetica", 10, "bold"), foreground="#FFD54F", background="#222530").pack(anchor="w")
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
        self.shortlist_frame = ttk.Frame(self.ui, style="Shortlist.TFrame", padding=4)
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
        self.thumb_bar = ttk.Frame(self.ui, style="Card.TFrame", padding=4)
        self.thumb_bar.pack(fill="x", padx=16, pady=2)

        th_header = ttk.Frame(self.thumb_bar, style="Card.TFrame")
        th_header.pack(fill="x")
        self.lbl_thumb_title = ttk.Label(th_header, text="Unique Candidate Window (Click to preview):", style="CardSub.TLabel")
        self.lbl_thumb_title.pack(side="left", padx=4)

        th_nav = ttk.Frame(th_header, style="Card.TFrame")
        th_nav.pack(side="right")
        ttk.Button(th_nav, text="◀ Prev 8", style="Nav.TButton", command=self.jump_prev_8).pack(side="left", padx=2)
        ttk.Button(th_nav, text="Next 8 ▶", style="Nav.TButton", command=self.jump_next_8).pack(side="left", padx=2)
        ttk.Button(th_nav, text="⏮ First", style="Nav.TButton", command=self.jump_first_candidate).pack(side="left", padx=2)

        self.thumb_container = ttk.Frame(self.thumb_bar, style="Card.TFrame")
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
        bot_bar = ttk.Frame(self.ui)
        bot_bar.pack(fill="x", padx=16, pady=(4, 10))

        ttk.Button(bot_bar, text="◀ Prev Block [P]", style="Nav.TButton", command=self.prev_g1_block).pack(side="left", padx=4)
        ttk.Button(bot_bar, text="Skip Block [N]", style="Nav.TButton", command=self.next_g1_block).pack(side="left", padx=4)

        self.btn_approve = ttk.Button(bot_bar, text="✔ Next Quad / Confirm [Enter]", style="Approve.TButton", padding=(20, 8), command=self.handle_enter_action)
        self.btn_approve.pack(side="right", padx=6)

        ttk.Button(bot_bar, text="Next Quad [Tab]", style="Nav.TButton", padding=(10, 8), command=self.next_quad_tab).pack(side="right", padx=4)

        # 8. Live Map Preview (Gen1 | Gen2 projection)
        self.build_map_preview_ui()

    def build_map_preview_ui(self):
        strip = ttk.Frame(self.ui, style="Card.TFrame", padding=4)
        strip.pack(fill="x", padx=16, pady=(0, 8))
        map_label = "none"
        if self.test_map:
            map_label = f"{self.test_map.get('map_id')} ({self.test_map.get('width')}x{self.test_map.get('height')})"
        ttk.Label(strip, text=f"Map context: {map_label}", style="CardSub.TLabel").pack(side="left", padx=4)
        ttk.Button(strip, text="Open Map Preview [M]", style="Nav.TButton",
                   command=lambda: self.shell.show_mode("preview") if self.shell else None).pack(side="right", padx=4)
        self._preview_strip = strip

    def on_collision_overlay_toggled(self):

        self.update_view()

    def adjust_map_zoom(self, delta):
        self.map_preview_zoom = max(1, min(4, self.map_preview_zoom + delta))
        self.schedule_map_preview_refresh()

    def schedule_map_preview_refresh(self):
        if self.on_mapping_changed:
            if self._map_preview_job is not None:
                try:
                    self.root.after_cancel(self._map_preview_job)
                except Exception:
                    pass
            self._map_preview_job = self.root.after(40, self.on_mapping_changed)

    def render_block_from_tile_ids(self, tiles16):
        """Bake export-accurate block art from 16 tile indices (what the game loads)."""
        from tileset_block_rebuild import render_block_from_tile_ids

        if not (self.g2_ts_rec and self.g2_sheet_path):
            return Image.new("RGB", (self.g2_block_px, self.g2_block_px), (32, 32, 32))
        return render_block_from_tile_ids(
            list(tiles16)[:16],
            self.g2_ts_rec,
            self.g2_sheet_path,
            block_px=self.g2_block_px,
            tile_size=int(self.profile.get("g2_tile_size") or 8),
            palette_bake=self.g2_palette_bake,
            game=self.profile.get("g2_game") or self.profile.get("game") or "gold",
        )

    def resolve_g2_block_image(self, g2_id):
        if g2_id in self.custom_blocks:
            cdef = self.custom_blocks[g2_id]
            tiles = cdef.get("tiles")
            if tiles and len(tiles) >= 16:
                return self.render_block_from_tile_ids(tiles)
            # In-progress block: fall back to quadrant thumbnails
            src = cdef.get("source_g1")
            if src is not None and src in self.assembled_quads:
                quads = [self._hydrate_quad_entry(q) for q in self.assembled_quads[src]]
                try:
                    assembled = assemble_quadrants_image(
                        quads[0]["img_np"], quads[1]["img_np"], quads[2]["img_np"], quads[3]["img_np"]
                    )
                    return Image.fromarray(assembled)
                except Exception:
                    pass
        if 0 <= g2_id < len(self.g2_images):
            return self.g2_images[g2_id]
        return Image.new("RGB", (self.g2_block_px, self.g2_block_px), (20, 20, 20))

    def resolve_g2_collision(self, g2_id):
        if g2_id in self.custom_blocks:
            return list(self.custom_blocks[g2_id].get("collision") or [0, 0, 0, 0])
        if g2_id < len(self.g2_coll_raw):
            return list(self.g2_coll_raw[g2_id])
        return [0x00, 0x00, 0x00, 0x00]

    def projected_g2_id_for_g1(self, g1_id):
        if g1_id in self.mapping:
            return self.mapping[g1_id]
        # Live preview of in-progress assembly for the current block
        if g1_id == self.current_g1_idx and g1_id in self.assembled_quads:
            quads = self.assembled_quads[g1_id]
            if (
                quads[0]["g2_id"] == quads[1]["g2_id"] == quads[2]["g2_id"] == quads[3]["g2_id"]
                and quads[0]["src_q"] == 0
                and quads[1]["src_q"] == 1
                and quads[2]["src_q"] == 2
                and quads[3]["src_q"] == 3
            ):
                return quads[0]["g2_id"]
            # Synthetic preview id — render from assembled quads
            return -1 - g1_id
        return None

    def render_map_image(self, side="g1"):
        if not self.test_map:
            return None
        width = int(self.test_map["width"])
        height = int(self.test_map["height"])
        blocks = self.test_map["blocks"]
        cell = max(4, 8 * self.map_preview_zoom)
        img = Image.new("RGB", (width * cell, height * cell), (16, 16, 20))
        highlight = self.current_g1_idx

        for y in range(height):
            for x in range(width):
                idx = y * width + x
                if idx >= len(blocks):
                    break
                g1_id = int(blocks[idx])
                if side == "g1":
                    src = self.g1_images[g1_id] if 0 <= g1_id < len(self.g1_images) else Image.new("RGB", (cell, cell), (40, 0, 0))
                    tile = src.resize((cell, cell), Image.NEAREST)
                else:
                    g2_id = self.projected_g2_id_for_g1(g1_id)
                    if g2_id is None:
                        tile = Image.new("RGB", (cell, cell), (30, 30, 36))
                    elif g2_id < 0:
                        # In-progress assembled preview
                        src_g1 = -1 - g2_id
                        quads = self.assembled_quads.get(src_g1)
                        if quads:
                            quads = [self._hydrate_quad_entry(q) for q in quads]
                            assembled = assemble_quadrants_image(
                                quads[0]["img_np"], quads[1]["img_np"], quads[2]["img_np"], quads[3]["img_np"]
                            )
                            tile = Image.fromarray(assembled).resize((cell, cell), Image.NEAREST)
                            if self.show_collision_overlay.get():
                                coll = [q.get("coll", 0) for q in quads]
                                tile = draw_collision_overlay(tile, coll, self.coll_color_by_val, alpha=100)
                        else:
                            tile = Image.new("RGB", (cell, cell), (50, 40, 20))
                    else:
                        src = self.resolve_g2_block_image(g2_id)
                        tile = src.resize((cell, cell), Image.NEAREST)
                        if self.show_collision_overlay.get():
                            tile = draw_collision_overlay(
                                tile, self.resolve_g2_collision(g2_id), self.coll_color_by_val, alpha=100
                            )
                if g1_id == highlight:
                    draw = ImageDraw.Draw(tile)
                    draw.rectangle([0, 0, cell - 1, cell - 1], outline="#FFB74D", width=max(1, cell // 8))
                img.paste(tile, (x * cell, y * cell))
        return img

    def refresh_map_preview(self):
        self._map_preview_job = None
        if self.on_mapping_changed:
            self.on_mapping_changed()

    def on_map_preview_click(self, event, side="g1"):
        return  # Full preview lives in PreviewView


    def _notify_dirty(self):
        if self.session_obj:
            self.session_obj.mapping = self.mapping
            self.session_obj.custom_blocks = self.custom_blocks
            self.session_obj.mark_dirty(True)
        if self.on_mapping_changed:
            self.on_mapping_changed()

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
        self.root.bind("c", lambda e: self.toggle_collision_overlay_key())
        self.root.bind("C", lambda e: self.toggle_collision_overlay_key())
        self.root.bind("<Control-s>", lambda e: self.save_mapping())
        self.root.bind("<Control-S>", lambda e: self.save_mapping())

        for f_idx in range(8):
            fn_key = f"<F{f_idx + 1}>"
            alt_key = f"<Alt-Key-{f_idx + 1}>"
            self.root.bind(fn_key, lambda e, s=f_idx: self.apply_favorite_slot(s))
            self.root.bind(alt_key, lambda e, s=f_idx: self.apply_favorite_slot(s))

        for n in range(1, 9):
            self.root.bind(str(n), lambda e, k=n-1: self.on_number_key(k))

    def toggle_collision_overlay_key(self):
        self.show_collision_overlay.set(not self.show_collision_overlay.get())
        self.on_collision_overlay_toggled()

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
                self.set_assembled_quad(self.current_g1_idx, self.active_quad_pos, chosen)
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
        """Map the whole Gen1 block to a stock Gen2 block (tiles + stock collision)."""
        for q in range(4):
            q_img = self.get_quad_image(g2_id, q)
            c_byte = self.g2_coll_raw[g2_id][q] if g2_id < len(self.g2_coll_raw) else 0x00
            chosen = {
                "uid": None,
                "g2_id": g2_id,
                "src_q": q,
                "coll": c_byte,
                "img_np": np.array(q_img),
                "score": 1.0,
            }
            for u in self.unique_quad_pool:
                if u["g2_id"] == g2_id and u["src_q"] == q:
                    chosen["uid"] = u["uid"]
                    chosen["coll"] = u.get("coll", c_byte)
                    break
            # Direct drop-in locks stock collision so later export cannot drift.
            self.set_assembled_quad(self.current_g1_idx, q, chosen, lock_coll=True)
            self.record_learned_choice(self.current_g1_idx, q, chosen)
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

    def apply_quad_feature_preset(
        self,
        g2_id,
        src_q,
        coll=0x00,
        tile_key=None,
        palette_slot=None,
        export_tile=None,
    ):
        """Applies a single quadrant feature preset (e.g. Stair step, cliff top) to active quad and advances."""
        chosen = self._chosen_from_g2_quad(
            g2_id,
            src_q,
            coll,
            tile_key=tile_key,
            palette_slot=palette_slot,
            export_tile=export_tile,
        )
        self.set_assembled_quad(self.current_g1_idx, self.active_quad_pos, chosen, lock_coll=True)
        self.record_learned_choice(self.current_g1_idx, self.active_quad_pos, chosen)
        self.advance_quad_or_block()

    def apply_favorite_slot(self, slot):
        if slot < len(self.favorites):
            fav = self.favorites[slot]
            g2_id = fav["g2_id"]
            src_q = fav.get("src_q", 0)
            coll = fav.get("coll", 0x00)
            chosen = self._chosen_from_g2_quad(
                g2_id,
                src_q,
                coll,
                tile_key=fav.get("tile_key"),
                palette_slot=fav.get("palette_slot"),
                export_tile=fav.get("export_tile"),
            )
            self.set_assembled_quad(self.current_g1_idx, self.active_quad_pos, chosen, lock_coll=True)
            self.record_learned_choice(self.current_g1_idx, self.active_quad_pos, chosen)
            self.advance_quad_or_block()

    def pin_current_to_favorite(self, target_slot=None):
        g1 = self.current_g1_idx
        q = self.active_quad_pos
        cur = self.assembled_quads[g1][q]
        g2_id = cur["g2_id"]
        src_q = cur["src_q"]
        coll = self.quad_coll_lock[g1].get(q, cur.get("coll", 0x00))

        if target_slot is None:
            slot_str = simpledialog.askstring("Pin Favorite", f"Pin G2 #{g2_id} ({QUAD_SHORT[src_q]}) coll=0x{coll:02X} to Favorite Slot (1-8)?", parent=self.root)
            if not slot_str or not slot_str.isdigit():
                return
            target_slot = int(slot_str) - 1

        if 0 <= target_slot < 8:
            name = f"B#{g2_id}"
            fav_entry = {
                "g2_id": g2_id,
                "src_q": src_q,
                "name": name,
                "coll": coll,
            }
            if cur.get("tile_key"):
                fav_entry["tile_key"] = tuple(int(t) for t in cur["tile_key"])
            if cur.get("palette_slot") is not None:
                fav_entry["palette_slot"] = int(cur["palette_slot"])
            if cur.get("export_tile") is not None:
                fav_entry["export_tile"] = int(cur["export_tile"])
            self.favorites[target_slot] = fav_entry
            self.save_favorites_to_disk()
            self.update_view()

    def set_active_quad(self, pos):
        self.active_quad_pos = pos
        g1 = self.current_g1_idx
        cands = self.get_ranked_candidates(g1, pos)
        self.current_quad_cand_idx = 0
        if pos in self.quad_user_modified[g1]:
            sync_idx = self.find_cand_index(
                cands, self.assembled_quads[g1][pos]
            )
            if sync_idx is not None:
                self.current_quad_cand_idx = sync_idx
        else:
            learned_rule = self._learned_rule_for_quad(g1, pos)
            if learned_rule:
                chosen = self._chosen_from_learned_rule(g1, pos, learned_rule)
                sync_idx = self.find_cand_index(cands, chosen)
                if sync_idx is not None:
                    self.current_quad_cand_idx = sync_idx
        self.update_view()

    def next_quad_tab(self):
        self.set_active_quad((self.active_quad_pos + 1) % 4)

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
            g1 = self.current_g1_idx
            q = self.active_quad_pos
            self.lock_quad_collision(g1, q, val)
            self.assembled_quads[g1][q] = dict(self.assembled_quads[g1][q])
            self.assembled_quads[g1][q]["coll"] = val
            self._save_learned_rule(g1, q, self.assembled_quads[g1][q], coll=val)
            self._notify_dirty()
            self.auto_save_session()
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
            self.set_assembled_quad(self.current_g1_idx, self.active_quad_pos, chosen)
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
                # Confirm what is on screen (assembled preview), not a mismatched thumb index.
                chosen = dict(self.assembled_quads[self.current_g1_idx][self.active_quad_pos])
            if chosen:
                self.set_assembled_quad(self.current_g1_idx, self.active_quad_pos, chosen)
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

            q_img = Image.fromarray(self._cand_preview_np(item)).resize((60, 60), Image.NEAREST)
            tk_c = ImageTk.PhotoImage(q_img)
            self.tk_cache[f"modal_{idx}"] = tk_c

            canv = tk.Canvas(cf, width=60, height=60, bg="#101114", highlightthickness=0)
            canv.pack(pady=2, padx=2)
            canv.create_image(30, 30, image=tk_c)

            lbl = tk.Label(cf, text=f"[{idx+1}] #{item['g2_id']}", font=("Helvetica", 9, "bold"), bg="#222530", fg="#FFFFFF")
            lbl.pack(pady=1)

            def select_fn(cand=item):
                top.destroy()
                self.set_assembled_quad(self.current_g1_idx, self.active_quad_pos, cand)
                self.record_learned_choice(self.current_g1_idx, self.active_quad_pos, cand)
                self.advance_quad_or_block()

            cf.bind("<Button-1>", lambda e, f=select_fn: f())
            canv.bind("<Button-1>", lambda e, f=select_fn: f())
            lbl.bind("<Button-1>", lambda e, f=select_fn: f())
            top.bind(str(idx + 1), lambda e, f=select_fn: f())

        top.bind("<Escape>", lambda e: top.destroy())

    def advance_quad_or_block(self):
        if self.active_quad_pos < 3:
            self.set_active_quad(self.active_quad_pos + 1)
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
        # Honor collision locks one last time before committing.
        for q in range(4):
            quads[q] = self.apply_locked_collision(g1_id, q, quads[q])
        coll_4 = [int(q["coll"]) & 0xFF for q in quads]

        same_block = (
            quads[0]["g2_id"] == quads[1]["g2_id"] == quads[2]["g2_id"] == quads[3]["g2_id"]
            and quads[0]["src_q"] == 0
            and quads[1]["src_q"] == 1
            and quads[2]["src_q"] == 2
            and quads[3]["src_q"] == 3
        )
        if same_block:
            g2_id = int(quads[0]["g2_id"])
            vanilla = (
                [int(x) & 0xFF for x in self.g2_coll_raw[g2_id]]
                if g2_id < len(self.g2_coll_raw)
                else [0x00, 0x00, 0x00, 0x00]
            )
            # Only reuse the stock Gen2 block when collision matches exactly.
            # User-marked impassable / grass / etc. must become a custom block.
            if coll_4 == vanilla:
                self.mapping[g1_id] = g2_id
                self._notify_dirty()
                return

        cid = self.next_custom_id
        self.next_custom_id += 1
        self.mapping[g1_id] = cid

        tiles_16 = self.get_assembled_tiles(g1_id)
        self.custom_blocks[cid] = {
            "tiles": tiles_16,
            "collision": coll_4,
            "source_g1": g1_id,
        }
        self._notify_dirty()

    def get_assembled_tiles(self, g1_id):
        quads = self.assembled_quads[g1_id]
        tl = self._quad_tiles_for(quads[0])
        tr = self._quad_tiles_for(quads[1])
        bl = self._quad_tiles_for(quads[2])
        br = self._quad_tiles_for(quads[3])
        return assemble_16_tiles(tl, tr, bl, br)

    def get_quad_image(self, g2_id, q_pos, quad_or_cand=None):
        palette_slot_override = None
        if quad_or_cand is not None:
            tiles = self._quad_tiles_for(quad_or_cand)
            if quad_or_cand.get("palette_slot") is not None and quad_or_cand.get("export_tile") is None:
                palette_slot_override = int(quad_or_cand["palette_slot"])
        elif self.g2_ts_rec and self.g2_sheet_path and g2_id < len(self.g2_tiles_raw):
            tiles = cvmod.extract_quad_tile_ids(self.g2_tiles_raw[g2_id], q_pos)
        else:
            tiles = None
        if tiles and self.g2_ts_rec and self.g2_sheet_path:
            quad_px = max(8, self.g2_block_px // 2)
            return render_quad_from_tile_ids(
                tiles,
                self.g2_ts_rec,
                self.g2_sheet_path,
                quad_px=quad_px,
                tile_size=int(self.profile.get("g2_tile_size") or 8),
                palette_bake=self.g2_palette_bake,
                game=self.profile.get("g2_game") or self.profile.get("game") or "gold",
                palette_slot_override=palette_slot_override,
            )
        if g2_id < len(self.g2_images):
            g2_np = np.array(self.g2_images[g2_id])
            q_np = extract_quadrants(g2_np)[q_pos]
            return Image.fromarray(q_np)
        return Image.new("RGB", (48, 48), (0, 0, 0))

    def _cand_preview_np(self, cand):
        """Tile-index bake for UI — matches live assembled / in-game, not CV cache."""
        g2_id = int(cand.get("g2_id", 0))
        src_q = int(cand.get("src_q", 0))
        img = self.get_quad_image(g2_id, src_q, quad_or_cand=cand)
        return np.array(img.resize((16, 16), Image.NEAREST))

    def _cand_tile_summary(self, cand):
        tiles = self._quad_tiles_for(cand)
        uniq = sorted(set(int(t) for t in tiles))
        if len(uniq) == 1:
            if uniq[0] == cvmod.FLAT_CAVE_FLOOR_DARK_EXPORT:
                return "t62↓dark"
            return f"t{uniq[0]}"
        if uniq == [12, 13, 28, 29]:
            return "t12-29↑"
        if tiles == [1, 1, 1, 1]:
            return "t1↓"
        return "t" + "/".join(str(t) for t in tiles)

    def get_block_image(self, g2_id):
        if g2_id < len(self.g2_images):
            return self.g2_images[g2_id]
        return Image.new("RGB", (48, 48), (0, 0, 0))

    def update_view(self):
        mapped_count = len(self.mapping)
        self.lbl_progress.config(text=f"Gen 1 Block {self.current_g1_idx} / {self.total_g1 - 1}  ({mapped_count}/{self.total_g1} mapped)")
        self.progress_bar["maximum"] = self.total_g1
        self.progress_bar["value"] = self.current_g1_idx + 1

        self.lbl_learned_badge.config(text=f"{len(self.learned_memory)} Learned Rules")

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
            self.lbl_special_notice.config(text=f"#{self.current_g1_idx}: {FEATURE_BAR_TITLE} → apply to {QUAD_SHORT[self.active_quad_pos]} & advance:")
            # Render special quadrant cards
            for idx, card in enumerate(self.special_quad_cards):
                d = card["data"]
                q_img = self.get_quad_image(d["g2_id"], d["src_q"], quad_or_cand=d).resize((self.dropin_thumb_size, self.dropin_thumb_size), Image.NEAREST)
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
                f_img = self.get_quad_image(fav["g2_id"], fav.get("src_q", 0), quad_or_cand=fav).resize((self.fav_thumb_size, self.fav_thumb_size), Image.NEAREST)
                tk_f = ImageTk.PhotoImage(f_img)
                self.tk_cache[f"fav_{s}"] = tk_f
                f_obj["canvas"].delete("all")
                f_obj["canvas"].create_image(self.fav_thumb_size // 2, self.fav_thumb_size // 2, image=tk_f)
                f_obj["label"].config(text=f"F{s+1}: {self._cand_tile_summary(fav)}")

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
            cands = [{"g2_id": 0, "src_q": 0, "score": 0.0, "coll": 0x00, "ssim": 0.0, "color": 0.0, "occurrences": [], "img_np": np.zeros((16, 16, 3), dtype=np.uint8)}]
        if self.current_quad_cand_idx >= len(cands):
            self.current_quad_cand_idx = 0

        g1 = self.current_g1_idx
        aq = self.active_quad_pos
        highlight_idx = self.current_quad_cand_idx
        # Active quadrant: cursor index is source of truth while browsing.
        # Piece-sticky (user_modified) only freezes after Enter/favorite/shortlist —
        # then we snap the highlight to that piece instead of overwriting it.
        if aq in self.quad_user_modified[g1]:
            cur_cand = self._hydrate_quad_entry(
                self.apply_locked_collision(g1, aq, self.assembled_quads[g1][aq])
            )
            self.assembled_quads[g1][aq] = cur_cand
            sync_idx = self.find_cand_index(cands, cur_cand)
            if sync_idx is not None:
                self.current_quad_cand_idx = sync_idx
                highlight_idx = sync_idx
            else:
                highlight_idx = None
        else:
            # Active tab follows the candidate cursor so ←/→ can override a learned default.
            cur_cand = self._hydrate_quad_entry(
                self.apply_locked_collision(g1, aq, cands[self.current_quad_cand_idx])
            )
            self.assembled_quads[g1][aq] = cur_cand
            highlight_idx = self.current_quad_cand_idx

        # Other quadrants: learned rules and user pins beat blind rank #1 refresh.
        for q in range(4):
            if q == aq:
                continue
            self.assembled_quads[g1][q] = self._resolve_quad_assembly(g1, q)

        if "img_np" not in cur_cand or cur_cand["img_np"] is None:
            cur_cand["img_np"] = self._cand_preview_np(cur_cand)

        q_img = Image.fromarray(self._cand_preview_np(cur_cand)).resize((self.quad_size, self.quad_size), Image.NEAREST)
        tk_q = ImageTk.PhotoImage(q_img)
        self.tk_cache["active_quad"] = tk_q
        self.canvas_quad_active.delete("all")
        self.canvas_quad_active.create_image(self.quad_size // 2, self.quad_size // 2, image=tk_q)

        if aq in self.quad_user_modified[g1] and highlight_idx is None:
            self.lbl_quad_rank.config(
                text="Confirmed selection  (←/→ to browse alternatives)",
                foreground="#81C784",
            )
        elif cur_cand.get("is_learned"):
            rank_n = (highlight_idx if highlight_idx is not None else self.current_quad_cand_idx) + 1
            self.lbl_quad_rank.config(
                text=f"Candidate #{rank_n} of {len(cands)}  🧠 Learned Preference!",
                foreground="#81C784",
            )
        else:
            rank_n = (highlight_idx if highlight_idx is not None else self.current_quad_cand_idx) + 1
            self.lbl_quad_rank.config(
                text=f"Candidate #{rank_n} of {len(cands)}",
                foreground="#FFB74D",
            )

        self.lbl_quad_src.config(
            text=f"Primary: G2 Block #{cur_cand['g2_id']} ({QUAD_SHORT[cur_cand['src_q']]})  [{self._cand_tile_summary(cur_cand)}]"
        )

        occs = cur_cand.get("occurrences", [])
        if cur_cand.get("has_water_tiles"):
            self.lbl_quad_also.config(
                text="⚠ Contains water tile(s) — renders as surf in-game unless collision is water",
                foreground="#64B5F6",
            )
        elif len(occs) > 1:
            other_blocks = [f"#{b}({QUAD_SHORT[q]})" for b, q in occs[1:6]]
            extra_count = len(occs) - 6
            extra_txt = f" +{extra_count} more" if extra_count > 0 else ""
            coll_note = ""
            variants = cur_cand.get("coll_variants")
            if variants and len(variants) > 1:
                coll_note = f"  coll variants: {', '.join(f'0x{c:02X}' for c in sorted(variants))}"
            self.lbl_quad_also.config(text=f"Also in: {', '.join(other_blocks)}{extra_txt}{coll_note}")
        else:
            self.lbl_quad_also.config(text="Unique to this block only")

        self.lbl_quad_score.config(
            text=(
                f"Score: {cur_cand.get('score', cur_cand.get('base_score', 0.0)):.3f} "
                f"(Px: {cur_cand.get('pixel', cur_cand.get('ssim', 0)):.2f}, "
                f"Col: {cur_cand.get('color', 0):.2f})"
            )
        )

        coll_val = self.assembled_quads[self.current_g1_idx][self.active_quad_pos]["coll"]
        matched_cbo_idx = 0
        for idx, p in enumerate(COLLISION_PRESETS):
            if p["val"] == coll_val:
                matched_cbo_idx = idx
                break
        self.cbo_collision.current(matched_cbo_idx)

        # 5. Live Assembled Block Preview (tile-index bake = export / in-game)
        quads = [self._hydrate_quad_entry(q) for q in self.assembled_quads[self.current_g1_idx]]
        self.assembled_quads[self.current_g1_idx] = quads
        try:
            tiles16 = self.get_assembled_tiles(self.current_g1_idx)
            assembled_pil = self.render_block_from_tile_ids(tiles16).resize(
                (self.preview_size, self.preview_size), Image.NEAREST
            )
        except Exception:
            q0_img = quads[0]["img_np"]
            q1_img = quads[1]["img_np"]
            q2_img = quads[2]["img_np"]
            q3_img = quads[3]["img_np"]
            assembled_np = assemble_quadrants_image(q0_img, q1_img, q2_img, q3_img)
            assembled_pil = Image.fromarray(assembled_np).resize(
                (self.preview_size, self.preview_size), Image.NEAREST
            )
        if self.show_collision_overlay.get():
            coll_for_overlay = [q["coll"] for q in quads]
            assembled_pil = draw_collision_overlay(
                assembled_pil, coll_for_overlay, self.coll_color_by_val, alpha=120
            ).resize((self.preview_size, self.preview_size), Image.NEAREST)
        draw_as = ImageDraw.Draw(assembled_pil)

        half_p = self.preview_size // 2
        draw_as.line([(half_p, 0), (half_p, self.preview_size)], fill="#444856", width=1)
        draw_as.line([(0, half_p), (self.preview_size, half_p)], fill="#444856", width=1)

        coll_str = [f"0x{q['coll']:02X}" for q in quads]
        locks = self.quad_coll_lock[g1]
        lock_marks = "".join("L" if q in locks else "-" for q in range(4))
        self.lbl_assembled_coll_summary.config(
            text=f"Collision: [{', '.join(coll_str)}]  locks[{lock_marks}]"
        )

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
                s_img = Image.fromarray(self._cand_preview_np(cand)).resize((40, 40), Image.NEAREST)
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
                t_img = Image.fromarray(self._cand_preview_np(cand)).resize((self.thumb_size, self.thumb_size), Image.NEAREST)
                tk_t = ImageTk.PhotoImage(t_img)
                self.tk_cache[f"thumb_{slot}"] = tk_t
                t_obj["canvas"].delete("all")
                t_obj["canvas"].create_image(self.thumb_size // 2, self.thumb_size // 2, image=tk_t)

                t_obj["label"].config(
                    text=f"#{cand_pos + 1}: #{cand['g2_id']}({QUAD_SHORT[cand['src_q']]}) {self._cand_tile_summary(cand)}"
                    + (" 💧" if cand.get("has_water_tiles") else "")
                )
                if highlight_idx is not None and cand_pos == highlight_idx:
                    t_obj["frame"].config(bg="#FFB74D", bd=2)
                else:
                    t_obj["frame"].config(bg="#222530", bd=1)
            else:
                t_obj["canvas"].delete("all")
                t_obj["label"].config(text="--")
                t_obj["frame"].config(bg="#181A20", bd=1)

        self.schedule_map_preview_refresh()

    def get_window_start(self, total_cands):
        half = self.thumb_window_size // 2
        anchor = self.current_quad_cand_idx
        if anchor < 0:
            anchor = 0
        start = max(0, anchor - half)
        if start + self.thumb_window_size > total_cands:
            start = max(0, total_cands - self.thumb_window_size)
        return start

    def select_window_slot(self, slot):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        win_start = self.get_window_start(len(cands))
        target_idx = win_start + slot
        if target_idx < len(cands):
            self.browse_candidate_to(target_idx)

    def next_candidate(self):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if cands:
            self.browse_candidate_to((self.current_quad_cand_idx + 1) % len(cands))

    def prev_candidate(self):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if cands:
            self.browse_candidate_to((self.current_quad_cand_idx - 1 + len(cands)) % len(cands))

    def jump_next_8(self):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if cands:
            self.browse_candidate_to(min(len(cands) - 1, self.current_quad_cand_idx + 8))

    def jump_prev_8(self):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if cands:
            self.browse_candidate_to(max(0, self.current_quad_cand_idx - 8))

    def jump_first_candidate(self):
        cands = self.get_ranked_candidates(self.current_g1_idx, self.active_quad_pos)
        if cands:
            self.browse_candidate_to(0)

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
                initialfile=os.path.basename(self.out_path) if self.out_path else f"{self.dict_name}_mapping.py"
            )
        if not file_path:
            return

        # Rebuild mapping/customs from live assembled quads so collision locks win.
        # Prior mapping entries are discarded — assembled_quads + locks are source of truth.
        self.custom_blocks = {}
        self.mapping = {}
        self.next_custom_id = max(161, self.total_g2)
        for i in range(self.total_g1):
            self.finalize_block_mapping(i)

        if self.water_tile_ids:
            leaks = []
            for cid, info in self.custom_blocks.items():
                tiles = info.get("tiles") or []
                if not any(t in self.water_tile_ids for t in tiles):
                    continue
                coll = [int(c) & 0xFF for c in (info.get("collision") or [])]
                if coll and all(c in self.water_collisions for c in coll):
                    continue
                leaks.append(int(info.get("source_g1", cid)))
            if leaks:
                preview = ", ".join(f"#{x}" for x in sorted(set(leaks))[:12])
                extra = f" (+{len(set(leaks)) - 12} more)" if len(set(leaks)) > 12 else ""
                if not messagebox.askyesno(
                    "Water tile index in wall/floor blocks",
                    "The map preview now shows export-accurate art. These Gen1 blocks "
                    "still include TILESET_CAVE tile #20 (the water index). Under CAVE/NITE "
                    "baking it can look like dark rock, but the game always animates #20 "
                    "as surf:\n"
                    f"{preview}{extra}\n\n"
                    "Re-pick those blocks (avoid 💧 candidates) or export anyway?",
                    parent=self.root,
                ):
                    return

        lines = [
            f"# Generated Block Translation Dictionary ({len(self.mapping)} / {self.total_g1} blocks mapped)",
            f"# Collision bytes are taken from the mapper (locks / combobox / favorites); not re-inferred.",
            f"{self.dict_name} = {{"
        ]

        keys = sorted(self.mapping.keys())
        for k in keys:
            v = self.mapping[k]
            lines.append(f"    {k}: {v},")
        lines.append("}\n")

        lines.append(f"# Custom Assembled Blocks for restore_kanto_dungeons.py")
        lines.append(f"{self.custom_blocks_name} = {{")
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
            f.flush()
            os.fsync(f.fileno())

        self.auto_save_session()

        json_path = os.path.splitext(file_path)[0] + ".json"
        export_data = {
            "mapping": self.mapping,
            "custom_blocks": self.custom_blocks
        }
        with open(json_path, "w") as f:
            json.dump(export_data, f, indent=2, sort_keys=True)
            f.flush()
            os.fsync(f.fileno())

        if self.session_obj:
            self.session_obj.mapping = self.mapping
            self.session_obj.custom_blocks = self.custom_blocks
            self.session_obj.clear_dirty()

        export_summary = (
            f"Saved {len(self.mapping)} mappings & {len(self.custom_blocks)} custom blocks to:\n"
            f"{file_path}\n({json_path})"
        )
        run_restore = (
            getattr(self, "run_restore_after_export", None)
            and self.run_restore_after_export.get()
        )
        if run_restore:
            try:
                self._run_restore_script(show_dialog=False)
                messagebox.showinfo(
                    "Export & Restore",
                    export_summary + f"\n\n{os.path.basename(self.profile.get('restore_script') or 'restore_kanto_dungeons.py')} completed.",
                )
            except Exception as exc:  # noqa: BLE001
                messagebox.showerror(
                    "Restore failed",
                    export_summary + f"\n\nExport was saved, but restore failed:\n{exc}",
                )
        else:
            messagebox.showinfo("Export Successful", export_summary)

    def _run_restore_script(self, *, show_dialog=True):
        import subprocess

        restore_name = self.profile.get("restore_script") or "restore_kanto_dungeons.py"
        restore = os.path.join(_TOOLS_DIR, restore_name)
        recomp = os.path.dirname(os.path.dirname(_TOOLS_DIR))
        subprocess.run(["python3", restore], cwd=recomp, check=True)
        label = os.path.basename(restore_name)
        if show_dialog:
            messagebox.showinfo("Restore", f"{label} completed.")

