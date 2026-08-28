extends ModalOverlay
class_name GameOverModal
## GameOverModal — the result screen, with the Retry that ends the match cleanly.
##
## Built once and re-shown, so a second victory signal cannot stack a second
## copy on top of the first.

signal retry_pressed
signal quit_pressed


func _init(_overlay_name: String = "GameOverModal", _dim: float = 0.65,
		_margin: int = 20, _separation: int = 12) -> void:
	super("GameOverModal", 0.65, 20, 12)


## Fill in the outcome and show. Safe to call more than once: the panel is
## rebuilt from scratch each time so a Retry-then-lose sequence cannot leave the
## previous result's wording behind.
func present(player_won: bool) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

	add_title(
		"🏆 VICTORY" if player_won else "💀 DEFEAT",
		26,
		Color(0.3, 0.9, 0.3) if player_won else Color(0.9, 0.3, 0.3),
	)
	add_text("The enemy castles have fallen." if player_won
		else "Your forces have been broken.")
	add_button("🔄  Retry", func(): retry_pressed.emit())
	add_button("🚪  Quit", func(): quit_pressed.emit())
	show()
