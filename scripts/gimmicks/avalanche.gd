class_name Avalanche
extends Node3D
## 雪山の雪崩。雪山にいると、ときどき山の上からゴゴゴゴと地鳴りが近づいてきて、雪の壁が斜面を駆け下りてくる。
## 飲み込まれると押し流されて体が冷える。壁にしがみついていれば耐えられるかもしれない。
## ハーケンでぶら下がっていれば、びくともしない。

const INTERVAL := Vector2(55.0, 85.0)
const WARNING := 4.5
const SPEED := 14.0
const START_DISTANCE := 45.0
const WIDTH := 28.0
const CLIMB_STAMINA_LOSS := 60.0
const CHILL := 15.0

var player: Player
var terrain: Terrain
var phase := "idle"

var _timer := 0.0
var _start := Vector3.ZERO  # 地鳴りが始まったときにプレイヤーがいた場所
var _direction := Vector3.FORWARD
var _travel := 0.0
var _hit := false
var _wave: Node3D
var _rumble: AudioStreamPlayer


func setup(owner_player: Player, mountain: Terrain) -> void:
	player = owner_player
	terrain = mountain
	_timer = randf_range(INTERVAL.x * 0.5, INTERVAL.y)
	_rumble = AudioStreamPlayer.new()
	_rumble.stream = Sfx.rumble()
	_rumble.volume_db = -30.0
	add_child(_rumble)
	_wave = Node3D.new()
	_wave.visible = false
	add_child(_wave)
	var puff := QuadMesh.new()
	puff.size = Vector2(1.6, 1.6)
	puff.material = CreatureKit.puff_material(Color(0.95, 0.96, 1.0, 0.8))
	var particles := CPUParticles3D.new()
	particles.amount = 260
	particles.lifetime = 1.2
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(WIDTH * 0.5, 1.5, 1.0)
	particles.direction = Vector3(0.0, 0.6, -1.0)
	particles.spread = 40.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 6.0
	particles.gravity = Vector3(0.0, -3.0, 0.0)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 4.0
	particles.mesh = puff
	particles.color_ramp = CreatureKit.fade_ramp()
	particles.local_coords = true
	_wave.add_child(particles)


func _physics_process(delta: float) -> void:
	if player == null or player.frozen:
		_stop()
		return
	var in_snow := Biomes.at(player.global_position) == Biomes.Id.SNOW
	match phase:
		"idle":
			if in_snow:
				_timer -= delta
				if _timer <= 0.0:
					start()
		"warning":
			_timer -= delta
			_rumble.volume_db = lerpf(-4.0, -24.0, _timer / WARNING)
			player.add_shake(0.15 * (1.0 - _timer / WARNING))
			if _timer <= 0.0:
				phase = "rushing"
				_wave.visible = true
		"rushing":
			_travel += SPEED * delta
			var front := _origin() + _direction * _travel
			front.y = terrain.height_at(front.x, front.z) + 1.0
			_wave.global_position = front
			_wave.look_at(front + _direction, Vector3.UP)
			player.add_shake(0.5)
			# 雪の壁がプレイヤーのところを通り過ぎる瞬間
			var ahead := (player.global_position - _origin()).dot(_direction)
			var side := absf((player.global_position - _origin()).dot(_direction.cross(Vector3.UP)))
			if not _hit and _travel >= ahead and side < WIDTH * 0.5:
				_hit = true
				engulf()
			if _travel > START_DISTANCE * 2.2:
				_stop()


## 地鳴りが始まる。雪崩は、雪山の頂上の方からプレイヤーに向かって下りてくる
func start() -> void:
	phase = "warning"
	_timer = WARNING
	_travel = 0.0
	_hit = false
	_start = player.global_position
	var summit := terrain.checkpoint(Biomes.Id.SNOW)
	var down := player.global_position - summit
	down.y = 0.0
	_direction = down.normalized() if down.length() > 1.0 else Vector3.BACK
	_rumble.play()


## 雪崩が下り始める場所（プレイヤーのいた場所から、山の上へ START_DISTANCE）
func _origin() -> Vector3:
	return _start - _direction * START_DISTANCE


## 飲み込まれた
func engulf() -> void:
	if player.clipped:
		player.add_shake(0.8)
		return
	player.chill(CHILL)
	if player.state == Player.State.CLIMB:
		player.stamina = maxf(player.stamina - CLIMB_STAMINA_LOSS, 0.0)
		if player.stamina <= 0.0:
			player.exhausted = true
		return
	player.shove(_direction * 11.0 + Vector3.UP * 3.0)


func _stop() -> void:
	if phase == "idle":
		return
	phase = "idle"
	_timer = randf_range(INTERVAL.x, INTERVAL.y)
	_wave.visible = false
	_rumble.stop()
