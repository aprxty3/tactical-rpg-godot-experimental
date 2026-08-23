extends Node
## GeminiClient — Autoload Singleton for Google Gemini 3.7 Flash Integration.
## Connects Godot 4.7 to the Gemini REST API for dynamic in-game dialogue,
## unit banter, and emergent campaign storytelling.

@export var model_name: String = "gemini-3.7-flash"
@export var request_timeout_seconds: float = 2.0
@export var enable_dynamic_dialogue: bool = true

var _api_key: String = ""
var _http_request: HTTPRequest

func _ready() -> void:
	_setup_http_client()
	_load_api_key()
	_connect_event_bus()

## Initialize the HTTPRequest child node
func _setup_http_client() -> void:
	_http_request = HTTPRequest.new()
	_http_request.name = "GeminiHTTPRequest"
	_http_request.timeout = request_timeout_seconds
	add_child(_http_request)

## Load API key securely from OS environment or local secret config
func _load_api_key() -> void:
	# 1. Check OS Environment variable (Preferred for CI & Dev)
	var env_key: String = OS.get_environment("GEMINI_API_KEY")
	if env_key != "":
		_api_key = env_key
		print("[GeminiClient] API key loaded successfully from environment.")
		return
	
	# 2. Check local secret config file (res://config/gemini_secret.cfg)
	var config_path: String = "res://config/gemini_secret.cfg"
	if FileAccess.file_exists(config_path):
		var cfg := ConfigFile.new()
		if cfg.load(config_path) == OK:
			_api_key = cfg.get_value("gemini", "api_key", "")
			if _api_key != "":
				print("[GeminiClient] API key loaded successfully from secret config.")
				return
	
	print("[GeminiClient] Warning: No GEMINI_API_KEY detected. Dynamic dialogue will use offline fallbacks.")

## Listen to gameplay events to generate contextual banter
func _connect_event_bus() -> void:
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.building_captured.connect(_on_building_captured)

## Set API Key programmatically at runtime
func set_api_key(key: String) -> void:
	_api_key = key
	print("[GeminiClient] API key manually updated.")

## Check if Gemini client is active and ready
func is_ready_for_requests() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return _api_key != "" and enable_dynamic_dialogue

## Core Async Request: Send prompt to Gemini 3.7 Flash API
func generate_content(prompt: String, system_instruction: String = "") -> String:
	if not is_ready_for_requests():
		return ""
	
	var endpoint: String = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" % [model_name, _api_key]
	var headers: PackedStringArray = ["Content-Type: application/json"]
	
	var payload: Dictionary = {
		"contents": [
			{
				"parts": [
					{"text": prompt}
				]
			}
		],
		"generationConfig": {
			"temperature": 0.7,
			"maxOutputTokens": 150
		}
	}
	
	if system_instruction != "":
		payload["systemInstruction"] = {
			"parts": [
				{"text": system_instruction}
			]
		}
	
	var json_body: String = JSON.stringify(payload)
	
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = request_timeout_seconds
	add_child(http)
	
	var err: Error = http.request(endpoint, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		http.queue_free()
		EventBus.ai_generation_failed.emit("HTTP request initiation failed with error code: %d" % err)
		return ""
	
	var result_array: Array = await http.request_completed
	http.queue_free()
	var response_code: int = result_array[1]
	var response_body: PackedByteArray = result_array[3]
	
	if response_code != 200:
		var error_msg: String = "Gemini API request failed (HTTP %d): %s" % [response_code, response_body.get_string_from_utf8()]
		print("[GeminiClient] ", error_msg)
		EventBus.ai_generation_failed.emit(error_msg)
		return ""
	
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(response_body.get_string_from_utf8())
	if parse_err != OK:
		EventBus.ai_generation_failed.emit("Failed to parse Gemini API JSON response.")
		return ""
	
	var response_dict: Dictionary = json.data
	if response_dict.has("candidates") and response_dict["candidates"].size() > 0:
		var candidate: Dictionary = response_dict["candidates"][0]
		if candidate.has("content") and candidate["content"].has("parts"):
			var generated_text: String = candidate["content"]["parts"][0].get("text", "").strip_edges()
			return generated_text
	
	return ""

## Helper: Generate short in-battle tactical banter
func request_combat_banter(attacker_name: String, defender_name: String, damage: int, is_fatal: bool) -> void:
	if not is_ready_for_requests():
		_emit_fallback_combat_dialogue(attacker_name, defender_name, is_fatal)
		return
	
	var system_prompt: String = "You are a dynamic dialogue generator for a medieval tactical strategy game (War Perang Tactics). Keep banter punchy, dramatic, and under 15 words. Return ONLY the spoken line."
	var prompt: String = "Attacker '%s' dealt %d damage to '%s'. Fatal: %s. Generate a 1-sentence battle cry or reaction from %s." % [
		attacker_name, damage, defender_name, str(is_fatal), attacker_name if is_fatal else defender_name
	]
	
	var line: String = await generate_content(prompt, system_prompt)
	if line != "":
		var speaker: String = attacker_name if is_fatal else defender_name
		EventBus.dialogue_generated.emit(speaker, line, "triumphant" if is_fatal else "wounded")
	else:
		_emit_fallback_combat_dialogue(attacker_name, defender_name, is_fatal)

## Helper: Generate building capture declaration
func request_capture_story(building_name: String, faction_name: String, unit_name: String) -> void:
	if not is_ready_for_requests():
		EventBus.dialogue_generated.emit(unit_name, "By the glory of the %s, this %s is ours!" % [faction_name, building_name], "triumphant")
		return
	
	var system_prompt: String = "You are an announcer for a medieval tactical game. Generate a heroic or sinister 1-sentence announcement for capturing a landmark. Under 15 words."
	var prompt: String = "Faction '%s' led by unit '%s' has captured '%s'." % [faction_name, unit_name, building_name]
	
	var line: String = await generate_content(prompt, system_prompt)
	if line != "":
		EventBus.story_event_narrated.emit("Territory Claimed", line)
	else:
		EventBus.dialogue_generated.emit(unit_name, "%s claims the %s!" % [faction_name, building_name], "triumphant")

# === Event Listeners ===

func _on_combat_resolved(result: Dictionary) -> void:
	if not enable_dynamic_dialogue:
		return
	var attacker_name: String = result.get("attacker_name", "Warrior")
	var defender_name: String = result.get("defender_name", "Enemy")
	var damage: int = result.get("damage_dealt", 10)
	var is_fatal: bool = result.get("defender_killed", false)
	
	# Trigger async dialogue generation without blocking combat flow
	request_combat_banter(attacker_name, defender_name, damage, is_fatal)

func _on_building_captured(building: Node, faction_id: int) -> void:
	if not enable_dynamic_dialogue:
		return
	var f_name: String = "Blue Kingdom" if faction_id == 0 else "Red Legion"
	var b_name: String = building.name if is_instance_valid(building) else "Building"
	request_capture_story(b_name, f_name, "Vanguard")

func _emit_fallback_combat_dialogue(attacker: String, defender: String, is_fatal: bool) -> void:
	if is_fatal:
		EventBus.dialogue_generated.emit(attacker, "Yield to our blade!", "triumphant")
	else:
		EventBus.dialogue_generated.emit(defender, "Is that all you've got?", "defiant")
