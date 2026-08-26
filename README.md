# Tactical RPG Godot Experimental

A turn-based tactical RPG built in **Godot 4.7**, working title *War Perang Tactics*.

Five factions fight over a 30×20 battlefield split by rivers, with grid movement, a
combat-advantage triangle, a captured-territory economy, fog of war, morale, and an
enemy AI that scores its options instead of walking at the nearest target.

This is an **experimental / learning repository**. It is built milestone by milestone,
each one closed only when an integration suite proves it, and the architecture is the
point as much as the game is.

> Inspired by *Ancient Empire 2*, *Symphony of War*, and *Heroes of Might and Magic: Olden Era*.

---

## 📌 Project Status — `v0.1.0`

| Milestone | State |
|---|---|
| **1 — Core Foundation** | ✅ Complete |
| **2 — Playable Prototype & Unit Expansion** | ✅ Complete |
| **3 — Economy & Unit Upgrade Tree** | ✅ Complete |
| **4 — Advanced Tactical Systems & Morale** | ✅ Complete — 61 checks passing |
| **5 — AI, Visual Polish, Mount, Audio** | 🟡 In progress — 88 checks passing; **Full Campaign deferred** |

Full Campaign is deliberately deferred: it needs a save/load layer that does not exist
in the repo yet, and on its own it is larger than all of Milestone 4. See
[`docs/Roadmap.md`](docs/Roadmap.md) for the reasoning and the per-item detail.

**By the numbers:** 36 GDScript sources · 91 unit resources · 66 derived spritesheets ·
10 integration test scenes · 5 playable factions.

---

## 🎮 What the game actually is

You take a faction, capture buildings to fund an army, recruit from your castle, and
push across a river-split map toward the enemy castle. Every design choice below exists
to make a turn feel like a decision rather than a click.

### Movement and terrain
Pathfinding runs on `AStarGrid2D` with orthogonal movement, plus a Dijkstra movement
field so reachable tiles account for **real terrain cost** — a road is 1 MP, forest is 2.
Two rivers cut the map into a west flank, a contested centre and an east flank, crossable
only at four bridges, so position is committing.

### Combat
A rock-paper-scissors triangle (Melee > Ranged > Mage > Melee, Holy vs Undead ×2.5) layered
with terrain modifiers, counter-attacks, forest ambush bonuses, and per-class traits.
Damage is computed in exactly one place — `CombatResolver` — and everything that needs a
number, the AI included, asks that same resolver.

### Economy
Gold, Iron, and Troop Capacity. Castles pay passive gold, mines and villages pay on
capture, and exceeding your capacity triggers a starvation penalty. Upgrading a unit away
from your castle costs a 2× "Field Tax", so promotion has geography.

### Tactical layer
Fog of war with explored-versus-visible states, a morale system that can make a unit
desert or surrender, forest ambushes, and TNT barrels that chain-detonate.

### Enemy AI
The enemy does not chase the nearest thing. `AITacticalEvaluator` scores objectives by
**value ÷ real path cost**, scores attacks by expected damage against the counter-attack
it will eat, and retreats when incoming threat outweighs remaining HP. The scoring is a
plain `RefCounted` class with no scene dependencies, so it can be unit-tested without
running a turn.

### Presentation
Eight-direction facing for cavalry, mount/dismount that trades movement for defence,
particle VFX driven purely off the event bus, screen shake, and an audio layer with
separate Music/SFX buses, a polyphonic SFX pool, crossfade and combat ducking.

---

## 🚀 Quick Start

**Prerequisites:** Godot Engine 4.7+ (GL Compatibility renderer).

1. Clone and open the project folder in Godot 4.7.
2. **First run only** — import the generated art:
   ```bash
   godot --headless --path . --import
   ```
   The 66 derived spritesheets under `assets/characters/generated/` have no `.import`
   files until Godot has seen them once.
3. Open [`scenes/TestGridScene.tscn`](scenes/TestGridScene.tscn) and press **`F6`**.

### Controls

| Input | Action |
|---|---|
| **Left Click on Unit** | Select (🟦 blue = movement range, 🟥 red = attack range) |
| **Left Click on Blue Tile** | Move there |
| **Left Click on Enemy** | Attack — resolves damage and any counter-attack |
| **Left Click on Your Castle** | Select the castle |
| **`[R]`** | Recruit popup at the selected castle (Tier 1–2 only) |
| **`[U]`** | Upgrade popup (Tier 3 is promotion-only; 2× Field Tax off-castle) |
| **`[M]`** | Mount / dismount the selected cavalry — consumes the action |
| **`[SPACE]`** | End turn (confirmation modal) |
| **`[ESC]`** | Close popup / deselect, or quit when nothing is selected |
| **`[W][A][S][D]` / Arrows** | Pan the camera |
| **Left-Drag** | Pan. Only becomes a drag past 6 px, so a click still selects |
| **Middle / Right-Drag** | Pan. Cursor at a screen edge also pans |
| **Mouse Wheel** | Zoom (0.55×–2.0×) |

---

## 🏗️ Architecture — 4-Layer Decoupled Pattern

