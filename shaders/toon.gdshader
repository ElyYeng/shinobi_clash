shader_type spatial;
// Toon / cel shading for characters and map props - adapted from the Ultimate Toon Source
// "stylized" shader (assets/UltimateToonSource/shader/stylized.gdshader, left untouched).
// Changes: colour textures read as sRGB, alpha-scissor cut-outs (hair cards), emission (glowing
// outfits / masks), double-sided, and the screen pattern is dropped (the pack ships no pattern
// texture). Materials are converted automatically by ToonKit (scripts/fx/toon_kit.gd).
render_mode cull_disabled;

group_uniforms Shader.Albedo;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float alpha_scissor = 0.0;          // > 0: cut out pixels below this alpha
uniform vec3 uv1_scale = vec3(1.0);         // texture transform from the source material (Meshy
uniform vec3 uv1_offset = vec3(0.0);        // models ship 16x-scaled UVs)
uniform bool use_vertex_color = false;
uniform float albedo_affect : hint_range(0.0, 1.0, 0.05) = 0.0;

group_uniforms Shader.Emission;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D emission_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float emission_energy = 0.0;

group_uniforms Shader.Light;
uniform bool use_stepped = true;
uniform float steps = 2.0;
uniform float step_smoothness : hint_range(0.0, 1.0, 0.05) = 0.08;
uniform vec4 shadow_tint : source_color = vec4(0.36, 0.32, 0.55, 1.0);
uniform float shadow_tint_amount : hint_range(0.0, 1.0, 0.1) = 0.35;

group_uniforms Shader.Specular;
uniform float specular : hint_range(0.0, 1.0, 0.05) = 0.0;

group_uniforms Shader.Rim;
uniform bool use_rim = true;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_amount = 3.0;
uniform float rim_smoothness = 0.12;
uniform float rim_mask_shadow : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float rim_blend : hint_range(0.0, 1.0, 0.05) = 0.22;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV) * albedo_color;
	if (use_vertex_color) {
		albedo *= COLOR;
	}
	ALBEDO = albedo.rgb;
	if (alpha_scissor > 0.0) {
		ALPHA = albedo.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	}
	EMISSION = emission.rgb * texture(emission_texture, UV).rgb * emission_energy;
	ROUGHNESS = 1.0;
	SPECULAR = specular;
}

void light() {
	float light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	if (use_stepped) {
		float light_mult = light * steps;
		float step_base = floor(light_mult);
		float light_factor = smoothstep(0.5 - step_smoothness, 0.5 + step_smoothness, light_mult - step_base);
		light = (step_base + light_factor) / steps;
	}
	vec3 diffuse = vec3(light) * (LIGHT_COLOR / PI);
	diffuse = (shadow_tint.rgb * (1.0 - light) * shadow_tint_amount) * (LIGHT_COLOR / PI) + diffuse * light;
	if (use_rim) {
		float rim_value = fresnel(rim_amount, NORMAL, VIEW);
		rim_value = smoothstep(0.5 - (rim_smoothness / 2.0), 0.5 + (rim_smoothness / 2.0), rim_value);
		rim_value = mix(rim_value, rim_value * light, rim_mask_shadow);
		diffuse += rim_color.rgb * rim_value * rim_blend * (LIGHT_COLOR / PI);
	}
	DIFFUSE_LIGHT += mix(diffuse, ALBEDO * diffuse, albedo_affect);
	SPECULAR_LIGHT += vec3(pow(light, 50.0)) * specular;
}
