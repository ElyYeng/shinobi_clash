// Aura 3D - from godotshaders.com/shader/aura-3d (CC0), ported to Godot 4.
// Goes on a slightly inflated, front-culled copy of the character's meshes (see AuraShell).
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_front, blend_add, shadows_disabled;

uniform sampler2D _NoiseTex : repeat_enable;
uniform float _Scale : hint_range(0.0, 0.05) = 0.05;
uniform float _Opacity : hint_range(0.01, 10.0) = 10.0;
uniform float _Edge : hint_range(0.0, 1.0) = 0.1;
uniform float _Push = 0.1;                       // how far the shell sits off the body, in metres
uniform vec4 _ColorAura : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 _ColorRim : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform float _Brightness : hint_range(0.5, 20.0) = 2.0;
uniform float _SpeedX : hint_range(-10.0, 10.0) = 0.0;
uniform float _SpeedY : hint_range(-10.0, 10.0) = 3.0;
uniform float _OffsetFade : hint_range(-10.0, 10.0) = 1.0;
uniform float _OutlineFixed : hint_range(0.0, 5.0) = 2.0;
uniform float _RimPower2 : hint_range(0.01, 10.0) = 6.0;
uniform float _Strength : hint_range(0.0, 2.0) = 1.0;   // fade in / out

void vertex() {
	// inflate in view space so the thickness is in metres for skinned and rigid meshes alike
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 vn = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v.xyz += vn * _Push;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	float speedx = TIME * _SpeedX * 0.005;
	float speedy = TIME * _SpeedY * -0.005;
	vec4 n = texture(_NoiseTex, vec2(SCREEN_UV.x * _Scale + speedx, SCREEN_UV.y * _Scale + speedy));
	vec4 n2 = texture(_NoiseTex, vec2(SCREEN_UV.x * (_Scale * 0.5) + speedx, SCREEN_UV.y * (_Scale * 0.5) + speedy));
	vec4 n3 = texture(_NoiseTex, vec2(SCREEN_UV.x * (_Scale * 2.0) + speedx, SCREEN_UV.y * (_Scale * 2.0) + speedy));
	float combined = (n.r * n2.r * 2.0) * n3.r * 2.0;

	float rims = pow(clamp(dot(VIEW, NORMAL), 0.0, 1.0), _RimPower2);
	float rim = rims - combined + rims * _OutlineFixed;
	float textured = clamp(rim * _Opacity, 0.0, 1.0);
	float extra = (clamp((_Edge + rim) * _Opacity, 0.0, 1.0) - textured) * _Brightness;
	vec4 result = _ColorAura * textured + _ColorRim * extra;
	result *= clamp((VERTEX.y + _OffsetFade) * 2.0, 0.0, 1.0);
	result *= _Strength;
	ALBEDO = result.rgb;
}
