shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
#include "res://shaders/atlas_tiled.gdshaderinc"

void fragment() {
	vec4 c = atlas_sample(UV) * COLOR;
	ALBEDO = c.rgb;
	ROUGHNESS = 0.9;
}
