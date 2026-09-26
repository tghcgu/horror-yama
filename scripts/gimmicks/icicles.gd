class_name Icicles
extends Node3D
## 突き出た岩板の裏に下がるつらら。真下を通ると、ピシッと鳴って落ちてくる。当たると大ケガ。

const TRIGGER_RADIUS := 1.8
const DELAY := 0.35
const FALL_GRAVITY := 22.0
const INJURY := 22.0

var player: Player
var terrain: Terrain
var state := "hanging"

var _timer := 0.0
var _speed := 0.0
var _hit := false
var _crack: AudioStreamPlayer3D


func setup(pos: Vector3, owner_player: Player, mountain: Terrain) -> void:
	player = owner_player
	terrain = mountain
	global_position = pos
	var shapes: Array = Shared.get_or_make("icicles", _build_shapes)
	var cluster := MeshInstance3D.new()
	cluster.mesh = (shapes[0] as Array).pick_random()
	cluster.material_override = shapes[1]
	cluster.rotation.y = randf() * TAU
	add_child(cluster)
	_crack = AudioStreamPlayer3D.new()
	_crack.stream = Sfx.crack()
	_crack.pitch_scale = 1.6
	_crack.unit_size = 6.0
	add_child(_crack)


## つららの形は 4 通りだけ作って、すべてのつららで使い回す。[形の一覧, 素材] を返す
static func _build_shapes() -> Array:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.88, 1.0, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.1
	var shapes := []
	var spike := CylinderMesh.new()
	spike.top_radius = 1.0
	spike.bottom_radius = 0.0
	spike.height = 1.0
	spike.radial_segments = 5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for variant in 4:
		var cluster := MeshBuilder.new()
		for i in rng.randi_range(4, 7):
			var width := rng.randf_range(0.06, 0.12)
			var length := rng.randf_range(0.5, 1.4)
			cluster.add(spike, Vector3(rng.randf_range(-0.5, 0.5), -length * 0.5, rng.randf_range(-0.5, 0.5)), Vector3.ZERO,
				Vector3(width, length, width))
		shapes.append(cluster.commit())
	return [shapes, material]


func _physics_process(delta: float) -> void:
	if player == null:
		return
	match state:
		"hanging":
			var offset := player.global_position - global_position
			if Vector2(offset.x, offset.z).length() < TRIGGER_RADIUS and offset.y < -0.5 and offset.y > -14.0 and not player.frozen:
				state = "cracking"
				_timer = DELAY
				_crack.play()
		"cracking":
			_timer -= delta
			position += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.01
			if _timer <= 0.0:
				state = "falling"
		"falling":
			_speed += FALL_GRAVITY * delta
			global_position.y -= _speed * delta
			var chest := player.global_position + Vector3.UP * 1.2
			if not _hit and global_position.distance_to(chest) < 1.1 and not player.frozen:
				_hit = true
				player.knock(Vector3.DOWN * 2.0, INJURY)
			if global_position.y < terrain.height_at(global_position.x, global_position.z) - 0.5:
				_shatter()


func _shatter() -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = Sfx.shimmer()
	sound.pitch_scale = 2.5
	sound.unit_size = 5.0
	get_parent().add_child(sound)
	sound.global_position = global_position
	sound.play()
	sound.finished.connect(sound.queue_free)
	queue_free()
