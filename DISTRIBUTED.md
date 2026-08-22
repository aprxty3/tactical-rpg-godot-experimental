---
type: Architecture Document
title: "War Perang Tactics — Decoupled & Distributed System Architecture"
description: "Event-driven communication, state management, and isolation patterns across game subsystems."
tags: [architecture, decoupled, event-driven, distributed, state-management]
generated: { by: human:aprxty3, at: 2026-08-22T23:55:00Z }
---

# 🌐 Decoupled & Distributed System Architecture

This document explains the design philosophy of the Decoupled & Event-Driven Architecture implemented in **War Perang Tactics**.

---

## 🎯 Core Principle: *Strict Separation of Concerns*

The main goal of this architecture is to ensure that **each subsystem can exist, be tested, and modified in isolation** without needing to know the internal structure of other subsystems.

```text
               ┌───────────────────────┐
               │      EventBus.gd      │  <── Single Event Backbone
               └───────────▲───────────┘
                           │ Typed Signals
     ┌─────────────────────┼─────────────────────┐
     │                     │                     │
┌────┴────────────┐  ┌─────┴───────────┐  ┌──────┴──────────┐
│   TurnManager   │  │   GridManager   │  │ CombatResolver  │
│ (State Machine) │  │  (Pathfinding)  │  │(Damage Formula) │
└─────────────────┘  └─────────────────┘  └─────────────────┘
     │                     │                     │
     └─────────────────────┼─────────────────────┘
                           │ Listen & Emit
               ┌───────────▼───────────┐
               │    EconomyManager     │
               │  (Treasury & Logistics│
               └───────────────────────┘
```

---

## 🧩 Subsystem Modules

### 1. `TurnManager` (FSM Subsystem)
* **Responsibility**: Manages the rotation of the turn-based phases (`UPKEEP` ➔ `PRODUCTION` ➔ `ACTION` ➔ `END_TURN`) and switches faction turns.
* **Isolation**: Has no direct dependency on UI or Grid nodes. It only broadcasts `turn_started`, `phase_changed`, and `turn_ended`.

### 2. `GridManager` (Spatial & Pathfinding Subsystem)
* **Responsibility**: Holds the spatial `AStarGrid2D` structure, converts pixel to grid coordinates, calculates reachable tiles (*Flood Fill*), and animates unit movement.
* **Isolation**: Does not directly alter unit HP or economic treasury states; it only listens to `unit_move_requested` and broadcasts `unit_move_completed`.

### 3. `CombatResolver` (Combat Math Subsystem)
* **Responsibility**: Purely calculates combat math (*Advantage Triangle*, *Defense Mitigation*, *Counter-Attack*).
* **Isolation**: Does not handle animation or grid movement. It receives `(attacker, defender)`, calculates damage, applies it to the unit, and broadcasts `combat_resolved`.

### 4. `EconomyManager` (State & Ledger Subsystem)
* **Responsibility**: Faction treasury ledger (`Dictionary[faction_id, int]`) for Gold, Iron, and Troop Capacity.
* **Isolation**: Calculates transactions and checks for *Starvation*. Does not control visual nodes.

### 5. `AIManager` (Autonomous Agent Subsystem)
* **Responsibility**: Controls NPC factions. Makes decisions reactively when receiving its faction's `turn_started` signal.

---

## 📡 Advantages of This Distributed Architecture

1. **High Testability**: Every manager can be tested independently using unit tests or mock scenes.
2. **Multiplayer Readiness (Networking Ready)**: Since all game actions are structured messages (*Event Signals*), this architecture is ready to be converted into a multiplayer system (RPC / WebSockets) where `EventBus` acts as the *message dispatcher* between client and server.
3. **No Memory Leaks / Circular Dependencies**: Eliminates cross-reference cycles between scripts (e.g., `Class A` calling `Class B` which calls `Class A`).
