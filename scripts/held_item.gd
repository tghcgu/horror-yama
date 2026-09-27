class_name HeldItem
extends Node3D
## 手に持っているアイテムを、画面の右下に見せる（カメラの子）。歩くと少しゆれ、使うと前へ突き出す。
## ナタは、右上から・左上からと交互に斜めに振り下ろし、重い一撃では頭の上から真下へ振り下ろす。
## Q をためている間は、後ろへ引きしぼる。
## 登っている間と、しまっている間（手ぶら）は隠す。

const REST := Vector3(0.3, -0.28, -0.52)

var player: Player

var _kind := -2
var _model: Node3D
var _time := 0.0
var _use := 0.0
var _swing_t := -1.0     # 振っている途中（0〜1）。振っていなければ負
var _swing_time := 0.3
var _swing_side := 1.0
var _swing_heavy := false


func _ready() -> void:
	position = REST


## 使った：前へ突き出す
func used() -> void:
	_use = 1.0


## ナタを振る。side = 1 なら右上から左下へ、-1 なら左上から右下へ。heavy なら頭の上から真下へ
func swing(side: float, heavy: bool, interval: float) -> void:
	_swing_t = 0.0
	_swing_time = clampf(interval * 0.8, 0.22, 0.5)
	_swing_side = side
	_swing_heavy = heavy


func _process(delta: float) -> void:
	if player == null:
		return
	var kind := player.holding_kind() if player.state != Player.State.CLIMB else -1
	if kind != _kind:
		_kind = kind
		if _model:
			_model.queue_free()
			_model = null
		if kind >= 0:
			_model = Items.build_model(kind)
			_model.rotation = Vector3(0.2, -0.5, 0.1)
			add_child(_model)
			for mesh: GeometryInstance3D in _model.find_children("*", "GeometryInstance3D", true, false):
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # ヘッドライトの光をさえぎらないように
				mesh.layers = PlayerHands.HANDS_LAYER  # 手と同じ層（目の前のヘッドライトで、まぶしく光らないように）
	_time += delta
	var walking := clampf(Vector2(player.velocity.x, player.velocity.z).length() / 4.0, 0.0, 1.0) if player.is_on_floor() else 0.0
	_use = move_toward(_use, 0.0, delta * 4.0)
	var charge := maxf(player.throw_charge, 0.0)
	position = REST + Vector3(sin(_time * 7.0) * 0.012, absf(cos(_time * 7.0)) * 0.018, 0.0) * walking \
		+ Vector3(-0.05, 0.04, -0.16) * _use + Vector3(0.06, 0.1, 0.22) * charge
	rotation = Vector3(-_use * 0.6 + charge * 0.7, 0.0, 0.0)
	if charge > 0.0:
		position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * 0.004 * charge  # ためきると、腕が震える
	if _swing_t >= 0.0:
		_swing_t += delta / _swing_time
		if _swing_t >= 1.0:
			_swing_t = -1.0
		else:
			_apply_swing(_swing_t)


## 振りの形：ふりかぶる（0〜0.3）→ 振り抜く（0.3〜0.6）→ 戻す（0.6〜1）
func _apply_swing(t: float) -> void:
	var s := _swing_side
	var raised: Array  # [位置のずれ, 回転]
	var through: Array
	if _swing_heavy:
		raised = [Vector3(-0.18, 0.26, 0.1), Vector3(1.1, 0.0, 0.2)]
		through = [Vector3(-0.2, -0.22, -0.3), Vector3(-1.5, 0.0, 0.1)]
	else:
		raised = [Vector3(0.1 * s - 0.08, 0.18, 0.06), Vector3(0.7, 0.35 * s, 0.9 * s)]
		through = [Vector3(-0.28 * s - 0.08, -0.14, -0.22), Vector3(-1.0, -0.4 * s, -0.7 * s)]
	var offset: Vector3
	var turn: Vector3
	if t < 0.3:
		var k := smoothstep(0.0, 1.0, t / 0.3)
		offset = (raised[0] as Vector3) * k
		turn = (raised[1] as Vector3) * k
	elif t < 0.6:
		var k := smoothstep(0.0, 1.0, (t - 0.3) / 0.3)
		offset = (raised[0] as Vector3).lerp(through[0], k)
		turn = (raised[1] as Vector3).lerp(through[1], k)
	else:
		var k := smoothstep(0.0, 1.0, (t - 0.6) / 0.4)
		offset = (through[0] as Vector3).lerp(Vector3.ZERO, k)
		turn = (through[1] as Vector3).lerp(Vector3.ZERO, k)
	position += offset
	rotation += turn
