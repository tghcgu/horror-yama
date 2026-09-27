class_name Kodama
extends Node3D
## 樹海の「木霊」。白くて小さな人形のような霊が、いつのまにか何体も遠巻きにこちらを見ている。
## 見ていない間だけ、カタカタ首を鳴らしながら近づいてきて、すぐそばまで来ると持ち物をひとつ盗んで逃げていく。
## 走って追いつけば取り返せる。逃げきられると、盗んだ物をどこかに放り出して消える。塩で消せる。

const MODEL := preload("res://assets/models/kodama.glb")
const HOP := 2.5
const HOP_INTERVAL := 1.1
const STEAL_DISTANCE := 1.3
const FLEE_SPEED := 5.5
const FLEE_TIME := 7.0
const LIFETIME := 50.0
const VIEW_COS := 0.6

var player: Player
var steal_chance := 0.2  # そばまで来ても、たいていは盗みそこねる
var terrain: Terrain
var features: MountainFeatures
var state := "hidden"
var carrying := -1

var _timer := 0.0
var _life := 0.0
var _time := randf() * 10.0
var _flee_direction := Vector3.FORWARD
var _poser: BonePoser
var _clicks: AudioStreamPlayer3D
var _held_item: Node3D


func _ready() -> void:
	add_to_group(&"creatures")
	add_to_group(&"spirits")
	var skin := CreatureKit.skin(Color.WHITE, Color(0.8, 1.0, 0.9), 0.5, 0.1)
	var model := CreatureKit.load_model(MODEL, skin, {"EyeBlack": CreatureKit.flat(Color(0.0, 0.0, 0.0), 0.9)})
	add_child(model)
	_poser = BonePoser.new(model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)
	_clicks = AudioStreamPlayer3D.new()
	_clicks.stream = Sfx.clicks()
	_clicks.unit_size = 3.0
	_clicks.max_distance = 30.0
	add_child(_clicks)
	visible = false


func appear(pos: Vector3) -> void:
	global_position = pos
	state = "watching"
	visible = true
	carrying = -1
	_life = LIFETIME
	_timer = HOP_INTERVAL
	_clicks.play()


func vanish() -> void:
	if carrying >= 0:
		_drop()
	state = "hidden"
	visible = false
	_clicks.stop()


func purify() -> void:
	if state != "hidden":
		vanish()


func scare(_from: Vector3) -> void:
	if state != "hidden":
		vanish()


func is_seen() -> bool:
	var camera := player.get_camera()
	var to := global_position + Vector3.UP * 0.4 - camera.global_position
	if (-camera.global_transform.basis.z).dot(to.normalized()) < VIEW_COS:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, global_position + Vector3.UP * 0.4, Player.TERRAIN_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	if state == "hidden" or player == null:
		return
	_life -= delta
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	match state:
		"watching":
			_face(to_player)
			if _life <= 0.0 or player.frozen:
				vanish()
				return
			if to_player.length() < STEAL_DISTANCE:
				steal()
				return
			_timer -= delta
			if _timer <= 0.0:
				_timer = HOP_INTERVAL
				if not is_seen():
					_move(to_player.normalized() * minf(HOP, to_player.length() - 0.8))
		"fleeing":
			_timer -= delta
			_move(_flee_direction * FLEE_SPEED * delta)
			_face(_flee_direction)
			if to_player.length() < 1.2 and _timer < FLEE_TIME - 1.0:  # 盗んだ直後は、まだ取り返せない
				player.message.emit("取り返した")
				vanish()
			elif _timer <= 0.0:
				vanish()


## すぐそばまで来た：持ち物をひとつ盗んで逃げる（たいていは盗みそこねて、笑いながら消える）
func steal() -> void:
	if randf() > steal_chance:
		player.message.emit("くすくす……と笑い声がして、木霊は消えた")
		vanish()
		return
	carrying = player.steal_item()
	if carrying < 0:
		vanish()  # 何も持っていなかった
		return
	player.message.emit("木霊に%sを盗まれた" % Items.NAMES[carrying])
	state = "fleeing"
	_timer = FLEE_TIME
	var away := global_position - player.global_position
	away.y = 0.0
	_flee_direction = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	_held_item = Items.build_model(carrying)
	_held_item.position = Vector3(0.0, 0.62, 0.0)
	_held_item.scale = Vector3.ONE * 1.3
	add_child(_held_item)


func _drop() -> void:
	if features and is_instance_valid(features):
		features.spawn_item(carrying, global_position + Vector3.UP * 0.6, Vector3(0.0, 2.0, 0.0))
	carrying = -1
	if _held_item:
		_held_item.queue_free()
		_held_item = null


func _move(step: Vector3) -> void:
	var next := global_position + step
	next.y = terrain.height_at(next.x, next.z)
	if not Ward.blocks(get_tree(), next):
		global_position = next


func _face(direction: Vector3) -> void:
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)


## 首をかしげて、カタカタ鳴らす
func _process(delta: float) -> void:
	if state == "hidden":
		return
	_time += delta
	var rattle := sin(_time * 30.0) * 0.08 if fmod(_time, 2.3) < 0.6 else 0.0
	_poser.set_target("head", Vector3(0.0, 0.0, sin(_time * 0.8) * 0.4 + rattle))
	var run := sin(_time * 18.0) * 0.8 if state == "fleeing" else 0.0
	_poser.set_target("leg.L", Vector3(run, 0.0, 0.0))
	_poser.set_target("leg.R", Vector3(-run, 0.0, 0.0))
	_poser.set_target("arm.L", Vector3(1.4 if carrying >= 0 else 0.0, 0.0, 0.0))
	_poser.set_target("arm.R", Vector3(1.4 if carrying >= 0 else 0.0, 0.0, 0.0))
	_poser.update(delta, 25.0)
