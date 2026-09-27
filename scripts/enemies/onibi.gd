class_name Onibi
extends Node3D
## 夜の山と霊峰にただよう青い火の玉「鬼火」。現れた場所のあたりを、ゆらゆらとただよう。
## 近づくと少しずつ寄ってきて、触れると体の芯まで冷える（しつこく追いかけてはこない）。しばらくすると消える。
## ナタや拳で払うと、ふっと消える。お札や発煙筒の円には入れない。塩をまけば消える。

const SPEED := 0.8          # 近くにいるときに寄ってくる速さ（歩けば振り切れる）
const NOTICE := 6.0         # これより近いと、寄ってくる
const WANDER := 6.0         # 現れた場所から、これくらいの範囲をただよう
const TOUCH_DISTANCE := 0.9
const CHILL := 10.0
const LIFETIME := 40.0

var player: Player
var active := false

var _time := randf() * 10.0
var _home := Vector3.ZERO
var _life := 0.0
var _light: OmniLight3D
var _hum: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"spirits")
	var core := CreatureKit.sphere(0.16)
	core.radial_segments = 8
	core.rings = 5
	CreatureKit.part(self, core, CreatureKit.glow(Color(0.4, 0.7, 1.0), 6.0))
	var flame := CPUParticles3D.new()
	flame.amount = 20
	flame.lifetime = 0.6
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.12
	flame.direction = Vector3.UP
	flame.spread = 20.0
	flame.initial_velocity_min = 0.4
	flame.initial_velocity_max = 0.9
	flame.gravity = Vector3.ZERO
	flame.scale_amount_min = 0.5
	flame.scale_amount_max = 1.2
	var wisp := SphereMesh.new()
	wisp.radius = 0.07
	wisp.height = 0.14
	wisp.radial_segments = 4
	wisp.rings = 2
	wisp.material = CreatureKit.glow(Color(0.3, 0.55, 1.0), 4.0)
	flame.mesh = wisp
	add_child(flame)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 0.6, 1.0)
	_light.omni_range = 6.0
	_light.light_energy = 1.4
	add_child(_light)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = Sfx.hum()
	_hum.unit_size = 3.0
	_hum.max_distance = 30.0
	add_child(_hum)
	visible = false


func appear(pos: Vector3, owner_player: Player) -> void:
	player = owner_player
	global_position = pos
	_home = pos
	_life = LIFETIME
	active = true
	visible = true
	scale = Vector3.ONE
	_hum.play()


func vanish() -> void:
	active = false
	visible = false
	_hum.stop()


func purify() -> void:
	vanish()


## 払われた（ときどき）・爆竹の音に驚いた：ふっと散って消える
func scare(_from: Vector3) -> void:
	if not active:
		return
	active = false
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.05, 0.25)
	tween.tween_callback(vanish)


func _physics_process(delta: float) -> void:
	if not active or player == null:
		return
	_time += delta
	_life -= delta
	if _life <= 0.0:
		scare(global_position)  # しばらくすると、ふっと消える
		return
	var target := player.global_position + Vector3.UP * 1.2
	var to := target - global_position
	# ふだんは現れた場所のまわりをただよい、近くにいるときだけ、ゆっくり寄ってくる
	var wander := _home + Vector3(sin(_time * 0.37) * WANDER, sin(_time * 0.8) * 1.2, cos(_time * 0.29) * WANDER)
	var goal := target if to.length() < NOTICE else wander
	var drift := Vector3(sin(_time * 1.3), sin(_time * 2.1) * 0.6, cos(_time * 1.1)) * 0.5
	var next := global_position + ((goal - global_position).limit_length(1.0) * SPEED + drift) * delta
	if not Ward.blocks(get_tree(), next):
		global_position = next
	_light.light_energy = 1.2 + sin(_time * 7.0) * 0.3
	if to.length() < TOUCH_DISTANCE and not player.frozen:
		player.chill(CHILL)
		vanish()
