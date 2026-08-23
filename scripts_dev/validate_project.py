#!/usr/bin/env python3
"""validate_project.py — static integrity check for resources and scenes.

Godot is not installed in every environment this repo is worked on, so this
catches the failures a headless run would catch, without the engine:

  * every ext_resource path actually exists on disk
  * hframes/vframes evenly divide the referenced spritesheet
  * every upgrade_paths target resolves
  * every unit carries baked sprite_scale / sprite_offset metrics
  * no unit_name still carries a faction colour prefix
  * generated PNGs are all referenced by something

It does NOT replace `godot --headless`: it cannot catch GDScript compile
errors. Run both.
"""
import glob
import os
import re
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

import spritegen_lib as G  # noqa: E402

FACTION_WORDS = ("Blue ", "Red ", "Purple ", "Yellow ", "Black ")
errors: list[str] = []
warnings: list[str] = []


def check_ext_resources() -> None:
    for path in glob.glob("resources/**/*.tres", recursive=True) + \
                glob.glob("scenes/**/*.tscn", recursive=True):
        for m in re.finditer(r'\[ext_resource[^\]]*path="res://([^"]+)"', open(path).read()):
            if not os.path.exists(m.group(1)):
                errors.append(f"{path}: missing ext_resource -> {m.group(1)}")


def check_units() -> None:
    used_textures = set()
    for path in sorted(glob.glob("resources/units/*.tres")):
        src = open(path).read()
        stem = os.path.basename(path)

        name = re.search(r'^unit_name = "([^"]*)"', src, re.M)
        if name and name.group(1).startswith(FACTION_WORDS):
            errors.append(f"{stem}: unit_name still prefixed with a faction colour "
                          f'-> "{name.group(1)}"')

        if not re.search(r"^sprite_scale = ", src, re.M):
            errors.append(f"{stem}: missing baked sprite_scale")
        if not re.search(r"^sprite_offset = ", src, re.M):
            errors.append(f"{stem}: missing baked sprite_offset")
        if "needs_palette_tint = true" in src:
            warnings.append(f"{stem}: still opts into the runtime tint shader")

        rid = re.search(r'spritesheet = ExtResource\("([^"]+)"\)', src)
        if not rid:
            errors.append(f"{stem}: no spritesheet assigned")
            continue
        ext = re.search(rf'\[ext_resource type="Texture2D"[^\]]*id="{re.escape(rid.group(1))}"[^\]]*\]', src)
        if not ext:
            errors.append(f"{stem}: spritesheet ExtResource id not declared")
            continue
        tex = re.search(r'path="res://([^"]+)"', ext.group(0)).group(1)
        used_textures.add(tex)
        if not os.path.exists(tex):
            errors.append(f"{stem}: spritesheet missing -> {tex}")
            continue

        hf = int((re.search(r"^hframes = (\d+)", src, re.M) or [0, "6"])[1])
        vf = int((re.search(r"^vframes = (\d+)", src, re.M) or [0, "6"])[1])
        w, h = Image.open(tex).size
        if w % hf or h % vf:
            errors.append(f"{stem}: {w}x{h} not divisible by {hf}x{vf} frames -> {tex}")

        # Measure the DRAWN body, not the padded frame — TinySwords frames are
        # mostly empty space, so frame height says nothing about on-screen size.
        scale = float(re.search(r"^sprite_scale = ([\d.]+)", src, re.M).group(1))
        bb = G.union_bbox(Image.open(tex).convert("RGBA"), hf, vf, row=0)
        if bb:
            body = (bb[3] - bb[1]) * scale
            if abs(body - G.TARGET_CHAR_PX) > 1.5:
                errors.append(f"{stem}: renders {body:.1f}px tall, expected "
                              f"{G.TARGET_CHAR_PX:.0f}px — metrics are stale, "
                              f"re-run scripts_dev/wire_units.py")

        for up in re.finditer(r'"([^"]+)": ExtResource\("([^"]+)"\)', src):
            uext = re.search(rf'\[ext_resource type="Resource"[^\]]*id="{re.escape(up.group(2))}"[^\]]*\]', src)
            if not uext:
                errors.append(f"{stem}: upgrade '{up.group(1)}' has no ext_resource")
                continue
            upath = re.search(r'path="res://([^"]+)"', uext.group(0)).group(1)
            if not os.path.exists(upath):
                errors.append(f"{stem}: upgrade '{up.group(1)}' -> missing {upath}")

    for gen in glob.glob("assets/characters/generated/**/*.png", recursive=True):
        if gen not in used_textures:
            warnings.append(f"generated but unreferenced: {gen}")


def check_scene_scales() -> None:
    """Node-level scale on a unit would fight the baked per-unit sprite scale."""
    for path in glob.glob("scenes/units/*.tscn") + ["scenes/TestGridScene.tscn"]:
        src = open(path).read()
        for m in re.finditer(r'\[node name="([^"]+)"[^\]]*\]\n(?:[^\[]*?)^scale = Vector2\(([^)]+)\)',
                             src, re.M):
            if "Sprite2D" in m.group(1):
                continue
            errors.append(f"{os.path.basename(path)}: node '{m.group(1)}' sets "
                          f"scale=({m.group(2)}) — units must stay at scale 1")


def check_imports() -> None:
    missing = [p for p in glob.glob("assets/characters/generated/**/*.png", recursive=True)
               if not os.path.exists(p + ".import")]
    if missing:
        warnings.append(f"{len(missing)} generated PNG(s) have no .import yet — run "
                        f"`godot --headless --import` (or just open the editor) once")


if __name__ == "__main__":
    check_ext_resources()
    check_units()
    check_scene_scales()
    check_imports()

    for w in warnings:
        print(f"  warn  {w}")
    for e in errors:
        print(f"  ERROR {e}")
    print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
    sys.exit(1 if errors else 0)
