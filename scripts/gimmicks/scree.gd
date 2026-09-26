class_name Scree
extends Node3D
## 岩場のガレ場。細かい石が積もった斜面で、ほとんど平らな所でも足をとられて滑り落ちる。

var player: Player
var radius := 4.0


func setup(pos: Vector3, patch_radius: float, terrain: Terrain, owner_player: Player) -> void:
	player = owner_player
	radius = patch_radius
	global_position = pos
	var pebble := SphereMesh.new()
	pebble.radius = 0.12
	pebble.height = 0.14
	pebble.radial_segments = 5
	pebble.rings = 3
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = pebble
	multimesh.instance_count = 90
	for i in multimesh.instance_count:
		var angle := randf() * TAU
		var r := sqrt(randf()) * radius
		var x := pos.x + cos(angle) * r
		var z := pos.z + sin(angle) * r
		var local := Vector3(x, terrain.height_at(x, z) + 0.03, z) - pos
		var s := randf_range(0.6, 1.8)
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(s, s * 0.5, s)), local))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = Psx.material("rock", Color(0.62, 0.6, 0.58), 0.3, 0.3)
	add_child(instance)


func _physics_process(_delta: float) -> void:
	if player == null or not player.is_on_floor():
		return
	var offset := player.global_position - global_position
	if Vector2(offset.x, offset.z).length() < radius and absf(offset.y) < 4.0:
		player.zone_slippery = true
