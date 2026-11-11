// Shared by the merged-map shaders (atlas_opaque / atlas_cutout / atlas_water).
// Every vertex carries its texture's region in the atlas in CUSTOM0 (x, y, w, h). The original
// UVs can go past 0..1 (tiling), so they're wrapped with fract() INSIDE that region; textureGrad
// with the unwrapped UV derivatives keeps mipmaps from flickering at the wrap seams.
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float max_lod = 4.0;   // limits how far mipmaps blur neighbouring regions into each other
varying vec4 region;

void vertex() {
	region = CUSTOM0;
}

vec4 atlas_sample(vec2 uv) {
	vec2 t = fract(uv);
	vec2 a = region.xy + t * region.zw;
	vec2 dx = dFdx(uv) * region.zw;
	vec2 dy = dFdy(uv) * region.zw;
	float scale = exp2(max_lod);
	float len = max(length(dx), length(dy)) * float(textureSize(atlas, 0).x);
	if (len > scale) {   // clamp the mip level so far-away tiles don't bleed
		dx *= scale / len;
		dy *= scale / len;
	}
	return textureGrad(atlas, a, dx, dy);
}
