extends Node
class_name MapObjectManager
## MapObjectManager — Logic layer manager for everything standing on the map
## that is not a unit or a building: treasure chests, powder kegs and fire.
##
## It owns the cell registry, drives the once-per-round tick, and holds the
## rules the objects themselves deliberately do not: how a blast chains, how
## fire spreads and scorches, and what comes out of a chest. The objects stay
## dumb actors; every rule that needs the grid, the economy or the roster lives
## here, behind one injected setup() like the rest of the managers.

@export_group("Hazard Settings")
## Seed for chest scatter and Pandora rolls. 0 randomizes each match; any other
## value reproduces a layout exactly, which is what the test scenes use.
@export var random_seed: int = 0
## How many chests to scatter when populate() is called.
@export var chest_count: int = 5
## Buried traps per match. Zero disables them entirely, which is what the
## focused older test scenes want.
@export var trap_count: int = GameConfig.HIDDEN_TRAP_COUNT
## Upper bound on barrels placed at bridge mouths.
@export var barrel_count: int = 6

## 1728x192 sheet — nine 192px frames in a single row.
const DEFAULT_UNIT_SCENE: String = "res://scenes/units/TacticalUnit.tscn"
## What claws its way out of a chest that should have stayed shut.
const AWAKENED_UNITS: Array[String] = [
	"res://resources/units/skull_black.tres",
	"res://resources/units/skeleton_black.tres",
]

const ADJACENT: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var grid_manager: GridManager
var economy_manager: Node
## Where spawned hazards and VFX are parented.
var object_container: Node2D
## Where units spawned by a chest are parented.
var unit_container: Node2D

## Vector2i -> Array[MapObject]. Several objects may share a cell (fire burning
## over a chest), so this maps to a list rather than a single object.
var _objects: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _last_round: int = 1


func _ready() -> void:
	EventBus.unit_move_completed.connect(_on_unit_move_completed)
	EventBus.turn_started.connect(_on_turn_started)


func setup(grid_mgr: GridManager, eco_mgr: Node, objects_parent: Node2D, units_parent: Node2D) -> void:
	grid_manager = grid_mgr
	economy_manager = eco_mgr
	object_container = objects_parent
	unit_container = units_parent

	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_last_round = TurnManager.turn_number


# ==============================================================================
# REGISTRY
# ==============================================================================

func register_object(obj: MapObject) -> void:
	if not _objects.has(obj.grid_position):
		_objects[obj.grid_position] = []
	_objects[obj.grid_position].append(obj)


## Called by MapObject.consume(). Erases eagerly rather than waiting for
## queue_free, so a chain reaction cannot re-enter a barrel already spent.
func unregister_object(obj: MapObject) -> void:
	var at_cell: Array = _objects.get(obj.grid_position, [])
	at_cell.erase(obj)
	if at_cell.is_empty():
		_objects.erase(obj.grid_position)


func objects_at(cell: Vector2i) -> Array:
	return _objects.get(cell, []).duplicate()


func has_fire_at(cell: Vector2i) -> bool:
	for obj in objects_at(cell):
		if obj is Fire:
			return true
	return false


## Convenience passthrough so map objects never need the GridManager directly.
func unit_at(cell: Vector2i) -> TacticalUnit:
	if not is_instance_valid(grid_manager):
		return null
	return grid_manager.get_unit_at(cell)


# ==============================================================================
# SPAWNING & PLACEMENT
# ==============================================================================

## Scatter the map's hazards and treasure. Barrels come from MapBuilder's bridge
## analysis (deterministic — they belong at the chokepoints); chests come from
## its seeded scatter, so every match reads differently.
func populate(map_builder: MapBuilder, reserved: Array[Vector2i]) -> void:
	if not is_instance_valid(map_builder):
		return
	# Barrels claim their cells before chests are scattered, so treasure can
	# never spawn underneath a keg.
	var claimed: Array[Vector2i] = reserved.duplicate()
	for cell in map_builder.get_barrel_cells(claimed, barrel_count):
		spawn_barrel(cell)
		claimed.append(cell)
	for cell in map_builder.get_chest_cells(claimed, chest_count, _rng):
		spawn_chest(cell)
		claimed.append(cell)
	# Traps last: they are invisible, so anything that must be seen has already
	# claimed its cell and a mine can never end up hidden under a chest.
	for cell in map_builder.get_trap_cells(claimed, trap_count, _rng):
		spawn_trap(cell)


func spawn_barrel(cell: Vector2i) -> Barrel:
	return _spawn(Barrel.new(), cell) as Barrel


func spawn_chest(cell: Vector2i) -> Chest:
	return _spawn(Chest.new(), cell) as Chest


func spawn_trap(cell: Vector2i) -> Trap:
	return _spawn(Trap.new(), cell) as Trap


