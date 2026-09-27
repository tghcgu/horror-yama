class_name Main
extends Node3D
## ゲームの流れ：山から遠く離れた町はずれの登山訓練場から始まる。登る練習や道具の練習をし、姿見の前で身だしなみを整え、
## 南のバス乗り場の霊峰行きのバスに乗ると、山へ向かう（ここで山を作る）。
## 樹海・岩場・雪山・霊峰の 4 つの山を越えて、霊峰の頂の祠をめざす。
## 各山の頂上のたき火にたどり着くと火がともり、倒れたときはそこから再開する。
## 最後の山（霊峰）では、夜になると“何か”が下から登ってきて、夜が明けると消える。地帯ごとに別の化け物もいる。
## 最初からやり直すと、ロビーに戻る。

enum RunState { LOBBY, TRAVELING, CLIMBING, RESPAWNING, ENDED }

const RESPAWN_DELAY := 3.0
const LOBBY_POSITION := Vector3(0.0, 400.0, 3000.0)  # 山から遠く離れた場所

var run_state := RunState.LOBBY
var elapsed := 0.0
var deaths := 0
var checkpoint := 0  # 再開するたき火の番号
const WORLD_SEED := 20260926  # 山はいつも同じ（遊ぶたびに変えると、ほころびが出やすいので、ひとつを作りこむ）
var next_seed := -1  # テスト用：これが 0 以上なら、その種で山を作る
var features: MountainFeatures
var enemies: EnemyDirector
var weather: Weather
var menu: PauseMenu
var appearance: AppearanceMenu
var lobby: Lobby

var _run_id := 0
var _gust: AudioStreamPlayer
var emote_wheel: EmoteWheel
var critters: CritterDirector
var fog: FogBanks  # まだ行けないステージを隠す霧
var _fog_warning := 0.0
var _fog_safe := Vector3.INF  # 霧の外で、最後に立っていた場所
var buddy: Player  # テスト用の、仲間のダミー（F2 で呼ぶ）
var _lamp_auto_lit := false
var _highest_biome := 0
var _unlocking := {}  # 霧が晴れる準備をしている（次のステージを作っている）ステージ

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
	emote_wheel = EmoteWheel.new()
	emote_wheel.player = player
	add_child(emote_wheel)
	critters = CritterDirector.new()
	add_child(critters)
	critters.setup(player, terrain, day)
	fog = FogBanks.new()
	add_child(fog)

	terrain.watch = player  # 当たり判定は、プレイヤーのまわりに作っていく
	terrain.process_physics_priority = -10  # プレイヤーより先に、足もとの地面を用意する
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
	_gust = AudioStreamPlayer.new()
	_gust.stream = Sfx.gust()
	add_child(_gust)
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
	if Input.is_action_just_pressed("buddy") and not player.frozen:
		spawn_buddy()
	wind.volume_db = lerpf(-4.0, -20.0, stalker.danger)  # 近づかれると、風の音が引いて静かになる
	enemies.set_physics_process(run_state == RunState.CLIMBING)
	critters.enabled = run_state == RunState.CLIMBING
	weather.enabled = not in_lobby and run_state != RunState.TRAVELING
	day.set_indoor(lobby.contains(pos))
	# ロビーと山は遠く離れているので、いない方は描かない
	lobby.visible = in_lobby or run_state == RunState.TRAVELING
	terrain.visible = not in_lobby
	if features:
		features.visible = not in_lobby
	fog.update(day.fog_color(), delta, not in_lobby)

	if in_lobby:
		player.hunger = 0.0
		player.warm = true
		player.in_snow = false
		player.injury = 0.0  # 訓練場では、落ちてもケガをしない
		player.cold = 0.0
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
	player.altitude_drain = MountainChain.CLIMB_DRAIN[biome]  # 後ろのステージほど空気が薄く、登ると疲れる
	player.night = day.is_night
	player.warm = features.campfires.any(func(c: Campfire) -> bool: return c.is_warming(pos))
	player.compass_target = _next_campfire()
	critters.guide_target = player.compass_target  # 白ぎつねが案内する先
	# まだ行けないステージの霧：奥へ入りこもうとすると押し戻され、深く入りこむと、元の場所へ連れ戻される
	_fog_warning -= delta
	var push := fog.push_back(pos) if not player.flying else Vector3.ZERO
	var sea := _sea_push(pos)
	if sea != Vector3.ZERO and run_state == RunState.CLIMBING:
		player.zone_push += sea
		if terrain.sea_depth(pos.x, pos.z) > 2.6 and _fog_safe.is_finite():
			player.return_to(_fog_safe)
			hud.show_notice("波にのまれて……気がつくと、砂浜に打ち上げられていた")
			_fog_warning = 6.0
		elif _fog_warning <= 0.0:
			_fog_warning = 6.0
			hud.show_notice("海は荒れていて、泳いでは戻れない……")
	elif push == Vector3.ZERO:
		if player.is_on_floor():
			_fog_safe = pos
		if run_state == RunState.CLIMBING and fog.at_wall(pos) and _fog_warning <= 0.0:
			_fog_warning = 6.0
			hud.show_notice("見えない何かにはばまれて、先へ進めない……山頂のたき火に火をともさないと")
		elif run_state == RunState.CLIMBING and fog.at_seal(pos) and _fog_warning <= 0.0:
			_fog_warning = 6.0
			hud.show_notice("来た道は、深い霧に閉ざされている。もう戻れない……")
	elif run_state == RunState.CLIMBING:
		if (fog.depth_into(pos) > FogBanks.LOST_DEPTH or fog.behind_wall(pos)) and _fog_safe.is_finite():
			player.return_to(_fog_safe)
			hud.show_notice("霧に巻かれて……気がつくと、元の場所に戻っていた")
			_fog_warning = 6.0
		else:
			player.zone_push += push
			if _fog_warning <= 0.0:
				_fog_warning = 6.0
				hud.show_notice("霧が深すぎて、この先へは進めない……")
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
	if buddy:
		buddy.queue_free()
		buddy = null

	run_state = RunState.LOBBY
	appearance.close()
	player.spawn_at(lobby.spawn_position, lobby.spawn_yaw)  # 鏡のほうを向いて立つ
	player.set_headlamp(false)
	stalker.reset()
	enemies.reset()
	critters.clear()
	day.reset()
	day.set_running(false)  # ロビーにいるあいだは、時間が止まっている
	hud.set_blackout(false)
	hud.clear_message()
	hud.show_hint()


