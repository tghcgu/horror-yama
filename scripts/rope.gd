class_name Rope
extends StaticBody3D
## 崖に垂らしたロープ。つかんで登ると、岩よりずっと楽に登れる（スタミナがあまり減らない）。
## 地形と同じ層に当たり判定を置くので、壁と同じようにつかんで登れる。

const GROUP := &"ropes"
const WIDTH := 0.3
const MAX_LENGTH := 26.0
const GAP := 0.3  # 壁からどれだけ離して垂らすか


## ツリーに加えてから呼ぶ。top は結んだ所、outward は壁の外向き（水平）、length は垂らす長さ
func setup(top: Vector3, outward: Vector3, length: float) -> void:
	add_to_group(GROUP)
	collision_layer = Player.TERRAIN_LAYER
	var out := Vector3(outward.x, 0.0, outward.z).normalized()
	# 岩肌のでっぱりに埋もれないように、いちばん張り出した所より外に垂らす
	var gap := GAP
	var space := get_world_3d().direct_space_state
	for h in range(1, int(length)):
		var from := top + out * 4.0 - Vector3.UP * h
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - out * 5.0, Player.TERRAIN_LAYER))
		if not hit.is_empty():
			gap = maxf(gap, ((hit.position as Vector3) - top).dot(out) + WIDTH)
	gap = minf(gap, 2.5)
	global_transform = Transform3D(Basis.looking_at(-out, Vector3.UP), top + out * gap)
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, length, WIDTH)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position.y = -length / 2.0
	add_child(collision)

	var rope_material := StandardMaterial3D.new()
	rope_material.albedo_color = Color(0.9, 0.45, 0.1)
	rope_material.roughness = 0.9
	var line := CylinderMesh.new()
	line.top_radius = 0.022
	line.bottom_radius = 0.022
	line.height = length
	line.radial_segments = 6
	line.material = rope_material
	var mesh := MeshInstance3D.new()
	mesh.mesh = line
	mesh.position.y = -length / 2.0
	add_child(mesh)
	# 1 m ごとの結び目
	var knot := SphereMesh.new()
	knot.radius = 0.04
	knot.height = 0.07
	knot.radial_segments = 6
	knot.rings = 3
	knot.material = rope_material
	for i in int(length):
		var k := MeshInstance3D.new()
		k.mesh = knot
		k.position.y = -1.0 - i
		add_child(k)
	# 結んだ所に打ったハーケン
	var anchor := Items.build_model(Items.Kind.PITON)
	anchor.scale = Vector3.ONE * 1.5
	anchor.rotation.x = -PI / 2.0  # とがった先を壁の中へ
	anchor.position = Vector3(0.0, 0.05, -gap)
	add_child(anchor)
	# ハーケンから、垂らした所までの短いロープ
	var span := CylinderMesh.new()
	span.top_radius = 0.022
	span.bottom_radius = 0.022
	span.height = gap
	span.radial_segments = 6
	span.material = rope_material
	var bridge := MeshInstance3D.new()
	bridge.mesh = span
	bridge.rotation.x = PI / 2.0
	bridge.position = Vector3(0.0, 0.05, -gap * 0.5)
	add_child(bridge)
