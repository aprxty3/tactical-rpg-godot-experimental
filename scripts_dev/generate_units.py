#!/usr/bin/env python3
"""SUPERSEDED — one-off generator for Milestone 3's Unit Upgrade Tree.

Kept for provenance only: this is how the Tier-2 fill-ins and the 40 Tier-3
promotions were originally created. DO NOT RUN IT AGAIN. It writes the visual
fields (`spritesheet`, `hframes`, `vframes`, `needs_palette_tint`) that are now
owned by a different pipeline, and `needs_palette_tint` no longer exists on
UnitData at all — re-running it would point every Tier-3 unit back at its
parent's texture and reintroduce a property the engine will reject.

The current pipeline, run from the repo root:

    python3 scripts_dev/generate_sprites.py   # derive the art
    python3 scripts_dev/wire_units.py         # wire it + bake render metrics
    python3 scripts_dev/validate_project.py   # verify

It also still refers to `priest_yellow.tres`, which was renamed to
`highpriest_yellow.tres`.
"""
import sys

import re
from pathlib import Path

_SUPERSEDED = (
    "scripts_dev/generate_units.py is superseded and will corrupt the unit "
    "resources if run.\nUse instead:\n"
    "  python3 scripts_dev/generate_sprites.py\n"
    "  python3 scripts_dev/wire_units.py\n"
    "  python3 scripts_dev/validate_project.py\n"
    "Pass --i-know-this-is-superseded to override."
)
if "--i-know-this-is-superseded" not in sys.argv:
    print(_SUPERSEDED)
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent
UNITS_DIR = ROOT / "resources" / "units"

FACTIONS = ["blue", "red", "purple", "yellow", "black"]
DISPLAY = {"blue": "Blue", "red": "Red", "purple": "Purple", "yellow": "Yellow", "black": "Black"}

# Generic (non-recolored) source sheets shared across all factions.
KNIGHT_TEX = ("res://assets/characters/knight/Idle/Idle-Sheet.png", 4, 1)
ROGUE_TEX = ("res://assets/characters/rogue/Idle/Idle-Sheet.png", 4, 1)
WIZZARD_TEX = ("res://assets/characters/wizzard/Idle/Idle-Sheet.png", 4, 1)
PRIEST_TEX = ("res://assets/characters/priest/priest1/v1/priest1_v1_1.png", 1, 1)

# Archer already has real per-faction art -- Sniper/Crossbowman reuse it directly.
ARCHER_TEX = {
    "blue": ("res://assets/characters/archer/Blue/Archer_Blue.png", 8, 7),
    "red": ("res://assets/characters/archer/Red/Archer_Red.png", 8, 7),
    "purple": ("res://assets/characters/archer/Purple/Archer_Purlple.png", 8, 7),
    "yellow": ("res://assets/characters/archer/Yellow/Archer_Yellow.png", 8, 7),
    "black": ("res://assets/characters/factions/black/Archer/Archer_Idle.png", 6, 1),
}


def write_tres(filename, *, unit_name, unit_class, tier, description,
                hp, atk, deff, mov, rmin, rmax, gold, iron, cap,
                tex_path, hframes, vframes, needs_tint,
                upgrade_paths=None):
    """upgrade_paths: dict[label] -> 'resources/units/<file>.tres' (repo-relative)."""
    upgrade_paths = upgrade_paths or {}
    ext_lines = [
        '[ext_resource type="Script" path="res://scripts/data/UnitData.gd" id="1_scr"]',
        f'[ext_resource type="Texture2D" path="{tex_path}" id="2_tex"]',
    ]
    up_ids = {}
    next_id = 3
    for label, target in upgrade_paths.items():
        eid = f"{next_id}_up"
        ext_lines.append(f'[ext_resource type="Resource" path="res://{target}" id="{eid}"]')
        up_ids[label] = eid
        next_id += 1

    if up_ids:
        body = ",\n".join(f'"{label}": ExtResource("{eid}")' for label, eid in up_ids.items())
        up_block = "upgrade_paths = {\n" + body + "\n}"
    else:
        up_block = "upgrade_paths = {}"

    tint_line = "needs_palette_tint = true\n" if needs_tint else ""

    content = (
        f'[gd_resource type="Resource" script_class="UnitData" load_steps={len(ext_lines) + 1} format=3]\n\n'
        + "\n".join(ext_lines)
        + "\n\n[resource]\n"
        f'script = ExtResource("1_scr")\n'
        f'unit_name = "{unit_name}"\n'
        f'unit_class = "{unit_class}"\n'
        f'tier = {tier}\n'
        f'description = "{description}"\n'
        f'max_health = {hp}\n'
        f'attack_power = {atk}\n'
        f'defense_power = {deff}\n'
        f'movement_points = {mov}\n'
        f'attack_range_min = {rmin}\n'
        f'attack_range_max = {rmax}\n'
        f'recruit_cost_gold = {gold}\n'
        f'recruit_cost_iron = {iron}\n'
        f'capacity_weight = {cap}\n'
        f'spritesheet = ExtResource("2_tex")\n'
        f'hframes = {hframes}\n'
        f'vframes = {vframes}\n'
        f'{tint_line}'
        f'{up_block}\n'
    )
    path = UNITS_DIR / filename
    path.write_text(content, encoding="utf-8")
    print(f"wrote {filename}")


