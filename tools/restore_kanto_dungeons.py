#!/usr/bin/env python3
"""
restore_kanto_dungeons.py

Offline data conversion pipeline for Kanto-Reforged.
Extracts canonical Gen 1 map data (blocks, dimensions, tilesets, collision, warps, signposts, objects, encounters)
for gutted Kanto dungeons (Viridian Forest, Route 2, Mt. Moon, Cerulean Cave, Seafoam Islands, Safari Zone, Gatehouses),
converts block layouts and tile collision to native Gen 2 format (TILESET_FOREST, TILESET_KANTO, TILESET_GATE, TILESET_HOUSE, TILESET_CAVE),
maps numeric sprite IDs to Gen 2 string sprite IDs,
and outputs production-ready Lua data structures to mods/Kanto-Reforged/world/restored_dungeons_data.lua.
"""

import os
import sys
import json
import subprocess

TARGET_MAPS = [
    "VIRIDIAN_FOREST",
    "VIRIDIAN_FOREST_NORTH_GATE",
    "VIRIDIAN_FOREST_SOUTH_GATE",
    "ROUTE_2",
    "ROUTE_2_GATE",
    "ROUTE_2_TRADE_HOUSE",
    "DIGLETTS_CAVE",
    "DIGLETTS_CAVE_ROUTE_2",
    "DIGLETTS_CAVE_ROUTE_11",
    "MT_MOON_1F",
    "MT_MOON_B1F",
    "MT_MOON_B2F",
    "CERULEAN_CAVE_1F",
    "CERULEAN_CAVE_2F",
    "CERULEAN_CAVE_B1F",
    "SEAFOAM_ISLANDS_1F",
    "SEAFOAM_ISLANDS_B1F",
    "SEAFOAM_ISLANDS_B2F",
    "SEAFOAM_ISLANDS_B3F",
    "SEAFOAM_ISLANDS_B4F",
    "SAFARI_ZONE_CENTER",
    "SAFARI_ZONE_EAST",
    "SAFARI_ZONE_WEST",
    "SAFARI_ZONE_NORTH",
    "SAFARI_ZONE_CENTER_REST_HOUSE",
    "SAFARI_ZONE_EAST_REST_HOUSE",
    "SAFARI_ZONE_NORTH_REST_HOUSE",
    "SAFARI_ZONE_WEST_REST_HOUSE",
    "SAFARI_ZONE_SECRET_HOUSE",
    "SAFARI_ZONE_GATE",
    "ROCK_TUNNEL_1F",
    "ROCK_TUNNEL_B1F",
    "ROCK_TUNNEL_POKECENTER",
]

# Custom blocks for Viridian Forest in TILESET_KANTO
CUSTOM_KANTO_BLOCKS = {
    129: {
        "tiles": [64, 65, 82, 82, 80, 81, 82, 82, 64, 65, 82, 82, 80, 81, 82, 82],
        "collision": [0x07, 0x18, 0x07, 0x18]
    }, # Trees left, Tall grass right
    130: {
        "tiles": [82, 82, 64, 65, 82, 82, 80, 81, 82, 82, 64, 65, 82, 82, 80, 81],
        "collision": [0x18, 0x07, 0x18, 0x07]
    }, # Tall grass left, Trees right
    131: {
        "tiles": [64, 65, 35, 35, 80, 81, 35, 35, 64, 65, 35, 35, 80, 81, 35, 35],
        "collision": [0x07, 0x00, 0x07, 0x00]
    }, # Trees left, Plain grass right
    132: {
        "tiles": [35, 35, 64, 65, 35, 35, 80, 81, 35, 35, 64, 65, 35, 35, 80, 81],
        "collision": [0x00, 0x07, 0x00, 0x07]
    }, # Plain grass left, Trees right
    133: {
        "tiles": [64, 65, 64, 65, 80, 81, 80, 81, 35, 35, 35, 35, 35, 35, 35, 35],
        "collision": [0x07, 0x07, 0x00, 0x00]
    }, # Trees top, Plain grass bottom
    134: {
        "tiles": [35, 35, 35, 35, 35, 35, 35, 35, 64, 65, 64, 65, 80, 81, 80, 81],
        "collision": [0x00, 0x00, 0x07, 0x07]
    }, # Plain grass top, Trees bottom
    135: {
        "tiles": [35, 35, 35, 35, 57, 35, 35, 35, 42, 43, 42, 43, 58, 59, 58, 59],
        "collision": [0x00, 0x00, 0xA0, 0xA0]
    }, # Ledge on plain grass
    136: {
        "tiles": [35, 35, 35, 35, 57, 35, 35, 35, 44, 44, 44, 44, 44, 44, 44, 44],
        "collision": [0x00, 0x00, 0x70, 0x70]
    }, # South exit warp pad (COLL_WARP_CARPET_DOWN on bottom half with path mat)
    137: {
        "tiles": [44, 44, 44, 44, 44, 44, 44, 44, 35, 35, 35, 35, 57, 35, 35, 35],
        "collision": [0x78, 0x78, 0x00, 0x00]
    }, # North exit warp pad (COLL_WARP_CARPET_UP on top half with path mat)
    138: {
        "tiles": [50, 75, 75, 50, 75, 75, 75, 75, 11, 12, 10, 10, 27, 28, 26, 26],
        "collision": [0x07, 0x07, 0x71, 0x71]
    }, # Safari Zone Gate Entrance (COLL_DOOR on bottom half)
    # Custom blocks for natural pond corners and island shorelines
    131: {"tiles": [64, 65, 35, 35, 80, 81, 35, 35, 64, 65, 35, 35, 80, 81, 35, 35], "collision": [0x07, 0x00, 0x07, 0x00]}, # Tree left, Grass right
    132: {"tiles": [35, 35, 64, 65, 35, 35, 80, 81, 35, 35, 64, 65, 35, 35, 80, 81], "collision": [0x00, 0x07, 0x00, 0x07]}, # Grass left, Tree right
    133: {"tiles": [64, 65, 64, 65, 80, 81, 80, 81, 35, 35, 35, 35, 35, 35, 35, 35], "collision": [0x07, 0x07, 0x00, 0x00]}, # Tree top, Grass bottom
    134: {"tiles": [35, 35, 35, 35, 35, 35, 35, 35, 64, 65, 64, 65, 80, 81, 80, 81], "collision": [0x00, 0x00, 0x07, 0x07]}, # Grass top, Tree bottom
    142: {"tiles": [51, 51, 51, 51, 51, 20, 20, 20, 51, 20, 20, 20, 51, 20, 20, 20], "collision": [0x07, 0x07, 0x07, 0x29]}, # NW Pond Corner
    143: {"tiles": [51, 51, 51, 51, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20], "collision": [0x07, 0x07, 0x29, 0x29]}, # North Shore
    144: {"tiles": [51, 51, 51, 51, 20, 20, 20, 84, 20, 20, 20, 84, 20, 20, 20, 84], "collision": [0x07, 0x07, 0x29, 0x07]}, # NE Pond Corner
    145: {"tiles": [51, 20, 20, 20, 51, 20, 20, 20, 51, 20, 20, 20, 51, 20, 20, 20], "collision": [0x07, 0x29, 0x07, 0x29]}, # West Shore
    146: {"tiles": [20, 20, 20, 84, 20, 20, 20, 84, 20, 20, 20, 84, 20, 20, 20, 84], "collision": [0x29, 0x07, 0x29, 0x07]}, # East Shore
    150: {"tiles": [20, 20, 20, 20, 20, 20, 51, 35, 20, 20, 51, 35, 20, 20, 51, 35], "collision": [0x29, 0x29, 0x07, 0x00]}, # Island NW Corner
    151: {"tiles": [20, 20, 20, 20, 35, 84, 20, 20, 35, 84, 20, 20, 35, 84, 20, 20], "collision": [0x29, 0x29, 0x00, 0x07]}, # Island NE Corner
    152: {"tiles": [20, 20, 51, 35, 20, 20, 51, 35, 20, 20, 20, 20, 20, 20, 20, 20], "collision": [0x07, 0x00, 0x29, 0x29]}, # Island SW Corner
    153: {"tiles": [35, 84, 20, 20, 35, 84, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20], "collision": [0x00, 0x07, 0x29, 0x29]}, # Island SE Corner
    # Authentic 4-step wooden stairs down through cliff
    158: {"tiles": [17, 17, 17, 17, 17, 17, 17, 17, 77, 78, 77, 78, 83, 84, 83, 84], "collision": [0x00, 0x00, 0x00, 0x00]},
    # Authentic 4-step wooden stairs up into cliff
    159: {"tiles": [77, 78, 77, 78, 83, 84, 83, 84, 17, 17, 17, 17, 17, 17, 17, 17], "collision": [0x00, 0x00, 0x00, 0x00]},
}


