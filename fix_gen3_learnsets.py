#!/usr/bin/env python3
"""Rewrite Gen 2/3 species level-up learnsets in pokemon_data.lua to Gen 3
timing (Emerald → RSE → FRLG). Does NOT touch sprites, palettes, or TMs.

Usage (from repo root or this folder):
  python3 mods/Kanto-Reforged/fix_gen3_learnsets.py
"""

from __future__ import annotations

import os
import re
import sys
import time

MOD_ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, MOD_ROOT)

from generate_pokemon_mod import (  # noqa: E402
    fetch_json,
    remap_move,
)

LUA_PATH = os.path.join(MOD_ROOT, "pokemon_data.lua")

# Gen 3 version groups, preferred order (Emerald has the full Gen 2+3 set).
GEN3_VGS = ("emerald", "ruby-sapphire", "firered-leafgreen")

DEX_MIN, DEX_MAX = 152, 386


def species_slug(species_id: str) -> str:
    return species_id.lower().replace("_", "-")


def fetch_gen3_learnset(dex: int, species_id: str):
    """Return (learnset_rows, evolution_moves) for Gen 3 only."""
    slug = species_slug(species_id)
    # Prefer dex-number cache names the generator uses, fall back to slug.
    poke = None
    for name in (str(dex), slug):
        try:
            poke = fetch_json(
                f"https://pokeapi.co/api/v2/pokemon/{name}",
                "pokemon",
                name,
            )
            break
        except Exception:
            poke = None
    if not poke:
        raise RuntimeError(f"could not fetch pokemon {species_id} (#{dex})")

    by_vg = {vg: {} for vg in GEN3_VGS}  # move -> level
    evo_moves = set()

    for move_entry in poke.get("moves") or []:
        raw = move_entry["move"]["name"].upper().replace("-", "_")
        m_name = remap_move(raw)
        for detail in move_entry.get("version_group_details") or []:
            if detail["move_learn_method"]["name"] != "level-up":
                continue
            vg = detail["version_group"]["name"]
            if vg not in by_vg:
                continue
            level = detail["level_learned_at"]
            if level == 0:
                evo_moves.add(m_name)
                continue
            # Keep earliest level if a vg lists the move twice
            prev = by_vg[vg].get(m_name)
            if prev is None or level < prev:
                by_vg[vg][m_name] = level

    chosen = None
    chosen_vg = None
    for vg in GEN3_VGS:
        if by_vg[vg]:
            chosen = by_vg[vg]
            chosen_vg = vg
            break
    if not chosen:
        raise RuntimeError(f"no Gen 3 level-up moves for {species_id}")

    learnset = [{"level": lvl, "move": mv} for mv, lvl in chosen.items()]
    learnset.sort(key=lambda e: (e["level"], e["move"]))
    return learnset, sorted(evo_moves), chosen_vg


def format_learnset(learnset):
    lines = ["    learnset = {"]
    for e in learnset:
        lines.append(f'      {{ level = {e["level"]}, move = "{e["move"]}" }},')
    lines.append("    },")
    return "\n".join(lines)


def format_level1(learnset):
    moves = [e["move"] for e in learnset if e["level"] == 1]
    if not moves:
        moves = [learnset[0]["move"]] if learnset else ["TACKLE"]
    # Dedup preserve order
    seen, out = set(), []
    for m in moves:
        if m not in seen:
            seen.add(m)
            out.append(m)
    lines = ["    level1Moves = {"]
    for m in out:
        lines.append(f'      "{m}",')
    lines.append("    },")
    return "\n".join(lines)


def format_evolution_moves(moves):
    lines = ["    evolutionMoves = {"]
    for m in moves:
        lines.append(f'      "{m}",')
    lines.append("    },")
    return "\n".join(lines)


SPECIES_HEADER = re.compile(
    r'^  ([A-Z0-9_]+) = \{\n'
    r'    id = "\1", name = "[^"]+", dex = (\d+),',
    re.M,
)


