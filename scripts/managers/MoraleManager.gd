extends Node
class_name MoraleManager
## MoraleManager — Logic layer manager for unit morale and surrender.
##
## Morale is a scalar on each TacticalUnit; this is its only writer.
##
## Surrender is two-phase: the broken unit freezes, `surrender_triggered` fires,
## and nothing resolves until the captor calls `resolve_surrender()`. That keeps
## the choice out of this manager and the rules out of the UI.

@export_group("Morale Settings")
## The faction whose surrender decisions are made by a human through the HUD.
## Every other faction auto-resolves. Mirrors AIManager.ai_faction_id.
@export var human_faction_id: int = GameConfig.Faction.BLUE_KINGDOM
## Master switch, so older test scenes can opt out of morale entirely.
@export var morale_enabled: bool = true

# Injected dependencies (never hardcoded paths — see AIManager.setup)
var grid_manager: GridManager
var economy_manager: Node

## Units awaiting a captor's decision: TacticalUnit -> captor faction_id.
var _pending: Dictionary = {}

const ADJACENT: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func _ready() -> void:
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.unit_damaged.connect(_on_unit_damaged)
	EventBus.unit_healed.connect(_on_unit_healed)
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.ambush_triggered.connect(_on_ambush_triggered)
	EventBus.building_captured.connect(_on_building_captured)
	EventBus.logistics_collapse_started.connect(_on_logistics_collapse)
	EventBus.turn_started.connect(_on_turn_started)


func setup(grid_mgr: GridManager, eco_mgr: Node) -> void:
	grid_manager = grid_mgr
	economy_manager = eco_mgr

# UPKEEP — regen, flanking, desertion


## Run once per faction turn, before its units act.
func _on_turn_started(faction_id: int) -> void:
	if not morale_enabled:
		return

	# Copy the roster: a desertion mutates it mid-loop.
	for unit in TurnManager.get_faction_units(faction_id).duplicate():
		if not is_instance_valid(unit) or not (unit is TacticalUnit):
			continue
		var tactical: TacticalUnit = unit
		if tactical.is_morale_immune():
			continue

		if _count_adjacent_enemies(tactical) >= GameConfig.MORALE_FLANK_MIN_ENEMIES:
			tactical.adjust_morale(GameConfig.MORALE_FLANK_PENALTY)
		else:
			tactical.adjust_morale(_regen_step(tactical))

		_check_desertion(tactical)


## Morale drifts back toward FAIR from either direction, so a rout is
## recoverable and a hot streak is not permanent.
func _regen_step(unit: TacticalUnit) -> int:
	var gap: int = GameConfig.MORALE_DEFAULT - unit.morale
	if gap == 0:
		return 0
	return signi(gap) * mini(GameConfig.MORALE_REGEN, absi(gap))


func _check_desertion(unit: TacticalUnit) -> void:
	if unit.get_morale_level() != GameConfig.MoraleLevel.FEARFUL:
		return
	if randf() < GameConfig.DESERTION_CHANCE_FEARFUL:
		unit.desert()


func _count_adjacent_enemies(unit: TacticalUnit) -> int:
	if not is_instance_valid(grid_manager):
		return 0
	var count: int = 0
	for dir in ADJACENT:
		var other: TacticalUnit = grid_manager.get_unit_at(unit.grid_position + dir)
		if is_instance_valid(other) and other.faction_id != unit.faction_id:
			count += 1
	return count

# BATTLEFIELD EVENTS — morale shifts


## A death is felt by everyone nearby: allies falter, enemies take heart.
func _on_unit_died(unit: Node, _cause: String) -> void:
	if not morale_enabled or not (unit is TacticalUnit):
		return
	var fallen: TacticalUnit = unit
	for other in _units_near(fallen.grid_position, GameConfig.MORALE_SHOCK_RADIUS, fallen):
		var delta: int = (
			GameConfig.MORALE_ALLY_DEATH if other.faction_id == fallen.faction_id
			else GameConfig.MORALE_ENEMY_DEATH
		)
		other.adjust_morale(delta)


