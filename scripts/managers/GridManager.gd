extends Node
class_name GridManager
## GridManager — Logic layer manager for grid-based positioning & pathfinding.
## Uses Godot 4's AStarGrid2D for efficient tactical movement calculations.
## Decoupled: communicates state changes via EventBus.

@export_group("Grid Settings")
## Size of a single grid cell in pixels (e.g., 16x16 or 32x32)
@export var cell_size: Vector2i = Vector2i(16, 16)
## Grid area size in number of cells (width x height)
@export var grid_size: Vector2i = Vector2i(30, 20)
## Grid position offset from map origin (0,0)
@export var grid_offset: Vector2 = Vector2.ZERO
## Unit movement animation speed per cell (seconds)
@export var move_duration_per_tile: float = 0.15

# === Core Pathfinding & Tracking ===
var astar: AStarGrid2D
## Mapping of cell positions to units: Dictionary[Vector2i, TacticalUnit]
var _occupied_cells: Dictionary = {}
## Mapping of cell positions to obstacles/buildings: Dictionary[Vector2i, Node]
var _obstacle_cells: Dictionary = {}
## Set status unit yang sedang dalam proses animasi bergerak
var _moving_units: Dictionary = {}


func _ready() -> void:
	_initialize_astar_grid()
	_connect_event_bus()
	# Register units already in the scene tree on load
	call_deferred("_auto_register_existing_units")


func _auto_register_existing_units() -> void:
	var tree = get_tree()
	if not tree:
		return
	# Cari semua node TacticalUnit di scene
	for node in tree.root.find_children("*", "TacticalUnit", true, false):
		if node is TacticalUnit:
			var cell = world_to_grid(node.global_position)
			register_unit(node, cell)


# ==============================================================================
# STEP 1: INISIALISASI & KONVERSI KOORDINAT
# ==============================================================================

func _initialize_astar_grid() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, grid_size.x, grid_size.y)
	astar.cell_size = Vector2(cell_size)
	astar.offset = grid_offset
	# Game taktis klasik (orthogonal 4 arah: Atas, Bawah, Kiri, Kanan)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()


## Convert world coordinates (pixels) to grid cell coordinates (Vector2i)
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos = world_pos - grid_offset
	return Vector2i(
		int(floor(local_pos.x / float(cell_size.x))),
		int(floor(local_pos.y / float(cell_size.y)))
	)


## Convert grid cell coordinates (Vector2i) to world coordinate center (pixels)
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return grid_offset + Vector2(
		grid_pos.x * cell_size.x + (cell_size.x / 2.0),
		grid_pos.y * cell_size.y + (cell_size.y / 2.0)
	)


## Check if cell coordinates are within the map bounds
func is_within_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y


# ==============================================================================
# STEP 2: OCCUPANCY & POSISI UNIT / OBSTACLE
# ==============================================================================

func _connect_event_bus() -> void:
	EventBus.unit_spawned.connect(_on_unit_spawned)
	EventBus.unit_died.connect(_on_unit_removed)
	EventBus.unit_deserted.connect(_on_unit_removed)
	EventBus.unit_move_requested.connect(_on_unit_move_requested)


## Check if cell is walkable (no other obstacles/units)
func is_cell_walkable(cell: Vector2i, ignore_unit: TacticalUnit = null) -> bool:
	if not is_within_bounds(cell):
		return false
	if astar.is_point_solid(cell):
		# If solid due to an ignored unit (e.g., self when calculating route)
		if _occupied_cells.get(cell) == ignore_unit:
			return true
		return false
	if _obstacle_cells.has(cell):
		return false
	if _occupied_cells.has(cell):
		var occupant = _occupied_cells[cell]
		if occupant != ignore_unit:
			return false
	return true


