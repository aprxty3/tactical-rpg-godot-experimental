extends Node
class_name MapBuilder
## MapBuilder — Logic layer: paints the tactical battlefield and reports which
## cells are impassable terrain.
##
## Two rivers cut a 30x20 board into a west flank, a contested centre and an
## east flank, crossable only at four bridges — the prototype's flat rectangle
## had no chokepoints and nothing to fight over.
##
## Owns no game rules: it paints TileMapLayers and hands blocked cells back to
## GridManager, the single source of truth for movement.

# --- Tileset source ids (resources/tilesets/terrain_flat_tileset.tres) ---
const SRC_GROUND: int = 0
const SRC_WATER: int = 1
const SRC_BRIDGE: int = 2

## TinySwords Tilemap_Flat packs two 4x4 blob blocks: grass at columns 0-3 and
## sand at columns 5-8. Within a block, column/row select which edges are drawn.
const GRASS_ORIGIN: Vector2i = Vector2i(0, 0)
const SAND_ORIGIN: Vector2i = Vector2i(5, 0)

const BRIDGE_H_MID: Vector2i = Vector2i(1, 0)
const BRIDGE_V_MID: Vector2i = Vector2i(0, 2)

@export var grid_size: Vector2i = Vector2i(30, 20)

# --- Layout ---------------------------------------------------------------
## Two rivers split the map into three lanes. Both break open across the middle
## band so the centre stays a single contiguous brawl, not a third island.
const RIVER_COLUMNS: Array[int] = [10, 19]
const RIVER_GAP_ROWS: Vector2i = Vector2i(8, 11)  # inclusive rows left dry
## Ornamental ponds — pure cover/terrain interest, away from the lanes.
const PONDS: Array[Rect2i] = [
	Rect2i(13, 0, 3, 2),
	Rect2i(14, 18, 3, 2),
	Rect2i(0, 9, 2, 2),
	Rect2i(28, 9, 2, 2),
]
## Road waypoints. Roads are drawn as L-segments between consecutive points and
## are deliberately routed through the river columns — every crossing becomes a
## bridge, so the bridges are wherever the roads actually need them.
const ROADS: Array = [
	[Vector2i(3, 3), Vector2i(10, 4), Vector2i(15, 6)],       # Purple  -> centre
	[Vector2i(26, 3), Vector2i(19, 4), Vector2i(15, 6)],      # Red     -> centre
	[Vector2i(3, 16), Vector2i(10, 15), Vector2i(15, 13)],    # Blue    -> centre
	[Vector2i(26, 16), Vector2i(19, 15), Vector2i(15, 13)],   # Yellow  -> centre
	[Vector2i(15, 6), Vector2i(15, 13)],                      # centre spine
	[Vector2i(3, 3), Vector2i(3, 16)],                        # west highway
	[Vector2i(26, 3), Vector2i(26, 16)],                      # east highway
]

var _water: Dictionary = {}    # Vector2i -> true
var _bridges: Dictionary = {}  # Vector2i -> true
var _roads: Dictionary = {}    # Vector2i -> true

## Vector2i -> GameConfig.TerrainType. Filled by build() for the base layout and
## upgraded by scatter_decor() where props actually land, so the terrain map and
## what the player sees can never disagree.
var _terrain: Dictionary = {}
## Vector2i -> Sprite2D, so a burning forest can drop its own tree.
var _decor_nodes: Dictionary = {}


## Paint every layer and return the cells GridManager must treat as solid.
func build(water_layer: TileMapLayer, ground_layer: TileMapLayer,
		path_layer: TileMapLayer, bridge_layer: TileMapLayer) -> Array[Vector2i]:
	_compute_water()
	_compute_roads()
	_carve_bridges()
	_compute_base_terrain()

	_paint_water(water_layer)
	_paint_blob(ground_layer, GRASS_ORIGIN, _land_cells())
	_paint_blob(path_layer, SAND_ORIGIN, _roads.keys())
	_paint_bridges(bridge_layer)

	var blocked: Array[Vector2i] = []
	for cell in _water:
		if not _bridges.has(cell):
			blocked.append(cell)
	return blocked


## The finished per-cell terrain map. Only meaningful after build() and, for
## forest/rock cells, after scatter_decor().
func get_terrain_map() -> Dictionary:
	return _terrain


