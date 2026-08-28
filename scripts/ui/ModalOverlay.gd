extends ColorRect
class_name ModalOverlay
## ModalOverlay — a dimmed, full-screen panel that blocks the board behind it.
##
## Both of this game's blocking dialogs (the surrender prompt and the result
## screen) were built by hand with the same seven-node skeleton: a full-rect
## ColorRect, a centred PanelContainer, a MarginContainer with four identical
## side margins, and a VBoxContainer. This is that skeleton, once.
##
## `MOUSE_FILTER_STOP` is the load-bearing detail, not decoration. A modal that
## lets clicks through is cosmetic: the surrender prompt would leave a prisoner
## frozen while the player kept playing, and the result screen would sit over a
## match that is still running. It is also why these are Controls rather than
## PopupPanels — a PopupPanel is dismissable by clicking outside it, and neither
## of these dialogs has a valid "no answer" outcome.

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
