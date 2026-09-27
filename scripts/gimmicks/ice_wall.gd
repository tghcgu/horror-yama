class_name IceWall
extends StaticBody3D
## 雪山の崖に張りついた青い氷。つかめるが、すべってずり落ち、ひどく疲れる（アイゼンがあれば平気）。
## （Player._update_surface が、つかんでいる面が "ice" のグループかどうかを見る）

const GROUP := &"ice"


## pos は崖の表面、normal は崖の外向き。見た目は Blender で作った凍った滝（prop_ice_wall）
func setup(pos: Vector3, normal: Vector3) -> void:
	add_to_group(GROUP)
	collision_layer = Player.TERRAIN_LAYER
	var out := normal.normalized()
	var up := (Vector3.UP - out * out.y).normalized()
	var size := randf_range(0.85, 1.35)
	global_transform = Transform3D(Basis(up.cross(out), up, out).scaled(Vector3.ONE * size), pos + out * 0.05)
	var mesh := Flora.prop("ice_wall")
	var look := MeshInstance3D.new()
	look.mesh = mesh
	add_child(look)
	var collision := CollisionShape3D.new()
	collision.shape = Flora.solid_shape(mesh)
	add_child(collision)
