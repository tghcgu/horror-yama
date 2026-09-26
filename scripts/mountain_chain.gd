class_name MountainChain
extends RefCounted
## 連なる 4 つの山（樹海・岩場・雪山・霊峰）の配置と大まかな形。遊ぶたびに generate() で乱数から決め直す。
## ふもとの樹海の山から北（-Z）へ向かって、山を越えるたびに高くなる。
## 山と山の間は、ひとつ前の山の頂上より低い谷（鞍部）でつながっている。
## 地面の高さ（Terrain）と、いまどの地帯にいるか（Biomes）の両方が、ここを元にする。

const COUNT := 4
const SIDE_DROP := 3.0   # 裾より外側の、谷へ落ちる斜面の急さ（1 m 進むと何 m 下がるか）
const PLATEAU := 5.0     # 頂上をこれだけ削って、たき火や祠を置ける平らな場所にする (m)
const LOWLAND := 7.0     # これより低い場所は、どこでも樹海
const BLEND := 6.0       # 地帯の境目をぼかす幅 (m)

# 各山：中心の位置、裾の高さ（ひとつ手前の谷の高さ）、頂上の高さ、裾の半径
static var centers: Array[Vector2] = [Vector2.ZERO, Vector2(18, -83), Vector2(-12, -166), Vector2(6, -245)]
static var bases: Array[float] = [0.0, 50.0, 115.0, 185.0]
static var peaks: Array[float] = [75.0, 145.0, 215.0, 285.0]
static var radii: Array[float] = [60.0, 65.0, 65.0, 60.0]


## 乱数の種から、4 つの山の位置と高さを決める。同じ種なら同じ山になる
static func generate(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var heading := 0.0  # 北（-Z）から左右へどれだけ曲がって進むか
	for i in COUNT:
		if i == 0:
			bases[0] = 0.0
			peaks[0] = rng.randf_range(70.0, 85.0)
			radii[0] = rng.randf_range(55.0, 65.0)
			centers[0] = Vector2.ZERO
			continue
		bases[i] = peaks[i - 1] - rng.randf_range(28.0, 40.0)
		peaks[i] = bases[i] + rng.randf_range(80.0, 100.0)
		radii[i] = rng.randf_range(55.0, 70.0)
		heading = clampf(heading + rng.randf_range(-0.5, 0.5), -0.6, 0.6)
		# ひとつ前の山の斜面が、この山の裾の高さまで下りてきた所で、この山が立ち上がる
		var previous_reach := radii[i - 1] * (peaks[i - 1] - bases[i]) / (peaks[i - 1] - bases[i - 1])
		var spacing := previous_reach + radii[i]
		centers[i] = centers[i - 1] + Vector2(sin(heading), -cos(heading)) * spacing


## 山 i だけがあったときの、なだらかな高さ（岩のでこぼこをつける前）
static func cone(i: int, x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(centers[i])
	var base := bases[i]
	var peak := peaks[i]
	var radius := radii[i]
	if d < radius:
		return base + (peak - base) * (1.0 - d / radius)
	return base - (d - radius) * SIDE_DROP


## その場所がどの山のものか（重み）。境目ではなめらかに混ざる
static func weights(x: float, z: float, height: float) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(COUNT)
	var best := -INF
	for i in COUNT:
		values[i] = cone(i, x, z)
		best = maxf(best, values[i])
	var total := 0.0
	for i in COUNT:
		values[i] = exp((values[i] - best) / BLEND)
		total += values[i]
	for i in COUNT:
		values[i] /= total
	# ふもとの低い場所は、どの山のそばでも樹海
	var lowland := 1.0 - smoothstep(LOWLAND - 3.0, LOWLAND + 3.0, height)
	for i in COUNT:
		values[i] = lerpf(values[i], 1.0 if i == 0 else 0.0, lowland)
	return values


static func summit(i: int) -> Vector2:
	return centers[i]


## 地形の広さ（すべての山と、そのまわりの谷が入る範囲）
static func bounds() -> Rect2:
	var rect := Rect2(centers[0], Vector2.ZERO)
	for i in COUNT:
		var reach := radii[i] + bases[i] / SIDE_DROP + 14.0
		rect = rect.expand(centers[i] + Vector2(reach, reach)).expand(centers[i] - Vector2(reach, reach))
	return rect.grow_individual(0.0, 0.0, 0.0, 30.0)  # ふもとの南にスタート地点
