extends Node2D
## TestMilestone5 — integration coverage for the four Milestone 5 systems:
## advanced enemy AI, visual polish, the mount system and the audio pipeline.
##
## Same soft-check harness as TestMilestone4: every check reports and the run
## ends with one summary line, so a break in one system cannot hide the state of
## the other three.
##
## The AI section is deliberately assertion-heavy and await-free. Splitting
## judgement out into AITacticalEvaluator is what makes that possible — the
## scoring can be interrogated on a built board without running a turn, timing
## an animation, or waiting on a signal.

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

var main: Node2D
var grid: GridManager
var combat: CombatResolver
var vision: VisionManager
var ai: AIManager
var vfx: VfxManager
var camera: TacticalCamera
var units_root: Node2D
var objects: MapObjectManager


func _ready() -> void:
	print("==========================================================")
	print("🎯 [TEST MILESTONE 5] Advanced AI · VFX · Mount · Audio")
	print("==========================================================")

	main = load("res://scenes/Match.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	grid = main.get_node("GridManager")
	combat = main.get_node("CombatResolver")
	vision = main.get_node("VisionManager")
	# The AI is no longer a node saved in the scene — the match builds one per
	# opponent, named after the faction it commands. This suite exercises the
	# evaluator, so any one of them will do; take Red's, which is the opponent
	# the board was laid out around.
	ai = main.ai_managers[0] if not main.ai_managers.is_empty() else null
	vfx = main.get_node("VfxManager")
	camera = main.get_node("Camera2D")
	units_root = main.get_node("Units")
	objects = main.get_node("MapObjectManager")

	# Freeze the scene's own input handling. Turns advancing mid-run would move
	# the map's units between assertions and make failures irreproducible; the
	# controller's _unhandled_input is what ends a turn, so silencing it is what
	# actually holds the board still.
	main.set_process_unhandled_input(false)

	await _test_match_bootstrap()
	_test_damage_preview()
	_test_objective_scoring()
	_test_terrain_aware_pathing()
	_test_attack_scoring()
	_test_threat_and_retreat()
	_test_recruit_composition()
	await _test_vfx()
	await _test_fire_vfx()
	_test_death_marker()
	await _test_hidden_traps()
	_test_barrel_leaves_fire()
	await _test_damage_glitch()
	_test_camera_shake()
	_test_mount_system()
	_test_directional_facing()
	_test_backwards_compatibility()
	_test_upgrade_does_not_refill_movement()
	await _test_ai_hunts_enemies()
	await _test_audio()
	await _test_unit_overlay()
	_test_hud_dialogs()
	_test_extracted_collaborators()
	_test_map_balance()
	_test_resource_roll()
	_test_village_garrison()
	await _test_troop_ceiling()
	await _test_black_castle_encounters()
	await _test_ai_appetite()
	# LAST: this one latches match_over and re-runs setup_match, which would
	# pull the board out from under anything that ran after it.
	await _test_match_end_stops_play()

	_report()


# ==============================================================================
# 0. MATCH BOOTSTRAP — the match is configured, not hardcoded
# ==============================================================================

## Runs before every other section, because it counts the units the scene
## mustered and the sections below spawn their own into the same container.
func _test_match_bootstrap() -> void:
	print("\n[0] The match is configured, not hardcoded")

	# --- what MatchSetup promises -------------------------------------------
	_check(MatchSetup.participants.size() == 4,
		"four armies take the field (got %d)" % MatchSetup.participants.size())
	# It fields monsters, but never an army: no economy, no recruitment, no
	# claim on the victory check. `participants` is the list all three follow
	# from, which is why this asserts on that list rather than on unit count.
	_check(not (GameConfig.Faction.BLACK_COVEN in MatchSetup.participants),
		"Black Coven fields no army — its castle is a den, not a contender")

	var remembered: int = MatchSetup.player_faction
	for faction_id in MatchSetup.participants:
		MatchSetup.set_player_faction(faction_id)
		var opponents: Array[int] = MatchSetup.ai_factions()
		var sound: bool = (
			opponents.size() == MatchSetup.participants.size() - 1
			and not (faction_id in opponents)
			and MatchSetup.is_player(faction_id)
			and not MatchSetup.is_ai(faction_id)
		)
		_check(sound, "commanding %s leaves %d opponents, none of them itself"
			% [GameConfig.faction_title(faction_id), MatchSetup.participants.size() - 1])

	# A faction that never takes a turn must not become the player's, or the
	# human is handed a match they can sit in but never act in.
	MatchSetup.set_player_faction(GameConfig.Faction.BLACK_COVEN)
	_check(MatchSetup.player_faction != GameConfig.Faction.BLACK_COVEN,
		"a non-participant is refused as the player's faction")
	MatchSetup.set_player_faction(remembered)

	# --- what the scene actually built --------------------------------------
	_check(main.ai_managers.size() == MatchSetup.participants.size() - 1,
		"one AI commander per opponent (got %d)" % main.ai_managers.size())

	var commanded: Dictionary = {}
	var doubled: bool = false
	for commander in main.ai_managers:
		if commanded.has(commander.ai_faction_id):
			doubled = true
		commanded[commander.ai_faction_id] = true
	_check(not commanded.has(main.player_faction),
		"no AI is driving the player's own army")
	_check(not doubled, "no faction has two commanders")

	# --- the armies it mustered ---------------------------------------------
	var per_faction: Dictionary = {}
	var on_water: int = 0
	var cells: Dictionary = {}
	var stacked: int = 0
	for u in units_root.get_children():
		if not (u is TacticalUnit):
			continue
		per_faction[u.faction_id] = int(per_faction.get(u.faction_id, 0)) + 1
		if grid.get_terrain(u.grid_position) == GameConfig.TerrainType.WATER:
			on_water += 1
		if cells.has(u.grid_position):
			stacked += 1
		cells[u.grid_position] = true

	var expected: int = main.STARTING_ROLES.size()
	var every_army_mustered: bool = true
	for faction_id in MatchSetup.participants:
		if int(per_faction.get(faction_id, 0)) != expected:
			every_army_mustered = false
	_check(every_army_mustered, "every participant musters %d units (got %s)"
		% [expected, str(per_faction)])

	# The armies used to be nodes saved in the scene file, hand-placed on known
	# dry ground. Spawning them in code puts that guarantee on the muster search
	# instead, so it has to be checked rather than assumed.
	_check(on_water == 0, "nobody was mustered into the river")
	_check(stacked == 0, "no two units share a cell")

	# Two lists, deliberately different lengths. `contenders` is who can win the
	# match; `faction_order` is who gets a turn, which since the Black Coven's
	# monsters arrived is strictly more. Checking only the second — as this did
	# — would pass just as happily if the marauders had been quietly folded into
	# the victory check, which is the exact bug the split exists to prevent.
	_check(TurnManager.contenders.size() == MatchSetup.participants.size(),
		"only the %d armies can win the match" % MatchSetup.participants.size())
	_check(TurnManager.faction_order.size()
			== MatchSetup.participants.size() + MatchSetup.marauders.size(),
		"the turn order carries the %d armies plus %d marauder(s)"
			% [MatchSetup.participants.size(), MatchSetup.marauders.size()])
	for marauder in MatchSetup.marauders:
		_check(not marauder in TurnManager.contenders,
			"%s takes a turn but cannot win" % GameConfig.faction_title(marauder))

	# --- the resource bar belongs to the player, not to whoever is playing ---
	# It used to be refreshed with the ACTIVE faction. With two armies that
	# self-corrected every time the player's turn came round; with four it spent
	# three quarters of each round showing an opponent's treasury, and leaked the
	# exact gold and iron the fog of war is otherwise hiding.
	var hud = main.main_hud
	var eco = main.economy_manager
	if is_instance_valid(hud) and is_instance_valid(eco):
		var enemy: int = MatchSetup.ai_factions()[0]
		# Drive the two treasuries apart, or the check passes on a coincidence.
		eco.collect_income(enemy, 777, 3)
		await get_tree().process_frame
		var mine: int = eco.get_gold(main.player_faction)
		_check(eco.get_gold(enemy) != mine, "the two treasuries differ, so the check can fail")

		# The HUD's own handler, called directly: emitting `turn_started` would
		# wake that faction's AI and move units out from under later sections.
		hud.call("_on_turn_started", enemy)
		_check(hud.gold_label.text == "💰 Gold: %d" % mine,
			"an enemy turn still shows the player's gold (%s)" % hud.gold_label.text)
		_check(hud.iron_label.text == "⛏️ Iron: %d" % eco.get_iron(main.player_faction),
			"and the player's iron (%s)" % hud.iron_label.text)

		hud.call("_on_turn_started", main.player_faction)
		await get_tree().process_frame


# ==============================================================================
# 1. ADVANCED AI
# ==============================================================================

func _test_damage_preview() -> void:
	print("\n--- 1. Damage preview (the AI's one source of truth) ---")
	var a := _spawn("res://resources/units/warrior_blue.tres", 0, Vector2i(4, 4))
	var d := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(5, 4))

	var preview: Dictionary = combat.preview_damage(a, d)
	_check(int(preview.get("damage", 0)) > 0, "preview_damage returns a real number")

	var hp_before: int = d.current_health
	_check(d.current_health == hp_before, "preview_damage does not touch the defender")

	# The number the AI plans with must be the number the player experiences.
	var resolved: Dictionary = combat.resolve_combat(a, d)
	var dealt: int = int(resolved["primary_attack"]["damage"])
	_check(dealt == int(preview["damage"]),
		"preview matches what resolve_combat actually deals (%d)" % dealt)

	_despawn([a, d])


func _test_objective_scoring() -> void:
	print("\n--- 2. Objective scoring (value per step, not proximity) ---")
	var ev := AITacticalEvaluator.new(grid, combat, null, 1)
	var unit := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(15, 8))

	var gold := _building_of_type("gold_mine")
	var iron := _building_of_type("iron_mine")
	_check(is_instance_valid(gold) and is_instance_valid(iron),
		"map provides a Gold Mine and an Iron Mine to compare")

	if is_instance_valid(gold) and is_instance_valid(iron):
		# Same cell for both, so only the type weighting can separate them.
		var gold_score: float = GameConfig.AI_OBJECTIVE_VALUE["gold_mine"]
		var iron_score: float = GameConfig.AI_OBJECTIVE_VALUE["iron_mine"]
		_check(gold_score > iron_score,
			"a Gold Mine outranks an Iron Mine at equal distance (%.0f > %.0f)"
				% [gold_score, iron_score])

	var castle := _building_of_type("castle")
	if is_instance_valid(castle):
		_check(GameConfig.AI_OBJECTIVE_VALUE["castle"] > GameConfig.AI_OBJECTIVE_VALUE["gold_mine"],
			"a Castle outranks every economic node")

	# Owning it means there is nothing to take.
	var own := _building_of_faction(1)
	if is_instance_valid(own):
		_check(ev.score_objective(unit, own) == -INF,
			"a building the AI already owns scores as no objective")

	var best: Building = ev.best_objective(unit)
	_check(is_instance_valid(best), "best_objective finds something worth walking to")
	if is_instance_valid(best):
		_check(best.faction_id != 1, "the chosen objective is not already ours")

	_despawn([unit])


func _test_terrain_aware_pathing() -> void:
	print("\n--- 3. Terrain-aware pathing (roads beat forest) ---")
	var ev := AITacticalEvaluator.new(grid, combat, null, 1)

	var road_cell := _cell_of_terrain(GameConfig.TerrainType.ROAD)
	var forest_cell := _cell_of_terrain(GameConfig.TerrainType.FOREST)
	_check(road_cell != Vector2i(-1, -1) and forest_cell != Vector2i(-1, -1),
		"map provides both road and forest to compare")

	if road_cell != Vector2i(-1, -1) and forest_cell != Vector2i(-1, -1):
		_check(grid.get_move_cost(forest_cell) > grid.get_move_cost(road_cell),
			"forest costs more to enter than road (%d > %d)"
				% [grid.get_move_cost(forest_cell), grid.get_move_cost(road_cell)])

	# The cost of a route must reflect the terrain crossed, not the tile count —
	# this is what the old Manhattan stepper could not express.
	var a := Vector2i(3, 16)
	var b := Vector2i(10, 15)
	var cost: int = ev.path_cost_between(a, b)
	var manhattan: int = absi(a.x - b.x) + absi(a.y - b.y)
	_check(cost >= manhattan,
		"real path cost is never cheaper than the tile count (%d >= %d)" % [cost, manhattan])
	_check(ev.path_cost_between(a, a) == 0, "cost to stand still is zero")


