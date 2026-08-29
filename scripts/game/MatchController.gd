extends Node2D
class_name MatchController
## The battlefield. Wires the managers, builds the map, musters the armies and
## turns player input into commands.
##
## Was `TestGridController` under `scripts/test/`: while it lived there the
## player's faction was a `const` and the opponent hardcoded to Red.
##
## Still doing too much — wiring, map construction, input, selection state,
## commands and the highlight overlay are six concerns in one file.

@onready var grid_manager: GridManager = $GridManager
@onready var combat_resolver: CombatResolver = $CombatResolver
@onready var economy_manager: Node = $EconomyManager
@onready var unit_container: Node2D = $Units
@onready var building_container: Node2D = $Buildings
@onready var main_hud: CanvasLayer = $MainHUD
@onready var map_builder: MapBuilder = $MapBuilder
@onready var camera: TacticalCamera = $Camera2D
@onready var decor_container: Node2D = $Decor
@onready var morale_manager: MoraleManager = $MoraleManager
@onready var vision_manager: VisionManager = $VisionManager
## Optional: purely decorative, and nothing here ever reads it back. A scene
## without it plays identically.
@onready var vfx_manager: VfxManager = get_node_or_null("VfxManager")
@onready var map_object_manager: MapObjectManager = $MapObjectManager
@onready var map_object_container: Node2D = $MapObjects

## Seed for the per-match resource layout. 0 rolls a fresh one every match;
## any other value reproduces the same board, which is what a bug report or a
## repeatable test needs.
@export var resource_seed: int = 0

## How long each AI waits between its own actions, so its turn reads as
## deliberate rather than instantaneous. One knob covering every AI on the
## field — with three opponents instead of one it is the single largest lever
## on how long a full round takes to watch.
@export var ai_action_delay: float = 0.4

## How much ground around a castle stays clear of props, in cells. `ArmyMuster`
## searches outward from the keep for somewhere to stand, and a tree in ring one
## is one fewer opening position.
const MUSTER_CLEARANCE: int = 2

## The roles each army musters with. Same three for everyone, so no faction
## opens with an advantage that was never designed.
const STARTING_ROLES: Array[String] = ["Pawn", "Warrior", "Archer"]

## The faction the human is playing. Everything view-side (fog, surrender
## prompts, input gating) is written from this faction's perspective.
##
## Filled from `MatchSetup` in `_ready`. It used to be a `const`, which is
## precisely why the player could never be anything but Blue.
var player_faction: int = GameConfig.Faction.BLUE_KINGDOM

## One commander per enemy faction, built in `_ready`. These cannot be authored
## in the scene: which factions the computer drives depends on which one the
## player chose, and that is not known until the faction screen has been through.

var ai_managers: Array[AIManager] = []

## The Black Castle's garrison. Built in code for the same reason the AI
## commanders are: it needs the finished board to find its keep, and the scene
## file cannot hold "whatever the map ended up looking like".
var encounter_manager: EncounterManager

var selected_unit: TacticalUnit = null
var selected_building: Building = null
var reachable_cells: Array[Vector2i] = []
var attackable_cells: Array[Vector2i] = []
var hovered_cell: Vector2i = Vector2i(-1, -1)

## The highlight layer. Created in code and forced to child index 0 — see
## GridOverlay's own note on why that position is load-bearing.
var grid_overlay: GridOverlay


