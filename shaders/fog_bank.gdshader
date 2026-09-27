// まだ行けないステージを隠す、濃い霧。画面全体に 1 枚の板を描き、視線が霧の中を通る道のりから濃さを求める。
// 霧は、境目（縦の平面）から奥の、上端より下にある。境目から少し入ると、みるみる濃くなる。
// 霧は、この先のステージの道すじに沿った太い帯の中だけにあり、帯のふちも上端も、もくもくと形を変える
// （横から見ても平らな壁には見えず、山並みにかかった雲のかたまりに見える）。
// 晴れるときは、薄い所からちぎれるように消えていき、境目も奥へ退いていく。
// 重さを抑えるため、模様の画像は 1 か所につき 1 回だけ読み、境目の波打ちは境目の近くでだけ読む。
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec3 color : source_color = vec3(0.7, 0.72, 0.74);
// 境目ごとに：xy = 霧の奥へ向かう向き (x, z)、z = 境目の位置（向きとの内積）、w = 霧の上端の高さ
uniform vec4 gate_1;
uniform vec4 gate_2;
uniform vec4 gate_3;
uniform vec3 clear;              // それぞれの霧の晴れ具合（0 = 濃い霧、1 = 晴れた）
uniform float density = 0.045;   // 1 m あたりの濃さ
uniform float ramp = 45.0;       // 境目から、濃くなりきるまでの奥行き (m)
uniform float wave = 80.0;       // 境目の波打ちの大きさ (m)
uniform float retreat = 70.0;    // 晴れるとき、境目が奥へ退く距離 (m)
uniform vec2 path_points[5];     // この先のステージの道すじ（霧の帯の芯）
uniform float corridor = 260.0;  // 霧の帯の太さ（芯からの距離, m）
// いま行けるステージのまわりも、霧で囲む（迷わないように）。ステージごとに：
//   stage_plains = 平地の始まり (xy) と終わり (zw)、stage_areas = 山の中心 (xy)、山の広がり (z)、平地の幅の半分 (w)
uniform vec4 stage_plains[4];
uniform vec4 stage_areas[4];
uniform int open_stages = 1;
uniform int first_stage = 0;  // これより前のステージは、霧に閉ざされた（来た道）
uniform float boundary_margin = 35.0;  // 平地と山から、これだけ離れると霧になる (m)
uniform float boundary_top = 400.0;    // まわりの霧の上端の高さ
// 砂浜のうしろの入り江の海は、霧でおおわない（海岸線と海が見えるように。海は深くて戻れない）
uniform vec2 beach_origin = vec2(0.0);
uniform vec2 beach_direction = vec2(0.0, -1.0);
uniform float cove_half_width = 140.0;

const int STEPS = 10;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);  // 画面いっぱいに描く
}

// その場所の霧の濃さ（0〜1）
float gate_density(vec4 gate, float clearing, vec3 p, float wisp) {
	if (clearing >= 1.0) {
		return 0.0;
	}
	float depth = dot(p.xz, gate.xy) - gate.z - clearing * retreat;
	float half_wave = wave * 0.5;
	if (depth < -half_wave) {
		return 0.0;  // 波打ってせり出しても、まだ届かない
	}
	// 境目の近くでだけ、境目に沿った横の位置で、境目を前後に波打たせる（ゆっくり形を変える）
	if (depth < ramp + half_wave) {
		float lateral = dot(p.xz, vec2(-gate.y, gate.x));
		depth -= (texture(noise, vec2(lateral * 0.0035, TIME * 0.004 + p.y * 0.0015)).r - 0.5) * wave;
	}
	float d = smoothstep(0.0, ramp, depth);
	// 上端は、もくもくと高さを変えて、空に溶かす
	float top = gate.w + (wisp - 0.45) * 50.0;
	d *= 1.0 - smoothstep(top - 200.0, top + 30.0, p.y);  // 上へ行くほど、ゆっくり薄れて空に溶ける（ぎざぎざにしない）
	// 晴れるときは、薄い所からちぎれて消えていく
	float threshold = -0.25 + clearing * 1.5;
	d *= smoothstep(threshold - 0.2, threshold + 0.2, wisp) * (1.0 - clearing * 0.6);
	return d;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1.0), 0.0, 1.0);
	return length(p - (a + ab * t));
}

