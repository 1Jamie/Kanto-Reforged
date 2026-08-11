#!/usr/bin/env python3
"""Dump FRLG Sevii trainer parties to JSON without expanding C macros.

Scans trainer_parties.h for TrainerMon* initializer bodies (`.species`,
`.lvl`, optional `.heldItem` / `.moves`) and joins them to trainers.h via
`.party = sParty_Name` symbols.

  python3 tools/dump_frlg_sevii_trainers.py --pokefirered /path/to/pokefirered \\
      -o sevii/frlg_trainers.json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

MOD_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PARTY_START = re.compile(
    r"static\s+const\s+struct\s+TrainerMon\w*\s+(sParty_\w+)\s*\[\s*\]\s*=\s*\{"
)
FIELD_SPECIES = re.compile(r"\.species\s*=\s*(SPECIES_\w+)")
FIELD_LVL = re.compile(r"\.lvl\s*=\s*(\d+)")
FIELD_HELD = re.compile(r"\.heldItem\s*=\s*(ITEM_\w+)")
FIELD_MOVES = re.compile(r"\.moves\s*=\s*\{([^}]+)\}")
TRAINER_BLOCK = re.compile(
    r"\[(TRAINER_\w+)\]\s*=\s*\{(.*?)\n\s*\},",
    re.S,
)
PARTY_REF = re.compile(r"\.party\s*=\s*\w+\(?(sParty_\w+)\)?")
CLASS_REF = re.compile(r"\.trainerClass\s*=\s*(TRAINER_CLASS_\w+)")
NAME_REF = re.compile(r'\.trainerName\s*=\s*_?\("([^"]*)"\)')


def parse_parties(text: str) -> dict[str, list[dict]]:
    parties: dict[str, list[dict]] = {}
    for m in PARTY_START.finditer(text):
        name = m.group(1)
        start = m.end()
        # Brace depth from the opening `{` already consumed by regex… we are
        # inside the array; find matching close at depth 0.
        depth = 1
        i = start
        while i < len(text) and depth:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        body = text[start:i - 1]
        mons = []
        # Split on top-level struct opens
        for mon_m in re.finditer(r"\{([^{}]*(\{[^{}]*\}[^{}]*)*)\}", body):
            chunk = mon_m.group(0)
            sp = FIELD_SPECIES.search(chunk)
            lv = FIELD_LVL.search(chunk)
            if not sp or not lv:
                continue
            mon: dict = {
                "species": sp.group(1),
                "level": int(lv.group(1)),
            }
            held = FIELD_HELD.search(chunk)
            if held:
                mon["heldItem"] = held.group(1)
            moves = FIELD_MOVES.search(chunk)
            if moves:
                mon["moves"] = [
                    x.strip() for x in moves.group(1).split(",") if x.strip() and x.strip() != "MOVE_NONE"
                ]
            mons.append(mon)
        parties[name] = mons
    return parties


def parse_trainers(text: str, parties: dict[str, list[dict]]) -> list[dict]:
    out = []
    for m in TRAINER_BLOCK.finditer(text):
        tid = m.group(1)
        body = m.group(2)
        pref = PARTY_REF.search(body)
        if not pref:
            continue
        pname = pref.group(1)
        party = parties.get(pname)
        if party is None:
            continue
        cls = CLASS_REF.search(body)
        name = NAME_REF.search(body)
        # Keep Sevii-ish trainers: name heuristics + known island strings
        blob = tid + " " + (name.group(1) if name else "") + " " + pname
        sevii_hint = any(
            k in blob.upper()
            for k in (
                "ISLAND", "EMBER", "KINDLE", "SEVII", "RUIN", "TANOBY",
                "SEVAULT", "ICEFALL", "BERRY_FOREST", "LOST_CAVE", "NAVEL",
                "BIRTH", "TRAINER_TOWER", "DOTTED", "PATTERN", "OUTCAST",
                "WATER_PATH", "GREEN_PATH", "RESORT", "MEMORIAL", "MEADOW",
                "BOND_BRIDGE", "CAPE_BRINK", "TREASURE",
            )
        )
        if not sevii_hint:
            continue
        out.append({
            "id": tid,
            "trainerClass": (cls.group(1) if cls else "TRAINER_CLASS_COOLTRAINER_M"),
            "displayName": name.group(1) if name else tid.replace("TRAINER_", ""),
            "partySymbol": pname,
            "party": party,
        })
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pokefirered", required=True)
    ap.add_argument("-o", "--output", default=os.path.join(MOD_ROOT, "sevii", "frlg_trainers.json"))
    args = ap.parse_args()

    parties_h = os.path.join(args.pokefirered, "src", "data", "trainer_parties.h")
    trainers_h = os.path.join(args.pokefirered, "src", "data", "trainers.h")
    if not os.path.isfile(parties_h) or not os.path.isfile(trainers_h):
        print("trainer_parties.h / trainers.h not found; writing empty dump", file=sys.stderr)
        os.makedirs(os.path.dirname(args.output), exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump({"trainers": [], "note": "headers missing"}, f, indent=2)
            f.write("\n")
        return

    parties = parse_parties(open(parties_h, encoding="utf-8", errors="replace").read())
    trainers = parse_trainers(open(trainers_h, encoding="utf-8", errors="replace").read(), parties)
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump({"trainers": trainers, "partyCount": len(parties)}, f, indent=2)
        f.write("\n")
    print(f"Wrote {args.output} ({len(trainers)} sevii-hint trainers, {len(parties)} party arrays)")


if __name__ == "__main__":
    main()
