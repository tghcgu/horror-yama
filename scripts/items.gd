class_name Items
extends RefCounted
## アイテムの種類・名前・説明・使い方・見た目・落ちている地帯

enum Kind {
	PITON, BANDAGE, ONIGIRI, OFUDA, ROPE, FLARE, FIRECRACKER, BELL, HAND_WARMER, THERMOS,
	CHOCOLATE, CANNED, CHALK, CRAMPONS, FIRST_AID, OMAMORI, MUSHROOM, SALT, ENERGY, COMPASS,
}

## 使い方
enum Use {
	SELF,     # 自分に使って、なくなる
	WALL,     # 登っている壁に使う（ハーケン）
	PLACE,    # その場に置く・貼る（お札・ロープ）
	THROW,    # 火をつけて／まいて投げる（発煙筒・爆竹・塩）
	TOOL,     # 何度でも使える道具（鈴・方位磁石）
	PASSIVE,  # 持っているだけで効く（お守り）
}

const COUNT := 20
const SLOTS := 6       # 持ち物の欄の数
const MAX_STACK := 3   # ひとつの欄に重ねられる数
const STARTING := [Kind.PITON, Kind.ONIGIRI]

const NAMES := [
	"ハーケン", "包帯", "おにぎり", "お札", "ロープ", "発煙筒", "爆竹", "熊よけの鈴", "カイロ", "水筒のお茶",
	"チョコ", "缶詰", "チョーク", "アイゼン", "救急箱", "お守り", "謎のキノコ", "清めの塩", "栄養ドリンク", "方位磁石",
]
const DESCRIPTIONS := [
	"登っている壁に打ち込み、ぶら下がって休む",
	"ケガを少し治す",
	"空腹を満たし、しばらく疲れにくくなる",
	"貼った場所のまわりに、化け物が入れなくなる",
	"崖のふちや壁から下へ垂らす。ロープは楽に登れる",
	"火をつけて投げる。燃えているあいだ、まわりに化け物が近寄れない",
	"火をつけて投げる。大きな音で、まわりの化け物を追い払う",
	"鳴らしているあいだ、獣が寄ってこない。ただし夜の“何か”にも聞こえる",
	"体を温め、しばらく冷えなくなる",
	"体が温まり、スタミナが少し戻る",
	"スタミナが少し戻り、空腹が少し減る",
	"空腹がほとんどなくなる。食べ終わるまで動けない",
	"しばらく、壁をつかんでいても疲れにくい。崩れる岩も少し長くもつ",
	"しばらく、急な斜面や氷の上でも滑らない",
	"ケガと寒さを治す",
	"持っているだけで、一度だけ転落死から守ってくれる",
	"何が起きるかわからない",
	"投げると、まわりの霊を消し去る",
	"スタミナが全快し、しばらく疲れにくい。あとでひどく腹が減る",
	"次のたき火の方角がわかる（なくならない）",
]
const USES := [
	Use.WALL, Use.SELF, Use.SELF, Use.PLACE, Use.PLACE, Use.THROW, Use.THROW, Use.TOOL, Use.SELF, Use.SELF,
	Use.SELF, Use.SELF, Use.SELF, Use.SELF, Use.SELF, Use.PASSIVE, Use.SELF, Use.THROW, Use.SELF, Use.TOOL,
]
## 食べ物（お地蔵さんにお供えできる）
const FOODS := [Kind.ONIGIRI, Kind.CHOCOLATE, Kind.CANNED]

## 地帯ごとの見つかりやすさ（樹海・岩場・雪山・霊峰）
const SPAWN_WEIGHTS := [
	[1.0, 3.0, 2.0, 1.0],  # ハーケン
	[2.0, 2.0, 2.0, 1.0],  # 包帯
	[3.0, 2.0, 2.0, 1.0],  # おにぎり
	[1.0, 1.0, 1.0, 3.0],  # お札
	[1.0, 2.0, 1.0, 1.0],  # ロープ
	[1.0, 1.0, 1.0, 1.0],  # 発煙筒
	[1.0, 1.0, 1.0, 0.5],  # 爆竹
	[1.5, 0.5, 0.3, 0.0],  # 熊よけの鈴
	[0.3, 1.0, 3.0, 2.0],  # カイロ
	[0.3, 1.0, 2.0, 1.0],  # 水筒のお茶
	[2.0, 2.0, 2.0, 1.0],  # チョコ
	[1.0, 1.0, 1.0, 0.5],  # 缶詰
	[0.5, 3.0, 1.0, 1.0],  # チョーク
	[0.2, 1.0, 3.0, 1.0],  # アイゼン
	[0.5, 1.0, 1.0, 1.0],  # 救急箱
	[0.3, 0.3, 0.5, 2.0],  # お守り
	[4.0, 0.5, 0.0, 0.0],  # 謎のキノコ
	[0.5, 0.5, 1.0, 3.0],  # 清めの塩
	[1.0, 1.0, 1.0, 1.0],  # 栄養ドリンク
	[1.0, 0.5, 0.3, 0.0],  # 方位磁石
]


