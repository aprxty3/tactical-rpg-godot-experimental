extends Control
class_name FactionSelect
## Choose which army the player commands, then start the match.
##
## The buttons are built from `MatchSetup.participants` rather than authored one
## per faction in the scene: the participant list is what a campaign chapter will
## vary, and a hand-authored row of four buttons would silently disagree with it.

const MATCH_SCENE: String = "res://scenes/Match.tscn"
const MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"

@onready var faction_row: HBoxContainer = %FactionRow
@onready var back_button: Button = %BackButton
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build_faction_buttons()


func _build_faction_buttons() -> void:
	for child in faction_row.get_children():
		child.queue_free()

	var first: Button = null
	for faction_id in MatchSetup.participants:
		var button := _make_faction_button(faction_id)
		faction_row.add_child(button)
		if first == null:
			first = button

	if first:
		first.grab_focus()

	hint_label.text = "%d armies take the field. The rest are commanded by the enemy." % (
		MatchSetup.participants.size())


## One card per faction: its colour, its title, and what it costs you to pick it.
func _make_faction_button(faction_id: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(180, 132)
	button.text = "%s\n\n%d opponents" % [
		GameConfig.faction_title(faction_id),
		MatchSetup.participants.size() - 1,
	]
	button.add_theme_font_size_override("font_size", 16)

	# Tint the card in the faction's own colour so the choice reads at a glance
	# rather than as four identical grey buttons with different words on them.
	var tint: Color = GameConfig.FACTION_TINT_COLORS.get(faction_id, Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = tint.darkened(0.55 if state == "normal" else 0.35)
		style.border_color = tint
		style.set_border_width_all(2 if state == "normal" else 4)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(12)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))

	button.pressed.connect(_on_faction_chosen.bind(faction_id))
	return button


func _on_faction_chosen(faction_id: int) -> void:
	MatchSetup.set_player_faction(faction_id)
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_on_back_pressed()
		get_viewport().set_input_as_handled()
