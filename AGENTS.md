---
type: Agent Guidelines
title: "War Perang Tactics — AI Agent & Coding Standards"
description: "Rules, conventions, tool workflows, and coding standards for AI assistants in this repository."
tags: [agents, gemini, ai-instructions, conventions, guidelines]
generated: { by: human:aprxty3, at: 2026-08-22T23:55:00Z }
---

# 🤖 AI Agent & LLM Guidelines (`AGENTS.md` / `GEMINI.md`)

Operational instructions for AI Assistants (Gemini, Claude, Antigravity, etc.) tasked with coding, refactoring, or adding features in the **War Perang Tactics** repository.

---

## 📜 Core Rules & Code Standards

### 1. Language & Engine Standards
* **Target Engine**: **Godot Engine 4.7+ (GL Compatibility)**.
* Use modern **GDScript 2.0** syntax with strict **Static Typing**.
* Avoid deprecated Godot 3 syntax (e.g., use `TileMapLayer` instead of `TileMap`, use `create_tween()` instead of the `Tween` node, use `@export` instead of `export`).

### 2. Static Typing Standards
* Always use explicit type hinting on variables and function return values:
  ```gdscript
  func get_path_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
  var distance: int = abs(a.x - b.x) + abs(a.y - b.y)
  ```
* Avoid ternary operator warnings by ensuring both branches of the ternary yield the exact same type, or use `is_instance_valid()`:
  ```gdscript
  var u_name: String = unit.unit_data.unit_name if is_instance_valid(unit.unit_data) else unit.name
  ```

### 3. Architectural Integrity (Decoupled Data-Driven)
* **FORBIDDEN** to use hardcoded `get_node("/root/...")` paths between managers.
* All cross-system communication MUST go through signals in [`scripts/autoload/EventBus.gd`](file:///home/aprxty3/Projects/godtot/war-perang-tactics/scripts/autoload/EventBus.gd).
* Static data belongs in Resources (`UnitData.gd`), global constants in `GameConfig.gd`.
* Signals in `EventBus.gd` must always be prefixed with the `@warning_ignore("unused_signal")` annotation.

### 4. OKF v0.2 Documentation Standard
* Every new documentation file in the `docs/` folder or root MUST include a **YAML frontmatter** adhering to the Open Knowledge Format (OKF v0.2):
  ```yaml
  ---
  type: <Document Type>
  title: "<Document Title>"
  description: "<Brief description>"
  tags: [<tag1>, <tag2>]
  generated: { by: human:aprxty3, at: 2026-08-22T00:00:00Z }
  ---
  ```

### 5. AI Coding Principles (ROBUST, DRY, KISS, YAGNI)
When writing or refactoring code in this repository, you MUST strictly adhere to the following principles:
*   **ROBUST**: Handle edge cases and avoid hard crashes. Validate instances using `is_instance_valid()`, add bounds checking for arrays/grids, and ensure headless testing always passes.
*   **DRY (Don't Repeat Yourself)**: Avoid duplicating logic or scenes manually. Prefer programmatic or dynamic generation (e.g., generating animation frames dynamically instead of hand-crafting individual nodes).
*   **KISS (Keep It Simple, Stupid)**: Favor simple, readable, and idiomatic Godot solutions. Rely on built-in tools like `AStarGrid2D` over complex custom algorithms.
*   **YAGNI (You Aren't Gonna Need It)**: Do not build features, abstractions, or scaling systems until they are explicitly required by the current milestone.

---

## 🛠️ Validation & Task Completion Workflow
Before ending your turn or reporting a task as complete, the AI Agent MUST perform the following checklist:
1. **Headless Testing**: Verify the scripts using the headless engine check:
   ```bash
   godot --headless --path . scenes/TestGridScene.tscn --quit-after 50
   ```
   Ensure the output yields **Exit Code 0** with no `SCRIPT ERROR` or `Compile Error` messages.
2. **Update CHANGELOG.md**: Document all new features, refactors, and bug fixes under the current date.
3. **Update docs/Roadmap.md**: Check off completed milestone tasks (`- [x]`) and adjust future plans if necessary.
4. **Update Knowledge Graph**: Run `graphify update` in the terminal to sync the project's memory and generate the new `GRAPH_REPORT.md`.
