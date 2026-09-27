class_name MountainChain
extends RefCounted
## 4 つのステージ（樹海・岩場・雪山・霊峰）の配置と大まかな形。遊ぶたびに generate() で乱数から決め直す。
## どのステージも、まずその地帯らしい凸凹だらけの平地をしばらく歩き、その先にその地帯の高い山並みがそびえる。
## 山はひとつの円すいではなく、主峰のまわりに肩・前山・衛星峰が重なった山塊で、裾の前山からだんだん高くなっていく。
## 山を越えるたびに高くなる。前の山の頂上から裏へ下りると、次のステージの平地に出る。
## 2 つめからのステージは、山並みの高い所にある。平地のふちは崖で、落ちると下の谷底まで落ちる。
## 谷底から先は、山すそがふもとの低地まで下っていく（全体がひとつながりの大地で、宙に浮いた所はない）。
## 次のステージは、前の山の頂上に着くまで濃い霧に隠れている（unlocked 個のステージだけが霧の外にある）。
## 霧の境目（gate）は、前の山の頂上のすぐ先の、次の平地が始まる所にある。
## 地面の高さ（Terrain）と、いまどの地帯にいるか（Biomes）の両方が、ここを元にする。

const COUNT := 4
const SIDE_DROP := 3.0          # 裾や平地のふちより外側の、落ち込む斜面の急さ（1 m 進むと何 m 下がるか）
const PLATEAU := 5.0            # 頂上をこれだけ削って、たき火や祠を置ける平らな場所にする (m)
const LOWLAND := 7.0            # これより低い場所は、どこでも樹海
const BLEND := 6.0              # 地帯の境目をぼかす幅 (m)
const PLAIN_HALF_WIDTH := 44.0  # 平地の幅の半分 (m)
const PLAIN_LENGTH := Vector2(110.0, 150.0)
const VALLEY_DEPTH := 70.0      # 平地のふちの崖から、その下の谷底までの深さ (m)
const APRON := 22.0             # 崖の下の谷底の広さ (m)。その先は、山すそがふもとの低地まで下っていく
const FOOT_SLOPE := 1.2         # 山すその下り坂の急さ（1 m 進むと何 m 下がるか）
const FOOT_BLEND := 25.0        # となり合うステージの谷底の高さを、なめらかにつなぐ幅 (m)
const OUTSKIRTS := 320.0        # 地形のまわりに広がる、ふもとの丘陵の幅 (m)
const SUB_PEAKS := Vector2i(7, 10)  # 主峰のまわりの、肩・前山・衛星峰の数
const SPREAD := 1.45            # 前山と尾根の先まで含めた山の広がり（裾の半径の倍率）
const DETAIL_MARGIN := 35.0     # 平地と山から、これだけ離れた所までは地形を細かく作る (m)

# --- 後ろのステージほど難しい ---
const HEIGHTS := [Vector2(260.0, 300.0), Vector2(300.0, 340.0), Vector2(330.0, 370.0), Vector2(360.0, 400.0)]  # 裾から頂上まで
const RADII := [Vector2(135.0, 150.0), Vector2(130.0, 145.0), Vector2(125.0, 140.0), Vector2(120.0, 135.0)]  # 裾の半径（小さいほど急）
const ROUGHNESS := [1.0, 1.15, 1.3, 1.5]    # 尾根・こぶの大きさの倍率
const CRACKS := [0.6, 0.9, 1.1, 1.35]       # 割れ目の深さの倍率
const CLIMB_DRAIN := [1.1, 1.25, 1.4, 1.6]  # 登るときの疲れやすさ（高いほど空気が薄い）
const ENEMY_RATE := [0.7, 0.9, 1.1, 1.35]   # 化け物の出やすさ
## 最初の山（樹海の山）の形は、乱数ではなく手で決める：[向き (度), 中心からの距離（裾の半径の倍率）, 高さの割合, 半径の倍率]。
## 向きは 0 度が東、90 度が南（平地の側）、270 度が北（次のステージへ下りる側で、ここには置かない）
const FIRST_MOUNTAIN := [
	[90.0, 0.72, 0.42, 0.3],    # 平地から見て正面の岩の胸壁：ここから登り始める
	[62.0, 0.9, 0.24, 0.24],    # 登り口の右の前山
	[122.0, 0.88, 0.3, 0.26],   # 登り口の左の前山
	[195.0, 0.52, 0.8, 0.42],   # 西の大きな肩：主峰に次いで高く、平地からよく見える
	[160.0, 0.82, 0.36, 0.28],  # 西の肩から南へ張り出す尾根の先
	[8.0, 0.6, 0.7, 0.3],       # 東の尖峰
	[36.0, 0.86, 0.3, 0.25],    # 東の尖峰の下の前山
	[228.0, 0.84, 0.46, 0.3],   # 北西の裏山
]