func _ready() -> void:
	# The layers carry explicit negative z_index (-4 water .. -1 bridge) so they
	# draw below this node's `_draw()` highlights. A positive z_index here would
	# not work: `z_as_relative` ties children to us, and ties resolve by tree
	# order — children paint over their parent's `_draw()`.

	EventBus.unit_move_completed.connect(_on_unit_move_completed)
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.building_captured.connect(_on_building_captured)
	EventBus.dialogue_generated.connect(_on_dialogue_generated)
	EventBus.story_event_narrated.connect(_on_story_event_narrated)
	EventBus.terrain_changed.connect(_on_terrain_changed)
	EventBus.vision_updated.connect(_on_vision_updated)
	EventBus.surrender_triggered.connect(_on_surrender_triggered)

	if main_hud.has_signal("end_turn_requested"):
		main_hud.end_turn_requested.connect(end_turn)
	if main_hud.has_signal("recruit_unit_requested"):
		main_hud.recruit_unit_requested.connect(_do_recruit)
	if main_hud.has_signal("upgrade_unit_requested"):
		main_hud.upgrade_unit_requested.connect(_do_upgrade)
	if main_hud.has_signal("surrender_choice_made"):
		main_hud.surrender_choice_made.connect(_on_surrender_choice_made)

	# 1. Whose match is this? MatchSetup is an autoload for exactly this reason:
	#    the choice is made on the faction screen and `change_scene_to_file`
	#    frees everything that screen owned before this scene is built.
	player_faction = MatchSetup.player_faction

	# 2. Register every faction that owns something on the map. Participants
	#    field armies and need a war chest; the rest take no turn but still hold
	#    a castle, and a captured building needs a treasury to pay into.
	for faction_id in MatchSetup.participants:
		economy_manager.register_faction(faction_id, 200, 6)
	for faction_id in GameConfig.FACTION_SUFFIX.keys():
		if not faction_id in MatchSetup.participants:
			economy_manager.register_faction(faction_id, 100, 2)

	# 3. Wire the Milestone 4 managers. Each takes its dependencies through
	#    setup() rather than reaching for node paths, so the same managers drop
	#    into the focused test scenes unchanged.
	morale_manager.human_faction_id = player_faction
	morale_manager.setup(grid_manager, economy_manager)
	vision_manager.observer_faction_id = player_faction
	combat_resolver.setup(grid_manager)
	map_object_manager.setup(grid_manager, economy_manager, map_object_container, unit_container)
	main_hud.player_faction_id = player_faction

	# The highlight layer, forced to the front of the child list. The map layers
	# sit at negative z_index so this controller's own drawing landed above them,
	# while Buildings and Units — both z 0 — drew after it in tree order. A node
	# draws before its children, so index 0 is the only position that reproduces
	# that stack; anywhere later buries the highlights under the units on them.
	grid_overlay = GridOverlay.new()
	grid_overlay.name = "GridOverlay"
	add_child(grid_overlay)
	move_child(grid_overlay, 0)
	grid_overlay.setup(grid_manager)

	# 4. Terrain first, armies second, everything that reads them third. The
	#    armies used to be nodes sitting in the scene file, so this order never
	#    came up; spawning them in code means the river has to exist before
	#    anyone is placed, or a starting unit lands in the water.
	_build_terrain()
	_dress_terrain()
	_scatter_resources()
	_spawn_starting_armies()
	_finish_map_setup()

	# 5. One commander per opponent. Before `start_turn`, because each hooks
	#    `turn_started` in its own `_ready` and would otherwise miss the first.
	_spawn_ai_commanders()

	# 6. Turn order is the participant list plus the marauders. The two are
	#    passed separately because only the first can win: a den of monsters
	#    takes a turn but must never count as a surviving faction, or "last one
	#    standing" is never reached and a won match simply never ends.
	TurnManager.setup_match(MatchSetup.participants, economy_manager, MatchSetup.marauders)

	# 7. The monsters, after setup_match so their spawn lands on a roster that
	#    already has a bucket for them, and before start_turn so the boss is on
	#    the keep by the time anyone can look at it.
	_spawn_encounters()

	main_hud.initialize(economy_manager, grid_manager)

	TurnManager.start_turn()
	_refresh_overlay()


## MapBuilder owns the layout; GridManager stays the only authority on
## walkability, so water is registered as blocked rather than inferred from tile
## ids. Split from the rest because the armies are mustered between the halves,
## and nothing can be placed until the water is known.
func _build_terrain() -> void:
	if not map_builder:
		return

	map_builder.grid_size = grid_manager.grid_size
	var blocked: Array[Vector2i] = map_builder.build(
		get_node_or_null("TileMapLayer_Water"),
		get_node_or_null("TileMapLayer_Ground"),
		get_node_or_null("TileMapLayer_Path"),
		get_node_or_null("TileMapLayer_Bridge"),
	)
	grid_manager.set_terrain_blocked_cells(blocked)


