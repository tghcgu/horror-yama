class_name Terrain
extends Node3D
## 段々になった山を生成する。崖（登る場所）と段（休める足場）が交互に続く。
## 高さごとに地帯（樹海・岩場・雪原・山頂）の色で塗り分ける。

const SIZE := 230.0          # 地形の一辺 (m)
const CELL := 0.6            # 頂点の間隔 (m)
const PEAK_HEIGHT := 144.0
const BASE_RADIUS := 90.0    # ふもとの半径の目安 (m)
const BULGE := 24.0          # 山全体の大きなうねり (m)。尾根や谷ができて、段が同心円にならない
const LEDGE_SHIFT := 6.0     # 段の位置を細かくずらす量。足場が途切れたり、崖が2段分つながったりする
const STEP_HEIGHTS := Vector2(8.0, 16.0)  # 崖1段の高さの範囲 (m)。段ごとにばらばら
const SUMMIT_DEPTH := 11.0   # てっぺんからこれだけ下で削って、山頂の台地にする (m)
const CLIFF_RATIO := 0.3     # 1段のうち崖になる割合（残りは平らな足場）
const NOISE_SEED := 20260925

var summit_position := Vector3.ZERO

var _bulge_noise := FastNoiseLite.new()
var _ledge_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _levels := PackedFloat32Array()  # 各段の足場の高さ（下から順に）
var _summit_cap := INF  # 山頂の台地の高さ。これより上は平らに削る
var _count := 0
var _half := 0.0
var _heights := PackedFloat32Array()
var _normals := PackedVector3Array()


func _ready() -> void:
	_bulge_noise.seed = NOISE_SEED
	_bulge_noise.frequency = 0.02
	_bulge_noise.fractal_octaves = 3
	_ledge_noise.seed = NOISE_SEED + 1
	_ledge_noise.frequency = 0.06
	_detail_noise.seed = NOISE_SEED + 2
	_detail_noise.frequency = 0.15
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var level := 0.0
	while level < PEAK_HEIGHT + BULGE * 2.0:
		_levels.append(level)
		level += rng.randf_range(STEP_HEIGHTS.x, STEP_HEIGHTS.y)
	_levels.append(level)
	# 山頂は、てっぺんより少し下の段で平らに削って、鳥居と祠を置ける台地にする
	var peak := _shaped(0.0, 0.0)
	for boundary in _levels:
		if boundary <= peak - SUMMIT_DEPTH:
			_summit_cap = boundary
	_build()


func height_at(x: float, z: float) -> float:
	var h := minf(_terrace(maxf(_shaped(x, z), 0.0)), _summit_cap) + 0.3 * _detail_noise.get_noise_2d(x, z)
	return maxf(h, 0.0)


## 段々にする前の、なだらかな山の高さ
func _shaped(x: float, z: float) -> float:
	var cone := PEAK_HEIGHT * (1.0 - Vector2(x, z).length() / BASE_RADIUS)
	return cone + BULGE * _bulge_noise.get_noise_2d(x, z) + LEDGE_SHIFT * _ledge_noise.get_noise_2d(x, z)


## スタート地点：南側（+Z）の、最初の崖から少し離れた平地
func spawn_point() -> Vector3:
	var edge := SIZE / 2.0 - 2.0
	var z := edge
	while z > 0.0 and height_at(0.0, z) < 0.5:
		z -= 1.0
	z = minf(z + 10.0, edge)
	return Vector3(0.0, height_at(0.0, z) + 0.5, z)


## 平らな足場（崖の縁から少し離れた場所）から、ランダムに点を選ぶ
func random_ledge_points(rng: RandomNumberGenerator, count: int, min_y: float, max_y: float, spacing: float,
		flat_radius := 3, avoid := PackedVector3Array(), avoid_radius := 0.0) -> PackedVector3Array:
	var result := PackedVector3Array()
	var attempts := 0
	while result.size() < count and attempts < count * 800:
		attempts += 1
		var xi := rng.randi_range(flat_radius, _count - 1 - flat_radius)
		var zi := rng.randi_range(flat_radius, _count - 1 - flat_radius)
		var h := _heights[zi * _count + xi]
		if h < min_y or h >= max_y or not _is_flat_area(xi, zi, flat_radius):
			continue
		var p := Vector3(xi * CELL - _half, h, zi * CELL - _half)
		if _too_close(p, result, spacing) or _too_close(p, avoid, avoid_radius):
			continue
		result.append(p)
	return result


