extends Node2D

func _ready() -> void:
	print("--- Running Comprehensive Faction & Animation Verification ---")
	
	var unit_scene: PackedScene = load("res://scenes/units/TacticalUnit.tscn")
	var unit_files = [
		"res://resources/units/pawn_blue.tres",
		"res://resources/units/warrior_blue.tres",
		"res://resources/units/archer_blue.tres",
		"res://resources/units/pawn_red.tres",
		"res://resources/units/warrior_red.tres",
		"res://resources/units/archer_red.tres",
		"res://resources/units/pawn_yellow.tres",
		"res://resources/units/warrior_yellow.tres",
		"res://resources/units/archer_yellow.tres",
		"res://resources/units/priest_yellow.tres",
		"res://resources/units/wizzard_yellow.tres",
		"res://resources/units/pawn_purple.tres",
		"res://resources/units/warrior_purple.tres",
		"res://resources/units/archer_purple.tres",
		"res://resources/units/rogue_purple.tres",
		"res://resources/units/skeleton_black.tres",
		"res://resources/units/vampire_black.tres",
	]
	
	for path in unit_files:
		var udata: UnitData = load(path)
		assert(udata != null, "UnitData loaded: " + path)
		assert(udata.spritesheet != null, "Spritesheet loaded: " + path)
		
		var unit: TacticalUnit = unit_scene.instantiate()
		unit.unit_data = udata
		add_child(unit)
		
		# Verify texture and dimensions
		assert(unit.sprite.texture == udata.spritesheet, "Texture must match spritesheet for " + udata.unit_name)
		assert(unit.sprite.hframes == udata.hframes, "hframes match for " + udata.unit_name)
		assert(unit.sprite.vframes == udata.vframes, "vframes match for " + udata.unit_name)
		
		# Verify animations
		assert(unit.animation_player.has_animation("idle"), "idle anim exists for " + udata.unit_name)
		assert(unit.animation_player.has_animation("run"), "run anim exists for " + udata.unit_name)
		assert(unit.animation_player.has_animation("attack"), "attack anim exists for " + udata.unit_name)
		
		# Verify Archer specific animation frame tracks
		if udata.unit_class == "Ranged":
			var anim = unit.animation_player.get_animation("attack")
			assert(anim != null, "Archer attack animation exists")
			print("🏹 Verified Archer Animation: length=", anim.length, " loop=", anim.loop_mode)
		
		print("✅ Verified unit: ", udata.unit_name, " (", udata.unit_class, ") - Spritesheet: ", udata.spritesheet.resource_path)
		unit.queue_free()
	
	print("🎉 All 17 unit resources across 5 factions verified successfully with ZERO errors!")
	get_tree().quit(0)
