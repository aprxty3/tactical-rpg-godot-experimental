extends MapObject
class_name Chest
## Chest — Pandora's Box. A one-shot treasure that resolves into one of four
## outcomes when a unit steps on it: war spoils, a mercenary, a trap, or the
## awakened dead. The odds live in GameConfig and the outcome is rolled by
## MapObjectManager, which is the only thing holding the economy and spawn
## references; this script owns nothing but the lid.

const CLOSED_TEXTURE: String = "res://assets/items/traps_and_items/chest/chest_1.png"
const OPEN_TEXTURE: String = "res://assets/items/traps_and_items/chest/chest_open_1.png"

var _sprite: Sprite2D


func _ready() -> void:
	super()
	_sprite = _make_sprite(CLOSED_TEXTURE)
	_start_shimmer()


## A gentle bob, so treasure reads as interactive rather than as scenery.
func _start_shimmer() -> void:
	if not is_instance_valid(_sprite):
		return
	var tween := create_tween().set_loops()
	tween.tween_property(_sprite, "position:y", -6.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_sprite, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func on_unit_entered(unit: TacticalUnit) -> void:
	if _spent or not is_instance_valid(unit):
		return
	# Flip the lid before consuming so the player sees what they opened.
	if is_instance_valid(_sprite):
		var opened: Texture2D = load(OPEN_TEXTURE) as Texture2D
		if is_instance_valid(opened):
			_sprite.texture = opened

	if is_instance_valid(manager) and manager.has_method("open_chest"):
		manager.open_chest(self, unit)
	consume(0.6)
