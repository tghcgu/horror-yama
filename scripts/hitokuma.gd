class_name Hitokuma
extends Node3D
## 人熊（ひとくま）：後ろ足で立ち上がったまま歩く、背丈 3 m の巨大なツキノワグマ。山の獣の中でいちばん強く、めったに出ない。
## 気づくと立ち上がって吠え、のしのしと寄ってきて、近くでは走って詰め寄り、鎌のような爪で薙ぎ払う（大ケガをして吹き飛ばされる）。
## とても打たれ強く、弱ると怒って速くなる。熊よけの鈴を鳴らしていると、近くまで来ないと気づかない。
## 爆竹の音には驚いて、しばらく離れていく。火のついたたき火やお札の円には入ってこない。
## 倒すと E ではぎとれる：肉と毛皮がたくさんと、山の秘薬「熊の胆」。
## 見た目は Blender で作ったモデル（tools/creatures/build_hitokuma.py）。

const MODEL := preload("res://assets/models/hitokuma.glb")
const HEALTH := 450.0
const NOTICE := 30.0
const NOTICE_WITH_BELL := 10.0
const WALK := 1.1
const STALK := 2.3
const CHARGE := 6.5
const REACH := 2.9          # 爪が届く距離（体の中心から）
const SWIPE_INJURY := 34.0
const SWIPE_KNOCK := 12.0
const SWIPE_WINDUP := 0.5
const SWIPE_COOLDOWN := 1.3
const SLOPE := 1.4
const LOOT := [[Items.Kind.RAW_MEAT, 6], [Items.Kind.PELT, 3], [Items.Kind.KUMANOI, 1]]

var player: Player
var terrain: Terrain
var state := "wander"
var health := HEALTH
var dead := false
var gone := false

var _model: Node3D
var _poser: BonePoser
var _voice: AudioStreamPlayer3D
var _steps: AudioStreamPlayer3D
var _timer := 0.0
var _time := randf() * 10.0
var _phase := 0.0
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _swing := 0.0        # 薙ぎ払いの進み具合（0〜1。振っていなければ負）
var _swing_side := 1.0
var _hit_done := false
var _cooldown := 0.0
var _flinch := 0.0
var _detour := 0.0


func setup(pos: Vector3, owner_player: Player, mountain: Terrain) -> void:
	player = owner_player
	terrain = mountain
	add_to_group(&"creatures")
	add_to_group(&"huntable")
	var skin := CreatureKit.skin(Color.WHITE, Color(1.0, 1.0, 1.0), 0.05, 0.03)
	_model = CreatureKit.load_model(MODEL, skin, {
		"Eye": CreatureKit.glow(Color(1.0, 0.45, 0.1), 6.0),
		"Teeth": CreatureKit.flat(Color(0.75, 0.68, 0.5), 0.5),
		"Claw": CreatureKit.flat(Color(0.06, 0.05, 0.045), 0.3),
		"Gum": CreatureKit.flat(Color(0.3, 0.05, 0.06), 0.6),
	})
	add_child(_model)
	_poser = BonePoser.new(_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)
	_voice = AudioStreamPlayer3D.new()
	_voice.stream = Sfx.grunt()  # 一度だけ吠える（くり返さない）
	_voice.pitch_scale = 0.5
	_voice.unit_size = 10.0
	_voice.max_distance = 70.0
	_voice.volume_db = 0.0
	add_child(_voice)
	_steps = AudioStreamPlayer3D.new()
	_steps.stream = Sfx.thud()
	_steps.unit_size = 6.0
	_steps.max_distance = 40.0
	add_child(_steps)
	global_position = pos
	_home = pos
	rotation.y = randf() * TAU
	_pick_wander()


func is_hostile() -> bool:
	return true


func hit_center() -> Vector3:
	return global_position + Vector3.UP * 1.8


func hit_radius() -> float:
	return 0.95


## ナタや投げた物で傷ついた：ひるんで吠え、向かってくる。弱ると怒って速くなる
func hit(damage: float, _attacker: Node3D) -> void:
	if dead:
		return
	health -= damage
	_flinch = 0.25
	if health <= 0.0:
		_die()
		return
	if state in ["wander", "graze"]:
		state = "stalk"
	if randf() < 0.4:
		_roar()


