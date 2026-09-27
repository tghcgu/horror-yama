class_name Lobby
extends Node3D
## 山のふもとの町はずれにある「登山訓練場」。ゲームはここから始まる（ここでは時間が止まり、化け物も獣も出ない）。
## 広い草地に、登る練習の場所と、道具の練習の場所が並ぶ。どこにも看板があり、やり方が書いてある。
##   ① 段差        ：跳んで乗り越える（縁にぶつかると、手をかけてよじ上る）
##   ② 登りの壁    ：つかんで登る。てっぺんから裏の階段で下りられる
##   ③ 張り出し    ：覆いかぶさる壁（疲れやすい）
##   ④ ロープと鎖  ：楽に登れる
##   ⑤ 氷の壁      ：すべり落ちる（アイゼンを使えば平気）
##   ⑥ 岩の塔      ：山と同じ、ごつごつした大岩の積み重なり
##   ⑦ 道具置き場  ：すべての道具が並び、E で好きなだけ取れる（練習用。山へは持っていけない）
##   ⑧ 巻藁        ：ナタで叩く・素手で殴る（与えた傷が出る）
##   ⑨ 的当て      ：Q をためて投げる（遠い的ほど強く投げる）
## スタート地点の小屋の前には大きな姿見があり、身だしなみを整えられる。南のヘリポートのヘリに乗ると、霊峰へ出発する。
## 原点は草地の真ん中。+Z が南（ヘリポートの側）。

const FIELD := Vector2(70.0, 66.0)  # 草地の広さの半分 (x, z)
const MIRROR_SIZE := Vector2(3.2, 2.6)
const MIRROR_REACH := 3.2  # 姿見のこれだけ手前までなら、身だしなみを整えられる
const MIRROR_AT := Vector3(0.0, 0.0, 38.0)  # 姿見の足もと（北の訓練場のほうを向けて立てる）
const FONT := preload("res://assets/fonts/DotGothic16-Regular.ttf")

var mirror: Mirror
var campfire: Campfire  # スタート地点の、火のついたたき火（肉を焼く練習もできる）
var spawn_position := Vector3.ZERO
var spawn_yaw := 0.0

var _body: StaticBody3D
var _board_point := Vector3.ZERO  # ヘリの扉の前（ここまで来ると出発する）
var _practice: Array[Node] = []  # 練習で投げた道具・打ったハーケン・垂らしたロープ・貼ったお札（出発するときに片づける）
var _wood: Material
var _paint: Material


## ツリーに追加して位置を決めてから呼ぶ。viewer は鏡を見るカメラ（プレイヤーの目）
func build(viewer: Camera3D) -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = Player.TERRAIN_LAYER  # 壁も岩も、つかんで登れる
	add_child(_body)
	_wood = Psx.material("wood", Color(0.55, 0.42, 0.3), 1.2)
	_paint = Psx.material("", Color(0.9, 0.88, 0.8))
	_build_ground()
	_build_mirror(viewer)
	_build_home()
	_build_steps()
	_build_climb_wall()
	_build_overhang()
	_build_rope_cliff()
	_build_ice_cliff()
	_build_boulder_tower()
	_build_item_tables()
	_build_dummies()
	_build_targets()
	_build_heliport()
	_build_trees()
	_build_backdrop()
	# 姿見の 2 m ほど手前に、姿見のほうを向いて立つ
	spawn_position = to_global(MIRROR_AT + Vector3(0.0, 0.05, -2.3))
	spawn_yaw = rotation.y + PI


## ヘリの扉の前まで来たか（出発の合図）
func is_boarding(point: Vector3) -> bool:
	return point.distance_to(_board_point) < 2.2


## 訓練場の中にいるか（霧を消すのに使う）
func contains(point: Vector3) -> bool:
	var p := to_local(point)
	return absf(p.x) < FIELD.x + 6.0 and absf(p.z) < FIELD.y + 6.0 and p.y > -5.0 and p.y < 80.0


## 姿見の前にいて、姿見のほうを向いているか
func facing_mirror(camera: Camera3D) -> bool:
	var p := mirror.to_local(camera.global_position)
	if p.z < 0.0 or p.z > MIRROR_REACH or absf(p.x) > MIRROR_SIZE.x / 2.0 + 0.6:
		return false
	var forward := -camera.global_transform.basis.z
	return forward.dot(-mirror.global_transform.basis.z) > 0.5


