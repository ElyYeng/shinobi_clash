class_name ShienClaw
extends BoneAttachment3D
## Violet Calamity Form 1: a procedural violet flame wrapped round the forearm and fist attached to the shinobi's left hand.
## The whole effect is generated from meshes, so it needs no extra texture or model asset.

const OUTER := Color("#7627D8")
const VIOLET := Color("#B45BFF")
const HOT := Color("#E7C7FF")

var _grip: Node3D
var _embers: Array[MeshInstance3D] = []
var _ember_origins: Array[Vector3] = []
var _flames: Array[Node3D] = []
var _flame_phase: Array[float] = []
var _time := 0.0

## Attach to the left hand (screen-right in a front-facing character shot).
## Falls back to the right hand on rigs that do not have a left-hand bone.
static func attach(model: Node3D) -> ShienClaw:
	if not is_instance_valid(model):
		return null
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_warning("[ShienClaw] Character model has no Skeleton3D.")
		return null
	var skeleton := skeletons[0] as Skeleton3D
	var hand_idx := -1
	var hand_side := "left"
	for i in skeleton.get_bone_count():
		var bone := _clean_bone_name(str(skeleton.get_bone_name(i)))
		if bone == "lefthand":
			hand_idx = i
			break
	if hand_idx < 0:
		hand_side = "right"
		for i in skeleton.get_bone_count():
			if _clean_bone_name(str(skeleton.get_bone_name(i))) == "righthand":
				hand_idx = i
				break
	if hand_idx < 0:
		push_warning("[ShienClaw] Could not find a left- or right-hand bone on the character rig.")
		return null

	var claw := ShienClaw.new()
	claw.name = "ShienVioletClaw"
	claw._build(skeleton, hand_idx, hand_side)
	skeleton.add_child(claw)
	claw.bone_name = str(skeleton.get_bone_name(hand_idx))
	return claw

static func _clean_bone_name(value: String) -> String:
	return value.to_lower().replace("mixamorig:", "").replace("mixamorig_", "").replace("_", "").replace(" ", "")

func _build(skeleton: Skeleton3D, hand_idx: int, side: String) -> void:
	var hand_rest := skeleton.get_bone_global_rest(hand_idx)
	var finger_direction := Vector3.ZERO
	for i in skeleton.get_bone_count():
		var bone := _clean_bone_name(str(skeleton.get_bone_name(i)))
		if bone.begins_with(side + "hand") and (bone.contains("middle") or bone.contains("index") or bone.contains("ring")):
			var delta: Vector3 = skeleton.get_bone_global_rest(i).origin - hand_rest.origin
			finger_direction = hand_rest.basis.inverse() * delta
			if finger_direction.length_squared() > 0.0001:
				break
	if finger_direction.length_squared() < 0.0001:
		finger_direction = Vector3(0.0, 0.0, -1.0)
	finger_direction = finger_direction.normalized()
	var up := Vector3.UP
	if absf(finger_direction.dot(up)) > 0.92:
		up = Vector3.RIGHT

	_grip = Node3D.new()
	_grip.name = "VioletClawGeometry"
	_grip.basis = Basis.looking_at(finger_direction, up)
	add_child(_grip)

	var outer := _material(OUTER, 0.62, 2.6)
	var violet := _material(VIOLET, 0.8, 3.6)
	var hot := _material(HOT, 0.9, 4.6)

	# Violet flame wrapped round the forearm and fist (the grip's -Z points along the fingers, +Z back up the arm).
	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.16
	glow_mesh.height = 0.32
	glow_mesh.radial_segments = 14
	glow_mesh.rings = 8
	glow.mesh = glow_mesh
	glow.scale = Vector3(1.0, 0.9, 1.3)
	glow.position = Vector3(0.0, 0.0, -0.06)
	glow.material_override = outer
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grip.add_child(glow)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Ragged flame sleeve: tongues start on a ring round the forearm and lick toward the fingers.
	for i in 22:
		var z := rng.randf_range(0.02, 0.42)
		var ang := rng.randf() * TAU
		var ring := 0.085 + z * 0.06
		var base := Vector3(cos(ang) * ring, sin(ang) * ring, z)
		var out := Vector3(cos(ang), sin(ang), 0.0)
		var len := rng.randf_range(0.16, 0.34)
		var curl := rng.randf_range(0.5, 1.0)
		var pts: Array[Vector3] = [
			Vector3.ZERO,
			out * 0.035 + Vector3(0, 0, -len * 0.3),
			out * 0.075 * curl + Vector3(0, 0, -len * 0.65) + Vector3(0, 0.02, 0),
			out * 0.06 * curl + Vector3(0, 0.05, -len)
		]
		var w := rng.randf_range(0.032, 0.05)
		_add_flame(base, pts, [w, w * 0.8, w * 0.4, 0.001], outer if i % 3 != 0 else violet, rng)
	# Long wisps streaming off the fist and past the fingertips, hot cores inside.
	for i in 9:
		var ang := float(i) / 9.0 * TAU + rng.randf_range(-0.2, 0.2)
		var base := Vector3(cos(ang) * 0.09, sin(ang) * 0.09, rng.randf_range(-0.12, 0.0))
		var out := Vector3(cos(ang), sin(ang), 0.0)
		var len := rng.randf_range(0.3, 0.5)
		var pts: Array[Vector3] = [
			Vector3.ZERO,
			out * 0.06 + Vector3(0, 0.02, -len * 0.3),
			out * 0.11 + Vector3(0, 0.07, -len * 0.65),
			out * 0.07 + Vector3(0, 0.15, -len)
		]
		_add_flame(base, pts, [0.05, 0.04, 0.02, 0.001], violet, rng)
		var core: Array[Vector3] = []
		for q in pts:
			core.append(q * 0.8)
		_add_flame(base, core, [0.02, 0.016, 0.008, 0.0006], hot, rng)

	# Small moving sparks keep the aura alive while the hand follows its animation.
	for i in 7:
		var spark := MeshInstance3D.new()
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.018 if i % 2 == 0 else 0.024
		spark_mesh.height = spark_mesh.radius * 2.0
		spark_mesh.radial_segments = 7
		spark_mesh.rings = 4
		spark.mesh = spark_mesh
		spark.material_override = hot if i % 3 == 0 else violet
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_grip.add_child(spark)
		_embers.append(spark)
		_ember_origins.append(Vector3(cos(float(i) * TAU / 7.0) * 0.17, sin(float(i) * TAU / 7.0) * 0.13, 0.03 + float(i % 3) * 0.09))
		spark.position = _ember_origins[-1]

