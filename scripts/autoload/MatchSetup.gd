extends Node
## MatchSetup — the choices that define ONE match, carried across scene loads.
##
## Easy to confuse with `GameConfig`: that holds fixed rules and never changes
## at runtime; this holds what the player picked and changes every match.
##
## Must be an autoload — the faction is chosen on one screen and consumed on
## another, and `change_scene_to_file()` frees everything in between.
##
## Campaign will extend it: a chapter, a roster and a save slot all belong to
## "this run", not to the rules.

## The four armies that contend. Black Coven is absent not because it is idle —
## it garrisons the Black Castle and takes a turn — but because it cannot win or
## lose, and this list is "who is contending". See `marauders`.
const DEFAULT_PARTICIPANTS: Array[int] = [
	GameConfig.Faction.BLUE_KINGDOM,
	GameConfig.Faction.RED_LEGION,
	GameConfig.Faction.PURPLE_SYNDICATE,
	GameConfig.Faction.YELLOW_EMPIRE,
]

## Which of the participants the human is playing.
var player_faction: int = GameConfig.Faction.BLUE_KINGDOM

## Turn order. A var so a campaign chapter can field three armies, or five.
var participants: Array[int] = []

## Take a turn but cannot win. Kept beside `participants` because the two answer
## different questions: who is playing, and who is merely on the board.
var marauders: Array[int] = []

## Seeds the scatter. 0 draws at random; a fixed value reproduces a board
## exactly, which the test suites rely on.
var map_seed: int = 0


func _ready() -> void:
	reset()


## Restore the defaults. Called on boot and whenever the player returns to the
## menu, so a second match never inherits the first one's choices.
func reset() -> void:
	participants.assign(DEFAULT_PARTICIPANTS)
	marauders.assign(GameConfig.MARAUDER_FACTIONS)
	player_faction = GameConfig.Faction.BLUE_KINGDOM
	map_seed = 0


## Pick the human's army. Falls back to the first participant rather than
## accepting a faction that is not on the field — a player faction that takes no
## turn would hand the human a match they can never act in.
func set_player_faction(faction_id: int) -> void:
	if faction_id in participants:
		player_faction = faction_id
	elif not participants.is_empty():
		push_warning("MatchSetup: faction %d is not a participant; falling back." % faction_id)
		player_faction = participants[0]


## Every participant the computer drives.
func ai_factions() -> Array[int]:
	var result: Array[int] = []
	for faction_id in participants:
		if faction_id != player_faction:
			result.append(faction_id)
	return result


## Is this faction driven by the computer? The match scene asks before accepting
## input, which is what keeps the player from moving during someone else's turn.
## Written as "a participant that is not the player" rather than a list of enemy
## IDs, so adding a fifth army needs no change here.
func is_ai(faction_id: int) -> bool:
	return faction_id in participants and faction_id != player_faction


func is_player(faction_id: int) -> bool:
	return faction_id == player_faction


## The seed to actually build the board with, resolving 0 to a random draw.
func resolve_map_seed() -> int:
	if map_seed != 0:
		return map_seed
	map_seed = randi()
	return map_seed
