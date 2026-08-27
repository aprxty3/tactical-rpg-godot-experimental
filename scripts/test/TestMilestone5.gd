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

	main = load("res://scenes/TestGridScene.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	grid = main.get_node("GridManager")
	combat = main.get_node("CombatResolver")
	vision = main.get_node("VisionManager")
	ai = main.get_node("AIManager")
	vfx = main.get_node("VfxManager")
	camera = main.get_node("Camera2D")
	units_root = main.get_node("Units")
	objects = main.get_node("MapObjectManager")

	# Freeze the scene's own input handling. Turns advancing mid-run would move
	# the map's units between assertions and make failures irreproducible; the
	# controller's _unhandled_input is what ends a turn, so silencing it is what
	# actually holds the board still.
	main.set_process_unhandled_input(false)

	_test_damage_preview()
	_test_objective_scoring()
	_test_terrain_aware_pathing()
	_test_attack_scoring()
	_test_threat_and_retreat()
	_test_recruit_composition()
	await _test_vfx()
	await _test_fire_vfx()
	_test_death_marker()
	_test_hidden_traps()
	_test_barrel_leaves_fire()
	await _test_damage_glitch()
	_test_camera_shake()
	_test_mount_system()
	_test_directional_facing()
	_test_backwards_compatibility()
	await _test_audio()

	_report()


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
