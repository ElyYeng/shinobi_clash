shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D chakra_noise : repeat_enable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float sway = 0.12;
uniform vec4 cloak_color : source_color = vec4(0.95, 0.095, 0.025, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.32, 0.06, 1.0);

void vertex() {
	// Root stays planted; the end undulates instead of rebuilding geometry every frame.
	float weight = UV.y * UV.y;
	VERTEX.x += sin(TIME * 2.1 - UV.y * 4.5) * sway * weight;
	VERTEX.z += sin(TIME * 1.6 - UV.y * 3.0) * sway * 0.45 * weight;
}

void fragment() {
	vec2 flow = vec2(UV.x * 2.0, UV.y * 3.0 - TIME * 0.32);
	float noise = texture(chakra_noise, flow).r;
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float bubbles = smoothstep(0.57, 0.72, noise);
	vec3 color = mix(cloak_color.rgb, rim_color.rgb, rim * 0.7);
	color *= 0.75 + noise * 0.35;
	ALBEDO = color;
	EMISSION = color * (0.35 + rim * 0.5);
	ALPHA = (0.24 + rim * 0.30 + bubbles * 0.13) * strength;
}
