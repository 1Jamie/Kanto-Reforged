#!/usr/bin/env python3
"""Full dual-pane map preview with tileset-filtered map picker (single PIL composites)."""

from __future__ import annotations

import tkinter as tk
from tkinter import ttk

from PIL import Image, ImageDraw, ImageTk

from map_layout_loader import list_preview_maps_for_profile, load_map_by_id
from tileset_block_rebuild import draw_collision_overlay
from block_mapper_profiles.common import COLLISION_COLOR_BY_VAL
from block_mapper import cv as cvmod


class PreviewView(ttk.Frame):
    def __init__(self, master, shell, **kwargs):
        super().__init__(master, **kwargs)
        self.shell = shell
        self.session = None
        self.mapper = None  # set by shell after MapperView exists
        self.zoom = 1
        self.show_collision = tk.BooleanVar(value=False)
        self._map_meta = None
        self._g1_pil = None
        self._g2_pil = None
        self._tk_g1 = None
        self._tk_g2 = None
        self._canvas_img_g1 = None
        self._canvas_img_g2 = None

        bar = ttk.Frame(self)
        bar.pack(fill="x", padx=8, pady=6)
        ttk.Button(bar, text="← Back to Mapper", command=lambda: shell.show_mode("mapper")).pack(side="left", padx=4)
        ttk.Label(bar, text="Map:").pack(side="left", padx=(12, 4))
        self.map_var = tk.StringVar()
        self.cbo_maps = ttk.Combobox(bar, textvariable=self.map_var, state="readonly", width=36)
        self.cbo_maps.pack(side="left")
        self.cbo_maps.bind("<<ComboboxSelected>>", lambda e: self._on_map_selected())
        ttk.Checkbutton(bar, text="Collision overlay", variable=self.show_collision, command=self.rebuild_composites).pack(
            side="left", padx=8
        )
        ttk.Button(bar, text="Zoom −", command=lambda: self._adjust_zoom(-1)).pack(side="right", padx=2)
        ttk.Button(bar, text="Zoom +", command=lambda: self._adjust_zoom(1)).pack(side="right", padx=2)

        panes = ttk.Frame(self)
        panes.pack(fill="both", expand=True, padx=8, pady=4)
        left = ttk.Frame(panes)
        left.pack(side="left", fill="both", expand=True, padx=(0, 4))
        ttk.Label(left, text="Gen 1 (source)").pack(anchor="w")
        self.canvas_g1 = tk.Canvas(left, bg="#101114", highlightthickness=1, highlightbackground="#3F4456")
        self.canvas_g1.pack(fill="both", expand=True)
        self.canvas_g1.bind("<Button-1>", lambda e: self._on_click(e, "g1"))
        self.canvas_g1.bind("<Configure>", lambda e: self._blit())

        right = ttk.Frame(panes)
        right.pack(side="left", fill="both", expand=True, padx=(4, 0))
        ttk.Label(right, text="Gen 2 (projection)").pack(anchor="w")
        self.canvas_g2 = tk.Canvas(right, bg="#101114", highlightthickness=1, highlightbackground="#64B5F6")
        self.canvas_g2.pack(fill="both", expand=True)
        self.canvas_g2.bind("<Button-1>", lambda e: self._on_click(e, "g2"))
        self.canvas_g2.bind("<Configure>", lambda e: self._blit())

        self.hint = ttk.Label(self, text="Run a profile from Setup to enable map preview.")
        self.hint.pack(anchor="w", padx=8, pady=4)

    def bind_session(self, session, mapper_view=None):
        self.session = session
        if mapper_view is not None:
            self.mapper = mapper_view
        tilesets = list(session.profile.get("preview_tilesets") or [])
        if not tilesets and session.profile.get("g1_tileset_id"):
            tilesets = [session.profile["g1_tileset_id"]]
        maps = list_preview_maps_for_profile(session.profile)
        labels = [f"{m['map_id']} ({m['width']}x{m['height']})" for m in maps]
        self._map_list = maps
        self.cbo_maps["values"] = labels
        preferred = (session.preview_map or {}).get("map_id")
        idx = 0
        if preferred:
            for i, m in enumerate(maps):
                if m["map_id"] == preferred:
                    idx = i
                    break
        if labels:
            self.cbo_maps.current(idx)
            self._on_map_selected()
            self.hint.config(text=f"Tilesets: {', '.join(tilesets)} — {len(maps)} maps")
        else:
            self.hint.config(text=f"No maps found for tilesets {tilesets}")

    def _current_map(self):
        if not getattr(self, "_map_list", None):
            return self.session.preview_map if self.session else None
        i = self.cbo_maps.current()
        if i < 0 or i >= len(self._map_list):
            return self.session.preview_map if self.session else None
        return load_map_by_id(self._map_list[i]["map_id"])

    def _on_map_selected(self):
        m = self._current_map()
        if m and self.session:
            self.session.preview_map = m
        self.rebuild_composites()

    def _adjust_zoom(self, delta):
        self.zoom = max(1, min(4, self.zoom + delta))
        self.rebuild_composites()

    def notify_mapping_changed(self, g1_ids=None):
        """Partial update: rebuild Gen2 composite (full rebuild is fine at cave sizes)."""
        if self.session and self.winfo_ismapped():
            self.rebuild_composites(g1_ids=g1_ids)

    def _cell_px(self):
        return max(4, 8 * self.zoom)

    def _resolve_g2_image(self, g2_id):
        mapper = self.mapper
        if mapper and hasattr(mapper, "resolve_g2_block_image"):
            return mapper.resolve_g2_block_image(g2_id)
        if self.session and 0 <= g2_id < len(self.session.g2_images):
            return self.session.g2_images[g2_id]
        return Image.new("RGB", (32, 32), (20, 20, 20))

    def _projected_g2(self, g1_id):
        if not self.session:
            return None
        mapper = self.mapper
        mapping = mapper.mapping if mapper else self.session.mapping
        if g1_id in mapping:
            return mapping[g1_id]
        if mapper and g1_id == getattr(mapper, "current_g1_idx", -1) and g1_id in getattr(mapper, "assembled_quads", {}):
            quads = mapper.assembled_quads[g1_id]
            if (
                quads[0]["g2_id"] == quads[1]["g2_id"] == quads[2]["g2_id"] == quads[3]["g2_id"]
                and quads[0]["src_q"] == 0
                and quads[1]["src_q"] == 1
                and quads[2]["src_q"] == 2
                and quads[3]["src_q"] == 3
            ):
                return quads[0]["g2_id"]
            return ("assembled", g1_id)
        return None

    def rebuild_composites(self, g1_ids=None):
        if not self.session:
            return
        m = self.session.preview_map or self._current_map()
        if not m:
            return
        width, height, blocks = m["width"], m["height"], m["blocks"]
        cell = self._cell_px()
        highlight = getattr(self.mapper, "current_g1_idx", -1) if self.mapper else -1
        g1_img = Image.new("RGB", (width * cell, height * cell), (16, 16, 20))
        g2_img = Image.new("RGB", (width * cell, height * cell), (16, 16, 20))
        colors = dict(COLLISION_COLOR_BY_VAL)

        for y in range(height):
            for x in range(width):
                idx = y * width + x
                if idx >= len(blocks):
                    break
                g1_id = int(blocks[idx])
                if 0 <= g1_id < len(self.session.g1_images):
                    tile1 = self.session.g1_images[g1_id].resize((cell, cell), Image.NEAREST)
                else:
                    tile1 = Image.new("RGB", (cell, cell), (40, 0, 0))
                if g1_id == highlight:
                    ImageDraw.Draw(tile1).rectangle([0, 0, cell - 1, cell - 1], outline="#FFB74D", width=max(1, cell // 8))
                g1_img.paste(tile1, (x * cell, y * cell))

                proj = self._projected_g2(g1_id)
                if proj is None:
                    tile2 = Image.new("RGB", (cell, cell), (30, 30, 36))
                elif isinstance(proj, tuple) and proj[0] == "assembled":
                    hitl = getattr(self.mapper, "hitl", None)
                    tile2 = None
                    if hitl:
                        try:
                            tiles16 = hitl.get_assembled_tiles(proj[1])
                            tile2 = hitl.render_block_from_tile_ids(tiles16).resize(
                                (cell, cell), Image.NEAREST
                            )
                        except Exception:
                            tile2 = None
                    if tile2 is None:
                        quads_raw = self.mapper.assembled_quads[proj[1]]
                        if hitl:
                            quads = [hitl._hydrate_quad_entry(q) for q in quads_raw]
                        else:
                            quads = quads_raw
                        assembled = cvmod.assemble_quadrants_image(
                            quads[0]["img_np"], quads[1]["img_np"], quads[2]["img_np"], quads[3]["img_np"]
                        )
                        tile2 = Image.fromarray(assembled).resize((cell, cell), Image.NEAREST)
                    if self.show_collision.get():
                        tile2 = draw_collision_overlay(
                            tile2, [q.get("coll", 0) for q in quads], colors, alpha=100
                        )
                else:
                    src = self._resolve_g2_image(int(proj))
                    tile2 = src.resize((cell, cell), Image.NEAREST)
                    if self.show_collision.get() and self.mapper:
                        coll = self.mapper.resolve_g2_collision(int(proj))
                        tile2 = draw_collision_overlay(tile2, coll, colors, alpha=100)
                if g1_id == highlight:
                    ImageDraw.Draw(tile2).rectangle([0, 0, cell - 1, cell - 1], outline="#FFB74D", width=max(1, cell // 8))
                g2_img.paste(tile2, (x * cell, y * cell))

        self._g1_pil = g1_img
        self._g2_pil = g2_img
        self._map_meta = {"width": width, "height": height, "cell": cell, "blocks": blocks}
        self._blit()

    def _blit(self):
        if self._g1_pil is None:
            return
        for canvas, pil, attr_tk, attr_id in (
            (self.canvas_g1, self._g1_pil, "_tk_g1", "_canvas_img_g1"),
            (self.canvas_g2, self._g2_pil, "_tk_g2", "_canvas_img_g2"),
        ):
            cw = max(100, int(canvas.winfo_width() or 400))
            ch = max(100, int(canvas.winfo_height() or 300))
            scale = min(cw / pil.width, ch / pil.height, 1.0)
            dw = max(1, int(pil.width * scale))
            dh = max(1, int(pil.height * scale))
            disp = pil.resize((dw, dh), Image.NEAREST)
            tk_img = ImageTk.PhotoImage(disp)
            setattr(self, attr_tk, tk_img)
            canvas.delete("all")
            iid = canvas.create_image(cw // 2, ch // 2, image=tk_img)
            setattr(self, attr_id, iid)
            if self._map_meta:
                self._map_meta["scale"] = scale
                self._map_meta["disp_w"] = dw
                self._map_meta["disp_h"] = dh

    def _on_click(self, event, side):
        meta = self._map_meta
        if not meta or not self.session:
            return
        canvas = self.canvas_g1 if side == "g1" else self.canvas_g2
        cw = max(100, int(canvas.winfo_width() or 400))
        ch = max(100, int(canvas.winfo_height() or 300))
        ox = (cw - meta["disp_w"]) // 2
        oy = (ch - meta["disp_h"]) // 2
        lx, ly = event.x - ox, event.y - oy
        if lx < 0 or ly < 0 or lx >= meta["disp_w"] or ly >= meta["disp_h"]:
            return
        cell_disp = meta["cell"] * meta["scale"]
        if cell_disp <= 0:
            return
        bx = int(lx / cell_disp)
        by = int(ly / cell_disp)
        if not (0 <= bx < meta["width"] and 0 <= by < meta["height"]):
            return
        idx = by * meta["width"] + bx
        blocks = meta["blocks"]
        if idx >= len(blocks):
            return
        g1_id = int(blocks[idx])
        self.shell.jump_to_g1_block(g1_id)