## Plant the props and freeze the terrain map. Pulled ahead of the resource roll
## because a tree makes a cell forest at 2 MP: rolling mines first measured
## fairness against bare rivers, and six rolls in twenty-four came out lopsided
## once the trees landed.
##
## Props stay off each army's muster ground and off the authored building cells,
## so the scene layout is still clean if the roll declines to replace it.
func _dress_terrain() -> void:
	if not map_builder:
		return

	var reserved: Array[Vector2i] = []
	for bld in get_tree().get_nodes_in_group("buildings"):
		if not (bld is Building):
			continue
		var clearance: int = MUSTER_CLEARANCE if bld.building_type == Building.BuildingType.CASTLE else 1
		for dx in range(-clearance, clearance + 1):
			for dy in range(-clearance, clearance + 1):
				reserved.append(bld.grid_position + Vector2i(dx, dy))

	map_builder.scatter_decor(decor_container, grid_manager.cell_size, reserved)
	grid_manager.set_terrain_map(map_builder.get_terrain_map())


## After the props, or it measures a map about to change underneath it; before
## the muster, because the muster refuses cells holding a building and a mine
## arriving later would land on a soldier.
##
## `ResourceScatter` keeps the authored layout when it cannot find a fair roll,
## so failing here costs variety, never fairness.
func _scatter_resources() -> void:
	var rng := RandomNumberGenerator.new()
	if resource_seed == 0:
		rng.randomize()
	else:
		rng.seed = resource_seed

	var scatter := ResourceScatter.new(grid_manager, rng)
	var report: Dictionary = scatter.scatter(get_tree().get_nodes_in_group("buildings"))
	if not report["applied"]:
		push_warning("ResourceScatter: keeping the authored layout — %s" % report["reason"])


## Props, hazards, fog and camera — everything that has to know where the
## terrain and the armies both ended up.
func _finish_map_setup() -> void:
	if not map_builder:
		return

	# Units carry only a pixel position from the scene; GridManager fills in
	# `grid_position` and defers that to end of frame. Prop reservation and the
	# fog's first sight pass both read it, so registration is pulled forward —
	# otherwise every unit reads (0, 0) and the fog marks the top-left explored.
	grid_manager.register_existing_units()

	# Keep hazards and treasure off anything gameplay-relevant. Recomputed here
	# rather than reused from `_dress_terrain`: the resources have moved since,
	# and the armies did not exist yet when the props went down.
	var reserved: Array[Vector2i] = []
	for bld in get_tree().get_nodes_in_group("buildings"):
		if bld is Building:
			reserved.append(bld.grid_position)
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				reserved.append(bld.grid_position + d)
	for unit in unit_container.get_children():
		if unit is TacticalUnit:
			reserved.append(unit.grid_position)

	map_object_manager.populate(map_builder, reserved)

	# Fog needs the finished terrain to know what conceals.
	vision_manager.setup(grid_manager, get_node_or_null("FogOfWarTileMapLayer"))

	if vfx_manager:
		vfx_manager.setup(grid_manager, camera, get_node_or_null("Vfx"))

	if camera:
		camera.configure(grid_manager.get_map_pixel_size(), _player_start_focus())


## Open the match looking at the player's own castle rather than the origin.
func _player_start_focus() -> Vector2:
	for bld in get_tree().get_nodes_in_group("buildings"):
		if bld is Building and bld.building_type == Building.BuildingType.CASTLE \
				and bld.faction_id == player_faction:
			return bld.global_position
	return grid_manager.get_map_pixel_size() * 0.5


# ==============================================================================
# ARMIES — mustered in code, because the number of them is no longer fixed
# ==============================================================================

## Placing the opening armies moved to `ArmyMuster`: castle lookup, the ring
## search for free ground, and unit instancing are one job, and they are the
## only part of this controller that runs exactly once and never again.
func _spawn_starting_armies() -> void:
	var muster := ArmyMuster.new(grid_manager, unit_container)
	muster.muster(MatchSetup.participants, STARTING_ROLES)


