---
type: Memory
title: "Project Memory & Architectural Context"
description: "Persistent context, architectural invariants, decisions, and system patterns for War Perang Tactics."
tags: [memory, architecture, context, invariants]
generated: { by: human:aprxty3, at: 2026-08-22T23:55:00Z }
---

# 🧠 Project Memory — War Perang Tactics

Dokumen ini berfungsi sebagai **Persistent Context (Memori Abadi)** untuk developer dan AI Agent yang bekerja di repositori ini. Semua aturan, keputusan arsitektur, dan konvensi utama didokumentasikan di sini.

---

## 🏛️ Invariabel Arsitektur (Architectural Invariants)

1. **Decoupled Data-Driven Pattern**:
   * **Resource Murni (Data Layer)**: Script di `scripts/data/` (seperti `UnitData.gd`) HANYA berisi data `@export`. Dilarang menaruh logika runtime, signal emission, atau manipulasi node di Resource.
   * **EventBus sebagai Single Source of Truth untuk Komunikasi**: Node tidak boleh memanggil `get_node("/root/...")` atau hardcoded path antar sesama manager. Semua komunikasi antar-sistem dilakukan melalui sinyal di [`scripts/autoload/EventBus.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/EventBus.gd).
   * **Node Aktor Pasif (Actor Layer)**: `TacticalUnit.gd` dan `Building.gd` hanya memanipulasi representasi visualnya sendiri, membaca Resource datanya, dan melempar event ke `EventBus`.
   * **Manajer Logika (Logic Layer)**: Manajer (`GridManager`, `CombatResolver`, `EconomyManager`, `AIManager`) mengolah state dan kalkulasi, lalu memancarkan hasilnya melalui `EventBus`.

2. **Standar Autoload (`project.godot`)**:
   * `EventBus` ➔ `*res://scripts/autoload/EventBus.gd`
   * `GameConfig` ➔ `*res://scripts/autoload/GameConfig.gd`
   * `TurnManager` ➔ `*res://scripts/autoload/TurnManager.gd`
   * `_mcp_game_helper` ➔ Autoload plugin godot_ai.

3. **Standar Koordinat & Grid**:
   * Ukuran Grid standar: Orthogonal 4-arah (`AStarGrid2D.DIAGONAL_MODE_NEVER`).
   * Heuristic standar: `AStarGrid2D.HEURISTIC_MANHATTAN`.
   * Cell Size standar: `Vector2i(64, 64)` pixel untuk gameplay 2D táctics.

4. **Multi-Faction Invariant**:
   * Semua sistem ekonomi dan unit wajib mendukung `faction_id` dinamis:
     * `0`: `BLUE_KINGDOM` (Player faksi default)
     * `1`: `RED_LEGION` (AI/Enemy faksi default)
     * `2`: `PURPLE_SYNDICATE`
     * `3`: `YELLOW_EMPIRE`
     * `4`: `BLACK_COVEN`
     * `99`: `NEUTRAL` (Bangunan / Creature netral)

---

## ⚖️ Rumus & Formula Kunci Permainan

1. **Formula Kerusakan Tempur (Combat Damage)**:
   $$\text{Base Damage} = \max(1, \text{Attacker.ATK} - (\text{Defender.DEF} \times 0.5))$$
   $$\text{Final Damage} = \text{round}(\text{Base Damage} \times \text{Advantage Mult} \times \text{Terrain Mod} \times \text{Counter Mod})$$

2. **Matriks Keunggulan Tempur (Advantage Multipliers)**:
   * **Advantage (1.5x)**: Melee > Ranged, Ranged > Mage, Mage > Melee, Infiltrator > Mage/Ranged.
   * **Disadvantage (0.7x)**: Ranged < Melee, Melee < Mage.
   * **Holy vs Undead (2.5x)**: Support/Priest > Undead/Skeleton/Vampire.

3. **Ekonomi & Field Tax**:
   * Upgrade di Kastil: $100\%$ biaya selisih tier.
   * Upgrade di Luar Kastil (Field Tax): $200\%$ biaya selisih tier (`GameConfig.FIELD_TAX_MULTIPLIER = 2`).
   * Kapasitas Pasukan Dasar: $8$ TC + ($2$ TC per Village yang dikuasai).
   * Starvation Damage: $15$ True Damage per unit jika faksi mengalami kelebihan kapasitas pasukan.

---

## 📌 Riwayat Keputusan Desain (Design Decisions)

| Tanggal | Keputusan | Rasional |
|---|---|---|
| **2026-08-22** | Migrasi ke Decoupled 4-Layer | Menghindari *spaghetti code* dan keterikatan path node antar manager. |
| **2026-08-22** | Penggunaan `AStarGrid2D` bawaan | Kinerja pathfinding C++ di level engine jauh lebih cepat daripada AStar buatan manual di GDScript. |
| **2026-08-22** | Standarisasi Dokumen ke OKF v0.2 | Memastikan seluruh dokumen arsitektur dan GDD mudah dipahami, di-query, dan diproses oleh LLM/Graphify. |
| **2026-08-22** | Pacing Asinkron pada `AIManager` | AI diberi jeda `0.4s` via `create_timer` agar aksi pergerakan dan serangan dapat diamati pemain secara natural. |
