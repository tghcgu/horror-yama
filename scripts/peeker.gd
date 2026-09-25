class_name Peeker
extends Node3D
## 登っている崖の上から、青白い顔と長い指でこちらを覗く“のぞき”。
## ヘッドライトで照らし続けると引っ込む。覗かれたまま登りきると、突き落とされる。

const RISE_TIME := 1.8        # ゆっくり顔を出す時間
const STARE_TO_REPEL := 1.0   # 照らし続けて追い払うのに必要な秒数
const LIGHT_COS := 0.94       # 画面の中心からこの角度（約20°）以内なら照らしている
const LIGHT_RANGE := 28.0
const SHOVE_DISTANCE := 3.0
const LIFETIME := 20.0
const SIZE := 1.5          # 人より大きい
const FINGER_CURL := 0.7   # 指が崖の縁から外へ垂れ下がる角度 (rad)

var active := false
var player: Player

var _outward := Vector3.FORWARD
var _rise := 0.0
var _stare := 0.0
var _life := 0.0
var _retreating := false
var _time := 0.0
var _model: Node3D
var _head: Node3D
var _fingers: Array[Node3D] = []
var _hiss: AudioStreamPlayer3D
var _shriek: AudioStreamPlayer3D


func _ready() -> void:
	_build()
	_hiss = _make_player(Sfx.hiss(), 1.0)
	_shriek = _make_player(Sfx.wail(), 2.0)
	visible = false


## rim は崖の縁、outward は崖の外（プレイヤーのいる側）へ向かう水平方向
func appear(rim: Vector3, outward: Vector3, owner_player: Player) -> void:
	player = owner_player
	_outward = outward
	global_position = rim
	look_at(rim + outward, Vector3.UP)
	active = true
	visible = true
	_rise = 0.0
	_stare = 0.0
	_life = LIFETIME
	_retreating = false


func hide_now() -> void:
	active = false
	visible = false


func retreat() -> void:
	_retreating = true


func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	if _retreating:
		_rise -= delta * 2.5
		if _rise <= 0.0:
			hide_now()
			return
	else:
		_rise = minf(_rise + delta / RISE_TIME, 1.0)
	_model.position.y = lerpf(-0.8, 0.0, smoothstep(0.0, 1.0, _rise))
	# 顔はプレイヤーを追い、首をかしげる。指は崖の縁でぴくぴく動く
	var eye := player.get_camera().global_position
	var gaze := eye - _head.global_position
	if gaze.length() > 0.1:
		_head.look_at(eye, Vector3.UP if absf(gaze.normalized().y) < 0.98 else _outward)
		_head.rotate_object_local(Vector3.BACK, 0.45)
	for i in _fingers.size():
		_fingers[i].rotation.x = FINGER_CURL + sin(_time * 7.0 + i * 1.7) * 0.12


func _physics_process(delta: float) -> void:
	if not active or _retreating or player == null:
		return
	_life -= delta
	if _life <= 0.0:
		retreat()
		return

	# ヘッドライトで照らされているか
	var camera := player.get_camera()
	var to_face := _head.global_position - camera.global_position
	var lit := player.is_headlamp_on() and to_face.length() < LIGHT_RANGE \
		and (-camera.global_transform.basis.z).dot(to_face.normalized()) > LIGHT_COS \
		and _line_of_sight(camera.global_position, _head.global_position)
	if lit and _rise > 0.5:
		_stare += delta
		if _stare >= STARE_TO_REPEL:
			_hiss.play()
			retreat()
			return
	else:
		_stare = maxf(_stare - delta * 0.5, 0.0)

	# 覗かれたまま崖を登りきろうとすると、突き落とされる
	if player.state == Player.State.MANTLE and _rise > 0.6 \
			and player.global_position.distance_to(global_position) < SHOVE_DISTANCE:
		player.shove(_outward * 6.0 + Vector3.UP * 3.0)
		_shriek.pitch_scale = 2.2
		_shriek.play()
		retreat()


func _line_of_sight(from: Vector3, to: Vector3) -> bool:
	var direction := (to - from).normalized()
	var query := PhysicsRayQueryParameters3D.create(from, to - direction * 0.4, Player.TERRAIN_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## 崖の上に腹ばいになり、縁から顔と長い指を出している青白い人（仮のモデル）
func _build() -> void:
	var skin := CreatureKit.skin(Color(0.6, 0.58, 0.55), Color(0.8, 0.85, 0.9), 0.12, 0.3)
	var dark := CreatureKit.flat(Color(0.01, 0.01, 0.01), 1.0)
	var pupil := CreatureKit.glow(Color(0.9, 0.9, 0.85), 1.5)
	_model = Node3D.new()
	_model.scale = Vector3.ONE * SIZE
	add_child(_model)
	# 縁の奥へ伸びる、腹ばいの体
	CreatureKit.part(_model, CreatureKit.capsule(0.15, 1.3), skin, Vector3(0.0, 0.1, 0.85), Vector3(PI / 2.0, 0.0, 0.0))
	CreatureKit.part(_model, CreatureKit.capsule(0.05, 0.4), skin, Vector3(0.0, 0.16, 0.12), Vector3(PI / 2.0 - 0.4, 0.0, 0.0))

	_head = CreatureKit.joint(_model, Vector3(0.0, 0.25, -0.08))
	CreatureKit.part(_head, CreatureKit.capsule(0.12, 0.34), skin)
	for side in [-1.0, 1.0]:
		CreatureKit.part(_head, CreatureKit.sphere(0.032), dark, Vector3(0.048 * side, 0.03, -0.1))
		CreatureKit.part(_head, CreatureKit.sphere(0.008), pupil, Vector3(0.048 * side, 0.03, -0.128))
	var mouth := BoxMesh.new()
	mouth.size = Vector3(0.05, 0.03, 0.02)
	CreatureKit.part(_head, mouth, dark, Vector3(0.0, -0.075, -0.105))

	# 崖の縁をつかむ両手。長い指が縁から垂れ下がる
	for side in [-1.0, 1.0]:
		var hand := CreatureKit.joint(_model, Vector3(0.32 * side, 0.03, -0.02))
		CreatureKit.part(hand, CreatureKit.capsule(0.04, 0.16), skin, Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0))
		for f in 4:
			var finger := CreatureKit.joint(hand, Vector3((f - 1.5) * 0.028, 0.0, -0.08))
			CreatureKit.part(finger, CreatureKit.capsule(0.013, 0.34), skin, Vector3(0.0, -0.16, 0.0))
			finger.rotation.x = FINGER_CURL
			_fingers.append(finger)


func _make_player(stream: AudioStream, pitch: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.pitch_scale = pitch
	sound.unit_size = 6.0
	sound.bus = &"Echo"
	add_child(sound)
	return sound
