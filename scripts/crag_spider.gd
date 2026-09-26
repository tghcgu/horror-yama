class_name CragSpider
extends Node3D
## 岩場の崖にはりつく大きなクモ。ふだんは壁をゆっくり這い回り、近くを登ると噛みついて壁から落とす。
## 見た目は Blender で作ったモデル（tools/creatures/build_spider.py）。

const CRAWL_SPEED := 0.35
const WANDER_RADIUS := 3.0
const BITE_DISTANCE := 1.3
const BITE_INJURY := 15.0
const BITE_COOLDOWN := 3.0
const ALERT_DISTANCE := 7.0  # これより近づくと、こちらを向いて前脚を振り上げる
const MODEL := preload("res://assets/models/spider.glb")
const SIDES := ["L", "R"]

var player: Player

var _home := Vector3.ZERO
var _normal := Vector3.UP
var _goal := Vector3.ZERO
var _cooldown := 0.0
var _time := randf() * 10.0
var _alert := false
var _moving := false
var _poser: BonePoser
var _hiss: AudioStreamPlayer3D


func _ready() -> void:
	var skin := CreatureKit.skin(Color.WHITE, Color(0.55, 0.2, 0.15), 0.15, 0.75)
	var model := CreatureKit.load_model(MODEL, skin, {
		"Eye": CreatureKit.glow(Color(1.0, 0.12, 0.08), 8.0),
		"Claw": CreatureKit.flat(Color(0.06, 0.05, 0.04), 0.3),
	})
	add_child(model)
	_poser = BonePoser.new(model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = Sfx.hiss()
	_hiss.unit_size = 4.0
	add_child(_hiss)


## ツリーに追加してから呼ぶ。pos は壁の表面、normal は壁の外向き
func setup(pos: Vector3, normal: Vector3, owner_player: Player) -> void:
	player = owner_player
	_home = pos
	_goal = pos
	_normal = normal
	global_position = pos
	_orient(Vector3.UP - normal * normal.y, 1.0)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_time += delta
	_cooldown -= delta
	var chest := player.global_position + Vector3.UP * 1.2
	var to_player := chest - global_position
	_alert = to_player.length() < ALERT_DISTANCE and not player.frozen
	_moving = false
	if _alert:
		_orient(to_player, 1.0 - exp(-8.0 * delta))
	else:
		var offset := _goal - global_position
		if offset.length() < 0.1:
			_goal = _pick_goal()
		else:
			global_position += offset.normalized() * minf(CRAWL_SPEED * delta, offset.length())
			_orient(offset, 1.0 - exp(-4.0 * delta))
			_moving = true

	if player.state == Player.State.CLIMB and not player.frozen and _cooldown <= 0.0 and to_player.length() < BITE_DISTANCE:
		_cooldown = BITE_COOLDOWN
		_hiss.pitch_scale = randf_range(0.9, 1.2)
		_hiss.play()
		player.bitten(BITE_INJURY)


## 這うときは脚を交互に持ち上げ、警戒中は前脚を振り上げて震わせ、牙をかちかち鳴らす
func _process(delta: float) -> void:
	for index in 4:
		for side in SIDES:
			var s := 1.0 if side == "L" else -1.0
			var phase := _time * 12.0 + (0.0 if (index + (0 if side == "L" else 1)) % 2 == 0 else PI)
			var lift := maxf(sin(phase), 0.0) * 0.3 if _moving else 0.0
			var swing := sin(phase) * 0.2 if _moving else 0.0
			if _alert and index == 0:
				lift = 0.9 + sin(_time * 30.0) * 0.08
				swing = 0.25
			_poser.set_target("leg%da.%s" % [index, side], Vector3(0.0, swing * s, lift * s))
			_poser.set_target("leg%db.%s" % [index, side], Vector3(0.0, 0.0, -lift * 0.6 * s))
	_poser.set_target("fangs", Vector3(absf(sin(_time * 25.0)) * 0.3 if _alert else 0.0, 0.0, 0.0))
	_poser.update(delta, 30.0)


func _pick_goal() -> Vector3:
	var right := _normal.cross(Vector3.UP)
	if right.length() < 0.1:
		return global_position
	right = right.normalized()
	var up := right.cross(-_normal).normalized()
	var candidate := _home + right * randf_range(-WANDER_RADIUS, WANDER_RADIUS) + up * randf_range(-WANDER_RADIUS, WANDER_RADIUS)
	var query := PhysicsRayQueryParameters3D.create(candidate + _normal * 1.0, candidate - _normal * 1.5, Player.TERRAIN_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.6:
		return global_position
	return hit.position


## 背中を壁の外へ、頭を direction の方へ向ける
func _orient(direction: Vector3, weight: float) -> void:
	var forward := direction - _normal * direction.dot(_normal)
	if forward.length() < 0.01:
		return
	var z := -forward.normalized()
	var x := _normal.cross(z).normalized()
	var target := Basis(x, _normal, z).orthonormalized()
	var current := global_transform.basis.orthonormalized()
	global_transform.basis = current.slerp(target, weight)
