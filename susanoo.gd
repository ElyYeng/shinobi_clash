class_name Susanoo
extends Node3D
## The skeletal Susanoo (Uchiha, hold C). Pure visual: model + chakra shader + animations, used by
## the local player and by remote avatars. The player script does the damage (player.gd).
## Model: assets/susanoo/susanoo.glb - animations idle / Leftpunch / rightpunch / slampunch.

## Susanoo colours - every player rolls one at random the first time (GameData.susanoo_color).
const PALETTE := [
	Color(0.55, 0.25, 1.0),   # purple
	Color(0.2, 0.5, 1.0),     # blue
	Color(1.0, 0.15, 0.2),    # red
	Color(0.2, 0.95, 0.45),   # green
	Color(1.0, 0.55, 0.1),    # orange
	Color(1.0, 0.88, 0.2),    # yellow
	Color(0.2, 0.95, 1.0),    # cyan
	Color(1.0, 0.35, 0.75),   # pink
	Color(0.9, 0.95, 1.0),    # white
]
const NAMES := ["Purple", "Blue", "Red", "Green", "Orange", "Yellow", "Cyan", "Pink", "White"]
const SCALE := 1.3
const ANIMS := {"lpunch": "Leftpunch", "rpunch": "rightpunch", "slam": "slampunch"}
const SPEED := {"lpunch": 1.5, "rpunch": 1.5, "slam": 1.25}
const IMPACT := 1.1    # seconds into each attack animation (at speed 1) where the hit lands

## Sounds (assets/susanoo/sfx, cut from the Susanoo sound pack). `peak` = seconds into the clip
## where it's loudest - hits are timed so that lands on the impact frame.
const SFX := "res://assets/susanoo/sfx/"
const HITS := [{"file": "punch_hit_a.ogg", "peak": 0.36}, {"file": "punch_hit_b.ogg", "peak": 0.24}]
const SLAM_PEAK := 1.48

var color := Color.WHITE
var follow: Node3D       # model whose facing we copy
var ap: AnimationPlayer
var _mats: Array[ShaderMaterial] = []
var _fade := 0.0
var _dying := false
var _hit_variant := 0

static var _noise: NoiseTexture2D

## Shared seamless noise for the chakra fire (generated once).
static func fire_noise() -> NoiseTexture2D:
	if _noise == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.012
		fn.fractal_octaves = 4
		fn.fractal_gain = 0.55
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.generate_mipmaps = true
		_noise.noise = fn
	return _noise

static func palette_color(i: int) -> Color:
	return PALETTE[posmod(i, PALETTE.size())]

## Your colour index - rolled randomly once and saved.
static func my_color_index() -> int:
	if GameData.susanoo_color < 0 or GameData.susanoo_color >= PALETTE.size():
		GameData.susanoo_color = randi() % PALETTE.size()
		GameData.save()
	return GameData.susanoo_color

## Rolls a new random colour (never the same one again) and saves it. Customize > ROLL.
static func reroll_color() -> int:
	var cur := my_color_index()
	var n := randi() % (PALETTE.size() - 1)
	GameData.susanoo_color = n if n < cur else n + 1
	GameData.save()
	return GameData.susanoo_color

## Seconds from starting an attack to its hit landing.
static func impact_delay(kind: String) -> float:
	return IMPACT / float(SPEED.get(kind, 1.0))

static func create(col: Color, follow_model: Node3D) -> Susanoo:
	var s := Susanoo.new()
	s.name = "Susanoo"
	s.color = col
	s.follow = follow_model
	return s

func _ready() -> void:
	var m: Node3D = load("res://assets/susanoo/susanoo.glb").instantiate()
	add_child(m)
	m.rotation.y = PI          # the model faces +Z, characters face -Z
	scale = Vector3.ONE * SCALE * 0.3
	var sh := load("res://shaders/susanoo.gdshader") as Shader
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var src := (mi as MeshInstance3D).get_active_material(0) as BaseMaterial3D
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("color", color)
		if src != null and src.albedo_texture != null:
			mat.set_shader_parameter("detail", src.albedo_texture)
		mat.set_shader_parameter("fade", 0.0)
		mat.set_shader_parameter("noise", fire_noise())
		(mi as MeshInstance3D).material_override = mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mats.append(mat)
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		ap = aps[0]
		var idle := ap.get_animation("idle")
		if idle != null:
			idle.loop_mode = Animation.LOOP_LINEAR
		ap.animation_finished.connect(func(_n: StringName) -> void: ap.play("idle", 0.35))
		ap.play("idle")
	# chakra flames licking up off the ribcage (on the model, so they move with it)
	var flames := Node3D.new()
	flames.position = Vector3(0, 1.6, 0)
	m.add_child(flames)
	Vfx.aura_flames(flames, Vector3.ZERO, 1.5, Color(color.r, color.g, color.b, 0.55), 20, true)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position = Vector3(0, 2.5, 0)
	add_child(light)
	_sound("summon.ogg", 2.0)
	# form up: grow from small and fade in
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * SCALE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_fade, 0.0, 1.0, 0.45)

func _set_fade(v: float) -> void:
	_fade = v
	for mat in _mats:
		mat.set_shader_parameter("fade", v)

func _process(delta: float) -> void:
	if follow != null and is_instance_valid(follow) and not _dying:
		rotation.y = lerp_angle(rotation.y, follow.global_rotation.y, 1.0 - exp(-10.0 * delta))

## lpunch / rpunch / slam
func attack(kind: String) -> void:
	if ap == null or _dying or not ANIMS.has(kind):
		return
	ap.play(ANIMS[kind], 0.12, float(SPEED[kind]))
	var hit_at := impact_delay(kind)
	if kind == "slam":
		_sound("slam_windup.ogg", -2.0)
		# the boom's loudest moment lands on the impact (start it part-way in if needed)
		var lead := SLAM_PEAK - hit_at
		if lead > 0.0:
			_sound("slam.ogg", 3.0, lead)
		else:
			get_tree().create_timer(-lead).timeout.connect(_sound.bind("slam.ogg", 3.0, 0.0))
	else:
		_sound("punch_whoosh.ogg", -3.0)
		var h: Dictionary = HITS[_hit_variant % HITS.size()]
		_hit_variant += 1
		get_tree().create_timer(maxf(0.0, hit_at - float(h["peak"]))).timeout.connect(_sound.bind(str(h["file"]), 1.0, 0.0))

## Plays one of the Susanoo sounds from where the Susanoo is (others hear it too, by distance).
## detached = keep playing after the Susanoo is gone (release sound).
func _sound(file: String, db := 0.0, from := 0.0, detached := false) -> void:
	if not is_inside_tree():
		return
	var stream := load(SFX + file) as AudioStream
	if stream == null:
		return
	var pl := AudioStreamPlayer3D.new()
	pl.stream = stream
	pl.volume_db = db
	pl.unit_size = 14.0
	pl.max_distance = 90.0
	pl.bus = "Master"
	if detached and get_parent() != null and get_parent().get_parent() != null:
		var host := get_parent().get_parent()
		host.add_child(pl)
		pl.global_position = global_position + Vector3.UP * 2.0
	else:
		add_child(pl)
		pl.position = Vector3.UP * 2.0
	pl.finished.connect(pl.queue_free)
	pl.play(from)

## Shrinks and fades out, then frees itself.
func dismiss() -> void:
	if _dying:
		return
	_dying = true
	_sound("release.ogg", -1.0, 0.0, true)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * SCALE * 0.4, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_fade, _fade, 0.0, 0.4)
	tw.chain().tween_callback(queue_free)
