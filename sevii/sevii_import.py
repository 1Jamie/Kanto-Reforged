#!/usr/bin/env python3
"""FRLG Sevii → Kanto-Reforged content importer.

Pulls topology + wild encounters from a pokefirered checkout (or partial
snip), remaps through Gen 1 / KR allowlists, and emits Lua/JSON under sevii/.

  python3 sevii_import.py --pokefirered /path/to/pokefirered
  python3 sevii_import.py --pokefirered /path --encounters-only
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request
from collections import defaultdict
from typing import Any

MOD_ROOT = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(MOD_ROOT))
DEFAULT_OUTDIR = os.path.join(MOD_ROOT, "sevii")

WILD_JSON_URL = (
    "https://raw.githubusercontent.com/pret/pokefirered/master/"
    "src/data/wild_encounters.json"
)

# FRLG land_mons weights (12 slots). Water default when count == 5.
LAND_WEIGHTS = [20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1]
WATER_WEIGHTS_5 = [60, 30, 5, 4, 1]
GEN1_BUCKET_PCT = [20, 20, 15, 10, 10, 10, 5, 5, 4, 1]

# Pure GBA padding / unused prototypes — compress may drop these.
PADDING_MAPS = {
    "Prototype_SeviiIsle_6",
    "Prototype_SeviiIsle_7",
    "Prototype_SeviiIsle_8",
    "Prototype_SeviiIsle_9",
    "SixIsland_GreenPath",
    "SixIsland_WaterPath",
    "FiveIsland_WaterLabyrinth",
}

# Never drop under --compress (landmarks / hubs / quest spine).
KEEP_ALWAYS = {
    "OneIsland", "TwoIsland", "ThreeIsland", "FourIsland", "FiveIsland",
    "SixIsland", "SevenIsland",
    "OneIsland_KindleRoad", "OneIsland_TreasureBeach", "OneIsland_Harbor",
    "TwoIsland_CapeBrink", "TwoIsland_Harbor",
    "ThreeIsland_BondBridge", "ThreeIsland_Port", "ThreeIsland_Harbor",
    "ThreeIsland_BerryForest",
    "MtEmber_Exterior", "MtEmber_Summit", "MtEmber_RubyPath_1F",
    "FourIsland_IcefallCave_Entrance", "FourIsland_Harbor",
    "FiveIsland_LostCave_Entrance", "FiveIsland_RocketWarehouse",
    "FiveIsland_Meadow", "FiveIsland_ResortGorgeous", "FiveIsland_MemorialPillar",
    "FiveIsland_Harbor",
    "SixIsland_OutcastIsland", "SixIsland_RuinValley", "SixIsland_Harbor",
    "SixIsland_PatternBush", "SixIsland_DottedHole_SapphireRoom",
    "SevenIsland_SevaultCanyon", "SevenIsland_TanobyRuins",
    "SevenIsland_Harbor", "SevenIsland_TrainerTower",
    "BirthIsland_Exterior", "BirthIsland_Harbor",
    "NavelRock_Exterior", "NavelRock_Harbor",
}

DIR_MAP = {
    "up": "north", "down": "south", "left": "west", "right": "east",
    "north": "north", "south": "south", "east": "east", "west": "west",
}

# Tight Gen 1 peers only; everything else → SEVII_* + basePic.
CLASS_MAP = {
    "YOUNGSTER": "OPP_YOUNGSTER",
    "BUG_CATCHER": "OPP_BUG_CATCHER",
    "LASS": "OPP_LASS",
    "SAILOR": "OPP_SAILOR",
    "HIKER": "OPP_HIKER",
    "FISHERMAN": "OPP_FISHER",
    "FISHER": "OPP_FISHER",
    "SWIMMER_M": "OPP_SWIMMER",
    "SWIMMER_F": "OPP_SWIMMER",
    "COOLTRAINER_M": "OPP_COOLTRAINER_M",
    "COOLTRAINER_F": "OPP_COOLTRAINER_F",
    "ROCKET": "OPP_ROCKET",
    "SUPER_NERD": "OPP_SUPER_NERD",
}

CLASS_BASEPIC = {
    "AROMA_LADY": "OPP_LASS",
    "RUIN_MANIAC": "OPP_HIKER",
    "PAINTER": "OPP_LASS",
    "TUBER_M": "OPP_YOUNGSTER",
    "TUBER_F": "OPP_LASS",
    "PKMN_BREEDER": "OPP_LASS",
    "PKMN_RANGER_M": "OPP_COOLTRAINER_M",
    "PKMN_RANGER_F": "OPP_COOLTRAINER_F",
    "GENTLEMAN": "OPP_GENTLEMAN",
    "LADY": "OPP_LASS",
    "RICH_BOY": "OPP_YOUNGSTER",
    "CRUSH_GIRL": "OPP_LASS",
    "CRUSH_KIN": "OPP_COOLTRAINER_M",
    "BIRD_KEEPER": "OPP_BIRD_KEEPER",
    "PSYCHIC_M": "OPP_PSYCHIC_TR",
    "PSYCHIC_F": "OPP_PSYCHIC_TR",
    "JUGGLER": "OPP_JUGGLER",
    "TAMER": "OPP_TAMER",
    "ENGINEER": "OPP_ENGINEER",
    "SCIENTIST": "OPP_SCIENTIST",
    "BIKER": "OPP_BIKER",
    "BURGLAR": "OPP_BURGLAR",
    "CUE_BALL": "OPP_CUE_BALL",
    "GAMBLER": "OPP_GAMBLER",
    "BEAUTY": "OPP_BEAUTY",
    "CHANNELER": "OPP_CHANNELER",
}


def load_species_allowlist(repo_root: str, mod_root: str) -> set[str]:
    ids: set[str] = set()
    van = os.path.join(repo_root, "data", "generated", "pokemon.lua")
    if os.path.isfile(van):
        text = open(van, encoding="utf-8").read()
        ids.update(re.findall(r"^\s{2}([A-Z][A-Z0-9_]*)\s*=\s*\{", text, re.M))
    kr = os.path.join(mod_root, "pokemon_data.lua")
    if os.path.isfile(kr):
        text = open(kr, encoding="utf-8").read()
        m = re.search(r"P\.species\s*=\s*\{(.*?)\n\}", text, re.S)
        if m:
            ids.update(re.findall(r"^\s{2}([A-Z][A-Z0-9_]*)\s*=\s*\{", m.group(1), re.M))
    return ids


def species_from_frlg(raw: str) -> str:
    name = raw.strip()
    if name.startswith("SPECIES_"):
        name = name[len("SPECIES_"):]
    return name


def frlg_map_to_node(name: str) -> str:
    """OneIsland_KindleRoad → SEVII_ONE_ISLAND_KINDLE_ROAD."""
    if name.startswith("MAP_"):
        name = name[4:]
    # Insert breaks before CamelCase capitals, then normalize to UPPER_SNAKE.
    spaced = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name)
    spaced = spaced.replace("-", "_").replace("__", "_")
    parts = [p for p in spaced.split("_") if p]
    return "SEVII_" + "_".join(p.upper() for p in parts)


def map_const_to_folder(map_const: str) -> str:
    """MAP_ONE_ISLAND_KINDLE_ROAD → OneIsland_KindleRoad (best-effort)."""
    if map_const.startswith("MAP_"):
        map_const = map_const[4:]
    parts = map_const.lower().split("_")
    # Known: ONE_ISLAND → OneIsland
    out = []
    i = 0
    while i < len(parts):
        if i + 1 < len(parts) and parts[i] in ("one", "two", "three", "four", "five", "six", "seven") and parts[i + 1] == "island":
            out.append(parts[i].capitalize() + "Island")
            i += 2
            continue
        if parts[i] == "mt" and i + 1 < len(parts):
            out.append("Mt" + parts[i + 1].capitalize())
            i += 2
            continue
        out.append(parts[i].capitalize())
        i += 1
    return "_".join(out)


def is_sevii_map_name(name: str) -> bool:
    n = name
    if n.startswith("MAP_"):
        n = n[4:]
    keys = (
        "OneIsland", "TwoIsland", "ThreeIsland", "FourIsland", "FiveIsland",
        "SixIsland", "SevenIsland", "MtEmber", "BirthIsland", "NavelRock",
        "TrainerTower", "Prototype_Sevii",
        "ONE_ISLAND", "TWO_ISLAND", "THREE_ISLAND", "FOUR_ISLAND",
        "FIVE_ISLAND", "SIX_ISLAND", "SEVEN_ISLAND", "MT_EMBER",
        "BIRTH_ISLAND", "NAVEL_ROCK", "TRAINER_TOWER", "PROTOTYPE_SEVII",
    )
    return any(k in n or n.startswith(k) for k in keys)


def load_map_groups(pokefirered: str) -> dict[str, Any]:
    path = os.path.join(pokefirered, "data", "maps", "map_groups.json")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def collect_sevii_folders(groups: dict[str, Any]) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()
    for key, val in groups.items():
        if key in ("group_order", "connections_include_order"):
            continue
        if not isinstance(val, list):
            continue
        for name in val:
            if is_sevii_map_name(name) and name not in seen:
                seen.add(name)
                names.append(name)
    return names


def read_map_json(pokefirered: str, folder: str) -> dict[str, Any] | None:
    path = os.path.join(pokefirered, "data", "maps", folder, "map.json")
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def build_topology(pokefirered: str, compress: bool, report: dict) -> dict:
    groups = load_map_groups(pokefirered)
    folders = collect_sevii_folders(groups)
    nodes = {}
    edges = []
    dropped = []

    for folder in folders:
        tag = "padding" if folder in PADDING_MAPS else "content"
        if folder in KEEP_ALWAYS:
            tag = "landmark" if tag == "content" else tag
        # Indoor vs outdoor heuristic
        indoor = "PokemonCenter" in folder or "Harbor" in folder or "House" in folder \
            or "Mart" in folder or "Room" in folder or folder.startswith("TrainerTower_")
        kind = "indoor" if indoor else "outdoor"
        if "Harbor" in folder:
            kind = "harbor"
        if any(x in folder for x in ("MtEmber", "Cave", "Forest", "Ruins", "Dotted", "Lost", "Warehouse", "Pattern")):
            kind = "dungeon" if kind != "harbor" else kind

        if compress and folder in PADDING_MAPS and folder not in KEEP_ALWAYS:
            dropped.append({"id": folder, "reason": "padding"})
            continue

        node_id = frlg_map_to_node(folder)
        nodes[node_id] = {
            "id": node_id,
            "frlg": folder,
            "kind": kind,
            "tag": tag,
        }

        mj = read_map_json(pokefirered, folder)
        if not mj:
            continue
        for conn in mj.get("connections") or []:
            dest = conn.get("map", "")
            if dest.startswith("MAP_"):
                dest_folder = map_const_to_folder(dest)
            else:
                dest_folder = dest
            if compress and dest_folder in PADDING_MAPS and dest_folder not in KEEP_ALWAYS:
                continue
            if not is_sevii_map_name(dest) and not is_sevii_map_name(dest_folder):
                continue
            direction = DIR_MAP.get(conn.get("direction", ""), None)
            if not direction:
                continue
            edges.append({
                "from": node_id,
                "to": frlg_map_to_node(dest_folder if "_" in dest_folder or dest_folder[0].isupper() else dest),
                "dir": direction,
            })

        script_gates = []
        for warp in mj.get("warp_events") or []:
            dest = warp.get("dest_map", "")
            # Heuristic: dynamic/script warps often go to elevators / special
            if "Elevator" in dest or "TRAINER_TOWER" in dest:
                script_gates.append({
                    "hint": "script_or_special",
                    "frlgDest": dest,
                })
        if script_gates:
            nodes[node_id]["scriptGates"] = script_gates

    # Bridge edges across dropped padding: if A→Pad and Pad→B, add A→B
    if compress and dropped:
        dropped_ids = {d["id"] for d in dropped}
        # Rebuild from raw connections using map json of kept nodes only
        # (already skipped edges into padding). Optional: scan padding maps
        # for far-side neighbors.
        for pad in dropped_ids:
            mj = read_map_json(pokefirered, pad)
            if not mj:
                continue
            neighbors = []
            for conn in mj.get("connections") or []:
                dest = conn.get("map", "")
                dest_folder = map_const_to_folder(dest) if dest.startswith("MAP_") else dest
                if dest_folder in dropped_ids:
                    continue
                if not is_sevii_map_name(dest_folder):
                    continue
                direction = DIR_MAP.get(conn.get("direction", ""))
                if direction:
                    neighbors.append((frlg_map_to_node(dest_folder), direction))
            # Connect all pairs of neighbors through the pad (shortened hop)
            for i, (a, da) in enumerate(neighbors):
                for b, db in neighbors[i + 1:]:
                    if a in nodes and b in nodes:
                        edges.append({"from": a, "to": b, "dir": da, "via": pad})
                        edges.append({"from": b, "to": a, "dir": db, "via": pad})

    report["droppedNodes"] = dropped
    return {
        "compressed": compress,
        "nodes": nodes,
        "edges": edges,
    }


def load_wild_encounters(pokefirered: str | None) -> dict[str, Any]:
    local = None
    if pokefirered:
        local = os.path.join(pokefirered, "src", "data", "wild_encounters.json")
    if local and os.path.isfile(local):
        with open(local, encoding="utf-8") as f:
            return json.load(f)
    print("Fetching wild_encounters.json from GitHub…")
    with urllib.request.urlopen(WILD_JSON_URL, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def land_water_rates(wild_root: dict) -> tuple[list[int], list[int]]:
    land, water = list(LAND_WEIGHTS), list(WATER_WEIGHTS_5)
    for group in wild_root.get("wild_encounter_groups") or []:
        for field in group.get("fields") or []:
            if field.get("type") == "land_mons" and field.get("encounter_rates"):
                land = list(field["encounter_rates"])
            if field.get("type") == "water_mons" and field.get("encounter_rates"):
                water = list(field["encounter_rates"])
    return land, water


def filter_slots(
    mons: list[dict],
    weights: list[int],
    allow: set[str],
    report: dict,
    map_id: str,
) -> list[dict]:
    out = []
    for i, mon in enumerate(mons):
        sp = species_from_frlg(mon.get("species", ""))
        w = weights[i] if i < len(weights) else 1
        if sp not in allow:
            report.setdefault("unmappedSpecies", []).append({
                "map": map_id, "species": sp, "slot": i,
            })
            continue
        level = int(mon.get("max_level") or mon.get("min_level") or 1)
        out.append({"species": sp, "level": level, "weight": w, "srcIndex": i})
    return out


def quantize_grass(slots: list[dict], report: dict, map_id: str) -> list[dict] | None:
    if not slots:
        report.setdefault("encounterEmpty", []).append({"map": map_id, "kind": "grass"})
        return None
    r = list(slots)
    if len(r) > 10:
        # Cull lowest weight; ties → later srcIndex first
        while len(r) > 10:
            worst = min(range(len(r)), key=lambda i: (r[i]["weight"], -r[i]["srcIndex"]))
            culled = r.pop(worst)
            report.setdefault("encounterCulls", []).append({
                "map": map_id, "species": culled["species"], "level": culled["level"],
            })
    elif len(r) < 10:
        # Pad by duplicating highest-weight first (round-robin)
        order = sorted(range(len(r)), key=lambda i: (-r[i]["weight"], r[i]["srcIndex"]))
        oi = 0
        while len(r) < 10:
            src = r[order[oi % len(order)]]
            dup = {"species": src["species"], "level": src["level"], "weight": src["weight"], "srcIndex": src["srcIndex"]}
            report.setdefault("encounterPads", []).append({
                "map": map_id, "species": dup["species"], "level": dup["level"],
                "fromIndex": src["srcIndex"], "toIndex": len(r),
            })
            r.append(dup)
            oi += 1
    assert len(r) == 10
    return [{"species": s["species"], "level": s["level"]} for s in r]


def proportional_water(slots: list[dict], report: dict, map_id: str) -> list[dict] | None:
    if not slots:
        report.setdefault("encounterEmpty", []).append({"map": map_id, "kind": "water"})
        return None
    weights = [s["weight"] for s in slots]
    total = sum(weights) or 1
    ideals = [10 * w / total for w in weights]
    floors = [int(x) for x in ideals]
    rem = 10 - sum(floors)
    frac_order = sorted(range(len(slots)), key=lambda i: -(ideals[i] - floors[i]))
    counts = list(floors)
    for i in range(rem):
        counts[frac_order[i % len(frac_order)]] += 1
    out: list[dict] = []
    for i, slot in enumerate(slots):
        for _ in range(counts[i]):
            out.append({"species": slot["species"], "level": slot["level"]})
    # Safety: length must be 10
    while len(out) < 10:
        out.append(dict(out[-1] if out else {"species": "TENTACOOL", "level": 5}))
    out = out[:10]
    report.setdefault("waterExpand", []).append({
        "map": map_id, "frlgRows": len(slots), "gen1Slots": 10, "counts": counts,
    })
    assert len(out) == 10
    return out


def build_encounters(
    wild_root: dict,
    allow: set[str],
    report: dict,
    phase0_only: bool = False,
) -> dict[str, Any]:
    land_w, water_w = land_water_rates(wild_root)
    out: dict[str, Any] = {}
    phase0_maps = {
        "MAP_ONE_ISLAND", "MAP_ONE_ISLAND_KINDLE_ROAD", "MAP_ONE_ISLAND_TREASURE_BEACH",
    }
    for group in wild_root.get("wild_encounter_groups") or []:
        for enc in group.get("encounters") or []:
            fmap = enc.get("map") or ""
            if not is_sevii_map_name(fmap):
                continue
            if phase0_only and fmap not in phase0_maps:
                continue
            node = frlg_map_to_node(fmap)
            entry: dict[str, Any] = {}
            if enc.get("land_mons"):
                lm = enc["land_mons"]
                filtered = filter_slots(lm.get("mons") or [], land_w, allow, report, node)
                grass = quantize_grass(filtered, report, node)
                if grass:
                    entry["grass"] = {"rate": int(lm.get("encounter_rate") or 0), "slots": grass}
            if enc.get("water_mons"):
                wm = enc["water_mons"]
                mons = wm.get("mons") or []
                wts = water_w if len(mons) == len(water_w) else (
                    WATER_WEIGHTS_5 if len(mons) == 5 else [1] * len(mons)
                )
                if len(mons) != len(water_w) and len(mons) != 5:
                    report.setdefault("waterWeightAssumption", []).append({
                        "map": node, "count": len(mons),
                    })
                filtered = filter_slots(mons, wts, allow, report, node)
                water = proportional_water(filtered, report, node)
                if water:
                    entry["water"] = {"rate": int(wm.get("encounter_rate") or 0), "slots": water}
            if entry:
                out[node] = entry
    return out


def lua_quote(s: str) -> str:
    return json.dumps(s)


def write_encounters_lua(path: str, encounters: dict[str, Any]) -> None:
    lines = [
        "-- Generated by sevii_import.py — do not hand-edit.",
        "local E = {}",
        "E.maps = {",
    ]
    for map_id in sorted(encounters.keys()):
        entry = encounters[map_id]
        lines.append(f"  {map_id} = {{")
        for kind in ("grass", "water"):
            block = entry.get(kind)
            if not block:
                continue
            lines.append(f"    {kind} = {{")
            lines.append(f"      rate = {int(block['rate'])},")
            lines.append("      slots = {")
            for slot in block["slots"]:
                lines.append(
                    f"        {{ level = {int(slot['level'])}, "
                    f"species = {lua_quote(slot['species'])} }},"
                )
            lines.append("      },")
            lines.append("    },")
        lines.append("  },")
    lines.append("}")
    lines.append("return E")
    lines.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def write_trainers_lua(path: str, trainers: list[dict], report: dict) -> None:
    """Emit SEVII_* trainer classes from dumped JSON (no held items)."""
    by_class: dict[str, dict] = {}
    class_map_report = []

    for t in trainers:
        frlg_class = (t.get("trainerClass") or t.get("class") or "COOLTRAINER_M").upper()
        frlg_class = frlg_class.replace("TRAINER_CLASS_", "")
        if frlg_class in CLASS_MAP:
            class_id = CLASS_MAP[frlg_class]
            base_pic = class_id
            mapped = True
        else:
            class_id = "SEVII_" + frlg_class
            base_pic = CLASS_BASEPIC.get(frlg_class, "OPP_COOLTRAINER_M")
            mapped = False
        class_map_report.append({
            "frlg": frlg_class, "id": class_id, "basePic": base_pic, "directOpp": mapped,
        })
        if t.get("heldItem") or t.get("held_item"):
            report.setdefault("heldItemHints", []).append({
                "trainer": t.get("id") or t.get("name"),
                "item": t.get("heldItem") or t.get("held_item"),
            })
        party = []
        for mon in t.get("party") or []:
            sp = species_from_frlg(str(mon.get("species", "")))
            if not sp:
                continue
            party.append({
                "level": int(mon.get("level") or mon.get("lvl") or 1),
                "species": sp,
            })
            if mon.get("moves"):
                report.setdefault("moveHints", []).append({
                    "trainer": t.get("id"), "species": sp, "moves": mon.get("moves"),
                })
        if not party:
            continue
        rec = by_class.setdefault(class_id, {
            "id": class_id,
            "name": (t.get("displayName") or frlg_class.replace("_", " "))[:12],
            "basePic": base_pic,
            "baseMoney": int(t.get("baseMoney") or 25),
            "parties": [],
        })
        rec["parties"].append(party)

    report["classMap"] = class_map_report

    lines = [
        "-- Generated by sevii_import.py — do not hand-edit.",
        "local T = {}",
        "T.classes = {",
    ]
    for cid in sorted(by_class.keys()):
        c = by_class[cid]
        lines.append(f"  {cid} = {{")
        lines.append(f"    id = {lua_quote(c['id'])},")
        lines.append(f"    name = {lua_quote(c['name'])},")
        lines.append(f"    basePic = {lua_quote(c['basePic'])},")
        lines.append(f"    baseMoney = {c['baseMoney']},")
        lines.append("    parties = {")
        for party in c["parties"]:
            lines.append("      {")
            for mon in party:
                lines.append(
                    f"        {{ level = {mon['level']}, species = {lua_quote(mon['species'])} }},"
                )
            lines.append("      },")
        lines.append("    },")
        lines.append("  },")
    lines.append("}")
    lines.append("return T")
    lines.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def load_trainers_json(path: str | None, report: dict) -> list[dict]:
    if not path or not os.path.isfile(path):
        report.setdefault("trainerParseFailures", []).append({
            "reason": "missing_json", "path": path,
        })
        return []
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return data.get("trainers") or data if isinstance(data, list) else []


def main() -> None:
    parser = argparse.ArgumentParser(description="Import FRLG Sevii data into KR sevii/")
    parser.add_argument("--pokefirered", type=str, default="",
                        help="Path to pokefirered checkout (map_groups + map.json)")
    parser.add_argument("--outdir", type=str, default=DEFAULT_OUTDIR)
    parser.add_argument("--trainers-json", type=str, default="",
                        help="Path to frlg_trainers.json from dump_frlg_sevii_trainers.py")
    parser.add_argument("--compress", action="store_true", default=True)
    parser.add_argument("--no-compress", action="store_true")
    parser.add_argument("--topology-only", action="store_true")
    parser.add_argument("--encounters-only", action="store_true")
    parser.add_argument("--trainers-only", action="store_true")
    parser.add_argument("--phase0", action="store_true",
                        help="Limit wild import to One Island slice maps")
    parser.add_argument("--repo-root", type=str, default=REPO_ROOT)
    args = parser.parse_args()

    compress = not args.no_compress
    os.makedirs(args.outdir, exist_ok=True)
    report: dict[str, Any] = {}

    do_topo = not (args.encounters_only or args.trainers_only) or args.topology_only
    do_enc = not (args.topology_only or args.trainers_only) or args.encounters_only
    do_tr = not (args.topology_only or args.encounters_only) or args.trainers_only
    if args.topology_only:
        do_enc = do_tr = False
    if args.encounters_only:
        do_topo = do_tr = False
    if args.trainers_only:
        do_topo = do_enc = False

    allow = load_species_allowlist(args.repo_root, MOD_ROOT)
    if not allow:
        print("WARNING: empty species allowlist — check --repo-root", file=sys.stderr)

    if do_topo:
        if not args.pokefirered:
            print("--pokefirered required for topology", file=sys.stderr)
            sys.exit(1)
        blueprint = build_topology(args.pokefirered, compress, report)
        bp_path = os.path.join(args.outdir, "blueprint.json")
        with open(bp_path, "w", encoding="utf-8") as f:
            json.dump(blueprint, f, indent=2)
            f.write("\n")
        print(f"Wrote {bp_path} ({len(blueprint['nodes'])} nodes, "
              f"{len(blueprint['edges'])} edges, "
              f"{len(report.get('droppedNodes') or [])} dropped)")

    if do_enc:
        wild = load_wild_encounters(args.pokefirered or None)
        encounters = build_encounters(wild, allow, report, phase0_only=args.phase0)
        enc_path = os.path.join(args.outdir, "encounters_data.lua")
        write_encounters_lua(enc_path, encounters)
        print(f"Wrote {enc_path} ({len(encounters)} maps)")

    if do_tr:
        tj = args.trainers_json or os.path.join(args.outdir, "frlg_trainers.json")
        trainers = load_trainers_json(tj, report)
        # Filter parties to allowlisted species
        cleaned = []
        for t in trainers:
            party = []
            for mon in t.get("party") or []:
                sp = species_from_frlg(str(mon.get("species", "")))
                if sp not in allow:
                    report.setdefault("unmappedSpecies", []).append({
                        "trainer": t.get("id"), "species": sp,
                    })
                    continue
                party.append({**mon, "species": sp})
            if party:
                cleaned.append({**t, "party": party})
        tr_path = os.path.join(args.outdir, "trainers_data.lua")
        write_trainers_lua(tr_path, cleaned, report)
        print(f"Wrote {tr_path} ({len(cleaned)} trainers)")

    # Deduplicate unmapped species list
    if "unmappedSpecies" in report:
        seen = set()
        uniq = []
        for row in report["unmappedSpecies"]:
            key = (row.get("map") or row.get("trainer"), row.get("species"))
            if key in seen:
                continue
            seen.add(key)
            uniq.append(row)
        report["unmappedSpecies"] = uniq

    report_path = os.path.join(args.outdir, "import_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
        f.write("\n")
    print(f"Wrote {report_path}")


if __name__ == "__main__":
    main()
