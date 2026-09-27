class_name ScatterField
extends MultiMeshInstance3D
## 小さな草花や石を、プレイヤーのまわり（radius 以内）にだけ描く。
## 置き場所はすべて覚えておき、プレイヤーが少し動くたびに、近くのものだけを GPU に渡し直す。
## 種類ごとに GPU の物は 1 つですむ（区画ごとに分けると、数が多すぎて GPU の上限に届いてしまう）。

const CELL := 24.0      # 置き場所を探しやすく分けておく区画 (m)
const REFRESH := 6.0    # これだけ動いたら、渡し直す (m)
const MAX_SHOWN := 3000

var radius := 60.0
var inner_radius := 0.0  # これより近いものは描かない（近くは細かい形、遠くは一枚絵、と描き分けるとき）
var watch: Node3D

var _cells := {}  # 区画 → その区画の置き場所（Transform3D の配列）
var _last := Vector3.INF


func setup(mesh: Mesh, transforms: Array[Transform3D], player: Node3D, draw_radius: float, material: Material = null, shadows := false, near_limit := 0.0) -> void:
	watch = player
	radius = draw_radius
	inner_radius = near_limit
	for t in transforms:
		var key := Vector2i(floori(t.origin.x / CELL), floori(t.origin.z / CELL))
		if not _cells.has(key):
			_cells[key] = []
		(_cells[key] as Array).append(t)
	var field := MultiMesh.new()
	field.transform_format = MultiMesh.TRANSFORM_3D
	field.mesh = mesh
	field.instance_count = mini(transforms.size(), MAX_SHOWN)
	field.visible_instance_count = 0
	multimesh = field
	if material:
		material_override = material
	if not shadows:
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## すぐに、いまの場所のまわりで渡し直す（場所が飛んだとき）
func refresh() -> void:
	_last = Vector3.INF


func _process(_delta: float) -> void:
	if watch == null or multimesh == null or multimesh.instance_count == 0:
		return
	var pos := watch.global_position
	if pos.distance_to(_last) < REFRESH:
		return
	_last = pos
	var shown := 0
	var reach := radius * radius
	var inside := inner_radius * inner_radius
	var x0 := floori((pos.x - radius) / CELL)
	var x1 := floori((pos.x + radius) / CELL)
	var z0 := floori((pos.z - radius) / CELL)
	var z1 := floori((pos.z + radius) / CELL)
	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			for t: Transform3D in _cells.get(Vector2i(cx, cz), []):
				var dx := t.origin.x - pos.x
				var dz := t.origin.z - pos.z
				var d2 := dx * dx + dz * dz
				if d2 < reach and d2 >= inside and shown < multimesh.instance_count:
					multimesh.set_instance_transform(shown, t)
					shown += 1
	multimesh.visible_instance_count = shown
