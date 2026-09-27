class_name PlayerSounds
extends Node
## プレイヤーの音：足音、着地、岩をつかむ音、疲れたときの息づかい

const STRIDE := 1.7  # 足音の間隔 (m)

var _player: Player
var _step_distance := 0.0
var _steps: AudioStreamPlayer
var _impact: AudioStreamPlayer
var _grip: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _pickup: AudioStreamPlayer
var _item: AudioStreamPlayer
var _bell: AudioStreamPlayer
var _swing: AudioStreamPlayer
var _chop: AudioStreamPlayer
var _ting: AudioStreamPlayer


func _ready() -> void:
	_player = get_parent() as Player
	if not _player.controlled:
		set_physics_process(false)  # 自分の耳元で鳴る音なので、仲間のダミーは鳴らさない
	_steps = _make_player(Sfx.footstep(), -8.0)
	_impact = _make_player(Sfx.thud(), 0.0)
	_grip = _make_player(Sfx.grip(), -6.0)
	_breath = _make_player(Sfx.breathing(), -60.0)
	_pickup = _make_player(Sfx.chime(), -10.0)
	_item = _make_player(Sfx.rustle(), -6.0)
	_swing = _make_player(Sfx.whoosh(), -4.0)
	_chop = _make_player(Sfx.chop(), -2.0)
	_ting = _make_player(Sfx.ting(), -8.0)
	_breath.play()


func set_bell(on: bool) -> void:
	if not _player.controlled:
		return
	if _bell == null:
		_bell = _make_player(Sfx.bell(), -8.0)
	if on:
		_bell.play()
	else:
		_bell.stop()


func play_grip() -> void:
	if not _player.controlled:
		return
	_grip.pitch_scale = randf_range(0.85, 1.2)
	_grip.play()


func play_pickup() -> void:
	if not _player.controlled:
		return
	_pickup.play()


func play_item() -> void:
	if not _player.controlled:
		return
	_item.pitch_scale = randf_range(0.9, 1.1)
	_item.play()


## ナタを振る・物を投げる「ヒュッ」。heavy なら低く重い音
func play_swing(heavy := false) -> void:
	if not _player.controlled:
		return
	_swing.pitch_scale = randf_range(0.7, 0.8) if heavy else randf_range(0.95, 1.2)
	_swing.play()


## 刃が獣や化け物に食いこむ「ザクッ」
func play_chop() -> void:
	if not _player.controlled:
		return
	_chop.pitch_scale = randf_range(0.85, 1.1)
	_chop.play()


## 刃が岩や木に当たる「カキン」
func play_ting() -> void:
	if not _player.controlled:
		return
	_ting.pitch_scale = randf_range(0.9, 1.15)
	_ting.play()


## strength: 0（軽い着地）〜 1（大ケガ）
func play_land(strength: float) -> void:
	if not _player.controlled:
		return
	_impact.volume_db = lerpf(-14.0, 2.0, strength)
	_impact.pitch_scale = lerpf(1.2, 0.8, strength)
	_impact.play()


func _physics_process(delta: float) -> void:
	if _player.frozen:
		_breath.volume_db = -60.0
		return
	var horizontal := Vector2(_player.velocity.x, _player.velocity.z).length()
	if _player.state == Player.State.WALK and _player.is_on_floor() and horizontal > 0.5:
		_step_distance += horizontal * delta
		if _step_distance >= STRIDE:
			_step_distance = 0.0
			_steps.pitch_scale = randf_range(0.8, 1.15)
			_steps.play()

	# 疲れるほど息が荒く、速くなる
	var fatigue := 1.0 if _player.exhausted else 1.0 - _player.stamina / Player.MAX_STAMINA
	var target_db := lerpf(-50.0, -20.0, smoothstep(0.55, 1.0, fatigue))  # かなり疲れたときだけ、控えめに聞こえる
	_breath.volume_db = lerpf(_breath.volume_db, target_db, 1.0 - exp(-3.0 * delta))
	_breath.pitch_scale = lerpf(1.0, 1.35, fatigue)


func _make_player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player
