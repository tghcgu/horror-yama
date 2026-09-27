class_name FogBanks
extends MeshInstance3D
## まだ行けないステージを隠す、濃い霧。前の山の頂上のすぐ先（霧の境目）から奥が、霧に包まれている。
## いま行けるステージ（平地と山）のまわりも霧が囲み、迷って外へ出ないようにする（入ると押し戻される）。
## 山頂のたき火に着くと、その先の霧がちぎれるように薄れて晴れていき、次のステージが見えてくる。
## 霧の奥へ入りこもうとすると、押し戻される（山頂に着かないと、先へは進めない）。
## 境目には見えない壁も立っていて、山頂のたき火に火をともすまでは、次の平地へ絶対に進めない（迷わないように）。
## 先へ進むと、来た道（ふたつ前のステージ）は霧に閉ざされ、境目の見えない壁も戻ってきて、もう戻れない（seal_gate）。
## 画面全体に 1 枚の板を描き、視線が霧の中を通る道のりから濃さを求める（fog_bank.gdshader）。

const SHADER := preload("res://shaders/fog_bank.gdshader")
const CLEAR_TIME := 8.0   # 霧が晴れきるまで (s)
const TOP_MARGIN := 45.0   # 霧の上端：その先の山の頂上より、これだけ高くまで隠す (m)
const PASS_MARGIN := 2.0   # 境目からこれだけ奥へ入ると、押し戻し始める (m)
const LOST_DEPTH := 8.0    # これより奥へ入りこんだら、霧に巻かれて元の場所へ連れ戻される (m)
const MARGIN := 35.0       # いま行けるステージ（平地と山）から、これだけ離れると霧になる (m)
const LOST_OUTSIDE := 45.0 # まわりの霧に、これより深く入りこんだら、元の場所へ連れ戻される (m)
const COVE_HALF_WIDTH := 140.0  # 砂浜のうしろの、霧でおおわない入り江の幅の半分 (m)
const WALL_WIDTH := 1400.0 # 見えない壁の幅 (m)。まわりこめないように、左右へ大きく広げる
const WALL_HEIGHT := 1600.0

var _material: ShaderMaterial
var _clear := Vector3.ZERO  # 境目 1〜3 の晴れ具合（0 = 濃い霧、1 = 晴れた）
var _opened := [false, false, false]  # 晴れ始めたか
var _open_count := 1                  # まわりの霧が囲むステージの数
var _first_open := 0                  # まわりの霧が囲む、いちばん手前のステージ（それより前は、霧に閉ざされた）
var suppressed := false               # テスト用：霧を描かない（重さを測るとき）
var _walls: Array[CollisionShape3D] = []  # 境目 1〜3 の見えない壁


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = -100  # ほかの半透明の物（たき火の炎など）より先に描く
	_material.set_shader_parameter("noise", _noise())
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0  # 画面いっぱいに描くので、見えないと判断されないように
	visible = false


## 山を作ったあとに呼ぶ：境目の位置を覚えて、すべての霧を濃くする
func setup() -> void:
	for k in range(1, MountainChain.COUNT):
		var point := MountainChain.gate_point(k)
		var direction := MountainChain.gate_direction(k)
		var top: float = MountainChain.peaks[k] + TOP_MARGIN
		_material.set_shader_parameter("gate_%d" % k, Vector4(direction.x, direction.y, point.dot(direction), top))
	# 霧の帯の芯：最初の境目から、この先のステージの山の真ん中をたどり、最後の山の向こうまで
	var path := PackedVector2Array([MountainChain.gate_point(1)])
	for k in range(1, MountainChain.COUNT):
		path.append(MountainChain.centers[k])
	var last := MountainChain.centers[MountainChain.COUNT - 1]
	path.append(last + (last - MountainChain.centers[MountainChain.COUNT - 2]).normalized() * 300.0)
	_material.set_shader_parameter("path_points", path)
	var plains := PackedVector4Array()
	var areas := PackedVector4Array()
	for i in MountainChain.COUNT:
		var start := MountainChain.plain_starts[i]
		var end := MountainChain.plain_ends[i]
		plains.append(Vector4(start.x, start.y, end.x, end.y))
		var center := MountainChain.centers[i]
		areas.append(Vector4(center.x, center.y, MountainChain.radii[i] * MountainChain.SPREAD, MountainChain.PLAIN_HALF_WIDTH))
	_material.set_shader_parameter("stage_plains", plains)
	_material.set_shader_parameter("stage_areas", areas)
	_material.set_shader_parameter("boundary_margin", MARGIN)
	var beach_start := MountainChain.plain_starts[0]
	_material.set_shader_parameter("beach_origin", beach_start)
	_material.set_shader_parameter("beach_direction", (MountainChain.plain_ends[0] - beach_start).normalized())
	_material.set_shader_parameter("cove_half_width", COVE_HALF_WIDTH)
	_open_areas(1)
	_first_open = 0
	_material.set_shader_parameter("first_stage", 0)
	_clear = Vector3.ZERO
	_opened = [false, false, false]
	_build_walls()
	_material.set_shader_parameter("clear", _clear)


