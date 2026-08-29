extends Node
class_name CombatResolver
## CombatResolver — Logic layer manager for resolving tactical combat.
## Calculates damage using the Combat Advantage Triangle, terrain modifiers,
## and counter-attack rules. Fully decoupled via EventBus.

@export_group("Combat Tuning")
## Multiplier for counter-attack
@export var counter_attack_multiplier: float = 0.75
## Apakah serangan balik diaktifkan?
@export var enable_counter_attack: bool = true

## Injected so combat can ask what terrain a unit is standing on. Optional:
## with no GridManager every cell reads as PLAIN and combat behaves exactly as
## it did before Milestone 4, which is what the older test scenes rely on.
var grid_manager: GridManager


func _ready() -> void:
	EventBus.unit_attack_requested.connect(_on_unit_attack_requested)


func setup(grid_mgr: GridManager) -> void:
	grid_manager = grid_mgr


## Eksekusi pertarungan antara Attacker dan Defender
func resolve_combat(attacker: TacticalUnit, defender: TacticalUnit) -> Dictionary:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return {}

	# 1. Pastikan attacker masih bisa bertindak
	if not attacker.can_act():
		push_warning("CombatResolver: %s cannot act this turn." % attacker.name)
		return {}

	# A unit that has already broken is a prisoner awaiting a decision, not a
	# target — striking it again would resolve its captor's choice for them.
	if defender.pending_surrender:
		return {}

	# 2. Hitung serangan utama (Attacker -> Defender)
	var attack_result = _calculate_damage(attacker, defender)

	# Striking out of forest cover is an ambush: the victim never gets to swing
	# back, and MoraleManager turns the shock into a morale hit.
	var is_ambush: bool = _is_ambush(attacker)
	if is_ambush:
		EventBus.ambush_triggered.emit(attacker, defender)

	# Emit sinyal awal pertarungan
	EventBus.combat_started.emit(attacker, defender)

	# Terapkan damage ke defender
	attacker.face_direction(defender.global_position)
	attacker.play_animation("attack")
	
	var defender_died = defender.take_damage(attack_result["damage"], attack_result["damage_type"])
	
	# Special Trait: Vampire Lifesteal (recovers 40% of damage dealt)
	var att_name = attacker.unit_data.unit_name.to_lower() if is_instance_valid(attacker.unit_data) else ""
	if ("vampire" in att_name or "nightstalker" in att_name) and attack_result["damage"] > 0:
		var lifesteal_amount = maxi(1, int(round(attack_result["damage"] * 0.4)))
		attacker.heal(lifesteal_amount)

	if attack_result["advantage_type"] != "NEUTRAL":
		EventBus.combat_advantage_applied.emit(
			attack_result["advantage_type"],
			attack_result["multiplier"]
		)

	# 3. Konsumsi aksi attacker
	attacker.consume_action()

	# 4. Counter-Attack if defender survives, is in range, and was not ambushed
	var counter_result: Dictionary = {}
	if not defender_died and enable_counter_attack and not is_ambush:
		var distance = _get_manhattan_distance(attacker.grid_position, defender.grid_position)
		var def_min_range: int = defender.unit_data.attack_range_min if is_instance_valid(defender.unit_data) else 1
		var def_max_range: int = defender.unit_data.attack_range_max if is_instance_valid(defender.unit_data) else 1

		# Defender can only counter if attacker is within its attack range
		if distance >= def_min_range and distance <= def_max_range:
			defender.face_direction(attacker.global_position)
			defender.play_animation("attack")
			
			counter_result = _calculate_damage(defender, attacker, counter_attack_multiplier)
			var attacker_died = attacker.take_damage(counter_result["damage"], counter_result["damage_type"])
			counter_result["killed_attacker"] = attacker_died

	# Return units to idle shortly after attack
	var tree := attacker.get_tree()
	if tree:
		var timer = tree.create_timer(0.6)
		timer.timeout.connect(_on_combat_animation_timeout.bind(attacker, defender, defender_died))

	var full_report = {
		"attacker": attacker,
		"defender": defender,
		"primary_attack": attack_result,
		"counter_attack": counter_result,
		"defender_killed": defender_died,
		"ambush": is_ambush,
	}

	EventBus.combat_resolved.emit(full_report)
	return full_report


