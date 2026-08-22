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


func _ready() -> void:
	add_to_group("buildings")
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
			gold = 20 # Bonus pendapatan pasif kastil

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


## Capture the building for a new faction
func capture(new_faction_id: int) -> void:
	if faction_id == new_faction_id:
		return
	
	var old_faction = faction_id
	faction_id = new_faction_id
	_update_visuals()
	
	EventBus.building_captured.emit(self, new_faction_id)
	EventBus.resource_node_captured.emit(get_type_string(), new_faction_id)


## Check if this castle can recruit a specific unit (cost & capacity)
func can_recruit(unit_data: UnitData, economy_mgr: Node, active_units: Array) -> Dictionary:
	if building_type != BuildingType.CASTLE:
		return {"can_recruit": false, "reason": "Hanya Castle yang bisa merekrut!"}
	if not is_instance_valid(unit_data):
		return {"can_recruit": false, "reason": "Data unit tidak valid."}

	# 1. Cek Biaya Gold
	if economy_mgr.get_gold(faction_id) < unit_data.recruit_cost_gold:
		return {"can_recruit": false, "reason": "Gold tidak cukup! (Butuh %d Gold)" % unit_data.recruit_cost_gold}

	# 2. Cek Biaya Iron
	if economy_mgr.get_iron(faction_id) < unit_data.recruit_cost_iron:
		return {"can_recruit": false, "reason": "Iron tidak cukup! (Butuh %d Iron)" % unit_data.recruit_cost_iron}

	# 3. Cek Troop Capacity
	var max_cap = economy_mgr.get_max_capacity(faction_id)
	var used_cap = economy_mgr.get_used_capacity(faction_id, active_units)
	if used_cap + unit_data.capacity_weight > max_cap:
		return {"can_recruit": false, "reason": "Kapasitas Pasukan (Troop Capacity) Penuh! (%d/%d)" % [used_cap, max_cap]}

	return {"can_recruit": true, "reason": "OK"}


## Eksekusi rekrut unit di sekitar kastil
func recruit_unit(unit_data: UnitData, spawn_cell: Vector2i, economy_mgr: Node, parent_node: Node) -> TacticalUnit:
	# Bayar biaya
	economy_mgr.spend_gold(faction_id, unit_data.recruit_cost_gold)
	economy_mgr.spend_iron(faction_id, unit_data.recruit_cost_iron)

	# Instansiasi unit baru (Gunakan prefab khusus dari UnitData jika ada, fallback ke default)
	var prefab: PackedScene = unit_data.unit_scene if (unit_data and is_instance_valid(unit_data.unit_scene)) else unit_scene_prefab
	var new_unit: TacticalUnit = prefab.instantiate() as TacticalUnit
	new_unit.unit_data = unit_data
	new_unit.faction_id = faction_id
	new_unit.grid_position = spawn_cell
	new_unit.scale = Vector2(0.45, 0.45)
	
	parent_node.add_child(new_unit)
	if new_unit.has_method("_initialize_from_data"):
		new_unit._initialize_from_data()
	
	EventBus.unit_recruited.emit(new_unit, faction_id)
	EventBus.unit_spawned.emit(new_unit, faction_id)

	return new_unit


func _update_visuals() -> void:
	if not sprite:
		return
	# Visual update based on faction
	# For example, if there is a specific texture per faction
	match faction_id:
		GameConfig.Faction.BLUE_KINGDOM:
			modulate = Color(1.0, 1.0, 1.0, 1.0)
		GameConfig.Faction.RED_LEGION:
			modulate = Color(1.0, 0.6, 0.6, 1.0)
		_:
			modulate = Color(0.8, 0.8, 0.8, 1.0)
