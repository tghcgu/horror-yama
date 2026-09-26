class_name Pickup
extends RigidBody3D
## 山に落ちているアイテム。物理で転がり、斜面では滑り落ち、崖から落ちれば下まで転がっていく。
## 見ながら E で拾う。夜でも見つけられるように、ほのかに光る。
## 火をつけて投げた発煙筒・爆竹、まいた塩は、ここで効き目を出す。

const GROUP := &"pickups"
const ITEM_LAYER := 16        # アイテムどうしと地形にだけぶつかる（プレイヤーはすり抜ける）
const VISUAL_SCALE := 1.6
const FLARE_TIME := 60.0
const FLARE_RADIUS := 7.0     # 燃えている発煙筒のまわりには、化け物が入れない
const FUSE_TIME := 1.4
const BANG_RADIUS := 18.0
const PURIFY_RADIUS := 9.0

var kind := 0
var lit := false
var radius := 0.0  # 燃えている発煙筒の守りの円（Ward.blocks が読む）

var _time_left := 0.0
var _landed := false
var _light: OmniLight3D
var _sparks: CPUParticles3D
var _sound: AudioStreamPlayer3D


## ツリーに加える前に呼ぶ。activated なら、火のついた発煙筒・爆竹、まいた塩として投げる
func setup(item_kind: int, activated := false) -> void:
	kind = item_kind
	lit = activated
	add_to_group(GROUP)
	collision_layer = ITEM_LAYER
	collision_mask = Player.TERRAIN_LAYER | ITEM_LAYER
	continuous_cd = true
	angular_damp = 0.6
	var surface := PhysicsMaterial.new()
	surface.friction = 0.9
	surface.bounce = 0.15
	physics_material_override = surface

	var model := Items.build_model(kind)
	model.scale = Vector3.ONE * VISUAL_SCALE
	add_child(model)
	var bounds := Items.model_bounds(model)
	var box := BoxShape3D.new()
	box.size = (bounds.size * VISUAL_SCALE).max(Vector3.ONE * 0.08)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position = bounds.get_center() * VISUAL_SCALE
	add_child(collision)
	mass = 0.4

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.85, 0.6)
	_light.light_energy = 0.6
	_light.omni_range = 2.2
	_light.position.y = 0.3
	add_child(_light)

	if not lit:
		return
	match kind:
		Items.Kind.FLARE:
			_time_left = FLARE_TIME
			radius = FLARE_RADIUS
			add_to_group(Ward.GROUP)
			_light.light_color = Color(1.0, 0.2, 0.12)
			_light.omni_range = 14.0
			_sparks = _make_sparks(Color(1.0, 0.35, 0.15), 40)
			_sound = _make_sound(Sfx.fizz(), 3.0)
		Items.Kind.FIRECRACKER:
			_time_left = FUSE_TIME
			_sparks = _make_sparks(Color(1.0, 0.8, 0.3), 16)
			_sound = _make_sound(Sfx.fizz(), 1.5)
		Items.Kind.SALT:
			_time_left = 2.5
			contact_monitor = true
			max_contacts_reported = 2
			body_entered.connect(func(_body: Node) -> void: _landed = true)


func _physics_process(delta: float) -> void:
	if global_position.y < -60.0:
		queue_free()
		return
	if not lit:
		return
	_time_left -= delta
	match kind:
		Items.Kind.FLARE:
			_light.light_energy = (2.6 + randf() * 0.8) * clampf(_time_left / 4.0, 0.0, 1.0)
			if _time_left <= 0.0:
				queue_free()  # 燃え尽きた
		Items.Kind.FIRECRACKER:
			if _time_left <= 0.0:
				_bang()
		Items.Kind.SALT:
			if _landed or _time_left <= 0.0:
				_purify()


## 爆竹がはじけた：まわりの化け物がみんな逃げていく
func _bang() -> void:
	for creature: Node3D in get_tree().get_nodes_in_group(&"creatures"):
		if creature.global_position.distance_to(global_position) < BANG_RADIUS and creature.has_method("scare"):
			creature.call("scare", global_position)
	_burst(Color(1.0, 0.85, 0.5), Sfx.bang(), 8.0)
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		var distance := player.global_position.distance_to(global_position)
		if distance < 12.0:
			player.add_shake(clampf(1.2 - distance / 10.0, 0.2, 1.0))
	queue_free()


## 塩が落ちた：まわりの霊が消える
func _purify() -> void:
	for spirit: Node3D in get_tree().get_nodes_in_group(&"spirits"):
		if spirit.global_position.distance_to(global_position) < PURIFY_RADIUS and spirit.has_method("purify"):
			spirit.call("purify")
	_burst(Color(0.9, 0.95, 1.0), Sfx.shimmer(), 3.0)
	queue_free()


## はじけた瞬間の光と音と火花。アイテム自体は消えるので、別に残して時間で消す
func _burst(color: Color, stream: AudioStream, energy: float) -> void:
	var flash := Node3D.new()
	get_parent().add_child(flash)
	flash.global_position = global_position + Vector3.UP * 0.3
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 12.0
	flash.add_child(light)
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 40
	sparks.lifetime = 0.8
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 7.0
	sparks.gravity = Vector3(0.0, -6.0, 0.0)
	sparks.mesh = _spark_mesh(color)
	sparks.emitting = true
	flash.add_child(sparks)
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.unit_size = 10.0
	sound.max_distance = 120.0
	flash.add_child(sound)
	sound.play()
	var tween := flash.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_callback(flash.queue_free)


func _make_sparks(color: Color, amount: int) -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.amount = amount
	sparks.lifetime = 0.7
	sparks.direction = Vector3.UP
	sparks.spread = 35.0
	sparks.initial_velocity_min = 0.6
	sparks.initial_velocity_max = 1.6
	sparks.gravity = Vector3(0.0, 1.0, 0.0)  # 煙のように上へ流れる
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.5
	sparks.mesh = _spark_mesh(color)
	sparks.position.y = 0.15
	add_child(sparks)
	return sparks


func _spark_mesh(color: Color) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	mesh.radial_segments = 4
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material = material
	return mesh


func _make_sound(stream: AudioStream, unit_size: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.unit_size = unit_size
	sound.autoplay = true  # ツリーに加わったときに鳴り始める
	add_child(sound)
	return sound
