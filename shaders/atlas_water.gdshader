shader_type spatial;
render_mode cull_disabled, diffuse_burley, depth_draw_opaque;
#include "res://shaders/atlas_tiled.gdshaderinc"
uniform vec2 flow = vec2(0.03, 0.015);   // water textures slide slowly

void fragment() {
	vec4 c = atlas_sample(UV + flow * TIME) * COLOR;
	ALBEDO = c.rgb;
	ALPHA = clamp(c.a, 0.0, 0.92);
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
