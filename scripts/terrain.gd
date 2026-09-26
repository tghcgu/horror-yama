class_name Terrain
extends Node3D
## 連なる 4 つの山（MountainChain）の地形を、遊ぶたびに乱数から作る。
## 平らな段はなく、鋭い尾根と深い溝が走るぐちゃぐちゃな岩山。斜面をあちこちで割れ目（クレバス）が横切る。
## 休めるのは、ごくまれな小さな岩棚と、山肌に突き刺さった大岩や岩板（ひさしのように突き出たものは、
## 下から登るとオーバーハングになる）の上だけ。雪山には、雪で隠れた深い穴（隠れクレバス）もある。

const CELL := 0.7              # 頂点の間隔 (m)
const WARP := 18.0             # 山の輪郭をゆがめる量 (m)
const RIDGE := 21.0            # 尾根と溝の深さ (m)
const RIDGE_MEAN := 0.35       # 尾根の模様の平均（これを引いて、地面全体が持ち上がらないようにする）
const CRAG := 5.0              # 細かい岩のでこぼこ (m)
const SHELF_STEP := 6.0        # 岩棚の段の高さ (m)
const CRACK_WIDTH := 0.05      # 割れ目の幅（模様の値で）
const CRACK_DEPTH := 11.0      # 割れ目の深さ (m)
const PLATEAU_RADIUS := 6.0    # 山頂の、たき火や祠を置く平らな場所の半径 (m)
const ROCKS_PER_MOUNTAIN := 55
const SLABS_PER_MOUNTAIN := 28
const TILE := 40              # 見た目の区画の大きさ（頂点の間隔の数。28 m 四方）
const FAR_STEP := 4           # 遠くの区画は、頂点を 4 つおきに間引いて描く
const NEAR_RANGE := 110.0     # これより遠い区画を、間引いた形に切り替える (m)
const SKIRT := 4.0            # 間引いた区画のふちの「すそ」の深さ (m)
const ROCK_RANGE := 240.0     # 大岩をこれより遠くでは描かない (m)
const PIT_COUNT := 6           # 雪山の隠れクレバスの数
const PIT_RADIUS := 2.2
const PIT_DEPTH := 11.0
const PIT_FIELD := 4.0         # 穴のまわりの、平らにならした雪原の幅 (m)。休めそうに見えて、実は罠

var summit_position := Vector3.ZERO  # 最後の山（霊峰）の頂上
var run_seed := 0
var pits := PackedVector3Array()     # 隠れクレバスの穴（x, z, ふちの高さ）。雪のふたは MountainFeatures がかぶせる
var overhangs := []                  # 突き出た岩板の裏側 [位置, 地帯]（つららを下げる）

var _warp_x := FastNoiseLite.new()
var _warp_z := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _crag := FastNoiseLite.new()
var _shelf := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _crack := FastNoiseLite.new()
var _origin := Vector2.ZERO  # 地形の北西の角
var _count_x := 0
var _count_z := 0
var _heights := PackedFloat32Array()
var _normals := PackedVector3Array()


## 地形を作る（数秒かかるので、読み込み画面を出してから呼ぶ）。前に作った地形は消す
func build(seed_value: int) -> void:
	run_seed = seed_value
	for child in get_children():
		child.queue_free()
	MountainChain.generate(seed_value)
	_setup_noise(seed_value)
	pits.clear()
	overhangs.clear()
	_build_ground()
	_build_rocks()
	summit_position = checkpoint(MountainChain.COUNT - 1)


func _setup_noise(seed_value: int) -> void:
	var setups := [
		[_warp_x, 0.012, 2, FastNoiseLite.FRACTAL_FBM], [_warp_z, 0.012, 2, FastNoiseLite.FRACTAL_FBM],
		[_ridge, 0.03, 4, FastNoiseLite.FRACTAL_RIDGED], [_crag, 0.09, 3, FastNoiseLite.FRACTAL_FBM],
		[_shelf, 0.045, 1, FastNoiseLite.FRACTAL_NONE], [_hills, 0.03, 3, FastNoiseLite.FRACTAL_FBM],
		[_detail, 0.15, 1, FastNoiseLite.FRACTAL_NONE], [_crack, 0.016, 2, FastNoiseLite.FRACTAL_FBM],
	]
	for i in setups.size():
		var noise: FastNoiseLite = setups[i][0]
		noise.seed = seed_value + i * 101
		noise.frequency = setups[i][1]
		noise.fractal_octaves = setups[i][2]
		noise.fractal_type = setups[i][3]


