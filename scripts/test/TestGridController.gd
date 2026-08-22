extends Node2D
## TestGridController — Interactive controller for testing Grid, Combat, Economy & Recruitment.
## Fitur:
## - [ESC]: Quit the game immediately.
## - [SPASI]: End Turn / Ganti Giliran Faction (Memicu Upkeep & Income).
## - [R]: Recruit New Unit if active faction's Castle is selected.
## - Klik Unit: Bergerak & Serang.
## - Klik Bangunan: Menampilkan info bangunan & opsi rekrutmen.

@onready var grid_manager: GridManager = $GridManager
@onready var combat_resolver: CombatResolver = $CombatResolver
@onready var economy_manager: Node = $EconomyManager
@onready var ai_manager: AIManager = $AIManager
@onready var unit_container: Node2D = $Units
@onready var building_container: Node2D = $Buildings
@onready var hud_label: Label = $CanvasLayer/InstructionPanel/MarginContainer/Label

var selected_unit: TacticalUnit = null
var selected_building: Building = null
var reachable_cells: Array[Vector2i] = []
var attackable_cells: Array[Vector2i] = []


func _ready() -> void:
	EventBus.unit_move_completed.connect(_on_unit_move_completed)
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.building_captured.connect(_on_building_captured)
	EventBus.gold_changed.connect(_on_resource_changed)
	EventBus.iron_changed.connect(_on_resource_changed)

	# 1. Daftarkan Faksi ke EconomyManager
	economy_manager.register_faction(GameConfig.Faction.BLUE_KINGDOM, 150, 4)
	economy_manager.register_faction(GameConfig.Faction.RED_LEGION, 150, 4)

	# 2. Setup AI Manager
	if ai_manager:
		ai_manager.setup(grid_manager, economy_manager)

	# 3. Setup match dengan EconomyManager terinjeksi
	TurnManager.setup_match([GameConfig.Faction.BLUE_KINGDOM, GameConfig.Faction.RED_LEGION], economy_manager)
	TurnManager.start_turn()

	queue_redraw()


func _get_resource_header(faction_id: int) -> String:
	var gold = economy_manager.get_gold(faction_id)
	var iron = economy_manager.get_iron(faction_id)
	var max_cap = economy_manager.get_max_capacity(faction_id)
	var used_cap = economy_manager.get_used_capacity(faction_id, TurnManager.get_faction_units(faction_id))
	return "💰 Gold: %d  |  ⛏️ Iron: %d  |  👥 Troop Cap: %d/%d" % [gold, iron, used_cap, max_cap]


func _update_hud_text(text: String) -> void:
	if hud_label:
		var curr_faction = TurnManager.get_current_faction()
		var header = _get_resource_header(curr_faction)
		hud_label.text = header + "\n" + text


func _unhandled_input(event: InputEvent) -> void:
	# ESC shortcut to quit
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_tree().quit()
		return

	# Ignore control input if it is Red Legion AI's turn
	if TurnManager.get_current_faction() == GameConfig.Faction.RED_LEGION:
		return

	# SPACE shortcut to End Turn
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		end_turn()
		return

	# R shortcut to Recruit Unit if Castle is selected
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
		_update_hud_text("🔴 GILIRAN AI (RED LEGION) SEDANG BERLANGSUNG...\n⏳ Musuh sedang merekrut & menggerakkan pasukannya...")
	else:
		_update_hud_text("🔵 YOUR TURN (BLUE KINGDOM) - Turn %d\n👉 Select unit to move/attack, or select Castle to recruit [R]. Press [SPACE] to End Turn." % [
			TurnManager.turn_number
		])


func _on_resource_changed(_faction_id: int, _amount: int) -> void:
	queue_redraw()


