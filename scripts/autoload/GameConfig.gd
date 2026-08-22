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
