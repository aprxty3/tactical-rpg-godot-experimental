extends Node
## AudioManager — Autoload for handling global sound effects.
## Listens to EventBus to play SFX without coupling to game logic.

var move_sfx: AudioStreamPlayer
var hit_sfx: AudioStreamPlayer
var victory_sfx: AudioStreamPlayer
var defeat_sfx: AudioStreamPlayer

func _ready() -> void:
	_setup_audio_players()
	_connect_signals()

func _setup_audio_players() -> void:
	move_sfx = AudioStreamPlayer.new()
	move_sfx.stream = preload("res://assets/sfx/move.wav")
	move_sfx.volume_db = -10.0
	add_child(move_sfx)

	hit_sfx = AudioStreamPlayer.new()
	hit_sfx.stream = preload("res://assets/sfx/hit.wav")
	hit_sfx.volume_db = -5.0
	add_child(hit_sfx)

	victory_sfx = AudioStreamPlayer.new()
	victory_sfx.stream = preload("res://assets/sfx/victory.wav")
	add_child(victory_sfx)

	defeat_sfx = AudioStreamPlayer.new()
	defeat_sfx.stream = preload("res://assets/sfx/defeat.wav")
	add_child(defeat_sfx)

func _connect_signals() -> void:
	EventBus.unit_move_completed.connect(_on_unit_move_completed)
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.victory_condition_met.connect(_on_victory)
	EventBus.defeat_condition_met.connect(_on_defeat)

func _on_unit_move_completed(_unit: Node, _from: Vector2i, _to: Vector2i) -> void:
	move_sfx.play()

func _on_combat_resolved(_result: Dictionary) -> void:
	hit_sfx.play()

func _on_victory(_faction_id: int, _condition: String) -> void:
	victory_sfx.play()

func _on_defeat(_faction_id: int, _condition: String) -> void:
	defeat_sfx.play()
