extends MapObject
class_name Trap
## Trap — a buried mine. Invisible until something stands on it.
##
## The only MapObject with no sprite at all. `Chest` and `Barrel` are landmarks
## you route around; a trap is the opposite — it exists to punish a route that
## looked safe, so drawing it, even faintly, would defeat it. There is no reveal
## mechanic and no adjacency tell: the AI walks the same blind map the player
## does, which is the only reason an invisible hazard is fair.
##
## Because it renders nothing, the base class's fade-out `consume()` has nothing
## to fade. It still runs — it is what unregisters the object and frees the node
## — the fade simply animates an empty Node2D for a quarter second.
##
## The blast itself (footprint, damage, the fires it starts) belongs to
## MapObjectManager, which knows the grid and the roster. This object only knows
## that it was stepped on.


func _ready() -> void:
	super()
	add_to_group("traps")
	# No _make_sprite() call, deliberately. See the class comment.


func on_unit_entered(unit: TacticalUnit) -> void:
	spring(unit)


## Fire the trap. Idempotent through `_spent`, so a unit that somehow enters
## twice in one frame cannot detonate the same mine twice.
##
## `trigger` is carried through to the blast because whoever trod on the mine is
## hit by definition — by the time this runs their walk animation has finished
## and they are usually standing clear of the footprint, so a blast that only
## looked at the footprint left the one who set it off untouched.
func spring(trigger: TacticalUnit = null) -> void:
	if _spent:
		return
	if is_instance_valid(manager) and manager.has_method("spring_trap_at"):
		manager.spring_trap_at(grid_position, trigger)
	else:
		consume()
