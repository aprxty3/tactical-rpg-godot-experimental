extends RefCounted
class_name AITacticalEvaluator
## AITacticalEvaluator — the AI's judgement, separated from its turn loop.
##
## `AIManager` decides *when* to act; this decides *what is worth doing*. Every
## function is a pure read of world state, so scoring can be tested on a built
## board without awaits, timers or signals. It holds no state of its own.
##
## Two rules it must never break:
##   1. Damage is never recomputed — `CombatResolver.preview_damage()` is the
##      only source, or the AI plans against rules the player does not play.
##   2. Nothing invisible is scored. Every enemy lookup goes through `can_see()`,
##      so the fog binds the AI exactly as it binds the player.

var _grid: GridManager
var _combat: CombatResolver
var _vision: VisionManager
var _faction_id: int


func _init(grid: GridManager, combat: CombatResolver, vision: VisionManager,
		faction_id: int) -> void:
	_grid = grid
	_combat = combat
	_vision = vision
	_faction_id = faction_id


# ==============================================================================
# VISIBILITY
# ==============================================================================

## Without a VisionManager the AI is omniscient, which is what the pre-fog test
## scenes expect. With one, it sees exactly what the fog allows.
func can_see(unit: TacticalUnit) -> bool:
	if not is_instance_valid(_vision):
		return true
	return _vision.can_see_unit(_faction_id, unit)


## Every enemy this faction is currently allowed to know about.
func visible_enemies() -> Array[TacticalUnit]:
	var found: Array[TacticalUnit] = []
	if not is_instance_valid(_grid) or not _grid.is_inside_tree():
		return found
	for node in _grid.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(node) or not (node is TacticalUnit):
			continue
		var unit: TacticalUnit = node
		if unit.faction_id != _faction_id and unit.current_health > 0 and can_see(unit):
			found.append(unit)
	return found


# ==============================================================================
# ATTACK SCORING
# ==============================================================================

## Swing quality as a fraction of the target's remaining health. Normalising by
## HP stops the AI hammering the toughest unit: 20 damage to a 25 HP mage beats
## 30 to a 200 HP guard. Negative means the swing costs more than it gains.
func score_attack(attacker: TacticalUnit, defender: TacticalUnit) -> float:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return -INF
	if not is_instance_valid(_combat):
		return 0.0

	var outgoing: int = int(_combat.preview_damage(attacker, defender).get("damage", 0))
	var target_hp: int = maxi(1, defender.current_health)
	var score: float = float(outgoing) / float(target_hp)

	# A dead unit cannot counter next turn, cannot capture, cannot heal. Finishing
	# is worth more than the raw damage number suggests.
	if outgoing >= defender.current_health:
		return score + GameConfig.AI_KILL_BONUS

	# Otherwise the target survives and swings back — unless the attack comes out
	# of ambush cover, which suppresses the counter entirely.
	var from_ambush: bool = (
		is_instance_valid(_grid) and _grid.is_ambush_cover(attacker.grid_position)
	)
	if from_ambush:
		score += GameConfig.AI_AMBUSH_BONUS
	else:
		var counter: int = int(_combat.preview_damage(defender, attacker).get("damage", 0))
		var own_hp: int = maxi(1, attacker.current_health)
		score -= (float(counter) / float(own_hp)) * GameConfig.AI_COUNTER_WEIGHT

	return score


## What an enemy is worth to WALK TOWARD (`score_attack` ranks a swing already
## in range). Same shape as `score_objective` — value over real path cost — so
## the caller can simply take the larger; a mode flag would make them
## incomparable.
func score_enemy_target(unit: TacticalUnit, enemy: TacticalUnit) -> float:
	if not is_instance_valid(unit) or not is_instance_valid(enemy):
		return -INF
	if enemy.faction_id == _faction_id or not can_see(enemy):
		return -INF

	var value: float = GameConfig.AI_ENEMY_VALUE
	if is_instance_valid(enemy.unit_data) and enemy.unit_data.max_health > 0:
		var missing: float = 1.0 - (float(enemy.current_health) / float(enemy.unit_data.max_health))
		value += GameConfig.AI_WOUNDED_BONUS * clampf(missing, 0.0, 1.0)

	var cost: int = path_cost_between(unit.grid_position, enemy.grid_position)
	if cost < 0:
		return -INF
	return value / float(cost + 1)