FOREST_G1_TO_G2 = {
    1: 11,   # Tall grass (Block 11)
    2: 15,   # Solid tree wall (Block 15)
    6: 129,  # Tree left, Tall grass right (Block 129)
    7: 130,  # Tall grass left, Tree right (Block 130)
    20: 1,   # Plain grass / path corridor (Block 1)
    21: 1,   # North gate door / path (Block 1)
    22: 1,   # Path (Block 1)
    24: 1,   # Plain grass / path (Block 1)
    27: 1,   # Clear path (Block 1)
    33: 135, # Ledge (Block 135)
    41: 1,   # Path (Block 1)
    53: 134, # Grass top, tree bottom (Block 134)
    55: 131, # Tree left, grass right (Block 131)
    57: 133, # Tree top, grass bottom (Block 133)
    59: 132, # Grass left, tree right (Block 132)
    73: 15,  # Solid tree wall (Block 15)
    88: 136, # South exit warp pad (Block 136)
}

SAFARI_G1_TO_G2 = {
    # 1. Plain Open Grass Ground
    0: 1, 3: 1, 27: 1, 44: 1, 46: 1, 47: 1,
    86: 1, 87: 1, 88: 1, 89: 1, 98: 1, 100: 1, 101: 1, 102: 1, 103: 1, 116: 1, 119: 1, 120: 1, 123: 1,
    # 2. Tall Grass (Wild Encounters - Complete Stepped Patterns)
    1: 11, 4: 11, 5: 11, 6: 11, 7: 11, 8: 11, 9: 11, 10: 11, 11: 11, 12: 11, 13: 11, 14: 11, 15: 11,
    21: 11, 29: 11, 30: 11, 31: 11, 32: 11, 34: 11, 35: 11, 36: 11, 37: 11, 40: 11, 41: 11,
    52: 11, 53: 11, 54: 11, 55: 11, 56: 11, 57: 11, 58: 11, 59: 11,
    72: 11, 73: 11, 76: 11, 77: 11, 99: 11,
    # 3. Trees & Boundaries (Half-blocks 124=top grass/bot tree, 125=top tree/bot grass, 126=left grass/right tree, 127=left tree/right grass)
    124: 134, 125: 133, 126: 132, 127: 131,
    2: 15, 16: 15, 17: 15, 18: 15, 19: 15, 20: 15, 24: 15,
    # 4. Fences & Wood Posts
    23: 26, 38: 27, 39: 27, 42: 27, 43: 27, 33: 27, 51: 27, 78: 27, 97: 27, 22: 27,
    # 5. Rest House Cottage
    25: 2, 26: 3, 28: 3,
    # 6. Water & Shorelines
    45: 67, 80: 67,
    81: 143, 92: 142, 82: 144, 90: 145, 91: 146,
    93: 150, 85: 151, 94: 152, 79: 153,
    48: 145, 84: 145, 106: 145, 114: 145,
    50: 146, 104: 146, 105: 146, 115: 146,
    49: 143, 110: 143, 111: 143,
    95: 67, 96: 67, 107: 67, 108: 67, 109: 67, 112: 67, 113: 67, 117: 67, 118: 67, 121: 67, 122: 67,
    # 7. Plateau & Cliffs (Native Gen 2 Kanto cliffs & 158/159 3-step stairs)
    60: 36, 61: 63, 62: 43, 63: 40, 64: 40, 65: 44, 66: 41, 67: 41,
    68: 36, 69: 87, 70: 37, 71: 158, 74: 159, 75: 158, 83: 87,
}

# Auto-merge generated Safari mappings and custom assembled blocks if present
try:
    import importlib.util
    for p_candidate in [
        os.path.abspath(os.path.join(os.path.dirname(__file__), "safari_g1_to_g2.py")),
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "safari_g1_to_g2.py")),
        os.path.abspath(os.path.join(os.getcwd(), "safari_g1_to_g2.py")),
    ]:
        if os.path.exists(p_candidate):
            spec = importlib.util.spec_from_file_location("safari_g1_to_g2", p_candidate)
            if spec and spec.loader:
                s_mod = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(s_mod)
                if hasattr(s_mod, "SAFARI_G1_TO_G2"):
                    SAFARI_G1_TO_G2.update(s_mod.SAFARI_G1_TO_G2)
                if hasattr(s_mod, "CUSTOM_KANTO_BLOCKS_GENERATED"):
                    CUSTOM_KANTO_BLOCKS.update(s_mod.CUSTOM_KANTO_BLOCKS_GENERATED)
                print(f"[restore_kanto_dungeons] Loaded {len(s_mod.SAFARI_G1_TO_G2)} Safari mappings and {len(s_mod.CUSTOM_KANTO_BLOCKS_GENERATED)} custom blocks from {p_candidate}")
                break
except Exception as e:
    print(f"[restore_kanto_dungeons] Notice: Could not import safari_g1_to_g2.py: {e}")



KANTO_G1_TO_G2 = {
    1: 1,    # Path / grass
    2: 1,    # Path
    3: 1,    # Path
    6: 1,    # Path
    7: 7,    # Ledge hop down
    8: 1,    # Path
    10: 1,   # Main road / path
    11: 1,   # Grass
    13: 1,   # Grass
    15: 15,  # Solid tree boundary (0x0F)
    26: 26,  # Ledge / fence
    27: 23,  # Cut tree (0x17)
    32: 1,   # Grass
    33: 1,   # Grass
    36: 1,   # Path
    37: 1,   # Path
    47: 7,   # Ledge
    49: 11,  # Tall grass (0x0B)
    50: 1,   # Path
    52: 1,   # Path
    59: 1,   # Path
    62: 1,   # Gatehouse roof
    63: 1,   # Gatehouse door / path
    82: 1,   # Fence / tree
    85: 1,   # House roof
    87: 1,   # House door / path
    108: 1,  # Path
    109: 1,  # Path
    110: 1,  # Path
    111: 1,  # Path
    116: 27, # Fence (0x1B)
    124: 1,  # Path
    125: 1,  # Diglett cave entrance path
    126: 1,  # Path
}

CAVE_G1_TO_G2 = {
    1: 1,    # Wall
    21: 16,  # Top wall
    22: 13,  # Wall corner
    24: 10,  # Left wall
    25: 25,  # Cave dirt floor
    26: 8,   # Right wall
    28: 17,  # Wall corner
    29: 2,   # Bottom wall
    43: 43,  # Ladder (0x2B)
    44: 43,  # Ladder
    62: 25,  # Floor
}

GEN2_GATE_BLOCKS = [2, 2, 4, 2, 2, 9, 1, 1, 1, 8, 13, 1, 1, 1, 12, 20, 1, 10, 1, 20]
GEN2_HOUSE_BLOCKS = [4, 30, 5, 29, 15, 1, 2, 15, 15, 12, 13, 15, 6, 11, 15, 7]

# Tileset-specific tile semantic rules for Gen 2 COLL_* mapping

# CAVERN rules
CAVERN_PITS = {0x21}  # 33 in decimal (hole/pit in Seafoam / Mt. Moon)
CAVERN_STAIRS = {
    0x01, 0x06, 0x08, 0x09, 0x0A, 0x0B, 0x0E, 0x0F,
    0x18, 0x19, 0x1A, 0x1B, 0x1E, 0x1F, 0x24, 0x25, 0x26, 0x27
}  # (1, 6, 8, 9, 10, 11, 14, 15, 24, 25, 26, 27, 30, 31, 36, 37, 38, 39)
CAVERN_EXTRA_WALKABLE = {0x10, 0x17, 0x31}  # (16, 23, 49)
CAVERN_WATER = {0x14, 0x32, 0x48}

# GYM rules
GYM_WARP_CARPET_DOWN = {0x15, 0x16}

# FOREST rules
FOREST_GRASS = {0x52}  # 82 decimal
FOREST_WARP_CARPET_DOWN = {0x50, 0x53, 0x08, 0x09, 0x18, 0x19}  # 80, 83, 8, 9, 24, 25
FOREST_EXTRA_WALKABLE = {0x28, 0x29, 0x2A, 0x2B, 0x38, 0x3A, 0x3B}  # 40, 41, 42, 43, 56, 58, 59

# GATE rules
GATE_COUNTERS = {0x90, 0x50, 0x51}
GATE_DOORS = {0x70, 0x5B, 0x5C}
GATE_WARP_CARPET_DOWN = {0x04, 0x14, 0x27, 0x37, 0x50, 0x53}  # Door exit mats (4, 20, 39, 55, 80, 83)

# LAB rules
LAB_COUNTERS = {0x90, 0x50, 0x51}
LAB_WARP_CARPET_DOWN = {0x04, 0x14, 0x27, 0x37}  # 4, 20, 39, 55 (door exit mats)

