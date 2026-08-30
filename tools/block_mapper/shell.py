#!/usr/bin/env python3
"""BlockMapperShell — Setup / Mapper / Map Preview state machine."""

from __future__ import annotations

import queue
import threading
import tkinter as tk
from tkinter import messagebox, ttk

from block_mapper.session import prepare_mapping_session
from block_mapper.views.mapper_view import MapperView
from block_mapper.views.preview_view import PreviewView
from block_mapper.views.setup_view import SetupView


class BlockMapperShell:
    def __init__(self, root: tk.Tk, cli_defaults: dict | None = None):
        self.root = root
        self.root.title("Block Mapper")
        self.root.geometry("1480x980")
        self.root.minsize(1100, 800)
        self.root.configure(bg="#181A20")

        self.session = None
        self.mode = "setup"
        self._result_queue: queue.Queue = queue.Queue()
        self._run_in_flight = False

        self._build_styles()

        # Mode bar
        self.mode_bar = ttk.Frame(root)
        self.mode_bar.pack(fill="x", padx=8, pady=6)
        self.btn_setup = ttk.Button(self.mode_bar, text="Setup", command=lambda: self.show_mode("setup"))
        self.btn_mapper = ttk.Button(self.mode_bar, text="Mapper", command=lambda: self.show_mode("mapper"))
        self.btn_preview = ttk.Button(self.mode_bar, text="Map Preview", command=lambda: self.show_mode("preview"))
        self.btn_setup.pack(side="left", padx=2)
        self.btn_mapper.pack(side="left", padx=2)
        self.btn_preview.pack(side="left", padx=2)
        self.btn_mapper.config(state="disabled")
        self.btn_preview.config(state="disabled")

        self.body = ttk.Frame(root)
        self.body.pack(fill="both", expand=True)

        # Instantiate views once
        self.setup_view = SetupView(self.body, self)
        self.mapper_view = MapperView(self.body, self)
        self.preview_view = PreviewView(self.body, self)

        self.setup_view.pack(fill="both", expand=True)
        # mapper/preview not packed yet

        if cli_defaults:
            self.setup_view.apply_cli_defaults(**cli_defaults)

        self.root.bind("m", lambda e: self._hotkey_preview())
        self.root.bind("M", lambda e: self._hotkey_preview())
        self.root.bind("<Escape>", lambda e: self.show_mode("mapper") if self.mode == "preview" else None)
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

        self._refresh_title()

    def _build_styles(self):
        style = ttk.Style()
        try:
            style.theme_use("clam")
        except Exception:
            pass
        style.configure("TFrame", background="#181A20")
        style.configure("Card.TFrame", background="#222530")
        style.configure("TLabel", background="#181A20", foreground="#E0E0E0")
        style.configure("Title.TLabel", font=("Helvetica", 14, "bold"), foreground="#FFFFFF", background="#181A20")
        style.configure("Header.TLabel", font=("Helvetica", 11, "bold"), foreground="#64B5F6", background="#181A20")
        style.configure("CardHeader.TLabel", background="#222530", font=("Helvetica", 12, "bold"), foreground="#90CAF9")
        style.configure("CardSub.TLabel", background="#222530", font=("Helvetica", 10), foreground="#B0B4C0")
        style.configure("Approve.TButton", font=("Helvetica", 11, "bold"), foreground="#FFFFFF", background="#2E7D32")
        style.map("Approve.TButton", background=[("active", "#388E3C")])
        style.configure("Nav.TButton", font=("Helvetica", 9), background="#333748", foreground="#E0E0E0")
        style.map("Nav.TButton", background=[("active", "#464C62")])

    def _refresh_title(self):
        pid = (self.session.profile.get("id") if self.session else None) or "idle"
        dirty = " *" if (self.session and self.session.is_dirty) else ""
        self.root.title(f"Block Mapper — {pid}{dirty}")

    def _on_dirty_changed(self, _dirty: bool):
        self._refresh_title()
        if self.preview_view.winfo_ismapped():
            self.preview_view.notify_mapping_changed()

    def _on_mapping_changed(self):
        if self.preview_view.winfo_ismapped():
            self.preview_view.notify_mapping_changed()

    def _hotkey_preview(self):
        if self.session and self.mode == "mapper":
            self.show_mode("preview")
        elif self.mode == "preview":
            self.show_mode("mapper")

    def show_mode(self, mode: str):
        if mode == self.mode:
            return
        if mode in ("mapper", "preview") and not self.session:
            messagebox.showinfo("No session", "Run Process / Run from Setup first.")
            return
        if mode == "setup" and self.session and self.session.is_dirty:
            if not self._confirm_leave_dirty():
                return

        # Hide all
        self.setup_view.pack_forget()
        self.mapper_view.pack_forget()
        self.preview_view.pack_forget()

        self.mode = mode
        if mode == "setup":
            self.setup_view.set_run_enabled(True)
            self.setup_view.pack(fill="both", expand=True)
        elif mode == "mapper":
            self.setup_view.set_run_enabled(False)
            self.mapper_view.pack(fill="both", expand=True)
        elif mode == "preview":
            self.setup_view.set_run_enabled(False)
            self.preview_view.pack(fill="both", expand=True)
            self.preview_view.rebuild_composites()

    def jump_to_g1_block(self, g1_id: int):
        self.show_mode("mapper")
        self.mapper_view.jump_to_g1(g1_id)

    def _confirm_leave_dirty(self) -> bool:
        ans = messagebox.askyesnocancel(
            "Unsaved mappings",
            "You have unsaved mappings. Export before leaving?",
        )
        if ans is None:
            return False
        if ans:
            ok = self.mapper_view.export_mapping()
            return ok or not self.session.is_dirty
        # No — discard
        if self.session:
            self.session.clear_dirty()
        return True

    def start_process_run(self, args: dict):
        if self._run_in_flight:
            return
        if self.session and self.mode != "setup":
            if not messagebox.askyesno(
                "Reprocess CV rankings?",
                "This rebuilds all CV rankings and reloads the mapper UI.\n"
                "Unsaved work is kept via session.json, but the window will blank briefly.\n\n"
                "Continue?",
            ):
                return
        if self.session and self.session.is_dirty:
            if not self._confirm_leave_dirty():
                return

        self._run_in_flight = True
        self.setup_view.set_busy(True, "Computing CV rankings… (this may take a while)")
        self._result_queue = queue.Queue()

        def worker():
            try:
                session = prepare_mapping_session(**args)
                self._result_queue.put({"ok": True, "session": session})
            except Exception as exc:  # noqa: BLE001 — must always report
                self._result_queue.put({"ok": False, "error": str(exc)})

        threading.Thread(target=worker, daemon=True).start()
        self.root.after(100, self._poll_run_queue)

    def _poll_run_queue(self):
        try:
            msg = self._result_queue.get_nowait()
        except queue.Empty:
            self.root.after(100, self._poll_run_queue)
            return

        self._run_in_flight = False
        self.setup_view.set_busy(False)
        if not msg.get("ok"):
            messagebox.showerror("Process failed", msg.get("error") or "Unknown error")
            self.setup_view.set_busy(False, "Failed — fix inputs and try again.")
            return

        self.session = msg["session"]
        self.session.on_dirty_changed = self._on_dirty_changed
        self.mapper_view.bind_session(self.session, on_mapping_changed=self._on_mapping_changed)
        self.preview_view.bind_session(self.session, mapper_view=self.mapper_view)
        self.btn_mapper.config(state="normal")
        self.btn_preview.config(state="normal")
        self._refresh_title()
        self.setup_view.set_busy(False, "Session ready.")
        self.show_mode("mapper")

    def _on_close(self):
        if self.session and self.session.is_dirty:
            if not self._confirm_leave_dirty():
                return
        self.root.destroy()


def launch_shell(cli_defaults: dict | None = None):
    root = tk.Tk()
    BlockMapperShell(root, cli_defaults=cli_defaults)
    root.mainloop()
