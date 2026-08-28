extends Node2D
class_name MenuBackdrop
## MenuBackdrop — the battlefield, drawn behind the main menu.
##
## The menu used to be a flat dark rectangle. This puts the actual board behind
## it: the same `MapBuilder` the match runs, the same tileset, the same castles
## and mines and villages. Terrain and props, no units, no fog, no HUD.
##
## It is scenery and nothing else. Nothing here reads input, keeps state, or
## talks to a manager — the menu can be opened, left and reopened without any of
## it mattering. Two consequences worth stating, because both are deliberate:
##
##   1. **The buildings leave the `buildings` group on the way in.** They are
##      real `Building` nodes (that is what makes them look right, banners and
##      all) and `Building._ready()` adds every one of them to that group.
##      Income, troop capacity, the victory check and the AI all find their
##      buildings by walking it. A decorative castle in there is a castle the
##      game can count, so they are pulled straight back out.
##   2. **No `GridManager`.** Nothing here pathfinds or occupies a cell, and a
##      grid would only invite something later to treat this as a live board.
##
## The layout is a copy of the one authored in `Match.tscn`, not a reference to
## it — reading it out of the match scene means loading every script that scene
## touches (the controller, the HUD, every manager) to find out where a village
## goes. Drift here is cosmetic: the match rolls its own resource layout at
## start anyway, so these positions are the fallback board, not the real one.

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
