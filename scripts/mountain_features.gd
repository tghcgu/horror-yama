class_name MountainFeatures
extends Node3D
## 山の上の置き物：地帯ごとの木や積み石、各山の頂上のたき火、霊峰の鳥居と祠、落ちているアイテム、壁の岩グモ、
## 山肌のあちこちの造形物（慰霊碑・石仏・遭難者の亡骸・道標・ビバーク跡・鎖場・磨崖仏・廃坑・梯子・お札の岩・吊り橋の残骸 など）、
## 木の上の手長、地帯ごとのギミック（沼・罠・落石・噴気孔・隠れクレバス・雪崩・突風・飛び石・鳥居・お地蔵さん など）。
## 打ち込んだハーケン・貼ったお札・垂らしたロープ・投げたアイテムもここで管理する。山を作り直すたびに、まるごと作り直す。
## 置き物はすべてのステージの分をはじめに置き、まだ現れていないステージの物は、せり上がり終わるまで隠しておく。

const CEDAR_COUNT := 420
const DEAD_TREE_COUNT := 150
const SNOW_TREE_COUNT := 70
const CAIRN_COUNT := 12    # 岩場と雪山、それぞれ
const SPIDER_COUNT := 18
const TENAGA_COUNT := 10
const PICKUPS_PER_BIOME := [16, 16, 16, 9]  # 山が広くなったぶん、見つけやすさが変わらないように増やす
const MOUNTAIN_BOXES := [28, 28, 26, 18]    # そのほかに、山の上の平らな所（登る途中）にも箱を置く
const MOUNTAIN_ABOVE := 12.0  # 平地の高さからこれだけ上を「山の上」とする (m)
## 山の上の造形物：地帯ごとに、[名前, 数]。置き方は MOUNTAIN_PROP_KINDS で決まる
const MOUNTAIN_PROPS := {
	Biomes.Id.FOREST: [["memorial", 5], ["buddha", 6], ["signpost", 6], ["bivouac", 4], ["remains", 3], ["ema", 3], ["hokora", 4],
		["jizo", 5], ["backpack", 5], ["chain", 8], ["carving", 4], ["talisman", 5], ["ladder", 5], ["mine", 2], ["bridge", 3]],
	Biomes.Id.CRAG: [["memorial", 5], ["buddha", 3], ["signpost", 6], ["bivouac", 5], ["remains", 5], ["backpack", 5], ["tent", 3],
		["chain", 12], ["carving", 3], ["talisman", 3], ["mine", 5], ["ladder", 6], ["bridge", 5]],
	Biomes.Id.SNOW: [["memorial", 6], ["signpost", 6], ["bivouac", 5], ["remains", 6], ["tent", 4], ["backpack", 4], ["jizo", 3],
		["chain", 8], ["talisman", 2], ["ladder", 3], ["mine", 1], ["bridge", 3]],
	Biomes.Id.SUMMIT: [["buddha", 8], ["memorial", 4], ["ema", 4], ["hokora", 5], ["jizo", 6], ["lantern", 8], ["torii", 3],
		["carving", 8], ["talisman", 8], ["chain", 6], ["ladder", 2], ["bridge", 2]],
}
## 山肌の岩棚（Terrain.landings）に、順に置いていく物（地帯ごと）。岩棚のおよそ半分には、箱も置いてある
const LANDING_PROPS := {
	Biomes.Id.FOREST: ["hokora", "memorial", "buddha", "bivouac", "ema", "signpost", "remains", "jizo", "memorial", "buddha"],
	Biomes.Id.CRAG: ["memorial", "bivouac", "remains", "signpost", "buddha", "tent", "bivouac"],
	Biomes.Id.SNOW: ["memorial", "bivouac", "remains", "signpost", "tent", "jizo"],
	Biomes.Id.SUMMIT: ["buddha", "hokora", "ema", "torii", "memorial", "lantern", "jizo", "buddha"],
}
const LANDING_EXTRAS := ["backpack", "jizo", "lantern", "signpost"]  # 岩棚のすみに、ときどき添える小さな物
## 岩棚の山側の崖に、ときどき掘られた廃坑や、立てかけた梯子。谷側が切れ落ちていれば、吊り橋の残骸
const LANDING_WALL_PROPS := {
	Biomes.Id.FOREST: ["ladder", "mine", "ladder"], Biomes.Id.CRAG: ["mine", "ladder"],
	Biomes.Id.SNOW: ["ladder", "mine"], Biomes.Id.SUMMIT: ["ladder"],
}
const LANDING_WALL_CHANCE := 0.4
const LANDING_BRIDGE_CHANCE := 0.3
const LANDING_BOX_CHANCE := 0.5
## 造形物ごとの置き方：[置く所, 足場の広さ, 描く距離, 当たり判定をつけるか]
##   ledge = 平らな所、wall = 崖の表面（表面に沿わせる）、upright = 崖の表面（まっすぐ立てる）、
##   foot = 崖の根元（崖に寄りかからせる）、edge = 崖っぷち（谷へ垂らす）
const MOUNTAIN_PROP_KINDS := {
	"memorial": ["ledge", 1, 150.0, true], "buddha": ["ledge", 1, 150.0, true], "signpost": ["ledge", 1, 110.0, true],
	"bivouac": ["ledge", 2, 130.0, true], "remains": ["ledge", 1, 90.0, false], "ema": ["ledge", 1, 120.0, true],
	"hokora": ["ledge", 1, 140.0, true], "jizo": ["ledge", 1, 100.0, true], "lantern": ["ledge", 1, 110.0, true],
	"torii": ["ledge", 2, 180.0, true], "backpack": ["ledge", 1, 80.0, false], "tent": ["ledge", 2, 110.0, false],
	"chain": ["wall", 0, 110.0, false], "talisman": ["wall", 0, 100.0, false], "carving": ["upright", 0, 150.0, true],
	"ladder": ["foot", 0, 130.0, false], "mine": ["foot", 0, 160.0, true], "bridge": ["edge", 0, 130.0, false],
}
const KEEP_CLEAR := 7.0  # たき火や祠のまわりには、木や岩を置かない
const TREE_TILE := 128.0     # 木を区画ごとにまとめる大きさ (m)。見えない区画は描かない
const TREE_RANGE := 280.0    # これより遠くの木は描かない (m)
const TREE_NEAR := 75.0      # これより近くの木は細かい形で、遠くは一枚絵で描く (m)
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
var _stage := -1  # いま作っているステージ（_ledges と _walls は、このステージからだけ点を選ぶ）
var _stage_content := [[], [], [], []]  # ステージ → そのステージを作ったときに置いた物（もう戻れなくなったら消す）
var _built_stages := [false, false, false, false]
var _unloaded := [false, false, false, false]
var mountain_props := {}  # 山の上の造形物の名前 → 置いた場所（Transform3D の配列）
var _loot_spots: Array[Transform3D] = []  # ビバーク跡の中など、箱を置く場所（やり直すたびに置き直す）
var _prop_spots := PackedVector3Array()   # 山の上の造形物を置いた場所（重ならないように）