## One AI per opponent.
##
## `ai_faction_id` is set before `setup()` and not after: `setup` builds the
## tactical evaluator around that id, so an AI configured the other way round
## would spend the match scoring the board from the wrong side.
func _spawn_ai_commanders() -> void:
	for faction_id in MatchSetup.ai_factions():
		var ai := AIManager.new()
		ai.name = "AI_%s" % GameConfig.faction_display_name(faction_id)
		ai.ai_faction_id = faction_id
		ai.action_delay = ai_action_delay
		add_child(ai)
		# combat_resolver last: it is what lets the AI score a swing with the
		# same damage formula the player's attacks resolve through.
		ai.setup(grid_manager, economy_manager, vision_manager,
			map_object_manager, combat_resolver)
		ai_managers.append(ai)


## Stand up the Black Castle's garrison.
##
## Skipped entirely when the map has no Black Castle or the match fields no
## marauders — `EncounterManager` warns and does nothing in that case, and the
## focused test scenes have neither.
func _spawn_encounters() -> void:
	if MatchSetup.marauders.is_empty():
		return
	encounter_manager = EncounterManager.new()
	encounter_manager.name = "EncounterManager"
	encounter_manager.faction_id = MatchSetup.marauders[0]
	encounter_manager.action_delay = ai_action_delay
	add_child(encounter_manager)
	encounter_manager.setup(grid_manager, unit_container, combat_resolver)
	encounter_manager.garrison()


func _update_hud_text(text: String) -> void:
	if main_hud and main_hud.has_method("_update_context_text"):
		main_hud._update_context_text(text)


func _unhandled_input(event: InputEvent) -> void:
	# The match is decided. Nothing gets through — not movement, not attacks, not
	# End Turn. Showing a VICTORY banner while the board stayed fully playable
	# underneath it is what made the result feel like a caption rather than an
	# ending.
	if main_hud and main_hud.has_method("is_match_over") and main_hud.is_match_over():
		return

	# A prisoner is waiting on a decision. The prompt has no cancel path on
	# purpose, so nothing else — not even Escape — is allowed through until the
	# player answers it.
	if main_hud and main_hud.has_method("is_surrender_popup_active") and main_hud.is_surrender_popup_active():
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if main_hud and main_hud.has_method("is_end_turn_confirmation_active") and main_hud.is_end_turn_confirmation_active():
			main_hud.hide_end_turn_confirmation()
			return
		if selected_unit or selected_building:
			_deselect_all()
			return
		get_tree().quit()
		return

	# Asked as "is it my turn" rather than "is it Red's turn". The old test named
	# one specific opponent, so with three of them the player kept full control
	# through Purple's and Yellow's turns.
	if not MatchSetup.is_player(TurnManager.get_current_faction()):
		return

	# `not event.echo` on every discrete command below: a held key auto-repeats
	# many times a second, and Space in particular would then open the end-turn
	# prompt and immediately confirm it, burning through turns without the
	# player ever letting go. Ending a turn, recruiting and promoting are all
	# one-per-press actions, so repeats are dropped.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if main_hud and main_hud.has_method("is_end_turn_confirmation_active"):
			if main_hud.is_end_turn_confirmation_active():
				main_hud._on_confirm_end_turn()
			else:
				main_hud.show_end_turn_confirmation()
		else:
			end_turn()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_try_recruit_at_selected_castle()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U:
		_try_upgrade_at_selected_unit()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_try_toggle_mount()
		return

	if event is InputEventMouseMotion:
		var cell := grid_manager.world_to_grid(get_global_mouse_position())
		if cell != hovered_cell:
			hovered_cell = cell
			_refresh_overlay()
		return

	# Acts on RELEASE, not press. A left-drag pans the camera, and whether a press
	# was a click or the start of a pan is only known once the cursor has moved —
	# so selecting on press would fire before that question could be answered.
	# TacticalCamera marks the release handled when it ended a pan, so a drag never
	# reaches this branch at all and cannot select the tile it finished over.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if main_hud and main_hud.has_method("is_end_turn_confirmation_active") and main_hud.is_end_turn_confirmation_active():
			return
		var mouse_pos = get_global_mouse_position()
		var clicked_cell = grid_manager.world_to_grid(mouse_pos)
		_handle_cell_click(clicked_cell)


