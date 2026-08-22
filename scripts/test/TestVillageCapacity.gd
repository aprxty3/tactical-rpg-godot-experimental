extends Node2D

func _ready() -> void:
	print("--- Running Village Economy & Troop Capacity Verification ---")

	var economy := EconomyManager.new()
	add_child(economy)
	economy.register_faction(GameConfig.Faction.BLUE_KINGDOM, 200, 5)
	economy.register_faction(GameConfig.Faction.RED_LEGION, 200, 5)

	var house_scene: PackedScene = load("res://scenes/buildings/House.tscn")
	var house: Building = house_scene.instantiate()
	add_child(house)

	assert(house.faction_id == GameConfig.Faction.NEUTRAL, "House starts neutral")
	assert(economy.get_max_capacity(GameConfig.Faction.BLUE_KINGDOM) == GameConfig.BASE_TROOP_CAPACITY, "Blue starts at base capacity")
	print("✅ [Neutral Village] House starts unowned, base capacity %d" % GameConfig.BASE_TROOP_CAPACITY)

	# 1. Blue captures the village -> +2 TC for Blue
	house.capture(GameConfig.Faction.BLUE_KINGDOM)
	var expected_captured := GameConfig.BASE_TROOP_CAPACITY + GameConfig.VILLAGE_CAPACITY_BONUS
	assert(economy.get_max_capacity(GameConfig.Faction.BLUE_KINGDOM) == expected_captured, "Blue capacity increases by VILLAGE_CAPACITY_BONUS after capture")
	print("✅ [Capture] Blue captures village, capacity %d -> %d" % [GameConfig.BASE_TROOP_CAPACITY, expected_captured])

	# 2. Red recaptures the same village -> Blue's bonus must be removed, Red gains it
	house.capture(GameConfig.Faction.RED_LEGION)
	assert(economy.get_max_capacity(GameConfig.Faction.BLUE_KINGDOM) == GameConfig.BASE_TROOP_CAPACITY, "Blue capacity reverts to base after losing the village")
	assert(economy.get_max_capacity(GameConfig.Faction.RED_LEGION) == expected_captured, "Red capacity increases after recapturing")
	print("✅ [Recapture] Red recaptures village, Blue reverts to %d, Red rises to %d" % [GameConfig.BASE_TROOP_CAPACITY, expected_captured])

	print("🎉 Village Economy & Troop Capacity verified: capture, recapture, and decrement-on-loss all correct!")
	get_tree().quit(0)
