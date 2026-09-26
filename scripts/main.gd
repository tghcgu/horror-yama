class_name Main
extends Node3D
## ゲームの流れ：山から遠く離れた町のホテルのロビーから始まる。鏡の前で身だしなみを整え、
## 玄関の外の霊峰行きのバスに乗ると、遊ぶたびに形の変わる山へ向かう（ここで山を作る）。
## 樹海・岩場・雪山・霊峰の 4 つの山を越えて、霊峰の頂の祠をめざす。
## 各山の頂上のたき火にたどり着くと火がともり、倒れたときはそこから再開する。
## 夜になると“何か”が下から登ってきて、夜が明けると消える。地帯ごとに別の化け物もいる。
## 最初からやり直すと、ロビーに戻る。

enum RunState { LOBBY, TRAVELING, CLIMBING, RESPAWNING, ENDED }

const RESPAWN_DELAY := 3.0
const LOBBY_POSITION := Vector3(0.0, 400.0, 3000.0)  # 山から遠く離れた場所

var run_state := RunState.LOBBY
var elapsed := 0.0
var deaths := 0
var checkpoint := 0  # 再開するたき火の番号
var next_seed := -1  # 次に作る山の乱数の種（-1 なら毎回ちがう山。自動テストで固定する）
var features: MountainFeatures
var enemies: EnemyDirector
var weather: Weather
var menu: PauseMenu
var appearance: AppearanceMenu
var lobby: Lobby

var _run_id := 0
var _lamp_auto_lit := false
var _highest_biome := 0

@onready var terrain: Terrain = $Terrain
@onready var player: Player = $Player
@onready var stalker: Stalker = $Stalker
@onready var day: DayCycle = $DayCycle
@onready var hud: Hud = $HUD/Overlay
@onready var wind: WindAudio = $Wind


func _ready() -> void:
	lobby = Lobby.new()
	add_child(lobby)
	lobby.global_position = LOBBY_POSITION
	lobby.build(player.get_camera())
	enemies = EnemyDirector.new()
	add_child(enemies)
	enemies.setup(player, terrain, day)
	weather = Weather.new()
	weather.player = player
	weather.day = day
	add_child(weather)
	menu = PauseMenu.new()
	add_child(menu)
	appearance = AppearanceMenu.new()
	add_child(appearance)  # 一時停止メニューより後に置き、Esc を先に受け取る
	add_child(RetroFilter.new())

	stalker.target = player
	hud.player = player
	hud.day = day

	day.night_fell.connect(_on_night_fell)
	day.dawn_broke.connect(_on_dawn)
	stalker.caught.connect(_on_caught)
	player.died.connect(_fall_down)
	player.hurt.connect(hud.flash_hurt)
	player.chilled.connect(hud.flash_cold)
	player.restart_requested.connect(_return_to_lobby)
	player.message.connect(hud.show_notice)
	player.ward_requested.connect(_on_ward_requested)
	player.piton_driven.connect(_on_piton_driven)
	player.rope_requested.connect(_on_rope_requested)
	player.item_thrown.connect(_on_item_thrown)
	menu.restart_requested.connect(_return_to_lobby)
	appearance.closed.connect(func() -> void: player.frozen = false)
	_return_to_lobby()

	if "--autotest" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/dev_autotest.gd").new())


## ゲームを閉じるとき、使い回していたメッシュや素材を先に手放す
func _exit_tree() -> void:
	Shared.clear()


func _process(delta: float) -> void:
	var pos := player.global_position
	var in_lobby := run_state == RunState.LOBBY
	hud.in_lobby = in_lobby
	hud.danger = stalker.danger
	wind.volume_db = lerpf(-4.0, -20.0, stalker.danger)  # 近づかれると、風の音が引いて静かになる
	enemies.set_physics_process(run_state == RunState.CLIMBING)
	weather.enabled = not in_lobby and run_state != RunState.TRAVELING
	day.set_indoor(lobby.contains(pos))
	# ロビーと山は遠く離れているので、いない方は描かない
	lobby.visible = in_lobby or run_state == RunState.TRAVELING
	terrain.visible = not in_lobby
	if features:
		features.visible = not in_lobby

	if in_lobby:
		player.hunger = 0.0
		player.warm = true
		player.in_snow = false
		hud.mirror_hint = lobby.facing_mirror(player.get_camera()) and not appearance.is_open()
		if Input.is_action_just_pressed("interact"):
			if appearance.is_open():
				appearance.close()
			elif hud.mirror_hint:
				appearance.open()
				player.frozen = true
		if lobby.is_boarding(pos):
			_depart()
		return
	hud.mirror_hint = false
	if features == null:
		return

	wind.altitude = clampf(pos.y / terrain.summit_position.y, 0.0, 1.0)
	day.set_biome_fog(Biomes.blend_value(Biomes.FOG_DENSITY, pos), Biomes.blend_color(Biomes.FOG_TINTS, pos))
	var biome := Biomes.at(pos)
	player.in_snow = biome == Biomes.Id.SNOW
	player.night = day.is_night
	player.warm = features.campfires.any(func(c: Campfire) -> bool: return c.is_warming(pos))
	player.compass_target = _next_campfire()
	if not _lamp_auto_lit and day.darkness > 0.45:
		_lamp_auto_lit = true  # 暗くなってきたら一度だけ自動で点ける（あとは F で自由に）
		player.set_headlamp(true)

	if run_state != RunState.CLIMBING:
		return
	elapsed += delta
	_light_campfires(pos)
	if biome > _highest_biome and player.is_on_floor():
		_highest_biome = biome
		hud.show_title(Biomes.NAMES[biome])
	if player.is_on_floor() and pos.y >= terrain.summit_position.y - 2.0:
		_on_summit()


