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
## What an army can field before it needs to take ground for more.
##
## Read as "your own keep and the land around it" — a faction's starting castle
## is already priced in here, which is why `CASTLE_CAPACITY_BONUS` below only
## pays out from the SECOND castle onward.
const BASE_TROOP_CAPACITY: int = 8
const VILLAGE_CAPACITY_BONUS: int = 3
## Every castle held beyond the first. Taking an enemy keep should be worth more
## than taking a village, because it costs far more to do and it is the only
## capture that can end someone's match.
##
## Counted from the second castle rather than the first so an army's opening
## capacity is unchanged, and so losing your own keep does not also starve the
## "rogue army" the victory rules deliberately allow to keep fighting.
const CASTLE_CAPACITY_BONUS: int = 5
const GOLD_MINE_INCOME: int = 50
## A castle pays a small stipend on top of being a spawn point, so holding one is
## worth something even before any mine is taken. Deliberately below a gold mine:
## the castle is already the thing you cannot afford to lose.
const CASTLE_GOLD_INCOME: int = 20
## Iron is a scarce gate, not a currency: no unit costs more than 4 iron and a
## faction opens with 6, so a mine yielding 30/turn made iron free forever after
## the first capture. 3/turn keeps one mine worth roughly one heavy unit per turn,
## the same ratio gold runs at, and matches PANDORA_SPOILS_IRON's 2-8 payout.
const IRON_MINE_INCOME: int = 3
const HOUSE_GOLD_INCOME: int = 10
## A unit holding one of its own villages is resupplied there, recovering this
## fraction of its MAXIMUM health each upkeep — so a hero on 20/100 leaves the
## village on 40/100, not 24/100. Villages were worth taking for the troop
## capacity and worth nothing afterwards; this makes them worth standing in, and
## gives a mauled army somewhere to pull back to instead of only forward to die.
const VILLAGE_GARRISON_HEAL_RATIO: float = 0.20
## A castle is a proper garrison, not a farmhouse: standing in one of your own
## keeps recovers this fraction of MAXIMUM health each upkeep. Double a village's
## rate on purpose — a castle is the one building whose loss ends the match, so
## the ground worth defending hardest should also be the ground worth retreating
## to. It also gives the promotion trip to a castle a second reason to exist.
const CASTLE_GARRISON_HEAL_RATIO: float = 0.40
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

# === Faction Display Names ===
## What the player is shown. Derived from the same table the resource suffix
## uses, so a faction cannot be renamed in one place and not the other.
##
## The HUD used to announce the enemy turn as "AI TURN (RED LEGION)". "AI" tells
## the player nothing about who is moving, and on a five-faction map there can be
## more than one of them.
static func faction_display_name(faction_id: int) -> String:
	var suffix: String = str(FACTION_SUFFIX.get(faction_id, ""))
	return suffix.capitalize() if suffix != "" else "Unknown"


## "Red Enemy", "Purple Enemy" — the label for a faction the player is fighting.
static func faction_enemy_name(faction_id: int) -> String:
	return "%s Enemy" % faction_display_name(faction_id)


## The house word each colour rules under. Only the noun lives here — the colour
## still comes from `FACTION_SUFFIX` through `faction_display_name`, so a faction
## renamed there is renamed everywhere, which is the whole point of that table.
const FACTION_HOUSE: Dictionary = {
	Faction.BLUE_KINGDOM: "Kingdom",
	Faction.RED_LEGION: "Legion",
	Faction.PURPLE_SYNDICATE: "Syndicate",
	Faction.YELLOW_EMPIRE: "Empire",
	Faction.BLACK_COVEN: "Coven",
}


## "Blue Kingdom", "Red Legion" — the full title, for menus and briefings where
## there is room for it. The HUD keeps using the short colour name.
static func faction_title(faction_id: int) -> String:
	var house: String = str(FACTION_HOUSE.get(faction_id, ""))
	if house == "":
		return faction_display_name(faction_id)
	return "%s %s" % [faction_display_name(faction_id), house]


## The coloured pip the HUD puts in front of "YOUR TURN".
##
## It used to be a literal 🔵 in the format string, so a player commanding the
## Purple Syndicate was told, every single turn, that they were blue. The colour
## has to come off the faction like every other faction-coloured thing does.
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
## Factions that raid rather than conquer.
##
## A marauder holds no ground: it cannot claim a castle or a mine, and a village
## it reaches is burned rather than flown a new flag. It also sits outside the
## victory check — it is a hazard of the map, like a minefield that walks, not a
## fifth contender the winner has to outlast.
##
## Written as a list rather than `faction_id == BLACK_COVEN` so a second
## encounter faction (bandits, a rival coven) needs no new branches downstream.
const MARAUDER_FACTIONS: Array[int] = [Faction.BLACK_COVEN]