## Daftarkan unit ke posisi grid tertentu
func register_unit(unit: TacticalUnit, cell: Vector2i) -> void:
	if not is_within_bounds(cell):
		push_warning("GridManager: Unit %s spawned outside grid bounds at %s" % [unit.name, cell])
		return
	
	unregister_unit(unit)
	
	_occupied_cells[cell] = unit
	unit.grid_position = cell
	unit.global_position = grid_to_world(cell)
	astar.set_point_solid(cell, true)


## Remove unit registration from grid
func unregister_unit(unit: TacticalUnit) -> void:
	var existing_cell := Vector2i(-1, -1)
	for cell in _occupied_cells:
		if _occupied_cells[cell] == unit:
			existing_cell = cell
			break
	
	if existing_cell != Vector2i(-1, -1):
		_occupied_cells.erase(existing_cell)
		if not _obstacle_cells.has(existing_cell):
			astar.set_point_solid(existing_cell, false)


## Mark a cell as impassable terrain (water, cliff). Kept separate from unit
## occupancy so a unit dying on a bridge tile cannot accidentally clear the
## river next to it.
func set_terrain_blocked(cell: Vector2i, blocked: bool = true) -> void:
	if not is_within_bounds(cell):
		return
	if blocked:
		_obstacle_cells[cell] = true
		astar.set_point_solid(cell, true)
	else:
		_obstacle_cells.erase(cell)
		if not _occupied_cells.has(cell):
			astar.set_point_solid(cell, false)


## Bulk variant used by MapBuilder once the battlefield is painted.
func set_terrain_blocked_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		set_terrain_blocked(cell, true)


## Total battlefield size in world pixels — used to clamp the camera.
func get_map_pixel_size() -> Vector2:
	return Vector2(grid_size.x * cell_size.x, grid_size.y * cell_size.y)


## Get unit at a specific tile (if any)
func get_unit_at(cell: Vector2i) -> TacticalUnit:
	return _occupied_cells.get(cell, null)


# ==============================================================================
# STEP 3: KALKULASI JANGKAUAN (MOVEMENT & ATTACK RANGE)
# ==============================================================================

## Get a list of all cells the unit can reach with its remaining movement (BFS / Flood Fill)
func get_reachable_cells(unit: TacticalUnit) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	if not is_instance_valid(unit) or not unit.can_move():
		return reachable

	var max_steps: int = unit.current_movement
	var start_cell: Vector2i = unit.grid_position
	
	# Antrean BFS: [Vector2i, cost_so_far]
	var queue: Array[Dictionary] = [{"cell": start_cell, "cost": 0}]
	var visited: Dictionary = {start_cell: 0}

	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	while queue.size() > 0:
		var current = queue.pop_front()
		var curr_cell: Vector2i = current["cell"]
		var curr_cost: int = current["cost"]

		if curr_cost > 0 and curr_cell != start_cell:
			# Destination cell must not be occupied by another unit
			if not _occupied_cells.has(curr_cell):
				reachable.append(curr_cell)

		if curr_cost >= max_steps:
			continue

		for dir in directions:
			var next_cell = curr_cell + dir
			var next_cost = curr_cost + 1 # Default step cost = 1 (bisa dimodif terrain)

			if not is_within_bounds(next_cell):
				continue
			if _obstacle_cells.has(next_cell):
				continue
			
			# Check unit obstacles: enemy units block the path
			if _occupied_cells.has(next_cell):
				var other_unit: TacticalUnit = _occupied_cells[next_cell]
				if other_unit != unit and other_unit.faction_id != unit.faction_id:
					continue # Musuh memblokir jalan

			if not visited.has(next_cell) or next_cost < visited[next_cell]:
				visited[next_cell] = next_cost
				queue.append({"cell": next_cell, "cost": next_cost})

	return reachable


