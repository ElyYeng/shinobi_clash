class_name CharToon
extends RefCounted
## Ultimate Toon Source "stylized" shader on characters and maps. Every surface gets a
## copy of the shader with the settings below plus its own colour / texture (and glow: power-up
## looks like Kurama Ink Mode keep the hard cel shading under their emission). Eyes keep their own.
## Settings match the material set up in the editor: 1 hard step, black shadow tint at 0.4.

const SHADER := "res://assets/UltimateToonSource/shader/stylized.gdshader"
const PARAMS := {
	"use_stepped": true, "steps": 1.0, "step_smoothness": 0.0,
	"shadow_tint": Color(0, 0, 0, 1), "shadow_tint_amount": 0.4,
	"use_pattern": false,   # TODO: copy the Pattern settings once that material is pushed
}
## Glow under toon shading: a bit less than the standard material's, so the shadow side still
## reads (else a glowing body is one flat colour).
const GLOW_SCALE := 0.8
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
		# hard cel light: the light angle and cast shadows each get a hard cut (the sun's shadows
		# are hard too - no soft-shadow blur, so there's no grain to turn into dither)
		code = code.replace("float ndotl = clamp(dot(NORMAL,LIGHT),0.0,1.0) * ATTENUATION;",
			"float ndotl = clamp(dot(NORMAL,LIGHT),0.0,1.0);")
		code = code.replace("vec3 diffuse = vec3(pow(light, 1.0)) * (LIGHT_COLOR / PI);",
			"light *= step(0.5, ATTENUATION);\n\tvec3 diffuse = vec3(pow(light, 1.0)) * (LIGHT_COLOR / PI);")
		# glow on top of the cel shading (power-up looks, lanterns): emission colour x mask x energy
		code = code.replace("void fragment() {",
			"uniform vec4 emission_color : source_color = vec4(0.0);\nuniform sampler2D emission_texture : source_color, filter_linear_mipmap, repeat_enable;\nuniform float emission_energy = 0.0;\nvoid fragment() {")
		code = code.replace("ALBEDO = albedo.rgb;",
			"ALBEDO = albedo.rgb;\n\tEMISSION = emission_color.rgb * texture(emission_texture, UV).rgb * emission_energy;")
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
	if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
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
	if b.emission_enabled:
		sm.set_shader_parameter("emission_color", b.emission)
		sm.set_shader_parameter("emission_texture", b.emission_texture if b.emission_texture != null else _white())
		sm.set_shader_parameter("emission_energy", b.emission_energy_multiplier * GLOW_SCALE)
	else:
		sm.set_shader_parameter("emission_energy", 0.0)
		sm.set_shader_parameter("emission_texture", _white())
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
