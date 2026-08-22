extends Node2D
## TestGridController — Controller visual dan input interaktif untuk testing GridManager.
## Fitur:
## - Klik kiri pada Unit untuk memilih unit (dan highlight petak jangkauan jalan).
## - Klik kiri pada petak biru (reachable) untuk memindahkan unit.
## - Menampilkan garis grid dan area jangkauan dengan warna visual.

@onready var grid_manager: GridManager = $GridManager
@onready var unit_container: Node2D = $Units

var selected_unit: TacticalUnit = null
var reachable_cells: Array[Vector2i] = []
var attackable_cells: Array[Vector2i] = []


func _ready() -> void:
	# Hubungkan event saat movement selesai agar highlight di-refresh
	EventBus.unit_move_completed.connect(_on_unit_move_completed)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var clicked_cell = grid_manager.world_to_grid(mouse_pos)
		_handle_cell_click(clicked_cell)


func _handle_cell_click(cell: Vector2i) -> void:
	if not grid_manager.is_within_bounds(cell):
		_deselect_unit()
		return

	var unit_at_cell = grid_manager.get_unit_at(cell)

	# 1. Jika ada unit di petak ini, pilih unit tersebut
	if unit_at_cell != null:
		_select_unit(unit_at_cell)
		return

	# 2. Jika ada unit terpilih dan klik di petak yang bisa dijangkau, minta gerak!
	if selected_unit != null and reachable_cells.has(cell):
		EventBus.unit_move_requested.emit(selected_unit, cell)
		# Kosongkan highlight sementara saat bergerak
		reachable_cells.clear()
		attackable_cells.clear()
		queue_redraw()
		return

	# 3. Klik di luar jangkauan -> deselect
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
	queue_redraw()


func _deselect_unit() -> void:
	selected_unit = null
	reachable_cells.clear()
	attackable_cells.clear()
	EventBus.unit_deselected.emit()
	queue_redraw()


func _on_unit_move_completed(unit: Node, _from: Vector2i, _to: Vector2i) -> void:
	if unit == selected_unit:
		# Update highlight setelah sampai di tujuan
		_select_unit(selected_unit)


func _draw() -> void:
	if not grid_manager:
		return

	var cs = grid_manager.cell_size
	var gs = grid_manager.grid_size

	# 1. Gambar Garis Grid Background (Abu-abu tipis)
	for x in range(gs.x + 1):
		var start = Vector2(x * cs.x, 0)
		var end = Vector2(x * cs.x, gs.y * cs.y)
		draw_line(start, end, Color(1, 1, 1, 0.15), 1.0)

	for y in range(gs.y + 1):
		var start = Vector2(0, y * cs.y)
		var end = Vector2(gs.x * cs.x, y * cs.y)
		draw_line(start, end, Color(1, 1, 1, 0.15), 1.0)

	# 2. Gambar Highlight Jangkauan Serang (Merah Transparan)
	for cell in attackable_cells:
		var rect = Rect2(Vector2(cell.x * cs.x, cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.25))

	# 3. Gambar Highlight Jangkauan Gerak (Biru Transparan)
	for cell in reachable_cells:
		var rect = Rect2(Vector2(cell.x * cs.x, cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(0.2, 0.5, 1.0, 0.4))
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.8), false, 1.0)

	# 4. Highlight Petak Unit yang Dipilih (Kuning)
	if selected_unit:
		var u_cell = selected_unit.grid_position
		var rect = Rect2(Vector2(u_cell.x * cs.x, u_cell.y * cs.y), Vector2(cs.x, cs.y))
		draw_rect(rect, Color(1.0, 0.9, 0.1, 0.8), false, 2.0)
