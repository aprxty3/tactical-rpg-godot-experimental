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
Status: 🟡 In Progress — core tree, promotion mechanic, and roster symmetry shipped; economy tasks below remain

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

[ Undead Lineage (Black Coven) — separate from the tree above, not yet reconciled ]
Skeleton (Fodder) ─────────────► Skeleton Warrior ──────────────► Lich (Necromancer)
Vampire (Bruiser) ─────────────► Vampire Lord ──────────────────► Nightstalker (Flight/Lifesteal)
```

Since Knight/Lancer (Melee) and Archer (Ranged) already had full art, and Monk/Wizzard/Rogue already existed on at least one faction, "shipping" this tree meant: fixing `Warrior`'s tier (was incorrectly `1`, same as Pawn), filling in the missing Tier-2 units per faction (Wizzard/Rogue), generating all 8 new Tier-3 branches (×5 factions), and building a runtime faction palette-tint shader (`assets/shaders/faction_tint.gdshader`) so the units without hand-painted per-faction art (Knight/Rogue/Wizzard and their Tier-3 offshoots) still render in the correct faction color instead of one shared generic sprite.

### 2. Progression & Economy Tasks
- [x] **UnitData Progression Blueprint**: `upgrade_paths: Dictionary[String, Resource]` on `UnitData.gd`, now populated on every Tier-1/Tier-2 unit across all 5 factions.
- [x] **Dynamic Upgrade Action & UI**: `[U]` key opens an Upgrade popup (`MainHUD.show_upgrade_popup`) listing the selected unit's `upgrade_paths`; mirrors the existing `[R]` Recruit popup.
- [x] **Field Tax Implementation**: `EconomyManager.get_upgrade_cost()` / `process_upgrade()` already existed and are now actually wired up; off-Castle promotions correctly cost $200\%$ of the tier-difference price.
- [ ] **Troop Capacity System & Logistics Collapse**: Starvation logic exists in `EconomyManager`; still needs Village-capture integration.
- [ ] **Village Economy Nodes**: Capturing villages grants $+2$ TC cap and $+10$ Gold passive revenue.
- [x] **Dual Upgrade Specializations**: Every Tier-2 unit offers exactly two Tier-3 choices (e.g. Warrior → Knight *or* Lancer).
- [ ] **Recruitment Pool Refresh**: Replenishment timers for elite tier units at Castles every $N$ turns.
- [ ] **Undead Lineage Reconciliation**: Black Coven's Skeleton/Vampire sub-tree (Lich, Vampire Lord, Nightstalker) still needs the same tier-fix + promotion-only treatment as the human tree above — deferred as a follow-up.


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