## 切り立った崖の壁から、ランダムに点を選ぶ。[位置, 壁の外向き] の組の配列を返す
func random_wall_points(rng: RandomNumberGenerator, count: int, min_y: float, max_y: float, spacing: float) -> Array:
	var result := []
	var positions := PackedVector3Array()
	var attempts := 0
	while result.size() < count and attempts < count * 800:
		attempts += 1
		var xi := rng.randi_range(1, _count - 2)
		var zi := rng.randi_range(1, _count - 2)
		var i := zi * _count + xi
		var h := _heights[i]
		var normal := _normals[i]
		if h < min_y or h >= max_y or normal.y > 0.35:
			continue
		var p := Vector3(xi * CELL - _half, h, zi * CELL - _half)
		if _too_close(p, positions, spacing):
			continue
		result.append([p, normal])
		positions.append(p)
	return result


func _is_flat_area(xi: int, zi: int, radius: int) -> bool:
	var stride := maxi(radius / 2, 1)
	for dz in range(-radius, radius + 1, stride):
		for dx in range(-radius, radius + 1, stride):
			if _normals[(zi + dz) * _count + xi + dx].y < 0.9:
				return false
	return true


func _too_close(p: Vector3, points: PackedVector3Array, distance: float) -> bool:
	for q in points:
		if p.distance_to(q) < distance:
			return true
	return false


## なだらかな高さを、平らな足場と切り立った崖の段々に変える
func _terrace(h: float) -> float:
	var i := 0
	while i < _levels.size() - 2 and _levels[i + 1] <= h:
		i += 1
	var bottom := _levels[i]
	var step := _levels[i + 1] - bottom
	var t := clampf(((h - bottom) / step - (1.0 - CLIFF_RATIO)) / CLIFF_RATIO, 0.0, 1.0)
	return bottom + smoothstep(0.0, 1.0, t) * step


func _build() -> void:
	_count = int(SIZE / CELL) + 1
	_half = SIZE / 2.0
	var count := _count
	_heights.resize(count * count)
	for zi in count:
		for xi in count:
			_heights[zi * count + xi] = height_at(xi * CELL - _half, zi * CELL - _half)

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(count * count)
	_normals.resize(count * count)
	colors.resize(count * count)
	# 山頂：台地の上で、山の中心にいちばん近い点
	summit_position = Vector3(0.0, -INF, 0.0)
	var summit_distance := INF
	for zi in count:
		for xi in count:
			var i := zi * count + xi
			var left := _heights[zi * count + maxi(xi - 1, 0)]
			var right := _heights[zi * count + mini(xi + 1, count - 1)]
			var back := _heights[maxi(zi - 1, 0) * count + xi]
			var front := _heights[mini(zi + 1, count - 1) * count + xi]
			var normal := Vector3(left - right, 2.0 * CELL, back - front).normalized()
			var pos := Vector3(xi * CELL - _half, _heights[i], zi * CELL - _half)
			vertices[i] = pos
			_normals[i] = normal
			colors[i] = _color_at(pos, normal)
			var distance := Vector2(pos.x, pos.z).length()
			if pos.y >= _summit_cap - 0.5 and distance < summit_distance:
				summit_position = pos
				summit_distance = distance

	var indices := PackedInt32Array()
	indices.resize((count - 1) * (count - 1) * 6)
	var k := 0
	for zi in count - 1:
		for xi in count - 1:
			var i := zi * count + xi
			indices[k] = i
			indices[k + 1] = i + 1
			indices[k + 2] = i + count
			indices[k + 3] = i + 1
			indices[k + 4] = i + count + 1
			indices[k + 5] = i + count
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Psx.terrain_material())

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.add_child(collision)
	add_child(body)

	_add_outer_ground()


## 地形の外側に広がる平地（端から落ちないように）
func _add_outer_ground() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(900.0, 1.0, 900.0)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position.y = -0.55

	var plane := PlaneMesh.new()
	plane.size = Vector2(900.0, 900.0)
	plane.subdivide_width = 60  # 頂点を震わせたとき、遠くの地面が大きく崩れないように
	plane.subdivide_depth = 60
	plane.material = Psx.material("ground_forest", Color(0.45, 0.5, 0.3), 0.33)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = plane
	mesh_instance.position.y = -0.05

	var body := StaticBody3D.new()
	body.add_child(collision)
	body.add_child(mesh_instance)
	add_child(body)


## 頂点の色は明るさのむらだけ（地帯ごとの色と模様は、地形のシェーダーが素材から決める）
func _color_at(pos: Vector3, _normal: Vector3) -> Color:
	var shade := 0.85 + 0.15 * _detail_noise.get_noise_2d(pos.x * 1.5, pos.z * 1.5)
	return Color(shade, shade, shade)
