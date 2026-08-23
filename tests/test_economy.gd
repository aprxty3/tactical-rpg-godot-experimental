@tool
extends McpTestSuite

func suite_name() -> String:
	return "economy"

func test_faction_treasury_and_income() -> void:
	var eco: EconomyManager = track(preload("res://scripts/managers/EconomyManager.gd").new()) as EconomyManager
	eco.register_faction(GameConfig.Faction.BLUE_KINGDOM, 200, 6)
	
	assert_eq(eco.get_gold(GameConfig.Faction.BLUE_KINGDOM), 200, "Initial gold must be 200")
	assert_eq(eco.get_iron(GameConfig.Faction.BLUE_KINGDOM), 6, "Initial iron must be 6")
	
	# Spend gold
	var spent = eco.spend_gold(GameConfig.Faction.BLUE_KINGDOM, 50)
	assert_true(spent, "Spending 50 gold should succeed")
	assert_eq(eco.get_gold(GameConfig.Faction.BLUE_KINGDOM), 150, "Gold remaining should be 150")
	
	# Capacity bump (+2 per village)
	assert_eq(eco.get_max_capacity(GameConfig.Faction.BLUE_KINGDOM), 8, "Base capacity is 8")
	eco._on_resource_node_captured("village", GameConfig.Faction.BLUE_KINGDOM, GameConfig.Faction.NEUTRAL)
	assert_eq(eco.get_max_capacity(GameConfig.Faction.BLUE_KINGDOM), 10, "Capacity after 1 village must be 10")
