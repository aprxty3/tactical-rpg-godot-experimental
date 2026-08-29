extends Node
class_name VisionManager
## VisionManager — Logic layer manager for Fog of War.
##
## Two sets per faction: what it can SEE now, and what it has ever seen. The
## HUD, the input handler and the AI all ask here, so the fog is symmetric and
## the AI cannot cheat.
##
## The Advance Wars rule, not raycast line of sight: a cell is seen inside a
## radius, and a unit on concealing terrain is only spotted from adjacent.
## Cheap, no corner cases, and already familiar to the genre's players.

@export_group("Fog Settings")
## Master switch. Off means every cell is visible to everyone, which is what
## the pre-Milestone-4 test scenes expect.
@export var fog_enabled: bool = true
## Whose view is painted on screen — the human player's.
@export var observer_faction_id: int = GameConfig.Faction.BLUE_KINGDOM
## How dark a never-scouted cell is drawn. Deliberately not opaque: the terrain
## stays readable underneath, because the fog's job is to hide who is out there,
## not to hide where the rivers and bridges are. A solid black sheet also read
## as a rendering failure rather than as fog.
@export_range(0.0, 1.0) var unseen_opacity: float = 0.78
## How dark a cell the observer has seen before but cannot see right now. Has to
## sit clearly between `unseen_opacity` and plain visible, or "remembered" and
## "never seen" collapse into the same shade.
@export_range(0.0, 1.0) var explored_opacity: float = 0.42

var grid_manager: GridManager
var fog_layer: TileMapLayer

## faction_id -> Dictionary[Vector2i, true]
var _visible: Dictionary = {}
## faction_id -> Dictionary[Vector2i, true]. Cells spotted at least once; the
## terrain stays drawn but dimmed, and units on them are not shown.
var _explored: Dictionary = {}
## faction_id -> Dictionary[Vector2i, true]. Cells where a unit would actually
## be spotted — visible cells minus concealing terrain that nobody is next to.
var _spotted: Dictionary = {}

# Fog tile atlas coordinates (see _build_fog_tileset).
const TILE_UNSEEN: Vector2i = Vector2i(0, 0)
const TILE_EXPLORED: Vector2i = Vector2i(1, 0)
const FOG_SOURCE_ID: int = 0


func _ready() -> void:
	EventBus.turn_started.connect(_on_recompute_event)
	EventBus.unit_move_completed.connect(_on_recompute_event)
	EventBus.unit_spawned.connect(_on_recompute_event)
	EventBus.unit_died.connect(_on_recompute_event)
	EventBus.unit_deserted.connect(_on_recompute_event)
	EventBus.unit_captured.connect(_on_recompute_event)
	EventBus.building_captured.connect(_on_recompute_event)
	EventBus.terrain_changed.connect(_on_recompute_event)


func setup(grid_mgr: GridManager, layer: TileMapLayer) -> void:
	grid_manager = grid_mgr
	fog_layer = layer
	if is_instance_valid(fog_layer):
		fog_layer.tile_set = _build_fog_tileset(grid_mgr.cell_size)
	recompute()


# ==============================================================================
# QUERIES — the public contract every other system uses
# ==============================================================================

## Can `faction_id` see the terrain at this cell right now?
func is_cell_visible(faction_id: int, cell: Vector2i) -> bool:
	if not fog_enabled:
		return true
	return _visible.get(faction_id, {}).has(cell)


## Has `faction_id` ever seen this cell? Explored terrain stays on the map.
func is_cell_explored(faction_id: int, cell: Vector2i) -> bool:
	if not fog_enabled:
		return true
	return _explored.get(faction_id, {}).has(cell)


## Can `faction_id` see this unit? Own units are always visible; enemies must be
## standing somewhere currently spotted.
func can_see_unit(faction_id: int, unit: TacticalUnit) -> bool:
	if not fog_enabled or not is_instance_valid(unit):
		return true
	if unit.faction_id == faction_id:
		return true
	return _spotted.get(faction_id, {}).has(unit.grid_position)


## Every enemy unit `faction_id` can currently see. The AI plans from this list
## rather than from the full roster, which is what makes the fog symmetric.
func visible_enemies_of(faction_id: int) -> Array[TacticalUnit]:
	var found: Array[TacticalUnit] = []
	for node in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(node) or not (node is TacticalUnit):
			continue
		var unit: TacticalUnit = node
		if unit.faction_id != faction_id and can_see_unit(faction_id, unit):
			found.append(unit)
	return found


# ==============================================================================
# COMPUTATION
# ==============================================================================

func _on_recompute_event(_a = null, _b = null, _c = null) -> void:
	recompute()


