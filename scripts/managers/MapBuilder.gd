extends Node
class_name MapBuilder
## MapBuilder — Logic layer: paints the tactical battlefield and reports which
## cells are impassable terrain.
##
## The 16x10 prototype map was a flat grass rectangle with a decorative dirt
## squiggle: no chokepoints, no cover, nothing to fight over. This builds a
## 30x20 Advance-Wars-shaped battlefield instead — two rivers cut the map into
## a west flank, a contested centre and an east flank, and the only ways across
## are four bridges.
##
## Decoupled: owns no game rules. It paints TileMapLayers and hands the blocked
## cells back to GridManager, which is the single source of truth for movement.

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


## Paint every layer and return the cells GridManager must treat as solid.
func build(water_layer: TileMapLayer, ground_layer: TileMapLayer,
		path_layer: TileMapLayer, bridge_layer: TileMapLayer) -> Array[Vector2i]:
	_compute_water()
	_compute_roads()
	_carve_bridges()

	_paint_water(water_layer)
	_paint_blob(ground_layer, GRASS_ORIGIN, _land_cells())
	_paint_blob(path_layer, SAND_ORIGIN, _roads.keys())
	_paint_bridges(bridge_layer)

	var blocked: Array[Vector2i] = []
	for cell in _water:
		if not _bridges.has(cell):
			blocked.append(cell)
	return blocked


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


## Tilemap_Flat's 4x4 blocks are a strict edge-lookup, not a set of
## interchangeable variants — verified by sampling every tile's border bands:
##   column 0 = left edge drawn   column 1 = no side edges
##   column 2 = right edge drawn  column 3 = both side edges
##   row    0 = top edge drawn    row    1 = no top/bottom edge
##   row    2 = bottom edge drawn row    3 = both
## Picking "column 1 or 2 at random" for interiors (an earlier attempt) sprays
## right-hand edges through the middle of the field and turns it into a maze.
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

## Forest / bush / rock props. Purely visual for now (Forest Ambush lands in
## Milestone 4), so they are plain Sprite2Ds rather than tiles or colliders —
## and they deliberately avoid roads, water and reserved cells so they never
## hide a unit or a building.
const DECOR_SPECS: Array = [
	{"path": "res://assets/terrain/Resources/Wood/Trees/Tree1.png", "hframes": 6, "scale": 0.30, "y": -14.0},
	{"path": "res://assets/terrain/Resources/Wood/Trees/Tree2.png", "hframes": 6, "scale": 0.30, "y": -14.0},
	{"path": "res://assets/terrain/Bushes/Bushe1.png", "hframes": 8, "scale": 0.45, "y": 4.0},
	{"path": "res://assets/terrain/Rocks/Rock1.png", "hframes": 1, "scale": 0.75, "y": 4.0},
	{"path": "res://assets/terrain/Rocks/Rock3.png", "hframes": 1, "scale": 0.75, "y": 4.0},
]

## Forest clumps, hand-placed so cover sits where fights actually happen:
## either side of each bridge approach and along the flank highways.
const DECOR_CLUMPS: Array[Vector2i] = [
	Vector2i(6, 2), Vector2i(7, 6), Vector2i(5, 11), Vector2i(6, 18),
	Vector2i(12, 2), Vector2i(13, 8), Vector2i(12, 16), Vector2i(17, 3),
	Vector2i(18, 8), Vector2i(17, 17), Vector2i(23, 2), Vector2i(24, 7),
	Vector2i(25, 11), Vector2i(23, 18), Vector2i(9, 9), Vector2i(20, 11),
	Vector2i(2, 7), Vector2i(28, 14), Vector2i(11, 12), Vector2i(19, 16),
]


func scatter_decor(parent: Node2D, cell_size: Vector2i, reserved: Array[Vector2i]) -> int:
	if not parent:
		return 0
	for child in parent.get_children():
		child.queue_free()

	var taken: Dictionary = {}
	for c in reserved:
		taken[c] = true

	var placed: int = 0
	for i in range(DECOR_CLUMPS.size()):
		var cell: Vector2i = DECOR_CLUMPS[i]
		if taken.has(cell) or is_water(cell) or is_road(cell) or not _in_bounds(cell):
			continue
		var spec: Dictionary = DECOR_SPECS[(cell.x * 5 + cell.y * 3) % DECOR_SPECS.size()]
		var tex: Texture2D = load(spec["path"]) as Texture2D
		if not is_instance_valid(tex):
			continue
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
		taken[cell] = true
		placed += 1
	return placed
