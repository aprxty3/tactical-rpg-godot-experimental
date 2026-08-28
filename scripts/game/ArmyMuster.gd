extends RefCounted
class_name ArmyMuster
## ArmyMuster — puts each participant's opening army on the board.
##
## These used to be six nodes saved into the scene file, which is exactly why
## the match could only ever be Blue versus Red: a scene file cannot hold "three
## units for whichever factions happen to be playing". Once that moved into
## code it landed in `MatchController` alongside input handling, selection state
## and the highlight overlay; this is that block on its own.
##
## Runs once, at setup, and holds no state between calls — so a test can muster
## an army onto a bare grid without building a match around it.

## How far from its castle an army will look for somewhere to stand before it
## gives up. Four rings is already 80 cells; needing more than that means the
## castle was walled in by water and the map is the problem, not the search.
const MAX_RADIUS: int = 4

var _grid: GridManager
var _container: Node2D


func _init(grid_manager: GridManager, unit_container: Node2D) -> void:
	_grid = grid_manager
	_container = unit_container


## Place `roles` around each faction's own castle. Returns everything mustered,
## so a caller can count what actually made it onto the board rather than
## assuming the full complement arrived.
func muster(faction_ids: Array, roles: Array[String]) -> Array:
	var placed: Array = []
	for faction_id in faction_ids:
		var castle: Building = castle_of(faction_id)
		if castle == null:
			push_warning("ArmyMuster: %s has no castle; it musters nothing."
				% GameConfig.faction_title(faction_id))
			continue

		var cells: Array[Vector2i] = muster_cells(castle.grid_position, roles.size())
		if cells.size() < roles.size():
			push_warning("ArmyMuster: only %d of %d muster cells free near %s's castle."
				% [cells.size(), roles.size(), GameConfig.faction_title(faction_id)])

		for i in range(mini(cells.size(), roles.size())):
			var unit := spawn_unit(roles[i], faction_id, cells[i])
			if is_instance_valid(unit):
				placed.append(unit)
	return placed


func castle_of(faction_id: int) -> Building:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	for bld in (loop as SceneTree).get_nodes_in_group("buildings"):
		if bld is Building and bld.building_type == Building.BuildingType.CASTLE \
				and bld.faction_id == faction_id:
			return bld
	return null


## Free cells around a castle, searched ring by ring so the army forms up tight
## against its own keep rather than strung out across the map.
func muster_cells(origin: Vector2i, count: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if not is_instance_valid(_grid):
		return found

	var radius: int = 1
	while found.size() < count and radius <= MAX_RADIUS:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				# The ring only. Everything inside it was already offered by a
				# smaller radius, and re-walking it would just cost time.
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var cell: Vector2i = origin + Vector2i(dx, dy)
				if found.has(cell):
					continue
				# A building's own cell is walkable as far as the grid is
				# concerned, but standing the opening army on top of the gold
				# mine next door reads as a bug.
				if not _grid.is_cell_walkable(cell):
					continue
				if _grid.get_building_at(cell) != null:
					continue
				found.append(cell)
				if found.size() == count:
					return found
		radius += 1
	return found


## Instance one unit scene and hand it to the grid.
##
## `faction_id` is assigned before `add_child`, so the unit is already the right
## colour when its own `_ready` builds the overhead readout from it.
func spawn_unit(role: String, faction_id: int, cell: Vector2i) -> TacticalUnit:
	if not is_instance_valid(_container) or not is_instance_valid(_grid):
		return null

	var suffix: String = GameConfig.faction_display_name(faction_id)
	var path: String = "res://scenes/units/TacticalUnit_%s_%s.tscn" % [role, suffix]
	if not ResourceLoader.exists(path):
		push_warning("ArmyMuster: no scene at %s" % path)
		return null

	var scene: PackedScene = load(path)
	var unit: TacticalUnit = scene.instantiate()
	unit.name = "%s_%s" % [suffix, role]
	unit.faction_id = faction_id
	_container.add_child(unit)
	_grid.register_unit(unit, cell)
	return unit