func height_at(x: float, z: float) -> float:
	# 輪郭をゆがめてから、それぞれの山の大まかな高さを出す
	var wx := x + _warp_x.get_noise_2d(x, z) * WARP
	var wz := z + _warp_z.get_noise_2d(x, z) * WARP
	var raw: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var best := -INF
	for i in MountainChain.COUNT:
		raw[i] = MountainChain.cone(i, wx, wz)
		best = maxf(best, raw[i])
	var ridge := _ridge.get_noise_2d(wx, wz) - RIDGE_MEAN  # 尾根ほど大きい（平均が 0 になるようにずらす）
	var crag := _crag.get_noise_2d(x, z)
	var shelf_mask := smoothstep(0.55, 0.75, _shelf.get_noise_2d(x, z))  # 岩棚はごくまれ
	var crack := 1.0 - smoothstep(0.0, CRACK_WIDTH, absf(_crack.get_noise_2d(wx, wz)))
	var h := 0.0
	for i in MountainChain.COUNT:
		if raw[i] < best - 30.0:
			continue
		var base: float = MountainChain.bases[i]
		var top: float = MountainChain.peaks[i] - MountainChain.PLATEAU
		# 頂上に近いほど、でこぼこを弱めて、たき火を置ける平らな場所を残す
		var fade := 1.0 - smoothstep(0.84, 0.98, (raw[i] - base) / (top - base))
		var v := raw[i] + (ridge * RIDGE + crag * CRAG - crack * CRACK_DEPTH) * fade
		# ところどころにだけ、小さな岩棚
		var steps := v / SHELF_STEP
		var level := floorf(steps)
		var shelf := (level + smoothstep(0.55, 1.0, steps - level)) * SHELF_STEP
		v = lerpf(v, shelf, shelf_mask * fade)
		# 山頂の真ん中には、必ず平らな場所を作る（倒れたあと、たき火のそばから再開するため）
		var from_center := Vector2(x, z).distance_to(MountainChain.centers[i])
		v = lerpf(v, top, 1.0 - smoothstep(PLATEAU_RADIUS, PLATEAU_RADIUS + 4.0, from_center))
		h = maxf(h, minf(v, top))
	# ふもとも平らにせず、起伏をつける
	var hills := 2.5 + _hills.get_noise_2d(x, z) * 5.0
	h = maxf(maxf(h, hills) + 0.3 * _detail.get_noise_2d(x, z), 0.2)
	# 隠れクレバス：平らな雪原の真ん中に、まっすぐ下へ落ちる深い穴
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


## スタート地点：最初の山の南のふもと
func spawn_point() -> Vector3:
	var c := MountainChain.centers[0]
	var z := c.y + MountainChain.radii[0] + 16.0
	return Vector3(c.x, height_at(c.x, z) + 0.5, z)


## 足場（ある程度平らな場所）から、ランダムに点を選ぶ。biome を指定すると、その地帯だけから選ぶ
func random_ledge_points(rng: RandomNumberGenerator, count: int, biome: int, spacing: float,
		flat_radius := 1, avoid := PackedVector3Array(), avoid_radius := 0.0, min_y := 1.0,
		min_normal_y := 0.85) -> PackedVector3Array:
	var result := PackedVector3Array()
	var area := _search_area(biome, flat_radius)
	var attempts := 0
	while result.size() < count and attempts < count * 4000:
		attempts += 1
		var xi := rng.randi_range(area.position.x, area.end.x)
		var zi := rng.randi_range(area.position.y, area.end.y)
		var p := _vertex(xi, zi)
		if p.y < min_y or not _is_flat_area(xi, zi, flat_radius, min_normal_y):
			continue
		if biome >= 0 and Biomes.at(p) != biome:
			continue
		if _too_close(p, result, spacing) or _too_close(p, avoid, avoid_radius):
			continue
		result.append(p)
	return result