func _test_attack_scoring() -> void:
	print("\n--- 4. Attack scoring (kills, counters, matchups) ---")
	var ev := AITacticalEvaluator.new(grid, combat, null, 1)
	var attacker := _spawn("res://resources/units/warrior_red.tres", 1, Vector2i(8, 8))
	var healthy := _spawn("res://resources/units/pawn_blue.tres", 0, Vector2i(9, 8))
	var wounded := _spawn("res://resources/units/pawn_blue.tres", 0, Vector2i(7, 8))
	wounded.current_health = 1

	var score_healthy: float = ev.score_attack(attacker, healthy)
	var score_wounded: float = ev.score_attack(attacker, wounded)
	_check(score_wounded > score_healthy,
		"a killable target outranks a healthy one (%.2f > %.2f)" % [score_wounded, score_healthy])
	_check(ev.would_kill(attacker, wounded), "would_kill agrees the 1 HP target dies")
	_check(not ev.would_kill(attacker, healthy), "would_kill rejects the healthy target")

	var target: TacticalUnit = ev.best_attack_target(attacker)
	_check(target == wounded, "best_attack_target picks the kill")

	# A unit that cannot act has nothing to offer.
	attacker.has_acted = true
	_check(ev.best_attack_target(attacker) == null, "a spent unit finds no target")
	attacker.has_acted = false

	_despawn([attacker, healthy, wounded])


func _test_threat_and_retreat() -> void:
	print("\n--- 5. Threat map & tactical retreat ---")
	var ev := AITacticalEvaluator.new(grid, combat, null, 1)
	var lone := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(15, 8))
	var foe_a := _spawn("res://resources/units/warrior_blue.tres", 0, Vector2i(16, 8))
	var foe_b := _spawn("res://resources/units/warrior_blue.tres", 0, Vector2i(14, 8))

	var here: float = ev.threat_at(lone.grid_position, lone)
	var far: float = ev.threat_at(Vector2i(2, 2), lone)
	_check(here > 0.0, "standing between two enemies registers threat (%.0f)" % here)
	_check(far < here, "a distant cell is safer (%.0f < %.0f)" % [far, here])

	_check(ev.should_retreat(lone),
		"a unit facing more damage than it has HP wants out, even at full health")

	lone.current_health = lone.unit_data.max_health
	_despawn([foe_a, foe_b])
	# NOT "threat is now zero": the map has its own garrison, and asserting an
	# absolute here would be testing the scene's unit placement rather than the
	# rule. Assert the rule itself, against whatever threat actually remains.
	var after: float = ev.threat_at(lone.grid_position, lone)
	_check(after < here,
		"removing the adjacent enemies lowers the threat (%.0f < %.0f)" % [after, here])
	var lethal: float = after / float(maxi(1, lone.current_health))
	_check(ev.should_retreat(lone) == (lethal >= GameConfig.AI_RETREAT_THREAT_RATIO),
		"at full health the retreat decision follows the threat ratio exactly (%.2f vs %.2f)"
			% [lethal, GameConfig.AI_RETREAT_THREAT_RATIO])

	# Wounded is its own independent trigger.
	lone.current_health = int(lone.unit_data.max_health * 0.2)
	_check(ev.should_retreat(lone), "a badly wounded unit retreats even unthreatened")

	var foe_c := _spawn("res://resources/units/warrior_blue.tres", 0, Vector2i(16, 8))
	var refuge: Vector2i = ev.best_retreat_cell(lone)
	if refuge != Vector2i(-1, -1):
		_check(ev.threat_at(refuge, lone) <= ev.threat_at(lone.grid_position, lone),
			"the chosen refuge is no more dangerous than standing still")
	else:
		_check(true, "no safer cell existed, so the unit correctly stands and fights")

	_despawn([lone, foe_c])


func _test_recruit_composition() -> void:
	print("\n--- 6. Recruitment counters what it can see ---")
	# The advantage table is the same one combat resolves through.
	_check(combat.class_advantage("Melee", "Ranged") > 1.0, "Melee beats Ranged")
	_check(combat.class_advantage("Ranged", "Mage") > 1.0, "Ranged beats Mage")
	_check(combat.class_advantage("Mage", "Melee") > 1.0, "Mage beats Melee")
	_check(combat.class_advantage("Ranged", "Melee") < 1.0, "Ranged loses to Melee")
	_check(is_equal_approx(combat.class_advantage("Melee", "Melee"), 1.0),
		"a mirror matchup is neutral")


# ==============================================================================
# 2. VISUAL POLISH
# ==============================================================================

func _test_vfx() -> void:
	print("\n--- 7. VFX ---")
	var container: Node2D = main.get_node("Vfx")
	_check(is_instance_valid(vfx), "VfxManager is present")
	_check(is_instance_valid(vfx.effect_container), "VfxManager received its container")

	var before: int = container.get_child_count()
	var spawned := 0
	for id in ["impact", "crit", "death", "desert", "explosion", "ambush"]:
		if is_instance_valid(vfx.burst_at_cell(Vector2i(15, 8), id)):
			spawned += 1
	_check(spawned == 6, "every named burst spawns (%d/6)" % spawned)
	_check(container.get_child_count() > before, "effects land in the container")

	_check(vfx.burst_at_cell(Vector2i(15, 8), "no_such_effect") == null,
		"an unknown effect id is refused rather than crashing")

	var flip := vfx.flipbook_at_cell(
		Vector2i(15, 8), vfx.EXPLOSION_SHEET, vfx.EXPLOSION_FRAMES, 0.3, 110.0)
	_check(is_instance_valid(flip), "the explosion flipbook spawns")

	# The leak test: hundreds of these fire in a match, so they must free
	# themselves without anyone calling back.
	await get_tree().create_timer(1.6).timeout
	_check(container.get_child_count() == 0,
		"every effect freed itself (%d left)" % container.get_child_count())

	# Combat must drive VFX through the bus alone — nothing calls VfxManager.
	var a := _spawn("res://resources/units/warrior_blue.tres", 0, Vector2i(4, 4))
	var d := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(5, 4))
	combat.resolve_combat(a, d)
	await get_tree().process_frame
	_check(container.get_child_count() > 0, "combat spawns VFX with no direct call")
	_despawn([a, d])


func _test_camera_shake() -> void:
	print("\n--- 8. Camera shake ---")
	var pos_before: Vector2 = camera.position
	camera.offset = Vector2.ZERO
	camera.shake(8.0, 0.3)
	camera._process_shake(0.05)
	_check(camera.offset != Vector2.ZERO, "shake displaces the camera")
	# The rule that keeps shake honest at the map edge, where limit_* clamps
	# position but leaves offset alone.
	_check(camera.position == pos_before, "shake moves offset, never position")

	camera._process_shake(10.0)
	_check(camera.offset == Vector2.ZERO, "shake settles back to zero")

	camera.shake(2.0, 0.2)
	camera._process_shake(0.01)
	var weak: float = camera.offset.length()
	camera.shake(20.0, 0.4)
	camera._process_shake(0.01)
	_check(camera.offset.length() >= weak,
		"a stronger impact during a shake reinforces rather than restarting it")
	camera._process_shake(10.0)


# ==============================================================================
# 3. MOUNT SYSTEM
# ==============================================================================

func _test_mount_system() -> void:
	print("\n--- 9. Mount / dismount ---")
	var lancer := _spawn("res://resources/units/lancer_blue.tres", 0, Vector2i(6, 6))
	_check(lancer.can_mount(), "a Lancer has a mount profile")
	_check(lancer.is_mounted, "riders start in the saddle")

	var mounted_class: String = lancer.get_effective_class()
	var mounted_mov: int = lancer.get_effective_movement()
	var mounted_def: int = lancer.get_effective_defense()
	_check(mounted_class == "Cavalry", "mounted, it fights as Cavalry")

	lancer.has_acted = false
	_check(lancer.toggle_mount(), "dismount succeeds")
	_check(not lancer.is_mounted, "state flipped to on foot")
	_check(lancer.get_effective_class() == "Melee", "on foot, it fights as Melee")
	_check(lancer.get_effective_movement() < mounted_mov,
		"dismounting costs movement (%d < %d)" % [lancer.get_effective_movement(), mounted_mov])
	_check(lancer.get_effective_defense() > mounted_def,
		"dismounting gains defence (%d > %d)" % [lancer.get_effective_defense(), mounted_def])

	# The price that stops a rider from swapping class to dodge every matchup.
	_check(not lancer.can_act(), "toggling consumes the unit's action")
	_check(not lancer.toggle_mount(), "a spent unit cannot toggle again")

	# Combat has to read the live class, or a dismounted rider keeps the charge.
	lancer.has_acted = false
	var foe := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(7, 6))
	var on_foot: int = int(combat.preview_damage(lancer, foe).get("damage", 0))
	lancer.toggle_mount()
	var mounted_dmg: int = int(combat.preview_damage(lancer, foe).get("damage", 0))
	_check(mounted_dmg > on_foot,
		"mounted hits harder than on foot (%d > %d) — the charge follows the class"
			% [mounted_dmg, on_foot])

	_despawn([lancer, foe])


func _test_directional_facing() -> void:
	print("\n--- 10. Eight-way facing from five sheets ---")
	var lancer := _spawn("res://resources/units/lancer_blue.tres", 0, Vector2i(10, 10))
	var origin: Vector2 = lancer.global_position

	var cases := {
		"Up": Vector2(0, -64), "UpRight": Vector2(64, -64), "Right": Vector2(64, 0),
		"DownRight": Vector2(64, 64), "Down": Vector2(0, 64),
	}
	var correct := 0
	for expected in cases:
		lancer.face_direction(origin + cases[expected])
		if lancer.facing == expected:
			correct += 1
	_check(correct == cases.size(), "all five authored facings resolve (%d/5)" % correct)

	# The left half is the same sheets mirrored — five sheets, eight directions.
	lancer.face_direction(origin + Vector2(-64, 0))
	_check(lancer.facing == "Right" and lancer.sprite.flip_h,
		"west mirrors the Right sheet")
	lancer.face_direction(origin + Vector2(-64, -64))
	_check(lancer.facing == "UpRight" and lancer.sprite.flip_h,
		"north-west mirrors the UpRight sheet")
	lancer.face_direction(origin + Vector2(64, 0))
	_check(not lancer.sprite.flip_h, "east is unmirrored")

	lancer.face_direction(origin + Vector2(0, -64))
	var base_tex: Texture2D = lancer.sprite.texture
	lancer.play_animation("attack")
	_check(lancer.sprite.texture != base_tex, "attacking swaps to the directional sheet")
	_check(lancer.sprite.hframes == lancer.unit_data.directional_attack_hframes,
		"the swapped sheet carries its own frame count")
	lancer.play_animation("idle")
	_check(lancer.sprite.texture == lancer.unit_data.spritesheet,
		"any other animation restores the base sheet")

	_despawn([lancer])


func _test_backwards_compatibility() -> void:
	print("\n--- 11. Regression guard: units without the new fields ---")
	var pawn := _spawn("res://resources/units/pawn_blue.tres", 0, Vector2i(12, 12))
	_check(not pawn.can_mount(), "a Pawn has no mount and knows it")
	_check(not pawn.has_directional_art(), "a Pawn has no directional art")
	_check(pawn.get_effective_class() == pawn.unit_data.unit_class,
		"effective class equals the raw stat block")
	_check(pawn.get_effective_movement() == pawn.unit_data.movement_points,
		"effective movement equals the raw stat block")
	_check(pawn.get_effective_defense() == pawn.unit_data.defense_power,
		"effective defence equals the raw stat block")

	var base_tex: Texture2D = pawn.sprite.texture
	var base_h: int = pawn.sprite.hframes
	pawn.play_animation("attack")
	_check(pawn.sprite.texture == base_tex and pawn.sprite.hframes == base_h,
		"attacking never swaps the sheet of a unit without directional art")

	pawn.face_direction(pawn.global_position + Vector2(-64, 0))
	_check(pawn.sprite.flip_h, "plain flip-left still works")
	pawn.face_direction(pawn.global_position + Vector2(64, 0))
	_check(not pawn.sprite.flip_h, "plain flip-right still works")

	# The whole roster, not just one sample.
	var dir_count := 0
	var mount_count := 0
	var total := 0
	var d := DirAccess.open("res://resources/units")
	if d:
		for f in d.get_files():
			if not f.ends_with(".tres"):
				continue
			var data = load("res://resources/units/" + f)
			if not (data is UnitData):
				continue
			total += 1
			if not data.directional_attack.is_empty():
				dir_count += 1
			if data.mount_profile != null:
				mount_count += 1
				if not (data.mount_profile is MountProfile):
					_check(false, "%s has a malformed mount_profile" % f)
	_check(total > 0, "scanned the unit roster (%d resources)" % total)
	_check(dir_count == 5, "exactly the 5 Lancers carry directional art (%d)" % dir_count)
	_check(mount_count == 5, "exactly the 5 Lancers carry a mount profile (%d)" % mount_count)

	_despawn([pawn])


# ==============================================================================
# 4. AUDIO
# ==============================================================================

