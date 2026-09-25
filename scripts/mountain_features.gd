class_name MountainFeatures
extends Node3D
## 山の上の置き物：地帯ごとの木や岩、山頂の鳥居と祠、落ちているアイテム、壁の岩グモ。
## 打ち込んだハーケンや貼ったお札もここで管理し、やり直すたびに片づける。

const CEDAR_COUNT := 170
const DEAD_TREE_COUNT := 70
const SNOW_TREE_COUNT := 45
const BOULDER_COUNT := 45
const CAIRN_COUNT := 14
const SPIDER_COUNT := 10
const PICKUPS_PER_BIOME := [5, 6, 6, 2]
const WORLD_SEED := 7

var _terrain: Terrain
var _player: Player
var _run_nodes: Array[Node] = []  # やり直しで片づけるもの（アイテム・ハーケン・お札）
var _lanterns: Array[OmniLight3D] = []
var _time := 0.0


func build(terrain: Terrain, player: Player) -> void:
	_terrain = terrain
	_player = player
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	_add_trees(rng)
	_add_rocks(rng)
	_add_shrine()
	_add_spiders(rng)


## やり直すたびに、アイテムを置き直し、ハーケンとお札を片づける
func reset_run() -> void:
	for node in _run_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_run_nodes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED + 100
	for biome in PICKUPS_PER_BIOME.size():
		var bottom: float = 3.0 if biome == 0 else Biomes.TOPS[biome - 1]
		var top: float = minf(Biomes.TOPS[biome], 10000.0)
		for point in _terrain.random_ledge_points(rng, PICKUPS_PER_BIOME[biome], bottom, top, 12.0, 3):
			var pickup := Pickup.new()
			add_child(pickup)
			pickup.global_position = point
			pickup.setup(Items.pick_random(rng), _player)
			_run_nodes.append(pickup)


func add_piton(point: Vector3, normal: Vector3) -> void:
	var model := Items.build_model(Items.Kind.PITON)
	add_child(model)
	var y := -normal  # とがった先を壁の中へ
	var x := y.cross(Vector3.UP)
	x = x.normalized() if x.length() > 0.1 else Vector3.RIGHT
	model.global_transform = Transform3D(Basis(x, y, x.cross(y)).scaled(Vector3.ONE * 1.5), point + normal * 0.1)
	_run_nodes.append(model)


func add_ward(point: Vector3, normal: Vector3) -> void:
	var ward := Ward.new()
	add_child(ward)
	ward.global_position = point
	ward.setup(normal)
	_run_nodes.append(ward)


func _process(delta: float) -> void:
	_time += delta
	for i in _lanterns.size():
		_lanterns[i].light_energy = 1.3 + 0.25 * sin(_time * 11.0 + i * 2.0) + randf() * 0.15


# --- 木 ---

func _add_trees(rng: RandomNumberGenerator) -> void:
	# スタート地点から最初の崖までは、道として木を置かない
	var spawn := _terrain.spawn_point()
	var trail := PackedVector3Array([spawn, spawn + Vector3(0.0, 0.0, -6.0), spawn + Vector3(0.0, 0.0, -12.0)])
	var forest_top: float = Biomes.TOPS[Biomes.Id.FOREST]
	var cedars := _terrain.random_ledge_points(rng, CEDAR_COUNT, -1.0, forest_top - 2.0, 4.0, 4, trail, 5.0)
	var dead := _terrain.random_ledge_points(rng, DEAD_TREE_COUNT, -1.0, forest_top - 2.0, 4.0, 4, trail, 5.0)
	var snowy := _terrain.random_ledge_points(rng, SNOW_TREE_COUNT, Biomes.TOPS[Biomes.Id.CRAG], Biomes.TOPS[Biomes.Id.SNOW] - 2.0, 5.0, 4)

	var bark := Psx.material("bark", Color(0.7, 0.6, 0.55), 0.8)
	var needles := Psx.material("ground_forest", Color(0.2, 0.3, 0.18), 0.9, 0.3)
	var dead_wood := Psx.material("bark", Color(0.8, 0.78, 0.75), 0.8, 0.2)
	var frosted := Psx.material("bark", Color(1.5, 1.55, 1.65), 0.8, 0.0)

	var cedar_transforms := _tree_transforms(rng, cedars, 0.8, 1.3)
	_multimesh(_cedar_trunk_mesh(), bark, cedar_transforms)
	_multimesh(_cedar_needles_mesh(), needles, cedar_transforms)
	var dead_transforms := _tree_transforms(rng, dead, 0.7, 1.2)
	_multimesh(_dead_tree_mesh(), dead_wood, dead_transforms)
	var snowy_transforms := _tree_transforms(rng, snowy, 0.6, 1.0)
	_multimesh(_dead_tree_mesh(), frosted, snowy_transforms)

	var trunks := StaticBody3D.new()
	add_child(trunks)
	for transforms in [cedar_transforms, dead_transforms, snowy_transforms]:
		for t: Transform3D in transforms:
			var s := t.basis.get_scale().y
			var shape := CylinderShape3D.new()
			shape.radius = 0.3 * s
			shape.height = 8.0 * s
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = t.origin + Vector3.UP * 4.0 * s
			trunks.add_child(collision)


