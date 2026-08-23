extends Node
class_name EconomyManager
## EconomyManager — Logic layer manager for multi-faction resource tracking.
## Listens to EventBus signals. Does NOT reference actor nodes directly.
## Register as a child of Managers node (NOT autoload — instantiated per-game).

# === Per-Faction Resource State ===
# Key: faction_id (int), Value: resource amount
var _faction_gold: Dictionary = {}
var _faction_iron: Dictionary = {}
var _faction_villages: Dictionary = {}  # village count per faction


func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	EventBus.resource_node_captured.connect(_on_resource_node_captured)
	EventBus.building_destroyed.connect(_on_building_destroyed)


## Initialize a faction's starting resources.
func register_faction(faction_id: int, starting_gold: int = 200, starting_iron: int = 5) -> void:
	_faction_gold[faction_id] = starting_gold
	_faction_iron[faction_id] = starting_iron
	_faction_villages[faction_id] = 0


# === Resource Queries ===

func get_gold(faction_id: int) -> int:
	return _faction_gold.get(faction_id, 0)


func get_iron(faction_id: int) -> int:
	return _faction_iron.get(faction_id, 0)


func get_max_capacity(faction_id: int) -> int:
	var village_count: int = _faction_villages.get(faction_id, 0)
	return GameConfig.BASE_TROOP_CAPACITY + (village_count * GameConfig.VILLAGE_CAPACITY_BONUS)


## Calculate the total Troop Capacity weight of active units.
func get_used_capacity(faction_id: int, active_units: Array) -> int:
	var total := 0
	for unit in active_units:
		if unit is TacticalUnit and unit.faction_id == faction_id and unit.unit_data:
			total += unit.unit_data.capacity_weight
	return total


# === Resource Modifications ===

func add_gold(faction_id: int, amount: int) -> void:
	_faction_gold[faction_id] = get_gold(faction_id) + amount
	EventBus.gold_changed.emit(faction_id, get_gold(faction_id))


func add_iron(faction_id: int, amount: int) -> void:
	_faction_iron[faction_id] = get_iron(faction_id) + amount
	EventBus.iron_changed.emit(faction_id, get_iron(faction_id))


func spend_gold(faction_id: int, amount: int) -> bool:
	if get_gold(faction_id) >= amount:
		_faction_gold[faction_id] -= amount
		EventBus.gold_changed.emit(faction_id, get_gold(faction_id))
		return true
	EventBus.resources_insufficient.emit(faction_id, "gold")
	return false


func spend_iron(faction_id: int, amount: int) -> bool:
	if get_iron(faction_id) >= amount:
		_faction_iron[faction_id] -= amount
		EventBus.iron_changed.emit(faction_id, get_iron(faction_id))
		return true
	EventBus.resources_insufficient.emit(faction_id, "iron")
	return false


# === Income Collection (called during Upkeep Phase) ===

## Collect income from all controlled resource nodes for a faction.
## gold_mines, iron_mines: count of mines controlled by this faction.
func collect_income(faction_id: int, gold_mines: int, iron_mines: int, houses: int) -> void:
	var gold_income := gold_mines * GameConfig.GOLD_MINE_INCOME + houses * GameConfig.HOUSE_GOLD_INCOME
	var iron_income := iron_mines * GameConfig.IRON_MINE_INCOME

	add_gold(faction_id, gold_income)
	add_iron(faction_id, iron_income)


# === Upgrade Cost Calculation (Field Tax) ===

## Calculate upgrade cost with Field Tax applied if not at Castle.
func get_upgrade_cost(current_data: UnitData, target_data: UnitData, is_at_castle: bool) -> Dictionary:
	var base_gold := maxi(0, target_data.recruit_cost_gold - current_data.recruit_cost_gold)
	var base_iron := maxi(0, target_data.recruit_cost_iron - current_data.recruit_cost_iron)

	var multiplier := 1
	if not is_at_castle:
		multiplier = GameConfig.FIELD_TAX_MULTIPLIER

	return {
		"gold": base_gold * multiplier,
		"iron": base_iron * multiplier,
	}


## Validate and execute an upgrade transaction.
## Returns true if the transaction succeeded.
func process_upgrade(faction_id: int, unit: TacticalUnit, target_data: UnitData, is_at_castle: bool) -> bool:
	if not unit.unit_data or not target_data:
		return false

	var cost := get_upgrade_cost(unit.unit_data, target_data, is_at_castle)

	if get_gold(faction_id) >= cost["gold"] and get_iron(faction_id) >= cost["iron"]:
		spend_gold(faction_id, cost["gold"])
		spend_iron(faction_id, cost["iron"])
		unit.upgrade_to(target_data)
		return true

	EventBus.resources_insufficient.emit(faction_id, "upgrade")
	return false


# === Logistics Collapse (Starvation Check) ===

## Check and apply starvation penalties if a faction is over troop capacity.
## Called during Upkeep Phase by TurnManager.
func check_logistics(faction_id: int, active_units: Array) -> void:
	var max_cap := get_max_capacity(faction_id)
	var used_cap := get_used_capacity(faction_id, active_units)

	EventBus.capacity_changed.emit(faction_id, used_cap, max_cap)

	if used_cap > max_cap:
		EventBus.logistics_collapse_started.emit(faction_id)
		_apply_starvation(active_units, faction_id)
		EventBus.logistics_collapse_ended.emit(faction_id)


## Apply starvation damage to all units of a faction.
## Iterates in reverse to safely handle unit removal.
func _apply_starvation(active_units: Array, faction_id: int) -> void:
	for i in range(active_units.size() - 1, -1, -1):
		var unit = active_units[i]
		if unit is TacticalUnit and unit.faction_id == faction_id:
			unit.take_damage(GameConfig.STARVATION_DAMAGE, "starvation")


# === Signal Handlers ===

func _on_resource_node_captured(node_type: String, new_faction_id: int, old_faction_id: int) -> void:
	match node_type:
		"village":
			if old_faction_id in _faction_villages:
				_faction_villages[old_faction_id] = maxi(0, _faction_villages[old_faction_id] - 1)
			_faction_villages[new_faction_id] = _faction_villages.get(new_faction_id, 0) + 1
			EventBus.capacity_changed.emit(
				new_faction_id,
				0,  # Will be recalculated on next check
				get_max_capacity(new_faction_id)
			)


func _on_building_destroyed(_building: Node) -> void:
	# Handle village destruction reducing capacity
	# Implementation depends on building node structure
	pass
