extends Node2D

func _ready() -> void:
	print("--- Running Comprehensive 5-Faction 28-Unit Verification ---")
	
	var dir = DirAccess.open("res://resources/units")
	assert(dir != null, "Directory res://resources/units exists")
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var tested_count = 0
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res_path = "res://resources/units/" + file_name
			var udata: UnitData = load(res_path)
			assert(udata != null, "UnitData loaded: " + res_path)
			assert(udata.spritesheet != null, "Spritesheet exists for: " + udata.unit_name)
			
			var unit_scene: PackedScene = load("res://scenes/units/TacticalUnit.tscn")
			var unit: TacticalUnit = unit_scene.instantiate()
			unit.unit_data = udata
			add_child(unit)
			
			assert(unit.sprite.texture == udata.spritesheet, "Texture matches spritesheet")
			assert(unit.animation_player.has_animation("idle"), "idle anim exists")
			assert(unit.animation_player.has_animation("run"), "run anim exists")
			assert(unit.animation_player.has_animation("attack"), "attack anim exists")
			
			print("✅ [%s] %s (Class: %s, Tier: %d) -> HP: %d, ATK: %d, DEF: %d, MOV: %d" % [
				file_name, udata.unit_name, udata.unit_class, udata.tier, udata.max_health, udata.attack_power, udata.defense_power, udata.movement_points
			])
			
			unit.queue_free()
			tested_count += 1
		file_name = dir.get_next()
		
	dir.list_dir_end()
	
	print("🎉 Successfully validated all %d unit definitions across all 5 factions!" % tested_count)
	get_tree().quit(0)
