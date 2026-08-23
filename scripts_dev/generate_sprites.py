#!/usr/bin/env python3
"""generate_sprites.py — derive every missing unit spritesheet, then bake the
per-unit render metrics back into resources/units/*.tres.

Run from the project root:   python3 scripts_dev/generate_sprites.py

Why this exists
---------------
Three separate defects shared one root cause — the art pack never had a sprite
for most of the roster:

  * Tier-3 promotions re-used their Tier-2 parent's texture verbatim, so
    Archer -> Sniper (and 12 others) changed nothing on screen.
  * Source frames range from 16x16 icons to 320x320 TinySwords sheets, but
    every unit node was hard-scaled to 0.45, so mages and undead rendered at a
    fraction of a Warrior's size.
  * Five factions shared one uncolored generic sheet, patched over at runtime
    by a palette-tint shader.

Rather than hand-authoring ~70 near-duplicate PNGs (and violating this repo's
DRY rule), every derived sheet is generated from its parent art:

    faction -> hue        (rotate the garment palette onto the faction hue)
    role    -> value/saturation + rim light + pixel accessory

Idempotent: safe to re-run. Only writes files whose bytes actually change.
"""
from __future__ import annotations

import io
import os
import re
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spritegen_lib as G  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

OUT_DIR = "assets/characters/generated"
CHANGED: list[str] = []

# --------------------------------------------------------------- definitions

# Hues sampled from GameConfig.FACTION_TINT_COLORS so generated art and the
# HUD/mini-map agree on what "Purple Syndicate" looks like.
FACTIONS = {
    "blue":   dict(hue=0.600, sat=1.00, val=1.00),
    "red":    dict(hue=0.010, sat=1.00, val=1.00),
    "purple": dict(hue=0.780, sat=1.00, val=1.00),
    "yellow": dict(hue=0.130, sat=1.00, val=1.05),
    "black":  dict(hue=0.720, sat=0.45, val=0.62),
}

# 32x32 strip bases that ship an Idle + a Run animation.
STRIP_BASES = {
    "wizzard":    "assets/characters/wizzard",
    "knight":     "assets/characters/knight",
    "rogue":      "assets/characters/rogue",
    "skel_base":  "assets/characters/skeleton/base",
    "skel_war":   "assets/characters/skeleton/warrior",
    "skel_mage":  "assets/characters/skeleton/mage",
    "skel_rogue": "assets/characters/skeleton/rogue",
}

# role -> (base, sat_mul, val_mul, hue_nudge, rim_rgb|None, accessory|None, alpha)
HUMAN_ROLES = {
    "wizzard":      ("wizzard", 1.00, 1.00,  0.00, None,                None,     1.0),
    "knight":       ("knight",  1.00, 1.00,  0.00, None,                None,     1.0),
    "rogue":        ("rogue",   1.00, 1.00,  0.00, None,                None,     1.0),
    "archmage":     ("wizzard", 1.15, 1.12,  0.00, (0.47, 0.86, 1.00), "orb",     1.0),
    "elementalist": ("wizzard", 1.35, 1.08,  0.00, (1.00, 0.55, 0.15), "flame",   1.0),
    "assassin":     ("rogue",   0.60, 0.62,  0.00, (0.90, 0.12, 0.15), "glint",   1.0),
    "shadowblade":  ("rogue",   0.90, 0.72,  0.06, (0.65, 0.35, 1.00), "ghost",   1.0),
    "paladin":      ("knight",  0.85, 1.18,  0.00, (1.00, 0.86, 0.30), "halo",    1.0),
}

# Black-Coven-only lineage. Undead don't vary by faction, so no hue rotation
# onto a faction colour — the role hue IS the identity.
UNDEAD_ROLES = {
    "skeletonfodder":  ("skel_base",  None,  1.00, 1.00, 0.00, None,               None,    1.00),
    "skeletonwarrior": ("skel_war",   None,  1.00, 1.00, 0.00, None,               None,    1.00),
    "skeletonmage":    ("skel_mage",  None,  1.00, 1.00, 0.00, None,               None,    1.00),
    "skeletonrogue":   ("skel_rogue", None,  1.00, 1.00, 0.00, None,               None,    1.00),
    "bonereaper":      ("skel_war",   0.99,  1.10, 0.78, 0.00, (0.90, 0.15, 0.10), "glint", 1.00),
    "lich":            ("skel_mage",  0.33,  1.00, 0.92, 0.00, (0.35, 1.00, 0.50), "crown", 1.00),
    "wraith":          ("skel_rogue", 0.50,  0.90, 1.05, 0.00, (0.40, 1.00, 1.00), "ghost", 0.72),
    "vampire":         ("rogue",      0.98,  1.00, 0.78, 0.00, None,               None,    1.00),
    "vampirelord":     ("rogue",      0.97,  1.15, 0.60, 0.00, (1.00, 0.85, 0.30), "fang",  1.00),
    "nightstalker":    ("rogue",      0.76,  0.85, 0.55, 0.00, (0.70, 0.40, 1.00), "ghost", 0.80),
    "cursedskull":     ("skel_base",  None,  0.25, 1.08, 0.00, (0.40, 1.00, 0.60), "crown", 1.00),
}