## Does this faction raid instead of conquering?
static func is_marauder(faction_id: int) -> bool:
	return faction_id in MARAUDER_FACTIONS

## What a marauder does to each building type is Building's own business and
## lives there, next to the enum it is keyed on — see `Building.claim_for`.

## The garrison that holds the Black Castle, in spawn order. The last entry is
## the boss and is treated as such — one only, planted on the keep itself, and
## it never steps off it.
const ENCOUNTER_ROSTER: Array[String] = [
	"res://resources/units/ghoul_black.tres",
	"res://resources/units/bonestalker_black.tres",
	"res://resources/units/gravewarden_black.tres",
	"res://resources/units/plaguewraith_black.tres",
	"res://resources/units/bloodfiend_black.tres",
]
const ENCOUNTER_BOSS: String = "res://resources/units/dreadwarden_black.tres"

## How far from the Black Castle a monster will chase, in Manhattan cells.
##
## Eleven covers the centre lanes and the inner ring of villages on a 30x20
## board without reaching any starting castle — a leash short enough that a
## player can choose to stay out of it, long enough that the middle of the map
## costs something to hold.
const ENCOUNTER_LEASH: int = 11

## How many monsters (excluding the boss) stand guard at once.
const ENCOUNTER_MAX_ACTIVE: int = 4
## How many take the field at match start. Below the cap on purpose: the den
## reinforcing itself over the first rounds reads as a place that is producing
## them, rather than a fixed pile of enemies that only ever shrinks.
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

# === Hidden Traps ===
## Buried mines: invisible until stepped on, scattered at match start.
##
## Named HIDDEN_* throughout because `PANDORA_TRAP_DAMAGE` already exists and is
## a different thing entirely — that one is a Pandora chest outcome, punishing a
## unit that chose to open something. These punish a unit for walking.
##
## Damage sits below a keg's 45: a keg is visible and can be played around, a
## buried mine cannot, and an unavoidable hit should not also be the biggest.
const HIDDEN_TRAP_DAMAGE: int = 32          # TRUE damage, ignores defense
## Blast footprint in cells, width x height. An even height cannot be centred on
## the trap's row; the extra row goes above it, so the plume reads as rising out
## of the cell that was stepped on.
const HIDDEN_TRAP_BLAST_SIZE: Vector2i = Vector2i(3, 2)
## Every cell in the footprint that can burn, does. A keg's ignition is a roll
## against terrain flammability; a mine is incendiary by design.
const HIDDEN_TRAP_IGNITE_ALL: bool = true
## How many are buried per match.
##
## Six on a 30x20 board is one mine per hundred cells, and play-testing found
## what that arithmetic predicts: whole matches went by without a single one
## going off, so the hazard existed on paper only. Fourteen is one per forty-odd
## cells — often enough to be a thing you route around, still rare enough that
## a route is worth planning rather than a coin-flip.
const HIDDEN_TRAP_COUNT: int = 14
## Kept this far apart (Manhattan), so one step can never set off two.
##
## Four, not five: the blast is 3x2, so four cells still leaves a gap no single
## detonation can bridge, and packing fourteen mines at five would have the
## scatter quietly return fewer than asked (it draws without replacement and
## gives up rather than looping).
const HIDDEN_TRAP_MIN_SPACING: int = 4

