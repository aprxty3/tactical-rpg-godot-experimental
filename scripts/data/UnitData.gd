extends Resource
class_name UnitData
## UnitData — Pure data container for unit stats and configuration.
## No logic, no signals — just exported properties for the Inspector.
## Create .tres files in res://resources/units/ for each unit type.

@export_group("Identity")
@export var unit_name: String = "Pawn"
## Unit archetype class (Worker, Melee, Cavalry, Ranged, Mage, Support, Infiltrator, Undead)
@export var unit_class: String = "Worker"
## Progression tier: 1 (base), 2 (advanced), 3 (elite)
@export var tier: int = 1
@export var description: String = ""

@export_group("Combat Stats")
@export var max_health: int = 100
@export var attack_power: int = 25
@export var defense_power: int = 10
## Grid tiles the unit can move per turn
@export var movement_points: int = 3
## Minimum attack range in tiles (1 = melee)
@export var attack_range_min: int = 1
## Maximum attack range in tiles (Archer = 3, Wizzard = 2)
@export var attack_range_max: int = 1

@export_group("Economy & Logistics")
## Gold cost to recruit this unit at a Castle
@export var recruit_cost_gold: int = 50
## Iron cost to recruit (0 for magic/support units)
@export var recruit_cost_iron: int = 1
## Troop Capacity weight: Tier1=1, Tier2=2, Tier3=3
@export var capacity_weight: int = 1

@export_group("Progression")
## Mapping of upgrade target name to its UnitData resource.
## Example: {"Knight": preload("res://resources/units/knight.tres")}
@export var upgrade_paths: Dictionary = {}

@export_group("Visuals")
@export var unit_scene: PackedScene
@export var spritesheet: Texture2D
@export var hframes: int = 6
@export var vframes: int = 6
@export var sprite_frames: SpriteFrames
@export var portrait: Texture2D
