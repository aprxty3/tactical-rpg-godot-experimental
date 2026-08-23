extends Node
## GameConfig — Global constants, enums, and configuration (Autoload Singleton).
## Pure data: no signals, no logic, just shared definitions.

# === Faction IDs ===
enum Faction {
	BLUE_KINGDOM = 0,
	RED_LEGION = 1,
	PURPLE_SYNDICATE = 2,
	YELLOW_EMPIRE = 3,
	BLACK_COVEN = 4,
	NEUTRAL = 99,
}

# === Turn Phases ===
enum Phase {
	UPKEEP,           # Collect income, check logistics, reset units
	PRODUCTION,       # Recruit units, construct buildings
	ACTION,           # Move, attack, interact, capture
	END_TURN,         # Evaluate victory/defeat, switch faction
}

# === Unit Class Types ===
enum UnitClass {
	WORKER,           # Pawn — captures, builds
	MELEE,            # Warrior, Knight — frontline
	CAVALRY,          # Knight (mounted) — heavy charge
	RANGED,           # Archer — physical ranged
	MAGE,             # Wizzard — AoE magic
	SUPPORT,          # Priest — healer & buffer
	INFILTRATOR,      # Rogue — backstab & stealth
	UNDEAD,           # Skeleton, Vampire — dark faction
}

# === Damage Types ===
enum DamageType {
	PHYSICAL,
	MAGICAL,
	HOLY,
	TRUE,             # Ignores defense (starvation, TNT explosion)
	FIRE,
	POISON,
}

# === Morale Levels (Milestone 4 — Roadmap) ===
enum MoraleLevel {
	FEARLESS = 4,     # +15% ATK, immune to surrender
	EAGER = 3,        # +5% ATK
	FAIR = 2,         # Neutral (default)
	SHAKEN = 1,       # -10% ATK, can be forced to surrender
	FEARFUL = 0,      # -20% ATK, auto-desert chance
}

# === Combat Advantage Multipliers ===
const ADVANTAGE_MULTIPLIER: float = 1.5   # Strong matchup
const DISADVANTAGE_MULTIPLIER: float = 0.7 # Weak matchup
const NEUTRAL_MULTIPLIER: float = 1.0
const HOLY_VS_UNDEAD_MULTIPLIER: float = 2.5  # Priest vs Skeleton/Vampire

# === Economy Constants ===
const BASE_TROOP_CAPACITY: int = 8
const VILLAGE_CAPACITY_BONUS: int = 2
const GOLD_MINE_INCOME: int = 50
const IRON_MINE_INCOME: int = 30
const HOUSE_GOLD_INCOME: int = 10
const FIELD_TAX_MULTIPLIER: int = 2       # 200% cost for field upgrades
const STARVATION_DAMAGE: int = 15         # True damage per overcap turn

# === Faction Resource Suffix ===
## Unit resources follow a `{role}_{faction}.tres` convention. This maps a
## faction onto that suffix, so anything that needs "the Blue version of this
## unit" — recruiting at a captured castle, or a unit defecting after it
## surrenders — resolves it the same way.
const FACTION_SUFFIX: Dictionary = {
	Faction.BLUE_KINGDOM: "blue",
	Faction.RED_LEGION: "red",
	Faction.PURPLE_SYNDICATE: "purple",
	Faction.YELLOW_EMPIRE: "yellow",
	Faction.BLACK_COVEN: "black",
}

# === Faction Palette-Tint Colors (for generic, non-recolored spritesheets) ===
const FACTION_TINT_COLORS: Dictionary = {
	Faction.BLUE_KINGDOM: Color(0.25, 0.55, 1.0),
	Faction.RED_LEGION: Color(0.95, 0.25, 0.2),
	Faction.PURPLE_SYNDICATE: Color(0.6, 0.25, 0.85),
	Faction.YELLOW_EMPIRE: Color(0.95, 0.8, 0.15),
	Faction.BLACK_COVEN: Color(0.35, 0.32, 0.4),
}

# === Map Event Probabilities (Pandora's Box) ===
const PANDORA_WAR_SPOILS_CHANCE: float = 0.50
const PANDORA_MERCENARY_CHANCE: float = 0.20
const PANDORA_TRAP_CHANCE: float = 0.15
const PANDORA_AWAKEN_DEAD_CHANCE: float = 0.15

# ==============================================================================
# MILESTONE 4 — Terrain, Morale, Vision, Hazards
# ==============================================================================

