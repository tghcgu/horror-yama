// 空。上から地平線への色の移り変わり、太陽のにじみ、流れる雲、夜の星と月。
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.3, 0.38, 0.5);
uniform vec3 horizon_color : source_color = vec3(0.6, 0.62, 0.64);
uniform vec3 ground_color : source_color = vec3(0.2, 0.2, 0.22);
uniform vec3 cloud_color : source_color = vec3(0.7, 0.7, 0.72);
uniform float cloud_amount = 0.6;
uniform float night = 0.0;  // 0（昼）〜 1（夜）。星と月の見え方
uniform vec3 moon_direction = vec3(-0.35, 0.55, -0.75);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float clouds(vec2 p) {
	float v = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		v += value_noise(p) * amplitude;
		p *= 2.1;
		amplitude *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 color = mix(horizon_color, top_color, smoothstep(0.0, 0.55, h));
	color = mix(color, ground_color, smoothstep(0.0, -0.2, h));

	// 太陽：小さな円盤と、まわりのにじみ
	if (LIGHT0_ENABLED && LIGHT0_ENERGY > 0.001) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		color += LIGHT0_COLOR * LIGHT0_ENERGY * (smoothstep(0.9994, 0.9997, s) * 2.0 + pow(s, 12.0) * 0.25);
	}

	if (h > 0.0) {
		// 星（夜だけ。ちらちらまたたく）
		vec2 star_uv = d.xz / (h + 0.25) * 55.0;
		vec2 cell = floor(star_uv);
		float r = hash(cell);
		vec2 jitter = vec2(hash(cell + 1.7), hash(cell + 4.3)) - 0.5;
		float star = step(0.955, r) * smoothstep(0.22, 0.0, length(fract(star_uv) - 0.5 - jitter * 0.5));
		star *= 0.55 + 0.45 * sin(TIME * (2.0 + r * 4.0) + r * 60.0);
		color += vec3(0.85, 0.9, 1.0) * star * night * smoothstep(0.0, 0.25, h) * (1.2 + r * 1.5);

		// 月
		float m = dot(d, normalize(moon_direction));
		color += vec3(0.9, 0.92, 1.0) * (smoothstep(0.9990, 0.9993, m) * 1.4 + pow(max(m, 0.0), 300.0) * 0.35) * night;

		// ゆっくり流れる雲
		vec2 cloud_uv = d.xz / (h + 0.12) * 1.3 + vec2(TIME * 0.004, TIME * 0.002);
		float c = smoothstep(0.45, 0.8, clouds(cloud_uv)) * cloud_amount * smoothstep(0.0, 0.15, h);
		color = mix(color, cloud_color, c);
	}
	COLOR = color;
}