GEN1_TO_GEN2_SPRITE = {
    1: "SPRITE_RED",
    2: "SPRITE_BLUE",
    3: "SPRITE_OAK",
    4: "SPRITE_YOUNGSTER",
    5: "SPRITE_LASS",
    6: "SPRITE_SUPER_NERD",
    7: "SPRITE_HIKER",
    8: "SPRITE_LASS",
    9: "SPRITE_BIKER",
    10: "SPRITE_SAILOR",
    11: "SPRITE_COOK",
    12: "SPRITE_COOLTRAINER_M",
    13: "SPRITE_COOLTRAINER_F",
    14: "SPRITE_BEAUTY",
    15: "SPRITE_SCIENTIST",
    16: "SPRITE_ROCKET",
    17: "SPRITE_CHANNELER",
    20: "SPRITE_GRAMPS",
    24: "SPRITE_TWIN",
    30: "SPRITE_GAMEBOY_KID",
    53: "SPRITE_BOULDER",
    60: "SPRITE_POKE_BALL",
    61: "SPRITE_FOSSIL",
}

TRAINER_LEVEL_MAP = {
    "VIRIDIAN_FOREST": {"base": 46, "class": "OPP_BUG_CATCHER"},
    "ROUTE_2": {"base": 45, "class": "OPP_BUG_CATCHER"},
    "MT_MOON_1F": {"base": 48, "class": "OPP_HIKER"},
    "MT_MOON_B1F": {"base": 49, "class": "OPP_SUPER_NERD"},
    "MT_MOON_B2F": {"base": 50, "class": "OPP_SUPER_NERD"},
    "SEAFOAM_ISLANDS_1F": {"base": 52, "class": "OPP_BOARDER"},
    "SEAFOAM_ISLANDS_B1F": {"base": 53, "class": "OPP_BOARDER"},
    "SEAFOAM_ISLANDS_B2F": {"base": 54, "class": "OPP_BOARDER"},
    "SEAFOAM_ISLANDS_B3F": {"base": 55, "class": "OPP_BOARDER"},
    "SEAFOAM_ISLANDS_B4F": {"base": 56, "class": "OPP_SKIER"},
}

ENCOUNTER_LEVEL_MAP = {
    "ROUTE_2": {"base": 28, "variance": 4},
    "VIRIDIAN_FOREST": {"base": 46, "variance": 6},
    "DIGLETTS_CAVE": {"base": 48, "variance": 5},
    "MT_MOON_1F": {"base": 48, "variance": 4},
    "MT_MOON_B1F": {"base": 49, "variance": 4},
    "MT_MOON_B2F": {"base": 50, "variance": 4},
    "SAFARI_ZONE_CENTER": {"base": 50, "variance": 6},
    "SAFARI_ZONE_EAST": {"base": 50, "variance": 6},
    "SAFARI_ZONE_WEST": {"base": 50, "variance": 6},
    "SAFARI_ZONE_NORTH": {"base": 50, "variance": 6},
    "SEAFOAM_ISLANDS_1F": {"base": 52, "variance": 4},
    "SEAFOAM_ISLANDS_B1F": {"base": 53, "variance": 4},
    "SEAFOAM_ISLANDS_B2F": {"base": 54, "variance": 4},
    "SEAFOAM_ISLANDS_B3F": {"base": 55, "variance": 4},
    "SEAFOAM_ISLANDS_B4F": {"base": 56, "variance": 4},
    "CERULEAN_CAVE_1F": {"base": 58, "variance": 6},
    "CERULEAN_CAVE_2F": {"base": 60, "variance": 6},
    "CERULEAN_CAVE_B1F": {"base": 62, "variance": 6},
    "ROCK_TUNNEL_1F": {"base": 48, "variance": 6},
    "ROCK_TUNNEL_B1F": {"base": 50, "variance": 6},
}

MAP_WARP_EXPLICIT_REDIRECTS = {
    "ROCK_TUNNEL_1F": {
        1: {"destMap": "ROUTE_10", "destWarp": 2},
        2: {"destMap": "ROUTE_10", "destWarp": 2},
        3: {"destMap": "ROUTE_10", "destWarp": 3},
        4: {"destMap": "ROUTE_10", "destWarp": 3},
        5: {"destMap": "ROCK_TUNNEL_B1F", "destWarp": 1},
        6: {"destMap": "ROCK_TUNNEL_B1F", "destWarp": 2},
        7: {"destMap": "ROCK_TUNNEL_B1F", "destWarp": 3},
        8: {"destMap": "ROCK_TUNNEL_B1F", "destWarp": 4},
    },
    "ROCK_TUNNEL_B1F": {
        1: {"destMap": "ROCK_TUNNEL_1F", "destWarp": 5},
        2: {"destMap": "ROCK_TUNNEL_1F", "destWarp": 6},
        3: {"destMap": "ROCK_TUNNEL_1F", "destWarp": 7},
        4: {"destMap": "ROCK_TUNNEL_1F", "destWarp": 8},
    },
    "ROCK_TUNNEL_POKECENTER": {
        1: {"destMap": "ROUTE_10", "destWarp": 1},
        2: {"destMap": "ROUTE_10", "destWarp": 1},
    },
    "VIRIDIAN_FOREST": {
        1: {"destMap": "VIRIDIAN_FOREST_NORTH_GATE", "destWarp": 3},
        2: {"destMap": "VIRIDIAN_FOREST_NORTH_GATE", "destWarp": 4},
        3: {"destMap": "VIRIDIAN_FOREST_SOUTH_GATE", "destWarp": 1},
        4: {"destMap": "VIRIDIAN_FOREST_SOUTH_GATE", "destWarp": 1},
        5: {"destMap": "VIRIDIAN_FOREST_SOUTH_GATE", "destWarp": 2},
        6: {"destMap": "VIRIDIAN_FOREST_SOUTH_GATE", "destWarp": 2},
    },
    "VIRIDIAN_FOREST_NORTH_GATE": {
        1: {"destMap": "ROUTE_2", "destWarp": 2},
        2: {"destMap": "ROUTE_2", "destWarp": 2},
        3: {"destMap": "VIRIDIAN_FOREST", "destWarp": 1},
        4: {"destMap": "VIRIDIAN_FOREST", "destWarp": 2},
    },
    "VIRIDIAN_FOREST_SOUTH_GATE": {
        1: {"destMap": "VIRIDIAN_FOREST", "destWarp": 3},
        2: {"destMap": "VIRIDIAN_FOREST", "destWarp": 4},
        3: {"destMap": "ROUTE_2", "destWarp": 6},
        4: {"destMap": "ROUTE_2", "destWarp": 6},
    },
    "ROUTE_2": {
        1: {"destMap": "DIGLETTS_CAVE_ROUTE_2", "destWarp": 1},
        2: {"destMap": "VIRIDIAN_FOREST_NORTH_GATE", "destWarp": 1},
        3: {"destMap": "ROUTE_2_TRADE_HOUSE", "destWarp": 1},
        4: {"destMap": "ROUTE_2_GATE", "destWarp": 1},
        5: {"destMap": "ROUTE_2_GATE", "destWarp": 3},
        6: {"destMap": "VIRIDIAN_FOREST_SOUTH_GATE", "destWarp": 3},
    },
    "DIGLETTS_CAVE_ROUTE_2": {
        1: {"destMap": "ROUTE_2", "destWarp": 1},
        2: {"destMap": "ROUTE_2", "destWarp": 1},
        3: {"destMap": "DIGLETTS_CAVE", "destWarp": 1},
    },
    "DIGLETTS_CAVE_ROUTE_11": {
        1: {"destMap": "ROUTE_11", "destWarp": 5},
        2: {"destMap": "ROUTE_11", "destWarp": 5},
        3: {"destMap": "DIGLETTS_CAVE", "destWarp": 2},
    },
    "DIGLETTS_CAVE": {
        1: {"destMap": "DIGLETTS_CAVE_ROUTE_2", "destWarp": 3},
        2: {"destMap": "DIGLETTS_CAVE_ROUTE_11", "destWarp": 3},
    },
    "ROUTE_2_GATE": {
        1: {"destMap": "ROUTE_2", "destWarp": 4},
        2: {"destMap": "ROUTE_2", "destWarp": 4},
        3: {"destMap": "ROUTE_2", "destWarp": 5},
        4: {"destMap": "ROUTE_2", "destWarp": 5},
    },
    "ROUTE_2_TRADE_HOUSE": {
        1: {"destMap": "ROUTE_2", "destWarp": 3},
        2: {"destMap": "ROUTE_2", "destWarp": 3},
    },
    "MT_MOON_1F": {
        1: {"destMap": "ROUTE_3", "destWarp": 1},
        2: {"destMap": "ROUTE_3", "destWarp": 2},
    },
    "MT_MOON_B1F": {
        8: {"destMap": "ROUTE_4", "destWarp": 1},
    },
    "CERULEAN_CAVE_1F": {
        1: {"destMap": "CERULEAN_CITY", "destWarp": 7},
        2: {"destMap": "CERULEAN_CITY", "destWarp": 7},
    },
    "SEAFOAM_ISLANDS_1F": {
        1: {"destMap": "ROUTE_20", "destWarp": 1},
        2: {"destMap": "ROUTE_20", "destWarp": 1},
        3: {"destMap": "ROUTE_20", "destWarp": 2},
        4: {"destMap": "ROUTE_20", "destWarp": 2},
    },
    "SAFARI_ZONE_GATE": {
        1: {"destMap": "FUCHSIA_CITY", "destWarp": 5},
        2: {"destMap": "FUCHSIA_CITY", "destWarp": 5},
    },
    "SAFARI_ZONE_CENTER_REST_HOUSE": {
        1: {"destMap": "SAFARI_ZONE_CENTER", "destWarp": 9},
        2: {"destMap": "SAFARI_ZONE_CENTER", "destWarp": 9},
    },
    "SAFARI_ZONE_EAST_REST_HOUSE": {
        1: {"destMap": "SAFARI_ZONE_EAST", "destWarp": 5},
        2: {"destMap": "SAFARI_ZONE_EAST", "destWarp": 5},
    },
    "SAFARI_ZONE_NORTH_REST_HOUSE": {
        1: {"destMap": "SAFARI_ZONE_NORTH", "destWarp": 9},
        2: {"destMap": "SAFARI_ZONE_NORTH", "destWarp": 9},
    },
    "SAFARI_ZONE_WEST_REST_HOUSE": {
        1: {"destMap": "SAFARI_ZONE_WEST", "destWarp": 8},
        2: {"destMap": "SAFARI_ZONE_WEST", "destWarp": 8},
    },
    "SAFARI_ZONE_SECRET_HOUSE": {
        1: {"destMap": "SAFARI_ZONE_WEST", "destWarp": 7},
        2: {"destMap": "SAFARI_ZONE_WEST", "destWarp": 7},
    },
}