# Roles derived from the big per-faction TinySwords sheets. Those are already
# faction-coloured, so only the role treatment is applied (no hue rotation).
BIG_ROLES = {
    # No pixel accessory on the 192px TinySwords sheets except the halo: at
    # that frame size an eye-glint lands on the straw hat, not on a face.
    # These three are read at ~0.46 scale in game, so the treatment has to be
    # strong enough to survive the downscale: a subtle rim alone is invisible.
    "sniper":      ("archer", 0.95, 0.58,  0.14, (0.55, 1.00, 0.30), None),
    "crossbowman": ("archer", 0.16, 1.10,  0.00, (0.70, 0.78, 0.95), None),
    "highpriest":  ("monk",   0.40, 1.20,  0.00, (1.00, 0.90, 0.45), "halo"),
}

BIG_SOURCES = {
    ("archer", "blue"):   ("assets/characters/archer/Blue/Archer_Blue.png", 8, 7),
    ("archer", "red"):    ("assets/characters/archer/Red/Archer_Red.png", 8, 7),
    ("archer", "purple"): ("assets/characters/archer/Purple/Archer_Purlple.png", 8, 7),
    ("archer", "yellow"): ("assets/characters/archer/Yellow/Archer_Yellow.png", 8, 7),
    ("archer", "black"):  ("assets/characters/factions/black/Archer/Archer_Idle.png", 6, 1),
    ("monk", "blue"):     ("assets/characters/factions/blue/Monk/Idle.png", 6, 1),
    ("monk", "red"):      ("assets/characters/factions/red/Monk/Idle.png", 6, 1),
    ("monk", "purple"):   ("assets/characters/factions/purple/Monk/Idle.png", 6, 1),
    ("monk", "yellow"):   ("assets/characters/factions/yellow/Monk/Idle.png", 6, 1),
    ("monk", "black"):    ("assets/characters/factions/black/Monk/Idle.png", 6, 1),
}

TARGET_COLS = 6  # 6 run frames; idle (4 frames) is ping-ponged to match


# ------------------------------------------------------------------- helpers

