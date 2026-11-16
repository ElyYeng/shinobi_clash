shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// UE5-style "texture variation" for the ground: breaks tiling by blending two differently
// rotated / scaled samples of the same texture with a world-space noise mask, adds macro
// light/dark + dry-yellow patches, and mixes in a second texture (dirt) where the noise says so.
uniform sampler2D tex_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_b : source_color, filter_linear_mipmap, repeat_enable;   // dirt / patch texture
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tex_scale = 0.12;   // world-space tiling (1 / metres per tile): no UV stretching, no seams between surfaces
uniform float use_b : hint_range(0.0, 1.0) = 0.0;   // how much of tex_b patches in
uniform float macro_scale = 0.004;     // size of the big light/dark areas (per metre)
uniform float detail_scale = 0.015;    // size of the patches
uniform float variation = 0.22;        // brightness variation strength
uniform vec3 dry_color = vec3(1.18, 1.05, 0.7);
uniform float dry_amount = 0.5;
uniform float tri_sharpness = 4.0;     // how fast the projections hand over on slopes (higher = tighter blend)
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Triplanar weights: how much each projection (side X, top Y, side Z) faces the surface.
vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(normalize(n)), vec3(tri_sharpness));
	return w / max(w.x + w.y + w.z, 1e-4);
}

vec2 rot(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Triplanar sample: projects from the top on flat ground and from the sides on slopes / cliffs,
// so the texture never gets smeared down a steep face (the old top-down wpos.xz projection did).
// a / o rotate + offset each plane's UV (the anti-tiling variant).
vec3 tri_rgb(sampler2D t, vec3 p, vec3 w, float a, vec2 o) {
	vec3 c = vec3(0.0);
	c += texture(t, rot(p.zy, a) + o).rgb * w.x;
	c += texture(t, rot(p.xz, a) + o).rgb * w.y;
	c += texture(t, rot(p.xy, a) + o).rgb * w.z;
	return c;
}

float tri_r(sampler2D t, vec3 p, vec3 w, vec2 o) {
	return texture(t, p.zy + o).r * w.x + texture(t, p.xz + o).r * w.y + texture(t, p.xy + o).r * w.z;
}

void fragment() {
	vec3 w = tri_w(wnrm);
	vec3 p = wpos * tex_scale;
	float n_macro = tri_r(noise, wpos * macro_scale, w, vec2(0.0));
	float n_det = tri_r(noise, wpos * detail_scale, w, vec2(0.37));
	float n_fine = tri_r(noise, wpos * detail_scale * 3.1, w, vec2(0.71));
	// anti-tiling: a second, rotated + rescaled sample fades in over the first
	vec3 c1 = tri_rgb(tex_a, p, w, 0.0, vec2(0.0));
	vec3 c2 = tri_rgb(tex_a, p * 0.73, w, 0.9, vec2(0.31));
	vec3 col = mix(c1, c2, smoothstep(0.38, 0.62, n_macro));
	// dirt patches
	if (use_b > 0.0) {
		vec3 d = tri_rgb(tex_b, p * 0.8, w, 0.0, vec2(0.0));
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
