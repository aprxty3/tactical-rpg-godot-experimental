#!/usr/bin/env python3
"""Build the six wandering encounters that garrison the Black Castle.

Offline, like every other art step in this project: Godot imports finished
PNGs and never recolours anything at runtime.

The source art was already in the repo and had never been referenced by a
single line of code -- `assets/characters/enemy_animations/` ships idle,
movement, attack, death and take-damage strips for three creatures
(skeleton1, skeleton2, vampire). Six monsters out of three bodies is the
whole reason `recolor` exists: rotating the garment palette keeps the
linework and gives each variant its own read.

Run with the deps this repo does not vendor::

    uv run --with numpy --with pillow python scripts_dev/generate_monsters.py

Writes `assets/characters/monsters/<id>/<id>.png` and
`resources/units/<id>_black.tres`. Re-runs are byte-stable, so an unchanged
monster leaves its mtime (and Godot's import cache) alone.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import spritegen_lib as G  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/characters/enemy_animations"
ART_OUT = ROOT / "assets/characters/monsters"
TRES_OUT = ROOT / "resources/units"

## Six columns to match every other derived sheet in the project, which is what
## TacticalUnit's "compact derived sheet" animation path expects: row 0 idle,
## row 1 run, and `attack` replays the run row faster.
COLS = 6

## Source strips per creature. The movement strips are longer than the idle
## ones (10 and 8 frames against 6), so they are resampled rather than
## truncated -- cutting at six would drop the back half of the stride and the
## walk would read as a limp.
BODIES = {
    "skeleton1": ("enemies-skeleton1_idle.png", "enemies-skeleton1_movement.png"),
    "skeleton2": ("enemies-skeleton2_idle.png", "enemies-skeleton2_movemen.png"),
    "vampire": ("enemies-vampire_idle.png", "enemies-vampire_movement.png"),
}

## The roster. `look` feeds spritegen_lib.recolor; everything else lands in the
## .tres verbatim. Stats and appearance live in one table on purpose -- they
## were authored together, and splitting them is how a "green sickly ghoul"
## ends up with the boss's health.
##
## Balance note: these are deliberately NOT tuned to faction units of the same
## tier. A monster costs nothing to field and never recruits, so its job is to
## be a toll on the centre of the map, not a fair fight.
MONSTERS = [
    {
        "id": "ghoul",
        "body": "skeleton1",
        "name": "Ghoul",
        "desc": "Starved dead that swarms anything straying near the black keep.",
        "look": {"hue": 0.28, "sat": 1.25, "val": 0.95},
        "health": 38, "attack": 14, "defense": 2, "move": 4, "rmin": 1, "rmax": 1,
        "weight": 1, "vision": 4,
    },
    {
        "id": "bonestalker",
        "body": "skeleton1",
        "name": "Bone Stalker",
        "desc": "A scout of the dead — fast, brittle, and always the first thing seen.",
        "look": {"sat": 0.25, "val": 1.12},
        "health": 30, "attack": 12, "defense": 1, "move": 6, "rmin": 1, "rmax": 1,
        "weight": 1, "vision": 6,
    },
    {
        "id": "gravewarden",
        "body": "skeleton2",
        "name": "Grave Warden",
        "desc": "Armoured bones that hold the approach and refuse to fall quickly.",
        "look": {"hue": 0.58, "sat": 1.15, "val": 0.88, "rim": (0.55, 0.72, 0.95)},
        "health": 70, "attack": 20, "defense": 12, "move": 3, "rmin": 1, "rmax": 1,
        "weight": 2, "vision": 4,
    },
    {
        "id": "plaguewraith",
        "body": "skeleton2",
        "name": "Plague Wraith",
        "desc": "Hurls rot from two tiles away. Thin enough that reaching it is the fight.",
        "look": {"hue": 0.78, "sat": 1.3, "val": 0.9, "alpha": 0.88},
        "health": 40, "attack": 22, "defense": 3, "move": 3, "rmin": 1, "rmax": 2,
        "weight": 2, "vision": 5,
    },
    {
        "id": "bloodfiend",
        "body": "vampire",
        "name": "Blood Fiend",
        "desc": "Feeds on what it kills. The reason a wounded unit should not linger.",
        "look": {"hue": 0.99, "sat": 1.35, "val": 0.95, "rim": (0.9, 0.25, 0.3)},
        "health": 62, "attack": 26, "defense": 8, "move": 4, "rmin": 1, "rmax": 1,
        "weight": 2, "vision": 5,
    },
    {
        "id": "dreadwarden",
        "body": "vampire",
        "name": "Dread Warden",
        "desc": "The thing the Black Castle was built around. It does not leave.",
        "look": {"hue": 0.11, "sat": 1.4, "val": 1.05, "rim": (1.0, 0.82, 0.35)},
        "health": 140, "attack": 34, "defense": 16, "move": 3, "rmin": 1, "rmax": 2,
        "weight": 4, "vision": 7,
        # The boss reads bigger than its 32px source. Scaling here rather than
        # with a node scale keeps it on the same footing as every other unit:
        # TacticalUnit sizes the Sprite2D from UnitData metrics alone.
        "scale_boost": 1.35,
    },
]


def load_strip(path: Path) -> tuple[list[Image.Image], tuple[int, int, int, int]]:
    """Split a single-row strip into square frames; return them and their union bbox.

    A local copy of spritegen_lib.load_strip because that one hardcodes the
    TinySwords `<dir>/<Anim>/<Anim>-Sheet.png` layout, and this pack is a flat
    folder of differently-named files.
    """
    img = Image.open(path).convert("RGBA")
    fh = img.height
    fw = fh  # every strip in this pack is square-framed
    cols = img.width // fw
    frames = [img.crop((c * fw, 0, (c + 1) * fw, fh)) for c in range(cols)]
    box = None
    for f in frames:
        bb = f.getbbox()
        if bb is None:
            continue
        box = bb if box is None else (min(box[0], bb[0]), min(box[1], bb[1]),
                                      max(box[2], bb[2]), max(box[3], bb[3]))
    return frames, (box or (0, 0, fw, fh))


def resample(frames: list[Image.Image], count: int) -> list[Image.Image]:
    """Pick `count` frames spread evenly across `frames`, preserving the arc."""
    if not frames:
        raise ValueError("empty animation strip")
    return [frames[round(i * (len(frames) - 1) / max(1, count - 1))] for i in range(count)]


def compose(body: str) -> Image.Image:
    """Idle + movement -> one 6x2 sheet, each row cropped to its own bbox.

    Cropping per animation keeps the idle bob and the walk stride intact;
    aligning both crops bottom-centre stops the creature hopping when idle
    hands over to run.
    """
    idle_src, move_src = BODIES[body]
    idle_f, idle_bb = load_strip(SRC / idle_src)
    move_f, move_bb = load_strip(SRC / move_src)

    idle_c = resample([f.crop(idle_bb) for f in idle_f], COLS)
    move_c = resample([f.crop(move_bb) for f in move_f], COLS)

    cw = max(max(f.width for f in idle_c), max(f.width for f in move_c)) + 2
    ch = max(max(f.height for f in idle_c), max(f.height for f in move_c)) + 2
    sheet = Image.new("RGBA", (cw * COLS, ch * 2), (0, 0, 0, 0))
    for r, row in enumerate((idle_c, move_c)):
        for c, f in enumerate(row):
            x = c * cw + (cw - f.width) // 2      # centre horizontally
            y = r * ch + (ch - 1 - f.height)      # stand on the cell floor
            sheet.alpha_composite(f, (x, y))
    return sheet


def dress(sheet: Image.Image, look: dict) -> Image.Image:
    out = G.recolor(
        sheet,
        hue_target=look.get("hue"),
        sat_mul=look.get("sat", 1.0),
        val_mul=look.get("val", 1.0),
        alpha_mul=look.get("alpha", 1.0),
    )
    if "rim" in look:
        bb = G.union_bbox(out, COLS, 2)
        body_h = max(1, (bb[3] - bb[1]) if bb else 1)
        out = G.add_rim(out, look["rim"], width=max(1, round(body_h / 22.0)), alpha=0.6)
    return out


def write_if_changed(path: Path, data: bytes) -> bool:
    """Write only on a real byte change, so Godot's import cache stays put."""
    if path.exists() and path.read_bytes() == data:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return True


