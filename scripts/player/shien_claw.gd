class_name ShienClaw
extends BoneAttachment3D
## Violet Calamity Form 1: a procedural violet flame wrapped round the forearm and fist attached to the shinobi's left hand.
## The whole effect is generated from meshes, so it needs no extra texture or model asset.

const OUTER := Color("#7627D8")
const VIOLET := Color("#B45BFF")
const HOT := Color("#E7C7FF")

var _model: Node3D
var _aura: AuraShell
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
	skeleton.add_child(claw)
	claw.bone_name = str(skeleton.get_bone_name(hand_idx))
	claw._model = model
	var drv := ShienFlameIdle.attach(model)   # the claw arm from the Flame Idle clip, in aura material
	if drv != null:
		drv.set_claw(true)
	claw._aura = AuraShell.make(claw, model, OUTER, HOT, 0.4, 0.05)   # Form 1: a stronger violet aura over the body
	return claw

static func _clean_bone_name(value: String) -> String:
	return value.to_lower().replace("mixamorig:", "").replace("mixamorig_", "").replace("_", "").replace(" ", "")

static func _aura_material(col: Color, rim: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/aura.gdshader")
	m.set_shader_parameter("_NoiseTex", AuraShell.noise())
	m.set_shader_parameter("_ColorAura", col)
	m.set_shader_parameter("_ColorRim", rim)
	m.set_shader_parameter("_RimPower2", 2.2)
	m.set_shader_parameter("_Scale", 0.035)
	m.set_shader_parameter("_SpeedY", 4.0)
	m.set_shader_parameter("_Brightness", 0.8)
	m.set_shader_parameter("_Opacity", 3.0)
	m.set_shader_parameter("_OutlineFixed", 0.8)
	m.set_shader_parameter("_OffsetFade", 10.0)
	return m

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

func _exit_tree() -> void:
	if is_instance_valid(_model):
		var drv := _model.get_node_or_null("ShienFlameIdle") as ShienFlameIdle
		if drv != null:
			drv.set_claw(false)
