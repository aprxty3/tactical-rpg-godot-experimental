extends Node
## TurnManager — Logic layer autoload for phase-based turn management.
## Drives the core gameplay loop: Upkeep → Production → Action → End Turn.
## Communicates via EventBus signals. References EconomyManager via signal, not path.


# === State ===
var current_phase: GameConfig.Phase = GameConfig.Phase.UPKEEP
var current_faction_index: int = 0
var turn_number: int = 1
var _is_game_over: bool = false

## Ordered list of faction IDs that take a turn, marauders included.
var faction_order: Array[int] = []

## The subset of `faction_order` that can actually win or lose the match.
##
## Split from the turn order because monsters need a turn without becoming a
## contender: with one list a den of ghouls counted as a surviving faction, so
## "last one standing" was unreachable and a won match never ended.
var contenders: Array[int] = []

## Per-faction arrays of active TacticalUnit nodes on the map.
## Key: faction_id (int), Value: Array of TacticalUnit nodes.
var faction_units: Dictionary = {}


# === Manager References (injected, not hardcoded paths) ===
var economy_manager: Node = null
## Latched when a victory or defeat is declared. Cleared by `setup_match`, which
## is what a scene reload runs — so Retry starts a live match rather than one
## that is already over.
var match_over: bool = false


func _ready() -> void:
	_connect_signals()
	EventBus.match_ended.connect(func(_won): match_over = true)


func _connect_signals() -> void:
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.unit_deserted.connect(_on_unit_deserted)
	EventBus.unit_spawned.connect(_on_unit_spawned)
	EventBus.unit_captured.connect(_on_unit_captured)
	EventBus.building_captured.connect(_on_building_captured)


## Start a match. `marauders` take a turn but sit outside the victory check —
## see `contenders`. Defaults to empty, so two-argument callers keep turn order
## and contenders identical.
func setup_match(factions: Array[int], eco_manager: Node,
		marauders: Array[int] = []) -> void:
	contenders = factions.duplicate()
	faction_order = factions.duplicate()
	for faction_id in marauders:
		if not faction_id in faction_order:
			faction_order.append(faction_id)
	economy_manager = eco_manager
	current_faction_index = 0
	turn_number = 1
	current_phase = GameConfig.Phase.UPKEEP
	# THIS manager is an autoload, so it survives reload_current_scene(). Without
	# clearing the latch here, Retry would rebuild the board and then refuse to
	# advance a single turn, because end_turn() would still see a finished match.
	match_over = false
	# The same reasoning applies to the victory latch. Retry cleared
	# `match_over` so turns advance again, but left this one set — so the
	# retried match ran forever and could never be won a second time.
	_is_game_over = false

	# Initialize empty unit arrays for each faction
	for faction_id in faction_order:
		faction_units[faction_id] = []

	# Daftarkan semua unit yang sudah ada di tree
	var tree = get_tree()
	if tree:
		for node in tree.root.find_children("*", "TacticalUnit", true, false):
			if node is TacticalUnit:
				if node.faction_id in faction_units:
					faction_units[node.faction_id].append(node)


func get_current_faction() -> int:
	if faction_order.is_empty():
		return -1
	return faction_order[current_faction_index]


func get_faction_units(faction_id: int) -> Array:
	return faction_units.get(faction_id, [])


# === Phase Execution ===

func start_turn() -> void:
	var faction_id := get_current_faction()
	if faction_id < 0:
		return

	EventBus.turn_started.emit(faction_id)
	_enter_phase(GameConfig.Phase.UPKEEP)


func advance_phase() -> void:
	match current_phase:
		GameConfig.Phase.UPKEEP:
			_enter_phase(GameConfig.Phase.PRODUCTION)
		GameConfig.Phase.PRODUCTION:
			_enter_phase(GameConfig.Phase.ACTION)
		GameConfig.Phase.ACTION:
			_enter_phase(GameConfig.Phase.END_TURN)
		GameConfig.Phase.END_TURN:
			_end_current_turn()


## Advance to the next faction. Refuses once the match is decided — blocking
## input is not enough, because the AI ends its own turn from a coroutine and
## would keep playing behind the result screen.
func end_turn() -> void:
	if match_over:
		return
	if current_phase != GameConfig.Phase.END_TURN:
		_enter_phase(GameConfig.Phase.END_TURN)
	_end_current_turn()


func _enter_phase(phase: GameConfig.Phase) -> void:
	current_phase = phase
	EventBus.phase_changed.emit(phase)

	match phase:
		GameConfig.Phase.UPKEEP:
			_execute_upkeep()
		GameConfig.Phase.PRODUCTION:
			_execute_production()
		GameConfig.Phase.ACTION:
			_execute_action()
		GameConfig.Phase.END_TURN:
			_execute_end_turn()


# === Phase Implementations ===

