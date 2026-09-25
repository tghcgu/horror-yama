class_name PlayerHands
extends Node3D
## 一人称で見える両手。
## 壁では左右の手が交互に岩をつかみ直しながら登り、疲れると震える。
## それ以外はカメラに対して決まった姿勢（下ろす／前に伸ばす／崖の上に手をつく／落ちながらもがく）をとる。

signal gripped  # 手が岩をつかんだ瞬間

const REGRIP_DISTANCE := 0.42  # つかんでいる点が理想の位置からこれだけ離れたら、つかみ直す
const MAX_ARM_REACH := 1.3     # これより離れたら、もう一方の手を待たずにつかみ直す
const REACH_TIME := 0.13
const REACH_LIFT := 0.1        # つかみ直すとき、壁から浮かせる量
const FOLLOW_SPEED := 18.0
const MAX_TREMBLE := 0.018
const SLEEVE_COLOR := Color(0.13, 0.15, 0.2)
const GLOVE_COLOR := Color(0.1, 0.09, 0.08)
const HANDS_LAYER := 2  # ヘッドライトでは照らさず、専用の弱いライトで照らす（近すぎて白飛びするため）

# カメラから見た手の位置。x は右手の値（左手は符号を反転する）
const REST_POSE := Vector3(0.28, -0.55, -0.3)    # 下ろしている（画面の外）
const MANTLE_POSE := Vector3(0.24, -0.38, -0.42) # 崖の上に手をついて乗り上がる
const FLAIL_POSE := Vector3(0.32, 0.02, -0.38)   # 落ちながらもがく
const SHOULDER := Vector3(0.26, -0.45, 0.1)


class Hand:
	var side := 1.0  # -1 = 左手, 1 = 右手
	var root: Node3D
	var arm: Node3D
	var grip := Vector3.ZERO
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var progress := 1.0  # つかみ直しの進み具合（1 = 動いていない）
	var planted := false


var _player: Player
var _camera: Camera3D
var _hands: Array = []
var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_player = get_parent() as Player
	_camera = _player.get_node("Head/Camera3D") as Camera3D
	var glove := _material(GLOVE_COLOR)
	var sleeve := _material(SLEEVE_COLOR)
	for side in [-1.0, 1.0]:
		var hand := Hand.new()
		hand.side = side
		hand.root = _build_hand(glove, side)
		hand.arm = _build_arm(sleeve)
		_hands.append(hand)


func _process(delta: float) -> void:
	_time += delta
	if _player.state == Player.State.CLIMB:
		_update_climbing(delta)
	else:
		for hand: Hand in _hands:
			hand.planted = false
			hand.progress = 1.0
			_follow(hand, _pose_target(hand), delta)
	for hand: Hand in _hands:
		_orient(hand, delta)
		_place_arm(hand)


func _update_climbing(delta: float) -> void:
	var n := _player.wall_normal()
	var up := (Vector3.UP - n * n.y).normalized()
	var right := (-n).cross(up).normalized()
	var chest := _player.global_position + Vector3.UP * 1.25
	var input := _player.climb_input
	var lead := (up * input.y + right * input.x) * 0.3  # 進む方向へ手を先に出す
	var tremble := _player.fatigue() * MAX_TREMBLE

	for i in _hands.size():
		var hand: Hand = _hands[i]
		var other: Hand = _hands[1 - i]
		var ideal := _on_wall(chest + up * 0.5 + right * (0.22 * hand.side) + lead, n)
		var too_far := hand.grip.distance_to(chest) > MAX_ARM_REACH
		var may_move := other.progress >= 1.0 or not hand.planted or too_far  # 基本は片手ずつ
		var wants_move := not hand.planted or too_far or hand.grip.distance_to(ideal) > REGRIP_DISTANCE
		if hand.progress >= 1.0 and may_move and wants_move:
			hand.from = hand.root.global_position
			hand.to = ideal
			hand.progress = 0.0

		if hand.progress < 1.0:
			hand.progress = minf(hand.progress + delta / REACH_TIME, 1.0)
			var t := smoothstep(0.0, 1.0, hand.progress)
			hand.root.global_position = hand.from.lerp(hand.to, t) + n * sin(PI * hand.progress) * REACH_LIFT
			if hand.progress >= 1.0:
				hand.planted = true
				hand.grip = hand.to
				gripped.emit()
		else:
			var shake := Vector3(
				_noise.get_noise_2d(_time * 40.0, hand.side * 10.0),
				_noise.get_noise_2d(hand.side * 10.0, _time * 40.0),
				_noise.get_noise_2d(_time * 40.0, 50.0 + hand.side * 10.0)) * tremble
			hand.root.global_position = hand.grip + shake


