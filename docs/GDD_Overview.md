---
type: Game Design Document
title: "War Perang Tactics — Core Game Design"
description: "High concept, core gameplay loop, victory conditions, and design pillars for War Perang Tactics."
tags: [gdd, design, core-loop, victory-conditions]
generated: { by: human:aprxty3, at: 2026-08-22T00:00:00Z }
---

# Game Design Document: War Perang Tactics

## 1. High Concept & Vision
**War Perang Tactics** is a turn-based tactical grid strategy game set in a medieval fantasy world. Players command faction armies to capture territories, manage gold mine economies, construct defensive fortifications, and lay siege to enemy castles on an interactive grid-based battlefield.

- **Genre**: Turn-Based Tactics / Strategy RPG (SRPG)
- **Target Platform**: PC / Desktop (Godot 4.x)
- **Visual Style**: 2D Pixel Art (Top-Down Orthogonal / Isometric Grid)
- **Core Inspirations**: *Advance Wars*, *Fire Emblem*, *Final Fantasy Tactics*, *Tiny Swords*

---

## 2. Core Gameplay Loop

A match begins at the menu, not on the board: **Main Menu → pick one of four
armies → Match**. From there every faction takes its turn in order, and the
Black Castle takes one too.

```
┌────────────────────────────────────────────────────────┐
│ 1. Upkeep                                              │
│    • Income from every building you hold               │
│    • Garrison healing — castle 40%, village 20%        │
│    • Starvation, if you are over your troop ceiling    │
│    • Reset movement and action points                  │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 2. Tactical Action                                     │
│    • Move — Dijkstra range at REAL terrain cost        │
│    • Attack — advantage triangle, terrain, morale,     │
│      counter-attack, forest ambush                     │
│    • Capture by ending a move on a building            │
│    • Recruit [R] at a castle, promote [U], mount [M]   │
│    • Trip traps, detonate kegs, open chests            │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 3. End Turn                                            │
│    • Morale drift; desertion and surrender resolve     │
│    • Fog recomputed for the next faction               │
│    • Victory check, then hand over                     │
└────────────────────────────────────────────────────────┘
```

The **Black Castle's garrison** slots into that order as a `marauder`: it takes
a turn, but it is excluded from the victory check. `TurnManager` keeps two
lists for exactly this — `faction_order` (everyone who acts) and `contenders`
(everyone who can win or lose).

---

## 3. Victory and Defeat Conditions

There is **one rule**, and it is deliberately narrower than the usual three:

> A faction is eliminated only when it has **no units AND no castles**.
> The last contender standing wins by *supremacy*.

Two consequences are the entire point of writing it this way:

- **Losing your castle does not lose you the match.** With units still on the
  board you fight on as a rogue army — no income, no recruitment, no capacity
  from a keep, but alive. This is why the troop-capacity formula charges from
  the *second* castle: a castle-less army must not also be starved.
- **Monsters cannot win, and killing them all wins nothing.** They are an
  environmental threat, not a contender.

Economic-domination and capture-the-capital conditions were considered and
dropped. Both ended matches while an army was still capable of fighting, which
is precisely the situation this game is trying to make interesting.

## 4. Design Pillars
1. **Easy to Learn, Deep Tactical Mastery**:
   Clear grid rules and visible unit stats make entry accessible, while terrain bonuses and formation synergies reward mastery.
2. **Dynamic Battlefield Hazards**:
   Interactive environmental objects like *TNT Barrels*, *Torches*, and *Elevated Ground* turn maps into dynamic tactical puzzles.
3. **Territorial Economy**:
   Victory requires balance between frontline combat and logistics—securing **Gold Mines** and **Towers** fuels military reinforcement.

---

## 5. Related Documentation Links
- **Macro-Economy**: See [[Macro_Economy]] for resource management, logistics, and field tax mechanics.
- **Units & Factions**: See [[Factions_and_Units]] for class definitions, combat triangle, and faction traits.
- **Terrain & Structures**: See [[Terrain_and_Buildings]] for building functions and terrain modifiers.
- **Technical Architecture**: See [[Architecture]] for Godot 4 scene trees, node systems, and GDScript patterns.