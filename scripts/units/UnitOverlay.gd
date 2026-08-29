extends Node2D
class_name UnitOverlay
## UnitOverlay — the overhead status readout for one unit: HP bar, morale strip,
## and floating combat text.
##
## Extracted from `TacticalUnit`, which had grown ~150 lines of widget
## construction. Nothing here knows a game rule — bands, immunity and palettes
## arrive already resolved, so it has no opinion that could drift.
##
## One component, not three: the widgets share a stacked column above the
## sprite, so their offsets are coupled by layout.
##
## The unit calls in directly rather than via signals — a parent driving its own
## child. The rule that must not break is the reverse: nothing here reaches back
## up to the unit or sideways to a sibling.
##
## Built lazily, so a caller can push state the same frame it is created.

## Width of both bars, in pixels. The morale fill is a fraction of this.
@export var bar_width: float = 70.0
## Height of the HP bar.
@export var hp_bar_height: float = 10.0
## Height of the morale strip. Deliberately thin — it is a glance, not a readout.
@export var morale_bar_height: float = 4.0
## Top-left of the HP bar, relative to the unit's origin.
@export var hp_bar_offset: Vector2 = Vector2(-35.0, -55.0)
## Top-left of the morale strip. Sits just under the HP bar.
@export var morale_bar_offset: Vector2 = Vector2(-35.0, -43.0)
## Where floating text spawns before it rises.
@export var float_text_offset: Vector2 = Vector2(-20.0, -70.0)
## How far floating text rises, and over how long.
@export var float_text_rise: float = 24.0
@export var float_text_duration: float = 0.6

# === Widgets (built on first use) ===
var _hp_bar: ProgressBar
var _hp_label: Label
var _hp_fill_style: StyleBoxFlat
var _hp_bg_style: StyleBoxFlat
var _hp_tween: Tween

var _morale_bar: ColorRect
var _morale_fill: ColorRect

var _built: bool = false


# === Public API ===

## Recolour the HP bar's border to the owning faction. This is how a defecting
## unit reads as having changed sides — the bar outline flips colour with it.
func set_faction_tint(tint: Color) -> void:
	_ensure_built()
	if _hp_bg_style:
		_hp_bg_style.border_color = Color(tint.r, tint.g, tint.b, 0.95)


## Draw a health value. `animate` tweens the bar toward the new value; pass
## false when setting up or when the change was not a hit (spawn, promotion).
func show_health(current: int, maximum: int, animate: bool = false) -> void:
	_ensure_built()
	if maximum <= 0:
		return

	_hp_bar.max_value = maximum
	var ratio: float = float(current) / float(maximum)

	# Green above half, amber down to a quarter, red below it — the last band is
	# the one that has to be readable at a glance across a 30x20 map.
	var bar_color: Color
	if ratio > 0.5:
		bar_color = Color(0.2, 0.85, 0.35)
	elif ratio > 0.25:
		bar_color = Color(0.95, 0.7, 0.15)
	else:
		bar_color = Color(0.95, 0.2, 0.2)
	_hp_fill_style.bg_color = bar_color

	var shown: int = maxi(0, current)
	if ratio <= 0.25 and current > 0:
		_hp_label.text = "⚠️ %d/%d" % [shown, maximum]
	else:
		_hp_label.text = "%d/%d" % [shown, maximum]

	if animate:
		# Two hits in one frame (a blast plus the fire it lit) would otherwise
		# leave two tweens racing the same property.
		if _hp_tween and _hp_tween.is_valid():
			_hp_tween.kill()
		_hp_tween = create_tween()
		_hp_tween.set_ease(Tween.EASE_OUT)
		_hp_tween.set_trans(Tween.TRANS_QUAD)
		_hp_tween.tween_property(_hp_bar, "value", float(shown), 0.25)
	else:
		_hp_bar.value = float(shown)


## Draw a morale value. `strip_visible` false hides the strip entirely — that is
## how Undead render, having no morale to show rather than full morale.
func show_morale(value: int, maximum: int, color: Color, strip_visible: bool) -> void:
	_ensure_built()
	if not strip_visible:
		_morale_bar.visible = false
		return

	_morale_bar.visible = true
	var ratio: float = clampf(float(value) / float(maximum), 0.0, 1.0) if maximum > 0 else 0.0
	_morale_fill.size = Vector2(bar_width * ratio, morale_bar_height)
	_morale_fill.color = color


## Rising, fading text over the unit: damage, healing, a morale band change,
## a mount toggle.
func pop_text(text: String, color: Color) -> void:
	_ensure_built()
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.position = float_text_offset
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - float_text_rise,
		float_text_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, float_text_duration) \
		.set_ease(Tween.EASE_IN).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


## Fade the whole readout on a caller-owned tween — used by the death sequence
## so the bars dissolve with the sprite instead of outliving it.
func fade_out(tween: Tween, duration: float) -> void:
	_ensure_built()
	tween.tween_property(self, "modulate:a", 0.0, duration)


# === Construction ===

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_build_hp_bar()
	_build_morale_bar()


func _build_hp_bar() -> void:
	_hp_bar = ProgressBar.new()
	_hp_bar.name = "FloatingHPBar"
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.custom_minimum_size = Vector2(bar_width, hp_bar_height)
	_hp_bar.size = Vector2(bar_width, hp_bar_height)
	_hp_bar.position = hp_bar_offset

	_hp_bg_style = StyleBoxFlat.new()
	_hp_bg_style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	_hp_bg_style.set_border_width_all(1)
	_hp_bg_style.set_corner_radius_all(2)
	_hp_bg_style.border_color = Color(0.7, 0.7, 0.75, 0.95)
	_hp_bar.add_theme_stylebox_override("background", _hp_bg_style)

	_hp_fill_style = StyleBoxFlat.new()
	_hp_fill_style.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill_style)

	_hp_label = Label.new()
	_hp_label.name = "HPLabel"
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.size = _hp_bar.size
	_hp_label.position = Vector2.ZERO
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 10)
	_hp_label.add_theme_constant_override("outline_size", 3)
	_hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hp_bar.add_child(_hp_label)

	add_child(_hp_bar)


func _build_morale_bar() -> void:
	_morale_bar = ColorRect.new()
	_morale_bar.name = "MoraleStrip"
	_morale_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_morale_bar.color = Color(0.08, 0.08, 0.1, 0.85)
	_morale_bar.size = Vector2(bar_width, morale_bar_height)
	_morale_bar.position = morale_bar_offset

	_morale_fill = ColorRect.new()
	_morale_fill.name = "Fill"
	_morale_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_morale_fill.position = Vector2.ZERO
	_morale_fill.size = Vector2(bar_width, morale_bar_height)
	_morale_bar.add_child(_morale_fill)

	add_child(_morale_bar)
