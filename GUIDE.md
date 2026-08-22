---
type: Developer Guide
title: "War Perang Tactics — Developer & Extension Guide"
description: "How to add new units, buildings, factions, systems, and test in Godot 4.7."
tags: [guide, tutorial, development, extension]
generated: { by: human:aprxty3, at: 2026-08-22T23:55:00Z }
---

# 📖 Developer & Extension Guide

Panduan praktis untuk developer yang ingin menambahkan unit baru, bangunan baru, atau memperluas mekanik game di **War Perang Tactics**.

---

## 🗡️ 1. Cara Menambahkan Unit Baru

Untuk membuat unit baru (misal: **Archer** atau **Knight**):

### Langkah A: Buat Resource `UnitData` (`.tres`)
1. Di Godot Editor (FileSystem), buat file Resource baru di folder `resources/units/` (misal `archer_blue.tres`).
2. Pilih Resource type `UnitData`.
3. Isi parameter di Inspector:
   * **Identity**:
     * `unit_name`: "Blue Archer"
     * `unit_class`: "Ranged"
     * `tier`: 1
   * **Combat Stats**:
     * `max_health`: 80
     * `attack_power`: 28
     * `defense_power`: 6
     * `movement_points`: 3
     * `attack_range_min`: 2 *(Bisa serang dari jarak jauh)*
     * `attack_range_max`: 3
   * **Economy & Logistics**:
     * `recruit_cost_gold`: 70
     * `recruit_cost_iron`: 1
     * `capacity_weight`: 2

### Langkah B: Buat Scene Prefab Unit (`.tscn`)
1. Buat scene turunan dari `scenes/units/TacticalUnit.tscn` atau buat `Node2D` baru dengan script `res://scripts/units/TacticalUnit.gd`.
2. Ganti texture `Sprite2D` dengan sprite unit terkait (misal `assets/Character_animation/Archer/Blue/Archer_Blue.png`).
3. Set `hframes` dan `vframes` sesuai spritesheet.
4. Pasang resource `archer_blue.tres` pada slot `@export var unit_data`.
5. Simpan scene di `scenes/units/TacticalUnit_Archer_Blue.tscn`.

---

## 🏰 2. Cara Menambahkan Bangunan Baru

Untuk menambahkan bangunan baru (misal: **Iron Mine** atau **Village**):

1. Buat scene baru di `scenes/buildings/` dengan root `Node2D` menggunakan script [`scripts/buildings/Building.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/buildings/Building.gd).
2. Di Inspector, atur:
   * `building_type`: Pilih tipe (misal `IRON_MINE` atau `HOUSE`).
   * `faction_id`: `99` (Neutral) atau `0` (Blue).
3. Tambahkan node anak `Sprite2D` dan pasang sprite bangunan dari `assets/Buildings/`.
4. Jika ingin bangunan bisa merekrut (khusus Castle):
   * Masukkan daftar Resource unit ke dalam array `recruitable_units`.

---

## 🧪 3. Cara Menjalankan & Menguji Scene

### Via Editor Godot:
1. Buka scene yang ingin diuji (misal: [`scenes/TestGridScene.tscn`](scenes/TestGridScene.tscn)).
2. Tekan **`F6`** (Play Current Scene).

### Via Terminal (Headless Mode):
Jika ingin menguji script secara otomatis tanpa membuka window grafis:
```bash
godot --headless --path . scenes/TestGridScene.tscn --quit-after 50
```
Jika return code `0` dan tidak ada error merah, berarti scene terkompilasi dan berjalan normal.

---

## 🔄 4. Cara Menambahkan Sinyal Baru ke EventBus

Jika Anda membuat sistem baru yang membutuhkan pertukaran data:
1. Buka [`scripts/autoload/EventBus.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/EventBus.gd).
2. Tambahkan deklarasi sinyal baru dengan tipe data yang jelas:
   ```gdscript
   signal weather_changed(new_weather: String, penalty_multiplier: float)
   ```
3. Emit dari Logic Layer/Manager:
   ```gdscript
   EventBus.weather_changed.emit("rain", 0.8)
   ```
4. Dengarkan di sistem yang relevan (`GridManager`, `UI`, dll):
   ```gdscript
   EventBus.weather_changed.connect(_on_weather_changed)
   ```
