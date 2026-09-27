class_name ItemBox
extends StaticBody3D
## アイテムの入った箱。見ながら E で開けると、ふたが跳ね上がり、上げ底の上に並んだアイテムが見える（見ながら E で取る）。
## 開けたあとも中をほんのり照らすので、夜でも中身がわかる。
## 地帯ごとに見た目が違う（樹海は木箱、岩場は鉄の箱、雪山は霜のついた木箱、霊峰は朱塗りの箱）。

const SIZE := Vector3(0.7, 0.42, 0.5)
const TRAY := 0.24  # 上げ底の高さ（アイテムが、ふちから少しのぞく高さに並ぶ）
const STYLES := [
	[Color(0.45, 0.3, 0.16), Color(0.3, 0.2, 0.1), Color(0.55, 0.5, 0.4)],    # 樹海：木箱（板・枠・金具）
	[Color(0.38, 0.4, 0.36), Color(0.22, 0.23, 0.21), Color(0.75, 0.6, 0.2)],  # 岩場：鉄の箱
	[Color(0.6, 0.58, 0.55), Color(0.85, 0.9, 0.95), Color(0.5, 0.55, 0.6)],   # 雪山：霜のついた木箱
	[Color(0.12, 0.06, 0.06), Color(0.7, 0.12, 0.08), Color(0.85, 0.7, 0.3)],  # 霊峰：朱塗りの箱
]

var contents: Array[int] = []
var opened := false
var features: MountainFeatures

var _lid: Node3D
var _glow: OmniLight3D


func setup(items: Array[int], style: int, owner_features: MountainFeatures) -> void:
	contents = items
	features = owner_features
	add_to_group(&"interactables")
	collision_layer = Player.TERRAIN_LAYER
	var box := BoxShape3D.new()
	box.size = SIZE
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position.y = SIZE.y * 0.5
	add_child(collision)
	var meshes: Array = Shared.get_or_make("item_box_%d" % style, _build_meshes.bind(style))
	var body := MeshInstance3D.new()
	body.mesh = meshes[0]
	body.material_override = Psx.vertex_material("wood", 1.0, 0.8)
	add_child(body)
	# ふたは奥のふちを軸に開く
	_lid = Node3D.new()
	_lid.position = Vector3(0.0, SIZE.y, -SIZE.z * 0.5)
	add_child(_lid)
	var lid := MeshInstance3D.new()
	lid.mesh = meshes[1]
	lid.material_override = body.material_override
	lid.position = Vector3(0.0, 0.0, SIZE.z * 0.5)
	_lid.add_child(lid)
	# 夜でも見つけられるように、すき間からほのかに光がもれる
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.85, 0.6)
	_glow.light_energy = 0.6
	_glow.omni_range = 2.4
	_glow.position.y = SIZE.y + 0.2
	_glow.distance_fade_enabled = true  # 箱がたくさんあるので、遠くの箱の明かりは消す
	_glow.distance_fade_begin = 35.0
	_glow.distance_fade_length = 10.0
	_glow.shadow_enabled = false
	add_child(_glow)


## 箱の本体とふた。板の継ぎ目・角の枠・留め金を、色を変えた形で重ねる
static func _build_meshes(style: int) -> Array:
	var colors: Array = STYLES[style]
	var plank: Color = colors[0]
	var frame: Color = colors[1]
	var metal: Color = colors[2]
	var cube := BoxMesh.new()
	var body := MeshBuilder.new()
	var height := SIZE.y * 0.8
	body.add(cube, Vector3(0.0, height * 0.5, 0.0), Vector3.ZERO, Vector3(SIZE.x, height, SIZE.z), plank)
	for i in 2:
		body.add(cube, Vector3(0.0, height * (0.3 + i * 0.4), 0.0), Vector3.ZERO, Vector3(SIZE.x + 0.02, 0.02, SIZE.z + 0.02), plank.darkened(0.3))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			body.add(cube, Vector3(x * SIZE.x * 0.5, height * 0.5, z * SIZE.z * 0.5), Vector3.ZERO, Vector3(0.06, height + 0.02, 0.06), frame)
	body.add(cube, Vector3(0.0, height - 0.06, SIZE.z * 0.5 + 0.01), Vector3.ZERO, Vector3(0.08, 0.1, 0.02), metal)  # 留め金
	body.add(cube, Vector3(0.0, TRAY - 0.01, 0.0), Vector3.ZERO, Vector3(SIZE.x - 0.05, 0.02, SIZE.z - 0.05), plank.lightened(0.25))  # 上げ底
	var lid := MeshBuilder.new()
	var lid_height := SIZE.y - height
	lid.add(cube, Vector3(0.0, lid_height * 0.5, 0.0), Vector3.ZERO, Vector3(SIZE.x + 0.03, lid_height, SIZE.z + 0.03), plank.lightened(0.05))
	lid.add(cube, Vector3(0.0, lid_height + 0.005, 0.0), Vector3.ZERO, Vector3(SIZE.x * 0.9, 0.012, 0.05), frame)
	lid.add(cube, Vector3(0.0, lid_height * 0.5, SIZE.z * 0.5 + 0.02), Vector3.ZERO, Vector3(0.1, lid_height * 0.8, 0.02), metal)
	return [body.commit(), lid.commit()]


func interact_hint(_player: Player) -> String:
	return "" if opened else "E：箱を開ける"


## 開ける：ふたが跳ね上がり、中身が飛び出す
func interact(_player: Player) -> void:
	if opened:
		return
	opened = true
	remove_from_group(&"interactables")
	var tween := create_tween()
	tween.tween_property(_lid, "rotation:x", -1.9, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 中身が見えるように、真上から明るく照らす
	tween.parallel().tween_property(_glow, "light_energy", 1.2, 0.3)
	_glow.omni_range = 1.6
	_glow.position.y = SIZE.y + 0.5
	var sound := AudioStreamPlayer3D.new()
	sound.stream = Sfx.crack()
	sound.pitch_scale = 0.8
	sound.unit_size = 4.0
	add_child(sound)
	sound.play()
	# 中身は上げ底の上に並べて置いたまま（取るまで動かない）
	for i in contents.size():
		var slot := (i - (contents.size() - 1) * 0.5) * 0.28
		var item := features.spawn_item(contents[i], global_transform * Vector3(slot, TRAY + 0.07, 0.0), Vector3.ZERO)
		item.freeze = true
		item.angular_velocity = Vector3.ZERO
		item.rotation = rotation
	contents.clear()
