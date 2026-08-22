---
type: Architecture Document
title: "War Perang Tactics — Decoupled & Distributed System Architecture"
description: "Event-driven communication, state management, and isolation patterns across game subsystems."
tags: [architecture, decoupled, event-driven, distributed, state-management]
generated: { by: human:aprxty3, at: 2026-08-22T23:55:00Z }
---

# 🌐 Decoupled & Distributed System Architecture

Dokumen ini menjelaskan filosofi desain arsitektur terdistribusi dan terpisah (*Decoupled & Event-Driven Architecture*) yang diterapkan pada **War Perang Tactics**.

---

## 🎯 Prinsip Utama: *Strict Separation of Concerns*

Tujuan utama dari arsitektur ini adalah memastikan bahwa **setiap subsistem dapat hidup, diuji, dan dimodifikasi secara terisolasi** tanpa perlu mengetahui struktur internal dari subsistem lain.

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

## 🧩 Modul Subsistem

### 1. `TurnManager` (FSM Subsistem)
* **Tanggung Jawab**: Mengatur rotasi fase turn-based (`UPKEEP` ➔ `PRODUCTION` ➔ `ACTION` ➔ `END_TURN`) dan pergantian giliran faksi.
* **Isolasi**: Tidak memiliki dependensi langsung ke node UI atau Grid. Ia hanya menyiarkan `turn_started`, `phase_changed`, dan `turn_ended`.

### 2. `GridManager` (Spatial & Pathfinding Subsistem)
* **Tanggung Jawab**: Memegang struktur spasial `AStarGrid2D`, mengonversi koordinat pixel ke grid, menghitung petak jangkauan jalan (*Flood Fill*), dan menganimasikan perpindahan unit.
* **Isolasi**: Tidak mengubah state HP unit atau kas ekonomi secara langsung; ia hanya mendengarkan `unit_move_requested` dan menyiarkan `unit_move_completed`.

### 3. `CombatResolver` (Combat Math Subsistem)
* **Tanggung Jawab**: Murni menghitung matematika pertarungan (*Advantage Triangle*, *Defense Mitigation*, *Counter-Attack*).
* **Isolasi**: Tidak menangani animasi atau grid. Ia menerima `(attacker, defender)`, menghitung damage, menerapkan ke unit, dan menyiarkan `combat_resolved`.

### 4. `EconomyManager` (State & Ledger Subsistem)
* **Tanggung Jawab**: Buku kas faksi (`Dictionary[faction_id, int]`) untuk Gold, Iron, dan Kapasitas Pasukan.
* **Isolasi**: Menghitung transaksi dan memeriksa *Starvation*. Tidak mengendalikan node visual.

### 5. `AIManager` (Autonomous Agent Subsistem)
* **Tanggung Jawab**: Mengendalikan faksi NPC. Mengambil keputusan secara reaktif ketika menerima sinyal `turn_started` milik faksinya.

---

## 📡 Keuntungan Arsitektur Terdistribusi Ini

1. **Testability Tinggi**: Setiap manager dapat diuji secara independen menggunakan unit test atau scene mock.
2. **Kesiapan Multiplayer (Networking Ready)**: Karena semua aksi permainan berbentuk pesan terstruktur (*Event Signals*), arsitektur ini siap dikonversi ke sistem multiplayer (RPC / WebSockets) di mana `EventBus` bertindak sebagai *message dispatcher* antar klien dan server.
3. **Bebas Memory Leak / Circular Dependency**: Menghilangkan siklus referensi silang antar script (`Class A` memanggil `Class B` yang memanggil `Class A`).
