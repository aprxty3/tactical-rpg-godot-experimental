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

As of the Milestone 3 Unit Upgrade Tree pass, **all 5 factions field the identical roster** (Pawn → Warrior/Archer/Wizzard/Monk/Rogue → 8 Tier-3 promotions) — factions differ by color, flavor text, and (Black Coven only) an additional Undead sub-roster, not by which classes they can field. "Signature units" below are flavor/lore framing, not mechanical exclusivity.

1. **Blue Kingdom**:
   - *Theme*: Standard chivalric kingdom, disciplined formations, and balanced defense.
   - *Flavor Units*: **Knight**, **Warrior**, **Pawn**.
2. **Red Legion**:
   - *Theme*: Aggressive offensive juggernaut focusing on brute physical damage and siege tactics.
   - *Flavor Units*: **Warrior**, **Archer**, **Lancer**.
3. **Purple Syndicate**:
   - *Theme*: Cunning shadow guild relying on high mobility, poisons, and ambush strikes.
   - *Flavor Units*: **Rogue**, **Assassin**, **Shadowblade**.
4. **Yellow Empire**:
   - *Theme*: Wealthy empire harnessing golden economy and ancient elemental sorcery.
   - *Flavor Units*: **Wizzard**, **Archmage**, **High Priest**.
5. **Black Coven / Necropolis**:
   - *Theme*: Dark death cult summoning legions of skeletal minions and cursed vitality.
   - *Flavor Units*: the full shared human roster (renamed — e.g. "Black Cultist Pawn", "Necromancer Monk") **plus** an exclusive Undead sub-roster: **Skeleton Army (Fodder, Warrior, Rogue, Mage)**, **Cursed Skull**, **Vampire**. The Undead sub-tree's own tier/promotion structure (→ Lich, Vampire Lord, Nightstalker) is still being reconciled — see `Roadmap.md` Milestone 3.

---

## 2. Unit Archetypes & Roles

**Tier 1 — recruitable at Castle:**

| Unit Class | Primary Role | Move Range | Attack Range | Special Traits & Capabilities |
| :--- | :--- | :---: | :---: | :--- |
| **Pawn** | Worker & Builder | 3 Tiles | 1 Tile (Melee) | Lowest cost. Captures and repairs structures twice as fast. |

**Tier 2 — recruitable at Castle, promotes from Pawn:**

| Unit Class | Primary Role | Move Range | Attack Range | Special Traits & Capabilities |
| :--- | :--- | :---: | :---: | :--- |
| **Warrior** | Frontline Infantry | 3 Tiles | 1 Tile (Melee) | Reliable frontline brawler with balanced HP and physical defense. |
| **Archer** | Ranged Marksman | 3 Tiles | 2-3 Tiles | Long-range physical attacks without triggering melee counter-attacks. |
| **Wizzard** | Area Elemental Mage | 2 Tiles | 2 Tiles (AoE) | Deals area-of-effect magical damage that pierces heavy physical armor. |
| **Monk** | Support & Holy Healer | 3 Tiles | 1-2 Tiles | Restores ally HP and deals $+150\%$ holy damage vs Undead. |
| **Rogue** | Skirmisher / Infiltrator | 4 Tiles | 1 Tile (Melee) | Ignores enemy zones of control; inflicts critical *Backstab* damage from behind. |

**Tier 3 — promotion-only via `[U]` Upgrade, never recruited directly:**

