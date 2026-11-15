class_name KuramaCloak
extends Node3D
## Boss-unlocked Z form: vermilion chakra aura, two small ears, one to three tails (ears and tails use
## the same aura material as the body, so they flicker and fade with it).
## Shared by Player and multiplayer avatars. Never changes the character's scale.

const CHAKRA := Color(0.95, 0.095, 0.025)
const RIM := Color(1.0, 0.32, 0.06)
const TAIL_BASE := Vector3(0.0, 0.85, 0.12)   # the tail swings around this point
## Curve control points (b, c, d) of each tail, starting from TAIL_BASE: 1 = S over the head, 2 = the
## mirrored one on the other side, 3 = one rising straight behind the back. [radius, b, c, d]
const TAIL_SHAPES := [
	[0.17, Vector3(-0.55, 1.10, 1.10), Vector3(-0.90, 2.90, 0.90), Vector3(0.25, 2.75, 0.10)],
	[0.15, Vector3(0.55, 1.00, 1.10), Vector3(0.95, 2.50, 0.85), Vector3(-0.10, 2.35, 0.05)],
	[0.14, Vector3(0.0, 1.25, 1.20), Vector3(0.15, 2.45, 1.40), Vector3(0.0, 2.95, 0.60)],
]
const RINGS := 32
const SIDES := 12

var model: Node3D
var _aura: AuraShell
var tails := 1   # 1..3, set before the cloak is added or later with set_tails()
var _tail_nodes: Array[MeshInstance3D] = []
var _ears: Node3D
var _head_skeleton: Skeleton3D
var _head_bone := -1
var _hip_bone := -1
var _tails_root: Node3D   # sits on the hip bone; the tails hang off it
var _age := 0.0

static func attach(parent: Node, character: Node3D, tail_count := 1) -> KuramaCloak:
	var cloak := KuramaCloak.new()
	cloak.model = character
	cloak.tails = clampi(tail_count, 1, TAIL_SHAPES.size())
	parent.add_child(cloak)
	return cloak

func _ready() -> void:
	if not is_instance_valid(model):
		queue_free()
		return
	# World-sized effects follow the model's pose without inheriting its import scale.
	top_level = true
	_aura = AuraShell.make(self, model, CHAKRA, RIM, 0.0, 0.045)
	_aura.set_strength(0.0)
	_aura.mat.set_shader_parameter("_Brightness", 0.8)
	_aura.mat.set_shader_parameter("_Opacity", 3.0)
	_aura.mat.set_shader_parameter("_OutlineFixed", 0.8)
	_aura.mat.set_shader_parameter("_SpeedY", 4.0)
	_aura.mat.set_shader_parameter("_OffsetFade", 10.0)   # the default fades the aura out below ~1 m under the camera: legs stayed bare
	_tails_root = Node3D.new()
	add_child(_tails_root)
	_build_tails()
	_ears = Node3D.new()
	add_child(_ears)
	for side in [-1.0, 1.0]:
		var ear := _tube(   # short, wide fox ear on top of the head (thin cones vanish in the aura shader)
			Vector3(side * 0.04, 0.05, -0.01), Vector3(side * 0.06, 0.16, -0.01),
			Vector3(side * 0.09, 0.27, 0.0), Vector3(side * 0.13, 0.40, 0.0),
			0.07, _aura.mat, 0.8, 0.1)   # base sits inside the skull so the ear grows out of the hair
		_ears.add_child(ear)
	# Cache the head bone once rather than traversing the model every frame.
	for node in model.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		var hip := -1
		for bone in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(bone).to_lower()
			if _head_bone < 0 and bone_name.ends_with("head") and not bone_name.contains("ctrl"):
				_head_skeleton = skeleton
				_head_bone = bone
			if hip < 0 and (bone_name.ends_with("hips") or bone_name.contains("pelvis")) and not bone_name.contains("ctrl"):
				hip = bone
		if _head_bone >= 0:
			_hip_bone = hip
			break
	_follow_model()

## Like the anime cloak: fat S-shaped tails rise behind the back and end in a point (the aura shell
## adds ~0.045 m to every radius).
func _build_tails() -> void:
	for t in _tail_nodes:
		t.queue_free()
	_tail_nodes.clear()
	for i in tails:
		var sh: Array = TAIL_SHAPES[i]
		var tail := _tube(TAIL_BASE, sh[1], sh[2], sh[3], float(sh[0]), _aura.mat, 0.7, 0.55)
		_tails_root.add_child(tail)
		_tail_nodes.append(tail)

