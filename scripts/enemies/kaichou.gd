class_name Kaichou
extends Node3D
## 岩場と雪山の空を旋回する、人の顔をした黒い大鳥「怪鳥」。ときどき悲鳴のような声を上げて、
## 登っている者めがけて急降下してくる。ぶつかるとケガをして、スタミナを奪われ、壁からはがされることもある。
## 急降下してくるところをヘッドライトで照らせば、目がくらんでそれていく。爆竹の音で逃げていく。

const MODEL := preload("res://assets/models/kaichou.glb")
const SIZE := 1.1
const CIRCLE_RADIUS := 14.0
const CIRCLE_HEIGHT := 12.0
const CIRCLE_SPEED := 0.45
const DIVE_INTERVAL := Vector2(40.0, 70.0)  # ほとんどは空を回って鳴くだけ
const DIVE_SPEED := 17.0
const HIT_DISTANCE := 1.0
const MAX_DIVES := 2     # これだけ急降下したら、飛び去る
const INJURY := 8.0
const STAMINA_LOSS := 15.0
const LIGHT_COS := 0.93

var player: Player
var state := "gone"
var aim_error := 2.2  # 狙いのずれ (m)

var _angle := 0.0
var _timer := 0.0
var _time := 0.0
var _velocity := Vector3.ZERO
var _dive_target := Vector3.ZERO
var _dives := 0
var _poser: BonePoser
var _screech: AudioStreamPlayer3D
var _wings: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"creatures")
	var skin := CreatureKit.skin(Color.WHITE, Color(0.35, 0.35, 0.5), 0.2, 0.3)
	var model := CreatureKit.load_model(MODEL, skin, {
		"Eye": CreatureKit.glow(Color(1.0, 0.12, 0.08), 6.0),
		"EyeBlack": CreatureKit.flat(Color(0.01, 0.0, 0.0), 0.2),
		"Claw": CreatureKit.flat(Color(0.08, 0.07, 0.06), 0.4),
		"Teeth": CreatureKit.flat(Color(0.7, 0.66, 0.55), 0.4),
	})
	model.scale = Vector3.ONE * SIZE
	add_child(model)
	_poser = BonePoser.new(model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)
	_screech = AudioStreamPlayer3D.new()
	_screech.stream = Sfx.screech()
	_screech.unit_size = 12.0
	_screech.max_distance = 120.0
	_screech.bus = &"Echo"
	add_child(_screech)
	_wings = AudioStreamPlayer3D.new()
	_wings.stream = Sfx.gust()
	_wings.pitch_scale = 2.5
	_wings.unit_size = 4.0
	add_child(_wings)
	visible = false


func is_active() -> bool:
	return state != "gone"


func arrive(owner_player: Player) -> void:
	player = owner_player
	state = "circling"
	visible = true
	_dives = 0
	_angle = randf() * TAU
	_timer = randf_range(DIVE_INTERVAL.x, DIVE_INTERVAL.y)
	global_position = _circle_point()
	_screech.play()


func leave() -> void:
	if state == "gone":
		return
	state = "leaving"
	_timer = 4.0


func scare(_from: Vector3) -> void:
	leave()


func dive() -> void:
	state = "diving"
	_timer = 3.0
	_dives += 1
	# 降下を始めたときの場所めがけて突っ込む（途中で動けばよけられる）。狙いも少しずれる
	var error := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.0, aim_error)
	_dive_target = player.global_position + Vector3.UP * 1.1 + error
	_screech.pitch_scale = randf_range(0.9, 1.1)
	_screech.play()


func _circle_point() -> Vector3:
	return player.global_position + Vector3(cos(_angle), 0.0, sin(_angle)) * CIRCLE_RADIUS \
		+ Vector3.UP * (CIRCLE_HEIGHT + sin(_time * 0.7) * 2.0)


func _physics_process(delta: float) -> void:
	if state == "gone" or player == null:
		return
	_time += delta
	_timer -= delta
	var previous := global_position
	match state:
		"circling":
			_angle += CIRCLE_SPEED * delta
			global_position = global_position.lerp(_circle_point(), 1.0 - exp(-2.0 * delta))
			if _timer <= 0.0 and not player.frozen and not player.bell_ringing and not Ward.blocks(get_tree(), player.global_position):
				dive()
		"diving":
			var to := _dive_target - global_position
			_velocity = _velocity.lerp(to.normalized() * DIVE_SPEED, 1.0 - exp(-4.0 * delta))
			global_position += _velocity * delta
			var to_player := player.global_position + Vector3.UP * 1.1 - global_position
			if _is_lit():
				_pull_up()  # まぶしくてそれていく
			elif to.length() < 0.8:
				_pull_up()  # 狙った場所を通り過ぎた
			elif to_player.length() < HIT_DISTANCE and not player.frozen:
				var push := _velocity.normalized() * 4.0
				if player.state == Player.State.CLIMB:
					push += player.wall_normal() * 1.0
				player.stamina = maxf(player.stamina - STAMINA_LOSS, 0.0)
				player.knock(push, INJURY)
				_pull_up()
			elif _timer <= 0.0:
				_pull_up()
		"rising":
			global_position += _velocity * delta
			_velocity = _velocity.lerp(Vector3.UP * 8.0, 1.0 - exp(-2.0 * delta))
			if _timer <= 0.0 and _dives >= MAX_DIVES:
				leave()
			elif _timer <= 0.0:
				state = "circling"
				_timer = randf_range(DIVE_INTERVAL.x, DIVE_INTERVAL.y)
				_angle = atan2(global_position.z - player.global_position.z, global_position.x - player.global_position.x)
		"leaving":
			global_position += (Vector3.UP * 10.0 + _velocity.normalized() * 6.0) * delta
			if _timer <= 0.0:
				state = "gone"
				visible = false
	var motion := global_position - previous
	if motion.length() > 0.01 and absf(motion.normalized().y) < 0.97:
		look_at(global_position + motion, Vector3.UP)


func _pull_up() -> void:
	state = "rising"
	_timer = 2.0
	_velocity = _velocity.normalized() * 10.0 + Vector3.UP * 6.0
	_wings.play()


## ヘッドライトで照らされているか
func _is_lit() -> bool:
	if not player.is_headlamp_on():
		return false
	var camera := player.get_camera()
	var to := global_position - camera.global_position
	return to.length() < 25.0 and (-camera.global_transform.basis.z).dot(to.normalized()) > LIGHT_COS


## 羽ばたき。急降下中は翼をたたむ
func _process(delta: float) -> void:
	if state == "gone":
		return
	var flap := sin(_time * 6.0) * 0.6
	var tuck := 0.0
	if state == "diving":
		flap = sin(_time * 20.0) * 0.08
		tuck = 0.9
	_poser.set_target("wing1.L", Vector3(0.0, -tuck * 0.5, flap))
	_poser.set_target("wing1.R", Vector3(0.0, tuck * 0.5, -flap))
	_poser.set_target("wing2.L", Vector3(0.0, -tuck, flap * 0.6))
	_poser.set_target("wing2.R", Vector3(0.0, tuck, -flap * 0.6))
	_poser.set_target("legs", Vector3(-1.0 if state == "diving" else 0.4, 0.0, 0.0))
	_poser.update(delta, 12.0)
	if player:
		_poser.aim("head", player.get_camera().global_position)
