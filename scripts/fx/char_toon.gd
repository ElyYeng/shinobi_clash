class_name CharToon
extends RefCounted
## Ultimate Toon Source "stylized" shader on characters (Hero models only). Every surface gets a
## copy of the shader with the settings below plus its own colour / texture. Eyes (unshaded) and
## glowing power-up materials (emission) keep their own materials.
## Settings match the material set up in the editor: 1 hard step, black shadow tint at 0.4.

const SHADER := "res://assets/UltimateToonSource/shader/stylized.gdshader"
const PARAMS := {
	"use_stepped": true, "steps": 1.0, "step_smoothness": 0.0,
	"shadow_tint": Color(0, 0, 0, 1), "shadow_tint_amount": 0.4,
	"use_pattern": false,   # TODO: copy the Pattern settings once that material is pushed
}
static var _shader: Shader

static func material_for(src: Material) -> Material:
	if not (src is BaseMaterial3D):
		return src
	var b := src as BaseMaterial3D
	if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or b.emission_enabled:
		return src
	if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		return src
	var nm := b.resource_name.to_lower()
	if nm.ends_with("eye") or nm.ends_with(" eye"):   # eyes keep their own material (eye colour, iris)
		return src
	if b.has_meta("char_toon"):
		return b.get_meta("char_toon")
	if _shader == null:
		# Same shader, but the colour texture is read as a colour image (sRGB) - without that hint
		# Godot treats it as raw data and every colour comes out pale and grey.
		_shader = Shader.new()
		_shader.code = (load(SHADER) as Shader).code.replace("uniform sampler2D albedo_texture;",
			"uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;")
	var sm := ShaderMaterial.new()
	sm.shader = _shader
	for k in PARAMS:
		sm.set_shader_parameter(k, PARAMS[k])
	sm.set_shader_parameter("albedo_color", b.albedo_color)
	if b.albedo_texture != null:
		sm.set_shader_parameter("albedo_texture", b.albedo_texture)
	else:
		sm.set_shader_parameter("albedo_texture", _white())
	b.set_meta("char_toon", sm)
	return sm

static var _white_tex: Texture2D
static func _white() -> Texture2D:
	if _white_tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex

## Converts every surface of a character model (call after any look change).
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
