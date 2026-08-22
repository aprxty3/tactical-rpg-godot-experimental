@warning_ignore("unused_signal")
extends Node
## EventBus — Central typed signal hub (Autoload Singleton).
## All cross-system communication flows through here.
## No logic, no state — only signal declarations.

# === Turn & Phase Signals ===
signal turn_started(faction_id: int)
signal phase_changed(new_phase: int)
signal turn_ended(faction_id: int)

# === Economy Signals ===
signal gold_changed(faction_id: int, new_amount: int)
signal iron_changed(faction_id: int, new_amount: int)
signal capacity_changed(faction_id: int, used: int, max_cap: int)
signal resource_node_captured(node_type: String, faction_id: int)
signal resources_insufficient(faction_id: int, resource_type: String)

# === Unit Lifecycle Signals ===
signal unit_spawned(unit: Node, faction_id: int)
signal unit_damaged(unit: Node, amount: int, damage_type: String)
signal unit_healed(unit: Node, amount: int)
signal unit_died(unit: Node, cause: String)
signal unit_upgraded(unit: Node, old_data: Resource, new_data: Resource)
signal unit_recruited(unit: Node, faction_id: int)
signal unit_deserted(unit: Node)

# === Unit Action Signals ===
signal unit_selected(unit: Node)
signal unit_deselected()
signal unit_move_requested(unit: Node, target_cell: Vector2i)
signal unit_move_completed(unit: Node, from_cell: Vector2i, to_cell: Vector2i)
signal unit_attack_requested(attacker: Node, target: Node)

# === Combat Signals ===
signal combat_started(attacker: Node, defender: Node)
signal combat_resolved(result: Dictionary)
signal combat_advantage_applied(advantage_type: String, multiplier: float)

# === Morale Signals (Roadmap: Milestone 4) ===
signal morale_changed(unit: Node, old_level: int, new_level: int)
signal surrender_triggered(unit: Node)
signal ambush_triggered(ambusher: Node, target: Node)

# === Building & Map Signals ===
signal building_captured(building: Node, faction_id: int)
signal building_destroyed(building: Node)
signal map_event_triggered(event_type: String, position: Vector2i, result: Dictionary)

# === Victory Signals ===
signal victory_condition_met(faction_id: int, condition: String)
signal defeat_condition_met(faction_id: int, condition: String)

# === Starvation / Logistics Signals ===
signal logistics_collapse_started(faction_id: int)
signal logistics_collapse_ended(faction_id: int)

# === AI Story & Dynamic Narrative Signals (Gemini 3.7 Flash) ===
signal dialogue_generated(speaker_name: String, text: String, emotion: String)
signal story_event_narrated(title: String, body: String)
signal ai_generation_failed(error_message: String)

