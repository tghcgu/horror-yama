extends Node
## 開発用の自動テスト。ゲームを起動したまま各機能を順に試し、結果を表示して終了する。
## 実行例: godot --path . -- --autotest [--shot-dir=<スクリーンショットの保存先>]

var _main: Main
var _shot_dir := ""
var _log := PackedStringArray()
var _failures := 0
var _start_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(12345)
	_main = get_parent() as Main
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.trim_prefix("--shot-dir=")
	_start_msec = Time.get_ticks_msec()
	_main.day.night_fell.connect(_note.bind("night fell"))
	_main.stalker.caught.connect(_note.bind("caught by stalker"))
	_main.player.died.connect(_note.bind("player died"))
	_main.player.hurt.connect(_note.bind("player hurt"))
	_main.player.chilled.connect(_note.bind("player chilled"))
	_run.call_deferred()


func _run() -> void:
	await _wait(0.5)
	if _shot_dir != "":
		await _overview_shot()
		await _biome_shots()
	await _test_climb_and_night()
	await _test_items()
	await _test_piton()
	await _test_ward()
	await _test_spider()
	await _test_peeker()
	await _test_pale_one()
	await _test_menu()
	_finish()


# --- 各テスト ---

## ボットに崖を登らせ、夜にしてから休ませる。“何か”が追いついてくるか
func _test_climb_and_night() -> void:
	_section("climb and night")
	await _restart()
	var player := _main.player
	_main.day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH - 8.0
	Input.action_press("move_forward")
	Input.action_press("grab")
	var max_y := 0.0
	var stalker_max_y := 0.0
	var shot_taken := false
	var caught := false
	for i in 44 * 10:  # 最大 44 秒
		await _wait(0.1)
		max_y = maxf(max_y, player.global_position.y)
		if _main.stalker.active:
			stalker_max_y = maxf(stalker_max_y, _main.stalker.global_position.y)
			if not shot_taken and _main.stalker.global_position.y > 5.0 and _shot_dir != "":
				shot_taken = true
				var head := _main.stalker.head_position()
				var outward := Vector3(head.x, 0.0, head.z).normalized()
				await _shot_from(head + outward * 3.0 + Vector3.UP * 1.0, head - Vector3.UP * 0.5, "stalker.png")
				await _shot_from(head + outward * 2.2 + Vector3.UP * 0.3, head - Vector3.UP * 0.7, "stalker_lit.png", true)
				await _shot_from(head + outward * 0.9, head, "stalker_face.png", true)
		if i == 200:  # 20 秒登ったら、手を止めて休む
			Input.action_release("move_forward")
			Input.action_release("grab")
			_note("bot stops and rests at y=%.1f" % player.global_position.y)
		if player.frozen:
			caught = true
			if _shot_dir != "":
				await _wait(0.15)
				await _save_shot("caught.png")
			break
	Input.action_release("move_forward")
	Input.action_release("grab")
	_check("bot climbed above the first cliff", max_y > 10.0, "max y %.1f" % max_y)
	_check("stalker climbed after nightfall", stalker_max_y > 5.0, "stalker max y %.1f" % stalker_max_y)
	_check("resting bot got caught or died", caught)
	await _wait(3.5)  # 暗転してやり直すのを待つ


func _test_items() -> void:
	_section("items")
	await _restart()
	var player := _main.player
	_check("starting items", str(player.items) == "[1, 0, 0, 1]", str(player.items))
	player.pick_up(Items.Kind.BANDAGE)
	player.injury = 30.0
	player.use_item(Items.Kind.BANDAGE)
	_check("bandage heals injury", player.injury == 0.0 and player.items[Items.Kind.BANDAGE] == 0, "injury %.1f" % player.injury)
	player.pick_up(Items.Kind.ONIGIRI)
	player.stamina = 20.0
	player.use_item(Items.Kind.ONIGIRI)
	_check("onigiri restores stamina", player.stamina >= 69.0 and player.boost_time > 0.0, "stamina %.1f" % player.stamina)
	player.use_item(Items.Kind.PITON)
	_check("piton cannot be used on the ground", player.items[Items.Kind.PITON] == 1)
	var pickups := _main.features.get_children().filter(func(n: Node) -> bool: return n is Pickup)
	_check("pickups placed on the mountain", pickups.size() >= 15, "%d pickups" % pickups.size())
	if _shot_dir != "" and not pickups.is_empty():
		var pickup: Node3D = pickups[0]
		await _shot_from(pickup.global_position + Vector3(1.6, 1.2, 1.6), pickup.global_position + Vector3.UP * 0.3, "pickup.png")


