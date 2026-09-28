class_name Terrain
extends Node3D
## 4 つのステージ（MountainChain）の地形を、遊ぶたびに乱数から作る。
## どのステージも、凸凹だらけの平地の先に、主峰と肩・前山が重なった高い山塊がそびえる。
## 山肌は大小の丸いこぶが隙間なく盛り上がり、その間を尾根と溝と割れ目（クレバス）が走る。
## 平らに休める所はほとんどない。丸い大岩が山肌のあちこちに埋まっていて、こぶと同じく手がかりにも障害にもなる。
## 雪山の平地には、雪で隠れた深い穴（隠れクレバス）もある。
##
## 平地のふちは崖で、その下の谷底から先は、山すそがふもとの低地まで下っていく
## （山並み全体がひとつながりの大地で、宙に浮いた所はない）。
## すべてのステージは最初から地形になっている。まだ行けないステージは濃い霧（FogBanks）に隠れていて、
## 山頂に着くと霧が晴れる。ステージの平地と山のまわりは細かく作り、遠くの山すそは粗く作る。
## 高さの計算と形づくりは、CPU のいくつものスレッドで手分けして行う。

const CELL := 1.0              # 頂点の間隔 (m)
const WARP := 18.0             # 山の輪郭をゆがめる量 (m)
const RIDGE := 4.0             # ゆるやかな尾根と溝の深さ (m)。ステージごとの倍率（MountainChain.ROUGHNESS）をかける
const CRAG := 1.5              # 岩のこぶ (m)
const DOME := 18.0             # 山肌や平地に散らばる、丸いこぶの高さ (m)
const SMALL_DOME := 6.0        # その上に重なる、小さなこぶの高さ (m)
const BLOBS_PER_MOUNTAIN := [320, 340, 360, 380]  # 山肌を埋めつくす、巨大な丸い岩の突起（山はほとんど、これでできている）
const BLOB_SIZE := Vector2(7.0, 17.0)  # 丸い岩の突起の半径 (m)。高い所ほど、さらに大きくする
const BIG := 10  # 巨大な岩の突起を、ふつうの大岩と別にまとめるための印
const BLOB_NEAR := 200.0  # 巨大な岩を、これより遠くでは粗い形で描く (m)
const PILLARS_PER_MOUNTAIN := [12, 14, 14, 16]  # 丸い岩を積み上げた柱
const BOULDER_SPACING := 10.0  # 切り立った壁や急な斜面を、この間隔で巨大な丸い岩でおおう（壁の高さに合わせて、上下にも積む）(m)
const BOULDER_SIZE := Vector2(7.5, 14.5)  # 壁をおおう丸い岩の半径 (m)。高い所ほど、さらに大きくする
const BOULDER_MAX := 9000      # 山ひとつあたりの上限（途中で打ち切って、山の一部だけ岩がないことにならないよう、大きめに）
const GAP_SPACING := 5.0       # すき間うめ：この間隔で、まだ岩におおわれていない急な地面を探す (m)
const ARCHES_PER_MOUNTAIN := [6, 7, 7, 8]       # 天然の岩のアーチ
const HILLS := 30.0            # 地形のまわりのふもとの、大きな丘の高さ (m)
const KNOBS := 1.2             # こぶの上にも平らな所を残さない、小さな丸いでこぼこ (m)
const CRACK_WIDTH := 0.06      # 割れ目の幅（模様の値で）
const CRACK_DEPTH := 6.0       # 割れ目の深さ (m)
const PLAIN_BUMPS := [3.0, 2.2, 2.0, 2.5]  # 平地の大きな起伏 (m)。ステージごとに、ほかにも地形らしい凸凹を足す
const PLATEAU_RADIUS := 6.0    # 山頂の、たき火や祠を置く平らな場所の半径 (m)
const ROCKS_PER_MOUNTAIN := [220, 260, 300, 340]  # 山肌に埋まった丸い大岩（後ろのステージほど多い）
const PLAIN_ROCKS := [40, 120, 60, 70]            # 平地に転がる岩の数（岩場の荒れ地に多い）
const TILE := 36              # 見た目と当たり判定の区画の大きさ（頂点の間隔の数）
const FAR_STEP := 4           # 遠くの区画は、頂点を 4 つおきに間引いて描く
const VFAR_STEP := 12         # さらに遠くは、頂点を 12 おきに間引いて描く（区画の大きさ 36 を割り切れる数）
const VFAR_RANGE := 450.0     # 細かい所を含むまとまりは、中心からこれより遠いと、いちばん粗い形にする (m)
const VFAR_RANGE_COARSE := 750.0  # 遠くの山すその大きなまとまりは、中心からこれより遠いと、いちばん粗い形にする (m)
const GROUP := 3              # 平地と山の近くは、区画 3×3 個分の見た目をひとつにまとめる（メッシュの数を減らす）
const GROUP_RANGE := 150.0    # まとまりの中心からこれより遠いと、間引いた形に切り替える (m)
const FAR_MERGE := 3          # 遠くの山すその粗い区画は、3×3 個分をさらにひとつにまとめる
const ROCK_TILE := 160.0      # 大岩の見た目を、この大きさの区画ごとにまとめる (m)
const SKIRT := 4.0            # 間引いた区画のふちの「すそ」の深さ (m)
const COARSE_BLOCK := 6       # 遠くの山すそは、区画 6×6 個分をまとめて、ひとつの粗い区画にする
const ROCK_RANGE := 260.0     # 大岩をこれより遠くでは描かない (m)
const LANDINGS_PER_MOUNTAIN := [46, 46, 42, 36]  # 山肌に切り込んだ、小さな平らな岩棚（祠や慰霊碑、箱などが置いてある）
const LANDING_RADIUS := Vector2(3.2, 5.0)  # 岩棚の平らな所の半径 (m)
const LANDING_BLEND := 4.0     # 岩棚のまわりの、山肌へなじませる幅 (m)。山側は崖になり、谷側は切れ落ちる
const LANDING_CELL := 16.0     # 岩棚を探しやすく分けておく区画 (m)
# --- 島と海：最初の平地のうしろは砂浜で、その先は海（戻れない）。地形のふちも、海に沈む ---
const SEA_LEVEL := -1.5        # 海面の高さ
const SEA_FLOOR := -12.0       # 海の底
const BEACH_BEGIN := 8.0       # 最初の平地の入り口から、これだけうしろから砂浜になる (m)
const BEACH_SPAWN := 32.0      # スタート地点（墜落したヘリのそば）の、平地の入り口からのうしろへの距離 (m)
const COAST := Vector2(30.0, 100.0)     # 横の海岸：最初のステージ（樹海）の広がりから、この距離で海へ下りきる (m)
const COAST_LATER := Vector2(60.0, 200.0)  # 先のステージの広がりから、この距離で海へ下りきる（高い山すそは、海からそびえる）(m)
const PIT_COUNT := 6           # 雪山の隠れクレバスの数
const PIT_RADIUS := 2.2
const PIT_DEPTH := 11.0
const PIT_FIELD := 4.0         # 穴のまわりの、平らにならした雪原の幅 (m)。休めそうに見えて、実は罠
const ROCK_CELL := 16.0        # 大岩を探しやすく分けておく区画の大きさ (m)
const ROCK_BULGE := 1.12       # 岩の形のいびつさ（球の表面を、この倍率までふくらませる）
const ROCK_NOTE_MARGIN := 3.0  # 岩のまわりの、これだけの近さまでは、岩の区画の中で調べられる (m)。これより大きい近さは調べない
const CACHE_PATH := "user://terrain_%d.res"  # 作り終えた地形の保存先（山ごと）
const COLLISION_CELL := 108.0    # 当たり判定を探しやすく分けておく区画 (m)
const COLLISION_RADIUS := 110.0  # プレイヤーからこれより近い区画には、当たり判定を作っておく (m)
const ROCK_COLLISION_CELL := 40.0  # 壁をおおう巨大な岩の当たり判定を、この大きさの区画ごとにまとめ、近づいたときに作る (m)
const CACHE_SOURCES := ["res://scripts/terrain.gd", "res://scripts/mountain_chain.gd", "res://scripts/terrain_cache.gd"]


## ひとつの区画を作るための、スレッドで手分けする仕事
class TileJob:
	var rect: Rect2i
	var coarse := false
	var heights := PackedFloat32Array()   # 細かい区画：rect の中のすべての頂点の高さ
	var normals := PackedVector3Array()
	var near := []                        # メッシュの配列（細かい形）
	var far := []                         # メッシュの配列（間引いた形。粗い区画はこれだけ）
	var vfar := []                        # メッシュの配列（いちばん粗い形。とても遠くから見るとき）
	var faces := PackedVector3Array()     # 当たり判定の三角形（作るまで覚えておく）
	var area := Rect2()                   # 区画の広さ（x, z）
	var has_collision := false
	var parent: Node3D                    # 当たり判定の体を置く所（null なら地面。大岩なら、そのステージの岩のまとまり）


## 見た目と当たり判定をひとつにまとめる、いくつかの区画（GPU に作るメッシュの数を減らすため）
class GroupJob:
	var tiles: Array[TileJob] = []
	var near := []   # 細かい形（細かい区画を含むときだけ）
	var far := []    # 間引いた形
	var vfar := []   # いちばん粗い形
	var faces := PackedVector3Array()
	var near_mesh: Mesh  # 作ったメッシュ（保存しておき、次からはこれを使う）
	var far_mesh: Mesh
	var vfar_mesh: Mesh


var summit_position := Vector3.ZERO  # 最後の山（霊峰）の頂上
var watch: Node3D                    # 当たり判定を、この物（プレイヤー）のまわりに作っておく
var run_seed := 0
var pits := PackedVector3Array()     # 隠れクレバスの穴（x, z, ふちの高さ）。雪のふたは MountainFeatures がかぶせる
var overhangs := []                  # 大岩の下側の、張り出した所 [位置, 地帯]（つららを下げる）
var landings := PackedVector4Array()  # 山肌の岩棚 (x, z, 高さ, 半径)
var landing_stages := PackedInt32Array()  # 岩棚ごとの、どの山にあるか
var _landing_cells := {}              # 区画 → その区画にかかる岩棚の番号（PackedInt32Array）

var _warp_x := FastNoiseLite.new()
var _warp_z := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _crag := FastNoiseLite.new()
var _shelf := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _crack := FastNoiseLite.new()
var _bulge := FastNoiseLite.new()
var _knobs := FastNoiseLite.new()
var _domes := FastNoiseLite.new()        # 大きな丸いこぶ（点からの距離の模様）
var _small_domes := FastNoiseLite.new()  # 小さな丸いこぶ
var _outer := Rect2()        # 地形の広さ（MountainChain.bounds() を覚えておく）
var _origin := Vector2.ZERO  # 細かく作りうる範囲の北西の角（頂点の番号 0, 0）
var _count_x := 0
var _count_z := 0
var _heights := PackedFloat32Array()  # 頂点ごとの高さ（細かく作った所だけ。置き物を置く場所を探すのに使う）
var _normals := PackedVector3Array()
var _built := PackedByteArray()  # 頂点ごとに、細かく作ったか
var _grid_ready := false  # 細かい地面を作り終えた（height_at は、作った地面の三角形から高さを読む）
var _vertex_biomes := PackedByteArray()  # 頂点ごとの地帯（置き場所を探すときに、一度求めたら覚えておく。255 = まだ）
var _material: ShaderMaterial
var _body: StaticBody3D
var _rock_groups: Array[Node3D] = []  # ステージごとの大岩（まだ作っていない・消したステージは null）
var _rock_kit := {}                   # 岩の形と素材（_prepare_rocks）
var _faces_cache := {}                # 岩の形 → その三角形（岩ごとに作り直すと遅い）
var _collision_cells := {}            # 区画 → そこにかかるまとまり（当たり判定をまだ作っていないものを探す）
var _waiting: Array[TileJob] = []     # 当たり判定をまだ作っていない区画
var _stream_timer := 0.0
var _rock_cells := {}  # 区画 → その区画の大岩の [形の逆変換, 中心, 外側の半径, いちばん短い辺]（置き物を岩の中に埋めないため）