def highpriest_path(color):
    return "resources/units/priest_yellow.tres" if color == "yellow" else f"resources/units/highpriest_{color}.tres"


# ---------------------------------------------------------------------------
# 1. New Tier-2 fill-ins: Wizzard (Blue/Red/Purple/Black), Rogue (Blue/Red/Yellow/Black)
# ---------------------------------------------------------------------------
for color in ["blue", "red", "purple", "black"]:
    name = f"{DISPLAY[color]} Wizzard" if color != "black" else "Black Wizzard"
    write_tres(
        f"wizzard_{color}.tres",
        unit_name=name, unit_class="Mage", tier=2,
        description=f"{DISPLAY[color]} battle mage hurling arcane bolts at range.",
        hp=45, atk=32, deff=3, mov=2, rmin=2, rmax=2, gold=120, iron=0, cap=2,
        tex_path=WIZZARD_TEX[0], hframes=WIZZARD_TEX[1], vframes=WIZZARD_TEX[2],
        needs_tint=True,
    )

for color in ["blue", "red", "yellow", "black"]:
    name = f"{DISPLAY[color]} Rogue" if color != "black" else "Black Rogue"
    write_tres(
        f"rogue_{color}.tres",
        unit_name=name, unit_class="Infiltrator", tier=2,
        description=f"{DISPLAY[color]} infiltrator striking from the shadows.",
        hp=50, atk=26, deff=4, mov=4, rmin=1, rmax=1, gold=90, iron=1, cap=2,
        tex_path=ROGUE_TEX[0], hframes=ROGUE_TEX[1], vframes=ROGUE_TEX[2],
        needs_tint=True,
    )

# Black Knight (only faction missing one)
write_tres(
    "knight_black.tres",
    unit_name="Black Knight", unit_class="Melee", tier=3,
    description="Black Coven heavy knight clad in cursed plate.",
    hp=95, atk=36, deff=12, mov=4, rmin=1, rmax=1, gold=150, iron=4, cap=3,
    tex_path=KNIGHT_TEX[0], hframes=KNIGHT_TEX[1], vframes=KNIGHT_TEX[2],
    needs_tint=True,
)

