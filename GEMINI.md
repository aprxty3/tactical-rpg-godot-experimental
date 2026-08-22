---
type: Agent Guidelines
title: "War Perang Tactics — AI Agent & Coding Standards"
description: "Rules, conventions, tool workflows, and coding standards for AI assistants in this repository."
tags: [agents, gemini, ai-instructions, conventions, guidelines]
generated: { by: human:aprxty3, at: 2026-08-22T23:55:00Z }
---

# 🤖 AI Agent & LLM Guidelines (`AGENTS.md` / `GEMINI.md`)

Petunjuk operasional untuk AI Assistant (Gemini, Claude, Antigravity, dll.) yang bertugas melakukan coding, refactoring, atau penambahan fitur di repository **War Perang Tactics**.

---

## 📜 Aturan Utama & Standar Kode

### 1. Standar Bahasa & Engine
* **Engine Target**: **Godot Engine 4.7+ (GL Compatibility)**.
* Gunakan sintaks **GDScript 2.0** modern dengan **Static Typing** ketat.
* Hindari sintaks usang Godot 3 (misal: gunakan `TileMapLayer` alih-alih `TileMap`, gunakan `create_tween()` alih-alih node `Tween`, gunakan `@export` alih-alih `export`).

### 2. Standar Static Typing
* Selalu gunakan pengetikan tipe eksplisit pada variabel dan return value fungsi:
  ```gdscript
  func get_path_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
  var distance: int = abs(a.x - b.x) + abs(a.y - b.y)
  ```
* Hindari warning ternary operator dengan memastikan kedua cabang ternary menghasilkan tipe yang persis sama atau gunakan `is_instance_valid()`:
  ```gdscript
  var u_name: String = unit.unit_data.unit_name if is_instance_valid(unit.unit_data) else unit.name
  ```

### 3. Integritas Arsitektur (Decoupled Data-Driven)
* **DILARANG** melakukan hardcoded `get_node("/root/...")` antar manager.
* Semua komunikasi antar-sistem wajib melalui sinyal di [`scripts/autoload/EventBus.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/EventBus.gd).
* Data statis ditaruh di Resource (`UnitData.gd`), konstanta global di `GameConfig.gd`.
* Sinyal di `EventBus.gd` harus selalu diawali dengan anotasi `@warning_ignore("unused_signal")`.

### 4. Standar Dokumentasi OKF v0.2
* Setiap file dokumen baru di folder `docs/` atau root WAJIB menyertakan **YAML frontmatter** sesuai Open Knowledge Format (OKF v0.2):
  ```yaml
  ---
  type: <Tipe Dokumen>
  title: "<Judul Dokumen>"
  description: "<Deskripsi singkat>"
  tags: [<tag1>, <tag2>]
  generated: { by: human:aprxty3, at: 2026-08-22T00:00:00Z }
  ---
  ```

---

## 🛠️ Alur Kerja Validasi
Sebelum menyelesaikan giliran atau melaporkan tugas selesai, AI Agent wajib memverifikasi script menggunakan headless engine check:
```bash
godot --headless --path . scenes/TestGridScene.tscn --quit-after 50
```
Pastikan output menghasilkan **Exit Code 0** tanpa pesan `SCRIPT ERROR` atau `Compile Error`.
