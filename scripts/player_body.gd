class_name PlayerBody
extends Node3D
## プレイヤーの体（Blender で作ったちびキャラの登山者）。自分の目線のカメラには映らず、鏡にだけ映る
## （ほかのプレイヤー（仲間）の体は、ふつうに見える）。
## 帽子・髪・上着・首まわり・表情は鏡の前で選んだ形だけを見せ、帽子とミトン・上着・首まわり・髪・肌を選んだ色に塗る。
## 歩く・登る・跳ぶ・滑る・落ちる・つかまれる・飛ぶ・食べる・投げる・手を差し伸べる、疲れや寒さ、
## それにエモート（手をふる・おどる など）に合わせて姿勢を変え、頭は見ている方向を向く。

const MODEL := preload("res://assets/models/climber.glb")
const BODY_LAYER := 4  # 目線のカメラに映さない層（鏡のカメラには映る）
const SIDES := ["L", "R"]
const BONES := ["upperarm.L", "upperarm.R", "forearm.L", "forearm.R", "thigh.L", "thigh.R", "shin.L", "shin.R",
	"spine", "chest", "neck"]

var _player: Player
var _poser: BonePoser
var _tinted := {}  # 色を塗る部分（hat / jacket / scarf / hair / skin） → その部分の素材の一覧
var _model: Node3D
var _phase := 0.0
var _time := 0.0
var _idle_time := 0.0


func _ready() -> void:
	_player = get_parent() as Player
	var model := MODEL.instantiate() as Node3D
	_model = model
	var materials := Psx.convert_model(model)
	for material_name: String in materials:
		var part := Appearance.tint_part(material_name)
		if part != "":
			if not _tinted.has(part):
				_tinted[part] = []
			(_tinted[part] as Array).append(materials[material_name])
	Settings.changed.connect(_apply_colors)
	_apply_colors()
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.layers = BODY_LAYER if _player.controlled else 1
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # 頭がヘッドライトの光をさえぎらないように
	add_child(model)
	_poser = BonePoser.new(model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)


func _apply_colors() -> void:
	for part: String in _tinted:
		for material: ShaderMaterial in _tinted[part]:
			if material:
				material.set_shader_parameter("albedo", Appearance.tint_for(part))
	Appearance.apply_styles(_model)


func _process(delta: float) -> void:
	_time += delta
	var pose := _pose(delta)
	for bone: String in BONES:
		_poser.set_target(bone, pose.get(bone, Vector3.ZERO))
	# すわる・しゃがむ・ひざをつくときは、体ごと下げる
	_model.position.y = lerpf(_model.position.y, -float(pose.get("_drop", 0.0)), 1.0 - exp(-10.0 * delta))
	_poser.update(delta, float(pose.get("_speed", 12.0)))
	# 頭は、カメラが見ている方向を向く（おじぎの間は、体といっしょに下を向く）
	if not pose.get("_no_aim", false):
		var camera := _player.get_camera()
		_poser.aim("head", camera.global_position - camera.global_transform.basis.z * 5.0)