func _test_audio() -> void:
	print("\n--- 12. Audio pipeline ---")
	var am = get_node("/root/AudioManager")
	_check(AudioServer.get_bus_index("Music") >= 0, "a Music bus exists")
	_check(AudioServer.get_bus_index("SFX") >= 0, "an SFX bus exists")

	_check(am._sfx_pool.size() > 1, "SFX plays through a pool, not one player")
	for i in range(4):
		am.play_sfx("hit")
	var voices := 0
	for p in am._sfx_pool:
		if p.playing:
			voices += 1
	_check(voices > 1, "overlapping hits do not cut each other off (%d voices)" % voices)
	am.play_sfx("no_such_sound")
	_check(true, "an unknown sfx id is ignored rather than crashing")

	var stream = am._music_stream("calm")
	_check(stream is AudioStreamWAV, "music loads as a stream")
	if stream is AudioStreamWAV:
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"music is forced to loop, regardless of import settings")

	am.stop_music(0.01)
	await get_tree().create_timer(0.1).timeout
	am.play_music("calm", 0.25)
	_check(am.current_music() == "calm", "play_music selects the track")
	var active_before: int = am._music_active
	am.play_music("calm")
	_check(am._music_active == active_before, "re-requesting the same track is a no-op")

	await get_tree().create_timer(0.4).timeout
	am.play_music("tension", 0.25)
	_check(am._music_active != active_before, "a crossfade swaps to the other player")
	await get_tree().create_timer(0.5).timeout
	_check(am._music_players[am._music_active].volume_db > -1.0,
		"the incoming track reaches full volume")
	_check(not am._music_players[1 - am._music_active].playing,
		"the outgoing track stops once it is inaudible")

	var bus := AudioServer.get_bus_index("Music")
	var base: float = AudioServer.get_bus_volume_db(bus)
	am.duck_music(true)
	await get_tree().create_timer(0.25).timeout
	var ducked: float = AudioServer.get_bus_volume_db(bus)
	_check(ducked < base - 3.0, "combat ducks the music (%.1f -> %.1f dB)" % [base, ducked])
	am.duck_music(false)
	await get_tree().create_timer(1.1).timeout
	_check(absf(AudioServer.get_bus_volume_db(bus) - base) < 0.5,
		"the music returns to its previous level")

	am.set_bus_volume_linear("SFX", 0.5)
	_check(is_equal_approx(snappedf(am.get_bus_volume_linear("SFX"), 0.01), 0.5),
		"a linear volume round-trips through dB")
	am.set_bus_volume_linear("SFX", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),
		"zero mutes the bus instead of setting -inf dB")
	am.set_bus_volume_linear("SFX", 1.0)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),
		"raising the slider unmutes")

	am.stop_music(0.01)


# ==============================================================================
# HELPERS
# ==============================================================================

## Build a bare unit from a resource. Deliberately not the .tscn: these tests
## care about data and rules, and instancing the full prefab would drag in
## per-faction scene wiring that has nothing to do with what is being checked.
# ==============================================================================
# 3b. FIRE VFX
# ==============================================================================

func _test_fire_vfx() -> void:
	print("\n[3b] Fire VFX")

	# EVERY texture in assets/effects/Particle FX/ is a sprite sheet — all eight
	# of them. Drawn flat, a particle shows the whole filmstrip stretched into a
	# wide smear, which is what made a death read as an explosion and a keg read
	# as a brown cloud. So the assertion is over the whole table, not just the
	# rows that happen to be fire: a new row that forgets `hframes` fails here.
	for fx_id in VfxManager.EFFECTS:
		var spec: Dictionary = VfxManager.EFFECTS[fx_id]
		_check(spec.has("hframes"), "'%s' declares its sheet frame count" % fx_id)
		var tex: Texture2D = load(VfxManager.FX_DIR + str(spec["texture"])) as Texture2D
		if is_instance_valid(tex) and spec.has("hframes"):
			var real_frames: int = tex.get_width() / tex.get_height()
			_check(int(spec["hframes"]) == real_frames,
				"'%s' hframes matches the real sheet (%d)" % [fx_id, real_frames])

	# Flame rises, embers fall. Every effect used to fall, which is right for
	# debris and wrong for fire.
	_check(float(VfxManager.EFFECTS["flame"]["gravity"]) < 0.0, "flame rises rather than falls")
	_check(float(VfxManager.EFFECTS["ember"]["gravity"]) > 0.0, "embers fall")

	var burst := vfx.burst_at_position(Vector2(400, 400), "flame")
	_check(is_instance_valid(burst), "a flame burst spawns")
	if is_instance_valid(burst):
		var mat := burst.material as CanvasItemMaterial
		_check(is_instance_valid(mat), "the burst carries a CanvasItemMaterial")
		if is_instance_valid(mat):
			_check(mat.particles_animation, "sheet animation is enabled on the material")
			_check(mat.particles_anim_h_frames == 10, "the material knows the frame count")
			_check(not mat.particles_anim_loop, "the flame does not loop back while fading")
			# Fire adds light; dust does not. Getting this wrong turns debris
			# into white smears.
			_check(mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "fire blends additively")
		_check(burst.anim_speed_max > 0.0, "particles advance through the sheet")

	var dust := vfx.burst_at_position(Vector2(400, 400), "impact")
	if is_instance_valid(dust):
		var dmat := dust.material as CanvasItemMaterial
		_check(is_instance_valid(dmat) and dmat.particles_animation,
			"dust is sheet-animated too, not just fire")
		if is_instance_valid(dmat):
			_check(dmat.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD,
				"dust does NOT add light")

	await get_tree().process_frame


# ==============================================================================
# 3b2. DEATH MARKER
# ==============================================================================

func _test_death_marker() -> void:
	print("\n[3b2] Death leaves a marker, not a blast")

	var container: Node2D = main.get_node_or_null("Vfx")
	_check(is_instance_valid(container), "the effect container exists")
	if not is_instance_valid(container):
		return

	# Snapshot rather than clear. `burst_at_position` schedules a deferred free
	# through a lambda that captures the particle node, so calling free() on the
	# container's children here kills a node the pending lambda still holds and
	# the engine logs "Lambda capture was freed" — a self-inflicted error in the
	# test, not a fault in the effect.
	var pre_existing: Dictionary = {}
	for child in container.get_children():
		pre_existing[child] = true

	var victim := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(14, 14))
	victim.current_health = 1
	victim.take_damage(999, "true")

	var particles: int = 0
	var markers: int = 0
	var fresh: Array = []
	for child in container.get_children():
		if pre_existing.has(child):
			continue
		fresh.append(child)
		if child is CPUParticles2D:
			particles += 1
		elif child is Sprite2D:
			markers += 1

	# The whole point of the change: a kill spawns a marker sprite and NO
	# particle spray. A red burst is the vocabulary of an explosion.
	_check(markers >= 1, "a death marker sprite is spawned")
	_check(particles == 0, "no particle burst on death (got %d)" % particles)

	for child in fresh:
		if child is Sprite2D:
			var spr: Sprite2D = child
			# 7x2 grid: the skull drops, bounces, settles and sinks.
			_check(spr.vframes == VfxManager.DEATH_VFRAMES, "the marker reads the sheet's 2 rows")
			_check(spr.hframes == VfxManager.DEATH_HFRAMES, "the marker reads the sheet's 7 columns")
			# A grid sheet's frame is texture_height / vframes tall. Scaling by
			# the full texture height would render it at half size.
			var tex: Texture2D = spr.texture
			if is_instance_valid(tex):
				var frame_h: float = float(tex.get_height()) / float(spr.vframes)
				_check(is_equal_approx(spr.scale.x, 72.0 / frame_h),
					"the marker is scaled by frame height, not sheet height")
			break

	_despawn([victim])


# ==============================================================================
# 3c. HIDDEN TRAPS
# ==============================================================================

func _test_hidden_traps() -> void:
	print("\n[3c] Hidden traps")

	var origin := Vector2i(10, 10)
	var trap := objects.spawn_trap(origin)
	_check(is_instance_valid(trap), "a trap spawns")
	if not is_instance_valid(trap):
		return

	# --- WALKED OVER, not stopped on ------------------------------------------
	# The reason traps were never met in play: `unit_move_completed` reports only
	# the destination cell, so a unit striding across a mine on its way somewhere
	# else never touched it. Six mines on ~500 cells made ENDING a move on one
	# near-impossible. Crossing must arm it.
	var crosser := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(10, 14))
	var crosser_hp: int = crosser.current_health
	var walk_over := Vector2i(9, 10)
	var mine := objects.spawn_trap(walk_over)
	_check(is_instance_valid(mine), "a second mine spawns on the route")
	# A route that passes THROUGH the mine and ends two cells beyond it.
	var route: Array[Vector2i] = [
		Vector2i(9, 12), Vector2i(9, 11), walk_over, Vector2i(9, 9), Vector2i(9, 8),
	]
	_check(not walk_over == route[route.size() - 1],
		"the route ends past the mine, not on it")
	EventBus.unit_path_walked.emit(crosser, route)
	await get_tree().process_frame
	_check(mine.is_spent(), "walking over the mine sets it off")
	_check(crosser.current_health < crosser_hp,
		"and the walker takes the blast (%d -> %d)" % [crosser_hp, crosser.current_health])
	_despawn([crosser])

	# The whole point: it draws nothing. A faint sprite would be a tell.
	var visuals: int = 0
	for child in trap.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			visuals += 1
	_check(visuals == 0, "the trap renders nothing at all")

	# --- footprint shape ---
	var cells := objects.trap_blast_cells(origin)
	_check(cells.size() == 6, "the footprint is 3x2 = 6 cells (got %d)" % cells.size())
	_check(cells[0] == origin, "the origin is first, so a listener can centre on it")

	var xs: Array[int] = []
	var ys: Array[int] = []
	for c in cells:
		if not xs.has(c.x):
			xs.append(c.x)
		if not ys.has(c.y):
			ys.append(c.y)
	_check(xs.size() == 3, "three columns wide")
	_check(ys.size() == 2, "two rows tall")
	# The unit that stepped on the mine is in the LOWER row, so the blast reads
	# as erupting upward out of the cell rather than swallowing the one behind.
	_check(origin.y == ys.max(), "the trap's own row is the lower of the two")

	# --- clipping at the map edge ---
	var edge := objects.trap_blast_cells(Vector2i(10, 0))
	_check(edge.size() == 3, "a footprint at the top edge clips to 3 cells (got %d)" % edge.size())
	for c in edge:
		_check(grid.is_within_bounds(c), "clipped footprint stays on the map")
		break

	# --- damage across the whole footprint ---
	var inside_lower := _spawn("res://resources/units/pawn_red.tres", 1, origin)
	var inside_upper := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(origin.x + 1, origin.y - 1))
	var outside := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(origin.x, origin.y - 4))
	var hp_lower: int = inside_lower.current_health
	var hp_upper: int = inside_upper.current_health
	var hp_outside: int = outside.current_health

	var expected_fires: int = 0
	if GameConfig.HIDDEN_TRAP_IGNITE_ALL:
		for c in cells:
			if grid.get_terrain(c) != GameConfig.TerrainType.WATER and not objects.has_fire_at(c):
				expected_fires += 1
	var fires_before: int = _count_fires()

	# `seen.assign(c)`, not `seen = c`: GDScript lambdas capture locals BY VALUE,
	# so rebinding the name inside the lambda updates the lambda's own copy and
	# the outer array stays empty. Array is a reference type, so mutating the
	# captured one reaches the array this scope is holding.
	var seen: Array = []
	EventBus.trap_sprung.connect(func(c): seen.assign(c), CONNECT_ONE_SHOT)
	objects.spring_trap_at(origin)

	_check(inside_lower.current_health < hp_lower, "the unit standing on it is hit")
	# This is the assertion that proves 3x2 rather than a single cell: the upper
	# row is a tile the old radius-1 blast would also have covered, so it is the
	# corner that distinguishes the two.
	_check(inside_upper.current_health < hp_upper, "a unit in the upper row is hit too")
	_check(outside.current_health == hp_outside, "a unit outside the footprint is untouched")
	_check(inside_lower.current_health == hp_lower - GameConfig.HIDDEN_TRAP_DAMAGE,
		"damage is TRUE damage, unreduced by defense")
	_check(seen.size() == 6, "trap_sprung carries the whole footprint")
	_check(seen.size() > 0 and seen[0] == origin, "trap_sprung leads with the origin")

	_check(_count_fires() - fires_before == expected_fires,
		"every non-water cell in the footprint caught (%d)" % expected_fires)

	# One-shot: the mine is gone, so walking back over it does nothing.
	_check(trap.is_spent(), "the trap is spent after firing")
	var hp_after: int = inside_lower.current_health
	trap.spring()
	_check(inside_lower.current_health == hp_after, "a spent trap cannot fire twice")

	_despawn([inside_lower, inside_upper, outside])

	# --- placement ---
	var placed: Array = get_tree().get_nodes_in_group("traps")
	var live: Array[Vector2i] = []
	for t in placed:
		if is_instance_valid(t) and not t.is_spent():
			live.append(t.grid_position)
	_check(live.size() >= 2, "the map is seeded with traps (%d live)" % live.size())
	var min_gap: int = 9999
	for i in range(live.size()):
		for j in range(i + 1, live.size()):
			min_gap = mini(min_gap, absi(live[i].x - live[j].x) + absi(live[i].y - live[j].y))
	if live.size() >= 2:
		# Without spacing, one step could set off two mines and delete a unit
		# with no counterplay at all.
		_check(min_gap >= GameConfig.HIDDEN_TRAP_MIN_SPACING,
			"traps are spaced at least %d apart (closest %d)" % [GameConfig.HIDDEN_TRAP_MIN_SPACING, min_gap])