def split_species_blocks(text: str):
    """Yield (start, end, species_id, dex, block) for each species table."""
    # Find species = { markers inside PokemonData.species
    starts = []
    for m in re.finditer(r'\n  ([A-Z0-9_]+) = \{\n    id = "\1"', text):
        starts.append((m.start() + 1, m.group(1), m.start() + 1))
    # Also capture dex from nearby
    results = []
    for i, (pos, sid, _) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else None
        # Find end of this species: next top-level `  NAME = {` or end of species table
        if end is None:
            # species table closes with `\n}\n` before evolutions or return
            close = re.search(r'\n\}\n\nPokemonData\.|^\}\n', text[pos:], re.M)
            end = pos + close.start() + 1 if close else len(text)
        block = text[pos:end]
        dm = re.search(r'dex = (\d+)', block)
        if not dm:
            continue
        results.append((pos, end, sid, int(dm.group(1)), block))
    return results


def replace_field(block: str, field: str, new_text: str) -> str:
    """Replace `field = { ... },` (brace-balanced) with new_text."""
    marker = f"    {field} = {{"
    idx = block.find(marker)
    if idx < 0:
        raise RuntimeError(f"missing {field}")
    i = idx + len(marker) - 1  # at '{'
    depth = 0
    for j in range(i, len(block)):
        c = block[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                # consume trailing comma/newline
                end = j + 1
                if end < len(block) and block[end] == ",":
                    end += 1
                if end < len(block) and block[end] == "\n":
                    end += 1
                return block[:idx] + new_text + "\n" + block[end:]
    raise RuntimeError(f"unbalanced {field}")


def main():
    text = open(LUA_PATH, encoding="utf-8").read()
    blocks = split_species_blocks(text)
    targets = [(p, e, s, d, b) for p, e, s, d, b in blocks if DEX_MIN <= d <= DEX_MAX]
    print(f"Rewriting Gen 3 learnsets for {len(targets)} species (#{DEX_MIN}–#{DEX_MAX})")
    print("Sprites/palettes untouched.\n")

    # Rebuild from the end so offsets stay valid
    new_text = text
    stats = {"ok": 0, "fail": 0, "vg": {}}
    failures = []

    for pos, end, sid, dex, block in reversed(targets):
        try:
            learnset, evo_moves, vg = fetch_gen3_learnset(dex, sid)
            stats["vg"][vg] = stats["vg"].get(vg, 0) + 1
            updated = block
            updated = replace_field(updated, "level1Moves", format_level1(learnset))
            updated = replace_field(updated, "learnset", format_learnset(learnset))
            # Only rewrite evolutionMoves when the field already exists
            if "    evolutionMoves = {" in updated:
                updated = replace_field(
                    updated, "evolutionMoves", format_evolution_moves(evo_moves)
                )
            new_text = new_text[:pos] + updated + new_text[end:]
            stats["ok"] += 1
            multi = {}
            for row in learnset:
                multi.setdefault(row["level"], []).append(row["move"])
            bad = {lv: m for lv, m in multi.items() if len(m) > 1}
            # Gen 3 legitimately teaches multiple moves at one level rarely
            # (e.g. some L1 starters). Flag 3+ as noteworthy only.
            if any(len(m) >= 3 for m in bad.values()):
                print(f"  note #{dex} {sid}: multi @ { {lv: len(m) for lv,m in bad.items()} } via {vg}")
            if stats["ok"] % 40 == 0:
                print(f"  … {stats['ok']}/{len(targets)}")
            time.sleep(0.01)  # be kind if cache misses
        except Exception as ex:
            stats["fail"] += 1
            failures.append((dex, sid, str(ex)))
            print(f"  FAIL #{dex} {sid}: {ex}")

    open(LUA_PATH, "w", encoding="utf-8").write(new_text)
    print(f"\nWrote {LUA_PATH}")
    print(f"OK={stats['ok']} FAIL={stats['fail']} version groups={stats['vg']}")
    if failures:
        print("Failures:")
        for dex, sid, err in failures:
            print(f"  #{dex} {sid}: {err}")
        sys.exit(1)


if __name__ == "__main__":
    main()