## Exactly what `resolve_combat()` would deal, touching no state and emitting
## nothing. Exists so the AI scores swings without a second copy of the formula,
## which would drift the moment either side was tuned.
##
## `def_cell_override` asks "what if the defender stood there instead" — threat
## mapping evaluates cells nothing has moved to yet. (-1, -1) means "as it is".
func preview_damage(att: TacticalUnit, def: TacticalUnit,
		def_cell_override: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if not is_instance_valid(att) or not is_instance_valid(def):
		return {"damage": 0, "base_damage": 0, "multiplier": 0.0,
				"advantage_type": "NEUTRAL", "damage_type": "physical",
				"terrain_mult": 1.0, "morale_mult": 1.0}
	return _calculate_damage(att, def, 1.0, def_cell_override)


## Kalkulasi damage mendalam dengan formula taktis & class specializations
func _calculate_damage(att: TacticalUnit, def: TacticalUnit, additional_mult: float = 1.0,
		def_cell_override: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var att_data: UnitData = att.unit_data
	var def_data: UnitData = def.unit_data

	var atk_power: int = att_data.attack_power if is_instance_valid(att_data) else 20
	# Defence and class come from the UNIT, not its resource: a dismounted rider
	# fights as infantry with a shield bonus, and reading the raw stat block here
	# would keep scoring it as the Cavalry it stepped off.
	var def_power: int = def.get_effective_defense() if is_instance_valid(def_data) else 10
	var att_class: String = att.get_effective_class() if is_instance_valid(att_data) else "Worker"
	var def_class: String = def.get_effective_class() if is_instance_valid(def_data) else "Worker"
	var att_name: String = att_data.unit_name.to_lower() if is_instance_valid(att_data) else ""
	var def_name: String = def_data.unit_name.to_lower() if is_instance_valid(def_data) else ""

	# 1. Base Damage Calculation based on Damage Type (Physical vs Magic)
	var base_damage: float
	var damage_type: String = "physical"

	if att_class == "Mage" or "wizard" in att_name or "wizzard" in att_name or "mage" in att_name:
		damage_type = "magic"
		# Mage: Armor-Piercing (bypasses 75% of physical defense)
		base_damage = float(atk_power) - (float(def_power) * 0.12)
	else:
		base_damage = float(atk_power) - (float(def_power) * 0.5)

	# Heavy Armor Trait (Knight): Takes 25% less physical damage
	if ("knight" in def_name or (def_class == "Melee" and def_data.tier >= 3)) and damage_type == "physical":
		base_damage *= 0.75

	base_damage = maxf(1.0, base_damage)

	# 2. Multiplier Keunggulan Taktis (Combat Advantage Triangle)
	var advantage_info = _get_advantage_multiplier(att_class, def_class, att_name, def_name)
	var advantage_mult: float = advantage_info["multiplier"]
	var advantage_type: String = advantage_info["type"]

	# 3. Class Fighting Style Modifiers
	var trait_mult: float = 1.0
	
	# Cavalry momentum charge (+25% when initiating). Keyed on CLASS only: the
	# old `or "lancer" in att_name` let a dismounted rider keep the bonus for its
	# name alone, defeating the point of dismounting.
	if att_class == "Cavalry":
		trait_mult *= 1.25

	# Rogue backstab (+50%). The name fallback STAYS, unlike Cavalry above:
	# Skeleton Rogue is class "Undead" so Holy Smite applies, and its name is the
	# only thing marking it a backstabber. Nothing dismounts into Infiltrator.
	if att_class == "Infiltrator" or "rogue" in att_name:
		trait_mult *= 1.50

	# 4. Terrain the DEFENDER is standing on. Forest and rock soak damage;
	#    roads and bridges leave a unit exposed.
	var terrain_def_mult: float = 1.0
	if is_instance_valid(grid_manager):
		var def_cell: Vector2i = (
			def_cell_override if def_cell_override != Vector2i(-1, -1) else def.grid_position
		)
		terrain_def_mult = grid_manager.get_damage_taken_mult(def_cell)

	# 5. The attacker's nerve. Undead always read as 1.0.
	var morale_mult: float = att.get_morale_attack_mult()

	# Hitung total damage
	var final_damage = int(round(
		base_damage * advantage_mult * trait_mult * terrain_def_mult * morale_mult * additional_mult
	))
	final_damage = maxi(1, final_damage)

	return {
		"damage": final_damage,
		"base_damage": int(base_damage),
		"multiplier": advantage_mult * trait_mult * additional_mult,
		"advantage_type": advantage_type,
		"damage_type": damage_type,
		"terrain_mult": terrain_def_mult,
		"morale_mult": morale_mult,
	}


## The advantage triangle: > 1.0 beats, < 1.0 loses. Exposed so recruitment can
## counter what the enemy fields without a second copy of the matchup table.
## Names are optional and only matter for unit-specific rules.
func class_advantage(attacker_class: String, defender_class: String,
		attacker_name: String = "", defender_name: String = "") -> float:
	var info: Dictionary = _get_advantage_multiplier(
		attacker_class, defender_class, attacker_name, defender_name
	)
	return float(info.get("multiplier", 1.0))


## Menentukan multiplier keunggulan taktis (Combat Advantage Triangle)
func _get_advantage_multiplier(attacker_class: String, defender_class: String, att_name: String = "", def_name: String = "") -> Dictionary:
	var a = attacker_class.to_upper()
	var d = defender_class.to_upper()

	# 1. Matchup Khusus: Priest / Monk / Paladin / Holy vs Undead (2.5x)
	if (a == "SUPPORT" or "priest" in att_name or "monk" in att_name or "paladin" in att_name) and (d == "UNDEAD" or "skeleton" in def_name or "vampire" in def_name or "skull" in def_name):
		return {"multiplier": GameConfig.HOLY_VS_UNDEAD_MULTIPLIER, "type": "HOLY_EFFECTIVE"}

	# 2. Melee / Cavalry > Ranged & Support (1.5x)
	if (a == "MELEE" or a == "CAVALRY") and (d == "RANGED" or d == "SUPPORT" or d == "WORKER"):
		return {"multiplier": GameConfig.ADVANTAGE_MULTIPLIER, "type": "ADVANTAGE"}

	# 3. Ranged > Mage / Support (1.5x)
	if a == "RANGED" and (d == "MAGE" or d == "SUPPORT"):
		return {"multiplier": GameConfig.ADVANTAGE_MULTIPLIER, "type": "ADVANTAGE"}

	# 4. Mage > Melee / Heavy Cavalry (Armor Piercing) (1.5x)
	if a == "MAGE" and (d == "MELEE" or d == "CAVALRY"):
		return {"multiplier": GameConfig.ADVANTAGE_MULTIPLIER, "type": "ADVANTAGE"}

	# 5. Infiltrator (Rogue) > Mage & Ranged (1.5x)
	if a == "INFILTRATOR" and (d == "MAGE" or d == "RANGED"):
		return {"multiplier": GameConfig.ADVANTAGE_MULTIPLIER, "type": "ADVANTAGE"}

	# 6. Disadvantage matchups (0.7x)
	if a == "RANGED" and (d == "MELEE" or d == "CAVALRY"):
		return {"multiplier": GameConfig.DISADVANTAGE_MULTIPLIER, "type": "DISADVANTAGE"}
	if (a == "MELEE" or a == "CAVALRY") and d == "MAGE":
		return {"multiplier": GameConfig.DISADVANTAGE_MULTIPLIER, "type": "DISADVANTAGE"}

	return {"multiplier": GameConfig.NEUTRAL_MULTIPLIER, "type": "NEUTRAL"}


## An attack launched from concealing cover that grants ambush (forest). Rocks
## hide a unit but give it nowhere to spring from, so they do not ambush.
func _is_ambush(attacker: TacticalUnit) -> bool:
	if not is_instance_valid(grid_manager):
		return false
	return grid_manager.is_ambush_cover(attacker.grid_position)


func _get_manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _on_unit_attack_requested(attacker: Node, target: Node) -> void:
	if attacker is TacticalUnit and target is TacticalUnit:
		resolve_combat(attacker, target)


func _on_combat_animation_timeout(att: Variant, def: Variant, def_died: bool) -> void:
	if is_instance_valid(att) and att is TacticalUnit:
		att.play_animation("idle")
	if not def_died and is_instance_valid(def) and def is TacticalUnit:
		def.play_animation("idle")
