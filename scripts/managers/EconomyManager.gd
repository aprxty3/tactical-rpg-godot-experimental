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
var _faction_castles: Dictionary = {}   # castle count per faction


func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	EventBus.resource_node_captured.connect(_on_resource_node_captured)
	EventBus.building_destroyed.connect(_on_building_destroyed)
	EventBus.unit_spawned.connect(_on_unit_lifecycle_changed)
	EventBus.unit_died.connect(_on_unit_lifecycle_changed)
	EventBus.unit_deserted.connect(_on_unit_lifecycle_changed)
	EventBus.unit_upgraded.connect(_on_unit_lifecycle_changed)
	# A defection moves capacity weight from one army to the other.
	EventBus.unit_captured.connect(_on_unit_lifecycle_changed)


## Initialize a faction's starting resources.
##
## Villages start at zero because every village on the map starts neutral, so
## the count can only ever be built up by captures. Castles cannot: a faction
## owns its keep from the moment the scene loads and no capture event ever fires
## for it, so the count has to be READ off the board here or an army that later
## takes an enemy castle would be credited with two while holding two — and
## every capacity number after that would be one castle too generous.
func register_faction(faction_id: int, starting_gold: int = 200, starting_iron: int = 5) -> void:
	_faction_gold[faction_id] = starting_gold
	_faction_iron[faction_id] = starting_iron
	_faction_villages[faction_id] = 0
	_faction_castles[faction_id] = _count_castles(faction_id)


## Castles this faction currently holds, read from the board.
##
## Returns 0 rather than failing when there is no tree to walk: the focused test
## scenes build an EconomyManager on its own, with no board at all, and they are
## entitled to a manager that still answers questions about gold.
func _count_castles(faction_id: int) -> int:
	if not is_inside_tree():
		return 0
	var tree := get_tree()
	if not tree:
		return 0
	var total := 0
	for bld in tree.get_nodes_in_group("buildings"):
		if bld is Building and bld.faction_id == faction_id \
				and bld.building_type == Building.BuildingType.CASTLE:
			total += 1
	return total


# === Resource Queries ===

func get_gold(faction_id: int) -> int:
	return _faction_gold.get(faction_id, 0)


func get_iron(faction_id: int) -> int:
	return _faction_iron.get(faction_id, 0)


## Everything this faction can field: its own lands, plus what it has taken.
##
## Castles count from the SECOND one. `BASE_TROOP_CAPACITY` already stands for
## a faction's own keep, so paying for the first as well would hand every army
## five free capacity at match start; and subtracting for a lost keep would
## starve the castle-less "rogue army" the victory rules deliberately let keep
## fighting. `maxi` is what holds that floor.
func get_max_capacity(faction_id: int) -> int:
	var village_count: int = _faction_villages.get(faction_id, 0)
	var extra_castles: int = maxi(0, int(_faction_castles.get(faction_id, 0)) - 1)
	return (GameConfig.BASE_TROOP_CAPACITY
		+ village_count * GameConfig.VILLAGE_CAPACITY_BONUS
		+ extra_castles * GameConfig.CASTLE_CAPACITY_BONUS)


## Calculate the total Troop Capacity weight of active units.
##
## Validity-checked first: a roster entry can outlive its node by a frame, and
## `is` on a freed instance is a hard crash rather than a false. This is read on
## every HUD refresh, recruit check and surrender prompt, so it has to survive a
## stale entry instead of taking the game down with it.
func get_used_capacity(faction_id: int, active_units: Array) -> int:
	var total := 0
	for unit in active_units:
		if not is_instance_valid(unit) or not (unit is TacticalUnit):
			continue
		if unit.faction_id == faction_id and is_instance_valid(unit.unit_data):
			total += unit.unit_data.capacity_weight
	return total


## Spare weight before this faction hits its own ceiling. Negative while an army
## is over capacity and starving.
func get_free_capacity(faction_id: int, active_units: Array) -> int:
	return get_max_capacity(faction_id) - get_used_capacity(faction_id, active_units)


## Would `weight` more troop weight still fit?
##
## The rule lives here, once, because three separate things add troops: a castle
## recruiting, a captor claiming a prisoner, and a chest paying out a mercenary.
## Only the first ever asked. An army that could not BUY its 13th point of
## troops could still be HANDED one, and the ceiling that recruitment enforces
## turned out to be the only one the game had.
func has_capacity_for(faction_id: int, weight: int, active_units: Array) -> bool:
	return get_free_capacity(faction_id, active_units) >= weight


# === Resource Modifications ===

func add_gold(faction_id: int, amount: int) -> void:
	_faction_gold[faction_id] = get_gold(faction_id) + amount
	if not Engine.is_editor_hint() and is_instance_valid(EventBus) and EventBus.has_signal("gold_changed"):
		EventBus.gold_changed.emit(faction_id, get_gold(faction_id))


