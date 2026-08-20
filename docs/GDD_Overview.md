# Game Design Document: War Perang Tactics

## 1. High Concept & Vision
**War Perang Tactics** is a turn-based tactical grid strategy game set in a medieval fantasy world. Players command faction armies to capture territories, manage gold mine economies, construct defensive fortifications, and lay siege to enemy castles on an interactive grid-based battlefield.

- **Genre**: Turn-Based Tactics / Strategy RPG (SRPG)
- **Target Platform**: PC / Desktop (Godot 4.x)
- **Visual Style**: 2D Pixel Art (Top-Down Orthogonal / Isometric Grid)
- **Core Inspirations**: *Advance Wars*, *Fire Emblem*, *Final Fantasy Tactics*, *Tiny Swords*

---

## 2. Core Gameplay Loop
The game operates in distinct phase-based turns:

```
┌────────────────────────────────────────────────────────┐
│ 1. Upkeep & Economy Phase                              │
│    • Collect gold income from Gold Mines & Houses      │
│    • Reset Unit Movement and Action Points             │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ 2. Production & Recruitment Phase                      │
│    • Recruit new units at Castle / Barracks            │
│    • Construct defensive structures (Towers, Walls)    │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ 3. Tactical Action Phase                               │
│    • Move units across the grid (Movement Range)       │
│    • Attack enemy targets (Class Advantage Triangle)   │
│    • Interact with terrain hazards (TNT Barrels)       │
│    • Capture strategic buildings (Capture Tile)        │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ 4. End Turn & Switch Phase                             │
│    • Evaluate Victory / Defeat Conditions              │
│    • Hand over turn control to enemy AI / Next Player  │
└────────────────────────────────────────────────────────┘
```

---

## 3. Victory and Defeat Conditions

### Victory Conditions:
1. **Total Conquest**: Eliminate all enemy units on the battlefield.
2. **Decapitation (Capture Capital)**: Capture or destroy the enemy faction's primary **Castle**.
3. **Economic Domination**: Control $\ge 75\%$ of all **Gold Mines** on the map for 3 consecutive turns.

### Defeat Conditions:
1. **Castle Fall**: The player's main Castle is captured or destroyed by an adversary.
2. **Total Annihilation**: All player military units are wiped out with insufficient resources to recruit replacements.

---

## 4. Design Pillars
1. **Easy to Learn, Deep Tactical Mastery**:
   Clear grid rules and visible unit stats make entry accessible, while terrain bonuses and formation synergies reward mastery.
2. **Dynamic Battlefield Hazards**:
   Interactive environmental objects like *TNT Barrels*, *Torches*, and *Elevated Ground* turn maps into dynamic tactical puzzles.
3. **Territorial Economy**:
   Victory requires balance between frontline combat and logistics—securing **Gold Mines** and **Towers** fuels military reinforcement.

---

## 5. Related Documentation Links
- **Units & Factions**: See [[Factions_and_Units]] for class definitions, combat triangle, and faction traits.
- **Terrain & Structures**: See [[Terrain_and_Buildings]] for building functions and terrain modifiers.
- **Technical Architecture**: See [[Architecture]] for Godot 4 scene trees, node systems, and GDScript patterns.