func _execute_upkeep() -> void:
	var faction_id := get_current_faction()
	var units := get_faction_units(faction_id)

	# 1. One sweep of this faction's holdings answers two questions: what they
	#    earn, and which of their cells resupply a unit standing on them. Each
	#    Building reports its own yield, so a castle's stipend or a future
	#    building type is paid without this loop knowing which types exist.
	var gold := 0
	var iron := 0
	## Cell -> fraction of max health healed there. A dictionary of rates rather
	## than a list of cells because a castle heals harder than a village, and
	## the alternative — one sweep and one heal pass per building type — grows a
	## copy of both every time a healing building is added.
	var heal_cells: Dictionary = {}

	var tree = get_tree()
	if tree:
		for bld in tree.get_nodes_in_group("buildings"):
			if not (bld is Building) or bld.faction_id != faction_id:
				continue
			var income: Dictionary = bld.get_income()
			gold += int(income.get("gold", 0))
			iron += int(income.get("iron", 0))
			var ratio: float = GARRISON_HEAL_BY_TYPE.get(bld.building_type, 0.0)
			if ratio > 0.0:
				heal_cells[bld.grid_position] = ratio

	# 2. The holdings feed their garrisons FIRST, and starvation still gets the
	#    last word below: standing in a village or a keep softens an
	#    over-capacity turn without cancelling it, which is the point of both
	#    rules at once.
	_heal_garrisons(units, heal_cells)

	if economy_manager:
		# 3. Income, then the logistics collapse (starvation) check.
		economy_manager.collect_income(faction_id, gold, iron)
		economy_manager.check_logistics(faction_id, units)

	# 4. Reset action/movement points for surviving units
	for unit in units:
		if is_instance_valid(unit) and unit is TacticalUnit:
			unit.reset_for_new_turn()

## Which building types resupply the troops standing on them, and how hard.
## A type absent from here heals nothing, which is every type not listed.
const GARRISON_HEAL_BY_TYPE: Dictionary = {
	Building.BuildingType.HOUSE: GameConfig.VILLAGE_GARRISON_HEAL_RATIO,
	Building.BuildingType.CASTLE: GameConfig.CASTLE_GARRISON_HEAL_RATIO,
}


## Resupply units standing on their OWN healing buildings. Ownership matters:
## capture is instant, so the two are the same in play, but requiring it stops a
## unit placed on a neutral house by a test or a chest from drawing rations.
func _heal_garrisons(units: Array, heal_cells: Dictionary) -> void:
	if heal_cells.is_empty():
		return
	for unit in units:
		if not is_instance_valid(unit) or not (unit is TacticalUnit):
			continue
		var tactical := unit as TacticalUnit
		if tactical.current_health <= 0 or not is_instance_valid(tactical.unit_data):
			continue
		var ratio: float = heal_cells.get(tactical.grid_position, 0.0)
		if ratio <= 0.0:
			continue
		# Ceil, then floored at 1: a percentage of a small max_health rounds to
		# nothing, and a village that heals for zero reads as broken rather than
		# as stingy. `heal` caps at max_health and is a no-op at full health.
		var amount: int = int(ceil(tactical.unit_data.max_health * ratio))
		tactical.heal(maxi(1, amount))


func _execute_production() -> void:
	# Player-driven phase — wait for player input (recruit, build)
	# Auto-advance for AI factions will be handled separately
	pass


func _execute_action() -> void:
	# Player-driven phase — wait for player input (move, attack, capture)
	# Auto-advance for AI factions will be handled separately
	pass


func _execute_end_turn() -> void:
	var faction_id := get_current_faction()

	# Check victory conditions
	_check_victory_conditions(faction_id)

	# Signal turn end
	EventBus.turn_ended.emit(faction_id)


func _end_current_turn() -> void:
	current_faction_index += 1

	# Wrap around to first faction and increment turn counter
	if current_faction_index >= faction_order.size():
		current_faction_index = 0
		turn_number += 1

	# Start the next faction's turn
	start_turn()


# === Victory / Defeat Checks ===

func _check_victory_conditions(_faction_id: int) -> void:
	if _is_game_over:
		return
		
	var alive_factions = []
	var tree = get_tree()
	if not tree:
		return
		
	# `contenders`, not `faction_order`: a marauder is scenery for this check.
	for fac in contenders:
		var units := get_faction_units(fac)
		var alive_unit_count := 0
		for unit in units:
			if is_instance_valid(unit):
				alive_unit_count += 1
				
		var alive_castle_count := 0
		for bld in tree.get_nodes_in_group("buildings"):
			if bld is Building and bld.faction_id == fac:
				if bld.building_type == Building.BuildingType.CASTLE:
					alive_castle_count += 1
				
		# Updated Victory/Defeat Rules:
		# A faction only loses if they have NO units AND NO castles (Annihilation).
		# If they lose their castle but still have units, they survive as a rogue army!
		if alive_unit_count == 0 and alive_castle_count == 0:
			EventBus.defeat_condition_met.emit(fac, "annihilation")
		else:
			alive_factions.append(fac)
			
	if alive_factions.size() == 1:
		_is_game_over = true
		EventBus.victory_condition_met.emit(alive_factions[0], "supremacy")
	elif alive_factions.size() == 0:
		_is_game_over = true


# === Signal Handlers ===

func _on_unit_died(unit: Node, _cause: String) -> void:
	_remove_unit_from_tracking(unit)
	_check_victory_conditions(-1)


func _on_unit_deserted(unit: Node) -> void:
	_remove_unit_from_tracking(unit)
	_check_victory_conditions(-1)


func _on_unit_spawned(unit: Node, faction_id: int) -> void:
	if faction_id in faction_units:
		faction_units[faction_id].append(unit)


## A unit defected instead of dying. Re-bucket it so both armies' rosters,
## troop capacity and victory checks immediately reflect the new allegiance.
func _on_unit_captured(unit: Node, _old_faction_id: int, new_faction_id: int) -> void:
	_remove_unit_from_tracking(unit)
	if new_faction_id in faction_units:
		faction_units[new_faction_id].append(unit)
	_check_victory_conditions(-1)


func _on_building_captured(_building: Node, _faction_id: int) -> void:
	_check_victory_conditions(-1)


func _remove_unit_from_tracking(unit: Node) -> void:
	for faction_id in faction_units:
		var units: Array = faction_units[faction_id]
		var idx := units.find(unit)
		if idx >= 0:
			units.remove_at(idx)
			break
