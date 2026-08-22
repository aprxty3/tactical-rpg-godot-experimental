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

### In Progress
- [ ] Decoupled Data-Driven architecture refactor
- [ ] EventBus autoload (signal hub)
- [ ] Multi-faction EconomyManager
- [ ] TurnManager state machine (4 phases)
- [ ] GridManager + AStarGrid2D pathfinding
- [ ] CombatResolver + damage formula
- [ ] Unit .tres resource files for all unit types
- [ ] Main scene setup (scene tree hierarchy)

## Milestone 2: Playable Prototype
Status: ⬜ Planned

- [ ] Grid-based unit movement (click to move)
- [ ] Attack action with combat triangle
- [ ] Building capture mechanic
- [ ] Gold/Iron income from mines per turn
- [ ] Basic recruitment at Castle
- [ ] End turn / faction switching
- [ ] Victory/Defeat condition checks
- [ ] Basic UI (Resource bar, Unit inspector, Action menu)

## Milestone 3: Economy & Progression
Status: ⬜ Planned

- [ ] Troop Capacity system + Logistics Collapse / Starvation
- [ ] Unit upgrade paths (Pawn → Knight → Cavalier)
- [ ] Field Tax mechanic (2x cost away from Castle)
- [ ] Village capture → TC bonus
- [ ] Iron Mine integration
- [ ] Dual upgrade paths per unit *(inspired by HoMM: Olden Era)*
- [ ] Recruitment pool refresh every N turns *(inspired by HoMM creature growth)*

## Milestone 4: Advanced Tactical Systems
Status: ⬜ Planned

- [ ] Morale system (Fearless → Eager → Fair → Shaken → Fearful) *(inspired by Symphony of War)*
- [ ] Surrender mechanic — force surrender on low-morale enemies *(inspired by Symphony of War)*
- [ ] Ambush from Forest terrain — first strike + morale shock *(inspired by Symphony of War)*
- [ ] Fog of War (FogOfWarTileMapLayer)
- [ ] Environmental hazards: TNT Barrel chain detonation
- [ ] Environmental hazards: Torch fire spread
- [ ] Pandora's Box / Treasure Chest random events

## Milestone 5: AI & Polish
Status: ⬜ Planned

- [ ] Enemy AI: basic unit movement and attack priority
- [ ] Enemy AI: strategic target prioritization (Gold Mines, Villages)
- [ ] Camera system (pan, zoom, screen shake)
- [ ] Combat animations + VFX
- [ ] Sound effects + background music
- [ ] Unit death / desertion animations
- [ ] Palette swap shaders for factions
- [ ] Sprite mounting system for cavalry

## Future Considerations (Post-MVP)
Status: 🔮 Backlog

These are features considered for future expansion, inspired by reference games:

| Feature | Inspiration | Notes |
|---------|------------|-------|
| Hero/Leader units with Leadership stat | Symphony of War | Squad leaders with passive buffs |
| Focus / Active Ability system | HoMM: Olden Era | Units generate Focus in combat to trigger abilities |
| Dynamic Weather (Rain, Snow, Fog) | Symphony of War | Affects ranged accuracy, movement, elemental magic |
| Town/Castle building upgrades | HoMM: Olden Era | Fort → Citadel → Castle progression |
| Faction Tech Tree / Laws | HoMM: Olden Era (Seals) | Persistent faction-wide policy bonuses |
| Magic Fatigue system | Symphony of War | Prevents mage spam across consecutive combats |
| Day/Night cycle | General | Affects visibility, ambush chances |
| Multiplayer (local hotseat) | Ancient Empire 2 | Two-player same-device |
| Map editor | General | Community content creation |

## Related Documentation
- Core Design: See [GDD_Overview.md](GDD_Overview.md)
- Economy Details: See [Macro_Economy.md](Macro_Economy.md)
- Unit Design: See [Factions_and_Units.md](Factions_and_Units.md)
- Terrain Design: See [Terrain_and_Buildings.md](Terrain_and_Buildings.md)
- Architecture: See [Architecture.md](Architecture.md)
- Technical Specs: See [Technical_Specs.md](Technical_Specs.md)
