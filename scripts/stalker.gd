class_name Stalker
extends Node3D
## 夜になると、ふもとからプレイヤーが通った道をそのままなぞって登ってくる“何か”。
## 「ぴたっと止まる → 急にカクカク動く」をくり返しながら近づき、プレイヤーが休んでいる間に距離を詰める。
## お札の円の中には入れない。

signal caught

const RECORD_SPACING := 0.5   # 足跡を記録する間隔 (m)
const START_SPEED := 2.6      # 道のりを進む平均の速さ (m/s)。登り続ければ逃げられ、休みすぎると追いつかれる
const SPEED_GAIN := 0.01      # 夜が長引くほど速くなる (m/s ずつ毎秒)
const MAX_GAP := 55.0         # これより遠くには離れない（道のりでの距離）
const CATCH_DISTANCE := 1.4
const SHORTCUT_RADIUS := 1.5  # 同じ場所を2回通った道は、ぐるっと回らずに近道する
const SHORTCUT_MIN_SAVING := 6.0  # 道のりがこれ以上短くなるときだけ近道する
const SHORTCUT_LOOKAHEAD := 300
const DANGER_NEAR := 5.0
const DANGER_FAR := 30.0

# 動き方
const DASH_TIME := Vector2(0.3, 0.9)    # 動いている時間の範囲（秒）
const FREEZE_TIME := Vector2(0.15, 0.6) # 止まっている時間の範囲（秒）
const DASH_BOOST := 1.7                 # 止まっている分を取り返すため、動くときは平均より速い
const POSE_INTERVAL := Vector2(0.1, 0.22)
const POSE_SNAP := 22.0                 # 手足が次の姿勢へ切り替わる速さ（大きいほどカクカク）

var target: Player
var active := false
var danger := 0.0  # 0（遠い）〜 1（すぐそば）。画面と音の演出に使う

var _trail := PackedVector3Array()
var _trail_length := PackedFloat32Array()  # 道の始点からの累積距離
var _index := 0
var _progress := 0.0
var _speed := START_SPEED
var _facing := Vector3.FORWARD
var _dashing := false
var _phase_time := 0.0
var _pose_time := 0.0
var _heartbeat_wait := 0.0

var _skin: ShaderMaterial
var _mouth_glow: StandardMaterial3D
var _body: Node3D
var _head: Node3D
var _jaw: Node3D
var _head_roll := 0.0
var _arms: Array[Node3D] = []  # [左肩, 左ひじ, 左手首, 右肩, 右ひじ, 右手首]
var _legs: Array[Node3D] = []  # [左股, 左ひざ, 左足首, 右股, 右ひざ, 右足首]
var _pose := {}                # 関節 → 目標の角度

var _scratch_player: AudioStreamPlayer3D
var _crack_player: AudioStreamPlayer3D
var _growl_player: AudioStreamPlayer3D
var _heartbeat_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer


func _ready() -> void:
	_build_body()
	_scratch_player = _make_3d_player(Sfx.scratches(), 8.0, 80.0, &"Echo")
	_crack_player = _make_3d_player(Sfx.crack(), 6.0, 50.0, &"Echo")
	_growl_player = _make_3d_player(Sfx.growl(), 2.5, 20.0, &"Master")
	_heartbeat_player = AudioStreamPlayer.new()
	_heartbeat_player.stream = Sfx.heartbeat()
	add_child(_heartbeat_player)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.stream = Sfx.wail()
	_voice_player.bus = &"Echo"
	add_child(_voice_player)
	reset()


func reset() -> void:
	stop()
	visible = false
	_trail.clear()
	_trail_length.clear()
	_index = 0
	_progress = 0.0


func activate() -> void:
	active = true
	visible = true
	_speed = START_SPEED
	_dashing = false
	_phase_time = 0.0
	_mouth_glow.emission_energy_multiplier = 1.0
	_progress = maxf(_end_length() - MAX_GAP, 0.0)
	_sync_index()
	global_position = _position_on_trail()
	_voice_player.pitch_scale = 1.0
	_voice_player.volume_db = -4.0
	_voice_player.play()
	_scratch_player.play()
	_growl_player.play()


