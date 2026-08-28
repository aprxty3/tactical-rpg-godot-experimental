extends Node
class_name EncounterManager
## EncounterManager — the Black Castle's garrison, and the turn it takes.
##
## The fifth thing on the board that moves, and deliberately not a fifth army.
## An `AIManager` plays to win: it recruits, banks gold, values every building
## by what it yields and marches on whatever is worth taking. None of that
## applies to a den of monsters. They own no economy, buy nothing, and hold no
## ground — a keep or a mine is scenery to them. What they do is refuse to let
## anyone hold the middle of the map for free.
##
## So this is its own manager rather than an `AIManager` with four flags. The
## judgement is still shared: `AITacticalEvaluator` picks targets and scores
## swings here exactly as it does for the armies, which is what keeps a ghoul
## attacking through the same damage rules the player attacks through.
##
## Two rules shape everything below:
##   1. **The leash.** No monster ever steps further than `ENCOUNTER_LEASH` from
##      the den. It is enforced when choosing a step, not corrected afterwards,
##      so a monster can never be out of bounds even for one frame.
##   2. **The boss never moves.** It is what the keep is built around. It swings
##      at whatever comes into reach and is otherwise furniture.

@export_group("Encounter Settings")
## Which faction the monsters belong to. Black Coven holds the centre castle and
## fields no army of its own, which is exactly the slot this needs.
@export var faction_id: int = GameConfig.Faction.BLACK_COVEN
## Pause between monster actions, so the turn reads as deliberate.
@export var action_delay: float = 0.35
## 0 randomises the garrison each match; any other value reproduces one.
@export var random_seed: int = 0

var grid_manager: GridManager
var unit_container: Node2D
## Optional. Supplies the damage numbers targets are scored with; without it the
## evaluator falls back to distance-only reasoning rather than guessing.
var combat_resolver: CombatResolver

## Same judgement the armies use, bound to the monsters' side of the board.
## Built with no VisionManager on purpose: a den knows what walks into its own
## territory. The leash is what limits the monsters, not the fog.
var evaluator: AITacticalEvaluator

## The Black Castle's cell — the anchor every leash check measures from.
var den_cell: Vector2i = Vector2i(-1, -1)

## The guardian. Held by reference rather than looked up, because "is this the
## boss" is asked once per unit per turn and the answer must not depend on
## comparing resource paths.
var _boss: TacticalUnit

var _rng := RandomNumberGenerator.new()
## Guards against a second turn starting while the first is still running — the
## same runaway `AIManager` documents: this handler is a coroutine, and two of
## them would each call `end_turn()` and eat a player's turn between them.
var _turn_running: bool = false
## Round number of the next reinforcement, so the interval survives the den
## being at cap for a while.
var _next_spawn_round: int = 0


func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)


func setup(grid_mgr: GridManager, units_parent: Node2D,
		combat_mgr: CombatResolver = null) -> void:
	grid_manager = grid_mgr
	unit_container = units_parent
	combat_resolver = combat_mgr
	evaluator = AITacticalEvaluator.new(grid_mgr, combat_mgr, null, faction_id)

	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed

	den_cell = _find_den()
	_next_spawn_round = TurnManager.turn_number + GameConfig.ENCOUNTER_SPAWN_INTERVAL


## Stand the opening garrison up: the boss on the keep, a couple of monsters
## around it.
##
## Call AFTER `TurnManager.setup_match`, so `unit_spawned` lands on a roster that
## already has a bucket for this faction. Spawning earlier is not an error — the
## setup sweep would find them in the tree — but it depends on which of two
## mechanisms happens to catch them, and only one of them works for the
## reinforcements below.
func garrison() -> void:
	if den_cell == Vector2i(-1, -1):
		push_warning("EncounterManager: no Black Castle on this map; no monsters spawned.")
		return

	_boss = _spawn(GameConfig.ENCOUNTER_BOSS, den_cell)
	for i in range(GameConfig.ENCOUNTER_INITIAL):
		_spawn_wanderer()


# ==============================================================================
# TURN
# ==============================================================================

func _on_turn_started(active_faction_id: int) -> void:
	if active_faction_id != faction_id or _turn_running:
		return
	_turn_running = true
	await _execute_turn()
	_turn_running = false


func _execute_turn() -> void:
	_reinforce()

	# Duplicated because a monster can die mid-turn (a trap it walked onto, a
	# counter-attack), and `get_faction_units` returns the live roster array.
	for unit in TurnManager.get_faction_units(faction_id).duplicate():
		if not is_instance_valid(unit) or not (unit is TacticalUnit):
			continue
		await _act(unit as TacticalUnit)

	await get_tree().create_timer(action_delay).timeout
	# Unconditional. An empty den still has to hand the turn on, or a match in
	# which every monster is dead simply stops here.
	TurnManager.end_turn()