## バスに乗った。暗転しているあいだに山を作り、登山口に降り立つ
func _depart() -> void:
	run_state = RunState.TRAVELING
	lobby.clear_practice()  # 訓練場で使った道具は、置いていく
	var run := _run_id
	hud.set_blackout(true)
	hud.show_message("ヘリで、霊峰へ向かう……", 30.0)
	await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame
	if run != _run_id:
		return
	var seed_value := next_seed if next_seed >= 0 else WORLD_SEED
	terrain.build(seed_value)
	if features:
		features.queue_free()
	features = MountainFeatures.new()
	add_child(features)
	features.build(terrain, player)
	features.build_stage(0)  # 最初のステージだけを作る（ほかのステージは、霧が晴れるときに作る）
	enemies.prepare(features)
	terrain.begin_run()  # 最初のステージだけが霧の外にある状態で始める
	_unlocking.clear()
	fog.setup()
	_fog_safe = terrain.spawn_point()
	hud.summit_height = terrain.summit_position.y

	elapsed = 0.0
	deaths = 0
	checkpoint = 0
	_highest_biome = Biomes.Id.FOREST
	_lamp_auto_lit = false
	# ヘリが墜落する（暗転のまま、揺れと音だけで）
	hud.show_message("……突然、機体が大きくゆれ、警報が鳴りひびいた", 3.0)
	player.add_shake(0.8)
	await get_tree().create_timer(1.2).timeout
	_crash_sound()
	player.add_shake(1.5)
	hud.show_message("墜落した……", 3.0)
	await get_tree().create_timer(1.2).timeout
	if run != _run_id:
		return
	player.spawn_at(terrain.spawn_point(), terrain.spawn_yaw())  # 島の砂浜で目を覚まし、山のほうを向いている
	stalker.reset()
	enemies.reset()
	day.reset()
	day.set_running(true)
	await get_tree().create_timer(0.3).timeout
	hud.set_blackout(false)
	hud.show_message("気がつくと、見知らぬ島の浜辺に倒れていた。山を越え、頂上から救助を呼ぶしかない", 6.0)
	run_state = RunState.CLIMBING


