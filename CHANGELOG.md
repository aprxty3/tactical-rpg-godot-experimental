---
type: Changelog
title: "War Perang Tactics — Daily Changelog"
description: "Comprehensive record of architectural restructuring, game systems implementation, and testing."
tags: [changelog, architecture, godot4, gameplay]
generated: { by: human:aprxty3, at: 2026-08-23T00:00:00Z }
---

# Changelog

All major changes to the **War Perang Tactics** project are recorded below.

---

## 📅 Summary of Today's Changes (2026-08-23)

### 1. 🌐 Language & Localization Standardization
- **English Translation**: Completely translated all documentation (`README.md`, `GUIDE.md`, `MEMORY.md`, `AGENTS.md`, `GEMINI.md`, `CHANGELOG.md`) and in-line code comments across all GDScript files from Indonesian to English.
- **AI Coding Philosophy**: Added strict enforcement of ROBUST, DRY, KISS, and YAGNI principles to all AI reference documents.
- **Roadmap Update**: Added the Unit Upgrade Tree and its branching logic to Milestone 3 in `Roadmap.md`.

### 2. 🧠 In-Game AI Narrative Engine (Gemini 3.7 Flash)
- **`GeminiClient.gd` Autoload**: Implemented a dynamic REST API client that interacts with Google's Gemini 3.7 Flash to generate dynamic, contextual dialogue for in-game combat and base captures.
- **Event-Driven Narrative**: Hooked into `EventBus.combat_resolved` and `building_captured` to broadcast `dialogue_generated` signals to the HUD.
- **Graceful Offline Fallback**: Safely defaults to offline hardcoded text if `GEMINI_API_KEY` is missing or rate-limited.

### 3. 🎭 Core Unit Archetypes & Animation System
- **Dynamic Animation Injector**: Upgraded `TacticalUnit.gd` to programmatically generate TinySwords-compliant animations (`idle`, `run`, `attack`) based on sprite dimensions, completely removing the need for manual track clicking and preventing out-of-bounds crashes.
- **Combat & Movement Animations**: `GridManager` and `CombatResolver` now natively call `play_animation("run")` and `play_animation("attack")` while handling sprite direction facing via `face_direction()`.
- **New Unit Data & Prefabs**: Generated accurate `UnitData.tres` and `TacticalUnit.tscn` prefabs for **Archer**, **Rogue**, **Wizzard**, **Priest**, **Skeleton**, and **Vampire**.

### 4. 🎮 Comprehensive UI, SFX & Victory Conditions (Milestone 2 Completed)
- **MainHUD (UI)**: Built a decoupled, responsive `MainHUD.tscn` (CanvasLayer) using `MarginContainer` and `PanelContainer` logic. Includes a Top Resource Bar, a Bottom-Left Unit/Building Inspector, and floating context action text.
- **Robust Victory Checks**: Upgraded `TurnManager.gd` to correctly calculate "Defeat by Castle Capture" and "Defeat by Annihilation" (0 units & 0 castles).
- **SFX Framework**: Created an `AudioManager.gd` autoload that seamlessly hooks into `EventBus` signals (`unit_move_completed`, `combat_resolved`, `victory_condition_met`). Generated procedural placeholder `.wav` assets for instant feedback.

### 5. 🩹 Dynamic Floating Health Bars & Combat Stat Rebalance
- **Overhead Health Bars**: Added dynamic, programmatic floating `ProgressBar` and `Label` to `TacticalUnit.gd` with smooth tweening and real-time color gradient indicators (Green > 50%, Amber 25-50%, Sekarat/Low Red <= 25%).
- **Combat Rebalancing**: Rebalanced unit stats across all unit `.tres` resources. Scaled Worker Pawn from 100 HP down to 45 HP (DEF 4) and Warrior to 75 HP (DEF 8), transforming combat from a 7-10 turn sponge slog into snappy, decisive 2-3 engagement tactics.
- **Bug Fixes**: Fixed `MainHUD.gd` property bindings (`attack_power` and `defense_power`), cleaned unused signal parameter warnings, and formatted recruit popup buttons with live cost displays.

