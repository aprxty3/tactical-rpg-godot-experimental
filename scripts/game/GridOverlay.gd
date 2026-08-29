extends Node2D
class_name GridOverlay
## GridOverlay — the tactical highlight layer: grid mesh, move range, attack
## range, the selected unit and building, and the hover cursor.
##
## **Draw order is load-bearing.** Map layers sit at negative `z_index` so this
## draws above them, while Buildings and Units at z 0 draw after it in tree
## order. A node's `_draw` runs before its children, so this must be the FIRST
## child of the match root — `MatchController` calls `move_child(overlay, 0)`.
## Anywhere later buries the highlights under the units standing on them.

const GRID_LINE: Color = Color(1, 1, 1, 0.18)

const MOVE_FILL: Color = Color(0.12, 0.58, 1.0, 0.42)
const MOVE_EDGE: Color = Color(0.35, 0.9, 1.0, 0.95)
const MOVE_DOT: Color = Color(0.6, 0.95, 1.0, 0.9)

const ATTACK_FILL: Color = Color(1.0, 0.15, 0.15, 0.48)
const ATTACK_EDGE: Color = Color(1.0, 0.35, 0.35, 1.0)
const ATTACK_CROSS: Color = Color(1.0, 0.9, 0.9, 0.95)
const ATTACK_DOT: Color = Color(1.0, 0.2, 0.2, 0.9)

const UNIT_FILL: Color = Color(1.0, 0.85, 0.15, 0.25)
const UNIT_EDGE: Color = Color(1.0, 0.92, 0.2, 1.0)

const BUILDING_FILL: Color = Color(0.2, 0.95, 0.45, 0.25)
const BUILDING_EDGE: Color = Color(0.3, 1.0, 0.5, 1.0)

const CURSOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const CURSOR_PAD: float = 4.0
const CURSOR_ARM: float = 10.0

const NO_CELL: Vector2i = Vector2i(-1, -1)

var grid_manager: GridManager

var reachable_cells: Array[Vector2i] = []
var attackable_cells: Array[Vector2i] = []
var hovered_cell: Vector2i = NO_CELL
var selected_unit_cell: Vector2i = NO_CELL
var selected_building_cell: Vector2i = NO_CELL


func setup(grid: GridManager) -> void:
	grid_manager = grid
	queue_redraw()


## One entry point for the whole overlay state. The controller owns what is
## selected and where the mouse is; this just paints whatever it is handed, so
## there is no second copy of the selection to fall out of step.
func refresh(reachable: Array[Vector2i], attackable: Array[Vector2i],
		unit_cell: Vector2i, building_cell: Vector2i, hover: Vector2i) -> void:
	reachable_cells = reachable
	attackable_cells = attackable
	selected_unit_cell = unit_cell
	selected_building_cell = building_cell
	hovered_cell = hover
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(grid_manager):
		return

	var cs: Vector2i = grid_manager.cell_size
	var gs: Vector2i = grid_manager.grid_size

	# 1. Grid mesh
	for x in range(gs.x + 1):
		draw_line(Vector2(x * cs.x, 0), Vector2(x * cs.x, gs.y * cs.y), GRID_LINE, 1.0)
	for y in range(gs.y + 1):
		draw_line(Vector2(0, y * cs.y), Vector2(gs.x * cs.x, y * cs.y), GRID_LINE, 1.0)

	# 2. Reachable move cells — blue field, glowing border, centre dot
	for cell in reachable_cells:
		var rect := _rect_of(cell, cs)
		draw_rect(rect, MOVE_FILL)
		draw_rect(rect, MOVE_EDGE, false, 2.5)
		draw_circle(rect.get_center(), 4.5, MOVE_DOT)

	# 3. Attackable cells — crimson field, hazard border, crosshair
	for cell in attackable_cells:
		var rect := _rect_of(cell, cs)
		var center := rect.get_center()
		draw_rect(rect, ATTACK_FILL)
		draw_rect(rect, ATTACK_EDGE, false, 3.0)
		draw_line(center - Vector2(10, 0), center + Vector2(10, 0), ATTACK_CROSS, 2.0)
		draw_line(center - Vector2(0, 10), center + Vector2(0, 10), ATTACK_CROSS, 2.0)
		draw_circle(center, 4.0, ATTACK_DOT)

	# 4. Selected unit — golden ring
	if selected_unit_cell != NO_CELL:
		var rect := _rect_of(selected_unit_cell, cs)
		draw_rect(rect, UNIT_FILL)
		draw_rect(rect, UNIT_EDGE, false, 3.5)

	# 5. Selected building — emerald ring
	if selected_building_cell != NO_CELL:
		var rect := _rect_of(selected_building_cell, cs)
		draw_rect(rect, BUILDING_FILL)
		draw_rect(rect, BUILDING_EDGE, false, 3.5)

	# 6. Hover cursor — corner brackets, drawn only inside the board
	if hovered_cell.x >= 0 and hovered_cell.x < gs.x \
			and hovered_cell.y >= 0 and hovered_cell.y < gs.y:
		_draw_cursor(_rect_of(hovered_cell, cs))


func _rect_of(cell: Vector2i, cs: Vector2i) -> Rect2:
	return Rect2(Vector2(cell.x * cs.x, cell.y * cs.y), Vector2(cs.x, cs.y))


func _draw_cursor(rect: Rect2) -> void:
	var tl := rect.position + Vector2(CURSOR_PAD, CURSOR_PAD)
	var tr := Vector2(rect.end.x - CURSOR_PAD, rect.position.y + CURSOR_PAD)
	var bl := Vector2(rect.position.x + CURSOR_PAD, rect.end.y - CURSOR_PAD)
	var br := rect.end - Vector2(CURSOR_PAD, CURSOR_PAD)

	draw_line(tl, tl + Vector2(CURSOR_ARM, 0), CURSOR, 2.0)
	draw_line(tl, tl + Vector2(0, CURSOR_ARM), CURSOR, 2.0)
	draw_line(tr, tr - Vector2(CURSOR_ARM, 0), CURSOR, 2.0)
	draw_line(tr, tr + Vector2(0, CURSOR_ARM), CURSOR, 2.0)
	draw_line(bl, bl + Vector2(CURSOR_ARM, 0), CURSOR, 2.0)
	draw_line(bl, bl - Vector2(0, CURSOR_ARM), CURSOR, 2.0)
	draw_line(br, br - Vector2(CURSOR_ARM, 0), CURSOR, 2.0)
	draw_line(br, br - Vector2(0, CURSOR_ARM), CURSOR, 2.0)
