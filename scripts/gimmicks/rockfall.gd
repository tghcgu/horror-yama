class_name Rockfall
extends Node3D
## 岩場の落石地帯。近くの崖にいると、ときどきパラパラと小石が落ちてきたあと、上から大きな岩が転がり落ちてくる。
## 当たるとケガをして、壁からはがされる（ハーケンでぶら下がっていれば耐えられる）。

const RANGE := 22.0
const INTERVAL := Vector2(7.0, 13.0)
const WARNING := 1.3
const ROCK_INJURY := 15.0

var player: Player

var _timer := 0.0
var _warning := -1.0
var _drop_point := Vector3.ZERO
var _rocks: Array[RigidBody3D] = []
var _rock_life := {}
var _trickle: LazyParticles
var _sound: AudioStreamPlayer3D
var _stone: Material


func setup(pos: Vector3, owner_player: Player) -> void:
	player = owner_player
	global_position = pos
	_timer = randf_range(INTERVAL.x, INTERVAL.y)
	_stone = Psx.material("rock", Color(0.6, 0.58, 0.55), 0.5, 0.4)
	_trickle = LazyParticles.new()
	add_child(_trickle)
	_trickle.setup(_make_trickle)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.crumble()
	_sound.unit_size = 12.0
	_sound.max_distance = 60.0
	_sound.top_level = true
	add_child(_sound)


func _physics_process(delta: float) -> void:
	_update_rocks(delta)
	if player == null or player.frozen:
		return
	var offset := player.global_position - global_position
	var near := Vector2(offset.x, offset.z).length() < RANGE and offset.y > -25.0 and offset.y < 8.0
	if _warning >= 0.0:
		_warning -= delta
		if _warning < 0.0:
			_trickle.set_emitting(false)
			for i in randi_range(2, 3):
				_drop(_drop_point + Vector3(randf_range(-1.5, 1.5), i * 1.5, randf_range(-1.5, 1.5)))
		return
	if not near:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(INTERVAL.x, INTERVAL.y)
		start_fall()


## 小石がパラパラ落ちてくる（前ぶれ）。WARNING 秒後に、プレイヤーの頭上から岩が落ちる
func start_fall() -> void:
	var outward := player.wall_normal() if player.state == Player.State.CLIMB else Vector3.ZERO
	_drop_point = player.global_position + Vector3.UP * randf_range(11.0, 15.0) + outward * 0.8
	_warning = WARNING
	_trickle.get_particles().global_position = _drop_point
	_trickle.set_emitting(true)
	_sound.global_position = _drop_point
	_sound.play()


func _drop(at: Vector3) -> void:
	var rock := RigidBody3D.new()
	rock.collision_layer = Pickup.ITEM_LAYER
	rock.collision_mask = Player.TERRAIN_LAYER
	rock.mass = 40.0
	rock.continuous_cd = true
	var r := randf_range(0.35, 0.6)
	var shape := SphereShape3D.new()
	shape.radius = r
	var collision := CollisionShape3D.new()
	collision.shape = shape
	rock.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.mesh = Shared.get_or_make("falling_rock", func() -> SphereMesh:  # 岩の形は 1 つを使い回し、大きさだけ変える
		var sphere := SphereMesh.new()
		sphere.radial_segments = 6
		sphere.rings = 3
		return sphere)
	mesh.material_override = _stone
	mesh.rotation = Vector3(randf(), randf(), randf())
	mesh.scale = Vector3(1.0, randf_range(0.7, 1.0), 1.0) * r * 2.0
	rock.add_child(mesh)
	get_parent().add_child(rock)
	rock.global_position = at
	rock.linear_velocity = Vector3(0.0, -4.0, 0.0)
	rock.angular_velocity = Vector3(randf(), randf(), randf()) * 6.0
	_rocks.append(rock)
	_rock_life[rock] = 8.0


func _update_rocks(delta: float) -> void:
	for rock: RigidBody3D in _rocks.duplicate():
		if not is_instance_valid(rock):
			_rocks.erase(rock)
			continue
		_rock_life[rock] -= delta
		if _rock_life[rock] <= 0.0:
			_rocks.erase(rock)
			_rock_life.erase(rock)
			rock.queue_free()
			continue
		if player == null or player.frozen or rock.linear_velocity.length() < 3.0:
			continue
		var chest := player.global_position + Vector3.UP * 1.0
		if rock.global_position.distance_to(chest) < 1.0:
			var push := rock.linear_velocity.normalized() * 3.0
			if player.state == Player.State.CLIMB:
				push += player.wall_normal() * 2.5
			player.knock(push, ROCK_INJURY)
			rock.linear_velocity *= 0.3
			_rock_life[rock] = minf(_rock_life[rock], 2.0)


## 粒子を作る（LazyParticles が、使うときにだけ呼ぶ）
func _make_trickle() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.amount = 24
	particles.lifetime = 1.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.0
	particles.gravity = Vector3(0.0, -12.0, 0.0)
	var pebble := BoxMesh.new()
	pebble.size = Vector3.ONE * 0.06
	pebble.material = _stone
	particles.mesh = pebble
	particles.top_level = true
	return particles
