extends MapObject
class_name Barrel
## Barrel — a powder keg parked beside a chokepoint.
##
## Detonates when a unit walks into it, when an attack targets it, or when it is
## caught in another barrel's blast. It does NOT block movement: an obstacle
## sitting in a bridge approach could wall off a crossing entirely, and a keg
## you can shoot is more interesting than a keg you must walk around.
##
## The blast itself — damage, chaining, and the fires it starts — belongs to
## MapObjectManager, which knows the grid and the roster.

const BARREL_TEXTURE: String = "res://assets/items/traps_and_items/box_1/box_1_1.png"
## The art pack ships plain crates; a rusty-red wash is what tells the player
## this particular crate is worth shooting.
const POWDER_TINT: Color = Color(1.25, 0.62, 0.48)

var _sprite: Sprite2D


func _ready() -> void:
	super()
	_sprite = _make_sprite(BARREL_TEXTURE)
	if is_instance_valid(_sprite):
		_sprite.modulate = POWDER_TINT


func on_unit_entered(_unit: TacticalUnit) -> void:
	detonate()


## Ask the manager to run the explosion centred on this cell. The manager
## consumes this barrel first, so the chain can never come back around to it.
## Barrels caught in someone else's blast are picked up by that same chain
## walk, which is why there is no separate "I was exploded" entry point.
func detonate() -> void:
	if _spent:
		return
	if is_instance_valid(manager) and manager.has_method("detonate_at"):
		manager.detonate_at(grid_position)
	else:
		consume()
