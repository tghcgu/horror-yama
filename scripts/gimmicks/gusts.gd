class_name Gusts
extends Node3D
## 霊峰の突風（天狗風）。ヒュオオと鳴り始めて 2 秒後、強い風が吹きつける。
## 立っていれば崖の方へ押し流され、登っていればしがみつくだけでスタミナが激しく減る。

const INTERVAL := Vector2(12.0, 22.0)
const WARNING := 2.0
const DURATION := 3.0
const PUSH := 5.5
const CLIMB_DRAIN := 3.5

var player: Player
var phase := "idle"
var direction := Vector3.RIGHT

var _timer := 0.0
var _sound: AudioStreamPlayer
var _streaks: CPUParticles3D


func setup(owner_player: Player) -> void:
	player = owner_player
	_timer = randf_range(INTERVAL.x * 0.5, INTERVAL.y)
	_sound = AudioStreamPlayer.new()
	_sound.stream = Sfx.gust()
	add_child(_sound)
	_streaks = CPUParticles3D.new()
	_streaks.emitting = false
	_streaks.amount = 80
	_streaks.lifetime = 0.8
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_streaks.emission_box_extents = Vector3(8.0, 3.0, 8.0)
	_streaks.gravity = Vector3.ZERO
	_streaks.initial_velocity_min = 14.0
	_streaks.initial_velocity_max = 20.0
	_streaks.spread = 5.0
	var paper := BoxMesh.new()
	paper.size = Vector3(0.05, 0.05, 0.6)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	white.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
	paper.material = white
	_streaks.mesh = paper
	_streaks.particle_flag_align_y = true
	add_child(_streaks)


func _physics_process(delta: float) -> void:
	if player == null or player.frozen:
		return
	var at_summit := Biomes.at(player.global_position) == Biomes.Id.SUMMIT
	_timer -= delta
	match phase:
		"idle":
			if at_summit and _timer <= 0.0:
				phase = "warning"
				_timer = WARNING
				var angle := randf() * TAU
				direction = Vector3(cos(angle), 0.0, sin(angle))
				_sound.play()
		"warning":
			if _timer <= 0.0:
				phase = "blowing"
				_timer = DURATION
				_streaks.direction = direction
				_streaks.emitting = true
		"blowing":
			_streaks.global_position = player.global_position + Vector3.UP * 1.5 - direction * 6.0
			if player.state == Player.State.CLIMB:
				player.zone_climb_drain = maxf(player.zone_climb_drain, CLIMB_DRAIN)
				player.add_shake(0.12)
			elif not player.clipped:
				player.zone_push = direction * PUSH
				player.add_shake(0.08)
			if _timer <= 0.0:
				phase = "idle"
				_timer = randf_range(INTERVAL.x, INTERVAL.y)
				_streaks.emitting = false