# 各ステージ：山の中心、裾の高さ（＝平地の高さ）、頂上の高さ、裾の半径、平地の始まりと終わり（山の裾）
static var centers: Array[Vector2] = [Vector2.ZERO, Vector2(18, -420), Vector2(-12, -840), Vector2(6, -1260)]
static var bases: Array[float] = [0.0, 230.0, 500.0, 800.0]
static var peaks: Array[float] = [280.0, 550.0, 850.0, 1180.0]
static var radii: Array[float] = [140.0, 138.0, 132.0, 128.0]
static var plain_starts: Array[Vector2] = [Vector2(0, 270), Vector2(10, -45), Vector2(0, -470), Vector2(0, -890)]
static var plain_ends: Array[Vector2] = [Vector2(0, 140), Vector2(15, -180), Vector2(-8, -600), Vector2(4, -1020)]
## ステージごとの肩・前山・衛星峰：[中心 (Vector2), 頂上の高さ, 裾の半径] の配列
static var sub_peaks: Array = [[], [], [], []]
## ステージごとの、主峰から放射状に張り出す尾根：[向き (ラジアン), 張り出す強さ, 鋭さ] の配列。尾根と尾根の間は沢になる
static var spurs: Array = [[], [], [], []]
## 霧の外にあるステージの数（最初は 1。山頂のたき火に着くたびに増える）。
## 置き物を置く間は、すべてのステージがあるものとして COUNT にしておく
static var unlocked := COUNT


