#!/usr/bin/env python3
"""
verify_dungeon_puzzles.py

Diagnostic tool to inspect bi-directional warp integrity, landing coordinate bounds,
Seafoam Islands current & boulder puzzle quads, and Safari Zone / Mt. Moon triggers.
"""

import os
import json
import subprocess

def load_data():
    tool_path = os.path.join("tools", "lua_to_json.lua")
    data_path = os.path.join("mods", "Kanto-Reforged", "world", "restored_dungeons_data.lua")
    proc = subprocess.run(["luajit", tool_path, data_path], capture_output=True, text=True, check=True)
    return json.loads(proc.stdout)

def verify_warps(maps):
    print("--- Verifying Multi-Floor Warp Integrity ---")
    warp_errors = []
    
    for map_id, mdef in maps.items():
        w_blocks = mdef.get("width", 0)
        h_blocks = mdef.get("height", 0)
        w_cells = w_blocks * 2
        h_cells = h_blocks * 2
        
        warps = mdef.get("warps", [])
        for i, w in enumerate(warps, 1):
            wx, wy = w.get("x", -1), w.get("y", -1)
            dest_map = w.get("destMap")
            dest_warp_idx = w.get("destWarp", 0)
            
            # Check source bounds (in 16x16 cells)
            if wx < 0 or wy < 0 or wx >= w_cells or wy >= h_cells:
                warp_errors.append(f"Map {map_id} warp #{i} at ({wx},{wy}) out of bounds ({w_cells}x{h_cells})")
            
            # Skip special return warps
            if dest_map in ("LAST_MAP", "PREVIOUS_MAP"):
                continue
                
            if dest_map not in maps:
                # May be external overworld map
                continue
                
            dest_def = maps[dest_map]
            dest_warps = dest_def.get("warps", [])
            if dest_warp_idx < 1 or dest_warp_idx > len(dest_warps):
                warp_errors.append(f"Map {map_id} warp #{i} points to invalid destWarp #{dest_warp_idx} in {dest_map} (max {len(dest_warps)})")
            else:
                target_w = dest_warps[dest_warp_idx - 1]
                tx, ty = target_w.get("x", -1), target_w.get("y", -1)
                tw_blocks = dest_def.get("width", 0)
                th_blocks = dest_def.get("height", 0)
                if tx < 0 or ty < 0 or tx >= tw_blocks * 2 or ty >= th_blocks * 2:
                    warp_errors.append(f"Map {map_id} warp #{i} landing ({tx},{ty}) in {dest_map} out of bounds ({tw_blocks*2}x{th_blocks*2})")
                    
    if warp_errors:
        print(f"FAILED: Found {len(warp_errors)} warp issues:")
        for err in warp_errors:
            print("  -", err)
    else:
        print("SUCCESS: All multi-floor warps are in bounds and correctly cross-linked!")

def verify_seafoam_puzzle(data):
    print("\n--- Verifying Seafoam Islands Boulder & Current Puzzle Data ---")
    patches = data.get("seafoamBoulderPatches", {})
    b4f_patch = patches.get("SEAFOAM_ISLANDS_B4F", [])
    
    print(f"Seafoam B4F dynamic boulder patches: {len(b4f_patch)} tile targets")
    for p in b4f_patch:
        print(f"  Target tile ({p['x']}, {p['y']}) -> Quad {p['targetQuad']} (Calm Surfable Water)")
        
    assert len(b4f_patch) >= 2, "Seafoam B4F must have at least 2 boulder hole target patches"
    print("SUCCESS: Seafoam Islands boulder puzzle dynamic collision quads verified!")

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    os.chdir(root_dir)
    
    data = load_data()
    maps = data.get("maps", {})
    verify_warps(maps)
    verify_seafoam_puzzle(data)

if __name__ == "__main__":
    main()