## 山を作ったあとに呼ぶ：ステージに関係なく置く物（たき火）を置く。ステージの中身は build_stage で作る
func build(terrain: Terrain, player: Player) -> void:
	_terrain = terrain
	_player = player
	_add_campfires()
	_clearings.append(_terrain.summit_position)
	for pit in _terrain.pits:
		_clearings.append(Vector3(pit.x, pit.z, pit.y))  # 隠れクレバスの上にも、木や物を置かない
	_limit_draw_distance(self)
	for campfire in campfires:  # まだ作っていないステージのたき火は、隠しておく
		if _terrain.stage_of(campfire.global_position) > 0:
			_show(campfire, false)


## ステージ stage の中身（木・下草・ギミック・岩グモ・建造物・造形物・箱など）を作る。
## そのステージが霧の中から現れるときに呼ぶ（地形の岩を作ったあとに）。乱数はステージごとなので、いつ作っても同じになる
func build_stage(stage: int) -> void:
	if _built_stages[stage]:
		return
	_built_stages[stage] = true
	_stage = stage
	var first := get_child_count()
	var rng := RandomNumberGenerator.new()
	rng.seed = _terrain.run_seed + 1 + stage * 7919
	if stage == 0:
		_add_crash_site()
	_add_trees(rng)
	_add_gimmicks(rng)  # 下草より先に置き、沼などの上には下草を置かない
	_add_flora(rng)
	_add_harvest(rng)
	_add_rocks(rng)
	if stage == Biomes.Id.SUMMIT:
		_add_shrine()
	_add_spiders(rng)
	_add_tenaga(rng)
	_add_structures(rng)
	_add_mountain_props(rng)
	_add_boxes(stage)
	var content: Array = _stage_content[stage]
	for index in range(first, get_child_count()):
		var node := get_child(index)
		content.append(node)
		_limit_node(node)
	for campfire in campfires:
		if _terrain.stage_of(campfire.global_position) == stage:
			_show(campfire, true)
	_stage = -1


## ステージの中身を作ってあるか
func has_stage(stage: int) -> bool:
	return _built_stages[stage] and not _unloaded[stage]


## もう戻れないステージの物を、すべて消す（軽くするため）。そこに落としたり置いたりした物も消す
func unload_stage(stage: int) -> void:
	_unloaded[stage] = true
	for node: Node in _stage_content[stage]:
		if is_instance_valid(node):
			node.queue_free()
	_stage_content[stage].clear()
	for node in _run_nodes:
		if is_instance_valid(node) and node is Node3D and _terrain.stage_of((node as Node3D).global_position) == stage:
			node.queue_free()
	_run_nodes.assign(_run_nodes.filter(func(n: Node) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion()))
	_lanterns.assign(_lanterns.filter(func(n: Node) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion()))
	for campfire in campfires:
		if _terrain.stage_of(campfire.global_position) == stage:
			_show(campfire, false)


func _show(node: Node3D, on: bool) -> void:
	node.visible = on
	node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED  # 動きも当たり判定も止める


## いま作っているステージ（_stage）の足場から、点を選ぶ。ほかの地帯を指定したら、何も選ばない。
## 選んだ点のうち、次のステージの霧の境目の先にはみ出した物は除く（ステージごとに作り、ステージごとに消すため）
func _ledges(rng: RandomNumberGenerator, count: int, biome: int, spacing: float, flat_radius := 1,
		avoid := PackedVector3Array(), avoid_radius := 0.0, min_y := 1.0, min_normal_y := 0.85) -> PackedVector3Array:
	var result := PackedVector3Array()
	if biome != _stage:
		return result
	for point in _terrain.random_ledge_points(rng, count, biome, spacing, flat_radius, avoid, avoid_radius, min_y, min_normal_y):
		if _terrain.stage_of(point) == _stage:
			result.append(point)
	return result


## いま作っているステージの崖の壁から、点を選ぶ（[位置, 壁の外向き] の組の配列）
func _walls(rng: RandomNumberGenerator, count: int, biome: int, spacing: float) -> Array:
	if biome != _stage:
		return []
	return _terrain.random_wall_points(rng, count, biome, spacing).filter(func(entry: Array) -> bool: return _terrain.stage_of(entry[0]) == _stage)


## ステージの箱を置く：足場のあちこち・山の上の平らな所（登る途中）・ビバーク跡や墜落したヘリのそば。中身は人の作った物
func _add_boxes(stage: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _terrain.run_seed + 100 + stage * 7919
	for point in _ledges(rng, PICKUPS_PER_BIOME[stage], stage, 12.0, 1, _clearings, 3.0, 5.0, 0.74):
		# アイテムは箱に入れて置く（ひとつの箱に 1〜2 個）
		var items: Array[int] = [Items.pick_random(rng)]
		if rng.randf() < 0.3:
			items.append(Items.pick_random(rng))
		_add_box(items, stage, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), point - Vector3.UP * 0.05))
	# 山の上にも、登る途中で見つかるように箱を置く（中身はひとつ、ときどきふたつ）
	var above: float = MountainChain.bases[stage] + MOUNTAIN_ABOVE
	for point in _ledges(rng, MOUNTAIN_BOXES[stage], stage, 14.0, 1, _clearings + _prop_spots, 3.0, above, 0.72):
		var items: Array[int] = [Items.pick_random(rng)]
		if rng.randf() < 0.2:
			items.append(Items.pick_random(rng))
		_add_box(items, stage, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), point - Vector3.UP * 0.05))
	# ビバーク跡の石垣の中や、墜落したヘリのそばには、置いていかれた箱
	for spot in _loot_spots:
		if _terrain.stage_of(spot.origin) == stage:
			var items: Array[int] = [Items.pick_random(rng), Items.pick_random(rng)]
			_add_box(items, stage, spot)


