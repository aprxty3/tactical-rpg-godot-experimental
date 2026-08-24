extends Node2D
class_name TacticalUnit
## TacticalUnit — Actor layer node for units on the battlefield.
## Holds a reference to UnitData (data layer) and communicates
## via EventBus (event layer). No direct manager references.

@export var unit_data: UnitData
@export var faction_id: int = 0

# === Runtime State (not saved in Resource) ===
var current_health: int = 0
var current_movement: int = 0
var has_acted: bool = false
var grid_position: Vector2i = Vector2i.ZERO

## Morale as a 0..100 scalar. GameConfig.MoraleLevel is derived from it rather
## than stored, so there is one source of truth and tuning happens on the
## scalar. MoraleManager is the only thing that should write this.
var morale: int = GameConfig.MORALE_DEFAULT
## Set while this unit has broken and is awaiting its captor's decision. A
## surrendering unit is frozen: it cannot act, move, or be attacked again.
var pending_surrender: bool = false

## Which of the five authored facings this unit is showing. The three left-hand
## directions are these same sheets flipped, which is why there are five names
## and eight directions.
var facing: String = "Down"

## Riders start in the saddle: a cavalry unit's stat block describes its mounted
## form, so this is the state its own numbers already assume. Meaningless (and
## never toggled) on units without a mount_profile.
var is_mounted: bool = true

# === Node References ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# === Overhead HP Bar Components ===
var hp_bar: ProgressBar
var hp_label: Label
var _hp_tween: Tween
var _fill_style: StyleBoxFlat
var _hp_bg_style: StyleBoxFlat

# === Overhead Morale Strip ===
var morale_bar: ColorRect
var morale_fill: ColorRect


func _ready() -> void:
	# Mirrors Building's "buildings" group: lets VisionManager and
	# MapObjectManager sweep every unit on the field without depending on
	# TurnManager having registered it first.
	add_to_group("units")

	if unit_data:
		_initialize_from_data()
	
	_setup_default_animations()
	_setup_health_bar()
	_setup_morale_bar()


## Setup standard TinySwords animation frames dynamically based on unit archetype
func _setup_default_animations() -> void:
	if not animation_player or not sprite:
		return
		
	var lib = AnimationLibrary.new()
	var create_anim = func(anim_name: String, row: int, frame_count: int, loop: bool, speed: float):
		var anim = Animation.new()
		anim.length = frame_count * speed
		if loop:
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE
		var track_idx = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, "Sprite2D:frame")
		var max_frame = (sprite.hframes * sprite.vframes) - 1
		for i in range(frame_count):
			var target_frame = min((row * sprite.hframes) + i, max_frame)
			anim.track_insert_key(track_idx, i * speed, target_frame)
		lib.add_animation(anim_name, anim)
		
	if sprite.vframes == 7 and sprite.hframes == 8:
		# TinySwords Archer layout (8 columns x 7 rows)
		create_anim.call("idle", 0, 6, true, 0.15)
		create_anim.call("run", 1, 6, true, 0.1)
		create_anim.call("attack", 3, 8, false, 0.08) # Row 3 is Shoot Front
	elif sprite.vframes >= 6:
		# Standard TinySwords Warrior (6x8) or Pawn (6x6)
		create_anim.call("idle", 0, 6, true, 0.15)
		create_anim.call("run", 1, 6, true, 0.1)
		create_anim.call("attack", 2, 6, false, 0.1)
	elif sprite.vframes >= 2:
		# Compact derived sheets (scripts_dev/generate_sprites.py):
		# row 0 = idle, row 1 = run. Attack replays the run row faster.
		var cols := maxi(1, sprite.hframes)
		create_anim.call("idle", 0, cols, true, 0.16)
		create_anim.call("run", 1, cols, true, 0.09)
		create_anim.call("attack", 1, cols, false, 0.07)
	else:
		# Single-row strip sheets (legacy / static icons)
		var frames = maxi(1, sprite.hframes)
		create_anim.call("idle", 0, frames, true, 0.15)
		create_anim.call("run", 0, frames, true, 0.1)
		create_anim.call("attack", 0, frames, false, 0.1)
	
	if animation_player.has_animation_library(""):
		animation_player.remove_animation_library("")
	animation_player.add_animation_library("", lib)
	animation_player.play("idle")


