extends Node2D

func _ready() -> void:
	print("--- Running In-Depth Combat Mechanics & Special Fighting Styles Test ---")
	
	var resolver = CombatResolver.new()
	add_child(resolver)
	
	var u_scene: PackedScene = load("res://scenes/units/TacticalUnit_Warrior_Blue.tscn")
	
	# Helper to instantiate test unit
	var make_unit = func(res_path: String, grid_pos: Vector2i) -> TacticalUnit:
		var u: TacticalUnit = u_scene.instantiate()
		u.unit_data = load(res_path)
		u.grid_position = grid_pos
		add_child(u)
		u._initialize_from_data()
		return u
		
	# 1. Test Vampire Lifesteal
	var vampire = make_unit.call("res://resources/units/vampire_black.tres", Vector2i(0, 0))
	var pawn = make_unit.call("res://resources/units/pawn_blue.tres", Vector2i(1, 0))
	vampire.current_health = 30 # Damaged state (max 70)
	pawn.current_health = 1 # One shot kill to prevent counter-attack
	
	var vamp_res = resolver.resolve_combat(vampire, pawn)
	assert(vampire.current_health > 30, "Vampire must heal from lifesteal!")
	print("✅ [Vampire Lifesteal] Successfully healed from 30 to %d HP after dealing %d damage!" % [vampire.current_health, vamp_res["primary_attack"]["damage"]])
	
	# 2. Test Mage Armor Piercing
	var wizzard = make_unit.call("res://resources/units/wizzard_yellow.tres", Vector2i(2, 2))
	var knight = make_unit.call("res://resources/units/knight_blue.tres", Vector2i(2, 3))
	var warrior = make_unit.call("res://resources/units/warrior_blue.tres", Vector2i(2, 4))
	
	# Physical warrior vs Knight
	var phys_calc = resolver._calculate_damage(warrior, knight)
	# Magic wizzard vs Knight
	var mage_calc = resolver._calculate_damage(wizzard, knight)
	assert(mage_calc["damage_type"] == "magic", "Wizzard deals magic damage")
	assert(mage_calc["damage"] > phys_calc["damage"], "Mage deals much higher damage against heavy armor!")
	print("✅ [Mage Armor Piercing] Magic damage vs Knight: %d (vs Physical: %d)" % [mage_calc["damage"], phys_calc["damage"]])
	
	# 3. Test Cavalry Momentum Charge
	var lancer = make_unit.call("res://resources/units/lancer_blue.tres", Vector2i(5, 5))
	var lancer_calc = resolver._calculate_damage(lancer, pawn)
	assert(lancer_calc["multiplier"] >= 1.5, "Lancer has advantage + momentum multiplier")
	print("✅ [Cavalry Momentum Charge] Lancer total multiplier: %.2fx (Damage: %d)" % [lancer_calc["multiplier"], lancer_calc["damage"]])
	
	# 4. Test Infiltrator Backstab
	var rogue = make_unit.call("res://resources/units/rogue_purple.tres", Vector2i(6, 6))
	var rogue_calc = resolver._calculate_damage(rogue, pawn)
	assert(rogue_calc["multiplier"] >= 1.5, "Rogue has backstab multiplier")
	print("✅ [Infiltrator Backstab] Rogue critical multiplier: %.2fx (Damage: %d)" % [rogue_calc["multiplier"], rogue_calc["damage"]])
	
	# 5. Test Holy Smite vs Undead
	var monk = make_unit.call("res://resources/units/monk_blue.tres", Vector2i(7, 7))
	var skeleton = make_unit.call("res://resources/units/skeleton_black.tres", Vector2i(7, 8))
	var holy_calc = resolver._calculate_damage(monk, skeleton)
	assert(holy_calc["advantage_type"] == "HOLY_EFFECTIVE", "Monk triggers HOLY_EFFECTIVE vs Skeleton")
	print("✅ [Holy Smite vs Undead] Monk vs Skeleton advantage: %s (Multiplier: %.2fx, Damage: %d)" % [holy_calc["advantage_type"], holy_calc["multiplier"], holy_calc["damage"]])
	
	# 6. Test Ranged Attack (Archer at distance 2 does not receive melee counter)
	var archer = make_unit.call("res://resources/units/archer_blue.tres", Vector2i(0, 5))
	var enemy_warrior = make_unit.call("res://resources/units/warrior_red.tres", Vector2i(2, 5)) # Distance = 2
	var archer_res = resolver.resolve_combat(archer, enemy_warrior)
	assert(archer_res["counter_attack"].is_empty(), "Melee defender cannot counter-attack ranged unit from 2 tiles away!")
	print("✅ [Ranged Advantage] Archer attacked from 2 tiles away with ZERO counter-attack received!")
	
	print("🎉 All Combat Logic, Fighting Styles, and Trait Specializations verified successfully!")
	get_tree().quit(0)