func _test_piton() -> void:
	_section("piton")
	await _restart()
	var player := _main.player
	if not await _climb_onto_first_wall():
		_check("reached a wall for the piton test", false)
		return
	Input.action_release("move_forward")
	player.use_item(Items.Kind.PITON)
	_check("piton clips onto the wall", player.clipped and player.items[Items.Kind.PITON] == 0)
	Input.action_release("grab")
	var y := player.global_position.y
	var stamina := player.stamina
	await _wait(1.5)
	_check("hanging on the piton without holding", player.state == Player.State.CLIMB and absf(player.global_position.y - y) < 0.2,
		"state %s, moved %.2f m" % [Player.State.keys()[player.state], player.global_position.y - y])
	_check("stamina recovers on the piton", player.stamina > stamina, "%.1f -> %.1f" % [stamina, player.stamina])
	if _shot_dir != "":
		await _save_shot("piton.png")


func _test_ward() -> void:
	_section("ward")
	await _restart()
	var player := _main.player
	player.use_item(Items.Kind.OFUDA)
	await _wait(0.2)
	var tree := get_tree()
	_check("ofuda places a ward", tree.get_nodes_in_group(Ward.GROUP).size() == 1)
	_check("ward blocks inside, not outside",
		Ward.blocks(tree, player.global_position) and not Ward.blocks(tree, player.global_position + Vector3(20.0, 0.0, 0.0)))
	_main.stalker.activate()  # 足跡はまだ短いので、“何か”はすぐそばに現れる
	await _wait(2.0)
	_check("stalker cannot catch a player inside the ward", not player.frozen)
	if _shot_dir != "":
		player.face_point(player.global_position + Vector3(0.0, -0.5, -3.0))
		await _save_shot("ward.png")
	_main.stalker.stop()


func _test_spider() -> void:
	_section("crag spider")
	await _restart()
	var spiders := _main.features.get_children().filter(func(n: Node) -> bool: return n is CragSpider)
	_check("spiders placed on the crag walls", spiders.size() >= 6, "%d spiders" % spiders.size())
	if spiders.is_empty():
		return
	var spider: CragSpider = spiders[0]
	var normal: Vector3 = spider.get("_normal")
	if _shot_dir != "":
		await _shot_from(spider.global_position + normal * 2.2 + Vector3.UP * 0.6, spider.global_position, "spider.png", true)
	var player := _main.player
	player.global_position = spider.global_position + normal * 0.45 - Vector3.UP * 1.2
	player.call("_start_climb", normal)
	Input.action_press("grab")
	var injury := player.injury
	await _wait(0.6)
	Input.action_release("grab")
	_check("spider bites a climber nearby", player.injury > injury, "injury %.1f -> %.1f" % [injury, player.injury])


func _test_peeker() -> void:
	_section("peeker")
	await _restart()
	var player := _main.player
	if not await _climb_onto_first_wall():
		_check("reached a wall for the peeker test", false)
		return
	Input.action_release("move_forward")
	var peeker := _main.enemies.peeker
	var spawned := _main.enemies.spawn_peeker()
	_check("peeker appears on the rim above", spawned and peeker.active)
	if not spawned:
		Input.action_release("grab")
		return
	await _wait(2.0)
	player.set_headlamp(true)
	if _shot_dir != "":
		var side := peeker.global_transform.basis.x
		await _shot_from(peeker.head_position() + side * 2.5 + peeker.global_transform.basis.z * -1.0,
			peeker.head_position() - Vector3.UP * 0.3, "peeker_side.png", true)
	player.face_point(peeker.head_position())
	if _shot_dir != "":
		await _save_shot("peeker.png")
	for i in 20:
		player.face_point(peeker.head_position())
		await _wait(0.1)
	_check("headlamp stare repels the peeker", bool(peeker.get("_retreating")) or not peeker.active)
	Input.action_release("grab")


func _test_pale_one() -> void:
	_section("pale one")
	await _restart()
	var player := _main.player
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var spots := _main.terrain.random_ledge_points(rng, 1, Biomes.TOPS[Biomes.Id.CRAG] + 4.0, Biomes.TOPS[Biomes.Id.SNOW] - 4.0, 1.0, 3)
	if spots.is_empty():
		_check("found a snow ledge", false)
		return
	player.spawn_at(spots[0] + Vector3.UP * 0.5, 0.0)
	var pale := _main.enemies.pale_one
	for i in 30:
		await _wait(0.1)
		if pale.active:
			break
	_check("pale one appears in the snow", pale.active)
	if not pale.active:
		return
	if _shot_dir != "":
		var front := -pale.global_transform.basis.z
		await _shot_from(pale.global_position + front * 3.2 + Vector3.UP * 2.3, pale.global_position + Vector3.UP * 2.0, "pale_one_close.png", true)
	# 背を向けると近づいてくる
	var away := player.global_position * 2.0 - pale.global_position
	player.face_point(Vector3(away.x, player.global_position.y + 1.6, away.z))
	var before := pale.global_position.distance_to(player.global_position)
	await _wait(2.0)
	var after := pale.global_position.distance_to(player.global_position)
	_check("pale one approaches while unseen", after < before - 2.0, "%.1f m -> %.1f m" % [before, after])
	# 見ていると動かない
	player.face_point(pale.global_position + Vector3.UP * 1.8)
	await _wait(0.2)
	if pale.call("_is_seen"):
		var watched := pale.global_position
		await _wait(1.5)
		_check("pale one freezes while watched", pale.global_position.distance_to(watched) < 0.05)
	else:
		_note("skip freeze check: the pale one is hidden behind the terrain")
	if _shot_dir != "":
		await _save_shot("pale_one.png")
	# 背を向け続けると触れられる
	away = player.global_position * 2.0 - pale.global_position
	player.face_point(Vector3(away.x, player.global_position.y + 1.6, away.z))
	var injury := player.injury
	for i in 150:
		await _wait(0.1)
		if i % 10 == 0:
			_note("pale one at %s, distance %.1f, active %s" % [pale.global_position.snapped(Vector3.ONE * 0.1),
				pale.global_position.distance_to(player.global_position), pale.active])
		if player.injury > injury:
			break
	_check("pale one chills the player", player.injury > injury, "injury %.1f" % player.injury)


