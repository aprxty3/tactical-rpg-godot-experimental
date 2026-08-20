# Technical Architecture & Godot 4 System Design

This document specifies the scene tree architecture, GDScript components, event flow, and pathfinding design for **War Perang Tactics** in Godot 4.x.

---

## 1. Scene Tree Hierarchy

```text
Main.tscn (Node2D)
├── CameraController2D (Camera2D) -> Pan, Zoom, Screen Shake
├── Map (Node2D)
│   ├── TerrainTileMapLayer (TileMapLayer) -> Visual & Ground data
│   ├── FogOfWarTileMapLayer (TileMapLayer) -> Faction visibility
│   ├── GridOverlay (Node2D) -> Movement & Attack Range Highlights
│   ├── Objects (Node2D)
│   │   ├── Buildings/ (Castle, GoldMine, Tower, House)
│   │   └── Interactables/ (TNT, Barrels, Torches)
│   └── Units (Node2D)
│       ├── PlayerUnits/
│       └── EnemyUnits/
├── Managers (Node)
│   ├── TurnManager (Node) -> Phase state machine & AI turn execution
│   ├── GridManager (Node) -> Grid coordinate translation & AStarGrid2D
│   ├── EconomyManager (Node) -> Faction gold treasury & upkeep
│   └── CombatResolver (Node) -> Damage calculation & status triggers
└── CanvasLayer (UI_HUD)
    ├── TurnIndicator (Control)
    ├── ResourceBar (Control: Gold, Unit Cap)
    ├── UnitInspectorPanel (Control: Selected unit stats & portrait)
    └── ActionMenu (Control: Move, Attack, Skill, End Turn)
```

---

## 2. Core Managers & System Responsibilities

### A. `GridManager.gd` & `AStarGrid2D`
- Handles world position $\leftrightarrow$ grid coordinate transformations.
- Maintains cell occupancy maps (preventing unit stacking, tracking obstacles like `TNT` or `Mountains`).
- Utilizes Godot 4's built-in **`AStarGrid2D`** for shortest-path calculation and Dijkstra flood-fill for reachable tiles.

### B. `TurnManager.gd` (Phase State Machine)
- Coordinates player, enemy AI, and neutral phases (`PLAYER_TURN` $\rightarrow$ `ENEMY_AI_TURN` $\rightarrow$ `NEUTRAL_TURN`).
- Emits gameplay signals:
  - `signal turn_started(faction_id)`
  - `signal phase_changed(new_phase)`
  - `signal victory_condition_met(winner_faction)`

### C. `Unit.gd` & `UnitData.tres` (Data-Driven Architecture)
- Employs **Custom Resource** (`UnitData`) to decouple unit parameters from node scene logic:
```gdscript
# UnitData.gd
class_name UnitData extends Resource

@export var unit_name: String = "Warrior"
@export var faction: String = "Blue"
@export var max_health: int = 100
@export var attack_power: int = 25
@export var defense_power: int = 10
@export var movement_points: int = 3
@export var attack_range: Vector2i = Vector2i(1, 1) # min, max
@export var recruit_cost: int = 100
@export var sprite_frames: SpriteFrames
```

### D. `CombatResolver.gd`
- Damage formula:
$$\text{Final Damage} = \max\Big(1, \, (\text{Attacker ATK} \times \text{Advantage Mod}) - (\text{Defender DEF} \times \text{Terrain Mod})\Big)$$
- Manages special procs: *Lifesteal* (**Vampire**), *Holy Cleansing* (**Priest**), and *Chain Detonations* (**TNT**).

---

## 3. Node Communication (Signal & Event-Driven)

```
[ Unit / Player Input ] ──(request_move)──► [ GridManager ]
                                                  │
                                          (validate_path)
                                                  │
                                                  ▼
[ CombatResolver ] ◄──(trigger_attack)─── [ Unit Action ]
        │
 (emit damage_applied)
        │
        ▼
[ UI_HUD / FloatingNumbers ] & [ Unit AnimationPlayer ]
```

---

## 4. Related Documentation Links
- **Core Loop & Win Conditions**: See [[GDD_Overview]] for phase flow.
- **Unit Stats & Archetypes**: See [[Factions_and_Units]] for parameters configured via `UnitData.tres`.
- **Terrain Multipliers**: See [[Terrain_and_Buildings]] for defense and movement modifiers.