## Play a specific animation if it exists.
##
## For units with per-direction attack sheets this also swaps the texture to the
## one matching `facing`, then swaps back for any other animation. The swap is
## confined to this one function on purpose: callers keep saying
## `play_animation("attack")` and neither know nor care that cavalry is special.
func play_animation(anim_name: String) -> void:
	if not animation_player:
		return
	if anim_name == "attack" and has_directional_art():
		_apply_directional_attack_sheet()
	elif _using_directional_sheet:
		_restore_base_sheet()

	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


## True while the Sprite2D is showing a directional sheet instead of the unit's
## base spritesheet, so the restore only runs when there is something to undo.
var _using_directional_sheet: bool = false


func _apply_directional_attack_sheet() -> void:
	if not sprite or not is_instance_valid(unit_data):
		return
	sprite.texture = unit_data.directional_attack[facing]
	sprite.hframes = maxi(1, unit_data.directional_attack_hframes)
	sprite.vframes = 1
	_using_directional_sheet = true
	_setup_default_animations()


func _restore_base_sheet() -> void:
	if not sprite or not is_instance_valid(unit_data):
		return
	if not is_instance_valid(unit_data.spritesheet):
		return
	sprite.texture = unit_data.spritesheet
	sprite.hframes = unit_data.hframes
	sprite.vframes = unit_data.vframes
	_using_directional_sheet = false
	_setup_default_animations()


## Make the unit face a specific global position.
##
## Always sets flip_h, which is the whole behaviour for units without
## directional art — unchanged from before, and the reason none of the existing
## resources needed touching. Units that DO have per-direction sheets also
## record which of the five authored facings applies, so the attack animation
## can pick the matching one.
func face_direction(target_global_pos: Vector2) -> void:
	if not sprite:
		return
	var delta: Vector2 = target_global_pos - global_position
	sprite.flip_h = delta.x < 0.0
	facing = _facing_for(delta)


## Map a direction vector onto one of the five authored facings.
##
## Only the magnitudes matter for the choice; the sign of x is carried by
## flip_h. The 2.4 ratio splits "mostly vertical" from "diagonal": a shallower
## split made a unit attacking one tile up and one tile across read as straight
## up, which looks wrong next to the tile it is actually hitting.
func _facing_for(delta: Vector2) -> String:
	var ax: float = absf(delta.x)
	var ay: float = absf(delta.y)
	if ax <= 0.001 and ay <= 0.001:
		return facing  # no movement — keep whatever we were showing
	if ay > ax * 2.4:
		return "Up" if delta.y < 0.0 else "Down"
	if ax > ay * 2.4:
		return "Right"
	return "UpRight" if delta.y < 0.0 else "DownRight"


## Does this unit have an authored sheet for the way it is currently facing?
func has_directional_art() -> bool:
	return (
		is_instance_valid(unit_data)
		and not unit_data.directional_attack.is_empty()
		and unit_data.directional_attack.has(facing)
		and is_instance_valid(unit_data.directional_attack[facing])
	)


# ==============================================================================
# MOUNT — riders on and off the horse
# ==============================================================================
#
# Everything below reads through the profile and falls back to the plain stat
# block when there is none. That is what lets 84 of the 85 unit resources ignore
# the mount system entirely: no profile means get_effective_* returns exactly
# what get_* always returned.

## Can this unit get on and off a horse at all?
func can_mount() -> bool:
	return is_instance_valid(unit_data) and unit_data.mount_profile is MountProfile


## The class this unit actually fights as right now.
##
## Combat must ask this rather than reading `unit_data.unit_class` directly, or
## a dismounted Lancer would still be scored as Cavalry and keep the charge
## bonus it no longer has a horse for.
func get_effective_class() -> String:
	if not is_instance_valid(unit_data):
		return "Worker"
	if not can_mount():
		return unit_data.unit_class
	var profile: MountProfile = unit_data.mount_profile
	return profile.mounted_class if is_mounted else profile.dismounted_class


## Defence including the on-foot bonus.
func get_effective_defense() -> int:
	if not is_instance_valid(unit_data):
		return 0
	var base: int = unit_data.defense_power
	if can_mount() and not is_mounted:
		base += (unit_data.mount_profile as MountProfile).dismount_defense_bonus
	return base


