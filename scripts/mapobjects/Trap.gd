extends MapObject
class_name Trap
## Trap — a buried mine. Invisible until something stands on it.
##
## The only MapObject with no sprite. Chests and kegs are landmarks to route
## around; a trap punishes a route that looked safe, so drawing it at all would
## defeat it. No reveal, no adjacency tell — the AI walks the same blind map,
## which is the only thing making an invisible hazard fair.
##
## `consume()` still runs (it unregisters and frees), it just fades nothing.
##
## The blast belongs to MapObjectManager, which knows the grid and the roster.
## This object only knows it was stepped on.


func _ready() -> void:
	super()
	add_to_group("traps")
	# No _make_sprite() call, deliberately. See the class comment.


func on_unit_entered(unit: TacticalUnit) -> void:
	spring(unit)


## Idempotent through `_spent`. `trigger` is passed through because whoever trod
## on the mine is hit by definition — their walk has already finished, so they
## are usually clear of the footprint by the time this runs.
func spring(trigger: TacticalUnit = null) -> void:
	if _spent:
		return
	if is_instance_valid(manager) and manager.has_method("spring_trap_at"):
		manager.spring_trap_at(grid_position, trigger)
	else:
		consume()