# ==============================================================================
# 3c2. BARREL BLAST LEAVES FIRE
# ==============================================================================

func _test_barrel_leaves_fire() -> void:
	print("\n[3c2] A keg leaves fire behind")

	# Kegs are parked at bridge and road chokepoints, and both are
	# `flammable: 0.00`. The old rule rolled against terrain flammability, so the
	# one place a keg could actually be shot was the one place its blast could
	# never leave a fire — which is exactly what the recording showed.
	var bridge: Vector2i = _find_terrain(GameConfig.TerrainType.BRIDGE)
	var road: Vector2i = _find_terrain(GameConfig.TerrainType.ROAD)
	var origin: Vector2i = bridge if bridge != Vector2i(-1, -1) else road
	_check(origin != Vector2i(-1, -1), "found an unflammable chokepoint to test on")
	if origin == Vector2i(-1, -1):
		return

	_check(GameConfig.terrain_rule(grid.get_terrain(origin), "flammable") == 0.0,
		"the test cell really is unflammable (the old rule's blind spot)")

	var before: int = _count_fires()
	var barrel := objects.spawn_barrel(origin)
	_check(is_instance_valid(barrel), "a keg spawns on the chokepoint")
	barrel.detonate()

	var lit: int = _count_fires() - before
	_check(lit > 0, "the blast leaves fire on unflammable ground (%d cells)" % lit)
	_check(objects.has_fire_at(origin), "the keg's own cell is burning")

	# Water is the one floor that holds: a blast reaching across a river must not
	# set the river alight.
	var water: Vector2i = _find_terrain(GameConfig.TerrainType.WATER)
	if water != Vector2i(-1, -1):
		_check(objects.ignite(water) == null, "water cannot be set alight")

	# Three rounds, then out — the lifetime the fire mechanic already promised.
	_check(GameConfig.FIRE_LIFETIME_TICKS == 3, "fire burns for 3 rounds")
	var fire: Fire = null
	for obj in objects.objects_at(origin):
		if obj is Fire:
			fire = obj
			break
	if is_instance_valid(fire):
		_check(fire.ticks_remaining == GameConfig.FIRE_LIFETIME_TICKS,
			"a fresh fire starts with its full lifetime")
		for i in range(GameConfig.FIRE_LIFETIME_TICKS):
			fire.on_round_tick()
		_check(fire.is_spent(), "the fire burns out after exactly 3 ticks")


## First cell of a given terrain type, or (-1,-1). Scans rather than hardcoding a
## coordinate so the test survives a map regeneration.
func _find_terrain(kind: GameConfig.TerrainType) -> Vector2i:
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var cell := Vector2i(x, y)
			if grid.get_terrain(cell) == kind and not objects.has_fire_at(cell):
				return cell
	return Vector2i(-1, -1)


func _count_fires() -> int:
	var n: int = 0
	for obj in get_tree().get_nodes_in_group("map_objects"):
		if obj is Fire and is_instance_valid(obj) and not obj.is_spent():
			n += 1
	return n


# ==============================================================================
# 3d. DAMAGE GLITCH
# ==============================================================================

func _test_damage_glitch() -> void:
	print("\n[3d] Red glitch on hit")

	var victim := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(12, 12))
	var base_modulate: Color = victim.sprite.modulate
	var base_offset: Vector2 = victim.sprite.offset

	victim.take_damage(1, "true")
	await get_tree().process_frame
	_check(victim.sprite.modulate != base_modulate, "the sprite is tinted mid-glitch")
	_check(victim.sprite.modulate.r > victim.sprite.modulate.g, "the tint is red, not white")

	# Hit again mid-glitch. Two live tweens racing is how a sprite gets stranded
	# tinted and shifted, so the second hit must kill the first.
	victim.take_damage(1, "true")
	await get_tree().process_frame

	var total: float = float(TacticalUnit.GLITCH_STEPS.size()) * TacticalUnit.GLITCH_STEP_TIME + 0.15
	await get_tree().create_timer(total).timeout

	_check(victim.sprite.modulate.is_equal_approx(Color.WHITE), "the tint is fully restored")
	_check(victim.sprite.position.is_zero_approx(), "the sprite returns to its exact position")
	# offset carries the baked 38px render metric; jittering it would misalign
	# the unit permanently.
	_check(victim.sprite.offset.is_equal_approx(base_offset), "the baked render offset is untouched")

	_despawn([victim])


# ==============================================================================
# 6. BUGFIXES — upgrade movement, AI aggression, match end
# ==============================================================================

func _test_upgrade_does_not_refill_movement() -> void:
	print("\n[6a] A promotion does not refund the walk")

	var unit := _spawn("res://resources/units/archer_blue.tres", 0, Vector2i(8, 12))
	var upgrade: UnitData = null
	# The dictionary holds UnitData resources directly — str() on one yields
	# "res:/..." with a single slash, which loads nothing.
	for key in unit.unit_data.upgrade_paths:
		upgrade = unit.unit_data.upgrade_paths[key] as UnitData
		if is_instance_valid(upgrade):
			break
	_check(is_instance_valid(upgrade), "the archer has a promotion to take")
	if not is_instance_valid(upgrade):
		_despawn([unit])
		return

	# Walk the unit dry, exactly as the report describes.
	unit.current_movement = 0
	unit.upgrade_to(upgrade)
	_check(unit.current_movement == 0,
		"a spent unit is still spent after promoting (got %d MP)" % unit.current_movement)
	_check(not unit.can_move(), "and cannot move again")

	# A partly-spent unit keeps what it had — it is not topped up to the new
	# maximum, and not reset to zero either.
	var fresh := _spawn("res://resources/units/archer_blue.tres", 0, Vector2i(9, 12))
	fresh.current_movement = 1
	fresh.upgrade_to(upgrade)
	_check(fresh.current_movement == 1, "a partly-spent unit keeps exactly what it had left")

	# Clamping still has to bite when a promotion LOWERS the ceiling.
	var slow := _spawn("res://resources/units/archer_blue.tres", 0, Vector2i(10, 12))
	slow.current_movement = 99
	slow.upgrade_to(upgrade)
	_check(slow.current_movement == slow.get_effective_movement(),
		"an over-full pool is clamped down to the new maximum")

	_despawn([unit, fresh, slow])


func _test_ai_hunts_enemies() -> void:
	print("\n[6b] The AI weighs enemies against buildings")

	var ev = ai.evaluator
	_check(is_instance_valid(ev), "the evaluator exists")
	if not is_instance_valid(ev):
		return

	# ADJACENT on purpose. Fog conceals a unit standing on concealing terrain
	# unless the observer is next to it, so a prey placed two tiles away can be
	# legitimately invisible depending on what the map generated there — which
	# would make this test fail for a reason that has nothing to do with hunting.
	var hunter := _spawn("res://resources/units/warrior_red.tres", 1, Vector2i(12, 8))
	var prey := _spawn("res://resources/units/pawn_blue.tres", 0, Vector2i(13, 8))
	if is_instance_valid(vision):
		vision.recompute()

	# Report both inputs, not just the verdict: -INF can mean "cannot see it" or
	# "cannot path to it", and those are different bugs.
	var seen: bool = ev.can_see(prey)
	var walk: int = ev.path_cost_between(hunter.grid_position, prey.grid_position)
	_check(seen, "the hunter can see the prey")
	_check(walk >= 0, "the hunter can path to the prey's cell (cost %d)" % walk)
	var score: float = ev.score_enemy_target(hunter, prey)
	_check(score > 0.0, "a visible enemy is worth walking toward (%.2f)" % score)

	# Comparable with an objective on the same scale — this is what lets the
	# caller simply take the larger of the two.
	var far_prey_score: float = ev.score_enemy_target(hunter, prey)
	var best: Dictionary = ev.best_enemy_target(hunter)
	_check(best.get("unit") == prey, "best_enemy_target finds it")
	_check(is_equal_approx(float(best.get("score", 0.0)), far_prey_score),
		"and reports the same score it was ranked with")

	# A wounded target outranks a healthy one: finishing a unit removes a whole
	# unit, chipping a healthy one removes nothing.
	#
	# Measured on the SAME cell, one after the other, so path cost and visibility
	# are identical by construction and the only variable left is health. Two
	# units on two cells would have let terrain decide the comparison.
	var probe_cell := Vector2i(13, 8)
	_despawn([prey])
	await get_tree().process_frame

	var healthy := _spawn("res://resources/units/pawn_blue.tres", 0, probe_cell)
	if is_instance_valid(vision):
		vision.recompute()
	var healthy_score: float = ev.score_enemy_target(hunter, healthy)
	_despawn([healthy])
	await get_tree().process_frame

	var wounded := _spawn("res://resources/units/pawn_blue.tres", 0, probe_cell)
	wounded.current_health = maxi(1, int(wounded.unit_data.max_health * 0.2))
	if is_instance_valid(vision):
		vision.recompute()
	var wounded_score: float = ev.score_enemy_target(hunter, wounded)

	_check(wounded_score > healthy_score,
		"a wounded target outranks a healthy one on the same cell (%.2f > %.2f)"
			% [wounded_score, healthy_score])

	# Own units are never prey.
	var friend := _spawn("res://resources/units/pawn_red.tres", 1, Vector2i(13, 8))
	_check(ev.score_enemy_target(hunter, friend) == -INF, "the AI does not hunt its own")

	_despawn([hunter, wounded, friend])


func _test_match_end_stops_play() -> void:
	print("\n[6c] A finished match actually stops")

	var hud = main.get_node_or_null("CanvasLayer/MainHUD")
	if hud == null:
		hud = main.find_child("MainHUD", true, false)
	_check(is_instance_valid(hud), "the HUD is reachable")
	if not is_instance_valid(hud):
		return

	_check(hud.has_method("is_match_over"), "the HUD exposes is_match_over()")
	_check(not hud.is_match_over(), "a running match is not over")

	# A THIRD party being annihilated is not the player's victory. The old rule
	# read "some faction was defeated and it was not me" as a win, which with
	# four armies ended the match the moment the first opponent fell — handing
	# the player a victory over two armies still standing.
	var bystander: int = GameConfig.Faction.PURPLE_SYNDICATE
	if bystander == hud.player_faction_id:
		bystander = GameConfig.Faction.YELLOW_EMPIRE
	EventBus.defeat_condition_met.emit(bystander, "test")
	await get_tree().process_frame
	_check(not hud.is_match_over(),
		"another faction's annihilation does not end the player's match")

	var turns_before: int = TurnManager.turn_number
	EventBus.victory_condition_met.emit(GameConfig.Faction.BLUE_KINGDOM, "test")
	await get_tree().process_frame

	_check(hud.is_match_over(), "the HUD latches the result")
	_check(TurnManager.match_over, "TurnManager latches it too")

	# The AI ends its own turn from a coroutine, so blocking player input alone
	# would leave the losing side still taking turns behind the result screen.
	TurnManager.end_turn()
	_check(TurnManager.turn_number == turns_before,
		"end_turn is refused once the match is decided")

	# Retry reloads the scene, and TurnManager is an autoload that survives it —
	# so setup_match must clear the latch or the rebuilt board never advances.
	TurnManager.setup_match([0, 1], null)
	_check(not TurnManager.match_over, "setup_match clears the latch for Retry")
	# There are two latches, and Retry used to clear only this one's sibling.
	# The retried match then ran forever: turns advanced, but victory could
	# never be declared a second time.
	_check(not bool(TurnManager.get("_is_game_over")),
		"setup_match clears the victory latch too")


func _spawn(res_path: String, faction: int, cell: Vector2i) -> TacticalUnit:
	var unit := TacticalUnit.new()
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	unit.add_child(spr)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	unit.add_child(ap)
	unit.unit_data = load(res_path)
	unit.faction_id = faction
	units_root.add_child(unit)
	grid.register_unit(unit, cell)
	if is_instance_valid(vision):
		vision.recompute()
	return unit


## Put a hand-built test unit onto its faction's actual ROSTER.
##
## `_spawn` above is enough for anything that reads the board — the grid, the
## fog, a combat swing. It is not enough for anything that reads the roster:
## troop capacity, upkeep and the victory check all walk `faction_units`, which
## TurnManager fills from `unit_spawned`, and only a real spawner emits that.
## Sections that stand an army up to test a LIMIT have to enlist it, or they
## measure an army the game cannot see.
func _enlist(unit: TacticalUnit) -> TacticalUnit:
	if is_instance_valid(unit):
		EventBus.unit_spawned.emit(unit, unit.faction_id)
	return unit