## Set a cell alight. No-op if it is already burning.
func ignite(cell: Vector2i) -> Fire:
	if has_fire_at(cell) or not is_instance_valid(grid_manager):
		return null
	if not grid_manager.is_within_bounds(cell):
		return null
	return _spawn(Fire.new(), cell) as Fire


func _spawn(obj: MapObject, cell: Vector2i) -> MapObject:
	if not is_instance_valid(object_container) or not is_instance_valid(grid_manager):
		obj.free()
		return null
	obj.grid_position = cell
	obj.manager = self
	obj.position = grid_manager.grid_to_world(cell)
	object_container.add_child(obj)
	register_object(obj)
	return obj


# ==============================================================================
# DISPATCH
# ==============================================================================

func _on_unit_move_completed(unit: Node, _from: Vector2i, to: Vector2i) -> void:
	if not (unit is TacticalUnit):
		return
	for obj in objects_at(to):
		if is_instance_valid(obj) and not obj.is_spent():
			obj.on_unit_entered(unit)


## Hazards act once per ROUND, not once per faction turn — otherwise a fire in a
## two-player match would burn twice as fast as its stated lifetime.
func _on_turn_started(_faction_id: int) -> void:
	if TurnManager.turn_number == _last_round:
		return
	_last_round = TurnManager.turn_number
	_tick_round()


func _tick_round() -> void:
	# Snapshot first: ticking spreads fire, which registers new objects, and
	# those must not also tick in the round that created them.
	var snapshot: Array = []
	for cell in _objects:
		snapshot.append_array(_objects[cell])
	for obj in snapshot:
		if is_instance_valid(obj) and not obj.is_spent():
			obj.on_round_tick()


# ==============================================================================
# EXPLOSIONS
# ==============================================================================

## Detonate the barrel at `origin` and everything its blast reaches.
##
## Breadth-first over a visited set rather than recursion: a cluster of kegs
## must never re-enter a cell it has already blown, and each barrel is consumed
## before its blast is applied so it cannot be queued twice.
func detonate_at(origin: Vector2i) -> void:
	var queue: Array[Vector2i] = [origin]
	var visited: Dictionary = {}
	var chain_index: int = 0

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if visited.has(cell):
			continue
		visited[cell] = true

		for obj in objects_at(cell):
			if obj is Barrel:
				obj.consume(0.05)

		_apply_blast(cell, chain_index)
		chain_index += 1

		for neighbour in _barrel_cells_within(cell, GameConfig.BARREL_CHAIN_RADIUS):
			if not visited.has(neighbour):
				queue.append(neighbour)


func _apply_blast(cell: Vector2i, chain_index: int) -> void:
	# Drawing the blast is VfxManager's job — it listens for this signal. This
	# manager owns map objects and their rules, not their pyrotechnics, and
	# keeping the visual here meant a scene could render two explosions or none
	# depending on which manager it happened to include.
	EventBus.hazard_detonated.emit(cell, GameConfig.BARREL_BLAST_RADIUS, chain_index)

	for target in _cells_within(cell, GameConfig.BARREL_BLAST_RADIUS):
		var victim: TacticalUnit = unit_at(target)
		if is_instance_valid(victim):
			# TRUE damage: a keg does not care how good your armour is.
			victim.take_damage(GameConfig.BARREL_DAMAGE, "true")
		if _is_flammable(target) and _rng.randf() < _flammability(target) * GameConfig.BLAST_IGNITION_MULT:
			ignite(target)


## Fire the buried trap at `origin`: a 3x2 wall of blast and flame.
##
## Deliberately NOT routed through `detonate_at`. A keg's blast is a Manhattan
## radius that chains into neighbouring kegs; a trap is a fixed rectangle that
## chains into nothing — `HIDDEN_TRAP_MIN_SPACING` guarantees no second trap is
## close enough to reach. Forcing both through one function would mean a
## rectangle/radius flag and a chain flag threaded through every call, to save
## about six lines.
func spring_trap_at(origin: Vector2i) -> void:
	# Consume first, exactly as `detonate_at` does for barrels: the blast can
	# damage the unit standing on the trap, and a re-entrant spring during that
	# must find the trap already spent.
	for obj in objects_at(origin):
		if obj is Trap:
			obj.consume(0.05)

	var footprint: Array[Vector2i] = trap_blast_cells(origin)
	# Origin first — VfxManager centres the blast flipbook on cells[0].
	EventBus.trap_sprung.emit(footprint)

	for cell in footprint:
		var victim: TacticalUnit = unit_at(cell)
		if is_instance_valid(victim):
			# TRUE damage, like a keg: buried powder does not care about armour.
			victim.take_damage(GameConfig.HIDDEN_TRAP_DAMAGE, "true")
			victim.adjust_morale(GameConfig.MORALE_AMBUSHED)
		# A mine is incendiary by design, so every cell that CAN burn does —
		# no flammability roll, unlike a keg's chancy ignition.
		if GameConfig.HIDDEN_TRAP_IGNITE_ALL and _is_flammable(cell):
			ignite(cell)


