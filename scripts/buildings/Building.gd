extends Node2D
class_name Building
## Building — Actor layer node for capturable structures, resource nodes, and recruitment hubs.
## Decoupled: Emits events via EventBus, registers position in GridManager.

const EconomyManagerScript = preload("res://scripts/managers/EconomyManager.gd")

enum BuildingType {
	CASTLE,
	GOLD_MINE,
	IRON_MINE,
	HOUSE,
	TOWER
}

## What ending a move on this building does for the arriving faction.
enum Claim {
	NOTHING,   ## Walked over. No flag changes, nothing burns.
	CAPTURE,   ## Flag changes to the arriving faction.
	RAZE,      ## Burned off the map entirely.
}

## The only building type a marauder can affect, and it destroys rather than
## takes it. Lives here rather than in GameConfig because it is keyed on
## `BuildingType`, and a rule keyed on an enum belongs beside that enum.
const MARAUDER_RAZES: Array[BuildingType] = [BuildingType.HOUSE]

## Folder name of each faction's hand-painted building set.
const FACTION_ART_DIR: Dictionary = {
	GameConfig.Faction.BLUE_KINGDOM: "Blue",
	GameConfig.Faction.RED_LEGION: "Red",
	GameConfig.Faction.PURPLE_SYNDICATE: "Purple",
	GameConfig.Faction.YELLOW_EMPIRE: "Yellow",
	GameConfig.Faction.BLACK_COVEN: "Black",
}

## Building types that ship a real per-faction sprite. Capturing one of these
## swaps the texture outright, so a captured Castle becomes the capturing
## faction's Castle rather than the old owner's tinted a bit differently.
const FACTION_ART_FILE: Dictionary = {
	BuildingType.CASTLE: "Castle.png",
	BuildingType.HOUSE: "House1.png",
	BuildingType.TOWER: "Tower.png",
}

## Resource nodes (mines) have no per-faction art in the pack, so ownership is
## shown with a generated pennant instead — see _update_faction_banner().
const BANNER_NAME: StringName = &"FactionBanner"

@export_group("Building Properties")
@export var building_type: BuildingType = BuildingType.CASTLE
@export var faction_id: int = GameConfig.Faction.NEUTRAL
@export var grid_position: Vector2i = Vector2i.ZERO

@export_group("Recruitment (Castle Only)")
## List of UnitData that can be recruited at this building
@export var recruitable_units: Array[UnitData] = []
## Unit scene prefab for spawning
@export var unit_scene_prefab: PackedScene = preload("res://scenes/units/TacticalUnit.tscn")

# Node References
@onready var sprite: Sprite2D = $Sprite2D


var _neutral_texture: Texture2D


func _ready() -> void:
	add_to_group("buildings")
	if sprite:
		_neutral_texture = sprite.texture
	_update_visuals()


## Get resource income per turn (Gold & Iron)
func get_income() -> Dictionary:
	var gold = 0
	var iron = 0
	match building_type:
		BuildingType.GOLD_MINE:
			gold = GameConfig.GOLD_MINE_INCOME
		BuildingType.IRON_MINE:
			iron = GameConfig.IRON_MINE_INCOME
		BuildingType.HOUSE:
			gold = GameConfig.HOUSE_GOLD_INCOME
		BuildingType.CASTLE:
			gold = GameConfig.CASTLE_GOLD_INCOME

	return {"gold": gold, "iron": iron}


## Get the building type string for event & tracking
func get_type_string() -> String:
	match building_type:
		BuildingType.CASTLE:
			return "castle"
		BuildingType.GOLD_MINE:
			return "gold_mine"
		BuildingType.IRON_MINE:
			return "iron_mine"
		BuildingType.HOUSE:
			return "village"
		BuildingType.TOWER:
			return "tower"
	return "unknown"


