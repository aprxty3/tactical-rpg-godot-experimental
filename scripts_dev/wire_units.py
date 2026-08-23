#!/usr/bin/env python3
"""wire_units.py — point every unit resource at its real art and bake the
render metrics that make units the same size on screen.

Run after scripts_dev/generate_sprites.py:

    python3 scripts_dev/generate_sprites.py
    python3 scripts_dev/wire_units.py

For each resources/units/*.tres it:
  1. repoints `spritesheet` at the generated sheet (Tier-3 promotions used to
     re-use their parent's texture verbatim, so upgrades changed nothing);
  2. bakes `sprite_scale` / `sprite_offset` from the art's real content bbox,
     so 16px undead icons and 320px Lancer frames render the same height;
  3. clears `needs_palette_tint` — faction colour is now baked into the art,
     the runtime shader is no longer the mechanism;
  4. strips the faction word out of `unit_name` ("Blue Pawn" -> "Pawn"), which
     is what the Recruit and Upgrade popups display.

Matching .tscn previews under scenes/units/ are kept in sync.
Idempotent: only rewrites files whose text actually changes.
"""
from __future__ import annotations

import glob
import os
import re
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spritegen_lib as G  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

FACTIONS = ("blue", "red", "purple", "yellow", "black")
FACTION_WORDS = ("Blue", "Red", "Purple", "Yellow", "Black")

# Roles whose sheet is the 6x2 idle/run strip built by generate_sprites.py.
STRIP_ROLES = {"wizzard", "knight", "rogue", "archmage", "elementalist",
               "assassin", "shadowblade", "paladin", "skeletonfodder",
               "skeletonwarrior", "skeletonmage", "skeletonrogue", "bonereaper",
               "lich", "wraith", "vampire", "vampirelord", "nightstalker",
               "cursedskull"}

# Roles derived from the big TinySwords sheets keep their source layout.
BIG_LAYOUT = {
    ("sniper", "black"): (6, 1), ("crossbowman", "black"): (6, 1),
    ("highpriest", "black"): (6, 1), ("highpriest", "blue"): (6, 1),
    ("highpriest", "red"): (6, 1), ("highpriest", "purple"): (6, 1),
    ("highpriest", "yellow"): (6, 1),
}
BIG_DEFAULT = (8, 7)  # archer sheets for blue/red/purple/yellow

# .tres basename -> (generated role, faction). Anything not listed keeps the
# art it already has and only gets metrics + name normalisation.
EXPLICIT = {
    "priest_yellow":        ("highpriest", "yellow"),
    "skeleton_base_black":  ("skeletonfodder", "black"),
    "skeleton_black":       ("skeletonwarrior", "black"),
    "skeleton_mage_black":  ("skeletonmage", "black"),
    "skeleton_rogue_black": ("skeletonrogue", "black"),
    "skull_black":          ("cursedskull", "black"),
    "bonereaper_black":     ("bonereaper", "black"),
    "lich_black":           ("lich", "black"),
    "wraith_black":         ("wraith", "black"),
    "vampire_black":        ("vampire", "black"),
    "vampirelord_black":    ("vampirelord", "black"),
    "nightstalker_black":   ("nightstalker", "black"),
}
BY_PREFIX = {"wizzard", "knight", "rogue", "archmage", "elementalist",
             "assassin", "shadowblade", "paladin", "sniper", "crossbowman",
             "highpriest"}

CHANGED: list[str] = []


def resolve_role(stem: str):
    if stem in EXPLICIT:
        return EXPLICIT[stem]
    for fac in FACTIONS:
        if stem.endswith("_" + fac):
            role = stem[: -len(fac) - 1]
            if role in BY_PREFIX:
                return role, fac
    return None


def layout_for(role: str, fac: str) -> tuple[int, int]:
    if role in STRIP_ROLES:
        return 6, 2
    return BIG_LAYOUT.get((role, fac), BIG_DEFAULT)


def strip_faction(name: str) -> str:
    """'Blue Pawn' -> 'Pawn'. Recruit/Upgrade popups show this verbatim, and
    a Blue castle listing 'Blue Pawn' is redundant."""
    for w in FACTION_WORDS:
        if name.startswith(w + " ") and len(name.split()) > 1:
            return name[len(w) + 1:]
    return name


def set_prop(body: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)} = .*$", re.M)
    if pat.search(body):
        return pat.sub(f"{key} = {value}", body, count=1)
    return body.rstrip("\n") + f"\n{key} = {value}\n"