static func pick_random(rng: RandomNumberGenerator, biome: int) -> int:
	var total := 0.0
	for weights: Array in SPAWN_WEIGHTS:
		total += float(weights[biome])
	var roll := rng.randf() * total
	for i in COUNT:
		roll -= float(SPAWN_WEIGHTS[i][biome])
		if roll <= 0.0:
			return i
	return COUNT - 1


## 落ちているアイテムや、手に持ったアイテムの見た目（大きさはだいたい 10〜25 cm）。
## 形は種類ごとに一度だけ作って 1 つのメッシュにまとめ、同じ種類のアイテムで使い回す
static func build_model(kind: int) -> Node3D:
	var meshes: Array = Shared.get_or_make("item_%d" % kind, _build_meshes.bind(kind))
	var model := Node3D.new()
	for entry: Array in meshes:
		var node := MeshInstance3D.new()
		node.mesh = entry[0]
		node.material_override = entry[1]
		model.add_child(node)
	return model


const GLOW := 0.5  # 色の a がこの値の部品は、光る部品としてまとめる（_glow() が返す）


static func _build_meshes(kind: int) -> Array:
	var root := {"solid": MeshBuilder.new(), "glow": MeshBuilder.new()}
	match kind:
		Kind.PITON:
			var metal := _material(Color(0.6, 0.62, 0.65), 0.9, 0.3)
			_part(root, _cylinder(0.004, 0.018, 0.24), metal, Vector3.ZERO)
			_part(root, _torus(0.02, 0.034), metal, Vector3(0.0, -0.14, 0.0), Vector3(PI / 2.0, 0.0, 0.0))
		Kind.BANDAGE:
			_part(root, _cylinder(0.06, 0.06, 0.08), _material(Color(0.92, 0.9, 0.84)), Vector3.ZERO, Vector3(0.0, 0.0, PI / 2.0))
			_part(root, _box(Vector3(0.075, 0.004, 0.12)), _material(Color(0.88, 0.86, 0.8)), Vector3(0.0, -0.058, 0.06))
		Kind.ONIGIRI:
			var rice := PrismMesh.new()
			rice.size = Vector3(0.14, 0.13, 0.06)
			_part(root, rice, _material(Color(0.95, 0.95, 0.92)), Vector3.ZERO)
			_part(root, _box(Vector3(0.07, 0.05, 0.064)), _material(Color(0.05, 0.08, 0.05)), Vector3(0.0, -0.04, 0.0))
		Kind.OFUDA:
			_part(root, _box(Vector3(0.07, 0.2, 0.004)), _material(Color(0.93, 0.88, 0.74)), Vector3.ZERO)
			var ink := _glow(Color(0.7, 0.05, 0.03), 1.5)
			for i in 3:
				var size := Vector3(0.012, 0.14, 0.006) if i == 1 else Vector3(0.045, 0.008, 0.006)
				_part(root, _box(size), ink, Vector3(0.0, [0.06, 0.0, -0.06][i], 0.0))
		Kind.ROPE:
			var rope := _material(Color(0.85, 0.45, 0.12))
			for i in 3:
				_part(root, _torus(0.05, 0.075), rope, Vector3(0.0, -0.02 + i * 0.02, 0.0), Vector3(0.0, 0.0, 0.1 * (i - 1)))
		Kind.FLARE:
			_part(root, _cylinder(0.022, 0.022, 0.22), _material(Color(0.8, 0.08, 0.05)), Vector3.ZERO)
			_part(root, _cylinder(0.024, 0.024, 0.04), _material(Color(0.95, 0.95, 0.9)), Vector3(0.0, 0.12, 0.0))
		Kind.FIRECRACKER:
			var paper := _material(Color(0.85, 0.1, 0.08))
			for i in 5:
				var angle := i * TAU / 5.0
				_part(root, _cylinder(0.012, 0.012, 0.09), paper, Vector3(cos(angle) * 0.025, 0.0, sin(angle) * 0.025))
			_part(root, _cylinder(0.003, 0.003, 0.08), _material(Color(0.3, 0.25, 0.2)), Vector3(0.0, 0.08, 0.0), Vector3(0.0, 0.0, 0.4))
		Kind.BELL:
			var brass := _material(Color(0.85, 0.65, 0.25), 0.8, 0.35)
			_part(root, _sphere(0.045), brass, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.1, 1.0))
			_part(root, _torus(0.01, 0.02), brass, Vector3(0.0, 0.055, 0.0), Vector3(PI / 2.0, 0.0, 0.0))
			_part(root, _box(Vector3(0.05, 0.004, 0.01)), _material(Color(0.1, 0.08, 0.05)), Vector3(0.0, -0.01, 0.042))
			_part(root, _cylinder(0.004, 0.004, 0.12), _material(Color(0.85, 0.15, 0.1)), Vector3(0.0, 0.12, 0.0))
		Kind.HAND_WARMER:
			_part(root, _box(Vector3(0.1, 0.13, 0.015)), _material(Color(0.95, 0.95, 0.92)), Vector3.ZERO)
			_part(root, _box(Vector3(0.1, 0.03, 0.017)), _material(Color(0.95, 0.45, 0.1)), Vector3(0.0, 0.03, 0.0))
		Kind.THERMOS:
			_part(root, _cylinder(0.035, 0.035, 0.2), _material(Color(0.7, 0.72, 0.75), 0.8, 0.3), Vector3.ZERO)
			_part(root, _cylinder(0.037, 0.037, 0.05), _material(Color(0.75, 0.15, 0.12)), Vector3(0.0, 0.12, 0.0))
		Kind.CHOCOLATE:
			_part(root, _box(Vector3(0.08, 0.15, 0.015)), _material(Color(0.35, 0.18, 0.1)), Vector3.ZERO)
			_part(root, _box(Vector3(0.082, 0.04, 0.017)), _material(Color(0.8, 0.8, 0.82), 0.9, 0.3), Vector3(0.0, 0.06, 0.0))
		Kind.CANNED:
			_part(root, _cylinder(0.04, 0.04, 0.07), _material(Color(0.75, 0.75, 0.78), 0.9, 0.3), Vector3.ZERO)
			_part(root, _cylinder(0.041, 0.041, 0.045), _material(Color(0.2, 0.45, 0.25)), Vector3.ZERO)
		Kind.CHALK:
			_part(root, _sphere(0.055), _material(Color(0.9, 0.9, 0.88)), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.1, 1.0))
			_part(root, _torus(0.04, 0.05), _material(Color(0.1, 0.1, 0.12)), Vector3(0.0, 0.05, 0.0))
		Kind.CRAMPONS:
			var steel := _material(Color(0.55, 0.57, 0.6), 0.9, 0.35)
			_part(root, _box(Vector3(0.08, 0.015, 0.2)), steel, Vector3.ZERO)
			for x in [-0.03, 0.03]:
				for z in [-0.07, 0.0, 0.07]:
					var spike := _cylinder(0.0, 0.008, 0.04)
					_part(root, spike, steel, Vector3(x, -0.025, z), Vector3(PI, 0.0, 0.0))
			_part(root, _box(Vector3(0.09, 0.01, 0.02)), _material(Color(0.8, 0.2, 0.1)), Vector3(0.0, 0.015, 0.0))
		Kind.FIRST_AID:
			_part(root, _box(Vector3(0.16, 0.11, 0.06)), _material(Color(0.8, 0.1, 0.1)), Vector3.ZERO)
			var white := _material(Color(0.95, 0.95, 0.95))
			_part(root, _box(Vector3(0.06, 0.018, 0.062)), white, Vector3.ZERO)
			_part(root, _box(Vector3(0.018, 0.06, 0.062)), white, Vector3.ZERO)
		Kind.OMAMORI:
			_part(root, _box(Vector3(0.05, 0.08, 0.012)), _material(Color(0.75, 0.1, 0.15)), Vector3.ZERO)
			_part(root, _box(Vector3(0.03, 0.035, 0.014)), _material(Color(0.9, 0.75, 0.3), 0.6, 0.4), Vector3(0.0, 0.005, 0.0))
			_part(root, _torus(0.008, 0.014), _material(Color(0.9, 0.75, 0.3)), Vector3(0.0, 0.05, 0.0), Vector3(PI / 2.0, 0.0, 0.0))
		Kind.MUSHROOM:
			_part(root, _cylinder(0.015, 0.02, 0.07), _material(Color(0.9, 0.87, 0.8)), Vector3(0.0, -0.02, 0.0))
			_part(root, _sphere(0.05), _material(Color(0.7, 0.12, 0.35)), Vector3(0.0, 0.02, 0.0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
			var spot := _glow(Color(0.7, 1.0, 0.6), 1.2)
			for i in 5:
				var angle := i * TAU / 5.0
				_part(root, _sphere(0.008), spot, Vector3(cos(angle) * 0.03, 0.04, sin(angle) * 0.03))
		Kind.SALT:
			_part(root, _cylinder(0.05, 0.04, 0.012), _material(Color(0.3, 0.25, 0.2)), Vector3(0.0, -0.02, 0.0))
			_part(root, _cylinder(0.0, 0.04, 0.06), _material(Color(0.97, 0.97, 0.95)), Vector3(0.0, 0.02, 0.0))
		Kind.ENERGY:
			_part(root, _cylinder(0.022, 0.024, 0.1), _material(Color(0.35, 0.18, 0.05), 0.2, 0.2), Vector3.ZERO)
			_part(root, _cylinder(0.025, 0.025, 0.04), _material(Color(0.95, 0.8, 0.1)), Vector3.ZERO)
			_part(root, _cylinder(0.012, 0.012, 0.02), _material(Color(0.8, 0.8, 0.8), 0.8, 0.3), Vector3(0.0, 0.06, 0.0))
		Kind.COMPASS:
			_part(root, _cylinder(0.045, 0.045, 0.02), _material(Color(0.8, 0.6, 0.25), 0.8, 0.35), Vector3.ZERO)
			_part(root, _cylinder(0.038, 0.038, 0.022), _material(Color(0.92, 0.9, 0.84)), Vector3.ZERO)
			_part(root, _box(Vector3(0.008, 0.004, 0.06)), _material(Color(0.8, 0.1, 0.08)), Vector3(0.0, 0.013, 0.0))
	var materials: Array = Shared.get_or_make("item_materials", _make_materials)
	var meshes := []
	if not (root.solid as MeshBuilder).is_empty():
		meshes.append([(root.solid as MeshBuilder).commit(), materials[0]])
	if not (root.glow as MeshBuilder).is_empty():
		meshes.append([(root.glow as MeshBuilder).commit(), materials[1]])
	return meshes


## 部品の色を頂点の色で塗る素材と、光る部品の素材
static func _make_materials() -> Array:
	var solid := StandardMaterial3D.new()
	solid.vertex_color_use_as_albedo = true
	solid.roughness = 0.7
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return [solid, glow]


## 見た目の範囲（モデルの原点から見た箱。物理の当たり判定や、絵の写し方に使う）
static func model_bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var local := mesh.transform * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


## 部品を、光る部品かどうかで分けてまとめる
static func _part(parts: Dictionary, mesh: PrimitiveMesh, color: Color, pos: Vector3,
		rot := Vector3.ZERO, part_scale := Vector3.ONE) -> void:
	var builder: MeshBuilder = parts.glow if is_equal_approx(color.a, GLOW) else parts.solid
	builder.add(mesh, pos, rot, part_scale, Color(color, 1.0))


## 部品の色（金属っぽさや粗さは、PS1 風の見た目では省く）
static func _material(color: Color, _metallic := 0.0, _roughness := 0.8) -> Color:
	return color


static func _glow(color: Color, _energy: float) -> Color:
	return Color(color, GLOW)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	return mesh


static func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 12
	mesh.ring_segments = 6
	return mesh
