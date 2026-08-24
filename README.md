# War Perang Tactics

A turn-based tactical strategy game built in Godot 4.7. Features a Decoupled Data-Driven Architecture, multi-faction economy, and deep tactical combat.

> Inspired by *Ancient Empire 2*, *Symphony of War*, and *Heroes of Might and Magic: Olden Era*.

---

## 🎯 Key Features

- ♟️ **Grid-Based Tactical Movement**: Pathfinding based on `AStarGrid2D` with orthogonal range (4 directions), unit collision detection, impassable water terrain, and smooth movement animation via Tweening.
- 🗺️ **30x20 Battlefield**: Two rivers split the map into a west flank, a contested centre and an east flank, crossable only at four bridges. Five faction castle slots, 4 Gold Mines, 2 Iron Mines and 6 Villages to fight over — with a pan/zoom camera clamped to the map bounds.
- ⚔️ **Combat Advantage Triangle**: Tactical combat calculation (Melee > Ranged > Mage > Melee; Holy vs Undead 2.5x) featuring a Counter-Attack mechanic.
- 💰 **Macro-Economy & Logistics**: Multi-Faction resource management (**Gold**, **Iron**, and **Troop Capacity**) with passive income from captured mines (*Gold Mine*, *Iron Mine*, *Houses*).
- 🏰 **Recruitment Centers (Castles)**: Recruit troops directly from the castle to surrounding tiles, provided the faction has enough treasury and troop capacity.
- 🤖 **Autonomous Tactical Enemy AI**: The enemy faction (Red Legion) can automatically recruit troops, pursue strategic targets (mines & castles), hunt the nearest player units, and finish off low-HP units.
- 🎨 **Derived Per-Faction Art**: 66 spritesheets generated from their parent art — the garment palette is hue-rotated onto the faction hue (skin and linework preserved), then each promotion gets its own value/saturation treatment, rim light and marker. Every Tier-3 unit looks distinct from the Tier-2 it was promoted from, in all five faction colours.
- 🏛️ **Decoupled Architecture**: 4 separate layers (Data, Event, Logic, Actor) that communicate purely through a centralized signal hub in `EventBus.gd`.
- 📖 **OKF v0.2 Compliant**: All game design and technical documentation follows the *Open Knowledge Format* standard, with automated knowledge graph integration via Graphify.

---

## 🚀 Quick Start / How to Play

### Prerequisites:
- **Godot Engine 4.7+** (Can be run directly in the editor).

### Running the Playable Test Scene:
1. Clone or open this project folder in Godot Engine 4.7.
2. **First run only** — import the generated art: open the project in the editor once, or
   run `godot --headless --path . --import`. The 66 derived spritesheets under
   `assets/characters/generated/` have no `.import` files until Godot has seen them.
3. Open the scene: [`scenes/TestGridScene.tscn`](scenes/TestGridScene.tscn).
4. Press **`F6`** (Play Current Scene).

### Regenerating the derived art
```bash
python3 scripts_dev/generate_sprites.py   # derive the 66 spritesheets
python3 scripts_dev/wire_units.py         # wire them + bake sprite_scale/offset
python3 scripts_dev/validate_project.py   # static integrity check (must report 0 errors)
python3 scripts_dev/preview_map.py        # optional: render the map to PNG
python3 scripts_dev/preview_units.py      # optional: render the unit lineup to PNG
```

### 🎮 Game Controls:
| Button / Action | Function |
|---|---|
| **Left Click on Unit** | Selects a unit (Displays 🟦 **Blue Tiles** for movement range, 🟥 **Red Tiles** for attack range). |
| **Left Click on Blue Tile** | Orders the selected unit to move to that tile. |
| **Left Click on Enemy (Red)** | Attacks the enemy unit, triggering damage calculation and a potential counter-attack. |
| **Left Click on Your Castle** | Selects the active faction's castle. |
| **`[R]`** | Opens the Recruit popup at the selected castle (Tier 1–2 only). |
| **`[U]`** | Opens the Upgrade popup for the selected unit (Tier-3 is promotion-only; 2x Field Tax off-castle). |
| **`[SPACE]` (Spacebar)** | **End Turn** (opens a confirmation modal ➔ switches faction turn). |
| **`[ESC]`** | Closes a popup / deselects, or quits when nothing is selected. |
| **`[W][A][S][D]` / Arrows** | Pan the camera. |
| **Middle- or Right-Drag** | Drag the camera. Mouse at a screen edge also pans. |
| **Mouse Wheel** | Zoom (clamped 0.55x – 2.0x). |

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
- [ ] **Milestone 2**: Playable Prototype & Unit Expansion (Archer, Rogue, Wizzard, Priest, Vampire, Skeleton + Spritesheet Animations + In-Game Gemini Flash Lite AI).
- [ ] **Milestone 3**: Economy & Unit Upgrade Tree (Branching promotions, Field Tax 2x, Troop Capacity / Starvation, Village nodes).
- [ ] **Milestone 4**: Advanced Tactical Systems (Morale & Surrender, Forest Ambush, Fog of War, TNT Chain Explosions). *Battlefield, impassable terrain and the pan/zoom camera have landed already.*
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
├── scripts_dev/               # Offline pipelines (sprite derivation, metric baking, validation)
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
