shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
#include "res://shaders/atlas_tiled.gdshaderinc"
uniform float alpha_cut = 0.45;

void fragment() {
	vec4 c = atlas_sample(UV) * COLOR;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.9;
}
