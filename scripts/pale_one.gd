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

var active := false
var cooldown := 0.0
var player: Player
var terrain: Terrain

var _step_wait := 0.0
var _closest := INF
var _stuck_time := 0.0
var _whisper: AudioStreamPlayer3D
var _touch: AudioStreamPlayer


func _ready() -> void:
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
		if Biomes.at(y) != Biomes.Id.SNOW:
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


func _physics_process(delta: float) -> void:
	cooldown -= delta
	if not active or player == null:
		return
	var to_player := player.global_position - global_position
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	if flat.length() > 0.1:
		look_at(global_position + flat, Vector3.UP)
	if _is_seen():
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


## 白い着物、顔を隠す長い黒髪、地面近くまで垂れた長い腕（仮のモデル）
func _build() -> void:
	var robe := CreatureKit.skin(Color(0.84, 0.85, 0.88), Color(0.9, 0.95, 1.0), 0.35, 0.1)
	var skin := CreatureKit.skin(Color(0.75, 0.76, 0.78), Color(0.9, 0.95, 1.0), 0.3, 0.2)
	var hair := CreatureKit.flat(Color(0.01, 0.01, 0.012), 0.35)
	var claw := CreatureKit.flat(Color(0.5, 0.5, 0.5), 0.5)

	var body := Node3D.new()
	add_child(body)
	# すそが広がった着物
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.16
	skirt.bottom_radius = 0.42
	skirt.height = 1.7
	CreatureKit.part(body, skirt, robe, Vector3(0.0, 0.85, 0.0))
	CreatureKit.part(body, CreatureKit.capsule(0.16, 1.0), robe, Vector3(0.0, 1.95, 0.0))
	CreatureKit.part(body, CreatureKit.capsule(0.05, 0.3), skin, Vector3(0.0, 2.5, 0.0))

	var head := CreatureKit.joint(body, Vector3(0.0, 2.72, 0.0))
	head.rotation.z = 0.4  # 首をかしげている
	CreatureKit.part(head, CreatureKit.capsule(0.11, 0.3), skin)
	# 顔の前と横に垂れる長い黒髪
	for i in 14:
		var angle := -PI * 0.55 + i * (PI * 1.1 / 13.0)
		var length := 0.9 + (0.25 if i % 3 == 0 else 0.0)
		CreatureKit.part(head, CreatureKit.capsule(0.022, length), hair,
			Vector3(sin(angle) * 0.1, 0.1 - length / 2.0, -cos(angle) * 0.11))
	CreatureKit.part(head, CreatureKit.sphere(0.12), hair, Vector3(0.0, 0.05, 0.02), Vector3.ZERO, Vector3(1.0, 1.1, 1.0))

	for side in [-1.0, 1.0]:
		var arm := CreatureKit.limb(body, Vector3(0.2 * side, 2.35, 0.0), 0.04, [0.8, 0.8, 0.15], skin, 4, claw)
		arm[0].rotation = Vector3(0.1, 0.0, 0.08 * side)
		arm[1].rotation.x = 0.15
