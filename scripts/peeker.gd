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
const SIZE := 1.3          # 人より大きい
const MODEL := preload("res://assets/models/peeker.glb")
const SIDES := ["L", "R"]

var active := false
var player: Player

var _outward := Vector3.FORWARD
var _rise := 0.0
var _stare := 0.0
var _life := 0.0
var _retreating := false
var _time := 0.0
var _model: Node3D
var _poser: BonePoser
var _hiss: AudioStreamPlayer3D
var _shriek: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"creatures")
	add_to_group(&"spirits")
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


func scare(_from: Vector3) -> void:
	if active:
		retreat()


func purify() -> void:
	if active:
		retreat()


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
	_model.position.y = lerpf(-0.9, 0.0, smoothstep(0.0, 1.0, _rise))
	# 指は崖の縁でぴくぴく動き、顔はプレイヤーを追って首をかしげる
	for i in SIDES.size():
		var twitch := sin(_time * 7.0 + i * 1.7) * 0.12 + sin(_time * 23.0 + i) * 0.03
		_poser.set_target("fingers." + SIDES[i], Vector3(twitch, 0.0, 0.0))
	_poser.update(delta, 20.0)
	_poser.aim("head", player.get_camera().global_position, 0.45)


## 顔の真ん中
func head_position() -> Vector3:
	var head := _poser.world_transform("head")
	return head.origin + head.basis.y.normalized() * 0.08


func _physics_process(delta: float) -> void:
	if not active or _retreating or player == null:
		return
	_life -= delta
	if _life <= 0.0:
		retreat()
		return

	# ヘッドライトで照らされているか
	var camera := player.get_camera()
	var face := head_position()
	var to_face := face - camera.global_position
	var lit := player.is_headlamp_on() and to_face.length() < LIGHT_RANGE \
		and (-camera.global_transform.basis.z).dot(to_face.normalized()) > LIGHT_COS \
		and _line_of_sight(camera.global_position, face)
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


## Blender で作ったモデル（tools/creatures/build_peeker.py）を読み込む
func _build() -> void:
	var skin := CreatureKit.skin(Color.WHITE, Color(0.8, 0.85, 0.9), 0.1, 0.3)
	_model = CreatureKit.load_model(MODEL, skin, {
		"EyeBlack": CreatureKit.flat(Color(0.0, 0.0, 0.0), 0.2),
		"Eye": CreatureKit.glow(Color(1.0, 1.0, 0.9), 3.0),
		"Teeth": CreatureKit.flat(Color(0.7, 0.66, 0.52), 0.4),
		"Claw": CreatureKit.flat(Color(0.3, 0.26, 0.22), 0.5),
	})
	_model.scale = Vector3.ONE * SIZE
	add_child(_model)
	_poser = BonePoser.new(_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)

func _make_player(stream: AudioStream, pitch: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.pitch_scale = pitch
	sound.unit_size = 6.0
	sound.bus = &"Echo"
	add_child(sound)
	return sound
