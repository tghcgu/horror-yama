class_name ShadowClimber
extends Node3D
## 霊峰に現れる「影法師」。自分とまったく同じ背格好の、真っ黒な登山者。目だけが白く光っている。
## 見ている間はじっとこちらを見返し、目を離すたびに距離を半分に詰めてくる。触れられると力が抜けきる。
## 塩で消せる。お札や発煙筒の円には入れない。

const MODEL := preload("res://assets/models/climber.glb")
const JUMP_WAIT := 1.5
const TOUCH_DISTANCE := 1.6
const MIN_STEP := 2.5
const VIEW_COS := 0.6
const LIFETIME := 45.0

var player: Player
var terrain: Terrain
var active := false

var _timer := 0.0
var _life := 0.0
var _poser: BonePoser
var _voice: AudioStreamPlayer3D
var _time := 0.0


func _ready() -> void:
	add_to_group(&"spirits")
	var model := MODEL.instantiate() as Node3D
	var shadow := StandardMaterial3D.new()
	shadow.albedo_color = Color(0.005, 0.005, 0.008)
	shadow.roughness = 1.0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(i, shadow)
	add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_poser = BonePoser.new(skeleton)
	# 白く光る目
	var head := BoneAttachment3D.new()
	head.bone_name = "head"
	skeleton.add_child(head)
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone("head")).affine_inverse()
	for side in [-1.0, 1.0]:
		var eye := Vector3(0.09 * side, 1.37, -0.23)  # 顔の目の位置（モデルの座標）を、頭の骨から見た位置に直す
		CreatureKit.part(head, CreatureKit.sphere(0.035), CreatureKit.glow(Color(1.0, 1.0, 0.95), 8.0), rest * eye)
	_voice = AudioStreamPlayer3D.new()
	_voice.stream = Sfx.whisper()
	_voice.pitch_scale = 0.7
	_voice.unit_size = 5.0
	add_child(_voice)
	visible = false


func appear(pos: Vector3, owner_player: Player, mountain: Terrain) -> void:
	player = owner_player
	terrain = mountain
	global_position = pos
	active = true
	visible = true
	_timer = JUMP_WAIT
	_life = LIFETIME
	_voice.play()


func vanish() -> void:
	active = false
	visible = false
	_voice.stop()


func purify() -> void:
	vanish()


func is_seen() -> bool:
	var camera := player.get_camera()
	var chest := global_position + Vector3.UP * 1.0
	var to := chest - camera.global_position
	if (-camera.global_transform.basis.z).dot(to.normalized()) < VIEW_COS:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, chest, Player.TERRAIN_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	if not active or player == null:
		return
	_life -= delta
	var to := player.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > 0.1:
		look_at(global_position + flat, Vector3.UP)
	if _life <= 0.0 or player.frozen:
		vanish()
		return
	if to.length() < TOUCH_DISTANCE:
		player.drain_all()
		player.message.emit("影に触れられて、力が抜けた")
		vanish()
		return
	if is_seen():
		_timer = JUMP_WAIT
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = JUMP_WAIT
		# 目を離したすきに、距離を半分に詰める
		var step := maxf(flat.length() * 0.5, MIN_STEP)
		var next := global_position + flat.normalized() * minf(step, flat.length() - 0.5)
		next.y = terrain.height_at(next.x, next.z)
		if not Ward.blocks(get_tree(), next):
			global_position = next


## 登山者と同じ姿勢で立ち、首だけをこちらへ向ける
func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	for side in ["L", "R"]:
		_poser.set_target("upperarm." + side, Vector3(0.05, 0.0, 0.05 if side == "L" else -0.05))
	_poser.update(delta, 8.0)
	_poser.aim("head", player.get_camera().global_position, sin(_time * 0.6) * 0.25)