func set_tails(count: int) -> void:
	count = clampi(count, 1, TAIL_SHAPES.size())
	if count == tails:
		return
	tails = count
	if _aura != null:
		_build_tails()

func _process(delta: float) -> void:
	if not is_instance_valid(model) or not model.is_inside_tree():
		queue_free()
		return
	_age += delta
	var strength := smoothstep(0.0, 0.45, _age)
	_aura.set_strength(strength * (0.70 + sin(_age * 3.0) * 0.045))
	# The tail lashes side to side and nods a little, pivoting at its base.
	for i in _tail_nodes.size():   # each tail has its own rhythm
		var ph := float(i) * 2.1
		var sway := Basis(Vector3.UP, sin(_age * 2.4 + ph) * 0.30 + sin(_age * 5.1 + ph) * 0.06) * Basis(Vector3.RIGHT, sin(_age * 1.7 + 1.0 + ph) * 0.08)
		_tail_nodes[i].transform = Transform3D(sway, TAIL_BASE - sway * TAIL_BASE)
	_follow_model()

func _follow_model() -> void:
	global_transform = Transform3D(model.global_basis.orthonormalized(), model.global_position)
	visible = model.is_visible_in_tree()
	var head_position := model.global_position + global_basis.y * 1.60
	if is_instance_valid(_head_skeleton) and _head_bone >= 0:
		head_position = (_head_skeleton.global_transform * _head_skeleton.get_bone_global_pose(_head_bone)).origin
	_ears.global_position = head_position
	# The tails stay on the waist however the body leans, dashes or crouches (the model's root stays
	# at the feet): their base follows the hip bone, the direction follows the character.
	var waist := model.global_position + global_basis.y * TAIL_BASE.y
	if is_instance_valid(_head_skeleton) and _hip_bone >= 0:
		waist = (_head_skeleton.global_transform * _head_skeleton.get_bone_global_pose(_hip_bone)).origin
	_tails_root.global_position = waist - global_basis.y * TAIL_BASE.y
	# Head tracking rotates the ears along with the character's face.
	_ears.global_basis = (_head_skeleton.global_transform * _head_skeleton.get_bone_global_pose(_head_bone)).basis.orthonormalized() if is_instance_valid(_head_skeleton) and _head_bone >= 0 else global_basis

## Closed tapered tube with analytic curve tangents and a stable radial frame.
## Only built on activation; the flowing chakra is animated by the aura shader.
## taper: how sharply it narrows to a point (1 = cone); bulge: extra thickness in the middle.
static func _tube(a: Vector3, b: Vector3, c: Vector3, d: Vector3, radius: float, material: Material, taper := 0.65, bulge := 0.40) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var previous_axis := Vector3.RIGHT
	for ring in RINGS + 1:
		var t := float(ring) / RINGS
		var u := 1.0 - t
		var center := a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t
		var tangent := ((b - a) * 3.0 * u * u + (c - b) * 6.0 * u * t + (d - c) * 3.0 * t * t).normalized()
		# Transport the frame to prevent a visible UV twist halfway up the tail.
		var axis := previous_axis - tangent * previous_axis.dot(tangent)
		if axis.length_squared() < 0.0001:
			axis = tangent.cross(Vector3.FORWARD)
		axis = axis.normalized()
		previous_axis = axis
		var other := tangent.cross(axis).normalized()
		var width := radius * pow(1.0 - t, taper) * (1.0 + sin(t * PI) * bulge)
		for segment in SIDES + 1:
			var angle := TAU * float(segment) / SIDES
			var normal := axis * cos(angle) + other * sin(angle)
			vertices.append(center + normal * width)
			normals.append(normal)
			uvs.append(Vector2(float(segment) / SIDES, t))
			if ring < RINGS and segment < SIDES:
				var i := ring * (SIDES + 1) + segment
				var next := i + SIDES + 1
				indices.append_array(PackedInt32Array([i, next, i + 1, i + 1, next, next + 1]))
	# Seal the base inside the body/head.
	var cap := vertices.size()
	vertices.append(a)
	normals.append((a - b).normalized())
	uvs.append(Vector2(0.5, 0.0))
	for segment in SIDES:
		indices.append_array(PackedInt32Array([cap, segment, segment + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 0.25
	instance.set_meta("no_aura", true)
	return instance