## いまの状態やエモートに合わせた姿勢。骨の名前 → 角度（BonePoser の向き）。
## "_drop" は体を下げる量、"_speed" は姿勢が切り替わる速さ、"_no_aim" は頭をカメラに向けない
func _pose(delta: float) -> Dictionary:
	var pose := {}
	var p := _player
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	var t := _time
	if p.state == Player.State.CLIMB:
		for i in 2:
			# 両腕を上へ伸ばし、左右交互に岩をつかみ直す
			var reach := sin(t * 5.0 + i * PI) * (0.35 if p.climb_input != Vector2.ZERO else 0.05)
			_limbs(pose, i, Vector3(2.6 + reach, 0.0, 0.15), Vector3(0.3, 0.0, 0.0), Vector3(0.7 + reach, 0.0, 0.1), Vector3(-1.1, 0.0, 0.0))
		_lean(pose, 0.25)
		return pose
	if p.state == Player.State.MANTLE or p.is_being_pulled():
		for i in 2:
			_limbs(pose, i, Vector3(1.6, 0.0, 0.2), Vector3.ZERO, Vector3(1.2 if i == 0 else 0.4, 0.0, 0.0), Vector3(-1.4, 0.0, 0.0))
		return pose
	if p.held_by:
		# つかまれて宙づり：腕を上に取られ、脚をばたつかせる
		for i in 2:
			var kick := sin(t * 9.0 + i * 2.0)
			_limbs(pose, i, Vector3(2.8, 0.0, 0.2), Vector3(0.2, 0.0, 0.0), Vector3(kick * 0.6, 0.0, 0.1), Vector3(-0.5 - absf(kick), 0.0, 0.0))
		pose["_speed"] = 20.0
		return pose
	if p.flying:
		# 空を飛ぶ：両腕を前へ突き出す
		for i in 2:
			_limbs(pose, i, Vector3(2.9, 0.0, 0.1), Vector3.ZERO, Vector3(-0.2, 0.0, 0.05), Vector3(-0.3, 0.0, 0.0))
		_lean(pose, 0.5)
		return pose
	if not p.is_on_floor():
		if p.velocity.y < -6.0:
			# 落ちながらもがく
			for i in 2:
				var flail := sin(t * 18.0 + i * 2.0) * 0.5
				_limbs(pose, i, Vector3(2.2 + flail, 0.0, 0.6), Vector3.ZERO, Vector3(0.5 - flail, 0.0, 0.1), Vector3(-0.9, 0.0, 0.0))
			pose["_speed"] = 20.0
		else:
			# 跳んでいる：ひざを曲げ、腕を少し広げる
			for i in 2:
				_limbs(pose, i, Vector3(0.8, 0.0, 0.5), Vector3(0.4, 0.0, 0.0), Vector3(0.9, 0.0, 0.05), Vector3(-1.4, 0.0, 0.0))
		return pose
	if p.sliding:
		# 滑り落ちる：体をのけぞらせ、両腕を広げてバランスをとる
		for i in 2:
			_limbs(pose, i, Vector3(0.4, 0.0, 1.2), Vector3(0.2, 0.0, 0.0), Vector3(0.6 if i == 0 else -0.1, 0.0, 0.1), Vector3(-0.3, 0.0, 0.0))
		_lean(pose, -0.35)
		return pose
	if p.reaching:
		# ひざをついて、崖の下へ手を差し伸べる
		_limbs(pose, 0, Vector3(0.3, 0.0, 0.3), Vector3(0.6, 0.0, 0.0), Vector3(1.4, 0.0, 0.05), Vector3(-1.6, 0.0, 0.0))
		_limbs(pose, 1, Vector3(1.3, 0.0, 0.1), Vector3.ZERO, Vector3(0.2, 0.0, 0.05), Vector3(-1.8, 0.0, 0.0))
		_lean(pose, 0.9)
		pose["_drop"] = 0.4
		return pose
	if p.emote != "":
		return _emote_pose(pose, p.emote, t)
	if p.crouching:
		return _emote_pose(pose, "crouch", t)
	if p.is_eating():
		# 缶詰を食べる：右手を口へ運び、もぐもぐ
		_limbs(pose, 1, Vector3(1.2, 0.0, 0.1), Vector3(2.0 + sin(t * 8.0) * 0.2, 0.0, 0.0), Vector3.ZERO, Vector3(-0.1, 0.0, 0.0))
		_limbs(pose, 0, Vector3(0.9, 0.0, -0.1), Vector3(1.4, 0.0, 0.0), Vector3.ZERO, Vector3(-0.1, 0.0, 0.0))
		return pose
	if speed > 0.3:
		# 歩く：脚と腕を交互に振る。走るほど大きく
		_phase += delta * speed * 1.9
		for i in 2:
			var swing := sin(_phase + i * PI) * clampf(speed / 4.5, 0.3, 1.3)
			_limbs(pose, i, Vector3(-swing * 0.4, 0.0, 0.08), Vector3(0.35, 0.0, 0.0), Vector3(swing * 0.5, 0.0, 0.0),
				Vector3(-maxf(-swing, 0.0) * 0.9 - 0.1, 0.0, 0.0))
		_idle_time = 0.0
		_lean(pose, 0.06)
		return pose
	_idle_time += delta
	if p.throw_time() > 0.0:
		# 投げる：右腕を振り下ろす
		var swing := p.throw_time() / 0.4
		_limbs(pose, 1, Vector3(0.8 + swing * 1.8, 0.0, 0.1), Vector3(0.3, 0.0, 0.0), Vector3.ZERO, Vector3(-0.1, 0.0, 0.0))
		pose["_speed"] = 25.0
		return pose
	if p.exhausted or p.stamina < p.max_stamina() * 0.25:
		# へとへと：ひざに手をついて、肩で息をする
		for i in 2:
			_limbs(pose, i, Vector3(0.9, 0.0, 0.05), Vector3(0.2, 0.0, 0.0), Vector3(0.3, 0.0, 0.05), Vector3(-0.4, 0.0, 0.0))
		_lean(pose, 1.3 + sin(t * 3.0) * 0.08)
		pose["_drop"] = 0.08
		return pose
	if p.cold > 25.0:
		# 寒い：腕を抱えて震える
		return _emote_pose(pose, "shiver", t)
	if fmod(_idle_time, 9.0) > 7.0:
		# しばらく立ち止まっていると、のびをする
		for i in 2:
			_limbs(pose, i, Vector3(2.9, 0.0, 0.25), Vector3(0.2, 0.0, 0.0), Vector3.ZERO, Vector3.ZERO)
		_lean(pose, -0.2)
		pose["_speed"] = 5.0
		return pose
	# 立ち止まっている：わずかに腕を下ろし、肩で息をする
	for i in 2:
		_limbs(pose, i, Vector3(0.05, 0.0, 0.05 + sin(t * 1.6) * 0.01), Vector3(0.15, 0.0, 0.0), Vector3.ZERO, Vector3.ZERO)
	_lean(pose, 0.04 + sin(t * 1.6) * 0.015)
	return pose


