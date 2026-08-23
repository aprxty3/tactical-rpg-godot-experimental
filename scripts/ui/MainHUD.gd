extends CanvasLayer

signal end_turn_requested

@onready var gold_label: Label = %GoldLabel
@onready var iron_label: Label = %IronLabel
@onready var cap_label: Label = %CapLabel
@onready var turn_label: Label = %TurnLabel
@onready var inspector_title: Label = %InspectorTitle
@onready var inspector_stats: Label = %InspectorStats
@onready var context_label: Label = %ContextLabel
@onready var victory_label: Label = %VictoryLabel
@onready var end_turn_btn: Button = %EndTurnBtn
@onready var inspector_panel: Control = %InspectorPanel
@onready var end_turn_modal: Control = %EndTurnConfirmModal
@onready var confirm_btn: Button = %ConfirmBtn
@onready var cancel_btn: Button = %CancelBtn

var current_faction_id: int = 0
var economy_manager: Node = null
## Optional — supplies the terrain readout in the unit inspector.
var grid_manager: Node = null

func _ready() -> void:
	# Hide inspector, victory, and modal at start
	inspector_panel.hide()
	victory_label.hide()
	end_turn_modal.hide()
	
	# Connect EventBus
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.iron_changed.connect(_on_iron_changed)
	EventBus.capacity_changed.connect(_on_capacity_changed)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.phase_changed.connect(_on_phase_changed)
	
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.unit_deselected.connect(_on_unit_deselected)
	EventBus.building_captured.connect(_on_building_captured)
	
	EventBus.victory_condition_met.connect(_on_victory_condition_met)
	EventBus.defeat_condition_met.connect(_on_defeat_condition_met)
	
	end_turn_btn.pressed.connect(show_end_turn_confirmation)
	confirm_btn.pressed.connect(_on_confirm_end_turn)
	cancel_btn.pressed.connect(hide_end_turn_confirmation)
	
	EventBus.surrender_decision_required.connect(_on_surrender_decision_required)
	EventBus.map_event_triggered.connect(_on_map_event_triggered)

	_setup_recruit_popup()
	_setup_surrender_modal()
	_update_context_text("Select unit to move/attack, or Castle to recruit.")


func show_end_turn_confirmation() -> void:
	if current_faction_id != 0: # Only allowed on player turn (Blue Kingdom)
		return
	end_turn_modal.show()
	confirm_btn.grab_focus()


func hide_end_turn_confirmation() -> void:
	end_turn_modal.hide()


func is_end_turn_confirmation_active() -> bool:
	return end_turn_modal.visible


func _on_confirm_end_turn() -> void:
	hide_end_turn_confirmation()
	end_turn_requested.emit()

var recruit_popup: PopupPanel
var recruit_vbox: VBoxContainer
signal recruit_unit_requested(building: Node, unit_data: Resource)

var upgrade_popup: PopupPanel
var upgrade_vbox: VBoxContainer
signal upgrade_unit_requested(unit: Node, target_data: Resource)

func _setup_recruit_popup() -> void:
	recruit_popup = PopupPanel.new()
	recruit_vbox = VBoxContainer.new()
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(recruit_vbox)
	recruit_popup.add_child(margin)
	add_child(recruit_popup)

	upgrade_popup = PopupPanel.new()
	upgrade_vbox = VBoxContainer.new()
	var upgrade_margin = MarginContainer.new()
	upgrade_margin.add_theme_constant_override("margin_left", 10)
	upgrade_margin.add_theme_constant_override("margin_right", 10)
	upgrade_margin.add_theme_constant_override("margin_top", 10)
	upgrade_margin.add_theme_constant_override("margin_bottom", 10)
	upgrade_margin.add_child(upgrade_vbox)
	upgrade_popup.add_child(upgrade_margin)
	add_child(upgrade_popup)