## What `faction_id` gets for ending a move here — the single place "who may
## take what" is answered, because three callers used to imply their own answer
## by calling `capture()` directly. Monsters raid rather than conquer: keeps and
## mines are scenery to them, a village is something to burn.
func claim_for(arriving_faction_id: int) -> Claim:
	if faction_id == arriving_faction_id:
		return Claim.NOTHING
	if GameConfig.is_marauder(arriving_faction_id):
		# A marauder cannot burn what nobody holds: an unclaimed village is not
		# a supply line, and razing neutral ground would just strip the map.
		if building_type in MARAUDER_RAZES and faction_id != GameConfig.Faction.NEUTRAL:
			return Claim.RAZE
		return Claim.NOTHING
	# A marauder's ground IS claimable — clearing the den is the point of the
	# encounter, and an earlier version refusing it made the boss a wall with
	# nothing behind it. Nothing extra guards the keep: the boss stands ON its
	# cell and a move cannot end on an occupied one, so the board enforces
	# "kill the guardian first".
	return Claim.CAPTURE


## Emits before freeing so listeners still get a valid node to read owner and
## type off. `remove_from_group` is not optional: income, capacity, victory and
## the AI all walk that group, and a queued-but-unfreed node would keep paying
## its owner for another turn.
func raze() -> void:
	remove_from_group("buildings")
	# `building_destroyed` only. `resource_node_captured` would have been the
	# lazy way to make the economy notice, but it means "this now belongs to
	# someone", and it would have credited a village to faction NEUTRAL — a
	# faction with no treasury and no troops to give capacity to.
	EventBus.building_destroyed.emit(self)
	queue_free()


## Capture the building for a new faction
func capture(new_faction_id: int) -> void:
	if faction_id == new_faction_id:
		return
	
	var old_faction = faction_id
	faction_id = new_faction_id
	_update_visuals()
	
	EventBus.building_captured.emit(self, new_faction_id)
	EventBus.resource_node_captured.emit(get_type_string(), new_faction_id, old_faction)


## Check if this castle can recruit a specific unit (cost & capacity)
func can_recruit(unit_data: UnitData, economy_mgr: Node, active_units: Array) -> Dictionary:
	if building_type != BuildingType.CASTLE:
		return {"can_recruit": false, "reason": "Hanya Castle yang bisa merekrut!"}
	if not is_instance_valid(unit_data):
		return {"can_recruit": false, "reason": "Data unit tidak valid."}

	# Price the variant that will actually be spawned (a captured castle
	# recruits the new owner's troops, not the previous owner's).
	unit_data = resolve_for_owner(unit_data)

	# 1. Cek Biaya Gold
	if economy_mgr.get_gold(faction_id) < unit_data.recruit_cost_gold:
		return {"can_recruit": false, "reason": "Gold tidak cukup! (Butuh %d Gold)" % unit_data.recruit_cost_gold}

	# 2. Cek Biaya Iron
	if economy_mgr.get_iron(faction_id) < unit_data.recruit_cost_iron:
		return {"can_recruit": false, "reason": "Iron tidak cukup! (Butuh %d Iron)" % unit_data.recruit_cost_iron}

	# 3. Cek Troop Capacity. Delegated so this rule reads the same here, at a
	#    surrender prompt and at a mercenary payout — a heavy unit that does not
	#    fit must be refused even when there is a point or two of room left.
	if not economy_mgr.has_capacity_for(faction_id, unit_data.capacity_weight, active_units):
		var max_cap: int = economy_mgr.get_max_capacity(faction_id)
		var used_cap: int = economy_mgr.get_used_capacity(faction_id, active_units)
		return {"can_recruit": false,
			"reason": "Kapasitas Pasukan penuh! (%d/%d, %s butuh %d)" % [
				used_cap, max_cap, unit_data.unit_name, unit_data.capacity_weight]}

	return {"can_recruit": true, "reason": "OK"}


