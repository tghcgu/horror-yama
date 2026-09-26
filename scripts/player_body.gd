class_name PlayerBody
extends Node3D
## プレイヤーの体（Blender で作ったちびキャラの登山者）。自分の目線のカメラには映らず、鏡にだけ映る。
## 帽子とミトン・上着・マフラーは、鏡の前で選んだ色に塗る。
## 歩けば脚と腕を振り、登るときは腕を上へ伸ばし、落ちるときはもがき、頭は見ている方向を向く。

const MODEL := preload("res://assets/models/climber.glb")
const BODY_LAYER := 4  # 目線のカメラに映さない層（鏡のカメラには映る）
const SIDES := ["L", "R"]

var _player: Player
var _poser: BonePoser
var _tinted := {}  # 色を塗る部分 → その部分の素材の一覧
var _phase := 0.0
var _time := 0.0


func _ready() -> void:
	_player = get_parent() as Player
	var model := MODEL.instantiate() as Node3D
	var materials := Psx.convert_model(model)
	_tinted = {
		"hat": [materials.get("climber_hat_tint"), materials.get("climber_mittens_tint")],
		"jacket": [materials.get("climber_jacket_tint")],
		"scarf": [materials.get("climber_scarf_tint")],
	}
	Settings.changed.connect(_apply_colors)
	_apply_colors()
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.layers = BODY_LAYER
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # 頭がヘッドライトの光をさえぎらないように
	add_child(model)
	_poser = BonePoser.new(model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)


func _apply_colors() -> void:
	for part: String in _tinted:
		for material: ShaderMaterial in _tinted[part]:
			if material:
				material.set_shader_parameter("albedo", Appearance.tint_of(part))


func _process(delta: float) -> void:
	_time += delta
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var falling := not _player.is_on_floor() and _player.velocity.y < -6.0 and _player.state == Player.State.WALK
	for i in SIDES.size():
		var side: String = SIDES[i]
		var s := 1.0 if i == 0 else -1.0
		var arm := Vector3.ZERO
		var forearm := Vector3.ZERO
		var thigh := Vector3.ZERO
		var shin := Vector3.ZERO
		match _player.state:
			Player.State.CLIMB:
				# 両腕を上へ伸ばし、左右交互に岩をつかみ直す
				var reach := sin(_time * 5.0 + i * PI) * (0.35 if _player.climb_input != Vector2.ZERO else 0.05)
				arm = Vector3(2.6 + reach, 0.0, 0.15 * s)
				forearm = Vector3(0.3, 0.0, 0.0)
				thigh = Vector3(0.7 + reach, 0.0, 0.1 * s)
				shin = Vector3(-1.1, 0.0, 0.0)
			Player.State.MANTLE:
				arm = Vector3(1.6, 0.0, 0.2 * s)
				thigh = Vector3(1.2 if i == 0 else 0.4, 0.0, 0.0)
				shin = Vector3(-1.4, 0.0, 0.0)
			_:
				if falling:
					var flail := sin(_time * 18.0 + i * 2.0) * 0.5
					arm = Vector3(2.2 + flail, 0.0, 0.6 * s)
					thigh = Vector3(0.5 - flail, 0.0, 0.1 * s)
					shin = Vector3(-0.9, 0.0, 0.0)
				elif speed > 0.3:
					# 歩く：脚と腕を交互に振る。走るほど大きく
					_phase += delta * speed * 1.9
					var swing := sin(_phase + i * PI) * clampf(speed / 4.5, 0.3, 1.3)
					thigh = Vector3(swing * 0.5, 0.0, 0.0)
					shin = Vector3(-maxf(-swing, 0.0) * 0.9 - 0.1, 0.0, 0.0)
					arm = Vector3(-swing * 0.4, 0.0, 0.08 * s)
					forearm = Vector3(0.35, 0.0, 0.0)
				else:
					# 立ち止まっている：わずかに腕を下ろし、肩で息をする
					arm = Vector3(0.05, 0.0, 0.05 * s + sin(_time * 1.6) * 0.01 * s)
					forearm = Vector3(0.15, 0.0, 0.0)
		_poser.set_target("upperarm." + side, arm)
		_poser.set_target("forearm." + side, forearm)
		_poser.set_target("thigh." + side, thigh)
		_poser.set_target("shin." + side, shin)
	var lean := 0.25 if _player.state == Player.State.CLIMB else 0.04 + sin(_time * 1.6) * 0.015
	_poser.set_target("spine", Vector3(-lean * 0.5, 0.0, 0.0))
	_poser.set_target("chest", Vector3(-lean * 0.5, 0.0, 0.0))
	_poser.update(delta, 12.0)
	# 頭は、カメラが見ている方向を向く
	var camera := _player.get_camera()
	_poser.aim("head", camera.global_position - camera.global_transform.basis.z * 5.0)