## 地形を作る（数秒かかるので、読み込み画面を出してから呼ぶ）。前に作った地形は消す。
## 作り終えたあとは、すべてのステージがあるものとして扱う（置き物を置くため）。遊び始めるときに begin_run() を呼ぶ
func build(seed_value: int) -> void:
	run_seed = seed_value
	for child in get_children():
		child.queue_free()
	_rock_groups.clear()
	_rock_groups.resize(MountainChain.COUNT)
	_faces_cache.clear()
	_rock_cells.clear()
	_grid_ready = false
	_vertex_biomes = PackedByteArray()
	MountainChain.generate(seed_value)
	MountainChain.unlocked = MountainChain.COUNT
	_outer = MountainChain.bounds()
	_setup_noise(seed_value)
	pits.clear()
	overhangs.clear()
	_plan_landings()
	_collision_cells.clear()
	_waiting.clear()
	# 前に作った同じ地形が保存してあれば、それを読む（なければ作って、保存しておく）
	var path := CACHE_PATH % seed_value
	var version := _cache_version()
	var cache := _load_cache(path, version)
	if cache:
		_restore(cache)
	else:
		_save_cache(path, version, _build_ground())
	_grid_ready = true
	_vertex_biomes.resize(_count_x * _count_z)
	_vertex_biomes.fill(255)
	ensure_collision(spawn_point(), COLLISION_RADIUS)
	_prepare_rocks()
	build_stage_rocks(0)  # ほかのステージの岩は、そのステージが現れるときに作る
	_build_sea()
	var start := MountainChain.plain_starts[0]
	_material.set_shader_parameter("beach_origin", start)
	_material.set_shader_parameter("beach_direction", (MountainChain.plain_ends[0] - start).normalized())
	summit_position = checkpoint(MountainChain.COUNT - 1)


## 最初のステージだけが霧の外にある状態で、遊び始める
func begin_run() -> void:
	MountainChain.unlocked = 1


## ステージ stage の霧が晴れた：そのステージの大岩を作る
func show_stage(stage: int) -> void:
	MountainChain.unlocked = maxi(MountainChain.unlocked, stage + 1)
	build_stage_rocks(stage)


## もう戻れないステージの大岩を消す（軽くするため）
func unload_stage(stage: int) -> void:
	if _rock_groups[stage] != null:
		var group := _rock_groups[stage]
		_waiting = _waiting.filter(func(job: TileJob) -> bool: return job.parent != group)
		for key: Vector2i in _collision_cells:
			_collision_cells[key] = (_collision_cells[key] as Array).filter(func(job: TileJob) -> bool: return job.parent != group)
		group.queue_free()
		_rock_groups[stage] = null


## ステージの大岩を作ってあるか
func has_stage(stage: int) -> bool:
	return _rock_groups[stage] != null


func _setup_noise(seed_value: int) -> void:
	var setups := [
		[_warp_x, 0.012, 2, FastNoiseLite.FRACTAL_FBM], [_warp_z, 0.012, 2, FastNoiseLite.FRACTAL_FBM],
		[_ridge, 0.02, 3, FastNoiseLite.FRACTAL_FBM], [_crag, 0.07, 2, FastNoiseLite.FRACTAL_FBM],
		[_shelf, 0.045, 1, FastNoiseLite.FRACTAL_NONE], [_hills, 0.02, 2, FastNoiseLite.FRACTAL_FBM],
		[_detail, 0.15, 1, FastNoiseLite.FRACTAL_NONE], [_crack, 0.016, 2, FastNoiseLite.FRACTAL_FBM],
		[_bulge, 0.035, 1, FastNoiseLite.FRACTAL_NONE], [_knobs, 0.16, 2, FastNoiseLite.FRACTAL_FBM],
		[_domes, 1.0 / 40.0, 1, FastNoiseLite.FRACTAL_NONE], [_small_domes, 1.0 / 16.0, 1, FastNoiseLite.FRACTAL_NONE],
	]
	for i in setups.size():
		var noise: FastNoiseLite = setups[i][0]
		noise.seed = seed_value + i * 101
		noise.frequency = setups[i][1]
		noise.fractal_octaves = setups[i][2]
		noise.fractal_type = setups[i][3]
	for noise: FastNoiseLite in [_domes, _small_domes]:
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE


## 丸い突起（0〜1）：散らばった点のまわりが、ふっくらした丸い頭の突起になる。となりの突起との間は、くびれた溝になる
func _dome(noise: FastNoiseLite, x: float, z: float) -> float:
	var d := clampf((noise.get_noise_2d(x, z) + 1.0) / 0.62, 0.0, 1.0)
	return pow(1.0 - d * d, 0.8)


## 地面の高さ。細かく作った所では、作った地面（当たり判定と同じ三角形）の上の高さを読む（速い）。
## それ以外（作っている最中や、遠くの山すそ）は、模様から計算する
func height_at(x: float, z: float) -> float:
	if _grid_ready:
		var gx := (x - _origin.x) / CELL
		var gz := (z - _origin.y) / CELL
		var xi := floori(gx)
		var zi := floori(gz)
		if xi >= 0 and zi >= 0 and xi < _count_x - 1 and zi < _count_z - 1:
			var i := zi * _count_x + xi
			if _built[i] == 1 and _built[i + 1] == 1 and _built[i + _count_x] == 1 and _built[i + _count_x + 1] == 1:
				# 升目は、右上と左下を結ぶ線で 2 つの三角形に分けてある（_grid_faces と同じ）
				var fx := gx - xi
				var fz := gz - zi
				if fx + fz <= 1.0:
					var a := _heights[i]
					return a + (_heights[i + 1] - a) * fx + (_heights[i + _count_x] - a) * fz
				var e := _heights[i + _count_x + 1]
				return e + (_heights[i + _count_x] - e) * (1.0 - fx) + (_heights[i + 1] - e) * (1.0 - fz)
	return _noise_height(x, z)


## 模様から計算する地面の高さ（いくつものスレッドから同時に呼ばれる。ここでは何も書きかえない）
func _noise_height(x: float, z: float) -> float:
	# 輪郭をゆがめてから、それぞれの山と平地の大まかな高さを出す
	var wx := x + _warp_x.get_noise_2d(x, z) * WARP
	var wz := z + _warp_z.get_noise_2d(x, z) * WARP
	var ridge := _ridge.get_noise_2d(wx, wz) * 1.3  # 丸みのある尾根と溝（とがった稜線にはしない）
	var crag := _crag.get_noise_2d(x, z) + _knobs.get_noise_2d(x, z) * KNOBS / CRAG
	var shelf_noise := _shelf.get_noise_2d(x, z)
	var dome := _dome(_domes, wx, wz)
	var small_dome := _dome(_small_domes, x, z)
	var mound := smoothstep(-0.2, 0.8, _bulge.get_noise_2d(wx, wz))  # 平地の、こんもりした小山
	# 割れ目：底が丸い U 字の溝
	var crack := 0.5 + 0.5 * cos(PI * minf(absf(_crack.get_noise_2d(wx, wz)) / CRACK_WIDTH, 1.0))
	var bumps := _hills.get_noise_2d(x, z)
	var hills := 2.0 + bumps * 2.5  # ふもとはゆるやかな起伏にして、ちゃんと歩けるようにする
	var knob := _knobs.get_noise_2d(x, z)
	var detail := 0.2 * _detail.get_noise_2d(x, z)
	# 崖の下の谷底と、その先の山すそ：近くのステージの谷底の高さを、ステージの境目でなめらかにつなぎ、
	# ステージから離れるほど、尾根と沢でうねりながら、ふもとの低地へ下っていく
	var distances := PackedFloat32Array()
	var nearest := INF
	for i in MountainChain.COUNT:
		var d := maxf(MountainChain.stage_distance(i, wx, wz), 0.0)
		distances.append(d)
		nearest = minf(nearest, d)
	var foot := 0.0
	var total := 0.0
	for i in MountainChain.COUNT:
		var weight := exp(-(distances[i] - nearest) / MountainChain.FOOT_BLEND)
		foot += weight * (MountainChain.valley_floor(i) - maxf(distances[i] - MountainChain.APRON, 0.0) * MountainChain.FOOT_SLOPE)
		total += weight
	var out := maxf(nearest - MountainChain.APRON, 0.0)
	var h := foot / total + bumps * 3.0 + (ridge * RIDGE + dome * DOME * 0.5) * smoothstep(0.0, 30.0, out)
	# ふもとの低地は、ステージから離れるほど大きな丘がうねる（地形の端に向かって、また低くなる）
	var edge := minf(minf(x - _outer.position.x, _outer.end.x - x), minf(z - _outer.position.y, _outer.end.y - z))
	hills += (bumps * 0.5 + 0.5 + dome * 0.4) * HILLS * smoothstep(60.0, 220.0, nearest) * smoothstep(0.0, 140.0, edge)
	for i in MountainChain.COUNT:
		# 平地：その地帯らしい凸凹だらけの、歩いて（ときにはよじ登って）進む土地
		var flat := MountainChain.plain(i, wx, wz)
		if flat > h - 30.0:
			h = maxf(h, flat + _plain_relief(i, bumps, mound, dome, small_dome, crack, knob, shelf_noise))
		var raw := MountainChain.cone(i, wx, wz)
		if raw > h - 80.0:
			var base: float = MountainChain.bases[i]
			var top: float = MountainChain.peaks[i] - MountainChain.PLATEAU
			# 頂上に近いほど、でこぼこを弱めて、たき火を置ける場所を残す
			var fade := 1.0 - smoothstep(0.9, 0.99, (raw - base) / (top - base))
			# 裾より下（平地に接する所）では、岩のでこぼこを平地に向かって弱める
			fade *= smoothstep(base - 6.0, base + 4.0, raw)
			var rough: float = MountainChain.ROUGHNESS[i]
			# 山肌の丸いこぶと割れ目（山の表面の大部分は、この上に埋めた巨大な丸い岩の突起がおおう）
			var elevation := clampf((raw - base) / (top - base), 0.0, 1.0)
			var lumps := ridge * RIDGE + (dome * DOME + small_dome * SMALL_DOME) * lerpf(0.5, 1.0, elevation) + crag * CRAG
			var v: float = raw + (lumps * rough - crack * CRACK_DEPTH * MountainChain.CRACKS[i]) * fade
			# 山頂の真ん中には、必ず平らな場所を作る（倒れたあと、たき火のそばから再開するため）
			var from_center := Vector2(x, z).distance_to(MountainChain.centers[i])
			v = lerpf(v, top, 1.0 - smoothstep(PLATEAU_RADIUS, PLATEAU_RADIUS + 4.0, from_center))
			h = maxf(h, minf(v, top))  # 頂上の平らな場所が、その山でいちばん高い
	var ground := _apply_landings(x, z, maxf(h, hills), small_dome * 0.9 + knob * 0.35) + detail
	return _apply_pits(x, z, maxf(_apply_coast(x, z, ground, bumps, edge), SEA_FLOOR))


## 島をかこむ海（大きな一枚の水面）
func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var area := _outer.grow(2500.0)
	plane.size = area.size
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	sea.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/psx_water.gdshader")
	var ripples := NoiseTexture2D.new()
	ripples.seamless = true
	ripples.width = 128
	ripples.height = 128
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	ripples.noise = noise
	material.set_shader_parameter("noise", ripples)
	sea.material_override = material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	sea.position = Vector3(area.get_center().x, SEA_LEVEL, area.get_center().y)