# --- 練習で使った道具（山の上と同じ呼び方で、訓練場に置く） ---

func spawn_item(kind: int, origin: Vector3, velocity: Vector3, activated := false) -> Pickup:
	var pickup := Pickup.new()
	pickup.setup(kind, activated)
	add_child(pickup)
	pickup.global_position = origin
	pickup.linear_velocity = velocity
	pickup.angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 4.0
	_practice.append(pickup)
	return pickup


func add_rope(top: Vector3, outward: Vector3, length: float) -> void:
	var rope := Rope.new()
	add_child(rope)
	rope.setup(top, outward, length)
	_practice.append(rope)


func add_ward(point: Vector3, normal: Vector3) -> void:
	var ward := Ward.new()
	add_child(ward)
	ward.global_position = point
	ward.setup(normal)
	_practice.append(ward)


func add_piton(point: Vector3, normal: Vector3) -> void:
	var model := Items.build_model(Items.Kind.PITON)
	add_child(model)
	var y := -normal  # とがった先を壁の中へ
	var x := y.cross(Vector3.UP)
	x = x.normalized() if x.length() > 0.1 else Vector3.RIGHT
	model.global_transform = Transform3D(Basis(x, y, x.cross(y)).scaled(Vector3.ONE * 1.5), point + normal * 0.1)
	_practice.append(model)


## 練習で使った道具を、すべて片づける
func clear_practice() -> void:
	for node in _practice:
		if is_instance_valid(node):
			node.queue_free()
	_practice.clear()


# --- 草地と、まわり ---

func _build_ground() -> void:
	_box(Vector3(FIELD.x * 2.0, 1.0, FIELD.y * 2.0), Vector3(0.0, -0.5, 0.0), Psx.material("ground_forest", Color(0.62, 0.68, 0.45), 0.25, 0.9))
	# 小道：スタート地点から北の訓練場へ、東の道具置き場と巻藁と的当てへ
	var path := Psx.material("ground_crag", Color(0.75, 0.7, 0.62), 0.4)
	_box(Vector3(3.0, 0.04, 44.0), Vector3(0.0, 0.02, 14.0), path, false)
	_box(Vector3(60.0, 0.04, 3.0), Vector3(20.0, 0.02, 12.0), path, false)
	_box(Vector3(46.0, 0.04, 3.0), Vector3(-18.0, 0.02, -12.0), path, false)


## 姿見：木の枠と、小さな屋根
func _build_mirror(viewer: Camera3D) -> void:
	mirror = Mirror.new()
	add_child(mirror)
	var center := MIRROR_AT + Vector3(0.0, 0.3 + MIRROR_SIZE.y / 2.0, 0.0)
	# 姿見の +Z（映す側）を北（訓練場の側, -Z）へ向ける
	mirror.transform = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)), center)
	mirror.setup(MIRROR_SIZE, viewer)
	var dark := Psx.material("wood", Color(0.3, 0.2, 0.13), 1.5)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.22, MIRROR_SIZE.y + 0.9, 0.22), center + Vector3(s * (MIRROR_SIZE.x / 2.0 + 0.11), -0.15, 0.05), dark)
	_box(Vector3(MIRROR_SIZE.x + 0.5, 0.2, 0.25), center + Vector3(0.0, MIRROR_SIZE.y / 2.0 + 0.1, 0.05), dark, false)
	_box(Vector3(MIRROR_SIZE.x + 0.5, 0.2, 0.25), center + Vector3(0.0, -MIRROR_SIZE.y / 2.0 - 0.1, 0.05), dark, false)
	var roof := PrismMesh.new()
	roof.size = Vector3(MIRROR_SIZE.x + 1.2, 0.5, 0.9)
	CreatureKit.part(self, roof, Psx.material("roof", Color(0.4, 0.3, 0.25), 1.0), center + Vector3(0.0, MIRROR_SIZE.y / 2.0 + 0.45, 0.05))
	_sign(MIRROR_AT + Vector3(3.4, 0.0, -0.6), "姿見", "E：身だしなみを整える\n（帽子・上着・マフラーの色と形）")


