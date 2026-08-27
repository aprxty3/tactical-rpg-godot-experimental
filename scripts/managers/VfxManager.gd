extends Node
class_name VfxManager
## VfxManager — Logic layer: turns things that happened into things you can see.
##
## Listens to the EventBus and nothing listens back. No gameplay script holds a
## reference to this manager, so a scene that omits it behaves identically minus
## the sparkle — which is exactly what the older focused test scenes need. It can
## never change an outcome, only illustrate one.
##
## Uses CPUParticles2D rather than GPUParticles2D on purpose: this project ships
## on the **GL Compatibility** renderer, where the GPU path's richer features
## (trails, attractors, collision) are unavailable anyway. The bursts here are
## 12-28 short-lived particles fired once, so the CPU cost is noise, and the CPU
## node needs no ParticleProcessMaterial — one node, one configuration, done.

@export_group("VFX Settings")
## Master switch. Off means no nodes are ever spawned, for a headless test run
## or a low-end machine.
@export var effects_enabled: bool = true
## Master switch for camera shake specifically — some players find it unpleasant,
## and it is the one effect that moves the whole screen.
@export var shake_enabled: bool = true

var grid_manager: GridManager
var camera: TacticalCamera
## Everything spawned goes under here, so effects never pollute the unit or
## building trees and a scene can clear them all in one call.
var effect_container: Node2D

const FX_DIR: String = "res://assets/effects/Particle FX/"
## Frame-animated sheets, as opposed to the particle textures above. 1728x192 in
## nine 192px frames — the layout is verified, not assumed.
const EXPLOSION_SHEET: String = "res://assets/effects/Explosion/Explosions.png"
const EXPLOSION_FRAMES: int = 9
## 896x128 sheet — seven 128px frames. The same sheet `Fire` uses for a burning
## cell, reused here for the flame that erupts at the instant of ignition.
const FIRE_SHEET: String = "res://assets/effects/Fire/Fire.png"
const FIRE_FRAMES: int = 7

## One table describing every effect, rather than one function per effect. Adding
## a new burst is a row here plus a call — not another near-copy of the spawn
## code, which is how effect systems usually rot.
##
## `speed` is a Vector2 read as (min, max). `gravity` is positive-down, matching
## Godot's screen axis, so a value above zero makes debris settle.
const EFFECTS: Dictionary = {
	"impact": {
		"texture": "Dust_01.png", "count": 14, "lifetime": 0.40,
		"speed": Vector2(70.0, 150.0), "spread": 180.0, "scale": 0.45,
		"gravity": 320.0, "tint": Color(1.0, 0.94, 0.78),
	},
	"crit": {
		"texture": "Explosion_01.png", "count": 18, "lifetime": 0.45,
		"speed": Vector2(110.0, 220.0), "spread": 180.0, "scale": 0.55,
		"gravity": 180.0, "tint": Color(1.0, 0.82, 0.45),
	},
	"death": {
		"texture": "Dust_02.png", "count": 22, "lifetime": 0.70,
		"speed": Vector2(50.0, 130.0), "spread": 180.0, "scale": 0.6,
		"gravity": 210.0, "tint": Color(0.95, 0.35, 0.32),
	},
	# Desertion is a rout, not a kill: pale, slow and drifting upward, so the
	# player can tell "I lost a unit" from "I broke one" without reading the log.
	"desert": {
		"texture": "Dust_02.png", "count": 16, "lifetime": 0.85,
		"speed": Vector2(30.0, 70.0), "spread": 60.0, "scale": 0.5,
		"gravity": -90.0, "tint": Color(0.72, 0.74, 0.80),
	},
	"explosion": {
		"texture": "Explosion_02.png", "count": 28, "lifetime": 0.55,
		"speed": Vector2(150.0, 300.0), "spread": 180.0, "scale": 0.75,
		"gravity": 240.0, "tint": Color(1.0, 0.72, 0.30),
	},
	# Fire_01/02/03 are sprite SHEETS (8/10/12 frames of 64px), not single
	# images. Drawn as flat textures — which is all this manager could do before
	# — every particle showed the whole filmstrip at once, which is why the
	# explosion read as orange grit instead of fire. `hframes` switches the
	# particle onto the flipbook path so each one plays the flame animation.
	#
	# Negative gravity because flame rises; the previous effects all used
	# positive gravity, which is right for debris and wrong for fire.
	"flame": {
		"texture": "Fire_02.png", "hframes": 10, "count": 18, "lifetime": 0.8,
		"speed": Vector2(55.0, 120.0), "spread": 26.0, "scale": 1.6,
		"gravity": -170.0, "tint": Color(1.0, 0.38, 0.10), "additive": true,
	},
	# The blast's own fireball: faster, wider, gone sooner.
	"fireball": {
		"texture": "Fire_03.png", "hframes": 12, "count": 20, "lifetime": 0.6,
		"speed": Vector2(110.0, 240.0), "spread": 180.0, "scale": 1.8,
		"gravity": -70.0, "tint": Color(1.0, 0.32, 0.08), "additive": true,
		"anim_speed": 0.7,
	},
	# Embers thrown clear of the blast — small, sparse, and the one fire effect
	# that falls, so the scene is not uniformly rising.
	"ember": {
		"texture": "Fire_01.png", "hframes": 8, "count": 14, "lifetime": 0.9,
		"speed": Vector2(140.0, 290.0), "spread": 180.0, "scale": 0.5,
		"gravity": 190.0, "tint": Color(1.0, 0.26, 0.05), "additive": true,
		"anim_speed": 0.65,
	},
	"ambush": {
		"texture": "Dust_01.png", "count": 12, "lifetime": 0.5,
		"speed": Vector2(40.0, 90.0), "spread": 120.0, "scale": 0.4,
		"gravity": -40.0, "tint": Color(0.55, 0.85, 0.55),
	},
}

