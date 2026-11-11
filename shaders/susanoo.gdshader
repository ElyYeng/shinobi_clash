shader_type spatial;
// Susanoo chakra body: translucent, glowing in the player's Susanoo colour, brighter at the
// silhouette (fresnel), the model's texture kept as detail. Values above 1 feed the bloom.
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(0.55, 0.25, 1.0, 1.0);
uniform sampler2D detail : source_color, filter_linear_mipmap;
uniform float intensity = 1.6;
uniform float fade : hint_range(0.0, 1.0) = 1.0;   // 0 = invisible (forming / dismissing)

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	vec3 t = texture(detail, UV).rgb;
	float lum = dot(t, vec3(0.299, 0.587, 0.114));
	float pulse = 0.92 + 0.08 * sin(TIME * 3.0 + UV.y * 12.0);
	ALBEDO = color.rgb * (0.55 + lum * 0.9) * intensity * pulse + color.rgb * fres * 2.2;
	ALPHA = clamp(0.42 + fres * 0.65 + lum * 0.15, 0.0, 0.96) * fade;
}