func _handle_cell_click(cell: Vector2i) -> void:
	if not grid_manager.is_within_bounds(cell):
		_deselect_all()
		return

	var unit_at_cell = grid_manager.get_unit_at(cell)
	var building_at_cell = grid_manager.get_building_at(cell)

	# 1. Attack enemy unit in red range
	if selected_unit != null and unit_at_cell != null and unit_at_cell != selected_unit:
		if unit_at_cell.faction_id != selected_unit.faction_id and attackable_cells.has(cell):
			EventBus.unit_attack_requested.emit(selected_unit, unit_at_cell)
			_deselect_all()
			return

	# 2. Memilih unit sendiri
	if unit_at_cell != null:
		if unit_at_cell.faction_id == TurnManager.get_current_faction():
			_select_unit(unit_at_cell)
		else:
			_update_hud_text("⚠️ Enemy unit / not this faction's turn! Select your own unit.")
		return

	# 3. Move to blue cell
	if selected_unit != null and reachable_cells.has(cell):
		EventBus.unit_move_requested.emit(selected_unit, cell)
		reachable_cells.clear()
		attackable_cells.clear()
		queue_redraw()
		return

	# 4. Memilih Bangunan (Castle / Mine)
	if building_at_cell != null:
		_select_building(building_at_cell)
		return

	# 5. Click empty cell
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
	var u_name: String = unit.unit_data.unit_name if is_instance_valid(unit.unit_data) else unit.name
	var hp_max: int = unit.unit_data.max_health if is_instance_valid(unit.unit_data) else 100
	_update_hud_text("⚔️ Selected: %s | HP: %d/%d | Move: %d | Act: %s\n👉 Click blue tile to move or click enemy in red range to attack!" % [
		u_name, unit.current_health, hp_max, unit.current_movement, str(unit.can_act())
	])
	queue_redraw()


func _select_building(bld: Building) -> void:
	_deselect_all()
	selected_building = bld
	var f_name = "Neutral"
	if bld.faction_id == GameConfig.Faction.BLUE_KINGDOM:
		f_name = "Blue Kingdom"
	elif bld.faction_id == GameConfig.Faction.RED_LEGION:
		f_name = "Red Legion"

	if bld.building_type == Building.BuildingType.CASTLE:
		if bld.faction_id == TurnManager.get_current_faction():
			_update_hud_text("🏰 YOUR CASTLE (%s) | Press [R] to Recruit Blue Pawn (50 Gold, 1 Iron)!" % f_name)
		else:
			_update_hud_text("🏰 Enemy Castle (%s) | Enter this tile to capture it!" % f_name)
	elif bld.building_type == Building.BuildingType.GOLD_MINE:
		_update_hud_text("⛏️ GOLD MINE (%s) | Generates +50 Gold per turn during Upkeep." % f_name)
	else:
		_update_hud_text("🏠 BANGUNAN (%s)" % f_name)

	queue_redraw()


func _try_recruit_at_selected_castle() -> void:
	if not selected_building or selected_building.building_type != Building.BuildingType.CASTLE:
		_update_hud_text("⚠️ Pilih Castle milikmu terlebih dahulu sebelum menekan [R]!")
		return
	if selected_building.faction_id != TurnManager.get_current_faction():
		_update_hud_text("⚠️ This castle does not belong to the active faction!")
		return
	if selected_building.recruitable_units.is_empty():
		return

	var unit_data = selected_building.recruitable_units[0]
	var active_units = TurnManager.get_faction_units(selected_building.faction_id)
	
	# Cek syarat rekrut
	var check = selected_building.can_recruit(unit_data, economy_manager, active_units)
	if not check["can_recruit"]:
		_update_hud_text("❌ Gagal Rekrut: %s" % check["reason"])
		return

	# Find an empty cell around the Castle (orthogonal 4 directions)
	var spawn_cell := Vector2i(-1, -1)
	var dirs = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
	for d in dirs:
		var target = selected_building.grid_position + d
		if grid_manager.is_cell_walkable(target):
			spawn_cell = target
			break

	if spawn_cell == Vector2i(-1, -1):
		_update_hud_text("❌ Recruitment Failed: All cells around the Castle are full!")
		return

	# Rekrut unit!
	var new_unit = selected_building.recruit_unit(unit_data, spawn_cell, economy_manager, unit_container)
	_update_hud_text("✨ Berhasil merekrut %s di koordinat %s! (Biaya: %d Gold, %d Iron)" % [
		unit_data.unit_name, spawn_cell, unit_data.recruit_cost_gold, unit_data.recruit_cost_iron
	])
	queue_redraw()


