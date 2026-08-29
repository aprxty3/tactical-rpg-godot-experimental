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
## Includes your starting keep, which is why CASTLE_CAPACITY_BONUS pays from
## the second castle onward.
const BASE_TROOP_CAPACITY: int = 8
const VILLAGE_CAPACITY_BONUS: int = 3
## Per castle beyond the first. Counted from the second so opening capacity is
## unchanged, and so a castle-less rogue army is not also starved.
const CASTLE_CAPACITY_BONUS: int = 5
const GOLD_MINE_INCOME: int = 50
## Below a gold mine on purpose — the castle is already the thing you cannot
## afford to lose.
const CASTLE_GOLD_INCOME: int = 20
## Iron is a gate, not a currency: nothing costs over 4 and factions open with 6,
## so the old 30/turn ended the constraint on first capture. 3 keeps one mine at
## roughly one heavy unit per turn.
const IRON_MINE_INCOME: int = 3
const HOUSE_GOLD_INCOME: int = 10
## Fraction of MAXIMUM health restored each upkeep to a unit on its own village.
## Gives a mauled army somewhere to fall back to rather than only forward.
const VILLAGE_GARRISON_HEAL_RATIO: float = 0.20
## Double a village. The ground worth defending hardest should also be the
## ground worth retreating to.
const CASTLE_GARRISON_HEAL_RATIO: float = 0.40
const FIELD_TAX_MULTIPLIER: int = 2       # 200% cost for field upgrades
const STARVATION_DAMAGE: int = 15         # True damage per overcap turn

# === Faction Resource Suffix ===
## Unit resources are named `{role}_{faction}.tres`. One table so a captured
## castle and a defecting prisoner resolve "their colour of this unit" alike.
const FACTION_SUFFIX: Dictionary = {
	Faction.BLUE_KINGDOM: "blue",
	Faction.RED_LEGION: "red",
	Faction.PURPLE_SYNDICATE: "purple",
	Faction.YELLOW_EMPIRE: "yellow",
	Faction.BLACK_COVEN: "black",
}

# === Faction Display Names ===
## Derived from FACTION_SUFFIX so a faction cannot be renamed in one place only.
## The HUD used to say "AI TURN", which names nobody when several AIs play.
static func faction_display_name(faction_id: int) -> String:
	var suffix: String = str(FACTION_SUFFIX.get(faction_id, ""))
	return suffix.capitalize() if suffix != "" else "Unknown"


## "Red Enemy", "Purple Enemy" — the label for a faction the player is fighting.
static func faction_enemy_name(faction_id: int) -> String:
	return "%s Enemy" % faction_display_name(faction_id)


## Only the noun. The colour still comes from FACTION_SUFFIX, so one rename
## there covers both.
const FACTION_HOUSE: Dictionary = {
	Faction.BLUE_KINGDOM: "Kingdom",
	Faction.RED_LEGION: "Legion",
	Faction.PURPLE_SYNDICATE: "Syndicate",
	Faction.YELLOW_EMPIRE: "Empire",
	Faction.BLACK_COVEN: "Coven",
}


## "Blue Kingdom" — the full title, for menus. The HUD uses the short name.
static func faction_title(faction_id: int) -> String:
	var house: String = str(FACTION_HOUSE.get(faction_id, ""))
	if house == "":
		return faction_display_name(faction_id)
	return "%s %s" % [faction_display_name(faction_id), house]


## The pip the HUD puts before "YOUR TURN". Was hardcoded blue, which told a
## Purple player they were blue every turn.
const FACTION_MARKER: Dictionary = {
	Faction.BLUE_KINGDOM: "🔵",
	Faction.RED_LEGION: "🔴",
	Faction.PURPLE_SYNDICATE: "🟣",
	Faction.YELLOW_EMPIRE: "🟡",
	Faction.BLACK_COVEN: "⚫",
}


## The faction's pip, or a neutral one for anything unlisted.
static func faction_marker(faction_id: int) -> String:
	return str(FACTION_MARKER.get(faction_id, "⚪"))