# === Terrain Types ===
## Per-cell terrain classification. MapBuilder derives it while painting the
## battlefield; GridManager stores it and is the single authority queried by
## CombatResolver (cover), VisionManager (concealment) and MapObjectManager
## (fire spread).
enum TerrainType {
	PLAIN,      # Open grass — no cover, no cost
	ROAD,       # Fast but exposed
	FOREST,     # Cover + concealment + ambush source
	ROCK,       # Heavy cover + concealment, no ambush
	WATER,      # Impassable
	BRIDGE,     # Fast, and the most exposed tile on the map
	SCORCHED,   # Forest that burned down — cover is gone for good
}

## Rules per terrain type.
##
## `damage_taken_mult` multiplies damage dealt TO a unit standing on the cell,
## so values BELOW 1.0 are good cover and values ABOVE 1.0 are exposure. It
## feeds CombatResolver's `terrain_def_mult` hook directly.
## `conceals` hides the occupant from any viewer further than
## VISION_CONCEALED_REVEAL_RANGE — the Advance Wars forest rule.
## `flammable` is the per-tick chance that an adjacent fire spreads here.
const TERRAIN_RULES: Dictionary = {
	TerrainType.PLAIN:    {"name": "Plain",    "move_cost": 1,  "damage_taken_mult": 1.00, "conceals": false, "ambush": false, "flammable": 0.12},
	TerrainType.ROAD:     {"name": "Road",     "move_cost": 1,  "damage_taken_mult": 1.15, "conceals": false, "ambush": false, "flammable": 0.00},
	TerrainType.FOREST:   {"name": "Forest",   "move_cost": 2,  "damage_taken_mult": 0.75, "conceals": true,  "ambush": true,  "flammable": 0.55},
	TerrainType.ROCK:     {"name": "Rocks",    "move_cost": 2,  "damage_taken_mult": 0.70, "conceals": true,  "ambush": false, "flammable": 0.00},
	TerrainType.WATER:    {"name": "Water",    "move_cost": 99, "damage_taken_mult": 1.00, "conceals": false, "ambush": false, "flammable": 0.00},
	TerrainType.BRIDGE:   {"name": "Bridge",   "move_cost": 1,  "damage_taken_mult": 1.25, "conceals": false, "ambush": false, "flammable": 0.00},
	TerrainType.SCORCHED: {"name": "Scorched", "move_cost": 1,  "damage_taken_mult": 1.05, "conceals": false, "ambush": false, "flammable": 0.00},
}

## Movement cost treated as "unreachable". Any cost at or above this is pruned
## by the movement field rather than being paid.
const MOVE_COST_IMPASSABLE: int = 99

# === Morale ===
## Morale is a scalar 0..100 owned by TacticalUnit. MoraleLevel is derived from
## it (an enum FSM — 5 states, one concern, no nesting), so tuning happens on
## the scalar while gameplay reads the level.
const MORALE_MAX: int = 100
const MORALE_DEFAULT: int = 55

## Lower bound (inclusive) of each level, highest first.
const MORALE_THRESHOLDS: Array = [
	{"min": 90, "level": MoraleLevel.FEARLESS},
	{"min": 70, "level": MoraleLevel.EAGER},
	{"min": 40, "level": MoraleLevel.FAIR},
	{"min": 20, "level": MoraleLevel.SHAKEN},
	{"min": 0,  "level": MoraleLevel.FEARFUL},
]

## Attack output multiplier per level — matches the MoraleLevel doc comments.
const MORALE_ATTACK_MULT: Dictionary = {
	MoraleLevel.FEARLESS: 1.15,
	MoraleLevel.EAGER:    1.05,
	MoraleLevel.FAIR:     1.00,
	MoraleLevel.SHAKEN:   0.90,
	MoraleLevel.FEARFUL:  0.80,
}

const MORALE_LABEL: Dictionary = {
	MoraleLevel.FEARLESS: "Fearless",
	MoraleLevel.EAGER:    "Eager",
	MoraleLevel.FAIR:     "Fair",
	MoraleLevel.SHAKEN:   "Shaken",
	MoraleLevel.FEARFUL:  "Fearful",
}

const MORALE_COLOR: Dictionary = {
	MoraleLevel.FEARLESS: Color(0.30, 0.95, 0.55),
	MoraleLevel.EAGER:    Color(0.65, 0.90, 0.35),
	MoraleLevel.FAIR:     Color(0.90, 0.85, 0.35),
	MoraleLevel.SHAKEN:   Color(0.95, 0.55, 0.20),
	MoraleLevel.FEARFUL:  Color(0.95, 0.25, 0.25),
}

