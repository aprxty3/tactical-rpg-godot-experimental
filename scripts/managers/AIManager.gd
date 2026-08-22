extends Node
class_name AIManager
## AIManager — Logic layer manager for NPC / Enemy AI factions.
## Handles tactical decision making: building recruitment, strategic pathfinding,
## prioritizing objectives (Gold Mines, Player Units), and executing attacks.

@export_group("AI Settings")
## Faksi yang dikendalikan oleh AI (default: RED_LEGION = 1)
@export var ai_faction_id: int = GameConfig.Faction.RED_LEGION
## Jeda waktu antar aksi AI (detik) agar terlihat alami bagi pemain
@export var action_delay: float = 0.4

# Referensi Manager
var grid_manager: GridManager
var economy_manager: Node


func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)


## Inisialisasi dependensi manager
func setup(grid_mgr: GridManager, eco_mgr: Node) -> void:
	grid_manager = grid_mgr
	economy_manager = eco_mgr


func _on_turn_started(faction_id: int) -> void:
	# Only act if it is the AI's turn
	if faction_id == ai_faction_id:
		# Add a slight delay at the start of the turn
		await get_tree().create_timer(action_delay).timeout
		_execute_ai_turn()


## Execute the entire AI turn flow
func _execute_ai_turn() -> void:
	# 1. Fase Rekrutmen di Kastil AI
	await _ai_try_recruit()

	# 2. Fase Pergerakan & Serangan Unit AI
	await _ai_move_and_attack_units()

	# 3. Finish AI turn -> Automatically Switch Turn to Player
	await get_tree().create_timer(action_delay).timeout
	_end_ai_turn()


## AI attempts to recruit new units if funds are sufficient
func _ai_try_recruit() -> void:
	if not economy_manager or not grid_manager:
		return

	var tree = get_tree()
	if not tree:
		return

	# Cari Castle milik AI
	var ai_castle: Building = null
	for bld in tree.get_nodes_in_group("buildings"):
		if bld is Building and bld.faction_id == ai_faction_id and bld.building_type == Building.BuildingType.CASTLE:
			ai_castle = bld
			break

	if not ai_castle or ai_castle.recruitable_units.is_empty():
		return

	var unit_data: UnitData = ai_castle.recruitable_units[0]
	var active_units = TurnManager.get_faction_units(ai_faction_id)

	# Cek apakah syarat rekrutmen terpenuhi
	var check = ai_castle.can_recruit(unit_data, economy_manager, active_units)
	if check["can_recruit"]:
		# Find an empty tile around the castle
		var dirs = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]
		var spawn_cell := Vector2i(-1, -1)
		for d in dirs:
			var target = ai_castle.grid_position + d
			if grid_manager.is_cell_walkable(target):
				spawn_cell = target
				break

		if spawn_cell != Vector2i(-1, -1):
			var unit_container = tree.root.find_child("Units", true, false)
			if unit_container:
				ai_castle.recruit_unit(unit_data, spawn_cell, economy_manager, unit_container)
				await get_tree().create_timer(action_delay).timeout


## AI moves and orders each of its units to attack
func _ai_move_and_attack_units() -> void:
	if not grid_manager:
		return

	var ai_units = TurnManager.get_faction_units(ai_faction_id).duplicate()

	for unit in ai_units:
		if not is_instance_valid(unit) or not (unit is TacticalUnit):
			continue
		var tactical_unit: TacticalUnit = unit as TacticalUnit

		# 1. Check if the enemy (player) is already in attack range BEFORE moving
		var target_before_move = _find_best_attack_target(tactical_unit)
		if target_before_move != null:
			# Serang langsung!
			EventBus.unit_attack_requested.emit(tactical_unit, target_before_move)
			await get_tree().create_timer(action_delay).timeout
			continue

		# 2. Jika belum bisa serang, cari target strategis (Unit Pemain terdekat atau Gold Mine netral)
		var strategic_target_cell = _find_strategic_destination(tactical_unit)
		if strategic_target_cell != Vector2i(-1, -1):
			var best_move_cell = _find_best_step_towards(tactical_unit, strategic_target_cell)
			if best_move_cell != Vector2i(-1, -1) and best_move_cell != tactical_unit.grid_position:
				# Request a path to that tile
				EventBus.unit_move_requested.emit(tactical_unit, best_move_cell)
				# Tunggu hingga animasi jalan selesai
				await EventBus.unit_move_completed
				await get_tree().create_timer(action_delay * 0.5).timeout

		# 3. Check if there is an enemy in attack range after moving
		var target_after_move = _find_best_attack_target(tactical_unit)
		if target_after_move != null and tactical_unit.can_act():
			EventBus.unit_attack_requested.emit(tactical_unit, target_after_move)
			await get_tree().create_timer(action_delay).timeout


## Find an enemy target within the unit's attack range
func _find_best_attack_target(unit: TacticalUnit) -> TacticalUnit:
	if not unit.can_act() or not unit.unit_data:
		return null

	var attack_cells = grid_manager.get_attackable_cells(
		unit.grid_position,
		unit.unit_data.attack_range_min,
		unit.unit_data.attack_range_max
	)

	var best_target: TacticalUnit = null
	var lowest_hp: int = 9999

	for cell in attack_cells:
		var target_unit = grid_manager.get_unit_at(cell)
		if target_unit != null and target_unit.faction_id != ai_faction_id:
			# Prioritize enemies with the lowest health (Finisher logic)
			if target_unit.current_health < lowest_hp:
				lowest_hp = target_unit.current_health
				best_target = target_unit

	return best_target


## Find the most important strategic goal (Nearest Player Unit or uncontrolled Gold Mine)
func _find_strategic_destination(unit: TacticalUnit) -> Vector2i:
	var tree = get_tree()
	if not tree:
		return Vector2i(-1, -1)

	var closest_pos := Vector2i(-1, -1)
	var min_distance := 9999

	# 1. Prioritas Utama: Bangunan yang belum dikuasai (Netral atau Milik Player)
	for bld in tree.get_nodes_in_group("buildings"):
		if bld is Building and bld.faction_id != ai_faction_id:
			var dist = _manhattan_distance(unit.grid_position, bld.grid_position)
			if dist < min_distance:
				min_distance = dist
				closest_pos = bld.grid_position

	# 2. Prioritas Kedua: Unit Player (Blue Kingdom)
	for other_faction_id in TurnManager.faction_order:
		if other_faction_id != ai_faction_id:
			for player_unit in TurnManager.get_faction_units(other_faction_id):
				if is_instance_valid(player_unit) and player_unit is TacticalUnit:
					var dist = _manhattan_distance(unit.grid_position, player_unit.grid_position)
					if dist < min_distance:
						min_distance = dist
						closest_pos = player_unit.grid_position

	return closest_pos


## Select the closest tile within movement range towards the strategic goal
func _find_best_step_towards(unit: TacticalUnit, target_cell: Vector2i) -> Vector2i:
	var reachable = grid_manager.get_reachable_cells(unit)
	if reachable.is_empty():
		return Vector2i(-1, -1)

	var best_cell := unit.grid_position
	var min_dist = _manhattan_distance(unit.grid_position, target_cell)

	for cell in reachable:
		var dist = _manhattan_distance(cell, target_cell)
		if dist < min_dist:
			min_dist = dist
			best_cell = cell

	return best_cell


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## End AI turn and return control to the player
func _end_ai_turn() -> void:
	TurnManager.advance_phase()
	if TurnManager.current_phase != GameConfig.Phase.UPKEEP:
		TurnManager._end_current_turn()