func _on_unit_damaged(unit: Node, amount: int, _damage_type: String) -> void:
	if not morale_enabled or not (unit is TacticalUnit):
		return
	var tactical: TacticalUnit = unit
	if not is_instance_valid(tactical.unit_data) or tactical.current_health <= 0:
		return

	var delta: int = GameConfig.MORALE_DAMAGE_TAKEN
	if float(amount) > float(tactical.unit_data.max_health) * 0.25:
		delta += GameConfig.MORALE_HEAVY_DAMAGE_EXTRA
	tactical.adjust_morale(delta)


func _on_unit_healed(unit: Node, _amount: int) -> void:
	if morale_enabled and unit is TacticalUnit:
		(unit as TacticalUnit).adjust_morale(GameConfig.MORALE_HEALED)


func _on_ambush_triggered(_ambusher: Node, target: Node) -> void:
	if morale_enabled and target is TacticalUnit:
		(target as TacticalUnit).adjust_morale(GameConfig.MORALE_AMBUSHED)


## Killing blows steady the victor — and a survivor who broke may now surrender.
func _on_combat_resolved(result: Dictionary) -> void:
	if not morale_enabled:
		return

	var attacker: TacticalUnit = result.get("attacker")
	var defender: TacticalUnit = result.get("defender")
	var counter: Dictionary = result.get("counter_attack", {})

	if result.get("defender_killed", false) and is_instance_valid(attacker):
		attacker.adjust_morale(GameConfig.MORALE_KILL_BONUS)
	if counter.get("killed_attacker", false) and is_instance_valid(defender):
		defender.adjust_morale(GameConfig.MORALE_KILL_BONUS)

	if not result.get("defender_killed", false) and is_instance_valid(attacker):
		_try_surrender(defender, attacker.faction_id)


## Taking ground lifts a whole army; losing it does the reverse.
func _on_building_captured(building: Node, new_faction_id: int) -> void:
	if not morale_enabled or not (building is Building):
		return
	_shift_faction_morale(new_faction_id, GameConfig.MORALE_CAPTURE_BONUS)
	for faction_id in TurnManager.faction_order:
		if faction_id != new_faction_id:
			_shift_faction_morale(faction_id, GameConfig.MORALE_CAPTURE_LOSS)


func _on_logistics_collapse(faction_id: int) -> void:
	if morale_enabled:
		_shift_faction_morale(faction_id, GameConfig.MORALE_STARVATION)


func _shift_faction_morale(faction_id: int, delta: int) -> void:
	for unit in TurnManager.get_faction_units(faction_id):
		if is_instance_valid(unit) and unit is TacticalUnit:
			(unit as TacticalUnit).adjust_morale(delta)


## Every living unit within a Manhattan radius, excluding one.
func _units_near(cell: Vector2i, radius: int, exclude: TacticalUnit) -> Array[TacticalUnit]:
	var found: Array[TacticalUnit] = []
	for faction_id in TurnManager.faction_order:
		for unit in TurnManager.get_faction_units(faction_id):
			if not is_instance_valid(unit) or unit == exclude or not (unit is TacticalUnit):
				continue
			var tactical: TacticalUnit = unit
			var distance: int = absi(tactical.grid_position.x - cell.x) + absi(tactical.grid_position.y - cell.y)
			if distance <= radius:
				found.append(tactical)
	return found

# SURRENDER


## Roll for a break after a unit survives an attack. FAIR and above hold the
## line; the undead never break at all.
func _try_surrender(unit: TacticalUnit, captor_faction_id: int) -> void:
	if not is_instance_valid(unit) or unit.pending_surrender or unit.is_morale_immune():
		return
	if unit.faction_id == captor_faction_id:
		return

	var chance: float = float(GameConfig.SURRENDER_CHANCE.get(unit.get_morale_level(), 0.0))
	if chance <= 0.0 or randf() >= chance:
		return

	begin_surrender(unit, captor_faction_id)