func _add_box(items: Array[int], style: int, xform: Transform3D) -> void:
	var box := ItemBox.new()
	add_child(box)
	box.setup(items, clampi(style, 0, ItemBox.STYLES.size() - 1), self)
	box.global_transform = xform
	_limit_draw_distance(box)
	_run_nodes.append(box)


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
	var cedars := _ledges(rng, CEDAR_COUNT, Biomes.Id.FOREST, 4.0, 2, avoid, KEEP_CLEAR, -1.0, 0.82)
	var dead := _ledges(rng, DEAD_TREE_COUNT, Biomes.Id.FOREST, 4.0, 2, avoid, KEEP_CLEAR, -1.0, 0.82)
	var snowy := _ledges(rng, SNOW_TREE_COUNT, Biomes.Id.SNOW, 5.0, 1, avoid, KEEP_CLEAR, 1.0, 0.8)

	var frosted := Psx.material("bark", Color(1.5, 1.55, 1.65), 0.8, 0.0)

	var cedar_transforms := _tree_transforms(rng, cedars, 0.75, 1.2)
	if _stage == Biomes.Id.FOREST:
		_cedars = cedar_transforms
	_trees("cedar", cedar_transforms)
	var dead_transforms := _tree_transforms(rng, dead, 0.7, 1.2)
	_trees("dead", dead_transforms)
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


# --- 下草・低木・倒木・転がっている物 ---

## 樹海には、笹やぶ・シダ・低木・野の花・苔むした石・キノコ・切り株・倒木・白樺・竹やぶがびっしり生え、
## 山の斜面には崖の松が根を張る。岩場にも松と低木。樹海のあちこちに、遭難者の荷物や、卒塔婆が立つ。
## 大きな物（木・切り株・倒木）には当たり判定をつける（木の幹はよじ登れる）
func _add_flora(rng: RandomNumberGenerator) -> void:
	var forest := Biomes.Id.FOREST
	var crag := Biomes.Id.CRAG
	var spawn := _terrain.spawn_point()
	var avoid := _clearings.duplicate()
	avoid.append_array([spawn, spawn + Vector3(0.0, 0.0, -6.0)])
	var colliders := StaticBody3D.new()
	add_child(colliders)
	# 小さな草花と石（当たり判定なし。プレイヤーのまわりにだけ描く）
	var ground_cover := [
		[Flora.model("sasa"), 2400, 0.6, 60.0], [Flora.model("fern"), 1600, 0.55, 55.0],
		[Flora.model("bush"), 800, 0.6, 100.0],
	]
	for entry: Array in ground_cover:
		var points := _ledges(rng, entry[1], forest, 0.0, 0, avoid, 2.5, -1.0, entry[2])
		_scatter(entry[0], _tree_transforms(rng, points, 0.8, 1.35), entry[3])
	var small := [[Flora.flowers(), 1400, 0.8, 55.0], [Flora.stones(), 900, 0.5, 70.0], [Flora.mushrooms(), 400, 0.7, 45.0]]
	for entry: Array in small:
		var points := _ledges(rng, entry[1], forest, 0.0, 0, avoid, 2.5, -1.0, entry[2])
		_scatter(entry[0], _tree_transforms(rng, points, 0.8, 1.3), entry[3], Psx.vertex_material("ground_forest", 2.0, 0.8))
	# 白樺と竹やぶ
	var birches := _ledges(rng, 170, forest, 4.0, 1, avoid, KEEP_CLEAR, -1.0, 0.8)
	var birch_transforms := _tree_transforms(rng, birches, 0.8, 1.2)
	_trees("birch", birch_transforms)
	_add_trunks(colliders, birch_transforms, 0.15, 6.0)
	var groves := _ledges(rng, 24, forest, 14.0, 2, avoid, KEEP_CLEAR, -1.0, 0.84)
	_trees("bamboo", _tree_transforms(rng, groves, 0.85, 1.15))
	# 切り株と倒木（上に乗ったり、陰に隠れたりできる）
	var stumps := _ledges(rng, 70, forest, 5.0, 1, avoid, KEEP_CLEAR, -1.0, 0.8)
	var stump_transforms := _tree_transforms(rng, stumps, 0.8, 1.3)
	_multimesh(Flora.model("stump"), null, stump_transforms, 120.0)
	for t in stump_transforms:
		var s := t.basis.get_scale().y
		_add_shape(colliders, Transform3D(Basis(), t.origin + Vector3.UP * 0.32 * s), _cylinder_shape(0.45 * s, 0.65 * s))
	var logs := _ledges(rng, 45, forest, 9.0, 2, avoid, KEEP_CLEAR, -1.0, 0.86)
	var log_transforms := _tree_transforms(rng, logs, 0.8, 1.2)
	_multimesh(Flora.model("log"), null, log_transforms, 140.0)
	for t in log_transforms:
		var box := BoxShape3D.new()
		box.size = Vector3(5.0, 0.7, 0.72)
		_add_shape(colliders, Transform3D(t.basis, t.origin + t.basis * Vector3(0.0, 0.33, 0.0)), box)
	# 崖の松：樹海の山と岩場の、斜面に根を張る
	for biome in [forest, crag]:
		var ledges := _ledges(rng, 200, biome, 5.0, 0, avoid, KEEP_CLEAR, 12.0, 0.45)
		var on_slopes := PackedVector3Array()
		for p in ledges:
			if _terrain.normal_at(p.x, p.z).y < 0.9:
				on_slopes.append(p)
		var pine_transforms := _tree_transforms(rng, on_slopes, 0.7, 1.15)
		_trees("pine", pine_transforms)
		_add_trunks(colliders, pine_transforms, 0.22, 4.5)
	var crag_bushes := _ledges(rng, 600, crag, 0.0, 0, avoid, 2.5, 5.0, 0.6)
	_scatter(Flora.model("bush"), _tree_transforms(rng, crag_bushes, 0.6, 1.0), 120.0)
	# 遭難者の痕跡：口の開いたザック、破れたテント、卒塔婆の列
	var traces := [["backpack", 10], ["tent", 4], ["sotoba", 7], ["jizo", 8], ["lantern", 6]]
	for entry: Array in traces:
		var points := _ledges(rng, entry[1], forest, 25.0, 2, avoid, KEEP_CLEAR, -1.0, 0.86)
		var transforms := _tree_transforms(rng, points, 0.95, 1.05)
		var mesh := Flora.prop(entry[0])
		_multimesh(mesh, null, transforms, 90.0, true)
		if entry[0] in ["jizo", "lantern", "sotoba"]:
			for t in transforms:
				_add_shape(colliders, t, Flora.solid_shape(mesh))


