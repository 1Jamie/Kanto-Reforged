#!/usr/bin/env python3
"""Generate Gen3 learnsets for dex #1–386 (Emerald → RSE → FRLG per species).

Writes pokemon/learnset_gen3.lua for runtime apply on both Red and Gold hosts.
Does NOT touch sprites, palettes, or stats.

Usage (from repo root or mod tools/):
  python3 mods/Kanto-Reforged/tools/gen3_learnsets.py
  python3 mods/Kanto-Reforged/tools/gen3_learnsets.py --check
  python3 mods/Kanto-Reforged/tools/gen3_learnsets.py --sync-pokemon-data-learnsets
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
MOD_ROOT = os.path.dirname(TOOLS_DIR)
sys.path.insert(0, TOOLS_DIR)

from generate_pokemon_mod import (  # noqa: E402
    MOD_ROOT as GEN_MOD_ROOT,
    PATH_POKEMON_DATA,
    fetch_json,
    load_kanto_reforged_move_powers,
    load_vanilla_moves,
    mod_data_path,
    remap_move,
)

GEN3_VGS = ("emerald", "ruby-sapphire", "firered-leafgreen")
DEX_MIN, DEX_MAX = 1, 386
TM_LEARN_LEVEL = 30
GENERIC_TM = {
    "FACADE", "SECRET_POWER", "HIDDEN_POWER", "RETURN", "FRUSTRATION",
    "SNORE", "MUD_SLAP", "HEADBUTT", "ROCK_SMASH", "STRENGTH",
    "CUT", "FLASH", "WHIRLPOOL", "DIVE", "ROCK_CLIMB",
}
RUNTIME_OUT = os.path.join(MOD_ROOT, "pokemon", "learnset_gen3.lua")
POKEMON_DATA_PATH = mod_data_path(MOD_ROOT, PATH_POKEMON_DATA)

GUARDED_SPRITE_KEYS = (
    "spriteFront", "spriteBack", "palette", "picSize", "frontSize", "backPalette",
)

# Spot-check species for --check (dex, species_id, move, level)
CHECK_ROWS = [
    (50, "DIGLETT", "GROWL", 5),
    (50, "DIGLETT", "MAGNITUDE", 9),
    (50, "DIGLETT", "DIG", 17),
    (25, "PIKACHU", "IRON_TAIL", 30),
    (152, "CHIKORITA", "RAZOR_LEAF", 8),
]


def repo_root() -> str:
    return os.path.dirname(os.path.dirname(GEN_MOD_ROOT))


def load_registered_moves() -> set[str]:
    moves = set(load_vanilla_moves(repo_root()))
    path = POKEMON_DATA_PATH
    if not os.path.exists(path):
        return moves
    in_moves = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("P.moves"):
                in_moves = True
                continue
            if in_moves and line.startswith("}"):
                break
            if in_moves:
                stripped = line.strip()
                if stripped.endswith("= {") and stripped[0].isupper():
                    moves.add(stripped.split("=")[0].strip())
    return moves


def fetch_pokemon(dex: int, species_id: str) -> dict:
    slug = species_id.lower().replace("_", "-")
    for name in (str(dex), slug):
        try:
            return fetch_json(
                f"https://pokeapi.co/api/v2/pokemon/{name}",
                "pokemon",
                name,
            )
        except Exception:
            pass
    raise RuntimeError(f"could not fetch #{dex} {species_id}")


def level_up_by_vg(poke_data: dict) -> dict[str, dict[str, int]]:
    by_vg = {vg: {} for vg in GEN3_VGS}
    for move_entry in poke_data.get("moves") or []:
        raw = move_entry["move"]["name"].upper().replace("-", "_")
        m_name = remap_move(raw)
        for detail in move_entry.get("version_group_details") or []:
            if detail["move_learn_method"]["name"] != "level-up":
                continue
            vg = detail["version_group"]["name"]
            if vg not in by_vg:
                continue
            level = detail["level_learned_at"]
            if level <= 0:
                continue
            prev = by_vg[vg].get(m_name)
            if prev is None or level < prev:
                by_vg[vg][m_name] = level
    return by_vg


def pick_version_group(poke_data: dict) -> tuple[str, dict[str, int]]:
    by_vg = level_up_by_vg(poke_data)
    for vg in GEN3_VGS:
        if by_vg[vg]:
            return vg, by_vg[vg]
    raise RuntimeError("no Gen3 level-up data")


def collect_level_up_rows(level_map: dict[str, int]) -> list[dict]:
    rows = [{"level": lvl, "move": mv} for mv, lvl in level_map.items()]
    rows.sort(key=lambda e: (e["level"], e["move"]))
    return rows


def collect_evolution_moves(poke_data: dict, vg: str) -> list[str]:
    out = set()
    for move_entry in poke_data.get("moves") or []:
        raw = move_entry["move"]["name"].upper().replace("-", "_")
        m_name = remap_move(raw)
        for detail in move_entry.get("version_group_details") or []:
            if detail["move_learn_method"]["name"] != "level-up":
                continue
            if detail["version_group"]["name"] != vg:
                continue
            if detail["level_learned_at"] == 0:
                out.add(m_name)
    return sorted(out)


def collect_tmhm(poke_data: dict, vg: str) -> set[str]:
    out: set[str] = set()
    for move_entry in poke_data.get("moves") or []:
        raw = move_entry["move"]["name"].upper().replace("-", "_")
        m_name = remap_move(raw)
        for detail in move_entry.get("version_group_details") or []:
            if detail["move_learn_method"]["name"] != "machine":
                continue
            if detail["version_group"]["name"] != vg:
                continue
            out.add(m_name)
    return out


def split_learnset(all_rows: list[dict]) -> tuple[list[str], list[dict]]:
    level1 = []
    learnset = []
    for row in all_rows:
        if row["level"] == 1:
            if row["move"] not in level1:
                level1.append(row["move"])
        else:
            learnset.append({"level": row["level"], "move": row["move"]})
    if not level1 and learnset:
        level1 = [learnset[0]["move"]]
        learnset = learnset[1:]
    if not level1:
        level1 = ["TACKLE"]
    return level1, learnset


def filter_known_moves(
    level1: list[str],
    learnset: list[dict],
    evo: list[str],
    tmhm: list[str],
    known: set[str],
) -> tuple[list[str], list[dict], list[str], list[str], int]:
    dropped = 0

    def keep_move(m: str) -> bool:
        return m in known

    out_l1 = []
    for m in level1:
        if keep_move(m):
            out_l1.append(m)
        else:
            dropped += 1

    out_ls = []
    for row in learnset:
        if keep_move(row["move"]):
            out_ls.append(row)
        else:
            dropped += 1

    out_evo = []
    for m in evo:
        if keep_move(m):
            out_evo.append(m)
        else:
            dropped += 1

    out_tm = []
    for m in tmhm:
        if keep_move(m):
            out_tm.append(m)
        else:
            dropped += 1

    return out_l1, out_ls, out_evo, out_tm, dropped


def natural_level_moves(
    level1: list[str], learnset: list[dict], evo: list[str]
) -> set[str]:
    s = set(level1) | set(evo)
    for row in learnset:
        s.add(row["move"])
    return s


def add_pragmatic_backports(
    learnset: list[dict],
    tmhm: list[str],
    natural: set[str],
    move_powers: dict[str, int],
) -> list[dict]:
    level_up = {row["move"] for row in learnset}
    candidates = []
    for m in tmhm:
        if m in natural or m in level_up or m in GENERIC_TM:
            continue
        power = move_powers.get(m, 0)
        if power < 60:
            continue
        candidates.append((power, m))
    candidates.sort(key=lambda kv: (-kv[0], kv[1]))
    out = list(learnset)
    for _, m in candidates[:4]:
        if m in natural or any(r["move"] == m for r in out):
            continue
        out.append({"level": TM_LEARN_LEVEL, "move": m})
    out.sort(key=lambda e: (e["level"], e["move"]))
    return out


def build_species_record(
    dex: int,
    species_id: str,
    known: set[str],
    move_powers: dict[str, int],
) -> tuple[dict, str, int]:
    poke = fetch_pokemon(dex, species_id)
    vg, level_map = pick_version_group(poke)
    all_rows = collect_level_up_rows(level_map)
    evo_raw = collect_evolution_moves(poke, vg)
    tmhm_raw = sorted(collect_tmhm(poke, vg))

    level1, learnset = split_learnset(all_rows)
    learnset = add_pragmatic_backports(learnset, tmhm_raw, natural_level_moves(level1, learnset, evo_raw), move_powers)

    level1, learnset, evo, tmhm, dropped = filter_known_moves(
        level1, learnset, evo_raw, tmhm_raw, known
    )

    return {
        "level1Moves": level1,
        "learnset": learnset,
        "evolutionMoves": evo,
        "tmhm": tmhm,
    }, vg, dropped


def early_damaging_count(level1: list[str], learnset: list[dict], move_powers: dict[str, int]) -> int:
    n = 0
    for m in level1:
        if move_powers.get(m, 0) > 0:
            n += 1
    for row in learnset:
        if row["level"] <= 20 and move_powers.get(row["move"], 0) > 0:
            n += 1
    return n


def write_runtime_lua(path: str, species: dict[str, dict]) -> None:
    print(f"Writing {path}...")
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- Generated Gen3 learnsets for dex #1–386\n")
        f.write("-- Source: PokeAPI (Emerald → RSE → FRLG per species)\n")
        f.write("-- Regenerate: python3 mods/Kanto-Reforged/tools/gen3_learnsets.py\n")
        f.write("local P = {}\n\n")
        f.write("P.species = {\n")
        for sid in sorted(species.keys()):
            rec = species[sid]
            f.write(f"  {sid} = {{\n")
            f.write("    level1Moves = {\n")
            for mv in rec["level1Moves"]:
                f.write(f'      {json.dumps(mv)},\n')
            f.write("    },\n")
            f.write("    learnset = {\n")
            for row in rec["learnset"]:
                f.write(
                    f'      {{ level = {row["level"]}, move = {json.dumps(row["move"])} }},\n'
                )
            f.write("    },\n")
            f.write("    evolutionMoves = {\n")
            for mv in rec["evolutionMoves"]:
                f.write(f'      {json.dumps(mv)},\n')
            f.write("    },\n")
            f.write("    tmhm = {\n")
            for mv in rec["tmhm"]:
                f.write(f'      {json.dumps(mv)},\n')
            f.write("    },\n")
            f.write("  },\n")
        f.write("}\n\nreturn P\n")


def format_level1_lua(moves: list[str]) -> str:
    lines = ["    level1Moves = {"]
    for m in moves:
        lines.append(f'      "{m}",')
    lines.append("    },")
    return "\n".join(lines)


def format_learnset_lua(learnset: list[dict]) -> str:
    lines = ["    learnset = {"]
    for e in learnset:
        lines.append(f'      {{ level = {e["level"]}, move = "{e["move"]}" }},')
    lines.append("    },")
    return "\n".join(lines)


def format_evo_lua(moves: list[str]) -> str:
    lines = ["    evolutionMoves = {"]
    for m in moves:
        lines.append(f'      "{m}",')
    lines.append("    },")
    return "\n".join(lines)


def format_tmhm_lua(moves: list[str]) -> str:
    lines = ["    tmhm = {"]
    for m in moves:
        lines.append(f'      "{m}",')
    lines.append("    },")
    return "\n".join(lines)


def split_species_blocks(text: str):
    starts = []
    for m in re.finditer(r'\n  ([A-Z0-9_]+) = \{\n    id = "\1"', text):
        starts.append((m.start() + 1, m.group(1)))
    results = []
    for i, (pos, sid) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else None
        if end is None:
            close = re.search(r'\n\}\n\nP\.', text[pos:], re.M)
            end = pos + close.start() + 1 if close else len(text)
        block = text[pos:end]
        dm = re.search(r"dex = (\d+)", block)
        if not dm:
            continue
        results.append((pos, end, sid, int(dm.group(1)), block))
    return results


def replace_field(block: str, field: str, new_text: str) -> str:
    marker = f"    {field} = {{"
    idx = block.find(marker)
    if idx < 0:
        raise RuntimeError(f"missing {field}")
    i = idx + len(marker) - 1
    depth = 0
    for j in range(i, len(block)):
        c = block[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                end = j + 1
                if end < len(block) and block[end] == ",":
                    end += 1
                if end < len(block) and block[end] == "\n":
                    end += 1
                return block[:idx] + new_text + "\n" + block[end:]
    raise RuntimeError(f"unbalanced {field}")


def sync_pokemon_data(species: dict[str, dict]) -> None:
    if not os.path.exists(POKEMON_DATA_PATH):
        print(f"Skip sync: {POKEMON_DATA_PATH} missing")
        return
    text = open(POKEMON_DATA_PATH, encoding="utf-8").read()
    blocks = split_species_blocks(text)
    targets = [(p, e, s, d, b) for p, e, s, d, b in blocks if DEX_MIN <= d <= DEX_MAX]
    new_text = text
    n = 0
    for pos, end, sid, dex, block in reversed(targets):
        rec = species.get(sid)
        if not rec:
            continue
        updated = block
        updated = replace_field(updated, "level1Moves", format_level1_lua(rec["level1Moves"]))
        # learnset in pokemon_data includes L1 rows historically
        merged = [{"level": 1, "move": m} for m in rec["level1Moves"]]
        merged.extend(rec["learnset"])
        updated = replace_field(updated, "learnset", format_learnset_lua(merged))
        if "    evolutionMoves = {" in updated:
            updated = replace_field(
                updated, "evolutionMoves", format_evo_lua(rec["evolutionMoves"])
            )
        if "    tmhm = {" in updated:
            updated = replace_field(updated, "tmhm", format_tmhm_lua(rec["tmhm"]))
        new_text = new_text[:pos] + updated + new_text[end:]
        n += 1
    open(POKEMON_DATA_PATH, "w", encoding="utf-8").write(new_text)
    print(f"Synced learnset fields for {n} species in pokemon_data.lua")


def assert_sprite_guard() -> None:
    import subprocess

    diff = subprocess.run(
        ["git", "diff", "--", "mods/Kanto-Reforged/pokemon/pokemon_data.lua"],
        cwd=repo_root(),
        capture_output=True,
        text=True,
    )
    if diff.returncode != 0:
        return
    for key in GUARDED_SPRITE_KEYS:
        if re.search(rf"^[+-].*{re.escape(key)}", diff.stdout, re.M):
            raise SystemExit(
                f"sync guard failed: pokemon_data.lua diff touches {key}"
            )


def generate_all(known: set[str], move_powers: dict[str, int]) -> dict[str, dict]:
    species: dict[str, dict] = {}
    total_dropped = 0
    sparse_warn = []
    vg_counts: dict[str, int] = {}

    for dex in range(DEX_MIN, DEX_MAX + 1):
        try:
            poke = fetch_pokemon(dex, str(dex))
            sid = poke["name"].upper().replace("-", "_")
            rec, vg, dropped = build_species_record(dex, sid, known, move_powers)
            species[sid] = rec
            total_dropped += dropped
            vg_counts[vg] = vg_counts.get(vg, 0) + 1
            if dropped:
                print(f"  #{dex} {sid}: dropped {dropped} unknown move(s) via {vg}")
            if early_damaging_count(rec["level1Moves"], rec["learnset"], move_powers) == 0:
                sparse_warn.append(f"#{dex} {sid}")
            if dex % 50 == 0:
                print(f"  … {dex}/{DEX_MAX}")
            time.sleep(0.005)
        except Exception as ex:
            print(f"  FAIL #{dex}: {ex}")

    print(f"\nSpecies OK: {len(species)}/{DEX_MAX - DEX_MIN + 1}")
    print(f"Total moves dropped (unknown): {total_dropped}")
    print(f"Version groups: {vg_counts}")
    if sparse_warn:
        print(f"WARN no damaging move by L20: {', '.join(sparse_warn[:20])}"
              + (" …" if len(sparse_warn) > 20 else ""))
    return species


def run_check(species: dict[str, dict]) -> None:
    fails = []
    for dex, sid, move, level in CHECK_ROWS:
        rec = species.get(sid)
        if not rec:
            fails.append(f"missing {sid}")
            continue
        if level == 1:
            if move not in rec["level1Moves"]:
                fails.append(f"{sid} L1 {move}")
            continue
        found = None
        for row in rec["learnset"]:
            if row["move"] == move:
                found = row["level"]
                break
        if found != level:
            fails.append(f"{sid} {move} expected L{level} got L{found}")
    if fails:
        raise SystemExit("check failed:\n  " + "\n  ".join(fails))
    print("check: OK")


def main() -> None:
    parser = argparse.ArgumentParser(description="Gen3 learnset generator (#1–386)")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate curated species after generation",
    )
    parser.add_argument(
        "--sync-pokemon-data-learnsets",
        action="store_true",
        help="Optional: rewrite learnset fields in pokemon_data.lua (#152–386 only)",
    )
    args = parser.parse_args()

    known = load_registered_moves()
    move_powers = load_kanto_reforged_move_powers(MOD_ROOT)
    for m in known:
        move_powers.setdefault(m, 40)

    print(f"Generating Gen3 learnsets #{DEX_MIN}–#{DEX_MAX} ({len(known)} known moves)\n")
    species = generate_all(known, move_powers)
    if len(species) < DEX_MAX - 10:
        raise SystemExit(f"too many failures: only {len(species)} species")

    write_runtime_lua(RUNTIME_OUT, species)
    if args.check:
        run_check(species)
    if args.sync_pokemon_data_learnsets:
        sync_pokemon_data(species)
        assert_sprite_guard()
        print("sync guard: no sprite/palette lines in diff")


if __name__ == "__main__":
    main()
