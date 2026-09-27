// 山の地形。頂点の色に入っている「4 つの地帯の重み」で素材を混ぜ、急な面には岩肌を貼る。
// （地帯は高さではなく、どの山の上にいるかで決まる。MountainChain を参照）
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/psx_common.gdshaderinc"

// 地帯ごとの岩肌（tools/textures/paint_rocks.py で描いた模様）
uniform sampler2D rock_forest : source_color, filter_nearest, repeat_enable;  // 樹海：湿った黒い岩と苔
uniform sampler2D rock_crag : source_color, filter_nearest, repeat_enable;    // 岩場：花崗岩
uniform sampler2D rock_snow : source_color, filter_nearest, repeat_enable;    // 雪山：霜と雪の筋
uniform sampler2D rock_summit : source_color, filter_nearest, repeat_enable;  // 霊峰：黒い玄武岩
uniform sampler2D ground_forest : source_color, filter_nearest, repeat_enable;
uniform sampler2D ground_crag : source_color, filter_nearest, repeat_enable;
uniform sampler2D ground_snow : source_color, filter_nearest, repeat_enable;
uniform sampler2D ground_summit : source_color, filter_nearest, repeat_enable;

uniform vec3 rock_tint_forest : source_color = vec3(1.0);
uniform vec3 rock_tint_crag : source_color = vec3(1.0);
uniform vec3 rock_tint_snow : source_color = vec3(1.0);
uniform vec3 rock_tint_summit : source_color = vec3(1.0);
uniform vec3 ground_tint_forest : source_color = vec3(0.45, 0.5, 0.3);
uniform vec3 ground_tint_crag : source_color = vec3(0.85, 0.8, 0.75);
uniform vec3 ground_tint_snow : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 ground_tint_summit : source_color = vec3(0.55, 0.5, 0.5);
uniform vec2 beach_origin = vec2(0.0);           // 最初の平地の入り口（ここからうしろが砂浜）
uniform vec2 beach_direction = vec2(0.0, -1.0);  // 平地の奥へ向かう向き
uniform float texture_scale = 0.33;    // 1 m あたりのくり返し回数（0.33 = 3 m で 1 枚）

varying vec3 world_position;
varying vec3 world_normal;
varying vec4 biome_weights;
varying float shade;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	biome_weights = COLOR;
	shade = UV.x;
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	vec3 p = world_position * texture_scale;
	vec3 n = world_normal;
	vec4 w = biome_weights / max(dot(biome_weights, vec4(1.0)), 0.001);

	// 素材は、その場所にある地帯のぶんだけ読む（ほとんどの場所は 1 つの地帯）。
	// 地面か岩肌かも、どちらかしか見えない所では、見えるほうだけ読む
	float flatness = smoothstep(0.62, 0.8, n.y);
	const float LITTLE = 0.02;
	vec3 ground = vec3(0.0);
	if (flatness > 0.0) {
		if (w.x > LITTLE) { ground += psx_triplanar(ground_forest, p, n) * ground_tint_forest * w.x; }
		if (w.y > LITTLE) { ground += psx_triplanar(ground_crag, p, n) * ground_tint_crag * w.y; }
		if (w.z > LITTLE) { ground += psx_triplanar(ground_snow, p, n) * ground_tint_snow * w.z; }
		if (w.w > LITTLE) { ground += psx_triplanar(ground_summit, p, n) * ground_tint_summit * w.w; }
	}
	vec3 rock = vec3(0.0);
	if (flatness < 1.0) {
		if (w.x > LITTLE) { rock += psx_triplanar(rock_forest, p, n) * rock_tint_forest * w.x; }
		if (w.y > LITTLE) { rock += psx_triplanar(rock_crag, p, n) * rock_tint_crag * w.y; }
		if (w.z > LITTLE) { rock += psx_triplanar(rock_snow, p, n) * rock_tint_snow * w.z; }
		if (w.w > LITTLE) { rock += psx_triplanar(rock_summit, p, n) * rock_tint_summit * w.w; }
	}
	// 同じ模様のくり返しが目立たないように、ずっと大きな周期で明るさをゆらす
	rock *= 0.72 + 0.56 * psx_triplanar(rock_crag, p * 0.11, n).r;
	// 切り立った岩肌は暗くする（重なった巨大な岩のすき間の、奥の影に見える）
	rock *= mix(0.55, 1.0, smoothstep(0.05, 0.6, n.y));
	vec3 surface = mix(rock, ground, flatness);
	// 海面の近く（島の砂浜と、波打ち際）は砂。濡れた所は暗い
	float behind = -dot(world_position.xz - beach_origin, beach_direction);  // 最初の平地の入り口から、うしろへの距離
	float beach = max(smoothstep(14.0, 24.0, behind), 1.0 - smoothstep(-0.8, 0.2, world_position.y));
	if (beach > 0.0) {
		vec3 sand = psx_triplanar(ground_crag, p * 0.8, n) * vec3(1.05, 0.95, 0.72);
		sand *= mix(0.62, 1.0, smoothstep(-1.6, -0.4, world_position.y));
		surface = mix(surface, sand, beach);
	}
	ALBEDO = surface * shade;
	ROUGHNESS = 1.0;
}
