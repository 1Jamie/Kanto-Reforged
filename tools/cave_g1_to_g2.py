# Seed CAVE_G1_TO_G2 — expand via:
#   python3 tools/block_mapper_gui.py --profile cavern_cave
# Then flip maps in restore_kanto_dungeons.CAVE_REMAP_MAPS when quality is accepted.
#
# Custom #120/#121 use Gen1 CAVERN sign tiles patched into overrides/tilesets/cave.png
# (tiles 90–93 ← Gen1 cavern 14/15/30/31), same pattern as Safari wooden stairs on kanto.png.

CAVE_G1_TO_G2 = {
    1: 1,    # Wall
    21: 16,  # Top wall
    22: 13,  # Wall corner
    24: 10,  # Left wall
    25: 25,  # Cave dirt floor
    26: 8,   # Right wall
    28: 17,  # Wall corner
    29: 2,   # Bottom wall
    42: 120, # Floor + wooden sign (Mt. Moon / Rock Tunnel)
    43: 43,  # Ladder
    44: 43,  # Ladder
    62: 25,  # Floor
    117: 121, # Water + wooden sign (Seafoam B4F)
}

CUSTOM_CAVE_BLOCKS_GENERATED = {
    120: {
        "tiles": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 90, 91, 1, 1, 92, 93],
        "collision": [0x00, 0x00, 0x00, 0x82],
    },
    121: {
        "tiles": [20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 90, 91, 20, 20, 92, 93],
        "collision": [0x29, 0x29, 0x29, 0x82],
    },
}
