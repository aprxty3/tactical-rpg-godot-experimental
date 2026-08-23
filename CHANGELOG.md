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


### 11. 🎯 High-Visibility Tactical Grid Highlights & Z-Index Elevation
- **Z-Index Layer Elevation**: Set `z_index = 2` for the grid drawing layer in `TestGridController.gd`. ~~Completely resolved~~ *(Correction: this alone did NOT fix it — see entry #12 below.)*
- **Vibrant Tactical Highlights**:
  - 🔵 **Reachable Move Cells**: High-contrast vibrant cyan-blue fill (`Color(0.12, 0.58, 1.0, 0.42)`) with glowing cyan borders and center pathing dot markers.
  - 🔴 **Attackable Cells**: High-contrast hazard crimson fill (`Color(1.0, 0.15, 0.15, 0.48)`) with bold red borders and precision crosshair reticle markers.
  - 🟡 **Selected Unit**: Golden pulse fill with bold double golden border (`Color(1.0, 0.92, 0.2, 1.0)`).
  - 🟢 **Selected Building**: Emerald green fill with glowing borders.
  - ◽ **Dynamic Cursor Hover**: Crisp white corner bracket highlights tracking the player's mouse over grid cells.


### 12. 🩹 Grid Highlight Occlusion — Actual Root-Cause Fix & Move-Completed Signal Crash
- **Root Cause Found**: The `z_index = 2` from entry #11 did nothing, because `TileMapLayer` is a **child** of the same node (`TestGridScene`) whose `_draw()` paints the highlights. With `z_as_relative` defaulting to `true`, the child's effective z-index rises together with its parent's, keeping them tied — and tied `CanvasItem`s paint in scene-tree order, so the child (`TileMapLayer`) always painted after (i.e. visually on top of) the parent's own `_draw()` output, regardless of the parent's `z_index` value.
- **Actual Fix**: Set `TileMapLayer.z_index = -1` (in `TestGridScene.tscn`) so terrain now has a strictly lower effective z-index than the root's highlight draw and its sibling `Units`/`Buildings`. Removed the now-inert `z_index = 2` line and replaced the misleading comment in `TestGridController.gd`.
- **Signal Signature Crash Fixed**: `EventBus.unit_move_completed(unit, from_cell, to_cell)` (3 args, emitted from `GridManager.gd:301`) was connected to `TestGridController._on_unit_move_completed(unit)` (1 arg) — every unit move threw `Method expected 1 argument(s), but called with 3` and silently skipped the handler body, which meant the player unit was never auto-reselected (and its highlights never redrawn) after finishing a move. Fixed the handler signature to accept all 3 arguments.
- **Noted, not fixed**: `CombatResolver.gd:73`'s post-attack idle timer can log a benign `Lambda capture ... was freed` error if a unit is freed within the 0.6s window after combat; low priority, does not affect gameplay correctness.


### 13. 🌳 Milestone 3 Foundation — Unit Upgrade Tree, Palette-Tint Shader & Roster Symmetry
- **Tier Data Fix**: `Warrior` was incorrectly tagged `tier = 1` (same as Pawn) despite being a clear power step up; corrected to `tier = 2` across all 5 factions.
- **Roster Symmetry**: Blue, Red, Purple, Yellow, and Black now all field the full Tier-2 roster (Warrior/Archer/Wizzard/Monk/Rogue) — previously only Purple had Rogue and only Yellow had Wizzard+Priest. Generated via a one-off script (`scripts_dev/generate_units.py`) per this project's own DRY principle rather than hand-authoring ~48 near-duplicate `.tres` files.
- **8 New Tier-3 Promotions** (×5 factions = 40 new units): Sniper & Crossbowman (from Archer), Archmage & Elementalist (from Wizzard), High Priest & Paladin (from Monk), Assassin & Shadowblade (from Rogue). Existing Knight/Lancer (from Warrior) folded into the same tree as-is.
- **`Priest` → `High Priest`**: The single existing `priest_yellow.tres` was retiered (2→3) and restatted into the Yellow High Priest, since `Monk` (already present on all 5 factions) became the tree's canonical Tier-2 Holy unit.
- **Runtime Faction Palette-Tint Shader** (`assets/shaders/faction_tint.gdshader` + `UnitData.needs_palette_tint` + `GameConfig.FACTION_TINT_COLORS`): Knight, Rogue, Wizzard, and every new Tier-3 unit that reuses a shared generic spritesheet (no hand-painted per-faction art exists) now render in their faction's color at runtime via `TacticalUnit._update_faction_tint()`, instead of every faction sharing one identical uncolored sprite.
- **Real Promotion Mechanic Wired Up**: `EconomyManager.get_upgrade_cost()`/`process_upgrade()` (Field Tax included) and `TacticalUnit.upgrade_to()` already existed but nothing called them. Added `[U]` key + `MainHUD.show_upgrade_popup()` (mirrors the existing `[R]` Recruit popup) so players can actually promote a selected unit through its `upgrade_paths`.
- **Recruitment Model Change**: Tier-3 units removed from Castle `recruitable_units` (including Yellow's former direct-recruit `priest_yellow.tres`) — they are now reachable only via promotion, which is the actual point of an "Upgrade Tree."
- **`CombatResolver.gd`**: Added `"paladin"` to the Holy-vs-Undead bonus name check so the new Holy Tier-3 melee unit gets its intended $2.5\times$ bonus.
- **New Test**: `scenes/test_upgrade_flow.tscn` / `TestUpgradeFlow.gd` verifies promotion success, HP-ratio scaling, Field Tax pricing (2x off-Castle), the insufficient-funds guard, and palette-tint flags end-to-end.
- **Deferred**: Black Coven's separate Undead lineage (Skeleton/Vampire → Lich/Vampire Lord/Nightstalker) has its own tier inconsistencies and was intentionally left out of this pass — see `Roadmap.md` Milestone 3.


### 14. 🏚️ Milestone 3 Completion — Village Economy, Troop Capacity Fix & Undead Lineage
- **Troop Capacity Bug Fix**: `Building.capture()` only ever reported the *new* owning faction via `EventBus.resource_node_captured`, so `EconomyManager` incremented the capturer's village count but never decremented the previous owner's — recapturing a village permanently inflated whoever held it first. Signal now carries both `new_faction_id` and `old_faction_id`; `EconomyManager._on_resource_node_captured` decrements the loser and increments the winner.
- **Village Economy Nodes Shipped**: `BuildingType.HOUSE` was already wired end-to-end (`"village"` type string, `+10` Gold via `collect_income`, `+2` TC via `get_max_capacity`) but no scene or map content existed. Added `scenes/buildings/House.tscn` (neutral, capturable, mirrors `GoldMine.tscn`'s pattern) and placed two neutral villages on `TestGridScene.tscn`.
- **`Building._update_visuals()`**: extended the faction modulate-tint match from 2 factions (Blue/Red) to all 5, so Purple/Yellow/Black captures now render distinctly instead of falling into the generic grey default.
- **Undead Lineage Reconciliation**: Black Coven's Skeleton/Vampire sub-tree is now a finished parallel track, independent of the human tree, reusing the identical `[U]` Upgrade mechanic with no new UI/backend code. `skeleton_black.tres` (Skeleton Warrior) retiered 1→2; previously-orphaned `skeleton_mage_black.tres`/`skeleton_rogue_black.tres` wired into `skeleton_base_black.tres`'s (Skeleton Fodder) `upgrade_paths`; `vampire_black.tres` retiered 3→2 and restatted into a Castle-recruitable Tier-2 entry point. 5 new Tier-3 units created — Bone Reaper, Lich, Wraith, Vampire Lord, Nightstalker — reusing existing small icon art (`skeleton1`/`skeleton2`/`skull`/`vampire v2`) rather than the palette-tint shader, since Undead units don't vary by faction.
- **`CombatResolver.gd`**: added `"nightstalker"` to the Vampire Lifesteal name check (previously only `"vampire"`, which would have silently excluded Nightstalker from its own signature trait).
- **Dropped `Recruitment Pool Refresh`**: this Roadmap item predated Tier-3 becoming promotion-only; a Castle-side elite-unit refresh timer no longer means anything once elites are never recruited at Castles.
- **New Tests**: `scenes/test_village_capacity.tscn` / `TestVillageCapacity.gd` verifies capture, recapture, and the capacity decrement-on-loss fix headlessly (avoids the live-mouse-click calibration issues noted in a prior session). `TestUpgradeFlow.gd` extended with a Skeleton Fodder → Skeleton Mage → Lich case to confirm the shared promotion mechanic works identically for the Undead track.
- **Known remaining gap**: `skull_black.tres` ("Cursed Skull") exists as a resource but isn't wired into any recruit list or upgrade path — flagged, not fixed, in this pass.


---

### 15. 🎨 Sprite Derivation Pipeline — Every Promotion Now Looks Different
- **The bug**: 13 of the 18 Tier-3 units re-used their Tier-2 parent's texture *verbatim*
  (`sniper_*.tres` and `crossbowman_*.tres` both pointed at `Archer_{Faction}.png`;
  `archmage`/`elementalist` at the Wizzard sheet; `assassin`/`shadowblade` at the Rogue
  sheet; `vampirelord` at the Vampire icon; `lich` at the Cursed Skull icon). Promoting a
  unit changed its stats and nothing else on screen.
- **`scripts_dev/spritegen_lib.py` + `generate_sprites.py`**: no image-generation model is
  available to this project, so **66 spritesheets are derived from their parent art** —
  the garment palette is hue-rotated onto the faction hue (skin tones and linework
  detected and excluded, so a Red wizard no longer gets a jaundiced face), then the role
  applies its own value/saturation treatment, a rim light, and a pixel accessory.
- **Role markers**: Paladin/High Priest halo, Archmage orb, Elementalist flame, Assassin &
  Bone Reaper eye-glint, Lich crown, Wraith/Shadowblade/Nightstalker wisps, Vampire Lord
  circlet. Sniper reads as a dark forest ranger and Crossbowman as pale steel — both tuned
  strong enough to survive the ~0.46 in-game downscale, where a rim alone is invisible.
- **The runtime palette-tint shader is gone.** `UnitData.needs_palette_tint` and
  `TacticalUnit._update_faction_tint()` are removed; faction color is baked into real art.
  This deliberately reverses the shader decision recorded earlier today — see `MEMORY.md`,
  which documents the reversal and why the original rationale no longer holds.
- **Idle + Run in one sheet**: derived sheets are 6x2 (row 0 idle, row 1 run) instead of a
  4-frame idle strip, so the 32px units finally animate while moving.
  `TacticalUnit._setup_default_animations()` gained a compact-layout branch for them.

### 16. 📏 Unit Render-Size Normalisation (the "mage is tiny" bug)
- **Root cause**: source frames range from 16x16 icons (Vampire, Lich, High Priest) through
  32x32 strips (Wizzard, Knight, Rogue, Skeletons) to 192x192 and 320x320 TinySwords sheets
  — yet every unit node was hard-scaled to `0.45`. Measured on a 64px tile that rendered a
  Warrior at 41px, a Pawn at 27px, a **Wizzard at 14px** and the undead icons at **7px**.
- **Fix**: two new baked fields on `UnitData` — `sprite_scale` and `sprite_offset` — applied
  by `TacticalUnit._apply_sprite_metrics()`. Unit nodes now stay at `scale = 1.0`; the
  hardcoded `0.45` is removed from `Building.recruit_unit()` and from the scene.
- **Baked, not guessed**: `scripts_dev/wire_units.py` measures each sheet's **idle-row**
  content bounding box and solves for `TARGET_CHAR_PX = 38`. Measuring the union of *all*
  rows was tried first and is wrong — a unit with a wide attack swing shrinks its resting
  pose to keep the widest frame in budget. All 91 units now render at exactly 38px.

### 17. 🚩 Faction Ownership Is Visible on Every Captured Building
- **`Building._update_faction_texture()`** replaces the old `modulate()` tint with a real
  texture swap out of `assets/buildings/{Blue,Red,Purple,Yellow,Black} Buildings/` — a
  captured Castle/Village/Tower now *becomes* the capturing faction's building.
- **`Building._update_faction_banner()`**: Gold and Iron mines have no per-faction art in
  the pack, so they fly a generated pennant in `GameConfig.FACTION_TINT_COLORS`, anchored
  above the sprite whatever its size. Neutral buildings fly none.
- **`Building.resolve_for_owner()`**: a captured castle recruits the **new owner's** unit
  variants. Blue taking the Yellow keep no longer fields yellow-sprited Blue troops. Costs
  are priced off the resolved variant in both `can_recruit()` and `recruit_unit()`.
- **Two authored-scene bugs fixed**: `Castle_Black.tscn` was pointing at
  `Castle_Destroyed.png` (the Black Coven's keep rendered as a ruin), and the *neutral*
  village used `House_Blue.png`, so uncaptured villages already looked like the player's.
  `GoldMine.tscn` also never declared `faction_id`, defaulting to `0` (Blue) instead of Neutral.

### 18. 🗺️ 30x20 Battlefield, Terrain, and a Pan/Zoom Camera
- **`scripts/managers/MapBuilder.gd`** (new, Logic layer): builds the battlefield from
  layout constants and hands the impassable cells to GridManager. Two rivers cut the map
  into a west flank, a contested centre and an east flank; roads are drawn as L-segments
  between waypoints and **every road/river crossing automatically becomes a bridge**, so
  the 8 bridge tiles sit exactly where the routes need them.
- **Four stacked `TileMapLayer`s** (water -4, ground -3, path -2, bridge -1): water fills
  the whole rect underneath, so the grass blob's own edge tiles form the shoreline. The
  tileset gained two atlas sources (`Water.png`, `Bridge_All.png`).
- **Blob-tiling fix**: `Tilemap_Flat`'s 4x4 blocks are a strict edge lookup (col 0 = left
  edge, 1 = none, 2 = right edge, 3 = both; rows likewise), verified by sampling every
  tile's border bands. A first attempt randomised columns 1/2 for "variety" and rendered
  the field as a maze of stray edges.
- **Map contents**: 5 faction castle slots (Purple NW, Red NE, Blue SW, Yellow SE, Black
  Coven centre — the contested prize), 4 Gold Mines, 2 Iron Mines, 6 Villages, 20 forest /
  rock props placed off roads, water and building approaches.
- **`scenes/buildings/IronMine.tscn`** (new): `BuildingType.IRON_MINE` was wired end-to-end
  in `EconomyManager` but had no scene and had never appeared on a map. Its art is a
  desaturated derivation of the Gold Mine sprite.
- **`GridManager`**: new `set_terrain_blocked()` / `set_terrain_blocked_cells()` /
  `get_map_pixel_size()`. Terrain blocking is kept separate from unit occupancy so a unit
  dying on a bridge cannot clear the river beside it.
- **`scripts/ui/TacticalCamera.gd`** (new): WASD/arrows, middle- or right-drag, and edge
  panning, plus wheel zoom clamped to 0.55–2.0. `Camera2D`'s own `limit_*` properties do
  the clamping, so the view can never leave the map. Pulled forward from Milestone 5
  because a 1920x1280 battlefield no longer fits one screen.
- **Also fixed**: `hovered_cell` was drawn by `_draw()` but never assigned — the hover
  cursor had never once appeared. `project.godot` now sets nearest-neighbour texture
  filtering (pixel art was being bilinear-filtered) and a 1408x792 default viewport.

### 19. 🏷️ Unit Names, Naming Convention, and Tooling
- **Faction prefix stripped from `unit_name`** across all 91 resources — the Recruit and
  Upgrade popups render `unit_name` verbatim, so a Blue castle was offering "Blue Pawn".
  Flavour names are preserved (`Cultist Pawn`, `Guard Warrior`, `Death Lancer`,
  `Necromancer Monk`). Verified safe: every name-based branch in `CombatResolver.gd`
  matches on role words (`vampire`, `wizzard`, `knight`, `paladin`, `skeleton`), never colour.
- **`priest_yellow.tres` -> `highpriest_yellow.tres`** (+ its scene), the last unit not
  following `{role}_{faction}` — a landmine for anything resolving units by convention,
  including the new `resolve_for_owner()`.
- **New dev tooling** in `scripts_dev/`: `spritegen_lib.py`, `generate_sprites.py`,
  `wire_units.py`, `validate_project.py` (static integrity check — ext_resource paths,
  frame divisibility, upgrade-path targets, baked metrics, name prefixes),
  `preview_map.py` and `preview_units.py` (render the map and the unit lineup to PNG for
  visual review without the engine). `generate_units.py` is frozen — it would reintroduce
  the removed `needs_palette_tint` property.
- **Tests**: `scenes/test_battlefield.tscn` + `TestBattlefield.gd` (map shape, terrain
  blocking, bridge crossability, capture texture swap, owner-variant recruitment).
  `TestUpgradeFlow.gd`'s palette-tint assertions are replaced by ones that check what the
  bug reports were actually about: every promotion swaps its spritesheet, no unit_name
  carries a faction prefix, and every unit carries baked render metrics.

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
- `/graphify update` synchronization generated **414 nodes, 499 edges, 42 communities**.

---

### 12. 🛡️ Engine Warning Elimination, Lambda Capture Safety, & Concurrent HTTP Refactor
- **EventBus Warning Cleanliness**: Added `@warning_ignore("unused_signal")` to every single signal declaration in `EventBus.gd`, completely silencing 30+ GDScript reload warnings in the Godot editor.
- **Lambda Capture Lifetime Safety**: Refactored timer and tween callbacks in `CombatResolver.gd`, `GridManager.gd`, and `MainHUD.gd` from capturing raw objects in anonymous closures to using `Callable.bind()` helper methods (`_on_combat_animation_timeout`, `_on_unit_move_tween_finished`, `_on_recruit_button_pressed`, `_on_upgrade_button_pressed`). Completely eliminated Godot runtime errors: `call: Lambda capture at index X was freed. Passed "null" instead.`
- **Concurrent Gemini HTTP Requests**: Upgraded `GeminiClient.gd` to spawn dedicated, lightweight `HTTPRequest` child nodes dynamically per request and automatically `queue_free()` them upon completion. Completely resolved: `HTTPRequest is processing a request. Wait for completion or cancel it before attempting a new one.`
- **Compiler Warning Polish**:
  - Prefixed unused parameters (`_building` in `EconomyManager.gd`, `_new_unit` in `TestGridController.gd`).
  - Removed unused local variable `has_any_buildings` in `TurnManager.gd`.
  - Renamed corner bracket coordinates in `TestGridController.gd` (`tl`, `tr`, `bl`, `br` $\rightarrow$ `pt_tl`, `pt_tr`, `pt_bl`, `pt_br`) to prevent shadowing `Object.tr()`.
  - Replaced ternary enum assignment in `TacticalUnit.gd` with explicit `if/else` block to eliminate incompatible ternary warnings.
- **Skill Customization Synchronization**: Created modern, comprehensive `war-tactics-dev` skill definitions in `~/.gemini/config/skills/`, `.agents/skills/`, and `docs/skills/`.
