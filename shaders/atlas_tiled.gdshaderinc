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

// ---- cel shading (anime look): hard light / shadow bands instead of smooth shading.
uniform float cel_bands : hint_range(1.0, 4.0) = 2.0;          // tones between shadow and light
uniform float cel_softness : hint_range(0.0, 0.2) = 0.03;      // width of the band edges
uniform vec4 cel_shadow_tint : source_color = vec4(0.78, 0.8, 0.95, 1.0);   // shadows lean cool
uniform float cel_rim : hint_range(0.0, 1.0) = 0.12;           // thin bright rim on edges facing the light

float cel_step(float x) {
	float b = max(cel_bands, 1.0);
	float s = x * b;
	float f = floor(s);
	return (f + smoothstep(0.5 - cel_softness * b, 0.5 + cel_softness * b, fract(s) - 0.0) ) / b;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float shade = min(ndl, smoothstep(0.3, 0.5, ATTENUATION));   // cast shadows join the bands
	float lit = cel_step(shade);
	vec3 tint = mix(cel_shadow_tint.rgb, vec3(1.0), lit);
	DIFFUSE_LIGHT += LIGHT_COLOR * tint * lit / PI;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * ndl;
	DIFFUSE_LIGHT += LIGHT_COLOR * step(0.5, rim) * cel_rim / PI;
}
