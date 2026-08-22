---
type: Changelog
title: "War Perang Tactics — Daily Changelog (2026-08-22)"
description: "Comprehensive record of architectural restructuring, game systems implementation, and testing on 2026-08-22."
tags: [changelog, 2026-08-22, architecture, godot4, gameplay]
generated: { by: human:aprxty3, at: 2026-08-22T23:55:00Z }
---

# Changelog — 2026-08-22

Semua perubahan besar pada proyek **War Perang Tactics** yang dieksekusi pada tanggal **22 Agustus 2026** tercatat secara rinci di bawah ini.

---

## 📅 Rangkuman Perubahan Hari Ini (2026-08-22)

### 1. 🏗️ Arsitektur & Fondasi Sistem (Decoupled Data-Driven)
- **4-Layer Architecture**: Mengubah arsitektur proyek dari monolitik/tightly-coupled menjadi arsitektur 4 lapis yang terpisah:
  1. **Data Layer**: Resources `.tres` murni tanpa logika (`UnitData.gd`).
  2. **Event Layer**: Autoload Hub sinyal terpusat (`EventBus.gd`).
  3. **Logic Layer**: Manajer aturan permainan (`TurnManager`, `EconomyManager`, `GridManager`, `CombatResolver`, `AIManager`).
  4. **Actor Layer**: Node visual di peta (`TacticalUnit`, `Building`).
- **Autoload Global**:
  - [`scripts/autoload/EventBus.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/EventBus.gd) — Central typed signal hub dengan anotasi bebas warning.
  - [`scripts/autoload/GameConfig.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/GameConfig.gd) — Enums global (`Faction`, `Phase`, `UnitClass`, `DamageType`, `MoraleLevel`) dan konstanta kalkulasi.
  - [`scripts/autoload/TurnManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/TurnManager.gd) — State machine giliran 4 fase (`UPKEEP` ➔ `PRODUCTION` ➔ `ACTION` ➔ `END_TURN`).
- **Refactor Model Data & Aktor**:
  - [`scripts/data/UnitData.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/data/UnitData.gd) — Custom Resource untuk stats, biaya rekrutmen Gold/Iron, dan bobot Troop Capacity.
  - [`scripts/units/TacticalUnit.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/units/TacticalUnit.gd) — Node aktor dengan sistem konsumsi movement & aksi, damage handling, dan upgrade.

### 2. 🗺️ Sistem Grid, Pathfinding & Pergerakan
- **GridManager ([`scripts/managers/GridManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/GridManager.gd))**:
  - Konfigurasi `AStarGrid2D` bawaan Godot 4.7 dengan mode orthogonal (4 arah).
  - Konversi koordinat dua arah: `world_to_grid()` dan `grid_to_world()`.
  - Kalkulasi jangkauan gerak menggunakan algoritma **BFS (Flood Fill)** dengan batasan `movement_points`.
  - Kalkulasi jangkauan serang menggunakan **Manhattan Distance** (`attack_range_min` hingga `attack_range_max`).
  - Animasi pergerakan unit halus menggunakan `Tween` berurutan antar petak.
  - Deteksi dan auto-capture bangunan saat unit mencapai petak tujuan.

### 3. ⚔️ Sistem Pertarungan & Taktis (Combat Advantage)
- **CombatResolver ([`scripts/managers/CombatResolver.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/CombatResolver.gd))**:
  - Formula Base Damage: `max(1, ATK - (DEF * 0.5))`.
  - **Combat Advantage Triangle**: Multiplier 1.5x (Advantage), 0.7x (Disadvantage), 2.5x (Holy vs Undead).
  - **Counter-Attack**: Musuh yang bertahan otomatis membalas jika selamat dan berada dalam jangkauan serangnya.

### 4. 💰 Sistem Ekonomi, Bangunan & Rekrutmen
- **EconomyManager ([`scripts/managers/EconomyManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/EconomyManager.gd))**:
  - Manajemen kas multi-faksi (Gold, Iron, Troop Capacity).
  - Perhitungan Field Tax saat upgrade di luar kastil (200% cost).
  - Sistem Starvation / Logistics Collapse jika jumlah unit melebihi kapasitas pasukan.
- **Building System ([`scripts/buildings/Building.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/buildings/Building.gd))**:
  - 5 Tipe Bangunan: Castle, Gold Mine, Iron Mine, House/Village, Tower.
  - Penghasil pasif: Gold Mine (+50 Gold/turn), Iron Mine (+30 Iron/turn), House (+10 Gold & +2 TC).
  - Rekrutmen di Castle (`[R]`): Validasi Gold, Iron, TC, lalu instansiasi unit di petak kosong di sekitar kastil.

### 5. 🤖 NPC / Enemy Tactical AI
- **AIManager ([`scripts/managers/AIManager.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/managers/AIManager.gd))**:
  - Otomasi penuh untuk giliran Red Legion (`Faction.RED_LEGION`).
  - Merekrut pasukan baru di Red Castle jika kas faksi mencukupi.
  - Memilih target strategis: merebut tambang emas terdekat atau memburu unit pemain.
  - Logika finisher: memprioritaskan menyerang unit dengan sisa HP terendah.
  - Pacing animasi natural (0.4s delay per aksi) dan otomatis mengakhiri giliran AI.

### 6. 🎮 Playable Interactive Testbed
- [`scenes/TestGridScene.tscn`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scenes/TestGridScene.tscn) & [`scripts/test/TestGridController.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/test/TestGridController.gd):
  - Visual Grid Overlay: Biru (Area Jalan), Merah (Area Serang), Kuning (Unit Aktif), Hijau (Kastil Aktif).
  - Live HUD Header: Menampilkan Gold, Iron, Troop Capacity, dan laporan Combat realtime.
  - Hotkeys: `[ESC]` keluar, `[SPASI]` ganti giliran / End Turn, `[R]` rekrut unit di Castle.

### 7. 📚 Standarisasi Dokumentasi OKF (Open Knowledge Format)
- Seluruh dokumen di `docs/` telah ditata ulang dan dilengkapi frontmatter OKF v0.2:
  - `GDD_Overview.md`, `Macro_Economy.md`, `Technical_Specs.md`, `Architecture.md`, `Factions_and_Units.md`, `Terrain_and_Buildings.md`, `Roadmap.md`, dan `index.md`.
- Integrasi **Git Hooks** otomatis (`graphify hook install`).
- Sinkronisasi `/graphify update` menghasilkan **25 nodes, 16 edges, 11 communities**.
