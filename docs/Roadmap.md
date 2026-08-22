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

## Milestone 1: Core Foundation (Current)
Status: 🔴 In Progress

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
Status: ⬜ Planned

- [ ] Implement additional Unit Classes (Archer, Rogue, Wizzard, Priest, Vampire, Skeleton).
- [ ] Integrate Spritesheet Animations for movement, attacking, and death.
- [ ] Implement robust Victory/Defeat condition checks based on Castle captures or Annihilation.
- [ ] Build a comprehensive UI (Resource bar, Unit inspector panel, Action context menu).
- [ ] Add sound effects (SFX) for combat impacts and movement.

## Milestone 3: Economy & Advanced Progression
Status: ⬜ Planned

- [ ] Finalize Troop Capacity system + Logistics Collapse / Starvation mechanics.
- [ ] Implement Unit Upgrade paths (e.g., Pawn → Knight → Cavalier).
- [ ] Implement Field Tax mechanic (Upgrades cost 200% when away from a friendly Castle).
- [ ] Village capture mechanic for expanding Troop Capacity (+2 TC per village).
- [ ] Dual upgrade paths per unit *(inspired by HoMM: Olden Era)*.
- [ ] Recruitment pool refresh every N turns *(inspired by HoMM creature growth)*.

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
