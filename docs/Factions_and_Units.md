---
type: Game Design Document
title: "Factions & Unit Archetypes"
description: "Warring factions, unit classes, stat blueprints, combat advantage triangle, and progression paths."
tags: [gdd, factions, units, combat-triangle, progression]
generated: { by: human:aprxty3, at: 2026-08-22T00:00:00Z }
---

# Factions & Units Guide

This document defines the warring factions, unit archetypes, stat blueprints, and combat advantage systems in **War Perang Tactics**.

---

## 1. The Five Warring Factions

1. **Blue Kingdom**:
   - *Theme*: Standard chivalric kingdom, disciplined formations, and balanced defense.
   - *Signature Units*: **Knight**, **Warrior**, **Pawn**.
2. **Red Legion**:
   - *Theme*: Aggressive offensive juggernaut focusing on brute physical damage and siege tactics.
   - *Signature Units*: **Warrior**, **Archer**, **TNT Specialist**.
3. **Purple Syndicate**:
   - *Theme*: Cunning shadow guild relying on high mobility, poisons, and ambush strikes.
   - *Signature Units*: **Rogue**, **Vampire**.
4. **Yellow Empire**:
   - *Theme*: Wealthy empire harnessing golden economy and ancient elemental sorcery.
   - *Signature Units*: **Wizzard**, **Priest**, **Castle Defender**.
5. **Black Coven / Necropolis (Undead Faction)**:
   - *Theme*: Dark death cult summoning legions of skeletal minions and cursed vitality.
   - *Signature Units*: **Skeleton Army (Base, Warrior, Rogue, Mage)**, **Skull**, **Vampire**.

---

## 2. Unit Archetypes & Roles

| Unit Class | Primary Role | Move Range | Attack Range | Special Traits & Capabilities |
| :--- | :--- | :---: | :---: | :--- |
| **Pawn** | Worker & Builder | 3 Tiles | 1 Tile (Melee) | Lowest cost. Captures and repairs structures twice as fast. |
| **Warrior** | Frontline Infantry | 3 Tiles | 1 Tile (Melee) | Reliable frontline brawler with balanced HP and physical defense. |
| **Knight** | Heavy Armored Cavalry | 4 Tiles | 1 Tile (Melee) | Immense physical armor. Gains a *Charge Bonus* when moving in a straight line before attacking. |
| **Archer** | Ranged Marksman | 3 Tiles | 2-3 Tiles | Long-range physical attacks without triggering melee counter-attacks. |
| **Rogue** | Skirmisher / Infiltrator | 4 Tiles | 1 Tile (Melee) | Ignores enemy zones of control; inflicts critical *Backstab* damage from behind. |
| **Wizzard** | Area Elemental Mage | 2 Tiles | 2 Tiles (AoE) | Deals area-of-effect magical damage that pierces heavy physical armor. |
| **Priest** | Support & Holy Healer | 3 Tiles | 1-2 Tiles | Restores ally HP, cleanses status ailments, and deals $+150\%$ holy damage vs Undead. |
| **Vampire** | Hybrid Bruiser | 4 Tiles | 1 Tile (Melee) | Recovers health proportional to damage dealt (*Lifesteal*). |
| **Skeleton Army** | Undead Swarm | 3 Tiles | 1-2 Tiles | Inexpensive fodder unit that can be reanimated on death by necromantic spells. |

### Resource Cost Matrix
| Unit | Gold Cost | Iron Cost | TC Weight | Notes |
|------|-----------|-----------|-----------|-------|
| Pawn | 50 | 1 | 1 | Cheapest, captures 2x fast |
| Warrior | 80 | 2 | 2 | Balanced frontliner |
| Knight | 150 | 4 | 3 | Heavy armor, charge bonus |
| Archer | 70 | 1 | 2 | Ranged, no counter-attack |
| Rogue | 90 | 1 | 2 | High mobility, backstab |
| Wizzard | 120 | 0 | 2 | AoE magic, armor piercing |
| Priest | 100 | 0 | 2 | Healer, +150% vs Undead |
| Vampire | 130 | 2 | 3 | Lifesteal bruiser |
| Skeleton | 30 | 0 | 1 | Cheap fodder, reanimatable |

---

## 3. Combat Advantage System (Tactical Triangle)

Combat damage resolution incorporates class matchups and elemental strengths:

```
                  ┌───────────────┐
                  │    Warrior    │
                  │   & Knight    │ (Heavy Melee)
                  └───────┬───────┘
                          │
             Crushes      │    Vulnerable to
             (Smash)      │    (Armor Piercing Magic)
                          ▼
┌────────────────┐                 ┌────────────────┐
│     Archer     │◄────────────────┤    Wizzard     │
│    & Rogue     │    Outranges    │    & Magic     │
└────────────────┘ (Speed / Range) └────────────────┘
```

- **Heavy Melee (Knight, Warrior)** $\rightarrow$ Overpowers **Rogue & Archer** in close-quarters combat.
- **Ranged & Agility (Archer, Rogue)** $\rightarrow$ Eliminates slow **Wizzard** units before casting completes.
- **Magic (Wizzard)** $\rightarrow$ Melts heavy plate armor of **Knight & Warrior**.
- **Holy vs Undead**: **Priest** attacks deal $+150\%$ damage against **Skeleton** and **Vampire** units.

---

## 4. Unit Stat Blueprint (Godot Resource)
Each unit is instantiated using a `UnitData.gd` custom resource:
- `unit_name`, `unit_class`, `tier`, `description`
- `max_health`, `attack_power`, `defense_power`, `movement_points`, `attack_range_min`, `attack_range_max`
- `recruit_cost_gold`, `recruit_cost_iron`, `capacity_weight`
- `upgrade_paths`
- `sprite_frames`, `portrait`

---

## 5. Related Documentation Links
- **Core Loop & Phases**: See [GDD_Overview.md](GDD_Overview.md) for turn progression and game rules.
- **Production & Capture**: See [Terrain_and_Buildings.md](Terrain_and_Buildings.md) for recruitment at Castles and healing in Houses.
- **Godot Implementation**: See [Architecture.md](Architecture.md) for node hierarchy and `CombatResolver.gd`.
