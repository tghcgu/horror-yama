class_name WallHand
extends Node3D
## 登っている崖の岩肌から、ずるりと生えてくる青白い「壁の手」。足首をつかんで離さない。
## つかまれている間はほとんど登れず、ひどく疲れる。Space で飛びつけば振りほどける。
## ヘッドライトで照らしても引っ込む。塩で消せる。

const MODEL := preload("res://assets/models/wall_hand.glb")
const ARM_LENGTH := 0.85
const EMERGE_TIME := 0.35
const GRIP_LIMIT := 7.0
const LIGHT_TIME := 0.4
const CLIMB_SLOW := 0.2
const CLIMB_DRAIN := 2.2

var player: Player
var state := "hidden"

var _timer := 0.0
var _lit := 0.0
var _grow := 0.0
var _model: Node3D
var _poser: BonePoser
var _normal := Vector3.BACK
var _sound: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"spirits")
	var skin := CreatureKit.skin(Color.WHITE, Color(0.8, 0.85, 0.9), 0.15, 0.4)
	_model = CreatureKit.load_model(MODEL, skin, {"Claw": CreatureKit.flat(Color(0.05, 0.04, 0.04), 0.4)})
	add_child(_model)
	_poser = BonePoser.new(_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.crack()
	_sound.pitch_scale = 0.5
	_sound.unit_size = 4.0
	add_child(_sound)
	visible = false


func is_active() -> bool:
	return state != "hidden"


## 壁の point（外向き normal）から生えて、プレイヤーの足首をつかみにいく
func emerge(point: Vector3, normal: Vector3, owner_player: Player) -> void:
	player = owner_player
	global_position = point
	_normal = normal
	state = "emerging"
	_grow = 0.0
	_timer = GRIP_LIMIT
	_lit = 0.0
	visible = true
	_sound.play()


func retract() -> void:
	if state == "hidden" or state == "retracting":
		return
	state = "retracting"


func purify() -> void:
	retract()


func _physics_process(delta: float) -> void:
	if state == "hidden" or player == null:
		return
	var ankle := player.global_position + Vector3.UP * 0.15
	match state:
		"emerging":
			_grow = minf(_grow + delta / EMERGE_TIME, 1.0)
			if _grow >= 1.0:
				state = "gripping"
		"gripping":
			_timer -= delta
			if player.state != Player.State.CLIMB or player.is_lunging() or _timer <= 0.0 or player.frozen:
				retract()
			else:
				player.zone_climb_slow = minf(player.zone_climb_slow, CLIMB_SLOW)
				player.zone_climb_drain = maxf(player.zone_climb_drain, CLIMB_DRAIN)
				if _is_lit():
					_lit += delta
					if _lit >= LIGHT_TIME:
						retract()
		"retracting":
			_grow = maxf(_grow - delta / EMERGE_TIME, 0.0)
			if _grow <= 0.0:
				state = "hidden"
				visible = false
				return
	# 腕を足首の方へ伸ばす（遠ければ引き伸ばされる）
	var to := ankle - global_position
	var reach := to.length()
	if reach > 0.05:
		var up := Vector3.UP if absf(to.normalized().y) < 0.95 else _normal
		global_transform = Transform3D(Basis.looking_at(to, up), global_position)
	var stretch := clampf(reach / ARM_LENGTH, 0.3, 3.0) if state == "gripping" else 1.0
	_model.scale = Vector3(1.0, 1.0, _grow * stretch)


func _is_lit() -> bool:
	if not player.is_headlamp_on():
		return false
	var camera := player.get_camera()
	var to := global_position - camera.global_position
	return (-camera.global_transform.basis.z).dot(to.normalized()) > 0.9


## つかんでいる間は指を握りしめ、生えてくるときは指を広げてもがく
func _process(delta: float) -> void:
	if state == "hidden":
		return
	var curl := 1.2 if state == "gripping" else sin(Time.get_ticks_msec() * 0.02) * 0.3 + 0.2
	_poser.set_target("fingers", Vector3(curl, 0.0, 0.0))
	_poser.update(delta, 18.0)