# === Faction Palette-Tint Colors (for generic, non-recolored spritesheets) ===
const FACTION_TINT_COLORS: Dictionary = {
	Faction.BLUE_KINGDOM: Color(0.25, 0.55, 1.0),
	Faction.RED_LEGION: Color(0.95, 0.25, 0.2),
	Faction.PURPLE_SYNDICATE: Color(0.6, 0.25, 0.85),
	Faction.YELLOW_EMPIRE: Color(0.95, 0.8, 0.15),
	Faction.BLACK_COVEN: Color(0.35, 0.32, 0.4),
}

# === Wandering Encounters (Black Coven) ===
## Factions that raid rather than conquer: they claim nothing, burn villages,
## and sit outside the victory check — a hazard, not a contender.
##
## A list rather than `== BLACK_COVEN` so a second one needs no new branches.
const MARAUDER_FACTIONS: Array[int] = [Faction.BLACK_COVEN]


## Does this faction raid instead of conquering?
static func is_marauder(faction_id: int) -> bool:
	return faction_id in MARAUDER_FACTIONS

## What a marauder does to each building type lives in `Building.claim_for`,
## next to the enum it is keyed on.

## The Black Castle garrison, in spawn order.
const ENCOUNTER_ROSTER: Array[String] = [
	"res://resources/units/ghoul_black.tres",
	"res://resources/units/bonestalker_black.tres",
	"res://resources/units/gravewarden_black.tres",
	"res://resources/units/plaguewraith_black.tres",
	"res://resources/units/bloodfiend_black.tres",
]
const ENCOUNTER_BOSS: String = "res://resources/units/dreadwarden_black.tres"

## Manhattan chase radius from the den. Covers the centre lanes and inner
## villages without reaching any starting castle, so the leash is avoidable.
const ENCOUNTER_LEASH: int = 11

## How many monsters (excluding the boss) stand guard at once.
const ENCOUNTER_MAX_ACTIVE: int = 4
## Below the cap on purpose, so the den reads as producing monsters rather than
## holding a fixed pile that only shrinks.
const ENCOUNTER_INITIAL: int = 2
## Rounds between reinforcements while under the cap.
const ENCOUNTER_SPAWN_INTERVAL: int = 3

# === Map Event Probabilities (Pandora's Box) ===
const PANDORA_WAR_SPOILS_CHANCE: float = 0.50
const PANDORA_MERCENARY_CHANCE: float = 0.20
const PANDORA_TRAP_CHANCE: float = 0.15
const PANDORA_AWAKEN_DEAD_CHANCE: float = 0.15

# ==============================================================================
# MILESTONE 4 — Terrain, Morale, Vision, Hazards
# ==============================================================================

# === Terrain Types ===
## MapBuilder derives it while painting; GridManager stores it and is the single
## authority for cover, concealment and fire spread.
enum TerrainType {
	PLAIN,      # Open grass — no cover, no cost
	ROAD,       # Fast but exposed
	FOREST,     # Cover + concealment + ambush source
	ROCK,       # Heavy cover + concealment, no ambush
	WATER,      # Impassable
	BRIDGE,     # Fast, and the most exposed tile on the map
	SCORCHED,   # Forest that burned down — cover is gone for good
}

## `damage_taken_mult` scales damage dealt TO the occupant: below 1.0 is cover,
## above 1.0 is exposure. `conceals` hides them beyond
## VISION_CONCEALED_REVEAL_RANGE. `flammable` is the per-tick spread chance.
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
## A 0..100 scalar owned by TacticalUnit; MoraleLevel is derived from it, so
## tuning happens on the scalar and gameplay reads the level.
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
## Explosions are a stronger ignition source than a creeping flame: forest
## always catches, grass still only sometimes, so a keg leaves no guaranteed
## firestorm.
const BLAST_IGNITION_MULT: float = 3.0

