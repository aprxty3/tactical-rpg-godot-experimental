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

The game boots from a menu, not from the board. Three scenes hand off through
the `MatchSetup` autoload, which is the only thing that survives
`change_scene_to_file()`:

```text
MainMenu.tscn  ──►  FactionSelect.tscn  ──►  Match.tscn
   (Backdrop = a live MapBuilder board, no units, no HUD)
```

`Match.tscn` is flat on purpose. Managers are siblings rather than a `Managers/`
branch, because `MatchController` injects every dependency by hand in `_ready()`
and a nesting level would only add a path to get wrong:

```text
Match.tscn (Node2D)  ── scripts/game/MatchController.gd
├── GridManager            AStarGrid2D pathing, occupancy, terrain cost
├── CombatResolver         the ONLY place damage is computed
├── EconomyManager         gold, iron, troop capacity per faction
├── MapBuilder             procedural terrain + decor scatter
├── TileMapLayer_Water / _Ground / _Path / _Bridge
├── Decor                  trees and props — no collision, no grid presence
├── Buildings              5 castles, 4 gold mines, 4 iron mines, 8 villages
├── Units                  every TacticalUnit, all factions
├── Camera2D               TacticalCamera — pan, zoom, shake (via `offset`)
├── MainHUD (CanvasLayer)  resources, turn banner, popups, game-over modal
├── MoraleManager          desertion and surrender
├── VisionManager          fog of war, explored vs visible
├── MapObjectManager       chests, traps, kegs, fire
├── MapObjects             the objects themselves
├── VfxManager             pure EventBus consumer — omit it and nothing breaks
├── Vfx                    spawned effects live here
└── FogOfWarTileMapLayer
```

Three collaborators are **not** in the scene — `MatchController` constructs them:

- `AIManager` — one instance **per AI faction**, each with its own seeded RNG
- `EncounterManager` — the Black Castle's garrison; takes a turn, cannot win
- `GridOverlay` — movement and attack range highlights

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

Five god nodes were split into ten collaborators so their decisions could be
tested without running a turn. The rule that drove the split: **anything that
decides something should be reachable without a scene.**

| Node | Kind | Responsibility |
| :--- | :--- | :--- |
| `GridManager` | Node | World ↔ cell transforms, occupancy, `AStarGrid2D` paths, Dijkstra reachability at real terrain cost |
| `MapBuilder` | Node | Builds terrain from a seed; returns the blocked-cell set and terrain map |
| `ResourceScatter` | RefCounted | Places mines, villages, chests, traps and kegs from that same seed, fairly per faction |
| `CombatResolver` | Node | The one damage formula. `preview_damage()` is public so the AI asks the same code real combat uses |
| `EconomyManager` | Node | Gold, iron, troop capacity, starvation. Owns the village/castle capacity ledger |
| `TurnManager` | **Autoload** | Turn order, upkeep, garrison healing, victory latch. Splits `contenders` (can win) from `faction_order` (takes a turn) |
| `AIManager` | RefCounted | Orchestrates one faction's turn — one instance per AI army |
| `AITacticalEvaluator` | RefCounted | All AI *scoring*. No node, no signals, no state beyond injected managers |
| `EncounterManager` | RefCounted | The Black Castle garrison: leashed monsters that raid rather than conquer |
| `MoraleManager` | Node | Morale drift, desertion, surrender offers |
| `VisionManager` | Node | Per-faction fog with explored-vs-visible states |
| `MapObjectManager` | Node | Chests, traps, kegs, fire spread and chain detonation |
| `VfxManager` | Node | Pure `EventBus` consumer. Nothing references it, so a scene can omit it entirely |
| `UnitOverlay` | Node2D | The HP bar / morale strip / floating text above a unit, split out of `TacticalUnit` |

### The two autoloads that are easy to confuse

- **`GameConfig`** — the game's fixed rules. Terrain tables, combat multipliers,
  morale thresholds, AI weights, capacity constants. Never changes at runtime.
- **`MatchSetup`** — what the player picked for *this* match. Participants,
  player faction, marauders, map seed. Changes every match, survives scene loads.

### `UnitData.tres` — the Data Layer blueprint

```gdscript
class_name UnitData extends Resource

@export_group("Identity")
@export var unit_name: String = "Pawn"
@export var unit_class: String = "Worker"   # drives the advantage triangle
@export var tier: int = 1

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

@export_group("Vision & Morale")
@export var vision_range: int = 0

@export_group("Visuals")
@export var spritesheet: Texture2D          # a derived 6x6 (or 6x2) sheet
@export var hframes: int = 6
@export var vframes: int = 6
@export var sprite_scale: float = 1.0       # baked offline, never tuned by hand
@export var sprite_offset: Vector2 = Vector2.ZERO

@export_group("Directional Art (optional)")
@export var directional_attack: Dictionary = {}

@export_group("Mount (optional)")
@export var mount_profile: Resource
```

**Every optional field defaults to the absent case.** `directional_attack = {}`
and `mount_profile = null` reproduce the previous behaviour exactly, which is why
86 of the then-91 unit resources needed no migration when the mount system
landed. Any future optional field should follow the same rule: make the absent
case indistinguishable from before, then opt in only what needs it.

`UnitData.variant_for_faction(data, faction_id)` resolves a resource to the
owning faction's colour by filename suffix, **falling back to the original when
no variant exists**. That fallback is load-bearing rather than defensive — it is
what makes capturing the Black Castle hand you the undead roster, since no
`skeleton_fodder_blue.tres` exists to swap in.

### `CombatResolver.gd`

Damage is computed in exactly one place:

$$\text{Damage} = \max\Big(1,\ (\text{ATK} \times \text{advantage} \times \text{morale}) - \text{DEF}\Big) \times \text{terrain damage-taken multiplier}$$

`preview_damage(attacker, defender)` exposes it publicly. The AI calls it rather
than reimplementing it, which is why class advantage, terrain, morale and traits
can never drift between what the AI expects and what actually happens.

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
