extends Node2D
## Headless verification for the 30x20 battlefield, terrain blocking, and
## faction ownership visuals. Covers the regressions reported against the
## 16x10 prototype: captured buildings kept the previous owner's colour, and
## nothing on the map was impassable.


func _ready() -> void:
	await get_tree().process_frame
	# Each of these awaits internally, so they must be awaited in turn —
	# otherwise they interleave and the summary prints before they finish.
	await _test_map_shape()
	await _test_terrain_blocking()
	await _test_building_capture_visuals()
	await _test_captured_castle_recruits_owner_units()
	print("\n ALL BATTLEFIELD TESTS PASSED")
	get_tree().quit()


func _test_map_shape() -> void:
	var scene: PackedScene = load("res://scenes/Match.tscn")
	assert(scene != null, "Match.tscn loads")
	var root: Node2D = scene.instantiate()
	add_child(root)
	await get_tree().process_frame

	var grid: GridManager = root.get_node("GridManager")
	assert(grid.grid_size == Vector2i(30, 20), "Battlefield is 30x20, got %s" % grid.grid_size)
	assert(grid.cell_size == Vector2i(64, 64), "Cell size stays 64px")

	var castles := 0
	var mines := 0
	var villages := 0
	for bld in get_tree().get_nodes_in_group("buildings"):
		if bld is Building:
			match bld.building_type:
				Building.BuildingType.CASTLE: castles += 1
				Building.BuildingType.GOLD_MINE, Building.BuildingType.IRON_MINE: mines += 1
				Building.BuildingType.HOUSE: villages += 1
	assert(castles == 5, "Five faction castle slots, got %d" % castles)
	assert(mines >= 6, "At least six resource nodes, got %d" % mines)
	assert(villages >= 6, "At least six villages, got %d" % villages)
	print(" [Map Shape] 30x20 grid, %d castles, %d mines, %d villages" % [castles, mines, villages])

	root.queue_free()
	await get_tree().process_frame


func _test_terrain_blocking() -> void:
	var grid := GridManager.new()
	grid.grid_size = Vector2i(30, 20)
	grid.cell_size = Vector2i(64, 64)
	add_child(grid)
	await get_tree().process_frame

	var builder := MapBuilder.new()
	builder.grid_size = Vector2i(30, 20)
	add_child(builder)

	var blocked: Array[Vector2i] = builder.build(null, null, null, null)
	assert(blocked.size() > 20, "Rivers and ponds must block real cells, got %d" % blocked.size())
	grid.set_terrain_blocked_cells(blocked)

	for cell in blocked:
		assert(not grid.is_cell_walkable(cell), "Water at %s must be impassable" % cell)

	# A bridge sits on a river column but has to stay crossable, otherwise the
	# two flanks are separate islands.
	var bridge_found := false
	for y in range(20):
		var c := Vector2i(10, y)
		if not builder.is_water(c) and builder.is_road(c) and y < 8:
			bridge_found = true
			assert(grid.is_cell_walkable(c), "Bridge at %s must be walkable" % c)
	assert(bridge_found, "At least one bridge crosses the west river")
	print(" [Terrain] %d impassable cells, bridges remain crossable" % blocked.size())

	builder.queue_free()
	grid.queue_free()
	await get_tree().process_frame


func _test_building_capture_visuals() -> void:
	var village: Building = load("res://scenes/buildings/House.tscn").instantiate()
	add_child(village)
	await get_tree().process_frame

	var neutral_tex: Texture2D = village.get_node("Sprite2D").texture
	assert(village.get_node_or_null("FactionBanner") == null, "Neutral buildings fly no banner")

	village.capture(GameConfig.Faction.RED_LEGION)
	var red_tex: Texture2D = village.get_node("Sprite2D").texture
	assert(red_tex != neutral_tex, "Captured village must change texture, not just tint")
	var banner := village.get_node_or_null("FactionBanner")
	assert(banner != null, "Captured building raises a faction banner")

	village.capture(GameConfig.Faction.BLUE_KINGDOM)
	var blue_tex: Texture2D = village.get_node("Sprite2D").texture
	assert(blue_tex != red_tex, "Recapture must swap to the new owner's art")
	print(" [Capture Visuals] neutral -> Red -> Blue each swaps the sprite")

	var castle: Building = load("res://scenes/buildings/Castle_Purple.tscn").instantiate()
	add_child(castle)
	await get_tree().process_frame
	var purple_tex: Texture2D = castle.get_node("Sprite2D").texture
	castle.capture(GameConfig.Faction.BLUE_KINGDOM)
	assert(castle.get_node("Sprite2D").texture != purple_tex,
		"A captured castle must render as the capturing faction's castle")
	print(" [Capture Visuals] Purple castle taken by Blue renders as a Blue castle")

	village.queue_free()
	castle.queue_free()
	await get_tree().process_frame


func _test_captured_castle_recruits_owner_units() -> void:
	var castle: Building = load("res://scenes/buildings/Castle_Yellow.tscn").instantiate()
	add_child(castle)
	await get_tree().process_frame

	var yellow_pawn: UnitData = load("res://resources/units/pawn_yellow.tres")
	assert(castle.resolve_for_owner(yellow_pawn) == yellow_pawn,
		"A Yellow castle still fields Yellow troops")

	castle.capture(GameConfig.Faction.BLUE_KINGDOM)
	var resolved: UnitData = castle.resolve_for_owner(yellow_pawn)
	assert(resolved.resource_path.ends_with("pawn_blue.tres"),
		"Blue must recruit Blue troops from a captured Yellow castle, got %s" % resolved.resource_path)

	# Undead have no per-faction variants; the lookup must fall back, not crash.
	var fodder: UnitData = load("res://resources/units/skeleton_base_black.tres")
	assert(castle.resolve_for_owner(fodder) == fodder,
		"Units without a faction variant fall back to themselves")
	print(" [Captured Recruitment] owner's variant resolved, undead fall back cleanly")

	castle.queue_free()
	await get_tree().process_frame