# === Hidden Traps ===
## Buried mines: invisible until stepped on. Named HIDDEN_* to keep them
## distinct from PANDORA_TRAP_DAMAGE, which punishes opening a chest rather than
## walking. Below a keg's 45 — an unavoidable hit should not be the biggest.
const HIDDEN_TRAP_DAMAGE: int = 32          # TRUE damage, ignores defense
## Footprint in cells. An even height cannot centre on the trap's row, so the
## extra row goes above and the plume reads as rising from the stepped cell.
const HIDDEN_TRAP_BLAST_SIZE: Vector2i = Vector2i(3, 2)
## Every burnable cell in the footprint ignites — a mine is incendiary by
## design, where a keg only rolls against terrain flammability.
const HIDDEN_TRAP_IGNITE_ALL: bool = true
## Six on a 30x20 board was one per hundred cells, and whole matches passed
## without one going off. Fourteen is one per forty — worth routing around.
const HIDDEN_TRAP_COUNT: int = 14
## Manhattan spacing, so one step never sets off two. Four rather than five:
## the 3x2 blast still cannot bridge it, and at five the scatter would quietly
## place fewer than fourteen (it draws without replacement and gives up).
const HIDDEN_TRAP_MIN_SPACING: int = 4

# === Enemy AI Tuning ===
## Divided by real path cost, so this is value per step rather than proximity.
## Castles top the list because taking one can end a match; iron sits low
## because it is a gate, not a currency.
const AI_OBJECTIVE_VALUE: Dictionary = {
	"castle": 100.0,
	"gold_mine": 70.0,
	"village": 55.0,
	"iron_mine": 40.0,
	"tower": 30.0,
}
## A neutral node is cheaper to take than one that has to be prised off an enemy.
const AI_NEUTRAL_BONUS: float = 1.25
## Added when the attack would kill: a corpse cannot counter next turn.
const AI_KILL_BONUS: float = 1.5
## How heavily the expected counter discounts an attack. At 1.0 damage taken is
## exactly as bad as damage dealt.
const AI_COUNTER_WEIGHT: float = 0.8
## Attacking out of ambush cover suppresses the counter entirely, so it is worth
## seeking out.
const AI_AMBUSH_BONUS: float = 0.6
## Below this fraction of max HP a unit looks for a way out. Lowered from 0.35:
## at a third of health there is still a real swing left, and breaking off that
## early read as passive.
const AI_RETREAT_HP_RATIO: float = 0.25
## ...and so does any unit whose incoming threat is this fraction of remaining
## HP. Raised from 0.9: `threat_at` deliberately over-estimates one turn's reach,
## so at 0.9 units fled fights they would have won. Above 1.0 they only flinch
## from ground that could actually kill them.
const AI_RETREAT_THREAT_RATIO: float = 1.35
## Retreating units prefer cover; this weights the terrain damage multiplier
## against raw threat when picking where to fall back to.
const AI_RETREAT_COVER_WEIGHT: float = 12.0

## A living enemy as a DESTINATION, on the same value-per-step scale as
## AI_OBJECTIVE_VALUE. Raised from 62 to sit level with a neutral gold mine
## (70 x 1.25 = 87.5) — below that, armies walked past each other to flags.
const AI_ENEMY_VALUE: float = 88.0
## Scales with the fraction of health already gone: finishing a unit removes a
## unit, chipping a healthy one removes nothing. At 60 a half-dead enemy (118)
## outranks every building.
const AI_WOUNDED_BONUS: float = 60.0

# === AI Recruitment Composition ===
## Discount per unit of the same class already owned.
##
## The old rule ranked by `(advantage, cost)` and took the maximum — deterministic
## twice over, since every tie went to the priciest unit (the 120g Wizzard) and
## Mage counters the commonest class. The answer was always "another mage".
##
## At 0.35 a counter class caps out near two before the army broadens, while the
## decisive 2.5x holy-vs-undead matchup still buys a third. Measured over 20
## trials of six draws: 2.3 mages, never fewer than 4 distinct classes.
const AI_SAME_CLASS_PENALTY: float = 0.35
## Breaks ties between equally sensible buys. Small enough never to override a
## real counter advantage.
const AI_RECRUIT_JITTER: float = 0.45
## Cost still nudges the choice at a thousandth of its value (120g = 0.12) —
## enough to prefer the better unit among equals, not enough to be the tiebreak.
const AI_RECRUIT_COST_WEIGHT: float = 0.001

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


## PLAIN fallback so an unmapped type cannot crash combat or pathfinding.
static func terrain_rule(terrain: TerrainType, key: String) -> Variant:
	var rules: Dictionary = TERRAIN_RULES.get(terrain, TERRAIN_RULES[TerrainType.PLAIN])
	return rules.get(key, TERRAIN_RULES[TerrainType.PLAIN].get(key))
