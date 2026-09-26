class_name MountainFeatures
extends Node3D
## 山の上の置き物：地帯ごとの木や積み石、各山の頂上のたき火、霊峰の鳥居と祠、落ちているアイテム、壁の岩グモ、
## 木の上の手長、地帯ごとのギミック（沼・罠・落石・噴気孔・隠れクレバス・雪崩・突風・飛び石・鳥居・お地蔵さん など）。
## 打ち込んだハーケン・貼ったお札・垂らしたロープ・投げたアイテムもここで管理する。山を作り直すたびに、まるごと作り直す。

const CEDAR_COUNT := 260
const DEAD_TREE_COUNT := 90
const SNOW_TREE_COUNT := 40
const CAIRN_COUNT := 8     # 岩場と雪山、それぞれ
const SPIDER_COUNT := 12
const TENAGA_COUNT := 7
const PICKUPS_PER_BIOME := [9, 9, 9, 5]
const KEEP_CLEAR := 7.0  # たき火や祠のまわりには、木や岩を置かない
const TREE_TILE := 48.0      # 木を区画ごとにまとめる大きさ (m)。見えない区画は描かない
const TREE_RANGE := 260.0    # これより遠くの木は描かない (m)
const DETAIL_RANGE := 110.0  # ギミック・アイテム・化け物など、小さな物をこれより遠くでは描かない (m)

## たき火。0 番はスタート地点、1〜3 番は樹海・岩場・雪山の山頂
var campfires: Array[Campfire] = []

var _terrain: Terrain
var _clearings := PackedVector3Array()
var _player: Player
var _run_nodes: Array[Node] = []  # やり直しで片づけるもの（アイテム・ハーケン・お札）
var _lanterns: Array[OmniLight3D] = []
var _time := 0.0
var _cedars: Array[Transform3D] = []


func build(terrain: Terrain, player: Player) -> void:
	_terrain = terrain
	_player = player
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.run_seed + 1
	_add_campfires()
	_clearings.append(_terrain.summit_position)
	for pit in _terrain.pits:
		_clearings.append(Vector3(pit.x, pit.z, pit.y))  # 隠れクレバスの上にも、木や物を置かない
	_add_trees(rng)
	_add_rocks(rng)
	_add_shrine()
	_add_spiders(rng)
	_add_tenaga(rng)
	_add_gimmicks(rng)
	_limit_draw_distance(self)


## やり直すたびに、アイテムを置き直し、ハーケンとお札を片づける
func reset_run() -> void:
	for node in _run_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_run_nodes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _terrain.run_seed + 100
	for biome in PICKUPS_PER_BIOME.size():
		for point in _terrain.random_ledge_points(rng, PICKUPS_PER_BIOME[biome], biome, 12.0, 1, _clearings, 3.0, 5.0, 0.74):
			var pickup := Pickup.new()
			pickup.setup(Items.pick_random(rng, biome))
			add_child(pickup)
			pickup.global_position = point + Vector3.UP * 0.25
			pickup.rotation.y = rng.randf() * TAU
			_limit_draw_distance(pickup)
			_run_nodes.append(pickup)


## 投げた・落としたアイテム。物理で飛んでいき、転がる
func spawn_item(kind: int, origin: Vector3, velocity: Vector3, activated := false) -> Pickup:
	var pickup := Pickup.new()
	pickup.setup(kind, activated)
	add_child(pickup)
	_limit_draw_distance(pickup)
	pickup.global_position = origin
	pickup.linear_velocity = velocity
	pickup.angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 4.0
	_run_nodes.append(pickup)
	return pickup


func add_rope(top: Vector3, outward: Vector3, length: float) -> void:
	var rope := Rope.new()
	add_child(rope)
	rope.setup(top, outward, length)
	_run_nodes.append(rope)


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
	var avoid := _clearings.duplicate()
	avoid.append_array([spawn, spawn + Vector3(0.0, 0.0, -6.0), spawn + Vector3(0.0, 0.0, -12.0)])
	var cedars := _terrain.random_ledge_points(rng, CEDAR_COUNT, Biomes.Id.FOREST, 4.0, 2, avoid, KEEP_CLEAR, -1.0, 0.82)
	var dead := _terrain.random_ledge_points(rng, DEAD_TREE_COUNT, Biomes.Id.FOREST, 4.0, 2, avoid, KEEP_CLEAR, -1.0, 0.82)
	var snowy := _terrain.random_ledge_points(rng, SNOW_TREE_COUNT, Biomes.Id.SNOW, 5.0, 1, avoid, KEEP_CLEAR, 1.0, 0.8)

	var bark := Psx.material("bark", Color(0.7, 0.6, 0.55), 0.8)
	var needles := Psx.material("ground_forest", Color(0.2, 0.3, 0.18), 0.9, 0.3)
	var dead_wood := Psx.material("bark", Color(0.8, 0.78, 0.75), 0.8, 0.2)
	var frosted := Psx.material("bark", Color(1.5, 1.55, 1.65), 0.8, 0.0)

	var cedar_transforms := _tree_transforms(rng, cedars, 0.8, 1.3)
	_cedars = cedar_transforms
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
	trunk.radial_segments = 8
	trunk.rings = 1
	return _merge([[trunk, Transform3D(Basis(), Vector3(0.0, 5.0, 0.0))]])