# Morale deltas. Negative = demoralizing.
const MORALE_ALLY_DEATH: int = -18        # An ally fell within MORALE_SHOCK_RADIUS
const MORALE_ENEMY_DEATH: int = 10        # An enemy fell nearby
const MORALE_KILL_BONUS: int = 15         # This unit landed the killing blow
const MORALE_DAMAGE_TAKEN: int = -8       # Took any hit
const MORALE_HEAVY_DAMAGE_EXTRA: int = -8 # ...and the hit removed >25% of max HP
const MORALE_FLANK_PENALTY: int = -10     # Per upkeep while flanked
const MORALE_AMBUSHED: int = -14          # Struck from concealing terrain
const MORALE_HEALED: int = 6              # Patched up by a Support unit
const MORALE_REGEN: int = 5               # Drift back toward MORALE_DEFAULT each upkeep
const MORALE_CAPTURE_BONUS: int = 12      # Faction-wide, on taking a building
const MORALE_CAPTURE_LOSS: int = -10      # Faction-wide, on losing one
const MORALE_STARVATION: int = -15        # Faction-wide, during logistics collapse

## Manhattan radius within which a death is felt by other units.
const MORALE_SHOCK_RADIUS: int = 3
## Adjacent enemies required before a unit counts as flanked.
const MORALE_FLANK_MIN_ENEMIES: int = 2

# === Surrender & Desertion ===
## Chance a unit surrenders after surviving an attack, keyed by morale level.
## Levels absent from this table never surrender (FAIR and above hold the line).
const SURRENDER_CHANCE: Dictionary = {
	MoraleLevel.FEARFUL: 0.60,
	MoraleLevel.SHAKEN:  0.30,
}
## Captured units join their new army at this fraction of max HP.
const SURRENDER_CAPTURE_HP_RATIO: float = 0.5
## ...and they join it shaken, not eager. A turncoat is not a loyalist.
const MORALE_AFTER_CAPTURE: int = 30
## Ransoming a surrendered unit pays this fraction of its recruit cost.
const SURRENDER_RANSOM_RATIO: float = 0.5
## Chance a FEARFUL unit deserts on its own during upkeep.
const DESERTION_CHANCE_FEARFUL: float = 0.15

# === Vision / Fog of War ===
## Fallback sight radius when UnitData.vision_range is left at 0.
const VISION_DEFAULT: int = 4
const VISION_BY_CLASS: Dictionary = {
	"Worker": 3, "Melee": 3, "Cavalry": 5, "Ranged": 6,
	"Mage": 4, "Support": 4, "Infiltrator": 6, "Undead": 3,
}
const VISION_CASTLE: int = 4
const VISION_BUILDING: int = 2
## A unit on concealing terrain is only spotted from within this range.
const VISION_CONCEALED_REVEAL_RANGE: int = 1

# === Environmental Hazards ===
const BARREL_DAMAGE: int = 45             # TRUE damage, ignores defense
const BARREL_BLAST_RADIUS: int = 1        # Manhattan radius that takes damage
const BARREL_CHAIN_RADIUS: int = 2        # Manhattan radius that chain-detonates
const FIRE_DAMAGE: int = 12               # Per tick, to whoever stands in it
const FIRE_LIFETIME_TICKS: int = 3        # Rounds before it burns out
## Multiplier applied on top of a terrain's `flammable` chance when fire spreads
## from an existing blaze.
const FIRE_SPREAD_MULT: float = 1.0
## Multiplier when the ignition source is an explosion instead. A blast is a far
## stronger source than a creeping flame — forest always catches — but grass
## still only sometimes does, so a keg does not automatically leave a five-tile
## firestorm behind it.
const BLAST_IGNITION_MULT: float = 3.0

# === Pandora's Box Rewards ===
const PANDORA_SPOILS_GOLD: Vector2i = Vector2i(80, 220)
const PANDORA_SPOILS_IRON: Vector2i = Vector2i(2, 8)
const PANDORA_TRAP_DAMAGE: int = 30
const PANDORA_UNDEAD_COUNT: int = 2


# === Derived Helpers ===

## Map a raw morale scalar onto its MoraleLevel.
static func morale_level_for(points: int) -> MoraleLevel:
	for band in MORALE_THRESHOLDS:
		if points >= int(band["min"]):
			return band["level"]
	return MoraleLevel.FEARFUL


## Look up one rule for a terrain type, with a PLAIN fallback so an unmapped
## type can never crash combat or pathfinding.
static func terrain_rule(terrain: TerrainType, key: String) -> Variant:
	var rules: Dictionary = TERRAIN_RULES.get(terrain, TERRAIN_RULES[TerrainType.PLAIN])
	return rules.get(key, TERRAIN_RULES[TerrainType.PLAIN].get(key))