## 島の海岸：最初の平地のうしろは、ゆるやかに下る砂浜になり、波打ち際から先は海に沈む（海岸線は、うねらせる）。
## 横も、最初のステージ（樹海）から離れた低地は海に沈み、先のステージの高い山は、海からそびえ立つ。
## 地形のふちへ行くほど、海に沈む（島のまわりは、ぐるりと海）
func _apply_coast(x: float, z: float, h: float, wobble: float, edge: float) -> float:
	var reach := MountainChain.core_distance(0, x, z) + wobble * 25.0
	var reach_later := INF
	for i in range(1, MountainChain.COUNT):
		reach_later = minf(reach_later, MountainChain.core_distance(i, x, z))
	reach_later += wobble * 25.0
	h = lerpf(h, SEA_FLOOR, smoothstep(COAST.x, COAST.y, reach) * smoothstep(COAST_LATER.x, COAST_LATER.y, reach_later))
	var start := MountainChain.plain_starts[0]
	var toward := (MountainChain.plain_ends[0] - start).normalized()
	var behind := -(Vector2(x, z) - start).dot(toward) + wobble * 14.0
	if behind > BEACH_BEGIN:
		var sand := 1.2 + wobble * 0.3 - maxf(behind - 22.0, 0.0) * 0.05
		h = lerpf(h, sand, smoothstep(BEACH_BEGIN, BEACH_BEGIN + 14.0, behind))
		h = lerpf(h, SEA_FLOOR, smoothstep(62.0, 120.0, behind))
	return lerpf(h, SEA_FLOOR, 1.0 - smoothstep(30.0, 220.0, edge))


## 島の砂浜か（草木や置き物を置かない）
func is_beach(x: float, z: float) -> bool:
	var start := MountainChain.plain_starts[0]
	var toward := (MountainChain.plain_ends[0] - start).normalized()
	return -(Vector2(x, z) - start).dot(toward) > BEACH_BEGIN + 2.0


## 足もとが海の中か、どれだけ深いか（海面から海の底まで, m）。陸なら 0 以下
func sea_depth(x: float, z: float) -> float:
	return SEA_LEVEL - height_at(x, z)


## 平地の凸凹。ステージごとに違い、どれも激しい：
##   樹海：大きくうねる起伏と、こんもりした小山、丸い土の塚
##   岩場：段々になった岩の台地（高い段は、よじ登る）と、えぐれた溝、丸い岩のこぶ
##   雪山：大きくうねる雪の吹きだまりと、丸い雪の塚
##   霊峰：ごつごつした塚と、深い堀
func _plain_relief(stage: int, bumps: float, mound: float, dome: float, small_dome: float, crack: float, knob: float, shelf: float) -> float:
	var relief: float = bumps * PLAIN_BUMPS[stage]
	match stage:
		Biomes.Id.FOREST:
			relief += mound * 6.0 + small_dome * 2.5 + knob * 0.5
		Biomes.Id.CRAG:
			var terrace := floorf((shelf * 0.5 + 0.5) * 5.0) * 1.8  # 1.8 m ずつの段
			relief += terrace + small_dome * 2.0 + knob * 0.6 - crack * 4.5
		Biomes.Id.SNOW:
			relief += mound * 8.0 + dome * 3.0 + bumps * 1.5
		Biomes.Id.SUMMIT:
			relief += maxf(knob, 0.0) * 3.5 + small_dome * 3.0 + mound * 3.0 - crack * 3.5
	return relief


## 岩棚：山肌に切り込んだ、小さな平らな場所。まわりは山肌へなじませる（山側は崖、谷側は切れ落ちる）。
## 真っ平らにはせず、bumps のぶんだけ、ゆるやかなこぶを残す
func _apply_landings(x: float, z: float, h: float, bumps: float) -> float:
	var list: Variant = _landing_cells.get(Vector2i(floori(x / LANDING_CELL), floori(z / LANDING_CELL)))
	if list == null:
		return h
	for index: int in list:
		var landing := landings[index]
		var d := Vector2(x - landing.x, z - landing.y).length()
		if d < landing.w + LANDING_BLEND:
			h = lerpf(h, landing.z + bumps, 1.0 - smoothstep(landing.w, landing.w + LANDING_BLEND, d))
	return h


## 山ごとに、山肌のあちこちへ岩棚を切り込む場所を決める（頂上の近くと、ほかの岩棚の近くはさける）
func _plan_landings() -> void:
	landings.clear()
	landing_stages.clear()
	_landing_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + 17
	for i in MountainChain.COUNT:
		var c := MountainChain.centers[i]
		var spread: float = MountainChain.radii[i] * MountainChain.SPREAD
		var height: float = MountainChain.peaks[i] - MountainChain.bases[i]
		var placed := 0
		for attempt in LANDINGS_PER_MOUNTAIN[i] * 30:
			if placed >= LANDINGS_PER_MOUNTAIN[i]:
				break
			var angle := rng.randf() * TAU
			var distance := spread * sqrt(rng.randf_range(0.03, 0.85))
			var x := c.x + cos(angle) * distance
			var z := c.y + sin(angle) * distance
			var radius := rng.randf_range(LANDING_RADIUS.x, LANDING_RADIUS.y)
			if Vector2(x, z).distance_to(c) < PLATEAU_RADIUS + 14.0 or near_landing(x, z, radius + LANDING_BLEND + 14.0):
				continue
			var y := height_at(x, z)
			var elevation := (y - MountainChain.bases[i]) / height
			if elevation < 0.06 or elevation > 0.92 or _biome_of(Vector3(x, y, z)) != i:
				continue
			var index := landings.size()
			landings.append(Vector4(x, z, y, radius))
			landing_stages.append(i)
			var reach := radius + LANDING_BLEND
			for cz in range(floori((z - reach) / LANDING_CELL), floori((z + reach) / LANDING_CELL) + 1):
				for cx in range(floori((x - reach) / LANDING_CELL), floori((x + reach) / LANDING_CELL) + 1):
					var key := Vector2i(cx, cz)
					var list: PackedInt32Array = _landing_cells.get(key, PackedInt32Array())
					list.append(index)
					_landing_cells[key] = list
			placed += 1


## (x, z) から margin 以内に、岩棚（なじませる所も含む）がかかっているか
func near_landing(x: float, z: float, margin := 0.0) -> bool:
	var reach := maxf(margin, 0.0)
	if reach > LANDING_CELL * 2.0 or _landing_cells.is_empty():
		for landing in landings:
			if Vector2(x - landing.x, z - landing.y).length() < landing.w + LANDING_BLEND + margin:
				return true
		return false
	# 近くの区画にかかっている岩棚だけを調べる
	for cz in range(floori((z - reach) / LANDING_CELL), floori((z + reach) / LANDING_CELL) + 1):
		for cx in range(floori((x - reach) / LANDING_CELL), floori((x + reach) / LANDING_CELL) + 1):
			var list: Variant = _landing_cells.get(Vector2i(cx, cz))
			if list == null:
				continue
			for index: int in list:
				var landing := landings[index]
				if Vector2(x - landing.x, z - landing.y).length() < landing.w + LANDING_BLEND + margin:
					return true
	return false


## 隠れクレバス：平らな雪原の真ん中に、まっすぐ下へ落ちる深い穴
func _apply_pits(x: float, z: float, h: float) -> float:
	for pit in pits:
		var d := Vector2(x, z).distance_to(Vector2(pit.x, pit.y))
		if d < PIT_RADIUS + PIT_FIELD:
			h = lerpf(h, pit.z, 1.0 - smoothstep(PIT_RADIUS + 1.0, PIT_RADIUS + PIT_FIELD, d))
		if d < PIT_RADIUS:
			h = minf(h, pit.z - PIT_DEPTH * (1.0 - smoothstep(PIT_RADIUS * 0.75, PIT_RADIUS, d)))
	return h


## 山 i の頂上（たき火や祠を置く、平らな場所の真ん中）
func checkpoint(i: int) -> Vector3:
	var c := MountainChain.centers[i]
	return Vector3(c.x, height_at(c.x, c.y), c.y)


## スタート地点：最初のステージの平地の入り口
## スタート地点：島の砂浜。墜落したヘリのそばで、少し歩くと最初の平地に入る
func spawn_point() -> Vector3:
	var start := MountainChain.plain_starts[0]
	var toward := (MountainChain.plain_ends[0] - start).normalized()
	var p := start - toward * BEACH_SPAWN
	return Vector3(p.x, height_at(p.x, p.y) + 0.5, p.y)


## スタート地点で、山のほうを向く向き
func spawn_yaw() -> float:
	return _yaw_toward(MountainChain.plain_starts[0], MountainChain.centers[0])


## ステージ i の山の裾（平地の終わり）
func foot_point(i: int) -> Vector3:
	var p := MountainChain.plain_ends[i]
	return Vector3(p.x, height_at(p.x, p.y) + 0.5, p.y)


## 山の裾で、山のほうを向く向き
func foot_yaw(i: int) -> float:
	return _yaw_toward(MountainChain.plain_ends[i], MountainChain.centers[i])


func _yaw_toward(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)


## その場所が、どのステージの霧が晴れたら出てくるか（置き物を、霧が晴れるまで隠しておくため）。
## 霧の奥にある物と、霧の手前にはみ出した次のステージの地帯にある物は、そのステージまで隠す
func stage_of(pos: Vector3) -> int:
	return maxi(MountainChain.gate_stage(pos.x, pos.z), _biome_of(pos))


## 足場（ある程度平らな場所）から、ランダムに点を選ぶ。biome を指定すると、その地帯だけから選ぶ。
## すべてのステージがある地形から探す
func random_ledge_points(rng: RandomNumberGenerator, count: int, biome: int, spacing: float,
		flat_radius := 1, avoid := PackedVector3Array(), avoid_radius := 0.0, min_y := 1.0,
		min_normal_y := 0.85) -> PackedVector3Array:
	var result := PackedVector3Array()
	var area := _search_area(biome, flat_radius)
	var attempts := 0
	while result.size() < count and attempts < count * 800:
		attempts += 1
		var xi := rng.randi_range(area.position.x, area.end.x)
		var zi := rng.randi_range(area.position.y, area.end.y)
		if _built[zi * _count_x + xi] == 0:
			continue  # 細かく作っていない所（遠くの山すそ）
		var p := _vertex(xi, zi)
		if p.y < min_y or p.y < SEA_LEVEL + 1.2 or not _is_flat_area(xi, zi, flat_radius, min_normal_y):
			continue  # 低すぎる所（波打ち際）や、平らでない所には置かない
		if biome > 0 and p.y < MountainChain.bases[biome] - 10.0:
			continue  # 崖の下の谷底には置かない
		if _too_close(p, result, spacing) or _too_close(p, avoid, avoid_radius) or near_rock(p, 0.8) or is_beach(p.x, p.z):
			continue
		if biome >= 0 and _vertex_biome(xi, zi) != biome:
			continue  # （地帯を求めるのは重いので、最後に調べる）
		result.append(p)
	return result


## 切り立った崖の壁から、ランダムに点を選ぶ。[位置, 壁の外向き] の組の配列を返す
func random_wall_points(rng: RandomNumberGenerator, count: int, biome: int, spacing: float) -> Array:
	var result := []
	var positions := PackedVector3Array()
	var area := _search_area(biome, 1)
	var attempts := 0
	while result.size() < count and attempts < count * 800:
		attempts += 1
		var xi := rng.randi_range(area.position.x, area.end.x)
		var zi := rng.randi_range(area.position.y, area.end.y)
		if _built[zi * _count_x + xi] == 0:
			continue
		var p := _vertex(xi, zi)
		var normal := _normals[zi * _count_x + xi]
		if p.y < 8.0 or normal.y > 0.35 or (biome > 0 and p.y < MountainChain.bases[biome] - 10.0) or _vertex_biome(xi, zi) != biome:
			continue
		if _too_close(p, positions, spacing) or near_rock(p, 0.5):
			continue
		result.append([p, normal])
		positions.append(p)
	return result


