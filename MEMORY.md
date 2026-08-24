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
   * Battlefield Size: `Vector2i(30, 20)` cells = 1920x1280 world pixels. Larger than
     the viewport by design — `TacticalCamera` pans and zoom-clamps to those bounds.
   * Impassable terrain is registered through `GridManager.set_terrain_blocked_cells()`.
     `MapBuilder` paints the tiles and reports the cells; **GridManager remains the only
     authority on walkability** — never infer passability from tile ids at query time.

4. **Unit Render Metrics (never hand-authored)**:
   * Source art spans 16x16 icons to 320x320 TinySwords frames. Unit nodes therefore stay
     at `scale = 1.0`; the per-unit `UnitData.sprite_scale` / `sprite_offset` carry the
     sizing, and `TacticalUnit._apply_sprite_metrics()` applies them.
   * Both values are **baked offline** by `scripts_dev/wire_units.py` from the idle row's
     content bounding box, targeting `TARGET_CHAR_PX = 38` body height on a 64px cell.
     Guessing them by hand is how the mage ended up a quarter of a Warrior's size.
   * `scripts_dev/validate_project.py` fails the build if any unit drifts off 38px.

5. **Multi-Faction Invariant**:
   * All economic and unit systems must support dynamic `faction_id`:
     * `0`: `BLUE_KINGDOM` (Default Player faction)
     * `1`: `RED_LEGION` (Default AI/Enemy faction)
     * `2`: `PURPLE_SYNDICATE`
     * `3`: `YELLOW_EMPIRE`
     * `4`: `BLACK_COVEN`
     * `99`: `NEUTRAL` (Neutral Buildings / Creatures)

