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

var current_faction_id: int = 0
var economy_manager: Node = null

func _ready() -> void:
	# Hide inspector and victory at start
	inspector_panel.hide()
	victory_label.hide()
	
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
	
	end_turn_btn.pressed.connect(func(): end_turn_requested.emit())
	
	_setup_recruit_popup()
	_update_context_text("Select unit to move/attack, or Castle to recruit.")

var recruit_popup: PopupPanel
var recruit_vbox: VBoxContainer
signal recruit_unit_requested(building: Node, unit_data: Resource)

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
		btn.pressed.connect(func(): 
			recruit_popup.hide()
			recruit_unit_requested.emit(building, unit_data)
		)
		recruit_vbox.add_child(btn)
		
	recruit_popup.popup_centered(Vector2(250, 200))

func initialize(eco_mgr: Node) -> void:
	economy_manager = eco_mgr
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
	inspector_stats.text = "HP: %d/%d | Move: %d\nATK: %d | DEF: %d\nAct: %s" % [
		unit.current_health, hp_max,
		unit.current_movement,
		atk, def,
		"Yes" if unit.can_act() else "No"
	]
	_update_context_text("Click blue tile to move or enemy to attack.")

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