## 切り立った崖の壁から、ランダムに点を選ぶ。[位置, 壁の外向き] の組の配列を返す
func random_wall_points(rng: RandomNumberGenerator, count: int, biome: int, spacing: float) -> Array:
	var result := []
	var positions := PackedVector3Array()
	var area := _search_area(biome, 1)
	var attempts := 0
	while result.size() < count and attempts < count * 4000:
		attempts += 1
		var xi := rng.randi_range(area.position.x, area.end.x)
		var zi := rng.randi_range(area.position.y, area.end.y)
		var p := _vertex(xi, zi)
		var normal := _normals[zi * _count_x + xi]
		if p.y < 8.0 or normal.y > 0.35 or Biomes.at(p) != biome:
			continue
		if _too_close(p, positions, spacing):
			continue
		result.append([p, normal])
		positions.append(p)
	return result


## 探す範囲（頂点の番号）。樹海（ふもと全体を含む）以外は、その地帯の山のまわりだけを探す
func _search_area(biome: int, margin: int) -> Rect2i:
	var whole := Rect2i(margin, margin, _count_x - 1 - margin * 2, _count_z - 1 - margin * 2)
	if biome <= 0 or biome >= MountainChain.COUNT:
		return whole
	var c := MountainChain.centers[biome]
	var reach := MountainChain.radii[biome] + 12.0
	var corner := Vector2i(int((c.x - reach - _origin.x) / CELL), int((c.y - reach - _origin.y) / CELL))
	var size := int(reach * 2.0 / CELL)
	return Rect2i(corner, Vector2i(size, size)).intersection(whole)


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
	for q in points:
		if Vector2(p.x - q.x, p.z - q.z).length() < distance:
			return true
	return false


# --- 地面 ---

func _build_ground() -> void:
	var area := MountainChain.bounds()
	_origin = area.position
	_count_x = int(area.size.x / CELL) + 1
	_count_z = int(area.size.y / CELL) + 1
	var total := _count_x * _count_z
	_heights.resize(total)
	_normals.resize(total)
	for zi in _count_z:
		for xi in _count_x:
			_heights[zi * _count_x + xi] = height_at(_origin.x + xi * CELL, _origin.y + zi * CELL)
	_compute_normals()
	_carve_pits()

	var colors := PackedColorArray()
	var shades := PackedVector2Array()
	colors.resize(total)
	shades.resize(total)
	for zi in _count_z:
		for xi in _count_x:
			var i := zi * _count_x + xi
			var pos := _vertex(xi, zi)
			# 頂点の色 = 4 つの地帯の重み（地形のシェーダーが、これで素材を混ぜる）
			var w := MountainChain.weights(pos.x, pos.z, pos.y)
			colors[i] = Color(w[0], w[1], w[2], w[3])
			shades[i] = Vector2(0.85 + 0.15 * _detail.get_noise_2d(pos.x * 1.5, pos.z * 1.5), 0.0)

	# 見た目は区画に分ける。画面や影に入らない区画は描かずにすみ、遠い区画は間引いた形で描く
	var material := Psx.terrain_material()
	for z0 in range(0, _count_z - 1, TILE):
		for x0 in range(0, _count_x - 1, TILE):
			var x1 := mini(x0 + TILE, _count_x - 1)
			var z1 := mini(z0 + TILE, _count_z - 1)
			var near := MeshInstance3D.new()
			near.mesh = _tile_mesh(x0, z0, x1, z1, 1, colors, shades)
			near.material_override = material
			near.visibility_range_end = NEAR_RANGE
			near.visibility_range_end_margin = 4.0
			add_child(near)
			var far := MeshInstance3D.new()
			far.mesh = _tile_mesh(x0, z0, x1, z1, FAR_STEP, colors, shades)
			far.material_override = material
			far.visibility_range_begin = NEAR_RANGE
			far.visibility_range_begin_margin = 4.0
			far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # 遠くの影は描かない
			add_child(far)

	# 当たり判定は全体でひとつ（細かい形のまま）
	var faces := PackedVector3Array()
	faces.resize((_count_x - 1) * (_count_z - 1) * 6)
	var k := 0
	for zi in _count_z - 1:
		for xi in _count_x - 1:
			var a := _vertex(xi, zi)
			var b := _vertex(xi + 1, zi)
			var c := _vertex(xi, zi + 1)
			var d := _vertex(xi + 1, zi + 1)
			faces[k] = a
			faces[k + 1] = b
			faces[k + 2] = c
			faces[k + 3] = b
			faces[k + 4] = d
			faces[k + 5] = c
			k += 6
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.add_child(collision)
	add_child(body)
	_add_outer_ground()


