// 山の地形。高さで地帯（樹海・岩場・雪原・山頂）の素材を切り替え、急な面には岩肌を貼る。
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/psx_common.gdshaderinc"

uniform sampler2D rock_low : source_color, filter_nearest, repeat_enable;   // 樹海の崖（苔むした岩）
uniform sampler2D rock_high : source_color, filter_nearest, repeat_enable;  // それより上の崖
uniform sampler2D ground_forest : source_color, filter_nearest, repeat_enable;
uniform sampler2D ground_crag : source_color, filter_nearest, repeat_enable;
uniform sampler2D ground_snow : source_color, filter_nearest, repeat_enable;
uniform sampler2D ground_summit : source_color, filter_nearest, repeat_enable;

uniform vec3 rock_tint_forest : source_color = vec3(0.55, 0.6, 0.5);
uniform vec3 rock_tint_crag : source_color = vec3(0.75, 0.72, 0.7);
uniform vec3 rock_tint_snow : source_color = vec3(0.7, 0.76, 0.85);
uniform vec3 rock_tint_summit : source_color = vec3(0.4, 0.37, 0.38);
uniform vec3 ground_tint_forest : source_color = vec3(0.45, 0.5, 0.3);
uniform vec3 ground_tint_crag : source_color = vec3(0.85, 0.8, 0.75);
uniform vec3 ground_tint_snow : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 ground_tint_summit : source_color = vec3(0.55, 0.5, 0.5);
uniform float rock_saturation = 0.35;  // 岩の素材は赤っぽいので、色を抜いて灰色寄りにする

uniform float texture_scale = 0.33;  // 1 m あたりのくり返し回数（0.33 = 3 m で 1 枚）
uniform vec3 biome_tops = vec3(36.0, 72.0, 108.0);
uniform float biome_blend = 4.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	vec3 p = world_position * texture_scale;
	vec3 n = world_normal;
	float h = world_position.y;
	float to_crag = smoothstep(biome_tops.x - biome_blend, biome_tops.x + biome_blend, h);
	float to_snow = smoothstep(biome_tops.y - biome_blend, biome_tops.y + biome_blend, h);
	float to_summit = smoothstep(biome_tops.z - biome_blend, biome_tops.z + biome_blend, h);

	vec3 ground = psx_triplanar(ground_forest, p, n) * ground_tint_forest;
	ground = mix(ground, psx_triplanar(ground_crag, p, n) * ground_tint_crag, to_crag);
	ground = mix(ground, psx_triplanar(ground_snow, p, n) * ground_tint_snow, to_snow);
	ground = mix(ground, psx_triplanar(ground_summit, p, n) * ground_tint_summit, to_summit);

	vec3 low = psx_saturate(psx_triplanar(rock_low, p, n), rock_saturation);
	vec3 high = psx_saturate(psx_triplanar(rock_high, p, n), rock_saturation);
	vec3 rock = mix(low * rock_tint_forest, high * rock_tint_crag, to_crag);
	rock = mix(rock, high * rock_tint_snow, to_snow);
	rock = mix(rock, high * rock_tint_summit, to_summit);

	float flatness = smoothstep(0.62, 0.8, n.y);
	ALBEDO = mix(rock, ground, flatness) * COLOR.rgb;
	ROUGHNESS = 1.0;
}
