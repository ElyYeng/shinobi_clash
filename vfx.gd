class_name Vfx
extends RefCounted
## Visual-quality toolbox: procedural sky, post-processing, particles, glow, grass, lanterns, camera shake.
## Everything is generated in code - no extra art assets needed.

## Old built-in sky (fallback only; the real one is res://shaders/sky.gdshader).
const SKY_SHADER := """shader_type sky;
uniform vec3 top_color : source_color = vec3(0.2, 0.45, 0.9);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.85, 0.95);
uniform vec3 ground_color : source_color = vec3(0.3, 0.33, 0.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.6, 0.65, 0.78);
uniform vec3 sun_dir = vec3(0.0, 0.5, 0.8);
uniform float cloud_cover = 0.55;
uniform float star_amount = 0.0;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.5));
	} else {
		col = mix(horizon_color, ground_color, pow(clamp(-h * 4.0, 0.0, 1.0), 0.6));
	}
	vec3 sd3 = normalize(sun_dir);
	float sd = max(dot(d, sd3), 0.0);
	// warm glow around the sun and a hard disc
	col += sun_color * (pow(sd, 8.0) * 0.28 + pow(sd, 64.0) * 0.45);
	col += sun_color * smoothstep(0.9985, 0.9995, sd) * 6.0;
	if (star_amount > 0.0 && h > 0.0) {
		vec2 sp = d.xz / (h + 0.2) * 60.0;
		float s = step(0.985, h21(floor(sp)));
		col += vec3(s) * star_amount * smoothstep(0.0, 0.3, h);
	}
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.14) * 1.15;
		float n = fbm2(uv);
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.3, n);
		float n2 = fbm2(uv + sd3.xz * 0.15);
		float shade = clamp(0.55 + (n - n2) * 4.0, 0.0, 1.0);
		vec3 cc = mix(cloud_shadow, cloud_color, shade);
		cc += sun_color * pow(sd, 6.0) * 0.25;
		float fade = smoothstep(0.0, 0.2, h);
		col = mix(col, cc, c * fade * 0.92);
	}
	COLOR = col;
}
"""

