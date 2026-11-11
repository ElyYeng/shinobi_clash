// Anime ink outlines for the whole screen (Forward+). Edges are found where depth jumps
// (silhouettes) or surface normals turn sharply (creases), then drawn as dark lines that fade
// out with distance. Added by Main (AnimePost.add_to) on a full-screen quad.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 line_color : source_color = vec4(0.07, 0.05, 0.07, 1.0);
uniform float thickness : hint_range(0.5, 3.0) = 1.0;      // pixels
uniform float depth_edge : hint_range(0.01, 0.5) = 0.06;   // relative depth jump that makes a line
uniform float normal_edge : hint_range(0.05, 1.0) = 0.4;   // normal change that makes a line
uniform float fade_start = 25.0;                            // metres: lines fade out ...
uniform float fade_end = 110.0;                             // ... until here
uniform float strength : hint_range(0.0, 1.0) = 0.85;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);   // full-screen quad
}

float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d = view_depth(uv, INV_PROJECTION_MATRIX);
	vec3 n = view_normal(uv);
	float edge = 0.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		float dn = view_depth(uv + offs[i], INV_PROJECTION_MATRIX);
		// only the nearer side of a silhouette draws the line (keeps lines 1 px wide)
		if (dn - d > d * depth_edge) {
			edge = 1.0;
		}
		if (d < 1000.0 && 1.0 - dot(n, view_normal(uv + offs[i])) > normal_edge) {
			edge = max(edge, 0.8);
		}
	}
	float fade = 1.0 - smoothstep(fade_start, fade_end, d);
	ALBEDO = line_color.rgb;
	ALPHA = edge * fade * strength;
}