def load_lua_json(lua_path):
    tool_path = os.path.join("tools", "lua_to_json.lua")
    if not os.path.exists(tool_path):
        raise FileNotFoundError(f"Missing {tool_path}")
    proc = subprocess.run(["luajit", tool_path, lua_path], capture_output=True, text=True, check=True)
    return json.loads(proc.stdout)

CLASS_NAME_TO_INDEX = {
    "OPP_YOUNGSTER": 1, "OPP_BUG_CATCHER": 2, "OPP_LASS": 3, "OPP_SAILOR": 4,
    "OPP_JR_TRAINER_M": 5, "OPP_JR_TRAINER_F": 6, "OPP_POKEMANIAC": 7, "OPP_SUPER_NERD": 8,
    "OPP_HIKER": 9, "OPP_BIKER": 10, "OPP_BURGLAR": 11, "OPP_ENGINEER": 12,
    "OPP_UNUSED_JUGGLER": 13, "OPP_FISHER": 14, "OPP_SWIMMER": 15, "OPP_CUE_BALL": 16,
    "OPP_GAMBLER": 17, "OPP_BEAUTY": 18, "OPP_PSYCHIC_TR": 19, "OPP_ROCKER": 20,
    "OPP_JUGGLER": 21, "OPP_TAMER": 22, "OPP_BIRD_KEEPER": 23, "OPP_BLACKBELT": 24,
    "OPP_RIVAL1": 25, "OPP_PROF_OAK": 26, "OPP_CHIEF": 27, "OPP_SCIENTIST": 28,
    "OPP_GIOVANNI": 29, "OPP_ROCKET": 30, "OPP_COOLTRAINER_M": 31, "OPP_COOLTRAINER_F": 32,
    "OPP_BRUNO": 33, "OPP_BROCK": 34, "OPP_MISTY": 35, "OPP_LT_SURGE": 36,
    "OPP_ERIKA": 37, "OPP_KOGA": 38, "OPP_BLAINE": 39, "OPP_SABRINA": 40,
    "OPP_GENTLEMAN": 41, "OPP_RIVAL2": 42, "OPP_RIVAL3": 43, "OPP_LORELEI": 44,
    "OPP_CHANNELER": 45, "OPP_AGATHA": 46, "OPP_LANCE": 47,
}

def build_block_collision(block_tiles, walkable_tiles, ts_id):
    quad_indices = [
        [0, 1, 4, 5],
        [2, 3, 6, 7],
        [8, 9, 12, 13],
        [10, 11, 14, 15]
    ]
    quads = []
    walkable_set = set(walkable_tiles) if walkable_tiles else set()

    for q in quad_indices:
        tiles = [block_tiles[i] for i in q if i < len(block_tiles)]
        
        if ts_id == "CAVERN":
            CAVERN_WALL_TILES = {4, 7, 16, 18, 23, 28, 30, 36, 38, 40, 49, 60}
            CAVERN_STAIR_TILES = {8, 9, 10, 11, 24, 25, 26, 27}
            CAVERN_PIT_TILES = {33}
            CAVERN_WATER_TILES = {20, 50, 72}
            CAVERN_ELEVATION_STAIRS = {43, 44, 45, 46}
            
            CAVERN_WARP_CARPET_TILES = {29, 31, 34, 15}
            
            if any(t in CAVERN_PIT_TILES for t in tiles):
                quads.append(0x68)  # COLL_PIT
            elif any(t in CAVERN_STAIR_TILES for t in tiles):
                quads.append(0x7A)  # COLL_STAIRCASE (warp stairs / ladders)
            elif any(t in CAVERN_WARP_CARPET_TILES for t in tiles):
                quads.append(0x76)  # COLL_WARP_CARPET_DOWN (cave exit mat)
            elif any(t in CAVERN_ELEVATION_STAIRS for t in tiles):
                quads.append(0x00)  # COLL_LAND (in-map wooden stairs between elevations)
            elif any(t in CAVERN_WATER_TILES for t in tiles):
                quads.append(0x29)  # COLL_WATER
            elif any(t in CAVERN_WALL_TILES for t in tiles):
                quads.append(0x07)  # COLL_WALL
            elif all(t in walkable_set or t in {5, 21, 22, 32, 34, 41, 42, 47, 48} for t in tiles):
                quads.append(0x00)  # COLL_LAND
            else:
                quads.append(0x07)  # COLL_WALL
        elif ts_id == "OVERWORLD":
            if any(t == 88 for t in tiles):
                quads.append(0x7B)  # COLL_CAVE (cave entrance door)
            elif any(t == 27 for t in tiles):
                quads.append(0x71)  # COLL_DOOR (building door)
            elif any(t == 82 for t in tiles):
                quads.append(0x18)  # COLL_TALL_GRASS
            elif all(t in walkable_set for t in tiles):
                quads.append(0x00)  # COLL_LAND
            else:
                quads.append(0x07)  # COLL_WALL
        elif ts_id == "FOREST":
            FOREST_GRASS_TILES = {32, 52, 82, 0x20, 0x52}
            FOREST_WARP_TILES = {58, 80, 83, 8, 9, 24, 25, 53, 54, 56}
            FOREST_WATER_TILES = {20, 72, 73, 74, 77, 78, 79, 90, 91, 92, 93, 94}
            FOREST_WALL_TILES = {1, 2, 3, 4, 5, 6, 7, 16, 17, 18, 19, 21, 22, 23, 40, 41, 42, 43, 44, 45, 59, 66, 67, 33, 34, 49, 50, 10, 11, 26, 27, 75, 76}
            
            if any(t in FOREST_WATER_TILES for t in tiles):
                quads.append(0x29)  # COLL_WATER
            elif any(t in FOREST_GRASS_TILES for t in tiles):
                quads.append(0x18)  # COLL_TALL_GRASS
            elif any(t in FOREST_WARP_TILES for t in tiles):
                quads.append(0x76)  # COLL_WARP_CARPET_DOWN
            elif any(t in FOREST_WALL_TILES for t in tiles):
                quads.append(0x07)  # COLL_WALL
            elif all(t in walkable_set or t in {30, 46, 48, 55, 57, 64, 81, 94, 95} for t in tiles):
                quads.append(0x00)  # COLL_LAND
            else:
                if tiles[2] in walkable_set and not any(t in FOREST_WALL_TILES for t in tiles):
                    quads.append(0x00)
                else:
                    quads.append(0x07)
        elif ts_id == "GYM":
            GYM_WARP_TILES = {21, 22, 74}
            GYM_COUNTER_TILES = {58}
            
            if any(t in GYM_WARP_TILES for t in tiles):
                quads.append(0x76)  # COLL_WARP_CARPET_DOWN
            elif any(t in GYM_COUNTER_TILES for t in tiles):
                quads.append(0x90)  # COLL_COUNTER
            elif all(t in walkable_set for t in tiles):
                quads.append(0x00)  # COLL_LAND
            else:
                quads.append(0x07)  # COLL_WALL
        elif ts_id in {"HOUSE", "INTERIOR", "LAB", "GATE", "CLUB"}:
            HOUSE_WARP_TILES = {26, 27, 28, 59, 4, 20, 39, 52, 55, 80, 83, 91, 92}
            HOUSE_COUNTER_TILES = {23, 50, 58, 80, 81}
            if any(t in HOUSE_WARP_TILES for t in tiles):
                quads.append(0x76)  # COLL_WARP_CARPET_DOWN
            elif any(t in HOUSE_COUNTER_TILES for t in tiles):
                quads.append(0x90)  # COLL_COUNTER
            elif all(t in walkable_set for t in tiles) or (len(tiles) >= 3 and tiles[2] in walkable_set):
                quads.append(0x00)  # COLL_LAND
            else:
                quads.append(0x07)  # COLL_WALL
        elif ts_id == "POKECENTER":
            POKECENTER_WARP_TILES = {27, 28, 91, 92, 59, 4, 20, 39, 55}
            POKECENTER_COUNTER_TILES = {58, 80, 81}
            if any(t in POKECENTER_WARP_TILES for t in tiles):
                quads.append(0x76)  # COLL_WARP_CARPET_DOWN
            elif any(t in POKECENTER_COUNTER_TILES for t in tiles):
                quads.append(0x90)  # COLL_COUNTER
            elif all(t in walkable_set for t in tiles) or (len(tiles) >= 3 and tiles[2] in walkable_set):
                quads.append(0x00)  # COLL_LAND
            else:
                quads.append(0x07)  # COLL_WALL
        else:
            if all(t in walkable_set for t in tiles):
                quads.append(0x00)
            else:
                quads.append(0x07)
    return quads

