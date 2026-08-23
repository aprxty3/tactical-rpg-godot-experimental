@tool
extends McpTestSuite

func suite_name() -> String:
	return "combat"

func test_combat_advantage_and_specializations() -> void:
	var resolver: CombatResolver = track(CombatResolver.new()) as CombatResolver
	
	# 1. Advantage Check (Melee > Ranged, Ranged > Mage, Mage > Melee)
	var melee_adv = resolver._get_advantage_multiplier("MELEE", "RANGED")
	assert_eq(melee_adv["multiplier"], GameConfig.ADVANTAGE_MULTIPLIER, "Melee must have advantage against Ranged")
	
	var ranged_adv = resolver._get_advantage_multiplier("RANGED", "MAGE")
	assert_eq(ranged_adv["multiplier"], GameConfig.ADVANTAGE_MULTIPLIER, "Ranged must have advantage against Mage")
	
	var mage_adv = resolver._get_advantage_multiplier("MAGE", "MELEE")
	assert_eq(mage_adv["multiplier"], GameConfig.ADVANTAGE_MULTIPLIER, "Mage must have advantage against Melee")
	
	# 2. Holy Smite Check (Support > Undead: 2.5x)
	var holy_adv = resolver._get_advantage_multiplier("SUPPORT", "UNDEAD")
	assert_eq(holy_adv["multiplier"], 2.5, "Holy/Support must deal 2.5x Holy Smite damage to Undead")