def drop_prop(body: str, key: str) -> str:
    return re.sub(rf"^{re.escape(key)} = .*\n", "", body, flags=re.M)


def write_if_changed(path: str, text: str) -> None:
    old = open(path).read() if os.path.exists(path) else None
    if text != old:
        with open(path, "w") as f:
            f.write(text)
        CHANGED.append(path)


def texture_of(header: str, body: str) -> str | None:
    m = re.search(r'spritesheet = ExtResource\("([^"]+)"\)', body)
    if not m:
        return None
    m2 = re.search(rf'\[ext_resource type="Texture2D"[^\]]*id="{re.escape(m.group(1))}"[^\]]*\]', header)
    if not m2:
        return None
    p = re.search(r'path="res://([^"]+)"', m2.group(0))
    return p.group(1) if p else None


def repoint_texture(header: str, body: str, new_path: str) -> str:
    """Swap the referenced texture path and drop its stale uid (the generated
    file has no uid until Godot re-imports it; a wrong uid wins over path)."""
    m = re.search(r'spritesheet = ExtResource\("([^"]+)"\)', body)
    if not m:
        return header
    rid = m.group(1)

    def repl(mm):
        line = mm.group(0)
        line = re.sub(r'\s*uid="[^"]*"', "", line)
        return re.sub(r'path="res://[^"]*"', f'path="res://{new_path}"', line)

    return re.sub(rf'\[ext_resource type="Texture2D"[^\]]*id="{re.escape(rid)}"[^\]]*\]',
                  repl, header)


def process_tres(path: str) -> tuple[str, int, int] | None:
    stem = os.path.basename(path)[:-5]
    src = open(path).read()
    if "[resource]" not in src:
        return None
    header, body = src.split("[resource]", 1)

    role = resolve_role(stem)
    if role:
        tex = f"assets/characters/generated/{role[0]}/{role[0]}_{role[1]}.png"
        hf, vf = layout_for(*role)
        header = repoint_texture(header, body, tex)
        body = set_prop(body, "hframes", str(hf))
        body = set_prop(body, "vframes", str(vf))
    else:
        tex = texture_of(header, body)
        hf = int((re.search(r"^hframes = (\d+)", body, re.M) or [0, "6"])[1])
        vf = int((re.search(r"^vframes = (\d+)", body, re.M) or [0, "6"])[1])

    if not tex or not os.path.exists(tex):
        print(f"  !! missing texture for {stem}: {tex}")
        return None

    scale, ox, oy = G.sprite_metrics(Image.open(tex).convert("RGBA"), hf, vf)
    body = set_prop(body, "sprite_scale", f"{scale}")
    body = set_prop(body, "sprite_offset", f"Vector2({ox}, {oy})")
    body = drop_prop(body, "needs_palette_tint")

    nm = re.search(r'^unit_name = "([^"]*)"', body, re.M)
    if nm:
        body = set_prop(body, "unit_name", f'"{strip_faction(nm.group(1))}"')

    write_if_changed(path, header + "[resource]" + body)
    return tex, hf, vf


def sync_scenes(tex_by_tres: dict[str, tuple[str, int, int]]) -> None:
    """Keep the editor-preview Sprite2D in each unit .tscn matching its data."""
    for path in glob.glob("scenes/units/*.tscn"):
        src = open(path).read()
        m = re.search(r'\[ext_resource type="Resource"[^\]]*path="res://resources/units/([^"]+)\.tres"', src)
        if not m or m.group(1) not in tex_by_tres:
            continue
        tex, hf, vf = tex_by_tres[m.group(1)]
        out = re.sub(r'(\[ext_resource type="Texture2D")([^\]]*)(\])',
                     lambda mm: mm.group(1)
                     + re.sub(r'path="res://[^"]*"', f'path="res://{tex}"',
                              re.sub(r'\s*uid="[^"]*"', "", mm.group(2)))
                     + mm.group(3), src, count=1)
        out = re.sub(r"^hframes = \d+$", f"hframes = {hf}", out, flags=re.M)
        out = re.sub(r"^vframes = \d+$", f"vframes = {vf}", out, flags=re.M)
        write_if_changed(path, out)


if __name__ == "__main__":
    table = {}
    for p in sorted(glob.glob("resources/units/*.tres")):
        r = process_tres(p)
        if r:
            table[os.path.basename(p)[:-5]] = r
    sync_scenes(table)
    print(f"processed {len(table)} unit resources")
    print(f"{len(CHANGED)} file(s) rewritten")