## The visible enemy most worth marching on, with its score.
## Returns {"unit": TacticalUnit|null, "score": float}.
func best_enemy_target(unit: TacticalUnit) -> Dictionary:
	var best: TacticalUnit = null
	var best_score: float = -INF
	for enemy in visible_enemies():
		var score: float = score_enemy_target(unit, enemy)
		if score > best_score:
			best_score = score
			best = enemy
	return {"unit": best, "score": best_score}


## Would this swing finish the target? Kept here so the damage number comes from
## one place: a wounded unit may stay to land a kill, and that call must agree
## with the score that ranked it.
func would_kill(attacker: TacticalUnit, defender: TacticalUnit) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return false
	if not is_instance_valid(_combat):
		return false
	var dmg: int = int(_combat.preview_damage(attacker, defender).get("damage", 0))
	return dmg >= defender.current_health


## The best target in reach right now, or null when nothing is worth hitting.
func best_attack_target(unit: TacticalUnit) -> TacticalUnit:
	if not is_instance_valid(unit) or not unit.can_act() or not is_instance_valid(unit.unit_data):
		return null
	if not is_instance_valid(_grid):
		return null

	var cells: Array[Vector2i] = _grid.get_attackable_cells(
		unit.grid_position,
		unit.unit_data.attack_range_min,
		unit.unit_data.attack_range_max
	)

	# Threshold is 0, not -INF: a swing scoring at or below zero costs more in
	# counter-damage than it gains. Declining is not idling — the caller falls
	# through to movement when this returns null.
	var best: TacticalUnit = null
	var best_score: float = 0.0
	for cell in cells:
		var target: TacticalUnit = _grid.get_unit_at(cell)
		if not is_instance_valid(target) or target.faction_id == _faction_id:
			continue
		if target.pending_surrender or not can_see(target):
			continue
		var score: float = score_attack(unit, target)
		if score > best_score:
			best_score = score
			best = target
	return best


# ==============================================================================
# OBJECTIVE SCORING
# ==============================================================================

## Real terrain-aware cost of walking from `from_cell` to `to_cell`, ignoring
## movement points — this measures distance in the currency the map actually
## charges, so a road detour can beat a shorter slog through forest.
## Returns -1 when no route exists.
func path_cost_between(from_cell: Vector2i, to_cell: Vector2i) -> int:
	if not is_instance_valid(_grid):
		return -1
	if from_cell == to_cell:
		return 0
	var path: Array[Vector2i] = _grid.get_path_cells(from_cell, to_cell)
	if path.size() < 2:
		return -1
	return _grid.get_path_cost(path)


## What a building is worth to this unit: value per step of travel. Dividing by
## path cost lets a better objective further away outrank a cheap one underfoot,
## which nearest-building-wins could not express.
func score_objective(unit: TacticalUnit, building: Building) -> float:
	if not is_instance_valid(unit) or not is_instance_valid(building):
		return -INF
	# Anything but a capture is worth nothing to march on. Without this the AI
	# scores the monster den top and feeds units into it one at a time, forever.
	if building.claim_for(_faction_id) != Building.Claim.CAPTURE:
		return -INF
	# Occupied: a building is claimed by ENDING a move on its cell, which an
	# occupied cell forbids. A general rule, but the boss standing permanently on
	# the Black Castle is what made it matter — without it every army queues
	# outside a keep none can enter. The occupant is still handled, as an enemy.
	if is_instance_valid(_grid) and _grid.get_unit_at(building.grid_position) != null:
		return -INF

	var value: float = float(
		GameConfig.AI_OBJECTIVE_VALUE.get(building.get_type_string(), 10.0)
	)
	if building.faction_id == GameConfig.Faction.NEUTRAL:
		value *= GameConfig.AI_NEUTRAL_BONUS

	var cost: int = path_cost_between(unit.grid_position, building.grid_position)
	if cost < 0:
		return -INF  # unreachable — water, or walled off
	# +1 so an adjacent objective scores high instead of dividing by zero.
	return value / float(cost + 1)


## The highest-value reachable building, or null when none is worth walking to.
func best_objective(unit: TacticalUnit) -> Building:
	if not is_instance_valid(_grid) or not _grid.is_inside_tree():
		return null
	var best: Building = null
	var best_score: float = -INF
	for node in _grid.get_tree().get_nodes_in_group("buildings"):
		if not (node is Building):
			continue
		var score: float = score_objective(unit, node)
		if score > best_score:
			best_score = score
			best = node
	return best


# ==============================================================================
# THREAT & RETREAT
# ==============================================================================