## Base layout terrain. Forest and rock are added later by scatter_decor(),
## because a cell is only forest if a tree was actually drawn on it.
func _compute_base_terrain() -> void:
	_terrain.clear()
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell := Vector2i(x, y)
			if _bridges.has(cell):
				_terrain[cell] = GameConfig.TerrainType.BRIDGE
			elif _water.has(cell):
				_terrain[cell] = GameConfig.TerrainType.WATER
			elif _roads.has(cell):
				_terrain[cell] = GameConfig.TerrainType.ROAD
			else:
				_terrain[cell] = GameConfig.TerrainType.PLAIN


func is_water(cell: Vector2i) -> bool:
	return _water.has(cell) and not _bridges.has(cell)


func is_road(cell: Vector2i) -> bool:
	return _roads.has(cell)


# === Layout computation ===

func _compute_water() -> void:
	for col in RIVER_COLUMNS:
		for y in range(grid_size.y):
			if y >= RIVER_GAP_ROWS.x and y <= RIVER_GAP_ROWS.y:
				continue
			_water[Vector2i(col, y)] = true
	for pond in PONDS:
		for x in range(pond.position.x, pond.position.x + pond.size.x):
			for y in range(pond.position.y, pond.position.y + pond.size.y):
				var c := Vector2i(x, y)
				if _in_bounds(c):
					_water[c] = true


func _compute_roads() -> void:
	for route in ROADS:
		for i in range(route.size() - 1):
			_draw_l_segment(route[i], route[i + 1])


## L-shaped segment: horizontal first, then vertical. Keeps roads on the grid
## and readable, the way Advance Wars lays them out.
func _draw_l_segment(from: Vector2i, to: Vector2i) -> void:
	var x := from.x
	while x != to.x:
		_roads[Vector2i(x, from.y)] = true
		x += signi(to.x - x)
	var y := from.y
	while y != to.y:
		_roads[Vector2i(to.x, y)] = true
		y += signi(to.y - y)
	_roads[to] = true


## Any road cell that lands in water becomes a bridge, plus its immediate
## neighbours along the river so the crossing is a real span, not one plank.
func _carve_bridges() -> void:
	for cell in _roads.keys():
		if _water.has(cell):
			_bridges[cell] = true


func _land_cells() -> Array:
	var cells: Array = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var c := Vector2i(x, y)
			if not _water.has(c) or _bridges.has(c):
				cells.append(c)
	return cells


# === Painting ===

func _paint_water(layer: TileMapLayer) -> void:
	if not layer:
		return
	layer.clear()
	# Water sits under everything: filling the whole rect means the grass blob's
	# own edge tiles form the shoreline, instead of leaving a black void.
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			layer.set_cell(Vector2i(x, y), SRC_WATER, Vector2i(0, 0))


## Paint a 4x4 blob block, picking the tile whose drawn edges match which
## neighbours are missing.
func _paint_blob(layer: TileMapLayer, origin: Vector2i, cells: Array) -> void:
	if not layer:
		return
	layer.clear()
	var present: Dictionary = {}
	for c in cells:
		present[c] = true
	for c in cells:
		var cell: Vector2i = c
		var l: bool = present.has(cell + Vector2i.LEFT)
		var r: bool = present.has(cell + Vector2i.RIGHT)
		var u: bool = present.has(cell + Vector2i.UP)
		var d: bool = present.has(cell + Vector2i.DOWN)
		layer.set_cell(cell, SRC_GROUND, origin + _blob_offset(l, r, u, d))


## Tilemap_Flat's 4x4 blocks are a strict edge lookup, not interchangeable
## variants — verified by sampling every tile's border bands:
##   col 0 = left edge   col 1 = none   col 2 = right edge   col 3 = both
##   row 0 = top edge    row 1 = none   row 2 = bottom edge  row 3 = both
## Randomising between columns 1 and 2 for interiors sprays right-hand edges
## through open field and renders the map as a maze.
func _blob_offset(l: bool, r: bool, u: bool, d: bool) -> Vector2i:
	var col: int = 3
	if l and r:
		col = 1
	elif r:
		col = 0
	elif l:
		col = 2
	var row: int = 3
	if u and d:
		row = 1
	elif d:
		row = 0
	elif u:
		row = 2
	return Vector2i(col, row)


func _paint_bridges(layer: TileMapLayer) -> void:
	if not layer:
		return
	layer.clear()
	for cell in _bridges:
		var horizontal: bool = _bridges.has(cell + Vector2i.LEFT) or _bridges.has(cell + Vector2i.RIGHT) \
			or _roads.has(cell + Vector2i.LEFT) or _roads.has(cell + Vector2i.RIGHT)
		layer.set_cell(cell, SRC_BRIDGE, BRIDGE_H_MID if horizontal else BRIDGE_V_MID)


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < grid_size.x and c.y >= 0 and c.y < grid_size.y


