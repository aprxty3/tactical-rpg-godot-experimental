extends Node2D
class_name MenuBackdrop
## MenuBackdrop — the battlefield, drawn behind the main menu.
##
## The same `MapBuilder`, tileset and buildings the match uses — terrain and
## props only, no units, fog or HUD. Scenery: it reads no input, keeps no state
## and talks to no manager.
##
## Two deliberate consequences:
##   1. **Buildings leave the `buildings` group on the way in.** They are real
##      `Building` nodes, and income, capacity, the victory check and the AI all
##      find buildings by walking that group. A decorative castle in it is a
##      castle the game can count.
##   2. **No `GridManager`.** Nothing pathfinds here, and a grid would invite
##      something later to treat this as a live board.
##
## The layout is a copy of `Match.tscn`'s, not a reference — reading it out
## would load every script that scene touches. Drift is cosmetic: the match
## rolls its own layout at start, so these are the fallback positions.

## World size of one cell, matching `GridManager.cell_size` on the match scene.
const CELL: Vector2i = Vector2i(64, 64)

@onready var map_builder: MapBuilder = $MapBuilder
@onready var decor: Node2D = $Decor
@onready var buildings: Node2D = $Buildings


func _ready() -> void:
	_demote_buildings()
	_build_map()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)


## Take the decorative buildings out of the gameplay group — see the class note.
func _demote_buildings() -> void:
	for bld in buildings.get_children():
		if bld is Building:
			bld.remove_from_group("buildings")


func _build_map() -> void:
	map_builder.grid_size = Vector2i(30, 20)
	map_builder.build(
		$TileMapLayer_Water,
		$TileMapLayer_Ground,
		$TileMapLayer_Path,
		$TileMapLayer_Bridge,
	)

	# Keep the trees off the buildings and their immediate approaches, the same
	# way the match does — a castle with a pine growing out of its gatehouse is
	# the one thing that would make this read as a mistake rather than a map.
	var reserved: Array[Vector2i] = []
	for bld in buildings.get_children():
		if not (bld is Building):
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				reserved.append(bld.grid_position + Vector2i(dx, dy))
	map_builder.scatter_decor(decor, CELL, reserved)


## Scale and centre the board to fill the window.
##
## Covers rather than fits: a letterboxed map would put bars against the menu's
## own background and read as a rendering fault. The overflow is the outer ring
## of the map, which is empty ground on every side.
##
## **Capped at 1:1.** A tall, narrow window needs a cover factor above 1, and
## magnifying this art past its native size does two bad things at once — it
## shimmers, because the scale is not an integer, and it zooms so far in that
## the backdrop stops reading as a map and becomes a field of grass. Past that
## point a thin band of scrim on two edges is the better trade.
const MAX_ZOOM: float = 1.0

func _fit_to_viewport() -> void:
	var world: Vector2 = Vector2(map_builder.grid_size * CELL)
	var view: Vector2 = get_viewport_rect().size
	if world.x <= 0.0 or world.y <= 0.0:
		return
	var factor: float = minf(MAX_ZOOM, maxf(view.x / world.x, view.y / world.y))
	scale = Vector2(factor, factor)
	position = (view - world * factor) * 0.5
