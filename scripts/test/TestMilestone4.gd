extends Node2D
## TestMilestone4 — integration coverage for the six Milestone 4 systems:
## terrain, morale, surrender, fog of war, environmental hazards and Pandora's
## Box.
##
## Uses soft checks rather than assert(): one broken system should not hide the
## state of the other five, so every check reports and the run ends with a
## single summary line that is easy to read out of the game log.

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

var main: Node2D
var grid: GridManager
var eco: Node
var morale_mgr: MoraleManager
var vision: VisionManager
var objects: MapObjectManager
var units_root: Node2D


func _ready() -> void:
	print("==========================================================")
	print("🎯 [TEST MILESTONE 4] Terrain · Morale · Surrender · Fog · Hazards · Pandora")
	print("==========================================================")

	main = load("res://scenes/TestGridScene.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	grid = main.get_node("GridManager")
	eco = main.get_node("EconomyManager")
	morale_mgr = main.get_node("MoraleManager")
	vision = main.get_node("VisionManager")
	objects = main.get_node("MapObjectManager")
	units_root = main.get_node("Units")

	_test_terrain()
	_test_movement_cost()
	_test_morale()
	await _test_surrender()
	_test_fog_of_war()
	_test_hazards()
	_test_fire_and_scorching()
	_test_pandora()

	_report()


# ==============================================================================
# 1. TERRAIN
# ==============================================================================

func _test_terrain() -> void:
	print("\n--- 1. Terrain ---")

	var forest := _find_cell_of(GameConfig.TerrainType.FOREST)
	var road := _find_cell_of(GameConfig.TerrainType.ROAD)
	var bridge := _find_cell_of(GameConfig.TerrainType.BRIDGE)

	_check(forest != Vector2i(-1, -1), "MapBuilder produced FOREST cells")
	_check(road != Vector2i(-1, -1), "MapBuilder produced ROAD cells")
	_check(bridge != Vector2i(-1, -1), "MapBuilder produced BRIDGE cells")

	if forest != Vector2i(-1, -1):
		_check(grid.get_move_cost(forest) == 2, "Forest costs 2 MP to enter")
		_check(grid.get_damage_taken_mult(forest) < 1.0, "Forest reduces damage taken (cover)")
		_check(grid.is_concealing(forest), "Forest conceals its occupant")
		_check(grid.is_ambush_cover(forest), "Forest is valid ambush cover")

	if road != Vector2i(-1, -1):
		_check(grid.get_move_cost(road) == 1, "Road costs 1 MP")
		_check(grid.get_damage_taken_mult(road) > 1.0, "Road leaves a unit exposed")

	if bridge != Vector2i(-1, -1):
		_check(grid.get_damage_taken_mult(bridge) > 1.0, "Bridge is the most exposed tile")

	# Water must still be impassable after the terrain rewrite.
	var water := _find_cell_of(GameConfig.TerrainType.WATER)
	if water != Vector2i(-1, -1):
		_check(not grid.is_cell_walkable(water), "Water remains impassable")


# ==============================================================================
# 2. MOVEMENT COST
# ==============================================================================

func _test_movement_cost() -> void:
	print("\n--- 2. Movement field ---")

	var unit := _spawn_test_unit("res://resources/units/pawn_blue.tres", GameConfig.Faction.BLUE_KINGDOM, Vector2i(4, 10))
	if unit == null:
		_check(false, "Could not spawn a pawn for movement tests")
		return

	unit.current_movement = 3
	var reachable := grid.get_reachable_cells(unit)
	_check(reachable.size() > 0, "Unit with 3 MP has reachable cells")

	# Every reachable cell must be affordable by the same field that offered it.
	var all_affordable := true
	var worst := 0
	for cell in reachable:
		var path := grid.get_movement_path(unit, cell)
		var cost := grid.get_path_cost(path)
		worst = maxi(worst, cost)
		if path.size() <= 1 or cost > unit.current_movement:
			all_affordable = false
	_check(all_affordable, "Every reachable cell has an affordable path (cost <= %d, worst %d)" % [unit.current_movement, worst])

	# A forest step must actually cost more than a plain step.
	var plain_reach := reachable.size()
	unit.current_movement = 1
	var one_step := grid.get_reachable_cells(unit)
	var forest_in_one_step := false
	for cell in one_step:
		if grid.get_terrain(cell) == GameConfig.TerrainType.FOREST:
			forest_in_one_step = true
	_check(not forest_in_one_step, "1 MP is never enough to enter a 2-cost forest")
	_check(one_step.size() < plain_reach, "1 MP reaches fewer cells than 3 MP (%d < %d)" % [one_step.size(), plain_reach])

	_despawn(unit)


# ==============================================================================
# 3. MORALE
# ==============================================================================

func _test_morale() -> void:
	print("\n--- 3. Morale ---")

	var unit := _spawn_test_unit("res://resources/units/warrior_blue.tres", GameConfig.Faction.BLUE_KINGDOM, Vector2i(5, 5))
	if unit == null:
		_check(false, "Could not spawn a warrior for morale tests")
		return

	_check(unit.get_morale_level() == GameConfig.MoraleLevel.FAIR, "A fresh unit starts FAIR")
	_check(is_equal_approx(unit.get_morale_attack_mult(), 1.0), "FAIR morale is a 1.0 attack multiplier")

	unit.morale = GameConfig.MORALE_DEFAULT
	unit.adjust_morale(-40)
	_check(unit.get_morale_level() == GameConfig.MoraleLevel.FEARFUL, "Heavy losses drive a unit to FEARFUL")
	_check(unit.get_morale_attack_mult() < 1.0, "FEARFUL units hit softer")

	unit.adjust_morale(80)
	_check(unit.get_morale_level() == GameConfig.MoraleLevel.FEARLESS, "Recovering past 90 reaches FEARLESS")
	_check(unit.get_morale_attack_mult() > 1.0, "FEARLESS units hit harder")

	unit.adjust_morale(999)
	_check(unit.morale == GameConfig.MORALE_MAX, "Morale clamps at MORALE_MAX")
	unit.adjust_morale(-999)
	_check(unit.morale == 0, "Morale clamps at 0")

	# Undead are immune.
	var skeleton := _spawn_test_unit("res://resources/units/skeleton_black.tres", GameConfig.Faction.BLACK_COVEN, Vector2i(6, 5))
	if skeleton != null:
		_check(skeleton.is_morale_immune(), "Undead are morale-immune")
		skeleton.adjust_morale(-90)
		_check(skeleton.get_morale_level() == GameConfig.MoraleLevel.FAIR, "Undead morale never shifts")
		_check(is_equal_approx(skeleton.get_morale_attack_mult(), 1.0), "Undead always hit at 1.0")
		_despawn(skeleton)

	_despawn(unit)


# ==============================================================================
# 4. SURRENDER
# ==============================================================================

func _test_surrender() -> void:
	print("\n--- 4. Surrender ---")

	# --- Capture path ---
	var prisoner := _spawn_test_unit("res://resources/units/warrior_red.tres", GameConfig.Faction.RED_LEGION, Vector2i(8, 5))
	if prisoner == null:
		_check(false, "Could not spawn a prisoner")
		return

	morale_mgr.begin_surrender(prisoner, GameConfig.Faction.BLUE_KINGDOM)
	_check(prisoner.pending_surrender, "A broken unit is frozen pending its captor's decision")
	_check(not prisoner.can_act(), "A prisoner cannot act")
	_check(not prisoner.can_move(), "A prisoner cannot move")

	morale_mgr.resolve_surrender(prisoner, "capture")
	await get_tree().process_frame
	_check(prisoner.faction_id == GameConfig.Faction.BLUE_KINGDOM, "Captured unit changes allegiance")
	_check(not prisoner.pending_surrender, "Capture clears the pending flag")
	_check(prisoner.morale == GameConfig.MORALE_AFTER_CAPTURE, "A turncoat arrives shaken")
	_check(
		TurnManager.get_faction_units(GameConfig.Faction.BLUE_KINGDOM).has(prisoner),
		"TurnManager re-buckets a captured unit into its new army",
	)
	_despawn(prisoner)

	# --- Ransom path ---
	var ransomed := _spawn_test_unit("res://resources/units/archer_red.tres", GameConfig.Faction.RED_LEGION, Vector2i(9, 5))
	if ransomed == null:
		return
	var gold_before: int = eco.get_gold(GameConfig.Faction.BLUE_KINGDOM)
	var expected_fee := int(round(ransomed.unit_data.recruit_cost_gold * GameConfig.SURRENDER_RANSOM_RATIO))

	morale_mgr.begin_surrender(ransomed, GameConfig.Faction.BLUE_KINGDOM)
	morale_mgr.resolve_surrender(ransomed, "ransom")
	await get_tree().process_frame

	var gained: int = eco.get_gold(GameConfig.Faction.BLUE_KINGDOM) - gold_before
	_check(gained == expected_fee, "Ransom pays %d gold (got %d)" % [expected_fee, gained])
	_check(not morale_mgr.has_pending_surrender(), "No prisoners left waiting after both resolutions")

	# --- Undead never surrender ---
	var skeleton := _spawn_test_unit("res://resources/units/skeleton_black.tres", GameConfig.Faction.RED_LEGION, Vector2i(10, 5))
	if skeleton != null:
		skeleton.morale = 0
		_check(
			float(GameConfig.SURRENDER_CHANCE.get(skeleton.get_morale_level(), 0.0)) == 0.0,
			"Undead never reach a morale band that can surrender",
		)
		_despawn(skeleton)


# ==============================================================================
# 5. FOG OF WAR
# ==============================================================================

func _test_fog_of_war() -> void:
	print("\n--- 5. Fog of War ---")

	_check(vision.fog_enabled, "Fog is enabled by default")

	var scout := _spawn_test_unit("res://resources/units/warrior_blue.tres", GameConfig.Faction.BLUE_KINGDOM, Vector2i(14, 10))
	if scout == null:
		_check(false, "Could not spawn a scout")
		return
	vision.recompute()

	_check(vision.is_cell_visible(GameConfig.Faction.BLUE_KINGDOM, scout.grid_position), "A unit sees its own cell")
	_check(vision.can_see_unit(GameConfig.Faction.BLUE_KINGDOM, scout), "A faction always sees its own units")

	# Somewhere far away must be dark.
	var far := Vector2i(0, 0)
	if _manhattan(far, scout.grid_position) > 12:
		_check(not vision.is_cell_visible(GameConfig.Faction.BLUE_KINGDOM, far), "Distant cells stay unseen")

	# Concealment: an enemy in forest is hidden at range but spotted from beside.
	var forest := _find_free_cell_of(GameConfig.TerrainType.FOREST)
	if forest != Vector2i(-1, -1):
		var hidden := _spawn_test_unit("res://resources/units/rogue_purple.tres", GameConfig.Faction.RED_LEGION, forest)
		if hidden != null:
			# Move the scout well clear of the forest first.
			var far_cell := forest + Vector2i(6, 0)
			if grid.is_cell_walkable(far_cell):
				grid.register_unit(scout, far_cell)
				vision.recompute()
				_check(
					not vision.can_see_unit(GameConfig.Faction.BLUE_KINGDOM, hidden),
					"An enemy in forest is invisible from a distance",
				)

			var beside := _adjacent_walkable(forest)
			if beside != Vector2i(-1, -1):
				grid.register_unit(scout, beside)
				vision.recompute()
				_check(
					vision.can_see_unit(GameConfig.Faction.BLUE_KINGDOM, hidden),
					"Stepping beside the forest reveals what is hiding in it",
				)
			_despawn(hidden)
	else:
		_check(false, "No free forest cell available to test concealment")

	# Explored memory: once seen, a cell stays explored.
	_check(
		vision.is_cell_explored(GameConfig.Faction.BLUE_KINGDOM, scout.grid_position),
		"Seen cells are remembered as explored",
	)

	_despawn(scout)
	vision.recompute()


# ==============================================================================
# 6. HAZARDS — barrels & chain detonation
# ==============================================================================

func _test_hazards() -> void:
	print("\n--- 6. Barrels & chain detonation ---")

	var origin := _find_open_area(Vector2i(14, 14))
	if origin == Vector2i(-1, -1):
		_check(false, "No open area found for the barrel test")
		return

	var chain_cell := origin + Vector2i(2, 0)
	var victim_cell := origin + Vector2i(1, 0)
	if not grid.is_cell_walkable(chain_cell) or not grid.is_cell_walkable(victim_cell):
		_check(false, "Barrel test area is obstructed")
		return

	var barrel_a := objects.spawn_barrel(origin)
	var barrel_b := objects.spawn_barrel(chain_cell)
	_check(barrel_a != null and barrel_b != null, "Barrels spawn on the map")

	var victim := _spawn_test_unit("res://resources/units/warrior_red.tres", GameConfig.Faction.RED_LEGION, victim_cell)
	if victim == null:
		_check(false, "Could not spawn a blast victim")
		return
	var hp_before: int = victim.current_health

	objects.detonate_at(origin)

	_check(victim.current_health < hp_before, "A unit inside the blast radius takes damage (%d -> %d)" % [hp_before, victim.current_health])
	_check(barrel_a.is_spent(), "The detonated barrel is consumed")
	_check(barrel_b.is_spent(), "A barrel %d tiles away chain-detonates" % GameConfig.BARREL_CHAIN_RADIUS)
	# The cell need not be empty — the blast may well have left a fire burning on
	# it — but no barrel may survive its own detonation.
	var barrel_remains := false
	for obj in objects.objects_at(origin):
		if obj is Barrel:
			barrel_remains = true
	_check(not barrel_remains, "Spent barrels unregister from their cell immediately")

	if is_instance_valid(victim):
		_despawn(victim)


# ==============================================================================
# 7. FIRE — spread, damage, and scorched earth
# ==============================================================================

func _test_fire_and_scorching() -> void:
	print("\n--- 7. Fire & scorched earth ---")

	var forest := _find_free_cell_of(GameConfig.TerrainType.FOREST)
	if forest == Vector2i(-1, -1):
		_check(false, "No free forest cell available to burn")
		return

	var fire := objects.ignite(forest)
	_check(fire != null, "A cell can be set alight")
	_check(objects.has_fire_at(forest), "The manager tracks the burning cell")
	_check(objects.ignite(forest) == null, "A burning cell cannot be ignited twice")

	# Fire burns whoever stands in it.
	var burned := _spawn_test_unit("res://resources/units/warrior_blue.tres", GameConfig.Faction.BLUE_KINGDOM, forest)
	if burned != null:
		var hp_before: int = burned.current_health
		fire.on_unit_entered(burned)
		_check(burned.current_health < hp_before, "Standing in fire hurts (%d -> %d)" % [hp_before, burned.current_health])
		_despawn(burned)

	# Burn it down and confirm the forest is permanently downgraded.
	for i in range(GameConfig.FIRE_LIFETIME_TICKS):
		if is_instance_valid(fire) and not fire.is_spent():
			fire.on_round_tick()

	_check(
		grid.get_terrain(forest) == GameConfig.TerrainType.SCORCHED,
		"A burnt-out forest becomes SCORCHED",
	)
	_check(not grid.is_concealing(forest), "Scorched earth no longer conceals")
	_check(not grid.is_ambush_cover(forest), "Scorched earth is no longer ambush cover")
	_check(grid.get_move_cost(forest) == 1, "Scorched earth is cheap to cross")


# ==============================================================================
# 8. PANDORA'S BOX
# ==============================================================================

var _events_seen: Dictionary = {}
var _event_count: int = 0

func _test_pandora() -> void:
	print("\n--- 8. Pandora's Box ---")

	EventBus.map_event_triggered.connect(_on_map_event)

	var opener := _spawn_test_unit("res://resources/units/pawn_blue.tres", GameConfig.Faction.BLUE_KINGDOM, Vector2i(15, 10))
	if opener == null:
		_check(false, "Could not spawn a chest opener")
		return

	var samples := 60
	for i in range(samples):
		# Top the opener up so a trap roll cannot kill it mid-sample.
		opener.current_health = opener.unit_data.max_health
		var chest := objects.spawn_chest(Vector2i(15, 10))
		if chest != null:
			objects.open_chest(chest, opener)
			chest.consume(0.01)

	_check(_event_count == samples, "Every chest emitted map_event_triggered (%d/%d)" % [_event_count, samples])
	for outcome in ["war_spoils", "mercenary", "trap", "awaken_dead"]:
		_check(_events_seen.has(outcome), "Outcome '%s' occurs across %d samples" % [outcome, samples])

	EventBus.map_event_triggered.disconnect(_on_map_event)
	if is_instance_valid(opener):
		_despawn(opener)


func _on_map_event(event_type: String, _cell: Vector2i, _result: Dictionary) -> void:
	_event_count += 1
	_events_seen[event_type] = true


# ==============================================================================
# HELPERS
# ==============================================================================

func _spawn_test_unit(resource_path: String, faction_id: int, cell: Vector2i) -> TacticalUnit:
	var data: UnitData = load(resource_path) as UnitData
	if not is_instance_valid(data):
		return null
	var prefab: PackedScene = data.unit_scene if is_instance_valid(data.unit_scene) else load("res://scenes/units/TacticalUnit.tscn")
	var unit: TacticalUnit = prefab.instantiate() as TacticalUnit
	unit.unit_data = data
	unit.faction_id = faction_id
	unit.grid_position = cell
	units_root.add_child(unit)
	unit._initialize_from_data()
	grid.register_unit(unit, cell)
	EventBus.unit_spawned.emit(unit, faction_id)
	return unit


## Retire a test unit through the game's own removal path rather than a bare
## queue_free(). Desertion emits unit_deserted, which is what unregisters it
## from the grid, the rosters and the capacity tally — a raw free would leave
## dangling entries behind and poison the checks that follow.
func _despawn(unit: TacticalUnit) -> void:
	if is_instance_valid(unit):
		unit.desert()


func _find_cell_of(terrain: GameConfig.TerrainType) -> Vector2i:
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var cell := Vector2i(x, y)
			if grid.get_terrain(cell) == terrain:
				return cell
	return Vector2i(-1, -1)


## Like _find_cell_of, but skips cells already holding a unit or a map object.
func _find_free_cell_of(terrain: GameConfig.TerrainType) -> Vector2i:
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var cell := Vector2i(x, y)
			if grid.get_terrain(cell) != terrain:
				continue
			if grid.get_unit_at(cell) != null or not objects.objects_at(cell).is_empty():
				continue
			return cell
	return Vector2i(-1, -1)


## A 3x1 run of walkable, empty cells starting at or near `near`.
func _find_open_area(near: Vector2i) -> Vector2i:
	for dx in range(0, 12):
		for dy in range(-4, 5):
			var origin := near + Vector2i(dx, dy)
			var ok := true
			for i in range(3):
				var cell := origin + Vector2i(i, 0)
				if not grid.is_cell_walkable(cell) or not objects.objects_at(cell).is_empty():
					ok = false
					break
			if ok:
				return origin
	return Vector2i(-1, -1)


func _adjacent_walkable(cell: Vector2i) -> Vector2i:
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if grid.is_cell_walkable(cell + dir):
			return cell + dir
	return Vector2i(-1, -1)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  ✅ %s" % message)
	else:
		_failed += 1
		_failures.append(message)
		print("  ❌ %s" % message)


func _report() -> void:
	print("\n==========================================================")
	if _failed == 0:
		print("🎉 MILESTONE 4 — ALL %d CHECKS PASSED" % _passed)
	else:
		print("⚠️  MILESTONE 4 — %d passed, %d FAILED" % [_passed, _failed])
		for failure in _failures:
			print("    ✗ %s" % failure)
	print("==========================================================")
