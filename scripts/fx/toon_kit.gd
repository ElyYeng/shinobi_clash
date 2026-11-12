class_name ToonKit
extends RefCounted
## Swaps ordinary (StandardMaterial3D) materials for the anime cel shader (shaders/cel.gdshader).
## Maps only, once when they load (main.gd). Characters keep their standard materials: their
## ripped, layered clothing meshes blotch under a hard cel band (skin shows through); they get
## the anime look from the ink outlines (shaders/anime_outline_post.gdshader) instead.
## Off: M > Settings > Cel Shading (GameData.toon_shading; applies to newly loaded maps).

const SHADER := "res://shaders/cel.gdshader"
static var _variants := {}   # "two_sided|cutout" -> Shader

## The cel shader in the variant a material needs: double-sided (cull_disabled) and/or cut-out
## (alpha scissor - only then does the shader write ALPHA, which would otherwise make Godot
## treat it as transparent).
static func _get_shader(two_sided: bool, cutout: bool) -> Shader:
	var key := "%s|%s" % [two_sided, cutout]
	if not _variants.has(key):
		var code := (load(SHADER) as Shader).code
		if two_sided:
			code = code.replace("render_mode cull_back;", "render_mode cull_disabled;")
		if cutout:
			code = code.replace("//CUTOUT ", "")
		var sh := Shader.new()
		sh.code = code
		_variants[key] = sh
	return _variants[key]

static func enabled() -> bool:
	return GameData.toon_shading

## The toon version of `src` (cached on it), or `src` itself when it shouldn't be converted:
## unshaded (glowing eyes), blended transparency, or already a custom shader.
## soft = characters: their normals are uneven (ripped game models), so the light/shadow edge is
## softened and the shadow a bit lighter - a hard cut there turns into blotches.
static func material_for(src: Material, soft := false) -> Material:
	if not enabled() or not (src is BaseMaterial3D):
		return src
	var b := src as BaseMaterial3D
	if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return src
	if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		return src
	var meta := "toon_soft" if soft else "toon"
	var sm: ShaderMaterial = b.get_meta(meta) if b.has_meta(meta) else null
	if sm == null:
		sm = ShaderMaterial.new()
		b.set_meta(meta, sm)
		if soft:
			sm.set_shader_parameter("band_softness", 0.14)
			sm.set_shader_parameter("shadow_color", Color(0.56, 0.54, 0.72))
			sm.set_shader_parameter("terminator_strength", 0.08)
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
	# Characters draw one-sided: their clothes are double-sided meshes with overlapping layers,
	# and with hard cel light the layers' light / shadow disagree and blotch through each other.
	# Cut-out hair cards stay double-sided.
	sm.shader = _get_shader(b.cull_mode == BaseMaterial3D.CULL_DISABLED and (not soft or cut > 0.0), cut > 0.0)
	if b.emission_enabled:
		sm.set_shader_parameter("emission", b.emission)
		sm.set_shader_parameter("emission_texture", b.emission_texture)
		sm.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
	else:
		sm.set_shader_parameter("emission_energy", 0.0)
	return sm

## Converts every mesh under `root` (surface materials and material overrides).
static func toonify(root: Node, soft := false) -> void:
	if not enabled() or root == null:
		return
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		if mi.material_override != null:
			var t := material_for(mi.material_override, soft)
			if t != mi.material_override:
				mi.material_override = t
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m == null:
				continue
			var t := material_for(m, soft)
			if t != m:
				mi.set_surface_override_material(s, t)