## Freeze a unit as a prisoner and hand the decision to its captor.
##
## Split out from the roll so the break itself can be triggered directly — by a
## test, or later by a scripted event — without depending on a dice throw.
func begin_surrender(unit: TacticalUnit, captor_faction_id: int) -> void:
	if not is_instance_valid(unit) or _pending.has(unit):
		return

	# Monsters take no prisoners and no ransom, so the unit simply does not
	# break. Refused here rather than at the branches below, which both assume a
	# captor with a treasury and a roster — letting a ghoul reach
	# `resolve_surrender` would press a knight into the undead ranks.
	if GameConfig.is_marauder(captor_faction_id):
		return

	unit.pending_surrender = true
	_pending[unit] = captor_faction_id
	EventBus.surrender_triggered.emit(unit)

	# The human captor is asked through the HUD; anyone else decides now.
	if captor_faction_id == human_faction_id:
		EventBus.surrender_decision_required.emit(unit, captor_faction_id)
	else:
		resolve_surrender(unit, auto_choice_for(captor_faction_id, unit))


## Can this army feed one more prisoner?
##
## A claimed unit is troops like any other, so it answers to the same ceiling a
## recruited one does. Pulled out of `auto_choice_for` because the human captor
## needs the same answer for a different reason: to be told, and to be stopped.
func has_room_for(captor_faction_id: int, unit: TacticalUnit) -> bool:
	if not is_instance_valid(economy_manager) or not is_instance_valid(unit) \
			or not is_instance_valid(unit.unit_data):
		return false
	return economy_manager.has_capacity_for(
		captor_faction_id,
		unit.unit_data.capacity_weight,
		TurnManager.get_faction_units(captor_faction_id)
	)


## What an AI captor does: take the prisoner if the army can feed one, and
## ransom them otherwise. Also the fallback if the HUD ever fails to ask.
func auto_choice_for(captor_faction_id: int, unit: TacticalUnit) -> String:
	return "capture" if has_room_for(captor_faction_id, unit) else "ransom"


## Settle a pending surrender. `choice` is "capture" or "ransom".
func resolve_surrender(unit: TacticalUnit, choice: String) -> void:
	if not is_instance_valid(unit) or not _pending.has(unit):
		return

	var captor_faction_id: int = _pending[unit]
	_pending.erase(unit)

	# A dialog can be answered "capture" by an army with no room. The ceiling is
	# enforced here because every claim — human, AI or scripted — passes through
	# this point. Ransom is the fallback rather than a refusal: the prisoner is
	# frozen until this resolves, so there must be an outcome.
	if choice == "capture" and not has_room_for(captor_faction_id, unit):
		choice = "ransom"

	if choice == "capture":
		_capture(unit, captor_faction_id)
	else:
		_ransom(unit, captor_faction_id)

	EventBus.surrender_resolved.emit(unit, choice, captor_faction_id)


## The prisoner changes sides, arriving wounded, shaken and already spent.
func _capture(unit: TacticalUnit, captor_faction_id: int) -> void:
	if is_instance_valid(unit.unit_data):
		unit.current_health = maxi(
			1, int(round(unit.unit_data.max_health * GameConfig.SURRENDER_CAPTURE_HP_RATIO))
		)
	unit.change_faction(captor_faction_id)


## The prisoner is sold back and leaves the field; the captor pockets the fee.
func _ransom(unit: TacticalUnit, captor_faction_id: int) -> void:
	if is_instance_valid(economy_manager) and is_instance_valid(unit.unit_data):
		var fee: int = int(round(unit.unit_data.recruit_cost_gold * GameConfig.SURRENDER_RANSOM_RATIO))
		economy_manager.add_gold(captor_faction_id, fee)
	unit.pending_surrender = false
	unit.desert()


## Is anyone waiting on a decision? Used by the controller to block input.
func has_pending_surrender() -> bool:
	return not _pending.is_empty()
