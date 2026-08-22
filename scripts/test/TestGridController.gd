extends Node2D
## TestGridController — Controller interaktif untuk testing Grid, Movement & Combat.
## Fitur:
## - [ESC]: Keluar dari game seketika.
## - Klik Unit Kamu: Pilih unit (Highlight Biru = Area Jalan, Highlight Merah = Area Serang).
## - Klik Petak Biru: Bergerak ke petak tersebut.
## - Klik Unit Musuh (Petak Merah): Menyerang musuh (memicu CombatResolver)!

@onready var grid_manager: GridManager = $GridManager
@onready var combat_resolver: CombatResolver = $CombatResolver
@onready var unit_container: Node2D = $Units
@onready var hud_label: Label = $CanvasLayer/InstructionPanel/MarginContainer/Label

var selected_unit: TacticalUnit = null
var reachable_cells: Array[Vector2i] = []
var attackable_cells: Array[Vector2i] = []


func _ready() -> void:
	EventBus.unit_move_completed.connect(_on_unit_move_completed)
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.turn_started.connect(_on_turn_started)
	
	# Setup match 2 Faction: 0 (Blue), 1 (Red)
	TurnManager.setup_match([GameConfig.Faction.BLUE_KINGDOM, GameConfig.Faction.RED_LEGION], null)
	TurnManager.start_turn()
	
	queue_redraw()


func _update_hud_text(text: String) -> void:
	if hud_label:
		hud_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	# Shortcut ESC untuk keluar
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_tree().quit()
		return

	# Shortcut SPACE untuk End Turn / Ganti Giliran Faction
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		end_turn()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var clicked_cell = grid_manager.world_to_grid(mouse_pos)
		_handle_cell_click(clicked_cell)


func end_turn() -> void:
	_deselect_unit()
	TurnManager.advance_phase()
	# Karena ini prototipe cepat, jika masih di phase Action, kita skip ke End Turn
	if TurnManager.current_phase != GameConfig.Phase.UPKEEP:
		TurnManager._end_current_turn()


func _on_turn_started(faction_id: int) -> void:
	var faction_name = "BLUE KINGDOM" if faction_id == GameConfig.Faction.BLUE_KINGDOM else "RED LEGION"
	var color_emoji = "🔵" if faction_id == GameConfig.Faction.BLUE_KINGDOM else "🔴"
	_update_hud_text("%s GILIRAN %s (Turn %d)\n👉 Klik unitmu untuk bertindak. Tekan [SPASI] untuk End Turn / Ganti Giliran." % [
		color_emoji, faction_name, TurnManager.turn_number
	])


func _handle_cell_click(cell: Vector2i) -> void:
	if not grid_manager.is_within_bounds(cell):
		_deselect_unit()
		return

	var unit_at_cell = grid_manager.get_unit_at(cell)

	# 1. Jika ada unit terpilih dan klik pada musuh yang berada dalam jangkauan serang -> SERANG!
	if selected_unit != null and unit_at_cell != null and unit_at_cell != selected_unit:
		if unit_at_cell.faction_id != selected_unit.faction_id and attackable_cells.has(cell):
			EventBus.unit_attack_requested.emit(selected_unit, unit_at_cell)
			_deselect_unit()
			return

	# 2. Jika klik unit, cek apakah unit milik faction yang sedang aktif
	if unit_at_cell != null:
		if unit_at_cell.faction_id == TurnManager.get_current_faction():
			_select_unit(unit_at_cell)
		else:
			_update_hud_text("⚠️ Ini unit musuh / bukan giliran faction ini! Pilih unitmu sendiri untuk bergerak.")
		return

	# 3. Jika ada unit terpilih dan klik petak biru (jangkauan gerak), jalankan!
	if selected_unit != null and reachable_cells.has(cell):
		EventBus.unit_move_requested.emit(selected_unit, cell)
		reachable_cells.clear()
		attackable_cells.clear()
		queue_redraw()
		return

	# 4. Klik petak kosong di luar jangkauan -> Deselect
	_deselect_unit()


func _select_unit(unit: TacticalUnit) -> void:
	selected_unit = unit
	reachable_cells = grid_manager.get_reachable_cells(unit)
	if unit.unit_data:
		attackable_cells = grid_manager.get_attackable_cells(
			unit.grid_position,
			unit.unit_data.attack_range_min,
			unit.unit_data.attack_range_max
		)
	EventBus.unit_selected.emit(unit)
	var u_name: String = unit.unit_data.unit_name if is_instance_valid(unit.unit_data) else unit.name
	var hp_max: int = unit.unit_data.max_health if is_instance_valid(unit.unit_data) else 100
	_update_hud_text("⚔️ Dipilih: %s | HP: %d/%d | Sisa Move: %d | Bisa Act: %s\n👉 Klik petak biru untuk gerak atau klik musuh di jangkauan merah untuk serang!" % [
		u_name, unit.current_health, hp_max, unit.current_movement, str(unit.can_act())
	])
	queue_redraw()


func _deselect_unit() -> void:
	selected_unit = null
	reachable_cells.clear()
	attackable_cells.clear()
	EventBus.unit_deselected.emit()
	_update_hud_text("🎮 Klik Blue Pawn untuk pilih unit. Klik petak biru untuk gerak. Klik Red Warrior untuk serang!\nTekan [ESC] untuk keluar.")
	queue_redraw()


func _on_unit_move_completed(unit: Node, _from: Vector2i, _to: Vector2i) -> void:
	if unit == selected_unit:
		_select_unit(selected_unit)


func _on_combat_resolved(result: Dictionary) -> void:
	var att: TacticalUnit = result["attacker"]
	var def: TacticalUnit = result["defender"]
	var pri = result["primary_attack"]
	var ctr = result.get("counter_attack", {})

	var att_name = att.unit_data.unit_name if att.unit_data else att.name
	var def_name = def.unit_data.unit_name if def.unit_data else def.name

	var log_str = "💥 COMBAT REPORT:\n"
	log_str += "• %s serang %s ➔ Damage: -%d HP (%s, mult: x%.2f)" % [
		att_name, def_name, pri["damage"], pri["advantage_type"], pri["multiplier"]
	]

	if ctr.has("damage"):
		log_str += "\n• %s balas counter ➔ Damage: -%d HP!" % [def_name, ctr["damage"]]

	if result.get("defender_killed", false):
		log_str += " ➔ ☠️ %s TEWAS!" % def_name

	_update_hud_text(log_str)
	print(log_str)
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