func end_turn() -> void:
	_deselect_all()
	TurnManager.end_turn()


func _on_turn_started(faction_id: int) -> void:
	if not MatchSetup.is_player(faction_id):
		_deselect_all()
	else:
		# Player turn logic setup handled via EventBus to HUD natively
		pass


func _handle_cell_click(cell: Vector2i) -> void:
	if not grid_manager.is_within_bounds(cell):
		_deselect_all()
		return

	var unit_at_cell = grid_manager.get_unit_at(cell)
	var building_at_cell = grid_manager.get_building_at(cell)

	# An enemy hidden by fog is not there as far as the player is concerned:
	# it can be neither clicked nor targeted, and the cell behaves as empty.
	if unit_at_cell != null and not _is_unit_visible(unit_at_cell):
		unit_at_cell = null

	if selected_unit != null and unit_at_cell != null and unit_at_cell != selected_unit:
		if unit_at_cell.faction_id != selected_unit.faction_id and attackable_cells.has(cell):
			EventBus.unit_attack_requested.emit(selected_unit, unit_at_cell)
			_deselect_all()
			return

	# Shooting a powder keg is an attack action in its own right — that is the
	# whole reason the kegs sit beside the bridge mouths.
	if selected_unit != null and unit_at_cell == null and attackable_cells.has(cell):
		if _try_shoot_barrel(cell):
			return

	if unit_at_cell != null:
		if unit_at_cell.faction_id == TurnManager.get_current_faction():
			_select_unit(unit_at_cell)
		else:
			_update_hud_text("⚠️ Enemy unit! Select your own unit.")
		return

	if selected_unit != null and reachable_cells.has(cell):
		EventBus.unit_move_requested.emit(selected_unit, cell)
		reachable_cells.clear()
		attackable_cells.clear()
		_refresh_overlay()
		return

	if building_at_cell != null:
		_select_building(building_at_cell)
		return

	_deselect_all()


## Can the human player currently see this unit?
func _is_unit_visible(unit: TacticalUnit) -> bool:
	if not is_instance_valid(vision_manager):
		return true
	return vision_manager.can_see_unit(player_faction, unit)


## Detonate a keg on `cell` if one is there. Costs the selected unit its action.
func _try_shoot_barrel(cell: Vector2i) -> bool:
	if not is_instance_valid(map_object_manager) or not selected_unit.can_act():
		return false

	var has_barrel := false
	for obj in map_object_manager.objects_at(cell):
		if obj is Barrel and not obj.is_spent():
			has_barrel = true
			break
	if not has_barrel:
		return false

	selected_unit.face_direction(grid_manager.grid_to_world(cell))
	selected_unit.play_animation("attack")
	selected_unit.consume_action()
	map_object_manager.detonate_at(cell)
	_update_hud_text("💥 Powder keg detonated!")
	_deselect_all()
	return true


func _select_unit(unit: TacticalUnit) -> void:
	_deselect_all()
	selected_unit = unit
	reachable_cells = grid_manager.get_reachable_cells(unit)
	if is_instance_valid(unit.unit_data):
		attackable_cells = grid_manager.get_attackable_cells(
			unit.grid_position,
			unit.unit_data.attack_range_min,
			unit.unit_data.attack_range_max,
		)
	EventBus.unit_selected.emit(unit)
	_refresh_overlay()


func _select_building(bld: Building) -> void:
	_deselect_all()
	selected_building = bld
	if main_hud.has_method("show_building_info"):
		main_hud.show_building_info(bld)
	_refresh_overlay()