## Textures are loaded once and shared by every burst. Reloading per effect would
## hit the disk cache on every sword swing.
var _textures: Dictionary = {}


func _ready() -> void:
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.unit_deserted.connect(_on_unit_deserted)
	EventBus.hazard_detonated.connect(_on_hazard_detonated)
	EventBus.ambush_triggered.connect(_on_ambush_triggered)
	EventBus.fire_ignited.connect(_on_fire_ignited)
	EventBus.trap_sprung.connect(_on_trap_sprung)


func setup(grid_mgr: GridManager, cam: TacticalCamera, container: Node2D) -> void:
	grid_manager = grid_mgr
	camera = cam
	effect_container = container


# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

## A swing landed. Bigger hits shake harder, and a kill reads as a kill.
func _on_combat_resolved(result: Dictionary) -> void:
	var defender = result.get("defender")
	if not is_instance_valid(defender):
		return

	var primary: Dictionary = result.get("primary_attack", {})
	var damage: int = int(primary.get("damage", 0))
	var advantage: String = str(primary.get("advantage_type", "NEUTRAL"))

	# A super-effective hit gets the brighter burst, so the advantage triangle is
	# legible in the moment rather than only in the damage number.
	var fx_id: String = "crit" if advantage != "NEUTRAL" and advantage != "DISADVANTAGE" else "impact"
	burst_at_position(defender.global_position, fx_id)

	# Shake scales with the fraction of health removed, not raw damage: losing
	# half your HP should feel the same whether you had 40 or 400.
	var max_hp: int = 100
	if is_instance_valid(defender.unit_data):
		max_hp = maxi(1, defender.unit_data.max_health)
	shake(clampf(float(damage) / float(max_hp), 0.0, 1.0) * 6.0, 0.22)


func _on_unit_died(unit: Node, _cause: String) -> void:
	if is_instance_valid(unit):
		burst_at_position(unit.global_position, "death")
		shake(4.0, 0.25)


func _on_unit_deserted(unit: Node) -> void:
	if is_instance_valid(unit):
		burst_at_position(unit.global_position, "desert")


func _on_hazard_detonated(cell: Vector2i, _radius: int, chain_index: int) -> void:
	# Four layers, because an explosion is not one shape: the flipbook is the
	# blast front, the fireball is burning gas, the debris is what it threw, and
	# the embers are what lands afterwards. Previously only the first and third
	# existed, so the blast read as a puff of orange dust.
	#
	# All of it lives here rather than half here and half in MapObjectManager,
	# which owns map objects and their rules, not their pyrotechnics.
	flipbook_at_cell(cell, EXPLOSION_SHEET, EXPLOSION_FRAMES, 0.45, 110.0)
	burst_at_cell(cell, "fireball")
	burst_at_cell(cell, "explosion")
	burst_at_cell(cell, "ember")
	# Later links in a chain shake less, otherwise a five-keg chain reaction
	# rattles the screen for a solid second.
	shake(9.0 / float(chain_index + 1), 0.35)