## ホテルのロビーに戻る（最初から、R、一時停止メニューの「最初から」）
func _return_to_lobby() -> void:
	_run_id += 1
	run_state = RunState.LOBBY
	appearance.close()
	player.spawn_at(lobby.spawn_position, lobby.spawn_yaw)  # 鏡のほうを向いて立つ
	player.set_headlamp(false)
	stalker.reset()
	enemies.reset()
	day.reset()
	day.set_running(false)  # ロビーにいるあいだは、時間が止まっている
	hud.set_blackout(false)
	hud.clear_message()
	hud.show_hint()


## バスに乗った。暗転しているあいだに山を作り、登山口に降り立つ
func _depart() -> void:
	run_state = RunState.TRAVELING
	var run := _run_id
	hud.set_blackout(true)
	hud.show_message("霊峰行きのバスに揺られて……", 30.0)
	await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame
	if run != _run_id:
		return
	var seed_value := next_seed if next_seed >= 0 else randi()
	terrain.build(seed_value)
	if features:
		features.queue_free()
	features = MountainFeatures.new()
	add_child(features)
	features.build(terrain, player)
	features.reset_run()
	enemies.prepare(features)
	hud.summit_height = terrain.summit_position.y

	elapsed = 0.0
	deaths = 0
	checkpoint = 0
	_highest_biome = Biomes.Id.FOREST
	_lamp_auto_lit = false
	player.spawn_at(terrain.spawn_point(), 0.0)  # 山（-Z 方向）を向いて降り立つ
	stalker.reset()
	enemies.reset()
	day.reset()
	day.set_running(true)
	await get_tree().create_timer(0.3).timeout
	hud.set_blackout(false)
	hud.show_message("日が沈む前に、山頂のたき火へ", 4.0)
	run_state = RunState.CLIMBING


# --- 持ち物から山に置く物（お札・ハーケン・ロープ・投げたアイテム） ---

func _on_ward_requested(point: Vector3, normal: Vector3) -> void:
	if features:
		features.add_ward(point, normal)


func _on_piton_driven(point: Vector3, normal: Vector3) -> void:
	if features:
		features.add_piton(point, normal)


func _on_rope_requested(top: Vector3, outward: Vector3, length: float) -> void:
	if features:
		features.add_rope(top, outward, length)


func _on_item_thrown(kind: int, origin: Vector3, velocity: Vector3, activated: bool) -> void:
	if features:
		features.spawn_item(kind, origin, velocity, activated)


## 方位磁石が指す、まだ火をともしていない次のたき火（全部ともしたら山頂の祠）
func _next_campfire() -> Vector3:
	for i in range(checkpoint + 1, features.campfires.size()):
		if not features.campfires[i].lit:
			return features.campfires[i].global_position
	return terrain.summit_position


## 近づいたたき火に火をともし、そこを再開地点にする
func _light_campfires(pos: Vector3) -> void:
	for i in features.campfires.size():
		var campfire := features.campfires[i]
		if campfire.lit or campfire.global_position.distance_to(pos) > Campfire.LIGHT_DISTANCE:
			continue
		campfire.set_lit(true)
		checkpoint = maxi(checkpoint, i)
		player.stamina = player.max_stamina()
		hud.show_title("たき火")


func _on_night_fell() -> void:
	stalker.hunt(day.night_count)
	hud.show_message("……下から、何かが登ってくる", 4.0)


func _on_dawn() -> void:
	stalker.retreat()
	_lamp_auto_lit = false
	hud.show_title("夜明け")


func _on_summit() -> void:
	run_state = RunState.ENDED
	stalker.retreat()
	hud.show_message("登頂　タイム %s　倒れた回数 %d　（R でロビーへ）" % [Hud.format_time(elapsed), deaths], 15.0)


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
	_fall_down()


## 倒れた（転落・捕まった・力尽きた）。暗転して、最後に火をともしたたき火から再開する
func _fall_down() -> void:
	if run_state != RunState.CLIMBING:
		return
	run_state = RunState.RESPAWNING
	deaths += 1
	player.frozen = true
	var run := _run_id
	await get_tree().create_timer(0.6).timeout
	hud.set_blackout(true)
	await get_tree().create_timer(RESPAWN_DELAY - 0.6).timeout
	if run != _run_id:  # 待っている間にロビーへ戻っていたら、何もしない
		return
	var campfire := features.campfires[checkpoint]
	player.respawn_at(campfire.global_position + Vector3(0.0, 0.5, 1.8), 0.0)
	stalker.reset()
	if day.is_night:
		stalker.hunt(day.night_count)
	enemies.reset()
	hud.set_blackout(false)
	run_state = RunState.CLIMBING
