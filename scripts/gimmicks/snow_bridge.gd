class_name SnowBridge
extends StaticBody3D
## 隠れクレバスをふさぐ雪のふた。まわりの雪と見分けがつかないが、上に乗るとミシッと鳴り、すぐに崩れ落ちる。

const COLLAPSE_TIME := 0.7

var player: Player
var radius := 2.2

var _timer := -1.0
var _crack: AudioStreamPlayer3D


## pit は Terrain.pits の 1 つ（x, z, ふちの高さ）
func setup(pit: Vector3, pit_radius: float, owner_player: Player) -> void:
	player = owner_player
	radius = pit_radius
	collision_layer = Player.TERRAIN_LAYER
	global_position = Vector3(pit.x, pit.z - 0.12, pit.y)
	var lid := CylinderShape3D.new()
	lid.radius = radius + 0.3
	lid.height = 0.24
	var collision := CollisionShape3D.new()
	collision.shape = lid
	add_child(collision)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius + 0.35
	mesh.bottom_radius = radius + 0.2
	mesh.height = 0.24
	mesh.radial_segments = 14
	CreatureKit.part(self, mesh, Psx.material("ground_snow", Color(1.0, 1.02, 1.06), 0.33, 0.8))
	_crack = AudioStreamPlayer3D.new()
	_crack.stream = Sfx.crack()
	_crack.pitch_scale = 0.6
	_crack.unit_size = 6.0
	add_child(_crack)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if _timer >= 0.0:
		_timer -= delta
		if _timer < 0.0:
			collapse()
		return
	var offset := player.global_position - global_position
	if Vector2(offset.x, offset.z).length() < radius + 0.2 and offset.y > -0.2 and offset.y < 0.8 and not player.frozen:
		_timer = COLLAPSE_TIME
		_crack.play()
		player.add_shake(0.3)


func collapse() -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = Sfx.crumble()
	sound.pitch_scale = 0.7
	sound.unit_size = 10.0
	get_parent().add_child(sound)
	sound.global_position = global_position
	sound.play()
	sound.finished.connect(sound.queue_free)
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = 50
	puff.lifetime = 1.5
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = radius
	puff.gravity = Vector3(0.0, -8.0, 0.0)
	var flake := BoxMesh.new()
	flake.size = Vector3.ONE * 0.15
	flake.material = Psx.material("", Color(1.0, 1.0, 1.05))
	puff.mesh = flake
	get_parent().add_child(puff)
	puff.global_position = global_position
	puff.emitting = true
	get_tree().create_timer(3.0).timeout.connect(puff.queue_free)
	queue_free()
