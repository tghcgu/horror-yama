extends Node
## 開発用の自動テスト。ゲームを起動したまま各機能を順に試し、結果を表示して終了する。
## 実行例: godot --path . -- --autotest [--shot-dir=<スクリーンショットの保存先>]

const TEST_SEED := 20260926  # テストでは毎回同じ山を作る

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


## テスト中は本物のマウスを無視する（画面ありで流すと、マウスの動きで視点が回ってしまう）
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()


func _run() -> void:
	await _wait(0.5)
	_main.next_seed = TEST_SEED
	if "--perf" in OS.get_cmdline_user_args():
		await _measure_performance()
		_finish()
		return
	await _test_lobby()
	if _shot_dir != "":
		await _overview_shot()
		await _biome_shots()
	await _test_chain_shape()
	await _test_climb_and_night()
	await _test_checkpoint()
	await _test_afflictions()
	await _test_dawn()
	await _test_items()
	await _test_physics_items()
	await _test_sliding()
	await _test_gimmicks()
	await _test_new_enemies()
	await _test_piton()
	await _test_ward()
	await _test_spider()
	await _test_peeker()
	await _test_pale_one()
	await _test_fly()
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


## ホテルのロビーから始まり、鏡に自分が映り、時間は止まっている。
## 鏡の前で身だしなみの色を変えると体の色が変わる。バスに乗ると山ができて、登山口に降り立つ
func _test_lobby() -> void:
	_section("lobby")
	var player := _main.player
	_check("the game starts in the hotel lobby", _main.run_state == Main.RunState.LOBBY and _main.lobby.contains(player.global_position))
	var time := _main.day.time
	await _wait(1.0)
	_check("time stands still in the lobby", _main.day.time == time)
	if DisplayServer.get_name() != "headless":  # 画面なしでは、鏡の映像は作られない
		var image := _main.lobby.mirror.get("_viewport").get_texture().get_image() as Image
		var center := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
		_check("the mirror reflects something", center.get_luminance() > 0.01, "center %s" % center)
	# 身だしなみ：鏡の前で E を押して、上着の色を変える
	_check("standing in front of the mirror shows the hint", _main.lobby.facing_mirror(player.get_camera()))
	_tap("interact")
	await _wait(0.3)
	_check("E opens the dressing menu", _main.appearance.is_open())
	var jacket := Settings.jacket_color
	_main.appearance.call("_choose", "jacket", (jacket + 3) % Appearance.COLORS.size())
	var body_material: ShaderMaterial = player.get_node("Body").get("_tinted")["jacket"][0]
	var tint: Color = body_material.get_shader_parameter("albedo")
	_check("choosing a color repaints the jacket", tint.is_equal_approx(Appearance.tint_of("jacket")) and Settings.jacket_color != jacket)
	if _shot_dir != "":
		await _save_shot("dressing.png")
	_main.appearance.close()
	await _wait(0.2)
	if _shot_dir != "":
		await _save_shot("lobby_mirror.png")
		var room := _main.lobby
		await _shot_from(room.to_global(Vector3(-5.5, 3.0, 4.6)), room.to_global(Vector3(3.0, 1.2, -1.5)), "lobby_wide.png")
		await _shot_from(room.to_global(Vector3(-3.0, 1.6, 4.8)), room.to_global(Vector3(1.0, 1.5, 12.0)), "lobby_bus.png")
	# 玄関を出て、バスの扉まで行く
	player.global_position = _main.lobby.get("_bus_door") + Vector3(0.0, 0.3, 0.0)
	var departed := await _wait_for_climb()
	_check("boarding the bus builds the mountain and starts the climb", departed)
	var start := _main.terrain.spawn_point()
	_check("arrived at the trailhead", player.global_position.distance_to(start) < 3.0,
		"%.1f m from the trailhead" % player.global_position.distance_to(start))
	if _shot_dir != "":
		player.face_point(player.get_camera().global_position + Vector3(0.0, 0.8, -5.0))
		await _wait(1.5)
		await _save_shot("trailhead.png")


## 山は奥ほど高く、山と山の間には、ひとつ前の山頂より低い谷がある。
## 平らな場所はほとんどなく、崖だらけ。種を変えると、ちがう形の山になる
func _test_chain_shape() -> void:
	_section("mountain chain")
	var terrain := _main.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var walls := 0
	var flats := 0
	var samples := 0
	for i in MountainChain.COUNT:
		for n in 500:
			var angle := rng.randf() * TAU
			var distance := MountainChain.radii[i] * sqrt(rng.randf_range(0.05, 0.8))
			var c := MountainChain.centers[i]
			var normal := terrain.normal_at(c.x + cos(angle) * distance, c.y + sin(angle) * distance)
			samples += 1
			if normal.y < Player.WALL_MAX_NORMAL_Y:
				walls += 1
			elif normal.y > 0.97:
				flats += 1
	_check("mostly cliffs", walls > samples * 0.4, "%d%% cliffs" % (walls * 100 / samples))
	_check("hardly any flat ground", flats < samples * 0.12, "%d%% flat" % (flats * 100 / samples))
	var peaks_here := MountainChain.peaks.duplicate()
	MountainChain.generate(TEST_SEED + 1)
	var different := MountainChain.peaks != peaks_here
	MountainChain.generate(terrain.run_seed)  # 元の山に戻す
	_check("another seed makes another mountain", different)
	var tops: Array[float] = []
	for i in MountainChain.COUNT:
		tops.append(terrain.checkpoint(i).y)
	_note("summits: %s" % str(tops))
	var rising := true
	for i in range(1, tops.size()):
		rising = rising and tops[i] > tops[i - 1] + 30.0
	_check("each mountain is higher than the last", rising)
	for i in MountainChain.COUNT - 1:
		var a: Vector2 = MountainChain.centers[i]
		var b: Vector2 = MountainChain.centers[i + 1]
		var lowest := INF
		for k in range(1, 20):
			var p := a.lerp(b, k / 20.0)
			lowest = minf(lowest, terrain.height_at(p.x, p.y))
		_check("valley between mountain %d and %d" % [i + 1, i + 2], lowest < tops[i] - 8.0, "lowest %.1f" % lowest)
	var campfires := _main.features.campfires
	_check("a campfire on each summit", campfires.size() == MountainChain.COUNT, "%d campfires" % campfires.size())


