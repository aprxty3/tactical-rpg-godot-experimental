extends Node
## MatchSetup — the choices that define ONE match, carried across scene loads.
##
## Deliberately separate from `GameConfig`, which they are easy to confuse:
## GameConfig holds the game's fixed rules and never changes while the game runs;
## MatchSetup holds what the player picked on the menu and changes every match.
##
## It has to be an autoload. The faction choice is made on one screen and
## consumed on another, and `change_scene_to_file()` frees everything in between
## — an exported property on the match scene could never survive that trip.
##
## Campaign will extend this rather than replace it: a chapter number, a
## persistent roster and a save slot all belong to "this run", not to the rules.

## The four armies that take the field. Black Coven is deliberately absent — it
## holds a castle on the map as a neutral prize, but fields no troops and takes
## no turn, and is reserved for the campaign's undead track.
const DEFAULT_PARTICIPANTS: Array[int] = [
	GameConfig.Faction.BLUE_KINGDOM,
	GameConfig.Faction.RED_LEGION,
	GameConfig.Faction.PURPLE_SYNDICATE,
	GameConfig.Faction.YELLOW_EMPIRE,
]

## Which of the participants the human is playing.
var player_faction: int = GameConfig.Faction.BLUE_KINGDOM

## Everyone taking a turn this match, in turn order. A var rather than a
## constant so a campaign chapter can field three armies, or five.
var participants: Array[int] = []

## Factions that take a turn but cannot win — the Black Coven's monsters. Kept
## beside `participants` rather than folded into it because the two lists answer
## different questions: who is playing, and who is merely on the board.
var marauders: Array[int] = []

## Seeds the scattered chests, traps and kegs. 0 means "pick one at random on
## match start"; a fixed value reproduces a board exactly, which is what the
## test suites rely on.
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