## 区画ひとつ分のメッシュ。step 個おきの頂点で作る（遠くの区画用に間引く）。
## 間引いた区画のふちには下向きの「すそ」をつけて、細かい区画とのすき間から空が見えないようにする
func _tile_mesh(x0: int, z0: int, x1: int, z1: int, step: int, colors: PackedColorArray, shades: PackedVector2Array) -> ArrayMesh:
	var xs: Array[int] = []
	for xi in range(x0, x1 + 1, step):
		xs.append(xi)
	if xs[xs.size() - 1] != x1:
		xs.append(x1)
	var zs: Array[int] = []
	for zi in range(z0, z1 + 1, step):
		zs.append(zi)
	if zs[zs.size() - 1] != z1:
		zs.append(z1)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tile_colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for zi in zs:
		for xi in xs:
			var i := zi * _count_x + xi
			vertices.append(_vertex(xi, zi))
			normals.append(_normals[i])
			tile_colors.append(colors[i])
			uvs.append(shades[i])
	var w := xs.size()
	for r in zs.size() - 1:
		for c in w - 1:
			var i := r * w + c
			indices.append_array([i, i + 1, i + w, i + 1, i + w + 1, i + w])
	if step > 1:
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
				vertices.append(vertices[index] - Vector3.UP * SKIRT)
				normals.append(normals[index])
				tile_colors.append(tile_colors[index])
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
	arrays[Mesh.ARRAY_COLOR] = tile_colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 地形の外側に広がる地面（端から落ちないように）
func _add_outer_ground() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(1600.0, 1.0, 1600.0)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position.y = -0.5
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600.0, 1600.0)
	plane.subdivide_width = 80  # 頂点を震わせたとき、遠くの地面が大きく崩れないように
	plane.subdivide_depth = 80
	plane.material = Psx.material("ground_forest", Color(0.45, 0.5, 0.3), 0.33)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = plane
	var body := StaticBody3D.new()
	body.position = Vector3(MountainChain.centers[0].x, 0.0, MountainChain.centers[0].y - 100.0)
	body.add_child(collision)
	body.add_child(mesh_instance)
	add_child(body)


func _compute_normals() -> void:
	for zi in _count_z:
		for xi in _count_x:
			var left := _heights[zi * _count_x + maxi(xi - 1, 0)]
			var right := _heights[zi * _count_x + mini(xi + 1, _count_x - 1)]
			var back := _heights[maxi(zi - 1, 0) * _count_x + xi]
			var front := _heights[mini(zi + 1, _count_z - 1) * _count_x + xi]
			_normals[zi * _count_x + xi] = Vector3(left - right, 2.0 * CELL, back - front).normalized()


## 雪山のなだらかな場所に、隠れクレバスの穴をあける（上から雪のふたをかぶせて隠す）
func _carve_pits() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + 13
	var spots := random_ledge_points(rng, PIT_COUNT, Biomes.Id.SNOW, 18.0, 1, PackedVector3Array([checkpoint(Biomes.Id.SNOW)]), 14.0, 20.0, 0.72)
	for spot in spots:
		pits.append(Vector3(spot.x, spot.z, spot.y + 0.05))
	var reach := int(ceilf((PIT_RADIUS + PIT_FIELD) / CELL)) + 1
	for pit in pits:
		var cx := int(roundf((pit.x - _origin.x) / CELL))
		var cz := int(roundf((pit.y - _origin.y) / CELL))
		for zi in range(maxi(cz - reach, 0), mini(cz + reach + 1, _count_z)):
			for xi in range(maxi(cx - reach, 0), mini(cx + reach + 1, _count_x)):
				_heights[zi * _count_x + xi] = height_at(_origin.x + xi * CELL, _origin.y + zi * CELL)
	if not pits.is_empty():
		_compute_normals()


func _near_pit(x: float, z: float, margin: float) -> bool:
	for pit in pits:
		if Vector2(x, z).distance_to(Vector2(pit.x, pit.y)) < PIT_RADIUS + PIT_FIELD + margin:
			return true
	return false


# --- 山肌に突き刺さった大岩と岩板 ---