6. **Coding Principles (ROBUST, DRY, KISS, YAGNI)**:
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
| **2026-08-23** | ~~Faction color for generic (non-recolored) sprites is a runtime shader tint, not new art~~ | **REVERSED 2026-08-23 (see below).** Original rationale: no image-generation tool was available in-session, so `UnitData.needs_palette_tint` + `assets/shaders/faction_tint.gdshader` recolored Knight/Rogue/Wizzard and their Tier-3 offshoots per faction_id instead of requiring hand-painted variants. |
| **2026-08-23** | Black Coven's Undead lineage is a parallel, Black-Coven-only progression track — not merged into the 5-faction human tree | Undead units don't vary by faction (there's only one Black Coven), and the branching shape differs (1 Tier-3 per Tier-2 for the Skeleton line, vs. 2 for the human tree); it reuses the exact same `[U]` Upgrade mechanic (`EconomyManager.process_upgrade`/`TacticalUnit.upgrade_to` are class-agnostic) with zero new backend/UI code. |
| **2026-08-23** | `Recruitment Pool Refresh` dropped from the Roadmap, not implemented | The item predated the decision to make Tier-3 promotion-only; once elite units are never recruited at Castles at all, a Castle-side refresh timer for them has no referent. Access to elites is already gated by gold/iron cost plus the Upgrade action itself. |
| **2026-08-25** | Buildings state their own income; `TurnManager` only sums it | `Building.get_income()` already encoded what each type is worth but had zero callers — `TurnManager` kept a parallel `match` that never listed CASTLE, so the castle stipend had never been paid. Keeping the same knowledge in two places is what hid the bug, so `collect_income()` now takes summed gold/iron and a new building type earns income without either caller knowing it exists. |
| **2026-08-25** | Iron is a scarce gate, not a currency (mine yield 30 → 3/turn) | No unit costs more than 4 Iron and a faction opens with 6, so a 30/turn mine ended the constraint on first capture. Gold runs at roughly one unit per mine per turn; Iron now matches that ratio, and agrees with `PANDORA_SPOILS_IRON`'s 2-8 payout for a rare chest. |
| **2026-08-25** | Fog hides *who*, not *where* — unseen cells are translucent, not black | An opaque sheet read as a rendering failure rather than as fog, and hid terrain the player has no reason to be denied. Three shades (0 / 0.42 / 0.78) keep visible, remembered and unseen distinct. Units stay hidden via `_apply_unit_visibility()`; buildings deliberately show through, matching the Advance Wars convention that map layout is known and only troops are secret. |
| **2026-08-25** | Click-vs-drag is decided by a 6 px threshold, and the grid acts on release | Left-drag panning and click-to-select both want the left button. Acting on press decides "click or pan?" before the cursor has moved and can answer it. `TacticalCamera` is a child of the controller, so it sees unhandled input first and marks a pan's release handled — no cross-references between the two scripts. |
| **2026-08-25** | Gemini narrative engine runs `gemini-3.5-flash-lite`, not full Flash | Full Flash is a thinking model: ~480 reasoning tokens and 2.5-5.6s for a one-line battle cry, which lands after the fight it reacts to. Lite answers in ~1.2-1.8s. Also note `maxOutputTokens` covers thinking **plus** output, and `thinkingConfig.thinkingBudget = 0` is ignored by these models — headroom is the only lever. |
| **2026-08-23** | **Reverses the palette-tint-shader decision above**: faction color is now baked into generated art, and `needs_palette_tint` / the runtime shader path are removed from `UnitData` and `TacticalUnit`. | The original decision's stated rationale was *"no image-generation tool is available"*. That constraint no longer holds: `scripts_dev/generate_sprites.py` derives real per-faction sheets from the parent art (hue-rotate the garment palette onto the faction hue, protecting skin tones and linework). A shader tint can only recolor — it cannot make a Sniper look different from an Archer, which was the actual reported bug. Reversal explicitly approved by aprxty3 this session. `assets/shaders/faction_tint.gdshader` is left on disk, unreferenced, in case it is wanted for VFX. |
| **2026-08-23** | Role identity is expressed as value/saturation + rim light + a pixel accessory; **hue stays reserved for faction identity** | Advance Wars reads ownership by color first. Giving Sniper its own green hue would have made a Blue Sniper unreadable as Blue. So faction owns hue, and the promotion tells itself apart by being darker/brighter, rim-lit, and carrying a marker (Paladin halo, Archmage orb, Elementalist flame, Assassin eye-glint, Lich crown, Wraith wisps, Vampire Lord circlet). |
| **2026-08-23** | Tier-3 art is **derived** from the Tier-2 parent sheet, not drawn from scratch | Procedurally drawing 32x32 pixel art from code would not match the TinySwords pack and would look worse than what it replaced. Derivation keeps the silhouette, animation timing and art style intact while making the promotion unmistakable. `scripts_dev/spritegen_lib.py` holds the transforms; the sheets are regenerable, so the pipeline — not the PNGs — is the source of truth. |
| **2026-08-23** | Undead and Vampire lines moved off their 16x16 static icons onto the 32px animated strip family | Those icons rendered at 7px on a 64px tile, which is the same defect as the mage, only worse. They also had no run animation. Deriving them from the skeleton/rogue strips gives the whole Black Coven roster one consistent size and an idle+run cycle. |
| **2026-08-23** | A captured Castle recruits the **new owner's** unit variants (`Building.resolve_for_owner`) | With five castles on the map, a Blue army taking the Yellow keep would otherwise recruit yellow-sprited troops fighting for Blue — exactly the ownership-color confusion this pass set out to fix. The `{role}_{faction}.tres` naming convention makes the swap a filename lookup, with a fallback for units (the Undead) that have no faction variants. |
| **2026-08-23** | `priest_yellow.tres` renamed to `highpriest_yellow.tres` | It was the only Tier-3 Holy unit not following `highpriest_{faction}`, so any code resolving units by convention — including the new `resolve_for_owner` — would have silently missed the Yellow Empire. |
| **2026-08-23** | `Tilemap_Flat` blob tiles are a strict edge lookup, not interchangeable variants | Columns are `0`=left edge, `1`=none, `2`=right edge, `3`=both (rows likewise for top/bottom), verified by sampling every tile's border bands. Randomising between columns 1 and 2 to "add variety" sprays right-hand edges through open field and renders the map as a maze. Variety comes from decor props instead. |
| **2026-08-23** | `scripts_dev/generate_units.py` is frozen (exits 2 unless overridden) | It still writes the removed `needs_palette_tint` property and points Tier-3 units back at their parent textures. Kept for provenance; superseded by `generate_sprites.py` -> `wire_units.py` -> `validate_project.py`. |
