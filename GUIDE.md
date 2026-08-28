---
type: Developer Guide
title: "War Perang Tactics — Developer & Extension Guide"
description: "How to add new units, buildings, factions, systems, and test in Godot 4.7."
tags: [guide, tutorial, development, extension]
generated: { by: human:aprxty3, at: 2026-08-22T23:55:00Z }
---

# 📖 Developer & Extension Guide

A practical guide for developers who want to add new units, new buildings, or expand game mechanics in **War Perang Tactics**.

---

## 🗡️ 1. How to Add a New Unit

To create a new unit (e.g., **Archer** or **Knight**):

### Step A: Create the `UnitData` Resource (`.tres`)
1. In the Godot Editor (FileSystem), create a new Resource file in the `resources/units/` folder (e.g., `archer_blue.tres`).
2. Select the Resource type `UnitData`.
3. Fill in the parameters in the Inspector:
   * **Identity**:
     * `unit_name`: "Blue Archer"
     * `unit_class`: "Ranged"
     * `tier`: 1
   * **Combat Stats**:
     * `max_health`: 80
     * `attack_power`: 28
     * `defense_power`: 6
     * `movement_points`: 3
     * `attack_range_min`: 2 *(Can attack from a distance)*
     * `attack_range_max`: 3
   * **Economy & Logistics**:
     * `recruit_cost_gold`: 70
     * `recruit_cost_iron`: 1
     * `capacity_weight`: 2
   * **Visuals** — `spritesheet`, `hframes`, `vframes`, and the two **baked** fields
     `sprite_scale` / `sprite_offset`.

> ⚠️ **Never type `sprite_scale` or `sprite_offset` by hand.** Source art in this project
> ranges from 16x16 icons to 320x320 TinySwords frames, so those two values are what keep
> a mage the same height as a Warrior. They are solved from the sheet's idle-row content
> bounding box. Add the unit, then run:
>
> ```bash
> python3 scripts_dev/wire_units.py         # bakes scale/offset for every unit
> python3 scripts_dev/validate_project.py   # fails if any unit drifts off 38px
> ```

> 💡 **`unit_name` has no faction prefix.** The Recruit and Upgrade popups render it
> verbatim, so a Blue castle offering "Blue Pawn" reads as noise — it is just `"Pawn"`.
> Flavour names (`Cultist Pawn`, `Death Lancer`) are fine; a bare colour word is not.

### Step B: Create the Unit Prefab Scene (`.tscn`)
1. Create a scene inherited from `scenes/units/TacticalUnit.tscn` or create a new `Node2D` with the script `res://scripts/units/TacticalUnit.gd`.
2. Change the `Sprite2D` texture with the relevant unit sprite (e.g., `assets/characters/archer/Blue/Archer_Blue.png`).
3. Set `hframes` and `vframes` according to the spritesheet. (Runtime overwrites both from
   `UnitData`; the scene values are just the editor preview.)
4. Attach the `archer_blue.tres` resource to the `@export var unit_data` slot.
5. **Leave the root node at `scale = 1.0`.** `TacticalUnit` scales its own `Sprite2D` from
   the baked metrics — a node-level scale multiplies on top and undoes the normalisation.
   `validate_project.py` fails the build if a unit scene sets one.
6. Save the scene as `scenes/units/TacticalUnit_Archer_Blue.tscn`.

### Step C: Derive the art if it doesn't exist yet
There is no image-generation tool in this project. If the unit is a promotion that would
otherwise re-use its parent's sheet, add it to the role table in
[`scripts_dev/generate_sprites.py`](scripts_dev/generate_sprites.py) instead of shipping a
duplicate texture:

```python
# role: (base_sheet, sat_mul, val_mul, hue_nudge, rim_rgb|None, accessory|None, alpha)
"myrole": ("rogue", 0.70, 0.85, 0.00, (0.9, 0.4, 0.1), "glint", 1.0),
```

**Faction owns hue; the role owns everything else** (value, saturation, rim light, pixel
accessory). Giving a role its own hue makes a Blue unit stop reading as Blue, which is the
one thing an Advance-Wars-style map cannot afford. Then:

```bash
python3 scripts_dev/generate_sprites.py
python3 scripts_dev/wire_units.py
python3 scripts_dev/preview_units.py   # eyeball it at real in-game size
```

`preview_units.py` reproduces Sprite2D's exact transform from the baked `.tres` values, so
what it renders is what the engine will draw. Check the promotion is still distinguishable
at ~0.4x scale — a subtle rim vanishes on the big TinySwords sheets.

---

## 🏰 2. How to Add a New Building

To add a new building (e.g., **Iron Mine** or **Village**):

