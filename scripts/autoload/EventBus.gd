@tool
extends Node
## EventBus — Central typed signal hub (Autoload Singleton).
## All cross-system communication flows through here.
## No logic, no state — only signal declarations.

# === Turn & Phase Signals ===
@warning_ignore("unused_signal")
signal turn_started(faction_id: int)
@warning_ignore("unused_signal")
signal phase_changed(new_phase: int)
@warning_ignore("unused_signal")
signal turn_ended(faction_id: int)

# === Economy Signals ===
@warning_ignore("unused_signal")
signal gold_changed(faction_id: int, new_amount: int)
@warning_ignore("unused_signal")
signal iron_changed(faction_id: int, new_amount: int)
@warning_ignore("unused_signal")
signal capacity_changed(faction_id: int, used: int, max_cap: int)
@warning_ignore("unused_signal")
signal resource_node_captured(node_type: String, new_faction_id: int, old_faction_id: int)
@warning_ignore("unused_signal")
signal resources_insufficient(faction_id: int, resource_type: String)

# === Unit Lifecycle Signals ===
@warning_ignore("unused_signal")
signal unit_spawned(unit: Node, faction_id: int)
@warning_ignore("unused_signal")
signal unit_damaged(unit: Node, amount: int, damage_type: String)
@warning_ignore("unused_signal")
signal unit_healed(unit: Node, amount: int)
@warning_ignore("unused_signal")
signal unit_died(unit: Node, cause: String)
@warning_ignore("unused_signal")
signal unit_upgraded(unit: Node, old_data: Resource, new_data: Resource)
@warning_ignore("unused_signal")
signal unit_recruited(unit: Node, faction_id: int)
@warning_ignore("unused_signal")
signal unit_deserted(unit: Node)

# === Unit Action Signals ===
@warning_ignore("unused_signal")
signal unit_selected(unit: Node)
@warning_ignore("unused_signal")
signal unit_deselected()
@warning_ignore("unused_signal")
signal unit_move_requested(unit: Node, target_cell: Vector2i)
@warning_ignore("unused_signal")
signal unit_move_completed(unit: Node, from_cell: Vector2i, to_cell: Vector2i)
@warning_ignore("unused_signal")
signal unit_attack_requested(attacker: Node, target: Node)

# === Combat Signals ===
@warning_ignore("unused_signal")
signal combat_started(attacker: Node, defender: Node)
@warning_ignore("unused_signal")
signal combat_resolved(result: Dictionary)
@warning_ignore("unused_signal")
signal combat_advantage_applied(advantage_type: String, multiplier: float)

# === Morale Signals (Roadmap: Milestone 4) ===
@warning_ignore("unused_signal")
signal morale_changed(unit: Node, old_level: int, new_level: int)
@warning_ignore("unused_signal")
signal surrender_triggered(unit: Node)
@warning_ignore("unused_signal")
signal ambush_triggered(ambusher: Node, target: Node)

# === Building & Map Signals ===
@warning_ignore("unused_signal")
signal building_captured(building: Node, faction_id: int)
@warning_ignore("unused_signal")
signal building_destroyed(building: Node)
@warning_ignore("unused_signal")
signal map_event_triggered(event_type: String, position: Vector2i, result: Dictionary)

# === Victory Signals ===
@warning_ignore("unused_signal")
signal victory_condition_met(faction_id: int, condition: String)
@warning_ignore("unused_signal")
signal defeat_condition_met(faction_id: int, condition: String)

# === Starvation / Logistics Signals ===
@warning_ignore("unused_signal")
signal logistics_collapse_started(faction_id: int)
@warning_ignore("unused_signal")
signal logistics_collapse_ended(faction_id: int)

# === AI Story & Dynamic Narrative Signals (Gemini 3.7 Flash) ===
@warning_ignore("unused_signal")
signal dialogue_generated(speaker_name: String, text: String, emotion: String)
@warning_ignore("unused_signal")
signal story_event_narrated(title: String, body: String)
@warning_ignore("unused_signal")
signal ai_generation_failed(error_message: String)