## 山頂のたき火に着くと火がともり、倒れたらそこから再開する（空腹は増える）
func _test_checkpoint() -> void:
	_section("checkpoint")
	await _restart()
	var player := _main.player
	var campfire := _main.features.campfires[1]
	player.global_position = campfire.global_position + Vector3(0.0, 0.5, 2.0)
	await _wait(0.5)
	_check("reaching the summit lights the campfire", campfire.lit and _main.checkpoint == 1)
	player.hunger = 20.0
	player.injury = 30.0
	player.global_position = Vector3(campfire.global_position.x, -40.0, campfire.global_position.z)  # 谷へ落ちる
	await _wait(3.8)
	var distance := player.global_position.distance_to(campfire.global_position)
	_check("respawn at the lit campfire", distance < 4.0 and not player.frozen, "%.1f m away" % distance)
	_check("respawn heals injury but adds hunger", player.injury == 0.0 and player.hunger >= 34.0,
		"injury %.1f, hunger %.1f" % [player.injury, player.hunger])
	_check("death counted", _main.deaths == 1)


## 空腹は時間でたまり、雪山では冷え、たき火で温まる。上限がなくなると倒れる
func _test_afflictions() -> void:
	_section("afflictions")
	await _restart()
	_calm_weather()
	_calm_enemies()
	var player := _main.player
	var hunger := player.hunger
	await _wait(2.0)
	_check("hunger grows over time", player.hunger > hunger + 0.1, "%.2f -> %.2f" % [hunger, player.hunger])
	player.spawn_at(_main.terrain.checkpoint(Biomes.Id.SNOW) + Vector3(5.0, 0.5, 0.0), 0.0)
	await _wait(2.0)
	_check("cold grows in the snow", player.cold > 0.5, "cold %.2f" % player.cold)
	var campfire := _main.features.campfires[3]
	campfire.set_lit(true)
	player.global_position = campfire.global_position + Vector3(0.0, 0.5, 2.0)
	player.cold = 30.0
	await _wait(1.5)
	_check("a campfire warms you up", player.cold < 20.0, "cold %.1f" % player.cold)
	_check("the summit around the campfire is flat", player.is_on_floor() and player.global_position.distance_to(campfire.global_position) < 4.0)
	player.hunger = Player.MAX_HUNGER
	player.injury = 10.0
	await _wait(0.5)
	_check("collapse when afflictions fill the bar", player.frozen)
	await _wait(3.5)


## 夜が明けると“何か”は姿を消し、次の夜にまた現れる
func _test_dawn() -> void:
	_section("dawn")
	await _restart()
	var day := _main.day
	if _shot_dir != "":
		# 夕暮れと夜の景色（空・星・ヘッドライトの光の筋）
		var campfire := _main.features.campfires[1]
		_main.player.global_position = campfire.global_position + Vector3(0.0, 0.5, 2.0)
		_main.player.face_point(_main.player.get_camera().global_position + Vector3(0.6, -0.15, 1.0))
		day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH * 0.5
		await _wait(2.0)
		await _save_shot("dusk.png")
		day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH + 20.0
		_main.player.set_headlamp(true)
		_main.player.face_point(_main.player.get_camera().global_position + Vector3(0.5, 0.35, 1.0))
		await _wait(1.0)
		await _save_shot("night_sky.png")
		_main.player.face_point(_main.player.get_camera().global_position + Vector3(0.3, -0.3, 1.0))
		await _wait(0.5)
		await _save_shot("night_headlamp.png")
		await _restart()
	day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH + 0.5
	await _wait(0.3)
	_check("night falls", day.is_night and _main.stalker.hunting)
	day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH + DayCycle.NIGHT_LENGTH + 0.5
	await _wait(0.3)
	_check("dawn sends the stalker away", not day.is_night and not _main.stalker.hunting and not _main.stalker.active)
	day.time = DayCycle.CYCLE + DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH + 0.5
	await _wait(0.3)
	_check("the second night comes", day.is_night and day.night_count == 2)


