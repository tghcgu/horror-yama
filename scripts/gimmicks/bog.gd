class_name Bog
extends Node3D
## 樹海の底なし沼。入ると足をとられて遅くなり、跳べず、少しずつ沈んでいく。頭まで沈むと助からない。

var player: Player
var radius := 3.5


func setup(center: Vector3, bog_radius: float, owner_player: Player) -> void:
	player = owner_player
	radius = bog_radius
	global_position = center
	var mud := StandardMaterial3D.new()
	mud.albedo_color = Color(0.2, 0.19, 0.1)  # 濁った緑がかった泥。空が映ってぬらりと光る
	mud.roughness = 0.08
	mud.metallic = 0.4
	var surface := CylinderMesh.new()
	surface.top_radius = radius
	surface.bottom_radius = radius
	surface.height = 0.1
	surface.radial_segments = 16
	surface.material = mud
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface
	mesh.position.y = 0.12
	add_child(mesh)
	# ふちに生えた葦
	var reeds := MeshBuilder.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.03, 1.0, 0.03)
	for i in 14:
		var angle := randf() * TAU
		var height := randf_range(0.6, 1.2)
		reeds.add(blade, Vector3(cos(angle), 0.0, sin(angle)) * radius * randf_range(0.85, 1.05) + Vector3.UP * height * 0.5,
			Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)), Vector3(1.0, height, 1.0), Color(0.35, 0.38, 0.2))
	reeds.instance(self, Psx.vertex_material())
	# ときどき浮かんでくる泡
	var bubbles := CPUParticles3D.new()
	bubbles.amount = 6
	bubbles.lifetime = 1.2
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = radius * 0.7
	bubbles.direction = Vector3.UP
	bubbles.initial_velocity_min = 0.05
	bubbles.initial_velocity_max = 0.15
	bubbles.gravity = Vector3.ZERO
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.2
	var bubble := SphereMesh.new()
	bubble.radius = 0.06
	bubble.height = 0.08
	bubble.material = mud
	bubbles.mesh = bubble
	bubbles.position.y = 0.15
	add_child(bubbles)
	var sound := AudioStreamPlayer3D.new()
	sound.stream = Sfx.bubbles()
	sound.unit_size = 3.0
	sound.max_distance = 25.0
	sound.autoplay = true
	add_child(sound)


func _physics_process(_delta: float) -> void:
	if player == null or player.state != Player.State.WALK:
		return
	var offset := player.global_position - global_position
	if Vector2(offset.x, offset.z).length() < radius and offset.y < 0.8:
		player.zone_bog = true