TRES = """[gd_resource type="Resource" script_class="UnitData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/UnitData.gd" id="1_scr"]
[ext_resource type="Texture2D" path="{tex}" id="2_tex"]

[resource]
script = ExtResource("1_scr")
unit_name = "{name}"
unit_class = "Undead"
tier = {tier}
description = "{desc}"
max_health = {health}
attack_power = {attack}
defense_power = {defense}
movement_points = {move}
attack_range_min = {rmin}
attack_range_max = {rmax}
recruit_cost_gold = 0
recruit_cost_iron = 0
capacity_weight = {weight}
vision_range = {vision}
spritesheet = ExtResource("2_tex")
hframes = {cols}
vframes = 2
sprite_scale = {scale}
sprite_offset = Vector2({off_x}, {off_y})
"""


def main() -> None:
    made = 0
    for m in MONSTERS:
        sheet = dress(compose(m["body"]), m["look"])

        png_path = ART_OUT / m["id"] / f"{m['id']}.png"
        png_path.parent.mkdir(parents=True, exist_ok=True)
        tmp = png_path.with_suffix(".tmp.png")
        sheet.save(tmp)
        png_changed = write_if_changed(png_path, tmp.read_bytes())
        tmp.unlink()

        scale, off_x, off_y = G.sprite_metrics(sheet, COLS, 2)
        scale = round(scale * m.get("scale_boost", 1.0), 4)

        tres_path = TRES_OUT / f"{m['id']}_black.tres"
        body = TRES.format(
            tex=f"res://assets/characters/monsters/{m['id']}/{m['id']}.png",
            name=m["name"],
            # Tier is display-only for monsters (they never promote), so it is
            # derived from capacity weight rather than authored twice.
            tier=min(3, m["weight"]),
            desc=m["desc"],
            health=m["health"], attack=m["attack"], defense=m["defense"],
            move=m["move"], rmin=m["rmin"], rmax=m["rmax"],
            weight=m["weight"], vision=m["vision"], cols=COLS,
            scale=scale, off_x=off_x, off_y=off_y,
        )
        tres_changed = write_if_changed(tres_path, body.encode("utf-8"))

        flag = "updated" if (png_changed or tres_changed) else "unchanged"
        made += 1
        print(f"  {m['id']:<13} {sheet.width:>3}x{sheet.height:<3} "
              f"scale={scale:<7} offset=({off_x}, {off_y})  [{flag}]")

    print(f"{made} monsters written to {ART_OUT.relative_to(ROOT)} "
          f"and {TRES_OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
