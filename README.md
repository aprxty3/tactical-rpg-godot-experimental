---
type: Overview
title: "War Perang Tactics — Project Overview"
description: "Turn-based tactical RPG built with Godot 4.7 featuring Decoupled Data-Driven architecture."
tags: [overview, readme, godot4, tactics, gamedev]
generated: { by: human:aprxty3, at: 2026-08-22T23:55:00Z }
---

# ⚔️ War Perang Tactics

> **Turn-Based Tactical RPG** yang dibangun menggunakan **Godot 4.7 (GL Compatibility)** dengan fondasi arsitektur **Decoupled Data-Driven**.
> Terinspirasi dari *Ancient Empire 2*, *Symphony of War*, dan *Heroes of Might and Magic: Olden Era*.

---

## 🎯 Fitur Utama

- ♟️ **Grid-Based Tactical Movement**: Pathfinding berbasis `AStarGrid2D` dengan jangkauan orthogonal (4 arah), deteksi tabrakan unit, dan animasi pergerakan mulus via Tweening.
- ⚔️ **Combat Advantage Triangle**: Kalkulasi pertarungan taktis (Melee > Ranged > Mage > Melee; Holy vs Undead 2.5x) dilengkapi mekanisme serangan balik (*Counter-Attack*).
- 💰 **Macro-Economy & Logistics**: Pengelolaan sumber daya Multi-Faksi (**Gold**, **Iron**, dan **Troop Capacity**) dengan pendapatan pasif dari tambang yang direbut (*Gold Mine*, *Iron Mine*, *Houses*).
- 🏰 **Pusat Rekrutmen (Castles)**: Rekrut pasukan langsung dari kastil ke petak di sekitarnya jika kas faksi dan kapasitas pasukan mencukupi.
- 🤖 **Autonomous Tactical Enemy AI**: Faksi musuh (Red Legion) mampu merekrut pasukan secara otomatis, mengejar target strategis (tambang & kastil), memburu unit pemain terdekat, dan menyerang unit yang sekarat.
- 🏛️ **Decoupled Architecture**: 4 layer terpisah (Data, Event, Logic, Actor) yang berkomunikasi murni melalui sinyal terpusat di `EventBus.gd`.
- 📖 **OKF v0.2 Compliant**: Seluruh dokumentasi game design dan teknis mengikuti standar *Open Knowledge Format* dengan integrasi knowledge graph otomatis via Graphify.

---

## 🚀 Quick Start / Cara Memainkan

### Prasyarat:
- **Godot Engine 4.7+** (Dapat dijalankan langsung di editor).

### Menjalankan Playable Test Scene:
1. Clone atau buka folder project ini di Godot Engine 4.7.
2. Buka scene: [`scenes/TestGridScene.tscn`](scenes/TestGridScene.tscn).
3. Tekan **`F6`** (Play Current Scene).

### 🎮 Kontrol Game:
| Tombol / Aksi | Fungsi |
|---|---|
| **Klik Kiri Unit** | Memilih unit (Muncul 🟦 **Petak Biru** untuk jangkauan jalan, 🟥 **Petak Merah** untuk jangkauan serang). |
| **Klik Petak Biru** | Memerintahkan unit yang dipilih untuk bergerak ke petak tersebut. |
| **Klik Unit Musuh (Merah)** | Menyerang unit musuh dan memicu kalkulasi damage serta counter-attack. |
| **Klik Castle Milikmu** | Memilih kastil faksi aktif. |
| **`[R]`** | Merekrut unit baru (**Blue Pawn**) di sekitar kastil terpilih (Biaya: 50 Gold, 1 Iron). |
| **`[SPASI]` (Spacebar)** | **End Turn** (Ganti giliran faksi ➔ Memulai giliran musuh AI / Upkeep phase). |
| **`[ESC]`** | Keluar dari game seketika. |

---

## 🏗️ Struktur Arsitektur (4-Layer Pattern)

