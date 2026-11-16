class_name ShienClaw
extends BoneAttachment3D
## Violet Calamity Form 2: a procedural aura claw attached to the shinobi's left hand.
## The whole effect is generated from meshes, so it needs no extra texture or model asset.

const OUTER := Color("#7627D8")
const VIOLET := Color("#B45BFF")
const HOT := Color("#E7C7FF")

var _grip: Node3D
var _embers: Array[MeshInstance3D] = []
var _ember_origins: Array[Vector3] = []
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

	var outer := _material(OUTER, 0.78, 2.8)
	var violet := _material(VIOLET, 0.88, 4.0)
	var hot := _material(HOT, 0.95, 5.0)

	# A glowing palm and wrist cuff make the claw read as part of the arm, not a floating weapon.
	var palm := MeshInstance3D.new()
	var palm_mesh := SphereMesh.new()
	palm_mesh.radius = 0.145
	palm_mesh.height = 0.29
	palm_mesh.radial_segments = 14
	palm_mesh.rings = 8
	palm.mesh = palm_mesh
	palm.scale = Vector3(1.12, 0.82, 1.45)
	palm.position = Vector3(0.0, -0.015, -0.075)
	palm.material_override = outer
	palm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grip.add_child(palm)

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.095
	core_mesh.height = 0.19
	core_mesh.radial_segments = 12
	core_mesh.rings = 7
	core.mesh = core_mesh
	core.scale = Vector3(1.0, 0.76, 1.45)
	core.position = Vector3(0.0, 0.025, -0.13)
	core.material_override = violet
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grip.add_child(core)

	var cuff := MeshInstance3D.new()
	var cuff_mesh := TorusMesh.new()
	cuff_mesh.inner_radius = 0.105
	cuff_mesh.outer_radius = 0.145
	cuff.mesh = cuff_mesh
	cuff.position = Vector3(0.0, 0.0, 0.105)
	cuff.rotation.x = PI * 0.5
	cuff.material_override = hot
	cuff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grip.add_child(cuff)

	# Four long talons fan out from the palm. Each has a bright inner flame edge.
	for i in 4:
		var x := lerpf(-0.105, 0.105, float(i) / 3.0)
		var length := [0.53, 0.66, 0.62, 0.50][i]
		var spread := (float(i) - 1.5) * 0.035
		var points: Array[Vector3] = [
			Vector3(x, -0.015, -0.115),
			Vector3(x * 1.22, 0.015, -0.25),
			Vector3(x * 1.52 + spread, 0.075, -length * 0.72),
			Vector3(x * 1.8 + spread * 1.5, 0.12, -length)
		]
		_add_tube(_grip, points, [0.061, 0.052, 0.027, 0.0015], outer, 7)
		var inner_points: Array[Vector3] = []
		for point in points:
			inner_points.append(point + Vector3(0.0, 0.012, 0.0))
		_add_tube(_grip, inner_points, [0.027, 0.023, 0.012, 0.0008], violet, 6)

	# The thumb sweeps outward like a hooked claw.
	var thumb: Array[Vector3] = [
		Vector3(0.12, -0.025, -0.035),
		Vector3(0.205, 0.015, -0.13),
		Vector3(0.265, 0.075, -0.27),
		Vector3(0.235, 0.14, -0.43)
	]
	_add_tube(_grip, thumb, [0.07, 0.058, 0.029, 0.001], outer, 7)
	var thumb_core: Array[Vector3] = []
	for point in thumb:
		thumb_core.append(point + Vector3(0.0, 0.012, 0.0))
	_add_tube(_grip, thumb_core, [0.029, 0.022, 0.012, 0.0008], hot, 6)

	# Violet flame tongues crawl back over the forearm from the wrist.
	var flame_paths: Array = [
		[Vector3(-0.10, 0.015, 0.025), Vector3(-0.17, 0.08, 0.16), Vector3(-0.13, 0.17, 0.31), Vector3(-0.035, 0.23, 0.43)],
		[Vector3(0.075, 0.005, 0.035), Vector3(0.15, 0.075, 0.17), Vector3(0.12, 0.19, 0.29), Vector3(0.04, 0.25, 0.39)],
		[Vector3(-0.025, -0.075, 0.04), Vector3(-0.07, -0.13, 0.19), Vector3(-0.02, -0.17, 0.32), Vector3(0.065, -0.12, 0.42)],
		[Vector3(0.12, -0.035, 0.03), Vector3(0.19, 0.015, 0.13), Vector3(0.22, 0.10, 0.24), Vector3(0.16, 0.18, 0.34)]
	]
	for i in flame_paths.size():
		var path: Array[Vector3] = []
		for point in flame_paths[i]:
			path.append(point)
		_add_tube(_grip, path, [0.075, 0.062, 0.034, 0.001], outer if i % 2 == 0 else violet, 7)

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

func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(_grip):
		var pulse := 1.0 + sin(_time * 6.0) * 0.025
		_grip.scale = Vector3.ONE * pulse
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