| Unit Class | Promotes From | Primary Role | Move Range | Attack Range | Special Traits & Capabilities |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Knight** | Warrior | Heavy Armored Infantry | 4 Tiles | 1 Tile (Melee) | Immense physical armor. Gains a *Charge Bonus* when moving in a straight line before attacking. |
| **Lancer** | Warrior | Mounted Cavalry | 5 Tiles | 1 Tile (Melee) | Momentum charge bonus damage on the turn it moves before attacking. |
| **Sniper** | Archer | Extreme-Range Marksman | 3 Tiles | 3-4 Tiles | Longest range in the game; trades some HP for reach. |
| **Crossbowman** | Archer | Armor-Piercing Ranged | 3 Tiles | 2-3 Tiles | Higher defense and flat damage than Sniper, shorter range. |
| **Archmage** | Wizzard | Area Devastation Mage | 2 Tiles | 2-3 Tiles | Highest raw magic damage output, fragile. |
| **Elementalist** | Wizzard | Status/Burn Mage | 3 Tiles | 2 Tiles | More mobile and durable than Archmage, lower peak damage. |
| **High Priest** | Monk | Mass Healer | 3 Tiles | 1-2 Tiles | Strongest holy support; $+150\%$ damage vs Undead. |
| **Paladin** | Monk | Melee/Holy Hybrid | 3 Tiles | 1 Tile (Melee) | Frontline durability with the Holy-vs-Undead bonus. |
| **Assassin** | Rogue | Glass-Cannon Backstab | 4 Tiles | 1 Tile (Melee) | Highest single-target burst, lowest defense. |
| **Shadowblade** | Rogue | Mobile Ambusher | 5 Tiles | 1 Tile (Melee) | More HP/defense than Assassin, slightly less burst. |

**Black Coven exclusive (Undead lineage, not yet reconciled into the tier system above):**

| Unit Class | Primary Role | Move Range | Attack Range | Special Traits & Capabilities |
| :--- | :--- | :---: | :---: | :--- |
| **Vampire** | Hybrid Bruiser | 4 Tiles | 1 Tile (Melee) | Recovers health proportional to damage dealt (*Lifesteal*). |
| **Skeleton Army** | Undead Swarm | 3 Tiles | 1-2 Tiles | Inexpensive fodder unit that can be reanimated on death by necromantic spells. |

### Resource Cost Matrix
| Unit | Tier | Gold Cost | Iron Cost | TC Weight | Notes |
|------|:---:|-----------|-----------|-----------|-------|
| Pawn | 1 | 50 | 1 | 1 | Cheapest, captures 2x fast |
| Warrior | 2 | 80 | 2 | 2 | Balanced frontliner |
| Archer | 2 | 70 | 1 | 2 | Ranged, no counter-attack |
| Wizzard | 2 | 120 | 0 | 2 | AoE magic, armor piercing |
| Monk | 2 | 100 | 0 | 2 | Healer, +150% vs Undead |
| Rogue | 2 | 90 | 1 | 2 | High mobility, backstab |
| Knight | 3 | 150 | 4 | 3 | Heavy armor, charge bonus (promotion only) |
| Lancer | 3 | 140 | 3 | 3 | Cavalry charge (promotion only) |
| Sniper | 3 | 130 | 2 | 3 | Extreme range (promotion only) |
| Crossbowman | 3 | 130 | 2 | 3 | Armor pierce (promotion only) |
| Archmage | 3 | 150 | 1 | 3 | Huge AoE (promotion only) |
| Elementalist | 3 | 140 | 1 | 3 | Status/burn (promotion only) |
| High Priest | 3 | 150 | 1 | 3 | Mass heal (promotion only) |
| Paladin | 3 | 150 | 2 | 3 | Melee/Holy hybrid (promotion only) |
| Assassin | 3 | 140 | 1 | 3 | Lethal backstab (promotion only) |
| Shadowblade | 3 | 140 | 1 | 3 | Stealth/ambush (promotion only) |
| Vampire | 3 | 130 | 2 | 3 | Lifesteal bruiser (Black Coven only) |
| Skeleton | 1 | 30 | 0 | 1 | Cheap fodder, reanimatable (Black Coven only) |

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
- **Holy vs Undead**: **Monk**, **High Priest**, and **Paladin** attacks deal $+150\%$ damage against **Skeleton** and **Vampire** units.

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
