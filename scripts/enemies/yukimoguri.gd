class_name Yukimoguri
extends Node3D
## 雪山の雪の下を泳ぐ「雪潜り」。雪の上を歩いていると、盛り上がった雪が足元へ近づいてきて、
## 丸い口が飛び出して噛みつく。壁や岩にしがみついていれば届かない。鈴の音を嫌い、爆竹で逃げていく。

const MODEL := preload("res://assets/models/yukimoguri.glb")
const SPEED := 4.8
const STRIKE_DISTANCE := 1.6
const RISE_TIME := 0.35
const BITE_REACH := 2.3
const INJURY := 22.0
const COOLDOWN := 10.0
const BELL_DISTANCE := 8.0

var player: Player
var terrain: Terrain
var state := "gone"

var _timer := 0.0
var _rise := 0.0
var _model: Node3D
var _mound: MeshInstance3D
var _spray: CPUParticles3D
var _poser: BonePoser
var _sound: AudioStreamPlayer3D
var _time := 0.0


func _ready() -> void:
	add_to_group(&"creatures")
	var skin := CreatureKit.skin(Color.WHITE, Color(0.9, 0.8, 0.85), 0.2, 0.7)
	_model = CreatureKit.load_model(MODEL, skin, {
		"Teeth": CreatureKit.flat(Color(0.75, 0.72, 0.6), 0.4),
		"EyeBlack": CreatureKit.flat(Color(0.05, 0.0, 0.0), 0.3),
	})
	_model.scale = Vector3.ONE * 1.2
	add_child(_model)
	_poser = BonePoser.new(_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)
	var heap := CreatureKit.sphere(0.8)
	heap.radial_segments = 8
	heap.rings = 4
	_mound = CreatureKit.part(self, heap, Psx.material("ground_snow", Color(1.0, 1.0, 1.05), 0.33, 0.8), Vector3.ZERO,
		Vector3.ZERO, Vector3(1.0, 0.35, 1.3))
	_spray = CPUParticles3D.new()
	_spray.amount = 24
	_spray.lifetime = 0.6
	_spray.direction = Vector3.UP
	_spray.spread = 50.0
	_spray.initial_velocity_min = 1.0
	_spray.initial_velocity_max = 2.5
	_spray.gravity = Vector3(0.0, -8.0, 0.0)
	var flake := BoxMesh.new()
	flake.size = Vector3.ONE * 0.08
	flake.material = Psx.material("", Color(1.0, 1.0, 1.05))
	_spray.mesh = flake
	add_child(_spray)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.rumble()
	_sound.unit_size = 4.0
	_sound.max_distance = 30.0
	add_child(_sound)
	visible = false


func is_active() -> bool:
	return state != "gone"


## プレイヤーから少し離れた雪の中から、狙い始める
func start_hunt(owner_player: Player, mountain: Terrain) -> void:
	player = owner_player
	terrain = mountain
	var angle := randf() * TAU
	var start := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 18.0
	global_position = Vector3(start.x, terrain.height_at(start.x, start.z), start.z)
	state = "hunting"
	visible = true
	_model.visible = false
	_mound.visible = true
	_spray.emitting = true
	_sound.play()


func stop() -> void:
	state = "gone"
	visible = false
	_sound.stop()


func scare(_from: Vector3) -> void:
	if state != "gone":
		_submerge(COOLDOWN * 3.0)


func _physics_process(delta: float) -> void:
	if state == "gone" or player == null:
		return
	_timer -= delta
	var to := player.global_position - global_position
	to.y = 0.0
	match state:
		"hunting":
			var on_snow := player.is_on_floor() and player.state == Player.State.WALK and not player.frozen 				and not Ward.blocks(get_tree(), player.global_position)  # たき火やお札の円の中までは来ない
			var keep_away := BELL_DISTANCE if player.bell_ringing else 0.0
			if on_snow and to.length() > keep_away:
				_move(to.normalized() * minf(SPEED * delta, to.length()))
				if to.length() < STRIKE_DISTANCE and keep_away == 0.0:
					strike()
			elif to.length() > 4.0:
				_move(to.normalized() * minf(SPEED * 0.5 * delta, to.length() - 4.0))  # 足元の近くで待ちかまえる
		"striking":
			_rise = minf(_rise + delta / RISE_TIME, 1.0)
			if _rise >= 1.0 and _timer > 0.0:
				_timer = 0.0
				var reach := (player.global_position - global_position).length()
				if reach < BITE_REACH and player.is_on_floor() and not player.frozen:
					player.knock(to.normalized() * 6.0 + Vector3.UP * 4.0, INJURY)
				_submerge(COOLDOWN)
		"sinking":
			_rise = maxf(_rise - delta * 1.5, 0.0)
			if _rise <= 0.0:
				_model.visible = false
				if _timer <= 0.0:
					start_hunt(player, terrain)
	_model.position.y = lerpf(-3.2, 0.0, smoothstep(0.0, 1.0, _rise))


## 雪の中から飛び出して噛みつく
func strike() -> void:
	state = "striking"
	_rise = 0.0
	_timer = 1.0
	_model.visible = true
	_mound.visible = false
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() > 0.1:
		look_at(global_position + to, Vector3.UP)
	_spray.restart()


func _submerge(wait: float) -> void:
	state = "sinking"
	_timer = wait


func _move(step: Vector3) -> void:
	var next := global_position + step
	global_position = Vector3(next.x, terrain.height_at(next.x, next.z), next.z)


func _process(delta: float) -> void:
	if state == "gone":
		return
	_time += delta
	_mound.scale = Vector3(1.0, 0.35 + sin(_time * 9.0) * 0.05, 1.3)
	for i in 4:
		_poser.set_target("seg%d" % i, Vector3(sin(_time * 6.0 + i) * 0.12, 0.0, cos(_time * 5.0 + i) * 0.1))
	_poser.update(delta, 15.0)
