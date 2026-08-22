extends Node2D

@onready var grid_manager: GridManager = $GridManager
@onready var combat_resolver: CombatResolver = $CombatResolver
@onready var economy_manager: Node = $EconomyManager
@onready var ai_manager: AIManager = $AIManager
@onready var unit_container: Node2D = $Units
@onready var building_container: Node2D = $Buildings
@onready var main_hud: CanvasLayer = $MainHUD

var selected_unit: TacticalUnit = null
var selected_building: Building = null
var reachable_cells: Array[Vector2i] = []
var attackable_cells: Array[Vector2i] = []

func _ready() -> void:
	EventBus.unit_move_completed.connect(_on_unit_move_completed)
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.building_captured.connect(_on_building_captured)
	EventBus.dialogue_generated.connect(_on_dialogue_generated)
	EventBus.story_event_narrated.connect(_on_story_event_narrated)
	
	if main_hud.has_signal("end_turn_requested"):
		main_hud.end_turn_requested.connect(end_turn)

	# 1. Daftarkan Faksi ke EconomyManager
	economy_manager.register_faction(GameConfig.Faction.BLUE_KINGDOM, 150, 4)
	economy_manager.register_faction(GameConfig.Faction.RED_LEGION, 150, 4)

	# 2. Setup AI Manager
	if ai_manager:
		ai_manager.setup(grid_manager, economy_manager)

	# 3. Setup match dengan EconomyManager terinjeksi
	TurnManager.setup_match([GameConfig.Faction.BLUE_KINGDOM, GameConfig.Faction.RED_LEGION], economy_manager)
	
	# Init HUD
	main_hud.initialize(economy_manager)
	
	TurnManager.start_turn()
	queue_redraw()

func _update_hud_text(text: String) -> void:
	if main_hud and main_hud.has_method("_update_context_text"):
		main_hud._update_context_text(text)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_tree().quit()
		return

	if TurnManager.get_current_faction() == GameConfig.Faction.RED_LEGION:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		end_turn()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_try_recruit_at_selected_castle()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var clicked_cell = grid_manager.world_to_grid(mouse_pos)
		_handle_cell_click(clicked_cell)

func end_turn() -> void:
	_deselect_all()
	TurnManager.advance_phase()
	if TurnManager.current_phase != GameConfig.Phase.UPKEEP:
		TurnManager._end_current_turn()

func _on_turn_started(faction_id: int) -> void:
	if faction_id == GameConfig.Faction.RED_LEGION:
		_deselect_all()
	else:
		# Player turn logic setup handled via EventBus to HUD natively
		pass

func _handle_cell_click(cell: Vector2i) -> void:
	if not grid_manager.is_within_bounds(cell):
		_deselect_all()
		return

	var unit_at_cell = grid_manager.get_unit_at(cell)
	var building_at_cell = grid_manager.get_building_at(cell)

	if selected_unit != null and unit_at_cell != null and unit_at_cell != selected_unit:
		if unit_at_cell.faction_id != selected_unit.faction_id and attackable_cells.has(cell):
			EventBus.unit_attack_requested.emit(selected_unit, unit_at_cell)
			_deselect_all()
			return

	if unit_at_cell != null:
		if unit_at_cell.faction_id == TurnManager.get_current_faction():
			_select_unit(unit_at_cell)
		else:
			_update_hud_text("⚠️ Enemy unit! Select your own unit.")
		return

	if selected_unit != null and reachable_cells.has(cell):
		EventBus.unit_move_requested.emit(selected_unit, cell)
		reachable_cells.clear()
		attackable_cells.clear()
		queue_redraw()
		return

	if building_at_cell != null:
		_select_building(building_at_cell)
		return

	_deselect_all()

func _select_unit(unit: TacticalUnit) -> void:
	_deselect_all()
	selected_unit = unit
	reachable_cells = grid_manager.get_reachable_cells(unit)
	if is_instance_valid(unit.unit_data):
		attackable_cells = grid_manager.get_attackable_cells(
			unit.grid_position,
			unit.unit_data.attack_range_min,
			unit.unit_data.attack_range_max
		)
	EventBus.unit_selected.emit(unit)
	queue_redraw()

func _select_building(bld: Building) -> void:
	_deselect_all()
	selected_building = bld
	if main_hud.has_method("show_building_info"):
		main_hud.show_building_info(bld)
	queue_redraw()

