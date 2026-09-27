class_name Fumarole
extends Node3D
## 岩場の硫黄の噴気孔。しばらく湯気を上げたあと、ゴゴゴと鳴って熱い蒸気を噴き上げる。
## 真上にいると吹き飛ばされてやけどする。うまく使えば、高い岩棚まで跳び上がれる。

const RADIUS := 1.2
const HEIGHT := 5.0
const IDLE := Vector2(5.0, 9.0)
const WARNING := 1.2
const BLAST := 1.5
const LAUNCH_SPEED := 15.0
const BURN := 8.0

var player: Player
var phase := "idle"

var _timer := 0.0
var _launched := false
var _steam: LazyParticles
var _steam_speed := 0.6
var _steam_ratio := 0.15
var _rumble: AudioStreamPlayer3D
var _blast: AudioStreamPlayer3D


func setup(pos: Vector3, owner_player: Player) -> void:
	player = owner_player
	global_position = pos
	_timer = randf_range(IDLE.x, IDLE.y)
	var vent := MeshBuilder.new()
	var crust := CylinderMesh.new()
	crust.top_radius = 1.0
	crust.bottom_radius = 1.1
	crust.height = 0.08
	crust.radial_segments = 12
	vent.add(crust, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, Vector3.ONE, Color(1.4, 1.2, 0.35))
	var hole := CylinderMesh.new()
	hole.top_radius = 0.3
	hole.bottom_radius = 0.3
	hole.height = 0.1
	hole.radial_segments = 8
	vent.add(hole, Vector3(0.0, 0.03, 0.0), Vector3.ZERO, Vector3.ONE, Color(0.05, 0.04, 0.02))
	vent.instance(self, Psx.vertex_material("ground_crag", 0.5, 1.0))
	_steam = LazyParticles.new()
	add_child(_steam)
	_steam.setup(_make_steam, player, 60.0)
	_rumble = _sound(Sfx.rumble(), 5.0)
	_blast = _sound(Sfx.blast(), 8.0)
	_set_steam(0.6, 0.15)


func _sound(stream: AudioStream, unit: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.unit_size = unit
	sound.max_distance = 50.0
	add_child(sound)
	return sound


func _set_steam(speed: float, ratio: float) -> void:
	_steam_speed = speed
	_steam_ratio = ratio
	if _steam.particles:
		_apply_steam(_steam.particles)


func _apply_steam(particles: CPUParticles3D) -> void:
	particles.initial_velocity_min = _steam_speed * 0.7
	particles.initial_velocity_max = _steam_speed
	particles.scale_amount_min = 1.0 + _steam_ratio * 3.0
	particles.scale_amount_max = 2.0 + _steam_ratio * 6.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	match phase:
		"idle":
			if _timer <= 0.0:
				phase = "warning"
				_timer = WARNING
				_rumble.play()
				_set_steam(1.5, 0.5)
		"warning":
			if _timer <= 0.0:
				erupt()
		"blast":
			if not _launched and player and not player.frozen:
				var offset := player.global_position - global_position
				if Vector2(offset.x, offset.z).length() < RADIUS and offset.y > -0.5 and offset.y < HEIGHT:
					_launched = true
					player.launch(LAUNCH_SPEED, BURN)
			if _timer <= 0.0:
				phase = "idle"
				_timer = randf_range(IDLE.x, IDLE.y)
				_rumble.stop()
				_set_steam(0.6, 0.15)


func erupt() -> void:
	phase = "blast"
	_timer = BLAST
	_launched = false
	_blast.play()
	_set_steam(12.0, 1.0)


## 粒子を作る（LazyParticles が、使うときにだけ呼ぶ）
func _make_steam() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 1.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.25
	particles.direction = Vector3.UP
	particles.spread = 12.0
	particles.gravity = Vector3.ZERO
	particles.damping_min = 0.5
	particles.damping_max = 1.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	var puff := QuadMesh.new()
	puff.size = Vector2(0.4, 0.4)
	puff.material = CreatureKit.puff_material(Color(0.95, 0.95, 0.9, 0.45))
	particles.mesh = puff
	particles.color_ramp = CreatureKit.fade_ramp()
	_apply_steam(particles)
	return particles