1. Create a new scene in `scenes/buildings/` with a `Node2D` root using the script [`scripts/buildings/Building.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/buildings/Building.gd).
2. In the Inspector, set:
   * `building_type`: Select the type (e.g., `IRON_MINE` or `HOUSE`).
   * `faction_id`: `99` (Neutral) or `0` (Blue).
3. Add a `Sprite2D` child node and attach the building sprite from `assets/buildings/`.
   For a **neutral** building use the neutral/construction art — `Building` swaps in the
   owning faction's sprite on capture, and falls back to whatever the scene authored while
   the building is unowned. (A neutral village authored with `House_Blue.png` looks like
   the player already owns it. This was a real bug.)
4. Ownership visuals are automatic:
   * Types listed in `Building.FACTION_ART_FILE` (Castle, House, Tower) get a **texture
     swap** out of `assets/buildings/{Faction} Buildings/`.
   * Everything else (Gold/Iron Mine) flies a generated pennant in the faction colour.
     Add a per-faction sprite to `FACTION_ART_FILE` if the art pack ever gains one.
5. If you want the building to be able to recruit (Castle only):
   * Insert the unit Resource list into the `recruitable_units` array.
   * `Building.resolve_for_owner()` maps each entry onto the **current owner's** variant via
     the `{role}_{faction}.tres` convention, so a captured castle fields the captor's troops.
     Keep that naming or the lookup silently falls back to the roster's own faction.

---

## 🧪 3. How to Run & Test Scenes

### Via Godot Editor:
- **`F5`** runs the project from the main menu ([`scenes/ui/MainMenu.tscn`](scenes/ui/MainMenu.tscn)) —
  the full path a player takes: menu → faction select → battlefield.
- **`F6`** plays whichever scene is open. Opening
  [`scenes/Match.tscn`](scenes/Match.tscn) directly skips the menu and starts a
  match under whatever [`MatchSetup`](scripts/autoload/MatchSetup.gd) currently
  holds — Blue Kingdom on a fresh launch. This is what every test suite does.

### Via Terminal (Headless Mode):
If you want to test scripts automatically without opening the graphical window:
```bash
# One-off after generating art: import the new PNGs so the engine can load them
godot --headless --path . --import

godot --headless --path . scenes/Match.tscn --quit-after 50
```
If the return code is `0` and there are no red errors, it means the scene compiled and ran normally.

### The test scenes
| Scene | Covers |
|---|---|
| `scenes/ui/MainMenu.tscn` | Boot screen — the project's main scene |
| `scenes/Match.tscn` | The playable battlefield end to end |
| `scenes/test_all_units.tscn` | Every `.tres` loads with a valid spritesheet & frame layout |
| `scenes/test_combat_mechanics.tscn` | The six class fighting styles and damage formula |
| `scenes/test_upgrade_flow.tscn` | Promotion, Field Tax, **promotion visuals**, unit names, baked metrics |
| `scenes/test_village_capacity.tscn` | Village capture, troop capacity, starvation |
| `scenes/test_popup_and_map.tscn` | End-turn modal and tilemap population |
| `scenes/test_battlefield.tscn` | Map shape, impassable water, bridge crossability, capture visuals, owner-variant recruitment |
| `scenes/test_undead_gameplay.tscn` | The Undead lineage — recruitment, promotion, Holy ×2.5 |
| `scenes/test_qa_stress.tscn` | Capacity ledger under capture/loss, health, sprite scaling |
| `scenes/test_milestone4.tscn` | **61 checks** — vision, morale, map objects, fog |
| `scenes/test_milestone5.tscn` | **324 checks** — AI scoring, VFX, mounts, audio, encounters, capacity |

> **The milestone suites never exit on their own.** They print their summary and
> then keep running, because live timers hold the tree open. Run them under
> `timeout` and read the log — the shell will report the `timeout` kill (exit
> **124**, or **144** if it escalates), and that is the *passing* outcome. Grep
> the output for `CHECKS PASSED`; never trust the exit code here.
>
> ```bash
> timeout 150 godot --headless --path . scenes/test_milestone5.tscn > /tmp/m5.log 2>&1
> grep -E "CHECKS PASSED|FAILED" /tmp/m5.log
> ```

### Static check without the engine
Godot isn't always on `PATH`. This catches everything except GDScript compile errors —
missing `ext_resource` paths, frame counts that don't divide the sheet, broken
`upgrade_paths`, missing or stale render metrics, and faction prefixes leaking back into
`unit_name`:
`spritegen_lib` imports **numpy**, which is deliberately not a system dependency
of this repo, so a bare `python3` invocation fails with `ModuleNotFoundError`.
`uv` supplies it per-run:

```bash
uv run --quiet --with numpy --with pillow python scripts_dev/validate_project.py
# must report "0 error(s)"
```
It is **not** a substitute for the headless run. Run both.

---

## 🔄 4. How to Add New Signals to EventBus

If you create a new system that requires data exchange:
1. Open [`scripts/autoload/EventBus.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/EventBus.gd).
2. Add a new signal declaration with explicit data types:
   ```gdscript
   signal weather_changed(new_weather: String, penalty_multiplier: float)
   ```
3. Emit from the Logic Layer/Manager:
   ```gdscript
   EventBus.weather_changed.emit("rain", 0.8)
   ```
4. Listen in the relevant system (`GridManager`, `UI`, etc.):
   ```gdscript
   EventBus.weather_changed.connect(_on_weather_changed)
   ```

---

## 🧠 5. Coding Philosophy (ROBUST, DRY, KISS, YAGNI)

All code contributions and AI generations for this project must follow these principles:
*   **ROBUST**: Ensure code gracefully handles missing nodes or null instances (use `is_instance_valid()`). Headless testing must always return Exit Code 0 without errors.
*   **DRY (Don't Repeat Yourself)**: Avoid copy-pasting code or manual scene setups. Use inheritance, helper functions, or dynamic programmatic generation to keep the codebase clean.
*   **KISS (Keep It Simple, Stupid)**: Avoid over-engineering. Use Godot's built-in features (like `AStarGrid2D`) rather than reinventing the wheel.
*   **YAGNI (You Aren't Gonna Need It)**: Do not build features or architectural abstractions that are not explicitly required by the current milestone. Keep it lean.