## 頂点の地帯（一度求めたら覚えておく）
func _vertex_biome(xi: int, zi: int) -> int:
	if _vertex_biomes.size() != _count_x * _count_z:
		return _biome_of(_vertex(xi, zi))  # 地面を作っている最中（まだ覚えておく場所がない）
	var index := zi * _count_x + xi
	if _vertex_biomes[index] == 255:
		_vertex_biomes[index] = _biome_of(_vertex(xi, zi))
	return _vertex_biomes[index]


## すべてのステージがあるときの地帯（置き物の置き場所を決めるとき用）
func _biome_of(p: Vector3) -> int:
	var w := MountainChain.weights(p.x, p.z, p.y, MountainChain.COUNT)
	var best := 0
	for i in w.size():
		if w[i] > w[best]:
			best = i
	return best


## 探す範囲（頂点の番号）。地帯を指定したら、そのステージの平地と山のまわりだけを探す
func _search_area(biome: int, margin: int) -> Rect2i:
	var whole := Rect2i(margin, margin, _count_x - 1 - margin * 2, _count_z - 1 - margin * 2)
	if biome < 0 or biome >= MountainChain.COUNT:
		return whole
	return _vertex_rect(MountainChain.stage_rect(biome)).intersection(whole)


func _vertex_rect(rect: Rect2) -> Rect2i:
	var corner := Vector2i(floori((rect.position.x - _origin.x) / CELL), floori((rect.position.y - _origin.y) / CELL))
	var size := Vector2i(ceili(rect.size.x / CELL) + 1, ceili(rect.size.y / CELL) + 1)
	return Rect2i(corner, size).intersection(Rect2i(0, 0, _count_x, _count_z))


func normal_at(x: float, z: float) -> Vector3:
	var e := 0.5
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()


func _vertex(xi: int, zi: int) -> Vector3:
	return Vector3(_origin.x + xi * CELL, _heights[zi * _count_x + xi], _origin.y + zi * CELL)


func _is_flat_area(xi: int, zi: int, radius: int, min_normal_y: float) -> bool:
	var stride := maxi(radius / 2, 1)
	for dz in range(-radius, radius + 1, stride):
		for dx in range(-radius, radius + 1, stride):
			if _normals[(zi + dz) * _count_x + xi + dx].y < min_normal_y:
				return false
	return true


## 横の距離で比べる（高さが違っても、真上・真下は近いとみなす）
func _too_close(p: Vector3, points: PackedVector3Array, distance: float) -> bool:
	if distance <= 0.0:
		return false
	for q in points:
		if Vector2(p.x - q.x, p.z - q.z).length() < distance:
			return true
	return false


# --- 地面 ---

## ステージの平地と山のまわりは、頂点ごとに高さを求めて細かく作る。
## そこから離れた山すそは、区画をまとめて、間引いた頂点だけで粗く作る。
## 重い計算（高さ・向き・メッシュの配列）はスレッドで手分けし、ノードを作るのだけをここで行う
func _build_ground() -> Array[GroupJob]:
	var block := TILE * COARSE_BLOCK
	var area := MountainChain.detail_bounds()
	_origin = area.position
	var blocks_x := ceili(area.size.x / (block * CELL))
	var blocks_z := ceili(area.size.y / (block * CELL))
	_count_x = blocks_x * block + 1
	_count_z = blocks_z * block + 1
	var total := _count_x * _count_z
	_heights = PackedFloat32Array()
	_heights.resize(total)
	_normals = PackedVector3Array()
	_normals.resize(total)
	_built.resize(total)
	_built.fill(0)

	# 区画を分ける：平地と山の近くは細かく、それ以外（遠くの山すそ）は粗く。見た目は、いくつかの区画ごとにまとめる
	var detailed: Array[TileJob] = []
	var groups: Array[GroupJob] = []
	var outer := MountainChain.bounds()
	var block_size := block * CELL
	var bx0 := floori((outer.position.x - _origin.x) / block_size)
	var bx1 := ceili((outer.end.x - _origin.x) / block_size)
	var bz0 := floori((outer.position.y - _origin.y) / block_size)
	var bz1 := ceili((outer.end.y - _origin.y) / block_size)
	var tile_reach := TILE * CELL * 0.72 + MountainChain.DETAIL_MARGIN
	var block_reach := block_size * 0.72 + MountainChain.DETAIL_MARGIN
	var far_groups := {}  # 遠くの粗い区画のまとまり（FAR_MERGE × FAR_MERGE 個ずつ）
	for bz in range(bz0, bz1):
		for bx in range(bx0, bx1):
			var x0 := bx * block
			var z0 := bz * block
			var inside := bx >= 0 and bx < blocks_x and bz >= 0 and bz < blocks_z
			if not inside or _core_distance(x0 + block / 2, z0 + block / 2) > block_reach:
				var key := Vector2i(floori(float(bx) / FAR_MERGE), floori(float(bz) / FAR_MERGE))
				if not far_groups.has(key):
					far_groups[key] = GroupJob.new()
					groups.append(far_groups[key])
				(far_groups[key] as GroupJob).tiles.append(_job(Rect2i(x0, z0, block + 1, block + 1), true))
				continue
			for gz in range(0, COARSE_BLOCK, GROUP):
				for gx in range(0, COARSE_BLOCK, GROUP):
					var group := GroupJob.new()
					for tz in range(gz, gz + GROUP):
						for tx in range(gx, gx + GROUP):
							var rect := Rect2i(x0 + tx * TILE, z0 + tz * TILE, TILE + 1, TILE + 1)
							var near := _core_distance(rect.position.x + TILE / 2, rect.position.y + TILE / 2) < tile_reach
							var job := _job(rect, not near)
							group.tiles.append(job)
							if near:
								detailed.append(job)
					groups.append(group)

	# 細かい区画の高さ → 向き（スレッドで手分けして、できたものをここでまとめる）
	_run_parallel(detailed, _job_heights)
	for job in detailed:
		_store(job.rect, job.heights, _heights)
		for zi in range(job.rect.position.y, job.rect.end.y):
			for xi in range(job.rect.position.x, job.rect.end.x):
				_built[zi * _count_x + xi] = 1
	_run_parallel(detailed, _job_normals)
	for job in detailed:
		_store_normals(job.rect, job.normals)
		job.heights = PackedFloat32Array()
		job.normals = PackedVector3Array()
	_carve_pits()

	# 見た目と当たり判定の配列（スレッド）→ ノード（ここ）
	_run_parallel(groups, _job_group)
	_material = Psx.terrain_material()
	_body = StaticBody3D.new()
	add_child(_body)
	for group in groups:
		_add_group_nodes(group)
	_add_outer_ground()
	return groups


# --- 作り終えた地形の保存 ---

## 地形を作るスクリプトの中身から決める版（書きかえると変わり、保存した地形は使われなくなる）
func _cache_version() -> String:
	var text := ""
	for source: String in CACHE_SOURCES:
		text += (load(source) as Script).source_code
	return str(text.hash())


func _load_cache(path: String, version: String) -> TerrainCache:
	if not FileAccess.file_exists(path):
		return null
	var cache := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as TerrainCache
	if cache == null or cache.version != version:
		return null
	return cache


