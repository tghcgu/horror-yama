// 木・岩・祠などの置き物。粗い素材を貼り、色味をそろえ、頂点を震わせる。
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/psx_common.gdshaderinc"

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform float texture_scale = 1.0;   // 1 m あたりのくり返し回数
uniform float saturation = 1.0;
uniform vec3 emission : source_color = vec3(0.0);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	vec3 tex = psx_triplanar(albedo_texture, world_position * texture_scale, world_normal);
	ALBEDO = albedo * psx_saturate(tex, saturation);
	ROUGHNESS = 1.0;
	EMISSION = emission;
}
