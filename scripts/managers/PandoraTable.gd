extends RefCounted
class_name PandoraTable
## PandoraTable — decides what is inside an opened chest.
##
## Four weighted outcomes and their consequences, lifted out of
## `MapObjectManager` along with the other two rule systems it was carrying.
##
## A RefCounted with injected collaborators, so it can be interrogated on a bare
## board. Spawning arrives as a Callable, not a reference back to the manager —
## the table says "put this unit here" without knowing who does it.

## The manager's own RNG, not a fresh one. `MapObjectManager.random_seed` makes
## a run reproducible, and a second generator would break that guarantee for
## every outcome rolled here.
var _rng: RandomNumberGenerator
var _economy: Node
var _spawn_unit: Callable
var _free_cells: Callable


func _init(rng: RandomNumberGenerator, economy_manager: Node,
		spawn_unit: Callable, free_cells_around: Callable) -> void:
	_rng = rng
	_economy = economy_manager
	_spawn_unit = spawn_unit
	_free_cells = free_cells_around


## Roll an outcome and apply it. Returns the result payload with the chosen
## outcome id folded in, ready for `EventBus.map_event_triggered`.
func open(cell: Vector2i, opener: TacticalUnit) -> Dictionary:
	var outcome: String = roll()
	var result: Dictionary = {}

	match outcome:
		"war_spoils":
			result = grant_spoils(opener)
		"mercenary":
			result = grant_mercenary(cell, opener)
		"trap":
			result = spring_trap(opener)
		"awaken_dead":
			result = awaken_dead(cell, opener)

	result["outcome"] = outcome
	return result


## Weighted pick over the GameConfig odds. Normalised by the running total
## rather than assuming the constants sum to 1.0, so retuning one of them cannot
## silently make an outcome unreachable.
func roll() -> String:
	var table: Array = [
		{"id": "war_spoils", "weight": GameConfig.PANDORA_WAR_SPOILS_CHANCE},
		{"id": "mercenary", "weight": GameConfig.PANDORA_MERCENARY_CHANCE},
		{"id": "trap", "weight": GameConfig.PANDORA_TRAP_CHANCE},
		{"id": "awaken_dead", "weight": GameConfig.PANDORA_AWAKEN_DEAD_CHANCE},
	]
	var total: float = 0.0
	for entry in table:
		total += float(entry["weight"])
	if total <= 0.0:
		return "war_spoils"

	var roll_value: float = _rng.randf() * total
	for entry in table:
		roll_value -= float(entry["weight"])
		if roll_value <= 0.0:
			return entry["id"]
	return table[table.size() - 1]["id"]


func grant_spoils(opener: TacticalUnit) -> Dictionary:
	var gold: int = _rng.randi_range(
		GameConfig.PANDORA_SPOILS_GOLD.x, GameConfig.PANDORA_SPOILS_GOLD.y)
	var iron: int = _rng.randi_range(
		GameConfig.PANDORA_SPOILS_IRON.x, GameConfig.PANDORA_SPOILS_IRON.y)
	if is_instance_valid(_economy):
		_economy.add_gold(opener.faction_id, gold)
		_economy.add_iron(opener.faction_id, iron)
	return {"gold": gold, "iron": iron}


func grant_mercenary(cell: Vector2i, opener: TacticalUnit) -> Dictionary:
	var data: UnitData = pick_mercenary_data(opener)
	var free_cells: Array = _free_cells.call(cell, 1)
	if data == null or free_cells.is_empty() or not _can_feed(opener.faction_id, data):
		# Nowhere to stand, nothing to hire, or no room in the ranks for one more
		# mouth — pay the finder's fee instead. A chest is the third way troops
		# enter an army, and free troops that ignore the troop ceiling are the
		# same bug as buying past it.
		return grant_spoils(opener)

	var hired: TacticalUnit = _spawn_unit.call(data, opener.faction_id, free_cells[0])
	return {"unit": hired, "unit_name": data.unit_name}


## Hire whatever the opener's own castle could field, preferring its best troop.
## Falls back to a copy of the opener when that faction holds no castle.
func pick_mercenary_data(opener: TacticalUnit) -> UnitData:
	var best: UnitData = null
	for node in _buildings():
		if not (node is Building):
			continue
		var building: Building = node
		if building.faction_id != opener.faction_id:
			continue
		if building.building_type != Building.BuildingType.CASTLE:
			continue
		for candidate in building.recruitable_units:
			if not is_instance_valid(candidate):
				continue
			if best == null or candidate.recruit_cost_gold > best.recruit_cost_gold:
				best = candidate

	if best != null:
		return UnitData.variant_for_faction(best, opener.faction_id)
	return opener.unit_data if is_instance_valid(opener.unit_data) else null


## Does the opener's army have capacity for this hire?
##
## Answers true when there is no economy to ask — the focused test scenes build
## the table without one, and a chest that refuses every mercenary there would
## be a silent change to what those scenes exercise.
func _can_feed(faction_id: int, data: UnitData) -> bool:
	if not is_instance_valid(_economy) or not _economy.has_method("has_capacity_for"):
		return true
	var roster: Array = TurnManager.get_faction_units(faction_id) if is_instance_valid(TurnManager) else []
	return _economy.has_capacity_for(faction_id, data.capacity_weight, roster)


func spring_trap(opener: TacticalUnit) -> Dictionary:
	opener.take_damage(GameConfig.PANDORA_TRAP_DAMAGE, "true")
	opener.adjust_morale(GameConfig.MORALE_AMBUSHED)
	return {"damage": GameConfig.PANDORA_TRAP_DAMAGE}


## The dead rise against whoever disturbed them.
##
## They enlist under the opener's enemy rather than the Black Coven, because the
## Coven takes no turns in this match — undead spawned into a faction that never
## acts would be statues. Their sprites stay Coven undead either way; the Undead
## line has no per-faction variants by design.
func awaken_dead(cell: Vector2i, opener: TacticalUnit) -> Dictionary:
	var hostile_faction: int = enemy_of(opener.faction_id)
	var cells: Array = _free_cells.call(cell, GameConfig.PANDORA_UNDEAD_COUNT)
	var raised: Array = []

	for i in range(mini(cells.size(), GameConfig.PANDORA_UNDEAD_COUNT)):
		var path: String = MapObjectManager.AWAKENED_UNITS[i % MapObjectManager.AWAKENED_UNITS.size()]
		var data: UnitData = load(path) as UnitData
		if is_instance_valid(data):
			raised.append(_spawn_unit.call(data, hostile_faction, cells[i]))

	return {"count": raised.size(), "faction_id": hostile_faction}


func enemy_of(faction_id: int) -> int:
	for other in TurnManager.faction_order:
		if other != faction_id:
			return other
	return GameConfig.Faction.BLACK_COVEN


## The scene tree is reachable from a RefCounted through the main loop, so the
## buildings sweep needs no injected node reference.
func _buildings() -> Array:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).get_nodes_in_group("buildings")
	return []
