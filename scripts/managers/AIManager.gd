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
## Optional. Without it the AI is omniscient, which is what the older test
## scenes expect; with it the AI is bound by exactly the same fog as the player.
var vision_manager: VisionManager
## Optional. Lets the AI shoot powder kegs standing next to its enemies.
var object_manager: MapObjectManager

## Enemy unit -> the cell where the AI last actually saw it. Without this the AI
## would forget an enemy the instant it stepped into a forest and simply stop
## advancing; with it, it keeps marching on the last sighting like a real scout
## report.
var _last_known: Dictionary = {}


func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)


## Inisialisasi dependensi manager
func setup(grid_mgr: GridManager, eco_mgr: Node,
		vision_mgr: VisionManager = null, object_mgr: MapObjectManager = null) -> void:
	grid_manager = grid_mgr
	economy_manager = eco_mgr
	vision_manager = vision_mgr
	object_manager = object_mgr


## Guards against a second AI turn starting while the first is still running.
##
## Without it the turn loop runs away: this handler is a coroutine, so a rapid
## turn change spawns a second _execute_ai_turn() alongside the first, and each
## one ends with its own TurnManager.end_turn(). The extra end_turn() lands on
## the PLAYER's turn and consumes it, so the match advances by itself while
## nobody is touching the controls.
var _turn_running: bool = false


func _on_turn_started(faction_id: int) -> void:
	# Only act if it is the AI's turn
	if faction_id != ai_faction_id or _turn_running:
		return

	_turn_running = true
	# Add a slight delay at the start of the turn
	await get_tree().create_timer(action_delay).timeout
	await _execute_ai_turn()
	_turn_running = false


## Execute the entire AI turn flow
func _execute_ai_turn() -> void:
	# 0. Write down everything currently in sight before moving a single unit.
	_refresh_scouting_report()

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

	var active_units = TurnManager.get_faction_units(ai_faction_id)
	var chosen_unit: UnitData = null

	# Loop in reverse (or pick highest tier/cost unit that is affordable)
	for u_data in ai_castle.recruitable_units:
		var check = ai_castle.can_recruit(u_data, economy_manager, active_units)
		if check["can_recruit"]:
			if chosen_unit == null or u_data.recruit_cost_gold > chosen_unit.recruit_cost_gold:
				chosen_unit = u_data

	if chosen_unit == null:
		return

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
			ai_castle.recruit_unit(chosen_unit, spawn_cell, economy_manager, unit_container)
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

		# 1. Blow a keg if one is in range and would catch someone — a free
		#    armour-ignoring hit beats a normal swing.
		var barrel_cell := _find_barrel_shot(tactical_unit)
		if barrel_cell != Vector2i(-1, -1):
			_shoot_barrel(tactical_unit, barrel_cell)
			await get_tree().create_timer(action_delay).timeout
			continue

		# 2. Check if a visible enemy is already in attack range BEFORE moving
		var target_before_move = _find_best_attack_target(tactical_unit)
		if target_before_move != null:
			# Serang langsung!
			EventBus.unit_attack_requested.emit(tactical_unit, target_before_move)
			await get_tree().create_timer(action_delay).timeout
			continue

		# 3. Jika belum bisa serang, cari target strategis (bangunan atau
		#    sighting terakhir dari musuh)
		var strategic_target_cell = _find_strategic_destination(tactical_unit)
		if strategic_target_cell != Vector2i(-1, -1):
			var best_move_cell = _find_best_step_towards(tactical_unit, strategic_target_cell)
			if best_move_cell != Vector2i(-1, -1) and best_move_cell != tactical_unit.grid_position:
				# Confirm the route exists before awaiting the completion signal:
				# a rejected move never emits, and the await would then swallow
				# some other unit's move and desync the whole turn.
				if grid_manager.get_movement_path(tactical_unit, best_move_cell).size() > 1:
					EventBus.unit_move_requested.emit(tactical_unit, best_move_cell)
					await _await_unit_move(tactical_unit)
					await get_tree().create_timer(action_delay * 0.5).timeout

		# 4. Check if there is an enemy in attack range after moving
		if not is_instance_valid(tactical_unit):
			continue
		var target_after_move = _find_best_attack_target(tactical_unit)
		if target_after_move != null and tactical_unit.can_act():
			EventBus.unit_attack_requested.emit(tactical_unit, target_after_move)
			await get_tree().create_timer(action_delay).timeout


