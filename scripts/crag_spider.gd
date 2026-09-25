class_name CragSpider
extends Node3D
## 岩場の崖にはりつく大きなクモ。ふだんは壁をゆっくり這い回り、近くを登ると噛みついて壁から落とす。

const CRAWL_SPEED := 0.35
const WANDER_RADIUS := 3.0
const BITE_DISTANCE := 1.3
const BITE_INJURY := 15.0
const BITE_COOLDOWN := 3.0
const ALERT_DISTANCE := 7.0  # これより近づくと、こちらを向いて前脚を振り上げる

var player: Player

var _home := Vector3.ZERO
var _normal := Vector3.UP
var _goal := Vector3.ZERO
var _cooldown := 0.0
var _time := randf() * 10.0
var _alert := false
var _legs: Array[Node3D] = []   # 脚の付け根
var _leg_base: Array[Vector3] = []
var _hiss: AudioStreamPlayer3D


func _ready() -> void:
	_build()
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = Sfx.hiss()
	_hiss.unit_size = 4.0
	add_child(_hiss)


## ツリーに追加してから呼ぶ。pos は壁の表面、normal は壁の外向き
func setup(pos: Vector3, normal: Vector3, owner_player: Player) -> void:
	player = owner_player
	_home = pos
	_goal = pos
	_normal = normal
	global_position = pos
	_orient(Vector3.UP - normal * normal.y, 1.0)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_time += delta
	_cooldown -= delta
	var chest := player.global_position + Vector3.UP * 1.2
	var to_player := chest - global_position
	_alert = to_player.length() < ALERT_DISTANCE and not player.frozen
	if _alert:
		_orient(to_player, 1.0 - exp(-8.0 * delta))
	else:
		var offset := _goal - global_position
		if offset.length() < 0.1:
			_goal = _pick_goal()
		else:
			global_position += offset.normalized() * minf(CRAWL_SPEED * delta, offset.length())
			_orient(offset, 1.0 - exp(-4.0 * delta))

	if player.state == Player.State.CLIMB and not player.frozen and _cooldown <= 0.0 and to_player.length() < BITE_DISTANCE:
		_cooldown = BITE_COOLDOWN
		_hiss.pitch_scale = randf_range(0.9, 1.2)
		_hiss.play()
		player.bitten(BITE_INJURY)


## 脚をせわしなく動かす。警戒中は前脚を振り上げて震わせる
func _process(_delta: float) -> void:
	for i in _legs.size():
		var base := _leg_base[i]
		var phase := _time * 12.0 + (0.0 if i % 2 == 0 else PI) + i * 0.4
		var lift := maxf(sin(phase), 0.0) * 0.25
		var swing := sin(phase) * 0.18
		if _alert and i < 2:
			lift = 0.9 + sin(_time * 30.0) * 0.08  # 前脚を振り上げる
			swing = 0.0
		_legs[i].rotation = Vector3(0.0, base.y + swing, base.z + lift * signf(base.z))


func _pick_goal() -> Vector3:
	var right := _normal.cross(Vector3.UP)
	if right.length() < 0.1:
		return global_position
	right = right.normalized()
	var up := right.cross(-_normal).normalized()
	var candidate := _home + right * randf_range(-WANDER_RADIUS, WANDER_RADIUS) + up * randf_range(-WANDER_RADIUS, WANDER_RADIUS)
	var query := PhysicsRayQueryParameters3D.create(candidate + _normal * 1.0, candidate - _normal * 1.5, Player.TERRAIN_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.6:
		return global_position
	return hit.position


## 背中を壁の外へ、頭を direction の方へ向ける
func _orient(direction: Vector3, weight: float) -> void:
	var forward := direction - _normal * direction.dot(_normal)
	if forward.length() < 0.01:
		return
	var z := -forward.normalized()
	var x := _normal.cross(z).normalized()
	var target := Basis(x, _normal, z).orthonormalized()
	var current := global_transform.basis.orthonormalized()
	global_transform.basis = current.slerp(target, weight)


func _build() -> void:
	var skin := CreatureKit.skin(Color(0.07, 0.05, 0.04), Color(0.55, 0.2, 0.15), 0.25, 0.75)
	var eye := CreatureKit.glow(Color(1.0, 0.15, 0.1), 6.0)
	var fang := CreatureKit.flat(Color(0.15, 0.1, 0.08), 0.3)
	var body := Node3D.new()
	body.scale = Vector3.ONE * 1.3
	add_child(body)
	CreatureKit.part(body, CreatureKit.sphere(0.16), skin, Vector3(0.0, 0.15, -0.12), Vector3.ZERO, Vector3(1.0, 0.6, 1.1))
	CreatureKit.part(body, CreatureKit.sphere(0.24), skin, Vector3(0.0, 0.2, 0.28), Vector3.ZERO, Vector3(1.0, 0.75, 1.3))
	for i in 6:
		var x := (-0.05 + (i % 3) * 0.05)
		var y := 0.21 + (i / 3) * 0.035
		CreatureKit.part(body, CreatureKit.sphere(0.017), eye, Vector3(x, y, -0.27))
	for side in [-1.0, 1.0]:
		CreatureKit.part(body, CreatureKit.cone(0.015, 0.09), fang, Vector3(0.035 * side, 0.1, -0.29), Vector3(PI + 0.5, 0.0, 0.0))
	# 8本の脚：付け根で外・上へ持ち上げ、ひざで壁の方へ折り曲げる
	for i in 4:
		for side in [-1.0, 1.0]:
			var roll: float = side * 2.18
			var yaw: float = side * (-0.7 + i * 0.45)
			var joints := CreatureKit.limb(body, Vector3(0.1 * side, 0.15, -0.2 + i * 0.07), 0.025, [0.4, 0.5], skin, 0, fang)
			joints[1].rotation.z = -side * 1.6
			_legs.append(joints[0])
			_leg_base.append(Vector3(0.0, yaw, roll))
			joints[0].rotation = Vector3(0.0, yaw, roll)
