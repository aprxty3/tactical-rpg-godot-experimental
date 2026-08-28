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

**Capture is instant.** Ending a move on a building flips it — there is no
multi-turn capture timer. `Building.claim_for(faction_id)` is the single
function that answers "who may take what", returning `CAPTURE`, `RAZE` or
`NOTHING`, so no caller gets to imply its own answer.

| Structure | Yield | Capacity | Garrison heal | Notes |
| :--- | :--- | :---: | :---: | :--- |
| **Castle** | +20 Gold / turn | **+5** beyond the first | **40%** | Recruit here. Losing it does **not** lose the match while you still have units |
| **Gold Mine** | +50 Gold / turn | — | — | The economy engine |
| **Iron Mine** | +3 Iron / turn | — | — | A gate, not a currency — see [[Macro_Economy]] |
| **Village / House** | +10 Gold / turn | **+3** | **20%** | The only building a marauder can affect — and it **burns** it |
| **Tower** | — | — | — | Defined in `Building.BuildingType` and priced in the AI's objective table, but **not placed on the current map**. Reserved |

> The **Tower** row is listed as unbuilt on purpose. It is referenced by enum and
> by `AI_OBJECTIVE_VALUE`, so code that walks building types must handle it; a
> reader looking for it on the board will not find one.

---

## 2. Interactive Battlefield Hazards

| Hazard | Behaviour |
| :--- | :--- |
| **Powder Keg** | 1 HP. Detonates in a **3x3**, chains into adjacent kegs, and leaves fire behind |
| **Buried Trap** | Invisible until sprung. **14 per map**, minimum spacing 4 |
| **Treasure Chest** | Opened by ending a move on it. Rolls `war_spoils` / `mercenary` / `trap` / `awaken_dead` |
| **Fire** | Spreads by terrain flammability, then leaves `SCORCHED` ground behind |

**Traps trigger on traversal, not on arrival.** This was a real bug: a mine only
fired if a unit *ended* its move on it, so walking straight over one was free.
`EventBus.unit_path_walked(unit, path)` now reports every cell a move crossed,
and `MapObjectManager` checks all of them.

Fire matters because terrain is flammable at different rates — forest at 0.55 is
more than four times as likely to catch as plain at 0.12, and roads, bridges,
water and already-scorched ground do not burn at all.

---

## 3. Terrain Biomes & Movement Modifiers

Seven terrain types, and the second column is the one worth reading twice:
**`damage_taken_mult` is a multiplier on damage received**, so below 1.0 is
cover and above 1.0 is exposure.

| Terrain | Move cost | Damage taken | Conceals | Ambush | Flammable |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Plain** | 1 | ×1.00 | — | — | 0.12 |
| **Road** | 1 | **×1.15** | — | — | — |
| **Forest** | 2 | **×0.75** | ✅ | ✅ | 0.55 |
| **Rocks** | 2 | **×0.70** | ✅ | — | — |
| **Bridge** | 1 | **×1.25** | — | — | — |
| **Scorched** | 1 | ×1.05 | — | — | — |
| **Water** | 99 | ×1.00 | — | — | — |

Three consequences the table understates:

- **Speed costs you.** Roads and bridges are the fastest ground and the most
  dangerous to stand on. Moving fast and being safe are opposed, deliberately.
- **A bridge is a killing floor.** Two rivers split the map and there are four
  crossings; at ×1.25 they are the worst tiles on the board to be caught on.
- **Water is not "expensive", it is impassable.** 99 is
  `MOVE_COST_IMPASSABLE` — the movement field prunes it rather than pricing it.
  There are no flying units, and nothing crosses except at a bridge.

Rocks give the best cover in the game (×0.70) and conceal, but do **not** grant
ambush — that belongs to forest alone.

## 4. Ambush Mechanics (Forest Terrain)

Ambush is **terrain-conditional, not class-conditional** — any unit attacking
*out of* forest ambushes, a Knight as readily as a Rogue. `CombatResolver`
asks one question, `grid_manager.is_ambush_cover(attacker.grid_position)`, and
the answer comes from the terrain table.

- **The victim never gets to swing.** An ambushed defender's counter-attack is
  skipped entirely. That is the whole reward — there is no separate damage bonus.
- **Cover and ambush are different properties.** Rocks conceal you (`conceals`)
  and give the best damage reduction in the game, but do **not** grant ambush:
  they hide a unit and give it nowhere to spring from. Only forest does both.
- No class restriction and no morale shock were ever implemented. An earlier
  draft of this document described both; the terrain table is the authority.

> *Inspired by Symphony of War's stealth and ambush system.*

---

## 5. Related Documentation Links
- **Economy Integration**: See [GDD_Overview.md](GDD_Overview.md) for gold revenue phases and upkeep mechanics.
- **Unit Production**: See [Factions_and_Units.md](Factions_and_Units.md) for units deployable from Castles.
- **Godot Scene Setup**: See [Architecture.md](Architecture.md) for `TileMapLayer` and pathfinding configuration.

---

## Implementation Status (2026-08-23)

| Structure | Scene | Ownership visual |
|---|---|---|
| Castle | `scenes/buildings/Castle{,_Red,_Purple,_Yellow,_Black}.tscn` | Texture swap from `assets/buildings/{Faction} Buildings/Castle.png` |
| Village / House | `scenes/buildings/House.tscn` | Texture swap from `{Faction} Buildings/House1.png` |
| Gold Mine | `scenes/buildings/GoldMine.tscn` | Faction pennant (no per-faction art in the pack) |
| Iron Mine | `scenes/buildings/IronMine.tscn` | Faction pennant; art is a desaturated derivation of the Gold Mine |
| Tower | *not yet scened* | Texture swap is already wired in `Building.FACTION_ART_FILE` |

Capturing a structure swaps its sprite to the capturing faction's own building rather than
tinting the previous owner's — and a captured **Castle recruits the new owner's unit
variants** via `Building.resolve_for_owner()`.

### Terrain

`scripts/managers/MapBuilder.gd` paints four stacked `TileMapLayer`s — water (z −4),
grass (−3), sand paths (−2), bridges (−1) — and reports impassable cells to
`GridManager.set_terrain_blocked_cells()`. **GridManager is the only authority on
walkability**; nothing infers passability from tile ids.

Currently modelled: **water** (impassable) and **bridges** (the only crossings). Forest and
rock props are placed but purely decorative — terrain combat modifiers land with Forest
Ambush in Milestone 4. `CombatResolver._calculate_damage()` already reserves the hook
(`terrain_def_mult`, pinned to `1.0`).
