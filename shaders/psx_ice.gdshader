// 氷（凍った滝・氷の壁・氷の柱）。模様は Blender で描いた氷の絵（縦の流れ筋・閉じこめられた泡・ひび・白い霜）。
// 氷らしく見せるために：
//   ・斜めから見るほど白く明るく光る（ふち光り）
//   ・正面から見ると、奥が深い青に沈んで見える（中まで透けて見える感じ）
//   ・つるつるで、光が鋭く照り返す
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/psx_common.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec3 deep_color : source_color = vec3(0.12, 0.3, 0.52);   // 正面から見たときの、奥の青
uniform vec3 rim_color : source_color = vec3(0.85, 0.95, 1.0);    // 斜めから見たときの光
uniform float rim_power = 2.5;
uniform float glow = 0.12;  // 夜でもうっすら青白く見える

void vertex() {
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	vec3 tex = texture(albedo_texture, UV).rgb;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	// 正面ほど奥の青に沈み、ふちほど模様（霜や泡）と光が出る
	vec3 body = mix(tex, tex * deep_color * 2.2, facing * 0.7);
	ALBEDO = mix(body, rim_color, rim * 0.45);
	ROUGHNESS = 0.18;
	SPECULAR = 0.8;
	EMISSION = (deep_color * 0.6 + rim_color * rim * 0.4) * glow;
}