## 境目ごとに、見えない壁を立てる：境目の少し奥に、左右にも上にも大きく広がる、見えない板
func _build_walls() -> void:
	for wall in _walls:
		if is_instance_valid(wall):
			wall.get_parent().queue_free()
	_walls.clear()
	for k in range(1, MountainChain.COUNT):
		var point := MountainChain.gate_point(k)
		var direction := MountainChain.gate_direction(k)
		var forward := Vector3(direction.x, 0.0, direction.y)
		var body := StaticBody3D.new()
		body.collision_layer = Player.BARRIER_LAYER
		body.collision_mask = 0
		get_parent().add_child.call_deferred(body)
		var shape := BoxShape3D.new()
		shape.size = Vector3(WALL_WIDTH, WALL_HEIGHT, 2.0)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		var center := Vector3(point.x, MountainChain.bases[k], point.y) + forward * (PASS_MARGIN - 0.5)
		body.transform = Transform3D(Basis(Vector3.UP.cross(forward), Vector3.UP, forward), center)
		_walls.append(collision)


## 見えない壁の向こう側にいるか（飛ばされたりして入りこんだとき。壁に押しつけられたままにせず、元の場所へ戻す）
func behind_wall(pos: Vector3) -> bool:
	for k in range(1, MountainChain.COUNT):
		if not _opened[k - 1] and MountainChain.past_gate(k, pos.x, pos.z) > PASS_MARGIN + 1.5:
			return true
	# 閉ざされた来た道の側
	return _first_open > 0 and MountainChain.past_gate(_first_open, pos.x, pos.z) < PASS_MARGIN - 3.0


## 境目 k（1〜3）を、うしろから閉ざす：その手前のステージ（来た道）は霧に包まれ、見えない壁も戻る。もう戻れない
func seal_gate(k: int) -> void:
	_first_open = maxi(_first_open, k)
	_walls[k - 1].set_deferred("disabled", false)
	_material.set_shader_parameter("first_stage", _first_open)


## 閉ざされた来た道の、見えない壁のそばにいるか（ぶつかったときの知らせ用）
func at_seal(pos: Vector3) -> bool:
	return _first_open > 0 and MountainChain.past_gate(_first_open, pos.x, pos.z) < PASS_MARGIN + 3.0


## いまの場所のすぐ先に、まだ火をともしていない山頂の見えない壁があるか（ぶつかったときの知らせ用）
func at_wall(pos: Vector3) -> bool:
	for k in range(1, MountainChain.COUNT):
		if not _opened[k - 1] and MountainChain.past_gate(k, pos.x, pos.z) > PASS_MARGIN - 3.0:
			return true
	return false


## 境目 k（1〜3）の霧を晴らす。animate しないなら、すぐに晴れる
func clear_gate(k: int, animate := true) -> void:
	_opened[k - 1] = true
	if k - 1 < _walls.size():
		_walls[k - 1].set_deferred("disabled", true)  # 見えない壁も消える
	_open_areas(k + 1)
	if not animate:
		_clear[k - 1] = 1.0
		_material.set_shader_parameter("clear", _clear)


## 境目 k の霧が晴れ始めたか（晴れ始めたら、もう通れる）
func is_opened(k: int) -> bool:
	return k <= 0 or k >= MountainChain.COUNT or _opened[k - 1]


## 境目 k の霧の晴れ具合（0〜1）
func clear_amount(k: int) -> float:
	return 1.0 if k <= 0 or k >= MountainChain.COUNT else _clear[k - 1]