## Rebuild every faction's visible/spotted sets and repaint the fog.
func recompute() -> void:
	if not is_instance_valid(grid_manager):
		return

	_visible.clear()
	_spotted.clear()

	if not fog_enabled:
		_apply_unit_visibility()
		_paint_fog()
		return

	# Observers first, so the concealment pass can measure distance to them.
	var observers: Dictionary = _collect_observers()

	for faction_id in observers:
		var seen: Dictionary = {}
		for observer in observers[faction_id]:
			_flood_vision(observer["cell"], int(observer["range"]), seen)
		_visible[faction_id] = seen
		_spotted[faction_id] = _compute_spotted(seen, observers[faction_id])

		var explored: Dictionary = _explored.get(faction_id, {})
		for cell in seen:
			explored[cell] = true
		_explored[faction_id] = explored

	_apply_unit_visibility()
	_paint_fog()
	EventBus.vision_updated.emit(observer_faction_id)


## Everything that grants sight: units by class, buildings by type.
## Returns faction_id -> Array[{cell, range}].
func _collect_observers() -> Dictionary:
	var result: Dictionary = {}

	for node in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(node) or not (node is TacticalUnit):
			continue
		var unit: TacticalUnit = node
		var unit_sight: int = GameConfig.VISION_DEFAULT
		if is_instance_valid(unit.unit_data):
			unit_sight = unit.unit_data.get_vision_range()
		_add_observer(result, unit.faction_id, unit.grid_position, unit_sight)

	for node in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(node) or not (node is Building):
			continue
		var building: Building = node
		if building.faction_id == GameConfig.Faction.NEUTRAL:
			continue
		var building_sight: int = (
			GameConfig.VISION_CASTLE if building.building_type == Building.BuildingType.CASTLE
			else GameConfig.VISION_BUILDING
		)
		_add_observer(result, building.faction_id, building.grid_position, building_sight)

	return result


func _add_observer(into: Dictionary, faction_id: int, cell: Vector2i, sight: int) -> void:
	if not into.has(faction_id):
		into[faction_id] = []
	into[faction_id].append({"cell": cell, "range": sight})


## Mark every in-bounds cell within Manhattan `radius` of `origin`.
func _flood_vision(origin: Vector2i, radius: int, into: Dictionary) -> void:
	for dx in range(-radius, radius + 1):
		var span: int = radius - absi(dx)
		for dy in range(-span, span + 1):
			var cell := Vector2i(origin.x + dx, origin.y + dy)
			if grid_manager.is_within_bounds(cell):
				into[cell] = true


## Where a unit would actually be spotted. Open ground gives itself away at any
## range; forest and rocks only from right next door.
func _compute_spotted(seen: Dictionary, observers: Array) -> Dictionary:
	var spotted: Dictionary = {}
	for cell in seen:
		if not grid_manager.is_concealing(cell):
			spotted[cell] = true
			continue
		for observer in observers:
			var origin: Vector2i = observer["cell"]
			var distance: int = absi(origin.x - cell.x) + absi(origin.y - cell.y)
			if distance <= GameConfig.VISION_CONCEALED_REVEAL_RANGE:
				spotted[cell] = true
				break
	return spotted


# ==============================================================================
# RENDERING
# ==============================================================================

## Hide unit nodes the observer cannot see. Sprites stand taller than their own
## tile, so relying on the fog layer to cover them would leave heads poking out
## of the dark.
func _apply_unit_visibility() -> void:
	for node in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(node) and node is TacticalUnit:
			node.visible = can_see_unit(observer_faction_id, node)


func _paint_fog() -> void:
	if not is_instance_valid(fog_layer) or not is_instance_valid(grid_manager):
		return

	fog_layer.clear()
	if not fog_enabled:
		return

	var size: Vector2i = grid_manager.grid_size
	for x in range(size.x):
		for y in range(size.y):
			var cell := Vector2i(x, y)
			if is_cell_visible(observer_faction_id, cell):
				continue
			var tile: Vector2i = (
				TILE_EXPLORED if is_cell_explored(observer_faction_id, cell) else TILE_UNSEEN
			)
			fog_layer.set_cell(cell, FOG_SOURCE_ID, tile)


## Build the fog atlas in code rather than shipping an art file: it is two flat
## squares whose only job is to match cell_size exactly, and generating it means
## the fog can never drift out of alignment when the grid is resized.
func _build_fog_tileset(cell_size: Vector2i) -> TileSet:
	var image := Image.create(cell_size.x * 2, cell_size.y, false, Image.FORMAT_RGBA8)
	var unseen := Color(0.02, 0.02, 0.05, unseen_opacity)
	var explored := Color(0.02, 0.02, 0.05, explored_opacity)
	for y in range(cell_size.y):
		for x in range(cell_size.x):
			image.set_pixel(x, y, unseen)
			image.set_pixel(x + cell_size.x, y, explored)

	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = cell_size
	source.create_tile(TILE_UNSEEN)
	source.create_tile(TILE_EXPLORED)

	var tile_set := TileSet.new()
	tile_set.tile_size = cell_size
	tile_set.add_source(source, FOG_SOURCE_ID)
	return tile_set
