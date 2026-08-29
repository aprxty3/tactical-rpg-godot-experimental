extends ColorRect
class_name ModalOverlay
## ModalOverlay — a dimmed, full-screen panel that blocks the board behind it.
##
## The seven-node skeleton both blocking dialogs were building by hand.
##
## `MOUSE_FILTER_STOP` is load-bearing: a modal that lets clicks through would
## leave a prisoner frozen while the player kept playing. Controls rather than
## PopupPanels for the same reason — a PopupPanel dismisses on an outside click,
## and neither dialog has a valid "no answer".

## Where callers put their content. Populated through the helpers below.
var box: VBoxContainer


func _init(overlay_name: String = "ModalOverlay", dim: float = 0.55,
		margin: int = 16, separation: int = 10) -> void:
	name = overlay_name
	color = Color(0.0, 0.0, 0.0, dim)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, margin)

	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)

	margins.add_child(box)
	panel.add_child(margins)
	add_child(panel)


## Centred heading. `color` is optional — pass one to make a win read green and
## a loss read red.
func add_title(text: String, font_size: int, font_color: Variant = null) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	if font_color is Color:
		label.add_theme_color_override("font_color", font_color)
	box.add_child(label)
	return label


## Centred body copy. Returned so a caller can keep the reference and rewrite
## the text each time the dialog is shown.
func add_text(text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return label


func add_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	box.add_child(button)
	return button
