class_name Tenaga
extends Node3D
## 樹海の杉の枝にうずくまる「手長」。体の何倍もある腕を地面近くまで垂らし、その下を通った者をつかんで吊り上げる。
## Space を連打してもがけば振りほどけるが、高い所で放されると落ちてケガをする。もがけないと、崖の方へ放り投げられる。

const MODEL := preload("res://assets/models/tenaga.glb")
const REACH := 1.7          # 手の真下からこれだけ以内を通るとつかまれる
const LIFT_TIME := 1.4
const HOLD_LIMIT := 4.5     # これだけもがけないと放り投げられる
const STRUGGLE_NEEDED := 8.0
const GRAB_INJURY := 10.0
const COOLDOWN := 25.0
const SIDES := ["L", "R"]

var player: Player
var terrain: Terrain
var state := "waiting"

var _timer := 0.0
var _time := randf() * 10.0
var _model: Node3D
var _poser: BonePoser
var _hiss: AudioStreamPlayer3D
var _lift := 0.0


## tree は杉の根元、tree_scale は杉の大きさ
func setup(tree: Vector3, tree_scale: float, owner_player: Player, mountain: Terrain) -> void:
	add_to_group(&"creatures")
	player = owner_player
	terrain = mountain
	var perch := 5.8 * tree_scale
	global_position = tree + Vector3.UP * perch
	rotation.y = randf() * TAU
	var skin := CreatureKit.skin(Color.WHITE, Color(0.3, 0.3, 0.25), 0.1, 0.2)
	_model = CreatureKit.load_model(MODEL, skin, {
		"Hair": CreatureKit.flat(Color(0.02, 0.02, 0.02), 0.3),
		"Eye": CreatureKit.glow(Color(1.0, 0.85, 0.5), 5.0),
		"Claw": CreatureKit.flat(Color(0.1, 0.08, 0.06), 0.4),
	})
	_model.scale = Vector3.ONE * maxf((perch - 1.6) / 2.66, 0.8)  # 指先が頭の高さまで届く大きさ
	_model.position.z = 0.35  # 幹の少し外側
	add_child(_model)
	_poser = BonePoser.new(_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = Sfx.hiss()
	_hiss.pitch_scale = 0.6
	_hiss.unit_size = 8.0
	add_child(_hiss)


## 両手のあいだ（つかむ場所）
func hands_position() -> Vector3:
	return (_poser.world_transform("hand.L").origin + _poser.world_transform("hand.R").origin) * 0.5


func scare(_from: Vector3) -> void:
	if state == "holding" or state == "lifting":
		_release(Vector3.ZERO)
	state = "retreating"
	_timer = COOLDOWN * 1.5
	_hiss.play()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_timer -= delta
	match state:
		"waiting":
			if player.frozen or player.held_by or player.state != Player.State.WALK:
				return
			var hands := hands_position()
			var offset := player.global_position - hands
			if Vector2(offset.x, offset.z).length() < REACH and offset.y < 1.0 and offset.y > -3.5:
				grab()
		"lifting", "holding":
			if player.held_by != self:
				state = "retreating"
				_timer = COOLDOWN
				return
			if state == "lifting":
				_lift = minf(_lift + delta / LIFT_TIME, 1.0)
				if _lift >= 1.0:
					state = "holding"
					_timer = HOLD_LIMIT
			player.global_position = hands_position() - Vector3.UP * 1.1
			if player.struggle >= STRUGGLE_NEEDED:
				_release(Vector3.ZERO)  # 振りほどいた。その高さから落ちる
				state = "retreating"
				_timer = COOLDOWN
			elif state == "holding" and _timer <= 0.0:
				# 振りほどけなかった：崖の方（下り側）へ放り投げる
				var away := Vector3(player.global_position.x, 0.0, player.global_position.z) - Vector3(global_position.x, 0.0, global_position.z)
				if away.length() < 0.1:
					away = Vector3.FORWARD
				_release(away.normalized() * 9.0 + Vector3.UP * 5.0)
				state = "retreating"
				_timer = COOLDOWN
		"retreating":
			_lift = maxf(_lift - delta * 0.6, 0.0)
			if _timer <= 0.0:
				state = "waiting"


func grab() -> void:
	state = "lifting"
	_lift = 0.0
	player.bitten(GRAB_INJURY)
	player.set_held(self)
	_hiss.play()


func _release(impulse: Vector3) -> void:
	player.set_held(null)
	if impulse != Vector3.ZERO:
		player.shove(impulse)
	else:
		player.velocity = Vector3.ZERO


## 腕はだらりと垂れてゆらゆら揺れ、長い指がゆっくり開いたり閉じたりする。つかむと肘を曲げて吊り上げる
func _process(delta: float) -> void:
	_time += delta
	for i in SIDES.size():
		var side: String = SIDES[i]
		var sway := sin(_time * 0.7 + i * 1.3) * 0.06
		_poser.set_target("upperarm." + side, Vector3(sway + _lift * 0.6, 0.0, 0.0))
		_poser.set_target("forearm." + side, Vector3(_lift * 1.9, 0.0, 0.0))
		var curl := 0.9 if player and player.held_by == self else (sin(_time * 1.1 + i) * 0.5 + 0.5) * 0.4
		_poser.set_target("fingers." + side, Vector3(curl, 0.0, 0.0))
	_poser.update(delta, 6.0)
	if player:
		_poser.aim("head", player.get_camera().global_position, sin(_time * 0.5) * 0.3)
