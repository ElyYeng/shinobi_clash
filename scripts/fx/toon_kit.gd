class_name ToonKit
extends RefCounted
## Swaps ordinary (StandardMaterial3D) materials for the toon shader (shaders/toon.gdshader).
## Characters are converted by Hero after every look change; maps once when they load (main.gd).
## Off: M > Settings > Toon Shading (GameData.toon_shading; applies to newly loaded maps).

const SHADER := "res://shaders/toon.gdshader"
static var _shader: Shader

static func enabled() -> bool:
	return GameData.toon_shading

## The toon version of `src` (cached on it), or `src` itself when it shouldn't be converted:
## unshaded (glowing eyes), blended transparency, or already a custom shader.
static func material_for(src: Material) -> Material:
	if not enabled() or not (src is BaseMaterial3D):
		return src
	var b := src as BaseMaterial3D
	if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return src
	if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		return src
	var sm: ShaderMaterial = b.get_meta("toon") if b.has_meta("toon") else null
	if sm == null:
		if _shader == null:
			_shader = load(SHADER)
		sm = ShaderMaterial.new()
		sm.shader = _shader
		b.set_meta("toon", sm)
	sm.set_shader_parameter("albedo_color", b.albedo_color)
	sm.set_shader_parameter("albedo_texture", b.albedo_texture)
	sm.set_shader_parameter("uv1_scale", b.uv1_scale)
	sm.set_shader_parameter("uv1_offset", b.uv1_offset)
	sm.set_shader_parameter("use_vertex_color", b.vertex_color_use_as_albedo)
	var cut := 0.0
	if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		cut = b.alpha_scissor_threshold
	elif b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
		cut = 0.5
	sm.set_shader_parameter("alpha_scissor", cut)
	if b.emission_enabled:
		sm.set_shader_parameter("emission", b.emission)
		sm.set_shader_parameter("emission_texture", b.emission_texture)
		sm.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
	else:
		sm.set_shader_parameter("emission_energy", 0.0)
	return sm

## Converts every mesh under `root` (surface materials and material overrides).
static func toonify(root: Node) -> void:
	if not enabled() or root == null:
		return
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		if mi.material_override != null:
			var t := material_for(mi.material_override)
			if t != mi.material_override:
				mi.material_override = t
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m == null:
				continue
			var t := material_for(m)
			if t != m:
				mi.set_surface_override_material(s, t)