## スタート地点：古い山小屋と、火のついたたき火、案内の大看板
func _build_home() -> void:
	var hut := Structures.prop("hut", Vector3(-12.0, 0.0, 44.0), PI)
	add_child(hut)
	campfire = Campfire.new()
	add_child(campfire)
	campfire.position = Vector3(-5.5, 0.0, 33.0)
	campfire.set_lit(true)
	_sign(Vector3(3.0, 0.0, 30.0), "登山訓練場", "登る練習と、道具の練習ができます。\n北の壁や岩で登り、東で道具を試そう。\n準備ができたら、南のヘリで霊峰へ。", 1.3)


# --- 登る練習 ---

## ① 段差：高さのちがう台を 3 つ
func _build_steps() -> void:
	var stone := Psx.material("stone", Color(0.7, 0.68, 0.64), 0.8)
	for k in 3:
		var height: float = [0.7, 1.4, 1.9][k]
		_box(Vector3(3.0, height, 3.0), Vector3(-12.0 + k * 3.6, height / 2.0, 20.0), stone)
	_sign(Vector3(-8.4, 0.0, 24.0), "① 段差", "Space で跳ぶ。\n段差に向かって跳ぶと、縁に手をかけてよじ上る。\n低い段差は、歩くだけで上がれる。")


## ② 登りの壁：9 m の壁。裏に下りる階段
func _build_climb_wall() -> void:
	var rock := _rock_material("rock_crag", "dust_top", 0.3)
	var center := Vector3(-24.0, 0.0, 4.0)
	_box(Vector3(12.0, 9.0, 5.0), center + Vector3(0.0, 4.5, 0.0), rock)
	for k in 9:  # 裏（北）の階段
		var top := 9.0 - k
		_box(Vector3(3.0, top, 1.0), center + Vector3(4.0, top / 2.0, -3.0 - k), rock)
	_sign(center + Vector3(0.0, 0.0, 5.5), "② 登りの壁", "右クリック（手ぶらなら左クリック）を押している間、壁をつかむ。\nWASD で登り、てっぺんで上へ進むと乗り上がる。\n登りながら Space で上へ飛びつく（スタミナを使う）。\nスタミナが切れると落ちる。")


## ③ 張り出し：上から覆いかぶさる壁
func _build_overhang() -> void:
	var rock := _rock_material("rock_crag", "dust_top", 0.3)
	var center := Vector3(-36.0, 0.0, -18.0)
	_box(Vector3(8.0, 12.0, 4.0), center + Vector3(0.0, 6.0, 0.0), rock)
	_box(Vector3(8.0, 1.2, 4.0), center + Vector3(0.0, 11.4, 4.0), rock)   # 上の張り出し
	_box(Vector3(8.0, 1.0, 2.2), center + Vector3(0.0, 6.0, 3.1), rock)    # 途中の張り出し
	for k in 12:
		var top := 12.0 - k
		_box(Vector3(2.5, top, 1.0), center + Vector3(-5.2, top / 2.0, -1.5 - k * 0.0) + Vector3(0.0, 0.0, -k * 1.0), rock)
	_sign(center + Vector3(4.5, 0.0, 8.0), "③ 張り出し", "上から覆いかぶさる壁は、登ると早く疲れる。\n張り出しの下は、裏へ回りこむように登ろう。")


## ④ ロープと鎖の崖：15 m の崖に、ロープと鎖が垂れている
func _build_rope_cliff() -> void:
	var rock := _rock_material("rock_forest", "moss_top", 0.8)
	var center := Vector3(-8.0, 0.0, -30.0)
	_box(Vector3(14.0, 15.0, 6.0), center + Vector3(0.0, 7.5, 0.0), rock)
	var face := center.z + 3.0
	var rope := Rope.new()
	add_child(rope)
	rope.setup(to_global(Vector3(center.x - 3.0, 15.0, face)), global_transform.basis.z, 15.0)
	var chain := MeshInstance3D.new()
	chain.mesh = Flora.prop("chain")
	add_child(chain)
	chain.transform = Transform3D(Basis().scaled(Vector3.ONE * 1.5), Vector3(center.x + 3.0, 13.5, face + 0.02))
	for k in 15:  # 裏（北）の階段
		var top := 15.0 - k
		_box(Vector3(3.0, top, 1.0), center + Vector3(8.5, top / 2.0, 2.5 - k), rock)
	_sign(center + Vector3(0.0, 0.0, 6.5), "④ ロープと鎖", "ロープと鎖は、疲れにくく、楽に登れる。\nロープは道具にもあり、崖のふちで使うと下へ垂らせる。\n崖の途中でハーケンを使うと、ぶら下がって休める。")


