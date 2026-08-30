#!/usr/bin/env python3
"""Mapper view — long-lived frame hosting the HITL core."""

from __future__ import annotations

import os
from tkinter import ttk

from block_mapper.views._hitl_core import _HitlMapper, apply_chrome


class MapperView(ttk.Frame):
    def __init__(self, master, shell, **kwargs):
        super().__init__(master, **kwargs)
        self.shell = shell
        self.session = None
        self.hitl = None
        self._placeholder = ttk.Label(self, text="Run Process from Setup to start mapping.")
        self._placeholder.pack(padx=16, pady=24)

    def bind_session(self, session, on_mapping_changed=None):
        self.session = session
        apply_chrome(session.profile)
        if self._placeholder:
            self._placeholder.destroy()
            self._placeholder = None
        # Clear previous HITL widgets
        for child in list(self.winfo_children()):
            child.destroy()
        self.hitl = None

        session_path = os.path.splitext(session.out_path)[0] + ".session.json"
        self.hitl = _HitlMapper(
            root=self.shell.root,
            g1_images=session.g1_images,
            g2_images=session.g2_images,
            block_rankings=session.block_rankings,
            base_quad_rankings=session.base_quad_rankings,
            unique_quad_pool=session.unique_quad_pool,
            g2_tiles_raw=session.g2_tiles_raw,
            g2_coll_raw=session.g2_coll_raw,
            g2_ts_rec=session.g2_ts_rec,
            g2_sheet_path=session.g2_sheet_path,
            g2_palette_bake=session.g2_palette_bake,
            out_path=session.out_path,
            session_path=session_path,
            dict_name=session.dict_name,
            custom_blocks_name=session.custom_blocks_name,
            profile=session.profile,
            test_map=session.preview_map,
            g1_block_px=session.g1_block_px,
            g2_block_px=session.g2_block_px,
            ui_parent=self,
            shell=self.shell,
            session_obj=session,
            on_mapping_changed=on_mapping_changed,
        )
        # Sync live state onto session for dirty tracking
        session.mapping = self.hitl.mapping
        session.custom_blocks = self.hitl.custom_blocks

    @property
    def mapping(self):
        return self.hitl.mapping if self.hitl else {}

    @property
    def assembled_quads(self):
        return self.hitl.assembled_quads if self.hitl else {}

    @property
    def current_g1_idx(self):
        return self.hitl.current_g1_idx if self.hitl else 0

    def resolve_g2_block_image(self, g2_id):
        return self.hitl.resolve_g2_block_image(g2_id)

    def resolve_g2_collision(self, g2_id):
        return self.hitl.resolve_g2_collision(g2_id)

    def jump_to_g1(self, g1_id: int):
        if not self.hitl:
            return
        if 0 <= g1_id < self.hitl.total_g1:
            self.hitl.current_g1_idx = g1_id
            self.hitl.active_quad_pos = 0
            self.hitl.current_quad_cand_idx = 0
            self.hitl.update_view()

    def export_mapping(self) -> bool:
        if not self.hitl:
            return False
        try:
            self.hitl.save_mapping()
            return not self.session.is_dirty
        except Exception:
            return False

    def set_keybinds_enabled(self, enabled: bool):
        # Keybinds are on root; shell manages focus modes
        pass