## One monster's whole turn: swing if something is in reach, otherwise close on
## whatever is worth closing on, then swing again if the walk brought it in.
func _act(unit: TacticalUnit) -> void:
	if not is_instance_valid(evaluator) or not is_instance_valid(grid_manager):
		return

	var target: TacticalUnit = evaluator.best_attack_target(unit)
	if target != null:
		EventBus.unit_attack_requested.emit(unit, target)
		await get_tree().create_timer(action_delay).timeout
		return

	# The boss holds the keep and nothing draws it off. Everything below this
	# line is movement, so it stops here.
	if unit == _boss:
		return

	var destination: Vector2i = _pick_destination(unit)
	if destination != Vector2i(-1, -1):
		var step: Vector2i = _step_towards(unit, destination)
		if step != Vector2i(-1, -1) and step != unit.grid_position:
			# Confirm a route exists before awaiting the arrival: a rejected
			# move never emits, and the await would then swallow some other
			# unit's arrival and desync the turn.
			if grid_manager.get_movement_path(unit, step).size() > 1:
				EventBus.unit_move_requested.emit(unit, step)
				await _await_move(unit)
				await get_tree().create_timer(action_delay * 0.5).timeout

	if not is_instance_valid(unit) or not unit.can_act():
		return
	var after: TacticalUnit = evaluator.best_attack_target(unit)
	if after != null:
		EventBus.unit_attack_requested.emit(unit, after)
		await get_tree().create_timer(action_delay).timeout


## Where this monster wants to be, in priority order:
##   1. the nearest intruder standing inside the den's territory,
##   2. the nearest occupied village inside it — the one thing they can burn,
##   3. home, if the monster has somehow ended up outside the leash.
##
## Note what is missing: they never march on a castle or a mine. Not because a
## check forbids it here, but because there is nothing they could do on arrival
## — `Building.claim_for` gives a marauder nothing for either.
func _pick_destination(unit: TacticalUnit) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_cost: int = -1

	for enemy in evaluator.visible_enemies():
		if not _within_leash(enemy.grid_position):
			continue
		var cost: int = evaluator.path_cost_between(unit.grid_position, enemy.grid_position)
		if cost < 0:
			continue
		if best_cost < 0 or cost < best_cost:
			best_cost = cost
			best_cell = enemy.grid_position
	if best_cell != Vector2i(-1, -1):
		return best_cell

	for bld in get_tree().get_nodes_in_group("buildings"):
		if not (bld is Building):
			continue
		if bld.claim_for(faction_id) != Building.Claim.RAZE:
			continue
		if not _within_leash(bld.grid_position):
			continue
		var cost: int = evaluator.path_cost_between(unit.grid_position, bld.grid_position)
		if cost < 0:
			continue
		if best_cost < 0 or cost < best_cost:
			best_cost = cost
			best_cell = bld.grid_position
	if best_cell != Vector2i(-1, -1):
		return best_cell

	# Nothing to do out here. Drift home rather than standing in a field.
	if not _within_leash(unit.grid_position):
		return den_cell
	return Vector2i(-1, -1)


## The reachable cell that gets closest to `target_cell` WITHOUT breaking the
## leash.
##
## Deliberately not `AITacticalEvaluator.best_step_towards`: that one is free to
## pick any reachable cell, which for a fast monster chasing a fleeing scout
## means walking clean out of the den's territory. Filtering the candidates —
## rather than moving and then dragging the monster back — is what makes the
## leash a rule instead of a correction.
func _step_towards(unit: TacticalUnit, target_cell: Vector2i) -> Vector2i:
	var reachable: Array[Vector2i] = grid_manager.get_reachable_cells(unit)
	if reachable.is_empty():
		return Vector2i(-1, -1)

	var best_cell: Vector2i = unit.grid_position
	var best_cost: int = evaluator.path_cost_between(unit.grid_position, target_cell)
	for cell in reachable:
		if not _within_leash(cell):
			continue
		var cost: int = evaluator.path_cost_between(cell, target_cell)
		if cost < 0:
			continue
		if best_cost < 0 or cost < best_cost:
			best_cost = cost
			best_cell = cell
	return best_cell


