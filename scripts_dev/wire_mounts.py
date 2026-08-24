#!/usr/bin/env python3
"""Wire the cavalry resources to their per-direction attack art and a MountProfile.

Only Lancer ships directional sheets. Every faction folder holds the same five
poses -- Up, UpRight, Right, DownRight, Down -- and the three left-facing
directions are produced at runtime by flipping the Right-side ones, so five
sheets cover eight facings.

Idempotent: running twice makes no second set of entries. Re-run it after adding
a faction or replacing the art.

    python3 scripts_dev/wire_mounts.py [--check]

--check reports what would change and writes nothing, for use in CI.
"""
from __future__ import annotations

import argparse
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FACTIONS = ["blue", "red", "purple", "yellow", "black"]
DIRECTIONS = ["Up", "UpRight", "Right", "DownRight", "Down"]

# One shared profile resource: every Lancer rides the same way, and five copies
# of the same four numbers is four chances to tune one of them and miss the rest.
#
# Deliberately NOT in resources/units/: several scripts load every .tres in that
# folder as a UnitData, so a MountProfile sitting there is a type error waiting
# to happen. The folder has an implicit contract; this respects it.
PROFILE_PATH = "resources/mounts/mount_lancer.tres"

PROFILE_BODY = """[gd_resource type="Resource" script_class="MountProfile" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/MountProfile.gd" id="1_mount"]

[resource]
script = ExtResource("1_mount")
mounted_class = "Cavalry"
dismounted_class = "Melee"
dismount_move_penalty = 2
dismount_defense_bonus = 4
"""


def png_size(path: Path) -> tuple[int, int]:
    """Width and height straight from the IHDR chunk -- no image library needed."""
    head = path.read_bytes()[:33]
    return struct.unpack(">II", head[16:24])


def art_dir(faction: str) -> Path:
    return ROOT / "assets" / "characters" / "factions" / faction / "Lancer"


def sheet_for(faction: str, direction: str) -> Path:
    return art_dir(faction) / f"Lancer_{direction}_Attack.png"


def wire(tres_path: Path, faction: str, check: bool) -> str:
    if not tres_path.exists():
        return f"MISSING {tres_path.relative_to(ROOT)}"

    text = tres_path.read_text(encoding="utf-8")
    if "directional_attack = {" in text:
        return f"skip    {tres_path.name} (already wired)"

    # Verify every sheet exists and shares one frame size before touching the
    # file. A half-wired resource that renders one direction at the wrong scale
    # is far harder to notice than a script that refused to run.
    frames: set[int] = set()
    for direction in DIRECTIONS:
        sheet = sheet_for(faction, direction)
        if not sheet.exists():
            return f"ERROR   {tres_path.name}: missing {sheet.name}"
        width, height = png_size(sheet)
        if height == 0 or width % height != 0:
            return f"ERROR   {tres_path.name}: {sheet.name} is {width}x{height}, not a square-frame strip"
        frames.add(width // height)
    if len(frames) != 1:
        return f"ERROR   {tres_path.name}: inconsistent frame counts {sorted(frames)}"
    hframes = frames.pop()

    # load_steps counts the resources Godot must load: script + textures.
    # Getting it wrong is tolerated by the loader but leaves a misleading file.
    m = re.search(r"load_steps=(\d+)", text)
    load_steps = int(m.group(1)) if m else 1
    new_steps = load_steps + len(DIRECTIONS) + 1  # directions + the mount profile

    ext_lines = []
    dict_lines = []
    for i, direction in enumerate(DIRECTIONS):
        res_id = f"{10 + i}_dir_{direction.lower()}"
        rel = sheet_for(faction, direction).relative_to(ROOT).as_posix()
        ext_lines.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="{res_id}"]')
        dict_lines.append(f'"{direction}": ExtResource("{res_id}")')
    ext_lines.append(f'[ext_resource type="Resource" path="res://{PROFILE_PATH}" id="20_mount"]')

    # Insert the ext_resources after the last existing one so the header block
    # stays contiguous, which is how Godot writes these files itself.
    last_ext = text.rfind("[ext_resource")
    line_end = text.index("\n", last_ext) + 1
    text = text[:line_end] + "\n".join(ext_lines) + "\n" + text[line_end:]

    if m:
        text = text.replace(f"load_steps={load_steps}", f"load_steps={new_steps}", 1)

    body = (
        "directional_attack = {\n"
        + ",\n".join(dict_lines)
        + "\n}\n"
        + f"directional_attack_hframes = {hframes}\n"
        + 'mount_profile = ExtResource("20_mount")\n'
    )
    text = text.rstrip("\n") + "\n" + body

    if check:
        return f"WOULD   {tres_path.name} (+{len(DIRECTIONS)} sheets, hframes={hframes})"
    tres_path.write_text(text, encoding="utf-8")
    return f"wired   {tres_path.name} (+{len(DIRECTIONS)} sheets, hframes={hframes})"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="report without writing")
    args = parser.parse_args()

    profile = ROOT / PROFILE_PATH
    if not profile.exists():
        if args.check:
            print(f"WOULD   create {PROFILE_PATH}")
        else:
            profile.parent.mkdir(parents=True, exist_ok=True)
            profile.write_text(PROFILE_BODY, encoding="utf-8")
            print(f"created {PROFILE_PATH}")
    else:
        print(f"skip    {PROFILE_PATH} (exists)")

    failed = False
    for faction in FACTIONS:
        result = wire(ROOT / "resources" / "units" / f"lancer_{faction}.tres", faction, args.check)
        print(" ", result)
        if result.startswith(("ERROR", "MISSING")):
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