## A cell caught alight. `Fire` draws the steady burn that follows; this is the
## moment of ignition, which the steady loop cannot express because it starts
## mid-cycle at whatever frame the tween happens to be on.
func _on_fire_ignited(cell: Vector2i) -> void:
	flipbook_at_cell(cell, FIRE_SHEET, FIRE_FRAMES, 0.5, 86.0)
	burst_at_cell(cell, "flame")


## A hidden trap went off. Same vocabulary as a keg — it is the same kind of
## event — but the shake is fixed rather than chain-scaled, and every cell in
## the footprint erupts, so a 3x2 trap reads as a wall of fire instead of one
## bang with fire appearing beside it.
func _on_trap_sprung(cells: Array) -> void:
	if cells.is_empty():
		return
	var origin: Vector2i = cells[0]
	flipbook_at_cell(origin, EXPLOSION_SHEET, EXPLOSION_FRAMES, 0.45, 130.0)
	burst_at_cell(origin, "ember")
	for cell in cells:
		burst_at_cell(cell, "fireball")
		burst_at_cell(cell, "flame")
	shake(11.0, 0.45)


func _on_ambush_triggered(_ambusher: Node, target: Node) -> void:
	if is_instance_valid(target):
		burst_at_position(target.global_position, "ambush")


# ==============================================================================
# PUBLIC EFFECT API
# ==============================================================================

## Fire a named burst on a grid cell.
func burst_at_cell(cell: Vector2i, effect_id: String) -> CPUParticles2D:
	if not is_instance_valid(grid_manager):
		return null
	return burst_at_position(grid_manager.grid_to_world(cell), effect_id)


## Fire a named burst at a world position. Returns the node so a caller (or a
## test) can inspect it; it frees itself and needs no follow-up.
func burst_at_position(world_pos: Vector2, effect_id: String) -> CPUParticles2D:
	if not effects_enabled or not EFFECTS.has(effect_id):
		return null
	if not is_instance_valid(effect_container):
		return null

	var spec: Dictionary = EFFECTS[effect_id]
	var particles := CPUParticles2D.new()
	particles.name = "Vfx_" + effect_id
	particles.texture = _texture_for(str(spec["texture"]))
	particles.position = world_pos

	# One-shot burst: emit everything at once, then die.
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = int(spec["count"])
	particles.lifetime = float(spec["lifetime"])
	# World space, so debris stays where it was thrown even if something moves
	# the container underneath it.
	particles.local_coords = false

	var speed: Vector2 = spec["speed"]
	particles.direction = Vector2.UP
	particles.spread = float(spec["spread"])
	particles.initial_velocity_min = speed.x
	particles.initial_velocity_max = speed.y
	particles.gravity = Vector2(0.0, float(spec["gravity"]))
	particles.scale_amount_min = float(spec["scale"]) * 0.7
	particles.scale_amount_max = float(spec["scale"])
	particles.damping_min = 20.0
	particles.damping_max = 60.0

	# Fade alpha to zero over the lifetime; without this the last frame pops out
	# of existence at full opacity.
	var tint: Color = spec["tint"]
	var ramp := Gradient.new()
	ramp.set_color(0, tint)
	ramp.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	particles.color_ramp = ramp

	# Sheet-animated particles. The frame layout lives on a CanvasItemMaterial,
	# not on the particle node, so without this the whole strip is drawn as one
	# squashed image. anim_speed 1.0 means exactly one pass through the sheet
	# over the particle's lifetime — looping would restart a flame that is
	# already fading out.
	if spec.has("hframes"):
		var mat := CanvasItemMaterial.new()
		mat.particles_animation = true
		mat.particles_anim_h_frames = int(spec["hframes"])
		mat.particles_anim_v_frames = 1
		mat.particles_anim_loop = false
		# NOTE on tints for additive rows: an additive tint is not the colour you
		# see, it is the colour ADDED to the ground behind it. Over this game's
		# grass a warm orange sums into pale yellow, so the fire rows carry
		# deliberately green-starved tints that only look right once added.
		#
		# Fire emits light, so overlapping flames must ADD rather than occlude.
		# On the default mix blend the nearest particle simply hides the ones
		# behind it and a cluster reads as opaque orange rubble; additive makes
		# the overlap brighten, which is what the eye recognises as flame.
		# Opt-in per effect: dust and debris are lit, not luminous, and would
		# turn into white smears.
		if bool(spec.get("additive", false)):
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		particles.material = mat
		# How far through the sheet a particle gets before it dies. 1.0 plays the
		# whole strip, which on these sheets ends in smoke frames — fine for a
		# steady flame, wrong for a blast, where the dark tail reads as rubble
		# rather than fire. Below 1.0 the particle expires while still luminous.
		var anim_speed: float = float(spec.get("anim_speed", 1.0))
		particles.anim_speed_min = anim_speed
		particles.anim_speed_max = anim_speed
		# Stagger the starting frame so sixteen flames are not the same flame.
		particles.anim_offset_min = 0.0
		particles.anim_offset_max = 0.4

	effect_container.add_child(particles)
	particles.emitting = true

	# Free once every particle has expired. The margin covers the frame the last
	# particle dies on; without it a burst can be culled mid-fade.
	_free_after(particles, float(spec["lifetime"]) + 0.35)
	return particles