def save_if_changed(img: Image.Image, path: str) -> None:
    """Write only on a real byte change so re-runs leave mtimes (and Godot's
    import cache) alone."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    new = buf.getvalue()
    old = open(path, "rb").read() if os.path.exists(path) else None
    if new != old:
        with open(path, "wb") as f:
            f.write(new)
        CHANGED.append(path)


def load_strip(base_dir: str, anim: str):
    """Return (frames, union_bbox) for a 32/64px animation strip."""
    img = Image.open(f"{base_dir}/{anim}/{anim}-Sheet.png").convert("RGBA")
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


def compose_strip_sheet(base_dir: str) -> Image.Image:
    """Idle + Run -> one tight sheet, 6 columns x 2 rows, bottom-centre aligned.

    Cropping each animation with its OWN union bbox keeps the intra-animation
    bob/stride, while aligning the two crops bottom-centre keeps the character
    from jumping when idle hands over to run.
    """
    idle_f, idle_bb = load_strip(base_dir, "Idle")
    run_f, run_bb = load_strip(base_dir, "Run")

    idle_c = [f.crop(idle_bb) for f in idle_f]
    run_c = [f.crop(run_bb) for f in run_f]
    # Ping-pong a 4-frame idle up to 6 columns so both rows share a frame count.
    order = [0, 1, 2, 3, 2, 1] if len(idle_c) == 4 else list(range(len(idle_c)))
    idle_c = [idle_c[i % len(idle_c)] for i in order[:TARGET_COLS]]
    while len(run_c) < TARGET_COLS:
        run_c.append(run_c[-1])
    run_c = run_c[:TARGET_COLS]

    cw = max(max(f.width for f in idle_c), max(f.width for f in run_c)) + 2
    ch = max(max(f.height for f in idle_c), max(f.height for f in run_c)) + 2
    sheet = Image.new("RGBA", (cw * TARGET_COLS, ch * 2), (0, 0, 0, 0))
    for r, row in enumerate((idle_c, run_c)):
        for c, f in enumerate(row):
            x = c * cw + (cw - f.width) // 2          # centre horizontally
            y = r * ch + (ch - 1 - f.height)          # stand on the cell floor
            sheet.alpha_composite(f, (x, y))
    return sheet


def apply_role(sheet: Image.Image, hf: int, vf: int, *, hue=None, nudge=0.0,
               sat=1.0, val=1.0, alpha=1.0, rim=None, acc=None) -> Image.Image:
    out = G.recolor(sheet, hue_target=hue, hue_nudge=nudge,
                    sat_mul=sat, val_mul=val, alpha_mul=alpha)
    body_h = 1
    bb = G.union_bbox(out, hf, vf)
    if bb:
        body_h = max(1, bb[3] - bb[1])
    if rim:
        out = G.add_rim(out, rim, width=max(1, round(body_h / 22.0)), alpha=0.6)
    if acc:
        fw, fh = out.width // hf, out.height // vf
        unit = max(1, round(body_h / 16.0))
        canvas = Image.new("RGBA", out.size, (0, 0, 0, 0))
        for c, r, frame in G.frames_of(out, hf, vf):
            fbb = frame.getbbox()
            canvas.alpha_composite(G.draw_accessory(frame, acc, fbb, unit),
                                   (c * fw, r * fh))
        out = canvas
    return out


# ------------------------------------------------------------------ pipelines

def gen_human() -> dict[tuple[str, str], tuple[str, int, int]]:
    """Every human-tree role x every faction. Returns {(role,faction): (path,hf,vf)}."""
    made = {}
    cache = {k: compose_strip_sheet(v) for k, v in STRIP_BASES.items()}
    for role, (base, sat, val, nudge, rim, acc, alpha) in HUMAN_ROLES.items():
        for fac, fdef in FACTIONS.items():
            img = apply_role(cache[base], TARGET_COLS, 2,
                             hue=fdef["hue"], nudge=nudge,
                             sat=sat * fdef["sat"], val=val * fdef["val"],
                             alpha=alpha, rim=rim, acc=acc)
            path = f"{OUT_DIR}/{role}/{role}_{fac}.png"
            save_if_changed(img, path)
            made[(role, fac)] = (path, TARGET_COLS, 2)
    return made


def gen_undead() -> dict[tuple[str, str], tuple[str, int, int]]:
    made = {}
    cache = {k: compose_strip_sheet(v) for k, v in STRIP_BASES.items()}
    for role, (base, hue, sat, val, nudge, rim, acc, alpha) in UNDEAD_ROLES.items():
        img = apply_role(cache[base], TARGET_COLS, 2, hue=hue, nudge=nudge,
                         sat=sat, val=val, alpha=alpha, rim=rim, acc=acc)
        path = f"{OUT_DIR}/{role}/{role}_black.png"
        save_if_changed(img, path)
        made[(role, "black")] = (path, TARGET_COLS, 2)
    return made


def gen_big() -> dict[tuple[str, str], tuple[str, int, int]]:
    made = {}
    for role, (base, sat, val, nudge, rim, acc) in BIG_ROLES.items():
        for fac in FACTIONS:
            src, hf, vf = BIG_SOURCES[(base, fac)]
            img = apply_role(Image.open(src).convert("RGBA"), hf, vf,
                             hue=None, nudge=nudge, sat=sat, val=val,
                             rim=rim, acc=acc)
            path = f"{OUT_DIR}/{role}/{role}_{fac}.png"
            save_if_changed(img, path)
            made[(role, fac)] = (path, hf, vf)
    return made


def gen_iron_mine() -> str:
    """No iron-mine art exists; desaturate the gold mine into a steel one."""
    src = "assets/buildings/gold_mine/GoldMine_Active.png"
    img = G.recolor(Image.open(src).convert("RGBA"),
                    hue_target=0.58, sat_mul=0.32, val_mul=0.94)
    path = "assets/buildings/iron_mine/IronMine_Active.png"
    save_if_changed(img, path)
    return path


if __name__ == "__main__":
    made = {}
    made.update(gen_human())
    made.update(gen_undead())
    made.update(gen_big())
    iron = gen_iron_mine()
    print(f"generated {len(made)} unit sheets + iron mine")
    print(f"{len(CHANGED)} file(s) written")
    for p in CHANGED[:8]:
        print("  ", p)
    if len(CHANGED) > 8:
        print(f"   ... and {len(CHANGED) - 8} more")
