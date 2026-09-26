class_name PaleOne
extends Node3D
## 雪原の吹雪の中に立つ、白い着物に長い黒髪の、背の高い人影“白い人”。
## 見られていない間だけ、じりじり近づいてくる。触れられると体が凍えてケガをする。お札の円には入れない。

const STEP_INTERVAL := 0.4
const STEP_LENGTH := 1.3
const TOUCH_DISTANCE := 1.7
const CHILL_INJURY := 25.0
const APPEAR_DISTANCE := Vector2(22.0, 32.0)
const VIEW_COS := 0.57   # 画面の中心からこの角度（約55°）以内なら見られている
const VIEW_RANGE := 70.0
const COOLDOWN := 20.0
const HEAD_TILT := 0.3  # 首のかしげ方 (rad)
const MODEL := preload("res://assets/models/pale_one.glb")

var active := false
var cooldown := 0.0
var player: Player
var terrain: Terrain

var _step_wait := 0.0
var _closest := INF
var _stuck_time := 0.0
var _poser: BonePoser
var _seen := false
var _time := 0.0
var _whisper: AudioStreamPlayer3D
var _touch: AudioStreamPlayer


func _ready() -> void:
	add_to_group(&"spirits")
	_build()
	_whisper = AudioStreamPlayer3D.new()
	_whisper.stream = Sfx.whisper()
	_whisper.unit_size = 5.0
	_whisper.max_distance = 45.0
	_whisper.position.y = 2.4
	add_child(_whisper)
	_touch = AudioStreamPlayer.new()
	_touch.stream = Sfx.wail()
	_touch.pitch_scale = 0.6
	_touch.bus = &"Echo"
	add_child(_touch)
	visible = false


## プレイヤーから少し離れた、見られていない雪原の上に現れる
func appear_near() -> bool:
	for attempt in 16:
		var angle := randf() * TAU
		var distance := randf_range(APPEAR_DISTANCE.x, APPEAR_DISTANCE.y)
		var x := player.global_position.x + cos(angle) * distance
		var z := player.global_position.z + sin(angle) * distance
		var y := terrain.height_at(x, z)
		if Biomes.at(Vector3(x, y, z)) != Biomes.Id.SNOW:
			continue
		global_position = Vector3(x, y, z)
		if _is_seen():
			continue
		active = true
		visible = true
		_closest = INF
		_stuck_time = 0.0
		_whisper.play()
		return true
	return false


## 見られていない場所のうち、プレイヤーの近くへ移る
func _reposition_closer() -> void:
	var start := global_position
	for attempt in 12:
		var angle := randf() * TAU
		var x := player.global_position.x + cos(angle) * 8.0
		var z := player.global_position.z + sin(angle) * 8.0
		global_position = Vector3(x, terrain.height_at(x, z), z)
		if not _is_seen() and not Ward.blocks(get_tree(), global_position):
			_closest = global_position.distance_to(player.global_position)
			_stuck_time = 0.0
			return
	global_position = start


func vanish() -> void:
	active = false
	visible = false
	_whisper.stop()
	cooldown = COOLDOWN


## 塩で清められた：しばらく現れない
func purify() -> void:
	if active:
		vanish()
		cooldown = COOLDOWN * 3.0


func _physics_process(delta: float) -> void:
	cooldown -= delta
	if not active or player == null:
		return
	var to_player := player.global_position - global_position
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	if flat.length() > 0.1:
		look_at(global_position + flat, Vector3.UP)
	_seen = _is_seen()
	if _seen:
		return  # 見られている間は、ぴくりとも動かない

	_step_wait -= delta
	if _step_wait <= 0.0:
		_step_wait = STEP_INTERVAL
		var next := global_position + to_player.normalized() * minf(STEP_LENGTH, to_player.length())
		next.y = maxf(next.y, terrain.height_at(next.x, next.z))
		if not Ward.blocks(get_tree(), next):
			global_position = next
		# 地形に引っかかって近づけないときは、見えない所から回り込み直す
		var distance := global_position.distance_to(player.global_position)
		if distance < _closest - 0.5:
			_closest = distance
			_stuck_time = 0.0
		else:
			_stuck_time += STEP_INTERVAL
			if _stuck_time > 3.0:
				_reposition_closer()
	if global_position.distance_to(player.global_position) < TOUCH_DISTANCE and not player.frozen:
		player.chill(CHILL_INJURY)
		_touch.play()
		vanish()


func _is_seen() -> bool:
	var camera := player.get_camera()
	var chest := global_position + Vector3.UP * 1.8
	var to_it := chest - camera.global_position
	if to_it.length() > VIEW_RANGE:
		return false
	if (-camera.global_transform.basis.z).dot(to_it.normalized()) < VIEW_COS:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, chest, Player.TERRAIN_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Blender で作ったモデル（tools/creatures/build_pale_one.py）を読み込む
func _build() -> void:
	var robe := CreatureKit.skin(Color.WHITE, Color(0.9, 0.95, 1.0), 0.3, 0.1)
	var model := CreatureKit.load_model(MODEL, robe, {
		"Hair": CreatureKit.flat(Color(0.01, 0.01, 0.012), 0.3),
		"EyeWhite": CreatureKit.flat(Color(0.8, 0.77, 0.72), 0.3),
		"EyeBlack": CreatureKit.flat(Color(0.0, 0.0, 0.0), 0.2),
		"Claw": CreatureKit.flat(Color(0.35, 0.33, 0.3), 0.4),
	})
	add_child(model)
	_poser = BonePoser.new(model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)


## 首をかしげてこちらを見る。見られていない間だけ、首と腕がぎこちなく揺れる
func _process(delta: float) -> void:
	if not active or player == null:
		return
	if not _seen:
		_time += delta
		_poser.set_target("upperarm.L", Vector3(sin(_time * 3.1) * 0.08, 0.0, 0.05))
		_poser.set_target("upperarm.R", Vector3(sin(_time * 2.7 + 1.0) * 0.08, 0.0, -0.05))
		_poser.set_target("chest", Vector3(0.12, 0.0, sin(_time * 1.7) * 0.05))
		_poser.update(delta, 8.0)
	_poser.aim("head", player.get_camera().global_position, HEAD_TILT + (0.0 if _seen else sin(_time * 5.0) * 0.1))