def lua_encode(val, indent=0):
    ind = "  " * indent
    if val is None:
        return "nil"
    elif isinstance(val, bool):
        return "true" if val else "false"
    elif isinstance(val, (int, float)):
        return str(val)
    elif isinstance(val, str):
        escaped = val.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{escaped}"'
    elif isinstance(val, list):
        if not val:
            return "{}"
        if all(isinstance(x, (int, float, bool, str)) for x in val) and len(val) <= 20:
            items = ", ".join(lua_encode(x) for x in val)
            return f"{{ {items} }}"
        lines = ["{"]
        for item in val:
            lines.append(f"{ind}  {lua_encode(item, indent + 1)},")
        lines.append(f"{ind}}}")
        return "\n".join(lines)
    elif isinstance(val, dict):
        if not val:
            return "{}"
        lines = ["{"]
        keys = sorted(val.keys(), key=lambda k: (isinstance(k, int), str(k)))
        for k in keys:
            key_str = f"[{k}]" if isinstance(k, int) else (f'["{k}"]' if not str(k).isidentifier() else str(k))
            lines.append(f"{ind}  {key_str} = {lua_encode(val[k], indent + 1)},")
        lines.append(f"{ind}}}")
        return "\n".join(lines)
    return "nil"

def generate_blaine_gym():
    """Generates Blaine's Gym dedicated interior room definition (SEAFOAM_GYM)."""
    return {
        "id": "SEAFOAM_GYM",
        "label": "SeafoamGym",
        "index": 1300,
        "width": 6,
        "height": 8,
        "tileset": "GYM",
        "gen1Tileset": "GYM",
        "environment": "GYM",
        "palette": "PALETTE_DAY",
        "borderBlock": 14,
        "blocks": [
            14, 14, 14, 14, 14, 14,
            14,  1,  2,  3,  4, 14,
            14,  5,  6,  7,  8, 14,
            14,  9, 10, 11, 12, 14,
            14, 13, 14, 15, 16, 14,
            14, 17, 18, 19, 20, 14,
            14, 21, 22, 23, 24, 14,
            14, 14,  1,  1, 14, 14,
        ],
        "warps": [
            {"x": 4, "y": 15, "destMap": "SEAFOAM_ISLANDS_1F", "destWarp": 5},
            {"x": 5, "y": 15, "destMap": "SEAFOAM_ISLANDS_1F", "destWarp": 5},
        ],
        "signs": [
            {"x": 3, "y": 13, "text": "TEXT_CINNABAR_GYM_STATUE"},
            {"x": 6, "y": 13, "text": "TEXT_CINNABAR_GYM_STATUE"},
        ],
        "bgEvents": [
            {"x": 3, "y": 13, "kind": 0, "scriptKey": [{"op": "opentext"}, {"op": "writetext", "text": "CINNABAR ISLAND POKEMON GYM\nLEADER: BLAINE"}, {"op": "waitbutton"}, {"op": "closetext"}], "text": "CINNABAR ISLAND POKEMON GYM\nLEADER: BLAINE"},
            {"x": 6, "y": 13, "kind": 0, "scriptKey": [{"op": "opentext"}, {"op": "writetext", "text": "CINNABAR ISLAND POKEMON GYM\nLEADER: BLAINE"}, {"op": "waitbutton"}, {"op": "closetext"}], "text": "CINNABAR ISLAND POKEMON GYM\nLEADER: BLAINE"},
        ],
        "objects": [
            {
                "index": 1,
                "name": "SEAFOAM_GYM_BLAINE",
                "sprite": "SPRITE_BLAINE",
                "x": 5,
                "y": 3,
                "movement": 6,
                "range": "DOWN",
                "text": "TEXT_CINNABARGYM_BLAINE",
                "trainerClass": "OPP_BLAINE",
                "trainerParty": 1,
                "level": 60,
                "sight": 3,
                "trainer": {
                    "class": "OPP_BLAINE",
                    "member": 1,
                    "party": 1,
                    "event": 2998,
                    "sight": 3,
                    "seenText": "TEXT_CINNABARGYM_BLAINE",
                    "winText": "Defeated!",
                    "lossText": "Better luck next time!",
                    "text": ["TEXT_CINNABARGYM_BLAINE", "Defeated!", "Better luck next time!"]
                }
            }
        ],
        "connections": {}
    }

MAP_MUSIC_MAP = {
    "VIRIDIAN_FOREST": 140, # Music_Route2 (0x80 | 12)
    "VIRIDIAN_FOREST_SOUTH_GATE": 140,
    "VIRIDIAN_FOREST_NORTH_GATE": 140,
    "ROUTE_2": 140,
    "ROUTE_2_GATE": 140,
    "MT_MOON_1F": 141, # Music_MtMoon (0x80 | 13)
    "MT_MOON_B1F": 141,
    "MT_MOON_B2F": 141,
    "DIGLETTS_CAVE": 141, # Music_MtMoon (0x80 | 13)
    "DIGLETTS_CAVE_ROUTE_2": 141,
    "DIGLETTS_CAVE_ROUTE_11": 141,
    "SEAFOAM_ISLANDS_1F": 153, # Music_UnionCave (0x80 | 25)
    "SEAFOAM_ISLANDS_B1F": 153,
    "SEAFOAM_ISLANDS_B2F": 153,
    "SEAFOAM_ISLANDS_B3F": 153,
    "SEAFOAM_ISLANDS_B4F": 153,
    "CERULEAN_CAVE_1F": 153, # Music_UnionCave (0x80 | 25)
    "CERULEAN_CAVE_2F": 153,
    "CERULEAN_CAVE_B1F": 153,
    "ROCK_TUNNEL_1F": 164, # Music_DarkCave (0x80 | 36)
    "ROCK_TUNNEL_B1F": 164,
    "ROCK_TUNNEL_POKECENTER": 134, # Music_PokemonCenter (0x80 | 6)
    "POWER_PLANT": 185, # Music_RocketHideout (0x80 | 57)
    "POKEMON_TOWER_1F": 139, # Music_LavenderTown (0x80 | 11)
    "POKEMON_TOWER_2F": 139,
    "POKEMON_TOWER_3F": 139,
    "POKEMON_TOWER_4F": 139,
    "POKEMON_TOWER_5F": 139,
    "POKEMON_TOWER_6F": 139,
    "POKEMON_TOWER_7F": 139,
    "POKEMON_MANSION_1F": 185, # Music_RocketHideout (0x80 | 57)
    "POKEMON_MANSION_2F": 185,
    "POKEMON_MANSION_3F": 185,
    "POKEMON_MANSION_B1F": 185,
    "SAFARI_ZONE_CENTER": 148, # Music_NationalPark (0x80 | 20)
    "SAFARI_ZONE_EAST": 148,
    "SAFARI_ZONE_NORTH": 148,
    "SAFARI_ZONE_WEST": 148,
    "SAFARI_ZONE_GATE": 148,
    "SAFARI_ZONE_CENTER_REST_HOUSE": 148,
    "SAFARI_ZONE_EAST_REST_HOUSE": 148,
    "SAFARI_ZONE_NORTH_REST_HOUSE": 148,
    "SAFARI_ZONE_WEST_REST_HOUSE": 148,
    "SAFARI_ZONE_SECRET_HOUSE": 148,
    "VICTORY_ROAD": 192, # Music_VictoryRoad (0x80 | 64)
    "SEAFOAM_GYM": 146, # Music_Gym (0x80 | 18)
}