## Play a horizontal sprite-sheet animation once on a grid cell, then free it.
##
## Complements the particle bursts rather than competing with them: a flipbook
## draws one authored shape (a fireball), particles throw many identical ones
## (debris). `display_height` scales the sheet to a readable size on a 64 px
## tile regardless of the source resolution.
func flipbook_at_cell(cell: Vector2i, sheet_path: String, frames: int,
		duration: float, display_height: float) -> Sprite2D:
	if not effects_enabled or not is_instance_valid(grid_manager):
		return null
	if not is_instance_valid(effect_container):
		return null

	var texture: Texture2D = _texture_for_path(sheet_path)
	if not is_instance_valid(texture) or frames <= 0:
		return null

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.hframes = frames
	sprite.frame = 0
	sprite.scale = Vector2.ONE * (display_height / float(texture.get_height()))
	sprite.position = grid_manager.grid_to_world(cell)
	effect_container.add_child(sprite)

	# tween_method rather than an AnimationPlayer: this is one throwaway node
	# with one linear frame sweep, and building an Animation resource for it
	# would be more machinery than the effect is worth.
	var tween := sprite.create_tween()
	tween.tween_method(_set_sheet_frame.bind(sprite, frames), 0.0, float(frames), duration)
	tween.tween_callback(sprite.queue_free)
	return sprite


## Tween target for a flipbook. Bound arguments arrive after the interpolated
## value, so the signature leads with `value`.
func _set_sheet_frame(value: float, sprite: Sprite2D, frames: int) -> void:
	if is_instance_valid(sprite):
		sprite.frame = clampi(int(value), 0, frames - 1)


## Rattle the camera.
##
## Animates `offset`, never `position`. `position` is what Camera2D's `limit_*`
## properties clamp, so shaking it would be silently squashed against the map
## edge — the shake would weaken exactly where the player is most likely to be
## fighting. `offset` is applied after clamping and is unaffected.
func shake(strength: float, duration: float) -> void:
	if not shake_enabled or strength <= 0.0:
		return
	if is_instance_valid(camera) and camera.has_method("shake"):
		camera.shake(strength, duration)


# ==============================================================================
# INTERNALS
# ==============================================================================

func _texture_for(file_name: String) -> Texture2D:
	return _texture_for_path(FX_DIR + file_name)


## Load-once cache keyed by full path. A battle fires hundreds of bursts; going
## back to load() each time would hit the resource cache on every sword swing.
func _texture_for_path(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = load(path) as Texture2D
	_textures[path] = tex
	return tex


## Self-cleanup. One-shot particles do not free themselves, and a battle spawns
## hundreds of them — without this the scene tree grows for the whole match.
func _free_after(node: Node, seconds: float) -> void:
	var tree := get_tree()
	if not tree:
		node.queue_free()
		return
	var timer := tree.create_timer(seconds)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)
