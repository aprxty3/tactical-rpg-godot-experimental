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
    *   Yield: **+20 Gold per turn**. A castle is a passive node in its own right, so a faction that has lost every mine still has a trickle of income to rebuild on.
    *   Capacity: **+5 Troop Capacity per castle held beyond the first.** The opening keep is already priced into the base of 8, so a starting faction reads 5/8 — and an army that has lost its castle is not additionally starved.
    *   **Garrison**: a unit standing on a castle its own faction holds recovers **40% of max health** each Upkeep — double a village, and the only other building that resupplies at all.
    *   Function: the deployment zone. Capturing an enemy castle gives you *their* recruit roster resolved to your own colour — and where no variant of your colour exists, the original stands. Taking the **Black Castle** therefore hands you the undead.
*   **Gold Mine**: 
    *   Yield: **+50 Gold per turn**.
    *   Utility: Essential for recruiting mercenary-like units, spellcasters (Wizard, Priest), and funding field upgrades.
*   **Iron Mine**: 
    *   Yield: **+3 Iron per turn**. Iron is a scarce gate rather than a currency — no unit costs more than 4 Iron and a faction opens with 6, so the yield is deliberately an order of magnitude below Gold's.
    *   Utility: Critical for forging heavy armor and weapons. Heavy units (Knight, Cavalier) require high Iron upkeep.
*   **Village**: 
    *   Yield: **+3 Troop Capacity**, plus **+10 Gold per turn**.
    *   Utility: Expands the maximum number of units a faction can deploy simultaneously on the board.
    *   **Garrison**: a unit standing on a village *its own faction holds* recovers **20% of its maximum health** each Upkeep. Villages were worth taking for the capacity and worth nothing afterwards; this makes them worth standing in, and gives a mauled army somewhere to fall back *to* rather than only forward.
    *   **Vulnerable**: a village is the one building a marauder can affect, and it **burns** it rather than capturing it — the capacity goes with it (see `Terrain_and_Buildings.md`).

> The two healing buildings are the two worth standing in. A mauled army now has
> somewhere to fall back *to* rather than only forward — and because the castle
> heals hardest, the ground worth defending is also the ground worth retreating to.

---

## 2. The Logistics Pipeline: Deployment & Upgrades

### A. Troop Capacity & The "Starvation" Penalty
Each faction starts at **8** (`BASE_TROOP_CAPACITY`). Deploying units consumes it by `capacity_weight` — Tier 1 costs 1, Tier 2 costs 2, Tier 3 costs 3.

    max = 8  +  3 x villages  +  5 x max(0, castles - 1)

*   **Dynamic Cap**: villages and castles both raise it, and both lower it again when lost. A razed village takes its 3 with it.
*   **Seeded, not accumulated**: castle counts are read off the board when a faction registers, because a faction already *owns* its opening keep and no capture event ever fires for it. Villages need no such seeding — every one of them starts neutral.
*   **Overcapacity Consequence**: If a faction's capacity drops below their active deployed units (e.g., `10/6` due to lost Villages), the army suffers a **Logistics Collapse**. 
    *   *Effect*: Unsupplied units suffer an HP penalty (Starvation) each Upkeep Phase. If HP drops too low from starvation, units may "Desert" (despawn from the board). *No rations, no loyalty.*

### B. Dynamic Upgrade Costs (The Field Tax)
Units possess a progression tree (e.g., Pawn -> Knight -> Cavalier) and can be upgraded seamlessly.
*   **Castle Upgrade**: normal cost — the logistics are handled locally.
*   **Field Upgrade**: `FIELD_TAX_MULTIPLIER = 2`, so **double**. Sending armour and weapons to the frontline is expensive and inefficient, but sometimes worth it for a breakthrough. Promotion therefore has geography, which is the whole point of the tax.

### C. Resource Balancing by Class
*   **Heavy Melee (Knight, Lancer, Paladin)**: high Iron, moderate Gold.
*   **Magic / Support (Wizzard, Monk, Archmage, High Priest)**: high Gold, little or no Iron — robes and tomes need no smelting.

Iron is a **gate, not a currency**: no unit costs more than 4, a faction opens with 6, and an iron mine yields 3 a turn. It exists to stop an all-heavy army, not to be accumulated.

---

## 3. Dynamic Map Events: Treasures & Ruins
Scattered across the map are nodes that offer high-risk, high-reward interactions to disrupt static gameplay.

*   **Treasure Chests**: a unit opens one by ending its move on it. `PandoraTable.roll()` returns one of four outcomes:
    *   `war_spoils` — a burst of Gold or Iron.
    *   `mercenary` — a free unit joins you on the spot.
    *   `trap` — it was a dud, and it hurts.
    *   `awaken_dead` — something hostile wakes up next to you.
*   **Buried traps**: 14 of them, scattered at a minimum spacing of 4 so no corridor becomes a minefield. They are invisible until sprung, and — this is the part that took a fix — they trigger on **any cell the path crosses**, not only where the move ends. Walking *over* a mine sets it off.
*   **Powder kegs**: 1 HP, detonate in a 3x3, and chain into adjacent kegs.

All of it is placed by `ResourceScatter` from the match seed. The same seed
reproduces a board exactly, which is what the test suites depend on, and the
scatter is balanced per faction so a random board is still a fair one.

---

## 4. Asset Optimization Guidelines (Developer Notes)
To manage asset workload for the unit progression tree:
*   **Palette rotation, offline — not a runtime shader.** `scripts_dev/generate_sprites.py` hue-rotates the garment palette onto each faction hue (skin and linework preserved), then gives each promotion its own value/saturation treatment, rim light and role marker. Godot imports finished PNGs and recolours nothing at runtime. 66 faction sheets and 6 monster sheets come out of a handful of source bodies this way.
*   **Sprite metrics are baked, never hand-tuned.** `wire_units.py` measures each sheet and writes `sprite_scale` / `sprite_offset` into the `.tres`, so a unit sits on its cell correctly by construction.
*   **Mounts are a stat swap plus directional art, not a layered horse sprite.** `MountProfile` carries `mounted_class` / `dismounted_class` and the dismount trade (`dismount_move_penalty`, `dismount_defense_bonus`); dismounting **consumes the unit's action**, so nobody free-swaps stats mid-fight to dodge a matchup.
*   **Every generator is byte-stable.** Re-running one leaves an unchanged sheet's mtime alone, so Godot's import cache is undisturbed by a no-op regeneration.

---

## 5. Related Documentation Links
- **Core GDD**: See [[GDD_Overview]] for high concept, core loop, and victory conditions.
- **Units & Factions**: See [[Factions_and_Units]] for class definitions, combat triangle, and faction traits.
- **Terrain & Structures**: See [[Terrain_and_Buildings]] for building functions and terrain modifiers.