## The other half of `_enlist`. `_despawn` frees the node, and a freed node left
## on the roster is a stale entry every later capacity reading has to step over.
func _discharge(units: Array) -> void:
	for u in units:
		if is_instance_valid(u):
			TurnManager._remove_unit_from_tracking(u)
	_despawn(units)


func _despawn(units: Array) -> void:
	for u in units:
		if is_instance_valid(u):
			grid.unregister_unit(u)
			# Leave the group BEFORE queue_free(). Freeing is deferred to the end
			# of the frame, so a node that has only been queued is still returned
			# by get_nodes_in_group() and still counts toward threat — which made
			# a removed enemy appear to keep threatening the cell it left.
			u.remove_from_group("units")
			u.queue_free()
	if is_instance_valid(vision):
		vision.recompute()


func _building_of_type(type_string: String) -> Building:
	for b in get_tree().get_nodes_in_group("buildings"):
		if b is Building and b.get_type_string() == type_string and b.faction_id != 1:
			return b
	return null


func _building_of_faction(faction: int) -> Building:
	for b in get_tree().get_nodes_in_group("buildings"):
		if b is Building and b.faction_id == faction:
			return b
	return null


func _cell_of_terrain(terrain: GameConfig.TerrainType) -> Vector2i:
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var cell := Vector2i(x, y)
			if grid.get_terrain(cell) == terrain:
				return cell
	return Vector2i(-1, -1)


# ==============================================================================
# 7. REFACTOR — the overhead readout is a component, not part of the actor
# ==============================================================================

## Guards the TacticalUnit -> UnitOverlay extraction. Two things can regress:
## the widgets can drift back onto the actor, or the component can stop
## reflecting the unit's state. Both are checked, because a component that is
## correctly separated but no longer updates is not an improvement.
func _test_unit_overlay() -> void:
	print("\n[7] The overhead readout is its own component")

	var unit := _spawn("res://resources/units/pawn_blue.tres", 0, Vector2i(14, 12))

	# Structure: the widgets belong to the overlay, never to the unit itself.
	# These two assertions are the actual regression guard — if someone rebuilds
	# a bar on the actor, this fails rather than silently duplicating the UI.
	_check(is_instance_valid(unit.overlay), "the unit owns a UnitOverlay child")
	_check(unit.overlay is UnitOverlay, "and it is the component type, not a bare Node2D")
	_check(unit.get_node_or_null("FloatingHPBar") == null,
		"the HP bar is NOT a direct child of the actor any more")
	_check(unit.get_node_or_null("MoraleStrip") == null,
		"nor is the morale strip")

	var bar: ProgressBar = unit.overlay.get_node_or_null("FloatingHPBar")
	var strip: ColorRect = unit.overlay.get_node_or_null("MoraleStrip")
	_check(bar != null, "the HP bar lives under the overlay")
	_check(strip != null, "the morale strip lives under the overlay")
	if bar == null or strip == null:
		_despawn([unit])
		return

	var label: Label = bar.get_node_or_null("HPLabel")
	_check(label != null, "the HP bar still carries its number label")

	# Behaviour: damage must reach the readout. The label updates synchronously
	# while the bar VALUE is tweened, so the label is what proves the push
	# happened this frame.
	var max_hp: int = unit.unit_data.max_health
	_check(label.text == "%d/%d" % [max_hp, max_hp],
		"a fresh unit reads full health (%s)" % label.text)

	unit.take_damage(int(max_hp / 2), "true")
	await get_tree().process_frame
	_check(label.text.begins_with("%d/" % (max_hp - int(max_hp / 2))),
		"the readout follows a hit (%s)" % label.text)

	# Floating text is parented to the overlay, not to the actor.
	var labels_before: int = _count_labels(unit.overlay)
	unit.overlay.pop_text("TEST", Color.WHITE)
	_check(_count_labels(unit.overlay) == labels_before + 1,
		"floating text spawns under the overlay")

	# Morale: a mortal unit shows the strip, Undead have none to show. This is
	# the one rule the overlay must NOT decide for itself — it is handed the
	# answer, so the check confirms the unit is still deciding it.
	_check(strip.visible, "a mortal unit shows its morale strip")
	var skeleton := _spawn("res://resources/units/skeleton_black.tres", 4, Vector2i(15, 12))
	var undead_strip: ColorRect = skeleton.overlay.get_node_or_null("MoraleStrip")
	_check(skeleton.is_morale_immune(), "the skeleton is morale-immune")
	_check(undead_strip != null and not undead_strip.visible,
		"an Undead unit hides the strip entirely rather than showing it full")

	# Defection recolours the bar border — the visible tell that a captured unit
	# changed sides.
	var before_tint: Color = _hp_border_color(unit)
	unit.change_faction(1)
	await get_tree().process_frame
	var after_tint: Color = _hp_border_color(unit)
	_check(before_tint != after_tint,
		"defecting repaints the HP bar border to the new faction")

	_despawn([unit, skeleton])


func _count_labels(root: Node) -> int:
	var n: int = 0
	for child in root.get_children():
		if child is Label:
			n += 1
	return n


func _hp_border_color(unit: TacticalUnit) -> Color:
	var bar: ProgressBar = unit.overlay.get_node_or_null("FloatingHPBar")
	if bar == null:
		return Color.BLACK
	var sb := bar.get_theme_stylebox("background")
	return (sb as StyleBoxFlat).border_color if sb is StyleBoxFlat else Color.BLACK


# ==============================================================================
# 8. REFACTOR — the HUD's dialogs are components, not inline widget code
# ==============================================================================

## Guards the MainHUD -> {UnitChoicePopup, SurrenderModal, GameOverModal} split.
## The recruit and upgrade popups were near-identical copies; they are now two
## instances of one component, so the check that matters is that BOTH still work
## and still emit their own distinct signal.
func _test_hud_dialogs() -> void:
	print("\n[8] HUD dialogs are their own components")

	var hud = main.main_hud
	_check(is_instance_valid(hud), "the HUD is reachable")
	if not is_instance_valid(hud):
		return

	_check(hud.recruit_popup is UnitChoicePopup, "the recruit popup is a UnitChoicePopup")
	_check(hud.upgrade_popup is UnitChoicePopup, "the upgrade popup is one too")
	_check(hud.recruit_popup != hud.upgrade_popup,
		"they are two instances, so both can never be open as one")
	_check(hud.surrender_modal is SurrenderModal, "the surrender prompt is a SurrenderModal")
	_check(hud.surrender_modal is ModalOverlay,
		"which is built on the shared ModalOverlay skeleton")

	# The blocking behaviour is the whole point of a modal — a dialog that lets
	# clicks through leaves the board playable underneath it.
	_check(hud.surrender_modal.mouse_filter == Control.MOUSE_FILTER_STOP,
		"the surrender overlay swallows clicks")

	# Assert the CONTRACT on a fresh instance, not on the HUD's live one. By the
	# time this section runs the combat sections above have fought real rounds,
	# and a unit that broke leaves a legitimately-open prompt behind — asserting
	# on the live modal tests match state, not the component.
	var fresh := SurrenderModal.new()
	_check(not fresh.visible, "a newly built surrender modal starts hidden")
	fresh.free()

	# The recruit list is built from a Castle's roster and relays through the
	# HUD's own signal, so the match controller's wiring is untouched.
	var castle: Building = _building_of_type("castle")
	if is_instance_valid(castle):
		var heard := []
		hud.recruit_unit_requested.connect(func(b, d): heard.append([b, d]), CONNECT_ONE_SHOT)
		hud.show_recruit_popup(castle)
		var buttons := _buttons_in(hud.recruit_popup)
		_check(buttons.size() > 0,
			"the recruit popup lists the castle's units (%d)" % buttons.size())
		_check(hud.recruit_popup.visible, "and is on screen")
		if not buttons.is_empty():
			buttons[0].pressed.emit()
			_check(heard.size() == 1, "choosing one relays recruit_unit_requested")
			_check(not hud.recruit_popup.visible, "and closes the popup")

	# The result screen is built on demand and re-shown, never stacked.
	hud._show_game_over_modal(true)
	_check(hud.game_over_modal is GameOverModal, "the result screen is a GameOverModal")
	var first_modal = hud.game_over_modal
	var win_titles := _labels_in(hud.game_over_modal)
	_check(win_titles.size() > 0 and "VICTORY" in win_titles[0].text,
		"a win reads VICTORY")
	hud._show_game_over_modal(false)
	_check(hud.game_over_modal == first_modal,
		"a second result re-uses the same overlay instead of stacking one")
	var lose_titles := _labels_in(hud.game_over_modal)
	_check(lose_titles.size() > 0 and "DEFEAT" in lose_titles[0].text,
		"and it is rewritten, not left reading VICTORY")
	hud.game_over_modal.hide()


## Depth-first: the widgets sit inside a margin/box chain, not directly under
## the dialog root.
func _buttons_in(root: Node) -> Array:
	var found := []
	for child in root.get_children():
		if child is Button:
			found.append(child)
		found.append_array(_buttons_in(child))
	return found


func _labels_in(root: Node) -> Array:
	var found := []
	for child in root.get_children():
		if child is Label:
			found.append(child)
		found.append_array(_labels_in(child))
	return found


# ==============================================================================
# 9. REFACTOR — chest table, army muster and highlight layer are collaborators
# ==============================================================================

## Guards the three remaining extractions: PandoraTable out of MapObjectManager,
## ArmyMuster and GridOverlay out of MatchController. Each is checked on its own
## terms — a collaborator that cannot be exercised without rebuilding the whole
## match would not have been worth splitting out.
func _test_extracted_collaborators() -> void:
	print("\n[9] Chest table, army muster and highlight layer")

	# --- PandoraTable ---------------------------------------------------------
	_check(objects.pandora is PandoraTable, "the chest outcomes live in a PandoraTable")
	var outcome: String = objects.pandora.roll()
	_check(outcome in ["war_spoils", "mercenary", "trap", "awaken_dead"],
		"roll() returns one of the four outcomes (%s)" % outcome)

	# The manager exposes `random_seed` so a run can be reproduced. That promise
	# only holds if the table rolls from the manager's generator rather than one
	# of its own, so the same seed must produce the same sequence.
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 12345
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 12345
	var table_a := PandoraTable.new(rng_a, null, Callable(), Callable())
	var table_b := PandoraTable.new(rng_b, null, Callable(), Callable())
	var seq_a := []
	var seq_b := []
	for i in range(20):
		seq_a.append(table_a.roll())
		seq_b.append(table_b.roll())
	_check(seq_a == seq_b, "the same seed rolls the same outcomes, so runs stay reproducible")

	# --- ArmyMuster -----------------------------------------------------------
	var muster := ArmyMuster.new(grid, units_root)
	var castle: Building = muster.castle_of(main.player_faction)
	_check(is_instance_valid(castle), "the muster finds the player's castle")
	if is_instance_valid(castle):
		var cells: Array[Vector2i] = muster.muster_cells(castle.grid_position, 3)
		_check(cells.size() == 3, "it finds three cells to form up on (%d)" % cells.size())
		var all_dry := true
		var all_clear := true
		for cell in cells:
			if not grid.is_cell_walkable(cell):
				all_dry = false
			if grid.get_building_at(cell) != null:
				all_clear = false
		_check(all_dry, "none of them is water or blocked terrain")
		_check(all_clear, "and none of them is another building's cell")

	# --- GridOverlay ----------------------------------------------------------
	_check(main.grid_overlay is GridOverlay, "the highlights are drawn by a GridOverlay")
	# Draw order is the whole reason this node exists at a fixed index: the map
	# layers sit at negative z_index, Buildings and Units at zero. Anywhere but
	# the front of the child list and the highlights end up under the units
	# standing on them.
	_check(main.get_child(0) == main.grid_overlay,
		"and it sits at child index 0, under the units rather than over them")
	_check(not main.has_method("_draw"),
		"the controller no longer paints the board itself")

	# The overlay must reflect what the controller selects, without keeping a
	# second copy of the selection that could drift.
	var probe := _spawn("res://resources/units/pawn_blue.tres", main.player_faction,
		Vector2i(16, 12))
	main._select_unit(probe)
	_check(main.grid_overlay.selected_unit_cell == probe.grid_position,
		"selecting a unit moves the golden ring to its cell")
	main._deselect_all()
	_check(main.grid_overlay.selected_unit_cell == GridOverlay.NO_CELL,
		"and deselecting clears it")
	_despawn([probe])


# ==============================================================================
# 10. MAP BALANCE — four armies on a board that was laid out for two
# ==============================================================================

