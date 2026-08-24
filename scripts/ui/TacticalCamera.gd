extends Camera2D
class_name TacticalCamera
## TacticalCamera — pan & zoom for a battlefield larger than the viewport.
##
## The 30x20 grid is 1920x1280 world pixels, so it no longer fits on screen at
## 1:1. Pan by dragging with any mouse button, with WASD/arrows, or by pushing
## the cursor into the screen edge; zoom with the wheel. Camera2D's own limit_*
## properties do the clamping, so the view can never leave the map.

@export var pan_speed: float = 900.0
@export var edge_pan_margin: float = 24.0
@export var edge_pan_enabled: bool = true
@export var zoom_step: float = 0.1
@export var zoom_min: float = 0.55
@export var zoom_max: float = 2.0

## Left-drag has to pan without stealing click-to-select, so the two are told
## apart by distance: the press only becomes a pan once the cursor has travelled
## this far from where it went down. Below it nothing moves and the release
## falls through to the grid as an ordinary click.
const LEFT_DRAG_THRESHOLD_PX: float = 6.0

## Middle/right drag — these pan from the first pixel, nothing else wants them.
var _dragging: bool = false
var _left_down: bool = false
var _left_pan: bool = false
var _left_press_pos: Vector2 = Vector2.ZERO

## Screen shake, decayed in _process. Held as remaining strength + remaining time
## rather than a Tween because a second impact during a shake must *reinforce*
## the first, not restart it — a tween would snap the offset back and read as a
## stutter mid-explosion.
var _shake_strength: float = 0.0
var _shake_remaining: float = 0.0
var _shake_total: float = 0.0


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
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_left_down = true
				_left_pan = false
				_left_press_pos = event.position
			else:
				# Swallow the release that ended a pan. This camera is a child of the
				# controller, so it sees unhandled input first; marking the event
				# handled is what stops the grid from reading the end of a drag as a
				# click on whatever tile the cursor happened to stop over.
				if _left_pan:
					get_viewport().set_input_as_handled()
				_left_down = false
				_left_pan = false
	elif event is InputEventMouseMotion:
		# Divide by zoom so a drag moves the world under the cursor 1:1.
		if _dragging:
			position -= event.relative / zoom
		elif _left_down:
			if not _left_pan and event.position.distance_to(_left_press_pos) > LEFT_DRAG_THRESHOLD_PX:
				_left_pan = true
			if _left_pan:
				position -= event.relative / zoom


func _process(delta: float) -> void:
	_process_shake(delta)

	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0

	if edge_pan_enabled and dir == Vector2.ZERO and not _dragging and not _left_pan:
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


## Rattle the view. Reinforcing rather than replacing: a bigger impact during an
## existing shake takes over, a smaller one is ignored, so a chain of explosions
## builds instead of resetting on every link.
func shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	if strength >= _shake_strength:
		_shake_strength = strength
		_shake_total = duration
		_shake_remaining = duration


## Decay the shake and write it to `offset`.
##
## `offset` and NOT `position`: Camera2D clamps `position` against limit_left /
## limit_right / limit_top / limit_bottom, so a position-based shake is silently
## flattened against the map edge — weakest exactly where the fighting tends to
## be. `offset` is applied after that clamp, so the shake is identical
## everywhere on the map.
func _process_shake(delta: float) -> void:
	if _shake_remaining <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return

	_shake_remaining = maxf(0.0, _shake_remaining - delta)
	# Fade out over the shake's own duration so it settles instead of cutting.
	var falloff: float = _shake_remaining / maxf(0.001, _shake_total)
	var amount: float = _shake_strength * falloff
	offset = Vector2(
		randf_range(-amount, amount),
		randf_range(-amount, amount)
	)

	if _shake_remaining <= 0.0:
		_shake_strength = 0.0
		offset = Vector2.ZERO