### 6. 🏹 Dynamic Recruitment Spritesheet Injection & Combat Symmetry Fix
- **Dynamic Visual Binding**: Added `spritesheet`, `hframes`, and `vframes` exports to `UnitData.gd`. Upgraded `TacticalUnit.gd`'s `_update_visuals()` to dynamically hot-swap sprite textures and reconstruct TinySwords animation tracks on runtime instantiation.
- **Recruitment Prefab Resolution**: Fixed castle recruitment in `Building.gd` so recruited Archers, Warriors, Rogues, Mages, etc., properly render their distinct spritesheets instead of defaulting to the generic Pawn sprite.
- **Combat Symmetry & Resource Expansion**: Created `pawn_red.tres` and `warrior_blue.tres`, populated both Blue and Red castles with distinct recruitable rosters, and resolved the apparent "Pawn vs Pawn" damage imbalance (which occurred because enemy Red Warriors were previously displaying Pawn sprites while dealing Melee Advantage damage).

### 7. 🔄 TurnManager API Clean-up & Private Access Fix
- **Public `end_turn()` API**: Added a dedicated public `end_turn()` method to `TurnManager.gd` that cleanly handles transitioning to `END_TURN` and advancing to the next faction.
- **Private Access Warning Resolution**: Replaced direct external calls to private `TurnManager._end_current_turn()` in `AIManager.gd` and `TestGridController.gd` with `TurnManager.end_turn()`, resolving the `[private-access]` GDScript warning.

### 8. 🗂️ Asset Directory Restructuring, Archer Animation Fix & 5-Faction Unit Expansion
- **Asset Cleanliness & Reorganization**: Restructured the messy 24-folder `/assets` directory into 9 clean, intuitive categories: `audio/`, `buildings/`, `characters/`, `decorations/`, `effects/`, `items/`, `legacy/`, `terrain/`, and `ui/`. Automatically migrated and updated all path references across all `.tscn`, `.tres`, `.gd`, and `.import` files with zero broken links.
- **Archer Animation Resolution**: Fixed TinySwords Archer slicing bug by configuring correct dimensions (`1536x1344` $\rightarrow$ `hframes = 8, vframes = 7`). Upgraded `TacticalUnit.gd`'s animation generator to automatically map Row 3 (8 frames) for Archer attacks.
- **Complete 5-Faction Unit Rosters & Scene Prefabs**: Generated and verified **38 unit resources** (`.tres`), **45 unit scenes** (`.tscn`), and all **5 Faction Castle Prefabs** (`scenes/buildings/Castle*.tscn`) covering all lineages and color variants across all 5 factions with complete symmetry:
  - 🔵 **Blue Kingdom**: Blue Pawn, Blue Warrior, Blue Archer, Blue Knight, Blue Lancer, Blue Monk. (Castle_Blue)
  - 🔴 **Red Legion**: Red Pawn, Red Warrior, Red Archer, Red Knight, Red Lancer, Red Monk. (Castle_Red)
  - 🟡 **Yellow Empire**: Yellow Pawn, Yellow Warrior, Yellow Archer, Yellow Knight, Yellow Lancer, Yellow Monk, Yellow Priest, Yellow Wizzard. (Castle_Yellow)
  - 🟣 **Purple Syndicate**: Purple Pawn, Purple Warrior, Purple Archer, Purple Knight, Purple Lancer, Purple Monk, Purple Rogue. (Castle_Purple)
  - ⚫ **Black Coven / Necropolis**: Black Cultist Pawn, Black Guard Warrior, Black Archer, Death Lancer, Necromancer Monk, Skeleton Fodder (Base), Skeleton Warrior, Skeleton Mage, Skeleton Rogue, Cursed Skull, Vampire. (Castle_Black)
- **Comprehensive Headless Verification**: Automated multi-unit assertion test (`TestAllUnits.gd`) validating spritesheet textures, frame dimensions, and animation libraries across all 38 unit resources with 100% pass rate.


