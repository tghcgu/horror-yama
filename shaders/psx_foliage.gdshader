// 葉・草・シダなど、薄い板に葉の絵を貼ったもの。裏からも見え、絵の透けた所は描かない。
// 高い所ほど、風でゆっくりゆれる（木ごとに少しずつずらす）。
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

#include "res://shaders/psx_common.gdshaderinc"

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform float saturation = 1.0;
uniform float sway = 0.035;  // 高さ 1 m あたりのゆれ幅 (m)

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float height = max(VERTEX.y, 0.0);
	float phase = TIME * 1.1 + origin.x * 0.37 + origin.z * 0.23;
	vec2 gust = vec2(sin(phase), sin(phase * 0.73 + 1.7)) * sway * height;
	gust += vec2(sin(TIME * 3.1 + VERTEX.x * 2.0 + VERTEX.z * 1.7), 0.0) * 0.015 * height;  // 葉先の細かなそよぎ
	VERTEX.xz += gust;
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	if (tex.a < 0.5) {
		discard;
	}
	ALBEDO = albedo * psx_saturate(tex.rgb, saturation);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;  // 裏から見ても、同じように光が当たる
	}
	ROUGHNESS = 1.0;
}
