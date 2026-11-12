class_name CharToon
extends RefCounted
## Ultimate Toon Source "stylized" shader on characters and maps. Every surface gets a
## copy of the shader with the settings below plus its own colour / texture. Eyes (unshaded) and
## glowing power-up materials (emission) keep their own materials.
## Settings match the material set up in the editor: 1 hard step, black shadow tint at 0.4.

const SHADER := "res://assets/UltimateToonSource/shader/stylized.gdshader"
const PARAMS := {
	"use_stepped": true, "steps": 1.0, "step_smoothness": 0.0,
	"shadow_tint": Color(0, 0, 0, 1), "shadow_tint_amount": 0.4,
	"use_pattern": false,   # TODO: copy the Pattern settings once that material is pushed
}
static var _shaders := {}

## The stylized shader, adjusted in memory (the file stays as it is): colour texture read as sRGB
## (else colours come out pale), the source material's UV scale / offset (map models use 16x UVs),
## and a double-sided copy for double-sided materials (leaves, cloth on the map).
static func _get_shader(two_sided: bool) -> Shader:
	if not _shaders.has(two_sided):
		var code := (load(SHADER) as Shader).code
		code = code.replace("uniform sampler2D albedo_texture;",
			"uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;\nuniform vec3 uv1_scale = vec3(1.0);\nuniform vec3 uv1_offset = vec3(0.0);")
		code = code.replace("void vertex() {", "void vertex() {\n\tUV = UV * uv1_scale.xy + uv1_offset.xy;")
		# hard step on the light angle only; cast shadows (soft, grainy edges from tall objects)
		# fade in smoothly instead of being snapped into dither
		code = code.replace("float ndotl = clamp(dot(NORMAL,LIGHT),0.0,1.0) * ATTENUATION;",
			"float ndotl = clamp(dot(NORMAL,LIGHT),0.0,1.0);")
		code = code.replace("vec3 diffuse = vec3(pow(light, 1.0)) * (LIGHT_COLOR / PI);",
			"light *= smoothstep(0.1, 0.9, ATTENUATION);\n\tvec3 diffuse = vec3(pow(light, 1.0)) * (LIGHT_COLOR / PI);")
		if two_sided:
			code = code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode cull_disabled;")
		var sh := Shader.new()
		sh.code = code
		_shaders[two_sided] = sh
	return _shaders[two_sided]

static func material_for(src: Material) -> Material:
	if not (src is BaseMaterial3D):
		return src
	var b := src as BaseMaterial3D
	if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or b.emission_enabled:
		return src
	if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:   # see-through / cut-out: keep
		return src
	var nm := b.resource_name.to_lower()
	if nm.ends_with("eye") or nm.ends_with(" eye"):   # eyes keep their own material (eye colour, iris)
		return src
	var two_sided := b.cull_mode == BaseMaterial3D.CULL_DISABLED
	var sm: ShaderMaterial = b.get_meta("char_toon") if b.has_meta("char_toon") else null
	if sm == null:
		sm = ShaderMaterial.new()
		sm.shader = _get_shader(two_sided)
		for k in PARAMS:
			sm.set_shader_parameter(k, PARAMS[k])
	# refreshed every time: colours set on the source later (skin colour) show up
	sm.set_shader_parameter("albedo_color", b.albedo_color)
	sm.set_shader_parameter("albedo_texture", b.albedo_texture if b.albedo_texture != null else _white())
	sm.set_shader_parameter("uv1_scale", b.uv1_scale)
	sm.set_shader_parameter("uv1_offset", b.uv1_offset)
	b.set_meta("char_toon", sm)
	return sm

static var _white_tex: Texture2D
static func _white() -> Texture2D:
	if _white_tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex

## Converts every surface under `model` (characters after any look change; maps on load).
static func apply(model: Node3D) -> void:
	if model == null:
		return
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m == null:
				continue
			var t := material_for(m)
			if t != m:
				mi.set_surface_override_material(s, t)