## Movement points including the on-foot penalty. Floors at 1 — a dismounted
## rider is slow, never rooted, because a unit that cannot move at all could be
## stranded permanently by a single bad toggle.
func get_effective_movement() -> int:
	if not is_instance_valid(unit_data):
		return 0
	var base: int = unit_data.movement_points
	if can_mount() and not is_mounted:
		base -= (unit_data.mount_profile as MountProfile).dismount_move_penalty
	return maxi(1, base)


## Get on or off the horse. Returns false when the unit cannot or may not.
##
## Costs the unit's action for the turn. Without that price a rider could stand
## in place swapping between Cavalry and Melee to present whichever class beats
## whatever is attacking it — dodging the advantage triangle for free, which is
## the one thing the triangle exists to prevent.
func toggle_mount() -> bool:
	if not can_mount() or pending_surrender or not can_act():
		return false

	is_mounted = not is_mounted
	# Re-cap movement so the change lands this turn, but never hand back points
	# already spent walking.
	current_movement = mini(current_movement, get_effective_movement())
	consume_action()
	_show_floating_indicator(
		"MOUNTED" if is_mounted else "ON FOOT",
		Color(0.85, 0.9, 1.0)
	)
	return true



## Initialize runtime state from UnitData resource.
func _initialize_from_data() -> void:
	if not unit_data:
		return

	current_health = unit_data.max_health
	current_movement = get_effective_movement()
	has_acted = false
	morale = GameConfig.MORALE_DEFAULT
	pending_surrender = false
	_update_visuals()
	_update_health_bar(false)
	_update_morale_bar()


## Reset movement and action points at the start of a new turn.
func reset_for_new_turn() -> void:
	if unit_data:
		current_movement = get_effective_movement()
		has_acted = false


## Apply damage to this unit. Emits signals via EventBus.
## Returns true if the unit died.
func take_damage(amount: int, damage_type: String = "normal") -> bool:
	current_health -= amount
	_update_health_bar(true)
	_flash_damage()
	_show_floating_indicator("-%d" % amount, Color(1.0, 0.25, 0.25))
	EventBus.unit_damaged.emit(self, amount, damage_type)

	if current_health <= 0:
		current_health = 0
		_handle_death(damage_type)
		return true
	return false


## Heal this unit by the given amount (capped at max_health).
func heal(amount: int) -> void:
	if not unit_data:
		return
	var old_health := current_health
	current_health = mini(current_health + amount, unit_data.max_health)
	var actual_healed := current_health - old_health
	if actual_healed > 0:
		_update_health_bar(true)
		_show_floating_indicator("+%d" % actual_healed, Color(0.25, 1.0, 0.35))
		EventBus.unit_healed.emit(self, actual_healed)


