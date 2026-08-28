extends ModalOverlay
class_name SurrenderModal
## SurrenderModal — asks the player what to do with a unit that has broken.
##
## Two exits, both of which resolve the capture. There is deliberately no cancel
## and no click-outside dismissal: a prisoner stays frozen until this is
## answered, so a dismissable prompt would strand the unit permanently.

signal choice_made(unit: Node, choice: String)

var _body: Label
var _unit: TacticalUnit = null


func _init(_overlay_name: String = "SurrenderModal", _dim: float = 0.55,
		_margin: int = 16, _separation: int = 10) -> void:
	super("SurrenderModal", 0.55, 16, 10)
	add_title("🏳️ ENEMY SURRENDERS", 18)
	_body = add_text()
	add_button("⚔️  Capture (joins your army)", _on_choice.bind("capture"))
	add_button("💰  Ransom (take the gold)", _on_choice.bind("ransom"))
	hide()


## `capacity_line` is passed in already formatted rather than looked up here —
## reading the captor's troop capacity means reaching for EconomyManager and
## TurnManager, and a dialog that queries managers is a dialog that cannot be
## shown in a test without building half the game.
func present(unit: TacticalUnit, ransom_gold: int, capacity_line: String) -> void:
	_unit = unit
	var data: UnitData = unit.unit_data
	var unit_name: String = data.unit_name if is_instance_valid(data) else str(unit.name)
	_body.text = "%s has broken and lays down arms.\nRansom pays %d Gold.%s" % [
		unit_name, ransom_gold, capacity_line
	]
	show()


func _on_choice(choice: String) -> void:
	hide()
	if is_instance_valid(_unit):
		choice_made.emit(_unit, choice)
	_unit = null