func show_recruit_popup(building: Node) -> void:
	for child in recruit_vbox.get_children():
		child.queue_free()

	var title = Label.new()
	title.text = "Select Unit to Recruit:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recruit_vbox.add_child(title)

	for unit_data in building.get("recruitable_units"):
		var btn = Button.new()
		btn.text = "%s (💰%d | ⛏️%d)" % [unit_data.unit_name, unit_data.recruit_cost_gold, unit_data.recruit_cost_iron]
		btn.pressed.connect(_on_recruit_button_pressed.bind(building, unit_data))
		recruit_vbox.add_child(btn)

	recruit_popup.popup_centered(Vector2(250, 200))

## Shows available promotions for `unit` (from its UnitData.upgrade_paths)
## alongside the Field Tax surcharge if not currently at a friendly Castle.
func show_upgrade_popup(unit: Node, is_at_castle: bool) -> void:
	for child in upgrade_vbox.get_children():
		child.queue_free()

	var title = Label.new()
	title.text = "Select Promotion:" if is_at_castle else "Select Promotion (⚠️ Field Tax 2x — not at Castle):"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_vbox.add_child(title)

	var paths: Dictionary = unit.unit_data.upgrade_paths if is_instance_valid(unit.unit_data) else {}
	for label in paths:
		var target_data = paths[label]
		var btn = Button.new()
		btn.text = "%s (💰%d | ⛏️%d)" % [target_data.unit_name, target_data.recruit_cost_gold, target_data.recruit_cost_iron]
		btn.pressed.connect(_on_upgrade_button_pressed.bind(unit, target_data))
		upgrade_vbox.add_child(btn)

	upgrade_popup.popup_centered(Vector2(250, 200))


func _on_recruit_button_pressed(building: Variant, unit_data: Variant) -> void:
	recruit_popup.hide()
	if is_instance_valid(building) and is_instance_valid(unit_data):
		recruit_unit_requested.emit(building, unit_data)


func _on_upgrade_button_pressed(unit: Variant, target_data: Variant) -> void:
	upgrade_popup.hide()
	if is_instance_valid(unit) and is_instance_valid(target_data):
		upgrade_unit_requested.emit(unit, target_data)

# ==============================================================================
# SURRENDER MODAL
# ==============================================================================

signal surrender_choice_made(unit: Node, choice: String)

var surrender_modal: Control
var surrender_text: Label
var _surrender_unit: TacticalUnit = null

## Built in code like the recruit and upgrade popups, but as a full-screen
## Control rather than a PopupPanel: a PopupPanel can be dismissed by clicking
## outside it, and a dismissed prompt would leave the prisoner frozen forever.
## This overlay has exactly two exits, both of which resolve the capture.
func _setup_surrender_modal() -> void:
	surrender_modal = ColorRect.new()
	surrender_modal.name = "SurrenderModal"
	surrender_modal.color = Color(0, 0, 0, 0.55)
	surrender_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	surrender_modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "🏳️ ENEMY SURRENDERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	surrender_text = Label.new()
	surrender_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(surrender_text)

	var capture_btn := Button.new()
	capture_btn.text = "⚔️  Capture (joins your army)"
	capture_btn.pressed.connect(_on_surrender_button.bind("capture"))
	box.add_child(capture_btn)

	var ransom_btn := Button.new()
	ransom_btn.text = "💰  Ransom (take the gold)"
	ransom_btn.pressed.connect(_on_surrender_button.bind("ransom"))
	box.add_child(ransom_btn)

	margin.add_child(box)
	panel.add_child(margin)
	surrender_modal.add_child(panel)
	add_child(surrender_modal)
	surrender_modal.hide()