const GROUND_SHADER := """shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec3 color_a : source_color = vec3(0.28, 0.5, 0.2);
uniform vec3 color_b : source_color = vec3(0.45, 0.68, 0.27);
uniform vec3 color_c : source_color = vec3(0.6, 0.5, 0.33);
uniform float tile = 1.0;
uniform float patchiness = 0.5;
varying vec3 wpos;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(11.3, 5.7);
		a *= 0.5;
	}
	return v;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz * tile;
	float big = fbm2(p * 0.06);
	float mid = fbm2(p * 0.35 + 3.0);
	float fine = vnoise(p * 5.0);
	vec3 c = mix(color_a, color_b, smoothstep(0.3, 0.7, big));
	c = mix(c, color_c, smoothstep(0.6, 0.85, fbm2(p * 0.11 + 9.0)) * patchiness);
	c *= 0.84 + 0.26 * mid;
	c *= 0.93 + 0.14 * fine;
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""

const GRASS_SHADER := """shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform vec3 base_color : source_color = vec3(0.12, 0.32, 0.1);
uniform vec3 tip_color : source_color = vec3(0.55, 0.8, 0.3);
uniform float wind = 0.22;
varying vec3 tint;
void vertex() {
	tint = COLOR.rgb;
	float h = UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 1.7 + wp.x * 0.55 + wp.z * 0.35);
	float s2 = cos(TIME * 1.2 + wp.x * 0.3 - wp.z * 0.5);
	VERTEX.x += s * wind * h * h;
	VERTEX.z += s2 * wind * 0.6 * h * h;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	ALBEDO = mix(base_color, tip_color, UV.y) * tint;
	ROUGHNESS = 1.0;
}
"""

const FLOWER_SHADER := """shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
varying vec3 tint;
void vertex() {
	tint = COLOR.rgb;
	float h = UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX.x += sin(TIME * 1.6 + wp.x * 0.5 + wp.z * 0.4) * 0.08 * h;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	float head = step(0.6, UV.y);
	ALBEDO = mix(vec3(0.16, 0.45, 0.12), tint, head);
	EMISSION = tint * head * 0.35;
	ROUGHNESS = 1.0;
}
"""

static var _glow_tex: GradientTexture2D = null
static var _quad: QuadMesh = null
static var _shrink: Curve = null

# ---------------------------------------------------------------- shared resources
static func glow_tex() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow_tex = t
	return _glow_tex

static func quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(1, 1)
	return _quad

static func shrink_curve() -> Curve:
	if _shrink == null:
		_shrink = Curve.new()
		_shrink.add_point(Vector2(0.0, 1.0))
		_shrink.add_point(Vector2(1.0, 0.0))
	return _shrink

static func particle_mat(additive := true, boost := 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = glow_tex()
	m.albedo_color = Color(boost, boost, boost, 1.0)
	m.no_depth_test = false
	return m

static func _fade_ramp(start_alpha := 1.0) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, start_alpha), Color(1, 1, 1, start_alpha * 0.7), Color(1, 1, 1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	return g

static func _free_later(node: Node, secs: float) -> void:
	if node.is_inside_tree():
		node.get_tree().create_timer(secs).timeout.connect(node.queue_free)

# ---------------------------------------------------------------- one-shot effects
## Radial burst of glowing sparks.
static func burst(parent: Node, pos: Vector3, color: Color, amount := 24, speed := 6.0, size := 0.3, life := 0.7, gravity := -9.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.local_coords = false
	p.mesh = quad()
	p.material_override = particle_mat(true, 1.8)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = speed * 0.4
	p.damping_max = speed * 0.9
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.scale_amount_curve = shrink_curve()
	p.color = Color(color.r, color.g, color.b, 1.0)
	p.color_ramp = _fade_ramp()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_later(p, life + 0.4)

## Soft, slowly rising smoke.
static func smoke(parent: Node, pos: Vector3, color: Color, size := 2.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 10
	p.lifetime = 1.3
	p.explosiveness = 0.9
	p.local_coords = false
	p.mesh = quad()
	p.material_override = particle_mat(false, 1.0)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = size * 0.3
	p.initial_velocity_max = size * 0.9
	p.gravity = Vector3(0, 0.8, 0)
	p.damping_min = size * 0.4
	p.damping_max = size * 0.7
	p.scale_amount_min = size * 0.45
	p.scale_amount_max = size * 0.9
	var dark := Color(color.r * 0.45 + 0.12, color.g * 0.45 + 0.12, color.b * 0.45 + 0.12, 0.55)
	p.color = dark
	p.color_ramp = _fade_ramp()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_later(p, 1.8)

## Short-lived point-light flash that lights the surroundings.
static func flash(parent: Node, pos: Vector3, color: Color, energy := 4.0, light_range := 8.0, secs := 0.25) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := OmniLight3D.new()
	l.light_color = Color(color.r, color.g, color.b, 1.0)
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, secs)
	t.tween_callback(l.queue_free)

## Expanding ground ring (additive glow).
static func shockwave(parent: Node, pos: Vector3, color: Color, radius := 8.0, secs := 0.5) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.88
	tm.outer_radius = 1.0
	tm.rings = 40
	tm.ring_segments = 6
	m.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.85)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = Vector3(pos.x, maxf(pos.y, 0.0) + 0.25, pos.z)
	m.scale = Vector3(0.3, 0.12, 0.3)
	var t := m.create_tween().set_parallel(true)
	t.tween_property(m, "scale", Vector3(radius, radius * 0.1, radius), secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, secs)
	t.chain().tween_callback(m.queue_free)

## The standard hit / poof effect used by Fx.puff: glow core + sparks + light (+ smoke + shockwave when big).
static func hit(parent: Node, pos: Vector3, color: Color, size := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var c := Color(color.r, color.g, color.b, 1.0)
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 16
	s.rings = 8
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, 0.9)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * 0.2 * size
	var t := m.create_tween().set_parallel(true)
	t.tween_property(m, "scale", Vector3.ONE * size * 1.3, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	t.chain().tween_callback(m.queue_free)
	burst(parent, pos, c, clampi(int(10.0 + size * 8.0), 10, 70), 4.0 + size * 2.5, 0.12 + size * 0.04, 0.45 + size * 0.08)
	flash(parent, pos, c, clampf(1.5 + size * 1.2, 1.5, 12.0), clampf(3.0 + size * 3.0, 4.0, 26.0), 0.22)
	if size >= 1.8:
		smoke(parent, pos, c, size)
	if size >= 3.0:
		shockwave(parent, Vector3(pos.x, 0.0, pos.z), c, size * 1.6, 0.45)

## Small dust puff for footsteps / landings.
static func dust(parent: Node, pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 4
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.local_coords = false
	p.mesh = quad()
	p.material_override = particle_mat(false, 1.0)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.3
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	p.color = Color(0.85, 0.78, 0.65, 0.45)
	p.color_ramp = _fade_ramp()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos + Vector3(0, 0.1, 0)
	p.emitting = true
	_free_later(p, 1.0)

## Floating combat number.
static func damage_number(parent: Node, pos: Vector3, amount: float, color := Color(1.0, 0.92, 0.35)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = str(int(round(amount)))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.font_size = 72
	l.pixel_size = 0.0055 * clampf(0.6 + amount / 30.0, 0.8, 2.2)
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0.1, 0.02, 0.0, 1.0)
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y + 1.8, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.5)
	t.chain().tween_callback(l.queue_free)

## Camera shake that decays (works on any Camera3D).
static func shake(cam: Camera3D, strength := 0.15, secs := 0.3) -> void:
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	var t := cam.create_tween()
	t.tween_method(_shake_step.bind(cam), strength, 0.0, secs)
	t.tween_callback(_shake_step.bind(0.0, cam))

static func _shake_step(v: float, cam: Camera3D) -> void:
	if not is_instance_valid(cam):
		return
	cam.h_offset = randf_range(-v, v)
	cam.v_offset = randf_range(-v, v)

# ---------------------------------------------------------------- attached / ambient effects
## Glowing trail that follows a moving node (projectiles).
static func trail(node: Node3D, color: Color, size := 0.3, amount := 28, life := 0.4) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.mesh = quad()
	p.material_override = particle_mat(true, 1.8)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, 1.0, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.scale_amount_curve = shrink_curve()
	p.color = Color(color.r, color.g, color.b, 1.0)
	p.color_ramp = _fade_ramp()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(p)

## Point light that travels with a node.
static func glow_light(node: Node3D, color: Color, energy := 1.5, light_range := 6.0, offset := Vector3.ZERO) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(color.r, color.g, color.b, 1.0)
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = false
	l.position = offset
	node.add_child(l)
	return l

## Upward-licking flames / energy around a spot (Kurama's chakra, etc.).
## soft = true: small, dimmer flames that don't blow out to white (player modes seen up close).
static func aura_flames(node: Node3D, offset: Vector3, radius: float, color: Color, amount := 80, soft := false) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.mesh = quad()
	p.material_override = particle_mat(true, 0.9 if soft else 1.7)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = radius * 0.6
	p.initial_velocity_max = radius * 1.4
	p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = radius * (0.14 if soft else 0.25)
	p.scale_amount_max = radius * (0.3 if soft else 0.55)
	p.scale_amount_curve = shrink_curve()
	var g := Gradient.new()
	var hot := Color(color.lightened(0.25), 0.4) if soft else Color(1.0, 0.95, 0.6, 0.9)
	g.colors = PackedColorArray([hot, Color(color, 0.55 if soft else 1.0), Color(color.r * 0.4, color.g * 0.1, color.b * 0.1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = offset
	node.add_child(p)

## Big area of drifting ambient particles. kind: "embers", "petals", "fireflies".
static func ambient(parent: Node, kind: String, center: Vector3, extents: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.mesh = quad()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var g := Gradient.new()
	match kind:
		"embers":
			p.amount = 380
			p.lifetime = 7.0
			p.preprocess = 7.0
			p.direction = Vector3.UP
			p.spread = 30.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 5.5
			p.gravity = Vector3(0.8, 0.5, 0.2)
			p.scale_amount_min = 0.07
			p.scale_amount_max = 0.22
			p.material_override = particle_mat(true, 2.2)
			g.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.5, 0.12, 1.0), Color(0.8, 0.12, 0.04, 0.0)])
			g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		"petals":
			p.amount = 170
			p.lifetime = 14.0
			p.preprocess = 14.0
			p.direction = Vector3(0.4, -1.0, 0.15)
			p.spread = 25.0
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.9
			p.gravity = Vector3(0.25, -0.45, 0.05)
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -120.0
			p.angular_velocity_max = 120.0
			p.scale_amount_min = 0.09
			p.scale_amount_max = 0.17
			var pm := StandardMaterial3D.new()
			pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			pm.vertex_color_use_as_albedo = true
			pm.cull_mode = BaseMaterial3D.CULL_DISABLED
			p.material_override = pm
			g.colors = PackedColorArray([Color(1.0, 0.72, 0.82, 1.0), Color(1.0, 0.82, 0.9, 1.0), Color(1.0, 0.72, 0.82, 1.0)])
			g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		_:
			p.amount = 110
			p.lifetime = 8.0
			p.preprocess = 8.0
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = 0.15
			p.initial_velocity_max = 0.6
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.1
			p.scale_amount_max = 0.2
			p.material_override = particle_mat(true, 3.0)
			g.colors = PackedColorArray([Color(1.0, 0.95, 0.5, 0.0), Color(1.0, 0.92, 0.45, 1.0), Color(1.0, 0.9, 0.4, 0.0)])
			g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = g
	p.position = center
	parent.add_child(p)
	p.emitting = true

# ---------------------------------------------------------------- terrain helpers
static func ground_mat(a: Color, b: Color, c: Color, scale := 1.0, patchiness := 0.5) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("color_c", c)
	m.set_shader_parameter("tile", scale)
	m.set_shader_parameter("patchiness", patchiness)
	return m

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(Vector3.UP)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(Vector3.UP)
	st.set_uv(uc)
	st.add_vertex(c)

static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades := 5
	for i in blades:
		var a := TAU * float(i) / float(blades) + float(i) * 0.7
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-dir.z, 0.0, dir.x) * 0.05
		var off := dir * 0.07
		var lean := dir * 0.13
		var h := 0.5 + 0.13 * float(i % 3)
		_tri(st, off - side, off + side, off + lean + Vector3(0, h, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1))
	return st.commit()

static func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.38
	# stem (two thin triangles), UV.y < 0.6 -> green
	_tri(st, Vector3(-0.015, 0, 0), Vector3(0.015, 0, 0), Vector3(0, h, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.5))
	_tri(st, Vector3(0, 0, -0.015), Vector3(0, 0, 0.015), Vector3(0, h, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.5))
	# head: flat six-point star, UV.y = 0.9 -> flower colour
	for i in 6:
		var a0 := TAU * float(i) / 6.0
		var a1 := TAU * float(i + 1) / 6.0
		var c := Vector3(0, h, 0)
		_tri(st, c, c + Vector3(cos(a0), 0.0, sin(a0)) * 0.1, c + Vector3(cos(a1), 0.0, sin(a1)) * 0.1, Vector2(0.5, 0.9), Vector2(0.5, 0.9), Vector2(0.5, 0.9))
	return st.commit()

## Scatters thousands of swaying grass tufts. `keep` is a Callable(Vector3) -> bool that rejects blocked spots.
static func grass(parent: Node, count: int, half: float, seed_v: int, keep: Callable, base: Color, tip: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var tries := 0
	while xf.size() < count and tries < count * 3:
		tries += 1
		var p := Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		if keep.is_valid() and not bool(keep.call(p)):
			continue
		var s := rng.randf_range(0.75, 1.5)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.7), s))
		xf.append(Transform3D(b, p))
		var v := rng.randf_range(0.78, 1.15)
		cols.append(Color(v, v * rng.randf_range(0.95, 1.08), v * rng.randf_range(0.8, 1.0), 1.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tuft_mesh()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var sh := Shader.new()
	sh.code = GRASS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("tip_color", tip)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

## Scatters little glowing flowers in several colours.
static func flowers(parent: Node, count: int, half: float, seed_v: int, keep: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var palette := [Color(1.0, 0.9, 0.95), Color(1.0, 0.85, 0.25), Color(1.0, 0.45, 0.6), Color(0.65, 0.55, 1.0), Color(1.0, 0.6, 0.3)]
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var tries := 0
	while xf.size() < count and tries < count * 3:
		tries += 1
		# clustered in patches
		var cx := floorf(rng.randf_range(-half, half) / 9.0) * 9.0
		var cz := floorf(rng.randf_range(-half, half) / 9.0) * 9.0
		var p := Vector3(cx + rng.randf_range(-3.5, 3.5), 0.0, cz + rng.randf_range(-3.5, 3.5))
		if keep.is_valid() and not bool(keep.call(p)):
			continue
		var s := rng.randf_range(0.8, 1.5)
		xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
		cols.append(palette[int(absf(sin(cx * 12.9898 + cz * 78.233) * 43758.5)) % palette.size()])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _flower_mesh()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var sh := Shader.new()
	sh.code = FLOWER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

## Glowing lava-like cracks across the floor (Kurama arena).
static func lava_cracks(parent: Node, radius: float, count: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.04)
	mat.emission_energy_multiplier = 3.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(6.0, radius)
		var pos := Vector3(cos(a) * r, 0.05, sin(a) * r)
		var seg_len := rng.randf_range(3.0, 11.0)
		var w := rng.randf_range(0.12, 0.45)
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, 0.02, seg_len)
		m.mesh = bm
		m.material_override = mat
		m.position = pos
		m.rotation.y = a + rng.randf_range(-0.9, 0.9)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(m)
		if i % 6 == 0:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.4, 0.1)
			l.light_energy = 1.6
			l.omni_range = 9.0
			l.shadow_enabled = false
			l.position = pos + Vector3(0, 0.8, 0)
			parent.add_child(l)

# ---------------------------------------------------------------- props
static func _emissive(col: Color, energy := 3.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	return mat

## Wooden post with a glowing paper lantern and a real warm light.
static func lantern(parent: Node, pos: Vector3, height := 2.9) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.1
	post.height = height
	root.add_child(Fx._part(post, Color(0.38, 0.24, 0.14), Vector3(0, height / 2.0, 0)))
	var arm := BoxMesh.new()
	arm.size = Vector3(0.6, 0.08, 0.08)
	root.add_child(Fx._part(arm, Color(0.38, 0.24, 0.14), Vector3(0.28, height - 0.1, 0), false))
	var body := SphereMesh.new()
	body.radius = 0.26
	body.height = 0.62
	var lamp := MeshInstance3D.new()
	lamp.mesh = body
	lamp.material_override = _emissive(Color(1.0, 0.58, 0.22), 3.2)
	lamp.position = Vector3(0.55, height - 0.4, 0)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lamp)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.65, 0.35)
	l.light_energy = 1.5
	l.omni_range = 11.0
	l.shadow_enabled = false
	l.position = Vector3(0.55, height - 0.4, 0)
	root.add_child(l)

## Japanese stone lantern with a glowing firebox.
static func stone_lantern(parent: Node, pos: Vector3) -> void:
	var stone := Color(0.62, 0.6, 0.57)
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var base := CylinderMesh.new()
	base.top_radius = 0.3
	base.bottom_radius = 0.38
	base.height = 0.3
	root.add_child(Fx._part(base, stone, Vector3(0, 0.15, 0)))
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.13
	shaft.bottom_radius = 0.16
	shaft.height = 0.8
	root.add_child(Fx._part(shaft, stone, Vector3(0, 0.7, 0)))
	var plate := BoxMesh.new()
	plate.size = Vector3(0.62, 0.1, 0.62)
	root.add_child(Fx._part(plate, stone, Vector3(0, 1.15, 0)))
	var fire := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.36, 0.36, 0.36)
	fire.mesh = fb
	fire.material_override = _emissive(Color(1.0, 0.6, 0.25), 3.5)
	fire.position = Vector3(0, 1.4, 0)
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fire)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.02
	cap.bottom_radius = 0.5
	cap.height = 0.34
	cap.radial_segments = 4
	var capmi := Fx._part(cap, stone.darkened(0.1), Vector3(0, 1.78, 0))
	capmi.rotation.y = PI / 4.0
	root.add_child(capmi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.65, 0.3)
	l.light_energy = 1.3
	l.omni_range = 8.0
	l.shadow_enabled = false
	l.position = Vector3(0, 1.4, 0)
	root.add_child(l)

## Big red torii gate.
static func torii(parent: Node, pos: Vector3, width := 6.4, height := 6.2) -> void:
	var red := Color(0.8, 0.14, 0.1)
	var black := Color(0.12, 0.1, 0.1)
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	for x in [-width / 2.0, width / 2.0]:
		var pm := CylinderMesh.new()
		pm.top_radius = 0.36
		pm.bottom_radius = 0.44
		pm.height = height
		pm.radial_segments = 14
		root.add_child(Fx._part(pm, red, Vector3(x, height / 2.0, 0)))
		var foot := CylinderMesh.new()
		foot.top_radius = 0.5
		foot.bottom_radius = 0.5
		foot.height = 0.35
		root.add_child(Fx._part(foot, black, Vector3(x, 0.17, 0)))
	var top := BoxMesh.new()
	top.size = Vector3(width + 2.4, 0.5, 0.7)
	root.add_child(Fx._part(top, black, Vector3(0, height + 0.25, 0)))
	var top2 := BoxMesh.new()
	top2.size = Vector3(width + 1.6, 0.35, 0.55)
	root.add_child(Fx._part(top2, red, Vector3(0, height - 0.12, 0)))
	var tie := BoxMesh.new()
	tie.size = Vector3(width + 0.2, 0.3, 0.4)
	root.add_child(Fx._part(tie, red, Vector3(0, height - 1.3, 0)))
	var plaque := BoxMesh.new()
	plaque.size = Vector3(0.9, 1.0, 0.3)
	root.add_child(Fx._part(plaque, black, Vector3(0, height - 0.75, 0), false))

static func bush(parent: Node, pos: Vector3, rng: RandomNumberGenerator, flowering := false) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var base := Color(0.17, 0.42, 0.18).lerp(Color(0.3, 0.55, 0.2), rng.randf())
	for i in 3:
		var sm := SphereMesh.new()
		var r := rng.randf_range(0.45, 0.8)
		sm.radius = r
		sm.height = r * 1.5
		sm.radial_segments = 10
		sm.rings = 5
		var col := base
		if flowering and i == 0:
			col = Color(1.0, 0.65, 0.78).lerp(Color(1.0, 0.82, 0.88), rng.randf())
		root.add_child(Fx._part(sm, col, Vector3(rng.randf_range(-0.5, 0.5), r * 0.5, rng.randf_range(-0.5, 0.5))))

# ---------------------------------------------------------------- environment / sky / post-processing
static func _preset(style: String) -> Dictionary:
	match style:
		"sunset":
			return {
				"top": Color(0.12, 0.17, 0.46), "horizon": Color(1.0, 0.56, 0.3), "ground": Color(0.35, 0.22, 0.2),
				"cloud": Color(1.0, 0.68, 0.48), "cloud_shadow": Color(0.32, 0.24, 0.45), "cover": 0.6,
				"sun": Color(1.0, 0.64, 0.34), "sun_energy": 1.7, "fill": Color(0.45, 0.55, 1.0), "fill_energy": 0.35,
				"ambient": 0.6, "fog": Color(1.0, 0.64, 0.45), "fog_density": 0.0028, "vol": 0.014,
				"glow": 0.9, "sat": 1.18, "contrast": 1.08, "stars": 0.25,
			}
		"inferno":
			return {
				"top": Color(0.1, 0.015, 0.04), "horizon": Color(0.95, 0.28, 0.08), "ground": Color(0.2, 0.06, 0.04),
				"cloud": Color(0.75, 0.2, 0.1), "cloud_shadow": Color(0.1, 0.02, 0.03), "cover": 0.7,
				"sun": Color(1.0, 0.5, 0.25), "sun_energy": 1.5, "fill": Color(0.9, 0.2, 0.1), "fill_energy": 0.5,
				"ambient": 0.5, "fog": Color(0.5, 0.12, 0.07), "fog_density": 0.006, "vol": 0.02,
				"glow": 1.1, "sat": 1.1, "contrast": 1.12, "stars": 0.0,
			}
		_:
			return {
				"top": Color(0.14, 0.4, 0.88), "horizon": Color(0.74, 0.86, 0.97), "ground": Color(0.36, 0.42, 0.36),
				"cloud": Color(1.0, 1.0, 1.0), "cloud_shadow": Color(0.62, 0.68, 0.82), "cover": 0.56,
				"sun": Color(1.0, 0.93, 0.78), "sun_energy": 1.5, "fill": Color(0.5, 0.62, 1.0), "fill_energy": 0.25,
				"ambient": 0.75, "fog": Color(0.72, 0.82, 0.92), "fog_density": 0.0015, "vol": 0.005,
				"glow": 0.7, "sat": 1.15, "contrast": 1.08, "stars": 0.0,
			}

## Builds sky, fog, glow, SSAO, colour grading and the sun/fill lights. style: "day", "sunset" or "inferno".
static func build_environment(parent: Node, style: String, sun_rot_deg: Vector3, shadow_dist: float) -> void:
	var c := _preset(style)
	var sun_basis := Basis.from_euler(sun_rot_deg * (PI / 180.0))
	var toward_sun := sun_basis.z

	var sh := load("res://shaders/sky.gdshader") as Shader   # shared with the maps' skies
	if sh == null:
		sh = Shader.new()
		sh.code = SKY_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("top_color", c["top"])
	sm.set_shader_parameter("horizon_color", c["horizon"])
	sm.set_shader_parameter("ground_color", c["ground"])
	sm.set_shader_parameter("sun_color", c["sun"])
	sm.set_shader_parameter("cloud_color", c["cloud"])
	sm.set_shader_parameter("cloud_shadow", c["cloud_shadow"])
	sm.set_shader_parameter("cloud_cover", c["cover"])
	sm.set_shader_parameter("star_amount", c["stars"])
	sm.set_shader_parameter("sun_dir", toward_sun)
	var sky := Sky.new()
	sky.sky_material = sm

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = c["ambient"]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = c["glow"]
	env.glow_strength = 1.1
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssao_light_affect = 0.35
	env.fog_enabled = true
	env.fog_light_color = c["fog"]
	env.fog_density = c["fog_density"]
	env.fog_sky_affect = 0.3
	env.fog_aerial_perspective = 0.35
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = c["vol"]
	env.volumetric_fog_albedo = c["fog"]
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_anisotropy = 0.7
	env.adjustment_enabled = true
	env.adjustment_contrast = c["contrast"]
	env.adjustment_saturation = c["sat"]
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot_deg
	sun.light_energy = c["sun_energy"]
	sun.light_color = c["sun"]
	sun.light_angular_distance = 0.6
	sun.light_volumetric_fog_energy = 1.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = shadow_dist
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	parent.add_child(sun)

	# Cool fill light from the opposite side gives the toon models a nice rim and keeps shadows from going flat black
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, sun_rot_deg.y + 180.0, 0.0)
	fill.light_energy = c["fill_energy"]
	fill.light_color = c["fill"]
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.0
	parent.add_child(fill)