func stop() -> void:
	active = false
	danger = 0.0
	_skin.set_shader_parameter("twitch", 0.0)
	_scratch_player.stop()
	_growl_player.stop()


func head_position() -> Vector3:
	return _head.global_position


## 捕まえた瞬間：カメラの目の前に飛び込んで、腕を伸ばし、あごを開いて叫ぶ
func lunge_at(eye: Vector3, direction: Vector3) -> void:
	visible = true
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() > 0.01:
		_facing = -flat.normalized()
		_body.look_at(_body.global_position + _facing, Vector3.UP)
	global_position += eye + direction * 0.6 - _head.global_position
	_look_at_point(_head, eye)
	_mouth_glow.emission_energy_multiplier = 5.0
	for s in [0, 3]:
		_arms[s].rotation = Vector3(1.3, 0.0, 0.0)
		_arms[s + 1].rotation = Vector3(0.3, 0.0, 0.0)
		_arms[s + 2].rotation = Vector3(-0.2, 0.0, 0.0)
	_jaw.rotation.x = -0.9
	_voice_player.pitch_scale = 1.7
	_voice_player.volume_db = 2.0
	_voice_player.play()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_record_trail()
	if not active:
		return

	_phase_time -= delta
	if _phase_time <= 0.0:
		_switch_phase()
	_speed += SPEED_GAIN * delta

	var previous_progress := _progress
	var previous_index := _index
	var step := _speed * DASH_BOOST * delta if _dashing else 0.0
	_progress = minf(maxf(_progress + step, _end_length() - MAX_GAP), _end_length())
	_sync_index()
	_take_shortcut()
	var next := _position_on_trail()
	if Ward.blocks(get_tree(), next):
		# お札の円の手前で立ち止まり、じっとこちらを見る
		_progress = previous_progress
		_index = previous_index
		next = global_position
		_dashing = false
		_phase_time = 0.4

	var previous := global_position
	global_position = next
	_update_facing(global_position - previous)

	var distance := global_position.distance_to(target.global_position)
	danger = 1.0 - clampf((distance - DANGER_NEAR) / (DANGER_FAR - DANGER_NEAR), 0.0, 1.0)
	if distance < CATCH_DISTANCE and not target.frozen and not Ward.blocks(get_tree(), target.global_position):
		stop()
		caught.emit()


func _process(delta: float) -> void:
	if not active:
		return
	if _dashing:
		_pose_time -= delta
		if _pose_time <= 0.0:
			_pose_time = randf_range(POSE_INTERVAL.x, POSE_INTERVAL.y)
			_new_pose()
	var weight := 1.0 - exp(-POSE_SNAP * delta)
	for joint: Node3D in _pose:
		joint.rotation = joint.rotation.lerp(_pose[joint], weight)

	_heartbeat_wait -= delta
	if danger > 0.05 and _heartbeat_wait <= 0.0:
		_heartbeat_player.volume_db = lerpf(-18.0, 0.0, danger)
		_heartbeat_player.play()
		_heartbeat_wait = lerpf(1.1, 0.42, danger)


## 動く ⇔ 止まる を切り替える。近くにいるほど止まっている時間が短い
func _switch_phase() -> void:
	_dashing = not _dashing
	if _dashing:
		_phase_time = randf_range(DASH_TIME.x, DASH_TIME.y)
		_pose_time = 0.0
	else:
		_phase_time = randf_range(FREEZE_TIME.x, FREEZE_TIME.y) * (1.0 - danger * 0.6)
	_skin.set_shader_parameter("twitch", 1.0 if _dashing else 0.0)