func _try_recruit_at_selected_castle() -> void:
	if not selected_building or selected_building.building_type != Building.BuildingType.CASTLE:
		_update_hud_text("⚠️ Select your Castle to recruit!")
		return
	if selected_building.faction_id != TurnManager.get_current_faction():
		_update_hud_text("⚠️ This castle belongs to the enemy!")
		return
	if selected_building.recruitable_units.is_empty():
		return

	if main_hud.has_method("show_recruit_popup"):
		main_hud.show_recruit_popup(selected_building)


## Get the selected rider on or off its horse.
##
## Mirrors the recruit/upgrade handlers: refuse with a readable reason rather
## than silently doing nothing, so a player pressing [M] on the wrong unit
## learns why instead of assuming the key is broken.
func _try_toggle_mount() -> void:
	if not selected_unit:
		_update_hud_text("⚠️ Select a unit first.")
		return
	if selected_unit.faction_id != TurnManager.get_current_faction():
		_update_hud_text("⚠️ You can only command your own units!")
		return
	if not selected_unit.can_mount():
		_update_hud_text("⚠️ This unit has no mount.")
		return
	if not selected_unit.can_act():
		_update_hud_text("⚠️ This unit has already acted this turn.")
		return

	var was_mounted: bool = selected_unit.is_mounted
	if selected_unit.toggle_mount():
		var state: String = "mounted" if selected_unit.is_mounted else "on foot"
		_update_hud_text("🐴 %s is now %s (MOV %d · DEF %d · %s)" % [
			selected_unit.unit_data.unit_name,
			state,
			selected_unit.get_effective_movement(),
			selected_unit.get_effective_defense(),
			selected_unit.get_effective_class(),
		])
		# Re-select so the movement overlay redraws against the new MOV — the
		# highlighted tiles are computed at selection time and would otherwise
		# still show the mounted range after stepping off the horse.
		_select_unit(selected_unit)
	else:
		selected_unit.is_mounted = was_mounted


func _try_upgrade_at_selected_unit() -> void:
	if not selected_unit:
		_update_hud_text("⚠️ Select a unit to upgrade!")
		return
	if selected_unit.faction_id != TurnManager.get_current_faction():
		_update_hud_text("⚠️ You can only upgrade your own units!")
		return
	if not is_instance_valid(selected_unit.unit_data) or selected_unit.unit_data.upgrade_paths.is_empty():
		_update_hud_text("⚠️ This unit has no available promotions.")
		return

	var castle_here := grid_manager.get_building_at(selected_unit.grid_position)
	var is_at_castle := (
		castle_here != null
		and castle_here.building_type == Building.BuildingType.CASTLE
		and castle_here.faction_id == selected_unit.faction_id
	)

	if main_hud.has_method("show_upgrade_popup"):
		main_hud.show_upgrade_popup(selected_unit, is_at_castle)


func _do_upgrade(unit: TacticalUnit, target_data: Resource) -> void:
	var castle_here := grid_manager.get_building_at(unit.grid_position)
	var is_at_castle := (
		castle_here != null
		and castle_here.building_type == Building.BuildingType.CASTLE
		and castle_here.faction_id == unit.faction_id
	)
	var old_name: String = unit.unit_data.unit_name if is_instance_valid(unit.unit_data) else "Unit"
	var success: bool = economy_manager.process_upgrade(unit.faction_id, unit, target_data, is_at_castle)
	if success:
		_update_hud_text("⬆️ %s promoted to %s!" % [old_name, target_data.unit_name])
		if selected_unit == unit:
			_select_unit(unit)
	else:
		_update_hud_text("❌ Not enough Gold/Iron to promote to %s." % target_data.unit_name)
	_refresh_overlay()


func _do_recruit(building: Building, unit_data: Resource) -> void:
	var active_units = TurnManager.get_faction_units(building.faction_id)

	var check = building.can_recruit(unit_data, economy_manager, active_units)
	if not check["can_recruit"]:
		_update_hud_text("❌ Recruitment failed: %s" % check["reason"])
		return

	var spawn_cell := Vector2i(-1, -1)
	var dirs = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
	for d in dirs:
		var target = building.grid_position + d
		if grid_manager.is_cell_walkable(target):
			spawn_cell = target
			break

	if spawn_cell == Vector2i(-1, -1):
		_update_hud_text("❌ Failed: All cells around Castle are full!")
		return

	var _new_unit = building.recruit_unit(unit_data, spawn_cell, economy_manager, unit_container)
	_update_hud_text("✨ Recruited %s at %s!" % [unit_data.unit_name, spawn_cell])
	_refresh_overlay()


