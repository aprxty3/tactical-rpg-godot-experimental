extends Camera2D
class_name TacticalCamera
## TacticalCamera — pan & zoom for a battlefield larger than the viewport.
##
## The 30x20 grid is 1920x1280 world pixels, so it no longer fits on screen at
## 1:1. Pan with WASD/arrows, a middle- or right-mouse drag, or by pushing the
## cursor into the screen edge; zoom with the wheel. Camera2D's own limit_*
## properties do the clamping, so the view can never leave the map.

@export var pan_speed: float = 900.0
@export var edge_pan_margin: float = 24.0
@export var edge_pan_enabled: bool = true
@export var zoom_step: float = 0.1
@export var zoom_min: float = 0.55
@export var zoom_max: float = 2.0

var _dragging: bool = false


## Fit the camera limits to the battlefield and centre it on `focus`.
func configure(map_pixel_size: Vector2, focus: Vector2) -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(map_pixel_size.x)
	limit_bottom = int(map_pixel_size.y)
	position = focus


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_zoom(zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_zoom(-zoom_step)
		elif event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		# Divide by zoom so a drag moves the world under the cursor 1:1.
		position -= event.relative / zoom


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0

	if edge_pan_enabled and dir == Vector2.ZERO and not _dragging:
		dir = _edge_pan_direction()

	if dir != Vector2.ZERO:
		position += dir.normalized() * pan_speed * delta / maxf(zoom.x, 0.01)


func _edge_pan_direction() -> Vector2:
	var vp := get_viewport()
	if not vp:
		return Vector2.ZERO
	var rect := vp.get_visible_rect()
	var m := vp.get_mouse_position()
	# Ignore a cursor parked outside the window — otherwise the camera drifts
	# forever while the player is alt-tabbed.
	if not rect.has_point(m):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if m.x < edge_pan_margin:
		dir.x -= 1.0
	elif m.x > rect.size.x - edge_pan_margin:
		dir.x += 1.0
	if m.y < edge_pan_margin:
		dir.y -= 1.0
	elif m.y > rect.size.y - edge_pan_margin:
		dir.y += 1.0
	return dir


func _apply_zoom(delta_zoom: float) -> void:
	var z: float = clampf(zoom.x + delta_zoom, zoom_min, zoom_max)
	zoom = Vector2(z, z)