## 爆竹の音：驚いて、しばらく離れていく
func scare(_from: Vector3) -> void:
	if dead:
		return
	state = "retreat"
	_timer = 8.0
	_swing = -1.0
	_roar()


func _roar() -> void:
	_voice.pitch_scale = randf_range(0.42, 0.55)
	_voice.play()


func _die() -> void:
	dead = true
	state = "dead"
	remove_from_group(&"creatures")
	remove_from_group(&"huntable")
	add_to_group(&"interactables")
	_voice.pitch_scale = 0.4
	_voice.play()  # 最後のうなり声（一度だけ）
	var tween := create_tween()
	tween.tween_property(_model, "rotation:x", PI * 0.5, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_model, "position:y", 0.4, 0.9)
	player.message.emit("人熊を倒した")


func interact_hint(_by: Player) -> String:
	return "E：はぎとる" if dead and not gone else ""


## 倒した人熊から、肉と毛皮をたくさんと、熊の胆をとる（持ちきれない分は、足もとに落ちる）
func interact(by: Player) -> void:
	if not dead or gone:
		return
	var taken: Array[String] = []
	for entry: Array in LOOT:
		for n in int(entry[1]):
			if not by.pick_up(entry[0]):
				by.item_thrown.emit(entry[0], global_position + Vector3.UP * 0.8, Vector3(randf_range(-1.5, 1.5), 2.5, randf_range(-1.5, 1.5)), false)
		taken.append("%s×%d" % [Items.NAMES[entry[0]], entry[1]])
	by.message.emit("はぎとった：" + "、".join(taken))
	remove_from_group(&"interactables")
	gone = true


func _pick_wander() -> void:
	var angle := randf() * TAU
	_target = _home + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(4.0, 14.0)
	state = "wander"
	_timer = randf_range(8.0, 14.0)


func _physics_process(delta: float) -> void:
	if player == null or dead:
		return
	_time += delta
	_timer -= delta
	_cooldown -= delta
	_flinch -= delta
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var safe := Ward.blocks(get_tree(), player.global_position)  # 守りの円の中の相手には、襲いかからない
	var raging := health < HEALTH * 0.3
	match state:
		"wander", "graze":
			var notice := NOTICE_WITH_BELL if player.bell_ringing else NOTICE
			if distance < notice and not player.frozen and not safe:
				state = "roar"
				_timer = 1.8
				_roar()
			elif state == "wander":
				_walk_toward(_target, WALK, delta)
				if global_position.distance_to(_target) < 1.0 or _timer <= 0.0:
					state = "graze"
					_timer = randf_range(3.0, 6.0)
			elif _timer <= 0.0:
				_pick_wander()
		"roar":
			_face(to_player, delta)
			if _timer <= 0.0:
				state = "stalk"
		"stalk":
			if safe or player.frozen:
				state = "retreat"
				_timer = 5.0
			elif distance < REACH and _cooldown <= 0.0:
				_start_swipe(to_player)
			elif distance < 10.0:
				_walk_toward(player.global_position, CHARGE * (1.25 if raging else 1.0), delta)  # 近くでは、走って詰め寄る
			else:
				_walk_toward(player.global_position, STALK * (1.4 if raging else 1.0), delta)
			if distance > NOTICE * 2.0:
				_pick_wander()
		"swipe":
			_face(to_player, delta)
			_swing += delta / (SWIPE_WINDUP + 0.35)
			var strike_at := SWIPE_WINDUP / (SWIPE_WINDUP + 0.35)
			if not _hit_done and _swing >= strike_at:
				_hit_done = true
				if distance < REACH + 0.4 and absf(player.global_position.y - global_position.y) < 2.5 and not player.frozen:
					var away := to_player.normalized() if distance > 0.1 else -global_transform.basis.z
					player.knock(away * SWIPE_KNOCK + Vector3.UP * 4.0, SWIPE_INJURY)
			if _swing >= 1.0:
				_swing = -1.0
				state = "stalk"
				_cooldown = SWIPE_COOLDOWN * (0.7 if raging else 1.0)
		"retreat":
			_walk_toward(global_position - to_player.normalized() * 6.0, STALK, delta)
			if _timer <= 0.0:
				_home = global_position
				_pick_wander()


