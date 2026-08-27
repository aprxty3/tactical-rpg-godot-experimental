extends Control
class_name MainMenu
## The first thing the game shows. Boots into this instead of straight onto a
## battlefield, which is what the match scene used to do — it was a test scene
## promoted to a product, so there was nowhere for a player to choose anything.
##
## Deliberately small. Settings and Continue belong here eventually, but each of
## them needs a system that does not exist yet (a settings store, a save layer),
## and a button that opens nothing is worse than no button.

const FACTION_SELECT_SCENE: String = "res://scenes/ui/FactionSelect.tscn"

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton
@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	# Returning to the menu abandons whatever match was in progress, so the next
	# one must not inherit its faction choice or its board seed.
	MatchSetup.reset()

	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	start_button.grab_focus()

	# The key exists in project.godot even when blank, so `get_setting`'s default
	# never fires and the label rendered as a bare "v".
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	version_label.text = "v%s" % version if version != "" else ""

	if AudioManager.has_method("play_music"):
		AudioManager.play_music("calm")


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(FACTION_SELECT_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