func _test_items() -> void:
	_section("items")
	await _restart()
	var player := _main.player
	var inventory := player.inventory
	_check("starting items", inventory.count_of(Items.Kind.PITON) == 1 and inventory.count_of(Items.Kind.ONIGIRI) == 1,
		"%s %s" % [inventory.kinds, inventory.counts])
	player.pick_up(Items.Kind.BANDAGE)
	player.injury = 30.0
	player.use_item(Items.Kind.BANDAGE)
	_check("bandage heals injury", player.injury == 0.0 and inventory.count_of(Items.Kind.BANDAGE) == 0, "injury %.1f" % player.injury)
	player.hunger = 40.0
	player.stamina = 20.0
	player.use_item(Items.Kind.ONIGIRI)
	_check("onigiri restores stamina and hunger", player.stamina >= 59.0 and player.boost_time > 0.0 and player.hunger <= 5.0,
		"stamina %.1f, hunger %.1f" % [player.stamina, player.hunger])
	player.use_item(Items.Kind.PITON)
	_check("piton cannot be used on the ground", inventory.count_of(Items.Kind.PITON) == 1)
	var pickups := _main.features.get_children().filter(func(n: Node) -> bool: return n is Pickup)
	_check("pickups placed on the mountains", pickups.size() >= 20, "%d pickups" % pickups.size())
	var kinds := {}
	for pickup: Pickup in pickups:
		kinds[pickup.kind] = true
	_check("many kinds of items are found", kinds.size() >= 10, "%d kinds" % kinds.size())
	# 持ち物の欄：同じ種類は 3 つまで重なり、6 つの欄がいっぱいになると拾えない
	for kind in [Items.Kind.CHOCOLATE, Items.Kind.CHOCOLATE, Items.Kind.CHOCOLATE, Items.Kind.CHOCOLATE]:
		player.pick_up(kind)
	_check("items stack up to 3 per slot", inventory.count_of(Items.Kind.CHOCOLATE) == 4 and inventory.counts[inventory.slot_of(Items.Kind.CHOCOLATE)] == 3)
	for kind in [Items.Kind.SALT, Items.Kind.ROPE, Items.Kind.CHALK]:
		player.pick_up(kind)
	_check("a full inventory refuses more", not player.pick_up(Items.Kind.CANNED))
	# いろいろなアイテムの効き目
	player.cold = 30.0
	player.pick_up(Items.Kind.HAND_WARMER)
	inventory.remove(Items.Kind.CHALK)
	player.pick_up(Items.Kind.HAND_WARMER)
	player.use_item(Items.Kind.HAND_WARMER)
	_check("hand warmer warms you", player.cold == 0.0 and player.has_effect("warmer"))
	player.use_item(Items.Kind.CHOCOLATE)
	_check("chocolate is eaten", inventory.count_of(Items.Kind.CHOCOLATE) == 3)
	inventory.clear()
	for kind in [Items.Kind.ENERGY, Items.Kind.COMPASS, Items.Kind.BELL, Items.Kind.FIRST_AID, Items.Kind.CRAMPONS, Items.Kind.MUSHROOM]:
		player.pick_up(kind)
	player.stamina = 10.0
	player.use_item(Items.Kind.ENERGY)
	_check("energy drink refills stamina", player.stamina >= player.max_stamina() - 0.1 and player.has_effect("crash"))
	player.use_item(Items.Kind.COMPASS)
	await _wait(0.2)
	_check("compass points to the next campfire", player.has_effect("compass") and inventory.count_of(Items.Kind.COMPASS) == 1
		and player.compass_target.distance_to(_main.features.campfires[1].global_position) < 0.5)
	player.use_item(Items.Kind.BELL)
	_check("bell rings until stopped", player.bell_ringing and inventory.count_of(Items.Kind.BELL) == 1)
	player.use_item(Items.Kind.BELL)
	player.injury = 20.0
	player.cold = 20.0
	player.use_item(Items.Kind.FIRST_AID)
	_check("first aid kit treats injury and cold", player.injury == 0.0 and player.cold == 0.0)
	player.use_item(Items.Kind.CRAMPONS)
	player.use_item(Items.Kind.MUSHROOM)
	_check("crampons and a mushroom", player.has_effect("crampons") and inventory.count_of(Items.Kind.MUSHROOM) == 0)
	if _shot_dir != "":
		for kind in [Items.Kind.ROPE, Items.Kind.FLARE, Items.Kind.FIRECRACKER, Items.Kind.SALT, Items.Kind.OMAMORI, Items.Kind.CHALK]:
			player.pick_up(kind)
		await _wait(0.3)
		await _save_shot("hotbar.png")
	if _shot_dir != "" and not pickups.is_empty():
		var pickup: Node3D = pickups[0]
		await _shot_from(pickup.global_position + Vector3(1.6, 1.2, 1.6), pickup.global_position + Vector3.UP * 0.3, "pickup.png")


## 投げたアイテムは物理で飛んで転がり、見ながら E で拾える。火をつけた発煙筒・爆竹・塩は効き目を出す。
## お守りは転落死から一度だけ守る。ロープは楽に登れる
func _test_physics_items() -> void:
	_section("physics items")
	await _restart()
	var player := _main.player
	var inventory := player.inventory
	player.pick_up(Items.Kind.CHOCOLATE)
	inventory.selected = inventory.slot_of(Items.Kind.CHOCOLATE)
	player.face_point(player.get_camera().global_position + Vector3(0.0, 0.3, -1.0))
	var before := _pickups()
	player.throw_selected()
	await _wait(0.1)
	var thrown := _pickups().filter(func(p: Pickup) -> bool: return not before.has(p))
	_check("throwing drops the item into the world", thrown.size() == 1 and (thrown[0] as Pickup).kind == Items.Kind.CHOCOLATE
		and inventory.count_of(Items.Kind.CHOCOLATE) == 0)
	if thrown.is_empty():
		return
	var item: Pickup = thrown[0]
	var start := item.global_position
	await _wait(2.0)
	_check("the thrown item flies and falls", item.global_position.distance_to(start) > 2.0 and item.global_position.y < start.y,
		"moved %.1f m" % item.global_position.distance_to(start))
	player.global_position = item.global_position + Vector3(0.0, 0.3, 1.5)
	await _wait(0.2)
	player.face_point(item.global_position)
	await _wait(0.1)
	_check("looking at an item shows a pick-up hint", player.aim_hint().begins_with("E："), player.aim_hint())
	_tap("interact")
	await _wait(0.2)
	_check("E picks it up again", inventory.count_of(Items.Kind.CHOCOLATE) == 1 and not is_instance_valid(item))

	# 火をつけた発煙筒のまわりには、化け物が入れない
	player.pick_up(Items.Kind.FLARE)
	player.face_point(player.get_camera().global_position + Vector3(0.0, -0.5, -1.0))
	player.use_item(Items.Kind.FLARE)
	await _wait(1.5)
	var flares := _pickups().filter(func(p: Pickup) -> bool: return p.kind == Items.Kind.FLARE and p.lit)
	_check("a lit flare keeps monsters away", flares.size() == 1 and Ward.blocks(get_tree(), (flares[0] as Pickup).global_position + Vector3(2.0, 0.0, 0.0)))
	if _shot_dir != "" and flares.size() == 1:
		var flare: Pickup = flares[0]
		await _shot_from(flare.global_position + Vector3(2.5, 1.8, 2.5), flare.global_position, "flare.png")
	# 爆竹は化け物を追い払い、塩は霊を消す
	var enemies := _main.enemies
	var ishinage := enemies.ishinage
	ishinage.appear(player.global_position + Vector3(4.0, 0.0, 0.0), player)
	_main.features.spawn_item(Items.Kind.FIRECRACKER, ishinage.global_position + Vector3.UP * 0.5, Vector3.ZERO, true)
	await _wait(2.0)
	_check("a firecracker scares monsters away", not ishinage.active)
	var wisp := enemies.onibi[0]
	wisp.appear(player.global_position + Vector3(0.0, 2.5, 6.0), player)
	_main.features.spawn_item(Items.Kind.SALT, wisp.global_position, Vector3.DOWN * 2.0, true)
	await _wait(1.0)
	_check("salt purifies spirits", not wisp.active, "%.1f m away" % wisp.global_position.distance_to(player.global_position))
	# お守りは転落死を一度だけ防ぐ
	player.pick_up(Items.Kind.OMAMORI)
	player.injury = 0.0
	player.call("_on_landed", Player.DEADLY_FALL_SPEED + 2.0)
	_check("omamori saves you from a deadly fall once", not player.frozen and inventory.count_of(Items.Kind.OMAMORI) == 0 and player.injury > 0.0)
	# ロープ：登っている壁から垂らして、つかむと楽に登れる
	player.spawn_at(_main.terrain.spawn_point(), 0.0)
	if await _climb_onto_first_wall():
		player.pick_up(Items.Kind.ROPE)
		player.use_item(Items.Kind.ROPE)
		await _wait(0.1)
		var ropes := _main.features.get_children().filter(func(n: Node) -> bool: return n is Rope)
		_check("a rope hangs from the wall", ropes.size() == 1 and inventory.count_of(Items.Kind.ROPE) == 0)
		if ropes.size() == 1:
			var rope: Rope = ropes[0]
			Input.action_release("move_forward")
			player.stamina = player.max_stamina()  # 登ってきた疲れを戻してから試す
			player.exhausted = false
			player.global_position = rope.global_position - Vector3.UP * 3.0 + rope.global_transform.basis.z * (Player.WALL_GAP + Rope.WIDTH * 0.5)
			player.call("_start_climb", rope.global_transform.basis.z)
			await _wait(0.3)
			_check("climbing the rope is easy", player.state == Player.State.CLIMB and player.climb_surface == "rope",
				"%s, %s" % [player.climb_surface, Player.State.keys()[player.state]])
			if _shot_dir != "":
				await _shot_from(rope.global_position + rope.global_transform.basis.z * 5.0 - Vector3.UP * 3.0, rope.global_position - Vector3.UP * 4.0, "rope.png")
	else:
		_check("reached a wall for the rope test", false)
	Input.action_release("move_forward")
	Input.action_release("grab")


