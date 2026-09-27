// 島をかこむ海。ゆっくりうねり、浅い所は明るい緑がかった青、深い所は黒っぽい青。
// 波打ち際（海の底が浅い所）には、白い波の泡が寄せては返す。
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec3 deep_color : source_color = vec3(0.03, 0.1, 0.14);
uniform vec3 shallow_color : source_color = vec3(0.12, 0.34, 0.36);
uniform vec3 foam_color : source_color = vec3(0.86, 0.9, 0.9);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_position.x * 0.13 + TIME * 0.8) * 0.12 + sin(world_position.z * 0.09 + TIME * 0.6) * 0.1;
	// （海の三角形はとても大きいので、PS1 風の頂点の震えはかけない。カメラの横の頂点で、形がくずれてしまう）
}

void fragment() {
	// 水面から海の底までの深さ（画面の奥行きから）
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float water_depth = max(VERTEX.z - view.z, 0.0);
	vec2 uv = world_position.xz * 0.018 + TIME * vec2(0.008, 0.005);
	float ripple = texture(noise, uv).r * 0.6 + texture(noise, uv * 2.7 - TIME * vec2(0.011, 0.006)).r * 0.4;
	vec3 water = mix(shallow_color, deep_color, smoothstep(0.4, 7.0, water_depth)) * (0.85 + ripple * 0.3);
	// 寄せては返す波の泡
	float surge = 0.5 + 0.5 * sin(TIME * 0.9 + world_position.x * 0.05);
	float foam = (1.0 - smoothstep(0.0, 0.5 + surge * 0.8, water_depth)) * smoothstep(0.35, 0.6, ripple + 0.2);
	ALBEDO = mix(water, foam_color, foam);
	ALPHA = mix(0.55, 0.96, smoothstep(0.2, 3.5, water_depth)) + foam * 0.3;
	ROUGHNESS = 0.2;
	SPECULAR = 0.5;
}
