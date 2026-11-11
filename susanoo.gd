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

var color := Color.WHITE
var follow: Node3D       # model whose facing we copy
var ap: AnimationPlayer
var _mats: Array[ShaderMaterial] = []
var _fade := 0.0
var _dying := false

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
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position = Vector3(0, 2.5, 0)
	add_child(light)
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

## Shrinks and fades out, then frees itself.
func dismiss() -> void:
	if _dying:
		return
	_dying = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * SCALE * 0.4, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_fade, _fade, 0.0, 0.4)
	tw.chain().tween_callback(queue_free)
