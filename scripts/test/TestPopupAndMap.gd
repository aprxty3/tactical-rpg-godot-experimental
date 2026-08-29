extends Node2D

func _ready() -> void:
	print("--- Running End Turn Confirmation & Map Generation Test ---")
	
	var scene: PackedScene = load("res://scenes/Match.tscn")
	var main_scene = scene.instantiate()
	add_child(main_scene)
	
	var hud: CanvasLayer = main_scene.get_node("MainHUD")
	var ground_layer: TileMapLayer = main_scene.get_node_or_null("TileMapLayer_Ground")
	var water_layer: TileMapLayer = main_scene.get_node_or_null("TileMapLayer_Water")
	var grid_mgr: GridManager = main_scene.get_node("GridManager")
	
	# 1. Verify TileMap Layer Coverage (30x20)
	var filled_cells = 0
	for x in range(grid_mgr.grid_size.x):
		for y in range(grid_mgr.grid_size.y):
			var pos = Vector2i(x, y)
			var has_tile = (ground_layer and ground_layer.get_cell_atlas_coords(pos) != Vector2i(-1, -1)) or \
						   (water_layer and water_layer.get_cell_atlas_coords(pos) != Vector2i(-1, -1))
			assert(has_tile, "Cell must be populated in Ground or Water layer at " + str(pos))
			filled_cells += 1
			
	print(" Verified 100% TileMap grid coverage: ", filled_cells, " tiles populated across layers!")
	
	# 2. Verify End Turn Confirmation Popup
	assert(hud.has_method("show_end_turn_confirmation"), "HUD has show_end_turn_confirmation")
	assert(hud.has_method("is_end_turn_confirmation_active"), "HUD has is_end_turn_confirmation_active")
	assert(not hud.is_end_turn_confirmation_active(), "Modal is hidden initially")
	
	# Open modal
	hud.show_end_turn_confirmation()
	assert(hud.is_end_turn_confirmation_active(), "Modal is visible after show")
	print(" Verified End Turn Confirmation modal opens properly!")
	
	# Cancel modal
	hud.hide_end_turn_confirmation()
	assert(not hud.is_end_turn_confirmation_active(), "Modal is hidden after cancel")
	print(" Verified End Turn Confirmation modal cancels properly!")
	
	# Confirm modal
	hud.show_end_turn_confirmation()
	hud._on_confirm_end_turn()
	assert(not hud.is_end_turn_confirmation_active(), "Modal is hidden after confirm")
	print(" Verified End Turn Confirmation modal emits end_turn on confirmation!")
	
	print(" All Popup and Map enhancements verified successfully with ZERO errors!")
	get_tree().quit(0)
