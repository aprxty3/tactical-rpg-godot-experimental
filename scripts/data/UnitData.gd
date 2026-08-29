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

@export_group("Vision & Morale")
## Sight radius in tiles for Fog of War. Leave at 0 to inherit the archetype
## default from GameConfig.VISION_BY_CLASS — that keeps all 91 existing .tres
## files valid without a migration, while still allowing per-unit overrides.
@export var vision_range: int = 0

@export_group("Visuals")
@export var unit_scene: PackedScene
@export var spritesheet: Texture2D
@export var hframes: int = 6
@export var vframes: int = 6
## Per-unit Sprite2D scale. Source art runs 16x16 to 320x320, so one node scale
## would render mages microscopic beside Warriors. Baked offline from the frame's
## content bbox: TARGET_CHAR_PX / content_height.
@export var sprite_scale: float = 1.0
## Sprite2D offset (in unscaled texture pixels) that centers the character
## horizontally and plants its feet on the tile. Also baked offline.
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var sprite_frames: SpriteFrames
@export var portrait: Texture2D

@export_group("Directional Art (optional)")
## Attack sheets by facing: Up, UpRight, Right, DownRight, Down. Left-facing
## halves come from flipping, so five sheets cover eight directions.
##
## **Empty is the supported default** — it reproduces the old flip-only path
## exactly, which is why no existing resource needed migration.
@export var directional_attack: Dictionary = {}
## Frames per directional attack sheet. These are single-row strips, so this is
## the whole layout — the TinySwords cavalry attacks are 3 frames.
@export var directional_attack_hframes: int = 3

@export_group("Mount (optional)")
## Present only on units that ride. Null means "this unit cannot mount", which
## is every unit that does not explicitly opt in.
@export var mount_profile: Resource


# === Derived Data ===
# Pure lookups, not game logic: they resolve a stored value against its
# archetype default so every caller reads the same answer.


## Effective sight radius, falling back to the archetype default.
func get_vision_range() -> int:
	if vision_range > 0:
		return vision_range
	return GameConfig.VISION_BY_CLASS.get(unit_class, GameConfig.VISION_DEFAULT)


## The undead feel no fear: they never gain, lose, or act on morale.
func is_morale_immune() -> bool:
	return unit_class == "Undead"


## `data` rewritten as the given faction's variant — a filename swap, given the
## `{role}_{faction}.tres` convention. Falls back unchanged when no variant
## exists, which is what hands the undead roster to whoever takes the Black
## Castle. Used by captured castles and by defecting prisoners.
static func variant_for_faction(data: UnitData, faction_id: int) -> UnitData:
	if not is_instance_valid(data):
		return data
	var suffix: String = GameConfig.FACTION_SUFFIX.get(faction_id, "")
	if suffix == "":
		return data
	var path: String = data.resource_path
	if path == "":
		return data
	var base: String = path.get_basename()
	var idx: int = base.rfind("_")
	if idx <= 0:
		return data
	var variant: String = "%s_%s.tres" % [base.substr(0, idx), suffix]
	if variant == path or not ResourceLoader.exists(variant):
		return data
	var loaded: UnitData = load(variant) as UnitData
	return loaded if is_instance_valid(loaded) else data
