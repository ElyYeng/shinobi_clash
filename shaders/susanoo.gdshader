shader_type spatial;
// Susanoo chakra body: translucent, glowing in the player's Susanoo colour, with chakra fire -
// two layers of seamless noise scrolling upward through the body (anchored to it, so the flames
// ride along with the punches), hot cores, wispy flickering edges and a bright silhouette.
// Values above 1 feed the bloom.
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(0.55, 0.25, 1.0, 1.0);
uniform sampler2D detail : source_color, filter_linear_mipmap;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float intensity = 1.5;
uniform float fire_scale = 0.6;      // flame size (bigger = smaller flames)
uniform float fire_speed = 0.9;       // how fast the flames rise
uniform float fade : hint_range(0.0, 1.0) = 1.0;   // 0 = invisible (forming / dismissing)

varying vec3 opos;

void vertex() {
	opos = VERTEX;   // body-space position (after skinning): the fire sticks to the Susanoo
}

float fire_at(vec3 p, float sc, float spd, float off) {
	vec2 up = vec2(0.0, TIME * spd);
	vec2 st = vec2(sc, sc * 0.45);   // stretched upward: tall licks of flame
	float a = texture(noise, p.xy * st + up + vec2(off, 0.0)).r;
	float b = texture(noise, p.zy * st + up + vec2(0.0, off)).r;
	return mix(a, b, 0.5);
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	float lum = dot(texture(detail, UV).rgb, vec3(0.299, 0.587, 0.114));
	// big slow flames x small fast licks -> fire streaks
	float big = fire_at(opos, fire_scale, fire_speed, 0.0);
	float small = fire_at(opos, fire_scale * 2.7, fire_speed * 1.9, 0.43);
	float f = big * 0.65 + small * 0.55;
	float flame = smoothstep(0.4, 0.78, f);
	float core = smoothstep(0.7, 0.95, f);
	vec3 col = color.rgb * (0.28 + lum * 0.5) * intensity;
	col += color.rgb * flame * 2.6;                       // flame streaks
	col = mix(col, vec3(1.0) * intensity * 1.4, core * 0.45);   // white-hot cores
	col += color.rgb * fres * 2.0;                        // bright silhouette
	ALBEDO = col;
	// wispy edges: the silhouette burns away where the noise is low
	float wisp = mix(1.0, smoothstep(0.25, 0.6, f), fres);
	ALPHA = clamp((0.16 + flame * 0.6 + fres * 0.5 + lum * 0.08) * wisp, 0.0, 0.95) * fade;
}