# --- 採れる木の実 ---

## 木いちごの茂み・栗の木・キノコの群れ（見ながら E で採る。しばらくすると、また実る）
func _add_harvest(rng: RandomNumberGenerator) -> void:
	var forest := Biomes.Id.FOREST
	var colliders := StaticBody3D.new()
	add_child(colliders)
	var berry_points := _ledges(rng, 45, forest, 8.0, 1, _clearings, KEEP_CLEAR, -1.0, 0.7)
	berry_points.append_array(_ledges(rng, 15, Biomes.Id.CRAG, 8.0, 1, _clearings, KEEP_CLEAR, 5.0, 0.7))
	for p in berry_points:
		var bush := _harvestable(p, Items.Kind.BERRIES, Vector2i(2, 4), "木いちごを摘む", false)
		var look := MeshInstance3D.new()
		look.mesh = Flora.model("bush")
		bush.add_child(look)
		var fruit := MeshInstance3D.new()
		fruit.mesh = Harvestable.berries_mesh()
		fruit.material_override = Psx.vertex_material("", 1.0, 1.0)
		bush.add_child(fruit)
		bush.fruit = fruit
	for p in _ledges(rng, 22, forest, 14.0, 2, _clearings, KEEP_CLEAR, -1.0, 0.82):
		var tree := _harvestable(p, Items.Kind.CHESTNUT, Vector2i(2, 4), "木をゆする", true)
		tree.regrow = 300.0
		var look := MeshInstance3D.new()
		look.mesh = Flora.model("chestnut")
		tree.add_child(look)
		_add_shape(colliders, Transform3D(Basis(), p + Vector3.UP * 1.6), _cylinder_shape(0.3, 3.2))
	for p in _ledges(rng, 30, forest, 10.0, 0, _clearings, KEEP_CLEAR, -1.0, 0.75):
		var patch := _harvestable(p, Items.Kind.MUSHROOM, Vector2i(1, 2), "キノコを採る", false)
		patch.regrow = 360.0
		var look := MeshInstance3D.new()
		look.mesh = Flora.mushrooms()
		look.material_override = Psx.vertex_material("", 1.0, 1.0)
		look.scale = Vector3.ONE * 1.6
		patch.add_child(look)
		patch.fruit = look


func _harvestable(pos: Vector3, kind: int, amount: Vector2i, label: String, drops: bool) -> Harvestable:
	var plant := Harvestable.new()
	plant.kind = kind
	plant.amount = amount
	plant.label = label
	plant.drop = drops
	plant.features = self
	add_child(plant)
	plant.global_position = pos - Vector3.UP * 0.1
	plant.rotation.y = randf() * TAU
	return plant


## 小さな物を、プレイヤーのまわりにだけ描く（ScatterField）
func _scatter(mesh: Mesh, transforms: Array[Transform3D], draw_radius: float, material: Material = null) -> void:
	if transforms.is_empty():
		return
	var field := ScatterField.new()
	add_child(field)
	field.setup(mesh, transforms, _player, draw_radius, material)


## 木を並べる：近く（TREE_NEAR 以内）は Blender で作った細かい形で、遠くは一枚絵で描く
func _trees(model_name: String, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var near := ScatterField.new()
	add_child(near)
	near.setup(Flora.model(model_name), transforms, _player, TREE_NEAR, null, true)
	var far := ScatterField.new()
	add_child(far)
	far.setup(Flora.impostor(model_name), transforms, _player, TREE_RANGE, null, false, TREE_NEAR)


func _add_trunks(body: StaticBody3D, transforms: Array[Transform3D], radius: float, height: float) -> void:
	for t in transforms:
		var s := t.basis.get_scale().y
		_add_shape(body, Transform3D(Basis(), t.origin + Vector3.UP * height * 0.5 * s), _cylinder_shape(radius * s, height * s))


func _cylinder_shape(radius: float, height: float) -> CylinderShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return shape


func _add_shape(body: StaticBody3D, xform: Transform3D, shape: Shape3D) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = xform
	body.add_child(collision)


func _tree_transforms(rng: RandomNumberGenerator, points: PackedVector3Array, min_scale: float, max_scale: float) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for p in points:
		var s := rng.randf_range(min_scale, max_scale)
		var tree_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		result.append(Transform3D(tree_basis, p - Vector3.UP * 0.2))
	return result


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
	var cairns := _ledges(rng, CAIRN_COUNT, Biomes.Id.CRAG, 10.0, 1, _clearings, KEEP_CLEAR, 1.0, 0.85)
	cairns.append_array(_ledges(rng, CAIRN_COUNT, Biomes.Id.SNOW, 10.0, 1, _clearings, KEEP_CLEAR, 1.0, 0.85))
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


# --- 墜落したヘリ ---

## 島の砂浜に墜落したヘリ：くすぶる煙と、残り火。そばには、積み荷の箱が 2 つ転がっている
func _add_crash_site() -> void:
	var spawn := _terrain.spawn_point()
	var start := MountainChain.plain_starts[0]
	var inland := (MountainChain.plain_ends[0] - start).normalized()
	var back := Vector3(-inland.x, 0.0, -inland.y)
	var side := Vector3(inland.y, 0.0, -inland.x)
	var at := spawn + back * 8.0 + side * 5.0
	at.y = _terrain.height_at(at.x, at.z)
	var wreck := Structures.prop("heli_wreck", at, atan2(back.x, back.z) + 0.6)
	add_child(wreck)
	_clearings.append(at)
	# 立ちのぼる黒い煙
	var smoke := CPUParticles3D.new()
	smoke.amount = 36
	smoke.lifetime = 7.0
	smoke.preprocess = 7.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.8
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.6, 1.2, 0.0)  # 海からの風に流される
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.4
	smoke.scale_amount_min = 1.5
	smoke.scale_amount_max = 4.0
	var puff := QuadMesh.new()
	puff.size = Vector2(1.0, 1.0)
	var puff_material := StandardMaterial3D.new()
	var soft := GradientTexture2D.new()  # 丸くぼけた煙のかたまり
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	soft.gradient = fade
	puff_material.albedo_texture = soft
	puff_material.albedo_color = Color(0.12, 0.12, 0.13, 0.5)
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.material = puff_material
	smoke.mesh = puff
	smoke.position = Vector3(0.0, 1.8, 0.0)
	wreck.add_child(smoke)
	# 残り火
	var ember := CreatureKit.part(wreck, CreatureKit.sphere(0.35), CreatureKit.glow(Color(1.0, 0.45, 0.12), 4.0), Vector3(0.6, 0.9, -0.8))
	ember.scale = Vector3(1.0, 0.6, 1.0)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.2)
	glow.light_energy = 1.6
	glow.omni_range = 9.0
	glow.position = Vector3(0.6, 1.4, -0.8)
	wreck.add_child(glow)
	# 積み荷の箱（やり直すたびに置き直す）
	for k in 2:
		var box_at := at + side * (3.0 + k * 1.4) - back * (1.5 - k * 2.0)
		box_at.y = _terrain.height_at(box_at.x, box_at.z) - 0.05
		_loot_spots.append(Transform3D(Basis(Vector3.UP, k * 1.3 + 0.4), box_at))


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
	for entry: Array in _walls(rng, SPIDER_COUNT, Biomes.Id.CRAG, 10.0):
		var spider := CragSpider.new()
		add_child(spider)
		spider.setup(entry[0], entry[1], _player)