## ⑤ 氷の壁
func _build_ice_cliff() -> void:
	var rock := _rock_material("rock_snow", "snow_top", 1.0)
	var center := Vector3(14.0, 0.0, -28.0)
	_box(Vector3(10.0, 10.0, 5.0), center + Vector3(0.0, 5.0, 0.0), rock)
	var ice := IceWall.new()
	add_child(ice)
	ice.setup(to_global(Vector3(center.x, 4.2, center.z + 2.5)), global_transform.basis.z)
	for k in 10:
		var top := 10.0 - k
		_box(Vector3(3.0, top, 1.0), center + Vector3(6.5, top / 2.0, 2.0 - k), rock)
	_sign(center + Vector3(0.0, 0.0, 6.5), "⑤ 氷の壁", "氷はつかんでも、すべってずり落ちる。\n道具置き場のアイゼンを使うと、しばらく滑らない。")


## ⑥ 岩の塔：山と同じ、ごつごつした大岩の積み重なり
func _build_boulder_tower() -> void:
	var material := _rock_material("rock_forest", "moss_top", 0.9)
	material.set_shader_parameter("flat_shading", true)
	material.set_shader_parameter("underside_dark", 0.62)
	var base := Vector3(30.0, 0.0, -14.0)
	var stack := [[4.6, Vector3(0.0, 2.6, 0.0)], [4.0, Vector3(1.4, 7.4, 0.8)], [3.4, Vector3(-0.8, 11.6, -0.6)],
		[3.8, Vector3(-4.2, 3.0, 2.6)], [2.8, Vector3(0.6, 15.0, 0.4)], [3.0, Vector3(4.0, 3.2, -3.0)], [2.2, Vector3(-0.4, 17.8, 0.0)]]
	for k in stack.size():
		var r: float = stack[k][0]
		var mesh := Terrain.blob_shape(10, 6, 700 + k * 37)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		add_child(instance)
		instance.transform = Transform3D(Basis(Vector3.UP, k * 1.7).scaled(Vector3(r * 2.1, r * 1.8, r * 2.0)), base + (stack[k][1] as Vector3))
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(instance.transform * mesh.get_faces())
		shape.backface_collision = true
		var collision := CollisionShape3D.new()
		collision.shape = shape
		_body.add_child(collision)
	_sign(base + Vector3(0.0, 0.0, 9.0), "⑥ 岩の塔", "山は、こんなごつごつした大岩の積み重なり。\n岩の張り出しの下は、横へ回りこんで登ろう。\n挟まって動けなくなったら、しばらく進もうとすると抜け出せる。")


# --- 道具の練習 ---

## ⑦ 道具置き場：すべての道具を台に並べる。E で好きなだけ取れる
func _build_item_tables() -> void:
	var origin := Vector3(8.0, 0.0, 22.0)
	var per_table := 10
	for t in 3:
		var table := origin + Vector3(t * 7.0, 0.0, 0.0)
		_box(Vector3(6.4, 0.9, 1.3), table + Vector3(2.8, 0.45, 0.0), _wood)
	for kind in Items.COUNT:
		var table := kind / per_table
		var slot := kind % per_table
		var rack := Rack.new()
		rack.kind = kind
		add_child(rack)
		rack.position = origin + Vector3(table * 7.0 + slot * 0.62, 0.95, 0.0)
		var tag := _label(Items.NAMES[kind], rack.position + Vector3(0.0, -0.3, 0.66), 0.0, 0.0022, Color(0.15, 0.1, 0.06))
		tag.font_size = 24
	_sign(origin + Vector3(8.0, 0.0, 3.2), "⑦ 道具置き場", "見ながら E で、好きなだけ取れる（練習用。山へは持っていけない）。\n1〜6・ホイールで手に持ち、左クリックで使う。Q で投げる。")


## ⑧ 巻藁：ナタで叩き、素手で殴る
func _build_dummies() -> void:
	for k in 3:
		var dummy := Dummy.new()
		add_child(dummy)
		dummy.position = Vector3(36.0 + k * 3.5, 0.0, 17.0)
		dummy.build(FONT)
	_sign(Vector3(39.5, 0.0, 21.5), "⑧ 巻藁", "ナタを持って左クリックで振る。押しっぱなしで振り続け、\n続けて振ると 3 振りめは重い一撃になる。\n手ぶらの左クリックは、殴る（つかめる壁がなければ）。")


