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

## 1. Four Armies and One Den

**Four factions contend. A fifth holds the centre and cannot win.**

Since the Milestone 3 upgrade-tree pass, all playable factions field the
**identical roster** (Pawn → Warrior/Archer/Wizzard/Monk/Rogue → 8 Tier-3
promotions). They differ by colour and flavour, not by which classes they can
field. "Flavour units" below are lore framing, not mechanical exclusivity.

| Faction | Theme | Flavour units |
| :--- | :--- | :--- |
| 🔵 **Blue Kingdom** | Chivalric kingdom, disciplined formations, balanced defence | Knight, Warrior, Pawn |
| 🔴 **Red Legion** | Offensive juggernaut — brute physical damage and siege | Warrior, Archer, Lancer |
| 🟣 **Purple Syndicate** | Shadow guild — mobility, poison, ambush | Rogue, Assassin, Shadowblade |
| 🟡 **Yellow Empire** | Wealthy empire — golden economy, elemental sorcery | Wizzard, Archmage, High Priest |

### ⚫ The Black Coven — a den, not a faction

The Black Coven **fields no army and cannot be chosen**. It garrisons the Black
Castle at the centre of the map with six monsters and takes a turn like anyone
else, but it is excluded from the victory check — `TurnManager` calls it a
*marauder*. Clearing it wins nothing on its own.

It plays by inverted rules, and each one is a deliberate negative:

- **It cannot claim a castle, a gold mine or an iron mine.** It holds no
  ground, so those are scenery to it.
- **A held village it BURNS** rather than flying a flag over. A *neutral*
  village it leaves alone — an unclaimed house is nobody's supply line, and
  razing neutral ground would only strip the map.
- **Its monsters never accept a surrender**, and never offer one.
- **Every monster is leashed** to roughly 11 cells of the den. They guard; they
  do not march on your capital.

**Taking the den is worth something anyway.** The Black Castle's recruit roster
includes **Skeleton Fodder** and **Vampire**, and `UnitData.variant_for_faction`
has no blue/red/purple/yellow variant to swap those to — so the fallback keeps
the black ones. Capture the keep and you recruit undead alongside your own
colour's troops. That is emergent from the resolver's fallback rule rather than
special-cased, which is why it survives adding a sixth faction.

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

**The Undead lineage — a parallel track reusing the same `[U]` Upgrade mechanic.** Recruitable from the **Black Castle by whoever holds it**, which in practice means whoever cleared the den:

Tier 1 (recruitable at Castle):

| Unit Class | Primary Role | Move Range | Attack Range | Special Traits & Capabilities |
| :--- | :--- | :---: | :---: | :--- |
| **Skeleton Fodder** | Undead Swarm | 3 Tiles | 1 Tile (Melee) | Inexpensive fodder unit, entry point into the Skeleton branch. |

Tier 2 (promotes from Skeleton Fodder, except Vampire which recruits directly at Castle):

| Unit Class | Promotes From | Primary Role | Move Range | Attack Range | Special Traits & Capabilities |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Skeleton Warrior** | Skeleton Fodder | Undead Melee | 3 Tiles | 1 Tile (Melee) | Reanimated warrior fighting with a rusty blade. |
| **Skeleton Mage** | Skeleton Fodder | Undead Caster | 2 Tiles | 2 Tiles | Casts cursed soul bolts at range. |
| **Skeleton Rogue** | Skeleton Fodder | Undead Skirmisher | 4 Tiles | 1 Tile (Melee) | Nimble undead striking from the dead of night. |
| **Vampire** | *(recruits directly)* | Hybrid Bruiser | 4 Tiles | 1 Tile (Melee) | Recovers health proportional to damage dealt (*Lifesteal*). |

Tier 3 (promotion-only, one option per Tier-2 parent for the Skeleton branch, two for Vampire):

| Unit Class | Promotes From | Primary Role | Move Range | Attack Range | Special Traits & Capabilities |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Bone Reaper** | Skeleton Warrior | Heavy Undead Melee | 4 Tiles | 1 Tile (Melee) | Hulking brute wielding a massive cursed blade. |
| **Lich** | Skeleton Mage | Necromancer Caster | 2 Tiles | 2-3 Tiles | Undead master of death magic, highest Undead-line damage. |
| **Wraith** | Skeleton Rogue | Stealth Ambusher | 5 Tiles | 1 Tile (Melee) | Hooded undead stalker that vanishes between strikes. |
| **Vampire Lord** | Vampire | Heavier Bruiser | 4 Tiles | 1 Tile (Melee) | Ascended vampire, gorged on stolen vitality; retains Lifesteal. |
| **Nightstalker** | Vampire | Mobile/Evasive | 5 Tiles | 1 Tile (Melee) | Feral, highly mobile vampire that hunts down fleeing prey; retains Lifesteal. |

**Black Castle garrison — the six wandering encounters.** Never recruited, never
promoted, and free to field, so they are deliberately **not** balanced against
faction units of the same tier. Their job is to make the centre of the map cost
something, not to be a fair fight.

| Monster | Role | HP | ATK | DEF | Move | Range | Vision |
| :--- | :--- | ---: | ---: | ---: | :---: | :---: | :---: |
| **Ghoul** | Starved swarm | 38 | 14 | 2 | 4 | 1 | 4 |
| **Bone Stalker** | Scout — fast, brittle, always seen first | 30 | 12 | 1 | **6** | 1 | **6** |
| **Grave Warden** | The wall; holds the approach | **70** | 20 | **12** | 3 | 1 | 4 |
| **Plague Wraith** | Rot at range; reaching it is the fight | 40 | 22 | 3 | 3 | **2** | 5 |
| **Blood Fiend** | Feeds on what it kills | 62 | **26** | 8 | 4 | 1 | 5 |
| **Dread Warden** *(boss)* | Stands on the keep's own tile | **140** | **34** | **16** | 3 | **2** | **7** |

Nothing guards the den beyond the boss itself — and nothing needs to. It
occupies the castle's cell, and a unit cannot end its move on an occupied one,
so "kill the guardian first" is enforced by the board rather than by a rule.

Six creatures come from **three** source bodies (skeleton ×2, vampire),
recoloured offline. See `scripts_dev/generate_monsters.py`.

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
| Skeleton Fodder | 1 | 30 | 0 | 1 | Cheap Undead fodder, entry point (Black Coven only) |
| Skeleton Warrior | 2 | 40 | 1 | 2 | Undead melee (promotion only, Black Coven only) |
| Skeleton Mage | 2 | 70 | 0 | 2 | Undead caster (promotion only, Black Coven only) |
| Skeleton Rogue | 2 | 60 | 1 | 2 | Undead skirmisher (promotion only, Black Coven only) |
| Vampire | 2 | 110 | 2 | 2 | Lifesteal bruiser, direct recruit (Black Coven only) |
| Bone Reaper | 3 | 150 | 3 | 3 | Heavy Undead melee (promotion only, Black Coven only) |
| Lich | 3 | 150 | 1 | 3 | Necromancer caster (promotion only, Black Coven only) |
| Wraith | 3 | 140 | 1 | 3 | Undead stealth ambusher (promotion only, Black Coven only) |
| Vampire Lord | 3 | 150 | 2 | 3 | Heavier lifesteal bruiser (promotion only, Black Coven only) |
| Nightstalker | 3 | 140 | 1 | 3 | Mobile lifesteal ambusher (promotion only, Black Coven only) |

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
