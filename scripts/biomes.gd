class_name Biomes
extends RefCounted
## 山の高さごとの地帯（バイオーム）。地面の色・霧・出てくる敵・置き物が変わる。

enum Id { FOREST, CRAG, SNOW, SUMMIT }

const NAMES := ["樹海", "岩場", "雪原", "山頂"]
const TOPS := [36.0, 72.0, 108.0, INF]  # 各地帯の上端の高さ (m)
const BLEND := 4.0                      # 地帯の境目をぼかす幅 (m)

const GROUND_COLORS := [Color(0.13, 0.19, 0.1), Color(0.33, 0.29, 0.24), Color(0.86, 0.88, 0.92), Color(0.22, 0.2, 0.2)]
const ROCK_COLORS := [Color(0.22, 0.2, 0.17), Color(0.34, 0.32, 0.3), Color(0.4, 0.43, 0.48), Color(0.17, 0.15, 0.16)]
const FOG_DENSITY := [1.9, 1.0, 1.7, 0.8]  # 基本の霧の濃さに掛ける倍率
const FOG_TINTS := [Color(0.32, 0.4, 0.33), Color(0.5, 0.45, 0.42), Color(0.85, 0.87, 0.92), Color(0.42, 0.3, 0.34)]


static func at(height: float) -> int:
	for i in TOPS.size():
		if height < TOPS[i]:
			return i
	return Id.SUMMIT


## 高さに応じて、地帯ごとの値を境目でなめらかにつないだ色を返す
static func blend_color(colors: Array, height: float) -> Color:
	var result: Color = colors[0]
	for i in range(1, colors.size()):
		var edge: float = TOPS[i - 1]
		result = result.lerp(colors[i], smoothstep(edge - BLEND, edge + BLEND, height))
	return result


static func blend_value(values: Array, height: float) -> float:
	var result: float = values[0]
	for i in range(1, values.size()):
		var edge: float = TOPS[i - 1]
		result = lerpf(result, values[i], smoothstep(edge - BLEND, edge + BLEND, height))
	return result
