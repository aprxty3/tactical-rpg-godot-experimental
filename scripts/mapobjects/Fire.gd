extends MapObject
class_name Fire
## Fire — a burning cell. Damages whoever stands in it, tries to spread each
## round, and burns out after GameConfig.FIRE_LIFETIME_TICKS.
##
## Fire is what makes forest cover a gamble rather than a free bonus: the same
## trees that soak damage and hide a unit are also the only terrain that really
## catches, and a burnt-out forest is downgraded to SCORCHED for the rest of the
## match. Spread and terrain changes are MapObjectManager's call.

const FIRE_TEXTURE: String = "res://assets/effects/Fire/Fire.png"
## 896x128 sheet — seven 128px frames in a single row.
const FIRE_HFRAMES: int = 7

var ticks_remaining: int = GameConfig.FIRE_LIFETIME_TICKS

var _sprite: Sprite2D


func _ready() -> void:
	super()
	_build_flame()
	EventBus.fire_ignited.emit(grid_position)


func _build_flame() -> void:
	var texture: Texture2D = load(FIRE_TEXTURE) as Texture2D
	if not is_instance_valid(texture):
		return

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = FIRE_HFRAMES
	_sprite.frame = 0
	# One frame is 128px tall; a flame slightly taller than its tile reads best.
	_sprite.scale = Vector2.ONE * (72.0 / float(texture.get_height()))
	_sprite.z_index = 2
	add_child(_sprite)

	# Cycle the sheet by tweening `frame` — no AnimationPlayer needed for a
	# seven-frame loop, and it keeps the object a single self-contained node.
	var tween := create_tween().set_loops()
	tween.tween_method(_set_flame_frame, 0.0, float(FIRE_HFRAMES), 0.7)


func _set_flame_frame(value: float) -> void:
	if is_instance_valid(_sprite):
		_sprite.frame = clampi(int(value), 0, FIRE_HFRAMES - 1)


## Anything walking into the flames is burnt on entry, not just at round end.
func on_unit_entered(unit: TacticalUnit) -> void:
	_burn(unit)


func on_round_tick() -> void:
	if _spent:
		return

	if is_instance_valid(manager):
		if manager.has_method("unit_at"):
			_burn(manager.unit_at(grid_position))
		if manager.has_method("spread_fire_from"):
			manager.spread_fire_from(grid_position)

	ticks_remaining -= 1
	if ticks_remaining <= 0:
		_burn_out()


func _burn(unit: TacticalUnit) -> void:
	if is_instance_valid(unit):
		unit.take_damage(GameConfig.FIRE_DAMAGE, "fire")


## Burning out is where fire permanently rewrites the map: forest becomes
## scorched earth and loses its cover, concealment and ambush for good.
func _burn_out() -> void:
	if is_instance_valid(manager) and manager.has_method("extinguish_fire_at"):
		manager.extinguish_fire_at(grid_position)
	consume(0.5)
