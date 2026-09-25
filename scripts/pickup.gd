class_name Pickup
extends Node3D
## 足場に落ちているアイテム。近づくと拾える。夜でも見つけられるように、ほのかに光る。

const PICK_DISTANCE := 1.7

var kind := 0
var player: Player

var _model: Node3D
var _time := randf() * TAU


func setup(item_kind: int, owner_player: Player) -> void:
	kind = item_kind
	player = owner_player
	_model = Items.build_model(kind)
	_model.scale = Vector3.ONE * 1.6
	add_child(_model)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.6)
	glow.light_energy = 0.7
	glow.omni_range = 2.5
	glow.position.y = 0.4
	add_child(glow)


func _process(delta: float) -> void:
	_time += delta
	_model.position.y = 0.35 + sin(_time * 2.0) * 0.05
	_model.rotation.y = _time * 1.2
	if player and not player.frozen and player.global_position.distance_to(global_position) < PICK_DISTANCE:
		player.pick_up(kind)
		queue_free()