## 墜落の音：金属のひしゃげる音と、衝撃
func _crash_sound() -> void:
	for stream: AudioStream in [Sfx.bang(), Sfx.clang(), Sfx.crumble()]:
		var sound := AudioStreamPlayer.new()
		sound.stream = stream
		sound.volume_db = -2.0
		add_child(sound)
		sound.play()
		sound.finished.connect(sound.queue_free)


## 島のまわりの海：波打ち際より先の深い所へは、泳いでは戻れない（押し戻され、深く入ると砂浜へ連れ戻される）
func _sea_push(pos: Vector3) -> Vector3:
	var depth := terrain.sea_depth(pos.x, pos.z)
	if depth <= 0.0 or player.flying:
		return Vector3.ZERO
	player.zone_slow = minf(player.zone_slow, 0.65)  # 水の中は、歩きにくい
	if depth < 0.9:
		return Vector3.ZERO
	var start := MountainChain.plain_starts[0]
	var inland := (MountainChain.plain_ends[0] - start).normalized()
	return Vector3(inland.x, 0.0, inland.y) * clampf(2.5 + (depth - 0.9) * 2.5, 0.0, 8.0)


# --- 持ち物から山に置く物（お札・ハーケン・ロープ・投げたアイテム） ---

## 道具を置く先（訓練場にいる間は訓練場、山にいる間は山）
func _item_host() -> Node:
	return lobby if run_state == RunState.LOBBY else features


func _on_ward_requested(point: Vector3, normal: Vector3) -> void:
	var host := _item_host()
	if host:
		host.call("add_ward", point, normal)


func _on_piton_driven(point: Vector3, normal: Vector3) -> void:
	var host := _item_host()
	if host:
		host.call("add_piton", point, normal)


func _on_rope_requested(top: Vector3, outward: Vector3, length: float) -> void:
	var host := _item_host()
	if host:
		host.call("add_rope", top, outward, length)


func _on_item_thrown(kind: int, origin: Vector3, velocity: Vector3, activated: bool) -> void:
	var host := _item_host()
	if host:
		var item: Pickup = host.call("spawn_item", kind, origin, velocity, activated)
		if velocity.length() > Player.THROW_MIN_SPEED * 0.8:
			item.arm(player)  # 投げつけた物は、当たると傷を負わせる（こぼれ落ちた物はちがう）


# --- 霧が晴れる ---

## 山頂に着くと、風が吹き抜けて、その先の霧が晴れていき、次のステージ（平地と山）が見えてくる。
## 次のステージは、ここで初めて作る（少し時間がかかるので、霧に包まれて暗くなっている間に）。
## そして、いま登ってきた山のひとつ前のステージは、霧に閉ざされて戻れなくなり、消える（軽くするため）。
## seal しないなら、前のステージを閉ざさない（テスト用）
func _unlock_stage(stage: int, animate := true, seal := true) -> void:
	if fog.is_opened(stage) or _unlocking.has(stage):
		return
	_unlocking[stage] = true
	var run := _run_id
	if animate:
		hud.show_message("風が吹き抜けて、霧が晴れていく……", 3.0)
		hud.set_blackout(true)
		await get_tree().create_timer(0.7).timeout
		await get_tree().process_frame
		if run != _run_id:
			return
	_build_stage(stage)
	if seal and stage >= 2:
		_seal_stage(stage - 2)
	fog.clear_gate(stage, animate)
	_unlocking.erase(stage)
	if animate:
		hud.set_blackout(false)
		_gust.volume_db = -8.0
		_gust.play()
		hud.show_notice("風が吹き抜けて、霧が晴れていく……")


## ステージの岩と中身を作る
func _build_stage(stage: int) -> void:
	terrain.show_stage(stage)
	features.build_stage(stage)
	enemies.refresh_monsters()


## もう戻れないステージ：その先との境目を霧と見えない壁で閉ざし、岩も中身も消す
func _seal_stage(stage: int) -> void:
	fog.seal_gate(stage + 1)
	terrain.unload_stage(stage)
	features.unload_stage(stage)


## テスト用：すべてのステージの霧を、すぐに晴らす（前のステージは閉ざさない）
func unlock_all_stages() -> void:
	for stage in range(1, MountainChain.COUNT):
		_unlock_stage(stage, false, false)


# --- テスト用：仲間のダミー ---

