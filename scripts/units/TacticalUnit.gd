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

# === Node References ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# === Overhead HP Bar Components ===
var hp_bar: ProgressBar
var hp_label: Label
var _hp_tween: Tween
var _fill_style: StyleBoxFlat


func _ready() -> void:
	if unit_data:
		_initialize_from_data()
	
	_setup_default_animations()
	_setup_health_bar()


## Setup standard TinySwords animation frames (6x6 or custom sprite sheet)
func _setup_default_animations() -> void:
	if not animation_player or not sprite:
		return
		
	var lib = AnimationLibrary.new()
	var create_anim = func(anim_name: String, row: int, frame_count: int, loop: bool, speed: float):
		var anim = Animation.new()
		anim.length = frame_count * speed
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		var track_idx = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, "Sprite2D:frame")
		var max_frame = (sprite.hframes * sprite.vframes) - 1
		for i in range(frame_count):
			var target_frame = min((row * sprite.hframes) + i, max_frame)
			anim.track_insert_key(track_idx, i * speed, target_frame)
		lib.add_animation(anim_name, anim)
		
	# Dynamic animation mapping based on sheet dimensions
	create_anim.call("idle", 0, mini(sprite.hframes, 6), true, 0.15)
	create_anim.call("run", mini(1, sprite.vframes - 1), mini(sprite.hframes, 6), true, 0.1)
	create_anim.call("attack", mini(2, sprite.vframes - 1), mini(sprite.hframes, 6), false, 0.1)
	
	if animation_player.has_animation_library(""):
		animation_player.remove_animation_library("")
	animation_player.add_animation_library("", lib)
	animation_player.play("idle")


## Play a specific animation if it exists
func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


## Make the unit face a specific global position (flips horizontal)
func face_direction(target_global_pos: Vector2) -> void:
	if sprite:
		sprite.flip_h = target_global_pos.x < global_position.x



## Initialize runtime state from UnitData resource.
func _initialize_from_data() -> void:
	current_health = unit_data.max_health
	current_movement = unit_data.movement_points
	has_acted = false
	_update_visuals()
	_update_health_bar(false)


## Reset movement and action points at the start of a new turn.
func reset_for_new_turn() -> void:
	if unit_data:
		current_movement = unit_data.movement_points
		has_acted = false


## Apply damage to this unit. Emits signals via EventBus.
## Returns true if the unit died.
func take_damage(amount: int, damage_type: String = "normal") -> bool:
	current_health -= amount
	_update_health_bar(true)
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
		EventBus.unit_healed.emit(self, actual_healed)


## Swap UnitData resource for an upgraded version.
## Proportionally scales HP so upgrades feel fair.
func upgrade_to(new_data: UnitData) -> void:
	if not unit_data or not new_data:
		return

	var old_data := unit_data
	var hp_ratio := float(current_health) / float(unit_data.max_health)

	unit_data = new_data
	current_health = int(hp_ratio * unit_data.max_health)
	current_movement = unit_data.movement_points

	_update_visuals()
	_update_health_bar(false)
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
	return not has_acted


## Check if this unit can still move this turn.
func can_move() -> bool:
	return current_movement > 0


# === Private Methods ===

func _setup_health_bar() -> void:
	hp_bar = ProgressBar.new()
	hp_bar.name = "FloatingHPBar"
	hp_bar.show_percentage = false
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.custom_minimum_size = Vector2(70, 10)
	hp_bar.size = Vector2(70, 10)
	hp_bar.position = Vector2(-35, -55)
	
	# Background style
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	bg_style.border_color = Color(0.8, 0.2, 0.2, 0.95) if faction_id != 0 else Color(0.2, 0.5, 0.9, 0.95)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	
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


func _handle_death(damage_type: String) -> void:
	match damage_type:
		"starvation":
			EventBus.unit_deserted.emit(self)
		_:
			EventBus.unit_died.emit(self, damage_type)
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
