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
var hovered_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	# TileMapLayer.z_index is set to -1 (in the scene file) so it draws below
	# this node's own _draw() highlights. z_index here alone would NOT work:
	# TileMapLayer is our own child, so z_as_relative would tie its effective
	# z_index to ours, and ties resolve by tree order (children paint over
	# their parent's _draw()).

	EventBus.unit_move_completed.connect(_on_unit_move_completed)
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.building_captured.connect(_on_building_captured)
	EventBus.dialogue_generated.connect(_on_dialogue_generated)
	EventBus.story_event_narrated.connect(_on_story_event_narrated)

	if main_hud.has_signal("end_turn_requested"):
		main_hud.end_turn_requested.connect(end_turn)
	if main_hud.has_signal("recruit_unit_requested"):
		main_hud.recruit_unit_requested.connect(_do_recruit)

	# 1. Daftarkan Faksi ke EconomyManager
	economy_manager.register_faction(GameConfig.Faction.BLUE_KINGDOM, 150, 4)
	economy_manager.register_faction(GameConfig.Faction.RED_LEGION, 150, 4)

	# 2. Setup AI Manager
	if ai_manager:
		ai_manager.setup(grid_manager, economy_manager)

	# 3. Setup match dengan EconomyManager terinjeksi
	TurnManager.setup_match(
		[GameConfig.Faction.BLUE_KINGDOM, GameConfig.Faction.RED_LEGION],
		economy_manager,
	)

	# 4. Generate tactical map layout on TileMapLayer
	_setup_tactical_tilemap()

	# Init HUD
	main_hud.initialize(economy_manager)

	TurnManager.start_turn()
	queue_redraw()


## Generates a complete, lush 16x10 tactical battlefield with roads and foliage
func _setup_tactical_tilemap() -> void:
	var tilemap: TileMapLayer = get_node_or_null("TileMapLayer")
	if not tilemap:
		return

	var gs = grid_manager.grid_size # Vector2i(16, 10)

	# 1. Fill entire grid with grass base
	for x in range(gs.x):
		for y in range(gs.y):
			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(1, 1))

	# 2. Dirt pathways connecting Castles and Mine
	var road_cells = [
		Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 3), Vector2i(4, 4),
		Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5), Vector2i(6, 4),
		Vector2i(7, 4), Vector2i(8, 4), Vector2i(8, 5), Vector2i(9, 5), Vector2i(9, 6), Vector2i(10, 6)
	]
	for cell in road_cells:
		tilemap.set_cell(cell, 0, Vector2i(6, 1)) # Dirt center tile

	# 3. Subtle foliage / grass flower details
	var detail_cells = {
		Vector2i(0, 3): Vector2i(3, 0),
		Vector2i(1, 7): Vector2i(3, 1),
		Vector2i(7, 1): Vector2i(3, 0),
		Vector2i(12, 2): Vector2i(3, 1),
		Vector2i(14, 8): Vector2i(3, 0),
		Vector2i(8, 8): Vector2i(3, 1),
		Vector2i(11, 2): Vector2i(3, 0),
		Vector2i(13, 5): Vector2i(3, 1),
	}
	for cell in detail_cells.keys():
		tilemap.set_cell(cell, 0, detail_cells[cell])


func _update_hud_text(text: String) -> void:
	if main_hud and main_hud.has_method("_update_context_text"):
		main_hud._update_context_text(text)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if main_hud and main_hud.has_method("is_end_turn_confirmation_active") and main_hud.is_end_turn_confirmation_active():
			main_hud.hide_end_turn_confirmation()
			return
		if selected_unit or selected_building:
			_deselect_all()
			return
		get_tree().quit()
		return

	if TurnManager.get_current_faction() == GameConfig.Faction.RED_LEGION:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if main_hud and main_hud.has_method("is_end_turn_confirmation_active"):
			if main_hud.is_end_turn_confirmation_active():
				main_hud._on_confirm_end_turn()
			else:
				main_hud.show_end_turn_confirmation()
		else:
			end_turn()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_try_recruit_at_selected_castle()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if main_hud and main_hud.has_method("is_end_turn_confirmation_active") and main_hud.is_end_turn_confirmation_active():
			return
		var mouse_pos = get_global_mouse_position()
		var clicked_cell = grid_manager.world_to_grid(mouse_pos)
		_handle_cell_click(clicked_cell)


func end_turn() -> void:
	_deselect_all()
	TurnManager.end_turn()


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
			unit.unit_data.attack_range_max,
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

	if main_hud.has_method("show_recruit_popup"):
		main_hud.show_recruit_popup(selected_building)


func _do_recruit(building: Building, unit_data: Resource) -> void:
	var active_units = TurnManager.get_faction_units(building.faction_id)

	var check = building.can_recruit(unit_data, economy_manager, active_units)
	if not check["can_recruit"]:
		_update_hud_text("❌ Recruitment failed: %s" % check["reason"])
		return

	var spawn_cell := Vector2i(-1, -1)
	var dirs = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
	for d in dirs:
		var target = building.grid_position + d
		if grid_manager.is_cell_walkable(target):
			spawn_cell = target
			break

	if spawn_cell == Vector2i(-1, -1):
		_update_hud_text("❌ Failed: All cells around Castle are full!")
		return

	var new_unit = building.recruit_unit(unit_data, spawn_cell, economy_manager, unit_container)
	_update_hud_text("✨ Recruited %s at %s!" % [unit_data.unit_name, spawn_cell])
	queue_redraw()


