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


func _ready() -> void:
	EventBus.unit_attack_requested.connect(_on_unit_attack_requested)


## Eksekusi pertarungan antara Attacker dan Defender
func resolve_combat(attacker: TacticalUnit, defender: TacticalUnit) -> Dictionary:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return {}

	# 1. Pastikan attacker masih bisa bertindak
	if not attacker.can_act():
		push_warning("CombatResolver: %s cannot act this turn." % attacker.name)
		return {}

	# 2. Hitung serangan utama (Attacker -> Defender)
	var attack_result = _calculate_damage(attacker, defender)
	
	# Emit sinyal awal pertarungan
	EventBus.combat_started.emit(attacker, defender)

	# Terapkan damage ke defender
	attacker.face_direction(defender.global_position)
	attacker.play_animation("attack")
	
	var defender_died = defender.take_damage(attack_result["damage"], attack_result["damage_type"])
	
	# Special Trait: Vampire Lifesteal (recovers 40% of damage dealt)
	var att_name = attacker.unit_data.unit_name.to_lower() if is_instance_valid(attacker.unit_data) else ""
	if "vampire" in att_name and attack_result["damage"] > 0:
		var lifesteal_amount = maxi(1, int(round(attack_result["damage"] * 0.4)))
		attacker.heal(lifesteal_amount)

	if attack_result["advantage_type"] != "NEUTRAL":
		EventBus.combat_advantage_applied.emit(
			attack_result["advantage_type"],
			attack_result["multiplier"]
		)

	# 3. Konsumsi aksi attacker
	attacker.consume_action()

	# 4. Counter-Attack if defender survives and is in range
	var counter_result: Dictionary = {}
	if not defender_died and enable_counter_attack:
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
	var timer = attacker.get_tree().create_timer(0.6)
	timer.timeout.connect(func():
		if is_instance_valid(attacker): attacker.play_animation("idle")
		if is_instance_valid(defender) and not defender_died: defender.play_animation("idle")
	)

	var full_report = {
		"attacker": attacker,
		"defender": defender,
		"primary_attack": attack_result,
		"counter_attack": counter_result,
		"defender_killed": defender_died
	}

	EventBus.combat_resolved.emit(full_report)
	return full_report


## Kalkulasi damage mendalam dengan formula taktis & class specializations
func _calculate_damage(att: TacticalUnit, def: TacticalUnit, additional_mult: float = 1.0) -> Dictionary:
	var att_data: UnitData = att.unit_data
	var def_data: UnitData = def.unit_data

	var atk_power: int = att_data.attack_power if is_instance_valid(att_data) else 20
	var def_power: int = def_data.defense_power if is_instance_valid(def_data) else 10
	var att_class: String = att_data.unit_class if is_instance_valid(att_data) else "Worker"
	var def_class: String = def_data.unit_class if is_instance_valid(def_data) else "Worker"
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
	
	# Cavalry (Lancer) Momentum Charge (+25% damage when initiating attack)
	if att_class == "Cavalry" or "lancer" in att_name:
		trait_mult *= 1.25

	# Infiltrator (Rogue) Backstab Critical (+50% damage)
	if att_class == "Infiltrator" or "rogue" in att_name:
		trait_mult *= 1.50

	# 4. Terrain defense modifier
	var terrain_def_mult: float = 1.0

	# Hitung total damage
	var final_damage = int(round(base_damage * advantage_mult * trait_mult * terrain_def_mult * additional_mult))
	final_damage = maxi(1, final_damage)

	return {
		"damage": final_damage,
		"base_damage": int(base_damage),
		"multiplier": advantage_mult * trait_mult * additional_mult,
		"advantage_type": advantage_type,
		"damage_type": damage_type
	}


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


func _get_manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _on_unit_attack_requested(attacker: Node, target: Node) -> void:
	if attacker is TacticalUnit and target is TacticalUnit:
		resolve_combat(attacker, target)
