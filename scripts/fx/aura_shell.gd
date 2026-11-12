class_name AuraShell
extends Node
## Chakra aura around a character (Aura 3D shader): every visible mesh of the model gets a
## slightly inflated copy with the aura material (skinned copies follow the animation). The
## copies live as long as this node: add it anywhere, free it (or call fade_out) to remove them.

const SHADER := preload("res://shaders/aura.gdshader")
const PUSH_WORLD := 0.07    # shell thickness in metres

static var _noise: NoiseTexture2D

var model: Node3D
var aura_col := Color(0.25, 0.6, 1.0)
var rim_col := Color(0.75, 0.92, 1.0)
var push := PUSH_WORLD    # shell thickness (m)
var mat: ShaderMaterial
var _shells: Array[MeshInstance3D] = []

static func make(parent: Node, model_: Node3D, aura: Color, rim: Color, fade_in := 0.25, thickness := PUSH_WORLD) -> AuraShell:
	var a := AuraShell.new()
	a.push = thickness
	a.model = model_
	a.aura_col = aura
	a.rim_col = rim
	parent.add_child(a)
	if fade_in > 0.0 and a.mat != null:
		a.mat.set_shader_parameter("_Strength", 0.0)
		a.create_tween().tween_method(func(v: float) -> void: a.mat.set_shader_parameter("_Strength", v), 0.0, 1.0, fade_in)
	return a

static func noise() -> NoiseTexture2D:
	if _noise == null:
		var fn := FastNoiseLite.new()
		fn.frequency = 1.0 / 32.0
		fn.fractal_octaves = 8
		fn.fractal_gain = 0.75
		fn.fractal_lacunarity = 2.75
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.as_normal_map = true
		_noise.bump_strength = 32.0
		_noise.noise = fn
	return _noise

func _ready() -> void:
	if model == null or not is_instance_valid(model):
		return
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("_NoiseTex", noise())
	mat.set_shader_parameter("_ColorAura", aura_col)
	mat.set_shader_parameter("_ColorRim", rim_col)
	mat.set_shader_parameter("_RimPower2", 2.2)    # wider glow than the shader default (6)
	mat.set_shader_parameter("_Scale", 0.035)
	mat.set_shader_parameter("_SpeedY", 6.0)       # flames rise faster
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.has_meta("aura_shell") or mi.has_meta("no_aura") \
				or mi.get_aabb().size.length() < 0.001:
			continue
		var sh := MeshInstance3D.new()
		sh.set_meta("aura_shell", true)
		sh.mesh = mi.mesh
		sh.skin = mi.skin
		sh.transform = mi.transform
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sh.material_override = mat
		mi.get_parent().add_child(sh)
		if mi.skeleton != NodePath(""):
			sh.skeleton = mi.skeleton   # sibling: same relative path to the skeleton
		_shells.append(sh)
	mat.set_shader_parameter("_Push", push)

## A short burst of aura (forming a Susanoo, transforming ...): bright, then fades away.
static func flare(parent: Node, model_: Node3D, col: Color, life := 1.2) -> void:
	if parent == null or model_ == null or not parent.is_inside_tree():
		return
	var a := make(parent, model_, col, col.lightened(0.6), 0.0)
	a.set_strength(2.0)
	a.get_tree().create_timer(maxf(life - 0.5, 0.05)).timeout.connect(func() -> void:
		if is_instance_valid(a):
			a.fade_out(0.5))

## First AuraShell under `n` (e.g. a power-up's fx node), or null.
static func find_in(n: Node) -> AuraShell:
	if n == null or not is_instance_valid(n):
		return null
	for c in n.get_children():
		if c is AuraShell:
			return c
	return null

func set_colors(aura: Color, rim: Color) -> void:
	aura_col = aura
	rim_col = rim
	if mat != null:
		mat.set_shader_parameter("_ColorAura", aura)
		mat.set_shader_parameter("_ColorRim", rim)

func set_strength(v: float) -> void:
	if mat != null:
		mat.set_shader_parameter("_Strength", v)

func fade_out(t := 0.3) -> void:
	if is_queued_for_deletion() or has_meta("closing"):
		return
	set_meta("closing", true)
	if mat == null or not is_inside_tree():
		queue_free()
		return
	var from: float = mat.get_shader_parameter("_Strength")
	var tw := create_tween()
	tw.tween_method(set_strength, from, 0.0, t)
	tw.tween_callback(queue_free)

func _exit_tree() -> void:
	for sh in _shells:
		if is_instance_valid(sh):
			sh.queue_free()
	_shells.clear()
