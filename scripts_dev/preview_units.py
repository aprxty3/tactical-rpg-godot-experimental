#!/usr/bin/env python3
"""preview_units.py — render units on tiles exactly as Godot will draw them.

Reads the baked sprite_scale / sprite_offset straight out of the .tres files
and reproduces Sprite2D's transform (frame centred on the node origin, then
offset, then scaled), so what comes out is a true preview of on-screen size —
the check that the mage-is-tiny bug is actually gone.

    python3 scripts_dev/preview_units.py  ->  scripts_dev/_preview/units.png
"""
import os
import re
import sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

CELL = 64
ROWS = [
    ("Tier 1-2 (Blue)", ["pawn_blue", "warrior_blue", "archer_blue", "monk_blue",
                         "wizzard_blue", "rogue_blue"]),
    ("Tier 3 (Blue)", ["knight_blue", "lancer_blue", "sniper_blue", "crossbowman_blue",
                       "archmage_blue", "elementalist_blue", "highpriest_blue",
                       "paladin_blue", "assassin_blue", "shadowblade_blue"]),
    ("Tier 1-2 (Red)", ["pawn_red", "warrior_red", "archer_red", "monk_red",
                        "wizzard_red", "rogue_red"]),
    ("Black Coven undead", ["skeleton_base_black", "skeleton_black", "skeleton_mage_black",
                            "skeleton_rogue_black", "bonereaper_black", "lich_black",
                            "wraith_black", "vampire_black", "vampirelord_black",
                            "nightstalker_black"]),
]


def read(stem):
    src = open(f"resources/units/{stem}.tres").read()
    rid = re.search(r'spritesheet = ExtResource\("([^"]+)"\)', src).group(1)
    ext = re.search(rf'\[ext_resource type="Texture2D"[^\]]*id="{re.escape(rid)}"[^\]]*\]', src)
    tex = re.search(r'path="res://([^"]+)"', ext.group(0)).group(1)
    g = lambda k, d: (re.search(rf"^{k} = (.+)$", src, re.M) or [0, d])[1]
    ox, oy = re.search(r"Vector2\(([-\d.]+), ([-\d.]+)\)", g("sprite_offset", "Vector2(0, 0)")).groups()
    return dict(tex=tex, hf=int(g("hframes", "6")), vf=int(g("vframes", "6")),
                scale=float(g("sprite_scale", "1")), off=(float(ox), float(oy)),
                name=re.search(r'^unit_name = "([^"]*)"', src, re.M).group(1))


def draw_unit(canvas, cx, cy, u):
    """Mirror Sprite2D: frame centred on the origin, shifted by offset, scaled."""
    im = Image.open(u["tex"]).convert("RGBA")
    fw, fh = im.width // u["hf"], im.height // u["vf"]
    frame = im.crop((0, 0, fw, fh))
    s = u["scale"]
    frame = frame.resize((max(1, round(fw * s)), max(1, round(fh * s))), Image.NEAREST)
    x = cx + round((u["off"][0] - fw / 2.0) * s)
    y = cy + round((u["off"][1] - fh / 2.0) * s)
    canvas.alpha_composite(frame, (x, y))


def main():
    tile = Image.open("assets/terrain/Ground/Tilemap_Flat.png").convert("RGBA") \
        .crop((CELL, CELL, 2 * CELL, 2 * CELL))
    cols = max(len(r[1]) for r in ROWS)
    W, H = 170 + cols * CELL, len(ROWS) * (CELL + 26)
    canvas = Image.new("RGBA", (W, H), (26, 28, 36, 255))
    d = ImageDraw.Draw(canvas)

    for ri, (label, stems) in enumerate(ROWS):
        top = ri * (CELL + 26)
        d.text((6, top + CELL // 2), label, fill=(255, 232, 150, 255))
        for ci, stem in enumerate(stems):
            x = 170 + ci * CELL
            canvas.alpha_composite(tile, (x, top))
            d.rectangle([x, top, x + CELL - 1, top + CELL - 1], outline=(255, 255, 255, 40))
            u = read(stem)
            draw_unit(canvas, x + CELL // 2, top + CELL // 2, u)
            d.text((x + 2, top + CELL + 2), u["name"][:11], fill=(190, 200, 215, 255))

    os.makedirs("scripts_dev/_preview", exist_ok=True)
    canvas.resize((W * 2, H * 2), Image.NEAREST).save("scripts_dev/_preview/units.png")
    print(f"rendered {sum(len(r[1]) for r in ROWS)} units on 64px tiles")


if __name__ == "__main__":
    main()