# --- 手長（樹海の杉の上にひそむ） ---

func _add_tenaga(rng: RandomNumberGenerator) -> void:
	if _stage != Biomes.Id.FOREST:
		return
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
	for p in _ledges(rng, 9, forest, 20.0, 5, avoid, 10.0, -1.0, 0.93):
		var bog := Bog.new()
		add_child(bog)
		bog.setup(p, rng.randf_range(2.8, 4.2), _player)
		_clearings.append(p)  # 沼の上には、木や倒木を置かない
	for p in _ledges(rng, 24, forest, 8.0, 1, avoid, 5.0, -1.0, 0.85):
		var trap := BearTrap.new()
		add_child(trap)
		trap.setup(p, _player)
	for p in _ledges(rng, 24, forest, 8.0, 1, avoid, 4.0, -1.0, 0.8):
		var puffball := Puffball.new()
		add_child(puffball)
		puffball.setup(p, _player)
	# つる（蔦）：樹海に多く、岩場と霊峰の崖にも少し
	for biome in [forest, forest, crag, summit]:
		for entry: Array in _walls(rng, 9, biome, 12.0):
			var vines := Vines.new()
			add_child(vines)
			vines.setup(entry[0], entry[1], _player)
	# 岩場：落石・崩れる岩・噴気孔・ガレ場
	for entry: Array in _walls(rng, 12, crag, 20.0):
		var rockfall := Rockfall.new()
		add_child(rockfall)
		rockfall.setup(entry[0], _player)
	for entry: Array in _walls(rng, 30, crag, 7.0):
		var rock := CrumblyRock.new()
		add_child(rock)
		rock.setup(entry[0], entry[1])
	for p in _ledges(rng, 12, crag, 12.0, 1, avoid, 6.0, 8.0, 0.76):
		var fumarole := Fumarole.new()
		add_child(fumarole)
		fumarole.setup(p, _player)
	for p in _ledges(rng, 15, crag, 12.0, 1, avoid, 6.0, 8.0, 0.62):
		var scree := Scree.new()
		add_child(scree)
		scree.setup(p, rng.randf_range(3.0, 5.0), _terrain, _player)
	# 雪山：隠れクレバス・雪崩・氷の壁・つらら
	if _stage == snow:
		for pit in _terrain.pits:
			var bridge := SnowBridge.new()
			add_child(bridge)
			bridge.setup(pit, Terrain.PIT_RADIUS, _player)
		var avalanche := Avalanche.new()
		add_child(avalanche)
		avalanche.setup(_player, _terrain)
	for entry: Array in _walls(rng, 24, snow, 8.0):
		var ice := IceWall.new()
		add_child(ice)
		ice.setup(entry[0], entry[1])
	var space := get_world_3d().direct_space_state
	for entry: Array in _terrain.overhangs:
		if (entry[1] != snow and entry[1] != summit) or entry[1] != _stage or _terrain.stage_of(entry[0]) != _stage:
			continue
		var point: Vector3 = entry[0]
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(point - Vector3.UP * 0.3, point - Vector3.UP * 12.0, Player.TERRAIN_LAYER))
		if not below.is_empty() and point.y - (below.position as Vector3).y < 2.5:
			continue  # 下に人が通れるすき間がない
		var icicles := Icicles.new()
		add_child(icicles)
		icicles.setup(point, _player, _terrain)
	# 霊峰：突風・幽霊の飛び石・鳥居の抜け道・お地蔵さん
	if _stage == summit:
		var gusts := Gusts.new()
		add_child(gusts)
		gusts.setup(_player)
	for entry: Array in _walls(rng, 5, summit, 25.0):
		var stones := GhostStones.new()
		add_child(stones)
		stones.setup(entry[0], entry[1])
	var gates: Array[ToriiGate] = []
	for biome in [crag, crag, snow, snow, summit, summit]:
		for p in _ledges(rng, 1, biome, 1.0, 1, avoid, 8.0, 8.0, 0.8):
			var mountain: Vector2 = MountainChain.centers[biome]
			var gate := ToriiGate.new()
			add_child(gate)
			gate.setup(p, Vector3(mountain.x - p.x, 0.0, mountain.y - p.z), _player)
			gates.append(gate)
			avoid.append(p)
	gates.shuffle()  # 同じ山の鳥居どうしが、2 つずつつながる
	for i in range(0, gates.size() - 1, 2):
		gates[i].partner = gates[i + 1]
		gates[i + 1].partner = gates[i]
	for biome in [forest, crag, snow, snow, summit, summit]:
		for p in _ledges(rng, 1, biome, 1.0, 1, avoid, 8.0, 8.0, 0.78):
			var mountain: Vector2 = MountainChain.centers[biome]
			var jizo := Jizo.new()
			add_child(jizo)
			jizo.setup(p, Vector3(p.x - mountain.x, 0.0, p.z - mountain.y))
			avoid.append(p)