## 仲間のダミーを呼ぶ。目の前が崖のふちなら、その下の壁にぶら下がった姿で現れる（引き上げを試せる）。
## そうでなければ、となりに立つ。ダミーはつかんだまま離さず、疲れない
func spawn_buddy() -> Player:
	if buddy:
		buddy.queue_free()
	buddy = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	buddy.controlled = false
	buddy.bot_input = {"grab": true}
	add_child(buddy)
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var space := player.get_world_3d().direct_space_state
	var base := player.global_position
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(base + forward * 1.3 + Vector3.UP, base + forward * 1.3 - Vector3.UP * 4.0, Player.TERRAIN_LAYER))
	if ground.is_empty() or (ground.position as Vector3).y < base.y - 1.5:
		# 崖のふち：下の壁を、外側から探す（切り立った所が見つかるまで、少しずつ深く）
		for depth: float in [1.8, 2.6, 3.4, 4.2]:
			var from := base + forward * 3.0 - Vector3.UP * depth
			var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - forward * 4.0, Player.TERRAIN_LAYER))
			if wall.is_empty() or (wall.normal as Vector3).y > 0.6:
				continue
			var normal: Vector3 = wall.normal
			buddy.spawn_at(wall.position + normal * Player.WALL_GAP - Vector3.UP * 1.0, player.rotation.y + PI)
			buddy.call("_start_climb", normal, wall.position)
			return buddy
	buddy.spawn_at(base + player.global_transform.basis.x.normalized() * 1.2, player.rotation.y)
	return buddy


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
		if campfire.lit or not campfire.is_visible_in_tree() or campfire.global_position.distance_to(pos) > Campfire.LIGHT_DISTANCE:
			continue
		campfire.set_lit(true)
		var entering_final := not in_final_stage() and i >= MountainChain.COUNT - 1
		checkpoint = maxi(checkpoint, i)
		if entering_final and day.is_night:
			_start_hunt()  # 夜のうちに最後の山へ入った
		if i >= 1 and i < MountainChain.COUNT:
			_unlock_stage(i)  # 山頂に着いた：次のステージが現れる
		player.stamina = player.max_stamina()
		hud.show_title("たき火")


## 最後の山を登っている（ひとつ手前の山頂のたき火に火をともした）
func in_final_stage() -> bool:
	return checkpoint >= MountainChain.COUNT - 1


func _on_night_fell() -> void:
	if in_final_stage():
		_start_hunt()
	else:
		hud.show_title("夜")


## “何か”が、ふもとから登ってくる（最後の山の夜だけ）
func _start_hunt() -> void:
	stalker.hunt(day.night_count)
	hud.show_message("……下から、何かが登ってくる", 4.0)


func _on_dawn() -> void:
	stalker.retreat()
	_lamp_auto_lit = false
	hud.show_title("夜明け")


func _on_summit() -> void:
	run_state = RunState.ENDED
	stalker.retreat()
	_call_rescue()
	hud.show_message("頂上で救難信号をあげた。救助のヘリが来る——島から脱出した　タイム %s　倒れた回数 %d　（R で訓練場へ）" % [Hud.format_time(elapsed), deaths], 20.0)


## 救助のヘリが、遠くから飛んできて、頂上の上で止まる
func _call_rescue() -> void:
	var summit := terrain.summit_position
	var heli := MeshInstance3D.new()
	heli.mesh = Flora.prop("heli")
	features.add_child(heli)
	var from := summit + Vector3(-160.0, 60.0, 120.0)
	var hover := summit + Vector3(6.0, 14.0, -4.0)
	heli.global_position = from
	heli.look_at(hover, Vector3.UP)
	var light := SpotLight3D.new()  # 探照灯
	light.spot_range = 40.0
	light.spot_angle = 22.0
	light.light_energy = 6.0
	light.position = Vector3(0.0, 0.8, -1.5)
	light.rotation.x = -1.2
	heli.add_child(light)
	var tween := create_tween()
	tween.tween_property(heli, "global_position", hover, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var rotor := AudioStreamPlayer3D.new()
	rotor.stream = Sfx.hum()
	rotor.pitch_scale = 0.35
	rotor.unit_size = 30.0
	rotor.max_distance = 400.0
	heli.add_child(rotor)
	rotor.play()


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
	if day.is_night and in_final_stage():
		stalker.hunt(day.night_count)
	enemies.reset()
	hud.set_blackout(false)
	run_state = RunState.CLIMBING