// いま行けるステージ（平地と山）から、横にどれだけ離れているか
float open_distance(vec2 p) {
	float best = 1e9;
	for (int i = 0; i < 4; i++) {
		if (i >= open_stages) {
			break;
		}
		if (i < first_stage) {
			continue;
		}
		float to_plain = segment_distance(p, stage_plains[i].xy, stage_plains[i].zw) - stage_areas[i].w;
		float to_mountain = length(p - stage_areas[i].xy) - stage_areas[i].z;
		best = min(best, min(to_plain, to_mountain));
	}
	vec2 from_start = p - beach_origin;
	if (first_stage == 0 && dot(from_start, beach_direction) < 0.0) {
		best = min(best, abs(dot(from_start, vec2(-beach_direction.y, beach_direction.x))) - cove_half_width);
	}
	// 閉ざされた来た道：その境目より手前は、すべて霧の中
	if (first_stage > 0) {
		vec4 sealed = first_stage == 1 ? gate_1 : (first_stage == 2 ? gate_2 : gate_3);
		best = max(best, sealed.z - dot(p, sealed.xy));
	}
	return best;
}

// 道すじ（折れ線）からの横の距離
float path_distance(vec2 p) {
	float best = 1e9;
	for (int i = 0; i < 4; i++) {
		best = min(best, segment_distance(p, path_points[i], path_points[i + 1]));
	}
	return best;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 to = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 from = CAMERA_POSITION_WORLD;
	// 視線の始めから見えている物までを何か所か調べて、濃さを足し合わせる
	// （画素ごとにずらすと、ざらついて見えるので、ずらさない）
	vec3 ray = to - from;
	float step_length = length(ray) / float(STEPS);
	vec2 drift = vec2(TIME * 0.6, TIME * 0.25);
	float optical = 0.0;
	float glow = 0.0;
	for (int i = 0; i < STEPS; i++) {
		vec3 p = from + ray * ((float(i) + 0.5) / float(STEPS));
		// 高さも混ぜた模様にして、縦の筋にならないようにする
		vec2 tilt = vec2(p.y * 0.8, -p.y * 0.55);
		float wisp = texture(noise, (p.xz + tilt + drift) * 0.0022).r;
		float d = 0.0;
		// 道すじから離れた所には、霧はない（帯のふちは、もくもくと出入りする）
		float edge = corridor + (wisp - 0.5) * 160.0;
		float in_corridor = 1.0 - smoothstep(edge - 100.0, edge, path_distance(p.xz));
		if (in_corridor > 0.0) {
			d = max(gate_density(gate_1, clear.x, p, wisp), max(gate_density(gate_2, clear.y, p, wisp), gate_density(gate_3, clear.z, p, wisp))) * in_corridor;
		}
		// いま行けるステージのまわりの霧（ふちは、もくもくと出入りする）
		float outside = open_distance(p.xz) - boundary_margin + (wisp - 0.5) * 60.0;
		if (outside > 0.0) {
			float around = smoothstep(0.0, 80.0, outside) * (1.0 - smoothstep(boundary_top - 280.0, boundary_top + 40.0, p.y + (wisp - 0.5) * 30.0)) * 0.55;
			d = max(d, around);
		}
		float amount = d * density * step_length * (0.55 + 0.9 * wisp);
		optical += amount;
		glow += amount * wisp;
	}
	if (optical < 0.003) {
		discard;  // 霧がない所は、描かない
	}
	float alpha = 1.0 - exp(-optical);
	float shade = glow / optical;  // 霧の濃淡で、明るさを変える（もくもくした雲に見せる）
	ALBEDO = color * (0.86 + 0.22 * shade);
	ALPHA = alpha;
}
