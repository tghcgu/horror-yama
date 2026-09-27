class_name Puffball
extends Node3D
## 樹海の大きなホコリタケ。近づくと胞子をぶわっと吹き出し、吸いこむと目がくらみ、息が上がる。

const TRIGGER_RADIUS := 1.8
const COOLDOWN := 8.0
const SPORE_TIME := 8.0

var player: Player

var _cooldown := 0.0
var _cloud: LazyParticles
var _caps: MeshInstance3D
var _sound: AudioStreamPlayer3D


func setup(pos: Vector3, owner_player: Player) -> void:
	player = owner_player
	global_position = pos
	var caps := MeshBuilder.new()
	var ball := CreatureKit.sphere(1.0)
	ball.radial_segments = 8
	ball.rings = 5
	for i in randi_range(3, 5):
		var r := randf_range(0.15, 0.32)
		var angle := randf() * TAU
		caps.add(ball, Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.0, 0.5) + Vector3.UP * r * 0.8, Vector3.ZERO,
			Vector3(r, r * 0.85, r), Color(0.85, 0.8, 0.68))
	_caps = caps.instance(self, Psx.vertex_material())
	_cloud = LazyParticles.new()
	add_child(_cloud)
	_cloud.setup(_make_cloud)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.blast()
	_sound.pitch_scale = 2.2
	_sound.volume_db = -8.0
	add_child(_sound)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0 or player == null or player.frozen:
		return
	if player.global_position.distance_to(global_position) < TRIGGER_RADIUS:
		burst()


func burst() -> void:
	_cooldown = COOLDOWN
	_cloud.get_particles().restart()
	_sound.play()
	player.effects["spores"] = SPORE_TIME
	var tween := _caps.create_tween()
	tween.tween_property(_caps, "scale", Vector3(1.2, 0.65, 1.2), 0.08)
	tween.tween_property(_caps, "scale", Vector3.ONE, 0.6)


## 粒子を作る（LazyParticles が、使うときにだけ呼ぶ）
func _make_cloud() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.explosiveness = 0.8
	particles.amount = 40
	particles.lifetime = 2.5
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.initial_velocity_min = 0.8
	particles.initial_velocity_max = 2.0
	particles.gravity = Vector3(0.0, -0.3, 0.0)
	particles.damping_min = 1.0
	particles.damping_max = 1.5
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	var puff := QuadMesh.new()
	puff.size = Vector2(0.35, 0.35)
	puff.material = CreatureKit.puff_material(Color(0.78, 0.78, 0.42, 0.6))
	particles.mesh = puff
	particles.color_ramp = CreatureKit.fade_ramp()
	particles.position.y = 0.3
	return particles
