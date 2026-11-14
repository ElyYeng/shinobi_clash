class_name KuramaCloak
extends Node3D
## Boss-unlocked Z form: vermilion chakra aura, two small ears, exactly one tail (ears and tail use
## the same aura material as the body, so they flicker and fade with it).
## Shared by Player and multiplayer avatars. Never changes the character's scale.

const CHAKRA := Color(0.95, 0.095, 0.025)
const RIM := Color(1.0, 0.32, 0.06)
const RINGS := 32
const SIDES := 12

var model: Node3D
var _aura: AuraShell
var _tail: MeshInstance3D
var _ears: Node3D
var _head_skeleton: Skeleton3D
var _head_bone := -1
var _age := 0.0

static func attach(parent: Node, character: Node3D) -> KuramaCloak:
	var cloak := KuramaCloak.new()
	cloak.model = character
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
	# One tapered curve rises behind the body and curls up to head height (aura material, so the
	# shell adds ~0.045 m to every radius below).
	_tail = _tube(
		Vector3(0.0, 0.90, 0.12), Vector3(-0.25, 1.00, 0.80),
		Vector3(-0.35, 2.00, 0.70), Vector3(0.20, 1.80, 0.35),
		0.12, _aura.mat)
	add_child(_tail)
	_ears = Node3D.new()
	add_child(_ears)
	for side in [-1.0, 1.0]:
		var ear := _tube(
			Vector3(side * 0.12, 0.12, 0.0), Vector3(side * 0.17, 0.20, 0.01),
			Vector3(side * 0.20, 0.32, 0.02), Vector3(side * 0.23, 0.38, 0.01),
			0.05, _aura.mat)
		_ears.add_child(ear)
	# Cache the head bone once rather than traversing the model every frame.
	for node in model.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		for bone in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(bone).to_lower()
			if bone_name.ends_with("head") and not bone_name.contains("ctrl"):
				_head_skeleton = skeleton
				_head_bone = bone
				break
		if _head_bone >= 0:
			break
	_follow_model()

func _process(delta: float) -> void:
	if not is_instance_valid(model) or not model.is_inside_tree():
		queue_free()
		return
	_age += delta
	var strength := smoothstep(0.0, 0.45, _age)
	_aura.set_strength(strength * (0.70 + sin(_age * 3.0) * 0.045))
	_follow_model()

func _follow_model() -> void:
	global_transform = Transform3D(model.global_basis.orthonormalized(), model.global_position)
	visible = model.is_visible_in_tree()
	var head_position := model.global_position + global_basis.y * 1.60
	if is_instance_valid(_head_skeleton) and _head_bone >= 0:
		head_position = (_head_skeleton.global_transform * _head_skeleton.get_bone_global_pose(_head_bone)).origin
	_ears.global_position = head_position
	# Head tracking rotates the ears along with the character's face.
	_ears.global_basis = (_head_skeleton.global_transform * _head_skeleton.get_bone_global_pose(_head_bone)).basis.orthonormalized() if is_instance_valid(_head_skeleton) and _head_bone >= 0 else global_basis

## Closed tapered tube with analytic curve tangents and a stable radial frame.
## Only built on activation; the flowing chakra is animated by the aura shader.
static func _tube(a: Vector3, b: Vector3, c: Vector3, d: Vector3, radius: float, material: Material) -> MeshInstance3D:
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
		var width := radius * pow(1.0 - t, 0.65) * (1.0 + sin(t * PI) * 0.40)
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