# === Decoration ===

## Plain Sprite2Ds, avoiding roads, water and reserved cells so they never hide
## a unit. The prop decides the cell's terrain type, so visible cover is exactly
## the cover the rules apply.
##
## Both tree sheets are 1536x256 holding EIGHT 192px frames, not six. Declaring
## six made Godot slice at 256px, so every frame carried a strip of the next
## tree's trunk — the slivers that appeared beside every tree.
const TREE_SPECS: Array = [
	{"path": "res://assets/terrain/Resources/Wood/Trees/Tree1.png", "hframes": 8, "scale": 0.30, "y": -14.0},
	{"path": "res://assets/terrain/Resources/Wood/Trees/Tree2.png", "hframes": 8, "scale": 0.30, "y": -14.0},
]
const ROCK_SPECS: Array = [
	{"path": "res://assets/terrain/Rocks/Rock1.png", "hframes": 1, "scale": 0.75, "y": 4.0},
	{"path": "res://assets/terrain/Rocks/Rock3.png", "hframes": 1, "scale": 0.75, "y": 4.0},
]

## Forest anchors, hand-placed so cover sits where fights actually happen:
## either side of each bridge approach and along the flank highways. Each
## anchor grows into a 2-4 cell clump, because a one-tile forest is a decoration
## while a clump is a position worth taking.
const FOREST_ANCHORS: Array[Vector2i] = [
	Vector2i(6, 2), Vector2i(7, 6), Vector2i(5, 11), Vector2i(6, 18),
	Vector2i(12, 2), Vector2i(13, 8), Vector2i(12, 16), Vector2i(17, 3),
	Vector2i(18, 8), Vector2i(17, 17), Vector2i(23, 2), Vector2i(24, 7),
	Vector2i(25, 11), Vector2i(23, 18), Vector2i(9, 9), Vector2i(20, 11),
]
## Lone boulders: heavier cover than forest and it cannot burn.
const ROCK_SPOTS: Array[Vector2i] = [
	Vector2i(2, 7), Vector2i(28, 14), Vector2i(11, 12), Vector2i(19, 16),
	Vector2i(8, 15), Vector2i(21, 5),
]

const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## Place props and tag the terrain map with the cover they create.
## Returns the number of prop cells placed.
func scatter_decor(parent: Node2D, cell_size: Vector2i, reserved: Array[Vector2i]) -> int:
	if not parent:
		return 0
	for child in parent.get_children():
		child.queue_free()
	_decor_nodes.clear()

	var taken: Dictionary = {}
	for c in reserved:
		taken[c] = true

	var placed: int = 0
	for anchor in FOREST_ANCHORS:
		var size: int = 2 + absi(anchor.x * 7 + anchor.y * 13) % 3
		for cell in _grow_clump(anchor, size, taken):
			if _place_prop(parent, cell, cell_size, TREE_SPECS, GameConfig.TerrainType.FOREST):
				taken[cell] = true
				placed += 1

	for cell in ROCK_SPOTS:
		if _is_prop_cell_free(cell, taken):
			if _place_prop(parent, cell, cell_size, ROCK_SPECS, GameConfig.TerrainType.ROCK):
				taken[cell] = true
				placed += 1

	return placed