```text
┌─────────────────────────────────────────────────────────┐
│                    1. DATA LAYER                        │
│   UnitData.tres  TerrainData.tres  BuildingData.tres    │
│   (Resources — Pure Data Containers, No Logic)          │
└──────────────────────┬──────────────────────────────────┘
                       │ read by
┌──────────────────────▼──────────────────────────────────┐
│                    2. ACTOR LAYER                       │
│   TacticalUnit.gd  Building.gd  MapObject.gd            │
│   (Node2D — Visual, Input, Sprite, Animation)           │
└──────────┬────────────────────────────┬─────────────────┘
           │ emit signals               │ emit signals
┌──────────▼────────────────────────────▼─────────────────┐
│                    3. EVENT LAYER                       │
│                   EventBus.gd                           │
│   (Autoload Singleton — Central Typed Signal Hub)       │
└──────────┬────────────────────────────┬─────────────────┘
           │ listened by                │ listened by
┌──────────▼────────────────────────────▼─────────────────┐
│                    4. LOGIC LAYER                       │
│   TurnManager  EconomyManager  CombatResolver  AIManager │
│   (Managers — Game Rules, State Machines, Calculations) │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 Struktur Folder Proyek

```text
war-perang-tactics/
├── assets/                    # Sprite, Audio, Tileset, Character Animations
├── docs/                      # Dokumentasi GDD & Arsitektur (OKF v0.2)
│   ├── index.md               # Hub navigasi dokumentasi
│   ├── GDD_Overview.md        # Visi & gameplay loop
│   ├── Macro_Economy.md       # Sistem ekonomi & logistik
│   ├── Technical_Specs.md     # Spesifikasi formula & angka
│   ├── Architecture.md        # Diagram sistem & scene tree
│   ├── Factions_and_Units.md  # 5 Faksi & Unit Archetypes
│   ├── Terrain_and_Buildings.md # Bangunan, Hazard & Bioma
│   └── Roadmap.md             # Milestone pengembangan
├── graphify-out/              # Knowledge Graph report & visualizer
├── resources/                 # Resource files (.tres)
│   ├── units/                 # Data unit (pawn_blue.tres, warrior_red.tres)
│   └── tilesets/              # TileSet data (terrain_flat_tileset.tres)
├── scenes/                    # Prefab dan scene utama
│   ├── buildings/             # Castle.tscn, Castle_Red.tscn, GoldMine.tscn
│   ├── units/                 # TacticalUnit.tscn, TacticalUnit_Red.tscn
│   └── TestGridScene.tscn     # Playable test scene
├── scripts/                   # GDScript source code
│   ├── autoload/              # EventBus.gd, GameConfig.gd, TurnManager.gd
│   ├── buildings/             # Building.gd
│   ├── data/                  # UnitData.gd
│   ├── managers/              # GridManager.gd, CombatResolver.gd, EconomyManager.gd, AIManager.gd
│   ├── test/                  # TestGridController.gd
│   └── units/                 # TacticalUnit.gd
├── CHANGELOG.md               # Catatan rilis & riwayat perubahan
├── GUIDE.md                   # Panduan developer & ekspansi sistem
├── MEMORY.md                  # Konteks arsitektur & aturan invariabel
├── DISTRIBUTED.md             # Pola decoupling & arsitektur terdistribusi
├── GEMINI.md                  # Panduan kerja AI & instruksi agent
├── AGENTS.md                  # Standar operasional agen LLM
└── project.godot              # Konfigurasi Godot 4.7 Engine
```

---

## 🗺️ Roadmap Singkat

- [x] **Milestone 1**: Core Foundation (Decoupled Data-Driven, EventBus, TurnManager, GridManager, CombatResolver, EconomyManager, Building & AI).
- [ ] **Milestone 2**: Unit Class Expansion (Archer, Rogue, Wizzard, Priest, Vampire, Skeleton) & Spritesheet Animation integration.
- [ ] **Milestone 3**: Fog of War, Battlefield Hazards (TNT detonation, Fire spread), & Ambush from Forests.
- [ ] **Milestone 4**: Morale & Surrender System *(inspired by Symphony of War)*.
- [ ] **Milestone 5**: Full Campaign, UI Theme/HUD overhaul, and SFX/BGM pipeline.

---

## 📜 Lisensi & Atribusi
Dibuat untuk proyek pengembangan game taktis independen. Asset pack menggunakan Tiny Swords & Pixel RPG Pack dengan modifikasi script custom.
