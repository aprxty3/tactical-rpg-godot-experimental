extends Node2D


func _ready() -> void:
	print("==========================================================")
	print(" [TEST UNDEAD GAMEPLAY] TESTING VAMPIRE & SKELETON TREE...")
	print("==========================================================")

	var main_scene_res: PackedScene = load("res://scenes/Match.tscn")
	assert(main_scene_res != null, "Match scene must load successfully")
	var main = main_scene_res.instantiate()
	add_child(main)
	await get_tree().process_frame

	var grid_mgr: GridManager = main.get_node("GridManager")
	var eco_mgr: Node = main.get_node("EconomyManager")
	var units_container: Node2D = main.get_node("Units")
	var buildings_container: Node2D = main.get_node("Buildings")

	# Find Castle Black (neutral / capturable keep)
	var castle_black: Building = null
	for bld in buildings_container.get_children():
		if bld is Building and bld.name == "Castle_Black":
			castle_black = bld
			break
	assert(castle_black != null, "Castle_Black must exist on the map")

	# 1. Blue Kingdom captures Castle Black
	castle_black.faction_id = GameConfig.Faction.BLUE_KINGDOM
	eco_mgr.add_gold(GameConfig.Faction.BLUE_KINGDOM, 500)
	eco_mgr.add_iron(GameConfig.Faction.BLUE_KINGDOM, 10)
	print(" Castle Black captured by Blue Kingdom.")

	# 2. Recruit Skeleton Fodder for Blue Kingdom
	var skel_res: UnitData = load("res://resources/units/skeleton_base_black.tres")
	assert(skel_res != null, "skeleton_base_black.tres must load")
	var skel_spawn_pos := Vector2i(15, 9)
	var skel_unit: TacticalUnit = castle_black.recruit_unit(skel_res, skel_spawn_pos, eco_mgr, units_container)
	assert(skel_unit != null, "Skeleton Fodder must be recruited")
	assert(skel_unit.faction_id == GameConfig.Faction.BLUE_KINGDOM, "Recruited Skeleton faction_id must be Blue Kingdom (0), got %d" % skel_unit.faction_id)
	assert(skel_unit.can_move(), "Skeleton must be able to move")

	# 3. Test Reachable & Attackable Tiles
	var skel_reachable: Array[Vector2i] = grid_mgr.get_reachable_cells(skel_unit)
	var skel_attackable: Array[Vector2i] = grid_mgr.get_attackable_cells(skel_unit.grid_position, skel_unit.unit_data.attack_range_min, skel_unit.unit_data.attack_range_max)
	assert(skel_reachable.size() > 0, "Skeleton must have reachable movement tiles")
	assert(skel_attackable.size() > 0, "Skeleton must have attackable tiles")
	print(" Skeleton Fodder reachable tiles: %d, attackable tiles: %d" % [skel_reachable.size(), skel_attackable.size()])

	# 4. Recruit Vampire for Blue Kingdom
	var vamp_res: UnitData = load("res://resources/units/vampire_black.tres")
	assert(vamp_res != null, "vampire_black.tres must load")
	var vamp_spawn_pos := Vector2i(16, 10)
	var vamp_unit: TacticalUnit = castle_black.recruit_unit(vamp_res, vamp_spawn_pos, eco_mgr, units_container)
	assert(vamp_unit != null, "Vampire must be recruited")
	assert(vamp_unit.faction_id == GameConfig.Faction.BLUE_KINGDOM, "Recruited Vampire faction_id must be Blue Kingdom (0), got %d" % vamp_unit.faction_id)
	assert(vamp_unit.can_move(), "Vampire must be able to move")

	var vamp_reachable: Array[Vector2i] = grid_mgr.get_reachable_cells(vamp_unit)
	var vamp_attackable: Array[Vector2i] = grid_mgr.get_attackable_cells(vamp_unit.grid_position, vamp_unit.unit_data.attack_range_min, vamp_unit.unit_data.attack_range_max)
	assert(vamp_reachable.size() > 0, "Vampire must have reachable movement tiles")
	assert(vamp_attackable.size() > 0, "Vampire must have attackable tiles")
	print(" Vampire reachable tiles: %d, attackable tiles: %d" % [vamp_reachable.size(), vamp_attackable.size()])

	# 5. Test Undead Upgrade Tree: Skeleton -> Skeleton Warrior -> Bone Reaper
	var skel_war_res: UnitData = load("res://resources/units/skeleton_black.tres")
	var upg_ok1: bool = eco_mgr.process_upgrade(GameConfig.Faction.BLUE_KINGDOM, skel_unit, skel_war_res, true)
	assert(upg_ok1, "Upgrade to Skeleton Warrior must succeed")
	assert(skel_unit.faction_id == GameConfig.Faction.BLUE_KINGDOM, "Skeleton Warrior must remain Blue Kingdom")
	assert(grid_mgr.get_reachable_cells(skel_unit).size() > 0, "Skeleton Warrior must have reachable tiles")

	var reaper_res: UnitData = load("res://resources/units/bonereaper_black.tres")
	var upg_ok2: bool = eco_mgr.process_upgrade(GameConfig.Faction.BLUE_KINGDOM, skel_unit, reaper_res, true)
	assert(upg_ok2, "Upgrade to Bone Reaper must succeed")
	assert(skel_unit.faction_id == GameConfig.Faction.BLUE_KINGDOM, "Bone Reaper must remain Blue Kingdom")
	assert(grid_mgr.get_reachable_cells(skel_unit).size() > 0, "Bone Reaper must have reachable tiles")
	print(" Undead Skeleton upgrade chain verified: Skeleton Fodder -> Skeleton Warrior -> Bone Reaper")

	# 6. Test Vampire Upgrade Tree: Vampire -> Vampire Lord
	var vamp_lord_res: UnitData = load("res://resources/units/vampirelord_black.tres")
	var upg_vamp: bool = eco_mgr.process_upgrade(GameConfig.Faction.BLUE_KINGDOM, vamp_unit, vamp_lord_res, true)
	assert(upg_vamp, "Upgrade to Vampire Lord must succeed")
	assert(vamp_unit.faction_id == GameConfig.Faction.BLUE_KINGDOM, "Vampire Lord must remain Blue Kingdom")
	assert(grid_mgr.get_reachable_cells(vamp_unit).size() > 0, "Vampire Lord must have reachable tiles")
	print(" Undead Vampire upgrade chain verified: Vampire -> Vampire Lord")

	print("==========================================================")
	print(" [TEST UNDEAD GAMEPLAY] ALL TESTS PASSED (100%)")
	print("==========================================================")
	get_tree().quit(0)
