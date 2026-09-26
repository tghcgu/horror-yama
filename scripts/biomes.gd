class_name Biomes
extends RefCounted
## 地帯（バイオーム）。連なる 4 つの山が、それぞれひとつの地帯になっている（MountainChain）。
## 地面の模様・霧・出てくる敵・置き物・寒さが変わる。

enum Id { FOREST, CRAG, SNOW, SUMMIT }

const NAMES := ["樹海", "岩場", "雪山", "霊峰"]
const FOG_DENSITY := [1.3, 1.0, 1.6, 0.8]  # 基本の霧の濃さに掛ける倍率
const FOG_TINTS := [Color(0.32, 0.4, 0.33), Color(0.5, 0.45, 0.42), Color(0.85, 0.87, 0.92), Color(0.42, 0.3, 0.34)]


static func at(pos: Vector3) -> int:
	var w := MountainChain.weights(pos.x, pos.z, pos.y)
	var best := 0
	for i in w.size():
		if w[i] > w[best]:
			best = i
	return best


## 場所に応じて、地帯ごとの値を境目でなめらかにつないだ色を返す
static func blend_color(colors: Array, pos: Vector3) -> Color:
	var w := MountainChain.weights(pos.x, pos.z, pos.y)
	var result := Color(0, 0, 0, 0)
	for i in w.size():
		result += (colors[i] as Color) * w[i]
	return result


static func blend_value(values: Array, pos: Vector3) -> float:
	var w := MountainChain.weights(pos.x, pos.z, pos.y)
	var result := 0.0
	for i in w.size():
		result += float(values[i]) * w[i]
	return result
