---
type: Roadmap
title: "Development Roadmap & Feature Pipeline"
description: "Prioritized feature roadmap with inspirations from Symphony of War, HoMM: Olden Era, and Ancient Empire 2."
tags: [roadmap, features, milestones, planning]
generated: { by: human:aprxty3, at: 2026-08-22T00:00:00Z }
sources:
  - id: symphony-of-war
    resource: https://symphonyofwar.wiki.gg/
    title: "Symphony of War: The Nephilim Saga Wiki"
  - id: homm-olden-era
    resource: https://wiki.hoodedhorse.com/Heroes_of_Might_and_Magic_Olden_Era/Main_Page
    title: "Heroes of Might and Magic: Olden Era Wiki"
  - id: ancient-empire-2
    resource: https://store.steampowered.com/app/Ancient_Empires_2
    title: "Ancient Empire 2"
---

# Development Roadmap

## Milestone 1: Core Foundation
Status: 🟢 Completed

### Completed
- [x] Project setup (Godot 4.7, GL Compatibility)
- [x] Game Design Document (GDD)
- [x] Faction & Unit design documentation
- [x] Terrain & Building design documentation
- [x] Macro-Economy design (Gold, Iron, Troop Capacity)
- [x] Basic UnitData Resource script
- [x] Basic EconomyManager (single-faction)
- [x] Basic TurnManager (upkeep phase)
- [x] Basic TacticalUnit script
- [x] Decoupled Data-Driven architecture refactor
- [x] EventBus autoload (signal hub)
- [x] Multi-faction EconomyManager
- [x] TurnManager state machine (4 phases)
- [x] GridManager + AStarGrid2D pathfinding
- [x] CombatResolver + damage formula
- [x] Unit .tres resource files for all unit types
- [x] Main scene setup (scene tree hierarchy)

## Milestone 2: Playable Prototype & Unit Expansion
Status: 🟢 Completed

- [x] Implement additional Unit Classes (Archer, Rogue, Wizzard, Priest, Vampire, Skeleton).
- [x] Integrate Spritesheet Animations for movement, attacking, and death.
- [x] Implement robust Victory/Defeat condition checks based on Castle captures or Annihilation.
- [x] Build a comprehensive UI (Resource bar, Unit inspector panel, Action context menu).
- [x] Add sound effects (SFX) for combat impacts and movement.
- [x] In-Game AI Narrative Engine: `GeminiClient.gd` autoload powered by **Gemini 3.5 Flash Lite** for dynamic combat banter and territory capture declarations. Flash Lite replaced full Flash on 2026-08-25: the heavier model is a thinking model that burned ~480 reasoning tokens and 2.5-5.6s on a single one-line battle cry, which lands after the fight it is reacting to has ended.


## Milestone 3: Economy & Advanced Progression (Unit Upgrade Tree)
Status: 🟢 Completed — human tree, Undead lineage, promotion mechanic, and Village economy all shipped

### 1. Unit Upgrade Tree Architecture
All 5 factions (Blue Kingdom, Red Legion, Purple Syndicate, Yellow Empire, Black Coven) now share the same symmetric human tree. Tier-1 (Pawn) and Tier-2 units are directly recruitable at a Castle; **Tier-3 units are promotion-only** — reached exclusively via the `[U]` Upgrade action on an existing Tier-2 unit, never recruited directly:

```text
                                ┌──► [ Melee ] ───► Warrior ────┬──► Knight (Heavy Armor)
                                │                                └──► Lancer (Mounted Charge)
                                │
                                ├──► [ Ranged ] ──► Archer ─────┬──► Sniper (Extreme Range)
                                │                                └──► Crossbowman (Armor Pierce)
                                │
[ Tier 1: Pawn ] ───────────────┼──► [ Magic ] ───► Wizzard ────┬──► Archmage (Huge AoE)
(Worker / Light Infantry)       │                                └──► Elementalist (Status/Burn)
                                │
                                ├──► [ Holy ] ────► Monk ───────┬──► High Priest (Mass Heal)
                                │                                └──► Paladin (Melee/Holy Hybrid)
                                │
                                └──► [ Stealth ] ─► Rogue ──────┬──► Assassin (Lethal Backstab)
                                                                 └──► Shadowblade (Stealth/Ambush)

[ Undead Lineage (Black Coven only) — a separate, parallel track, NOT merged into the tree above ]
                          ┌──► Skeleton Warrior ──► Bone Reaper (Heavy Melee)
                          │
[ Tier 1: Skeleton Fodder ]──► Skeleton Mage ────► Lich (Necromancer Caster)
                          │
                          └──► Skeleton Rogue ───► Wraith (Stealth Ambusher)

[ Tier 2: Vampire (Lifesteal Bruiser, own entry point — no Tier-1 parent) ]──┬──► Vampire Lord (Heavier Bruiser)
                                                                              └──► Nightstalker (Mobile/Evasive)
```