## Eksekusi rekrut unit di sekitar kastil
func recruit_unit(unit_data: UnitData, spawn_cell: Vector2i, economy_mgr: Node, parent_node: Node) -> TacticalUnit:
	# Bayar biaya (harga varian yang benar-benar di-spawn)
	var to_spawn: UnitData = resolve_for_owner(unit_data)
	economy_mgr.spend_gold(faction_id, to_spawn.recruit_cost_gold)
	economy_mgr.spend_iron(faction_id, to_spawn.recruit_cost_iron)

	unit_data = to_spawn

	# Instansiasi unit baru (Gunakan prefab khusus dari UnitData jika ada, fallback ke default)
	var prefab: PackedScene = unit_data.unit_scene if (unit_data and is_instance_valid(unit_data.unit_scene)) else unit_scene_prefab
	var new_unit: TacticalUnit = prefab.instantiate() as TacticalUnit
	new_unit.unit_data = unit_data
	new_unit.faction_id = faction_id
	new_unit.grid_position = spawn_cell
	# No node-level scale: TacticalUnit sizes its own Sprite2D from the
	# per-unit metrics baked into UnitData (sprite_scale / sprite_offset),
	# so 32px mage art and 192px TinySwords art end up the same height.
	
	parent_node.add_child(new_unit)
	if new_unit.has_method("_initialize_from_data"):
		new_unit._initialize_from_data()
	
	EventBus.unit_recruited.emit(new_unit, faction_id)
	EventBus.unit_spawned.emit(new_unit, faction_id)

	return new_unit


## Castles are capturable, so without this a Blue army taking the Yellow keep
## would recruit yellow-sprited troops fighting for Blue. The lookup lives on
## UnitData because defection needs the identical one.
func resolve_for_owner(data: UnitData) -> UnitData:
	return UnitData.variant_for_faction(data, faction_id)


func _update_visuals() -> void:
	if not sprite:
		return
	_update_faction_texture()
	_update_faction_banner()


## Swap in the owning faction's own building sprite where the art pack has one.
## Falls back to the scene's authored (neutral / construction) texture.
func _update_faction_texture() -> void:
	var dir_name: String = FACTION_ART_DIR.get(faction_id, "")
	var file_name: String = FACTION_ART_FILE.get(building_type, "")

	if dir_name != "" and file_name != "":
		var path := "res://assets/buildings/%s Buildings/%s" % [dir_name, file_name]
		if ResourceLoader.exists(path):
			sprite.texture = load(path)
			modulate = Color.WHITE
			return

	# No faction art for this type (mines) or the building is still neutral.
	if is_instance_valid(_neutral_texture):
		sprite.texture = _neutral_texture
	modulate = Color.WHITE if faction_id != GameConfig.Faction.NEUTRAL else Color(0.82, 0.82, 0.86, 1.0)


## Plant a faction-coloured pennant above the building. Mines have no
## recoloured art, so without this a captured Gold Mine looks untouched; the
## pennant also gives every building type one consistent ownership tell.
func _update_faction_banner() -> void:
	var banner: Node2D = get_node_or_null(NodePath(BANNER_NAME))

	if faction_id == GameConfig.Faction.NEUTRAL:
		if is_instance_valid(banner):
			banner.queue_free()
		return

	var tint: Color = GameConfig.FACTION_TINT_COLORS.get(faction_id, Color.WHITE)

	if not is_instance_valid(banner):
		banner = Node2D.new()
		banner.name = BANNER_NAME
		var pole := Polygon2D.new()
		pole.name = "Pole"
		pole.polygon = PackedVector2Array([
			Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(1.5, -26), Vector2(-1.5, -26)
		])
		pole.color = Color(0.24, 0.18, 0.12)
		banner.add_child(pole)
		var flag := Polygon2D.new()
		flag.name = "Flag"
		flag.polygon = PackedVector2Array([
			Vector2(1.5, -26), Vector2(20, -21), Vector2(1.5, -16)
		])
		banner.add_child(flag)
		add_child(banner)

	var flag_node := banner.get_node_or_null("Flag") as Polygon2D
	if flag_node:
		flag_node.color = tint

	# Sit the pole just above the sprite's drawn top edge, whatever its size.
	var top: float = -24.0
	if is_instance_valid(sprite.texture):
		top = -0.5 * sprite.texture.get_height() * absf(sprite.scale.y) + sprite.offset.y
	banner.position = Vector2(0, top + 6.0)
	banner.z_index = 1