### 9. 🛑 End Turn Confirmation Modal & Lush 16x10 Battlefield Map Generation
- **End Turn Confirmation Modal**: Built a responsive, centered confirmation modal in `MainHUD.tscn` with a darkened backdrop (`Color(0,0,0,0.6)`). Prompts the player with *"End Your Turn?"* and Yes/No buttons. Pressing `[SPACE]` opens the modal; pressing `[SPACE]` again or clicking *"Yes"* confirms and ends the turn; pressing `[ESC]` or clicking *"No"* closes the modal safely without passing the turn.
- **Dynamic 16x10 Tactical Battlefield**: Added `_setup_tactical_tilemap()` in `TestGridController.gd` to completely fill the 16x10 grid with grass tiles, dirt pathways connecting Blue Castle, Neutral Gold Mine, and Red Castle, as well as natural flower/grass detail patches. Removed empty black void areas.
- **Automated Test Validation**: Added `scenes/test_popup_and_map.tscn` confirming 100% grid cell population (160 tiles) and modal state transitions with Exit Code 0.


### 10. ⚔️ In-Depth Combat Mechanics, Class Fighting Styles & Combat VFX
- **Class Fighting Styles & Special Traits**:
  - 🩸 **Vampire Lifesteal**: Recovers health ($+40\%$ of damage dealt) upon attacking.
  - ✨ **Mage Armor-Piercing**: Magical damage ignores $75\%$ of physical defense (`DEF * 0.12`), effectively countering heavily armored units.
  - 🛡️ **Knight Heavy Armor**: Endures physical damage with $-25\%$ flat physical damage reduction.
  - 🐎 **Cavalry Momentum Charge**: Devastating $+25\%$ damage bonus when initiating attacks against enemies.
  - 🗡️ **Infiltrator Backstab**: $+50\%$ critical backstab damage against targets.
  - ✝️ **Holy Smite**: Support/Monk/Priest units inflict $2.5\times$ Holy damage against Undead targets.
  - 🏹 **Ranged Advantage**: Attacks from $2\text{--}3$ tiles away prevent defender from executing melee counter-attacks.
- **Combat Visuals & Animation Polish**:
  - Dynamic floating damage text (`-X` in red, `+X` in green) with pop and float tween animations in `TacticalUnit.gd`.
  - Sprite flash effect (`_flash_damage()`) on taking damage.
  - Smooth death dissolve and fade-out animation before removal.
- **Automated Test Validation**: Added `scenes/test_combat_mechanics.tscn` verifying all 6 combat traits and calculations with 100% pass rate.


---

## 📅 2026-08-22

### 1. 🏗️ Architecture & System Foundation (Decoupled Data-Driven)
- **4-Layer Architecture**: Changed the project architecture from a monolithic/tightly-coupled design to a separated 4-layer architecture:
  1. **Data Layer**: Pure `.tres` Resources without logic (`UnitData.gd`).
  2. **Event Layer**: Centralized signal hub Autoload (`EventBus.gd`).
  3. **Logic Layer**: Game rule managers (`TurnManager`, `EconomyManager`, `GridManager`, `CombatResolver`, `AIManager`).
  4. **Actor Layer**: Visual nodes on the map (`TacticalUnit`, `Building`).