func _try_recruit_at_selected_castle() -> void:
	if not selected_building or selected_building.building_type != Building.BuildingType.CASTLE:
		_update_hud_text("⚠️ Select your Castle to recruit!")
		return
	if selected_building.faction_id != TurnManager.get_current_faction():
		_update_hud_text("⚠️ This castle belongs to the enemy!")
		return
	if selected_building.recruitable_units.is_empty():
		return

	var unit_data = selected_building.recruitable_units[0]
	var active_units = TurnManager.get_faction_units(selected_building.faction_id)
	
	var check = selected_building.can_recruit(unit_data, economy_manager, active_units)
	if not check["can_recruit"]:
		_update_hud_text("❌ Recruitment failed: %s" % check["reason"])
		return

	var spawn_cell := Vector2i(-1, -1)
	var dirs = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
	for d in dirs:
		var target = selected_building.grid_position + d
		if grid_manager.is_cell_walkable(target):
			spawn_cell = target
			break

	if spawn_cell == Vector2i(-1, -1):
		_update_hud_text("❌ Failed: All cells around Castle are full!")
		return

	var new_unit = selected_building.recruit_unit(unit_data, spawn_cell, economy_manager, unit_container)
	_update_hud_text("✨ Recruited %s at %s!" % [unit_data.unit_name, spawn_cell])
	queue_redraw()

func _deselect_all() -> void:
	selected_unit = null
	selected_building = null
	reachable_cells.clear()
	attackable_cells.clear()
	EventBus.unit_deselected.emit()
	queue_redraw()

func _on_unit_move_completed(unit: Node, _from: Vector2i, _to: Vector2i) -> void:
	if unit == selected_unit:
		_select_unit(selected_unit)

func _on_building_captured(building: Node, faction_id: int) -> void:
	var f_name = "BLUE KINGDOM" if faction_id == GameConfig.Faction.BLUE_KINGDOM else "RED LEGION"
	_update_hud_text("🚩 %s captured by %s!" % [building.name, f_name])

func _on_combat_resolved(result: Dictionary) -> void:
	var att: TacticalUnit = result["attacker"]
	var def: TacticalUnit = result["defender"]
	var pri = result["primary_attack"]
	var ctr = result.get("counter_attack", {})

	var att_name = att.unit_data.unit_name if is_instance_valid(att.unit_data) else att.name
	var def_name = def.unit_data.unit_name if is_instance_valid(def.unit_data) else def.name

	var log_str = "💥 %s hit %s for %d HP" % [att_name, def_name, pri["damage"]]

	if ctr.has("damage"):
		log_str += " | Counter: %d HP" % ctr["damage"]
	if result.get("defender_killed", false):
		log_str += " ➔ ☠️ %s DIED!" % def_name

	_update_hud_text(log_str)
	queue_redraw()

func _on_dialogue_generated(speaker_name: String, text: String, _emotion: String) -> void:
	_update_hud_text("💬 [%s]: %s" % [speaker_name, text])

func _on_story_event_narrated(title: String, body: String) -> void:
	_update_hud_text("📜 [%s]: %s" % [title, body])

func _draw() -> void:
	if not grid_manager:
		return

	var cs = grid_manager.cell_size
	var gs = grid_manager.grid_size

	for x in range(gs.x + 1):
		draw_line(Vector2(x * cs.x, 0), Vector2(x * cs.x, gs.y * cs.y), Color(1, 1, 1, 0.12), 1.0)
	for y in range(gs.y + 1):
		draw_line(Vector2(0, y * cs.y), Vector2(gs.x * cs.x, y * cs.y), Color(1, 1, 1, 0.12), 1.0)

	for cell in attackable_cells:
		var rect = Rect2(Vector2(cell.x * cs.x, cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.25))
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.6), false, 1.0)

	for cell in reachable_cells:
		var rect = Rect2(Vector2(cell.x * cs.x, cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(0.2, 0.5, 1.0, 0.35))
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.8), false, 1.0)

	if selected_unit:
		var u_cell = selected_unit.grid_position
		var rect = Rect2(Vector2(u_cell.x * cs.x, u_cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(1.0, 0.9, 0.1, 0.85), false, 2.0)

	if selected_building:
		var b_cell = selected_building.grid_position
		var rect = Rect2(Vector2(b_cell.x * cs.x, b_cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(0.2, 1.0, 0.4, 0.85), false, 2.0)