## 乱数の種から、各ステージの平地と山の位置・高さを決める。同じ種なら同じ山になる
static func generate(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var heading := 0.0  # 北（-Z）から左右へどれだけ曲がって進むか
	for i in COUNT:
		sub_peaks[i] = []
		spurs[i] = []
		if i == 0:
			bases[0] = 0.0
			peaks[0] = rng.randf_range(HEIGHTS[0].x, HEIGHTS[0].y)
			radii[0] = rng.randf_range(RADII[0].x, RADII[0].y)
			centers[0] = Vector2.ZERO
			# 最初の平地は、最初の山の南のふもとに広がる（ここがスタート地点）
			var length := rng.randf_range(PLAIN_LENGTH.x, PLAIN_LENGTH.y)
			plain_ends[0] = Vector2(0.0, radii[0])
			plain_starts[0] = plain_ends[0] + Vector2(0.0, length)
			continue
		bases[i] = peaks[i - 1] - rng.randf_range(40.0, 60.0)
		peaks[i] = bases[i] + rng.randf_range(HEIGHTS[i].x, HEIGHTS[i].y)
		radii[i] = rng.randf_range(RADII[i].x, RADII[i].y)
		heading = clampf(heading + rng.randf_range(-0.35, 0.35), -0.45, 0.45)
		var direction := Vector2(sin(heading), -cos(heading))
		# ひとつ前の山の裏の斜面が、このステージの平地の高さまで下りてきた所から、平地が始まる
		var previous_reach := _reach(i - 1, bases[i])
		plain_starts[i] = centers[i - 1] + direction * previous_reach
		plain_ends[i] = plain_starts[i] + direction * rng.randf_range(PLAIN_LENGTH.x, PLAIN_LENGTH.y)
		centers[i] = plain_ends[i] + direction * radii[i]
	for i in COUNT:
		sub_peaks[i] = _first_mountain_peaks() if i == 0 else _make_sub_peaks(i, rng)
		spurs[i] = _make_spurs(rng)


## 主峰から張り出す尾根（5〜8 本、向きはばらばら、強さと鋭さもばらばら）
static func _make_spurs(rng: RandomNumberGenerator) -> Array:
	var result := []
	var count := rng.randi_range(5, 8)
	var start := rng.randf() * TAU
	for k in count:
		var angle := start + k * TAU / count + rng.randf_range(-0.3, 0.3)
		result.append([angle, rng.randf_range(0.22, 0.42), rng.randf_range(6.0, 16.0)])
	return result


## 向き angle での主峰の広がりの倍率：尾根の向きでは外へ張り出し、尾根と尾根の間（沢）ではくびれる
static func _spur_stretch(i: int, angle: float) -> float:
	var stretch := -0.14
	for spur: Array in spurs[i]:
		stretch += float(spur[1]) * pow(maxf(cos(angle - float(spur[0])), 0.0), float(spur[2]))
	return 1.0 + stretch


## 最初の山の肩・前山（FIRST_MOUNTAIN のとおりに置く）
static func _first_mountain_peaks() -> Array:
	var result := []
	for entry: Array in FIRST_MOUNTAIN:
		var angle := deg_to_rad(entry[0])
		var center := centers[0] + Vector2(cos(angle), sin(angle)) * radii[0] * float(entry[1])
		result.append([center, bases[0] + (peaks[0] - bases[0]) * float(entry[2]), radii[0] * float(entry[3])])
	return result


## 主峰のまわりに、肩（高い衛星峰）と前山（裾の低い山）を散らす。
## 次の平地へ下りる側と、頂上の平らな場所の上には置かない
static func _make_sub_peaks(i: int, rng: RandomNumberGenerator) -> Array:
	var result := []
	var toward_next := (plain_starts[i + 1] - centers[i]).normalized() if i + 1 < COUNT else Vector2.ZERO
	var count := rng.randi_range(SUB_PEAKS.x, SUB_PEAKS.y)
	var height := peaks[i] - bases[i]
	for attempt in 80:
		if result.size() >= count:
			break
		var angle := rng.randf() * TAU
		var direction := Vector2(cos(angle), sin(angle))
		if toward_next != Vector2.ZERO and direction.dot(toward_next) > cos(0.7):
			continue
		var along := rng.randf_range(0.3, 0.95)
		var foothill := along > 0.72
		var radius := radii[i] * (rng.randf_range(0.22, 0.34) if foothill else rng.randf_range(0.3, 0.48))
		radius = minf(radius, along * radii[i] - 14.0)  # 頂上の平らな場所にかからない
		if radius < 16.0:
			continue
		var top := bases[i] + height * (rng.randf_range(0.15, 0.38) if foothill else rng.randf_range(0.45, 0.8))
		result.append([centers[i] + direction * radii[i] * along, top, radius])
	return result


## 山 i の、岩のでこぼこをつける前の高さ：主峰と、肩・前山を重ねた山塊
static func cone(i: int, x: float, z: float) -> float:
	var p := Vector2(x, z)
	var offset := p - centers[i]
	var stretch := _spur_stretch(i, atan2(offset.y, offset.x)) if not spurs[i].is_empty() else 1.0
	var h := _peak(p, centers[i], peaks[i], radii[i] * stretch, bases[i])
	if p.distance_to(centers[i]) > radii[i] * SPREAD + 20.0:
		return h
	for sub: Array in sub_peaks[i]:
		h = maxf(h, _peak(p, sub[0], sub[1], sub[2], bases[i]))
	return h


## ひとつの峰の高さ。釣鐘の形（裾はゆるやかに立ち上がり、中腹は急で、頂上は丸い）。
## 裾から外は、はじめはゆるく、だんだん急に落ち込む
static func _peak(p: Vector2, center: Vector2, top: float, radius: float, base: float) -> float:
	var d := p.distance_to(center)
	if d < radius:
		var t := 1.0 - d / radius
		return base + (top - base) * lerpf(t * t * (3.0 - 2.0 * t), t, 0.15)
	var out := d - radius
	return base - out * SIDE_DROP * smoothstep(0.0, 12.0, out)


## 山 i の主峰の斜面が、高さ height まで下りてくる中心からの距離
static func _reach(i: int, height: float) -> float:
	var low := 0.0
	var high := radii[i]
	for n in 24:
		var mid := (low + high) * 0.5
		if _peak(centers[i] + Vector2(mid, 0.0), centers[i], peaks[i], radii[i], bases[i]) > height:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


## ステージ i の平地だけがあったときの高さ（平地の上は裾の高さ、ふちから外は落ち込む）。
## 2 つめからの平地は、始まり（霧の境目）より手前へは広がらず、そこで切れ落ちる
static func plain(i: int, x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := _segment_distance(p, plain_starts[i], plain_ends[i])
	var out := maxf(d - PLAIN_HALF_WIDTH, 0.0)
	if i > 0:
		out = maxf(out, -(p - plain_starts[i]).dot(gate_direction(i)))
	return bases[i] - out * SIDE_DROP * smoothstep(0.0, 10.0, out)  # ふちは丸く落ち込む


## ステージ i の平地と山のまわりの、崖の下の谷底の高さ。最初のステージは、ふもとの低地そのもの
static func valley_floor(i: int) -> float:
	return 0.0 if i == 0 else bases[i] - VALLEY_DEPTH


## ステージ i の平地と主峰の裾から、横にどれだけ離れているか（上にいれば 0 以下）
static func stage_distance(i: int, x: float, z: float) -> float:
	var p := Vector2(x, z)
	var to_plain := _segment_distance(p, plain_starts[i], plain_ends[i]) - PLAIN_HALF_WIDTH
	var to_mountain := p.distance_to(centers[i]) - radii[i]
	return minf(to_plain, to_mountain)


## ステージ i の平地と、前山まで含めた山の広がりから、横にどれだけ離れているか（地形を細かく作る範囲を決める）
static func core_distance(i: int, x: float, z: float) -> float:
	var p := Vector2(x, z)
	var to_plain := _segment_distance(p, plain_starts[i], plain_ends[i]) - PLAIN_HALF_WIDTH
	var to_mountain := p.distance_to(centers[i]) - radii[i] * SPREAD
	return minf(to_plain, to_mountain)


## 霧の境目 k（1〜COUNT-1）の位置：ステージ k-1 の山頂のすぐ先の、ステージ k の平地の始まり
static func gate_point(k: int) -> Vector2:
	return plain_starts[k]


## 霧の境目 k から、霧の奥へ向かう向き（ステージ k の平地の向き）
static func gate_direction(k: int) -> Vector2:
	return (plain_ends[k] - plain_starts[k]).normalized()


## 霧の境目 k から、どれだけ奥（霧の側）にいるか (m)。手前なら負
static func past_gate(k: int, x: float, z: float) -> float:
	return (Vector2(x, z) - gate_point(k)).dot(gate_direction(k))


## その場所が、どのステージの霧の奥にあるか（最初のステージの側なら 0）
static func gate_stage(x: float, z: float) -> int:
	var stage := 0
	for k in range(1, COUNT):
		if past_gate(k, x, z) > 0.0:
			stage = k
	return stage


## その場所がどのステージのものか（重み）。境目ではなめらかに混ざる。count を省くと、いま現れているステージだけで決める
static func weights(x: float, z: float, height: float, count := -1) -> PackedFloat32Array:
	var n := unlocked if count < 0 else count
	var values := PackedFloat32Array()
	values.resize(COUNT)
	var best := -INF
	for i in n:
		values[i] = maxf(cone(i, x, z), plain(i, x, z))
		best = maxf(best, values[i])
	var total := 0.0
	for i in COUNT:
		values[i] = exp((values[i] - best) / BLEND) if i < n else 0.0
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


## ステージ i（平地と山）が占める範囲。ふちから谷底へ落ち込む崖と、そのまわりの谷底も含める（置き物を探す範囲）
static func stage_rect(i: int, margin := 0.0) -> Rect2:
	var drop := (bases[i] - valley_floor(i) + 20.0) / SIDE_DROP + APRON + margin
	if i == 0:
		drop = (20.0 / SIDE_DROP) + APRON * 2.0 + margin  # 最初のステージのまわりは、樹海の低地が広がる
	return _stage_area(i).grow(drop)


## ステージ i の平地と、前山まで含めた山の範囲
static func _stage_area(i: int) -> Rect2:
	var rect := Rect2(centers[i], Vector2.ZERO).grow(radii[i] * SPREAD)
	rect = rect.merge(Rect2(plain_starts[i], Vector2.ZERO).grow(PLAIN_HALF_WIDTH))
	return rect.merge(Rect2(plain_ends[i], Vector2.ZERO).grow(PLAIN_HALF_WIDTH))


## 地形を細かく作りうる範囲（すべてのステージの stage_rect が入る）
static func detail_bounds() -> Rect2:
	var rect := stage_rect(0, 14.0)
	for i in range(1, COUNT):
		rect = rect.merge(stage_rect(i, 14.0))
	return rect


## 地形の広さ：すべてのステージと、そのまわりの山すそがふもとの低地まで下りきる範囲
static func bounds() -> Rect2:
	var rect := detail_bounds()
	for i in range(1, COUNT):
		var foot := APRON + (valley_floor(i) + 16.0) / FOOT_SLOPE + 14.0
		rect = rect.merge(_stage_area(i).grow(foot))
	return rect.grow(OUTSKIRTS)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
