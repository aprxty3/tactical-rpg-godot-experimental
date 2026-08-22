---
type: Game Design Document
title: "Macro-Economy & Field Logistics"
description: "Resource management, territory control, troop capacity, field tax mechanics, and dynamic map events."
tags: [gdd, economy, logistics, resources, field-tax]
generated: { by: human:aprxty3, at: 2026-08-22T00:00:00Z }
sources:
  - id: symphony-of-war
    resource: https://symphonyofwar.wiki.gg/
    title: "Symphony of War: The Nephilim Saga Wiki"
  - id: homm-olden-era
    resource: https://wiki.hoodedhorse.com/Heroes_of_Might_and_Magic_Olden_Era/Main_Page
    title: "Heroes of Might and Magic: Olden Era Wiki"
---

# Macro-Economy & Advanced Field Mechanics

**Update**: Expansion of resource management, territory control, and unit progression inspired by classic macro-strategy logic.

---

## 1. Resource Nodes & Territory Control
The battlefield is dotted with strategic nodes that factions must capture to sustain their war machine. 

*   **Castle (Headquarters)**: 
    *   Limit: 1 Main Castle per faction per map.
    *   Function: Primary deployment zone for new units and base of operations. Capturing an enemy's castle grants access to their deployment zone.
*   **Gold Mine**: 
    *   Yield: +X Gold per turn.
    *   Utility: Essential for recruiting mercenary-like units, spellcasters (Wizard, Priest), and funding field upgrades.
*   **Iron Mine**: 
    *   Yield: +Y Iron per turn.
    *   Utility: Critical for forging heavy armor and weapons. Heavy units (Knight, Cavalier) require high Iron upkeep.
*   **Village**: 
    *   Yield: +1 to +2 Troops Capacity.
    *   Utility: Expands the maximum number of units a faction can deploy simultaneously on the board.

---

## 2. The Logistics Pipeline: Deployment & Upgrades

### A. Troop Capacity & The "Starvation" Penalty
Each faction starts with a base troop limit (e.g., `0/8`). Deploying units consumes this capacity based on unit tier (Pawn = 1, Knight = 2, Cavalier = 3).
*   **Dynamic Cap**: Capturing Villages increases the cap; losing Villages decreases it.
*   **Overcapacity Consequence**: If a faction's capacity drops below their active deployed units (e.g., `10/6` due to lost Villages), the army suffers a **Logistics Collapse**. 
    *   *Effect*: Unsupplied units suffer an HP penalty (Starvation) each Upkeep Phase. If HP drops too low from starvation, units may "Desert" (despawn from the board). *No rations, no loyalty.*

### B. Dynamic Upgrade Costs (The Field Tax)
Units possess a progression tree (e.g., Pawn -> Knight -> Cavalier) and can be upgraded seamlessly.
*   **Castle Upgrade**: Normal cost. (e.g., Pawn to Knight = 50 Gold + 1 Iron). The logistics are handled locally.
*   **Field Upgrade**: $200\%$ cost penalty. (e.g., Pawn to Knight = 100 Gold + 2 Iron). Sending heavy armor and weapons directly to the frontlines is expensive and highly inefficient, but sometimes tactically necessary for a surprise breakthrough.

### C. Resource Balancing by Class
*   **Heavy Melee (Knight, Cavalier)**: Requires high Iron, moderate Gold.
*   **Magic / Support (Wizard, Priest)**: Requires high Gold, 0 Iron (robes and ancient tomes don't require smelting).

---

## 3. Dynamic Map Events: Treasures & Ruins
Scattered across the map are nodes that offer high-risk, high-reward interactions to disrupt static gameplay.

*   **Treasure Chests / Ruins**: Requires a unit to interact (spend an action).
*   **Randomized Outcomes (Pandora's Box)**:
    *   *Windfall*: Grants a burst of Gold or Iron.
    *   *Reinforcements*: Spawns a free, temporary mercenary unit.
    *   *Ambush (Dud)*: Triggers a trap (AoE Poison) or awakens a slumbering neutral threat (e.g., Black Coven Skeletons) that immediately becomes hostile to the nearest unit.

---

## 4. Asset Optimization Guidelines (Developer Notes)
To manage asset workload for the unit progression tree:
*   **Palette Swapping (Shaders)**: Elite or upgraded units use the base unit's sprite with altered color schemes via Godot Shaders (e.g., Blue Pawn upgrades to Silver/Gold Elite Pawn).
*   **Sprite Mounting**: Cavalry units are created by dynamically rendering an infantry sprite over a separate horse sprite within the Godot `SceneTree`, avoiding the need for dedicated Cavalry animation sheets.

---

## 5. Related Documentation Links
- **Core GDD**: See [[GDD_Overview]] for high concept, core loop, and victory conditions.
- **Units & Factions**: See [[Factions_and_Units]] for class definitions, combat triangle, and faction traits.
- **Terrain & Structures**: See [[Terrain_and_Buildings]] for building functions and terrain modifiers.