Since Knight/Lancer (Melee) and Archer (Ranged) already had full art, and Monk/Wizzard/Rogue already existed on at least one faction, "shipping" this tree meant: fixing `Warrior`'s tier (was incorrectly `1`, same as Pawn), filling in the missing Tier-2 units per faction (Wizzard/Rogue), generating all 8 new Tier-3 branches (×5 factions), and building a runtime faction palette-tint shader (`assets/shaders/faction_tint.gdshader`) so the units without hand-painted per-faction art (Knight/Rogue/Wizzard and their Tier-3 offshoots) still render in the correct faction color instead of one shared generic sprite.

The Undead lineage is intentionally **not** folded into the 5-faction symmetric tree — it's a Black-Coven-exclusive track with its own simpler branching (one Tier-3 per Tier-2, not two) that reuses the identical `[U]` Upgrade mechanic. `skeleton_mage_black.tres`/`skeleton_rogue_black.tres` existed fully-built but were never wired into any recruit list before this pass; `skeleton_black.tres` (Skeleton Warrior) was wrongly tagged tier 1 (same as Fodder); `vampire_black.tres` was a dead-end Tier-3 with no promotion path. All five new Tier-3 Undead units (Bone Reaper, Lich, Wraith, Vampire Lord, Nightstalker) reuse existing small icon art (`assets/characters/skeleton/skeleton1|skeleton2|skull/`, `assets/characters/vampire/v2/`) rather than the palette-tint shader, since each already has unique art and Undead units don't vary by faction.