## 手足・首・あごを、でたらめな角度へ一気に曲げる
func _new_pose() -> void:
	for s in [0, 3]:
		_pose[_arms[s]] = Vector3(randf_range(1.5, 2.9), 0.0, randf_range(-0.5, 0.5))
		_pose[_arms[s + 1]] = Vector3(randf_range(0.2, 1.4), 0.0, 0.0)
		_pose[_arms[s + 2]] = Vector3(randf_range(-0.4, 0.6), 0.0, 0.0)
		_pose[_legs[s]] = Vector3(randf_range(-1.0, 0.3), 0.0, randf_range(-0.25, 0.25))
		_pose[_legs[s + 1]] = Vector3(randf_range(-1.6, -0.2), 0.0, 0.0)
		_pose[_legs[s + 2]] = Vector3(randf_range(0.2, 0.9), 0.0, 0.0)
	_pose[_jaw] = Vector3(randf_range(-0.3, 0.0), 0.0, 0.0)
	_head_roll = randf_range(-0.7, 0.7)
	if _crack_player and randf() < 0.5:
		_crack_player.pitch_scale = randf_range(0.7, 1.4)
		_crack_player.play()


func _record_trail() -> void:
	if target.frozen:
		return
	var pos := target.global_position
	if _trail.is_empty():
		_trail.append(pos)
		_trail_length.append(0.0)
		return
	var step := pos.distance_to(_trail[_trail.size() - 1])
	if step >= RECORD_SPACING:
		_trail.append(pos)
		_trail_length.append(_end_length() + step)


func _end_length() -> float:
	return 0.0 if _trail_length.is_empty() else _trail_length[_trail_length.size() - 1]


func _sync_index() -> void:
	while _index < _trail.size() - 1 and _trail_length[_index + 1] <= _progress:
		_index += 1


func _position_on_trail() -> Vector3:
	if _trail.is_empty():
		return global_position
	if _index >= _trail.size() - 1:
		return _trail[_trail.size() - 1]
	var a := _trail_length[_index]
	var b := _trail_length[_index + 1]
	var t := clampf((_progress - a) / (b - a), 0.0, 1.0) if b > a else 0.0
	return _trail[_index].lerp(_trail[_index + 1], t)


func _take_shortcut() -> void:
	var here := _position_on_trail()
	var last := mini(_index + SHORTCUT_LOOKAHEAD, _trail.size() - 1)
	for j in range(last, _index + 1, -1):
		if _trail_length[j] - _progress < SHORTCUT_MIN_SAVING:
			return
		if _trail[j].distance_to(here) < SHORTCUT_RADIUS:
			_index = j
			_progress = _trail_length[j]
			return


## 体は進む方向（近くまで来たらこちら）へ向け、首だけはいつもプレイヤーを見上げる
func _update_facing(motion: Vector3) -> void:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var wanted := Vector3.ZERO
	if to_target.length() < 8.0:
		wanted = to_target
	elif Vector2(motion.x, motion.z).length() > 0.002:
		wanted = Vector3(motion.x, 0.0, motion.z)
	if wanted.length() > 0.01:
		var blended := _facing.lerp(wanted.normalized(), 0.1)
		if blended.length() > 0.01:
			_facing = blended.normalized()
	_body.look_at(_body.global_position + _facing, Vector3.UP)
	_look_at_point(_head, target.global_position + Vector3.UP * 1.6)
	_head.rotate_object_local(Vector3.BACK, _head_roll)


func _look_at_point(node: Node3D, point: Vector3) -> void:
	var gaze := point - node.global_position
	if gaze.length() < 0.1:
		return
	var up := Vector3.UP if absf(gaze.normalized().y) < 0.98 else Vector3.BACK
	node.look_at(node.global_position + gaze, up)


