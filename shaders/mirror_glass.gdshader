// 古い鏡の面。鏡のカメラの映像を左右反転して貼り、少し暗く青みがかった色にして、ふちの曇りとくすみを足す。
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D reflection : source_color, filter_nearest;
uniform vec3 tint : source_color = vec3(0.86, 0.9, 0.92);
uniform float grime = 0.35;  // くすみの強さ

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec3 color = texture(reflection, vec2(1.0 - UV.x, UV.y)).rgb * tint;
	// ふちほど曇り、ところどころ銀がはげて黒ずんでいる
	vec2 edge = min(UV, 1.0 - UV);
	float fog = 1.0 - smoothstep(0.0, 0.12, min(edge.x, edge.y * 1.6));
	float stains = smoothstep(0.62, 0.85, value_noise(UV * vec2(9.0, 6.0)) * 0.7 + value_noise(UV * vec2(31.0, 20.0)) * 0.3);
	color = mix(color, color * 0.35, stains * grime);
	color = mix(color, vec3(0.06, 0.065, 0.065), fog * 0.45);
	ALBEDO = color;
}