func _cedar_needles_mesh() -> ArrayMesh:
	var parts := []
	for i in 5:
		var layer := CylinderMesh.new()
		layer.top_radius = 0.0
		layer.bottom_radius = 2.0 - i * 0.35
		layer.height = 2.8
		layer.radial_segments = 10
		layer.rings = 1
		parts.append([layer, Transform3D(Basis(), Vector3(0.0, 4.0 + i * 1.4, 0.0))])
	return _merge(parts)


## 枯れ木：細い幹から、ねじれた枝が四方へ伸びる
func _dead_tree_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.05
	trunk.bottom_radius = 0.22
	trunk.height = 7.0
	trunk.radial_segments = 7
	trunk.rings = 1
	var parts := [[trunk, Transform3D(Basis(), Vector3(0.0, 3.5, 0.0))]]
	for i in 6:
		var branch := CylinderMesh.new()
		branch.top_radius = 0.015
		branch.bottom_radius = 0.07
		branch.height = 2.4 - i * 0.2
		branch.radial_segments = 5
		branch.rings = 1
		var branch_basis := Basis(Vector3.UP, i * 2.1) * Basis(Vector3.BACK, -0.8 - (i % 2) * 0.3)
		var base := Vector3(0.0, 2.4 + i * 0.65, 0.0)
		parts.append([branch, Transform3D(branch_basis, base + branch_basis.y * branch.height / 2.0)])
	return _merge(parts)


# --- 積み石（大きな岩は Terrain が山肌に突き刺している） ---

func _add_rocks(rng: RandomNumberGenerator) -> void:
	var stone := Psx.material("boulder", Color(0.65, 0.65, 0.66), 0.6, 0.3)
	# 積み石：誰かが積んだ小さな石の塔
	var cairns := _terrain.random_ledge_points(rng, CAIRN_COUNT, Biomes.Id.CRAG, 10.0, 1, _clearings, KEEP_CLEAR, 1.0, 0.85)
	cairns.append_array(_terrain.random_ledge_points(rng, CAIRN_COUNT, Biomes.Id.SNOW, 10.0, 1, _clearings, KEEP_CLEAR, 1.0, 0.85))
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


# --- たき火 ---

func _add_campfires() -> void:
	var spots := [_terrain.spawn_point() + Vector3(2.5, 0.0, 1.5)]
	for i in MountainChain.COUNT - 1:
		spots.append(_terrain.checkpoint(i))
	for spot: Vector3 in spots:
		var campfire := Campfire.new()
		add_child(campfire)
		campfire.global_position = Vector3(spot.x, _terrain.height_at(spot.x, spot.z), spot.z)
		campfires.append(campfire)
		_clearings.append(campfire.global_position)


# --- 霊峰の鳥居と祠 ---

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
	for entry: Array in _terrain.random_wall_points(rng, SPIDER_COUNT, Biomes.Id.CRAG, 10.0):
		var spider := CragSpider.new()
		add_child(spider)
		spider.setup(entry[0], entry[1], _player)


# --- 手長（樹海の杉の上にひそむ） ---

func _add_tenaga(rng: RandomNumberGenerator) -> void:
	var spawn := _terrain.spawn_point()
	var chosen := 0
	var order := range(_cedars.size())
	for i in order.size():
		var j := rng.randi_range(i, order.size() - 1)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	for index: int in order:
		if chosen >= TENAGA_COUNT:
			break
		var tree := _cedars[index]
		if tree.origin.distance_to(spawn) < 25.0:
			continue
		var tenaga := Tenaga.new()
		add_child(tenaga)
		tenaga.setup(tree.origin, tree.basis.get_scale().y, _player, _terrain)
		chosen += 1


# --- 地帯ごとのギミック ---

