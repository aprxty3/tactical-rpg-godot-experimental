extends Node
class_name CombatResolver
## CombatResolver — Logic layer manager for resolving tactical combat.
## Calculates damage using the Combat Advantage Triangle, terrain modifiers,
## and counter-attack rules. Fully decoupled via EventBus.

@export_group("Combat Tuning")
## Multiplier untuk serangan balik (Counter-attack)
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
	var defender_died = defender.take_damage(attack_result["damage"], attack_result["damage_type"])
	
	if attack_result["advantage_type"] != "NEUTRAL":
		EventBus.combat_advantage_applied.emit(
			attack_result["advantage_type"],
			attack_result["multiplier"]
		)

	# 3. Konsumsi aksi attacker
	attacker.consume_action()

	# 4. Serangan Balik (Counter-Attack) jika defender selamat dan dalam jangkauan
	var counter_result: Dictionary = {}
	if not defender_died and enable_counter_attack:
		var distance = _get_manhattan_distance(attacker.grid_position, defender.grid_position)
		var def_min_range: int = defender.unit_data.attack_range_min if is_instance_valid(defender.unit_data) else 1
		var def_max_range: int = defender.unit_data.attack_range_max if is_instance_valid(defender.unit_data) else 1

		# Defender hanya bisa counter jika penyerang ada dalam jangkauan serangnya
		if distance >= def_min_range and distance <= def_max_range:
			counter_result = _calculate_damage(defender, attacker, counter_attack_multiplier)
			var attacker_died = attacker.take_damage(counter_result["damage"], counter_result["damage_type"])
			counter_result["killed_attacker"] = attacker_died

	var full_report = {
		"attacker": attacker,
		"defender": defender,
		"primary_attack": attack_result,
		"counter_attack": counter_result,
		"defender_killed": defender_died
	}

	EventBus.combat_resolved.emit(full_report)
	return full_report


## Kalkulasi damage mendalam dengan formula taktis
func _calculate_damage(att: TacticalUnit, def: TacticalUnit, additional_mult: float = 1.0) -> Dictionary:
	var att_data: UnitData = att.unit_data
	var def_data: UnitData = def.unit_data

	var atk_power: int = att_data.attack_power if is_instance_valid(att_data) else 20
	var def_power: int = def_data.defense_power if is_instance_valid(def_data) else 10
	var att_class: String = att_data.unit_class if is_instance_valid(att_data) else "Worker"
	var def_class: String = def_data.unit_class if is_instance_valid(def_data) else "Worker"

	# Formula Base Damage: ATK - (DEF * 0.5)
	var base_damage: float = float(atk_power) - (float(def_power) * 0.5)
	base_damage = maxf(1.0, base_damage)

	# Multiplier Keunggulan Taktis (Combat Advantage Triangle)
	var advantage_info = _get_advantage_multiplier(att_class, def_class)
	var advantage_mult: float = advantage_info["multiplier"]
	var advantage_type: String = advantage_info["type"]

	# Terrain defense modifier (Default 1.0, bisa ditingkatkan jika unit di Forest/Mountain)
	var terrain_def_mult: float = 1.0 # 1.0 = normal, 0.8 = hutan (+20% def), 0.6 = gunung (+40% def)

	# Hitung total damage
	var final_damage = int(round(base_damage * advantage_mult * terrain_def_mult * additional_mult))
	final_damage = maxi(1, final_damage)

	return {
		"damage": final_damage,
		"base_damage": int(base_damage),
		"multiplier": advantage_mult * additional_mult,
		"advantage_type": advantage_type,
		"damage_type": "physical"
	}


## Menentukan multiplier keunggulan taktis (Combat Advantage Triangle)
func _get_advantage_multiplier(attacker_class: String, defender_class: String) -> Dictionary:
	var a = attacker_class.to_upper()
	var d = defender_class.to_upper()

	# 1. Matchup Khusus: Priest / Holy vs Undead (2.5x)
	if a == "SUPPORT" and (d == "UNDEAD" or d == "SKELETON" or d == "VAMPIRE"):
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
