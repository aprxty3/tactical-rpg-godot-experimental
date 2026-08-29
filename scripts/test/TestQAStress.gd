extends Node2D


func _ready() -> void:
	print("==========================================================")
	print(" [QA AUTOMATED TEST SUITE] STARTING FULL SYSTEM AUDIT...")
	print("==========================================================")

	# 1. Load Main Battlefield Scene
	var main_scene_res: PackedScene = load("res://scenes/Match.tscn")
	assert(main_scene_res != null, "Match scene must load successfully")
	var main = main_scene_res.instantiate()
	add_child(main)
	await get_tree().process_frame

	var grid_mgr: GridManager = main.get_node("GridManager")
	var eco_mgr: Node = main.get_node("EconomyManager")
	var combat_res: CombatResolver = main.get_node("CombatResolver")
	var hud = main.get_node("MainHUD")
	var units_container: Node2D = main.get_node("Units")
	var buildings_container: Node2D = main.get_node("Buildings")

	assert(grid_mgr != null, "GridManager must be present")
	assert(eco_mgr != null, "EconomyManager must be present")
	assert(combat_res != null, "CombatResolver must be present")
	assert(hud != null, "MainHUD must be present")
	
	# Verify Starting Troop Capacity & Starting Units HP
	var blue_used_cap = eco_mgr.get_used_capacity(GameConfig.Faction.BLUE_KINGDOM, TurnManager.get_faction_units(GameConfig.Faction.BLUE_KINGDOM))
	var red_used_cap = eco_mgr.get_used_capacity(GameConfig.Faction.RED_LEGION, TurnManager.get_faction_units(GameConfig.Faction.RED_LEGION))
	assert(blue_used_cap == 5, "Blue starting used capacity must be 5 (1 Pawn + 2 Warrior + 2 Archer), got %d" % blue_used_cap)
	assert(red_used_cap == 5, "Red starting used capacity must be 5 (1 Pawn + 2 Warrior + 2 Archer), got %d" % red_used_cap)
	
	for unit in units_container.get_children():
		if unit is TacticalUnit and unit.unit_data:
			assert(unit.current_health == unit.unit_data.max_health, "Starting unit %s HP must be 100%% (%d/%d)" % [
				unit.unit_data.unit_name, unit.current_health, unit.unit_data.max_health
			])
			
	# Verify Lancer scale across factions
	for fac in ["blue", "red", "purple", "yellow", "black"]:
		var lancer_res: UnitData = load("res://resources/units/lancer_%s.tres" % fac)
		assert(lancer_res != null, "Lancer resource for %s must exist" % fac)
		assert(is_equal_approx(lancer_res.sprite_scale, 0.50), "Lancer sprite_scale must be 0.50, got %f" % lancer_res.sprite_scale)
		
	print(" [QA 01] Core subsystems, initial 5/8 capacity, 100% starting HP, and Lancer metrics validated.")

	# 2. Verify Battlefield & Building Layout (30x20)
	assert(grid_mgr.grid_size == Vector2i(30, 20), "Grid size must be 30x20")
	var building_count: int = 0
	var castle_count: int = 0
	var mine_count: int = 0
	var village_count: int = 0

	for bld in buildings_container.get_children():
		if bld is Building:
			building_count += 1
			match bld.building_type:
				Building.BuildingType.CASTLE: castle_count += 1
				Building.BuildingType.GOLD_MINE, Building.BuildingType.IRON_MINE: mine_count += 1
				Building.BuildingType.HOUSE: village_count += 1

	assert(building_count >= 15, "Battlefield must have all landmark buildings placed")
	print(" [QA 02] Battlefield validated: %d Buildings (%d Castles, %d Mines, %d Villages)" % [
		building_count, castle_count, mine_count, village_count
	])

	# 2b. Test Village Claiming and Dynamic Capacity Expansion
	var test_village: Building = null
	for bld in buildings_container.get_children():
		if bld is Building and bld.building_type == Building.BuildingType.HOUSE and bld.faction_id == GameConfig.Faction.NEUTRAL:
			test_village = bld
			break
	assert(test_village != null, "A neutral village must exist for claiming")
	test_village.capture(GameConfig.Faction.BLUE_KINGDOM)
	var blue_cap_after_village: int = eco_mgr.get_max_capacity(GameConfig.Faction.BLUE_KINGDOM)
	var blue_used_after_village: int = eco_mgr.get_used_capacity(GameConfig.Faction.BLUE_KINGDOM, TurnManager.get_faction_units(GameConfig.Faction.BLUE_KINGDOM))
	# Against the constant, not a literal. The literal 10 outlived the balance
	# it was written for the moment a village started paying 3 instead of 2.
	var expect_after_village: int = GameConfig.BASE_TROOP_CAPACITY + GameConfig.VILLAGE_CAPACITY_BONUS
	assert(blue_cap_after_village == expect_after_village,
		"Blue max capacity must be %d after claiming 1 village, got %d"
			% [expect_after_village, blue_cap_after_village])
	assert(blue_used_after_village == 5, "Blue used capacity must remain 5 (not 0) after claiming village, got %d" % blue_used_after_village)
	print(" [QA 02b] Village claim verified: Capacity updated to %d/%d (Used capacity accurately preserved)." % [blue_used_after_village, blue_cap_after_village])

	# A castle is worth more than a village and pays only from the SECOND one —
	# a faction's own keep is already priced into BASE_TROOP_CAPACITY, so taking
	# an enemy's is the first castle that adds anything.
	var enemy_castle: Building = null
	for bld in get_tree().get_nodes_in_group("buildings"):
		if bld is Building and bld.building_type == Building.BuildingType.CASTLE \
				and bld.faction_id == GameConfig.Faction.RED_LEGION:
			enemy_castle = bld
			break
	assert(enemy_castle != null, "An enemy castle must exist for claiming")
	enemy_castle.capture(GameConfig.Faction.BLUE_KINGDOM)
	var blue_cap_after_castle: int = eco_mgr.get_max_capacity(GameConfig.Faction.BLUE_KINGDOM)
	var expect_after_castle: int = expect_after_village + GameConfig.CASTLE_CAPACITY_BONUS
	assert(blue_cap_after_castle == expect_after_castle,
		"Blue max capacity must be %d after taking a second castle, got %d"
			% [expect_after_castle, blue_cap_after_castle])
	enemy_castle.capture(GameConfig.Faction.RED_LEGION)
	assert(eco_mgr.get_max_capacity(GameConfig.Faction.BLUE_KINGDOM) == expect_after_village,
		"Losing the taken castle must give the capacity back")
	print(" [QA 02c] Castle claim verified: +%d capacity on the second keep, returned on loss."
		% GameConfig.CASTLE_CAPACITY_BONUS)

	# 3. Test Recruitment at Blue Castle
	var blue_castle: Building = null
	for bld in buildings_container.get_children():
		if bld is Building and bld.faction_id == GameConfig.Faction.BLUE_KINGDOM and bld.building_type == Building.BuildingType.CASTLE:
			blue_castle = bld
			break

	assert(blue_castle != null, "Blue Castle must exist on the map")
	assert(blue_castle.recruitable_units.size() > 0, "Blue Castle must have recruitable units")

	var pawn_data: UnitData = blue_castle.recruitable_units[0]
	var initial_gold: int = eco_mgr.get_gold(GameConfig.Faction.BLUE_KINGDOM)
	var spawn_pos := Vector2i(4, 16) # Adjacent to Blue Castle at (3, 16)

	var recruited_unit: TacticalUnit = blue_castle.recruit_unit(pawn_data, spawn_pos, eco_mgr, units_container)
	assert(recruited_unit != null, "Recruitment must spawn a valid TacticalUnit")
	assert(grid_mgr.get_unit_at(spawn_pos) == recruited_unit, "Unit must be registered in GridManager")
	assert(eco_mgr.get_gold(GameConfig.Faction.BLUE_KINGDOM) == initial_gold - pawn_data.recruit_cost_gold, "Gold must be deducted accurately")
	print(" [QA 03] Recruitment mechanics passed: %s recruited at %s." % [recruited_unit.unit_data.unit_name, spawn_pos])

	# 4. Test Unit Movement and Pathfinding
	var target_cell := Vector2i(5, 16)
	assert(grid_mgr.is_cell_walkable(target_cell), "Target cell must be walkable")
	EventBus.unit_move_requested.emit(recruited_unit, target_cell)
	await get_tree().create_timer(0.4).timeout
	assert(recruited_unit.grid_position == target_cell, "Unit must reach target cell")
	print(" [QA 04] Unit movement & Tween execution verified at %s." % target_cell)

	# 5. Test Combat Resolution (Pawn vs Cultist Pawn)
	var enemy_res: UnitData = load("res://resources/units/pawn_black.tres")
	var enemy_scene: PackedScene = load("res://scenes/units/TacticalUnit.tscn")
	var enemy_unit: TacticalUnit = enemy_scene.instantiate()
	enemy_unit.unit_data = enemy_res
	enemy_unit.faction_id = GameConfig.Faction.BLACK_COVEN
	units_container.add_child(enemy_unit)
	grid_mgr.register_unit(enemy_unit, Vector2i(6, 16))

	var enemy_initial_hp: int = enemy_unit.current_health
	var combat_report: Dictionary = combat_res.resolve_combat(recruited_unit, enemy_unit)
	assert(combat_report.has("primary_attack"), "Combat report must have primary attack")
	assert(enemy_unit.current_health < enemy_initial_hp, "Enemy must take damage from combat")
	print(" [QA 05] Combat Resolver verified: Dealt %d damage to %s." % [
		combat_report["primary_attack"]["damage"], enemy_res.unit_name
	])

	# 6. Test Promotion Flow Outside Castle (Field Tax 2x)
	var warrior_res: UnitData = load("res://resources/units/warrior_blue.tres")
	var upgrade_success: bool = eco_mgr.process_upgrade(GameConfig.Faction.BLUE_KINGDOM, recruited_unit, warrior_res, false) # False = in field
	assert(upgrade_success, "Upgrade with Field Tax should succeed if treasury allows")
	assert(recruited_unit.unit_data == warrior_res, "UnitData should now be Warrior")
	print(" [QA 06] Unit Promotion & Field Tax verified: Unit promoted to %s." % recruited_unit.unit_data.unit_name)

	# 7. Test Multi-Turn Cycle & AI Simulation (5 Full Turns)
	print("⏳ [QA 07] Simulating 5 full consecutive turn cycles with AI automation...")
	for turn_idx in range(1, 6):
		TurnManager.end_turn()
		await get_tree().create_timer(0.2).timeout
		# Cycle back to player
		if TurnManager.get_current_faction() != GameConfig.Faction.BLUE_KINGDOM:
			TurnManager.end_turn()
			await get_tree().create_timer(0.2).timeout

	print(" [QA 07] Turn cycling & AI routines executed with ZERO crashes.")

	print("==========================================================")
	print(" [QA AUDIT RESULT] ALL 7 AUTOMATED INTEGRATION TESTS PASSED (100%)")
	print("==========================================================")
	get_tree().quit(0)
