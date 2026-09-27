class_name Ishinage
extends Node3D
## 岩場の岩棚の上に現れる、ひとつ目の毛むくじゃらの「石投げ」。崖を登ってくる者めがけて、石を投げ落としてくる。
## 当たるとケガをして壁からはがされる。爆竹の音や熊よけの鈴を嫌う。

const MODEL := preload("res://assets/models/ishinage.glb")
const SIZE := 1.25
const THROW_INTERVAL := 3.2
const WINDUP := 0.8
const LIFETIME := 25.0
const ROCK_SPEED := 15.0
const ROCK_INJURY := 18.0

var player: Player
var active := false

var _life := 0.0
var _timer := 0.0
var _winding := false
var _rocks: Array[RigidBody3D] = []
var _poser: BonePoser
var _grunt: AudioStreamPlayer3D
var _stone: Material
var _time := 0.0


func _ready() -> void:
	add_to_group(&"creatures")
	var skin := CreatureKit.skin(Color.WHITE, Color(0.4, 0.35, 0.3), 0.1, 0.1)
	var model := CreatureKit.load_model(MODEL, skin, {
		"Eye": CreatureKit.glow(Color(1.0, 0.7, 0.15), 6.0),
		"EyeBlack": CreatureKit.flat(Color(0.02, 0.01, 0.01), 0.3),
		"Teeth": CreatureKit.flat(Color(0.62, 0.56, 0.4), 0.5),
	})
	model.scale = Vector3.ONE * SIZE
	add_child(model)
	_poser = BonePoser.new(model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)
	_grunt = AudioStreamPlayer3D.new()
	_grunt.stream = Sfx.grunt()
	_grunt.unit_size = 8.0
	_grunt.max_distance = 60.0
	add_child(_grunt)
	_stone = Psx.material("rock", Color(0.6, 0.57, 0.52), 0.5, 0.4)
	visible = false


func appear(ledge: Vector3, owner_player: Player) -> void:
	player = owner_player
	global_position = ledge
	active = true
	visible = true
	_life = LIFETIME
	_timer = 1.5
	_winding = false
	_grunt.play()


func leave() -> void:
	active = false
	visible = false
	_grunt.stop()


func scare(_from: Vector3) -> void:
	if active:
		leave()


func _physics_process(delta: float) -> void:
	_update_rocks(delta)
	if not active or player == null:
		return
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() > 0.1:
		look_at(global_position + to, Vector3.UP)
	_life -= delta
	if _life <= 0.0 or player.frozen or player.bell_ringing or Ward.blocks(get_tree(), player.global_position):
		leave()
		return
	_timer -= delta
	if not _winding and _timer <= WINDUP:
		_winding = true
	if _timer <= 0.0:
		_winding = false
		_timer = THROW_INTERVAL
		throw_rock()


## 石をプレイヤーの胸めがけて放物線で投げる（少しぶれる）
func throw_rock() -> void:
	var start := global_position + Vector3.UP * 1.6 * SIZE
	var target := player.global_position + Vector3.UP * 1.1 + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4), randf_range(-0.6, 0.6))
	var flight := clampf(start.distance_to(target) / ROCK_SPEED, 0.5, 2.0)
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var velocity := (target - start) / flight + Vector3.UP * 0.5 * gravity * flight
	var rock := RigidBody3D.new()
	rock.collision_layer = Pickup.ITEM_LAYER
	rock.collision_mask = Player.TERRAIN_LAYER
	rock.mass = 20.0
	rock.continuous_cd = true
	var shape := SphereShape3D.new()
	shape.radius = 0.28
	var collision := CollisionShape3D.new()
	collision.shape = shape
	rock.add_child(collision)
	var stone_mesh: SphereMesh = Shared.get_or_make("thrown_rock", func() -> SphereMesh:  # 石の形は 1 つを使い回す
		var sphere := SphereMesh.new()
		sphere.radius = 0.28
		sphere.height = 0.5
		sphere.radial_segments = 6
		sphere.rings = 3
		return sphere)
	CreatureKit.part(rock, stone_mesh, _stone)
	get_parent().add_child(rock)
	rock.global_position = start
	rock.linear_velocity = velocity
	rock.set_meta("life", 6.0)
	_rocks.append(rock)
	_grunt.pitch_scale = randf_range(1.3, 1.6)


func _update_rocks(delta: float) -> void:
	for rock: RigidBody3D in _rocks.duplicate():
		if not is_instance_valid(rock):
			_rocks.erase(rock)
			continue
		var life: float = rock.get_meta("life") - delta
		rock.set_meta("life", life)
		if life <= 0.0:
			_rocks.erase(rock)
			rock.queue_free()
			continue
		if player == null or player.frozen or rock.linear_velocity.length() < 4.0:
			continue
		if rock.global_position.distance_to(player.global_position + Vector3.UP * 1.0) < 0.9:
			var push := rock.linear_velocity.normalized() * 3.0
			if player.state == Player.State.CLIMB:
				push += player.wall_normal() * 2.5
			player.knock(push, ROCK_INJURY)
			rock.linear_velocity *= 0.2
			rock.set_meta("life", minf(life, 1.5))


## 投げる前に、右腕を大きく振りかぶる
func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	var raise := 2.8 if _winding else -0.3
	_poser.set_target("upperarm.R", Vector3(raise, 0.0, -0.2))
	_poser.set_target("forearm.R", Vector3(0.8 if _winding else 0.2, 0.0, 0.0))
	_poser.set_target("upperarm.L", Vector3(0.3 + sin(_time * 2.0) * 0.1, 0.0, 0.2))
	_poser.set_target("chest", Vector3(-0.3 if _winding else 0.25, 0.0, 0.0))
	_poser.update(delta, 10.0 if _winding else 25.0)
	_poser.aim("head", player.get_camera().global_position)