### 2. Progression & Economy Tasks
- [x] **UnitData Progression Blueprint**: `upgrade_paths: Dictionary[String, Resource]` on `UnitData.gd`, now populated on every Tier-1/Tier-2 unit across all 5 factions (human tree) and the full Undead lineage (Black Coven).
- [x] **Dynamic Upgrade Action & UI**: `[U]` key opens an Upgrade popup (`MainHUD.show_upgrade_popup`) listing the selected unit's `upgrade_paths`; mirrors the existing `[R]` Recruit popup.
- [x] **Field Tax Implementation**: `EconomyManager.get_upgrade_cost()` / `process_upgrade()` already existed and are now actually wired up; off-Castle promotions correctly cost $200\%$ of the tier-difference price.
- [x] **Troop Capacity System & Logistics Collapse**: Starvation logic already existed in `EconomyManager`; fixed a real bug where `Building.capture()` only reported the *new* owner, so a village's capacity bonus was never removed from whoever lost it on recapture. `EventBus.resource_node_captured` now carries both `new_faction_id` and `old_faction_id`.
- [x] **Village Economy Nodes**: New `scenes/buildings/House.tscn` (neutral capturable node, mirrors `GoldMine.tscn`'s pattern) grants $+2$ TC cap and $+10$ Gold passive revenue on capture — the mechanic already existed in `EconomyManager`/`Building.gd` (`BuildingType.HOUSE` → `"village"`) but no scene or map placement existed until now. Two neutral villages placed on `TestGridScene.tscn`.
- [x] **Dual Upgrade Specializations**: Every Tier-2 unit in the human tree offers exactly two Tier-3 choices (e.g. Warrior → Knight *or* Lancer); the Undead lineage uses a simpler 1:1 branching by design (see above).
- [x] **Undead Lineage Reconciliation**: Black Coven's Skeleton/Vampire sub-tree is a finished parallel track — see the diagram above.

**Dropped**: *Recruitment Pool Refresh* (replenishment timers for elite units at Castles) — this item predated the decision to make Tier-3 promotion-only. Since elite units are no longer recruited at Castles at all, a refresh timer for them no longer applies; access is already gated by gold/iron cost and the Upgrade action itself.

**Known remaining gap**: `skull_black.tres` ("Cursed Skull", tier 1, Undead) now has its own derived sprite but is still not wired into any recruit list or upgrade path — flagged for a future pass.

### 3. Art Correction Pass (2026-08-23)
The tree above shipped with its promotions **sharing their parent's texture** — 13 of the
18 Tier-3 units were visually identical to the Tier-2 unit they were promoted from, which
made the tree look cosmetic even though it was mechanically real. Corrected:

- [x] **Derived Tier-3 art** for all 18 promotions across 5 factions (66 generated sheets):
      `scripts_dev/generate_sprites.py` hue-rotates the parent's garment palette onto the
      faction hue, then applies a per-role value/saturation treatment, rim light, and pixel
      accessory. Faction owns hue; role owns everything else.
- [x] **Runtime palette-tint shader retired.** `UnitData.needs_palette_tint` and
      `TacticalUnit._update_faction_tint()` are removed — faction colour is baked into real
      per-faction art. This reverses an earlier decision on the same day; the reversal and
      its rationale are recorded in `MEMORY.md`.
- [x] **Unit render-size normalisation**: baked `sprite_scale` / `sprite_offset` on
      `UnitData` put every unit at 38px body height on a 64px tile, regardless of whether
      its source frame is 16x16 or 320x320.
- [x] **Undead & Vampire lines migrated** off 16x16 static icons onto the 32px animated
      strip family, gaining an idle + run cycle and a consistent size.
- [x] **`highpriest_yellow.tres`** — the last resource not following `{role}_{faction}`.


## Milestone 4: Advanced Tactical Systems & Morale
Status: 🟢 Completed — all six tactical systems shipped 2026-08-23

### Landed early (prerequisites for the systems below)
- [x] **30x20 battlefield** (`scripts/managers/MapBuilder.gd`): two rivers, four road-driven
      bridge crossings, ornamental ponds, and a shoreline formed by the grass blob tileset.
      Replaces the flat 16x10 grass rectangle, which had no chokepoints to fight over.
- [x] **Impassable terrain**: `GridManager.set_terrain_blocked_cells()` — water blocks both
      BFS movement range and A* pathing. Terrain blocking is tracked separately from unit
      occupancy.
- [x] **Five faction castle slots** on one map (Purple NW, Red NE, Blue SW, Yellow SE, Black
      Coven centre), plus 4 Gold Mines, 2 Iron Mines and 6 Villages as contested objectives.
- [x] **`IronMine.tscn`**: `BuildingType.IRON_MINE` had been wired through `EconomyManager`
      since Milestone 1 but had no scene and had never appeared on a map.
- [x] **Forest / rock props** placed off roads and building approaches — the terrain that
      Forest Ambush (below) will attach its bonuses to.

### The six tactical systems (all shipped 2026-08-23)

Three new Logic-layer managers carry them, injected through `setup()` like
`AIManager` and communicating only over `EventBus`: **`MoraleManager`** (morale
and surrender), **`VisionManager`** (fog of war), and **`MapObjectManager`**
(chests, kegs, fire). The map objects themselves share one `MapObject` base —
all three are "one cell, reacts when stepped on, ticks once per round" — so
`Chest`, `Barrel` and `Fire` stay small and hold no manager references of their
own.

- [x] **Terrain System** *(prerequisite for the rest)*: `GameConfig.TerrainType`
      + `TERRAIN_RULES` give every cell a move cost, a damage-taken multiplier,
      a concealment flag and a flammability. `MapBuilder` derives the map while
      it paints — a cell is Forest because a tree was actually drawn on it — and
      `GridManager` owns it from then on as the single authority. Forest anchors
      now grow into 2-4 cell clumps, because a one-tile wood is decoration and a
      clump is a position worth taking.
- [x] **Movement cost**: `GridManager` moved from uniform-cost BFS to a Dijkstra
      movement field. Forest and rocks cost 2 MP, roads and bridges 1, so the
      west/east highways are finally worth using. Reachability *and* the route
      walked are both derived from the same field, which is what guarantees a
      unit can never be offered a tile it cannot afford to reach.
- [x] **Morale System**: a 0-100 scalar on `TacticalUnit`, with the 5 states
      derived from it (an enum FSM — one concern, no nesting). Nearby deaths,
      damage taken, flanking, ambushes, starvation and lost buildings move it;
      it drifts back toward Fair each upkeep. Drives an attack multiplier
      (0.80x-1.15x), desertion at Fearful, and surrender eligibility. **Undead
      are immune** — derived from `unit_class`, no new field.
- [x] **Surrender Mechanic**: a unit that survives an attack while Shaken or
      Fearful may break. It freezes as a prisoner and its captor decides:
      the player is asked through a modal with no cancel path, an AI captor
      applies the capacity rule itself (take the prisoner if the army can feed
      one, ransom them otherwise). Captured units defect — adopting the new
      owner's own art via `UnitData.variant_for_faction` — arriving wounded,
      shaken and already spent.
- [x] **Terrain Ambush**: attacking out of Forest suppresses the counter-attack
      entirely and lands a morale shock on the victim. Fills the
      `terrain_def_mult` hook that had been pinned to 1.0 since Milestone 1.
- [x] **Fog of War**: `FogOfWarTileMapLayer` with a tileset generated in code,
      three states per cell (unseen / explored-and-remembered / visible). Uses
      the Advance Wars rule rather than raycast LOS — radius, plus units on
      concealing terrain only spotted from an adjacent tile — which is cheap and
      has no corner cases. **Symmetric: the AI is bound by the same fog**, and
      keeps a last-known-position scouting report so losing sight of an enemy
      makes it march on the last sighting instead of going passive.
- [x] **Environmental Hazards**: powder kegs sit beside the bridge mouths
      (derived from the map's own bridge analysis, not hardcoded). They detonate
      when stepped on or shot, deal TRUE damage, and chain through neighbouring
      kegs via a breadth-first walk over a visited set. Fire damages whoever
      stands in it, spreads to flammable neighbours, and **burns forest down to
      `SCORCHED`** — permanently removing that cover, concealment and ambush.
- [x] **Pandora's Box / Treasure Chests**: seeded scatter (fixed seed reproduces
      a layout for tests). Four outcomes on the existing `GameConfig` odds — war
      spoils, a mercenary, a trap, or the awakened dead, who enlist under the
      opener's *enemy*. Closes the Milestone 3 gap: `skull_black.tres` finally
      has a use.

**Verified**: `scenes/test_milestone4.tscn` — 61 integration checks, all
passing, covering every system above. The older suites (battlefield, combat,
upgrade, village, undead) still pass unchanged.

**Fixed along the way** (all pre-existing; each confirmed against the
unmodified build before being touched):
- `EconomyManager.get_used_capacity()` / `_apply_starvation()` ran `is` against
  roster entries without an `is_instance_valid` check, so a single stale
  reference crashed the game. Both are read on every HUD refresh and recruit
  check. Found by the new test suite.
- **Discrete key commands accepted auto-repeat.** Space / R / U / Escape all
  fired on `echo` events, so *holding* Space opened the end-turn prompt and
  confirmed it in the same breath. Fixed by dropping `event.echo` on all four.
  ⚠️ **Still open**: an idle match continues to advance by itself on this
  machine. Stack-dumping every `end_turn()` caller showed all of them arriving
  through the Space handler — never from the AI — and the same runaway
  reproduces on the unmodified pre-Milestone-4 build, so it is not something
  this milestone introduced. As the echo guard did not stop it, the events are
  discrete key-downs rather than auto-repeat.

  *Investigated further 2026-08-25, still not closed.* Reading the raw evdev
  devices directly (the user is in the `input` group, so no tooling or sudo was
  needed) found **no key held down** — `EVIOCGKEY` across all 25 input devices
  came back clean, which rules out a mechanically stuck spacebar. A 240-second
  capture logged 10 Space presses, **none of them isolated**: every one sat
  within 2s of other typing, i.e. ordinary input. That capture is *not*
  conclusive, though — the window was contaminated by 548 other keypresses and
  the game was not running for all of it.

  Meanwhile the symptom was observed first-hand the same day: during
  MCP-driven camera testing, with the agent sending **no keyboard input at
  all**, `TurnManager.turn_number` climbed on its own to 4 and then 5, and Blue
  units relocated between evaluations. So the behaviour is real and frequent,
  but the "stray Space from outside the project" explanation is now the
  *unverified* half. Next step is a clean capture: game running idle, hands off
  the keyboard, correlating evdev Space events against `turn_number`. If that
  window shows turns advancing with zero Space events, the original diagnosis is
  wrong and this returns to being a code bug worth chasing.
- **AI turn hardening** (defensive, no observed failure): `AIManager` awaited
  the *global* `unit_move_completed`, which resumes on whichever unit arrives
  first rather than the one being waited on, and never resumes at all if the
  move is rejected — either way the coroutine desynchronises from its turn, and
  a late resume would end the turn twice. Replaced with a bounded per-unit wait
  (`GridManager.is_unit_moving`) plus a `_turn_running` re-entrancy guard.

## Milestone 5: AI Enhancements, Campaign & Polish
Status: 🟡 In progress — AI, Visual Polish, Mount System and Audio shipped 2026-08-25; Full Campaign deferred

**Verified**: `scenes/test_milestone5.tscn` — 88 integration checks, all passing.
Every earlier suite (Milestone 4, battlefield, combat, all-units, upgrade,
village, undead) still passes unchanged.

- [x] **Advanced Enemy AI** *(2026-08-25)*: judgement split out of the turn loop
      into `scripts/managers/ai/AITacticalEvaluator.gd`, so the scoring can be
      tested on a built board without running a turn, awaiting a signal or
      timing an animation.
      - **Objectives are ranked by value per step of travel**, not proximity:
        `GameConfig.AI_OBJECTIVE_VALUE` divided by the *real* terrain-aware path
        cost. A Gold Mine 13 MP away now outranks an Iron Mine 11 MP away —
        exactly the prioritisation the item asked for, which the old
        nearest-building-wins rule could not express at all.
      - **Movement follows the Dijkstra field**, not Manhattan distance. The old
        stepper could not tell a road from a forest and routinely spent 2 MP to
        save one tile of straight line.
      - **Defensive manoeuvring**: a unit under `AI_RETREAT_HP_RATIO` health, or
        standing where incoming threat is `AI_RETREAT_THREAT_RATIO` of the HP it
        has left, breaks off toward the lowest-threat reachable cell with cover
        as the tiebreak. A killing blow still outranks fleeing — a corpse cannot
        chase.
      - **Attacks are scored, not sorted by HP**: expected damage against the
        counter it will eat, plus a kill bonus and an ambush bonus. A swing that
        scores at or below zero is declined rather than feeding the unit in.
      - **Recruitment counters what it can see**, using the same advantage table
        combat resolves through.
      - Damage is never recomputed: `CombatResolver.preview_damage()` was
        promoted from private, so the AI plans against the exact numbers the
        player experiences and the two can never drift.
- [x] **Dynamic Camera System** — *pulled forward, delivered 2026-08-23*: `scripts/ui/TacticalCamera.gd` does WASD/arrow panning, drag-to-pan on any mouse button, edge panning, and wheel zoom clamped to the map bounds. Left-drag was added 2026-08-25 and needed the grid's click handler to move from press to release: whether a left press is a click or the start of a pan is only decidable once the cursor has moved, so acting on press answered the question too early. A 6 px threshold separates the two, and the camera marks a pan's release as handled so a drag never selects the tile it finished over. Pulled out of this milestone early because a 30x20 map is 1920x1280 world pixels and no longer fits one screen. Screen shake on heavy impacts is still outstanding.
- [x] **Visual Polish** *(2026-08-25)*: `scripts/managers/VfxManager.gd`, a pure
      EventBus consumer — no gameplay script references it, so a scene without it
      plays identically minus the sparkle. Impact, critical, death, desertion,
      explosion and ambush bursts drive the previously-unused
      `assets/effects/Particle FX/` art through one shared spawn helper. Death
      reads red and violent, desertion pale and drifting, so a rout is
      distinguishable from a kill at a glance.
      - Uses **CPUParticles2D**: this project ships on the GL Compatibility
        renderer, where the GPU path's extra features are unavailable anyway.
      - Screen shake (the last outstanding Dynamic Camera item) animates the
        camera's **`offset`, never `position`** — `position` is what `limit_*`
        clamps, so a position-based shake is silently flattened against the map
        edge, weakest exactly where the fighting tends to be.
      - `MapObjectManager`'s hand-rolled explosion moved here, so there is one
        explosion implementation instead of two in different managers.
      *(Palette-swap shaders for faction colouring are no longer planned —
      superseded by baked per-faction art, see Milestone 3 §3.)*
- [x] **Mount System** *(2026-08-25)*: both halves.
      - **Eight-way facing from five sheets.** Only Lancer ships directional art
        (`Lancer_{Up|UpRight|Right|DownRight|Down}_Attack.png`, ×5 factions) and
        it had been sitting unused — the resources pointed only at
        `Lancer_Idle.png`. The three left-hand directions are those same sheets
        mirrored, so five sheets cover eight facings.
      - **Mount / dismount** via `scripts/data/MountProfile.gd` and `[M]`.
        Mounted is Cavalry at MOV 5 / DEF 10; on foot is Melee at MOV 3 / DEF 14.
        **Dismounting costs the unit's action** — without that price a rider
        could stand still swapping class to present whichever one beats its
        attacker, dodging the advantage triangle for free.
      - **Backwards compatible by construction**: an empty `directional_attack`
        and a null `mount_profile` reproduce the old behaviour exactly, so 86 of
        the 91 unit resources needed no migration and are covered by an explicit
        regression check.
- [x] **Audio Overhaul** *(2026-08-25)*: `default_bus_layout.tres` (Master →
      Music, SFX) plus a rewritten `AudioManager`: an 8-voice SFX pool (the old
      single player cut off its own previous hit), tween crossfade between
      tracks, and combat ducking on the bus rather than the player so it
      survives a track change mid-fight. Track choice follows whose turn it is.
      - The repo shipped **no music at all**, so
        `scripts_dev/generate_music.py` renders three placeholder loops with the
        stdlib only (numpy is absent). Every partial's frequency is snapped to a
        multiple of 1/loop-length, so each completes a whole number of cycles and
        the loop point is measurably gentler than the steepest slope already in
        the track. They are scaffolding for the mixing code, not a soundtrack:
        drop real tracks at the same paths to replace them.
      - Loop mode is forced on the stream at load, because generated WAVs have no
        `.import` loop setting and the score would otherwise play once and stop.
- [ ] **Full Campaign**: Design a multi-chapter narrative campaign with escalating difficulty and persistent army progression.
      **Deferred from this pass**: it needs a save/load layer, which does not
      exist anywhere in the repo yet, and is alone larger than all of Milestone 4.

## Future Considerations (Post-MVP Backlog)
Status: 🔮 Backlog

| Feature | Inspiration | Notes |
|---------|------------|-------|
| Hero/Leader units with Leadership stat | Symphony of War | Squad leaders with passive buffs in a radius |
| Focus / Active Ability system | HoMM: Olden Era | Units generate Focus in combat to trigger unique active abilities |
| Dynamic Weather (Rain, Snow, Fog) | Symphony of War | Affects ranged accuracy, movement penalties, and elemental magic effectiveness |
| Town/Castle building upgrades | HoMM: Olden Era | Progress from Fort → Citadel → Castle, increasing defense and recruitment yield |
| Faction Tech Tree / Laws | HoMM: Olden Era (Seals) | Persistent faction-wide policy bonuses |
| Magic Fatigue system | Symphony of War | Prevents mage spam across consecutive combats by increasing cost or reducing effectiveness |
| Day/Night cycle | General | Affects visibility range, stealth detection, and ambush chances |
| Multiplayer (local hotseat) | Ancient Empire 2 | Pass-and-play two-player same-device capability |
| Map editor | General | Community content creation tool with exportable layouts |

## Related Documentation
- Core Design: See [GDD_Overview.md](GDD_Overview.md)
- Economy Details: See [Macro_Economy.md](Macro_Economy.md)
- Unit Design: See [Factions_and_Units.md](Factions_and_Units.md)
- Terrain Design: See [Terrain_and_Buildings.md](Terrain_and_Buildings.md)
- Architecture: See [Architecture.md](Architecture.md)
- Technical Specs: See [Technical_Specs.md](Technical_Specs.md)