## One flame tongue: a tapering tube on its own pivot at `base`, so it can sway from its root.
func _add_flame(base: Vector3, pts: Array[Vector3], radii: Array[float], mat: Material, rng: RandomNumberGenerator) -> void:
	var pivot := Node3D.new()
	pivot.position = base
	_grip.add_child(pivot)
	_add_tube(pivot, pts, radii, mat, 6)
	_flames.append(pivot)
	_flame_phase.append(rng.randf() * TAU)

func _process(delta: float) -> void:
	_time += delta
	for i in _flames.size():
		if is_instance_valid(_flames[i]):
			var f := _time * 7.0 + _flame_phase[i]
			_flames[i].rotation = Vector3(sin(f) * 0.12, cos(f * 0.8) * 0.12, 0.0)
			_flames[i].scale = Vector3.ONE * (1.0 + sin(f * 1.3) * 0.12)
	for i in _embers.size():
		if is_instance_valid(_embers[i]):
			var angle := _time * (1.2 + float(i) * 0.12) + float(i) * TAU / 7.0
			_embers[i].position = _ember_origins[i] + Vector3(cos(angle) * 0.035, sin(angle * 1.3) * 0.04, sin(angle) * 0.045)

static func _material(col: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	return mat

static func _add_tube(parent: Node3D, points: Array[Vector3], radii: Array[float], material: Material, sides := 7) -> void:
	if points.size() < 2 or points.size() != radii.size():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var tangent := (points[i + 1] - points[i]).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.001:
			side = tangent.cross(Vector3.RIGHT).normalized()
		var up := side.cross(tangent).normalized()
		var tangent_next := tangent
		if i + 2 < points.size():
			tangent_next = (points[i + 2] - points[i + 1]).normalized()
		var side_next := tangent_next.cross(Vector3.UP).normalized()
		if side_next.length_squared() < 0.001:
			side_next = tangent_next.cross(Vector3.RIGHT).normalized()
		var up_next := side_next.cross(tangent_next).normalized()
		for j in sides:
			var a0 := TAU * float(j) / float(sides)
			var a1 := TAU * float(j + 1) / float(sides)
			var n00 := side * cos(a0) + up * sin(a0)
			var n01 := side * cos(a1) + up * sin(a1)
			var n10 := side_next * cos(a0) + up_next * sin(a0)
			var n11 := side_next * cos(a1) + up_next * sin(a1)
			var p00 := points[i] + n00 * radii[i]
			var p01 := points[i] + n01 * radii[i]
			var p10 := points[i + 1] + n10 * radii[i + 1]
			var p11 := points[i + 1] + n11 * radii[i + 1]
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p10)
			st.add_vertex(p01)
			st.add_vertex(p11)
			st.add_vertex(p10)
	st.generate_normals()
	var mesh := st.commit()
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