## The 3x2 footprint centred on `origin`, clipped to the map.
##
## Width 3 centres cleanly (origin +/- 1). Height 2 cannot be centred on a single
## row, so the extra row goes ABOVE the origin: the unit that stepped on the mine
## is always in the lower row, and the blast reads as erupting upward out of it
## rather than swallowing the cell behind.
##
## `origin` is always element 0, which is what lets a listener centre a single
## blast sprite without re-deriving the shape.
func trap_blast_cells(origin: Vector2i) -> Array[Vector2i]:
	var size: Vector2i = GameConfig.HIDDEN_TRAP_BLAST_SIZE
	var half_w: int = (size.x - 1) / 2
	var cells: Array[Vector2i] = []
	if is_instance_valid(grid_manager) and grid_manager.is_within_bounds(origin):
		cells.append(origin)

	for dy in range(-(size.y - 1), 1):
		for dx in range(-half_w, half_w + 1):
			var cell := Vector2i(origin.x + dx, origin.y + dy)
			if cell == origin:
				continue
			if is_instance_valid(grid_manager) and not grid_manager.is_within_bounds(cell):
				continue
			cells.append(cell)
	return cells


## Cells holding an unspent barrel within `radius` of `cell`.
func _barrel_cells_within(cell: Vector2i, radius: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for candidate in _cells_within(cell, radius):
		for obj in objects_at(candidate):
			if obj is Barrel and not obj.is_spent():
				found.append(candidate)
				break
	return found


func _cells_within(origin: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in range(-radius, radius + 1):
		var span: int = radius - absi(dx)
		for dy in range(-span, span + 1):
			var cell := Vector2i(origin.x + dx, origin.y + dy)
			if is_instance_valid(grid_manager) and grid_manager.is_within_bounds(cell):
				cells.append(cell)
	return cells


# ==============================================================================
# FIRE
# ==============================================================================

## Try to catch each neighbouring cell alight. Only terrain with a `flammable`
## chance can catch, which in practice means forest burns and everything else
## mostly does not.
func spread_fire_from(cell: Vector2i) -> void:
	for dir in ADJACENT:
		var neighbour: Vector2i = cell + dir
		if not _is_flammable(neighbour):
			continue
		var chance: float = _flammability(neighbour)
		if _rng.randf() < chance:
			ignite(neighbour)


func _is_flammable(cell: Vector2i) -> bool:
	if not is_instance_valid(grid_manager) or not grid_manager.is_within_bounds(cell):
		return false
	return not has_fire_at(cell) and _flammability(cell) > 0.0


func _flammability(cell: Vector2i) -> float:
	var base: float = float(GameConfig.terrain_rule(grid_manager.get_terrain(cell), "flammable"))
	return base * GameConfig.FIRE_SPREAD_MULT


## A fire that burns out takes the forest with it. Scorched earth keeps the
## movement cost of open ground but loses cover, concealment and ambush — so
## burning the enemy out of a wood is a permanent tactical change, not a
## temporary one.
func extinguish_fire_at(cell: Vector2i) -> void:
	var scorched: bool = false
	if is_instance_valid(grid_manager) and grid_manager.get_terrain(cell) == GameConfig.TerrainType.FOREST:
		grid_manager.set_terrain(cell, GameConfig.TerrainType.SCORCHED)
		scorched = true
	EventBus.fire_extinguished.emit(cell, scorched)


# ==============================================================================
# PANDORA'S BOX
# ==============================================================================

## Resolve an opened chest into one of four outcomes and announce it.
func open_chest(chest: Chest, opener: TacticalUnit) -> void:
	var outcome: String = _roll_pandora()
	var result: Dictionary = {}

	match outcome:
		"war_spoils":
			result = _grant_spoils(opener)
		"mercenary":
			result = _grant_mercenary(chest.grid_position, opener)
		"trap":
			result = _spring_trap(opener)
		"awaken_dead":
			result = _awaken_dead(chest.grid_position, opener)

	result["outcome"] = outcome
	EventBus.map_event_triggered.emit(outcome, chest.grid_position, result)


## Weighted pick over the GameConfig odds. Normalised by the total rather than
## assuming the constants sum to 1.0, so retuning one of them cannot silently
## make an outcome unreachable.
func _roll_pandora() -> String:
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

	var roll: float = _rng.randf() * total
	for entry in table:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return entry["id"]
	return table[table.size() - 1]["id"]


func _grant_spoils(opener: TacticalUnit) -> Dictionary:
	var gold: int = _rng.randi_range(GameConfig.PANDORA_SPOILS_GOLD.x, GameConfig.PANDORA_SPOILS_GOLD.y)
	var iron: int = _rng.randi_range(GameConfig.PANDORA_SPOILS_IRON.x, GameConfig.PANDORA_SPOILS_IRON.y)
	if is_instance_valid(economy_manager):
		economy_manager.add_gold(opener.faction_id, gold)
		economy_manager.add_iron(opener.faction_id, iron)
	return {"gold": gold, "iron": iron}


func _grant_mercenary(cell: Vector2i, opener: TacticalUnit) -> Dictionary:
	var data: UnitData = _pick_mercenary_data(opener)
	var free_cells := _free_cells_around(cell, 1)
	if data == null or free_cells.is_empty():
		# Nowhere to stand, or nothing to hire — pay the finder's fee instead.
		return _grant_spoils(opener)

	var hired := _spawn_unit(data, opener.faction_id, free_cells[0])
	return {"unit": hired, "unit_name": data.unit_name}


## Hire whatever the opener's own castle could field, preferring its best troop.
## Falls back to a copy of the opener when that faction holds no castle.
func _pick_mercenary_data(opener: TacticalUnit) -> UnitData:
	var best: UnitData = null
	for node in get_tree().get_nodes_in_group("buildings"):
		if not (node is Building):
			continue
		var building: Building = node
		if building.faction_id != opener.faction_id or building.building_type != Building.BuildingType.CASTLE:
			continue
		for candidate in building.recruitable_units:
			if is_instance_valid(candidate) and (best == null or candidate.recruit_cost_gold > best.recruit_cost_gold):
				best = candidate

	if best != null:
		return UnitData.variant_for_faction(best, opener.faction_id)
	return opener.unit_data if is_instance_valid(opener.unit_data) else null


func _spring_trap(opener: TacticalUnit) -> Dictionary:
	opener.take_damage(GameConfig.PANDORA_TRAP_DAMAGE, "true")
	opener.adjust_morale(GameConfig.MORALE_AMBUSHED)
	return {"damage": GameConfig.PANDORA_TRAP_DAMAGE}


## The dead rise against whoever disturbed them.
##
## They enlist under the opener's enemy rather than the Black Coven, because the
## Coven takes no turns in this match — undead spawned into a faction that never
## acts would be statues. Their sprites stay Coven undead either way; the
## Undead line has no per-faction variants by design.
func _awaken_dead(cell: Vector2i, opener: TacticalUnit) -> Dictionary:
	var hostile_faction: int = _enemy_of(opener.faction_id)
	var cells := _free_cells_around(cell, GameConfig.PANDORA_UNDEAD_COUNT)
	var raised: Array = []

	for i in range(mini(cells.size(), GameConfig.PANDORA_UNDEAD_COUNT)):
		var path: String = AWAKENED_UNITS[i % AWAKENED_UNITS.size()]
		var data: UnitData = load(path) as UnitData
		if is_instance_valid(data):
			raised.append(_spawn_unit(data, hostile_faction, cells[i]))

	return {"count": raised.size(), "faction_id": hostile_faction}


func _enemy_of(faction_id: int) -> int:
	for other in TurnManager.faction_order:
		if other != faction_id:
			return other
	return GameConfig.Faction.BLACK_COVEN


# === Spawn helpers ===

## Instance a unit the same way Building.recruit_unit does — its own prefab when
## the resource names one, the shared TacticalUnit scene otherwise.
func _spawn_unit(data: UnitData, faction_id: int, cell: Vector2i) -> TacticalUnit:
	if not is_instance_valid(unit_container):
		return null

	var prefab: PackedScene = data.unit_scene if is_instance_valid(data.unit_scene) else load(DEFAULT_UNIT_SCENE)
	if not is_instance_valid(prefab):
		return null

	var unit: TacticalUnit = prefab.instantiate() as TacticalUnit
	unit.unit_data = data
	unit.faction_id = faction_id
	unit.grid_position = cell
	unit_container.add_child(unit)
	if unit.has_method("_initialize_from_data"):
		unit._initialize_from_data()

	EventBus.unit_spawned.emit(unit, faction_id)
	return unit


## Walkable, unoccupied cells next to `cell`, nearest ring first.
func _free_cells_around(cell: Vector2i, count: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if not is_instance_valid(grid_manager):
		return found

	for radius in range(1, 3):
		for candidate in _cells_within(cell, radius):
			if found.size() >= count:
				return found
			if candidate == cell or found.has(candidate):
				continue
			if grid_manager.is_cell_walkable(candidate):
				found.append(candidate)
	return found
