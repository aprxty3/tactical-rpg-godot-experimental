---
type: Technical Specification
title: "Technical Specs — Economy, Upgrades & Map Systems"
description: "Detailed technical specifications for economy constraints, field tax formula, map node interactions, and upgrade mechanics."
tags: [technical, economy, field-tax, map-nodes, upgrades]
generated: { by: human:aprxty3, at: 2026-08-22T00:00:00Z }
---

# Technical Specs: Economy & Upgrades

This document outlines the GDScript implementation for dynamic upgrade costs (Field Tax) and the Troop Capacity (Starvation) systems using Godot's `Resource` and Autoload Managers.

## 1. Core Resource & Economy Constraints

The economy in this game is driven by three main variables. Management of these determines whether a faction will dominate the map or crumble due to logistical collapse.

| Resource Type | Acquisition Method | Primary Utility | Over-cap / Deficit Consequence |
| :--- | :--- | :--- | :--- |
| **Gold (G)** | Gold Mines (+50/turn), Houses (+10/turn) | Baseline currency for recruiting all units, especially Magic/Support units. | Cannot drop below 0. Deficit prevents recruitment/upgrades. |
| **Iron (Fe)** | Iron Mines (+30/turn) | Forging heavy armor and physical weaponry (Knights, Cavaliers). | Cannot drop below 0. Heavy units are locked without it. |
| **Troop Capacity (TC)** | Base Capacity (8) + Villages (+2/village) | Determines the maximum weight of active units on the board. | **Logistics Collapse:** Triggers starvation penalty if deployed TC > Max TC. |

### Unit Capacity Weighting System
Capacity is not calculated as "1 unit = 1 TC". Elite units require greater logistics and rations:
*   **Tier 1 (Pawn, Skeleton, Rogue):** 1 TC
*   **Tier 2 (Warrior, Archer, Priest, Wizzard):** 2 TC
*   **Tier 3 (Knight, Cavalier, Vampire):** 3 TC

---

## 2. Interactive Map Nodes (Strategic Points)

These nodes are the primary points of contention (Points of Interest). AI Pathfinding (via `AStarGrid2D`) will prioritize these nodes as secondary objectives besides attacking enemy units.

### A. Sustained Economy Nodes
*   **Castle (Headquarters):** Unit spawn point. Has 500 HP. If HP reaches 0, the owning faction is eliminated. The faction that takes over gains spawn access in the area.
*   **Gold Mine / Iron Mine:** Passive nodes. Once occupied (changes color according to faction), automatically injects resources at the start of every Upkeep Phase.
*   **Village:** Adds +2 TC. Vulnerable to area of effect attacks. If destroyed by a TNT Barrel, the faction's TC is automatically reduced.

### B. High-Risk / High-Reward Nodes (Pandora's Box)
These nodes are consumable and use a probability system (RNG) calculated when a unit steps on them.

*   **Ancient Ruins / Treasure Chest:**
    *   **50% - War Spoils:** Gain +100 Gold or +50 Iron.
    *   **20% - Mercenary Contract:** Automatically spawns 1 random unit in an adjacent tile without costing Gold/Iron (but still consumes TC).
    *   **15% - Booby Trap:** Explodes, dealing 30 True Damage in a 3x3 area.
    *   **15% - Awaken the Dead:** Spawns 2 neutral Skeleton units that are instantly aggressive (Aggro) towards the nearest unit. (A dark humor moment that forces players to adapt their formation).

---

## 3. The "Field Tax" Mechanics (Dynamic Upgrades)

To simulate the harsh reality of war, unit upgrade costs are highly dependent on their geographical location. Sending heavy weapons to the front lines is much more expensive than forging weapons at the castle.

**Upgrade Formula:**
`Cost = (Target_Resource_Cost - Current_Resource_Cost) * Location_Multiplier`

*   **Castle Upgrade (Multiplier = 1x):**
    The unit is on an adjacent tile to the Castle. Normal price.
*   **Field Upgrade (Multiplier = 2x):**
    The unit is on the battlefield (more than 1 tile away from the Castle). 
    *Example:* Upgrade Pawn -> Knight in the field.
    *(100G - 50G) * 2 = 100 Gold.*
    *(2Fe - 1Fe) * 2 = 2 Iron.*

---

## 4. Technical Implementation Notes

### EconomyManager (Autoload)
Handles logic for calculating field tax and checking troop capacities:
- `calculate_field_tax(base_cost, distance_to_castle) -> int`
- `validate_upgrade_transaction(unit_data, target_data, position) -> bool`
- `get_total_used_capacity(faction_id) -> int`

### TurnManager Upkeep Phase Sequence:
1. Inject Gold & Iron from controlled mines.
2. Check `get_total_used_capacity()` vs `Max_Capacity`.
3. If Used > Max:
   - Trigger `execute_starvation()`.
   - Reverse loop through active units.
   - Apply 15 True Damage (type: "starvation").
   - If HP <= 0, `queue_free()` (Unit Desertion).
4. Reset action points & movement points for surviving units.
