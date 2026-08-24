"""Shared defaults for block mapper profiles."""

# Gen 2 COLL_* presets shown in the GUI combobox / collision overlay.
COLLISION_PRESETS = [
    {"label": "0x00: Walkable / Path", "val": 0x00, "color": "#81C784"},
    {"label": "0x07: Solid Wall / Tree", "val": 0x07, "color": "#E57373"},
    {"label": "0x18: Tall Grass (Wild Encounters)", "val": 0x18, "color": "#FFD54F"},
    {"label": "0x21: Pit / Hole", "val": 0x21, "color": "#212121"},
    {"label": "0x29: Water / Surf", "val": 0x29, "color": "#64B5F6"},
    {"label": "0x2B: Ladder / Cave Warp", "val": 0x2B, "color": "#FF8A65"},
    {"label": "0x82: Sign / Readable", "val": 0x82, "color": "#FFB74D"},
    {"label": "0xA0: Ledge Down (Hop)", "val": 0xA0, "color": "#BA68C8"},
    {"label": "0xA1: Ledge Left", "val": 0xA1, "color": "#BA68C8"},
    {"label": "0xA2: Ledge Right", "val": 0xA2, "color": "#BA68C8"},
    {"label": "0x70: Door / Warp Carpet Down", "val": 0x70, "color": "#4DB6AC"},
    {"label": "0x71: Gate Entrance Door", "val": 0x71, "color": "#4DB6AC"},
    {"label": "0x78: Warp Carpet Up", "val": 0x78, "color": "#4DB6AC"},
]

COLLISION_COLOR_BY_VAL = {p["val"]: p["color"] for p in COLLISION_PRESETS}
COLLISION_COLOR_BY_VAL.setdefault(0x00, "#81C784")

# Default outdoor / Kanto building exclusions (Safari / Forest).
GEN2_BUILDING_BLOCKS = {
    2, 3, 4, 5, 9, 16, 17, 18, 22, 23, 45, 46, 48, 55, 56, 57, 58, 60, 61,
    83, 85, 102, 104, 105, 113, 114, 115, 117, 118, 124, 125, 126, 127, 138,
    140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157,
}

GEN1_BUILDING_BLOCKS_SAFARI = {25, 26, 28}
GEN1_STAIR_BLOCKS_SAFARI = {
    60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 83, 84, 85,
}
# Gen1 FOREST wooden sign metatiles (Viridian Forest + Safari Zone posts).
GEN1_SIGN_BLOCKS_FOREST = {21, 22, 33, 51}
# Gen1 CAVERN wooden sign metatiles (Mt. Moon / Rock Tunnel floor; Seafoam water).
GEN1_SIGN_BLOCKS_CAVERN = {42, 117}

DEFAULT_BLOCK_SIZE = 16  # metatile edge in source sheet cells; sheets often store 32px (2x)
DEFAULT_TILE_SIZE = 8


def base_profile(**overrides):
    """Return a PROFILE dict with Sevii-ready dimension defaults."""
    profile = {
        "id": "unnamed",
        "title": "Block Mapper",
        "g1_sheet": None,
        "g2_sheet": None,
        "g1_card_sheet": False,
        "g2_card_sheet": False,
        "g1_max_blocks": 128,
        "g2_max_blocks": 160,
        # Physical pixel size of one block in the sliced sheet (after card crop).
        # Card sheets typically yield 96px; grid sheets often 32px. Prefer auto from
        # the first sliced block when unset; these fields document intent for FRLG.
        "g1_block_size": None,
        "g2_block_size": None,
        "g1_tile_size": DEFAULT_TILE_SIZE,
        "g2_tile_size": DEFAULT_TILE_SIZE,
        "g1_tileset_id": None,  # optional Gen1 host tileset for sheet rebuild
        "g2_tileset_id": "TILESET_KANTO",
        "g2_palette_env": "ROUTE",
        "dict_name": "G1_TO_G2",
        "custom_blocks_name": "CUSTOM_BLOCKS_GENERATED",
        "out": "g1_to_g2.py",
        "exclude_buildings": True,
        "gen2_building_blocks": set(GEN2_BUILDING_BLOCKS),
        "gen1_building_blocks": set(),
        "gen1_feature_blocks": set(),
        "feature_bar_title": "Special Features (Click piece to apply & advance):",
        "favorites": [],
        "quad_presets": [],
        "building_dropins": [],
        "whole_block_dropins": [],
        "collision_presets": list(COLLISION_PRESETS),
        "test_map_id": None,
        "test_map_width": None,
        "test_map_height": None,
        "test_map_json": None,
        "preview_tilesets": [],  # Gen1 tileset ids for Map Preview picker
        "synthesize": None,  # callable(g1_raw_blocks, g2_raw_blocks) or None
        "custom_blocks_source": None,  # attribute name on restore module to seed tiles
    }
    profile.update(overrides)
    if not profile.get("preview_tilesets") and profile.get("g1_tileset_id"):
        profile["preview_tilesets"] = [profile["g1_tileset_id"]]
    return profile
