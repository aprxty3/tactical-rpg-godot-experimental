---
type: Memory
title: "Project Memory & Architectural Context"
description: "Persistent context, architectural invariants, decisions, and system patterns for War Perang Tactics."
tags: [memory, architecture, context, invariants]
generated: { by: human:aprxty3, at: 2026-08-22T23:55:00Z }
---

# 🧠 Project Memory — War Perang Tactics

This document serves as the **Persistent Context (Eternal Memory)** for developers and AI Agents working in this repository. All core rules, architectural decisions, and conventions are documented here.

---

## 🏛️ Architectural Invariants

1. **Decoupled Data-Driven Pattern**:
   * **Pure Resources (Data Layer)**: Scripts in `scripts/data/` (e.g., `UnitData.gd`) MUST ONLY contain `@export` data variables. It is strictly forbidden to place runtime logic, signal emission, or node manipulation in Resources.
   * **EventBus as Single Source of Truth**: Nodes must not call `get_node("/root/...")` or hardcode paths to communicate with other managers. All cross-system communication is handled via signals in [`scripts/autoload/EventBus.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/EventBus.gd).
   * **Passive Actor Nodes (Actor Layer)**: `TacticalUnit.gd` and `Building.gd` only manipulate their own visual representation, read their data Resources, and emit events to the `EventBus`.
   * **Logic Managers (Logic Layer)**: Managers (`GridManager`, `CombatResolver`, `EconomyManager`, `AIManager`) process state and calculations, then broadcast the results via the `EventBus`.

2. **Autoload Standards (`project.godot`)**:
   * `EventBus` ➔ `*res://scripts/autoload/EventBus.gd`
   * `GameConfig` ➔ `*res://scripts/autoload/GameConfig.gd`
   * `TurnManager` ➔ `*res://scripts/autoload/TurnManager.gd`
   * `_mcp_game_helper` ➔ Autoload plugin godot_ai.

3. **Coordinate & Grid Standards**:
   * Standard Grid Size: 4-directional Orthogonal (`AStarGrid2D.DIAGONAL_MODE_NEVER`).
   * Standard Heuristic: `AStarGrid2D.HEURISTIC_MANHATTAN`.
   * Standard Cell Size: `Vector2i(64, 64)` pixels for 2D tactical gameplay.

4. **Multi-Faction Invariant**:
   * All economic and unit systems must support dynamic `faction_id`:
     * `0`: `BLUE_KINGDOM` (Default Player faction)
     * `1`: `RED_LEGION` (Default AI/Enemy faction)
     * `2`: `PURPLE_SYNDICATE`
     * `3`: `YELLOW_EMPIRE`
     * `4`: `BLACK_COVEN`
     * `99`: `NEUTRAL` (Neutral Buildings / Creatures)

5. **Coding Principles (ROBUST, DRY, KISS, YAGNI)**:
   * **ROBUST**: Fail gracefully, validate instances (`is_instance_valid`), and use headless tests to ensure no script errors.
   * **DRY**: No redundant code. Extract logic to helpers or dynamic generators instead of manual duplication.
   * **KISS**: Simple, understandable, and idiomatic Godot solutions.
   * **YAGNI**: Implement only what the current milestone demands.

---

## ⚖️ Key Formulas & Calculations

1. **Combat Damage Formula**:
   $$\text{Base Damage} = \max(1, \text{Attacker.ATK} - (\text{Defender.DEF} \times 0.5))$$
   $$\text{Final Damage} = \text{round}(\text{Base Damage} \times \text{Advantage Mult} \times \text{Terrain Mod} \times \text{Counter Mod})$$

2. **Combat Advantage Multipliers**:
   * **Advantage (1.5x)**: Melee > Ranged, Ranged > Mage, Mage > Melee, Infiltrator > Mage/Ranged.
   * **Disadvantage (0.7x)**: Ranged < Melee, Melee < Mage.
   * **Holy vs Undead (2.5x)**: Support/Priest > Undead/Skeleton/Vampire.

3. **Economy & Field Tax**:
   * Upgrading at a Castle: $100\%$ of the tier difference cost.
   * Upgrading outside a Castle (Field Tax): $200\%$ of the tier difference cost (`GameConfig.FIELD_TAX_MULTIPLIER = 2`).
   * Base Troop Capacity: $8$ TC + ($2$ TC per controlled Village).
   * Starvation Damage: $15$ True Damage per unit if the faction exceeds its troop capacity.

---

## 📌 Design Decisions History

| Date | Decision | Rationale |
|---|---|---|
| **2026-08-22** | Migration to Decoupled 4-Layer | Prevent spaghetti code and node path entanglement across managers. |
| **2026-08-22** | Use native `AStarGrid2D` | C++ level pathfinding performance in the engine is vastly superior to manual AStar in GDScript. |
| **2026-08-22** | Document Standardization to OKF v0.2 | Ensure all architecture and GDD documents are easily readable, queryable, and processed by LLMs/Graphify. |
| **2026-08-22** | Asynchronous Pacing for `AIManager` | AI is given a `0.4s` delay via `create_timer` so movement and attack actions can be naturally observed by the player. |
| **2026-08-23** | Tier-3 units are promotion-only, not Castle-recruitable | Makes the Milestone 3 "Unit Upgrade Tree" mean something mechanically — previously Knight/Lancer sat directly in `recruitable_units` alongside Tier-1/2 units, making the tree purely cosmetic. |
| **2026-08-23** | `Monk` (not `Priest`) is the canonical Tier-2 Holy unit | `Monk` already had full per-faction art on all 5 factions; the lone `priest_yellow.tres` was retiered into the Yellow `High Priest` (Tier-3) instead of duplicating a second Holy Tier-2 slot. |
| **2026-08-23** | Faction color for generic (non-recolored) sprites is a runtime shader tint, not new art | No image-generation tool is available in-session; `UnitData.needs_palette_tint` + `assets/shaders/faction_tint.gdshader` recolor Knight/Rogue/Wizzard and their Tier-3 offshoots per faction_id instead of requiring hand-painted variants. |