func _test_menu() -> void:
	_section("pause menu")
	_main.menu.open()
	await _wait(0.3)
	_check("menu pauses the game", get_tree().paused)
	if _shot_dir != "":
		await _save_shot("menu.png")
	_main.menu.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_check("closing the menu resumes", not get_tree().paused)


# --- スクリーンショット ---

func _overview_shot() -> void:
	var world := _main.day.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment
	world.environment.fog_enabled = false
	await _shot_from(Vector3(150.0, 120.0, 200.0), Vector3(0.0, 55.0, 0.0), "overview.png")
	world.environment.fog_enabled = true


## 各地帯の足場に立ち、山の外側を見下ろした景色。山頂では祠を見る
func _biome_shots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for biome in Biomes.NAMES.size():
		await _restart()
		var player := _main.player
		if biome == Biomes.Id.SUMMIT:
			var summit := _main.terrain.summit_position
			player.spawn_at(summit + Vector3(0.0, 0.5, 1.5), 0.0)
			player.face_point(summit + Vector3(0.0, 1.0, -5.0))
		else:
			var bottom: float = 4.0 if biome == 0 else Biomes.TOPS[biome - 1] + 3.0
			var spots := _main.terrain.random_ledge_points(rng, 1, bottom, Biomes.TOPS[biome] - 3.0, 1.0, 3)
			if spots.is_empty():
				continue
			player.spawn_at(spots[0] + Vector3.UP * 0.5, 0.0)
			var outward := Vector3(spots[0].x, 0.0, spots[0].z).normalized()
			player.face_point(player.get_camera().global_position + outward * 10.0 - Vector3.UP * 2.5)
		await _wait(2.5)  # 霧の色が切り替わるのを待つ
		await _save_shot("biome_%d.png" % biome)


# --- 道具 ---

func _restart() -> void:
	Input.action_release("move_forward")
	Input.action_release("grab")
	_main.call("_start_run")
	await _wait(0.3)


## 最初の崖に取りつくまで前進する（つかんだまま、少し登った状態で返す）
func _climb_onto_first_wall() -> bool:
	var player := _main.player
	Input.action_press("move_forward")
	Input.action_press("grab")
	for i in 80:
		await _wait(0.1)
		if player.state == Player.State.CLIMB and player.global_position.y > 3.0:
			return true
	return false


## lit を true にすると、形を確認できるようにカメラのそばに一時的な照明を置く
func _shot_from(from: Vector3, look_target: Vector3, file_name: String, lit := false) -> void:
	var camera := Camera3D.new()
	_main.add_child(camera)
	camera.global_position = from
	camera.look_at(look_target)
	camera.make_current()
	if lit:
		var light := OmniLight3D.new()
		light.omni_range = 8.0
		light.light_energy = 1.0
		camera.add_child(light)
		light.position = Vector3(0.6, 0.8, 0.0)
	await _save_shot(file_name)
	camera.queue_free()
	_main.player.get_camera().make_current()


func _save_shot(file_name: String) -> void:
	if _shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file_name))
	_note("screenshot " + file_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _section(title: String) -> void:
	_note("--- " + title)


func _check(title: String, passed: bool, detail := "") -> void:
	if not passed:
		_failures += 1
	_note("%s  %s%s" % ["PASS" if passed else "FAIL", title, ("  (" + detail + ")") if detail != "" else ""])


func _note(text: String) -> void:
	_log.append("%6.1fs  %s" % [(Time.get_ticks_msec() - _start_msec) / 1000.0, text])


func _finish() -> void:
	print("=== AUTOTEST ===")
	for line in _log:
		print(line)
	print("RESULT: %s (%d failed)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