# === Enemy AI Tuning ===
## What each building is worth as an objective. The AI divides these by the real
## path cost of reaching them, so a Gold Mine two roads away outranks a Village
## next door — value per step, not raw proximity. Castles top the list because
## taking one ends the match; Iron Mines sit low because iron is a scarce gate
## rather than a currency (see IRON_MINE_INCOME).
const AI_OBJECTIVE_VALUE: Dictionary = {
	"castle": 100.0,
	"gold_mine": 70.0,
	"village": 55.0,
	"iron_mine": 40.0,
	"tower": 30.0,
}
## A neutral node is cheaper to take than one that has to be prised off an enemy.
const AI_NEUTRAL_BONUS: float = 1.25
## Finishing a wounded unit is worth more than chip damage: a corpse cannot
## counter-attack next turn. Added to an attack's score when it would kill.
const AI_KILL_BONUS: float = 1.5
## How heavily expected counter-attack damage discounts an attack's score. At
## 1.0 the AI treats damage taken as exactly as bad as damage dealt.
const AI_COUNTER_WEIGHT: float = 0.8
## Attacking out of ambush cover suppresses the counter entirely, so it is worth
## seeking out.
const AI_AMBUSH_BONUS: float = 0.6
## Below this fraction of max HP a unit starts looking for a way out.
##
## Lowered from 0.35 after play-testing: at a third of health a unit still has
## a real swing in it, and an army that walks away at the first scratch reads as
## passive rather than as careful. Now only genuinely mauled units break off.
const AI_RETREAT_HP_RATIO: float = 0.25
## ...and so does any unit standing where the incoming threat this turn is at
## least this fraction of the HP it has left, however healthy it looks.
##
## Raised from 0.9. `threat_at` sums every visible enemy that could both reach
## and strike the cell, which is deliberately an over-estimate of one turn's
## reach — so at 0.9 a unit near two enemies was almost always "in danger" and
## spent the match backing away from fights it would have won. Above 1.0 it only
## flinches from ground that could actually kill it outright.
const AI_RETREAT_THREAT_RATIO: float = 1.35
## Retreating units prefer cover; this weights the terrain damage multiplier
## against raw threat when picking where to fall back to.
const AI_RETREAT_COVER_WEIGHT: float = 12.0

## What a living enemy is worth as a DESTINATION, on the same scale as
## AI_OBJECTIVE_VALUE (castle 100 ... tower 30) and divided by the same real path
## cost. Without this the AI only ever walked to buildings: `best_objective`
## always found one on a map carrying 4 gold mines, 2 iron mines, 6 villages and
## 5 castles, so hunting was unreachable code and the army never engaged unless
## the player happened to stand in its path.
##
## Raised from 62 to sit level with a gold mine (70 x 1.25 neutral = 87.5), so a
## living enemy at comparable distance is now a genuine alternative to another
## capture rather than a distant second. Below that the armies spent whole
## matches walking past each other to flags.
const AI_ENEMY_VALUE: float = 88.0
## A target already hurt is worth more than a fresh one — finishing a wounded
## unit removes a whole unit, where chipping a healthy one removes nothing.
## Scales linearly with the fraction of health already gone. At 60 a
## half-dead enemy (118) outranks every building on the board.
const AI_WOUNDED_BONUS: float = 60.0

# === AI Recruitment Composition ===
## How much each unit of the same class already in the army discounts buying
## another one.
##
## The old rule ranked candidates by `(counter advantage, gold cost)` and took
## the maximum, which is deterministic twice over: the same board always picked
## the same unit, and every tie went to the most expensive — the Wizzard, at 120
## gold the priciest thing a castle sells. Since Melee is the commonest class on
## the field and Mage counters Melee, the answer was "another mage", every time.
##
## At 0.35 the third unit of a class carries -0.70, which a 1.5x counter
## advantage (0.80 net) can no longer pay for against a neutral alternative at
## 1.00 — so a counter class caps out around two before the army broadens. The
## decisive 2.5x holy-vs-undead matchup still buys a third and a fourth, which
## is right: that one is worth stacking.
##
## Measured over 20 trials of six draws against a Melee enemy: 0.35 averages
## 2.3 mages and never fewer than 4 distinct classes. The old rule bought six
## mages out of six, every time.
const AI_SAME_CLASS_PENALTY: float = 0.35
## Random spread added to each candidate's score, so two equally sensible buys
## are not always resolved the same way. Small enough that it reorders equals
## and never overrides a real counter advantage.
const AI_RECRUIT_JITTER: float = 0.45
## Gold cost still nudges the choice, at a thousandth of its value — a 120g
## Wizzard carries 0.12. Enough to prefer the better unit among equals, far too
## little to be the tiebreak it used to be.
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


## Look up one rule for a terrain type, with a PLAIN fallback so an unmapped
## type can never crash combat or pathfinding.
static func terrain_rule(terrain: TerrainType, key: String) -> Variant:
	var rules: Dictionary = TERRAIN_RULES.get(terrain, TERRAIN_RULES[TerrainType.PLAIN])
	return rules.get(key, TERRAIN_RULES[TerrainType.PLAIN].get(key))