## Wait for ONE unit's walk to finish, with a hard ceiling.
##
## Replaces `await EventBus.unit_move_completed`, which resumes on whichever
## unit arrives first — not necessarily this one — and never resumes at all if
## the move is rejected. Either way the coroutine desynchronises from the turn
## it belongs to, and a coroutine that resumes late calls end_turn() a second
## time. Polling one unit's own moving flag cannot mistake another unit's
## arrival for this one's, and the ceiling guarantees the turn always finishes.
func _await_unit_move(unit: TacticalUnit, max_seconds: float = 4.0) -> void:
	var elapsed: float = 0.0
	while elapsed < max_seconds:
		if not is_instance_valid(unit) or not grid_manager.is_unit_moving(unit):
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()


## Spend the unit's action detonating a keg instead of attacking.
func _shoot_barrel(unit: TacticalUnit, cell: Vector2i) -> void:
	unit.face_direction(grid_manager.grid_to_world(cell))
	unit.play_animation("attack")
	unit.consume_action()
	object_manager.detonate_at(cell)


# ==============================================================================
# SCOUTING — what the AI is allowed to know
# ==============================================================================

## Can this faction actually see the unit right now?
func _can_see(unit: TacticalUnit) -> bool:
	if not is_instance_valid(vision_manager):
		return true
	return vision_manager.can_see_unit(ai_faction_id, unit)


## Refresh the last-known-position map from what is visible this turn, and drop
## entries for units that have since died.
func _refresh_scouting_report() -> void:
	for tracked in _last_known.keys():
		if not is_instance_valid(tracked):
			_last_known.erase(tracked)

	for node in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(node) or not (node is TacticalUnit):
			continue
		var unit: TacticalUnit = node
		if unit.faction_id != ai_faction_id and _can_see(unit):
			_last_known[unit] = unit.grid_position


## Find an enemy target within the unit's attack range.
## Only units the AI can actually see are eligible — an enemy sitting in a
## forest one tile away is invisible until something steps beside it, which is
## exactly what makes the ambush bonus worth setting up.
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
		if target_unit == null or target_unit.faction_id == ai_faction_id:
			continue
		if target_unit.pending_surrender or not _can_see(target_unit):
			continue
		# Prioritize enemies with the lowest health (Finisher logic)
		if target_unit.current_health < lowest_hp:
			lowest_hp = target_unit.current_health
			best_target = target_unit

	return best_target


## A powder keg in range with an enemy standing beside it is a better use of an
## action than a normal swing: the blast ignores armour and can chain.
func _find_barrel_shot(unit: TacticalUnit) -> Vector2i:
	if not is_instance_valid(object_manager) or not unit.can_act() or not unit.unit_data:
		return Vector2i(-1, -1)

	var attack_cells = grid_manager.get_attackable_cells(
		unit.grid_position,
		unit.unit_data.attack_range_min,
		unit.unit_data.attack_range_max
	)

	for cell in attack_cells:
		var has_barrel := false
		for obj in object_manager.objects_at(cell):
			if obj is Barrel and not obj.is_spent():
				has_barrel = true
				break
		if not has_barrel:
			continue

		# Only worth it if the blast would actually catch someone else.
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.ZERO]:
			var victim: TacticalUnit = grid_manager.get_unit_at(cell + dir)
			if is_instance_valid(victim) and victim.faction_id != ai_faction_id and _can_see(victim):
				return cell

	return Vector2i(-1, -1)


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

	# 2. Prioritas Kedua: musuh yang PERNAH terlihat.
	# Deliberately the scouting report rather than the live roster: marching on
	# a stale sighting is what a blinded army does, and reading live positions
	# here would quietly hand the AI back its omniscience.
	for tracked in _last_known:
		if not is_instance_valid(tracked):
			continue
		var last_seen: Vector2i = _last_known[tracked]
		var dist = _manhattan_distance(unit.grid_position, last_seen)
		if dist < min_distance:
			min_distance = dist
			closest_pos = last_seen

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
	TurnManager.end_turn()