## Get list of attackable tiles from a specific position
func get_attackable_cells(origin_cell: Vector2i, min_range: int, max_range: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(-max_range, max_range + 1):
		for y in range(-max_range, max_range + 1):
			var dist = abs(x) + abs(y) # Manhattan Distance
			if dist >= min_range and dist <= max_range:
				var target_cell = origin_cell + Vector2i(x, y)
				if is_within_bounds(target_cell):
					cells.append(target_cell)
	return cells


## Get tile route from start to destination using AStar
func get_path_cells(from_cell: Vector2i, to_cell: Vector2i, _unit: TacticalUnit = null) -> Array[Vector2i]:
	var path_array: Array[Vector2i] = []
	if not is_within_bounds(from_cell) or not is_within_bounds(to_cell):
		return path_array

	# Lepaskan sementara status solid titik awal & akhir agar AStar bisa menemukan rute
	astar.set_point_solid(from_cell, false)
	var target_was_solid = astar.is_point_solid(to_cell)
	astar.set_point_solid(to_cell, false)

	var raw_path = astar.get_id_path(from_cell, to_cell)

	# Kembalikan status solid
	astar.set_point_solid(from_cell, true)
	if target_was_solid:
		astar.set_point_solid(to_cell, true)

	for p in raw_path:
		path_array.append(Vector2i(p.x, p.y))

	return path_array


# ==============================================================================
# STEP 4: EKSEKUSI PERGERAKAN UNIT (TWEENING & EVENTBUS)
# ==============================================================================

func _on_unit_move_requested(unit: Node, target_cell: Vector2i) -> void:
	if not unit is TacticalUnit:
		return
	var tactical_unit: TacticalUnit = unit as TacticalUnit
	if _moving_units.has(tactical_unit):
		return # Unit masih dalam proses animasi bergerak

	var from_cell: Vector2i = tactical_unit.grid_position
	if from_cell == target_cell:
		return

	# Cek apakah target valid dalam jangkauan
	var reachable = get_reachable_cells(tactical_unit)
	if not reachable.has(target_cell):
		push_warning("GridManager: Cell %s unreachable for unit %s" % [target_cell, tactical_unit.name])
		return

	var path = get_path_cells(from_cell, target_cell, tactical_unit)
	if path.size() <= 1:
		return

	_execute_unit_movement(tactical_unit, path)


func _execute_unit_movement(unit: TacticalUnit, path: Array[Vector2i]) -> void:
	_moving_units[unit] = true
	var from_cell := path[0]
	var to_cell := path[path.size() - 1]

	# Update occupancy & AStar solid map lebih awal
	_occupied_cells.erase(from_cell)
	astar.set_point_solid(from_cell, false)

	_occupied_cells[to_cell] = unit
	astar.set_point_solid(to_cell, true)
	unit.grid_position = to_cell

	# Hitung movement cost
	var steps_cost = path.size() - 1
	unit.consume_movement(steps_cost)

	# Animasi pergerakan halus (Tween)
	unit.play_animation("run")
	unit.face_direction(grid_to_world(to_cell))
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	for i in range(1, path.size()):
		var target_world_pos = grid_to_world(path[i])
		tween.tween_property(unit, "global_position", target_world_pos, move_duration_per_tile)

	tween.finished.connect(func():
		_moving_units.erase(unit)
		unit.play_animation("idle")
		
		# Check if destination tile has a building to capture
		var building = get_building_at(to_cell)
		if building and building.faction_id != unit.faction_id:
			building.capture(unit.faction_id)
		
		EventBus.unit_move_completed.emit(unit, from_cell, to_cell)
	)


## Get building at a specific tile (if any)
func get_building_at(cell: Vector2i) -> Building:
	var tree = get_tree()
	if not tree:
		return null
	for bld in tree.get_nodes_in_group("buildings"):
		if bld is Building and bld.grid_position == cell:
			return bld
	return null


# === EventBus General Signal Listeners ===

func _on_unit_spawned(unit: Node, _faction_id: int) -> void:
	if unit is TacticalUnit:
		register_unit(unit, unit.grid_position)


func _on_unit_removed(unit: Node, _param = null) -> void:
	if unit is TacticalUnit:
		unregister_unit(unit)
		_moving_units.erase(unit)
