extends Resource
class_name MountProfile
## MountProfile — what changes when a rider gets on or off its horse.
##
## Pure data, no logic: a Resource in the Data layer, read by TacticalUnit.
## Stored as deltas from the unit's mounted baseline rather than as two full
## stat blocks, so a Lancer's `.tres` stays the single place its numbers live
## and there is no second copy to forget to update.
##
## Units start MOUNTED. That is the natural reading of a cavalry unit's own stat
## block — `movement_points = 5` on a Lancer is the mounted speed — so
## dismounting subtracts and mounting restores, instead of the base numbers
## describing a state the unit is almost never in.

## Class the unit fights as while mounted. Feeds the advantage triangle, so a
## mounted Lancer is "Cavalry" with everything that implies.
@export var mounted_class: String = "Cavalry"
## ...and on foot. A dismounted rider is infantry: it loses the charge bonus
## Cavalry gets in CombatResolver and is read as Melee by the triangle.
@export var dismounted_class: String = "Melee"

## Movement points given up by dismounting. A horse is speed; losing it costs
## most of that.
@export var dismount_move_penalty: int = 2
## Defence gained by dismounting. A rider presents a big target and cannot use
## a shield wall; on foot it can. This is what makes dismounting a real choice
## rather than a strict downgrade.
@export var dismount_defense_bonus: int = 4