func _start_swipe(to_player: Vector3) -> void:
	state = "swipe"
	_swing = 0.0
	_hit_done = false
	_swing_side = -_swing_side
	_face(to_player, 1.0)
	_roar()


## 地面の上を歩く。崖や大岩、守りの円にはばまれたら、向きを変えて回りこむ
func _walk_toward(goal: Vector3, speed: float, delta: float) -> void:
	if _flinch > 0.0:
		return
	var flat := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	if flat.length() < 0.05:
		return
	var length := minf(speed * delta, flat.length())
	for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
		var step := flat.normalized().rotated(Vector3.UP, turn + _detour) * length
		var next := global_position + step
		next.y = terrain.height_at(next.x, next.z)
		if absf(next.y - global_position.y) > SLOPE * step.length() + 0.05 or terrain.near_rock(next + Vector3.UP * 0.8, 0.4):
			continue
		if Ward.blocks(get_tree(), next) and not Ward.blocks(get_tree(), global_position):
			continue
		_detour = clampf(_detour + turn * 0.5, -2.0, 2.0) if turn != 0.0 else move_toward(_detour, 0.0, delta)
		global_position = next
		_face(step, delta)
		var before := _phase
		_phase += delta * speed * 2.2
		if int(before / PI) != int(_phase / PI):
			_steps.pitch_scale = randf_range(0.5, 0.7)
			_steps.play()  # ずしん、ずしん
		return
	_detour = -_detour if absf(_detour) > 0.1 else 1.5


func _face(direction: Vector3, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(delta * 5.0, 1.0))


## 体の動き：のしのし歩く・立ち上がって吠える・腕を振り上げて薙ぎ払う
func _process(delta: float) -> void:
	if _poser == null or dead:
		return
	var moving := state in ["wander", "stalk", "retreat"]
	var stride := sin(_phase) if moving else 0.0
	var run := 1.0 if state == "stalk" and player and global_position.distance_to(player.global_position) < 10.0 else 0.0
	var roar := 1.0 if state == "roar" else 0.0
	for i in 2:
		var side := "L" if i == 0 else "R"
		var s := 1.0 if i == 0 else -1.0
		_poser.set_target("thigh." + side, Vector3(stride * s * (0.45 + run * 0.25), 0.0, 0.0))
		_poser.set_target("shin." + side, Vector3(-maxf(stride * s, 0.0) * 0.6, 0.0, 0.0))
		# 腕は歩みに合わせて振り、吠えるときは大きく広げて振り上げる
		var arm := Vector3(-stride * s * 0.35 - run * 0.5, 0.0, 0.15 * s)
		arm = arm.lerp(Vector3(-1.9, 0.0, 0.9 * s), roar)
		if state == "swipe" and _swing >= 0.0 and (s > 0.0) == (_swing_side > 0.0):
			var t := _swing
			var raised := Vector3(-2.3, 0.3 * s, 0.8 * s)
			var through := Vector3(0.6, -0.6 * s, -0.4 * s)
			var strike_at := SWIPE_WINDUP / (SWIPE_WINDUP + 0.35)
			arm = raised * smoothstep(0.0, 1.0, t / strike_at) if t < strike_at else raised.lerp(through, smoothstep(0.0, 1.0, (t - strike_at) / (1.0 - strike_at)))
		_poser.set_target("upperarm." + side, arm)
		_poser.set_target("forearm." + side, Vector3(-0.4 - roar * 0.6, 0.0, 0.0))
		_poser.set_target("fingers." + side, Vector3(0.3 + roar * 0.4, 0.0, 0.0))
	_poser.set_target("spine", Vector3(0.15 + run * 0.35 - roar * 0.45, 0.0, sin(_phase * 0.5) * 0.05))
	_poser.set_target("chest", Vector3(0.1 - roar * 0.25, 0.0, 0.0))
	_poser.set_target("jaw", Vector3(0.1 + roar * 0.6 + (0.35 if state == "swipe" else 0.0) + absf(sin(_time * 1.3)) * 0.08, 0.0, 0.0))
	_poser.update(delta, 7.0)
	if player and state != "wander" and state != "graze":
		_poser.aim("head", player.get_camera().global_position)
	_model.position.y = absf(stride) * 0.06
