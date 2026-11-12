// Stylised sky for every map (village, open world, Kurama arena - and Vfx.build_environment).
// Gradient sky + sun + soft drifting clouds. Tweak the uniforms on the map's Sky material in the
// Inspector: WorldEnvironment > Environment > Sky > Sky Material.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.2, 0.45, 0.9);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.85, 0.95);
uniform vec3 ground_color : source_color = vec3(0.3, 0.33, 0.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.6, 0.65, 0.78);
uniform vec3 sun_dir = vec3(0.0, 0.5, 0.8);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.55;   // how much of the sky is cloud
uniform float cloud_softness : hint_range(0.05, 0.6) = 0.2; // edge softness
uniform float cloud_scale : hint_range(0.2, 4.0) = 1.0;     // bigger = smaller clouds
uniform float cloud_speed : hint_range(0.0, 0.2) = 0.012;   // drift
uniform float wisps : hint_range(0.0, 1.0) = 0.35;           // thin high cloud layer
uniform float star_amount = 0.0;
uniform vec2 cloud_offset = vec2(0.0);                      // where the cloud layer sits

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}
float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
// Smooth gradient noise, about -0.7..0.7.
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(hash2(i), f);
	float b = dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
// Fractal noise mapped to roughly 0..1; rotated octaves avoid grid-aligned streaks.
float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int i = 0; i < octaves; i++) {
		v += a * gnoise(p);
		p = r * p + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v * 0.9 + 0.5;
}
// Cloud density at a sky-plane position: domain-warped fbm gives puffy, irregular shapes.
float cloud_density(vec2 uv) {
	vec2 w = vec2(fbm(uv * 0.6, 3), fbm(uv * 0.6 + vec2(5.2, 1.3), 3));
	float n = fbm(uv + (w - 0.5) * 1.4, 5);
	return (n - 0.5) * 2.1 + 0.5;   // stretch: clear sky between clouds, solid cores
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	} else {
		col = mix(horizon_color, ground_color, pow(clamp(-h * 4.0, 0.0, 1.0), 0.6));
	}
	vec3 sd3 = normalize(sun_dir);
	float sd = max(dot(d, sd3), 0.0);
	col += sun_color * (pow(sd, 10.0) * 0.22 + pow(sd, 90.0) * 0.4);   // glow around the sun
	col += sun_color * smoothstep(0.9986, 0.9995, sd) * 5.0;           // sun disc
	if (star_amount > 0.0 && h > 0.0) {
		vec2 sp = d.xz / (h + 0.2) * 60.0;
		float s = step(0.985, h21(floor(sp)));
		col += vec3(s) * star_amount * smoothstep(0.0, 0.3, h);
	}
	if (h > 0.0) {
		// Project onto a curved cloud layer (less stretching near the horizon than a flat plane).
		vec2 uv = d.xz / (h * 0.85 + 0.18) * 1.3 * cloud_scale;
		// (no TIME: an animated sky gets its lighting rebuilt every frame, which hung AMD RX 5700
		// GPUs - "Vulkan device lost" in SKY_PASS. cloud_offset moves the clouds by hand instead.)
		vec2 wind = cloud_offset;
		float n = cloud_density(uv + wind);
		float cov = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + cloud_softness, n);
		// Light: compare with the density a little toward the sun - thicker toward the sun = shaded.
		vec2 to_sun = normalize(sd3.xz + vec2(0.0001)) * 0.12;
		float n_sun = cloud_density(uv + wind + to_sun);
		float lit = clamp(0.7 + (n - n_sun) * 2.2, 0.0, 1.0);
		vec3 cc = mix(cloud_shadow, cloud_color, lit);
		cc = mix(cc, cloud_shadow, smoothstep(0.75, 1.05, n) * 0.35);      // dense cores a bit grey
		cc += sun_color * pow(sd, 7.0) * (1.0 - cov * 0.6) * 0.35;         // bright rims near the sun
		float fade = smoothstep(0.015, 0.22, h);                            // melt into the horizon haze
		col = mix(col, cc, cov * fade * 0.95);
		// Thin high wisps
		if (wisps > 0.0) {
			vec2 uv2 = d.xz / (h + 0.35) * vec2(0.6, 2.2) * cloud_scale + wind * 1.7 + vec2(40.0, 10.0);
			float wv = smoothstep(0.58, 0.85, fbm(uv2, 4));
			col = mix(col, cloud_color * 0.95 + sun_color * 0.05, wv * wisps * 0.35 * fade * (1.0 - cov));
		}
	}
	// soft haze band at the horizon
	col = mix(col, horizon_color, exp(-abs(h) * 14.0) * 0.25);
	COLOR = col;
}
