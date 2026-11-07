class_name Fx
extends RefCounted
## Shared helpers: input map, placeholder ninja model, effects.

static func setup_inputs() -> void:
	_key("forward", [KEY_W]); _key("back", [KEY_S])
	_key("left", [KEY_A]); _key("right", [KEY_D])
	_key("jump", [KEY_SPACE]); _key("sprint", [KEY_SHIFT])
	_key("dash", [KEY_Q]); _key("fire", [KEY_R])
	_key("clone", [KEY_F]); _key("charge", [KEY_C])
	_key("lockon", [KEY_TAB, KEY_N]); _key("restart", [KEY_ENTER])
	_key("pause", [KEY_ESCAPE])
	_key("ability", [KEY_X]); _key("spin_menu", [KEY_B])
	_key("to_menu", [KEY_M]); _key("interact", [KEY_E])
	_key("jutsu_t", [KEY_T]); _key("jutsu_y", [KEY_Y]); _key("jutsu_g", [KEY_G]); _key("jutsu_h", [KEY_H])
	_key("biju", [KEY_Z]); _key("substitute", [KEY_V]); _key("volley", [KEY_E]); _key("quest_log", [KEY_L])
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_mouse("kunai", MOUSE_BUTTON_RIGHT)
	_mouse("lockon", MOUSE_BUTTON_MIDDLE)

static func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k as Key
		if not InputMap.action_has_event(action, e):
			InputMap.action_add_event(action, e)

static func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventMouseButton.new()
	e.button_index = button as MouseButton
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)

static var _mats := {}
static var _outline: ShaderMaterial = null

## Cel-shaded material, cached per colour (fewer materials = cheaper rendering).
static func toon_mat(col: Color, outline := true) -> StandardMaterial3D:
	var key := "%s%s" % [col.to_html(), outline]
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		toonify(mat, outline)
		_mats[key] = mat
	return _mats[key]

static func toonify(mat: StandardMaterial3D, outline := true) -> void:
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.85
	if outline:
		mat.next_pass = outline_mat()

## Inverted-hull outline with constant on-screen width (works at any model scale).
static func outline_mat() -> ShaderMaterial:
	if _outline == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 1.6;
void vertex() {
	vec4 c = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 o = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	if (length(o) > 0.0001) { c.xy += normalize(o) / VIEWPORT_SIZE * width * 2.0 * c.w; }
	POSITION = c;
}
void fragment() { ALBEDO = vec3(0.06, 0.04, 0.05); }
"""
		_outline = ShaderMaterial.new()
		_outline.shader = sh
	return _outline

## Converts every material on an imported model to cel shading + outline.
static func toonify_model(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var key := "m%d" % mi.mesh.surface_get_material(i).get_instance_id() if mi.mesh.surface_get_material(i) else ""
			if key == "" or not mi.mesh.surface_get_material(i) is StandardMaterial3D:
				continue
			if not _mats.has(key):
				var m := mi.mesh.surface_get_material(i).duplicate() as StandardMaterial3D
				toonify(m)
				_mats[key] = m
			mi.set_surface_override_material(i, _mats[key])

static func _part(mesh: Mesh, col: Color, pos: Vector3, outline := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = toon_mat(col, outline)
	m.position = pos
	return m

static func _glow(col: Color, energy := 2.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	return mat

## Placeholder ninja made of primitives. Replace with your own rigged model.
static func make_ninja(body_col: Color, band_col: Color, eye_col := Color(0.08, 0.08, 0.1)) -> Node3D:
	var root := Node3D.new()
	var skin := Color(0.96, 0.8, 0.65)
	var dark := Color(0.12, 0.12, 0.16)
	var cap := CapsuleMesh.new(); cap.radius = 0.32; cap.height = 1.0
	root.add_child(_part(cap, body_col, Vector3(0, 1.05, 0)))
	var belt := CylinderMesh.new()
	belt.top_radius = 0.34; belt.bottom_radius = 0.34; belt.height = 0.12
	root.add_child(_part(belt, band_col, Vector3(0, 0.82, 0), false))
	var head := SphereMesh.new(); head.radius = 0.26; head.height = 0.52
	root.add_child(_part(head, skin, Vector3(0, 1.72, 0)))
	var band := CylinderMesh.new()
	band.top_radius = 0.28; band.bottom_radius = 0.28; band.height = 0.1
	root.add_child(_part(band, band_col, Vector3(0, 1.8, 0)))
	var hair := CylinderMesh.new()
	hair.top_radius = 0.0; hair.bottom_radius = 0.3; hair.height = 0.3
	root.add_child(_part(hair, Color(0.9, 0.75, 0.2), Vector3(0, 2.0, 0)))
	# face: two eyes (glow when eye_col is bright)
	var eye := SphereMesh.new(); eye.radius = 0.045; eye.height = 0.09
	var emat := _glow(eye_col, 3.0 if eye_col.get_luminance() > 0.2 else 0.0)
	for ex in [-0.1, 0.1]:
		var em := MeshInstance3D.new()
		em.mesh = eye
		em.material_override = emat
		em.position = Vector3(ex, 1.74, -0.235)
		root.add_child(em)
	var leg := BoxMesh.new(); leg.size = Vector3(0.22, 0.5, 0.22)
	root.add_child(_part(leg, dark, Vector3(-0.15, 0.25, 0)))
	root.add_child(_part(leg, dark, Vector3(0.15, 0.25, 0)))
	var boot := BoxMesh.new(); boot.size = Vector3(0.25, 0.12, 0.34)
	root.add_child(_part(boot, band_col.darkened(0.3), Vector3(-0.15, 0.06, -0.04), false))
	root.add_child(_part(boot, band_col.darkened(0.3), Vector3(0.15, 0.06, -0.04), false))
	var arm_mesh := BoxMesh.new(); arm_mesh.size = Vector3(0.14, 0.55, 0.14)
	root.add_child(_part(arm_mesh, body_col, Vector3(-0.42, 1.08, 0)))
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(0.42, 1.35, 0)
	arm.add_child(_part(arm_mesh, body_col, Vector3(0, -0.27, 0)))
	var glove := BoxMesh.new(); glove.size = Vector3(0.17, 0.14, 0.17)
	arm.add_child(_part(glove, dark, Vector3(0, -0.58, 0), false))
	root.add_child(arm)
	return root

static func swing(arm: Node3D) -> void:
	if arm == null:
		return
	var t := arm.create_tween()
	arm.rotation.x = -1.0
	t.tween_property(arm, "rotation:x", 1.7, 0.1)
	t.tween_property(arm, "rotation:x", 0.0, 0.2)

static func puff(parent: Node, pos: Vector3, color: Color, size := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	Vfx.hit(parent, pos, color, size)
