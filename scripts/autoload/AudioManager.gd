extends Node
## AudioManager — Autoload for music and sound effects.
##
## Listens to EventBus and nothing listens back, so gameplay never knows audio
## exists. SFX use a small pool — one player per effect cut the previous hit off
## mid-melee. Music is two crossfaded players with ducking, following whose turn
## it is. Volume goes through the buses, not per-player, so one slider moves a
## whole bus.

const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"

## Enough voices for a busy exchange without letting a chain reaction turn into
## a wall of noise.
const SFX_POOL_SIZE: int = 8

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"

## Logical name -> file. Callers say `play_sfx("hit")` and never touch a path,
## so re-pointing a sound at new art is a one-line change here.
const SFX_LIBRARY: Dictionary = {
	"move": "move.wav",
	"hit": "hit.wav",
	"victory": "victory.wav",
	"defeat": "defeat.wav",
}

const MUSIC_LIBRARY: Dictionary = {
	"calm": "calm.wav",
	"tension": "tension.wav",
	"combat": "combat.wav",
}

## Seconds of overlap when swapping tracks.
@export var crossfade_seconds: float = 1.2
## How far the music drops while combat is on screen, in dB.
@export var duck_db: float = -9.0
@export var duck_attack_seconds: float = 0.12
@export var duck_release_seconds: float = 0.9
## Off means the music players are never even started — for a headless test run.
@export var music_enabled: bool = true

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _sfx_streams: Dictionary = {}

## Two players so a crossfade has something to fade *from*. `_music_active` is
## the index of whichever is currently the audible one.
var _music_players: Array[AudioStreamPlayer] = []
var _music_active: int = 0
var _music_track: String = ""
var _music_tween: Tween

var _duck_tween: Tween
var _music_base_db: float = 0.0


func _ready() -> void:
	_build_sfx_pool()
	_build_music_players()
	_music_base_db = AudioServer.get_bus_volume_db(_bus(BUS_MUSIC))
	_connect_signals()

# SETUP


func _build_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = BUS_SFX
		add_child(player)
		_sfx_pool.append(player)

	for id in SFX_LIBRARY:
		var stream: AudioStream = load(SFX_DIR + SFX_LIBRARY[id]) as AudioStream
		if is_instance_valid(stream):
			_sfx_streams[id] = stream


func _build_music_players() -> void:
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = BUS_MUSIC
		# Silent until a crossfade raises it. Starting at 0 dB would make the
		# very first track slam in at full volume before the tween runs.
		player.volume_db = -80.0
		add_child(player)
		_music_players.append(player)


func _connect_signals() -> void:
	EventBus.unit_move_completed.connect(_on_unit_move_completed)
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.victory_condition_met.connect(_on_victory)
	EventBus.defeat_condition_met.connect(_on_defeat)
	EventBus.turn_started.connect(_on_turn_started)

# SFX


## Play a named effect on the next free voice.
##
## Round-robin rather than "find an idle player": with a pool this size the
## oldest voice is the right one to reuse, and scanning for idleness would
## silently drop a sound once every voice happened to be busy.
func play_sfx(id: String) -> void:
	if not _sfx_streams.has(id) or _sfx_pool.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stream = _sfx_streams[id]
	player.play()

# MUSIC


## Fade from whatever is playing to `track_id`.
##
## Re-requesting the track already playing is a no-op, so an event that fires
## several times a turn cannot restart the score mid-bar.
func play_music(track_id: String, fade: float = -1.0) -> void:
	if not music_enabled or _music_track == track_id:
		return
	if not MUSIC_LIBRARY.has(track_id):
		return

	var stream: AudioStream = _music_stream(track_id)
	if not is_instance_valid(stream):
		return

	var seconds: float = crossfade_seconds if fade < 0.0 else fade
	var outgoing: AudioStreamPlayer = _music_players[_music_active]
	_music_active = 1 - _music_active
	var incoming: AudioStreamPlayer = _music_players[_music_active]

	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	_music_track = track_id

	if is_instance_valid(_music_tween):
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", 0.0, seconds)
	if outgoing.playing:
		_music_tween.tween_property(outgoing, "volume_db", -80.0, seconds)
		# Stop only once it is inaudible; stopping on the same frame the fade
		# starts is what makes a "crossfade" cut instead.
		_music_tween.chain().tween_callback(outgoing.stop)


func stop_music(fade: float = 0.6) -> void:
	_music_track = ""
	for player in _music_players:
		if player.playing:
			var tween := create_tween()
			tween.tween_property(player, "volume_db", -80.0, fade)
			tween.tween_callback(player.stop)


func current_music() -> String:
	return _music_track


## Load a music stream, forcing it to loop.
##
## WAV loop points normally come from the file's `.import` settings, which
## generated files do not have. Setting loop_mode on the resource itself is the
## reliable path and survives a re-import; without it the score plays once and
## then leaves the match in silence.
func _music_stream(track_id: String) -> AudioStream:
	var stream: AudioStream = load(MUSIC_DIR + MUSIC_LIBRARY[track_id]) as AudioStream
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream

# DUCKING


## Dip the Music bus so a hit is audible over the score, then let it back up.
##
## Acts on the bus rather than the players so it survives a crossfade — ducking
## a player would be undone the moment the track changed mid-fight.
func duck_music(active: bool) -> void:
	var bus := _bus(BUS_MUSIC)
	if bus < 0:
		return
	if is_instance_valid(_duck_tween):
		_duck_tween.kill()
	var target: float = _music_base_db + duck_db if active else _music_base_db
	var seconds: float = duck_attack_seconds if active else duck_release_seconds
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(bus, db),
		AudioServer.get_bus_volume_db(bus),
		target,
		seconds
	)

# VOLUME API


func _bus(bus_name: String) -> int:
	return AudioServer.get_bus_index(bus_name)


## Set a bus volume from a 0.0-1.0 slider value.
##
## Muting at the bottom instead of converting: linear_to_db(0.0) is -inf, which
## Godot stores but which makes the slider jump on the way back up.
func set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var bus := _bus(bus_name)
	if bus < 0:
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	if clamped <= 0.001:
		AudioServer.set_bus_mute(bus, true)
		return
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, linear_to_db(clamped))
	if bus_name == BUS_MUSIC:
		# Keep the duck's reference point in step with the player's choice, or
		# the next release would restore the *old* volume.
		_music_base_db = AudioServer.get_bus_volume_db(bus)


func get_bus_volume_linear(bus_name: String) -> float:
	var bus := _bus(bus_name)
	if bus < 0:
		return 0.0
	if AudioServer.is_bus_mute(bus):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus))

# EVENT HANDLERS


func _on_unit_move_completed(_unit: Node, _from: Vector2i, _to: Vector2i) -> void:
	play_sfx("move")


func _on_combat_started(_attacker: Node, _defender: Node) -> void:
	duck_music(true)


func _on_combat_resolved(_result: Dictionary) -> void:
	play_sfx("hit")
	duck_music(false)


func _on_victory(_faction_id: int, _condition: String) -> void:
	play_sfx("victory")
	stop_music()


func _on_defeat(_faction_id: int, _condition: String) -> void:
	play_sfx("defeat")
	stop_music()


## The score follows whose turn it is: calm while the player thinks, tense while
## the AI moves. Derived from the turn signal alone, so no manager has to
## remember to tell the audio layer anything.
func _on_turn_started(faction_id: int) -> void:
	play_music("calm" if faction_id == GameConfig.Faction.BLUE_KINGDOM else "tension")