func _flash_damage() -> void:
	if not sprite:
		return
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color(2.0, 0.4, 0.4), 0.08)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func _show_floating_indicator(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.position = Vector2(-20, -70)
	add_child(label)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


## Swap UnitData resource for an upgraded version.
## Proportionally scales HP so upgrades feel fair.
func upgrade_to(new_data: UnitData) -> void:
	if not unit_data or not new_data:
		return

	var old_data := unit_data
	var hp_ratio := float(current_health) / float(unit_data.max_health)

	unit_data = new_data
	current_health = int(hp_ratio * unit_data.max_health)
	current_movement = get_effective_movement()

	_update_visuals()
	_update_health_bar(false)
	# A promotion is a shot in the arm — and it also re-evaluates immunity, so
	# the strip has to be refreshed either way.
	adjust_morale(GameConfig.MORALE_KILL_BONUS)
	_update_morale_bar()
	if animation_player and animation_player.has_animation("level_up_effect"):
		animation_player.play("level_up_effect")

	EventBus.unit_upgraded.emit(self, old_data, new_data)


## Consume movement points when moving on the grid.
## Returns true if the unit has enough points to move.
func consume_movement(cost: int) -> bool:
	if current_movement >= cost:
		current_movement -= cost
		return true
	return false


## Mark this unit as having used its action for this turn.
func consume_action() -> void:
	has_acted = true


## Check if this unit can still act this turn.
func can_act() -> bool:
	return not has_acted and not pending_surrender


## Check if this unit can still move this turn.
func can_move() -> bool:
	return current_movement > 0 and not pending_surrender


# === Morale ===

## Current morale band. Undead never waver, so they read as FAIR forever and
## every multiplier lands on 1.0 without a special case at each call site.
func get_morale_level() -> GameConfig.MoraleLevel:
	if is_morale_immune():
		return GameConfig.MoraleLevel.FAIR
	return GameConfig.morale_level_for(morale)


func is_morale_immune() -> bool:
	return is_instance_valid(unit_data) and unit_data.is_morale_immune()


## Attack output multiplier from the unit's current morale band.
func get_morale_attack_mult() -> float:
	return float(GameConfig.MORALE_ATTACK_MULT.get(get_morale_level(), 1.0))


## Shift morale by `delta`, clamped to 0..MORALE_MAX. Emits morale_changed only
## when the band actually crossed, so listeners fire on meaningful shifts rather
## than on every point. Returns the new level.
func adjust_morale(delta: int) -> GameConfig.MoraleLevel:
	if is_morale_immune() or delta == 0:
		return get_morale_level()

	var old_level := get_morale_level()
	morale = clampi(morale + delta, 0, GameConfig.MORALE_MAX)
	var new_level := get_morale_level()
	_update_morale_bar()

	if new_level != old_level:
		_show_floating_indicator(
			GameConfig.MORALE_LABEL.get(new_level, "?"),
			GameConfig.MORALE_COLOR.get(new_level, Color.WHITE),
		)
		EventBus.morale_changed.emit(self, old_level, new_level)
	return new_level


## Defect to a new faction without dying.
##
## The unit adopts the new owner's own art where a `{role}_{faction}` variant
## exists, and arrives shaken and spent — capturing an enemy should not also
## hand you a free extra action this turn. TurnManager re-buckets it off the
## unit_captured signal, keeping this an actor-only concern.
func change_faction(new_faction_id: int) -> void:
	if faction_id == new_faction_id:
		return

	var old_faction := faction_id
	faction_id = new_faction_id

	if is_instance_valid(unit_data):
		var variant := UnitData.variant_for_faction(unit_data, new_faction_id)
		if variant != unit_data:
			unit_data = variant
			_update_visuals()

	pending_surrender = false
	has_acted = true
	current_movement = 0
	morale = GameConfig.MORALE_AFTER_CAPTURE

	_apply_hp_bar_faction_color()
	_update_health_bar(false)
	_update_morale_bar()

	EventBus.unit_captured.emit(self, old_faction, new_faction_id)


# === Private Methods ===

func _setup_health_bar() -> void:
	hp_bar = ProgressBar.new()
	hp_bar.name = "FloatingHPBar"
	hp_bar.show_percentage = false
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.custom_minimum_size = Vector2(70, 10)
	hp_bar.size = Vector2(70, 10)
	hp_bar.position = Vector2(-35, -55)
	
	# Background style — the border carries the owner's colour, which is how a
	# defecting unit reads as having changed sides.
	_hp_bg_style = StyleBoxFlat.new()
	_hp_bg_style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	_hp_bg_style.set_border_width_all(1)
	_hp_bg_style.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", _hp_bg_style)
	_apply_hp_bar_faction_color()
	
	# Fill style
	_fill_style = StyleBoxFlat.new()
	_fill_style.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("fill", _fill_style)
	
	# Number label
	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_label.size = hp_bar.size
	hp_label.position = Vector2.ZERO
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.add_theme_constant_override("outline_size", 3)
	hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_bar.add_child(hp_label)
	
	add_child(hp_bar)
	_update_health_bar(false)


func _apply_hp_bar_faction_color() -> void:
	if not _hp_bg_style:
		return
	var tint: Color = GameConfig.FACTION_TINT_COLORS.get(faction_id, Color(0.7, 0.7, 0.75))
	_hp_bg_style.border_color = Color(tint.r, tint.g, tint.b, 0.95)


func _update_health_bar(animate: bool = false) -> void:
	if not hp_bar or not is_instance_valid(unit_data):
		return
	
	var max_hp: int = unit_data.max_health
	hp_bar.max_value = max_hp
	
	var ratio: float = float(current_health) / float(max_hp) if max_hp > 0 else 0.0
	
	# Dynamic color: Green (> 50%) -> Amber/Yellow (25%-50%) -> Bright Red (<= 25% - Sekarat!)
	var bar_color: Color
	if ratio > 0.5:
		bar_color = Color(0.2, 0.85, 0.35)
	elif ratio > 0.25:
		bar_color = Color(0.95, 0.7, 0.15)
	else:
		bar_color = Color(0.95, 0.2, 0.2)
		
	if _fill_style:
		_fill_style.bg_color = bar_color
	
	if hp_label:
		if ratio <= 0.25 and current_health > 0:
			hp_label.text = "⚠️ %d/%d" % [maxi(0, current_health), max_hp]
		else:
			hp_label.text = "%d/%d" % [maxi(0, current_health), max_hp]
	
	if animate:
		if _hp_tween and _hp_tween.is_valid():
			_hp_tween.kill()
		_hp_tween = create_tween()
		_hp_tween.set_ease(Tween.EASE_OUT)
		_hp_tween.set_trans(Tween.TRANS_QUAD)
		_hp_tween.tween_property(hp_bar, "value", float(maxi(0, current_health)), 0.25)
	else:
		hp_bar.value = float(maxi(0, current_health))


## A thin strip under the HP bar. Deliberately not a second numeric readout —
## the exact scalar belongs in the inspector panel; on the battlefield the
## player only needs to see at a glance which units are about to break.
func _setup_morale_bar() -> void:
	morale_bar = ColorRect.new()
	morale_bar.name = "MoraleStrip"
	morale_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	morale_bar.color = Color(0.08, 0.08, 0.1, 0.85)
	morale_bar.size = Vector2(70, 4)
	morale_bar.position = Vector2(-35, -43)

	morale_fill = ColorRect.new()
	morale_fill.name = "Fill"
	morale_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	morale_fill.position = Vector2.ZERO
	morale_fill.size = Vector2(70, 4)
	morale_bar.add_child(morale_fill)

	add_child(morale_bar)
	_update_morale_bar()


func _update_morale_bar() -> void:
	if not is_instance_valid(morale_bar):
		return
	# Undead have no morale to show, so they get no strip at all.
	if is_morale_immune():
		morale_bar.visible = false
		return

	morale_bar.visible = true
	var level := get_morale_level()
	var ratio: float = clampf(float(morale) / float(GameConfig.MORALE_MAX), 0.0, 1.0)
	morale_fill.size = Vector2(70.0 * ratio, 4)
	morale_fill.color = GameConfig.MORALE_COLOR.get(level, Color.WHITE)


## Walk off the battlefield without being killed — a morale break rather than a
## wound. Routed through the same removal path as a death so every listener
## (grid occupancy, rosters, capacity) unregisters the unit exactly once.
func desert() -> void:
	if current_health <= 0:
		return
	current_health = 0
	_show_floating_indicator("DESERTED", GameConfig.MORALE_COLOR[GameConfig.MoraleLevel.FEARFUL])
	_handle_death("desertion")


func _handle_death(damage_type: String) -> void:
	match damage_type:
		"starvation", "desertion":
			EventBus.unit_deserted.emit(self)
		_:
			EventBus.unit_died.emit(self, damage_type)

	# Smooth death effect: fade out and dissolve
	if sprite:
		var death_tween = create_tween()
		death_tween.set_parallel(true)
		death_tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
		death_tween.tween_property(sprite, "scale", sprite.scale * 0.8, 0.35)
		if hp_bar:
			death_tween.tween_property(hp_bar, "modulate:a", 0.0, 0.2)
		death_tween.chain().tween_callback(queue_free)
	else:
		queue_free()


func _update_visuals() -> void:
	if not unit_data or not sprite:
		return
	if is_instance_valid(unit_data.spritesheet):
		sprite.texture = unit_data.spritesheet
		sprite.hframes = unit_data.hframes
		sprite.vframes = unit_data.vframes
		_setup_default_animations()
	elif unit_data.sprite_frames and sprite:
		pass
	_apply_sprite_metrics()


## Normalize on-screen size across wildly different source art.
## Frames range from 16x16 icons to 320x320 TinySwords sheets, so the node
## itself stays at scale 1.0 and the Sprite2D carries a per-unit scale baked
## from the art's real content bounding box (UnitData.sprite_scale/offset).
func _apply_sprite_metrics() -> void:
	if not sprite or not unit_data:
		return
	var s: float = unit_data.sprite_scale
	if s <= 0.0:
		s = 1.0
	sprite.scale = Vector2(s, s)
	sprite.offset = unit_data.sprite_offset