## エモート（T で選ぶ動き）
func _emote_pose(pose: Dictionary, emote: String, t: float) -> Dictionary:
	match emote:
		"wave":  # 手をふる
			_limbs(pose, 1, Vector3(2.4, 0.0, 0.5), Vector3(0.5 + 0.5 * sin(t * 9.0), 0.0, 0.0), Vector3.ZERO, Vector3.ZERO)
			_limbs(pose, 0, Vector3(0.05, 0.0, 0.05), Vector3(0.15, 0.0, 0.0), Vector3.ZERO, Vector3.ZERO)
		"cheer":  # ばんざい：両手を上げて、ぴょんぴょん
			var bounce := absf(sin(t * 6.0))
			for i in 2:
				_limbs(pose, i, Vector3(3.0, 0.0, 0.35), Vector3(0.1, 0.0, 0.0), Vector3(0.3 * bounce, 0.0, 0.05), Vector3(-0.6 * bounce, 0.0, 0.0))
			pose["_drop"] = 0.08 * bounce
		"bow":  # おじぎ
			for i in 2:
				_limbs(pose, i, Vector3(-0.1, 0.0, 0.02), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
			_lean(pose, 1.0)
			pose["neck"] = Vector3(-0.3, 0.0, 0.0)
			pose["_no_aim"] = true
			pose["_speed"] = 6.0
		"point":  # ゆびさす
			_limbs(pose, 1, Vector3(1.6, 0.0, 0.0), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
			_limbs(pose, 0, Vector3(0.2, 0.0, 0.5), Vector3(1.2, 0.0, 0.0), Vector3.ZERO, Vector3.ZERO)
		"sit":  # すわる
			for i in 2:
				_limbs(pose, i, Vector3(0.5, 0.0, 0.1), Vector3(0.6, 0.0, 0.0), Vector3(1.55, 0.0, 0.1), Vector3(-1.55, 0.0, 0.0))
			_lean(pose, -0.1)
			pose["_drop"] = 0.46
			pose["_speed"] = 6.0
		"dance":  # おどる
			var beat := t * 6.0
			for i in 2:
				var step := maxf(sin(beat + i * PI), 0.0)
				_limbs(pose, i, Vector3(1.5 + 1.2 * sin(beat + i * PI), 0.0, 0.5), Vector3(1.0, 0.0, 0.0),
					Vector3(0.4 * step, 0.0, 0.05), Vector3(-0.8 * step, 0.0, 0.0))
			pose["spine"] = Vector3(0.0, 0.0, sin(beat) * 0.2)
			pose["chest"] = Vector3(0.0, sin(beat) * 0.2, 0.0)
			pose["_drop"] = 0.05 * absf(sin(beat * 2.0))
			pose["_speed"] = 18.0
		"shiver":  # ぶるぶる：腕を抱えて震える
			var shake := sin(t * 45.0) * 0.04
			for i in 2:
				_limbs(pose, i, Vector3(0.8, 0.0, -0.3), Vector3(1.8, 0.0, 0.0), Vector3(0.05, 0.0, -0.05), Vector3(-0.1, 0.0, 0.0))
			pose["spine"] = Vector3(-0.1, 0.0, shake)
			pose["chest"] = Vector3(-0.1, shake, 0.0)
			pose["_speed"] = 30.0
		"crouch":  # しゃがむ
			for i in 2:
				_limbs(pose, i, Vector3(1.0, 0.0, 0.1), Vector3(0.8, 0.0, 0.0), Vector3(1.9, 0.0, 0.1), Vector3(-2.2, 0.0, 0.0))
			_lean(pose, 0.4)
			pose["_drop"] = 0.6
			pose["_speed"] = 8.0
	return pose


## 片側（0 = 左、1 = 右）の腕と脚。横方向の角度は外向きを正として渡す
func _limbs(pose: Dictionary, i: int, arm: Vector3, forearm: Vector3, thigh: Vector3, shin: Vector3) -> void:
	var side: String = SIDES[i]
	var s := 1.0 if i == 0 else -1.0
	pose["upperarm." + side] = Vector3(arm.x, arm.y * s, arm.z * s)
	pose["forearm." + side] = forearm
	pose["thigh." + side] = Vector3(thigh.x, thigh.y * s, thigh.z * s)
	pose["shin." + side] = shin


## 上半身を前へ倒す（負なら後ろへそらす）
func _lean(pose: Dictionary, amount: float) -> void:
	pose["spine"] = Vector3(-amount * 0.5, 0.0, 0.0)
	pose["chest"] = Vector3(-amount * 0.5, 0.0, 0.0)