func _tree_transforms(rng: RandomNumberGenerator, points: PackedVector3Array, min_scale: float, max_scale: float) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for p in points:
		var s := rng.randf_range(min_scale, max_scale)
		var tree_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		result.append(Transform3D(tree_basis, p - Vector3.UP * 0.2))
	return result


## 杉：まっすぐな幹と、何段も重なった円すいの葉
func _cedar_trunk_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.1
	trunk.bottom_radius = 0.28
	trunk.height = 10.0
	return _merge([[trunk, Transform3D(Basis(), Vector3(0.0, 5.0, 0.0))]])


func _cedar_needles_mesh() -> ArrayMesh:
	var parts := []
	for i in 5:
		var layer := CylinderMesh.new()
		layer.top_radius = 0.0
		layer.bottom_radius = 2.0 - i * 0.35
		layer.height = 2.8
		layer.radial_segments = 10
		parts.append([layer, Transform3D(Basis(), Vector3(0.0, 4.0 + i * 1.4, 0.0))])
	return _merge(parts)


## 枯れ木：細い幹から、ねじれた枝が四方へ伸びる
func _dead_tree_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.05
	trunk.bottom_radius = 0.22
	trunk.height = 7.0
	var parts := [[trunk, Transform3D(Basis(), Vector3(0.0, 3.5, 0.0))]]
	for i in 6:
		var branch := CylinderMesh.new()
		branch.top_radius = 0.015
		branch.bottom_radius = 0.07
		branch.height = 2.4 - i * 0.2
		branch.radial_segments = 6
		var branch_basis := Basis(Vector3.UP, i * 2.1) * Basis(Vector3.BACK, -0.8 - (i % 2) * 0.3)
		var base := Vector3(0.0, 2.4 + i * 0.65, 0.0)
		parts.append([branch, Transform3D(branch_basis, base + branch_basis.y * branch.height / 2.0)])
	return _merge(parts)


# --- 岩 ---

func _add_rocks(rng: RandomNumberGenerator) -> void:
	var stone := Psx.material("boulder", Color(0.65, 0.65, 0.66), 0.6, 0.3)
	var boulders := _terrain.random_ledge_points(rng, BOULDER_COUNT, Biomes.TOPS[Biomes.Id.FOREST], 10000.0, 6.0, 4)
	var boulder_mesh := SphereMesh.new()
	boulder_mesh.radius = 1.0
	boulder_mesh.height = 2.0
	boulder_mesh.radial_segments = 9
	boulder_mesh.rings = 5
	var transforms: Array[Transform3D] = []
	var bodies := StaticBody3D.new()
	add_child(bodies)
	for p in boulders:
		var size := Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.4, 1.0), rng.randf_range(0.5, 1.4))
		var center := p + Vector3.UP * size.y * 0.4
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(size), center))
		var shape := SphereShape3D.new()
		shape.radius = minf(size.x, size.z) * 0.85
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = center
		bodies.add_child(collision)
	_multimesh(boulder_mesh, stone, transforms)

	# 積み石：誰かが積んだ小さな石の塔
	var cairns := _terrain.random_ledge_points(rng, CAIRN_COUNT, Biomes.TOPS[Biomes.Id.FOREST], Biomes.TOPS[Biomes.Id.SNOW], 10.0, 3)
	var parts := []
	var heights := [0.12, 0.36, 0.56, 0.72]
	var radii := [0.35, 0.27, 0.2, 0.13]
	for i in 4:
		var pebble := SphereMesh.new()
		pebble.radial_segments = 8
		pebble.rings = 4
		pebble.radius = radii[i]
		pebble.height = radii[i] * 2.0
		parts.append([pebble, Transform3D(Basis().scaled(Vector3(1.0, 0.5, 0.85)), Vector3(0.02 * i, heights[i], 0.0))])
	var cairn_transforms: Array[Transform3D] = []
	for p in cairns:
		cairn_transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
	_multimesh(_merge(parts), stone, cairn_transforms)


# --- 山頂の鳥居と祠 ---

