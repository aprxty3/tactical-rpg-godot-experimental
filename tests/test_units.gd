@tool
extends McpTestSuite

func suite_name() -> String:
	return "units"

func test_all_units_validity() -> void:
	var dir := DirAccess.open("res://resources/units/")
	assert_true(dir != null, "resources/units/ must be accessible")
	
	dir.list_dir_begin()
	var filename := dir.get_next()
	var count := 0
	
	while filename != "":
		if filename.ends_with(".tres") and not filename.ends_with(".remap"):
			var res = load("res://resources/units/" + filename)
			assert_true(res != null, "Resource %s must load successfully" % filename)
			if res:
				assert_gt(res.max_health, 0, "%s must have HP > 0" % filename)
				assert_gt(res.attack_power, 0, "%s must have ATK > 0" % filename)
				assert_true(res.defense_power >= 0, "%s must have DEF >= 0" % filename)
				assert_gt(res.movement_points, 0, "%s must have MOV > 0" % filename)
				assert_gt(res.sprite_scale, 0.0, "%s must have baked sprite_scale > 0" % filename)
				count += 1
		filename = dir.get_next()
		
	assert_eq(count, 91, "Expected exactly 91 unit definition resources across 5 factions")
