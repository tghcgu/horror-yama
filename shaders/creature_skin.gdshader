// 化け物の肌。暗闇でも輪郭がうっすら浮かび、濡れたような光沢があり、皮膚の下がわずかにうごめく。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/psx_common.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.03, 0.03, 0.03);
uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;  // Blender で焼き込んだ肌の模様
uniform float mottle_amount = 0.4;  // まだら模様の強さ（焼き込んだ模様があるときは 0 にする）
uniform vec3 rim_color : source_color = vec3(0.35, 0.4, 0.45);
uniform float rim_strength = 0.3;   // 輪郭の光り方
uniform float rim_power = 3.0;      // 大きいほど輪郭の細いところだけ光る
uniform float wetness : hint_range(0.0, 1.0) = 0.5;
uniform float twitch = 0.0;         // 皮膚のうごめき（動いている間だけ上げる）

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// なめらかにつながるまだら模様
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	VERTEX += NORMAL * sin(TIME * 23.0 + VERTEX.y * 31.0 + VERTEX.x * 17.0) * 0.004 * twitch;
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float mottle = value_noise(UV * vec2(12.0, 24.0)) * 0.6 + value_noise(UV * vec2(40.0, 80.0)) * 0.4;
	ALBEDO = base_color * texture(albedo_texture, UV).rgb * (1.0 - mottle_amount * 0.5 + mottle_amount * mottle);
	ROUGHNESS = mix(0.95, 0.25, wetness);
	SPECULAR = 0.5;
	EMISSION = rim_color * rim * rim_strength;
}