## まわりの霧が囲む範囲を、はじめの count 個のステージにする
func _open_areas(count: int) -> void:
	_open_count = count
	_material.set_shader_parameter("open_stages", count)
	_material.set_shader_parameter("boundary_top", MountainChain.peaks[count - 1] + 30.0)


## いま行けるステージ（平地と山）から、横にどれだけ離れているか (m)。と、いちばん近い場所
func _outside(pos: Vector3) -> Array:
	var point := Vector2(pos.x, pos.z)
	var best := INF
	var nearest := point
	for i in range(_first_open, _open_count):
		var start := MountainChain.plain_starts[i]
		var end := MountainChain.plain_ends[i]
		var ab := end - start
		var on_plain := start + ab * clampf((point - start).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var to_plain := point.distance_to(on_plain) - MountainChain.PLAIN_HALF_WIDTH
		if to_plain < best:
			best = to_plain
			nearest = on_plain
		var center := MountainChain.centers[i]
		var to_mountain := point.distance_to(center) - MountainChain.radii[i] * MountainChain.SPREAD
		if to_mountain < best:
			best = to_mountain
			nearest = center
	# 砂浜のうしろの入り江（海）は、まわりの霧に含めない（海の深い所は Main が押し戻す）
	var beach_start := MountainChain.plain_starts[0]
	var inland := (MountainChain.plain_ends[0] - beach_start).normalized()
	var from_start := point - beach_start
	if _first_open == 0 and from_start.dot(inland) < 0.0:
		var to_cove := absf(from_start.dot(inland.orthogonal())) - COVE_HALF_WIDTH
		if to_cove < best:
			best = to_cove
			nearest = beach_start
	# 閉ざされた来た道：境目より手前は、すべて霧の中
	if _first_open > 0:
		var behind := -MountainChain.past_gate(_first_open, point.x, point.y)
		if behind > best:
			best = behind
			nearest = MountainChain.gate_point(_first_open) + MountainChain.gate_direction(_first_open) * 10.0
	return [best, nearest]


## まだ晴れていない霧の中へ、どれだけ入りこんでいるか (m)。霧の外なら 0 以下
func depth_into(pos: Vector3) -> float:
	var deepest := -INF
	for k in range(1, MountainChain.COUNT):
		if not _opened[k - 1]:
			deepest = maxf(deepest, MountainChain.past_gate(k, pos.x, pos.z))
	var outside: float = _outside(pos)[0]
	return maxf(deepest, (outside - MARGIN) * LOST_DEPTH / (LOST_OUTSIDE - MARGIN))


## 霧の奥へ入りこんだとき、押し戻す速さ（霧の外なら ZERO）。奥へ入るほど強く押し戻す
func push_back(pos: Vector3) -> Vector3:
	# まわりの霧：いま行けるステージのほうへ押し戻す
	var outside: Array = _outside(pos)
	if outside[0] > MARGIN:
		var back: Vector2 = (outside[1] as Vector2) - Vector2(pos.x, pos.z)
		if back.length() > 0.1:
			back = back.normalized()
			return Vector3(back.x, 0.0, back.y) * clampf(2.5 + (outside[0] - MARGIN) * 0.4, 0.0, 8.0)
	for k in range(1, MountainChain.COUNT):
		if _opened[k - 1]:
			continue
		var depth := MountainChain.past_gate(k, pos.x, pos.z)
		if depth > PASS_MARGIN:
			var direction := MountainChain.gate_direction(k)
			return -Vector3(direction.x, 0.0, direction.y) * clampf(2.5 + (depth - PASS_MARGIN) * 0.5, 0.0, 8.0)
	return Vector3.ZERO


## 毎フレーム：晴れていく霧を進め、霧の色を空と霧の色に合わせる。shown でなければ描かない
func update(fog_color: Color, delta: float, shown: bool) -> void:
	for i in _opened.size():
		if _opened[i] and _clear[i] < 1.0:
			_clear[i] = minf(_clear[i] + delta / CLEAR_TIME, 1.0)
	_material.set_shader_parameter("clear", _clear)
	_material.set_shader_parameter("color", fog_color)
	visible = shown and not suppressed  # まわりの霧は、いつもある


func _noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 71
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	return texture
