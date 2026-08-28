---
type: Index
title: "War Perang Tactics — Documentation Hub"
description: "Central index for all game design, technical, and planning documents."
tags: [index, documentation, navigation]
generated: { by: human:aprxty3, at: 2026-08-22T00:00:00Z }
---

# War Perang Tactics — Documentation

## Game Design Documents
- [GDD Overview](GDD_Overview.md) — Core vision, gameplay loop, victory conditions, design pillars.
- [Macro Economy](Macro_Economy.md) — Resource nodes, troop capacity, field tax, dynamic map events.
- [Factions & Units](Factions_and_Units.md) — Four playable armies, the Black Castle den and its six monsters, unit archetypes, combat triangle, progression.
- [Terrain & Buildings](Terrain_and_Buildings.md) — Capturable structures, hazards, terrain modifiers, ambush mechanics.

## Technical Documents
- [Architecture](Architecture.md) — Scene tree hierarchy, Decoupled Data-Driven pattern, signal flow.
- [Technical Specs](Technical_Specs.md) — Economy constraints, field tax formula, map node interactions.

## Planning & Release
- [Roadmap](Roadmap.md) — Development milestones, feature pipeline, reference game inspirations.
- [Release Guide](Release_Guide.md) — Version-number rules, export presets, the checks a build must pass, and the itch.io page settings.

## Where a fact lives

When two documents disagree, the code wins — and these are the files that hold
the answers, so check them before trusting a table here:

| Question | Authority |
| :--- | :--- |
| Terrain costs, combat multipliers, morale, AI weights, capacity | `scripts/autoload/GameConfig.gd` |
| What damage a hit actually deals | `scripts/managers/CombatResolver.gd` |
| Who may capture, raze, or neither | `Building.claim_for()` |
| Who takes a turn vs who can win | `TurnManager.faction_order` / `.contenders` |
| What this match is (participants, seed, player) | `scripts/autoload/MatchSetup.gd` |