func _pickups() -> Array:
	return _main.features.get_children().filter(func(n: Node) -> bool: return n is Pickup)


## 急な斜面では足をとられて滑り落ちる。アイゼンをつけていれば滑らない
func _test_sliding() -> void:
	_section("sliding")
	var terrain := _main.terrain
	var player := _main.player
	var spot := Vector3.INF
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for attempt in 4000:
		var c := MountainChain.centers[0]
		var angle := rng.randf() * TAU
		var distance := MountainChain.radii[0] * rng.randf_range(0.2, 0.9)
		var x := c.x + cos(angle) * distance
		var z := c.y + sin(angle) * distance
		var n := terrain.normal_at(x, z)
		var below := Vector3(n.x, 0.0, n.z).normalized() * 1.0
		var n2 := terrain.normal_at(x + below.x, z + below.z)
		if n.y > 0.74 and n.y < 0.85 and n2.y > 0.7 and n2.y < 0.9:
			spot = Vector3(x, terrain.height_at(x, z), z)
			break
	if not spot.is_finite():
		_note("skip sliding test: no slope found")
		return
	player.spawn_at(spot + Vector3.UP * 0.3, 0.0)
	var slid := false
	var top_speed := 0.0
	for i in 15:
		await _wait(0.1)
		slid = slid or player.sliding
		top_speed = maxf(top_speed, Vector2(player.velocity.x, player.velocity.z).length())
	var moved := Vector2(player.global_position.x - spot.x, player.global_position.z - spot.z).length()
	_check("you slide down a steep slope", slid and moved > 0.5,
		"moved %.1f m, top speed %.1f, normal %.2f" % [moved, top_speed, terrain.normal_at(spot.x, spot.z).y])
	player.spawn_at(spot + Vector3.UP * 0.3, 0.0)
	player.effects["crampons"] = 30.0
	await _wait(1.5)
	moved = Vector2(player.global_position.x - spot.x, player.global_position.z - spot.z).length()
	_check("crampons stop the slide", not player.sliding and moved < 0.6, "moved %.1f m" % moved)