## Wait for ONE monster's walk to finish, with a hard ceiling.
##
## Polls the unit's own moving flag rather than awaiting `unit_move_completed`,
## which resumes on whichever unit arrives first and never resumes at all if the
## move was rejected. Either failure ends with this coroutine calling
## `end_turn()` out of sequence, which is how a turn loop runs away.
func _await_move(unit: TacticalUnit, max_seconds: float = 4.0) -> void:
	var elapsed: float = 0.0
	while elapsed < max_seconds:
		if not is_instance_valid(unit) or not grid_manager.is_unit_moving(unit):
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()


# ==============================================================================
# THE DEN
# ==============================================================================

## Add one monster every `ENCOUNTER_SPAWN_INTERVAL` rounds while under the cap.
##
## Stops dead once the boss falls. That is the whole reward for killing it: the
## den keeps whatever is still standing, but it stops being a source, so the
## centre of the map can finally be cleared for good instead of bleeding a new
## ghoul every third round for the rest of the match.
func _reinforce() -> void:
	if not is_instance_valid(_boss):
		return
	if TurnManager.turn_number < _next_spawn_round:
		return
	_next_spawn_round = TurnManager.turn_number + GameConfig.ENCOUNTER_SPAWN_INTERVAL
	if _wanderer_count() >= GameConfig.ENCOUNTER_MAX_ACTIVE:
		return
	_spawn_wanderer()


## Everything in the den except the boss, which does not count against the cap —
## it is the den, not part of its garrison.
func _wanderer_count() -> int:
	var total := 0
	for unit in TurnManager.get_faction_units(faction_id):
		if is_instance_valid(unit) and unit != _boss:
			total += 1
	return total


func _spawn_wanderer() -> TacticalUnit:
	var roster: Array[String] = GameConfig.ENCOUNTER_ROSTER
	if roster.is_empty():
		return null
	var cell: Vector2i = _free_cell_near_den()
	if cell == Vector2i(-1, -1):
		return null
	return _spawn(roster[_rng.randi_range(0, roster.size() - 1)], cell)


## Instance one monster and put it on the board.
##
## `unit_spawned` is what registers it with the grid AND puts it on
## TurnManager's roster, so it is emitted last, after grid_position is set —
## GridManager reads that field off the unit rather than taking a cell argument.
func _spawn(data_path: String, cell: Vector2i) -> TacticalUnit:
	if not is_instance_valid(unit_container) or not ResourceLoader.exists(data_path):
		push_warning("EncounterManager: cannot spawn %s" % data_path)
		return null
	var data: UnitData = load(data_path) as UnitData
	if not is_instance_valid(data):
		return null

	var scene: PackedScene = data.unit_scene if is_instance_valid(data.unit_scene) \
		else load("res://scenes/units/TacticalUnit.tscn")
	var unit: TacticalUnit = scene.instantiate() as TacticalUnit
	unit.name = "Monster_%s" % data.unit_name.replace(" ", "")
	unit.unit_data = data
	unit.faction_id = faction_id
	unit.grid_position = cell
	unit_container.add_child(unit)
	if unit.has_method("_initialize_from_data"):
		unit._initialize_from_data()

	EventBus.unit_spawned.emit(unit, faction_id)
	return unit


## Ring search outward from the keep for somewhere to stand, mirroring how each
## army musters around its own castle.
func _free_cell_near_den() -> Vector2i:
	if not is_instance_valid(grid_manager) or den_cell == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	for radius in range(1, 5):
		var ring: Array[Vector2i] = []
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var cell: Vector2i = den_cell + Vector2i(dx, dy)
				if grid_manager.is_cell_walkable(cell) and grid_manager.get_building_at(cell) == null:
					ring.append(cell)
		if not ring.is_empty():
			return ring[_rng.randi_range(0, ring.size() - 1)]
	return Vector2i(-1, -1)


func _find_den() -> Vector2i:
	var tree := get_tree()
	if not tree:
		return Vector2i(-1, -1)
	for bld in tree.get_nodes_in_group("buildings"):
		if bld is Building and bld.building_type == Building.BuildingType.CASTLE \
				and bld.faction_id == faction_id:
			return bld.grid_position
	return Vector2i(-1, -1)


## Manhattan, matching every other distance rule on this board (trap spacing,
## resource fairness bands). Diagonal-aware distance would let a monster reach
## further along the diagonals than along the axes for no stated reason.
func _within_leash(cell: Vector2i) -> bool:
	if den_cell == Vector2i(-1, -1):
		return true
	return absi(cell.x - den_cell.x) + absi(cell.y - den_cell.y) <= GameConfig.ENCOUNTER_LEASH