func _pose_target(hand: Hand) -> Vector3:
	var pose := REST_POSE
	if _player.state == Player.State.MANTLE:
		pose = MANTLE_POSE
	elif not _player.is_on_floor() and _player.velocity.y < -7.0:
		pose = FLAIL_POSE + Vector3(0.0, sin(_time * 22.0 + hand.side) * 0.08, 0.0)
	return _camera_point(pose, hand.side)


func _follow(hand: Hand, target: Vector3, delta: float) -> void:
	var pos := hand.root.global_position
	if pos.distance_to(target) > 3.0:
		hand.root.global_position = target  # 復活などで瞬間移動したとき
	else:
		hand.root.global_position = pos.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))


## 壁では手のひらを岩に向け、それ以外ではカメラの向きに合わせる
func _orient(hand: Hand, delta: float) -> void:
	var target: Basis
	if _player.state == Player.State.CLIMB:
		var n := _player.wall_normal()
		var up := (Vector3.UP - n * n.y).normalized()
		target = Basis.looking_at(-n, up) * Basis(Vector3.BACK, -0.3 * hand.side)
	elif _player.state == Player.State.MANTLE:
		target = _camera.global_transform.basis * Basis(Vector3.RIGHT, -PI / 2.0)  # 手のひらを下に
	else:
		target = _camera.global_transform.basis
	var current := hand.root.global_transform.basis.orthonormalized()
	hand.root.global_transform.basis = current.slerp(target.orthonormalized(), 1.0 - exp(-20.0 * delta))


func _place_arm(hand: Hand) -> void:
	var shoulder := _camera_point(SHOULDER, hand.side)
	var wrist := hand.root.global_position - hand.root.global_transform.basis.y * 0.06
	var length := shoulder.distance_to(wrist)
	if length < 0.01:
		return
	var direction := (wrist - shoulder) / length
	var up_hint := Vector3.UP if absf(direction.y) < 0.95 else Vector3.FORWARD
	var arm_basis := Basis.looking_at(direction, up_hint)
	arm_basis.z *= length  # 肩から手首までの長さに伸ばす
	hand.arm.global_transform = Transform3D(arm_basis, (shoulder + wrist) * 0.5)


func _camera_point(pose: Vector3, side: float) -> Vector3:
	return _camera.global_transform * Vector3(pose.x * side, pose.y, pose.z)


func _on_wall(point: Vector3, normal: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + normal * 0.6, point - normal * 1.2, Player.TERRAIN_LAYER)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return point - normal * Player.WALL_GAP
	return (hit.position as Vector3) + normal * 0.03


func _build_hand(material: Material, side: float) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.top_level = true
	_add_box(root, Vector3(0.07, 0.075, 0.028), material, Vector3.ZERO, Vector3.ZERO)
	# 指は岩のほうへ少し曲げる
	_add_box(root, Vector3(0.066, 0.06, 0.024), material, Vector3(0.0, 0.064, -0.011), Vector3(-0.5, 0.0, 0.0))
	_add_box(root, Vector3(0.02, 0.045, 0.02), material, Vector3(-0.042 * side, 0.0, -0.012), Vector3(0.0, 0.0, 0.6 * side))
	return root


func _build_arm(material: Material) -> Node3D:
	var arm := Node3D.new()
	add_child(arm)
	arm.top_level = true
	var sleeve := CapsuleMesh.new()
	sleeve.radius = 0.03
	sleeve.height = 1.0
	sleeve.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = sleeve
	mesh.rotation.x = PI / 2.0  # カプセルの縦軸を、腕の向き（-Z）にそろえる
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.layers = HANDS_LAYER
	arm.add_child(mesh)
	return arm


func _add_box(parent: Node3D, box_size: Vector3, material: Material, pos: Vector3, rot: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = box_size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = pos
	mesh.rotation = rot
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.layers = HANDS_LAYER
	parent.add_child(mesh)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
