shader_type spatial;
// Anime cel shading for characters and map props (materials are converted by ToonKit,
// scripts/fx/toon_kit.gd). Two crisp tones per light - lit and shadow - with the shadow tinting
// the surface's own colour cool (not just darker), a thin warm "terminator" glow where light
// turns to shadow, a rim light on lit edges and a small hard highlight. Cast shadows fall into
// the same shadow tone. Edges are anti-aliased with fwidth so the band stays crisp, not jagged.
render_mode cull_back;   // ToonKit makes a double-sided copy for double-sided materials

group_uniforms Surface;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec3 uv1_scale = vec3(1.0);          // texture transform from the source material
uniform vec3 uv1_offset = vec3(0.0);
uniform bool use_vertex_color = false;
uniform float alpha_scissor = 0.0;           // > 0: cut out pixels below this alpha (hair cards)
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D emission_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float emission_energy = 0.0;

group_uniforms Cel;
uniform vec4 shadow_color : source_color = vec4(0.30, 0.29, 0.48, 1.0);   // multiplies the lit colour in shadow
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.48;             // half-lambert value where shadow starts
uniform float band_softness : hint_range(0.0, 0.2) = 0.015;
uniform vec4 terminator_color : source_color = vec4(1.0, 0.55, 0.45, 1.0);
uniform float terminator_strength : hint_range(0.0, 1.0) = 0.16;
uniform float terminator_width : hint_range(0.01, 0.3) = 0.07;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform float rim_width : hint_range(0.05, 0.6) = 0.22;
uniform float spec_strength : hint_range(0.0, 1.0) = 0.12;
uniform float spec_size : hint_range(0.0, 0.3) = 0.05;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV) * albedo_color;
	if (use_vertex_color) {
		albedo *= COLOR;
	}
	ALBEDO = albedo.rgb;
	//CUTOUT ALPHA = albedo.a; ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	// (ToonKit enables the line above only for cut-out materials - any ALPHA write makes Godot
	// draw the material as transparent, which breaks depth sorting on ordinary surfaces)
	EMISSION = emission.rgb * texture(emission_texture, UV).rgb * emission_energy;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float shade = ndl * 0.5 + 0.5;                          // half-lambert
	float aa = fwidth(shade) + band_softness;
	float lit = smoothstep(shadow_threshold - aa, shadow_threshold + aa, shade);
	// cast shadows / light falloff blend in linearly (like standard lighting), so shadow-map
	// noise stays smooth instead of being snapped into speckles by the hard band
	lit *= ATTENUATION;
	vec3 tone = mix(shadow_color.rgb, vec3(1.0), lit);
	// warm glow along the light / shadow boundary
	float term = clamp(1.0 - abs(shade - shadow_threshold) / terminator_width, 0.0, 1.0);
	tone += terminator_color.rgb * term * term * terminator_strength;
	DIFFUSE_LIGHT += LIGHT_COLOR * tone * (0.72 / PI);
	// thin rim on the lit side
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width - 0.03, 1.0 - rim_width + 0.03, fres) * lit;
	DIFFUSE_LIGHT += LIGHT_COLOR * rim * rim_strength / PI;
	// small hard highlight
	vec3 h = normalize(LIGHT + VIEW);
	float sp = smoothstep(1.0 - spec_size - 0.01, 1.0 - spec_size + 0.01, clamp(dot(NORMAL, h), 0.0, 1.0)) * lit;
	SPECULAR_LIGHT += LIGHT_COLOR * sp * spec_strength;
}
