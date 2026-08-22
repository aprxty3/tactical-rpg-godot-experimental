---
type: Game Design Document
title: "Terrain & Battlefield Structures"
description: "Capturable buildings, battlefield hazards, terrain biomes, and movement/defense modifiers."
tags: [gdd, terrain, buildings, hazards, movement]
generated: { by: human:aprxty3, at: 2026-08-22T00:00:00Z }
---

# Terrain & Buildings Guide

This document details interactive battlefield structures, environmental hazards, and terrain modifiers in **War Perang Tactics**.

---

## 1. Battlefield Structures & Capturable Buildings

Structures provide logistical, economic, and defensive footholds. Any ground unit can capture structures by occupying the tile.

| Structure | Strategic Role & Mechanics | Faction Benefit | Capture Requirements |
| :--- | :--- | :--- | :--- |
| **Castle (Headquarters)** | Central command outpost and premier unit spawn point. | Enables recruitment of all high-tier units (**Knight**, **Wizzard**). Dictates victory/loss conditions. | Occupy tile for 2 full turns. |
| **Gold Mine** | Primary economy engine. Generates revenue every turn during the *Upkeep Phase*. | Provides $+50$ Gold per turn to the controlling faction. | Captured instantly upon occupation by infantry. |
| **Tower / Wood Tower** | Defensive bastion & watchtower. Automatically fires arrows at approaching enemies. | Grants $+30\%$ Defense bonus to garrisoned units; attacks hostile units within 3 tiles range. | Defeated when structure HP reaches 0 or captured. |
| **House / Wood House** | Civilian dwelling and field triage. | Increases maximum unit population cap by $+2$ and yields $+10$ Gold. Units stationed here regenerate $20\%$ HP per turn. | Stepped on by any unit. |

---

## 2. Interactive Battlefield Hazards

Environments are interactive, allowing players to manipulate hazards for tactical advantage:

1. **TNT Barrel (Explosive Hazard)**:
   - Fragile structure with 1 HP.
   - When attacked by fire arrows, torches, or **Wizzard** spells, detonates in a $3 \times 3$ area.
   - Inflicts massive *True Damage* to all units caught in the blast and destroys adjacent wooden objects.
2. **Wooden Barrel & Crate**:
   - Acts as movement obstacles (*Path Blockers*).
   - Destructible by physical attacks; can drop health consumables or bonus gold upon breaking.
3. **Torch**:
   - Interactive light source and ignition trigger.
   - Can be activated to ignite grass/forest tiles or trigger explosive chain reactions with TNT Barrels.

---

## 3. Terrain Biomes & Movement Modifiers

Each grid cell has distinct properties modifying *Movement Cost* and *Defense Multipliers*:

| Terrain Biome | Movement Cost | Defense Bonus | Tactical Notes |
| :--- | :---: | :---: | :--- |
| **Plains / Grass** | 1 MP | $0\%$ | Standard open terrain with no penalties. |
| **Forest / Trees** | 2 MP | $+20\%$ | Provides cover from ranged attacks; restricts heavy cavalry (**Knight**) movement. |
| **Dungeon Tiles / Cobblestone** | 1 MP | $+5\%$ | Solid stone floor; immune to burning terrain effects. |
| **Mountain / Cliffs** | Impassable | $+40\%$ | Impassable for ground units; accessible only by flying units or special teleportation skills. |
| **Water / River** | 3 MP (Special) | $-10\%$ | Requires bridges or aquatic movement capabilities. |

---

## 4. Ambush Mechanics (Forest Terrain)

Units positioned in Forest tiles gain a concealment advantage. When an enemy unit moves adjacent to a concealed unit, an **Ambush** may trigger:

- **First Strike**: The concealed unit attacks first before the enemy can react.
- **Morale Shock**: The ambushed unit suffers a temporary morale penalty (-1 morale level).
- **Conditions**: Only Light Infantry (Rogue, Archer) and certain faction-specific units can trigger ambushes. Heavy units (Knight, Warrior) are too conspicuous.

> *Inspired by Symphony of War's stealth and ambush system.*

---

## 5. Related Documentation Links
- **Economy Integration**: See [GDD_Overview.md](GDD_Overview.md) for gold revenue phases and upkeep mechanics.
- **Unit Production**: See [Factions_and_Units.md](Factions_and_Units.md) for units deployable from Castles.
- **Godot Scene Setup**: See [Architecture.md](Architecture.md) for `TileMapLayer` and pathfinding configuration.