func _add_shrine() -> void:
	var center := _terrain.summit_position
	var radius := _plateau_radius(center)
	var red := Psx.material("wood", Color(1.0, 0.22, 0.12), 1.0, 0.6)  # 朱塗り
	var black := Psx.material("roof", Color(0.6, 0.6, 0.62), 1.2)  # 瓦
	var wood := Psx.material("wood", Color(0.75, 0.6, 0.45), 1.0)
	var stone := Psx.material("stone", Color(0.8, 0.8, 0.78), 1.5)
	var bodies := StaticBody3D.new()
	add_child(bodies)

	# 祠
	var shrine := _anchor(center + Vector3(0.0, 0.0, -radius * 0.45))
	CreatureKit.part(shrine, _box(Vector3(1.4, 0.4, 1.2)), stone, Vector3(0.0, 0.2, 0.0))
	CreatureKit.part(shrine, _box(Vector3(1.0, 0.8, 0.8)), wood, Vector3(0.0, 0.8, 0.0))
	var roof := PrismMesh.new()
	roof.size = Vector3(1.5, 0.5, 1.2)
	CreatureKit.part(shrine, roof, black, Vector3(0.0, 1.45, 0.0))
	_add_box_collision(bodies, shrine.global_position + Vector3.UP * 0.7, Vector3(1.4, 1.4, 1.2))

	# 石灯籠（ろうそくの火がゆらめく）
	for side in [-1.0, 1.0]:
		var lantern := _anchor(center + Vector3(1.5 * side, 0.0, -radius * 0.1))
		CreatureKit.part(lantern, _cylinder(0.2, 0.2, 0.2), stone, Vector3(0.0, 0.1, 0.0))
		CreatureKit.part(lantern, _cylinder(0.07, 0.07, 0.8), stone, Vector3(0.0, 0.6, 0.0))
		CreatureKit.part(lantern, _box(Vector3(0.32, 0.3, 0.32)), stone, Vector3(0.0, 1.15, 0.0))
		CreatureKit.part(lantern, CreatureKit.sphere(0.07), CreatureKit.glow(Color(1.0, 0.55, 0.2), 4.0), Vector3(0.0, 1.15, 0.0))
		var cap := PrismMesh.new()
		cap.size = Vector3(0.5, 0.22, 0.5)
		CreatureKit.part(lantern, cap, stone, Vector3(0.0, 1.41, 0.0))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.omni_range = 7.0
		light.position.y = 1.15
		lantern.add_child(light)
		_lanterns.append(light)

	# 鳥居（足場が狭すぎるときは置かない）
	if radius < 2.5:
		return
	var gate := _anchor(center + Vector3(0.0, 0.0, radius * 0.8))
	for side in [-1.0, 1.0]:
		CreatureKit.part(gate, _cylinder(0.14, 0.16, 3.6), red, Vector3(1.4 * side, 1.8, 0.0))
		var pillar := CylinderShape3D.new()
		pillar.radius = 0.16
		pillar.height = 3.6
		var collision := CollisionShape3D.new()
		collision.shape = pillar
		collision.position = gate.global_position + Vector3(1.4 * side, 1.8, 0.0)
		bodies.add_child(collision)
	CreatureKit.part(gate, _box(Vector3(3.5, 0.18, 0.2)), red, Vector3(0.0, 2.9, 0.0))
	CreatureKit.part(gate, _box(Vector3(4.2, 0.2, 0.32)), red, Vector3(0.0, 3.45, 0.0))
	CreatureKit.part(gate, _box(Vector3(4.5, 0.12, 0.38)), black, Vector3(0.0, 3.6, 0.0))


## 山頂の平らな場所の広さ（中心から何 m まで、ほぼ同じ高さが続くか）
func _plateau_radius(center: Vector3) -> float:
	var radius := 1.0
	while radius < 6.0:
		var next := radius + 0.5
		for i in 8:
			var angle := i * TAU / 8.0
			var h := _terrain.height_at(center.x + cos(angle) * next, center.z + sin(angle) * next)
			if absf(h - center.y) > 1.2:
				return radius
		radius = next
	return radius


## 地面の高さに合わせて置く、置き物の基準点
func _anchor(pos: Vector3) -> Node3D:
	var anchor := Node3D.new()
	add_child(anchor)
	anchor.global_position = Vector3(pos.x, _terrain.height_at(pos.x, pos.z), pos.z)
	return anchor


func _add_box_collision(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position = center
	body.add_child(collision)


# --- 岩グモ ---

func _add_spiders(rng: RandomNumberGenerator) -> void:
	var bottom: float = Biomes.TOPS[Biomes.Id.FOREST] + 2.0
	var top: float = Biomes.TOPS[Biomes.Id.CRAG] - 2.0
	for entry: Array in _terrain.random_wall_points(rng, SPIDER_COUNT, bottom, top, 10.0):
		var spider := CragSpider.new()
		add_child(spider)
		spider.setup(entry[0], entry[1], _player)


# --- 道具 ---

func _multimesh(mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)


## いくつかの形を、1つのメッシュにまとめる（[メッシュ, 置く位置と向き] の配列から）
func _merge(parts: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	for part: Array in parts:
		tool.append_from(part[0], 0, part[1])
	return tool.commit()


func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	return cylinder