# ---------------------------------------------------------------------------
# 2. New Tier-3 branches, all 5 factions each
# ---------------------------------------------------------------------------
for color in FACTIONS:
    d = DISPLAY[color]
    tex, hf, vf = ARCHER_TEX[color]
    write_tres(f"sniper_{color}.tres", unit_name=f"{d} Sniper", unit_class="Ranged", tier=3,
               description=f"{d} marksman picking off targets from extreme range.",
               hp=55, atk=30, deff=4, mov=3, rmin=3, rmax=4, gold=130, iron=2, cap=3,
               tex_path=tex, hframes=hf, vframes=vf, needs_tint=False)

    write_tres(f"crossbowman_{color}.tres", unit_name=f"{d} Crossbowman", unit_class="Ranged", tier=3,
               description=f"{d} crossbow soldier piercing heavy armor.",
               hp=60, atk=34, deff=6, mov=3, rmin=2, rmax=3, gold=130, iron=2, cap=3,
               tex_path=tex, hframes=hf, vframes=vf, needs_tint=False)

    write_tres(f"archmage_{color}.tres", unit_name=f"{d} Archmage", unit_class="Mage", tier=3,
               description=f"{d} archmage unleashing devastating area magic.",
               hp=55, atk=42, deff=4, mov=2, rmin=2, rmax=3, gold=150, iron=1, cap=3,
               tex_path=WIZZARD_TEX[0], hframes=WIZZARD_TEX[1], vframes=WIZZARD_TEX[2], needs_tint=True)

    write_tres(f"elementalist_{color}.tres", unit_name=f"{d} Elementalist", unit_class="Mage", tier=3,
               description=f"{d} elementalist scorching foes with lingering burns.",
               hp=50, atk=36, deff=5, mov=3, rmin=2, rmax=2, gold=140, iron=1, cap=3,
               tex_path=WIZZARD_TEX[0], hframes=WIZZARD_TEX[1], vframes=WIZZARD_TEX[2], needs_tint=True)

    if color != "yellow":
        write_tres(f"highpriest_{color}.tres", unit_name=f"{d} High Priest", unit_class="Support", tier=3,
                   description=f"{d} high priest channeling mass healing light.",
                   hp=70, atk=20, deff=6, mov=3, rmin=1, rmax=2, gold=150, iron=1, cap=3,
                   tex_path=PRIEST_TEX[0], hframes=PRIEST_TEX[1], vframes=PRIEST_TEX[2], needs_tint=True)

    write_tres(f"paladin_{color}.tres", unit_name=f"{d} Paladin", unit_class="Melee", tier=3,
               description=f"{d} paladin, a holy knight blending steel and faith.",
               hp=85, atk=32, deff=10, mov=3, rmin=1, rmax=1, gold=150, iron=2, cap=3,
               tex_path=KNIGHT_TEX[0], hframes=KNIGHT_TEX[1], vframes=KNIGHT_TEX[2], needs_tint=True)

    write_tres(f"assassin_{color}.tres", unit_name=f"{d} Assassin", unit_class="Infiltrator", tier=3,
               description=f"{d} assassin delivering lethal backstabs.",
               hp=55, atk=40, deff=3, mov=4, rmin=1, rmax=1, gold=140, iron=1, cap=3,
               tex_path=ROGUE_TEX[0], hframes=ROGUE_TEX[1], vframes=ROGUE_TEX[2], needs_tint=True)

    write_tres(f"shadowblade_{color}.tres", unit_name=f"{d} Shadowblade", unit_class="Infiltrator", tier=3,
               description=f"{d} shadowblade striking from ambush.",
               hp=60, atk=34, deff=5, mov=5, rmin=1, rmax=1, gold=140, iron=1, cap=3,
               tex_path=ROGUE_TEX[0], hframes=ROGUE_TEX[1], vframes=ROGUE_TEX[2], needs_tint=True)

print("--- new files done ---")

# ---------------------------------------------------------------------------
# 3. Patch existing files
# ---------------------------------------------------------------------------

def read(name):
    return (UNITS_DIR / name).read_text(encoding="utf-8")


def write(name, text):
    (UNITS_DIR / name).write_text(text, encoding="utf-8")


def bump_load_steps(text, added_ext_resources):
    m = re.search(r"load_steps=(\d+)", text)
    n = int(m.group(1)) + added_ext_resources
    return re.sub(r"load_steps=\d+", f"load_steps={n}", text, count=1)


def insert_ext_resources(text, new_lines):
    # Insert right after the last existing [ext_resource ...] line.
    lines = text.split("\n")
    last_ext_idx = max(i for i, l in enumerate(lines) if l.startswith("[ext_resource"))
    for offset, nl in enumerate(new_lines, start=1):
        lines.insert(last_ext_idx + offset, nl)
    return "\n".join(lines)


def set_upgrade_paths_block(text, ext_id_by_label):
    body = ",\n".join(f'"{label}": ExtResource("{eid}")' for label, eid in ext_id_by_label.items())
    new_block = "upgrade_paths = {\n" + body + "\n}"
    assert "upgrade_paths = {}" in text, "expected empty upgrade_paths = {} placeholder"
    return text.replace("upgrade_paths = {}", new_block, 1)


def add_upgrade_paths(filename, targets: dict):
    """targets: label -> 'resources/units/xxx.tres'"""
    text = read(filename)
    if "upgrade_paths = {}" not in text:
        print(f"  SKIP (already patched or unexpected format): {filename}")
        return
    new_ext_lines = []
    ext_id_by_label = {}
    next_id = 3
    for label, target in targets.items():
        eid = f"{next_id}_up"
        new_ext_lines.append(f'[ext_resource type="Resource" path="res://{target}" id="{eid}"]')
        ext_id_by_label[label] = eid
        next_id += 1
    text = bump_load_steps(text, len(new_ext_lines))
    text = insert_ext_resources(text, new_ext_lines)
    text = set_upgrade_paths_block(text, ext_id_by_label)
    write(filename, text)
    print(f"patched upgrade_paths -> {filename}")


def set_tier(filename, new_tier):
    text = read(filename)
    text2 = re.sub(r"^tier = \d+$", f"tier = {new_tier}", text, count=1, flags=re.M)
    if text2 == text:
        print(f"  SKIP (tier already set?): {filename}")
    write(filename, text2)
    print(f"set tier={new_tier} -> {filename}")


