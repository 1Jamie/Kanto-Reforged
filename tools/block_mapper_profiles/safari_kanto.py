"""Safari Zone outdoor blocks → Gold TILESET_KANTO."""

from .common import (
    GEN1_BUILDING_BLOCKS_SAFARI,
    GEN1_SIGN_BLOCKS_FOREST,
    GEN1_STAIR_BLOCKS_SAFARI,
    GEN2_BUILDING_BLOCKS,
    base_profile,
)


def synthesize(g1_raw_blocks, g2_raw_blocks):
    """Shipped wood_stair.png (#158/#159) + Gen1 forest wooden sign (#160)."""
    from PIL import Image

    from tileset_quad_patches import render_stair_block_previews

    if not g2_raw_blocks:
        return

    render_stair_block_previews(g2_raw_blocks)

    bw, bh = g2_raw_blocks[0].size
    while len(g2_raw_blocks) <= 160:
        g2_raw_blocks.append(Image.new("RGB", (bw, bh), (0, 0, 0)))

    # Prefer Gen1 FOREST sign metatile (#33) for outdoor wooden sign thumbnails.
    sign_src = 33 if len(g1_raw_blocks) > 33 else (21 if len(g1_raw_blocks) > 21 else None)
    if sign_src is not None:
        g2_raw_blocks[160] = g1_raw_blocks[sign_src].resize((bw, bh), Image.NEAREST)
    print("Loaded custom stairs (#158/#159) + Gen1 forest sign (#160) into Gen 2 pool.")


PROFILE = base_profile(
    id="safari_kanto",
    title="Safari Zone → TILESET_KANTO",
    g1_sheet="gen1_safari_blocks.png",
    g2_sheet="gen2_kanto_blocks.png",
    g1_card_sheet=True,
    g2_card_sheet=True,
    g1_max_blocks=128,
    g2_max_blocks=161,
    g2_tileset_id="TILESET_KANTO",
    g2_palette_env="ROUTE",
    g2_tile_palette_overrides={77: 1, 78: 1, 83: 1, 84: 1, 96: 1, 97: 1, 98: 1, 99: 1},
    dict_name="SAFARI_G1_TO_G2",
    custom_blocks_name="CUSTOM_KANTO_BLOCKS_GENERATED",
    out="safari_g1_to_g2.py",
    exclude_buildings=True,
    gen2_building_blocks=set(GEN2_BUILDING_BLOCKS),
    gen1_building_blocks=set(GEN1_BUILDING_BLOCKS_SAFARI),
    gen1_feature_blocks=set(GEN1_STAIR_BLOCKS_SAFARI) | set(GEN1_SIGN_BLOCKS_FOREST),
    feature_bar_title="Stairs, Cliffs & Wooden Signs (Click piece to apply & advance):",
    custom_blocks_source="CUSTOM_KANTO_BLOCKS",
    test_map_id="SAFARI_ZONE_CENTER",
    preview_tilesets=["FOREST"],
    favorites=[
        {"g2_id": 1, "src_q": 0, "name": "Plain Grass", "coll": 0x00},
        {"g2_id": 11, "src_q": 0, "name": "Tall Grass", "coll": 0x18},
        {"g2_id": 15, "src_q": 0, "name": "Solid Tree", "coll": 0x07},
        {"g2_id": 27, "src_q": 0, "name": "Wood Fence", "coll": 0x07},
        {"g2_id": 160, "src_q": 0, "name": "Wood Sign", "coll": 0x82},
        {"g2_id": 158, "src_q": 2, "name": "Stairs Down L", "coll": 0x00},
        {"g2_id": 159, "src_q": 0, "name": "Stairs Up L", "coll": 0x00},
        {"g2_id": 36, "src_q": 2, "name": "Cliff Wall", "coll": 0x07},
    ],
    building_dropins=[
        {"label": "Small House L (#2)", "g2_id": 2},
        {"label": "Small House R / Door (#3)", "g2_id": 3},
        {"label": "Small Hut L (#4)", "g2_id": 4},
        {"label": "Small Hut R / Door (#5)", "g2_id": 5},
        {"label": "Rest Booth L (#22)", "g2_id": 22},
        {"label": "Rest Booth R / Door (#23)", "g2_id": 23},
        {"label": "3-Wide House L (#16)", "g2_id": 16},
        {"label": "3-Wide House M (#17)", "g2_id": 17},
        {"label": "3-Wide House R (#18)", "g2_id": 18},
    ],
    quad_presets=[
        {"label": "Stairs Down L", "g2_id": 158, "src_q": 2, "coll": 0x00},
        {"label": "Stairs Down R", "g2_id": 158, "src_q": 3, "coll": 0x00},
        {"label": "Stairs Up L", "g2_id": 159, "src_q": 0, "coll": 0x00},
        {"label": "Stairs Up R", "g2_id": 159, "src_q": 1, "coll": 0x00},
        {"label": "Wood Sign TL", "g2_id": 160, "src_q": 0, "coll": 0x82},
        {"label": "Cliff Wall", "g2_id": 36, "src_q": 2, "coll": 0x07},
        {"label": "Cliff Top", "g2_id": 36, "src_q": 0, "coll": 0x07},
        {"label": "Ledge Hop", "g2_id": 42, "src_q": 2, "coll": 0xA0},
        {"label": "Wood Fence", "g2_id": 27, "src_q": 0, "coll": 0x07},
        {"label": "Plain Grass", "g2_id": 1, "src_q": 0, "coll": 0x00},
    ],
    whole_block_dropins=[
        {"label": "Full Stairs Down", "g2_id": 158},
        {"label": "Full Stairs Up", "g2_id": 159},
        {"label": "Wooden Sign", "g2_id": 160},
    ],
    synthesize=synthesize,
)