# --- 平地の建造物と巨木 ---

## 各ステージの平地に、その地帯らしい建造物を建てる（どれも登れる）
func _add_structures(rng: RandomNumberGenerator) -> void:
	var taken := _clearings.duplicate()
	var spawn := _terrain.spawn_point()
	taken.append(spawn)
	var plan := {  # ステージ → 建てる物の一覧
		Biomes.Id.FOREST: ["tree", "tree", "tree", "tree", "hut", "hut", "ruins_mossy"],
		Biomes.Id.CRAG: ["tower", "tower", "ruins", "ruins", "ruins"],
		Biomes.Id.SNOW: ["hut_snowy", "tower_snowy", "ice", "ice", "ice"],
		Biomes.Id.SUMMIT: ["stairs", "stairs", "ruins", "ruins"],
	}
	for stage: int in plan:
		if stage != _stage:
			continue
		for what: String in plan[stage]:
			var spot := _plain_spot(rng, stage, taken)
			if not spot.is_finite():
				continue
			taken.append(spot)
			var toward := MountainChain.centers[stage] - Vector2(spot.x, spot.z)
			var yaw := atan2(-toward.x, -toward.y) + PI  # 戸口や石段は、平地の入り口のほうを向ける
			var built: StaticBody3D
			match what:
				"tree":
					built = Structures.giant_tree(spot, rng)
				"hut", "hut_snowy":
					built = Structures.hut(spot, yaw, what == "hut_snowy")
				"tower", "tower_snowy":
					built = Structures.tower(spot, yaw, what == "tower_snowy")
				"ruins", "ruins_mossy":
					built = Structures.ruins(spot, rng.randf() * TAU, rng, what == "ruins_mossy")
				"stairs":
					built = Structures.stairs(spot, yaw)
				"ice":
					built = Structures.ice_pillars(spot, rng)
			add_child(built)
			if what.begins_with("hut"):
				# 小屋の中には、アイテムの箱がひとつ
				var box := ItemBox.new()
				add_child(box)
				var items: Array[int] = [Items.pick_random(rng), Items.pick_random(rng)]
				box.setup(items, stage, self)
				box.global_transform = built.global_transform.translated_local(Vector3(0.8, 0.37, -1.2))


# --- 山の上の造形物 ---

## 山肌のあちこちに、造形物を置く：平らな所には慰霊碑や石仏、崖には鎖や磨崖仏、崖の根元には廃坑や梯子、
## 崖っぷちには吊り橋の残骸。登る途中にも、見つける物がたくさんあるように
func _add_mountain_props(rng: RandomNumberGenerator) -> void:
	var colliders := StaticBody3D.new()
	add_child(colliders)
	for stage: int in MOUNTAIN_PROPS:
		if stage != _stage:
			continue
		var above: float = MountainChain.bases[stage] + MOUNTAIN_ABOVE
		var placed := _furnish_landings(rng, stage)  # 名前 → 置き方（岩棚の分）
		for entry: Array in MOUNTAIN_PROPS[stage]:
			var prop_name: String = entry[0]
			var kind: Array = MOUNTAIN_PROP_KINDS[prop_name]
			var avoid := _clearings.duplicate()
			avoid.append_array(_prop_spots)
			var transforms: Array[Transform3D] = []
			match kind[0]:
				"ledge":
					for p in _ledges(rng, entry[1], stage, 20.0, kind[1], avoid, KEEP_CLEAR, above, 0.72):
						# 少し傾いた所では、低いほうの側が浮かないように、傾きのぶんだけ埋める
						var n := _terrain.normal_at(p.x, p.z)
						var sink := minf(0.08 + sqrt(maxf(1.0 - n.y * n.y, 0.0)) / maxf(n.y, 0.1) * 0.6, 0.7)
						transforms.append(Transform3D(_facing_out(p, stage, rng), p - Vector3.UP * sink))
				"wall", "upright":
					transforms = _wall_props(rng, entry[1], stage, above, kind[0] == "upright")
				"foot":
					transforms = _foot_props(rng, entry[1], stage, above, avoid, prop_name)
				"edge":
					transforms = _edge_props(rng, entry[1], stage, above, avoid)
			if not placed.has(prop_name):
				placed[prop_name] = []
			(placed[prop_name] as Array).append_array(transforms)
			for t in transforms:
				_prop_spots.append(t.origin)
		for prop_name: String in placed:
			var kind: Array = MOUNTAIN_PROP_KINDS[prop_name]
			var transforms: Array[Transform3D] = []
			transforms.assign(placed[prop_name])
			if transforms.is_empty():
				continue
			var mesh := Flora.prop(prop_name)
			_multimesh(mesh, null, transforms, kind[2], kind[2] >= 130.0)
			if not mountain_props.has(prop_name):
				mountain_props[prop_name] = []
			(mountain_props[prop_name] as Array).append_array(transforms)
			for t in transforms:
				if kind[3]:
					_add_shape(colliders, t, Flora.solid_shape(mesh))
				match prop_name:
					"bivouac":
						_loot_spots.append(t.translated_local(Vector3(-0.45, 0.02, -0.4)))
					"remains":
						_add_belongings(t)


