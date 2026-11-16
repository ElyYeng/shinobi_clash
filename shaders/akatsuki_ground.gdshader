shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// UE5-style "texture variation" for the ground: breaks tiling by blending two differently
// rotated / scaled samples of the same texture with a world-space noise mask, adds macro
// light/dark + dry-yellow patches, and mixes in a second texture (dirt) where the noise says so.
uniform sampler2D tex_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_b : source_color, filter_linear_mipmap, repeat_enable;   // dirt / patch texture
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float use_b : hint_range(0.0, 1.0) = 0.0;   // how much of tex_b patches in
uniform float macro_scale = 0.004;     // size of the big light/dark areas (per metre)
uniform float detail_scale = 0.015;    // size of the patches
uniform float variation = 0.22;        // brightness variation strength
uniform vec3 dry_color = vec3(1.18, 1.05, 0.7);
uniform float dry_amount = 0.5;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 rot(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	float n_macro = texture(noise, wpos.xz * macro_scale).r;
	float n_det = texture(noise, wpos.xz * detail_scale + 0.37).r;
	float n_fine = texture(noise, wpos.xz * detail_scale * 3.1 + 0.71).r;
	// anti-tiling: a second, rotated + rescaled sample fades in over the first
	vec3 c1 = texture(tex_a, uv).rgb;
	vec3 c2 = texture(tex_a, rot(uv, 0.9) * 0.73 + 0.31).rgb;
	vec3 col = mix(c1, c2, smoothstep(0.38, 0.62, n_macro));
	// dirt patches
	if (use_b > 0.0) {
		vec3 d = texture(tex_b, uv * 0.8).rgb;
		col = mix(col, d, smoothstep(0.62, 0.7, n_det) * use_b);
	}
	// macro variation: lighter / darker areas, dry-yellow patches
	col *= 1.0 + (n_macro - 0.5) * 2.0 * variation + (n_fine - 0.5) * variation * 0.5;
	col = mix(col, col * dry_color, smoothstep(0.55, 0.8, n_det) * dry_amount);
	ALBEDO = col * tint.rgb;
	ROUGHNESS = 1.0;
}

void light() {   // cel-style: one hard light step, like the toon shader on the rest of the map
	float l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(0.38, 1.0, step(0.3, l));
}
