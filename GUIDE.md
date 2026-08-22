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

### Step B: Create the Unit Prefab Scene (`.tscn`)
1. Create a scene inherited from `scenes/units/TacticalUnit.tscn` or create a new `Node2D` with the script `res://scripts/units/TacticalUnit.gd`.
2. Change the `Sprite2D` texture with the relevant unit sprite (e.g., `assets/characters/archer/Blue/Archer_Blue.png`).
3. Set `hframes` and `vframes` according to the spritesheet.
4. Attach the `archer_blue.tres` resource to the `@export var unit_data` slot.
5. Save the scene as `scenes/units/TacticalUnit_Archer_Blue.tscn`.

---

## 🏰 2. How to Add a New Building

To add a new building (e.g., **Iron Mine** or **Village**):

1. Create a new scene in `scenes/buildings/` with a `Node2D` root using the script [`scripts/buildings/Building.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/buildings/Building.gd).
2. In the Inspector, set:
   * `building_type`: Select the type (e.g., `IRON_MINE` or `HOUSE`).
   * `faction_id`: `99` (Neutral) or `0` (Blue).
3. Add a `Sprite2D` child node and attach the building sprite from `assets/buildings/`.
4. If you want the building to be able to recruit (Castle only):
   * Insert the unit Resource list into the `recruitable_units` array.

---

## 🧪 3. How to Run & Test Scenes

### Via Godot Editor:
1. Open the scene you want to test (e.g., [`scenes/TestGridScene.tscn`](scenes/TestGridScene.tscn)).
2. Press **`F6`** (Play Current Scene).

### Via Terminal (Headless Mode):
If you want to test scripts automatically without opening the graphical window:
```bash
godot --headless --path . scenes/TestGridScene.tscn --quit-after 50
```
If the return code is `0` and there are no red errors, it means the scene compiled and ran normally.

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
