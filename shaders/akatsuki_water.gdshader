shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Animated river water for the Akatsuki map (world-space, so it flows the same on every polygon).
uniform sampler2D base_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform vec2 flow = vec2(0.05, 0.02);      // texture drift per second
uniform float tex_scale = 0.02;
uniform float wave_height = 0.35;
uniform float wave_speed = 1.2;
uniform float alpha = 0.85;
varying vec3 wpos;

float waves(vec2 p, float t) {
	return sin(p.x * 0.35 + t * wave_speed) * 0.5 + sin(p.y * 0.5 - t * wave_speed * 1.3) * 0.35 + sin((p.x + p.y) * 0.8 + t * wave_speed * 1.7) * 0.15;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += waves(wpos.xz, TIME) * wave_height;
}
void fragment() {
	vec2 uv = wpos.xz * tex_scale;
	vec3 a = texture(base_tex, uv + flow * TIME).rgb;
	vec3 b = texture(base_tex, uv * 1.7 - flow * TIME * 1.4 + 0.37).rgb;
	vec3 c = mix(a, b, 0.5) * tint.rgb;
	float e = 0.4;   // ripple normal from the wave field
	float hx = waves(wpos.xz + vec2(e, 0.0), TIME) - waves(wpos.xz - vec2(e, 0.0), TIME);
	float hz = waves(wpos.xz + vec2(0.0, e), TIME) - waves(wpos.xz - vec2(0.0, e), TIME);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(-hx, 0.0, -hz, 0.0)).xyz * wave_height * 1.5);
	float sparkle = smoothstep(0.82, 1.0, (a.r + b.g) * 0.6 + waves(wpos.xz * 2.0, TIME * 1.5) * 0.3);
	ALBEDO = c + sparkle * 0.25;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	ALPHA = alpha;
}
