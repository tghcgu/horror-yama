class_name Main
extends Node3D
## ゲームの流れ：夕方にふもとからスタート → 樹海・岩場・雪原を登って、山頂の祠をめざす。
## 日が沈むと“何か”が下から登ってくる。地帯ごとに別の化け物もいる。

enum RunState { CLIMBING, ENDED }

const RESTART_DELAY := 3.0

var run_state := RunState.CLIMBING
var elapsed := 0.0
var features: MountainFeatures
var enemies: EnemyDirector
var weather: Weather
var menu: PauseMenu

var _start_position := Vector3.ZERO
var _run_id := 0
var _lamp_auto_lit := false
var _highest_biome := 0
var _campfire_light: OmniLight3D

@onready var terrain: Terrain = $Terrain
@onready var player: Player = $Player
@onready var stalker: Stalker = $Stalker
@onready var day: DayCycle = $DayCycle
@onready var hud: Hud = $HUD/Overlay
@onready var wind: WindAudio = $Wind


func _ready() -> void:
	_start_position = terrain.spawn_point()
	_add_campfire(_start_position + Vector3(2.5, 0.0, 1.5))
	features = MountainFeatures.new()
	add_child(features)
	features.build(terrain, player)
	enemies = EnemyDirector.new()
	add_child(enemies)
	enemies.setup(player, terrain, day)
	weather = Weather.new()
	weather.player = player
	weather.day = day
	add_child(weather)
	menu = PauseMenu.new()
	add_child(menu)
	add_child(RetroFilter.new())

	stalker.target = player
	hud.player = player
	hud.day = day
	hud.summit_height = terrain.summit_position.y

	day.night_fell.connect(_on_night_fell)
	stalker.caught.connect(_on_caught)
	player.died.connect(_on_player_died)
	player.hurt.connect(hud.flash_hurt)
	player.chilled.connect(hud.flash_cold)
	player.restart_requested.connect(_start_run)
	player.ward_requested.connect(features.add_ward)
	player.piton_driven.connect(features.add_piton)
	menu.restart_requested.connect(_start_run)
	_start_run()

	if "--autotest" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/dev_autotest.gd").new())


func _process(delta: float) -> void:
	_campfire_light.light_energy = 2.2 + 0.35 * sin(Time.get_ticks_msec() * 0.013) + randf() * 0.25
	var altitude := player.global_position.y
	wind.altitude = clampf(altitude / terrain.summit_position.y, 0.0, 1.0)
	wind.volume_db = lerpf(-4.0, -20.0, stalker.danger)  # 近づかれると、風の音が引いて静かになる
	hud.danger = stalker.danger
	day.set_biome_fog(Biomes.blend_value(Biomes.FOG_DENSITY, altitude), Biomes.blend_color(Biomes.FOG_TINTS, altitude))
	if not _lamp_auto_lit and day.darkness > 0.45:
		_lamp_auto_lit = true  # 暗くなってきたら一度だけ自動で点ける（あとは F で自由に）
		player.set_headlamp(true)
	if run_state != RunState.CLIMBING:
		return
	elapsed += delta
	var biome := Biomes.at(altitude)
	if biome > _highest_biome and player.is_on_floor():
		_highest_biome = biome
		hud.show_title(Biomes.NAMES[biome])
	if player.is_on_floor() and altitude >= terrain.summit_position.y - 2.0:
		_on_summit()


func _start_run() -> void:
	_run_id += 1
	run_state = RunState.CLIMBING
	elapsed = 0.0
	_highest_biome = Biomes.Id.FOREST
	player.spawn_at(_start_position, 0.0)  # 山（-Z 方向）を向いてスタート
	player.set_headlamp(false)
	_lamp_auto_lit = false
	stalker.reset()
	enemies.reset()
	features.reset_run()
	day.reset()
	day.set_process(true)
	hud.set_blackout(false)
	hud.show_hint()
	hud.show_message("日が沈む前に、できるだけ高く登れ", 4.0)


func _on_night_fell() -> void:
	stalker.activate()
	hud.show_message("……下から、何かが登ってくる", 4.0)


func _on_summit() -> void:
	run_state = RunState.ENDED
	stalker.stop()
	day.set_process(false)
	var title := "逃げ切った" if day.is_night else "登頂"
	hud.show_message("%s　タイム %s　（R でもう一度）" % [title, Hud.format_time(elapsed)], 12.0)


func _on_caught() -> void:
	player.frozen = true
	# “何か”のいる方へ振り向かせ、その目の前に飛び込ませる
	var eye := player.get_camera().global_position
	var direction := (stalker.head_position() - eye).normalized()
	player.face_point(eye + direction)
	stalker.lunge_at(eye, direction)
	player.flicker_out()  # 暗闇の中で、光る目と口だけが迫ってくる
	player.add_shake(1.2)
	hud.flash_hurt()
	_end_run()


func _on_player_died() -> void:
	_end_run()


func _end_run() -> void:
	if run_state != RunState.CLIMBING:
		return
	run_state = RunState.ENDED
	day.set_process(false)
	stalker.stop()
	var run := _run_id
	await get_tree().create_timer(0.6).timeout
	hud.set_blackout(true)
	await get_tree().create_timer(RESTART_DELAY - 0.6).timeout
	if run == _run_id:  # 待っている間に R で再スタートしていなければ
		_start_run()


func _add_campfire(pos: Vector3) -> void:
	pos.y = terrain.height_at(pos.x, pos.z)
	var campfire := Node3D.new()
	campfire.position = pos
	add_child(campfire)
	for i in 3:
		var wood := CylinderMesh.new()
		wood.top_radius = 0.07
		wood.bottom_radius = 0.07
		wood.height = 0.9
		var piece := _make_mesh(wood, Color(0.25, 0.16, 0.1))
		piece.rotation = Vector3(deg_to_rad(80.0), i * TAU / 3.0, 0.0)
		piece.position.y = 0.12
		campfire.add_child(piece)
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.18
	flame_mesh.height = 0.45
	var flame := _make_mesh(flame_mesh, Color(1.0, 0.55, 0.15), true)
	flame.position.y = 0.3
	campfire.add_child(flame)
	_campfire_light = OmniLight3D.new()
	_campfire_light.light_color = Color(1.0, 0.55, 0.25)
	_campfire_light.omni_range = 14.0
	_campfire_light.shadow_enabled = true
	_campfire_light.position.y = 0.8
	campfire.add_child(_campfire_light)


func _make_mesh(mesh: PrimitiveMesh, color: Color, glowing := false) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glowing:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance
