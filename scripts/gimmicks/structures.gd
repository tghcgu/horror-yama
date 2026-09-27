class_name Structures
extends RefCounted
## 平地に建つ建造物と、登れる巨木。どれも壁や幹をつかんで登れ、屋根や枝や台の上に立てる。
##   廃小屋（樹海・雪山）、見張り櫓（岩場）、崩れた石垣（岩場・霊峰）、石段と石灯籠（霊峰）、
##   御神木（樹海。しめ縄つきの巨木で、太い枝が足場になる）、氷の柱（雪山。つかむと滑る）
## 形は MeshBuilder で 1 つにまとめ、当たり判定は箱や円柱を並べる（地形と同じ層なので、つかんで登れる）。


## 部品を足していく道具：見た目の形と、当たり判定の箱をいっしょに足す
class Kit:
	var body: StaticBody3D
	var look := MeshBuilder.new()

	func _init(pos: Vector3, yaw: float) -> void:
		body = StaticBody3D.new()
		body.collision_layer = Player.TERRAIN_LAYER
		body.position = pos
		body.rotation.y = yaw

	## 箱（見た目と当たり判定）
	func box(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, solid := true) -> void:
		look.add(BoxMesh.new(), pos, rot, size, color)
		if solid:
			var shape := BoxShape3D.new()
			shape.size = size
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = pos
			collision.rotation = rot
			body.add_child(collision)

	## 円柱（見た目と当たり判定）
	func column(radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, solid := true, top := -1.0) -> void:
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius if top < 0.0 else top
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 10
		look.add(mesh, pos, rot, Vector3.ONE, color)
		if solid:
			var shape := CylinderShape3D.new()
			shape.radius = radius
			shape.height = height
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = pos
			collision.rotation = rot
			body.add_child(collision)

	## 見た目だけ（葉やしめ縄など）
	func deco(mesh: PrimitiveMesh, pos: Vector3, color: Color, rot := Vector3.ZERO, part_scale := Vector3.ONE) -> void:
		look.add(mesh, pos, rot, part_scale, color)

	func finish(texture: String, texture_scale := 1.0) -> StaticBody3D:
		look.instance(body, Psx.vertex_material(texture, texture_scale, 0.8))
		return body


## Blender で作った建物・置き物を、見た目どおりの当たり判定つきで建てる（壁も幹もつかんで登れる）
static func prop(prop_name: String, pos: Vector3, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Player.TERRAIN_LAYER
	body.position = pos
	body.rotation.y = yaw
	body.set_meta("prop", prop_name)
	var mesh := Flora.prop(prop_name)
	var look := MeshInstance3D.new()
	look.mesh = mesh
	body.add_child(look)
	var collision := CollisionShape3D.new()
	collision.shape = Flora.solid_shape(mesh)
	body.add_child(collision)
	return body


## 山小屋：縦板の壁と錆びたトタン屋根の、古い避難小屋。戸口から入れ、屋根に登れる
static func hut(pos: Vector3, yaw: float, snowy: bool) -> StaticBody3D:
	if not snowy:
		return prop("hut", pos, yaw)
	var kit := Kit.new(pos, yaw)
	var wall := Color(0.45, 0.33, 0.22)
	var dark := Color(0.28, 0.2, 0.14)
	var w := 4.0
	var d := 5.0
	var h := 2.8
	kit.box(Vector3(w, 0.2, d), Vector3(0.0, 0.1, 0.0), dark)  # 床
	kit.box(Vector3(w, h, 0.2), Vector3(0.0, h * 0.5, -d * 0.5), wall)  # 奥の壁
	kit.box(Vector3(0.2, h, d), Vector3(-w * 0.5, h * 0.5, 0.0), wall)
	kit.box(Vector3(0.2, h, d), Vector3(w * 0.5, h * 0.5, 0.0), wall)
	kit.box(Vector3(1.4, h, 0.2), Vector3(-w * 0.5 + 0.7, h * 0.5, d * 0.5), wall)  # 戸口の左右
	kit.box(Vector3(1.4, h, 0.2), Vector3(w * 0.5 - 0.7, h * 0.5, d * 0.5), wall)
	kit.box(Vector3(1.2, 0.6, 0.2), Vector3(0.0, h - 0.3, d * 0.5), wall)  # 戸口の上
	for side in [-1.0, 1.0]:  # 切妻の屋根（片方ずつ傾けた板）
		kit.box(Vector3(w * 0.62, 0.18, d + 0.6), Vector3(side * w * 0.26, h + 0.62, 0.0), Color(0.92, 0.94, 0.97) if snowy else dark,
			Vector3(0.0, 0.0, -side * 0.55))
	for i in 5:  # 板の継ぎ目
		kit.box(Vector3(0.04, h, 0.03), Vector3(-w * 0.5 + 0.12, h * 0.5, -d * 0.5 + 0.5 + i * 1.0), dark, Vector3.ZERO, false)
	return kit.finish("wood")


## 見張り櫓：4 本の柱で立つ高い台。はしごで登れる
static func tower(pos: Vector3, yaw: float, snowy: bool) -> StaticBody3D:
	var kit := Kit.new(pos, yaw)
	var wood := Color(0.5, 0.38, 0.26)
	var height := 9.0
	for x in [-1.3, 1.3]:
		for z in [-1.3, 1.3]:
			kit.column(0.14, height, Vector3(x, height * 0.5, z), wood)
	for level in [3.0, 6.0]:  # すじかい
		kit.box(Vector3(2.8, 0.1, 0.1), Vector3(0.0, level, 1.3), wood, Vector3(0.0, 0.0, 0.4), false)
		kit.box(Vector3(2.8, 0.1, 0.1), Vector3(0.0, level, -1.3), wood, Vector3(0.0, 0.0, -0.4), false)
	kit.box(Vector3(3.4, 0.25, 3.4), Vector3(0.0, height, 0.0), wood.darkened(0.2))  # 台
	for side in [-1.0, 1.0]:  # 手すり
		kit.box(Vector3(3.4, 0.8, 0.08), Vector3(0.0, height + 0.5, side * 1.66), wood)
		kit.box(Vector3(0.08, 0.8, 3.4), Vector3(side * 1.66, height + 0.5, 0.0), wood)
	kit.box(Vector3(3.8, 0.12, 3.8), Vector3(0.0, height + 2.2, 0.0), Color(0.92, 0.94, 0.97) if snowy else wood.darkened(0.3))  # 屋根
	for x in [-1.5, 1.5]:
		kit.column(0.07, 1.4, Vector3(x, height + 1.5, 1.5), wood, Vector3.ZERO, false)
		kit.column(0.07, 1.4, Vector3(x, height + 1.5, -1.5), wood, Vector3.ZERO, false)
	# はしご：前の面に、つかめる板（桟の見た目つき）
	kit.box(Vector3(0.6, height, 0.12), Vector3(0.0, height * 0.5, 1.75), wood.lightened(0.05))
	for i in int(height / 0.4):
		kit.box(Vector3(0.6, 0.05, 0.08), Vector3(0.0, 0.3 + i * 0.4, 1.83), wood.darkened(0.3), Vector3.ZERO, false)
	return kit.finish("wood")


## 崩れた石垣：高さのばらばらな石積みの壁と、崩れ落ちた石、壁を這う蔦。よじ登って渡っていける
static func ruins(pos: Vector3, yaw: float, rng: RandomNumberGenerator, mossy: bool) -> StaticBody3D:
	if mossy:
		return prop(["ruins_a", "ruins_b", "ruins_c"][rng.randi() % 3], pos, yaw)
	var kit := Kit.new(pos, yaw)
	var stone := Color(0.62, 0.6, 0.56) if not mossy else Color(0.5, 0.55, 0.45)
	var x := -7.0
	while x < 7.0:
		var length := rng.randf_range(1.5, 3.5)
		var height := rng.randf_range(1.0, 5.0)
		kit.box(Vector3(length, height, 1.0), Vector3(x + length * 0.5, height * 0.5, rng.randf_range(-0.3, 0.3)),
			stone.darkened(rng.randf_range(0.0, 0.2)), Vector3(0.0, rng.randf_range(-0.08, 0.08), 0.0))
		x += length + rng.randf_range(0.0, 1.6)  # ところどころ崩れて、すき間がある
	for i in rng.randi_range(4, 8):  # 崩れ落ちた石
		var s := rng.randf_range(0.5, 1.2)
		kit.box(Vector3.ONE * s, Vector3(rng.randf_range(-7.0, 7.0), s * 0.4, rng.randf_range(-3.0, 3.0)), stone.darkened(0.1),
			Vector3(rng.randf(), rng.randf(), rng.randf()))
	return kit.finish("stone", 0.8)


## 石段と石灯籠：塚の上の小さなほこらへ続く石段
static func stairs(pos: Vector3, yaw: float) -> StaticBody3D:
	var kit := Kit.new(pos, yaw)
	var stone := Color(0.6, 0.58, 0.58)
	var steps := 12
	for i in steps:
		kit.box(Vector3(2.4, 0.4, 0.5), Vector3(0.0, 0.2 + i * 0.4, -i * 0.5), stone.darkened(0.05 * (i % 2)))
		kit.box(Vector3(2.4, 0.4 + i * 0.4, 0.5), Vector3(0.0, (0.4 + i * 0.4) * 0.5, -i * 0.5), stone.darkened(0.15), Vector3.ZERO, false)
	var top := Vector3(0.0, steps * 0.4, -steps * 0.5 - 1.5)
	kit.box(Vector3(4.0, steps * 0.4, 3.0), Vector3(0.0, steps * 0.2, top.z), stone.darkened(0.1))  # 上の台
	kit.box(Vector3(1.0, 1.0, 0.8), top + Vector3(0.0, 0.5, -0.6), Color(0.45, 0.32, 0.22))  # 小さなほこら
	var roof := PrismMesh.new()
	kit.deco(roof, top + Vector3(0.0, 1.25, -0.6), Color(0.2, 0.2, 0.22), Vector3.ZERO, Vector3(1.3, 0.5, 1.1))
	for side in [-1.0, 1.0]:  # 石灯籠
		var base := Vector3(side * 1.6, 0.0, 0.6)
		kit.column(0.18, 0.2, base + Vector3(0.0, 0.1, 0.0), stone)
		kit.column(0.07, 0.9, base + Vector3(0.0, 0.65, 0.0), stone)
		kit.box(Vector3(0.36, 0.32, 0.36), base + Vector3(0.0, 1.25, 0.0), stone)
		kit.deco(PrismMesh.new(), base + Vector3(0.0, 1.55, 0.0), stone, Vector3.ZERO, Vector3(0.55, 0.25, 0.55))
	return kit.finish("stone", 0.8)


## 御神木：見上げるほどの杉の巨木。しめ縄が巻かれ、太い枝が足場になる。幹をつかんで登れる
static func giant_tree(pos: Vector3, rng: RandomNumberGenerator) -> StaticBody3D:
	return prop("shinboku", pos, rng.randf() * TAU)


static func _old_giant_tree(pos: Vector3, rng: RandomNumberGenerator) -> StaticBody3D:
	var kit := Kit.new(pos, rng.randf() * TAU)
	var bark := Color(0.42, 0.3, 0.22)
	var height := rng.randf_range(20.0, 26.0)
	kit.column(1.5, height, Vector3(0.0, height * 0.5, 0.0), bark, Vector3.ZERO, true, 0.7)
	# 根の張り出し
	for i in 5:
		var angle := i * TAU / 5.0 + rng.randf() * 0.4
		kit.box(Vector3(0.7, 1.4, 2.4), Vector3(cos(angle) * 1.6, 0.5, sin(angle) * 1.6), bark.darkened(0.1),
			Vector3(0.3, -angle + PI / 2.0, 0.0))
	# しめ縄と紙垂
	var rope := TorusMesh.new()
	rope.inner_radius = 1.45
	rope.outer_radius = 1.7
	kit.deco(rope, Vector3(0.0, 2.6, 0.0), Color(0.85, 0.75, 0.45))
	for i in 6:
		var angle := i * TAU / 6.0
		kit.deco(BoxMesh.new(), Vector3(cos(angle) * 1.72, 2.2, sin(angle) * 1.72), Color(0.97, 0.97, 0.95),
			Vector3(0.0, -angle, 0.0), Vector3(0.18, 0.5, 0.02))
	# 太い枝（上に乗れる）と、こんもりした葉
	var leaf := Color(0.18, 0.28, 0.16)
	for i in 7:
		var y := height * rng.randf_range(0.35, 0.95)
		var angle := rng.randf() * TAU
		var length := rng.randf_range(3.0, 5.5)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		kit.box(Vector3(length, 0.5, 0.6), direction * (length * 0.5 + 0.8) + Vector3.UP * y, bark,
			Vector3(0.0, -angle, 0.12))
		var crown := SphereMesh.new()
		crown.radial_segments = 8
		crown.rings = 5
		kit.deco(crown, direction * (length + 0.8) + Vector3.UP * (y + 1.2), leaf, Vector3.ZERO, Vector3(4.5, 2.6, 4.5))
	var top := SphereMesh.new()
	top.radial_segments = 8
	top.rings = 5
	kit.deco(top, Vector3.UP * (height + 1.5), leaf, Vector3.ZERO, Vector3(7.0, 5.0, 7.0))
	return kit.finish("bark", 0.8)


## 氷の柱：雪原から突き出た、何本もの氷の柱。つかめるが、すべる
static func ice_pillars(pos: Vector3, rng: RandomNumberGenerator) -> StaticBody3D:
	var body := prop("ice_pillars", pos, rng.randf() * TAU)  # Blender で作った、ねじれた氷の柱の群れ
	body.scale = Vector3.ONE * rng.randf_range(0.9, 1.25)
	body.add_to_group(&"ice")
	return body