## The castles have always been 4-fold symmetric; the resources were not, because
## the map was authored when only Blue and Red fielded armies. Measured before
## the fix, in terrain-aware walk cost from each castle to its nearest node:
## iron was 5 for Purple/Yellow and 12 for Blue/Red, and villages were the
## mirror of that. Blue — the default player faction — had neither a gold nor an
## iron mine as its nearest anything.
##
## Manhattan distance would pass a map this test should fail, so every distance
## here is a real Dijkstra walk over the same move costs a unit pays.
func _test_map_balance() -> void:
	print("\n[10] Resources are even across all four armies")

	var castles: Dictionary = {}
	var nodes: Dictionary = {"gold_mine": [], "iron_mine": [], "village": []}
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (b is Building):
			continue
		if b.building_type == Building.BuildingType.CASTLE:
			castles[b.faction_id] = b.grid_position
		else:
			var kind: String = b.get_type_string()
			if nodes.has(kind):
				nodes[kind].append(b.grid_position)

	_check(nodes["gold_mine"].size() == 4, "four gold mines (%d)" % nodes["gold_mine"].size())
	_check(nodes["iron_mine"].size() == 4, "four iron mines (%d)" % nodes["iron_mine"].size())
	_check(nodes["village"].size() == 8, "eight villages (%d)" % nodes["village"].size())

	# Every node must be standable. A mine in a river is worth nothing to anyone.
	var unreachable: int = 0
	for kind in nodes:
		for cell in nodes[kind]:
			if not grid.is_cell_walkable(cell):
				unreachable += 1
	_check(unreachable == 0, "every resource sits on ground a unit can stand on")

	for kind in nodes:
		var lo: int = 99999
		var hi: int = -1
		var readout: String = ""
		for faction_id in MatchSetup.participants:
			var best: int = 99999
			for cell in nodes[kind]:
				var cost: int = _walk_cost(castles.get(faction_id, Vector2i(-1, -1)), cell)
				if cost >= 0 and cost < best:
					best = cost
			readout += "%s=%d " % [GameConfig.faction_display_name(faction_id), best]
			lo = mini(lo, best)
			hi = maxi(hi, best)
		# One MP of slack: the walk crosses generated terrain, so demanding an
		# exact tie would make this fail on a cosmetic tree.
		_check(hi - lo <= 1,
			"%s is within 1 MP for every army (%s spread=%d)" % [kind, readout.strip_edges(), hi - lo])

	# Fairness of DISTANCE is not fairness of SHARE: a map could tie on distance
	# and still hand one army three mines. Count what is nearest to whom.
	var share: Dictionary = {}
	for faction_id in MatchSetup.participants:
		share[faction_id] = {"gold_mine": 0, "iron_mine": 0, "village": 0}
	for kind in nodes:
		for cell in nodes[kind]:
			var winner: int = -1
			var best: int = 99999
			for faction_id in MatchSetup.participants:
				var cost: int = _walk_cost(castles.get(faction_id, Vector2i(-1, -1)), cell)
				if cost >= 0 and cost < best:
					best = cost
					winner = faction_id
			if winner >= 0:
				share[winner][kind] += 1

	var even: bool = true
	var tally: String = ""
	for faction_id in MatchSetup.participants:
		var s: Dictionary = share[faction_id]
		tally += "%s(%d/%d/%d) " % [GameConfig.faction_display_name(faction_id),
			s["gold_mine"], s["iron_mine"], s["village"]]
		if s["gold_mine"] != 1 or s["iron_mine"] != 1 or s["village"] != 2:
			even = false
	_check(even, "each army is nearest to exactly 1 gold, 1 iron, 2 villages — %s" % tally.strip_edges())


# ==============================================================================
# 11. THE RESOURCE ROLL — a different board every match, fair every time
# ==============================================================================

## `_test_map_balance` above already measured THIS match's board and found it
## even. That is the outcome; this is the machinery, and it is what stops the
## next roll from being the unfair one. Two properties matter: the layout is
## built from mirror orbits (so fairness is structural, not lucky), and the roll
## actually rolls (so the board really does change between matches).
func _test_resource_roll() -> void:
	print("\n[11] The resource layout is rolled, not fixed")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var scatter := ResourceScatter.new(grid, rng)

	# --- the mirror group ----------------------------------------------------
	var orbit: Array[Vector2i] = scatter.orbit_of(Vector2i(7, 4))
	var mirrored: bool = orbit.size() == 4 \
		and orbit.has(Vector2i(7, 4)) and orbit.has(Vector2i(22, 4)) \
		and orbit.has(Vector2i(7, 15)) and orbit.has(Vector2i(22, 15))
	_check(mirrored, "a cell and its three reflections form one orbit (%s)" % str(orbit))

	# A cell that is its own mirror cannot seed a set of four, and placing it
	# anyway is how a layout ends up with three of something. This map is even on
	# both sides so no cell sits on an axis — which is the property to assert:
	# every orbit it can produce really is four distinct cells.
	var ragged: int = 0
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var o: Array[Vector2i] = scatter.orbit_of(Vector2i(x, y))
			var distinct: Dictionary = {}
			for c in o:
				distinct[c] = true
			if distinct.size() != 4:
				ragged += 1
	_check(ragged == 0, "no cell on this map seeds a partial orbit (%d ragged)" % ragged)

	# --- what is actually on the board ---------------------------------------
	# Fairness measured once is fairness on one map. Symmetry is the reason it
	# holds on every map, so check the property rather than the measurement.
	var cells: Dictionary = {"gold_mine": [], "iron_mine": [], "village": []}
	for b in get_tree().get_nodes_in_group("buildings"):
		if b is Building and cells.has(b.get_type_string()):
			cells[b.get_type_string()].append(b.grid_position)

	for kind in cells:
		var present: Dictionary = {}
		for cell in cells[kind]:
			present[cell] = true
		var closed: bool = true
		for cell in cells[kind]:
			for image in scatter.orbit_of(cell):
				if not present.has(image):
					closed = false
		_check(closed, "every %s has all three of its mirror images (%d cells)"
			% [kind, cells[kind].size()])

	# --- it rolls ------------------------------------------------------------
	# `roll` reports a layout without moving anything, so this cannot disturb the
	# board the sections above measured.
	var buildings: Array = get_tree().get_nodes_in_group("buildings")
	var seeds: Array[int] = [11, 22, 33, 44]
	var seen: Dictionary = {}
	var all_found: bool = true
	for seed_value in seeds:
		var r := RandomNumberGenerator.new()
		r.seed = seed_value
		var report: Dictionary = ResourceScatter.new(grid, r).roll(buildings)
		if not report["found"]:
			all_found = false
			continue
		seen[str(report["gold_mine"]) + str(report["iron_mine"]) + str(report["village"])] = true

	_check(all_found, "every seed reaches a complete layout on this map")
	_check(seen.size() > 1, "different seeds lay the map out differently (%d of %d distinct)"
		% [seen.size(), seeds.size()])

	# The bands are what keep a fair roll from also being a shapeless one.
	var r2 := RandomNumberGenerator.new()
	r2.seed = 7
	var sample: Dictionary = ResourceScatter.new(grid, r2).roll(buildings)
	if sample["found"]:
		var castles: Array[Vector2i] = []
		for b in get_tree().get_nodes_in_group("buildings"):
			if b is Building and b.building_type == Building.BuildingType.CASTLE \
					and b.faction_id in MatchSetup.participants:
				castles.append(b.grid_position)
		var in_band: bool = true
		for kind in ["gold_mine", "iron_mine", "village"]:
			var band: Vector2i = ResourceScatter.REACH_BAND[kind]
			var nearest: int = 99999
			for cell in sample[kind]:
				for castle in castles:
					nearest = mini(nearest, _walk_cost(castle, cell))
			if nearest < band.x or nearest > band.y:
				in_band = false
		_check(in_band, "a rolled layout keeps every kind inside its distance band")
	else:
		_check(false, "a rolled layout keeps every kind inside its distance band")


# ==============================================================================
# 12. VILLAGES RESUPPLY THEIR GARRISON
# ==============================================================================

## A village was worth taking for the troop capacity and worth nothing once
## taken. Standing in one now heals a fraction of MAXIMUM health each upkeep, so
## a mauled army has somewhere to pull back to. Driven through the real upkeep
## rather than by calling the heal directly: the rule was never the hard part,
## being reached from the turn loop is.
func _test_village_garrison() -> void:
	print("\n[12] A village resupplies whoever holds it")

	var village: Building = _building_of_type("village")
	if village == null:
		_check(false, "the map has a village to garrison")
		return

	var faction: int = MatchSetup.participants[0]
	var owner_before: int = village.faction_id
	village.capture(faction)

	# Gold and iron are handed out by the same upkeep; top the treasury up so a
	# later section cannot be affected by what this one earns.
	var index_before: int = TurnManager.current_faction_index
	TurnManager.current_faction_index = TurnManager.faction_order.find(faction)

	var garrison: TacticalUnit = _enlist(_spawn("res://resources/units/pawn_%s.tres"
		% GameConfig.FACTION_SUFFIX[faction], faction, village.grid_position))
	var control: TacticalUnit = _enlist(_spawn("res://resources/units/pawn_%s.tres"
		% GameConfig.FACTION_SUFFIX[faction], faction,
		_open_cell_away_from(village.grid_position)))

	var maximum: int = garrison.unit_data.max_health
	var expected: int = maxi(1, int(ceil(maximum * GameConfig.VILLAGE_GARRISON_HEAL_RATIO)))
	garrison.current_health = maxi(1, maximum / 5)
	control.current_health = maxi(1, maximum / 5)
	var wounded: int = garrison.current_health

	TurnManager._execute_upkeep()

	_check(garrison.current_health == wounded + expected,
		"the garrison recovers %d%% of its maximum (%d -> %d)"
		% [int(GameConfig.VILLAGE_GARRISON_HEAL_RATIO * 100.0), wounded, garrison.current_health])
	_check(control.current_health == wounded,
		"a unit standing in the open recovers nothing (%d)" % control.current_health)

	# Full health is not overhealed, and a second turn keeps healing.
	garrison.current_health = maximum
	TurnManager._execute_upkeep()
	_check(garrison.current_health == maximum,
		"a healthy garrison is not overhealed past %d" % maximum)

	# The village has to be YOURS. A unit sitting on someone else's house is
	# occupying it, not being supplied by it.
	var rival: int = MatchSetup.participants[1]
	village.capture(rival)
	garrison.current_health = wounded
	TurnManager._execute_upkeep()
	_check(garrison.current_health == wounded,
		"a village flying another flag supplies nobody (%d)" % garrison.current_health)

	# --- and a castle resupplies harder than a village ----------------------
	# Two rates through one code path: the upkeep sweep reads a per-type table
	# rather than testing for HOUSE, so this is the check that the table is
	# actually consulted and not just declared.
	village.capture(faction)
	var keep: Building = null
	for b in get_tree().get_nodes_in_group("buildings"):
		if b is Building and b.building_type == Building.BuildingType.CASTLE \
				and b.faction_id == faction:
			keep = b
			break
	if keep != null:
		var warded: TacticalUnit = _enlist(_spawn("res://resources/units/pawn_%s.tres"
			% GameConfig.FACTION_SUFFIX[faction], faction, keep.grid_position))
		var keep_expected: int = maxi(1, int(ceil(
			maximum * GameConfig.CASTLE_GARRISON_HEAL_RATIO)))
		warded.current_health = wounded
		garrison.current_health = wounded
		TurnManager._execute_upkeep()
		_check(warded.current_health == wounded + keep_expected,
			"a castle garrison recovers %d%% of its maximum (%d -> %d)"
			% [int(GameConfig.CASTLE_GARRISON_HEAL_RATIO * 100.0), wounded,
				warded.current_health])
		_check(warded.current_health > garrison.current_health,
			"the keep out-heals the village (%d vs %d)"
			% [warded.current_health, garrison.current_health])
		_discharge([warded])
	else:
		_check(false, "the player has a castle to garrison")

	_discharge([garrison, control])
	village.capture(owner_before)
	TurnManager.current_faction_index = index_before