func _save_cache(path: String, version: String, groups: Array[GroupJob]) -> void:
	var cache := TerrainCache.new()
	cache.version = version
	cache.origin = _origin
	cache.count_x = _count_x
	cache.count_z = _count_z
	cache.heights = _heights
	cache.built = _built
	cache.pits = pits
	for group in groups:
		var rects := []
		var coarse := []
		var grids := []
		for job in group.tiles:
			rects.append(job.rect)
			coarse.append(job.coarse)
			grids.append(job.heights if job.coarse else PackedFloat32Array())
		cache.groups.append({"near": group.near_mesh, "far": group.far_mesh, "vfar": group.vfar_mesh, "rects": rects, "coarse": coarse, "grids": grids})
	var error := ResourceSaver.save(cache, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_warning("地形を保存できませんでした (%d)" % error)


## 保存してあった地形を読む。頂点の向きと当たり判定は、高さから作り直す
func _restore(cache: TerrainCache) -> void:
	_origin = cache.origin
	_count_x = cache.count_x
	_count_z = cache.count_z
	_heights = cache.heights
	_built = cache.built
	pits = cache.pits
	_normals = PackedVector3Array()
	_normals.resize(_count_x * _count_z)
	var groups: Array[GroupJob] = []
	var detailed: Array[TileJob] = []
	for entry: Dictionary in cache.groups:
		var group := GroupJob.new()
		group.near_mesh = entry["near"]
		group.far_mesh = entry["far"]
		group.vfar_mesh = entry.get("vfar")
		var rects: Array = entry["rects"]
		for k in rects.size():
			var job := _job(rects[k], entry["coarse"][k])
			if job.coarse:
				job.heights = entry["grids"][k]
			else:
				detailed.append(job)
			group.tiles.append(job)
		groups.append(group)
	_run_parallel(detailed, _job_normals)
	for job in detailed:
		_store_normals(job.rect, job.normals)
		job.normals = PackedVector3Array()
	_run_parallel(groups, _job_group_faces)
	_material = Psx.terrain_material()
	_body = StaticBody3D.new()
	add_child(_body)
	for group in groups:
		_add_group_nodes(group)
	_add_outer_ground()


## （スレッド）まとまりの中の区画の当たり判定だけを、高さから作る
func _job_group_faces(group: GroupJob) -> void:
	for job in group.tiles:
		var step := FAR_STEP if job.coarse else 1
		var xs := _steps(job.rect.position.x, job.rect.end.x - 1, step)
		var zs := _steps(job.rect.position.y, job.rect.end.y - 1, step)
		job.faces = _grid_faces(xs, zs, job.heights if job.coarse else _gather_heights(xs, zs))


func _job(rect: Rect2i, is_coarse: bool) -> TileJob:
	var job := TileJob.new()
	job.rect = rect
	job.coarse = is_coarse
	return job


## 頂点 (xi, zi) が、いちばん近いステージの平地と山の広がりから、どれだけ離れているか (m)
func _core_distance(xi: int, zi: int) -> float:
	var x := _origin.x + xi * CELL
	var z := _origin.y + zi * CELL
	var best := INF
	for i in MountainChain.COUNT:
		best = minf(best, MountainChain.core_distance(i, x, z))
	return best


## 仕事をスレッドで手分けして片づけ、全部終わるまで待つ
func _run_parallel(jobs: Array, work: Callable) -> void:
	if jobs.is_empty():
		return
	var task := WorkerThreadPool.add_group_task(func(index: int) -> void: work.call(jobs[index]), jobs.size(), -1, true)
	WorkerThreadPool.wait_for_group_task_completion(task)


## （スレッド）細かい区画の、すべての頂点の高さ
func _job_heights(job: TileJob) -> void:
	var heights := PackedFloat32Array()
	heights.resize(job.rect.size.x * job.rect.size.y)
	var k := 0
	for zi in range(job.rect.position.y, job.rect.end.y):
		for xi in range(job.rect.position.x, job.rect.end.x):
			heights[k] = height_at(_origin.x + xi * CELL, _origin.y + zi * CELL)
			k += 1
	job.heights = heights


## （スレッド）細かい区画の、すべての頂点の向き。細かく作っていないとなりの頂点は、その場で高さを求める
func _job_normals(job: TileJob) -> void:
	var normals := PackedVector3Array()
	normals.resize(job.rect.size.x * job.rect.size.y)
	var k := 0
	for zi in range(job.rect.position.y, job.rect.end.y):
		for xi in range(job.rect.position.x, job.rect.end.x):
			normals[k] = _normal_of(xi, zi)
			k += 1
	job.normals = normals


func _normal_of(xi: int, zi: int) -> Vector3:
	var left := _height_of(maxi(xi - 1, 0), zi)
	var right := _height_of(mini(xi + 1, _count_x - 1), zi)
	var back := _height_of(xi, maxi(zi - 1, 0))
	var front := _height_of(xi, mini(zi + 1, _count_z - 1))
	return Vector3(left - right, 2.0 * CELL, back - front).normalized()


func _height_of(xi: int, zi: int) -> float:
	var i := zi * _count_x + xi
	if _built[i] == 1:
		return _heights[i]
	return height_at(_origin.x + xi * CELL, _origin.y + zi * CELL)


## （スレッド）区画の見た目と当たり判定の配列。細かい区画は求めてある高さから、粗い区画はその場で高さを求めて作る
func _job_meshes(job: TileJob) -> void:
	if job.coarse:
		_coarse_meshes(job)
		return
	var xs := _steps(job.rect.position.x, job.rect.end.x - 1, 1)
	var zs := _steps(job.rect.position.y, job.rect.end.y - 1, 1)
	var heights := _gather_heights(xs, zs)
	job.near = _grid_arrays(xs, zs, heights, _gather_normals(xs, zs), 0.0)
	job.faces = _grid_faces(xs, zs, heights)
	var far_xs := _steps(job.rect.position.x, job.rect.end.x - 1, FAR_STEP)
	var far_zs := _steps(job.rect.position.y, job.rect.end.y - 1, FAR_STEP)
	job.far = _grid_arrays(far_xs, far_zs, _gather_heights(far_xs, far_zs), _gather_normals(far_xs, far_zs), SKIRT)
	var vfar_xs := _steps(job.rect.position.x, job.rect.end.x - 1, VFAR_STEP)
	var vfar_zs := _steps(job.rect.position.y, job.rect.end.y - 1, VFAR_STEP)
	job.vfar = _grid_arrays(vfar_xs, vfar_zs, _gather_heights(vfar_xs, vfar_zs), _gather_normals(vfar_xs, vfar_zs), SKIRT * 3.0)


func _gather_heights(xs: Array[int], zs: Array[int]) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for zi in zs:
		for xi in xs:
			result.append(_heights[zi * _count_x + xi])
	return result


func _gather_normals(xs: Array[int], zs: Array[int]) -> PackedVector3Array:
	var result := PackedVector3Array()
	for zi in zs:
		for xi in xs:
			result.append(_normals[zi * _count_x + xi])
	return result


## （スレッド）粗い区画：FAR_STEP 個おきの頂点だけ高さを求める。一回り外側の高さも求めて、ふちでも光がなめらかにつながるようにする
func _coarse_meshes(job: TileJob) -> void:
	var xs := _steps(job.rect.position.x, job.rect.end.x - 1, FAR_STEP)
	var zs := _steps(job.rect.position.y, job.rect.end.y - 1, FAR_STEP)
	var gx: Array[int] = [xs[0] - FAR_STEP]
	gx.append_array(xs)
	gx.append(xs[xs.size() - 1] + FAR_STEP)
	var gz: Array[int] = [zs[0] - FAR_STEP]
	gz.append_array(zs)
	gz.append(zs[zs.size() - 1] + FAR_STEP)
	var w := gx.size()
	var grid := PackedFloat32Array()
	for zi in gz:
		for xi in gx:
			grid.append(height_at(_origin.x + xi * CELL, _origin.y + zi * CELL))
	var heights := PackedFloat32Array()
	var normals := PackedVector3Array()
	for r in range(1, gz.size() - 1):
		for c in range(1, w - 1):
			heights.append(grid[r * w + c])
			var dx := float(gx[c + 1] - gx[c - 1]) * CELL
			var dz := float(gz[r + 1] - gz[r - 1]) * CELL
			var slope_x := (grid[r * w + c - 1] - grid[r * w + c + 1]) / dx
			var slope_z := (grid[(r - 1) * w + c] - grid[(r + 1) * w + c]) / dz
			normals.append(Vector3(slope_x, 1.0, slope_z).normalized())
	job.far = _grid_arrays(xs, zs, heights, normals, SKIRT)
	# いちばん粗い形：間引いた頂点を、さらに VFAR_STEP ごとに拾う
	var pick_x: Array[int] = []
	var pick_z: Array[int] = []
	var vxs: Array[int] = []
	var vzs: Array[int] = []
	for c in xs.size():
		if (xs[c] - xs[0]) % VFAR_STEP == 0 or c == xs.size() - 1:
			pick_x.append(c)
			vxs.append(xs[c])
	for r in zs.size():
		if (zs[r] - zs[0]) % VFAR_STEP == 0 or r == zs.size() - 1:
			pick_z.append(r)
			vzs.append(zs[r])
	var vheights := PackedFloat32Array()
	var vnormals := PackedVector3Array()
	for r: int in pick_z:
		for c: int in pick_x:
			vheights.append(heights[r * xs.size() + c])
			vnormals.append(normals[r * xs.size() + c])
	job.vfar = _grid_arrays(vxs, vzs, vheights, vnormals, SKIRT * 3.0)
	job.faces = _grid_faces(xs, zs, heights)
	job.heights = heights  # 保存しておき、次からは当たり判定をここから作る


## （スレッド）まとまりの中の区画の形を作り、ひとつの配列にまとめる。
## 細かい形には、細かい区画の細かい形と、粗い区画の形を入れる。間引いた形には、すべての区画の間引いた形を入れる
func _job_group(group: GroupJob) -> void:
	var near_parts := []
	var far_parts := []
	var vfar_parts := []
	var detailed := false
	for job in group.tiles:
		_job_meshes(job)
		if job.coarse:
			near_parts.append(job.far)
		else:
			near_parts.append(job.near)
			detailed = true
		far_parts.append(job.far)
		vfar_parts.append(job.vfar)
		job.near = []
		job.far = []
		job.vfar = []
	group.far = _merge_arrays(far_parts)
	group.vfar = _merge_arrays(vfar_parts)
	if detailed:
		group.near = _merge_arrays(near_parts)


## いくつかのメッシュの配列を、ひとつにつなげる
func _merge_arrays(parts: Array) -> Array:
	if parts.size() == 1:
		return parts[0]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for part: Array in parts:
		var offset := vertices.size()
		vertices.append_array(part[Mesh.ARRAY_VERTEX])
		normals.append_array(part[Mesh.ARRAY_NORMAL])
		colors.append_array(part[Mesh.ARRAY_COLOR])
		uvs.append_array(part[Mesh.ARRAY_TEX_UV])
		var part_indices: PackedInt32Array = part[Mesh.ARRAY_INDEX]
		var start := indices.size()
		indices.append_array(part_indices)
		for k in range(start, indices.size()):
			indices[k] += offset
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## まとまりのノード（見た目と当たり判定）を作る。細かい形は近くでだけ、間引いた形は遠くでだけ描く
func _add_group_nodes(group: GroupJob) -> void:
	if group.far_mesh == null:
		group.far_mesh = _array_mesh(group.far)
	if group.near_mesh == null and not group.near.is_empty():
		group.near_mesh = _array_mesh(group.near)
	if group.vfar_mesh == null and not group.vfar.is_empty():
		group.vfar_mesh = _array_mesh(group.vfar)
	var far := MeshInstance3D.new()
	far.mesh = group.far_mesh
	far.material_override = _material
	if group.vfar_mesh:
		# とても遠くは、いちばん粗い形で描く（島全体を細かく描くと、三角形が多すぎて重い）
		var vfar := MeshInstance3D.new()
		vfar.mesh = group.vfar_mesh
		vfar.material_override = _material
		var switch := VFAR_RANGE if group.near_mesh else VFAR_RANGE_COARSE
		vfar.visibility_range_begin = switch
		vfar.visibility_range_begin_margin = 20.0
		vfar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(vfar)
		far.visibility_range_end = switch
		far.visibility_range_end_margin = 20.0
	if group.near_mesh:
		var near := MeshInstance3D.new()
		near.mesh = group.near_mesh
		near.material_override = _material
		near.visibility_range_end = GROUP_RANGE
		near.visibility_range_end_margin = 10.0
		add_child(near)
		far.visibility_range_begin = GROUP_RANGE
		far.visibility_range_begin_margin = 10.0
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # 遠くの影は描かない
	add_child(far)
	group.near = []
	group.far = []
	group.vfar = []
	# 当たり判定は、区画ごとに、プレイヤーが近づいたときに作る（全部を一度に作ると、とても時間がかかる）
	for job in group.tiles:
		job.area = Rect2(_origin + Vector2(job.rect.position) * CELL, Vector2(job.rect.size - Vector2i.ONE) * CELL)
		_queue_collision(job)


## 当たり判定をまだ作っていない区画として覚える（プレイヤーが近づいたら作る）
func _queue_collision(job: TileJob) -> void:
	var c0 := Vector2i((job.area.position / COLLISION_CELL).floor())
	var c1 := Vector2i((job.area.end / COLLISION_CELL).floor())
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var key := Vector2i(cx, cz)
			if not _collision_cells.has(key):
				_collision_cells[key] = []
			(_collision_cells[key] as Array).append(job)
	_waiting.append(job)


## 地面そのもの（大岩や置き物をのぞく）の当たり判定の体（区画ごとの体は、この子にある）
func ground_body() -> StaticBody3D:
	return _body


## 区画の当たり判定を作る
func _build_collision(job: TileJob) -> void:
	if job.has_collision:
		return
	job.has_collision = true
	if job.parent != null and not is_instance_valid(job.parent):
		_waiting.erase(job)  # その大岩は、もう消えた
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(job.faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	# 区画ごとに別の体にする（ひとつの体に形をどんどん足すと、足すたびに体全体を作り直すので、歩くたびに引っかかる）
	var body := StaticBody3D.new()
	body.collision_layer = _body.collision_layer
	body.collision_mask = _body.collision_mask
	body.add_child(collision)
	(job.parent if job.parent != null else _body).add_child(body)
	job.faces = PackedVector3Array()
	_waiting.erase(job)


## pos から radius 以内にかかるまとまりの当たり判定を、いますぐ作る（プレイヤーを遠くへ置く前に呼ぶ）
func ensure_collision(pos: Vector3, radius := 30.0) -> void:
	var point := Vector2(pos.x, pos.z)
	for job in _waiting.duplicate():
		if job.area.grow(radius).has_point(point):
			_build_collision(job)


## すべてのまとまりの当たり判定を作る（テストで、遠くの地面を調べるとき）
func ensure_all_collision() -> void:
	for job in _waiting.duplicate():
		_build_collision(job)


func _physics_process(delta: float) -> void:
	if watch == null or _waiting.is_empty():
		return
	var pos := watch.global_position
	# 足もとのまとまりは、すぐに作る（遠くへ飛ばされたときにも、地面を突き抜けないように）
	var key := Vector2i((Vector2(pos.x, pos.z) / COLLISION_CELL).floor())
	for job: TileJob in _collision_cells.get(key, []):
		if not job.has_collision and job.area.grow(8.0).has_point(Vector2(pos.x, pos.z)):
			_build_collision(job)
	# まわりのまとまりは、いちばん近いものから少しずつ作る
	_stream_timer -= delta
	if _stream_timer > 0.0:
		return
	_stream_timer = 0.12
	var point := Vector2(pos.x, pos.z)
	var nearest: TileJob = null
	var best := COLLISION_RADIUS
	for job in _waiting:
		var gap := maxf(job.area.get_center().distance_to(point) - job.area.size.length() * 0.5, 0.0)
		if gap < best:
			best = gap
			nearest = job
	if nearest:
		_build_collision(nearest)


func _array_mesh(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## rect の中の値を、全体の配列の該当する場所へ書き写す
func _store(rect: Rect2i, values: PackedFloat32Array, into: PackedFloat32Array) -> void:
	var k := 0
	for zi in range(rect.position.y, rect.end.y):
		for xi in range(rect.position.x, rect.end.x):
			into[zi * _count_x + xi] = values[k]
			k += 1


func _store_normals(rect: Rect2i, values: PackedVector3Array) -> void:
	var k := 0
	for zi in range(rect.position.y, rect.end.y):
		for xi in range(rect.position.x, rect.end.x):
			_normals[zi * _count_x + xi] = values[k]
			k += 1


## from から to までの頂点の番号を、step 個おきに（最後の頂点は必ず入れる）
func _steps(from: int, to: int, step: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(from, to + 1, step):
		result.append(i)
	if result[result.size() - 1] != to:
		result.append(to)
	return result


## 頂点の格子（xs × zs の高さと向き）から、地形のメッシュの配列を作る。
## skirt（深さ, m）が 0 より大きければ、ふちに下向きの「すそ」をつけて、となりの区画とのすき間から空が見えないようにする
func _grid_arrays(xs: Array[int], zs: Array[int], heights: PackedFloat32Array, grid_normals: PackedVector3Array, skirt: float) -> Array:
	var vertices := PackedVector3Array()
	var normals := grid_normals.duplicate()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var k := 0
	for zi in zs:
		for xi in xs:
			var pos := Vector3(_origin.x + xi * CELL, heights[k], _origin.y + zi * CELL)
			vertices.append(pos)
			# 頂点の色 = 4 つの地帯の重み（地形のシェーダーが、これで素材を混ぜる）
			var w := MountainChain.weights(pos.x, pos.z, pos.y, MountainChain.COUNT)
			colors.append(Color(w[0], w[1], w[2], w[3]))
			uvs.append(Vector2(0.85 + 0.15 * _detail.get_noise_2d(pos.x * 1.5, pos.z * 1.5), 0.0))
			k += 1
	var w := xs.size()
	for r in zs.size() - 1:
		for c in w - 1:
			var i := r * w + c
			indices.append_array([i, i + 1, i + w, i + 1, i + w + 1, i + w])
	if skirt > 0.0:
		# すそ：ふちの頂点を下へ伸ばした帯
		var edges := [[], [], [], []]
		for c in w:
			edges[0].append(c)
			edges[1].append((zs.size() - 1) * w + c)
		for r in zs.size():
			edges[2].append(r * w)
			edges[3].append(r * w + w - 1)
		for edge: Array in edges:
			var base := vertices.size()
			for index: int in edge:
				vertices.append(vertices[index] - Vector3.UP * skirt)
				normals.append(normals[index])
				colors.append(colors[index])
				uvs.append(uvs[index])
			for n in edge.size() - 1:
				var top_a: int = edge[n]
				var top_b: int = edge[n + 1]
				indices.append_array([top_a, top_b, base + n, top_b, base + n + 1, base + n])
				indices.append_array([top_a, base + n, top_b, top_b, base + n, base + n + 1])  # 裏からも見えるように
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## 頂点の格子（xs × zs の高さ）から、当たり判定の三角形を作る
func _grid_faces(xs: Array[int], zs: Array[int], heights: PackedFloat32Array) -> PackedVector3Array:
	var w := xs.size()
	var faces := PackedVector3Array()
	faces.resize((w - 1) * (zs.size() - 1) * 6)
	var k := 0
	for r in zs.size() - 1:
		var z_a := _origin.y + zs[r] * CELL
		var z_b := _origin.y + zs[r + 1] * CELL
		for c in w - 1:
			var x_a := _origin.x + xs[c] * CELL
			var x_b := _origin.x + xs[c + 1] * CELL
			var a := Vector3(x_a, heights[r * w + c], z_a)
			var b := Vector3(x_b, heights[r * w + c + 1], z_a)
			var d := Vector3(x_a, heights[(r + 1) * w + c], z_b)
			var e := Vector3(x_b, heights[(r + 1) * w + c + 1], z_b)
			faces[k] = a
			faces[k + 1] = b
			faces[k + 2] = d
			faces[k + 3] = b
			faces[k + 4] = e
			faces[k + 5] = d
			k += 6
	return faces


## 地形の外側に広がる地面（端から落ちないように）
func _add_outer_ground() -> void:
	# 地形の外は海（_build_sea）。万一地形を突き抜けたときのために、海の底より下に見えない床を敷いておく
	var area := MountainChain.bounds()
	var size := maxf(area.size.x, area.size.y) + 1400.0
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	var collision := CollisionShape3D.new()
	collision.shape = box
	var body := StaticBody3D.new()
	var center := area.get_center()
	body.position = Vector3(center.x, SEA_FLOOR - 1.5, center.y)
	body.add_child(collision)
	add_child(body)


## 雪山のなだらかな場所（おもに雪原の平地）に、隠れクレバスの穴をあける（上から雪のふたをかぶせて隠す）
func _carve_pits() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + 13
	var spots := random_ledge_points(rng, PIT_COUNT, Biomes.Id.SNOW, 18.0, 1, PackedVector3Array([checkpoint(Biomes.Id.SNOW)]), 14.0, 20.0, 0.72)
	for spot in spots:
		pits.append(Vector3(spot.x, spot.z, spot.y + 0.05))
	var whole := Rect2i(0, 0, _count_x, _count_z)
	for pit in pits:
		var reach := PIT_RADIUS + PIT_FIELD + CELL * 2.0
		var rect := _vertex_rect(Rect2(pit.x - reach, pit.y - reach, reach * 2.0, reach * 2.0))
		for zi in range(rect.position.y, rect.end.y):
			for xi in range(rect.position.x, rect.end.x):
				var i := zi * _count_x + xi
				_heights[i] = height_at(_origin.x + xi * CELL, _origin.y + zi * CELL)
				_built[i] = 1
		var around := rect.grow(1).intersection(whole)
		for zi in range(around.position.y, around.end.y):
			for xi in range(around.position.x, around.end.x):
				_normals[zi * _count_x + xi] = _normal_of(xi, zi)


func _near_pit(x: float, z: float, margin: float) -> bool:
	for pit in pits:
		if Vector2(x, z).distance_to(Vector2(pit.x, pit.y)) < PIT_RADIUS + PIT_FIELD + margin:
			return true
	return false


# --- 山肌に埋まった丸い大岩 ---

## 岩の形と素材を用意する（どのステージの岩も、これを使い回す）
func _prepare_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + 7
	var shapes: Array[ArrayMesh] = []
	for s in 8:
		shapes.append(_rock_shape(rng))
	var blobs: Array[ArrayMesh] = []
	var blobs_far: Array[ArrayMesh] = []
	var blobs_solid: Array[ArrayMesh] = []
	for s in 6:
		var lump_seed := rng.randi()
		blobs.append(blob_shape(22, 13, lump_seed))  # 近くで見ても、輪郭が角ばらないように細かく
		blobs_far.append(blob_shape(12, 7, lump_seed))
		blobs_solid.append(blob_shape(14, 9, lump_seed))  # 当たり判定は、少し粗い形で（作るのが速い）
	var chunks: Array[ArrayMesh] = []  # 壁をおおう丸い塊
	var chunks_solid: Array[ArrayMesh] = []
	var chunks_far: Array[ArrayMesh] = []
	for s in 6:
		var lump_seed := rng.randi()
		chunks.append(blob_shape(18, 11, lump_seed))
		chunks_far.append(blob_shape(10, 6, lump_seed))
		chunks_solid.append(blob_shape(12, 8, lump_seed))
	var arch := _arch_shape(rng)
	# 地帯ごとの岩：樹海は苔むした黒い岩（上は苔）、岩場は花崗岩（上は砂ぼこり）、雪山は霜の岩（上は雪）、霊峰は玄武岩（上は灰）
	var looks := [["rock_forest", "moss_top", 0.9], ["rock_crag", "dust_top", 0.45], ["rock_snow", "snow_top", 1.0], ["rock_summit", "ash_top", 0.5]]
	var materials := []
	for biome in looks.size():
		var rock_material := Psx.material(looks[biome][0], Color.WHITE, 0.3, 1.0)
		rock_material.set_shader_parameter("top_texture", Psx.texture(looks[biome][1]))
		rock_material.set_shader_parameter("top_amount", looks[biome][2])
		rock_material.set_shader_parameter("macro_variation", 0.3)
		rock_material.set_shader_parameter("flat_shading", false)  # なめらかに陰影をつけて、丸い岩に見せる
		rock_material.set_shader_parameter("underside_dark", 0.62)  # 岩の下側は暗く（重なった岩のすき間が、深い影になる）
		materials.append(rock_material)
	_rock_kit = {"shapes": shapes, "blobs": blobs, "blobs_far": blobs_far, "blobs_solid": blobs_solid, "chunks": chunks, "chunks_far": chunks_far,
		"chunks_solid": chunks_solid, "arch": arch, "materials": materials}


## ステージ i の岩を作る（そのステージが霧の中から現れるときに作る）。丸い岩の形を何種類か使い、山肌に向きも大きさも
## ばらばらに埋める（半分ほど埋まり、丸い頭が突き出る）。平地にも、その地帯らしく岩を転がす（岩場の荒れ地に多い）。
## 雪山の大きな岩の下側は張り出しになるので、つららを下げる場所として覚えておく。
## 乱数はステージごとなので、いつ作っても同じ岩になる。次のステージの霧の境目の先には置かない（ステージごとに消すため）
func build_stage_rocks(i: int) -> void:
	if _rock_groups[i] != null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + 7 + (i + 1) * 7919
	var shapes: Array = _rock_kit["shapes"]
	var blobs: Array = _rock_kit["blobs"]
	var blobs_far: Array = _rock_kit["blobs_far"]
	var chunks: Array = _rock_kit["chunks"]
	var chunks_far: Array = _rock_kit["chunks_far"]
	var blobs_solid: Array = _rock_kit["blobs_solid"]
	var chunks_solid: Array = _rock_kit["chunks_solid"]
	var arch: ArrayMesh = _rock_kit["arch"]
	var materials: Array = _rock_kit["materials"]
	var tile_size := ROCK_TILE
	var group := Node3D.new()
	add_child(group)
	_rock_groups[i] = group
	var body := StaticBody3D.new()
	group.add_child(body)
	var tools := {}  # [区画, 地帯] → その区画の岩をまとめたメッシュ（区画ごとに分けて、見えない所は描かない）
	var c := MountainChain.centers[i]
	var spread: float = MountainChain.radii[i] * MountainChain.SPREAD
	var plain_count: int = PLAIN_ROCKS[i]
	var rock_count: int = ROCKS_PER_MOUNTAIN[i]
	for n in rock_count + plain_count:
		var on_plain := n >= rock_count
		var x: float
		var z: float
		if on_plain:
			var along := MountainChain.plain_starts[i].lerp(MountainChain.plain_ends[i], rng.randf())
			var side := (MountainChain.plain_ends[i] - MountainChain.plain_starts[i]).normalized().orthogonal()
			var p := along + side * rng.randf_range(-1.0, 1.0) * MountainChain.PLAIN_HALF_WIDTH * 0.9
			x = p.x
			z = p.y
		else:
			var angle := rng.randf() * TAU
			var distance := spread * sqrt(rng.randf_range(0.02, 0.9))
			x = c.x + cos(angle) * distance
			z = c.y + sin(angle) * distance
		var ground := Vector3(x, height_at(x, z), z)
		if ground.distance_to(checkpoint(i)) < 10.0 or _near_pit(x, z, 5.0) or stage_of(ground) != i:
			continue  # 頂上のたき火のまわりと、隠れクレバスの上はあけておく
		if on_plain and ground.y < MountainChain.bases[i] - 12.0:
			continue  # 平地のふちの崖の下には置かない
		if i == 0 and on_plain and Vector2(x, z).distance_to(MountainChain.plain_starts[0]) < 16.0:
			continue  # スタート地点のまわりもあけておく
		var normal := normal_at(x, z)
		var s := rng.randf_range(1.2, 3.8) if on_plain else rng.randf_range(2.0, 7.5)
		if not on_plain and near_landing(x, z, s * 0.6):
			continue  # 岩棚はふさがない
		var size := Vector3(s * rng.randf_range(0.8, 1.25), s * rng.randf_range(0.7, 1.2), s * rng.randf_range(0.8, 1.25))
		var rock_basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var center := ground - normal * size.y * 0.2  # 半分ほど埋める
		var xform := Transform3D(rock_basis * Basis.from_scale(size), center)
		_note_rock(xform, size)
		var shape_mesh: ArrayMesh = shapes[rng.randi() % shapes.size()]
		var biome := _biome_of(ground)
		var key := Vector3i(floori(center.x / tile_size), floori(center.z / tile_size), biome)
		if not tools.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = tool
		(tools[key] as SurfaceTool).append_from(shape_mesh, 0, xform)
		if biome == Biomes.Id.SNOW and not on_plain and s > 3.5 and normal.y < 0.7:
			# 急な斜面の大岩の、谷側の下の張り出し
			var outward := Vector3(normal.x, 0.0, normal.z).normalized()
			overhangs.append([center + outward * size.x * 0.35 - Vector3.UP * size.y * 0.3, biome])
		var collision := CollisionShape3D.new()
		var faces := shape_mesh.get_faces()
		for f in faces.size():
			faces[f] = xform * faces[f]
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(faces)
		concave.backface_collision = true
		collision.shape = concave
		body.add_child(collision)
	# 巨大な丸い岩の突起：山肌に半分ほど埋め、隙間なく並べる（高い所ほど大きい）。よじ登れる
	var height: float = MountainChain.peaks[i] - MountainChain.bases[i]
	var toward_next := (MountainChain.plain_starts[i + 1] - c).normalized() if i + 1 < MountainChain.COUNT else Vector2.ZERO
	for n in BLOBS_PER_MOUNTAIN[i]:
		var angle := rng.randf() * TAU
		var direction := Vector2(cos(angle), sin(angle))
		var distance := spread * sqrt(rng.randf_range(0.0, 0.92))
		var x := c.x + direction.x * distance
		var z := c.y + direction.y * distance
		var ground := Vector3(x, height_at(x, z), z)
		var elevation := (ground.y - MountainChain.bases[i]) / height
		if elevation < 0.04 or elevation > 0.97 or _near_pit(x, z, 8.0) or stage_of(ground) != i:
			continue  # 平地と、頂上の平らな場所には置かない
		var r := rng.randf_range(BLOB_SIZE.x, BLOB_SIZE.y) * lerpf(0.8, 1.5, elevation)
		if Vector2(x, z).distance_to(c) < PLATEAU_RADIUS + r + 4.0 or near_landing(x, z, r * 1.05 - LANDING_BLEND):
			continue
		if toward_next != Vector2.ZERO and direction.dot(toward_next) > cos(0.4) and distance < spread * 0.8:
			continue  # 次の平地へ下りる斜面はあけておく
		var normal := normal_at(x, z)
		var size := Vector3(rng.randf_range(0.85, 1.15), rng.randf_range(0.75, 1.05), rng.randf_range(0.85, 1.15)) * r * 2.0
		var blob_basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		var center := ground - normal * r * rng.randf_range(0.25, 0.45)  # 半分以上を、山肌から突き出す
		if normal.y < 0.55 and rng.randf() < 0.3:
			center = ground + normal * r * 0.15 - Vector3.UP * r * 0.1  # 切り立った壁から、せり出したふくらみ（下はオーバーハング）
		var pick := rng.randi() % blobs.size()
		_add_big_rock(tools, body, blobs[pick], Transform3D(blob_basis * Basis.from_scale(size), center), size, ground, tile_size, true, blobs_far[pick] as ArrayMesh,
			blobs_solid[pick] as ArrayMesh)
	# 岩の柱：大小の丸い岩を積み上げた塔（よじ登って、てっぺんで休める）
	for n in PILLARS_PER_MOUNTAIN[i]:
		var angle := rng.randf() * TAU
		var distance := spread * sqrt(rng.randf_range(0.05, 0.85))
		var x := c.x + cos(angle) * distance
		var z := c.y + sin(angle) * distance
		var ground := Vector3(x, height_at(x, z), z)
		var elevation := (ground.y - MountainChain.bases[i]) / height
		if elevation < 0.03 or elevation > 0.8 or ground.distance_to(checkpoint(i)) < 25.0 or near_landing(x, z, 6.0) or stage_of(ground) != i:
			continue
		var r := rng.randf_range(3.0, 5.0)
		var point := ground - Vector3.UP * r * 0.4
		for level in rng.randi_range(3, 5):
			var size := Vector3(rng.randf_range(0.9, 1.1), rng.randf_range(0.8, 1.0), rng.randf_range(0.9, 1.1)) * r * 2.0
			var pick := rng.randi() % blobs.size()
			_add_big_rock(tools, body, blobs[pick], Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(size), point), size, ground, tile_size, true, blobs_far[pick] as ArrayMesh,
				blobs_solid[pick] as ArrayMesh)
			point += Vector3(rng.randf_range(-0.3, 0.3) * r, r * rng.randf_range(1.2, 1.5), rng.randf_range(-0.3, 0.3) * r)
			r *= rng.randf_range(0.7, 0.85)
	# 岩のアーチ：山肌に、くぐったり乗り越えたりできる天然の岩橋
	for n in ARCHES_PER_MOUNTAIN[i]:
		var angle := rng.randf() * TAU
		var distance := spread * sqrt(rng.randf_range(0.05, 0.8))
		var x := c.x + cos(angle) * distance
		var z := c.y + sin(angle) * distance
		var ground := Vector3(x, height_at(x, z), z)
		var elevation := (ground.y - MountainChain.bases[i]) / height
		if elevation < 0.02 or elevation > 0.75 or ground.distance_to(checkpoint(i)) < 25.0 or near_landing(x, z, 10.0) or stage_of(ground) != i:
			continue
		var normal := normal_at(x, z)
		var across := Vector3(-normal.z, 0.0, normal.x).normalized()  # 等高線に沿って架ける（両足の高さがそろう）
		if across.length() < 0.5:
			across = Vector3.RIGHT
		var span := rng.randf_range(5.0, 9.0)
		var arch_basis := Basis(across, Vector3.UP, across.cross(Vector3.UP)).scaled(Vector3(span, span * rng.randf_range(0.8, 1.2), span))
		var arch_center := ground - Vector3.UP * 1.0
		_add_big_rock(tools, body, arch, Transform3D(arch_basis, arch_center), Vector3.ONE * span * 2.0, ground, tile_size, false, arch)
	# 壁をおおう巨大な丸い岩：切り立った壁を、ふっくらした巨大な丸い岩の積み重なりに変える（ただの壁を残さない）。
	# 山全体を格子に区切り、壁にかかる升目には、壁の高さに合わせて上下に何段も積む（壁の面積に比例させる）
	var boulder_faces := {}  # 区画 → 当たり判定の三角形の配列（区画ごとにひとつの形にまとめる）
	var spawn := spawn_point()
	var boulders := 0
	# （山だけでなく、平地のふちの谷へ落ちこむ崖も含め、そのステージのすべての崖をおおう）
	var area := MountainChain.stage_rect(i)
	for gz in int(area.size.y / BOULDER_SPACING) + 1:
		for gx in int(area.size.x / BOULDER_SPACING) + 1:
			if boulders >= BOULDER_MAX:
				break
			var cx := area.position.x + gx * BOULDER_SPACING
			var cz := area.position.y + gz * BOULDER_SPACING
			# 升目の四すみと真ん中の高さから、いちばん低い所と高い所を探す。その差が大きい升目は、崖
			var low := Vector2.ZERO
			var high := Vector2.ZERO
			var low_h := INF
			var high_h := -INF
			for corner: Vector2 in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.5, 0.5)]:
				var q := Vector2(cx, cz) + corner * BOULDER_SPACING
				var qh := height_at(q.x, q.y)
				if qh < low_h:
					low_h = qh
					low = q
				if qh > high_h:
					high_h = qh
					high = q
			var rise := high_h - low_h
			var on_mountain := (high_h - MountainChain.bases[i]) / height > 0.04
			if on_mountain and rise < BOULDER_SPACING * 0.45:
				continue  # 山は、崖と急な斜面をすべて（地面の平たい壁が見えないように）
			if not on_mountain and rise < BOULDER_SPACING * 0.8 and (rise < BOULDER_SPACING * 0.5 or rng.randf() < 0.6):
				continue  # 平地は、崖だけ（歩いて進む凸凹は、そのまま）
			# 崖の高さに合わせて、下から上まで何段も積む
			var layers := clampi(roundi(rise / (BOULDER_SPACING * 0.85)), 1, 16)
			for layer in layers:
				if boulders >= BOULDER_MAX:
					break
				var target := low_h + (layer + rng.randf_range(0.2, 0.8)) / layers * rise
				var a := 0.0
				var b := 1.0
				for step in 7:  # 低い所と高い所を結ぶ線の上で、その高さになる所を探す
					var mid := (a + b) * 0.5
					var m := low.lerp(high, mid)
					if height_at(m.x, m.y) < target:
						a = mid
					else:
						b = mid
				var across := (high - low).normalized().orthogonal() if high != low else Vector2.RIGHT
				var spot := low.lerp(high, (a + b) * 0.5) + across * rng.randf_range(-0.35, 0.35) * BOULDER_SPACING  # 格子に並ばないように
				var x := spot.x
				var z := spot.y
				var ground := Vector3(x, height_at(x, z), z)
				var elevation := clampf((ground.y - MountainChain.bases[i]) / height, 0.0, 1.0)
				if elevation > 0.95 or _near_pit(x, z, 6.0) or stage_of(ground) != i:
					continue
				if Vector2(x, z).distance_to(Vector2(spawn.x, spawn.z)) < 30.0:
					continue  # スタート地点のまわりはあけておく
				var r := rng.randf_range(BOULDER_SIZE.x, BOULDER_SIZE.y) * lerpf(0.9, 1.25, elevation)
				if Vector2(x, z).distance_to(c) < PLATEAU_RADIUS + r + 4.0 or near_landing(x, z, r * 0.9 - LANDING_BLEND):
					continue
				var normal := normal_at(x, z)
				var size := Vector3(rng.randf_range(0.9, 1.15), rng.randf_range(0.8, 1.05), rng.randf_range(0.9, 1.15)) * r * 2.0
				var boulder_basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
				var center := ground + normal * r * rng.randf_range(-0.05, 0.3)  # 半分以上を、壁から突き出す
				var pick := rng.randi() % chunks.size()
				_add_big_rock(tools, body, chunks[pick], Transform3D(boulder_basis * Basis.from_scale(size), center), size, ground, tile_size, true, chunks_far[pick],
					chunks_solid[pick] as ArrayMesh, false, boulder_faces)  # 当たり判定は、同じ岩の少し粗い形で
				boulders += 1
	# すき間うめ：それでも岩におおわれずに見えている急な地面（平たい壁）にも、丸い岩を置く（山全体を、丸の集まりに見せる）
	for gz in int(area.size.y / GAP_SPACING) + 1:
		for gx in int(area.size.x / GAP_SPACING) + 1:
			if boulders >= BOULDER_MAX:
				break
			var x := area.position.x + (gx + rng.randf_range(0.2, 0.8)) * GAP_SPACING
			var z := area.position.y + (gz + rng.randf_range(0.2, 0.8)) * GAP_SPACING
			var normal := normal_at(x, z)
			if normal.y > 0.6:
				continue  # 急ではない（歩ける地面は、そのまま）
			var ground := Vector3(x, height_at(x, z), z)
			if near_rock(ground, 0.6) or stage_of(ground) != i or _near_pit(x, z, 6.0) or ground.y < SEA_LEVEL + 1.0:
				continue
			var elevation := (ground.y - MountainChain.bases[i]) / height
			if elevation < 0.04 or elevation > 0.95 or Vector2(x, z).distance_to(Vector2(spawn.x, spawn.z)) < 30.0:
				continue  # 平地（歩いて進む所）と、頂上の平らな場所には置かない
			var r := rng.randf_range(BOULDER_SIZE.x, BOULDER_SIZE.y) * 0.75
			if Vector2(x, z).distance_to(c) < PLATEAU_RADIUS + r + 4.0 or near_landing(x, z, r * 0.9 - LANDING_BLEND):
				continue
			var size := Vector3(rng.randf_range(0.9, 1.15), rng.randf_range(0.8, 1.05), rng.randf_range(0.9, 1.15)) * r * 2.0
			var gap_basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
			var pick := rng.randi() % chunks.size()
			_add_big_rock(tools, body, chunks[pick], Transform3D(gap_basis * Basis.from_scale(size), ground + normal * r * 0.2), size, ground, tile_size, true, chunks_far[pick],
				chunks_solid[pick] as ArrayMesh, false, boulder_faces)
			boulders += 1
	# 当たり判定は、区画ごとにまとめておき、プレイヤーが近づいたときに作る（ステージを作るときに全部作ると、とても時間がかかる）
	for key: Vector2i in boulder_faces:
		var job := TileJob.new()
		for part: PackedVector3Array in boulder_faces[key]:
			job.faces.append_array(part)
		job.parent = group
		job.area = Rect2(Vector2(key) * ROCK_COLLISION_CELL, Vector2.ONE * ROCK_COLLISION_CELL).grow(BOULDER_SIZE.y * 1.4)
		_queue_collision(job)
	if watch != null:
		ensure_collision(watch.global_position, 30.0)
	# 法線は、元の岩の形のものをそのまま使う（まとめてから作り直すと、とても時間がかかる）
	for key: Vector3i in tools:
		var tool: SurfaceTool = tools[key]
		var instance := MeshInstance3D.new()
		instance.mesh = tool.commit()
		instance.material_override = materials[key.z % BIG]
		if key.z >= BIG * 2:
			instance.visibility_range_begin = BLOB_NEAR  # 遠くの巨大な岩は、粗い形で
			instance.visibility_range_begin_margin = 10.0
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif key.z >= BIG:
			instance.visibility_range_end = BLOB_NEAR
			instance.visibility_range_end_margin = 10.0
		else:
			instance.visibility_range_end = ROCK_RANGE
		group.add_child(instance)


## 巨大な岩（丸い突起・柱・アーチ）の見た目と当たり判定を足す。note なら、置き物を埋めないように覚えておく
## collision_mesh を渡すと、当たり判定はその（面の少ない）形で作る。overhang なら、雪山で下側のつららの場所として覚える
func _add_big_rock(tools: Dictionary, body: StaticBody3D, mesh: ArrayMesh, xform: Transform3D, size: Vector3, ground: Vector3, tile_size: float, note := true, far_mesh: ArrayMesh = null,
		collision_mesh: ArrayMesh = null, overhang := true, merge_into: Variant = null) -> void:
	if note:
		_note_rock(xform, size)
	var biome := _biome_of(ground)
	# 大きいので、遠くからも見せる（近くは細かい形、遠くは粗い形）
	for level in [[mesh, BIG], [far_mesh, BIG * 2]]:
		if level[0] == null:
			continue
		var key := Vector3i(floori(xform.origin.x / tile_size), floori(xform.origin.z / tile_size), biome + int(level[1]))
		if not tools.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = tool
		(tools[key] as SurfaceTool).append_from(level[0], 0, xform)
	var normal := normal_at(ground.x, ground.z)
	if overhang and biome == Biomes.Id.SNOW and normal.y < 0.7:
		var outward := Vector3(normal.x, 0.0, normal.z).normalized()
		overhangs.append([xform.origin + outward * size.x * 0.4 - Vector3.UP * size.y * 0.25, biome])
	var source := collision_mesh if collision_mesh else mesh
	if not _faces_cache.has(source.get_instance_id()):
		_faces_cache[source.get_instance_id()] = source.get_faces()
	var faces: PackedVector3Array = xform * (_faces_cache[source.get_instance_id()] as PackedVector3Array)
	if merge_into is Dictionary:
		# 当たり判定は、区画ごとにまとめて、あとでひとつの形にする（merge_into: 区画 → 三角形の配列の配列）
		var cell := Vector2i(floori(xform.origin.x / ROCK_COLLISION_CELL), floori(xform.origin.z / ROCK_COLLISION_CELL))
		# （配列は、あとでまとめてつなぐ。ここでつなぐと、増えた配列を毎回まるごと写すので、とても遅い）
		if not merge_into.has(cell):
			merge_into[cell] = []
		(merge_into[cell] as Array).append(faces)
		return
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	concave.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = concave
	body.add_child(collision)


## 岩のアーチの形（幅 2、高さ 1 の半円の輪。太さはうねる）
func _arch_shape(rng: RandomNumberGenerator) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 18
	var sides := 9
	var points: Array[PackedVector3Array] = []
	for k in rings + 1:
		var theta := PI * k / rings
		var center := Vector3(cos(theta), sin(theta), 0.0)
		var tangent := Vector3(-sin(theta), cos(theta), 0.0)
		var outward := center.normalized()
		var side := tangent.cross(outward).normalized()
		var thickness := 0.22 * (1.0 + 0.35 * sin(theta)) * rng.randf_range(0.9, 1.1)  # 足元は太く、まん中は少し細く
		if k == 0 or k == rings:
			thickness *= 1.6
		var ring := PackedVector3Array()
		for s in sides:
			var a := TAU * s / sides
			ring.append(center + (outward * cos(a) + side * sin(a)) * thickness * rng.randf_range(0.88, 1.12))
		points.append(ring)
	for k in rings:
		for s in sides:
			var a := points[k][s]
			var b := points[k][(s + 1) % sides]
			var c := points[k + 1][s]
			var d := points[k + 1][(s + 1) % sides]
			for v in [a, c, b, b, c, d]:
				tool.add_vertex(v)
	tool.index()
	tool.generate_normals()
	return tool.commit()


## 置いた大岩を覚えておく（形は、大きさ 1 の球を xform でのばしたもの）
func _note_rock(xform: Transform3D, size: Vector3) -> void:
	var radius := maxf(size.x, maxf(size.y, size.z)) * 0.5 * ROCK_BULGE
	var entry := [xform.affine_inverse(), xform.origin, radius, minf(size.x, minf(size.y, size.z))]
	# 岩がかかる区画すべてに入れる（調べるときに、まわりの区画まで見なくてすむ）
	var reach := radius + ROCK_NOTE_MARGIN
	for cz in range(floori((xform.origin.z - reach) / ROCK_CELL), floori((xform.origin.z + reach) / ROCK_CELL) + 1):
		for cx in range(floori((xform.origin.x - reach) / ROCK_CELL), floori((xform.origin.x + reach) / ROCK_CELL) + 1):
			var key := Vector2i(cx, cz)
			if not _rock_cells.has(key):
				_rock_cells[key] = []
			_rock_cells[key].append(entry)


## p が大岩の中か、岩の表面から margin 以内か（置き物や、テストで人を置く場所が、岩に埋まらないように）
func near_rock(p: Vector3, margin := 0.5) -> bool:
	if margin > ROCK_NOTE_MARGIN:
		# 遠くまで調べるときは、まわりの区画も見る
		var extra := ceili((margin - ROCK_NOTE_MARGIN) / ROCK_CELL)
		var seen := {}
		for dz in range(-extra, extra + 1):
			for dx in range(-extra, extra + 1):
				for rock: Array in _rock_cells.get(Vector2i(floori(p.x / ROCK_CELL) + dx, floori(p.z / ROCK_CELL) + dz), []):
					if seen.has(rock[1]):
						continue
					seen[rock[1]] = true
					if p.distance_to(rock[1]) <= float(rock[2]) + margin and ((rock[0] as Transform3D) * p).length() < 0.5 * ROCK_BULGE + margin / (rock[3] as float):
						return true
		return false
	for rock: Array in _rock_cells.get(Vector2i(floori(p.x / ROCK_CELL), floori(p.z / ROCK_CELL)), []):
		if p.distance_squared_to(rock[1]) > (float(rock[2]) + margin) * (float(rock[2]) + margin):
			continue
		# 岩の形（のばした球）の中で、表面からの近さを大まかに比べる
		var local := (rock[0] as Transform3D) * p
		if local.length() < 0.5 * ROCK_BULGE + margin / (rock[3] as float):
			return true
	return false


## p が大岩の奥深くに埋まっているか（表面のでこぼこでは、まちがえない深さ）
func inside_rock(p: Vector3) -> bool:
	for rock: Array in _rock_cells.get(Vector2i(floori(p.x / ROCK_CELL), floori(p.z / ROCK_CELL)), []):
		if p.distance_to(rock[1]) < rock[2] and ((rock[0] as Transform3D) * p).length() < 0.3:
			return true
	return false


## 巨大な丸い岩の突起の形（大きさ 1）：ふっくらした丸い塊に、ゆるやかなうねりと、ところどころの小さなこぶ。
## 同じ lump_seed なら、面の数がちがっても同じ形になる（遠くで使う粗い形と、近くで使う細かい形）
static func blob_shape(segments := 14, rings := 9, lump_seed := 0) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = segments
	sphere.rings = rings
	var data := sphere.get_mesh_arrays()
	var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	# なめらかな丸い塊にする：ゆるやかな大きいうねりで、少しだけゆがめる（同じ lump_seed なら、面の数がちがっても同じ形）
	var lumps := FastNoiseLite.new()
	lumps.seed = lump_seed
	lumps.frequency = 0.9
	lumps.fractal_octaves = 1
	for i in points.size():
		var p := points[i]
		points[i] = p * (1.0 + lumps.get_noise_3d(p.x, p.y, p.z) * 0.14)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices.size():
		tool.add_vertex(points[indices[i]])
	tool.index()
	tool.generate_normals()
	return tool.commit()


## 丸みのある岩の形（大きさ 1 の、少しいびつな丸い塊）。なめらかに光が当たる
func _rock_shape(rng: RandomNumberGenerator) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 14
	sphere.rings = 8
	var data := sphere.get_mesh_arrays()
	var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	# ゆるやかなうねりで、なめらかにゆがめる（同じ場所の頂点は同じだけ動くので、割れ目はできない）
	var warp := FastNoiseLite.new()
	warp.seed = rng.randi()
	warp.frequency = 1.0
	warp.fractal_octaves = 1
	for i in points.size():
		var p := points[i]
		points[i] = p * (1.0 + warp.get_noise_3d(p.x, p.y, p.z) * (ROCK_BULGE - 1.0) * 1.2)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices.size():
		tool.add_vertex(points[indices[i]])
	tool.index()  # 同じ場所の頂点をまとめて、面の境目でも光がなめらかにつながるようにする
	tool.generate_normals()
	return tool.commit()
