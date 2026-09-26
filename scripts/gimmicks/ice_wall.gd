class_name IceWall
extends StaticBody3D
## 雪山の崖に張りついた青い氷。つかめるが、すべってずり落ち、ひどく疲れる（アイゼンがあれば平気）。
## （Player._update_surface が、つかんでいる面が "ice" のグループかどうかを見る）

const GROUP := &"ice"


## pos は崖の表面、normal は崖の外向き
func setup(pos: Vector3, normal: Vector3) -> void:
	add_to_group(GROUP)
	collision_layer = Player.TERRAIN_LAYER
	var out := normal.normalized()
	var up := (Vector3.UP - out * out.y).normalized()
	global_transform = Transform3D(Basis(up.cross(out), up, out), pos + out * 0.45)
	var size := Vector3(randf_range(2.5, 4.0), randf_range(3.5, 6.0), 1.2)
	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.shape = box
	add_child(collision)
	var material: StandardMaterial3D = Shared.get_or_make("ice_wall", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.8, 1.0, 0.75)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic = 0.2
		m.rim_enabled = true
		m.rim = 0.6
		return m)
	var ice := MeshBuilder.new()
	ice.add(BoxMesh.new(), Vector3.ZERO, Vector3.ZERO, size)
	# 表面の氷のこぶ
	var bump := CreatureKit.sphere(1.0)
	bump.radial_segments = 6
	bump.rings = 3
	for i in 5:
		var r := randf_range(0.3, 0.6)
		ice.add(bump, Vector3(randf_range(-1.0, 1.0) * size.x * 0.4, randf_range(-1.0, 1.0) * size.y * 0.4, size.z * 0.4),
			Vector3.ZERO, Vector3(r, r * 1.4, r * 0.35))
	ice.instance(self, material)
