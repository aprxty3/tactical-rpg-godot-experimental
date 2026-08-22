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
- [x] In-Game AI Narrative Engine: `GeminiClient.gd` autoload powered by **Gemini 3.7 Flash** for dynamic combat banter and territory capture declarations.


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

**Known remaining gap**: `skull_black.tres` ("Cursed Skull", tier 1, Undead) exists as a resource but is not wired into any recruit list or upgrade path — out of scope for this pass, flagged for a future one.


## Milestone 4: Advanced Tactical Systems & Morale
Status: ⬜ Planned

- [ ] **Morale System**: Units shift between 5 states (Fearless → Eager → Fair → Shaken → Fearful) based on nearby deaths or being flanked *(inspired by Symphony of War)*.
- [ ] **Surrender Mechanic**: Force surrender on low-morale enemies to capture them or gain resources *(inspired by Symphony of War)*.
- [ ] **Terrain Ambush**: First strike and morale shock bonuses when attacking from Forest terrain *(inspired by Symphony of War)*.
- [ ] **Fog of War**: Implement `FogOfWarTileMapLayer` to obscure enemy movements.
- [ ] **Environmental Hazards**: Chain detonations via TNT Barrels and dynamic fire spread mechanics.
- [ ] **Pandora's Box / Treasure Chests**: Random events and loot drops scattered across the map.

## Milestone 5: AI Enhancements, Campaign & Polish
Status: ⬜ Planned

- [ ] **Advanced Enemy AI**: Strategic target prioritization (Gold Mines, Villages) and defensive maneuvering when at a disadvantage.
- [ ] **Dynamic Camera System**: Edge panning, scroll-wheel zoom, and screen shake on heavy impacts.
- [ ] **Visual Polish**: Advanced combat VFX (particles), unit death / desertion animations, and palette swap shaders for faction coloring.
- [ ] **Mount System**: Sprite mounting mechanics for cavalry units.
- [ ] **Full Campaign**: Design a multi-chapter narrative campaign with escalating difficulty and persistent army progression.
- [ ] **Audio Overhaul**: Full background music (BGM) pipeline and dynamic mixing.

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
