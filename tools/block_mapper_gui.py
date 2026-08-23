#!/usr/bin/env python3
r"""
block_mapper_gui.py — thin entry for the in-UI block mapper shell.

Usage:
  python3 block_mapper_gui.py
  python3 block_mapper_gui.py --profile cavern_cave
  python3 block_mapper_gui.py --list-profiles
"""

from __future__ import annotations

import argparse
import os
import sys

_TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from block_mapper_profiles import list_profiles  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description="In-UI Gen1→Gen2 Block Mapper (Setup / Mapper / Preview)")
    parser.add_argument("--profile", default="safari_kanto", help=f"Pre-select profile ({', '.join(list_profiles())})")
    parser.add_argument("--g1", default=None, help="Override Gen 1 blockset sheet")
    parser.add_argument("--g2", default=None, help="Override Gen 2 blockset sheet")
    parser.add_argument("--out", default=None, help="Override output mapping .py path")
    parser.add_argument("--dict-name", default=None, help="Override export dictionary name")
    parser.add_argument("--include-buildings", action="store_true", help="Include building pieces in the pool")
    parser.add_argument("--list-profiles", action="store_true", help="List profiles and exit")
    args = parser.parse_args()

    if args.list_profiles:
        for p in list_profiles():
            print(p)
        return

    try:
        import tkinter as tk  # noqa: F401
    except ImportError:
        print("Error: Tkinter is required.")
        sys.exit(1)

    from block_mapper.shell import launch_shell

    launch_shell(
        cli_defaults={
            "profile_id": args.profile,
            "g1": args.g1,
            "g2": args.g2,
            "out": args.out,
            "dict_name": args.dict_name,
            "include_buildings": True if args.include_buildings else None,
        }
    )


if __name__ == "__main__":
    main()