## やせこけて背骨の曲がった、手足の長い人影（仮のモデル）
func _build_body() -> void:
	_skin = CreatureKit.skin(Color(0.025, 0.024, 0.024), Color(0.35, 0.4, 0.48), 0.2, 0.6)
	_mouth_glow = CreatureKit.glow(Color(0.3, 0.02, 0.02), 1.0)
	var claw := CreatureKit.flat(Color(0.1, 0.09, 0.08), 0.4)
	var tooth := CreatureKit.flat(Color(0.72, 0.68, 0.6), 0.5)
	var eye := CreatureKit.glow(Color(1.0, 0.92, 0.75), 12.0)
	var socket := CreatureKit.flat(Color.BLACK, 1.0)

	_body = Node3D.new()
	add_child(_body)
	var pelvis := CreatureKit.joint(_body, Vector3(0.0, 1.15, 0.0))
	CreatureKit.part(pelvis, CreatureKit.capsule(0.11, 0.34), _skin, Vector3.ZERO, Vector3(0.0, 0.0, PI / 2.0))

	# 前かがみの背骨。あばら骨と、背中に浮き出た背骨の節
	var spine := CreatureKit.joint(pelvis, Vector3(0.0, 0.05, 0.0))
	spine.rotation.x = -0.8
	CreatureKit.part(spine, CreatureKit.capsule(0.14, 0.75), _skin, Vector3(0.0, 0.42, 0.0))
	for i in 5:
		CreatureKit.part(spine, CreatureKit.capsule(0.013, 0.3 - i * 0.02), _skin,
			Vector3(0.0, 0.22 + i * 0.1, -0.12), Vector3(0.0, 0.0, PI / 2.0))
	for i in 6:
		CreatureKit.part(spine, CreatureKit.sphere(0.035), _skin, Vector3(0.0, 0.12 + i * 0.12, 0.12))

	var neck := CreatureKit.joint(spine, Vector3(0.0, 0.82, -0.03))
	CreatureKit.part(neck, CreatureKit.capsule(0.045, 0.34), _skin, Vector3(0.0, 0.15, 0.0))

	# 頭：後ろに長い頭蓋、落ちくぼんだ目、開くあご
	_head = CreatureKit.joint(neck, Vector3(0.0, 0.33, 0.0))
	CreatureKit.part(_head, CreatureKit.capsule(0.12, 0.4), _skin, Vector3(0.0, 0.06, 0.04), Vector3(1.27, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		CreatureKit.part(_head, CreatureKit.sphere(0.032), socket, Vector3(0.05 * side, 0.07, -0.128))
		CreatureKit.part(_head, CreatureKit.sphere(0.02), eye, Vector3(0.05 * side, 0.07, -0.152))
	CreatureKit.part(_head, CreatureKit.sphere(0.05), _mouth_glow, Vector3(0.0, -0.07, -0.09))
	for i in 6:
		var x := -0.045 + i * 0.018
		CreatureKit.part(_head, CreatureKit.cone(0.008, 0.045), tooth, Vector3(x, -0.05, -0.13), Vector3(PI, 0.0, 0.0))
	_jaw = CreatureKit.joint(_head, Vector3(0.0, -0.06, 0.0))
	CreatureKit.part(_jaw, CreatureKit.capsule(0.055, 0.2), _skin, Vector3(0.0, -0.03, -0.05), Vector3(PI / 2.0, 0.0, 0.0))
	for i in 6:
		var x := -0.045 + i * 0.018
		CreatureKit.part(_jaw, CreatureKit.cone(0.008, 0.045), tooth, Vector3(x, 0.035, -0.12))

	for side in [-1.0, 1.0]:
		_arms.append_array(CreatureKit.limb(spine, Vector3(0.24 * side, 0.74, 0.0), 0.045, [0.7, 0.65, 0.16], _skin, 4, claw))
	for side in [-1.0, 1.0]:
		_legs.append_array(CreatureKit.limb(pelvis, Vector3(0.12 * side, 0.0, 0.0), 0.055, [0.55, 0.55, 0.12], _skin, 3, claw))
	_new_pose()
	for joint: Node3D in _pose:
		joint.rotation = _pose[joint]


func _make_3d_player(stream: AudioStream, unit_size: float, max_distance: float, bus_name: StringName) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.unit_size = unit_size
	player.max_distance = max_distance
	player.bus = bus_name
	player.position.y = 1.5
	add_child(player)
	return player
