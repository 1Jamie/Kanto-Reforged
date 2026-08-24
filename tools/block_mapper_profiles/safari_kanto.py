"""Safari Zone outdoor blocks → Gold TILESET_KANTO."""

from .common import (
    GEN1_BUILDING_BLOCKS_SAFARI,
    GEN1_SIGN_BLOCKS_FOREST,
    GEN1_STAIR_BLOCKS_SAFARI,
    GEN2_BUILDING_BLOCKS,
    base_profile,
)


def synthesize(g1_raw_blocks, g2_raw_blocks):
    """Mt. Moon wooden stairs (#158/#159) + Gen1 forest wooden sign (#160)."""
    from PIL import Image

    if len(g1_raw_blocks) <= 83 or len(g2_raw_blocks) <= 36:
        return

    g1_83 = g1_raw_blocks[83]
    gw, gh = g1_83.size
    wood_stair_right = g1_83.crop((gw // 2, gh // 2, gw, gh))
    wood_stair_left = wood_stair_right.transpose(Image.FLIP_LEFT_RIGHT)

    b36 = g2_raw_blocks[36]
    bw, bh = b36.size
    cliff_top_left = b36.crop((0, 0, bw // 2, bh // 2))
    cliff_top_right = b36.crop((bw // 2, 0, bw, bh // 2))
    target_qw, target_qh = bw // 2, bh // 2
    wood_stair_left = wood_stair_left.resize((target_qw, target_qh), Image.NEAREST)
    wood_stair_right = wood_stair_right.resize((target_qw, target_qh), Image.NEAREST)

    b158 = Image.new("RGB", (bw, bh))
    b158.paste(cliff_top_left, (0, 0))
    b158.paste(cliff_top_right, (target_qw, 0))
    b158.paste(wood_stair_left, (0, target_qh))
    b158.paste(wood_stair_right, (target_qw, target_qh))

    b159 = Image.new("RGB", (bw, bh))
    b159.paste(wood_stair_left, (0, 0))
    b159.paste(wood_stair_right, (target_qw, 0))
    b159.paste(cliff_top_left, (0, target_qh))
    b159.paste(cliff_top_right, (target_qw, target_qh))

    while len(g2_raw_blocks) <= 160:
        g2_raw_blocks.append(Image.new("RGB", (bw, bh), (0, 0, 0)))
    g2_raw_blocks[158] = b158
    g2_raw_blocks[159] = b159

    # Prefer Gen1 FOREST sign metatile (#33) for outdoor wooden sign thumbnails.
    sign_src = 33 if len(g1_raw_blocks) > 33 else (21 if len(g1_raw_blocks) > 21 else None)
    if sign_src is not None:
        g2_raw_blocks[160] = g1_raw_blocks[sign_src].resize((bw, bh), Image.NEAREST)
    print("Synthesized Mt. Moon stairs (#158/#159) + Gen1 forest sign (#160) into Gen 2 pool.")


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