func add_iron(faction_id: int, amount: int) -> void:
	_faction_iron[faction_id] = get_iron(faction_id) + amount
	if not Engine.is_editor_hint() and is_instance_valid(EventBus) and EventBus.has_signal("iron_changed"):
		EventBus.iron_changed.emit(faction_id, get_iron(faction_id))


func spend_gold(faction_id: int, amount: int) -> bool:
	if get_gold(faction_id) >= amount:
		_faction_gold[faction_id] -= amount
		if not Engine.is_editor_hint() and is_instance_valid(EventBus) and EventBus.has_signal("gold_changed"):
			EventBus.gold_changed.emit(faction_id, get_gold(faction_id))
		return true
	if not Engine.is_editor_hint() and is_instance_valid(EventBus) and EventBus.has_signal("resources_insufficient"):
		EventBus.resources_insufficient.emit(faction_id, "gold")
	return false


func spend_iron(faction_id: int, amount: int) -> bool:
	if get_iron(faction_id) >= amount:
		_faction_iron[faction_id] -= amount
		if not Engine.is_editor_hint() and is_instance_valid(EventBus) and EventBus.has_signal("iron_changed"):
			EventBus.iron_changed.emit(faction_id, get_iron(faction_id))
		return true
	if not Engine.is_editor_hint() and is_instance_valid(EventBus) and EventBus.has_signal("resources_insufficient"):
		EventBus.resources_insufficient.emit(faction_id, "iron")
	return false


# === Income Collection (called during Upkeep Phase) ===

## Pay a faction its per-turn revenue. Takes already-summed totals rather than
## building counts: each Building states its own yield through get_income(), so
## what a type is worth lives in exactly one place and a new building type earns
## income without this function or TurnManager knowing it exists.
func collect_income(faction_id: int, gold: int, iron: int) -> void:
	add_gold(faction_id, gold)
	add_iron(faction_id, iron)


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
		if not is_instance_valid(unit) or not (unit is TacticalUnit):
			continue
		if unit.faction_id == faction_id:
			unit.take_damage(GameConfig.STARVATION_DAMAGE, "starvation")


# === Signal Handlers ===

## Which ledger each capturable building type moves.
##
## A dictionary rather than a `match` with a branch per type, because both
## branches were byte-identical apart from the tally they touched — and the
## castle would have been a third copy of the same fifteen lines.
const CAPACITY_LEDGER: Dictionary = {
	"village": "_faction_villages",
	"castle": "_faction_castles",
}


func _on_resource_node_captured(node_type: String, new_faction_id: int, old_faction_id: int) -> void:
	if not CAPACITY_LEDGER.has(node_type):
		return
	var ledger: Dictionary = get(CAPACITY_LEDGER[node_type])

	# The loser is decremented only if it was ever registered. A building can
	# change hands from NEUTRAL, and neutral has no treasury to debit.
	if old_faction_id in ledger:
		ledger[old_faction_id] = maxi(0, int(ledger[old_faction_id]) - 1)
		_announce_capacity(old_faction_id)

	ledger[new_faction_id] = int(ledger.get(new_faction_id, 0)) + 1
	_announce_capacity(new_faction_id)


## Tell the HUD what this faction can now field. Guarded rather than assumed:
## this runs from a signal, and the focused test scenes drive captures with no
## TurnManager and sometimes no EventBus at all.
func _announce_capacity(faction_id: int) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(EventBus) \
			or not EventBus.has_signal("capacity_changed"):
		return
	var units: Array = TurnManager.get_faction_units(faction_id) if is_instance_valid(TurnManager) else []
	EventBus.capacity_changed.emit(
		faction_id, get_used_capacity(faction_id, units), get_max_capacity(faction_id))


func _on_unit_lifecycle_changed(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(EventBus) or not EventBus.has_signal("capacity_changed"):
		return
	if not is_instance_valid(TurnManager):
		return
	for fid in _faction_gold.keys():
		var units: Array = TurnManager.get_faction_units(fid)
		var used_cap: int = get_used_capacity(fid, units)
		var max_cap: int = get_max_capacity(fid)
		EventBus.capacity_changed.emit(fid, used_cap, max_cap)


## A building was burned off the map. Only villages carry troop capacity, so
## only they need unwinding here — but the emit is deliberately not filtered at
## the source, so a future destructible building type arrives at one handler.
##
## This was a `pass` with a note saying it depended on the node structure. It
## stopped being hypothetical the moment monsters could raze a village: without
## it, an army kept the +2 capacity of a village that no longer existed, and
## kept it permanently, because nothing else ever decrements that count.
func _on_building_destroyed(building: Node) -> void:
	if not is_instance_valid(building) or not (building is Building):
		return
	if building.building_type != Building.BuildingType.HOUSE:
		return

	var owner_id: int = building.faction_id
	if not _faction_villages.has(owner_id):
		return
	_faction_villages[owner_id] = maxi(0, _faction_villages[owner_id] - 1)

	# The owner may now be over the ceiling they were exactly at. Announcing it
	# here means the HUD turns red the moment the smoke clears, rather than
	# waiting for their next upkeep to tell them they are starving.
	_announce_capacity(owner_id)
