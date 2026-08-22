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


func _ready() -> void:
	if unit_data:
		_initialize_from_data()


## Initialize runtime state from UnitData resource.
func _initialize_from_data() -> void:
	current_health = unit_data.max_health
	current_movement = unit_data.movement_points
	has_acted = false
	_update_visuals()


## Reset movement and action points at the start of a new turn.
func reset_for_new_turn() -> void:
	if unit_data:
		current_movement = unit_data.movement_points
		has_acted = false


## Apply damage to this unit. Emits signals via EventBus.
## Returns true if the unit died.
func take_damage(amount: int, damage_type: String = "normal") -> bool:
	current_health -= amount
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

func _handle_death(damage_type: String) -> void:
	match damage_type:
		"starvation":
			EventBus.unit_deserted.emit(self)
		_:
			EventBus.unit_died.emit(self, damage_type)
	queue_free()


func _update_visuals() -> void:
	if not unit_data:
		return
	# Apply sprite frames from UnitData if available
	if unit_data.sprite_frames and sprite:
		# For animated sprites, assign texture from first frame
		pass
	# Additional visual updates (palette swap, shader) go here