func _deselect_all() -> void:
	selected_unit = null
	selected_building = null
	reachable_cells.clear()
	attackable_cells.clear()
	EventBus.unit_deselected.emit()
	_update_hud_text("🎮 Click unit to act, click Castle to recruit [R]. Press [SPACE] to End Turn.")
	queue_redraw()


func _on_unit_move_completed(unit: Node, _from: Vector2i, _to: Vector2i) -> void:
	if unit == selected_unit:
		_select_unit(selected_unit)


func _on_building_captured(building: Node, faction_id: int) -> void:
	if building is Building:
		var f_name = "BLUE KINGDOM" if faction_id == GameConfig.Faction.BLUE_KINGDOM else "RED LEGION"
		_update_hud_text("🚩 BUILDING CAPTURED! %s is now controlled by %s!" % [building.name, f_name])


func _on_combat_resolved(result: Dictionary) -> void:
	var att: TacticalUnit = result["attacker"]
	var def: TacticalUnit = result["defender"]
	var pri = result["primary_attack"]
	var ctr = result.get("counter_attack", {})

	var att_name = att.unit_data.unit_name if is_instance_valid(att.unit_data) else att.name
	var def_name = def.unit_data.unit_name if is_instance_valid(def.unit_data) else def.name

	var log_str = "💥 COMBAT REPORT:\n• %s serang %s ➔ -%d HP (%s, x%.2f)" % [
		att_name, def_name, pri["damage"], pri["advantage_type"], pri["multiplier"]
	]

	if ctr.has("damage"):
		log_str += " | Counter: -%d HP!" % ctr["damage"]
	if result.get("defender_killed", false):
		log_str += " ➔ ☠️ %s TEWAS!" % def_name

	_update_hud_text(log_str)
	queue_redraw()


func _draw() -> void:
	if not grid_manager:
		return

	var cs = grid_manager.cell_size
	var gs = grid_manager.grid_size

	# 1. Garis Grid
	for x in range(gs.x + 1):
		draw_line(Vector2(x * cs.x, 0), Vector2(x * cs.x, gs.y * cs.y), Color(1, 1, 1, 0.12), 1.0)
	for y in range(gs.y + 1):
		draw_line(Vector2(0, y * cs.y), Vector2(gs.x * cs.x, y * cs.y), Color(1, 1, 1, 0.12), 1.0)

	# 2. Area Jangkauan Serang (Merah)
	for cell in attackable_cells:
		var rect = Rect2(Vector2(cell.x * cs.x, cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.25))
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.6), false, 1.0)

	# 3. Area Jangkauan Gerak (Biru)
	for cell in reachable_cells:
		var rect = Rect2(Vector2(cell.x * cs.x, cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(0.2, 0.5, 1.0, 0.35))
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.8), false, 1.0)

	# 4. Highlight Unit Aktif (Kuning)
	if selected_unit:
		var u_cell = selected_unit.grid_position
		var rect = Rect2(Vector2(u_cell.x * cs.x, u_cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(1.0, 0.9, 0.1, 0.85), false, 2.0)

	# 5. Highlight Bangunan Aktif (Hijau / Cyan)
	if selected_building:
		var b_cell = selected_building.grid_position
		var rect = Rect2(Vector2(b_cell.x * cs.x, b_cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(0.2, 1.0, 0.4, 0.85), false, 2.0)