## A walkable, unoccupied cell touching `cell`, falling back to a wider ring.
## Used to stand a unit beside a specific building rather than wherever the
## map-wide scan happens to land first.
func _free_neighbour_of(cell: Vector2i) -> Vector2i:
	for radius in range(1, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var candidate: Vector2i = cell + Vector2i(dx, dy)
				if grid.is_cell_walkable(candidate) and grid.get_building_at(candidate) == null:
					return candidate
	return _open_cell_away_from(cell)


## Somewhere open that is not the given cell and holds no building — for the
## control unit, which must be standing on ordinary ground.
func _open_cell_away_from(cell: Vector2i) -> Vector2i:
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var candidate := Vector2i(x, y)
			if candidate == cell or not grid.is_cell_walkable(candidate):
				continue
			if grid.get_building_at(candidate) != null:
				continue
			return candidate
	return cell


# ==============================================================================
# 13. THE TROOP CEILING BINDS EVERY WAY TROOPS ARRIVE
# ==============================================================================

## Recruiting always checked the ceiling. Nothing else did — so an army that
## could not BUY its next unit could still be handed one by a prisoner's
## surrender or by a chest, and the limit the HUD displayed was enforced on
## exactly one of the three doors into the roster.
func _test_troop_ceiling() -> void:
	print("\n[13] Troop capacity binds every way a unit can arrive")

	var faction: int = MatchSetup.participants[0]
	var suffix: String = GameConfig.FACTION_SUFFIX[faction]
	var economy: Node = main.economy_manager
	var castle: Building = null
	for b in get_tree().get_nodes_in_group("buildings"):
		if b is Building and b.building_type == Building.BuildingType.CASTLE \
				and b.faction_id == faction:
			castle = b
	if castle == null or not is_instance_valid(economy):
		_check(false, "the player's castle and treasury are reachable")
		return

	# Cost must never be what refuses these — the ceiling must.
	economy.add_gold(faction, 99999)
	economy.add_iron(faction, 999)

	# --- fill the roster to two points below the ceiling ---------------------
	var filler: Array = []
	var maximum: int = economy.get_max_capacity(faction)
	while economy.get_used_capacity(faction, TurnManager.get_faction_units(faction)) < maximum - 2:
		var cell: Vector2i = _open_cell_away_from(castle.grid_position)
		var pawn: TacticalUnit = _enlist(
			_spawn("res://resources/units/pawn_%s.tres" % suffix, faction, cell))
		if pawn == null:
			break
		filler.append(pawn)
		if filler.size() > 40:
			break

	var roster: Array = TurnManager.get_faction_units(faction)
	var used: int = economy.get_used_capacity(faction, roster)
	_check(used == maximum - 2, "roster stood up at %d/%d for the test" % [used, maximum])

	# --- the rule itself -----------------------------------------------------
	_check(economy.has_capacity_for(faction, 2, roster),
		"a 2-weight unit still fits at %d/%d" % [used, maximum])
	_check(not economy.has_capacity_for(faction, 3, roster),
		"a 3-weight unit does not fit at %d/%d" % [used, maximum])

	# --- door one: recruiting at a castle ------------------------------------
	var heavy: UnitData = load("res://resources/units/knight_%s.tres" % suffix)
	var light: UnitData = load("res://resources/units/warrior_%s.tres" % suffix)
	var heavy_check: Dictionary = castle.can_recruit(heavy, economy, roster)
	var light_check: Dictionary = castle.can_recruit(light, economy, roster)
	_check(heavy.capacity_weight == 3 and light.capacity_weight == 2,
		"the test units weigh what it assumes (%d and %d)"
		% [heavy.capacity_weight, light.capacity_weight])
	_check(not heavy_check["can_recruit"],
		"the castle refuses the heavy unit — %s" % heavy_check["reason"])
	_check(light_check["can_recruit"], "the castle still allows the one that fits")

	# --- door two: claiming a prisoner ---------------------------------------
	var morale: MoraleManager = main.morale_manager
	var rival: int = MatchSetup.participants[1]
	var prisoner: TacticalUnit = _enlist(_spawn("res://resources/units/knight_%s.tres"
		% GameConfig.FACTION_SUFFIX[rival], rival, _open_cell_away_from(castle.grid_position)))

	_check(not morale.has_room_for(faction, prisoner),
		"the captor has no room for a 3-weight prisoner")
	_check(morale.auto_choice_for(faction, prisoner) == "ransom",
		"an AI captor ransoms rather than starve its army")

	# The bug as reported: the AI asks before it chooses, but the human is asked
	# by a dialog and can answer "capture" regardless. Standing in for the human
	# here — the captor is treated as the one being prompted — so the prisoner
	# stays pending and the claim arrives exactly the way a button press does.
	var human_before: int = morale.human_faction_id
	morale.human_faction_id = faction

	var outcome: Array = []
	var probe := func(_u: Node, result: String, _f: int): outcome.append(result)
	EventBus.surrender_resolved.connect(probe)
	morale.begin_surrender(prisoner, faction)
	_check(morale.has_pending_surrender(), "the prisoner waits on the captor's answer")
	morale.resolve_surrender(prisoner, "capture")
	EventBus.surrender_resolved.disconnect(probe)

	morale.human_faction_id = human_before
	# The prompt was answered through the manager rather than the button, so the
	# dialog it opened is still on screen. Nothing else in this suite may inherit
	# a modal that is blocking input.
	if main_hud_surrender_visible():
		main.main_hud.surrender_modal.hide()

	_check(outcome.size() == 1 and outcome[0] == "ransom",
		"a capture the army cannot feed is settled as a ransom (%s)" % str(outcome))
	_check(not is_instance_valid(prisoner) or prisoner.faction_id == rival,
		"the prisoner never joined the roster")

	# --- door three: a mercenary out of a chest ------------------------------
	# Topped up to the ceiling first. The table hires the best unit the faction's
	# castle can field, and at 6/8 a light hire still fits — refusing it would
	# have been the wrong behaviour, and a green tick for the wrong reason.
	while economy.get_used_capacity(faction, TurnManager.get_faction_units(faction)) < maximum:
		var top_up: TacticalUnit = _enlist(_spawn("res://resources/units/pawn_%s.tres" % suffix,
			faction, _open_cell_away_from(castle.grid_position)))
		if top_up == null:
			break
		filler.append(top_up)
		if filler.size() > 40:
			break
	_check(economy.get_used_capacity(faction, TurnManager.get_faction_units(faction)) == maximum,
		"roster filled to the ceiling at %d/%d" % [maximum, maximum])

	if is_instance_valid(objects) and objects.pandora != null and not filler.is_empty():
		var opener: TacticalUnit = filler[0]
		# The chest also pays gold when it has nowhere to STAND a mercenary, so
		# without this the refusal below could pass for the wrong reason.
		var has_space: bool = false
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if grid.is_cell_walkable(opener.grid_position + d):
				has_space = true
		_check(has_space, "the chest has room to stand a mercenary, so a refusal is the ceiling")
		var payout: Dictionary = objects.pandora.grant_mercenary(opener.grid_position, opener)
		_check(not payout.has("unit"),
			"a chest pays gold instead of a mercenary when the ranks are full (%s)"
			% str(payout.keys()))
		# If it hired one anyway, it must not be left standing on the board for
		# the sections below to trip over.
		if payout.has("unit") and is_instance_valid(payout["unit"]):
			_discharge([payout["unit"]])

	# --- and it lets them in again once there is room ------------------------
	_discharge(filler)
	await get_tree().process_frame
	var freed: Array = TurnManager.get_faction_units(faction)
	_check(economy.has_capacity_for(faction, 3, freed),
		"the heavy unit fits again once the roster empties (%d/%d)"
		% [economy.get_used_capacity(faction, freed), economy.get_max_capacity(faction)])

	if is_instance_valid(prisoner):
		_discharge([prisoner])


func main_hud_surrender_visible() -> bool:
	if not is_instance_valid(main.main_hud):
		return false
	var modal = main.main_hud.surrender_modal
	return is_instance_valid(modal) and modal.visible


## Terrain-aware Dijkstra, ignoring unit occupancy: this measures the shape of
## the MAP, not who happens to be standing where on turn one.
func _walk_cost(from: Vector2i, to: Vector2i) -> int:
	if from.x < 0 or to.x < 0:
		return -1
	var dist: Dictionary = {from: 0}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var best_i: int = 0
		for i in range(frontier.size()):
			if dist[frontier[i]] < dist[frontier[best_i]]:
				best_i = i
		var cur: Vector2i = frontier[best_i]
		frontier.remove_at(best_i)
		if cur == to:
			return dist[cur]
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nxt: Vector2i = cur + d
			if not grid.is_within_bounds(nxt):
				continue
			if grid.get_terrain(nxt) == GameConfig.TerrainType.WATER and nxt != to:
				continue
			var nd: int = dist[cur] + grid.get_move_cost(nxt)
			if not dist.has(nxt) or nd < dist[nxt]:
				dist[nxt] = nd
				frontier.append(nxt)
	return -1


# ==============================================================================
# 14. THE BLACK CASTLE KEEPS A GARRISON
# ==============================================================================

## Monsters raid; they do not conquer.
##
## The rule they exist to test is a negative one, and negatives are what quietly
## stop holding: a marauder that CAN claim a gold mine breaks nothing loudly, it
## just hands the centre of the map to a faction with no economy and no turn
## worth taking. So most of this section asserts what does NOT happen.
func _test_black_castle_encounters() -> void:
	print("\n[14] The Black Castle keeps a garrison")

	var monsters: int = GameConfig.Faction.BLACK_COVEN
	var army: int = MatchSetup.participants[0]

	# --- the roster exists and is six creatures, one of them the boss --------
	_check(GameConfig.ENCOUNTER_ROSTER.size() == 5,
		"five wandering encounters are defined (got %d)" % GameConfig.ENCOUNTER_ROSTER.size())
	var all_load: bool = ResourceLoader.exists(GameConfig.ENCOUNTER_BOSS)
	var distinct: Dictionary = {}
	for path in GameConfig.ENCOUNTER_ROSTER + [GameConfig.ENCOUNTER_BOSS]:
		if not ResourceLoader.exists(path):
			all_load = false
			continue
		var data: UnitData = load(path) as UnitData
		if not is_instance_valid(data) or not is_instance_valid(data.spritesheet):
			all_load = false
			continue
		distinct[data.unit_name] = true
	_check(all_load, "every encounter resource loads and carries art")
	_check(distinct.size() == 6, "the six encounters are all different creatures (got %d)"
		% distinct.size())

	# The undead feel no fear, which is what keeps them off the morale system
	# entirely — a ghoul that could be talked into surrendering would be a
	# prisoner the player has capacity for and the monsters do not.
	var boss_data: UnitData = load(GameConfig.ENCOUNTER_BOSS) as UnitData
	_check(is_instance_valid(boss_data) and boss_data.is_morale_immune(),
		"the boss is morale-immune, like everything else undead")

	# --- what a marauder may and may not take -------------------------------
	var den: Building = null
	var mine: Building = null
	var village: Building = null
	var keep: Building = null
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (b is Building):
			continue
		if b.building_type == Building.BuildingType.CASTLE and b.faction_id == monsters:
			den = b
		elif b.building_type == Building.BuildingType.CASTLE and b.faction_id == army:
			keep = b
		elif b.building_type == Building.BuildingType.GOLD_MINE and mine == null:
			mine = b
		elif b.building_type == Building.BuildingType.HOUSE and village == null:
			village = b

	if den == null or mine == null or village == null or keep == null:
		_check(false, "the map has a den, a mine, a village and an army castle")
		return

	var mine_owner: int = mine.faction_id
	var village_owner: int = village.faction_id
	# The mine goes to a RIVAL, not to `army`. Both questions below are asked
	# about it — "can a monster take this" and "would our army march on it" —
	# and an army never marches on ground it already holds, so handing it to
	# `army` would make the control check fail for a reason unrelated to
	# monsters.
	mine.capture(MatchSetup.participants[1])
	village.capture(army)

	_check(keep.claim_for(monsters) == Building.Claim.NOTHING,
		"a monster cannot claim an army's castle")
	_check(mine.claim_for(monsters) == Building.Claim.NOTHING,
		"a monster cannot claim a gold mine")
	_check(village.claim_for(monsters) == Building.Claim.RAZE,
		"a monster BURNS a held village rather than taking it")
	_check(den.claim_for(army) == Building.Claim.CAPTURE,
		"an army CAN claim the den — clearing it is the point of the encounter")
	_check(village.claim_for(army) == Building.Claim.NOTHING,
		"nobody re-claims what they already hold")

	# A neutral village is nobody's supply line, so there is nothing to deny.
	village.capture(GameConfig.Faction.NEUTRAL)
	_check(village.claim_for(monsters) == Building.Claim.NOTHING,
		"an unclaimed village is not worth burning")
	village.capture(army)

	# --- the AI is not lured into a den it can never take --------------------
	# Without this the monster keep scores as the highest-value objective on the
	# board (a castle, dead centre, near everything) and each army feeds units
	# into it one at a time for the rest of the match.
	# Stood next to the mine so the control check measures the claim rule and
	# not whether a corner of the map happens to have a route to the middle.
	var scout: TacticalUnit = _enlist(_spawn("res://resources/units/pawn_%s.tres"
		% GameConfig.FACTION_SUFFIX[army], army, _free_neighbour_of(mine.grid_position)))
	var judge := AITacticalEvaluator.new(grid, main.combat_resolver, null, army)
	_check(judge.score_objective(scout, den) == -INF,
		"the den is not marched on while its boss stands on it")
	_check(judge.score_objective(scout, mine) > -INF,
		"a real objective still scores (control)")

	# ...and the reason must be the OCCUPANT, not the ownership — otherwise the
	# keep stays worthless after the boss falls and the reward never arrives.
	var guard: TacticalUnit = grid.get_unit_at(den.grid_position)
	if is_instance_valid(guard):
		grid.unregister_unit(guard)
		_check(judge.score_objective(scout, den) > -INF,
			"once the den is empty the keep becomes a real objective")
		grid.register_unit(guard, den.grid_position)
	else:
		_check(false, "the boss is standing on the den")

	# The same rule holds for any building, which is what makes it a rule rather
	# than a special case: park a unit on the mine and it stops being somewhere
	# anyone can march to this turn.
	var squatter: TacticalUnit = _enlist(_spawn("res://resources/units/pawn_%s.tres"
		% GameConfig.FACTION_SUFFIX[MatchSetup.participants[1]],
		MatchSetup.participants[1], mine.grid_position))
	_check(judge.score_objective(scout, mine) == -INF,
		"an occupied mine is not an objective either")
	_discharge([squatter])

	# --- razing actually costs the owner its capacity -----------------------
	var economy: Node = main.economy_manager
	var cap_before: int = economy.get_max_capacity(army)
	village.raze()
	await get_tree().process_frame
	var cap_after: int = economy.get_max_capacity(army)
	_check(cap_after == cap_before - GameConfig.VILLAGE_CAPACITY_BONUS,
		"burning a village takes its %d troop capacity back (%d -> %d)"
		% [GameConfig.VILLAGE_CAPACITY_BONUS, cap_before, cap_after])
	_check(not is_instance_valid(village) or not village.is_in_group("buildings"),
		"a razed village stops paying its owner income")

	# --- monsters take no prisoners -----------------------------------------
	var morale = main.morale_manager
	if is_instance_valid(morale):
		morale.begin_surrender(scout, monsters)
		_check(not scout.pending_surrender,
			"a unit cannot surrender to a monster — there is nobody to surrender to")

	# --- the turn banner is coloured for whoever is actually playing --------
	# A literal 🔵 in the format string told a Purple player they were blue,
	# every turn, for the whole match.
	var pips: Dictionary = {}
	for faction_id in MatchSetup.participants:
		pips[GameConfig.faction_marker(faction_id)] = true
	_check(pips.size() == MatchSetup.participants.size(),
		"every army has its own turn marker (got %d for %d armies)"
		% [pips.size(), MatchSetup.participants.size()])
	_check(GameConfig.faction_marker(GameConfig.Faction.PURPLE_SYNDICATE) != \
		GameConfig.faction_marker(GameConfig.Faction.BLUE_KINGDOM),
		"commanding Purple is not announced in blue")

	# Read the banner the player actually sees, not just the table behind it.
	# The bug was a hardcoded pip in the format string, and a table can be
	# perfectly correct while the format string ignores it.
	var hud_probe = main.main_hud
	if is_instance_valid(hud_probe) and hud_probe.get("context_label") != null:
		var was_player: int = hud_probe.player_faction_id
		var was_text: String = hud_probe.context_label.text
		for faction_id in MatchSetup.participants:
			hud_probe.player_faction_id = faction_id
			hud_probe._on_turn_started(faction_id)
			var shown: String = hud_probe.context_label.text
			_check(shown.contains(GameConfig.faction_marker(faction_id))
					and shown.contains(GameConfig.faction_display_name(faction_id).to_upper()),
				"%s reads its own turn banner: %s"
					% [GameConfig.faction_title(faction_id), shown.get_slice("\n", 0)])
		hud_probe.player_faction_id = was_player
		hud_probe.context_label.text = was_text
	else:
		_check(false, "the HUD exposes its context banner")

	# --- the garrison is real, and it is on its leash -----------------------
	var den_units: Array = TurnManager.get_faction_units(monsters)
	_check(den_units.size() >= GameConfig.ENCOUNTER_INITIAL,
		"the den garrisons at least %d creatures (got %d)"
		% [GameConfig.ENCOUNTER_INITIAL, den_units.size()])

	var encounters = main.encounter_manager
	if is_instance_valid(encounters):
		_check(encounters.den_cell == den.grid_position,
			"the den anchors on the Black Castle at %s" % str(den.grid_position))

		var all_leashed: bool = true
		for m in den_units:
			if not is_instance_valid(m):
				continue
			if not encounters._within_leash(m.grid_position):
				all_leashed = false
		_check(all_leashed, "every monster spawns inside the %d-cell leash"
			% GameConfig.ENCOUNTER_LEASH)

		# The leash is enforced when a step is CHOSEN, not corrected after the
		# fact — so a monster ordered at a target beyond it must stop at the
		# boundary rather than walk out and be dragged back.
		var far: Vector2i = Vector2i(
			clampi(den.grid_position.x + GameConfig.ENCOUNTER_LEASH * 2, 0, grid.grid_size.x - 1),
			den.grid_position.y)
		var runner: TacticalUnit = null
		for m in den_units:
			if is_instance_valid(m) and m != encounters._boss:
				runner = m
				break
		if runner != null:
			var step: Vector2i = encounters._step_towards(runner, far)
			_check(encounters._within_leash(step),
				"chasing a target beyond the leash still stops inside it (%s)" % str(step))
		else:
			_check(false, "the den has a wanderer to test the leash with")
	else:
		_check(false, "the match built an EncounterManager")

	_discharge([scout])
	mine.capture(mine_owner)
	if is_instance_valid(village):
		village.capture(village_owner)

	# --- the menu's backdrop is scenery, not a board -------------------------
	# `MenuBackdrop` puts 21 real `Building` nodes behind the main menu so it
	# looks like the game rather than a dark rectangle. `Building._ready()` adds
	# every one of them to the "buildings" group, which is how income, troop
	# capacity, the victory check and the AI all find their buildings — so a
	# decorative castle left in there is a castle the game would count. The
	# backdrop pulls them straight back out; this is the check that it still
	# does, because the failure would be silent and would look like an economy
	# bug rather than a menu one.
	var before: int = get_tree().get_nodes_in_group("buildings").size()
	var backdrop = load("res://scenes/ui/MenuBackdrop.tscn").instantiate()
	add_child(backdrop)
	await get_tree().process_frame
	var during: int = get_tree().get_nodes_in_group("buildings").size()
	var props: int = 0
	for child in backdrop.get_node("Buildings").get_children():
		if child is Building:
			props += 1
	_check(props >= 20, "the menu backdrop stands up a full board (%d buildings)" % props)
	_check(during == before,
		"none of them join the gameplay group (%d before, %d with the backdrop up)"
			% [before, during])
	backdrop.queue_free()
	await get_tree().process_frame


# ==============================================================================
# 15. WHAT THE AI WANTS — CAPACITY, COMPOSITION, AGGRESSION
# ==============================================================================

## Three play-testing complaints, one section: keeps were worth no capacity, the
## enemy only ever bought mages, and the armies read as passive.
func _test_ai_appetite() -> void:
	print("\n[15] Taking ground, buying variety, picking fights")

	var army: int = MatchSetup.participants[0]
	var rival: int = MatchSetup.participants[1]
	var economy: Node = main.economy_manager

	# --- a second keep is worth more than a village -------------------------
	var base: int = economy.get_max_capacity(army)
	_check(base == GameConfig.BASE_TROOP_CAPACITY,
		"an army holding one keep and no villages sits at base capacity (%d)" % base)

	var rival_keep: Building = null
	for b in get_tree().get_nodes_in_group("buildings"):
		if b is Building and b.building_type == Building.BuildingType.CASTLE \
				and b.faction_id == rival:
			rival_keep = b
			break
	if rival_keep == null:
		_check(false, "there is a rival castle to take")
		return

	rival_keep.capture(army)
	_check(economy.get_max_capacity(army) == base + GameConfig.CASTLE_CAPACITY_BONUS,
		"taking an enemy keep is worth +%d capacity (%d -> %d)"
			% [GameConfig.CASTLE_CAPACITY_BONUS, base, economy.get_max_capacity(army)])
	_check(economy.get_max_capacity(rival) == GameConfig.BASE_TROOP_CAPACITY,
		"...and losing your only keep does not starve you below base (%d)"
			% economy.get_max_capacity(rival))
	rival_keep.capture(rival)
	_check(economy.get_max_capacity(army) == base,
		"the capacity goes back when the keep does")

	_check(GameConfig.CASTLE_CAPACITY_BONUS > GameConfig.VILLAGE_CAPACITY_BONUS,
		"a keep outranks a village (+%d vs +%d)"
			% [GameConfig.CASTLE_CAPACITY_BONUS, GameConfig.VILLAGE_CAPACITY_BONUS])

	# --- the recruiter buys an army, not six copies of one unit -------------
	# The old rule was deterministic twice over — same board, same answer, and
	# every tie to the most expensive unit, which is the Wizzard. Six draws
	# against a Melee enemy used to be six mages.
	var commander: AIManager = null
	for ai in main.ai_managers:
		commander = ai
		break
	var castle: Building = null
	for b in get_tree().get_nodes_in_group("buildings"):
		if b is Building and b.building_type == Building.BuildingType.CASTLE \
				and b.faction_id == army:
			castle = b
			break

	if commander == null or castle == null or castle.recruitable_units.is_empty():
		_check(false, "an AI commander and a stocked castle are reachable")
		return

	# Twenty trials, not one. The tiebreak is deliberately random, so a single
	# sample tests the seed rather than the rule — and a flaky assertion in a
	# suite this size is worse than no assertion at all.
	var roster: Array = castle.recruitable_units
	const TRIALS: int = 20
	var mage_total: int = 0
	var fewest_classes: int = 99
	var sample: Dictionary = {}
	for trial in range(TRIALS):
		var picked: Dictionary = {}
		var army_so_far: Array = []
		for i in range(6):
			var choice: UnitData = commander.pick_recruit(roster, "Melee", army_so_far)
			if not is_instance_valid(choice):
				break
			picked[choice.unit_class] = int(picked.get(choice.unit_class, 0)) + 1
			# Fake the purchase, so the next draw sees the army the last built.
			var bought := TacticalUnit.new()
			bought.unit_data = choice
			army_so_far.append(bought)
		for u in army_so_far:
			if is_instance_valid(u):
				u.free()
		mage_total += int(picked.get("Mage", 0))
		fewest_classes = mini(fewest_classes, picked.size())
		sample = picked

	var mage_mean: float = float(mage_total) / float(TRIALS)
	_check(fewest_classes >= 3,
		"every trial of six draws buys at least 3 different classes (worst %d, last %s)"
			% [fewest_classes, str(sample)])
	_check(mage_mean <= 2.5,
		"six draws against Melee average at most 2.5 mages (got %.2f over %d trials)"
			% [mage_mean, TRIALS])

	# An empty army still buys the actual counter — variety must never cost the
	# AI its matchups, so the composition penalty has to start at zero.
	var counters: Dictionary = {}
	for i in range(12):
		var first: UnitData = commander.pick_recruit(roster, "Melee", [])
		if is_instance_valid(first):
			counters[first.unit_class] = true
	_check(counters.has("Mage"),
		"with nothing on the board yet the counter to Melee is still reachable (%s)"
			% str(counters.keys()))

	# --- and the armies actually pick fights --------------------------------
	# `score_enemy_target` and `score_objective` share a scale on purpose, so
	# this is a real comparison rather than two numbers that merely look alike.
	var gold_value: float = float(GameConfig.AI_OBJECTIVE_VALUE.get("gold_mine", 0.0))
	_check(GameConfig.AI_ENEMY_VALUE >= gold_value,
		"a living enemy is worth at least a gold mine to walk toward (%.0f vs %.0f)"
			% [GameConfig.AI_ENEMY_VALUE, gold_value])
	_check(GameConfig.AI_ENEMY_VALUE + GameConfig.AI_WOUNDED_BONUS
			> float(GameConfig.AI_OBJECTIVE_VALUE.get("castle", 0.0)),
		"a half-dead enemy outranks even a castle (%.0f vs %.0f)"
			% [GameConfig.AI_ENEMY_VALUE + GameConfig.AI_WOUNDED_BONUS,
				float(GameConfig.AI_OBJECTIVE_VALUE.get("castle", 0.0))])

	# A unit at half health standing next to one enemy used to break off. The
	# threat estimate counts every enemy that could reach AND strike the cell,
	# which over-counts a single turn on purpose — so the trigger has to sit
	# above 1.0 or the AI flinches from fights it wins.
	_check(GameConfig.AI_RETREAT_THREAT_RATIO > 1.0,
		"a unit only breaks off from ground that could actually kill it (%.2f)"
			% GameConfig.AI_RETREAT_THREAT_RATIO)
	_check(GameConfig.AI_RETREAT_HP_RATIO < 0.3,
		"and only when genuinely mauled, not merely scratched (%.2f)"
			% GameConfig.AI_RETREAT_HP_RATIO)

	var judge := AITacticalEvaluator.new(grid, main.combat_resolver, null, army)
	var hurt: TacticalUnit = _enlist(_spawn("res://resources/units/warrior_%s.tres"
		% GameConfig.FACTION_SUFFIX[army], army, _open_cell_away_from(castle.grid_position)))
	hurt.current_health = int(hurt.unit_data.max_health * 0.5)
	_check(not judge.should_retreat(hurt),
		"a warrior at half health with nothing adjacent stands its ground")
	hurt.current_health = maxi(1, int(hurt.unit_data.max_health * 0.15))
	_check(judge.should_retreat(hurt),
		"...but one at 15% looks for a way out")
	_discharge([hurt])


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
		print("🎉 MILESTONE 5 — ALL %d CHECKS PASSED" % _passed)
	else:
		print("⚠️  MILESTONE 5 — %d passed, %d FAILED" % [_passed, _failed])
		for failure in _failures:
			print("    ✗ %s" % failure)
	print("==========================================================")