func _deselect_all() -> void:
	selected_unit = null
	selected_building = null
	reachable_cells.clear()
	attackable_cells.clear()
	EventBus.unit_deselected.emit()
	queue_redraw()


func _on_unit_move_completed(unit: TacticalUnit, _from_cell: Vector2i, _to_cell: Vector2i) -> void:
	if unit.faction_id == 0:
		_select_unit(unit)
	queue_redraw()


func _on_building_captured(building: Building, _new_faction_id: int) -> void:
	_update_hud_text("🚩 Building captured: %s!" % building.name)
	queue_redraw()


func _on_combat_resolved(result: Dictionary) -> void:
	var att_name = result.get("attacker", null)
	var def_name = result.get("defender", null)
	att_name = att_name.unit_data.unit_name if is_instance_valid(att_name) and is_instance_valid(att_name.unit_data) else "Attacker"
	def_name = def_name.unit_data.unit_name if is_instance_valid(def_name) and is_instance_valid(def_name.unit_data) else "Defender"

	var prim = result.get("primary_attack", {})
	var ctr = result.get("counter_attack", {})
	var log_str = "⚔️ %s hit %s for %d HP" % [att_name, def_name, prim.get("damage", 0)]

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

	# 1. Grid lines (Tactical overlay mesh)
	for x in range(gs.x + 1):
		draw_line(Vector2(x * cs.x, 0), Vector2(x * cs.x, gs.y * cs.y), Color(1, 1, 1, 0.18), 1.0)
	for y in range(gs.y + 1):
		draw_line(Vector2(0, y * cs.y), Vector2(gs.x * cs.x, y * cs.y), Color(1, 1, 1, 0.18), 1.0)

	# 2. Reachable Move Cells (Vibrant Blue with glowing border and center dot)
	for cell in reachable_cells:
		var rect = Rect2(Vector2(cell.x * cs.x, cell.y * cs.y), Vector2(cs.x, cs.y))
		var center = rect.get_center()
		draw_rect(rect, Color(0.12, 0.58, 1.0, 0.42))
		draw_rect(rect, Color(0.35, 0.9, 1.0, 0.95), false, 2.5)
		draw_circle(center, 4.5, Color(0.6, 0.95, 1.0, 0.9))

	# 3. Attackable Cells (Vibrant Crimson Red with Hazard border and Crosshair)
	for cell in attackable_cells:
		var rect = Rect2(Vector2(cell.x * cs.x, cell.y * cs.y), Vector2(cs.x, cs.y))
		var center = rect.get_center()
		draw_rect(rect, Color(1.0, 0.15, 0.15, 0.48))
		draw_rect(rect, Color(1.0, 0.35, 0.35, 1.0), false, 3.0)
		# Crosshair reticle
		draw_line(center - Vector2(10, 0), center + Vector2(10, 0), Color(1.0, 0.9, 0.9, 0.95), 2.0)
		draw_line(center - Vector2(0, 10), center + Vector2(0, 10), Color(1.0, 0.9, 0.9, 0.95), 2.0)
		draw_circle(center, 4.0, Color(1.0, 0.2, 0.2, 0.9))

	# 4. Selected Unit Highlight (Golden double ring)
	if selected_unit:
		var u_cell = selected_unit.grid_position
		var rect = Rect2(Vector2(u_cell.x * cs.x, u_cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(1.0, 0.85, 0.15, 0.25))
		draw_rect(rect, Color(1.0, 0.92, 0.2, 1.0), false, 3.5)

	# 5. Selected Building Highlight (Emerald ring)
	if selected_building:
		var b_cell = selected_building.grid_position
		var rect = Rect2(Vector2(b_cell.x * cs.x, b_cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(0.2, 0.95, 0.45, 0.25))
		draw_rect(rect, Color(0.3, 1.0, 0.5, 1.0), false, 3.5)

	# 6. Hovered Cell Cursor
	if hovered_cell.x >= 0 and hovered_cell.x < gs.x and hovered_cell.y >= 0 and hovered_cell.y < gs.y:
		var rect = Rect2(Vector2(hovered_cell.x * cs.x, hovered_cell.y * cs.y), Vector2(cs.x, cs.y))
		var pad = 4.0
		# Corner brackets
		var tl = rect.position + Vector2(pad, pad)
		var tr = Vector2(rect.end.x - pad, rect.position.y + pad)
		var bl = Vector2(rect.position.x + pad, rect.end.y - pad)
		var br = rect.end - Vector2(pad, pad)
		var clr = Color(1.0, 1.0, 1.0, 0.8)
		draw_line(tl, tl + Vector2(10, 0), clr, 2.0)
		draw_line(tl, tl + Vector2(0, 10), clr, 2.0)
		draw_line(tr, tr - Vector2(10, 0), clr, 2.0)
		draw_line(tr, tr + Vector2(0, 10), clr, 2.0)
		draw_line(bl, bl + Vector2(10, 0), clr, 2.0)
		draw_line(bl, bl - Vector2(0, 10), clr, 2.0)
		draw_line(br, br - Vector2(10, 0), clr, 2.0)
		draw_line(br, br - Vector2(0, 10), clr, 2.0)