## 地帯ごとのギミック
func _test_gimmicks() -> void:
	_section("gimmicks")
	await _restart()
	var player := _main.player
	var features := _main.features
	_calm_weather()
	var counts := {}
	for node in features.get_children():
		var script := node.get_script() as Script
		var type_name: String = script.get_global_name() if script else ""
		counts[type_name] = counts.get(type_name, 0) + 1
	_note("gimmicks: %s" % str(counts))
	for gimmick in ["Bog", "BearTrap", "Puffball", "Vines", "Rockfall", "CrumblyRock", "Fumarole", "Scree", "SnowBridge",
			"Avalanche", "IceWall", "Gusts", "GhostStones", "ToriiGate", "Jizo", "Tenaga"]:
		_check("placed: " + gimmick, counts.get(gimmick, 0) > 0)

	# 沼：沈んでいく
	var bog: Bog = _first(Bog)
	if bog:
		player.spawn_at(bog.global_position + Vector3.UP * 0.5, 0.0)
		await _wait(1.5)
		_check("you sink in the bog", player.sink > 0.2, "sink %.2f" % player.sink)
		if _shot_dir != "":
			player.face_point(bog.global_position + Vector3(bog.radius, 0.0, 0.0))
			await _save_shot("bog.png")
	# トラバサミ：踏むと挟まれる
	var trap: BearTrap = _first(BearTrap)
	if trap:
		player.spawn_at(trap.global_position + Vector3(0.0, 0.3, 3.0), 0.0)
		if _shot_dir != "":
			player.face_point(trap.global_position)
			await _wait(0.5)
			await _save_shot("bear_trap.png")
		player.global_position = trap.global_position + Vector3.UP * 0.3
		await _wait(0.5)
		_check("a bear trap snaps shut", not trap.armed and player.injury > 0.0)
	# 胞子キノコ
	var puffball: Puffball = _first(Puffball)
	if puffball:
		player.spawn_at(puffball.global_position + Vector3(0.8, 0.5, 0.0), 0.0)
		await _wait(0.4)
		_check("puffballs release spores", player.has_effect("spores"))
	# 噴気孔：噴き上がると吹き飛ばされる
	var fumarole: Fumarole = _first(Fumarole)
	if fumarole:
		player.spawn_at(fumarole.global_position + Vector3.UP * 0.3, 0.0)
		await _wait(0.3)
		var y := player.global_position.y
		fumarole.call("erupt")
		var highest := y
		for i in 10:
			await _wait(0.1)
			highest = maxf(highest, player.global_position.y)
		_check("a fumarole launches you", highest > y + 3.0, "rose %.1f m" % (highest - y))
		if _shot_dir != "":
			await _shot_from(fumarole.global_position + Vector3(4.0, 2.5, 4.0), fumarole.global_position + Vector3.UP * 2.0, "fumarole.png")
	# 崩れる岩：つかんでいると砕ける
	var rock: CrumblyRock = null
	var space := get_viewport().world_3d.direct_space_state
	for node in _main.features.get_children():
		var candidate := node as CrumblyRock
		if candidate == null:
			continue
		var out := candidate.global_transform.basis.z
		var front := PhysicsRayQueryParameters3D.create(candidate.global_position + out * 1.0, candidate.global_position + out * 2.8 - Vector3.UP, Player.TERRAIN_LAYER)
		if space.intersect_ray(front).is_empty():
			rock = candidate
			break
	if rock:
		var normal := rock.global_transform.basis.z
		if _shot_dir != "":
			await _shot_from(rock.global_position + normal * 5.0 + Vector3.UP * 1.0, rock.global_position, "crumbly_rock.png", true)
		player.spawn_at(rock.global_position + normal * (Player.WALL_GAP + 0.95) - Vector3.UP * 1.0, 0.0)
		player.call("_start_climb", normal)
		Input.action_press("grab")
		var fell := false
		for i in 30:
			await _wait(0.1)
			if not is_instance_valid(rock):
				fell = player.state != Player.State.CLIMB
				break
		Input.action_release("grab")
		_check("a crumbly rock breaks under you", not is_instance_valid(rock) and fell,
			"surface %s, state %s" % [player.climb_surface, Player.State.keys()[player.state]])
	# 隠れクレバス：雪のふたを踏むと落ちる
	var bridge: SnowBridge = _first(SnowBridge)
	if bridge:
		var rim := bridge.global_position.y
		var pit_center := bridge.global_position
		var bottom := _main.terrain.height_at(bridge.global_position.x, bridge.global_position.z)
		player.spawn_at(bridge.global_position + Vector3.UP * 0.4, 0.0)
		var lowest := INF
		for i in 35:
			await _wait(0.1)
			lowest = minf(lowest, player.global_position.y)
		var under := get_viewport().world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3.UP * 0.5, player.global_position - Vector3.UP * 2.0))
		var what := "nothing" if under.is_empty() else "%s (in %s, shape %d, %d shapes) at %s" % [under.collider,
			(under.collider as Node).get_parent().name, under.shape, (under.collider as Node).get_child_count(), under.position]
		_check("a hidden crevasse swallows you", not is_instance_valid(bridge) and lowest < rim - 4.0,
			"fell %.1f m into a %.1f m pit, standing on %s, player at %s, pit at %s" % [rim - lowest, rim - bottom, what,
			player.global_position, pit_center])
		if _shot_dir != "":
			player.face_point(player.get_camera().global_position + Vector3(0.0, 1.0, -0.3))
			await _wait(0.3)
			await _save_shot("crevasse.png")
	# 氷の壁：すべる
	var ice: IceWall = _first(IceWall)
	if ice:
		var normal := ice.global_transform.basis.z
		player.spawn_at(ice.global_position + normal * (Player.WALL_GAP + 0.65) - Vector3.UP * 1.0, 0.0)
		player.call("_start_climb", normal)
		Input.action_press("grab")
		await _wait(0.3)
		_check("ice walls are slippery", player.climb_surface == "ice", player.climb_surface)
		if _shot_dir != "":
			await _shot_from(ice.global_position + normal * 5.0 + Vector3.UP * 1.5, ice.global_position, "ice_wall.png", true)
		Input.action_release("grab")
	# 雪崩：押し流されて冷える
	var avalanche: Avalanche = _first(Avalanche)
	if avalanche:
		player.spawn_at(_main.terrain.checkpoint(Biomes.Id.SNOW) + Vector3(0.0, 0.5, 2.5), 0.0)
		await _wait(0.3)
		var chilled := [false]
		player.chilled.connect(func() -> void: chilled[0] = true, CONNECT_ONE_SHOT)
		avalanche.call("start")
		var hit := false
		for i in 120:
			await _wait(0.1)
			if avalanche.get("_hit"):
				hit = true
				break
		_check("an avalanche sweeps over you", hit and chilled[0])
		if _shot_dir != "":
			await _wait(0.1)
			await _save_shot("avalanche.png")
	# 突風：押し流される
	var gusts: Gusts = _first(Gusts)
	if gusts:
		player.spawn_at(_main.terrain.summit_position + Vector3(0.0, 0.5, 2.0), 0.0)
		await _wait(0.5)
		gusts.set("_timer", 0.0)
		gusts.phase = "warning"
		await _wait(Gusts.WARNING + 0.1)
		var start := player.global_position
		await _wait(1.5)
		_check("a gust pushes you", Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length() > 1.5)
	# 幽霊の飛び石：現れたり消えたりする
	var stones: GhostStones = _first(GhostStones)
	if stones:
		var solid := stones.is_solid(0)
		var changed := false
		for i in 80:
			await _wait(0.1)
			changed = changed or stones.is_solid(0) != solid
		_check("ghost stones fade in and out", changed)
		if _shot_dir != "":
			await _shot_from(stones.global_position + Vector3(8.0, 8.0, 8.0), stones.global_position + Vector3.UP * 6.0, "ghost_stones.png")
	# 鳥居：くぐると対の鳥居へ飛ばされる
	var gate: ToriiGate = _first(ToriiGate)
	if gate and gate.partner:
		player.spawn_at(gate.global_position + Vector3.UP * 0.3, 0.0)
		await _wait(0.3)
		_check("a torii gate warps you to its partner", player.global_position.distance_to(gate.partner.global_position) < 4.0)
		if _shot_dir != "":
			var forward := -gate.global_transform.basis.z
			await _shot_from(gate.global_position + forward * 4.0 + Vector3.UP * 1.6, gate.global_position + Vector3.UP * 1.1, "torii.png")
	# お地蔵さん：食べ物をお供えすると、お守りを授かる
	var jizo: Jizo = _first(Jizo)
	if jizo:
		player.inventory.clear()
		player.pick_up(Items.Kind.ONIGIRI)
		player.inventory.selected = player.inventory.slot_of(Items.Kind.ONIGIRI)
		jizo.interact(player)
		_check("an offering to jizo gives an omamori", player.inventory.count_of(Items.Kind.OMAMORI) == 1 and jizo.offered)
		if _shot_dir != "":
			var front := -jizo.global_transform.basis.z
			await _shot_from(jizo.global_position + front * 1.8 + Vector3.UP * 1.2, jizo.global_position + Vector3.UP * 0.5, "jizo.png", true)


