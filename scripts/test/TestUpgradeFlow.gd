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
	print("✅ [Promotion] Pawn -> %s succeeded, HP scaled to %d/%d, gold %d -> %d" % [
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
	print("✅ [Field Tax] Warrior -> %s off-Castle cost %dg (vs %dg at Castle)" % [knight_data.unit_name, field_cost["gold"], castle_cost["gold"]])

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
	print("✅ [Insufficient Funds] Upgrade correctly rejected, unit remained %s" % poor_unit.unit_data.unit_name)

	# 4. Palette-tint sanity: Knight (generic sheet) tints, Pawn (real per-faction art) does not
	assert(knight_data.needs_palette_tint, "Knight is flagged for runtime palette tint")
	var pawn_data: UnitData = load("res://resources/units/pawn_blue.tres")
	assert(not pawn_data.needs_palette_tint, "Pawn keeps its hand-painted art, no tint")
	print("✅ [Palette Tint Flags] Knight=true, Pawn=false as expected")

	print("🎉 Unit Upgrade Tree verified: promotion, Field Tax, funds-guard, and tint flags all correct!")
	get_tree().quit(0)
