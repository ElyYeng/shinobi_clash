shader_type spatial;
// Greybox material: flat colour + a world-space grid (thin line every 1 m, stronger every 4 m)
// so distances and heights are easy to read while blocking out a level.
render_mode diffuse_burley, specular_disabled;

uniform vec4 color : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform float grid_strength : hint_range(0.0, 1.0) = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid(vec2 p, float s, float w) {
	vec2 q = p / s;
	vec2 g = abs(fract(q - 0.5) - 0.5) / max(fwidth(q), vec2(1e-4));
	return 1.0 - min(min(g.x, g.y) / w, 1.0);
}

void fragment() {
	vec3 n = abs(wnrm);
	vec2 p = (n.y > n.x && n.y > n.z) ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy);
	float lines = grid(p, 1.0, 1.0) * 0.07 + grid(p, 4.0, 1.4) * 0.16;
	ALBEDO = color.rgb * (1.0 - lines * grid_strength);
	ROUGHNESS = 0.9;
}