## 雪崩と突風を、しばらく起こさない（化け物やギミックを試している間）
func _calm_weather() -> void:
	for node in _main.features.get_children():
		if node is Gusts or node is Avalanche:
			node.set("_timer", 9999.0)


## ほかの化け物を出さない（ひとつの仕組みだけを試したいとき）
func _calm_enemies() -> void:
	var enemies := _main.enemies
	var cooldowns: Dictionary = enemies.get("_cooldowns")
	for key: String in cooldowns:
		cooldowns[key] = 9999.0
	enemies.yukimoguri.stop()
	enemies.kaichou.state = "gone"
	enemies.kaichou.visible = false


func _first(type: Variant) -> Node:
	for node in _main.features.get_children():
		if is_instance_of(node, type):
			return node
	return null


## 新しい化け物たち
func _test_new_enemies() -> void:
	_section("new enemies")
	await _restart()
	var player := _main.player
	var enemies := _main.enemies
	var terrain := _main.terrain
	_calm_weather()
	# 手長：真下を通るとつかまれ、もがけば放される
	var tenaga: Tenaga = _first(Tenaga)
	if tenaga:
		var hands := tenaga.hands_position()
		var ground := Vector3(hands.x, terrain.height_at(hands.x, hands.z), hands.z)
		if _shot_dir != "":
			var middle := (tenaga.global_position + hands) * 0.5
			await _shot_from(middle + Vector3(5.5, -0.5, 5.5), middle, "tenaga.png", true)
		player.spawn_at(ground + Vector3.UP * 0.3, 0.0)
		await _wait(0.6)
		_check("tenaga grabs you from the tree", player.held_by == tenaga)
		await _wait(1.0)
		_check("tenaga lifts you up", player.global_position.y > ground.y + 0.8, "%.1f m up" % (player.global_position.y - ground.y))
		if _shot_dir != "":
			var held := tenaga.hands_position()
			await _shot_from(held + Vector3(4.5, 0.5, 4.5), held - Vector3.UP * 0.8, "tenaga_grab.png", true)
		player.struggle = Tenaga.STRUGGLE_NEEDED + 1.0
		await _wait(0.2)
		_check("struggling frees you", player.held_by == null)
		await _wait(2.0)
	# 木霊：近づいて持ち物を盗み、逃げる。消えると盗んだ物を落とす
	player.spawn_at(_main.terrain.spawn_point(), 0.0)
	var shown := enemies.spawn_kodama()
	_check("kodama appear around you", shown >= 3, "%d kodama" % shown)
	if _shot_dir != "" and shown > 0:
		player.face_point(enemies.kodamas[0].global_position + Vector3.UP * 0.4)
		await _wait(0.3)
		await _save_shot("kodama.png")
	var kodama := enemies.kodamas[0]
	kodama.global_position = player.global_position + Vector3(0.8, 0.0, 0.0)
	await _wait(0.2)
	_check("kodama steal an item", kodama.state == "fleeing" and kodama.carrying >= 0 and player.inventory.count_of(Items.Kind.PITON) + player.inventory.count_of(Items.Kind.ONIGIRI) == 1)
	var before := _pickups().size()
	kodama.vanish()
	_check("the stolen item is dropped when kodama vanish", _pickups().size() == before + 1)
	for k in enemies.kodamas:
		k.vanish()
	# 鬼火：触れると冷える
	# 雪潜り：雪原を歩いていると、雪の下から噛みつく
	var snow_spot := terrain.checkpoint(Biomes.Id.SNOW) + Vector3(0.0, 0.5, 4.5)
	player.spawn_at(snow_spot, 0.0)
	await _wait(0.3)
	var injury := player.injury
	var worm := enemies.yukimoguri
	worm.start_hunt(player, terrain)
	worm.global_position = snow_spot + Vector3(4.0, -0.5, 0.0)
	var bitten := false
	for i in 60:
		await _wait(0.1)
		if player.injury > injury:
			bitten = true
			break
	_check("yukimoguri bites from under the snow", bitten)
	worm.stop()
	# 火のついたたき火のそばは安全：雪の上でも噛まれない
	var fire := _main.features.campfires[3]
	fire.set_lit(true)
	player.spawn_at(fire.global_position + Vector3(0.0, 0.5, 1.5), 0.0)
	await _wait(0.3)
	injury = player.injury
	worm.start_hunt(player, terrain)
	worm.global_position = player.global_position + Vector3(3.0, -0.5, 0.0)
	await _wait(3.0)
	_check("monsters stay away from a lit campfire", player.injury == injury)
	worm.stop()
	fire.set_lit(false)
	# 鬼火：触れると冷える（たき火の守りの外で）
	player.spawn_at(snow_spot, 0.0)
	await _wait(0.3)
	var wisp := enemies.onibi[1]
	wisp.appear(player.global_position + Vector3(2.0, 1.3, 0.0), player)
	var chilled := [false]
	player.chilled.connect(func() -> void: chilled[0] = true, CONNECT_ONE_SHOT)
	await _wait(2.0)
	_check("onibi chill you", chilled[0] and not wisp.active)
	if _shot_dir != "":
		await _wait(0.1)
		await _shot_from(worm.global_position + Vector3(3.5, 2.0, 3.5), worm.global_position + Vector3.UP * 1.2, "yukimoguri.png", true)
	worm.stop()
	# 怪鳥：急降下してぶつかってくる
	player.spawn_at(snow_spot, 0.0)
	await _wait(0.3)
	injury = player.injury
	var bird := enemies.kaichou
	bird.arrive(player)
	await _wait(0.5)
	if _shot_dir != "":
		await _shot_from(player.global_position + Vector3(0.0, 2.0, 0.0), bird.global_position, "kaichou.png", true)
	bird.dive()
	var struck := false
	for i in 40:
		await _wait(0.1)
		if player.injury > injury:
			struck = true
			break
	_check("kaichou dives into you", struck)
	bird.leave()
	# 影法師：目を離すと近づき、触れられると力が抜ける
	var shadow := enemies.shadow
	player.spawn_at(terrain.summit_position + Vector3(0.0, 0.5, 1.5), 0.0)
	await _wait(0.3)
	shadow.appear(player.global_position + Vector3(0.0, 0.0, 5.0), player, terrain)
	if _shot_dir != "":
		player.face_point(shadow.global_position + Vector3.UP * 1.3)
		await _wait(0.2)
		await _save_shot("shadow.png")
	player.face_point(player.get_camera().global_position + Vector3(0.0, 0.0, -5.0))
	var drained := false
	for i in 60:
		await _wait(0.1)
		if player.exhausted:
			drained = true
			break
	_check("the shadow drains you when you look away", drained)
	shadow.vanish()
	# 石投げ：上から石を投げてくる
	player.spawn_at(snow_spot, 0.0)
	await _wait(0.3)
	injury = player.injury
	var thrower := enemies.ishinage
	thrower.appear(player.global_position + Vector3(0.0, 6.0, -8.0), player)
	var rock_hit := false
	for i in 80:
		await _wait(0.1)
		if player.injury > injury:
			rock_hit = true
			break
	_check("ishinage hits you with a rock", rock_hit)
	if _shot_dir != "":
		await _shot_from(thrower.global_position + Vector3(2.5, 1.5, 3.0), thrower.global_position + Vector3.UP * 1.0, "ishinage.png", true)
	thrower.leave()
	# 壁の手：登っていると足首をつかまれる。飛びつけば振りほどける
	player.spawn_at(_main.terrain.spawn_point(), 0.0)
	if await _climb_onto_first_wall():
		Input.action_release("move_forward")
		var grabbed := enemies.spawn_wall_hand()
		await _wait(0.6)
		var hand := enemies.hands[0]
		_check("a hand grabs your ankle", grabbed and hand.state == "gripping")
		if _shot_dir != "":
			var n := player.wall_normal()
			await _shot_from(player.global_position + n * 2.5 + Vector3.UP * 0.2, player.global_position, "wall_hand.png", true)
		_tap("jump")
		await _wait(0.3)
		_check("lunging shakes the hand off", hand.state != "gripping")
	else:
		_check("reached a wall for the hand test", false)
	Input.action_release("move_forward")
	Input.action_release("grab")


