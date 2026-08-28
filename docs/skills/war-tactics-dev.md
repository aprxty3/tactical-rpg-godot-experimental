---
type: Skill Documentation
title: "War Tactics Developer Skill Reference"
description: "Operational development skill for War Perang Tactics covering architecture, asset derivation, 38px sprite normalization, map generation, and anti-patterns."
tags: [skill, guidelines, architecture, sprites, combat]
generated: { by: human:aprxty3, at: 2026-08-23T15:46:00Z }
---

# ⚔️ War Tactics Developer Skill (`war-tactics-dev`)

This document is the reference version of the `war-tactics-dev` skill for developers and AI agents in **War Perang Tactics**.

---

## 🏛️ 1. Core Architecture Invariants (4-Layer Model)

Communication MUST strictly follow the decoupled 4-layer architecture:
1. **Data Layer (`scripts/data/`)**: Pure `.tres` custom Resources (`UnitData.gd`). MUST contain only `@export` variables. No logic, no signal emissions, no node references.
2. **Event Layer (`scripts/autoload/EventBus.gd`)**: Global signal hub. All cross-manager communication goes through `EventBus`. `@warning_ignore("unused_signal")` is mandatory on all signals.
3. **Logic Layer (`scripts/managers/`, `scripts/autoload/`)**: Rule engines — `TurnManager`, `EconomyManager`, `GridManager`, `CombatResolver`, `MapBuilder`, `MoraleManager`, `VisionManager`, `MapObjectManager`, `VfxManager`, plus the non-node collaborators `AIManager`, `AITacticalEvaluator`, `EncounterManager` and `ResourceScatter`. **Anything that DECIDES something must be reachable without a scene** — that rule is why the last four are `RefCounted`.
4. **Actor Layer (`scripts/units/`, `scripts/buildings/`)**: Visual scene nodes (`TacticalUnit`, `Building`). Passive actors that read Resources, update visual representations, and emit events.

---

## 📏 2. Unit Rendering & Metric Normalization Standard

Source assets span 16×16 icons up to 320×320 TinySwords sheets. Hardcoding node scale is strictly prohibited.

### The 38px Body Height Rule:
- All `TacticalUnit` root nodes MUST remain at **`scale = Vector2(1.0, 1.0)`**.
- Visual sizing is handled entirely by **`UnitData.sprite_scale`** and **`UnitData.sprite_offset`**.
- Both values are **baked offline** by `scripts_dev/wire_units.py` based on the bounding box of the idle animation row, targeting **`TARGET_CHAR_PX = 38`** body height on a 64px grid cell.
- `TacticalUnit._apply_sprite_metrics()` applies these metrics to `Sprite2D.scale` and `Sprite2D.offset`.
- Run `python3 scripts_dev/validate_project.py` to verify that no unit deviates from the 38px standard.

---

## 🎨 3. Asset & Visual Derivation Pipeline

### Faction Colors & Tier-3 Visual Identities:
- **Faction Identity = Hue**: Garment colors are rotated to the 5 faction hues (Blue, Red, Yellow, Purple, Black), with skin tones and line work strictly protected.
- **Role / Tier Identity = Value, Saturation, Rim Light, & Pixel Accessories**:
  - **Paladin**: Golden Halo
  - **Archmage**: Mystic Floating Orb
  - **Elementalist**: Flame Crest / Fiery Aura
  - **Assassin**: Red Eye Glint
  - **Lich**: Dark Crown & Scepter
  - **Wraith**: Ethereal Spectral Wisps
  - **Vampire Lord**: Royal Blood Circlet

### Offline Pipeline Workflow:
```bash
# 1. Generate derived spritesheets from base art
uv run --with numpy,Pillow python scripts_dev/generate_sprites.py

# 2. Wire UnitData resources, bounding boxes, scales, and offsets
uv run --with numpy,Pillow python scripts_dev/wire_units.py

# 3. Validate project consistency (bounding boxes, names, scales)
uv run --with numpy,Pillow python scripts_dev/validate_project.py

# 4. Run Godot headless import to generate .import files
godot --headless --editor --quit-after 50
```

---