## 山 stage の岩棚に、造形物を順に置く（谷側を向けて、真ん中より少し谷寄りに）。すみに小さな物や箱を添えることもある。
## 名前 → 置き方（Transform3D の配列）を返す
func _furnish_landings(rng: RandomNumberGenerator, stage: int) -> Dictionary:
	var placed := {}
	var names: Array = LANDING_PROPS[stage]
	var k := 0
	for index in _terrain.landings.size():
		if _terrain.landing_stages[index] != stage:
			continue
		var landing := _terrain.landings[index]
		var center := Vector3(landing.x, _terrain.height_at(landing.x, landing.y), landing.y)
		if _too_close_to(center, _clearings, 9.0):
			continue  # 隠れクレバスやたき火の上はさける
		var facing := _facing_out(center, stage, rng)
		var entries := [[names[k % names.size()], center + facing.z * landing.w * 0.15, facing]]
		k += 1
		# 山側（いちばんせり上がる向き）と谷側（いちばん落ちこむ向き）
		var uphill := Vector3.ZERO
		var downhill := Vector3.ZERO
		var rise := -INF
		var drop := INF
		for a in 16:
			var dir := Vector3(cos(a * TAU / 16.0), 0.0, sin(a * TAU / 16.0))
			var probe := center + dir * (landing.w + 3.0)
			var h := _terrain.height_at(probe.x, probe.z) - center.y
			if h > rise:
				rise = h
				uphill = dir
			if h < drop:
				drop = h
				downhill = dir
		var walls: Array = LANDING_WALL_PROPS[stage]
		if rise > 3.0 and rng.randf() < LANDING_WALL_CHANCE:
			var wall_prop: String = walls[rng.randi() % walls.size()]
			var t := _landing_wall_prop(wall_prop, center, uphill, landing.w)
			if t != Transform3D():
				if not placed.has(wall_prop):
					placed[wall_prop] = []
				(placed[wall_prop] as Array).append(t)
		if drop < -3.5 and rng.randf() < LANDING_BRIDGE_CHANCE:
			var edge := center + downhill * (landing.w + 0.3)
			edge.y = _terrain.height_at(edge.x, edge.z) - 0.05
			if not placed.has("bridge"):
				placed["bridge"] = []
			(placed["bridge"] as Array).append(Transform3D(Basis(Vector3.UP.cross(downhill), Vector3.UP, downhill), edge))
			entries[0][1] = center - downhill * landing.w * 0.2  # 真ん中の物は、橋の柱から離す
		var side := facing.x * landing.w * 0.55 * (1.0 if rng.randf() < 0.5 else -1.0)
		if rng.randf() < LANDING_BOX_CHANCE:
			_loot_spots.append(Transform3D(facing.rotated(Vector3.UP, rng.randf_range(-0.6, 0.6)), center + side - Vector3.UP * 0.05))
		elif rng.randf() < 0.6:
			entries.append([LANDING_EXTRAS[rng.randi() % LANDING_EXTRAS.size()], center + side, facing.rotated(Vector3.UP, rng.randf_range(-0.8, 0.8))])
		for entry: Array in entries:
			var spot: Vector3 = entry[1]
			spot.y = _terrain.height_at(spot.x, spot.z) - 0.08
			if not placed.has(entry[0]):
				placed[entry[0]] = []
			(placed[entry[0]] as Array).append(Transform3D(entry[2], spot))
			_prop_spots.append(spot)
	return placed


## 岩棚の山側の崖に据える物（廃坑・梯子）の置き方。うまく据えられなければ Transform3D()
func _landing_wall_prop(prop_name: String, center: Vector3, uphill: Vector3, radius: float) -> Transform3D:
	var out := -uphill
	var yaw_basis := Basis(Vector3.UP.cross(out), Vector3.UP, out)
	if prop_name == "mine":
		var origin := center + uphill * (radius + 0.4)
		origin.y = _terrain.height_at(origin.x, origin.z) - 0.1
		return Transform3D(yaw_basis, origin)
	# 梯子：平らな所に足を置き、崖の 5 m ほどの高さに寄りかからせる
	var foot := center + uphill * (radius - 0.8)
	foot.y = _terrain.height_at(foot.x, foot.z)
	for step in range(4, 40):
		var d := step * 0.25
		var probe := foot + uphill * d
		if _terrain.height_at(probe.x, probe.z) >= foot.y + 5.0:
			return _lean(yaw_basis, foot, probe - uphill * 0.15 + Vector3.UP * (foot.y + 5.0 - probe.y), Vector3(0.0, 0.0, 1.3), Vector3(0.0, 5.24, 0.05))
	return Transform3D()


## 平らな所の置き物は、谷のほう（山の中心から外）を向ける（登ってくる人から見えるように）。少しだけ、向きをばらつかせる
func _facing_out(p: Vector3, stage: int, rng: RandomNumberGenerator) -> Basis:
	var center: Vector2 = MountainChain.centers[stage]
	var out := Vector2(p.x - center.x, p.z - center.y).normalized()
	var yaw := atan2(out.x, out.y) + rng.randf_range(-0.5, 0.5)
	return Basis(Vector3.UP, yaw)


## 崖の表面に取りつける物。upright ならまっすぐ立て、そうでなければ崖の表面に沿わせる（鎖やお札）
func _wall_props(rng: RandomNumberGenerator, count: int, stage: int, above: float, upright: bool) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for entry: Array in _walls(rng, count * 4, stage, 20.0):
		if result.size() >= count:
			break
		var p: Vector3 = entry[0]
		var normal: Vector3 = entry[1]
		if p.y < above or _too_close_to(p, _prop_spots, 12.0) or (upright and normal.y > 0.2):
			continue
		var out := Vector3(normal.x, 0.0, normal.z).normalized()
		if upright:
			# まっすぐ立てて、少し崖にめりこませる（崖の傾きのぶん、上が浮かないように）
			result.append(Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), p - out * 0.3 - Vector3.UP * 0.4))
		else:
			var z := normal.normalized()
			var up := (Vector3.UP - z * z.y).normalized()
			result.append(Transform3D(Basis(up.cross(z).normalized(), up, z).scaled(Vector3.ONE * 1.4), p + up * 1.2))  # 遠くからも見える大きさに
	return result


## 崖の根元に置く物（廃坑の入り口、立てかけた梯子）。原点は崖の根元の地面、+Z は崖から離れる向き
func _foot_props(rng: RandomNumberGenerator, count: int, stage: int, above: float, avoid: PackedVector3Array, prop_name: String) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for p in _ledges(rng, count * 12, stage, 14.0, 1, avoid, KEEP_CLEAR, above, 0.7):
		if result.size() >= count:
			break
		var foot := _find_wall_foot(p)
		if foot.is_empty():
			continue
		var origin: Vector3 = foot[0]
		var into: Vector3 = foot[1]
		var out := -into
		var yaw_basis := Basis(Vector3.UP.cross(out), Vector3.UP, out)
		if prop_name == "mine":
			# 坑道の奥が崖の中に隠れるくらい、切り立った所だけ
			if _terrain.height_at(origin.x + into.x * 1.4, origin.z + into.z * 1.4) < origin.y + 2.6:
				continue
			result.append(Transform3D(yaw_basis, origin + into * 0.15 - Vector3.UP * 0.05))
		else:
			# 梯子の上の端が、崖の 5 m ほどの高さに寄りかかるように傾ける
			var reach := -1.0
			for d in range(2, 25):
				if _terrain.height_at(origin.x + into.x * d * 0.25, origin.z + into.z * d * 0.25) >= origin.y + 5.0:
					reach = d * 0.25
					break
			if reach < 0.0:
				continue
			var top := origin + into * (reach - 0.15) + Vector3.UP * 5.0
			var foot_point := origin + out * 1.2
			foot_point.y = _terrain.height_at(foot_point.x, foot_point.z)
			result.append(_lean(yaw_basis, foot_point, top, Vector3(0.0, 0.0, 1.3), Vector3(0.0, 5.24, 0.05)))
		_prop_spots.append(origin)
	return result