func _test_piton() -> void:
	_section("piton")
	await _restart()
	var player := _main.player
	if not await _climb_onto_first_wall():
		_check("reached a wall for the piton test", false)
		return
	Input.action_release("move_forward")
	player.use_item(Items.Kind.PITON)
	_check("piton clips onto the wall", player.clipped and player.inventory.count_of(Items.Kind.PITON) == 0)
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
	player.global_position += Vector3(0.0, 0.0, -8.0)  # スタート地点のたき火から離れる
	await _wait(0.5)
	player.pick_up(Items.Kind.OFUDA)
	player.use_item(Items.Kind.OFUDA)
	await _wait(0.2)
	var tree := get_tree()
	_check("ofuda places a ward", tree.get_nodes_in_group(Ward.GROUP).filter(func(n: Node) -> bool: return n is Ward).size() == 1)
	_check("ward blocks inside, not outside",
		Ward.blocks(tree, player.global_position) and not Ward.blocks(tree, player.global_position + Vector3(20.0, 0.0, 0.0)))
	_main.stalker.hunt(1)
	_main.stalker.call("_appear")  # 足跡はまだ短いので、“何か”はすぐそばに現れる
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
	if not await _climb_onto_first_wall(true):
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
	_calm_weather()
	_calm_enemies()
	var player := _main.player
	# 雪山の頂上の平らな場所に立つ（たき火から 5 m 離れているので、火はつかず、温まらない）
	player.spawn_at(_main.terrain.checkpoint(Biomes.Id.SNOW) + Vector3(5.0, 0.5, 0.0), 0.0)
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
	var cold := player.cold
	for i in 150:
		await _wait(0.1)
		if player.cold > cold + 10.0:
			break
	_check("pale one chills the player", player.cold > cold + 10.0, "cold %.1f -> %.1f" % [cold, player.cold])


## テスト用の飛行モード：F1 で飛び、壁をすり抜け、やめると落下のケガなしで着地する
func _test_fly() -> void:
	_section("fly mode")
	var player := _main.player
	player.spawn_at(_main.terrain.spawn_point(), 0.0)
	await _wait(0.3)
	_tap("fly")
	await _wait(0.1)
	_check("F1 starts flying", player.flying)
	var start := player.global_position
	Input.action_press("jump")
	await _wait(1.5)
	Input.action_release("jump")
	_check("flying up", player.global_position.y > start.y + 10.0, "rose %.1f m" % (player.global_position.y - start.y))
	# 山の中へ突っ込んでも、すり抜けて進める
	player.face_point(Vector3(MountainChain.centers[0].x, player.global_position.y, MountainChain.centers[0].y))
	var before := player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(1.5)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("flying fast through anything", player.global_position.distance_to(before) > 40.0,
		"moved %.1f m" % player.global_position.distance_to(before))
	player.global_position = _main.terrain.spawn_point() + Vector3.UP * 30.0
	player.injury = 0.0
	_tap("fly")
	for i in 40:
		await _wait(0.1)
		if player.is_on_floor():
			break
	await _wait(0.3)
	_check("landing after flying does no harm", not player.flying and not player.frozen and player.injury == 0.0 and player.is_on_floor(),
		"injury %.1f" % player.injury)


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


# --- 重さの計測（--perf） ---

