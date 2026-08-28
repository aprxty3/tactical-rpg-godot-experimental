extends PopupPanel
class_name UnitChoicePopup
## UnitChoicePopup — pick one unit from a costed list.
##
## Recruiting at a Castle and promoting a veteran are the same interaction:
## show some UnitData, price each one, act on the chosen one. They had been
## written twice in `MainHUD` — two popups, two identical margin blocks, two
## copies of the `"%s (💰%d | ⛏️%d)"` button format, two identical
## `popup_centered(Vector2(250, 200))` calls — differing only in their title and
## in what they emitted.
##
## So this takes the differences as arguments. `payload` is whatever the caller
## needs handed back: the Castle doing the recruiting, or the unit being
## promoted. This class never inspects it.

## `payload` is echoed back untouched; `choice` is the UnitData that was picked.
signal option_chosen(payload: Variant, choice: Resource)

const POPUP_SIZE: Vector2i = Vector2i(250, 200)
const MARGIN: int = 10

var _list: VBoxContainer


func _init(popup_name: String = "UnitChoicePopup") -> void:
	name = popup_name
	_list = VBoxContainer.new()
	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, MARGIN)
	margins.add_child(_list)
	add_child(margins)


## Rebuild the list and show it. `options` holds UnitData; anything invalid in
## it is skipped rather than crashing the popup, because the callers read from
## authored resource dictionaries that can carry a broken path.
func present(title_text: String, options: Array, payload: Variant) -> void:
	for child in _list.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(title)

	for option in options:
		if not is_instance_valid(option):
			continue
		var button := Button.new()
		button.text = "%s (💰%d | ⛏️%d)" % [
			option.unit_name, option.recruit_cost_gold, option.recruit_cost_iron
		]
		button.pressed.connect(_on_option_pressed.bind(payload, option))
		_list.add_child(button)

	popup_centered(POPUP_SIZE)


func _on_option_pressed(payload: Variant, choice: Variant) -> void:
	hide()
	# A Castle can be captured or destroyed while its recruit list is open, and a
	# promoting unit can die to a hazard. Emitting either as a freed reference is
	# what the original guard was there to prevent.
	if payload is Object and not is_instance_valid(payload):
		return
	if not is_instance_valid(choice):
		return
	option_chosen.emit(payload, choice)