```text
┌─────────────────────────────────────────────────────────┐
│                    1. DATA LAYER                        │
│   UnitData.tres  TerrainData.tres  MountProfile.tres    │
│   (Resources — pure data containers, no logic)          │
└──────────────────────┬──────────────────────────────────┘
                       │ read by
┌──────────────────────▼──────────────────────────────────┐
│                    2. ACTOR LAYER                       │
│   TacticalUnit.gd  Building.gd  MapObject.gd            │
│   (Node2D — visual, input, sprite, animation)           │
└──────────┬────────────────────────────┬─────────────────┘
           │ emit signals               │ emit signals
┌──────────▼────────────────────────────▼─────────────────┐
│                    3. EVENT LAYER                       │
│                   EventBus.gd                           │
│   (Autoload singleton — central typed signal hub)       │
└──────────┬────────────────────────────┬─────────────────┘
           │ listened by                │ listened by
┌──────────▼────────────────────────────▼─────────────────┐
│                    4. LOGIC LAYER                       │
│  TurnManager EconomyManager CombatResolver AIManager    │
│  VisionManager MoraleManager VfxManager MapObjectManager │
│   (Managers — rules, state machines, calculations)      │
└─────────────────────────────────────────────────────────┘
```

**The rules that hold this together:**

- `EventBus` is the *only* cross-system channel. No manager reaches into another.
- Managers are injected via `setup()`, never fetched by node path.
- One source of truth per rule. `CombatResolver.preview_damage()` exists precisely so the
  AI can plan against the same maths the player experiences.
- A manager that a scene omits must not break that scene — `VfxManager` is a pure event
  consumer for exactly this reason.

**Autoloads:** `AudioManager`, `EventBus`, `GameConfig`, `TurnManager`, `GeminiClient`.

---

## 🧪 Testing

Every milestone ships an integration scene that reports pass/fail per check and continues
on failure, so one broken system cannot mask the others.

```bash
godot --headless --path . scenes/test_milestone5.tscn   # 88 checks
godot --headless --path . scenes/test_milestone4.tscn   # 61 checks
godot --headless --path . scenes/test_all_units.tscn    # all 91 unit resources
```

Other suites: `test_battlefield`, `test_combat_mechanics`, `test_upgrade_flow`,
`test_village_capacity`, `test_undead_gameplay`, `test_popup_and_map`, `test_qa_stress`.

---

## 🎨 Regenerating the derived art

The 66 faction spritesheets are **derived**, not hand-drawn per faction: the garment
palette is hue-rotated onto the faction hue (skin and linework preserved), then each
promotion gets its own value/saturation treatment, rim light and role marker.

```bash
python3 scripts_dev/generate_sprites.py   # derive the 66 spritesheets
python3 scripts_dev/wire_units.py         # wire them + bake sprite_scale/offset
python3 scripts_dev/wire_mounts.py        # wire directional cavalry art
python3 scripts_dev/generate_music.py     # render placeholder music loops
python3 scripts_dev/validate_project.py   # static integrity check (must report 0 errors)
```

---

## 🧠 Coding Philosophy

**ROBUST** — fail gracefully, explicit static typing, zero headless script errors.
**DRY** — programmatic generation over manual duplication.
**KISS** — use built-in Godot features; avoid over-engineering.
**YAGNI** — no abstraction before the current milestone needs it.

---

## 📁 Project Structure

```text
.
├── assets/          # Sprites, audio, tilesets, shaders, VFX  (third-party art — see LICENSE)
├── addons/          # Third-party editor addons  (own licenses — see LICENSE)
├── docs/            # GDD & architecture documentation (OKF v0.2)
├── resources/       # Resource files (.tres) — 91 units, mounts, terrain
├── scenes/          # Prefabs, the playable scene, and 10 test scenes
├── scripts/         # GDScript source — autoload/ data/ managers/ ui/ units/ test/
├── scripts_dev/     # Offline pipelines (sprite derivation, metric baking, validation)
├── tests/           # Standalone unit tests
├── CHANGELOG.md     # Release notes & change history
├── GUIDE.md         # Developer guide & system expansion
├── MEMORY.md        # Architectural invariants & design-decision history
├── DISTRIBUTED.md   # Decoupling pattern rationale
├── LICENSE          # MIT (own code) + third-party scope
└── project.godot    # Godot 4.7 configuration
```

---

## 📜 License

This project's **own source code and documentation** are released under the
[MIT License](LICENSE).

That grant is deliberately scoped, and the distinction matters if you reuse this repo:

- **`addons/`** — three bundled editor addons (script-ide, godot_ai, GDQuest GDScript
  Formatter). Each is MIT under *its own* copyright holder, and ships its own LICENSE
  file. Their notices must be retained; nothing here relicenses them.
- **`assets/`** — **not** covered by the MIT grant. The artwork derives from third-party
  pixel-art packs (*Tiny Swords*, *Pixel RPG Pack*) and is redistributed under those
  packs' own terms. The generated spritesheets are programmatic derivatives of that art
  and inherit its terms — the derivation *scripts* are MIT, the *pixels* are not.

If you plan to ship anything built on this, verify the current terms of those asset packs
with their original authors first.