## 垂直同期を切って、いろいろな場所の FPS と描画の数を測る
func _measure_performance() -> void:
	_section("performance")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var player := _main.player
	await _measure("lobby")
	player.global_position = _main.lobby.get("_bus_door") + Vector3(0.0, 0.3, 0.0)
	await _wait_for_climb()
	var terrain := _main.terrain
	_note("build: %d nodes in the mountain features" % _main.features.get_child_count())
	await _measure("trailhead")
	if "--breakdown" in OS.get_cmdline_user_args():
		await _breakdown()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for biome in Biomes.NAMES.size():
		var spot := terrain.summit_position if biome == Biomes.Id.SUMMIT else terrain.checkpoint(biome)
		player.spawn_at(spot + Vector3(0.0, 0.5, 2.0), 0.0)
		var center: Vector2 = MountainChain.centers[mini(biome + 1, MountainChain.COUNT - 1)]
		player.face_point(Vector3(center.x, spot.y, center.y))
		await _measure("summit of %s, looking ahead" % Biomes.NAMES[biome])
	# 樹海の真ん中（木と罠と沼が多い）
	var forest := terrain.random_ledge_points(rng, 1, Biomes.Id.FOREST, 1.0, 1, PackedVector3Array(), 0.0, -1.0, 0.8)
	if not forest.is_empty():
		player.spawn_at(forest[0] + Vector3.UP * 0.5, 0.0)
		player.face_point(Vector3(MountainChain.centers[0].x, forest[0].y + 5.0, MountainChain.centers[0].y))
		await _measure("inside the forest")
	# 夜（ヘッドライト、鬼火）
	player.spawn_at(terrain.spawn_point(), 0.0)
	_main.day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH + 5.0
	player.set_headlamp(true)
	_main.enemies.spawn_onibi(4)
	await _measure("night at the trailhead")
	# 山全体を見渡す（いちばん多く描く）
	var camera := Camera3D.new()
	_main.add_child(camera)
	camera.global_position = Vector3(MountainChain.centers[0].x + 120.0, 160.0, MountainChain.centers[0].y + 140.0)
	camera.look_at(Vector3(MountainChain.centers[1].x, 90.0, MountainChain.centers[1].y))
	camera.make_current()
	await _measure("whole chain from above")
	camera.queue_free()


## 何が重いのかを調べる：ひとつずつ消して測り直す
func _breakdown() -> void:
	var sun: DirectionalLight3D = _main.day.get("_sun")
	sun.shadow_enabled = false
	await _measure("  - without sun shadows")
	sun.shadow_enabled = true
	_main.lobby.visible = false
	await _measure("  - without the lobby")
	_main.lobby.visible = true
	for child in _main.features.get_children():
		if child is MultiMeshInstance3D:
			child.visible = false
	await _measure("  - without trees and cairns")
	for child in _main.features.get_children():
		if child is MultiMeshInstance3D:
			child.visible = true
	for child in _main.terrain.get_children():
		if child is MeshInstance3D:
			child.visible = false
	await _measure("  - without terrain and rocks")
	for child in _main.terrain.get_children():
		if child is MeshInstance3D:
			child.visible = true
	for child in _main.features.get_children():
		if not child is MultiMeshInstance3D and child is Node3D:
			child.visible = false
	await _measure("  - without gimmicks, items, campfires")
	for child in _main.features.get_children():
		if child is Node3D:
			child.visible = true


func _measure(label: String) -> void:
	await _wait(1.5)  # 読み込みや霧の切り替わりを待つ
	var times: Array[float] = []
	var draws := 0.0
	var primitives := 0.0
	var elapsed := 0.0
	while elapsed < 3.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		elapsed += dt
		times.append(dt)
		draws = maxf(draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives = maxf(primitives, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	times.sort()
	var average := elapsed / times.size()
	var worst := times[int(times.size() * 0.99)]  # 遅いほうから 1% のフレーム
	_note("%-32s avg %5.0f fps   1%% low %5.0f fps   draw calls %5d   triangles %7d   video mem %d MB" % [label, 1.0 / average,
		1.0 / worst, draws, primitives, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])


# --- スクリーンショット ---

func _overview_shot() -> void:
	var world := _main.day.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment
	world.environment.fog_enabled = false
	await _shot_from(Vector3(300.0, 230.0, 60.0), Vector3(0.0, 110.0, -125.0), "overview.png")
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
			var spots := _main.terrain.random_ledge_points(rng, 1, biome, 1.0, 1, PackedVector3Array(), 0.0, 20.0, 0.85)
			if spots.is_empty():
				continue
			player.spawn_at(spots[0] + Vector3.UP * 0.5, 0.0)
			var center: Vector2 = MountainChain.centers[biome]
			var outward := Vector3(spots[0].x - center.x, 0.0, spots[0].z - center.y).normalized()
			player.face_point(player.get_camera().global_position + outward * 10.0 - Vector3.UP * 2.5)
		await _wait(2.5)  # 霧の色が切り替わるのを待つ
		await _save_shot("biome_%d.png" % biome)


# --- 道具 ---

## ロビーに戻ってからバスに乗り直し、登山口から始める（テストでは毎回同じ山）
func _restart() -> void:
	Input.action_release("move_forward")
	Input.action_release("grab")
	_main.call("_return_to_lobby")
	_main.player.global_position = _main.lobby.get("_bus_door") + Vector3(0.0, 0.3, 0.0)
	await _wait_for_climb()


## バスに乗って山に着く（登り始められる）まで待つ
func _wait_for_climb() -> bool:
	for i in 200:
		await _wait(0.1)
		if _main.run_state == Main.RunState.CLIMBING:
			return true
	return false


## 最初の崖に取りつくまで前進する（つかんだまま、少し登った状態で返す）。steep なら切り立った壁まで登る
func _climb_onto_first_wall(steep := false) -> bool:
	var player := _main.player
	Input.action_press("move_forward")
	Input.action_press("grab")
	for i in 160 if steep else 80:
		await _wait(0.1)
		if player.state == Player.State.CLIMB and player.global_position.y > 3.0 and (not steep or player.wall_normal().y < 0.4):
			return true
	_note("could not reach a wall: at %s, state %s, sliding %s, stuck %s" % [player.global_position, Player.State.keys()[player.state],
		player.sliding, player.get("_stuck_time")])
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


## キーを一度押して離したことにする（ゲームが「押した瞬間」を拾えるように、入力として流す）
func _tap(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


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