## 🗺️ 4. Tactical Battlefield & Map Generation

- **Grid Size**: `30x20` cells (1920×1280 world pixels).
- **Cell Size**: `64x64` pixels.
- **Layers**: 4 dedicated `TileMapLayer` nodes:
  1. `TileMapLayer_Water` (z_index: -4)
  2. `TileMapLayer_Ground` (z_index: -3)
  3. `TileMapLayer_Path` (z_index: -2)
  4. `TileMapLayer_Bridge` (z_index: -1)
- **Grid Highlights**: Drawn in `MatchController._draw()` with **`z_index = 2`** to ensure full visibility above terrain.
- **Passability Authority**: `MapBuilder.gd` paints terrain tiles and returns blocked cells. **`GridManager.set_terrain_blocked_cells()` is the sole authority on walkability**. Never infer walkability from tile IDs at query time.
- **Auto-Bridges**: 8 bridge tiles automatically spawn where roads cross river columns (columns 10 and 19).

---

## 🏰 5. Building Claims & Recruitment Logic

- **Texture Swapping**: When a building is captured (`Building.capture(faction_id)`), swap its texture using real assets from `assets/buildings/{Faction} Buildings/`. Never use `modulate()`.
- **Mines**: Gold Mines and Iron Mines display faction-colored banners upon capture.
- **Dynamic Castle Rosters**: Captured castles dynamically update their `recruitable_units` array to the conquering faction's unit variants.
- **Capacity Ledger**: a village grants **+3** Troop Capacity, a castle **+5 beyond the first** (`maxi(0, castles - 1)` — the opening keep is already priced into the base of 8). Both are returned on loss, and a razed village takes its 3 with it. Castle counts must be **seeded from the board** at `register_faction`, because a faction already owns its opening keep and no capture event ever fires for it; villages need no seeding since every one starts neutral.

---

## ⚔️ 6. Combat & Special Fighting Styles

$$\text{Base Damage} = \max(1, \text{ATK} - (\text{DEF} \times 0.5))$$
$$\text{Final Damage} = \text{round}(\text{Base Damage} \times \text{Advantage Mult} \times \text{Trait Mult} \times \text{Terrain Mod} \times \text{Counter Mod})$$

- **Mage / Armor-Piercing**: Magical damage ignores $75\%$ of physical defense (`DEF * 0.12`).
- **Knight / Heavy Armor**: Takes $-25\%$ flat physical damage reduction.
- **Cavalry (Lancer) Momentum**: $+25\%$ damage bonus when initiating attacks.
- **Infiltrator (Rogue) Backstab**: $+50\%$ critical damage bonus.
- **Holy Smite (Monk / Priest)**: $2.5\times$ damage against Undead.
- **Vampire Lifesteal**: Heals self for $+40\%$ of damage dealt.
- **Ranged Advantage (Archer)**: Attacks from $2\text{--}3$ tiles receive no melee counter-attack.

---

## 🚫 7. Strict Anti-Patterns Table

| Anti-Pattern (DO NOT DO) | Correct Pattern (DO THIS) | Reason |
| :--- | :--- | :--- |
| `UnitData.needs_palette_tint = true` | Use derived textures from `generate_sprites.py` | Shaders cannot create distinct role silhouettes and break 2D draw call batching. |
| Hardcoded node scale `scale = 0.45` | Set node `scale = 1.0`, use `sprite_scale` / `sprite_offset` | Source sprites range from 16px to 320px; baking ensures exact 38px uniform height. |
| `modulate = Color(...)` for building capture | Swap texture from `assets/buildings/{Faction}/` | Modulation looks muddy and fails to capture faction-specific architectural details. |
| Checking tile IDs for pathfinding | Use `GridManager.is_cell_walkable()` | `GridManager` and `AStarGrid2D` are the single authority on movement. |
| Direct node path calls `get_node("/root/...")` | Emit typed signals to `EventBus` | Decoupled architecture prevents spaghetti code and allows modular unit testing. |
| `scripts_dev/generate_units.py` | Use `scripts_dev/wire_units.py` | `generate_units.py` is frozen (exits 2) to prevent restoring deprecated properties. |