func _on_surrender_decision_required(unit: Node, captor_faction_id: int) -> void:
	if not (unit is TacticalUnit):
		return
	_surrender_unit = unit as TacticalUnit

	var data: UnitData = _surrender_unit.unit_data
	var unit_name: String = data.unit_name if is_instance_valid(data) else _surrender_unit.name
	var ransom: int = 0
	var weight: int = 0
	if is_instance_valid(data):
		ransom = int(round(data.recruit_cost_gold * GameConfig.SURRENDER_RANSOM_RATIO))
		weight = data.capacity_weight

	var room: String = ""
	if is_instance_valid(economy_manager):
		var used: int = economy_manager.get_used_capacity(
			captor_faction_id, TurnManager.get_faction_units(captor_faction_id)
		)
		var maximum: int = economy_manager.get_max_capacity(captor_faction_id)
		room = "\nTroop Cap: %d/%d  (this unit costs %d)" % [used, maximum, weight]

	surrender_text.text = "%s has broken and lays down arms.\nRansom pays %d Gold.%s" % [
		unit_name, ransom, room
	]
	surrender_modal.show()


func _on_surrender_button(choice: String) -> void:
	surrender_modal.hide()
	if is_instance_valid(_surrender_unit):
		surrender_choice_made.emit(_surrender_unit, choice)
	_surrender_unit = null


func is_surrender_popup_active() -> bool:
	return is_instance_valid(surrender_modal) and surrender_modal.visible


## Narrate whatever came out of a chest.
func _on_map_event_triggered(event_type: String, _position: Vector2i, result: Dictionary) -> void:
	match event_type:
		"war_spoils":
			_update_context_text("🎁 War Spoils! +%d Gold, +%d Iron." % [result.get("gold", 0), result.get("iron", 0)])
		"mercenary":
			_update_context_text("🎁 A mercenary joins you: %s!" % result.get("unit_name", "Unknown"))
		"trap":
			_update_context_text("💥 It was a trap! %d damage." % result.get("damage", 0))
		"awaken_dead":
			_update_context_text("💀 You disturbed the dead — %d rise against you!" % result.get("count", 0))


func initialize(eco_mgr: Node, grid_mgr: Node = null) -> void:
	economy_manager = eco_mgr
	grid_manager = grid_mgr
	_refresh_resources(TurnManager.get_current_faction())
	_refresh_turn_label()

func _on_turn_started(faction_id: int) -> void:
	current_faction_id = faction_id
	if faction_id == 1: # RED_LEGION
		_update_context_text("🔴 AI TURN (RED LEGION) IS PLAYING...")
		end_turn_btn.disabled = true
	else:
		_update_context_text("🔵 YOUR TURN (BLUE KINGDOM)\nSelect unit or Castle.")
		end_turn_btn.disabled = false
	_refresh_resources(faction_id)
	_refresh_turn_label()

func _on_phase_changed(_new_phase: int) -> void:
	_refresh_turn_label()

func _refresh_resources(faction_id: int) -> void:
	if not economy_manager:
		return
	gold_label.text = "💰 Gold: %d" % economy_manager.get_gold(faction_id)
	iron_label.text = "⛏️ Iron: %d" % economy_manager.get_iron(faction_id)
	var max_cap = economy_manager.get_max_capacity(faction_id)
	var used_cap = economy_manager.get_used_capacity(faction_id, TurnManager.get_faction_units(faction_id))
	cap_label.text = "👥 Troop Cap: %d/%d" % [used_cap, max_cap]

func _on_gold_changed(faction_id: int, new_amount: int) -> void:
	if faction_id == current_faction_id:
		gold_label.text = "💰 Gold: %d" % new_amount

func _on_iron_changed(faction_id: int, new_amount: int) -> void:
	if faction_id == current_faction_id:
		iron_label.text = "⛏️ Iron: %d" % new_amount

func _on_capacity_changed(faction_id: int, used: int, max_cap: int) -> void:
	if faction_id == current_faction_id:
		cap_label.text = "👥 Troop Cap: %d/%d" % [used, max_cap]

func _refresh_turn_label() -> void:
	var phase_name = ""
	match TurnManager.current_phase:
		0: phase_name = "Upkeep"
		1: phase_name = "Production"
		2: phase_name = "Action"
		3: phase_name = "End"
	turn_label.text = "Turn %d - %s" % [TurnManager.turn_number, phase_name]