- **Global Autoloads**:
  - [`scripts/autoload/EventBus.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/EventBus.gd) — Central typed signal hub with warning-free annotations.
  - [`scripts/autoload/GameConfig.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/GameConfig.gd) — Global Enums (`Faction`, `Phase`, `UnitClass`, `DamageType`, `MoraleLevel`) and calculation constants.
  - [`scripts/autoload/TurnManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/TurnManager.gd) — 4-phase turn state machine (`UPKEEP` ➔ `PRODUCTION` ➔ `ACTION` ➔ `END_TURN`).
- **Data Model & Actor Refactor**:
  - [`scripts/data/UnitData.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/data/UnitData.gd) — Custom Resource for stats, Gold/Iron recruitment costs, and Troop Capacity weights.
  - [`scripts/units/TacticalUnit.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/units/TacticalUnit.gd) — Actor node with movement & action consumption system, damage handling, and upgrades.

### 2. 🗺️ Grid System, Pathfinding & Movement
- **GridManager ([`scripts/managers/GridManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/GridManager.gd))**:
  - Configured Godot 4.7's native `AStarGrid2D` with orthogonal mode (4 directions).
  - Two-way coordinate conversion: `world_to_grid()` and `grid_to_world()`.
  - Movement range calculation using the **BFS (Flood Fill)** algorithm capped by `movement_points`.
  - Attack range calculation using **Manhattan Distance** (`attack_range_min` to `attack_range_max`).
  - Smooth unit movement animation using sequential `Tween` between tiles.
  - Detection and auto-capture of buildings when a unit reaches its destination tile.

### 3. ⚔️ Combat & Tactical System (Combat Advantage)
- **CombatResolver ([`scripts/managers/CombatResolver.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/CombatResolver.gd))**:
  - Base Damage Formula: `max(1, ATK - (DEF * 0.5))`.
  - **Combat Advantage Triangle**: Multipliers 1.5x (Advantage), 0.7x (Disadvantage), 2.5x (Holy vs Undead).
  - **Counter-Attack**: Defending enemies automatically retaliate if they survive and the attacker is within their attack range.

### 4. 💰 Economy, Buildings & Recruitment System
- **EconomyManager ([`scripts/managers/EconomyManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/EconomyManager.gd))**:
  - Multi-faction treasury management (Gold, Iron, Troop Capacity).
  - Field Tax calculation when upgrading outside a castle (200% cost).
  - Starvation / Logistics Collapse system if unit count exceeds troop capacity.
- **Building System ([`scripts/buildings/Building.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/buildings/Building.gd))**:
  - 5 Building Types: Castle, Gold Mine, Iron Mine, House/Village, Tower.
  - Passive income generators: Gold Mine (+50 Gold/turn), Iron Mine (+30 Iron/turn), House (+10 Gold & +2 TC).
  - Recruitment at Castle (`[R]`): Validates Gold, Iron, and TC, then instantiates units on empty tiles around the castle.

### 5. 🤖 NPC / Enemy Tactical AI
- **AIManager ([`scripts/managers/AIManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/AIManager.gd))**:
  - Full automation for the Red Legion's turn (`Faction.RED_LEGION`).
  - Recruits new troops at the Red Castle if the faction treasury allows.
  - Selects strategic targets: capturing the nearest gold mine or hunting player units.
  - Finisher logic: prioritizes attacking the unit with the lowest remaining HP.
  - Natural animation pacing (0.4s delay per action) and automatically ends the AI turn.

### 6. 🎮 Playable Interactive Testbed
- [`scenes/TestGridScene.tscn`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scenes/TestGridScene.tscn) & [`scripts/test/TestGridController.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/test/TestGridController.gd):
  - Visual Grid Overlay: Blue (Walkable Area), Red (Attackable Area), Yellow (Active Unit), Green (Active Castle).
  - Live HUD Header: Displays Gold, Iron, Troop Capacity, and realtime Combat reports.
  - Hotkeys: `[ESC]` quit, `[SPACE]` switch turn / End Turn, `[R]` recruit unit at Castle.

### 7. 📚 OKF (Open Knowledge Format) Documentation Standardization
- All documents in `docs/` have been reorganized and equipped with OKF v0.2 frontmatter:
  - `GDD_Overview.md`, `Macro_Economy.md`, `Technical_Specs.md`, `Architecture.md`, `Factions_and_Units.md`, `Terrain_and_Buildings.md`, `Roadmap.md`, and `index.md`.
- Automated **Git Hooks** integration (`graphify hook install`).
- `/graphify update` synchronization generated **25 nodes, 16 edges, 11 communities**.