## 平らな所 p のすぐ横で、崖がそびえ始める所：[崖の根元の地面, 崖へ向かう水平の向き]。なければ空
func _find_wall_foot(p: Vector3) -> Array:
	var best := 0.0
	var found := []
	for k in 16:
		var angle := k * TAU / 16.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var rise := _terrain.height_at(p.x + dir.x * 3.0, p.z + dir.z * 3.0) - p.y
		if rise < 3.0 or rise <= best:
			continue
		for step in range(1, 12):
			var d := step * 0.25
			var h := _terrain.height_at(p.x + dir.x * d, p.z + dir.z * d)
			if h > p.y + 0.35:
				var foot := p + dir * maxf(d - 0.25, 0.0)
				foot.y = _terrain.height_at(foot.x, foot.z)
				best = rise
				found = [foot, dir]
				break
	return found


## 崖っぷちに置く物（吊り橋の残骸）。原点は崖の縁、+Z は谷の側
func _edge_props(rng: RandomNumberGenerator, count: int, stage: int, above: float, avoid: PackedVector3Array) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for p in _ledges(rng, count * 12, stage, 14.0, 1, avoid, KEEP_CLEAR, above, 0.7):
		if result.size() >= count:
			break
		for k in 16:
			var angle := k * TAU / 16.0
			var dir := Vector3(cos(angle), 0.0, sin(angle))
			if p.y - _terrain.height_at(p.x + dir.x * 2.5, p.z + dir.z * 2.5) < 3.5:
				continue
			var edge := p
			for step in range(1, 10):
				var next := p + dir * step * 0.25
				var h := _terrain.height_at(next.x, next.z)
				if h < p.y - 0.4:
					break
				edge = Vector3(next.x, h, next.z)
			result.append(Transform3D(Basis(Vector3.UP.cross(dir), Vector3.UP, dir), edge - Vector3.UP * 0.05))
			_prop_spots.append(edge)
			break
	return result


## 長い物（梯子）を、足もと foot から top へ届くように傾けた置き方。local_foot と local_top はモデルの中の足と頭の位置
func _lean(yaw_basis: Basis, foot: Vector3, top: Vector3, local_foot: Vector3, local_top: Vector3) -> Transform3D:
	var target := yaw_basis.inverse() * (top - foot)
	var along := local_top - local_foot
	var tilt := atan2(target.z, target.y) - atan2(along.z, along.y)
	var s := clampf(target.length() / along.length(), 0.85, 1.25)
	var lean_basis := yaw_basis * Basis(Vector3.RIGHT, tilt).scaled(Vector3.ONE * s)
	return Transform3D(lean_basis, foot - lean_basis * local_foot)


func _too_close_to(p: Vector3, points: PackedVector3Array, distance: float) -> bool:
	for other in points:
		if other.distance_squared_to(p) < distance * distance:
			return true
	return false


## 遭難者の亡骸：見ながら E で、遺品をさがせる（一度だけ）
func _add_belongings(t: Transform3D) -> void:
	var stage := _terrain.stage_of(t.origin)
	var belongings := Harvestable.new()
	belongings.kind = Items.pick_random(RandomNumberGenerator.new())
	belongings.amount = Vector2i(1, 1)
	belongings.regrow = INF
	belongings.label = "遺品をさがす"
	belongings.found_message = "遺品の中に、%sがあった"
	belongings.features = self
	add_child(belongings)
	belongings.global_position = t.origin + Vector3.UP * 0.1


## 平地の上の、ほかの物から離れた、だいたい平らな場所
func _plain_spot(rng: RandomNumberGenerator, stage: int, taken: PackedVector3Array) -> Vector3:
	var start := MountainChain.plain_starts[stage]
	var end := MountainChain.plain_ends[stage]
	var side := (end - start).normalized().orthogonal()
	for attempt in 40:
		var p := start.lerp(end, rng.randf_range(0.1, 0.95)) + side * rng.randf_range(-1.0, 1.0) * MountainChain.PLAIN_HALF_WIDTH * 0.8
		var y := _terrain.height_at(p.x, p.y)
		var spot := Vector3(p.x, y, p.y)
		if _terrain.normal_at(p.x, p.y).y < 0.8 or absf(y - MountainChain.bases[stage]) > 10.0 or _terrain.near_rock(spot, 3.0):
			continue
		var clear := true
		for other in taken:
			if Vector2(other.x - spot.x, other.z - spot.z).length() < 16.0:
				clear = false
				break
		if clear:
			return spot - Vector3.UP * 0.2
	return Vector3.INF


# --- 道具 ---

## 同じ形をたくさん置く。区画ごとに分けて、画面や影に入らない区画・遠い区画は描かない。
## material が null なら、メッシュの面ごとの素材で描く（Blender で作った草木）
func _multimesh(mesh: Mesh, material: Material, transforms: Array[Transform3D], draw_range := TREE_RANGE, shadows := true) -> void:
	if transforms.is_empty():
		return
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
		if material:
			instance.material_override = material
		instance.visibility_range_end = draw_range
		if not shadows:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


## 小さな物（ギミック・アイテム・化け物）は、遠くでは描かない（その物自身も）
func _limit_node(node: Node) -> void:
	if node is GeometryInstance3D and not node is MultiMeshInstance3D and (node as GeometryInstance3D).visibility_range_end == 0.0:
		(node as GeometryInstance3D).visibility_range_end = DETAIL_RANGE
	_limit_draw_distance(node)


## 小さな物（ギミック・アイテム・化け物）は、遠くでは描かない（中の物）
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
