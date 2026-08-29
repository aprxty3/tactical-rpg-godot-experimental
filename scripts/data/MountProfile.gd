extends Resource
class_name MountProfile
## MountProfile — what changes when a rider gets on or off its horse.
##
## Deltas from the mounted baseline, not two stat blocks, so the unit's `.tres`
## stays the only place its numbers live.
##
## Units start MOUNTED: a Lancer's `movement_points = 5` IS the mounted speed,
## so dismounting subtracts rather than the base describing a rare state.

## Class while mounted — feeds the advantage triangle.
@export var mounted_class: String = "Cavalry"
## ...and on foot: loses the Cavalry charge bonus and reads as Melee.
@export var dismounted_class: String = "Melee"

## Movement given up by dismounting — a horse is mostly speed.
@export var dismount_move_penalty: int = 2
## Defence gained on foot. This is what makes dismounting a choice rather than
## a strict downgrade.
@export var dismount_defense_bonus: int = 4