def add_needs_tint(filename):
    text = read(filename)
    if "needs_palette_tint" in text:
        print(f"  SKIP (already tinted): {filename}")
        return
    text2 = text.replace("upgrade_paths = {}", "needs_palette_tint = true\nupgrade_paths = {}", 1)
    write(filename, text2)
    print(f"added needs_palette_tint -> {filename}")


# 3a. Warrior: fix tier 1 -> 2, add upgrade_paths to Knight/Lancer
for color in FACTIONS:
    set_tier(f"warrior_{color}.tres", 2)
    add_upgrade_paths(f"warrior_{color}.tres", {
        "Knight": f"resources/units/knight_{color}.tres",
        "Lancer": f"resources/units/lancer_{color}.tres",
    })

# 3b. Archer: add upgrade_paths to Sniper/Crossbowman
for color in FACTIONS:
    add_upgrade_paths(f"archer_{color}.tres", {
        "Sniper": f"resources/units/sniper_{color}.tres",
        "Crossbowman": f"resources/units/crossbowman_{color}.tres",
    })

# 3c. Existing Wizzard (yellow) / Rogue (purple): tint + upgrade_paths
add_needs_tint("wizzard_yellow.tres")
add_upgrade_paths("wizzard_yellow.tres", {
    "Archmage": "resources/units/archmage_yellow.tres",
    "Elementalist": "resources/units/elementalist_yellow.tres",
})
add_needs_tint("rogue_purple.tres")
add_upgrade_paths("rogue_purple.tres", {
    "Assassin": "resources/units/assassin_purple.tres",
    "Shadowblade": "resources/units/shadowblade_purple.tres",
})

# also give the brand-new wizzard_*/rogue_* fill-ins their upgrade_paths
for color in ["blue", "red", "purple", "black"]:
    add_upgrade_paths(f"wizzard_{color}.tres", {
        "Archmage": f"resources/units/archmage_{color}.tres",
        "Elementalist": f"resources/units/elementalist_{color}.tres",
    })
for color in ["blue", "red", "yellow", "black"]:
    add_upgrade_paths(f"rogue_{color}.tres", {
        "Assassin": f"resources/units/assassin_{color}.tres",
        "Shadowblade": f"resources/units/shadowblade_{color}.tres",
    })

# 3d. Existing Knights (blue/red/purple/yellow): tint (black knight created fresh already tinted)
for color in ["blue", "red", "purple", "yellow"]:
    add_needs_tint(f"knight_{color}.tres")

# 3e. Monk: add upgrade_paths to High Priest / Paladin
for color in FACTIONS:
    add_upgrade_paths(f"monk_{color}.tres", {
        "High Priest": f"res://{highpriest_path(color)}"[len("res://"):] if False else highpriest_path(color),
        "Paladin": f"resources/units/paladin_{color}.tres",
    })

# 3f. Pawn: add upgrade_paths to all 5 Tier-2 branches
for color in FACTIONS:
    add_upgrade_paths(f"pawn_{color}.tres", {
        "Warrior": f"resources/units/warrior_{color}.tres",
        "Archer": f"resources/units/archer_{color}.tres",
        "Wizzard": f"resources/units/wizzard_{color}.tres",
        "Monk": f"resources/units/monk_{color}.tres",
        "Rogue": f"resources/units/rogue_{color}.tres",
    })

# 3g. Priest (yellow) -> retier & restat as the Yellow High Priest
text = read("priest_yellow.tres")
text = text.replace('unit_name = "Yellow Priest"', 'unit_name = "Yellow High Priest"')
text = re.sub(r"^tier = \d+$", "tier = 3", text, count=1, flags=re.M)
text = re.sub(r"^description = .*$", 'description = "Yellow high priest channeling mass healing light."', text, count=1, flags=re.M)
text = re.sub(r"^max_health = \d+$", "max_health = 70", text, count=1, flags=re.M)
text = re.sub(r"^attack_power = \d+$", "attack_power = 20", text, count=1, flags=re.M)
text = re.sub(r"^defense_power = \d+$", "defense_power = 6", text, count=1, flags=re.M)
text = re.sub(r"^recruit_cost_gold = \d+$", "recruit_cost_gold = 150", text, count=1, flags=re.M)
text = re.sub(r"^capacity_weight = \d+$", "capacity_weight = 3", text, count=1, flags=re.M)
if "needs_palette_tint" not in text:
    text = text.replace("upgrade_paths = {}", "needs_palette_tint = true\nupgrade_paths = {}", 1)
write("priest_yellow.tres", text)
print("retiered priest_yellow.tres -> Yellow High Priest (tier 3)")

print("--- patch pass done ---")