## Expected incoming damage if `unit` stood on `cell` next turn. Threat range is
## movement plus attack range — deliberately an over-estimate, because being too
## cautious costs a tempo and being too optimistic costs the unit.
func threat_at(cell: Vector2i, unit: TacticalUnit) -> float:
	if not is_instance_valid(unit) or not is_instance_valid(_combat):
		return 0.0

	var total: float = 0.0
	for enemy in visible_enemies():
		if not is_instance_valid(enemy.unit_data):
			continue
		var reach: int = enemy.unit_data.movement_points + enemy.unit_data.attack_range_max
		var distance: int = (
			absi(enemy.grid_position.x - cell.x) + absi(enemy.grid_position.y - cell.y)
		)
		if distance > reach:
			continue
		# Score the hit as if the unit were already standing there, so terrain
		# under the candidate cell is properly credited.
		total += float(_combat.preview_damage(enemy, unit, cell).get("damage", 0))
	return total


## Two independent triggers: badly hurt, or standing somewhere the enemy can
## kill it from regardless of health. The second stops a full-health mage being
## parked inside three enemies' reach.
func should_retreat(unit: TacticalUnit) -> bool:
	if not is_instance_valid(unit) or not is_instance_valid(unit.unit_data):
		return false
	if not unit.can_move():
		return false

	var hp_ratio: float = float(unit.current_health) / float(maxi(1, unit.unit_data.max_health))
	var incoming: float = threat_at(unit.grid_position, unit)
	var lethal_ratio: float = incoming / float(maxi(1, unit.current_health))

	return (
		hp_ratio <= GameConfig.AI_RETREAT_HP_RATIO
		or lethal_ratio >= GameConfig.AI_RETREAT_THREAT_RATIO
	)


## The reachable cell minimising incoming damage, cover breaking ties. Returns
## (-1, -1) when standing still is already safest — running into worse ground is
## not a retreat.
func best_retreat_cell(unit: TacticalUnit) -> Vector2i:
	if not is_instance_valid(unit) or not is_instance_valid(_grid):
		return Vector2i(-1, -1)

	var here: float = _retreat_cost(unit.grid_position, unit)
	var best_cell := Vector2i(-1, -1)
	var best_cost: float = here

	for cell in _grid.get_reachable_cells(unit):
		var cost: float = _retreat_cost(cell, unit)
		if cost < best_cost:
			best_cost = cost
			best_cell = cell
	return best_cell


## Lower is safer. Threat dominates; cover is a tiebreaker worth a fixed number
## of damage points so that two equally-exposed cells resolve toward the one
## that soaks damage.
func _retreat_cost(cell: Vector2i, unit: TacticalUnit) -> float:
	var cost: float = threat_at(cell, unit)
	if is_instance_valid(_grid):
		# get_damage_taken_mult is < 1.0 on protective terrain, so this subtracts
		# more from good ground than from open field.
		var exposure: float = _grid.get_damage_taken_mult(cell)
		cost += (exposure - 1.0) * GameConfig.AI_RETREAT_COVER_WEIGHT
	return cost


# ==============================================================================
# MOVEMENT
# ==============================================================================

## The reachable cell that gets closest to `target_cell` in real travel cost,
## breaking ties toward the safer square.
##
## Replaces a Manhattan-distance walk, which could not tell a road from a forest
## and so routinely sent units into 2 MP terrain to save 1 tile of straight-line
## distance.
func best_step_towards(unit: TacticalUnit, target_cell: Vector2i) -> Vector2i:
	if not is_instance_valid(unit) or not is_instance_valid(_grid):
		return Vector2i(-1, -1)

	var reachable: Array[Vector2i] = _grid.get_reachable_cells(unit)
	if reachable.is_empty():
		return Vector2i(-1, -1)

	var best_cell: Vector2i = unit.grid_position
	var best_cost: int = path_cost_between(unit.grid_position, target_cell)
	var best_threat: float = INF
	var measured_threat: bool = false

	for cell in reachable:
		var cost: int = path_cost_between(cell, target_cell)
		if cost < 0:
			continue
		if best_cost < 0 or cost < best_cost:
			best_cost = cost
			best_cell = cell
			best_threat = threat_at(cell, unit)
			measured_threat = true
		elif cost == best_cost:
			if not measured_threat:
				best_threat = threat_at(best_cell, unit)
				measured_threat = true
			var threat: float = threat_at(cell, unit)
			if threat < best_threat:
				best_threat = threat
				best_cell = cell

	return best_cell
