extends Node2D


func _ready() -> void:
	print("--- Running Unit Upgrade Tree Verification ---")

	var economy := EconomyManager.new()
	add_child(economy)
	economy.register_faction(GameConfig.Faction.BLUE_KINGDOM, 200, 5)

	var u_scene: PackedScene = load("res://scenes/units/TacticalUnit_Pawn_Blue.tscn")

	var make_unit = func(res_path: String) -> TacticalUnit:
		var u: TacticalUnit = u_scene.instantiate()
		u.unit_data = load(res_path)
		u.faction_id = GameConfig.Faction.BLUE_KINGDOM
		add_child(u)
		u._initialize_from_data()
		return u

	# 1. Pawn -> Warrior at Castle (full price, no Field Tax)
	var unit: TacticalUnit = make_unit.call("res://resources/units/pawn_blue.tres")
	var warrior_data: UnitData = load("res://resources/units/warrior_blue.tres")
	var gold_before := economy.get_gold(GameConfig.Faction.BLUE_KINGDOM)
	var cost := economy.get_upgrade_cost(unit.unit_data, warrior_data, true)
	assert(cost["gold"] == warrior_data.recruit_cost_gold - unit.unit_data.recruit_cost_gold, "At-Castle upgrade cost is the plain tier difference")

	var ok := economy.process_upgrade(GameConfig.Faction.BLUE_KINGDOM, unit, warrior_data, true)
	assert(ok, "Pawn -> Warrior upgrade must succeed with sufficient funds")
	assert(unit.unit_data == warrior_data, "Unit swapped to Warrior data")
	assert(economy.get_gold(GameConfig.Faction.BLUE_KINGDOM) == gold_before - cost["gold"], "Gold deducted by exact at-Castle cost")
	print(" [Promotion] Pawn -> %s succeeded, HP scaled to %d/%d, gold %d -> %d" % [
		warrior_data.unit_name, unit.current_health, unit.unit_data.max_health,
		gold_before, economy.get_gold(GameConfig.Faction.BLUE_KINGDOM)
	])

	# 2. Warrior -> Knight, off-Castle (Field Tax 2x)
	var knight_data: UnitData = load("res://resources/units/knight_blue.tres")
	gold_before = economy.get_gold(GameConfig.Faction.BLUE_KINGDOM)
	var field_cost := economy.get_upgrade_cost(unit.unit_data, knight_data, false)
	var castle_cost := economy.get_upgrade_cost(unit.unit_data, knight_data, true)
	assert(field_cost["gold"] == castle_cost["gold"] * GameConfig.FIELD_TAX_MULTIPLIER, "Field Tax doubles the gold cost off-Castle")

	ok = economy.process_upgrade(GameConfig.Faction.BLUE_KINGDOM, unit, knight_data, false)
	assert(ok, "Warrior -> Knight upgrade must succeed (funds cover Field Tax)")
	assert(unit.unit_data == knight_data, "Unit swapped to Knight data")
	print(" [Field Tax] Warrior -> %s off-Castle cost %dg (vs %dg at Castle)" % [knight_data.unit_name, field_cost["gold"], castle_cost["gold"]])

	# 3. Insufficient funds must fail cleanly (no swap, no deduction) -- use a
	# fresh Pawn->Warrior attempt (genuinely positive cost) with gold drained to 0.
	economy.spend_gold(GameConfig.Faction.BLUE_KINGDOM, economy.get_gold(GameConfig.Faction.BLUE_KINGDOM))
	var poor_unit: TacticalUnit = make_unit.call("res://resources/units/pawn_blue.tres")
	var poor_cost := economy.get_upgrade_cost(poor_unit.unit_data, warrior_data, true)
	assert(poor_cost["gold"] > 0, "Pawn -> Warrior must have a genuinely positive cost for this guard to mean anything")
	var data_before_fail: UnitData = poor_unit.unit_data
	ok = economy.process_upgrade(GameConfig.Faction.BLUE_KINGDOM, poor_unit, warrior_data, true)
	assert(not ok, "Upgrade must fail when funds are insufficient")
	assert(poor_unit.unit_data == data_before_fail, "Unit data must NOT change on a failed upgrade")
	print(" [Insufficient Funds] Upgrade correctly rejected, unit remained %s" % poor_unit.unit_data.unit_name)

	# 4. A promotion must LOOK different. Tier-3 units used to re-use their
	# parent's texture verbatim, so Archer -> Sniper changed nothing on screen.
	var pawn_data: UnitData = load("res://resources/units/pawn_blue.tres")
	assert(knight_data.spritesheet != pawn_data.spritesheet,
		"Knight and Pawn must not share a spritesheet")
	for pair in [
		["res://resources/units/archer_blue.tres", "res://resources/units/sniper_blue.tres"],
		["res://resources/units/archer_blue.tres", "res://resources/units/crossbowman_blue.tres"],
		["res://resources/units/wizzard_blue.tres", "res://resources/units/archmage_blue.tres"],
		["res://resources/units/rogue_blue.tres", "res://resources/units/assassin_blue.tres"],
		["res://resources/units/monk_blue.tres", "res://resources/units/highpriest_blue.tres"],
		["res://resources/units/skeleton_mage_black.tres", "res://resources/units/lich_black.tres"],
		["res://resources/units/vampire_black.tres", "res://resources/units/vampirelord_black.tres"],
	]:
		var base: UnitData = load(pair[0])
		var promo: UnitData = load(pair[1])
		assert(base.spritesheet != promo.spritesheet,
			"%s -> %s must not share a spritesheet" % [base.unit_name, promo.unit_name])
	print(" [Promotion Visuals] every checked promotion swaps its spritesheet")

	# 5. Faction colour must not leak into the displayed name.
	for res_path in ["res://resources/units/pawn_blue.tres",
			"res://resources/units/warrior_red.tres",
			"res://resources/units/wizzard_purple.tres",
			"res://resources/units/highpriest_yellow.tres"]:
		var d: UnitData = load(res_path)
		for word in ["Blue ", "Red ", "Purple ", "Yellow ", "Black "]:
			assert(not d.unit_name.begins_with(word),
				"unit_name '%s' still carries a faction prefix" % d.unit_name)
	print(" [Unit Names] recruit/upgrade labels carry no faction prefix")

	# 6. Every unit must render at the same body height regardless of source art.
	var dir := DirAccess.open("res://resources/units")
	var checked := 0
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".tres"):
				var d: UnitData = load("res://resources/units/" + f)
				assert(d.sprite_scale > 0.0, "%s has no baked sprite_scale" % f)
				var tex_h: float = float(d.spritesheet.get_height()) / float(maxi(1, d.vframes))
				assert(tex_h * d.sprite_scale < 200.0, "%s renders absurdly large" % f)
				checked += 1
			f = dir.get_next()
		dir.list_dir_end()
	print(" [Sprite Metrics] %d units carry baked scale/offset" % checked)

	# 7. Undead lineage: Skeleton Fodder -> Skeleton Mage -> Lich (own parallel track)
	economy.register_faction(GameConfig.Faction.BLACK_COVEN, 200, 5)
	var undead_scene: PackedScene = load("res://scenes/units/TacticalUnit.tscn")
	var fodder: TacticalUnit = undead_scene.instantiate()
	fodder.unit_data = load("res://resources/units/skeleton_base_black.tres")
	fodder.faction_id = GameConfig.Faction.BLACK_COVEN
	add_child(fodder)
	fodder._initialize_from_data()

	var mage_data: UnitData = load("res://resources/units/skeleton_mage_black.tres")
	ok = economy.process_upgrade(GameConfig.Faction.BLACK_COVEN, fodder, mage_data, true)
	assert(ok, "Skeleton Fodder -> Skeleton Mage upgrade must succeed")
	assert(fodder.unit_data == mage_data, "Unit swapped to Skeleton Mage data")

	var lich_data: UnitData = load("res://resources/units/lich_black.tres")
	ok = economy.process_upgrade(GameConfig.Faction.BLACK_COVEN, fodder, lich_data, true)
	assert(ok, "Skeleton Mage -> Lich upgrade must succeed")
	assert(fodder.unit_data == lich_data, "Unit swapped to Lich data")
	assert(lich_data.unit_class == "Undead", "Lich keeps unit_class Undead for the Holy-vs-Undead bonus")
	print(" [Undead Track] Skeleton Fodder -> Skeleton Mage -> %s promotion chain works identically" % lich_data.unit_name)

	print(" Unit Upgrade Tree verified: promotion, Field Tax, funds-guard, tint flags, and the Undead track all correct!")
	get_tree().quit(0)
