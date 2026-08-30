"""Mythical custom rooms: Gen1 OVERWORLD source → Gold TILESET_KANTO (Gen2 apply only).

Gen1 runtime keeps OVERWORLD + native block IDs via legend_mythicals.register().
"""

from .common import COLLISION_PRESETS, GEN2_BUILDING_BLOCKS, base_profile


MYTHICAL_G1_BLOCKS = {1, 10, 15, 26, 28, 67, 85}

PROFILE = base_profile(
    id="legend_mythical_overworld",
    title="Legend Mythicals (OVERWORLD → TILESET_KANTO)",
    g1_tileset_id="OVERWORLD",
    g1_palette_env="OVERWORLD",
    g2_tileset_id="TILESET_KANTO",
    g2_palette_env="ROUTE",
    g2_palette_daytime="DAY",
    g1_max_blocks=128,
    g2_max_blocks=161,
    g1_card_sheet=False,
    g2_card_sheet=True,
    dict_name="LEGEND_MYTHICAL_G1_TO_G2",
    custom_blocks_name="LEGEND_MYTHICAL_CUSTOM_BLOCKS",
    out="legend_mythical_g1_to_g2.py",
    restore_script="apply_legend_mappings.py",
    exclude_buildings=True,
    gen2_building_blocks=set(GEN2_BUILDING_BLOCKS),
    gen1_feature_blocks=MYTHICAL_G1_BLOCKS,
    feature_bar_title="Mythical Room Blocks (wall, grass, water, ledge, stump):",
    test_map_json="legend_maps/SKY_PILLAR_KANT.json",
    preview_map_ids=[
        "SKY_PILLAR_KANT",
        "ILEX_SHRINE_KANT",
        "BIRTH_ISLAND_KANT",
    ],
    preview_tilesets=["OVERWORLD"],
    collision_presets=list(COLLISION_PRESETS),
    favorites=[
        {"g2_id": 1, "src_q": 0, "name": "Grass/Path", "coll": 0x00},
        {"g2_id": 11, "src_q": 0, "name": "Tall Grass", "coll": 0x18},
        {"g2_id": 15, "src_q": 0, "name": "Tree Wall", "coll": 0x07},
        {"g2_id": 26, "src_q": 0, "name": "Ledge", "coll": 0xA3},
        {"g2_id": 28, "src_q": 0, "name": "Stump", "coll": 0x07},
        {"g2_id": 20, "src_q": 0, "name": "Water", "coll": 0x29},
        {"g2_id": 10, "src_q": 0, "name": "Sand", "coll": 0x00},
    ],
    quad_presets=[
        {"label": "Walkable Grass", "g2_id": 1, "src_q": 0, "coll": 0x00},
        {"label": "Solid Tree", "g2_id": 15, "src_q": 0, "coll": 0x07},
        {"label": "Water", "g2_id": 20, "src_q": 0, "coll": 0x29},
        {"label": "Ledge Down", "g2_id": 26, "src_q": 2, "coll": 0xA3},
        {"label": "Stump", "g2_id": 28, "src_q": 0, "coll": 0x07},
        {"label": "Sand", "g2_id": 10, "src_q": 0, "coll": 0x00},
    ],
)