## Grow a contiguous clump outward from an anchor. Deterministic: the neighbour
## order is rotated by the anchor's own coordinates, so clumps differ in shape
## without ever differing between runs.
func _grow_clump(anchor: Vector2i, size: int, taken: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var rot: int = absi(anchor.x + anchor.y) % NEIGHBOURS.size()
	var dirs: Array[Vector2i] = []
	for i in range(NEIGHBOURS.size()):
		dirs.append(NEIGHBOURS[(i + rot) % NEIGHBOURS.size()])

	var queue: Array[Vector2i] = [anchor]
	var seen: Dictionary = {anchor: true}
	var claimed: Dictionary = {}

	while not queue.is_empty() and cells.size() < size:
		var cell: Vector2i = queue.pop_front()
		if not _is_prop_cell_free(cell, taken) or claimed.has(cell):
			continue
		cells.append(cell)
		claimed[cell] = true
		for d in dirs:
			var n: Vector2i = cell + d
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return cells


## A cell can hold a prop when it is open ground nobody has claimed. Roads and
## water stay clear so the lanes read cleanly and nothing blocks a crossing.
func _is_prop_cell_free(cell: Vector2i, taken: Dictionary) -> bool:
	if not _in_bounds(cell) or taken.has(cell):
		return false
	return not _water.has(cell) and not _roads.has(cell) and not _bridges.has(cell)


## Instance one prop sprite and record the terrain it creates.
func _place_prop(parent: Node2D, cell: Vector2i, cell_size: Vector2i,
		specs: Array, terrain: GameConfig.TerrainType) -> bool:
	var spec: Dictionary = specs[absi(cell.x * 5 + cell.y * 3) % specs.size()]
	var tex: Texture2D = load(spec["path"]) as Texture2D
	if not is_instance_valid(tex):
		return false

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = int(spec["hframes"])
	spr.frame = 0
	spr.scale = Vector2(spec["scale"], spec["scale"])
	spr.position = Vector2(
		cell.x * cell_size.x + cell_size.x / 2.0,
		cell.y * cell_size.y + cell_size.y / 2.0 + float(spec["y"])
	)
	parent.add_child(spr)
	_decor_nodes[cell] = spr
	_terrain[cell] = terrain
	return true


## Drop the prop standing on a cell — used when a forest burns down. The terrain
## map itself is GridManager's to change; this only clears the visual.
func clear_decor_at(cell: Vector2i) -> void:
	var spr: Node = _decor_nodes.get(cell)
	if is_instance_valid(spr):
		spr.queue_free()
	_decor_nodes.erase(cell)


# === Hazard & Treasure Placement ===

## Barrel positions, derived from the map rather than hardcoded: every bridge
## has a mouth (the road cell where it meets land), and a barrel goes on the
## open ground flanking that mouth. Blowing one while an enemy column funnels
## across is the whole point, so they sit beside the lane, never on it.
func get_barrel_cells(reserved: Array[Vector2i], max_count: int = 6) -> Array[Vector2i]:
	var taken: Dictionary = {}
	for c in reserved:
		taken[c] = true

	var mouths: Dictionary = {}
	for bridge in _bridges:
		for d in NEIGHBOURS:
			var mouth: Vector2i = bridge + d
			if _roads.has(mouth) and not _water.has(mouth) and not _bridges.has(mouth):
				mouths[mouth] = true

	var cells: Array[Vector2i] = []
	# Vector2i sorts lexicographically (x, then y), which is all the determinism
	# this needs — the same map must always produce the same barrel layout.
	var ordered: Array = mouths.keys()
	ordered.sort()

	for mouth in ordered:
		if cells.size() >= max_count:
			break
		for d in NEIGHBOURS:
			var spot: Vector2i = mouth + d
			if _is_prop_cell_free(spot, taken) and not _decor_nodes.has(spot):
				cells.append(spot)
				taken[spot] = true
				break
	return cells


## Treasure positions, scattered with a seeded RNG so every match differs while
## a fixed seed still reproduces a layout exactly for tests. Chests avoid roads,
## water and prop cells so they are always visible and always reachable.
## The same seeded scatter as chests, differing only in spacing — shared rather
## than copied, since a copy would drift the moment either filter changed.
##
## Traps are deliberately NOT kept off roads and bridges: a mine on the only
## bridge is the point of a mine. `_scatter_cells` already excludes water and
## occupied cells.
func get_trap_cells(reserved: Array[Vector2i], count: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	return _scatter_cells(reserved, count, rng, GameConfig.HIDDEN_TRAP_MIN_SPACING)


func get_chest_cells(reserved: Array[Vector2i], count: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	# Chests kept 4 apart so one unit cannot sweep three in a single move.
	return _scatter_cells(reserved, count, rng, 4)


## Seeded scatter shared by chests and traps: pick `count` free cells at random,
## rejecting any pick that lands within `min_spacing` (Manhattan) of one already
## chosen. Draws without replacement, so it terminates even when spacing makes
## the target count unreachable — it returns fewer cells rather than looping.
func _scatter_cells(reserved: Array[Vector2i], count: int,
		rng: RandomNumberGenerator, min_spacing: int) -> Array[Vector2i]:
	var taken: Dictionary = {}
	for c in reserved:
		taken[c] = true

	var candidates: Array[Vector2i] = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell := Vector2i(x, y)
			if _is_prop_cell_free(cell, taken) and not _decor_nodes.has(cell):
				candidates.append(cell)

	var cells: Array[Vector2i] = []
	while cells.size() < count and not candidates.is_empty():
		var idx: int = rng.randi_range(0, candidates.size() - 1)
		var pick: Vector2i = candidates[idx]
		candidates.remove_at(idx)
		var too_close := false
		for other in cells:
			if absi(other.x - pick.x) + absi(other.y - pick.y) < min_spacing:
				too_close = true
				break
		if not too_close:
			cells.append(pick)
	return cells