func _add_gimmicks(rng: RandomNumberGenerator) -> void:
	var avoid := _clearings.duplicate()
	# スタート地点から最初の山へ向かう道には、罠や沼を置かない
	var spawn := _terrain.spawn_point()
	var center := Vector3(MountainChain.centers[0].x, spawn.y, MountainChain.centers[0].y)
	for i in 10:
		avoid.append(spawn.lerp(center, i / 10.0 * 0.6))
	var forest := Biomes.Id.FOREST
	var crag := Biomes.Id.CRAG
	var snow := Biomes.Id.SNOW
	var summit := Biomes.Id.SUMMIT
	# 樹海：底なし沼・トラバサミ・胞子キノコ・つる
	for p in _terrain.random_ledge_points(rng, 6, forest, 20.0, 5, avoid, 10.0, -1.0, 0.93):
		var bog := Bog.new()
		add_child(bog)
		bog.setup(p, rng.randf_range(2.8, 4.2), _player)
	for p in _terrain.random_ledge_points(rng, 16, forest, 8.0, 1, avoid, 5.0, -1.0, 0.85):
		var trap := BearTrap.new()
		add_child(trap)
		trap.setup(p, _player)
	for p in _terrain.random_ledge_points(rng, 16, forest, 8.0, 1, avoid, 4.0, -1.0, 0.8):
		var puffball := Puffball.new()
		add_child(puffball)
		puffball.setup(p, _player)
	for entry: Array in _terrain.random_wall_points(rng, 10, forest, 12.0):
		var vines := Vines.new()
		add_child(vines)
		vines.setup(entry[0], entry[1], _player)
	# 岩場：落石・崩れる岩・噴気孔・ガレ場
	for entry: Array in _terrain.random_wall_points(rng, 8, crag, 20.0):
		var rockfall := Rockfall.new()
		add_child(rockfall)
		rockfall.setup(entry[0], _player)
	for entry: Array in _terrain.random_wall_points(rng, 20, crag, 7.0):
		var rock := CrumblyRock.new()
		add_child(rock)
		rock.setup(entry[0], entry[1])
	for p in _terrain.random_ledge_points(rng, 8, crag, 12.0, 1, avoid, 6.0, 8.0, 0.76):
		var fumarole := Fumarole.new()
		add_child(fumarole)
		fumarole.setup(p, _player)
	for p in _terrain.random_ledge_points(rng, 10, crag, 12.0, 1, avoid, 6.0, 8.0, 0.62):
		var scree := Scree.new()
		add_child(scree)
		scree.setup(p, rng.randf_range(3.0, 5.0), _terrain, _player)
	# 雪山：隠れクレバス・雪崩・氷の壁・つらら
	for pit in _terrain.pits:
		var bridge := SnowBridge.new()
		add_child(bridge)
		bridge.setup(pit, Terrain.PIT_RADIUS, _player)
	var avalanche := Avalanche.new()
	add_child(avalanche)
	avalanche.setup(_player, _terrain)
	for entry: Array in _terrain.random_wall_points(rng, 16, snow, 8.0):
		var ice := IceWall.new()
		add_child(ice)
		ice.setup(entry[0], entry[1])
	var space := get_world_3d().direct_space_state
	for entry: Array in _terrain.overhangs:
		if entry[1] != snow and entry[1] != summit:
			continue
		var point: Vector3 = entry[0]
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(point - Vector3.UP * 0.3, point - Vector3.UP * 12.0, Player.TERRAIN_LAYER))
		if not below.is_empty() and point.y - (below.position as Vector3).y < 2.5:
			continue  # 下に人が通れるすき間がない
		var icicles := Icicles.new()
		add_child(icicles)
		icicles.setup(point, _player, _terrain)
	# 霊峰：突風・幽霊の飛び石・鳥居の抜け道・お地蔵さん
	var gusts := Gusts.new()
	add_child(gusts)
	gusts.setup(_player)
	for entry: Array in _terrain.random_wall_points(rng, 3, summit, 25.0):
		var stones := GhostStones.new()
		add_child(stones)
		stones.setup(entry[0], entry[1])
	var gates: Array[ToriiGate] = []
	for biome in [crag, crag, snow, snow, summit, summit]:
		for p in _terrain.random_ledge_points(rng, 1, biome, 1.0, 1, avoid, 8.0, 8.0, 0.8):
			var mountain: Vector2 = MountainChain.centers[biome]
			var gate := ToriiGate.new()
			add_child(gate)
			gate.setup(p, Vector3(mountain.x - p.x, 0.0, mountain.y - p.z), _player)
			gates.append(gate)
			avoid.append(p)
	gates.shuffle()
	for i in range(0, gates.size() - 1, 2):
		gates[i].partner = gates[i + 1]
		gates[i + 1].partner = gates[i]
	for biome in [crag, snow, summit, summit]:
		for p in _terrain.random_ledge_points(rng, 1, biome, 1.0, 1, avoid, 8.0, 8.0, 0.78):
			var mountain: Vector2 = MountainChain.centers[biome]
			var jizo := Jizo.new()
			add_child(jizo)
			jizo.setup(p, Vector3(p.x - mountain.x, 0.0, p.z - mountain.y))
			avoid.append(p)


# --- 道具 ---

## 同じ形をたくさん置く。区画ごとに分けて、画面や影に入らない区画・遠い区画は描かない
func _multimesh(mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	var tiles := {}
	for t in transforms:
		var key := Vector2i(floori(t.origin.x / TREE_TILE), floori(t.origin.z / TREE_TILE))
		if not tiles.has(key):
			tiles[key] = []
		(tiles[key] as Array).append(t)
	for key: Vector2i in tiles:
		var group: Array = tiles[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = group.size()
		for i in group.size():
			multimesh.set_instance_transform(i, group[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material
		instance.visibility_range_end = TREE_RANGE
		add_child(instance)


## 小さな物（ギミック・アイテム・化け物）は、遠くでは描かない
func _limit_draw_distance(node: Node) -> void:
	for child in node.get_children():
		if child is MultiMeshInstance3D:
			continue
		if child is GeometryInstance3D and (child as GeometryInstance3D).visibility_range_end == 0.0:
			(child as GeometryInstance3D).visibility_range_end = DETAIL_RANGE
		_limit_draw_distance(child)


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
