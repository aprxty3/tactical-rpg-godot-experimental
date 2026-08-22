extends Node
## TurnManager — Logic layer autoload for phase-based turn management.
## Drives the core gameplay loop: Upkeep → Production → Action → End Turn.
## Communicates via EventBus signals. References EconomyManager via signal, not path.

# === State ===
var current_phase: GameConfig.Phase = GameConfig.Phase.UPKEEP
var current_faction_index: int = 0
var turn_number: int = 1

## Ordered list of faction IDs participating in this match.
var faction_order: Array[int] = []

## Per-faction arrays of active TacticalUnit nodes on the map.
## Key: faction_id (int), Value: Array of TacticalUnit nodes.
var faction_units: Dictionary = {}

# === Manager References (injected, not hardcoded paths) ===
var economy_manager: Node = null


func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.unit_deserted.connect(_on_unit_deserted)
	EventBus.unit_spawned.connect(_on_unit_spawned)


## Initialize the turn system with participating factions.
## Call this when the match/level starts.
func setup_match(factions: Array[int], eco_manager: Node) -> void:
	faction_order = factions
	economy_manager = eco_manager
	current_faction_index = 0
	turn_number = 1
	current_phase = GameConfig.Phase.UPKEEP

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


## Get the faction ID of the currently active faction.
func get_current_faction() -> int:
	if faction_order.is_empty():
		return -1
	return faction_order[current_faction_index]


## Get all active units for a specific faction.
func get_faction_units(faction_id: int) -> Array:
	return faction_units.get(faction_id, [])


# === Phase Execution ===

## Start the turn for the current faction. Begins with Upkeep.
func start_turn() -> void:
	var faction_id := get_current_faction()
	if faction_id < 0:
		return

	EventBus.turn_started.emit(faction_id)
	_enter_phase(GameConfig.Phase.UPKEEP)


## Advance to the next phase. Called when the current phase is complete.
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


## Execute logic for entering a specific phase.
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

## Upkeep Phase: collect income, check logistics, reset units.
func _execute_upkeep() -> void:
	var faction_id := get_current_faction()
	var units := get_faction_units(faction_id)

	# 1. Collect income from controlled resource nodes
	if economy_manager:
		# TODO: Replace with actual mine/house counts from GridManager
		var gold_mines := 1   # placeholder
		var iron_mines := 0   # placeholder
		var houses := 0       # placeholder
		economy_manager.collect_income(faction_id, gold_mines, iron_mines, houses)

		# 2. Check logistics collapse (starvation)
		economy_manager.check_logistics(faction_id, units)

	# 3. Reset action/movement points for surviving units
	for unit in units:
		if is_instance_valid(unit) and unit is TacticalUnit:
			unit.reset_for_new_turn()


## Production Phase: player can recruit and build.
func _execute_production() -> void:
	# Player-driven phase — wait for player input (recruit, build)
	# Auto-advance for AI factions will be handled separately
	pass


## Action Phase: player can move, attack, interact.
func _execute_action() -> void:
	# Player-driven phase — wait for player input (move, attack, capture)
	# Auto-advance for AI factions will be handled separately
	pass


## End Turn Phase: check victory/defeat, then switch faction.
func _execute_end_turn() -> void:
	var faction_id := get_current_faction()

	# Check victory conditions
	_check_victory_conditions(faction_id)

	# Signal turn end
	EventBus.turn_ended.emit(faction_id)


## End current faction's turn and move to next.
func _end_current_turn() -> void:
	current_faction_index += 1

	# Wrap around to first faction and increment turn counter
	if current_faction_index >= faction_order.size():
		current_faction_index = 0
		turn_number += 1

	# Start the next faction's turn
	start_turn()


# === Victory / Defeat Checks ===

func _check_victory_conditions(faction_id: int) -> void:
	# Total Annihilation: check if any enemy faction has zero units
	for other_faction in faction_order:
		if other_faction == faction_id:
			continue
		var enemy_units := get_faction_units(other_faction)
		var alive_count := 0
		for unit in enemy_units:
			if is_instance_valid(unit):
				alive_count += 1
		if alive_count == 0:
			EventBus.victory_condition_met.emit(faction_id, "total_annihilation")
			return

	# TODO: Castle capture check (needs GridManager/building tracking)
	# TODO: Economic domination check (75% gold mines for 3 turns)


# === Signal Handlers ===

func _on_unit_died(unit: Node, _cause: String) -> void:
	_remove_unit_from_tracking(unit)


func _on_unit_deserted(unit: Node) -> void:
	_remove_unit_from_tracking(unit)


func _on_unit_spawned(unit: Node, faction_id: int) -> void:
	if faction_id in faction_units:
		faction_units[faction_id].append(unit)


func _remove_unit_from_tracking(unit: Node) -> void:
	for faction_id in faction_units:
		var units: Array = faction_units[faction_id]
		var idx := units.find(unit)
		if idx >= 0:
			units.remove_at(idx)
			break