func _on_unit_selected(unit: Node) -> void:
	inspector_panel.show()
	var u_name: String = unit.unit_data.unit_name if is_instance_valid(unit.unit_data) else unit.name
	var hp_max: int = unit.unit_data.max_health if is_instance_valid(unit.unit_data) else 100
	var atk: int = unit.unit_data.attack_power if is_instance_valid(unit.unit_data) else 0
	var def: int = unit.unit_data.defense_power if is_instance_valid(unit.unit_data) else 0
	
	inspector_title.text = "⚔️ " + u_name
	inspector_stats.text = "HP: %d/%d | Move: %d\nATK: %d | DEF: %d\nAct: %s\n%s\n%s" % [
		unit.current_health, hp_max,
		unit.current_movement,
		atk, def,
		"Yes" if unit.can_act() else "No",
		_morale_line(unit as TacticalUnit),
		_terrain_line(unit as TacticalUnit),
	]
	var has_upgrades: bool = is_instance_valid(unit.unit_data) and not unit.unit_data.upgrade_paths.is_empty()
	if has_upgrades:
		_update_context_text("Click blue tile to move or enemy to attack.\n[U] Upgrade unit.")
	else:
		_update_context_text("Click blue tile to move or enemy to attack.")

## Morale readout: the band, the raw scalar, and what it is doing to damage.
func _morale_line(unit: TacticalUnit) -> String:
	if unit.is_morale_immune():
		return "Morale: — (undead, fearless by nature)"
	var level := unit.get_morale_level()
	var mult: float = unit.get_morale_attack_mult()
	return "Morale: %s (%d) ×%.2f ATK" % [
		GameConfig.MORALE_LABEL.get(level, "?"), unit.morale, mult
	]


## What the unit is standing in, and whether that helps or hurts.
func _terrain_line(unit: TacticalUnit) -> String:
	if not is_instance_valid(grid_manager):
		return ""
	var terrain = grid_manager.get_terrain(unit.grid_position)
	var name_text: String = str(GameConfig.terrain_rule(terrain, "name"))
	var taken: float = float(GameConfig.terrain_rule(terrain, "damage_taken_mult"))
	var note: String = "cover" if taken < 1.0 else ("exposed" if taken > 1.0 else "open")
	if bool(GameConfig.terrain_rule(terrain, "ambush")):
		note += ", ambush"
	return "Terrain: %s — ×%.2f dmg taken (%s)" % [name_text, taken, note]


func show_building_info(bld: Node) -> void:
	inspector_panel.show()
	var f_name: String = "Neutral"
	if bld.faction_id == 0:
		f_name = "Blue Kingdom"
	elif bld.faction_id == 1:
		f_name = "Red Legion"
		
	inspector_title.text = "🏰 " + bld.name
	inspector_stats.text = "Owner: %s" % f_name
	
	if bld.get("building_type") == 0: # CASTLE
		if bld.faction_id == current_faction_id:
			_update_context_text("Castle Selected. Press [R] to recruit.")
		else:
			_update_context_text("Enemy Castle. Capture it!")
	elif bld.get("building_type") == 1: # GOLD_MINE
		_update_context_text("Gold Mine (+50 Gold per turn).")

func _on_unit_deselected() -> void:
	inspector_panel.hide()
	if current_faction_id != 1:
		_update_context_text("Select unit or Castle.")

func _on_building_captured(building: Node, _faction_id: int) -> void:
	if inspector_panel.visible and inspector_title.text.contains(building.name):
		show_building_info(building)

func _update_context_text(text: String) -> void:
	context_label.text = text

func _on_victory_condition_met(faction_id: int, _condition: String) -> void:
	if faction_id == 0: # Blue (Player)
		victory_label.text = "VICTORY"
		victory_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	else:
		victory_label.text = "DEFEAT"
		victory_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	victory_label.show()

func _on_defeat_condition_met(faction_id: int, _condition: String) -> void:
	if faction_id == 0: # Blue (Player)
		victory_label.text = "DEFEAT"
		victory_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	else:
		victory_label.text = "VICTORY"
		victory_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	victory_label.show()
