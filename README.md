# War Perang Tactics

A turn-based tactical strategy game built in Godot 4.7. Features a Decoupled Data-Driven Architecture, multi-faction economy, and deep tactical combat.

> Inspired by *Ancient Empire 2*, *Symphony of War*, and *Heroes of Might and Magic: Olden Era*.

---

## 🎯 Key Features

- ♟️ **Grid-Based Tactical Movement**: Pathfinding based on `AStarGrid2D` with orthogonal range (4 directions), unit collision detection, and smooth movement animation via Tweening.
- ⚔️ **Combat Advantage Triangle**: Tactical combat calculation (Melee > Ranged > Mage > Melee; Holy vs Undead 2.5x) featuring a Counter-Attack mechanic.
- 💰 **Macro-Economy & Logistics**: Multi-Faction resource management (**Gold**, **Iron**, and **Troop Capacity**) with passive income from captured mines (*Gold Mine*, *Iron Mine*, *Houses*).
- 🏰 **Recruitment Centers (Castles)**: Recruit troops directly from the castle to surrounding tiles, provided the faction has enough treasury and troop capacity.
- 🤖 **Autonomous Tactical Enemy AI**: The enemy faction (Red Legion) can automatically recruit troops, pursue strategic targets (mines & castles), hunt the nearest player units, and finish off low-HP units.
- 🏛️ **Decoupled Architecture**: 4 separate layers (Data, Event, Logic, Actor) that communicate purely through a centralized signal hub in `EventBus.gd`.
- 📖 **OKF v0.2 Compliant**: All game design and technical documentation follows the *Open Knowledge Format* standard, with automated knowledge graph integration via Graphify.

---

## 🚀 Quick Start / How to Play

### Prerequisites:
- **Godot Engine 4.7+** (Can be run directly in the editor).

### Running the Playable Test Scene:
1. Clone or open this project folder in Godot Engine 4.7.
2. Open the scene: [`scenes/TestGridScene.tscn`](scenes/TestGridScene.tscn).
3. Press **`F6`** (Play Current Scene).

### 🎮 Game Controls:
| Button / Action | Function |
|---|---|
| **Left Click on Unit** | Selects a unit (Displays 🟦 **Blue Tiles** for movement range, 🟥 **Red Tiles** for attack range). |
| **Left Click on Blue Tile** | Orders the selected unit to move to that tile. |
| **Left Click on Enemy (Red)** | Attacks the enemy unit, triggering damage calculation and a potential counter-attack. |
| **Left Click on Your Castle** | Selects the active faction's castle. |
| **`[R]`** | Recruits a new unit (**Blue Pawn**) around the selected castle (Cost: 50 Gold, 1 Iron). |
| **`[SPACE]` (Spacebar)** | **End Turn** (Switches faction turn ➔ Starts enemy AI turn / Upkeep phase). |
| **`[ESC]`** | Quits the game immediately. |

---

## 🏗️ Architecture Structure (4-Layer Pattern)

```text
┌─────────────────────────────────────────────────────────┐
│                    1. DATA LAYER                        │
│   UnitData.tres  TerrainData.tres  BuildingData.tres    │
│   (Resources — Pure Data Containers, No Logic)          │
└──────────────────────┬──────────────────────────────────┘
                       │ read by
┌──────────────────────▼──────────────────────────────────┐
│                    2. ACTOR LAYER                       │
│   TacticalUnit.gd  Building.gd  MapObject.gd            │
│   (Node2D — Visual, Input, Sprite, Animation)           │
└──────────┬────────────────────────────┬─────────────────┘
           │ emit signals               │ emit signals
┌──────────▼────────────────────────────▼─────────────────┐
│                    3. EVENT LAYER                       │
│                   EventBus.gd                           │
│   (Autoload Singleton — Central Typed Signal Hub)       │
└──────────┬────────────────────────────┬─────────────────┘
           │ listened by                │ listened by
┌──────────▼────────────────────────────▼─────────────────┐
│                    4. LOGIC LAYER                       │
│   TurnManager  EconomyManager  CombatResolver  AIManager │
│   (Managers — Game Rules, State Machines, Calculations) │
└─────────────────────────────────────────────────────────┘
```

---

## 🧠 Coding Philosophy
This project strictly enforces the **ROBUST**, **DRY**, **KISS**, and **YAGNI** principles:
- **ROBUST**: Fail gracefully, use explicit typing, and ensure zero headless script errors.
- **DRY (Don't Repeat Yourself)**: Eliminate redundancy (e.g., dynamic programmatic generation over manual duplication).
- **KISS (Keep It Simple, Stupid)**: Use built-in Godot features; avoid over-engineering.
- **YAGNI (You Aren't Gonna Need It)**: Do not build features or abstractions before they are required by the current milestone.

---

## 🗺️ Detailed Roadmap & Milestones

- [x] **Milestone 1**: Core Foundation (Decoupled Data-Driven Architecture, EventBus, TurnManager, GridManager, CombatResolver, EconomyManager, Building & Basic AI).
- [ ] **Milestone 2**: Playable Prototype & Unit Expansion (Archer, Rogue, Wizzard, Priest, Vampire, Skeleton + Spritesheet Animations + In-Game Gemini 3.7 Flash AI).
- [ ] **Milestone 3**: Economy & Unit Upgrade Tree (Branching promotions, Field Tax 2x, Troop Capacity / Starvation, Village nodes).
- [ ] **Milestone 4**: Advanced Tactical Systems (Morale & Surrender, Forest Ambush, Fog of War, TNT Chain Explosions).
- [ ] **Milestone 5**: Full Campaign, Advanced AI, UI Theme/HUD overhaul, SFX/BGM pipeline.
*(For the complete design specifications and full ASCII trees, see [`docs/Roadmap.md`](docs/Roadmap.md))*

---

## 📁 Project Folder Structure

```text
war-perang-tactics/
├── assets/                    # Sprite, Audio, Tileset, Character Animations
├── docs/                      # GDD & Architecture Documentation (OKF v0.2)
├── graphify-out/              # Knowledge Graph report & visualizer
├── resources/                 # Resource files (.tres)
├── scenes/                    # Main prefabs and scenes
├── scripts/                   # GDScript source code
├── CHANGELOG.md               # Release notes & change history
├── GUIDE.md                   # Developer guide & system expansion
├── MEMORY.md                  # Architectural context & invariant rules
├── DISTRIBUTED.md             # Decoupling pattern & distributed architecture
├── GEMINI.md                  # AI workflow guidelines & agent instructions
├── AGENTS.md                  # LLM agent operational standards
└── project.godot              # Godot 4.7 Engine Configuration
```

---

## 📜 License & Attribution
Created for an independent tactical game development project. Asset pack utilizes Tiny Swords & Pixel RPG Pack with custom script modifications.
