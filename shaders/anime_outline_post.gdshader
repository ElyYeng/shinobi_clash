// Anime ink outlines for the whole screen (Forward+), added by Main (AnimePost.add_to) on a
// full-screen quad. Edges are found where depth jumps (silhouettes) or surface normals turn
// sharply (creases), checked in 8 directions and anti-aliased. The ink is a dark version of the
// colour underneath (dark red on red cloth, deep green on leaves) like hand-inked cels, lines are
// thicker up close and thinner far away, and fade out in the distance.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec4 line_color : source_color = vec4(0.06, 0.04, 0.07, 1.0);
uniform float ink_from_surface : hint_range(0.0, 1.0) = 0.45;   // 0 = flat line_color, 1 = darkened surface colour
uniform float ink_darkness : hint_range(0.0, 1.0) = 0.12;       // how dark the surface-coloured ink is
uniform float thickness_near : hint_range(0.5, 4.0) = 2.0;      // pixels, close up
uniform float thickness_far : hint_range(0.5, 3.0) = 1.0;       // pixels, far away
uniform float depth_edge : hint_range(0.01, 0.5) = 0.05;        // relative depth jump that makes a line
uniform float normal_edge : hint_range(0.05, 1.0) = 0.35;       // normal change that makes a line
uniform float fade_start = 30.0;                                 // metres: lines fade out ...
uniform float fade_end = 120.0;                                  // ... until here
uniform float strength : hint_range(0.0, 1.0) = 1.0;

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
	vec2 uv = SCREEN_UV;
	float d = view_depth(uv, INV_PROJECTION_MATRIX);
	vec3 n = view_normal(uv);
	float t = mix(thickness_near, thickness_far, smoothstep(4.0, 40.0, d));
	vec2 px = t / VIEWPORT_SIZE;
	float edge = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 o = vec2(cos(a), sin(a)) * px;
		float dn = view_depth(uv + o, INV_PROJECTION_MATRIX);
		// silhouettes: only the nearer side draws, strength grows with the size of the jump
		edge = max(edge, smoothstep(d * depth_edge, d * depth_edge * 2.5, dn - d));
		if (d < 1000.0) {
			float crease = 1.0 - dot(n, view_normal(uv + o));
			edge = max(edge, smoothstep(normal_edge, normal_edge * 1.8, crease) * 0.85);
		}
	}
	float fade = 1.0 - smoothstep(fade_start, fade_end, d);
	vec3 under = texture(screen_tex, uv).rgb;
	vec3 ink = mix(line_color.rgb, under * ink_darkness, ink_from_surface);
	ALBEDO = ink;
	ALPHA = edge * fade * strength;
}