## ⑨ 的当て：投げる線から、近い的・中くらいの的・遠い的
func _build_targets() -> void:
	var line := Vector3(56.0, 0.02, 12.0)
	_box(Vector3(10.0, 0.05, 0.3), line, _paint, false)
	for k in 3:
		var target := Target.new()
		add_child(target)
		target.position = Vector3(56.0 + (k - 1) * 3.0, 0.0, 12.0 - [8.0, 16.0, 28.0][k])
		target.build(FONT)
	_sign(line + Vector3(0.0, -0.02, 3.0), "⑨ 的当て", "Q を押している間、ためる。離すと投げる。\nためるほど強く、遠くへ飛ぶ。\n重い物・とがった物ほど、当たると痛い。")


# --- ヘリポート ---

## 南のヘリポート：コンクリートの発着場に H の印、吹き流し。霊峰行きのヘリが待っている
func _build_heliport() -> void:
	var pad := Vector3(14.0, 0.0, 54.0)
	var concrete := Psx.material("stone", Color(0.55, 0.55, 0.56), 0.3)
	var paint := Psx.material("", Color(0.92, 0.9, 0.82))
	_box(Vector3(18.0, 0.12, 18.0), pad + Vector3(0.0, 0.06, 0.0), concrete)
	for k in 24:  # 円の印
		var a := k * TAU / 24.0
		var mark := _box(Vector3(1.3, 0.02, 0.35), pad + Vector3(cos(a) * 6.5, 0.13, sin(a) * 6.5), paint, false)
		mark.rotation.y = -a + PI / 2.0
	for x in [-1.6, 1.6]:  # H の印
		_box(Vector3(0.5, 0.02, 4.4), pad + Vector3(x - 5.0, 0.13, 0.0), paint, false)
	_box(Vector3(2.7, 0.02, 0.5), pad + Vector3(-5.0, 0.13, 0.0), paint, false)
	var heli := Structures.prop("heli", pad + Vector3(0.0, 0.12, 0.0), 0.0)
	add_child(heli)
	_board_point = to_global(pad + Vector3(1.4, 0.6, 0.35))  # 右の扉の前
	# 吹き流し
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.06
	pole.height = 5.0
	CreatureKit.part(self, pole, Psx.material("", Color(0.75, 0.75, 0.78)), pad + Vector3(8.0, 2.5, -8.0))
	var sock := CylinderMesh.new()
	sock.top_radius = 0.12
	sock.bottom_radius = 0.3
	sock.height = 1.6
	var windsock := CreatureKit.part(self, sock, Psx.material("", Color(0.95, 0.45, 0.1)), pad + Vector3(8.7, 4.7, -8.0))
	windsock.rotation.z = PI / 2.0
	_sign(pad + Vector3(-6.0, 0.0, -10.0), "ヘリポート", "ヘリの右の扉まで行くと、霊峰へ出発する。")


# --- まわりの木と、遠くの山 ---

func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var models := [Flora.model("cedar"), Flora.model("cedar"), Flora.model("birch"), Flora.model("pine")]
	for i in 90:
		var p := Vector3(rng.randf_range(-FIELD.x, FIELD.x), 0.0, rng.randf_range(-FIELD.y, FIELD.y))
		if absf(p.x) < FIELD.x - 10.0 and absf(p.z) < FIELD.y - 10.0:
			continue  # 草地のふちにだけ
		if p.z > 42.0 and absf(p.x - 14.0) < 14.0:
			continue  # ヘリポートのまわりには生やさない
		var tree := MeshInstance3D.new()
		tree.mesh = models[rng.randi() % models.size()]
		add_child(tree)
		tree.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.3)), p)


## 北の空の下に見える、遠い霊峰の山並み（ただの影絵）
func _build_backdrop() -> void:
	var far := Psx.material("", Color(0.32, 0.36, 0.44))
	for peak: Array in [[Vector3(0.0, 0.0, -520.0), 190.0, 360.0], [Vector3(-260.0, 0.0, -470.0), 150.0, 230.0], [Vector3(250.0, 0.0, -480.0), 160.0, 270.0]]:
		var cone := CylinderMesh.new()
		cone.top_radius = 6.0
		cone.bottom_radius = peak[1]
		cone.height = peak[2]
		cone.radial_segments = 9
		CreatureKit.part(self, cone, far, (peak[0] as Vector3) + Vector3(0.0, (peak[2] as float) / 2.0 - 20.0, 0.0))


# --- 部品 ---

## 岩の素材（地帯の岩と同じ見た目）
func _rock_material(rock: String, top: String, top_amount: float) -> ShaderMaterial:
	var material := Psx.material(rock, Color.WHITE, 0.3, 1.0)
	material.set_shader_parameter("top_texture", Psx.texture(top))
	material.set_shader_parameter("top_amount", top_amount)
	return material


## 二本の脚の上に、題とやり方を書いた板の看板（南から読める）
func _sign(pos: Vector3, title: String, text: String, size := 1.0) -> void:
	var width := 3.4 * size
	var height := 1.9 * size
	for s in [-1.0, 1.0]:
		_box(Vector3(0.12, height + 0.9, 0.12), pos + Vector3(s * (width / 2.0 - 0.2), (height + 0.9) / 2.0, 0.0), _wood, false)
	_box(Vector3(width, height, 0.08), pos + Vector3(0.0, 0.9 + height / 2.0, 0.0), Psx.material("wood", Color(0.78, 0.66, 0.5), 1.5), false)
	_label(title, pos + Vector3(0.0, 0.9 + height - 0.3 * size, 0.05), 0.0, 0.0075 * size, Color(0.35, 0.08, 0.05))
	var body := _label(text, pos + Vector3(0.0, 0.9 + height * 0.42, 0.05), 0.0, 0.0034 * size, Color(0.12, 0.08, 0.05))
	body.width = width / body.pixel_size * 0.95
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY


func _label(text: String, pos: Vector3, yaw: float, pixel_size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 32
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = pos
	label.rotation.y = yaw
	add_child(label)
	return label


func _box(box_size: Vector3, center: Vector3, material: Material, collide := true) -> MeshInstance3D:
	return _box_in(self, box_size, center, material, collide)


func _box_in(parent: Node3D, box_size: Vector3, center: Vector3, material: Material, collide: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := CreatureKit.part(parent, mesh, material, center)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = box_size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		# 当たり判定は、すべて訓練場（このノード）から見た位置に置く
		var parent_transform := Transform3D() if parent == self else parent.transform
		collision.transform = parent_transform * Transform3D(Basis(), center)
		_body.add_child(collision)
	return instance


## 与えた傷の数字を、ふわっと浮かべて消す
static func pop_number(near: Node3D, pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 48
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	near.add_child(label)
	label.global_position = pos
	var tween := label.create_tween()
	tween.tween_property(label, "global_position", pos + Vector3.UP * 0.9, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.tween_callback(label.queue_free)


## 道具置き場に並ぶ道具。見ながら E で、いくつでも取れる
class Rack extends Node3D:
	var kind := 0

	func _ready() -> void:
		add_to_group(&"interactables")
		var model := Items.build_model(kind)
		model.scale = Vector3.ONE * 1.6
		add_child(model)

	func interact_hint(_player: Player) -> String:
		return "E：%sを取る（練習用）" % Items.NAMES[kind]

	func interact(player: Player) -> void:
		if player.pick_up(kind):
			player.message.emit("%sを手に取った（1〜6 で持ち替え）" % Items.NAMES[kind])


## 巻藁：ナタで叩いたり、殴ったりする練習台。与えた傷が浮かび、合計が札に出る（壊れない）
class Dummy extends Node3D:
	var total := 0.0
	var _bundle: Node3D
	var _tally: Label3D

	func build(font: Font) -> void:
		add_to_group(&"creatures")
		add_to_group(&"practice")  # 練習台：化け物ではないので、傷はそのまま入る
		var wood := Psx.material("wood", Color(0.45, 0.32, 0.2), 1.2)
		var straw := Psx.material("", Color(0.82, 0.7, 0.42))
		var post := CylinderMesh.new()
		post.top_radius = 0.07
		post.bottom_radius = 0.09
		post.height = 1.0
		CreatureKit.part(self, post, wood, Vector3(0.0, 0.5, 0.0))
		_bundle = Node3D.new()
		_bundle.position = Vector3(0.0, 0.9, 0.0)
		add_child(_bundle)
		var bundle := CylinderMesh.new()
		bundle.top_radius = 0.26
		bundle.bottom_radius = 0.3
		bundle.height = 1.3
		CreatureKit.part(_bundle, bundle, straw, Vector3(0.0, 0.65, 0.0))
		for y in [0.25, 0.65, 1.05]:  # 縛った縄
			var tie := CylinderMesh.new()
			tie.top_radius = 0.3
			tie.bottom_radius = 0.3
			tie.height = 0.05
			CreatureKit.part(_bundle, tie, wood, Vector3(0.0, y, 0.0))
		var head := CreatureKit.sphere(0.2)
		CreatureKit.part(_bundle, head, straw, Vector3(0.0, 1.45, 0.0))
		var arm := BoxMesh.new()
		arm.size = Vector3(1.2, 0.08, 0.08)
		CreatureKit.part(_bundle, arm, wood, Vector3(0.0, 1.05, 0.0))
		# 看板と同じ向き（南）に、合計の札
		_tally = Label3D.new()
		_tally.font = font
		_tally.font_size = 32
		_tally.pixel_size = 0.004
		_tally.modulate = Color(0.12, 0.08, 0.05)
		_tally.text = "合計 0"
		_tally.position = Vector3(0.0, 0.35, 0.12)
		add_child(_tally)
		var board := BoxMesh.new()
		board.size = Vector3(0.7, 0.22, 0.02)
		CreatureKit.part(self, board, Psx.material("", Color(0.85, 0.8, 0.68)), Vector3(0.0, 0.35, 0.1))

	func hit_center() -> Vector3:
		return global_position + Vector3.UP * 1.5

	func hit_radius() -> float:
		return 0.45

	func scare(_from: Vector3) -> void:
		pass

	func hit(damage: float, _attacker: Node3D) -> void:
		total += damage
		_tally.text = "合計 %d" % roundi(total)
		Lobby.pop_number(self, hit_center() + Vector3.UP * 0.5, "%d" % roundi(damage), Color(1.0, 0.85, 0.3) if damage < 40.0 else Color(1.0, 0.35, 0.2))
		_bundle.rotation.z = (0.3 if randf() < 0.5 else -0.3) * clampf(damage / 40.0, 0.3, 1.0)
		var tween := create_tween()
		tween.tween_property(_bundle, "rotation:z", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 的：投げた物を当てる、丸い板。当たると傷の数字が浮かび、板がゆれる
class Target extends Node3D:
	var hits := 0
	var _board: Node3D
	var _tally: Label3D

	func build(font: Font) -> void:
		add_to_group(&"creatures")
		add_to_group(&"practice")
		var wood := Psx.material("wood", Color(0.45, 0.32, 0.2), 1.2)
		for s in [-1.0, 1.0]:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.1, 1.9, 0.1)
			CreatureKit.part(self, leg, wood, Vector3(s * 0.55, 0.95, 0.0))
		_board = Node3D.new()
		_board.position = Vector3(0.0, 1.6, 0.06)
		add_child(_board)
		var colors := [Color(0.9, 0.88, 0.82), Color(0.75, 0.12, 0.1), Color(0.9, 0.88, 0.82), Color(0.75, 0.12, 0.1)]
		for k in colors.size():
			var ring := CylinderMesh.new()
			ring.top_radius = 0.7 - k * 0.16
			ring.bottom_radius = ring.top_radius
			ring.height = 0.04 + k * 0.012
			var disc := CreatureKit.part(_board, ring, Psx.material("", colors[k]), Vector3.ZERO)
			disc.rotation.x = PI / 2.0
		_tally = Label3D.new()
		_tally.font = font
		_tally.font_size = 32
		_tally.pixel_size = 0.005
		_tally.modulate = Color(0.12, 0.08, 0.05)
		_tally.text = "命中 0"
		_tally.position = Vector3(0.0, 0.6, 0.08)
		add_child(_tally)

	func hit_center() -> Vector3:
		return _board.global_position

	func hit_radius() -> float:
		return 0.6

	func scare(_from: Vector3) -> void:
		pass

	func hit(damage: float, _attacker: Node3D) -> void:
		hits += 1
		_tally.text = "命中 %d" % hits
		Lobby.pop_number(self, hit_center() + Vector3.UP * 0.6, "%d" % roundi(damage), Color(1.0, 0.85, 0.3) if damage < 20.0 else Color(1.0, 0.35, 0.2))
		_board.rotation.x = -0.35
		var tween := create_tween()
		tween.tween_property(_board, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
