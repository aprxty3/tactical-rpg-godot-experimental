extends Node2D
class_name MapObject
## MapObject — Actor layer base for anything that sits on a single battlefield
## cell and reacts to the battle around it: treasure, explosives, fire.
##
## All three answer the same two questions — what happens when a unit steps
## here, and what happens each round — so they share one base rather than three
## near-identical scripts.
## Subclasses stay small and hold no manager references of their own: anything
## needing gold, units or terrain calls back through `manager`, which is
## injected by MapObjectManager when the object is spawned.

## Cell this object occupies. Set by MapObjectManager at spawn time.
@export var grid_position: Vector2i = Vector2i.ZERO

## Injected by MapObjectManager. Subclasses use it to reach the game systems.
var manager: Node = null

## Cleared once the object has been consumed, so a chest opened by two units in
## the same frame — or a barrel caught by two blasts — only fires once.
var _spent: bool = false


func _ready() -> void:
	add_to_group("map_objects")


## A unit finished a move onto this object's cell.
func on_unit_entered(_unit: TacticalUnit) -> void:
	pass


## One game round has passed (every faction has taken a turn).
func on_round_tick() -> void:
	pass


## Has this object already fired? Guards every one-shot interaction.
func is_spent() -> bool:
	return _spent


## Mark used and fade out. Idempotent: calling it twice does nothing the second
## time, which is what makes chain reactions safe.
func consume(fade: float = 0.25) -> void:
	if _spent:
		return
	_spent = true
	if is_instance_valid(manager) and manager.has_method("unregister_object"):
		manager.unregister_object(self)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, fade)
	tween.tween_property(self, "scale", scale * 0.7, fade)
	tween.chain().tween_callback(queue_free)


## Build the object's sprite from a 16x16-style icon, scaled to read clearly on
## a 64px tile. Shared here because all three subclasses need the same maths.
func _make_sprite(texture_path: String, target_px: float = 38.0) -> Sprite2D:
	var texture: Texture2D = load(texture_path) as Texture2D
	if not is_instance_valid(texture):
		return null

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * (target_px / float(maxi(1, texture.get_height())))
	add_child(sprite)
	return sprite
