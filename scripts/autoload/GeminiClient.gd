extends Node
## GeminiClient — Autoload Singleton for Google Gemini Flash Lite Integration.
## Connects Godot 4.7 to the Gemini REST API for dynamic in-game dialogue,
## unit banter, and emergent campaign storytelling.

## Flash Lite, not full Flash: banter is one throwaway sentence, and the heavier
## model spent ~480 thinking tokens and 2.5-5.6s producing it — by which point the
## fight it was reacting to is already over. Lite answers the same prompt in ~0.9s.
@export var model_name: String = "gemini-3.5-flash-lite"
## Gemini answers a short banter line in 1.3-2.1s measured against this very
## endpoint, so the old 2.0s ceiling sat *inside* the response window and killed
## most calls mid-flight. A timed-out HTTPRequest reports response_code 0 with an
## empty body, which is why the failure read as an unexplained "HTTP 0" rather
## than as a timeout. Dialogue is cosmetic and every path already has an offline
## fallback, so a generous ceiling costs nothing while a tight one silently
## disables the whole feature.
@export var request_timeout_seconds: float = 10.0
## Gemini 3.x models think before answering, and maxOutputTokens covers the
## thinking budget AND the reply together. At the old 150 the model spent ~142
## tokens reasoning and had 4 left for the line itself, so replies came back
## truncated mid-sentence ("You cannot hide in") or with no text part at all,
## always with finishReason MAX_TOKENS. Note thinkingConfig.thinkingBudget = 0
## does NOT help — this model ignores it and thinks anyway. Headroom is the only
## lever, and unused budget is not billed.
@export var max_output_tokens: int = 512
@export var enable_dynamic_dialogue: bool = true

var _api_key: String = ""

func _ready() -> void:
	_load_api_key()
	_connect_event_bus()

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

## Core Async Request: Send prompt to the Gemini generateContent API
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
			"maxOutputTokens": max_output_tokens
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
	var transport_result: int = result_array[0]
	var response_code: int = result_array[1]
	var response_body: PackedByteArray = result_array[3]
	
	# A request that never reached the server has no HTTP status at all, so
	# reporting it as "HTTP 0" hides which failure it was — a timeout, a dead
	# link and a TLS fault all looked identical. Name the transport fault first
	# and only fall through to status codes once the response actually arrived.
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		var transport_msg: String = "Gemini request never completed (%s)" % _transport_result_name(transport_result)
		print("[GeminiClient] ", transport_msg)
		EventBus.ai_generation_failed.emit(transport_msg)
		return ""
	
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

## Translate HTTPRequest's Result enum into something a log line can explain.
## RESULT_TIMEOUT is the one that actually bit us; the rest are here so the next
## transport failure names itself instead of arriving as a bare zero.
func _transport_result_name(result: int) -> String:
	match result:
		HTTPRequest.RESULT_TIMEOUT:
			return "timeout after %.1fs — raise request_timeout_seconds" % request_timeout_seconds
		HTTPRequest.RESULT_CANT_CONNECT:
			return "cannot connect"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "DNS resolution failed — check network"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake failed"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "no response from server"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "request failed"
	return "HTTPRequest.Result %d" % result


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
	var b_name: String = String(building.name) if is_instance_valid(building) else "Building"
	request_capture_story(b_name, f_name, "Vanguard")

func _emit_fallback_combat_dialogue(attacker: String, defender: String, is_fatal: bool) -> void:
	if is_fatal:
		EventBus.dialogue_generated.emit(attacker, "Yield to our blade!", "triumphant")
	else:
		EventBus.dialogue_generated.emit(defender, "Is that all you've got?", "defiant")
