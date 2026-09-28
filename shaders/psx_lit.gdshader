// 木・岩・祠などの置き物。粗い素材を貼り、色味をそろえ、頂点を震わせる。
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/psx_common.gdshaderinc"

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform float texture_scale = 1.0;   // 1 m あたりのくり返し回数
uniform float saturation = 1.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform bool use_uv = false;         // true なら、モデルの UV で貼る（Blender で模様を焼き込んだモデル用）
uniform bool use_vertex_color = false; // true なら、頂点の色を掛ける（小さな形をまとめた置き物用。MeshBuilder）
uniform bool flat_shading = false;     // true なら、面ごとに陰影をつける（ごつごつした岩）
uniform float underside_dark = 0.0;    // 下を向いた面を、これだけ暗くする（岩のすき間の深い影）
uniform sampler2D top_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform float top_amount = 0.0;        // 上を向いた面をおおう物（苔・砂ぼこり・雪・灰）の濃さ
uniform float macro_variation = 0.0;   // 同じ模様のくり返しが目立たないように、大きな周期で明るさをゆらす量
uniform float detail_amount = 1.0;     // 模様の濃さ（小さいほど、模様の平均の色に近い、のっぺりした面になる）
uniform vec3 texture_average : source_color = vec3(0.5);  // 模様の平均の色

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	vec3 tex = use_uv ? texture(albedo_texture, UV).rgb : psx_triplanar(albedo_texture, world_position * texture_scale, world_normal);
	tex = mix(texture_average, tex, detail_amount);
	ALBEDO = albedo * psx_saturate(tex, saturation) * (use_vertex_color ? COLOR.rgb : vec3(1.0));
	if (flat_shading) {
		vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		NORMAL = dot(n, VIEW) < 0.0 ? -n : n;
	}
	if (macro_variation > 0.0) {
		ALBEDO *= 1.0 - macro_variation + macro_variation * 2.0 * psx_triplanar(albedo_texture, world_position * texture_scale * 0.13, world_normal).g;
	}
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	if (top_amount > 0.0) {
		// 上を向いた面ほど、苔や雪におおわれる（ふちは模様でぎざぎざに）
		vec3 top = texture(top_texture, world_position.xz * texture_scale).rgb;
		float edge = (texture(top_texture, world_position.xz * texture_scale * 0.37).g - 0.5) * 0.5;
		ALBEDO = mix(ALBEDO, top, smoothstep(0.3, 0.7, up + edge) * top_amount);
	}
	if (underside_dark > 0.0) {
		ALBEDO *= mix(1.0 - underside_dark, 1.0, smoothstep(-0.55, 0.35, up));
	}
	ROUGHNESS = 1.0;
	EMISSION = emission;
}