MAP_PALETTE_MAP = {
    "ROCK_TUNNEL_1F": "PALETTE_DARK",
    "ROCK_TUNNEL_B1F": "PALETTE_DARK",
}

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    os.chdir(root_dir)

    print("Extracting Gen 1 data from data/generated/...")
    maps_data = load_lua_json("data/generated/maps.lua")
    tilesets_data = load_lua_json("data/generated/tilesets.lua")
    encounters_data = load_lua_json("data/generated/encounters.lua")
    pokemon_data = load_lua_json("data/generated/pokemon.lua")
    gbc_palettes = load_lua_json("data/palettes_gbc.lua")
    world_palettes = gbc_palettes.get("world", {})

    evo_map = {}
    for p_id, p_def in pokemon_data.items():
        evos = p_def.get("evolutions", [])
        for e in evos:
            to_spec = e.get("species")
            method = e.get("method")
            level = e.get("level", 30)
            if method == "STONE":
                level = 36
            elif method == "TRADE":
                level = 38
            if to_spec and p_id not in evo_map:
                evo_map[p_id] = {"to": to_spec, "level": level}

    root_map = {}
    for p_id in pokemon_data:
        root_map[p_id] = p_id
    for base, evo in evo_map.items():
        cur = evo["to"]
        root_map[cur] = root_map.get(base, base)

    def get_evolved(sp, target_level, stage_count=1):
        cur = sp
        for _ in range(stage_count):
            if cur in evo_map:
                evo = evo_map[cur]
                if target_level >= evo["level"]:
                    cur = evo["to"]
                else:
                    break
            else:
                break
        return cur

    COCOON_SPECIES = {"KAKUNA": True, "METAPOD": True, "SILCOON": True, "CASCOON": True, "PUPITAR": True}

    def promote_slots(slots):
        family_indices = {}
        for idx, s in enumerate(slots):
            fam = root_map.get(s["species"], s["species"])
            if fam not in family_indices:
                family_indices[fam] = []
            family_indices[fam].append(idx)
        
        out = [dict(s) for s in slots]
        for fam, indices in family_indices.items():
            total = len(indices)
            cocoon_placed = False
            for rank, idx in enumerate(indices):
                s = out[idx]
                sp = s["species"]
                lvl = s["level"]
                if total == 1:
                    if sp in evo_map and lvl >= evo_map[sp]["level"] + 20 and idx >= len(slots) * 0.7:
                        promoted = get_evolved(sp, lvl, 1)
                        if promoted in COCOON_SPECIES:
                            promoted = get_evolved(promoted, lvl, 1)
                        s["species"] = promoted
                elif total == 2:
                    if rank == 1:
                        promoted = get_evolved(sp, lvl, 1)
                        if promoted in COCOON_SPECIES and lvl >= 25:
                            promoted = get_evolved(promoted, lvl, 1)
                        s["species"] = promoted
                elif total >= 3:
                    if rank == 0:
                        pass # keep active base form
                    elif rank == 1:
                        # Primary common slot gets active adult
                        s["species"] = get_evolved(sp, lvl, 2)
                    elif rank == 2:
                        # Intermediate slot allows 1 cocoon or stage 1 form
                        promoted = get_evolved(sp, lvl, 1)
                        if promoted in COCOON_SPECIES:
                            if not cocoon_placed:
                                cocoon_placed = True
                            else:
                                promoted = get_evolved(promoted, lvl, 1)
                        s["species"] = promoted
                    else:
                        # Further slots promote to full adult / final forms
                        s["species"] = get_evolved(sp, lvl, 2)
        return out

    restored_maps = {}
    restored_tilesets = {}
    restored_encounters = {}
    restored_gen2_encounters = {"grass": {}, "water": {}}

    # Build tileset records with full blocks, walkable, tilePalettes, and 8-color BG palette sets
    for ts_id, ts_def in tilesets_data.items():
        blocks = ts_def.get("blocks", [])
        walkable = ts_def.get("walkable") or ts_def.get("walkableTiles") or []
        collision_quads = []
        for b in blocks:
            quads = build_block_collision(b, walkable, ts_id)
            collision_quads.append(quads)
        
        record = dict(ts_def)
        record["collision"] = collision_quads

        # Attach GBC 8-color BG palette set and tile-to-palette mapping (tilePalettes)
        group_pals = world_palettes.get("groupColors", {}).get(ts_id)
        if group_pals:
            record["palettes"] = group_pals

        tile_groups = world_palettes.get("tileGroups", {}).get(ts_id, {})
        if tile_groups:
            tile_pals = []
            for tid in range(256):
                slot = tile_groups.get(str(tid), tile_groups.get(tid, 0))
                tile_pals.append(int(slot) + 1)
            record["tilePalettes"] = tile_pals
        if ts_id == "OVERWORLD":
            rec_blocks = list(record.get("blocks", []))
            rec_coll = list(record.get("collision", []))
            while len(rec_blocks) <= 165:
                rec_blocks.append([0] * 16)
                rec_coll.append([0x07] * 4)
            rec_blocks[58] = [10, 75, 75, 10, 75, 75, 75, 75, 11, 12, 10, 10, 27, 28, 26, 26]
            rec_coll[58] = [0x07, 0x07, 0x71, 0x71]
            rec_blocks[138] = [10, 75, 75, 10, 75, 75, 75, 75, 11, 12, 10, 10, 27, 28, 26, 26]
            rec_coll[138] = [0x07, 0x07, 0x71, 0x71]
            record["blocks"] = rec_blocks
            record["collision"] = rec_coll

        restored_tilesets[ts_id] = record

    gold_ts_path = os.path.expanduser("~/.local/share/love/pokemon-love2d/gold/data/generated/tilesets.lua")
    if os.path.exists(gold_ts_path):
        gold_tilesets = load_lua_json(gold_ts_path)
        if "TILESET_KANTO" in gold_tilesets:
            kanto_rec = dict(gold_tilesets["TILESET_KANTO"])
            kanto_blocks = list(kanto_rec.get("blocks", []))
            kanto_coll = list(kanto_rec.get("collision", []))
            max_custom = max([165] + list(CUSTOM_KANTO_BLOCKS.keys()))
            while len(kanto_blocks) <= max_custom:
                kanto_blocks.append([0] * 16)
                kanto_coll.append([0x07] * 4)
            for idx, c_def in CUSTOM_KANTO_BLOCKS.items():
                kanto_blocks[idx] = list(c_def["tiles"])
                kanto_coll[idx] = list(c_def["collision"])
            kanto_blocks[58] = [50, 75, 75, 50, 75, 75, 75, 75, 11, 12, 10, 10, 27, 28, 26, 26]
            kanto_coll[58] = [0x07, 0x07, 0x71, 0x71]
            kanto_rec["blocks"] = kanto_blocks
            kanto_rec["collision"] = kanto_coll
            kanto_pals = list(kanto_rec.get("tilePalettes", []))
            if len(kanto_pals) >= 84:
                kanto_pals[77] = 1
                kanto_pals[78] = 1
                kanto_pals[83] = 1
            kanto_rec["tilePalettes"] = kanto_pals
            restored_tilesets["TILESET_KANTO"] = kanto_rec



    for map_idx, map_id in enumerate(TARGET_MAPS, 1):
        if map_id in maps_data:
            mdef = dict(maps_data[map_id])
            lvl_info = TRAINER_LEVEL_MAP.get(map_id)
            
            ts_gen1 = mdef.get("tileset")
            mdef["gen1Tileset"] = ts_gen1

            # Map to native Gen 2 tilesets, blocksets, and environments
            if map_id == "VIRIDIAN_FOREST":
                mdef["tileset"] = "TILESET_KANTO"
                mdef["environment"] = "ROUTE"
                mdef["palette"] = "PALETTE_AUTO"
                mdef["borderBlock"] = 15
                v_blocks = [FOREST_G1_TO_G2.get(b, 15) for b in mdef.get("blocks", [])]
                v_blocks[0 * 17 + 0] = 137
                v_blocks[0 * 17 + 1] = 137
                mdef["blocks"] = v_blocks
            elif map_id == "ROUTE_2":
                mdef["tileset"] = "TILESET_KANTO"
                mdef["environment"] = "ROUTE"
                mdef["palette"] = "PALETTE_AUTO"
                mdef["borderBlock"] = 15
                mdef["blocks"] = list(mdef.get("blocks", []))
                mdef["connections"] = {
                    "north": {"map": "PEWTER_CITY", "offset": -5},
                    "south": {"map": "VIRIDIAN_CITY", "offset": -5}
                }
            elif map_id in ("VIRIDIAN_FOREST_NORTH_GATE", "VIRIDIAN_FOREST_SOUTH_GATE", "ROUTE_2_GATE", "SAFARI_ZONE_GATE"):
                mdef["tileset"] = "TILESET_GATE"
                mdef["environment"] = "GATE"
                mdef["palette"] = "PALETTE_DAY"
                mdef["borderBlock"] = 0
                mdef["width"] = 5
                mdef["height"] = 4
                mdef["blocks"] = list(GEN2_GATE_BLOCKS)
            elif map_id == "ROUTE_2_TRADE_HOUSE" or (map_id.startswith("SAFARI_ZONE_") and (map_id.endswith("REST_HOUSE") or map_id.endswith("SECRET_HOUSE"))):
                mdef["tileset"] = "TILESET_HOUSE"
                mdef["environment"] = "INDOOR"
                mdef["palette"] = "PALETTE_DAY"
                mdef["borderBlock"] = 0
                mdef["width"] = 4
                mdef["height"] = 4
                mdef["blocks"] = list(GEN2_HOUSE_BLOCKS)
            elif map_id.startswith("MT_MOON") or map_id.startswith("CERULEAN_CAVE") or map_id.startswith("SEAFOAM_ISLANDS") or map_id.startswith("DIGLETTS_CAVE"):
                # Use the Gen 1 tileset id as environment so bakeMapImage picks the
                # custom environments[CAVERN] row registered from groupColors, not
                # Gold's generic CAVE pool (which left these maps grayscale).
                mdef["tileset"] = ts_gen1
                mdef["environment"] = ts_gen1
                mdef["palette"] = "PALETTE_DAY"
                if ts_gen1 in restored_tilesets:
                    mdef["collision"] = restored_tilesets[ts_gen1]["collision"]
            elif map_id.startswith("SAFARI_ZONE") and not map_id.endswith("HOUSE") and not map_id.endswith("GATE"):
                mdef["tileset"] = "TILESET_KANTO"
                mdef["environment"] = "ROUTE"
                mdef["palette"] = "PALETTE_AUTO"
                mdef["borderBlock"] = 15
                s_blocks = [SAFARI_G1_TO_G2.get(b, 1) for b in mdef.get("blocks", [])]
                if map_id == "SAFARI_ZONE_CENTER":
                    s_blocks[12 * 15 + 7] = 136  # South exit warp pad to SAFARI_ZONE_GATE
                mdef["blocks"] = s_blocks
            else:
                mdef["tileset"] = ts_gen1
                mdef["environment"] = ts_gen1
                mdef["palette"] = "PALETTE_DAY"

            ts_final = mdef.get("tileset")
            if ts_final in restored_tilesets:
                mdef["collision"] = restored_tilesets[ts_final]["collision"]

            if map_id == "VIRIDIAN_FOREST":
                warps = [
                    # 1-2: North Exit & Entrance (arrive facing DOWN; exit when stepping UP)
                    {"x": 1, "y": 0, "destMap": "VIRIDIAN_FOREST_NORTH_GATE_KR", "destWarp": 3},
                    {"x": 2, "y": 0, "destMap": "VIRIDIAN_FOREST_NORTH_GATE_KR", "destWarp": 4},
                    # 3-4: South Exit & Entrance (arrive facing UP; exit when stepping DOWN)
                    {"x": 16, "y": 47, "destMap": "VIRIDIAN_FOREST_SOUTH_GATE_KR", "destWarp": 1},
                    {"x": 17, "y": 47, "destMap": "VIRIDIAN_FOREST_SOUTH_GATE_KR", "destWarp": 2},
                ]
            elif map_id == "DIGLETTS_CAVE_ROUTE_11":
                warps = [
                    {"x": 2, "y": 7, "destMap": "VERMILION_CITY", "destWarp": 10},
                    {"x": 3, "y": 7, "destMap": "VERMILION_CITY", "destWarp": 10},
                    {"x": 4, "y": 4, "destMap": "DIGLETTS_CAVE_KR", "destWarp": 2},
                ]
            elif map_id == "SAFARI_ZONE_GATE":

                warps = [
                    {"x": 4, "y": 7, "destMap": "FUCHSIA_CITY", "destWarp": 7},
                    {"x": 5, "y": 7, "destMap": "FUCHSIA_CITY", "destWarp": 7},
                    {"x": 4, "y": 0, "destMap": "SAFARI_ZONE_CENTER_KR", "destWarp": 1},
                    {"x": 5, "y": 0, "destMap": "SAFARI_ZONE_CENTER_KR", "destWarp": 2},
                ]

            else:
                warps = []
                for idx, w in enumerate(mdef.get("warps", []), 1):
                    w_copy = dict(w)
                    if map_id in MAP_WARP_EXPLICIT_REDIRECTS and idx in MAP_WARP_EXPLICIT_REDIRECTS[map_id]:
                        red = MAP_WARP_EXPLICIT_REDIRECTS[map_id][idx]
                        w_copy["destMap"] = red["destMap"]
                        w_copy["destWarp"] = red["destWarp"]
                    elif w_copy.get("destMap") == "LAST_MAP":
                        w_copy["destWarp"] = 0xff
                    dest = w_copy.get("destMap")
                    if dest and dest in TARGET_MAPS:
                        w_copy["destMap"] = dest + "_KR"
                    warps.append(w_copy)
            mdef["warps"] = warps
            coord_events = list(mdef.get("coordEvents", []))
            mdef["coordEvents"] = coord_events

            RANGE_TO_MOVE = {
                "DOWN": 6,
                "UP": 7,
                "LEFT": 8,
                "RIGHT": 9,
                "NONE": 1,
            }

            objects = []
            for obj_idx, obj in enumerate(mdef.get("objects", []), 1):
                obj_copy = dict(obj)
                spr = obj_copy.get("sprite")
                if isinstance(spr, int):
                    obj_copy["sprite"] = GEN1_TO_GEN2_SPRITE.get(spr, "SPRITE_YOUNGSTER")
                elif spr == "SPRITE_GIRL":
                    obj_copy["sprite"] = "SPRITE_LASS"
                elif spr == "SPRITE_LITTLE_GIRL":
                    obj_copy["sprite"] = "SPRITE_TWIN"

                # Gatehouse NPC position adjustments for Gen 2 gate layout
                if map_id in ("ROUTE_2_GATE", "VIRIDIAN_FOREST_NORTH_GATE", "VIRIDIAN_FOREST_SOUTH_GATE", "SAFARI_ZONE_GATE"):
                    if obj_idx == 1:
                        obj_copy["x"], obj_copy["y"] = 6, 4
                    elif obj_idx == 2:
                        obj_copy["x"], obj_copy["y"] = 3, 2
                
                # Movement & facing mapping for Gen 2
                range_raw = str(obj_copy.get("range", "DOWN"))
                facing_dir = range_raw.lower()
                if facing_dir not in ("down", "up", "left", "right"):
                    facing_dir = "down"
                obj_copy["facing"] = facing_dir

                if obj_copy.get("movement") == "WALK":
                    obj_copy["movement"] = 2
                else:
                    obj_copy["movement"] = RANGE_TO_MOVE.get(range_raw, 6)

                if obj_copy.get("text", "").endswith("_VOLTORB") or obj_copy.get("text", "").endswith("_ELECTRODE"):
                    obj_copy["isTrap"] = True
                
                event_num = 2000 + map_idx * 50 + obj_idx

                if "trainerClass" in obj_copy:
                    if lvl_info:
                        obj_copy["level"] = lvl_info["base"]
                    sight = obj_copy.get("sight", 3)
                    obj_copy["sight"] = sight
                    party_num = obj_copy.get("trainerParty", 1)
                    
                    nice_name = obj_copy.get("name", "TRAINER").replace("TEXT_", "").split("_")[-1].capitalize()
                    class_id = obj_copy["trainerClass"]
                    class_num = CLASS_NAME_TO_INDEX.get(class_id, class_id)
                    
                    text_key = obj_copy.get("text", "TEXT_TRAINER")
                    win_key = text_key + "_WIN"
                    
                    talk_after_script = [
                        {"op": "opentext"},
                        {"op": "writetext", "text": win_key},
                        {"op": "waitbutton"},
                        {"op": "closetext"}
                    ]
                    
                    obj_copy["trainer"] = {
                        "class": class_num,
                        "className": class_id,
                        "member": party_num,
                        "party": party_num,
                        "event": event_num,
                        "sight": sight,
                        "seenText": text_key,
                        "winText": win_key,
                        "lossText": "Better luck next time!",
                        "text": [text_key, win_key, "Better luck next time!"],
                        "scriptKey": talk_after_script
                    }
                elif obj_copy.get("item"):
                    item_name = obj_copy["item"]
                    # Swap Gen 1 Red specific items for Gen 2 canon equivalents:
                    if item_name == "GOLD_TEETH":
                        item_name = "LEFTOVERS"  # Rare prize for reaching deep Safari West
                    elif item_name == "TM_EGG_BOMB":
                        item_name = "TM_DETECT"  # Gen 2 TM43
                    elif item_name == "TM_SKULL_BASH":
                        item_name = "TM_DEFENSE_CURL"  # Gen 2 TM40
                    elif item_name == "TM_DOUBLE_TEAM":
                        item_name = "TM_DOUBLE_TEAM"  # Gen 2 TM32

                    obj_copy["item"] = item_name
                    obj_copy["itemball"] = {
                        "item": item_name,
                        "quantity": 1
                    }
                    obj_copy["eventFlag"] = event_num
                elif "text" in obj_copy:
                    obj_copy["scriptKey"] = [
                        {"op": "faceplayer"},
                        {"op": "opentext"},
                        {"op": "writetext", "text": obj_copy.get("text", "")},
                        {"op": "waitbutton"},
                        {"op": "closetext"}
                    ]

                objects.append(obj_copy)

            mdef["objects"] = objects

            # Gen 2 Mount Moon Silver (coord-event battle near Route 3 entrance).
            # Runtime also injects this; keep him in regenerated data so _KR maps
            # aren't empty of the rival after a restore_kanto_dungeons.py run.
            if map_id == "MT_MOON_1F":
                has_rival = any(
                    o.get("name") == "MT_MOON_1F_SILVER_RIVAL" or o.get("isRivalEvent")
                    for o in mdef["objects"]
                )
                if not has_rival:
                    mdef["objects"].append({
                        "index": 14,
                        "name": "MT_MOON_1F_SILVER_RIVAL",
                        "sprite": "SPRITE_RIVAL",
                        "x": 14,
                        "y": 28,
                        "range": "DOWN",
                        "movement": 6,
                        "sight": 0,
                        "event": 793,
                        "eventFlag": 793,
                        "isRivalEvent": True,
                        "level": 58,
                        "trainerClass": "OPP_RIVAL2",
                        "trainerParty": 1,
                        "text": "TEXT_MT_MOON_SILVER_RIVAL_SEEN",
                    })
                mdef["coordEvents"] = [
                    {"sceneId": 0, "x": 14, "y": 34, "scriptKey": "MT_MOON_RIVAL_LEFT"},
                    {"sceneId": 0, "x": 14, "y": 33, "scriptKey": "MT_MOON_RIVAL_LEFT"},
                    {"sceneId": 0, "x": 15, "y": 34, "scriptKey": "MT_MOON_RIVAL_RIGHT"},
                    {"sceneId": 0, "x": 15, "y": 33, "scriptKey": "MT_MOON_RIVAL_RIGHT"},
                ]

            # Build bgEvents for signposts
            bg_events = []
            for s_idx, s in enumerate(mdef.get("signs", []), 1):
                sign_text = s.get("text", "Sign")
                bg_events.append({
                    "x": s.get("x", 0),
                    "y": s.get("y", 0),
                    "kind": 0,
                    "scriptKey": [
                        {"op": "opentext"},
                        {"op": "writetext", "text": sign_text},
                        {"op": "waitbutton"},
                        {"op": "closetext"}
                    ],
                    "text": sign_text
                })
            mdef["bgEvents"] = bg_events

            if "connections" in mdef and isinstance(mdef["connections"], dict):

                norm_conn = {}
                for c_dir, c_val in mdef["connections"].items():
                    c_copy = dict(c_val)
                    if "map" in c_copy and "mapId" not in c_copy:
                        c_copy["mapId"] = c_copy["map"]
                    if "mapId" in c_copy and "map" not in c_copy:
                        c_copy["map"] = c_copy["mapId"]
                    norm_conn[c_dir] = c_copy
                mdef["connections"] = norm_conn

            if map_id in MAP_MUSIC_MAP:
                mdef["music"] = MAP_MUSIC_MAP[map_id]
            elif "music" not in mdef:
                mdef["music"] = 140
            if map_id in MAP_PALETTE_MAP:
                mdef["palette"] = MAP_PALETTE_MAP[map_id]
            mdef["id"] = map_id + "_KR"
            restored_maps[map_id + "_KR"] = mdef

            if map_id in encounters_data:
                raw_enc = encounters_data[map_id]
                enc_copy = json.loads(json.dumps(raw_enc))
                scale = ENCOUNTER_LEVEL_MAP.get(map_id)
                if scale:
                    for kind in ("grass", "water"):
                        slots = enc_copy.get(kind, {}).get("slots", [])
                        if slots:
                            g1_levels = [s["level"] for s in slots if "level" in s]
                            if g1_levels:
                                min_l, max_l = min(g1_levels), max(g1_levels)
                                for s in slots:
                                    if "level" in s:
                                        lvl = s["level"]
                                        if max_l > min_l:
                                            rel = (lvl - min_l) / (max_l - min_l)
                                            s["level"] = int(round(scale["base"] - scale["variance"]/2 + rel * scale["variance"]))
                                        else:
                                            s["level"] = scale["base"]
                            enc_copy[kind]["slots"] = promote_slots(slots)
                restored_encounters[map_id + "_KR"] = enc_copy

                # Also generate Gen 2 native format for Gold engine (7 slots per TOD for grass, 3 for water)
                if "grass" in enc_copy and enc_copy["grass"].get("slots"):
                    g_slots = enc_copy["grass"]["slots"]
                    g2_indices = [0, 1, 2, 3, 6, 8, 9]
                    g2_slots = [dict(g_slots[min(i, len(g_slots)-1)]) for i in g2_indices]
                    g_rate = enc_copy["grass"].get("rate", 25) or 25
                    g2_entry = {
                        "rates": {"MORN": g_rate, "DAY": g_rate, "NITE": g_rate},
                        "slots": {
                            "MORN": [dict(s) for s in g2_slots],
                            "DAY": [dict(s) for s in g2_slots],
                            "NITE": [dict(s) for s in g2_slots],
                        }
                    }
                    restored_gen2_encounters["grass"][map_id + "_KR"] = g2_entry

                if "water" in enc_copy and enc_copy["water"].get("slots"):
                    w_slots = [dict(s) for s in enc_copy["water"]["slots"][:3]]
                    w_rate = enc_copy["water"].get("rate", 10) or 10
                    w_entry = {
                        "rate": w_rate,
                        "slots": w_slots
                    }
                    restored_gen2_encounters["water"][map_id + "_KR"] = w_entry

    blaine_gym = generate_blaine_gym()
    if blaine_gym["tileset"] in restored_tilesets:
        blaine_gym["collision"] = restored_tilesets[blaine_gym["tileset"]]["collision"]
    blaine_gym["id"] = "SEAFOAM_GYM_KR"
    restored_maps["SEAFOAM_GYM_KR"] = blaine_gym

    seafoam_patches = {
        "SEAFOAM_ISLANDS_B3F": [
            {"x": 18, "y": 7, "targetQuad": 0x24},
            {"x": 19, "y": 7, "targetQuad": 0x24},
        ],
        "SEAFOAM_ISLANDS_B4F": [
            {"x": 4, "y": 14, "targetQuad": 0x24},
            {"x": 5, "y": 14, "targetQuad": 0x24},
        ]
    }

    out_file = os.path.join("mods", "Kanto-Reforged", "world", "restored_dungeons_data.lua")
    os.makedirs(os.path.dirname(out_file), exist_ok=True)

    with open(out_file, "w", encoding="utf-8") as f:
        f.write("-- restored_dungeons_data.lua\n")
        f.write("-- Generated by tools/restore_kanto_dungeons.py\n\n")
        f.write("local Data = {}\n\n")
        f.write(f"Data.maps = {lua_encode(restored_maps)}\n\n")
        f.write(f"Data.tilesets = {lua_encode(restored_tilesets)}\n\n")
        f.write(f"Data.encounters = {lua_encode(restored_encounters)}\n\n")
        f.write(f"Data.gen2Encounters = {lua_encode(restored_gen2_encounters)}\n\n")
        f.write(f"Data.seafoamBoulderPatches = {lua_encode(seafoam_patches)}\n\n")
        f.write("return Data\n")

    print(f"Successfully generated {out_file} ({len(restored_maps)} maps, {len(restored_tilesets)} tilesets)!")

if __name__ == "__main__":
    main()