## 角ばった岩の形を何種類か作り、山肌に向きも大きさもばらばらに突き刺す。
## 岩板は平たく大きく、山肌から横へ突き出るので、上は足場、下はオーバーハングになる
func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + 7
	var shapes: Array[ArrayMesh] = []
	for s in 8:
		shapes.append(_rock_shape(rng))
	var tools := {}  # [区画, 地帯] → その区画の岩をまとめたメッシュ（区画ごとに分けて、見えない所は描かない）
	var tile_size := TILE * CELL * 2.0
	var body := StaticBody3D.new()
	add_child(body)
	for i in MountainChain.COUNT:
		var c := MountainChain.centers[i]
		var radius := MountainChain.radii[i]
		for n in ROCKS_PER_MOUNTAIN + SLABS_PER_MOUNTAIN:
			var slab := n >= ROCKS_PER_MOUNTAIN
			var angle := rng.randf() * TAU
			var distance := radius * sqrt(rng.randf_range(0.03, 0.85))
			var x := c.x + cos(angle) * distance
			var z := c.y + sin(angle) * distance
			var ground := Vector3(x, height_at(x, z), z)
			if ground.distance_to(checkpoint(i)) < 9.0 or _near_pit(x, z, 5.0):
				continue  # 頂上のたき火のまわりと、隠れクレバスの上はあけておく
			var normal := normal_at(x, z)
			var size: Vector3
			var rock_basis: Basis
			if slab:
				# 山の外側へ向かって、ほぼ水平に突き出る平たい岩板
				size = Vector3(rng.randf_range(4.0, 8.0), rng.randf_range(0.8, 1.6), rng.randf_range(3.0, 6.0))
				var outward := Vector3(normal.x, 0.0, normal.z).normalized()
				if outward.length() < 0.1:
					outward = Vector3.FORWARD
				rock_basis = Basis.looking_at(outward, Vector3.UP).rotated(outward.cross(Vector3.UP).normalized(), rng.randf_range(-0.35, 0.3))
			else:
				var s := rng.randf_range(1.8, 6.5)
				size = Vector3(s * rng.randf_range(0.7, 1.3), s * rng.randf_range(0.6, 1.4), s * rng.randf_range(0.7, 1.3))
				rock_basis = Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
			var center := ground - normal * size.y * 0.25 + (Vector3(normal.x, 0.0, normal.z) * size.z * 0.3 if slab else Vector3.ZERO)
			var xform := Transform3D(rock_basis * Basis.from_scale(size), center)
			var shape_mesh: ArrayMesh = shapes[rng.randi() % shapes.size()]
			var biome := Biomes.at(ground)
			var key := Vector3i(floori(center.x / tile_size), floori(center.z / tile_size), biome)
			if not tools.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = tool
			(tools[key] as SurfaceTool).append_from(shape_mesh, 0, xform)
			if slab:
				overhangs.append([xform * Vector3(0.0, -0.5, -0.3), biome])  # 岩板の外寄りの裏側
			var collision := CollisionShape3D.new()
			var faces := shape_mesh.get_faces()
			for f in faces.size():
				faces[f] = xform * faces[f]
			var concave := ConcavePolygonShape3D.new()
			concave.set_faces(faces)
			concave.backface_collision = true
			collision.shape = concave
			body.add_child(collision)
	var tints := [Color(0.5, 0.55, 0.45), Color(0.72, 0.7, 0.68), Color(0.78, 0.82, 0.9), Color(0.42, 0.38, 0.4)]
	var materials := []
	for biome in tints.size():
		materials.append(Psx.material("rock" if biome > 0 else "rock_mossy", tints[biome], 0.35, 0.4))
	for key: Vector3i in tools:
		var tool: SurfaceTool = tools[key]
		tool.generate_normals()
		var instance := MeshInstance3D.new()
		instance.mesh = tool.commit()
		instance.material_override = materials[key.z]
		instance.visibility_range_end = ROCK_RANGE
		add_child(instance)


## ごつごつした岩の形（大きさ 1 の、でこぼこした多面体）。面ごとに平らに光が当たる
func _rock_shape(rng: RandomNumberGenerator) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 7
	sphere.rings = 4
	var data := sphere.get_mesh_arrays()
	var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	# 同じ場所の頂点は同じだけ動かして、割れ目ができないようにする
	var offsets := {}
	for i in points.size():
		var key := points[i].snapped(Vector3.ONE * 0.001)
		if not offsets.has(key):
			offsets[key] = rng.randf_range(0.75, 1.25)
		points[i] *= offsets[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices.size():
		tool.add_vertex(points[indices[i]])
	tool.generate_normals()
	return tool.commit()
