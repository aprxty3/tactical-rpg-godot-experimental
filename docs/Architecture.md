---
type: Architecture Document
title: "System Architecture & Godot 4 Design"
description: "Scene tree hierarchy, decoupled data-driven architecture, manager responsibilities, and signal flow for War Perang Tactics."
tags: [architecture, godot, scene-tree, managers, signals]
generated: { by: human:aprxty3, at: 2026-08-22T00:00:00Z }
---

# Technical Architecture & Godot 4 System Design

This document specifies the scene tree architecture, GDScript components, event flow, and pathfinding design for **War Perang Tactics** in Godot 4.x.

---

## 1. Scene Tree Hierarchy

```text
Main.tscn (Node2D)
├── CameraController2D (Camera2D)
├── Map (Node2D)
│   ├── TerrainTileMapLayer (TileMapLayer)
│   ├── FogOfWarTileMapLayer (TileMapLayer)
│   ├── GridOverlay (Node2D)
│   ├── Objects (Node2D)
│   │   ├── Buildings/ (Castle, GoldMine, Tower, House)
│   │   └── Interactables/ (TNT, Barrels, Torches)
│   └── Units (Node2D)
│       ├── PlayerUnits/
│       └── EnemyUnits/
├── Managers (Node)
│   ├── GridManager (Node)
│   ├── EconomyManager (Node)
│   └── CombatResolver (Node)
└── CanvasLayer (UI_HUD)
    ├── TurnIndicator (Control)
    ├── ResourceBar (Control: Gold, Iron, Unit Cap)
    ├── UnitInspectorPanel (Control)
    └── ActionMenu (Control)
```

---

## 2. Decoupled Data-Driven Architecture

The game utilizes a 4-layer architecture pattern to cleanly separate data, logic, communication, and visual representation:

- **Data Layer** — `UnitData` Resource files (.tres) — pure data, no logic
- **Event Layer** — `EventBus.gd` autoload — central typed signal hub for decoupled communication
- **Logic Layer** — Manager nodes (EconomyManager, TurnManager, CombatResolver, GridManager) — react to and emit signals
- **Actor Layer** — `TacticalUnit` Node2D — visual representation + interaction, delegates to data

```
┌─────────────────────────────────────────────────────────┐
│                    DATA LAYER                           │
│   UnitData.tres  TerrainData.tres  FactionData.tres     │
│   (Resources — pure data containers, no logic)          │
└──────────────────────┬──────────────────────────────────┘
                       │ read by
┌──────────────────────▼──────────────────────────────────┐
│                    ACTOR LAYER                          │
│   TacticalUnit.gd  Building.gd  MapObject.gd           │
│   (Node2D — visuals, input, animation)                  │
└──────────┬────────────────────────────┬─────────────────┘
           │ emit signals               │ emit signals
┌──────────▼────────────────────────────▼─────────────────┐
│                    EVENT LAYER                          │
│                   EventBus.gd                           │
│   (Autoload — typed signal hub, no logic)               │
└──────────┬────────────────────────────┬─────────────────┘
           │ listened by                │ listened by
┌──────────▼────────────────────────────▼─────────────────┐
│                    LOGIC LAYER                          │
│   TurnManager  EconomyManager  CombatResolver  GridMgr  │
│   (Managers — game rules, state machines, calculations)  │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Core Managers & System Responsibilities

### A. `GridManager.gd` & `AStarGrid2D`
- Handles world position $\leftrightarrow$ grid coordinate transformations.
- Maintains cell occupancy maps (preventing unit stacking, tracking obstacles like `TNT` or `Mountains`).
- Utilizes Godot 4's built-in **`AStarGrid2D`** for shortest-path calculation and Dijkstra flood-fill for reachable tiles.

### B. `TurnManager.gd` (Phase State Machine)
- Coordinates player, enemy AI, and neutral phases (`PLAYER_TURN` $\rightarrow$ `ENEMY_AI_TURN` $\rightarrow$ `NEUTRAL_TURN`).
- Emits gameplay signals via EventBus.

### C. `UnitData.tres` (Data Layer Blueprint)
Employs custom resources to decouple unit parameters from node scene logic:
```gdscript
class_name UnitData extends Resource

@export_group("Identity")
@export var unit_name: String = "Pawn"
@export var unit_class: String = "Worker"
@export var tier: int = 1
@export var description: String = ""

@export_group("Combat Stats")
@export var max_health: int = 100
@export var attack_power: int = 25
@export var defense_power: int = 10
@export var movement_points: int = 3
@export var attack_range_min: int = 1
@export var attack_range_max: int = 1

@export_group("Economy & Logistics")
@export var recruit_cost_gold: int = 50
@export var recruit_cost_iron: int = 1
@export var capacity_weight: int = 1

@export_group("Progression")
@export var upgrade_paths: Dictionary = {}

@export_group("Visuals")
@export var sprite_frames: SpriteFrames
@export var portrait: Texture2D
```

### D. `CombatResolver.gd`
- Damage formula:
$$\text{Final Damage} = \max\Big(1, \, (\text{Attacker ATK} \times \text{Advantage Mod}) - (\text{Defender DEF} \times \text{Terrain Mod})\Big)$$
- Manages special procs: *Lifesteal* (**Vampire**), *Holy Cleansing* (**Priest**), and *Chain Detonations* (**TNT**).

---

## 4. Node Communication (Signal & Event-Driven)

```
[ TacticalUnit ] ──(EventBus.unit_action_requested)──► [ GridManager ]
                                                           │
                                                   (validate & execute)
                                                           │
                                                           ▼
[ CombatResolver ] ◄──(EventBus.combat_started)─── [ GridManager ]
        │
  (EventBus.combat_resolved)
        │
        ▼
[ UI_HUD ] & [ TacticalUnit.AnimationPlayer ]
```

---

## 5. Related Documentation Links
- **Economy, Upgrades & Map Systems**: See [[Technical_Specs]] for field tax and node details.