func _deselect_all() -> void:
	selected_unit = null
	selected_building = null
	reachable_cells.clear()
	attackable_cells.clear()
	EventBus.unit_deselected.emit()
	_refresh_overlay()


func _on_unit_move_completed(unit: TacticalUnit, _from_cell: Vector2i, _to_cell: Vector2i) -> void:
	# `== 0` was Blue's id written as a bare number. It kept the camera
	# reselecting Blue units for a player commanding Yellow.
	if unit.faction_id == player_faction:
		_select_unit(unit)
	_refresh_overlay()


func _on_building_captured(building: Building, _new_faction_id: int) -> void:
	_update_hud_text("🚩 Building captured: %s!" % building.name)
	_refresh_overlay()


func _on_combat_resolved(result: Dictionary) -> void:
	var att_name = result.get("attacker", null)
	var def_name = result.get("defender", null)
	att_name = att_name.unit_data.unit_name if is_instance_valid(att_name) and is_instance_valid(att_name.unit_data) else "Attacker"
	def_name = def_name.unit_data.unit_name if is_instance_valid(def_name) and is_instance_valid(def_name.unit_data) else "Defender"

	var prim = result.get("primary_attack", {})
	var ctr = result.get("counter_attack", {})
	var log_str = "⚔️ %s hit %s for %d HP" % [att_name, def_name, prim.get("damage", 0)]

	if ctr.has("damage"):
		log_str += " | Counter: %d HP" % ctr["damage"]
	if result.get("defender_killed", false):
		log_str += " ➔ ☠️ %s DIED!" % def_name

	_update_hud_text(log_str)
	_refresh_overlay()


## A forest burned down. GridManager already rewrote the terrain; the tree
## standing on it has to go too, or the map would still promise cover it no
## longer gives.
func _on_terrain_changed(cell: Vector2i, new_terrain: int) -> void:
	if new_terrain == GameConfig.TerrainType.SCORCHED and is_instance_valid(map_builder):
		map_builder.clear_decor_at(cell)
	# Movement ranges are terrain-dependent, so a live selection is now stale.
	if selected_unit:
		_select_unit(selected_unit)
	_refresh_overlay()


func _on_vision_updated(_faction_id: int) -> void:
	_refresh_overlay()


func _on_surrender_triggered(unit: Node) -> void:
	var unit_name: String = "A unit"
	if unit is TacticalUnit and is_instance_valid(unit.unit_data):
		unit_name = unit.unit_data.unit_name
	_update_hud_text("🏳️ %s has broken and surrendered!" % unit_name)


func _on_surrender_choice_made(unit: Node, choice: String) -> void:
	if is_instance_valid(morale_manager) and unit is TacticalUnit:
		morale_manager.resolve_surrender(unit, choice)
	_update_hud_text(
		"⚔️ Prisoner pressed into service." if choice == "capture"
		else "💰 Prisoner ransomed for gold."
	)
	_refresh_overlay()


func _on_dialogue_generated(speaker_name: String, text: String, _emotion: String) -> void:
	_update_hud_text("💬 [%s]: %s" % [speaker_name, text])


func _on_story_event_narrated(title: String, body: String) -> void:
	_update_hud_text("📜 [%s]: %s" % [title, body])


## Hand the overlay everything it paints. The controller stays the single owner
## of what is selected and where the cursor is; the overlay keeps no copy that
## could fall out of step with it.
func _refresh_overlay() -> void:
	if not is_instance_valid(grid_overlay):
		return
	grid_overlay.refresh(
		reachable_cells,
		attackable_cells,
		selected_unit.grid_position if is_instance_valid(selected_unit) else GridOverlay.NO_CELL,
		selected_building.grid_position if is_instance_valid(selected_building) else GridOverlay.NO_CELL,
		hovered_cell,
	)
