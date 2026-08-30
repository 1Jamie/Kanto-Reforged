#!/usr/bin/env python3
"""Setup view — profile / sheets / Process Run."""

from __future__ import annotations

import os
import tkinter as tk
from tkinter import filedialog, ttk

from block_mapper_profiles import list_profiles, load_profile
from block_mapper.session import resolve_sheet_path


class SetupView(ttk.Frame):
    def __init__(self, master, shell, **kwargs):
        super().__init__(master, **kwargs)
        self.shell = shell
        self._building = True

        pad = {"padx": 12, "pady": 4}
        ttk.Label(self, text="Block Mapper Setup", style="Title.TLabel").pack(anchor="w", padx=12, pady=(16, 8))

        form = ttk.Frame(self)
        form.pack(fill="x", padx=12)

        ttk.Label(form, text="Profile").grid(row=0, column=0, sticky="w", **pad)
        self.profile_var = tk.StringVar(value="safari_kanto")
        self.cbo_profile = ttk.Combobox(
            form, textvariable=self.profile_var, values=list_profiles(), state="readonly", width=40
        )
        self.cbo_profile.grid(row=0, column=1, sticky="ew", **pad)
        self.cbo_profile.bind("<<ComboboxSelected>>", lambda e: self._on_profile_changed())

        ttk.Label(form, text="Gen1 sheet").grid(row=1, column=0, sticky="w", **pad)
        self.g1_var = tk.StringVar()
        ttk.Entry(form, textvariable=self.g1_var, width=48).grid(row=1, column=1, sticky="ew", **pad)
        ttk.Button(form, text="Browse…", command=lambda: self._browse(self.g1_var)).grid(row=1, column=2, **pad)

        ttk.Label(form, text="Gen2 sheet").grid(row=2, column=0, sticky="w", **pad)
        self.g2_var = tk.StringVar()
        ttk.Entry(form, textvariable=self.g2_var, width=48).grid(row=2, column=1, sticky="ew", **pad)
        ttk.Button(form, text="Browse…", command=lambda: self._browse(self.g2_var)).grid(row=2, column=2, **pad)

        self.g1_card = tk.BooleanVar(value=False)
        self.g2_card = tk.BooleanVar(value=False)
        self.include_buildings = tk.BooleanVar(value=False)
        ttk.Checkbutton(form, text="Gen1 card sheet", variable=self.g1_card).grid(row=3, column=1, sticky="w", **pad)
        ttk.Checkbutton(form, text="Gen2 card sheet", variable=self.g2_card).grid(row=4, column=1, sticky="w", **pad)
        ttk.Checkbutton(form, text="Include building blocks in pool", variable=self.include_buildings).grid(
            row=5, column=1, sticky="w", **pad
        )

        ttk.Label(form, text="Output .py").grid(row=6, column=0, sticky="w", **pad)
        self.out_var = tk.StringVar()
        ttk.Entry(form, textvariable=self.out_var, width=48).grid(row=6, column=1, sticky="ew", **pad)

        ttk.Label(form, text="Dict name").grid(row=7, column=0, sticky="w", **pad)
        self.dict_var = tk.StringVar()
        ttk.Entry(form, textvariable=self.dict_var, width=48).grid(row=7, column=1, sticky="ew", **pad)

        form.columnconfigure(1, weight=1)

        self.status = ttk.Label(self, text="Select a profile and click Process / Run.", foreground="#B0B4C0")
        self.status.pack(anchor="w", padx=12, pady=8)

        btn_row = ttk.Frame(self)
        btn_row.pack(fill="x", padx=12, pady=12)
        self.btn_run = ttk.Button(btn_row, text="Process / Run", style="Approve.TButton", command=self._on_run)
        self.btn_run.pack(side="left")

        self._building = False
        self._on_profile_changed()

    def _browse(self, var: tk.StringVar):
        path = filedialog.askopenfilename(
            title="Select block sheet",
            filetypes=[("PNG", "*.png"), ("All", "*.*")],
        )
        if path:
            var.set(path)

    def apply_cli_defaults(self, profile_id=None, g1=None, g2=None, out=None, dict_name=None, include_buildings=None):
        if profile_id:
            self.profile_var.set(profile_id)
            self._on_profile_changed()
        if g1:
            self.g1_var.set(g1)
        if g2:
            self.g2_var.set(g2)
        if out:
            self.out_var.set(out)
        if dict_name:
            self.dict_var.set(dict_name)
        if include_buildings is not None:
            self.include_buildings.set(bool(include_buildings))

    def _on_profile_changed(self):
        if self._building:
            return
        try:
            profile = load_profile(self.profile_var.get())
        except Exception as exc:  # noqa: BLE001
            self.status.config(text=f"Profile error: {exc}", foreground="#E57373")
            return
        # setup_view.py lives in tools/block_mapper/views/ → tools/
        tools = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        self.g1_var.set(profile.get("g1_sheet") or "")
        self.g2_var.set(profile.get("g2_sheet") or "")
        self.g1_card.set(bool(profile.get("g1_card_sheet")))
        self.g2_card.set(bool(profile.get("g2_card_sheet")))
        self.include_buildings.set(not bool(profile.get("exclude_buildings", True)))
        self.out_var.set(os.path.join(tools, profile.get("out") or "g1_to_g2.py"))
        self.dict_var.set(profile.get("dict_name") or "G1_TO_G2")
        g1_ok = resolve_sheet_path(self.g1_var.get()) or profile.get("g1_tileset_id")
        g2_ok = resolve_sheet_path(self.g2_var.get()) or profile.get("g2_tileset_id")
        bits = []
        if not g1_ok:
            bits.append("Gen1 sheet missing (rebuild if g1_tileset_id set)")
        if not g2_ok:
            bits.append("Gen2 sheet missing (rebuild if g2_tileset_id set)")
        self.status.config(
            text="; ".join(bits) if bits else f"Ready — {profile.get('title') or profile.get('id')}",
            foreground="#E57373" if bits else "#A5D6A7",
        )

    def gather_run_args(self) -> dict:
        profile = load_profile(self.profile_var.get())
        profile["g1_card_sheet"] = self.g1_card.get()
        profile["g2_card_sheet"] = self.g2_card.get()
        profile["dict_name"] = self.dict_var.get() or profile.get("dict_name")
        if self.out_var.get():
            profile["out"] = self.out_var.get()
        return {
            "profile": profile,
            "g1_sheet_path": resolve_sheet_path(self.g1_var.get()) or self.g1_var.get() or None,
            "g2_sheet_path": resolve_sheet_path(self.g2_var.get()) or self.g2_var.get() or None,
            "out_file": self.out_var.get() or None,
            "exclude_buildings": not self.include_buildings.get(),
        }

    def set_busy(self, busy: bool, message: str | None = None):
        if busy:
            self.btn_run.config(state="disabled")
        else:
            self.set_run_enabled(self.shell.mode == "setup")
        self.cbo_profile.config(state="disabled" if busy else "readonly")
        if message:
            self.status.config(text=message, foreground="#FFB74D" if busy else "#A5D6A7")

    def set_run_enabled(self, enabled: bool):
        if not self.shell._run_in_flight:
            self.btn_run.config(state="normal" if enabled else "disabled")

    def _on_run(self):
        self.shell.start_process_run(self.gather_run_args())
