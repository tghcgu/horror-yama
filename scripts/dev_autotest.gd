extends Node
## 開発用の自動テスト。ゲームを起動したまま各機能を順に試し、結果を表示して終了する。
## 実行例: godot --path . -- --autotest [--shot-dir=<スクリーンショットの保存先>]

const TEST_SEED := Main.WORLD_SEED  # 遊ぶときと同じ山を調べる

var _main: Main
var _shot_dir := ""
var _log := PackedStringArray()
var _failures := 0
var _start_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(12345)
	Settings.persist = false  # 遊ぶ人の設定を書きかえない
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


## --only=stages,items のように指定したら、その項目だけ流す（指定がなければすべて）
func _wants(name: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			return name in arg.trim_prefix("--only=").split(",")
	return true


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
	await _test_lobby()  # 山を作るので、いつも流す
	if _wants("stages"):
		await _test_stages()
	if _shot_dir != "" and _wants("look"):
		await _look_shots()
	if _shot_dir != "":
		await _overview_shot()
		await _biome_shots()
	if _wants("chain_shape"):
		await _test_chain_shape()
	if _wants("climb_and_night"):
		await _test_climb_and_night()
	if _wants("checkpoint"):
		await _test_checkpoint()
	if _wants("afflictions"):
		await _test_afflictions()
	if _wants("dawn"):
		await _test_dawn()
	if _wants("items"):
		await _test_items()
	if _wants("physics_items"):
		await _test_physics_items()
	if _wants("sliding"):
		await _test_sliding()
	if _wants("gimmicks"):
		await _test_gimmicks()
	if _wants("new_enemies"):
		await _test_new_enemies()
	if _wants("piton"):
		await _test_piton()
	if _wants("ward"):
		await _test_ward()
	if _wants("spider"):
		await _test_spider()
	if _wants("peeker"):
		await _test_peeker()
	if _wants("pale_one"):
		await _test_pale_one()
	if _wants("fly"):
		await _test_fly()
	if _wants("social"):
		await _test_social()
	if _wants("hunting"):
		await _test_hunting()
	if _wants("critters"):
		await _test_critters()
	if "--only=lamp" in OS.get_cmdline_user_args():
		await _test_lamp()
	if _wants("combat"):
		await _test_combat()
	if _wants("mountain_props"):
		await _test_mountain_props()
	if _wants("night_monsters"):
		await _test_night_monsters()
	if "--only=census" in OS.get_cmdline_user_args():
		await _test_census()
	if _wants("menu"):
		await _test_menu()
	if _wants("gate_leak"):
		await _test_gate_leak()
	_finish()


# --- 各テスト ---

## 戦う：ナタは押しっぱなしで振り続ける、素手で殴る、投げた物が当たると傷を負う（Q をためると強く飛ぶ）、
## 熊も倒せる。引っかかる段差は、跳ぶと手をかけて乗り越える
func _test_combat() -> void:
	_section("combat")
	await _restart()
	_calm_weather()
	_calm_enemies()
	var player := _main.player
	var terrain := _main.terrain
	var director := _main.critters
	director.clear()
	var here := terrain.spawn_point()
	player.spawn_at(here, 0.0)
	await _wait(0.3)
	var place := func(kind: String, distance: float) -> Critter:
		var at := here + Vector3(0.0, 0.0, -distance)
		at.y = terrain.height_at(at.x, at.z)
		var critter := Critter.new()
		director.add_child(critter)
		critter.setup(kind, at, player, terrain)
		critter.set_physics_process(false)  # 動かないようにして試す
		player.face_point(critter.hit_center())
		return critter
	# ナタを押しっぱなし：何度も振る
	player.inventory.selected = player.inventory.slot_of(Items.Kind.NATA)
	player.stowed = false
	var deer: Critter = place.call("deer", 1.9)
	await _wait(0.2)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var held_mouse := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var stamina := player.stamina
	if held_mouse:
		Input.action_press("use_item")
		await _wait(1.0)
		Input.action_release("use_item")
		_check("holding the button keeps swinging the machete", deer.dead, "health %.0f" % deer.health)
	else:
		for i in 3:
			_tap("use_item")
			await _wait(0.5)
		_note("mouse can not be captured here: swung by clicks")
		_check("swinging the machete kills a deer", deer.dead, "health %.0f" % deer.health)
	_check("swinging uses stamina", player.stamina < stamina)
	# 人熊も倒せる（とても打たれ強い）。倒すと、熊の胆がとれる
	var bear_at := here + Vector3(0.0, 0.0, -2.6)
	bear_at.y = terrain.height_at(bear_at.x, bear_at.z)
	var bear := Hitokuma.new()
	director.add_child(bear)
	bear.setup(bear_at, player, terrain)
	bear.set_physics_process(false)
	player.face_point(bear.hit_center())
	if _shot_dir != "":
		bear.state = "roar"
		await _wait(0.6)
		var bear_front := -bear.global_transform.basis.z
		await _shot_from(bear.global_position + bear_front * 5.5 + Vector3.UP * 1.6, bear.hit_center() + Vector3.UP * 0.3, "hitokuma.png", true)
		bear.state = "stalk"
	var bear_health := bear.health
	for i in 40:
		if bear.dead:
			break
		player.face_point(bear.hit_center())
		player.set("_swing_cooldown", 0.0)
		_tap("use_item")
		await _wait(0.3)
	_check("the humanoid bear can be killed with the machete", bear.dead, "health %.0f / %.0f" % [bear.health, bear_health])
	player.inventory.clear()
	bear.interact(player)
	_check("the humanoid bear gives bear bile", player.inventory.count_of(Items.Kind.KUMANOI) == 1)
	player.injury = 30.0
	player.inventory.selected = player.inventory.slot_of(Items.Kind.KUMANOI)
	player.stowed = false
	player.use_selected()
	_check("bear bile heals everything", player.injury == 0.0 and player.boost_time > 60.0)
	player.inventory.clear()
	for kind: int in Items.STARTING:
		player.inventory.add(kind)
	player.inventory.selected = player.inventory.slot_of(Items.Kind.NATA)
	bear.queue_free()
	deer.queue_free()
	# 化け物には、ナタはあまり効かない（亡者は一振りでは消えない）
	var wanderer: Wanderer = _main.enemies.wanderers[0]
	var ghost_at := here + Vector3(0.0, 0.0, -2.0)
	ghost_at.y = terrain.height_at(ghost_at.x, ghost_at.z)
	wanderer.appear(ghost_at, player, terrain)
	player.face_point(Combat.body_center(wanderer))
	player.set("_swing_cooldown", 0.0)
	_tap("use_item")
	await _wait(0.4)
	_check("monsters shrug off the machete", wanderer.active)
	wanderer.vanish()
	# 野犬：近くに肉を投げると食べに来て、なつく
	var dog := Critter.new()
	director.add_child(dog)
	var dog_at := here + Vector3(6.0, 0.0, 0.0)
	dog_at.y = terrain.height_at(dog_at.x, dog_at.z)
	dog.setup("dog", dog_at, player, terrain)
	var meat_at := here + Vector3(4.0, 1.0, 0.0)
	_main.features.spawn_item(Items.Kind.RAW_MEAT, meat_at, Vector3.ZERO)
	for i in 60:
		await _wait(0.1)
		if dog.tamed:
			break
	_check("a wild dog is tamed with food", dog.tamed, "state %s" % dog.state)
	_check("the tamed dog wears a collar", dog.find_child("Collar", true, false) != null)
	if _shot_dir != "":
		var collar := dog.find_child("Collar", true, false) as Node3D
		await _wait(0.2)
		var look_at := collar.global_position if collar else dog.global_position + Vector3.UP * 0.5
		var facing := dog.global_transform.basis.z
		await _shot_from(look_at + dog.global_transform.basis.x * 0.9 - facing * 0.35 + Vector3.UP * 0.15, look_at, "dog_collar.png", true)
	player.global_position += Vector3(8.0, 0.0, 0.0)
	await _wait(2.0)
	_check("the tamed dog follows you", dog.global_position.distance_to(player.global_position) < 8.0, "%.1f m" % dog.global_position.distance_to(player.global_position))
	# いっしょに戦う：プレイヤーが叩いた獣に、犬も噛みつく
	var prey_at := player.global_position + Vector3(0.0, 0.0, -3.0)
	prey_at.y = terrain.height_at(prey_at.x, prey_at.z)
	var prey := Critter.new()
	director.add_child(prey)
	prey.setup("tanuki", prey_at, player, terrain)
	prey.set_physics_process(false)
	player.last_struck = prey
	var prey_health := prey.health
	for i in 40:
		await _wait(0.1)
		if prey.health < prey_health:
			break
	_check("the tamed dog attacks what you attack", prey.health < prey_health, "health %.0f -> %.0f" % [prey_health, prey.health])
	_check("animal sounds go to the animals volume", (prey.get("_voice") as AudioStreamPlayer3D).bus == &"Animals")
	_check("animal sounds do not loop", not (prey.get("_voice") as AudioStreamPlayer3D).stream.loop_mode if (prey.get("_voice") as AudioStreamPlayer3D).stream is AudioStreamWAV else true)
	prey.queue_free()
	dog.queue_free()
	player.spawn_at(here, 0.0)
	await _wait(0.3)
	# 素手で殴る
	player.stowed = true
	var tanuki: Critter = place.call("tanuki", 1.3)
	await _wait(0.2)
	var before := tanuki.health
	player.set("_swing_cooldown", 0.0)
	_tap("use_item")
	await _wait(0.4)
	if not held_mouse:
		player.call("_punch")  # 画面なしでは、左クリックの押しっぱなしが読めない
		await _wait(0.3)
	_check("punching with bare hands hurts an animal", tanuki.health < before, "health %.0f -> %.0f" % [before, tanuki.health])
	tanuki.queue_free()
	# 投げつける：重い物ほど痛い。Q をためると強く飛ぶ
	player.stowed = false
	var boar: Critter = place.call("boar", 5.0)
	await _wait(0.2)
	player.inventory.clear()
	player.inventory.add(Items.Kind.CANNED)
	player.inventory.add(Items.Kind.BERRIES)
	player.inventory.selected = player.inventory.slot_of(Items.Kind.CANNED)
	player.face_point(boar.hit_center())
	before = boar.health
	var press := InputEventAction.new()
	press.action = "throw"
	press.pressed = true
	Input.parse_input_event(press)
	await _wait(1.0)
	_check("holding Q charges the throw", player.throw_charge > 0.9, "charge %.2f" % player.throw_charge)
	var release := InputEventAction.new()
	release.action = "throw"
	release.pressed = false
	Input.parse_input_event(release)
	await _wait(0.8)
	var canned_hit := before - boar.health
	_check("a thrown can hurts the boar", canned_hit > 15.0, "damage %.0f" % canned_hit)
	boar.set_physics_process(false)
	boar.state = "idle"
	player.inventory.selected = player.inventory.slot_of(Items.Kind.BERRIES)
	player.face_point(boar.hit_center())
	before = boar.health
	player.throw_selected(1.0)
	await _wait(0.8)
	_check("light things hurt less than heavy things", before - boar.health < canned_hit * 0.3, "berries %.1f vs can %.1f" % [before - boar.health, canned_hit])
	boar.queue_free()
	# 引っかかる段差：跳ぶと、手をかけて乗り越える
	player.spawn_at(here, 0.0)
	await _wait(0.4)
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 1.5, 2.0)
	shape.shape = box
	block.add_child(shape)
	_main.add_child(block)
	var forward := -player.global_transform.basis.z
	block.global_position = player.global_position + forward * 1.9 + Vector3.UP * 0.75
	block.rotation.y = player.rotation.y
	await _wait(0.2)
	Input.action_press("move_forward")
	Input.action_press("jump")
	var top := block.global_position.y + 0.75
	var on_top := false
	for i in 12:
		await _wait(0.1)
		if player.is_on_floor() and player.global_position.y > top - 0.2:
			on_top = true
			break
	Input.action_release("jump")
	Input.action_release("move_forward")
	_check("jumping at a ledge climbs over it", on_top, "%.2f m below the top" % (top - player.global_position.y))
	block.queue_free()
	player.inventory.clear()
	for kind: int in Items.STARTING:
		player.inventory.add(kind)

## ヘッドライト：夜に F で点けると、目の前が明るくなる（画面ありで流す）
func _test_lamp() -> void:
	_section("headlamp")
	await _restart()
	_calm_weather()
	_calm_enemies()
	var player := _main.player
	_main.day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH + 20.0
	await _wait(2.0)
	player.spawn_at(_main.terrain.spawn_point(), _main.terrain.spawn_yaw())
	player.set_headlamp(false)
	await _wait(1.0)
	player.face_point(player.get_camera().global_position + (-player.global_transform.basis.z) * 5.0 - Vector3.UP * 2.0)
	await _wait(0.5)
	var dark := await _screen_brightness()
	if _shot_dir != "":
		await _save_shot("lamp_off.png")
	_tap("toggle_lamp")
	await _wait(0.5)
	var lit := await _screen_brightness()
	if _shot_dir != "":
		await _save_shot("lamp_on.png")
	_check("F turns the headlamp on", player.is_headlamp_on())
	_check("the headlamp lights up the ground ahead", lit > dark * 1.5 + 0.02, "brightness %.3f -> %.3f" % [dark, lit])


func _screen_brightness() -> float:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var total := 0.0
	var count := 0
	for y in range(image.get_height() / 3, image.get_height() * 2 / 3, 4):
		for x in range(image.get_width() / 3, image.get_width() * 2 / 3, 4):
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxf(count, 1.0)

## 山の上の造形物と箱：登る途中にも、見つける物がたくさんある
func _test_mountain_props() -> void:
	_section("mountain props")
	await _restart()
	var features := _main.features
	var total := 0
	var first_kinds := 0
	for prop_name: String in features.mountain_props:
		var list: Array = features.mountain_props[prop_name]
		total += list.size()
		if list.any(func(t: Transform3D) -> bool: return _main.terrain.stage_of(t.origin) == 0):
			first_kinds += 1
	var counts := {}
	for prop_name: String in features.mountain_props:
		counts[prop_name] = (features.mountain_props[prop_name] as Array).size()
	_note("mountain props %s" % str(counts))
	_check("many objects stand on the mountains", total >= 150, "%d objects" % total)
	_check("the first mountain has many kinds of objects", first_kinds >= 12, "%d kinds" % first_kinds)
	var above: float = MountainChain.bases[0] + MountainFeatures.MOUNTAIN_ABOVE
	var boxes := features.get_children().filter(func(n: Node) -> bool:
		return n is ItemBox and _main.terrain.stage_of(n.global_position) == 0 and (n as Node3D).global_position.y > above)
	_check("item boxes lie on the mountain too", boxes.size() >= 20, "%d boxes on the first mountain" % boxes.size())
	# 亡骸の遺品をさがす
	var belongings: Harvestable = null
	for node in features.get_children():
		if node is Harvestable and (node as Harvestable).label == "遺品をさがす" and _main.terrain.stage_of(node.global_position) == 0:
			belongings = node
			break
	_check("remains lie on the first mountain", belongings != null)
	if belongings:
		var player := _main.player
		player.inventory.clear()
		player.spawn_at(belongings.global_position + Vector3(0.0, 0.5, 1.2), 0.0)
		await _wait(0.3)
		belongings.interact(player)
		_check("searching the remains finds something", Array(player.inventory.kinds).any(func(k: int) -> bool: return k != -1) and not belongings.is_ripe())


## 化け物は、日が暮れてから夜明けまでしか出ない
func _test_night_monsters() -> void:
	_section("night monsters")
	await _restart()
	var enemies := _main.enemies
	var day := _main.day
	var spider: CragSpider = _first(CragSpider)
	day.time = 20.0
	await _wait(0.5)
	_check("no monsters in the daytime", not day.monsters_out() and enemies.wanderers.all(func(w: Wanderer) -> bool: return not w.active)
		and not spider.get("_model").visible)
	day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH * 0.8
	await _wait(0.5)
	_check("monsters come out as it gets dark", day.monsters_out() and spider.get("_model").visible and spider.is_physics_processing())
	enemies.spawn_wanderer()
	enemies.spawn_onibi(2)
	await _wait(0.3)
	_check("monsters roam at dusk", enemies.wanderers.any(func(w: Wanderer) -> bool: return w.active))
	day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH + DayCycle.NIGHT_LENGTH + 0.5
	await _wait(0.5)
	# 山頂のたき火のまわりは、一息つける：化け物は出ない
	day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH + 20.0
	_main.player.spawn_at(_main.features.campfires[1].global_position + Vector3(0.0, 0.5, 2.0), 0.0)
	enemies.set("_cooldowns", {})
	await _wait(3.0)
	var anything := enemies.wanderers.any(func(w: Wanderer) -> bool: return w.active) or enemies.onibi.any(func(o: Onibi) -> bool: return o.active)
	_check("no monsters come near a summit campfire", not anything)
	day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH + DayCycle.NIGHT_LENGTH + 0.5
	await _wait(0.5)
	_check("dawn sends the monsters away", not day.monsters_out() and enemies.wanderers.all(func(w: Wanderer) -> bool: return not w.active)
		and enemies.onibi.all(func(o: Onibi) -> bool: return not o.active) and not spider.get("_model").visible)
	day.time = 20.0

## ボットに崖を登らせ、夜にしてから休ませる。“何か”が追いついてくるか
func _test_climb_and_night() -> void:
	_section("climb and night")
	await _restart()
	var player := _main.player
	player.spawn_at(_main.terrain.foot_point(0), _main.terrain.foot_yaw(0))
	_main.checkpoint = MountainChain.COUNT - 1  # “何か”は最後の山にしか出ないので、最後のステージにいることにする
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
## 訓練場：登りの壁を登れる、道具置き場から道具を取れる、巻藁を叩ける、的に当てられる
func _test_training(player: Player) -> void:
	var room := _main.lobby
	# 登りの壁
	player.spawn_at(room.to_global(Vector3(-24.0, 0.05, 7.4)), room.rotation.y)
	await _wait(0.3)
	player.face_point(room.to_global(Vector3(-24.0, 3.0, 4.0)))
	Input.action_press("move_forward")
	Input.action_press("grab")
	var start_y := player.global_position.y
	for i in 60:
		await _wait(0.1)
		if player.global_position.y > start_y + 8.5:
			break
	Input.action_release("move_forward")
	Input.action_release("grab")
	_check("you can climb the practice wall", player.global_position.y > start_y + 5.0, "%.1f m up" % (player.global_position.y - start_y))
	# 道具置き場
	player.inventory.clear()
	var racks := room.get_children().filter(func(n: Node) -> bool: return n.has_method("interact") and n.get("kind") != null)
	_check("every item lies on the practice tables", racks.size() == Items.COUNT, "%d racks" % racks.size())
	var crampons: Node3D = racks.filter(func(n: Node) -> bool: return n.get("kind") == Items.Kind.CRAMPONS)[0]
	crampons.call("interact", player)
	crampons.call("interact", player)
	_check("items can be taken again and again", player.inventory.count_of(Items.Kind.CRAMPONS) == 2)
	# 巻藁
	var dummies := room.get_children().filter(func(n: Node) -> bool: return n.has_method("hit") and n.get("total") != null)
	var dummy: Node3D = dummies[0]
	player.spawn_at(dummy.global_position + room.global_transform.basis.z * 1.6, room.rotation.y)
	await _wait(0.3)
	player.inventory.clear()  # （spawn_at は持ち物を最初の道具に戻すので、そのあとで持たせる）
	player.inventory.add(Items.Kind.NATA)
	player.inventory.selected = 0
	player.stowed = false
	player.face_point(dummy.call("hit_center"))
	_tap("use_item")
	await _wait(0.5)
	_check("the machete hits the straw dummy", float(dummy.get("total")) > 0.0, "total %.0f" % float(dummy.get("total")))
	# 的当て
	var targets := room.get_children().filter(func(n: Node) -> bool: return n.has_method("hit") and n.get("hits") != null)
	var target: Node3D = targets[0]
	player.spawn_at(room.to_global(Vector3(target.position.x, 0.05, 12.0)), room.rotation.y)
	await _wait(0.3)
	player.inventory.clear()
	player.inventory.add(Items.Kind.CANNED)
	player.inventory.selected = 0
	player.face_point(target.call("hit_center") + Vector3.UP * 0.4)
	player.throw_selected(0.6)
	for i in 20:
		await _wait(0.1)
		if int(target.get("hits")) > 0:
			break
	_check("a thrown item hits the target", int(target.get("hits")) > 0)
	# たき火に向かって E で食べ物を焼く：焼いた物になって、持ち運べる
	player.spawn_at(room.campfire.global_position + room.global_transform.basis.z * 1.6, room.rotation.y)
	await _wait(0.3)
	player.face_point(room.campfire.global_position)
	player.inventory.clear()
	player.inventory.add(Items.Kind.RAW_MEAT)
	player.inventory.add(Items.Kind.MUSHROOM)
	player.inventory.selected = 0
	player.stowed = false
	await _wait(0.1)
	_check("facing the fire offers to cook", player.aimed == room.campfire and player.aim_hint().contains("生肉"), player.aim_hint())
	player.interact()
	player.interact()
	await _wait(0.1)
	_check("raw meat is cooked at a lit fire and can be carried", player.inventory.count_of(Items.Kind.COOKED_MEAT) == 1 and player.inventory.count_of(Items.Kind.RAW_MEAT) == 0)
	_check("other food can be cooked too", player.inventory.count_of(Items.Kind.GRILLED_MUSHROOM) == 1 and player.inventory.count_of(Items.Kind.MUSHROOM) == 0)
	_check("boxes hold only man-made things", range(200).all(func(_i: int) -> bool: return not Items.pick_random(RandomNumberGenerator.new()) in Items.NOT_IN_BOXES))
	# しゃがむと、低い天井の下をくぐれる。天井の下では、立ち上がらない
	var ceiling := StaticBody3D.new()
	ceiling.collision_layer = Player.TERRAIN_LAYER
	var slab := CollisionShape3D.new()
	var slab_shape := BoxShape3D.new()
	slab_shape.size = Vector3(4.0, 0.4, 3.0)
	slab.shape = slab_shape
	ceiling.add_child(slab)
	room.add_child(ceiling)
	var crawl_from := room.to_global(Vector3(-10.0, 0.05, 30.0))
	var crawl_ahead := room.global_transform.basis.x
	ceiling.global_position = crawl_from + crawl_ahead * 3.5 + Vector3.UP * 1.5
	player.spawn_at(crawl_from, room.rotation.y)
	await _wait(0.3)
	player.face_point(player.get_camera().global_position + crawl_ahead)
	Input.action_press("move_forward")
	var standing_under := false  # 立ったまま、天井の下を通れたか
	for i in 25:
		await _wait(0.1)
		var along := (player.global_position - crawl_from).dot(crawl_ahead)
		standing_under = standing_under or (absf(along - 3.5) < 1.0 and player.global_position.y < crawl_from.y + 0.5)
	Input.action_release("move_forward")
	player.spawn_at(crawl_from, room.rotation.y)
	await _wait(0.3)
	player.face_point(player.get_camera().global_position + crawl_ahead)
	Input.action_press("crouch")
	Input.action_press("move_forward")
	var crouched_under := false
	for i in 30:
		await _wait(0.1)
		var along := (player.global_position - crawl_from).dot(crawl_ahead)
		crouched_under = crouched_under or (absf(along - 3.5) < 1.0 and player.global_position.y < crawl_from.y + 0.5)
	Input.action_release("move_forward")
	_check("crouching lowers your eyes and body", player.crouching and player.get_camera().global_position.y - player.global_position.y < 1.2)
	player.global_position = ceiling.global_position - Vector3.UP * 1.5
	await _wait(0.2)
	Input.action_release("crouch")
	await _wait(0.3)
	var still_down := player.crouching
	player.global_position = crawl_from
	await _wait(0.3)
	_check("crouching lets you pass under a low ceiling", not standing_under and crouched_under and still_down and not player.crouching,
		"standing went under %s, crouched went under %s, stayed down under it %s" % [standing_under, crouched_under, still_down])
	ceiling.queue_free()
	player.spawn_at(room.spawn_position, room.spawn_yaw)
	await _wait(0.3)


func _test_lobby() -> void:
	_section("lobby")
	var player := _main.player
	_check("the game starts in the training ground", _main.run_state == Main.RunState.LOBBY and _main.lobby.contains(player.global_position))
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
	_main.appearance.call("_choose", "jacket_color", (jacket + 3) % Appearance.COLORS.size())
	var body_material: ShaderMaterial = player.get_node("Body").get("_tinted")["jacket"][0]
	var tint: Color = body_material.get_shader_parameter("albedo")
	_check("choosing a color repaints the jacket", tint.is_equal_approx(Appearance.tint_of("jacket")) and Settings.jacket_color != jacket)
	# 形の着せ替え：帽子を次の形にすると、その帽子だけが見える
	var hat_before := Settings.hat_style
	Settings.hat_style = 0
	_main.appearance.call("_step_style", "hat", 1)
	var model: Node = player.get_node("Body").get("_model")
	var hats := model.find_children("Hat_*", "MeshInstance3D", true, false)
	var shown := hats.filter(func(m: MeshInstance3D) -> bool: return m.visible)
	_check("changing the hat shows only the chosen hat", hats.size() >= 6 and shown.size() == 1
		and String(shown[0].name) == "Hat_" + Appearance.style_of("hat"), "%d hats, %s" % [hats.size(), shown.map(func(m: Node) -> String: return m.name)])
	_main.appearance.call("_choose", "skin_tone", 4)
	var skin_material: ShaderMaterial = player.get_node("Body").get("_tinted")["skin"][0]
	_check("choosing a skin tone repaints the face", (skin_material.get_shader_parameter("albedo") as Color).is_equal_approx(Appearance.skin_tint()))
	Settings.hat_style = hat_before
	Settings.apply()
	if _shot_dir != "":
		await _save_shot("dressing.png")
	_main.appearance.close()
	await _wait(0.2)
	if _shot_dir != "":
		await _save_shot("lobby_mirror.png")
		var room := _main.lobby
		await _shot_from(room.to_global(Vector3(0.0, 9.0, 40.0)), room.to_global(Vector3(0.0, 2.0, 0.0)), "lobby_wide.png")
		await _shot_from(room.to_global(Vector3(-20.0, 6.0, 20.0)), room.to_global(Vector3(-24.0, 4.0, 4.0)), "lobby_climb.png")
		await _shot_from(room.to_global(Vector3(20.0, 4.0, 30.0)), room.to_global(Vector3(20.0, 1.0, 22.0)), "lobby_items.png")
		await _shot_from(room.to_global(Vector3(46.0, 4.0, 26.0)), room.to_global(Vector3(46.0, 1.5, 10.0)), "lobby_targets.png")
		await _shot_from(room.to_global(Vector3(4.0, 4.0, 42.0)), room.to_global(Vector3(14.0, 1.5, 54.0)), "lobby_heli.png")
	await _test_training(player)
	# ヘリポートへ行き、ヘリの扉まで行く
	player.global_position = _main.lobby.get("_board_point") + Vector3(0.0, 0.3, 0.0)
	var departed := await _wait_for_climb()
	_check("boarding the helicopter builds the mountain and starts the climb", departed)
	var start := _main.terrain.spawn_point()
	_check("arrived at the trailhead", player.global_position.distance_to(start) < 3.0,
		"%.1f m from the trailhead" % player.global_position.distance_to(start))
	if _shot_dir != "":
		player.face_point(player.get_camera().global_position + Vector3(0.0, 0.8, -5.0))
		await _wait(1.5)
		await _save_shot("trailhead.png")


## 最初は最初のステージ（平地と山）だけが霧の外にある。山頂のたき火に火をともすと、その先の霧が晴れて、
## 次のステージの置き物も現れる。霧の奥へは入れない。地形はひとつながりで、宙に浮いた所はない。
## “何か”は最後の山でだけ追ってくる
func _test_stages() -> void:
	_section("stages")
	var terrain := _main.terrain
	var player := _main.player
	var fog := _main.fog
	_check("the next stages are hidden in fog at the start", MountainChain.unlocked == 1 and not fog.is_opened(1) and fog.visible)
	_check("only the first stage is built at the start", terrain.has_stage(0) and not terrain.has_stage(1) and _main.features.has_stage(0) and not _main.features.has_stage(1)
		and not _main.features.get_children().any(func(n: Node) -> bool: return n is CragSpider))
	# 地形はひとつながり：ステージの横へずっと離れていっても、足もとに地面があり、ふもとの低地まで下りていく
	terrain.ensure_all_collision()
	await _wait(0.1)
	var space := player.get_world_3d().direct_space_state
	var floating := 0
	var probes := 0
	var lowest_edge := INF
	var misses: Array[String] = []
	for i in range(1, MountainChain.COUNT):
		var middle := MountainChain.plain_starts[i].lerp(MountainChain.plain_ends[i], 0.5)
		var side := MountainChain.gate_direction(i).orthogonal()
		for sign_value: float in [-1.0, 1.0]:
			var previous := INF
			var area := MountainChain.bounds().grow(-6.0)
			for n in range(1, 80):
				var p := middle + side * sign_value * n * 8.0
				if not area.has_point(p):
					break  # 地形の外（ふもとの低地がどこまでも続く）
				# 大岩や木は通り抜けて、地面そのものに当たるまで調べる
				var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, 1400.0, p.y), Vector3(p.x, -50.0, p.y), Player.TERRAIN_LAYER)
				var hit := space.intersect_ray(query)
				for skip in 6:
					if hit.is_empty() or (hit.collider as Node).get_parent() == terrain.ground_body() or (hit.collider as Node).get_parent() == terrain:
						break
					query.exclude = query.exclude + [hit.rid]
					hit = space.intersect_ray(query)
				probes += 1
				if hit.is_empty() or absf((hit.position as Vector3).y - terrain.height_at(p.x, p.y)) > 3.0:  # 遠くは粗いので、少しのずれは許す
					floating += 1
					if misses.size() < 4:
						misses.append("(%.0f, %.0f) hit %s ground %.1f" % [p.x, p.y,
							"none" if hit.is_empty() else "%.1f %s" % [(hit.position as Vector3).y, (hit.collider as Node).name],
							terrain.height_at(p.x, p.y)])
				previous = (hit.position as Vector3).y if not hit.is_empty() else previous
			lowest_edge = minf(lowest_edge, previous)
	_check("the ground is one connected land (no floating islands)", floating == 0 and lowest_edge < 40.0,
		"%d of %d probes without ground, far side at %.1f m %s" % [floating, probes, lowest_edge, misses])
	# 平地：スタート地点から山の裾まで、歩いて進める平らな道
	var flat := 0
	var steep: Array[String] = []
	for k in 11:
		var p := MountainChain.plain_starts[0].lerp(MountainChain.plain_ends[0], k / 10.0)
		var normal_y := terrain.normal_at(p.x, p.y).y
		if normal_y > 0.8:  # 凸凹はあっても、滑り落ちずに歩ける
			flat += 1
		else:
			steep.append("%d:%.2f" % [k, normal_y])
	_check("a walkable plain before the first mountain", flat >= 6, "%d of 11 points walkable %s" % [flat, steep])  # 凸凹は激しいが、半分以上は歩ける
	# 夜になっても、最初の山では“何か”は来ない
	_main.day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH + 0.5
	await _wait(0.3)
	_check("no stalker before the final stage", _main.day.is_night and not _main.stalker.hunting)
	_main.day.time = 0.0
	# 霧の奥へ入りこもうとしても、押し戻される
	var inside := MountainChain.plain_starts[1] + MountainChain.gate_direction(1) * 12.0
	player.spawn_at(Vector3(inside.x, terrain.height_at(inside.x, inside.y) + 0.5, inside.y), 0.0)
	await _wait(1.5)
	var depth := MountainChain.past_gate(1, player.global_position.x, player.global_position.z)
	_check("the fog pushes you back", depth < 9.0, "%.1f m into the fog" % depth)
	# 島の海：砂浜のうしろの海へは、泳いでは戻れない（押し戻される）
	var shore_start := MountainChain.plain_starts[0]
	var to_sea := -(MountainChain.plain_ends[0] - shore_start).normalized()
	var wade := shore_start + to_sea * 75.0
	player.spawn_at(Vector3(wade.x, maxf(terrain.height_at(wade.x, wade.y), Terrain.SEA_LEVEL - 0.6) + 0.3, wade.y), 0.0)
	await _wait(0.3)
	player.face_point(player.get_camera().global_position + Vector3(to_sea.x, 0.0, to_sea.y))
	Input.action_press("move_forward")
	await _wait(4.0)
	Input.action_release("move_forward")
	var sea_depth := terrain.sea_depth(player.global_position.x, player.global_position.z)
	_check("the sea pushes you back to the beach", sea_depth < 2.6, "%.1f m deep" % sea_depth)
	# 横も海：最初のステージの横へ離れると、海岸に出て、その先は海（霧ではなく、海が行き止まり）
	var middle0 := MountainChain.plain_starts[0].lerp(MountainChain.plain_ends[0], 0.5)
	var side0 := (MountainChain.plain_ends[0] - MountainChain.plain_starts[0]).normalized().orthogonal()
	var coast_depths: Array[String] = []
	var sea_on_both_sides := true
	for sign_value: float in [-1.0, 1.0]:
		var far_out := middle0
		while MountainChain.core_distance(0, far_out.x, far_out.y) < Terrain.COAST.y + 30.0:
			far_out += side0 * sign_value * 5.0  # 最初のステージの広がりから、海岸の先まで横へ離れる
		var depth_there := terrain.sea_depth(far_out.x, far_out.y)
		coast_depths.append("%.1f" % depth_there)
		sea_on_both_sides = sea_on_both_sides and depth_there > 2.6 and fog.depth_into(Vector3(far_out.x, 0.0, far_out.y)) < 0.0
	_check("both sides of the first stage end at the sea, not in fog", sea_on_both_sides, "depths %s" % [coast_depths])
	var side_wade := middle0
	while terrain.sea_depth(side_wade.x, side_wade.y) < 0.3:
		side_wade += side0 * 2.0  # 横の波打ち際まで
	player.spawn_at(Vector3(side_wade.x, maxf(terrain.height_at(side_wade.x, side_wade.y), Terrain.SEA_LEVEL - 0.6) + 0.3, side_wade.y), 0.0)
	await _wait(0.3)
	player.face_point(player.get_camera().global_position + Vector3(side0.x, 0.0, side0.y))
	Input.action_press("move_forward")
	await _wait(4.0)
	Input.action_release("move_forward")
	sea_depth = terrain.sea_depth(player.global_position.x, player.global_position.z)
	_check("the sea at the side pushes you back to land", sea_depth < 2.6, "%.1f m deep" % sea_depth)
	# 見えない壁：山頂のたき火をともすまで、次の平地へは歩いて進めない
	var gate := MountainChain.gate_point(1)
	var ahead := MountainChain.gate_direction(1)
	var before_gate := gate - ahead * 6.0
	player.spawn_at(Vector3(before_gate.x, terrain.height_at(before_gate.x, before_gate.y) + 0.5, before_gate.y), 0.0)
	await _wait(0.3)
	player.face_point(player.get_camera().global_position + Vector3(ahead.x, 0.0, ahead.y))
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _wait(3.0)
	Input.action_release("jump")
	Input.action_release("move_forward")
	depth = MountainChain.past_gate(1, player.global_position.x, player.global_position.z)
	_check("an invisible wall blocks the next plain until the summit fire is lit", depth < FogBanks.PASS_MARGIN + 0.5, "%.1f m past the gate" % depth)
	var campfire := _main.features.campfires[1]
	var next := MountainChain.centers[1]
	if _shot_dir != "":
		player.spawn_at(campfire.global_position + Vector3(0.0, 0.5, 2.0), 0.0)
		await _wait(0.2)
		player.face_point(Vector3(next.x, campfire.global_position.y - 10.0, next.y))
		await _wait(1.0)
		await _save_shot("fog_wall.png")
		player.spawn_at(terrain.spawn_point(), terrain.spawn_yaw())
		await _wait(0.2)
		player.face_point(player.get_camera().global_position + Vector3(0.0, 0.25, -1.0))
		await _wait(1.0)
		await _save_shot("fog_from_start.png")
	# 山頂のたき火に着くと、次のステージを作り、その先の霧が晴れていく
	player.spawn_at(campfire.global_position + Vector3(0.0, 0.5, 2.0), 0.0)
	player.face_point(Vector3(next.x, campfire.global_position.y - 10.0, next.y))
	await _wait(1.5)
	_check("reaching the summit clears the fog ahead", fog.is_opened(1) and MountainChain.unlocked == 2 and fog.clear_amount(1) < 1.0)
	_check("the next stage is built when the summit fire is lit", terrain.has_stage(1) and _main.features.has_stage(1) and not terrain.has_stage(2) and terrain.has_stage(0))
	if _shot_dir != "":
		await _wait(3.0)
		await _save_shot("fog_clearing.png")
	for i in 120:
		await _wait(0.1)
		if fog.clear_amount(1) >= 1.0:
			break
	_check("the fog has cleared", fog.clear_amount(1) >= 1.0 and not fog.is_opened(2))
	# 見えない壁は消えている（見えない壁だけに当たる線を、境目の向こうまで引いてみる）
	await _wait(0.2)
	var from := Vector3(before_gate.x, terrain.height_at(before_gate.x, before_gate.y) + 1.0, before_gate.y)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(ahead.x, 0.0, ahead.y) * 12.0, Player.BARRIER_LAYER)
	var barrier := player.get_world_3d().direct_space_state.intersect_ray(query)
	_check("after lighting the summit fire, the way to the next plain is open", barrier.is_empty() and not fog.at_wall(from + Vector3(ahead.x, 0.0, ahead.y) * 6.0))
	var shown := _main.features.get_children().filter(func(n: Node) -> bool: return n is CragSpider and (n as Node3D).visible)
	_check("things of the new stage appear", not shown.is_empty())
	if _shot_dir != "":
		await _save_shot("fog_cleared.png")
	# 次の山頂のたき火をともすと、その次のステージを作り、来た道（最初のステージ）は霧に閉ざされて消える
	var second := _main.features.campfires[2]
	player.spawn_at(second.global_position + Vector3(0.0, 0.5, 2.0), 0.0)
	await _wait(1.5)
	_check("the stage before last is sealed and unloaded", terrain.has_stage(2) and _main.features.has_stage(2) and not terrain.has_stage(0) and not _main.features.has_stage(0)
		and not _main.features.campfires[0].visible and second.visible and _main.checkpoint == 2)
	var sealed_from := Vector3(gate.x, 0.0, gate.y) + Vector3(ahead.x, 0.0, ahead.y) * 8.0
	sealed_from.y = terrain.height_at(sealed_from.x, sealed_from.z) + 1.0
	query = PhysicsRayQueryParameters3D.create(sealed_from, sealed_from - Vector3(ahead.x, 0.0, ahead.y) * 14.0, Player.BARRIER_LAYER)
	barrier = player.get_world_3d().direct_space_state.intersect_ray(query)
	var near_wall := Vector3(gate.x, 0.0, gate.y) + Vector3(ahead.x, 0.0, ahead.y) * 3.0
	_check("an invisible wall blocks the way back", not barrier.is_empty() and fog.at_seal(near_wall))
	var back_there := gate - ahead * 60.0
	_check("the way back is lost in fog", fog.behind_wall(Vector3(back_there.x, 0.0, back_there.y)) and fog.depth_into(Vector3(back_there.x, 0.0, back_there.y)) > 0.0)
	if _shot_dir != "":
		var watch_from := sealed_from + Vector3(ahead.x, 0.0, ahead.y) * 20.0
		watch_from.y = terrain.height_at(watch_from.x, watch_from.z) + 0.5
		player.spawn_at(watch_from, 0.0)
		await _wait(0.2)
		player.face_point(Vector3(back_there.x, sealed_from.y + 5.0, back_there.y))
		await _wait(1.0)
		await _save_shot("fog_sealed_behind.png")


## 山は奥ほど高く、山と山の間には、ひとつ前の山頂より低い谷がある。
## 平らな場所はほとんどなく、崖だらけ。種を変えると、ちがう形の山になる
func _test_chain_shape() -> void:
	_section("mountain chain")
	_main.unlock_all_stages()
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
	var centers_here := MountainChain.centers.duplicate()
	MountainChain.generate(Main.WORLD_SEED)
	_check("the mountains are the same every time", MountainChain.peaks == peaks_here and MountainChain.centers == centers_here)
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
	_main.checkpoint = MountainChain.COUNT - 1  # “何か”が出る最後のステージ
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
	var pickups := _main.features.get_children().filter(func(n: Node) -> bool: return n is ItemBox)
	_check("item boxes placed on the mountains", pickups.size() >= 20, "%d boxes" % pickups.size())
	var kinds := {}
	for box: ItemBox in pickups:
		for kind in box.contents:
			kinds[kind] = true
	_check("many kinds of items are found", kinds.size() >= 10, "%d kinds" % kinds.size())
	# 箱を開けると、中のアイテムが飛び出す
	var box: ItemBox = pickups[0]
	var inside := box.contents.size()
	var inside_kinds := box.contents.duplicate()
	var before_open := _pickups().size()
	player.global_position = box.global_position + box.global_transform.basis.z * 1.6 + Vector3.UP * 0.4  # 持ち物はそのまま
	player.velocity = Vector3.ZERO
	player.face_point(box.global_position + Vector3.UP * 0.3)
	await _wait(0.2)
	_check("looking at a box shows a hint", player.aim_hint() == "E：箱を開ける", player.aim_hint())
	_tap("interact")
	await _wait(0.5)
	var shown := _pickups().filter(func(p: Pickup) -> bool: return p.freeze and p.global_position.distance_to(box.global_position) < 0.8)
	_check("opening a box shows the items inside", box.opened and _pickups().size() == before_open + inside and shown.size() == inside,
		"%d inside" % inside)
	await _wait(0.5)
	_check("the items stay in the box", shown.all(func(p: Pickup) -> bool: return p.global_position.distance_to(box.global_position) < 0.8))
	if not shown.is_empty():
		player.face_point((shown[0] as Pickup).global_position)
	await _wait(0.2)
	_tap("interact")
	await _wait(0.2)
	_check("an item in the box can be taken", player.inventory.count_of(inside_kinds[0]) >= 1)
	player.inventory.remove(inside_kinds[0])  # あとの持ち物のテストのために戻す
	# 持ち物の欄：同じ種類は 3 つまで重なり、6 つの欄がいっぱいになると拾えない
	for kind in [Items.Kind.CHOCOLATE, Items.Kind.CHOCOLATE, Items.Kind.CHOCOLATE, Items.Kind.CHOCOLATE]:
		player.pick_up(kind)
	_check("items stack up to 3 per slot", inventory.count_of(Items.Kind.CHOCOLATE) == 4 and inventory.counts[inventory.slot_of(Items.Kind.CHOCOLATE)] == 3)
	for kind in [Items.Kind.SALT, Items.Kind.ROPE, Items.Kind.CHALK]:
		player.pick_up(kind)
	_check("a full inventory refuses more", not player.pick_up(Items.Kind.CANNED))
	# いろいろなアイテムの効き目
	inventory.clear()
	for k in 4:
		player.pick_up(Items.Kind.CHOCOLATE)
	player.cold = 30.0
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
	if _shot_dir != "" and pickups.size() > 1:
		var closed: Node3D = pickups[1]
		await _shot_from(closed.global_position + Vector3(1.4, 1.0, 1.4), closed.global_position + Vector3.UP * 0.2, "pickup.png")


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
	# アイテムのそばの、いちばん平らな所に立って見る（斜面だと滑って離れてしまう）
	var terrain := _main.terrain
	var stand := Vector3.INF
	var flattest := -1.0
	for k in 8:
		var around := item.global_position + Vector3(cos(k * TAU / 8.0), 0.0, sin(k * TAU / 8.0)) * 1.2
		var normal_y := terrain.normal_at(around.x, around.z).y
		if normal_y > flattest and not terrain.near_rock(around, 0.3):
			flattest = normal_y
			stand = Vector3(around.x, terrain.height_at(around.x, around.z) + 0.05, around.z)
	player.global_position = stand
	player.velocity = Vector3.ZERO
	await _wait(0.1)
	player.face_point(item.global_position)
	await _wait(0.1)
	_check("looking at an item shows a pick-up hint", player.aim_hint().begins_with("E："), "%s (aimed %s, frozen %s, %.2f m from the item)" % [player.aim_hint(), player.aimed, player.frozen, player.get_camera().global_position.distance_to(item.global_position)])
	_tap("interact")
	await _wait(0.2)
	_check("E picks it up again", inventory.count_of(Items.Kind.CHOCOLATE) == 1 and not is_instance_valid(item))
	# 地面を突き抜けたナタや、大岩に埋まったナタは、上へ出てきて、また拾える
	var here := player.global_position
	var buried := _main.features.spawn_item(Items.Kind.NATA, Vector3(here.x + 1.0, terrain.height_at(here.x + 1.0, here.z) - 2.0, here.z), Vector3.ZERO)
	var inside_rock := Vector3.INF
	for cell: Array in (terrain.get("_rock_cells") as Dictionary).values():
		for rock: Array in cell:
			if (rock[1] as Vector3).distance_to(here) < 120.0 and float(rock[3]) > 4.0:
				inside_rock = rock[1]
				break
		if inside_rock.is_finite():
			break
	var stuck: Pickup = null
	if inside_rock.is_finite():
		stuck = _main.features.spawn_item(Items.Kind.NATA, inside_rock, Vector3.ZERO)
	await _wait(1.0)
	var surface := terrain.height_at(buried.global_position.x, buried.global_position.z)
	_check("a machete that fell through the ground comes back up", buried.global_position.y > surface - 0.3, "%.1f m vs ground %.1f" % [buried.global_position.y, surface])
	if stuck:
		_check("a machete stuck inside a boulder comes back out", not terrain.inside_rock(stuck.global_position) and stuck.global_position.y > inside_rock.y,
			"%.1f m above the rock's center" % (stuck.global_position.y - inside_rock.y))
		stuck.queue_free()
	player.global_position = buried.global_position + Vector3(1.2, 0.2, 0.0)
	player.velocity = Vector3.ZERO
	await _wait(0.2)
	player.face_point(buried.global_position)
	await _wait(0.1)
	var had := inventory.count_of(Items.Kind.NATA)
	player.interact()
	await _wait(0.1)
	_check("the machete can be picked up again", inventory.count_of(Items.Kind.NATA) == had + 1, player.aim_hint())

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
		# 足もとのまわり（小さなでこぼこも含めて）が、どこも滑るほど急な所
		var steep_all := true
		for k in 9:
			var offset := Vector2.ZERO if k == 0 else Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * 0.6
			var n := terrain.normal_at(x + offset.x, z + offset.y)
			if n.y < 0.6 or n.y > 0.76:
				steep_all = false
				break
		if steep_all and not terrain.near_rock(Vector3(x, terrain.height_at(x, z), z), 2.0):
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
		var normal := ice.global_transform.basis.z.normalized()
		var thick := ice.global_transform.basis.get_scale().z
		player.spawn_at(ice.global_position + normal * (Player.WALL_GAP + 0.9 * thick) - Vector3.UP * 1.0, 0.0)
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
		_check("tenaga is not out in the daytime", not tenaga.get("_model").visible and not tenaga.is_physics_processing())
		tenaga.set_awake(true)
		await _wait(1.5)  # 垂らした腕の形が落ち着くまで
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
	kodama.steal_chance = 1.0  # テストでは必ず盗ませる
	var carried := func() -> int:
		var total := 0
		for count in player.inventory.counts:
			total += count
		return total
	var carried_before: int = carried.call()
	kodama.global_position = player.global_position + Vector3(0.8, 0.0, 0.0)
	await _wait(0.2)
	_check("kodama steal an item", kodama.state == "fleeing" and kodama.carrying >= 0 and carried.call() == carried_before - 1)
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
	# 鬼火：触れると冷える（たき火から離れた、平地の中ほどで。たき火のそばは一息つける場所なので、化け物は消える）
	var open_field := MountainChain.plain_starts[0].lerp(MountainChain.plain_ends[0], 0.45)
	player.spawn_at(Vector3(open_field.x, terrain.height_at(open_field.x, open_field.y) + 0.5, open_field.y), 0.0)
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
	bird.aim_error = 0.0  # テストでは狙いをはずさない
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
	player.stamina = player.max_stamina() * 0.5  # 疲れた状態で、ぶら下がって休む
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
	# スタート地点のたき火の守り（広い）から離れた、平地の中ほどで試す
	var field := MountainChain.plain_starts[0].lerp(MountainChain.plain_ends[0], 0.4)
	player.spawn_at(Vector3(field.x, _main.terrain.height_at(field.x, field.y) + 0.5, field.y), 0.0)
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
	await _wait(0.5)  # 昼か夜かが、化け物たちに伝わるのを待つ
	_check("spiders hide in the daytime", not spider.get("_model").visible and not spider.is_physics_processing())
	# 壁に取りつける岩グモを選ぶ（大岩が壁をおおっている所もある）
	var space := _main.player.get_world_3d().direct_space_state
	for candidate: CragSpider in spiders:
		_main.terrain.ensure_collision(candidate.global_position, 30.0)
		await _wait(0.05)
		var n: Vector3 = candidate.get("_normal")
		var from := candidate.global_position + n * 0.45 - Vector3.UP * 1.2 + Vector3.UP
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - n * 1.2, Player.TERRAIN_LAYER)).is_empty():
			spider = candidate
			break
	spider.set_awake(true)
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
	if bool(peeker.get("_retreating")) or not peeker.active:
		_check("headlamp stare repels the peeker", true)
	elif not peeker.call("_line_of_sight", player.get_camera().global_position, peeker.head_position()):
		_note("skip headlamp check: a rock is between you and the peeker")
	else:
		_check("headlamp stare repels the peeker", false)
	Input.action_release("grab")


func _test_pale_one() -> void:
	_section("pale one")
	await _restart()
	_calm_weather()
	_calm_enemies()
	var player := _main.player
	# 雪山の、たき火（休み場）から離れた平らな所に立つ
	var fires := PackedVector3Array()
	for campfire in _main.features.campfires:
		fires.append(campfire.global_position)
	var snow_rng := RandomNumberGenerator.new()
	snow_rng.seed = 3
	var snow_spots := _main.terrain.random_ledge_points(snow_rng, 1, Biomes.Id.SNOW, 1.0, 1, fires, Campfire.REST_RADIUS + 15.0, 20.0, 0.85)
	player.spawn_at((snow_spots[0] if not snow_spots.is_empty() else _main.terrain.checkpoint(Biomes.Id.SNOW)) + Vector3(0.0, 0.5, 0.0), 0.0)
	var pale := _main.enemies.pale_one
	await _wait(1.0)
	_check("no pale one in the daytime", not pale.active)
	_main.day.time = DayCycle.DAY_LENGTH + DayCycle.SUNSET_LENGTH * 0.8  # 日が暮れてきた
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


## エモート（動くとやめる）と、崖の下の仲間に手を差し伸べて引き上げる
func _test_social() -> void:
	_section("emotes and pulling up")
	await _restart()
	_calm_weather()
	_calm_enemies()
	var player := _main.player
	var terrain := _main.terrain
	player.spawn_at(terrain.spawn_point(), terrain.spawn_yaw())
	await _wait(0.5)
	player.play_emote("dance")
	await _wait(0.6)
	_check("dancing", player.emote == "dance")
	if _shot_dir != "":
		var front := -player.global_transform.basis.z
		await _shot_from(player.global_position + front * 3.0 + Vector3.UP * 1.3, player.global_position + Vector3.UP * 0.9, "emote_dance.png", true)
	Input.action_press("move_forward")
	await _wait(0.3)
	Input.action_release("move_forward")
	_check("moving stops the emote", player.emote == "")
	player.play_emote("sit")
	await _wait(0.8)
	_check("sitting lowers the eyes", player.get_camera().global_position.y < player.global_position.y + 1.2)
	player.emote = ""
	# 崖のふちを探して、外を向いて立つ
	var edge := _find_edge(MountainChain.centers[0])
	if not edge.is_empty():
		player.spawn_at(edge[0], 0.0)
		player.face_point(player.get_camera().global_position + edge[1])
		await _wait(0.4)
		var buddy := _main.spawn_buddy()
		await _wait(0.4)
		_check("a buddy hangs below the edge", buddy.state == Player.State.CLIMB, Player.State.keys()[buddy.state])
		if _shot_dir != "":
			await _shot_from(player.global_position + edge[1] * 4.0 + Vector3.UP * 0.5, buddy.global_position + Vector3.UP * 1.0, "buddy_hanging.png", true)
		Input.action_press("reach")
		for i in 20:
			await _wait(0.1)
			if buddy.is_being_pulled():
				break
		if _shot_dir != "":
			await _shot_from(player.global_position + edge[1].cross(Vector3.UP) * 3.5 + Vector3.UP * 1.2, player.global_position, "pull_up.png", true)
		await _wait(1.2)
		Input.action_release("reach")
		_check("reaching out pulls the buddy up", buddy.state == Player.State.WALK and buddy.global_position.y > player.global_position.y - 1.0,
			"buddy %.1f m below, %s" % [player.global_position.y - buddy.global_position.y, Player.State.keys()[buddy.state]])
		buddy.queue_free()
		_main.buddy = null
	else:
		_note("skip pull-up test: no cliff edge found")


## 山 center のまわりで、足元から先がすとんと落ちている崖のふちを探す。[立つ場所, 外向き] を返す
func _find_edge(center: Vector2) -> Array:
	var terrain := _main.terrain
	for step in 48:
		var angle := step * TAU / 48.0
		var out := Vector2(cos(angle), sin(angle))
		for r in range(8, 50):
			var p := center + out * float(r)
			var here := terrain.height_at(p.x, p.y)
			var ahead := center + out * (r + 2.5)
			var behind := center + out * (r - 1.0)
			if terrain.near_landing(p.x, p.y, 3.0) or terrain.near_rock(Vector3(p.x, here, p.y), 1.5):
				continue  # 岩棚のなだらかな縁や、岩のそばはさける（くっきりした崖の縁を探す）
			if terrain.normal_at(p.x, p.y).y > 0.85 and absf(terrain.height_at(behind.x, behind.y) - here) < 0.6 \
					and here - terrain.height_at(ahead.x, ahead.y) > 4.0:
				return [Vector3(p.x, here + 0.4, p.y), Vector3(out.x, 0.0, out.y)]
	return []


## ナタで獣を狩り、はぎとる。イノシシは突進してくる。木いちごを摘み、手に持って左クリックで食べる
func _test_hunting() -> void:
	_section("hunting")
	await _restart()
	_calm_weather()
	_calm_enemies()
	var player := _main.player
	var terrain := _main.terrain
	var director := _main.critters
	director.clear()
	var here := terrain.spawn_point()
	player.spawn_at(here, 0.0)
	await _wait(0.3)
	# シカ：目の前に置いて、ナタで二度叩く
	var ahead := here + Vector3(0.0, 0.0, -1.8)
	ahead.y = terrain.height_at(ahead.x, ahead.z)
	var deer := Critter.new()
	director.add_child(deer)
	deer.setup("deer", ahead, player, terrain)
	player.inventory.selected = player.inventory.slot_of(Items.Kind.NATA)
	player.stowed = false
	for swing in 2:
		player.face_point(deer.global_position + Vector3.UP * 0.6)
		await _wait(0.1)
		deer.global_position = ahead
		deer.state = "idle"
		_tap("use_item")
		await _wait(0.7)
	_check("the machete kills a deer", deer.dead, "health %.0f" % deer.health)
	# 逃げる獣は、目の前では消えない（崖や岩にはばまれても）
	var hare := Critter.new()
	director.add_child(hare)
	var hare_at := here + Vector3(1.5, 0.0, 2.5)
	hare_at.y = terrain.height_at(hare_at.x, hare_at.z)
	hare.setup("rabbit", hare_at, player, terrain)
	hare.call("_start_flee")
	await _wait(3.5)
	_check("a fleeing animal does not vanish while you are close", not hare.gone or hare.global_position.distance_to(player.global_position) > 12.0,
		"%.1f m away" % hare.global_position.distance_to(player.global_position))
	hare.queue_free()
	var meat_before := player.inventory.count_of(Items.Kind.RAW_MEAT)
	deer.interact(player)
	_check("skinning gives meat and a pelt", player.inventory.count_of(Items.Kind.RAW_MEAT) > meat_before and player.inventory.count_of(Items.Kind.PELT) >= 1,
		"%s" % [player.inventory.kinds])
	# イノシシ：近づくと突進してきて、ケガをする（スタート地点のたき火の守りの外の、岩のない平らな所で）
	var inland := MountainChain.plain_starts[0].lerp(MountainChain.plain_ends[0], 0.4)
	var across := (MountainChain.plain_ends[0] - MountainChain.plain_starts[0]).normalized().orthogonal()
	for k in 40:
		var along := MountainChain.plain_starts[0].lerp(MountainChain.plain_ends[0], 0.3 + (k % 5) * 0.1) + across * (k / 5 - 4) * 8.0
		var spot := Vector3(along.x, terrain.height_at(along.x, along.y), along.y)
		if not terrain.near_rock(spot, 9.0) and terrain.normal_at(along.x, along.y).y > 0.9 and terrain.normal_at(along.x + 6.0, along.y).y > 0.85:
			inland = along
			break
	var field := Vector3(inland.x, terrain.height_at(inland.x, inland.y) + 0.5, inland.y)
	player.spawn_at(field, 0.0)
	await _wait(0.3)
	player.injury = 0.0
	var boar := Critter.new()
	director.add_child(boar)
	var boar_at := field + Vector3(6.0, 0.0, 0.0)
	boar_at.y = terrain.height_at(boar_at.x, boar_at.z)
	boar.setup("boar", boar_at, player, terrain)
	var struck := false
	var seen := []
	for i in 50:
		await _wait(0.1)
		if seen.is_empty() or seen[-1] != boar.state:
			seen.append(boar.state)
		if player.injury > 0.0:
			struck = true
			break
	_check("a boar charges into you", struck, "states %s" % [seen])
	player.spawn_at(here, 0.0)
	await _wait(0.3)
	# 木いちご：摘んで、手に持って左クリックで食べる
	var bushes := _main.features.get_children().filter(func(n: Node) -> bool: return n is Harvestable)
	_check("fruit to harvest grows in the forest", bushes.size() >= 30, "%d plants" % bushes.size())
	var berries: Harvestable = null
	for plant: Harvestable in bushes:
		if plant.kind == Items.Kind.BERRIES:
			berries = plant
			break
	if berries:
		player.inventory.clear()
		berries.interact(player)
		_check("picking berries gives berries", player.inventory.count_of(Items.Kind.BERRIES) >= 2 and not berries.is_ripe())
		player.inventory.selected = player.inventory.slot_of(Items.Kind.BERRIES)
		player.stowed = false
		var count := player.inventory.count_of(Items.Kind.BERRIES)
		player.hunger = 30.0
		_tap("use_item")
		await _wait(0.2)
		_check("left click eats the berries in hand", player.inventory.count_of(Items.Kind.BERRIES) == count - 1 and player.hunger < 30.0)
	boar.queue_free()


## 地帯ごとの動物が現れ、近づくと顔を上げて逃げる。霊峰の白ぎつねは道を案内する
func _test_critters() -> void:
	_section("critters")
	await _restart()
	_calm_weather()
	_calm_enemies()
	var player := _main.player
	var terrain := _main.terrain
	var director := _main.critters
	var seen := {}
	for biome in Biomes.NAMES.size():
		director.clear()
		var middle := MountainChain.plain_starts[biome].lerp(MountainChain.plain_ends[biome], 0.5)
		player.spawn_at(Vector3(middle.x, terrain.height_at(middle.x, middle.y) + 0.5, middle.y), 0.0)
		await _wait(0.2)
		for attempt in 6:
			director.spawn_group(biome)
		for critter in director.critters():
			seen[critter.species] = true
		if _shot_dir != "" and not director.critters().is_empty():
			var first: Critter = director.critters()[0]
			await _wait(1.0)
			await _shot_from(first.global_position + Vector3(4.0, 2.0, 4.0), first.global_position + Vector3.UP * 0.5, "critters_%d.png" % biome, true)
	_note("animals: %s" % str(seen.keys()))
	_check("animals live in every biome", seen.size() >= 6, "%d kinds" % seen.size())
	# 近づくと逃げる
	director.clear()
	var middle := MountainChain.plain_starts[0].lerp(MountainChain.plain_ends[0], 0.5)
	player.spawn_at(Vector3(middle.x, terrain.height_at(middle.x, middle.y) + 0.5, middle.y), 0.0)
	await _wait(0.2)
	var walker: Critter = null
	for attempt in 10:
		director.spawn_group(Biomes.Id.FOREST)
		for critter in director.critters():
			if Critter.SPECIES[critter.species].kind in ["walker", "hopper"]:
				walker = critter
				break
		if walker:
			break
	if walker:
		var start := walker.global_position
		player.global_position = walker.global_position + Vector3(2.5, 0.5, 0.0)
		await _wait(1.5)
		_check("animals run away when you come close", walker.state == "flee" or walker.gone or walker.global_position.distance_to(start) > 2.0,
			"%s is %s" % [walker.species, walker.state])
	# 白ぎつねの道案内
	director.clear()
	var summit_plain := MountainChain.plain_starts[3].lerp(MountainChain.plain_ends[3], 0.3)
	player.spawn_at(Vector3(summit_plain.x, terrain.height_at(summit_plain.x, summit_plain.y) + 0.5, summit_plain.y), 0.0)
	await _wait(0.3)
	var fox: Critter = null
	for attempt in 20:
		director.spawn_group(Biomes.Id.SUMMIT)
		for critter in director.critters():
			if critter.species == "fox":
				fox = critter
		if fox:
			break
	if fox:
		fox.global_position = player.global_position + Vector3(3.0, 0.0, 0.0)
		fox.global_position.y = terrain.height_at(fox.global_position.x, fox.global_position.z)
		var goal := director.guide_target
		var before := Vector2(fox.global_position.x - goal.x, fox.global_position.z - goal.z).length()
		await _wait(2.0)
		var after := Vector2(fox.global_position.x - goal.x, fox.global_position.z - goal.z).length()
		_check("the white fox leads the way", fox.state == "guide" and after < before - 1.0, "%.1f m -> %.1f m" % [before, after])
		if _shot_dir != "":
			await _shot_from(fox.global_position + Vector3(2.5, 1.5, 2.5), fox.global_position + Vector3.UP * 0.3, "fox.png", true)
	else:
		_check("a white fox appears on the sacred peak", false)
	director.clear()


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


## 見えない壁：前へ歩く・跳ぶ・壁をつかんで登る、をどこで試しても、火をともすまで次のステージへは入れない
func _test_gate_leak() -> void:
	_section("gate leak")
	await _restart(false)
	var player := _main.player
	var terrain := _main.terrain
	var gate := MountainChain.gate_point(1)
	var ahead := MountainChain.gate_direction(1)
	var across := ahead.orthogonal()
	var leaks: Array[String] = []
	var tries := 0
	for lateral: float in [-50.0, -25.0, 0.0, 25.0, 50.0]:
		var start := gate + across * lateral - ahead * 3.0
		var ground := terrain.height_at(start.x, start.y)
		terrain.ensure_collision(Vector3(start.x, ground, start.y), 30.0)
		player.spawn_at(Vector3(start.x, ground + 0.5, start.y), 0.0)
		await _wait(0.2)
		for mode in ["walk", "climb"]:
			tries += 1
			player.spawn_at(Vector3(start.x, ground + 0.5, start.y), 0.0)
			player.face_point(player.get_camera().global_position + Vector3(ahead.x, 0.0, ahead.y))
			Input.action_press("move_forward")
			if mode == "climb":
				Input.action_press("grab")
			var furthest := -INF
			for i in 60:
				if i % 5 == 0:
					Input.action_press("jump")
				elif i % 5 == 1:
					Input.action_release("jump")
				await _wait(0.1)
				furthest = maxf(furthest, MountainChain.past_gate(1, player.global_position.x, player.global_position.z))
			Input.action_release("move_forward")
			Input.action_release("grab")
			Input.action_release("jump")
			if furthest > FogBanks.PASS_MARGIN + 1.0:
				leaks.append("%s at %+.0f m: %.1f m past" % [mode, lateral, furthest])
	_check("nobody gets past the invisible wall before the fire is lit", leaks.is_empty(), "%d tries, leaks %s" % [tries, leaks])


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
	# 音量は項目ごと：音はそれぞれの項目の通り道に流れ、項目の音量がかかる
	var own := _main.player.find_children("*", "AudioStreamPlayer", true, false)
	_check("the player's own sounds go to the self volume", not own.is_empty() and own.all(func(s: Node) -> bool: return s.get("bus") == &"Self"))
	var fire := _main.lobby.get("campfire") as Node
	var crackle := fire.find_children("*", "AudioStreamPlayer3D", true, false)
	_check("a campfire goes to the nature volume", not crackle.is_empty() and crackle[0].get("bus") == &"World")
	_check("echoing monster voices go to the monster volume", AudioServer.get_bus_send(AudioServer.get_bus_index("Echo")) == &"Monsters")
	var before := Settings.volume_animals
	Settings.volume_animals = 0.5
	Settings.apply()
	_check("each volume sets its own bus", absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Animals")) - linear_to_db(0.5)) < 0.01
		and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Monsters")) - linear_to_db(maxf(Settings.volume_monsters, 0.0001))) < 0.01)
	Settings.volume_animals = 0.0
	Settings.apply()
	_check("a volume at zero mutes it", AudioServer.is_bus_mute(AudioServer.get_bus_index("Animals")))
	Settings.volume_animals = before
	Settings.apply()


# --- 重さの計測（--perf） ---

## 垂直同期を切って、いろいろな場所の FPS と描画の数を測る
func _measure_performance() -> void:
	_section("performance")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var player := _main.player
	await _measure("lobby")
	player.global_position = _main.lobby.get("_board_point") + Vector3(0.0, 0.3, 0.0)
	await _wait_for_climb()
	var terrain := _main.terrain
	_note("build: %d nodes in the mountain features, %d rocks noted" % [_main.features.get_child_count(), terrain.get("_rock_cells").values().reduce(func(a: int, l: Array) -> int: return a + l.size(), 0)])
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
		if biome == 0 and "--breakdown-summit" in OS.get_cmdline_user_args():
			await _wait(8.0)
			await _measure("  (settled)")
			var rock_groups: Array = terrain.get("_rock_groups")
			for group: Variant in rock_groups:
				if group != null:
					(group as Node3D).visible = false
			await _measure("  - without the big rocks")
			for group: Variant in rock_groups:
				if group != null:
					(group as Node3D).visible = true
			for child in terrain.get_children():
				if child is MeshInstance3D:
					child.visible = false
			await _measure("  - without the ground")
			for child in terrain.get_children():
				if child is MeshInstance3D:
					child.visible = true
			_main.fog.suppressed = true
			await _measure("  - without the fog banks")
			_main.fog.suppressed = false
			for child in _main.features.get_children():
				if child is Node3D and not child is Campfire:
					child.visible = false
			await _measure("  - without trees, props, gimmicks")
			for child in _main.features.get_children():
				if child is Node3D:
					child.visible = true
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
	var saved_retro := Settings.retro
	for level in [0, 3]:
		Settings.retro = level
		Settings.apply()
		await _measure("  - screen roughness %s (3D scale %.2f, window %s)" % [Settings.RETRO_NAMES[level], get_viewport().scaling_3d_scale, get_window().size])
	Settings.retro = saved_retro
	Settings.apply()
	var world := _main.day.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment
	var environment := world.environment
	environment.glow_enabled = false
	await _measure("  - without glow")
	environment.glow_enabled = true
	environment.background_mode = Environment.BG_COLOR
	await _measure("  - without the sky")
	environment.background_mode = Environment.BG_SKY
	environment.fog_enabled = false
	await _measure("  - without distance fog")
	environment.fog_enabled = true
	var retro := _main.get_children().filter(func(n: Node) -> bool: return n is RetroFilter)
	if not retro.is_empty():
		(retro[0] as CanvasLayer).visible = false
		await _measure("  - without the retro filter")
		(retro[0] as CanvasLayer).visible = true
	var camera := _main.player.get_camera()
	camera.cull_mask &= ~PlayerHands.HANDS_LAYER
	await _measure("  - without hands and held item")
	camera.cull_mask |= PlayerHands.HANDS_LAYER
	var hud_nodes := _main.get_children().filter(func(n: Node) -> bool: return n is CanvasLayer and not n is RetroFilter)
	for n: CanvasLayer in hud_nodes:
		n.visible = false
	await _measure("  - without HUD layers")
	for n: CanvasLayer in hud_nodes:
		n.visible = true
	_main.terrain.set_physics_process(false)
	await _measure("  - without collision streaming")
	_main.terrain.set_physics_process(true)
	await _wait(15.0)
	await _measure("  - after streaming settles")
	_main.fog.suppressed = true
	await _measure("  - without the fog banks")
	_main.fog.suppressed = false
	_main.critters.process_mode = Node.PROCESS_MODE_DISABLED
	_main.enemies.process_mode = Node.PROCESS_MODE_DISABLED
	await _measure("  - without animals and monsters")
	_main.critters.process_mode = Node.PROCESS_MODE_INHERIT
	_main.enemies.process_mode = Node.PROCESS_MODE_INHERIT
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
	var rock_groups: Array = _main.terrain.get("_rock_groups")
	for group: Variant in rock_groups:
		if group != null:
			(group as Node3D).visible = false
	await _measure("  - without the big rocks")
	for group: Variant in rock_groups:
		if group != null:
			(group as Node3D).visible = true
	for child in _main.terrain.get_children():
		if child is MeshInstance3D:
			child.visible = false
	await _measure("  - without the ground")
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
	var cpu := 0.0
	var physics := 0.0
	var gpu := 0.0
	var viewport_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	while elapsed < 3.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		elapsed += dt
		times.append(dt)
		cpu += Performance.get_monitor(Performance.TIME_PROCESS)
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		draws = maxf(draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives = maxf(primitives, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	times.sort()
	var average := elapsed / times.size()
	var worst := times[int(times.size() * 0.99)]  # 遅いほうから 1% のフレーム
	_note("%-32s avg %5.0f fps   1%% low %5.0f fps   draw calls %5d   triangles %7d   video mem %d MB   process %.1f ms  physics %.1f ms  gpu %.1f ms" % [label, 1.0 / average,
		1.0 / worst, draws, primitives, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		cpu / times.size() * 1000.0, physics / times.size() * 1000.0, gpu / times.size()])
	_note("      physics: active %d, pairs %d, islands %d" % [Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)])


# --- スクリーンショット ---

func _overview_shot() -> void:
	var world := _main.day.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment
	world.environment.fog_enabled = false
	var c := MountainChain.centers[0]
	var r: float = MountainChain.radii[0]
	await _shot_from(Vector3(c.x + r * 3.2, MountainChain.peaks[0] * 1.3, c.y + r * 2.0), Vector3(c.x, MountainChain.peaks[0] * 0.4, c.y - r), "overview.png")
	world.environment.fog_enabled = true


## GPU に作る物の数を数える（--only=census）。多すぎると Vulkan のバッファが作れなくなる
func _test_census() -> void:
	_section("census")
	var meshes := {}
	var materials := {}
	var counts := {}
	var by_parent := {}
	for node in _main.find_children("*", "GeometryInstance3D", true, false):
		var kind := node.get_class()
		counts[kind] = counts.get(kind, 0) + 1
		var owner_name := String(node.get_parent().get_class()) + ":" + String(node.get_parent().name).left(18)
		var top := node
		while top.get_parent() != _main and top.get_parent() != null:
			top = top.get_parent()
		by_parent[top.name] = by_parent.get(top.name, 0) + 1
		var geometry := node as GeometryInstance3D
		if geometry.material_override:
			materials[geometry.material_override.get_rid()] = true
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh:
			mesh = (node as MultiMeshInstance3D).multimesh.mesh
			meshes[(node as MultiMeshInstance3D).multimesh.get_rid()] = true
		if mesh:
			meshes[mesh.get_rid()] = true
			for i in mesh.get_surface_count():
				var material := mesh.surface_get_material(i)
				if material:
					materials[material.get_rid()] = true
	_note("geometry nodes %s" % str(counts))
	_note("by top node %s" % str(by_parent))
	_note("unique meshes/multimeshes %d, unique materials %d" % [meshes.size(), materials.size()])
	# 置き物の種類ごとに、自分だけのメッシュ（ほかと共有していないもの）がいくつあるか
	var mesh_users := {}
	for node in _main.features.find_children("*", "GeometryInstance3D", true, false):
		var rid: Variant = null
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			rid = (node as MeshInstance3D).mesh.get_rid()
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh:
			rid = (node as MultiMeshInstance3D).multimesh.get_rid()
		elif node is CPUParticles3D:
			rid = node.get_instance_id()
		var owner_node := node
		while owner_node.get_parent() != _main.features:
			owner_node = owner_node.get_parent()
		var kind: String = owner_node.get_script().get_global_name() if owner_node.get_script() else owner_node.get_class()
		if not mesh_users.has(kind):
			mesh_users[kind] = {}
		mesh_users[kind][rid] = true
	var summary := {}
	for kind: String in mesh_users:
		summary[kind] = mesh_users[kind].size()
	_note("unique meshes by feature kind %s" % str(summary))
	var particles := {}
	for node in _main.find_children("*", "CPUParticles3D", true, false):
		var owner_node: Node = node
		while owner_node.get_parent() and owner_node.get_parent() != _main.features and owner_node.get_parent() != _main:
			owner_node = owner_node.get_parent()
		var kind: String = owner_node.get_script().get_global_name() if owner_node.get_script() else owner_node.get_class()
		particles[kind] = particles.get(kind, 0) + 1
	_note("cpu particles by owner %s" % str(particles))


## 最初のステージを、決まった場所から眺めた景色（作りこみの確認用。--only=look）
func _look_shots() -> void:
	_main.day.time = 20.0  # 昼
	_calm_weather()
	var terrain := _main.terrain
	var c := MountainChain.centers[0]
	var r: float = MountainChain.radii[0]
	var top: float = MountainChain.peaks[0]
	var start := terrain.spawn_point()
	var foot := MountainChain.plain_ends[0]
	var middle := MountainChain.plain_starts[0].lerp(foot, 0.5)
	var summit := Vector3(c.x, top, c.y)
	var inland3 := MountainChain.plain_ends[0] - MountainChain.plain_starts[0]
	var back3 := -Vector3(inland3.x, 0.0, inland3.y).normalized()
	var views := [
		["look_beach.png", start + Vector3(0.0, 1.6, 0.0) - back3 * 6.0, start + back3 * 30.0 + Vector3(0.0, -1.0, 0.0)],
		["look_coast.png", start + back3 * 40.0 + Vector3(60.0, 30.0, 0.0), start + Vector3(0.0, 0.0, 0.0)],
		["look_start.png", start + Vector3(0.0, 1.5, 0.0), summit],
		["look_plain_above.png", Vector3(middle.x + 30.0, terrain.height_at(middle.x, middle.y) + 45.0, middle.y + 60.0), Vector3(c.x, top * 0.35, c.y)],
		["look_foot.png", Vector3(foot.x + 8.0, terrain.height_at(foot.x, foot.y) + 2.0, foot.y + 25.0), Vector3(c.x, top * 0.5, c.y)],
		["look_mountain_south.png", Vector3(c.x - r * 0.4, top * 0.55, c.y + r * 2.6), Vector3(c.x, top * 0.5, c.y)],
		["look_mountain_east.png", Vector3(c.x + r * 2.6, top * 0.7, c.y + r * 0.3), Vector3(c.x, top * 0.45, c.y)],
		["look_mountain_west.png", Vector3(c.x - r * 2.4, top * 0.6, c.y - r * 0.5), Vector3(c.x, top * 0.45, c.y)],
		["look_aerial.png", Vector3(c.x + r * 1.5, top * 2.2, c.y + r * 3.5), Vector3(c.x, top * 0.3, c.y - r * 0.5)],
		["look_fog_far.png", Vector3(c.x + r * 0.8, top * 1.1, c.y + r * 2.2), Vector3(c.x, top * 0.9, c.y - r * 2.5)],
	]
	# 山の中腹の斜面を、すぐ近くから見る
	var angle := deg_to_rad(110.0)
	var slope := c + Vector2(cos(angle), sin(angle)) * r * 0.55
	var slope_y := terrain.height_at(slope.x, slope.y)
	views.append(["look_slope_close.png", Vector3(slope.x, slope_y + 6.0, slope.y) + Vector3(cos(angle), 0.0, sin(angle)) * 30.0, Vector3(slope.x, slope_y + 10.0, slope.y)])
	# 頂上から、霧のかかった次のステージのほうを見る
	var ahead := MountainChain.gate_direction(1)
	views.append(["look_summit_fog.png", terrain.checkpoint(0) + Vector3(0.0, 1.8, 0.0), terrain.checkpoint(0) + Vector3(ahead.x, -0.1, ahead.y) * 50.0])
	for view: Array in views:
		await _shot_from(view[1], view[2], view[0])
	# どの山の壁も、岩の出っぱりで入り組んでいるか（霧を消し、先のステージも見せて）
	_main.fog.suppressed = true
	var wall_rng := RandomNumberGenerator.new()
	wall_rng.seed = 5
	for stage in MountainChain.COUNT:
		terrain.show_stage(stage)
		_main.features.build_stage(stage)
		var walls := terrain.random_wall_points(wall_rng, 2, stage, 30.0)
		for k in walls.size():
			var p: Vector3 = walls[k][0]
			var n: Vector3 = walls[k][1]
			var out := Vector3(n.x, 0.0, n.z).normalized()
			await _shot_from(p + out * 16.0 + Vector3.UP * 4.0, p + Vector3.UP * 2.0, "look_wall_%d_%d.png" % [stage, k])
	_main.fog.suppressed = false
	# 山の上の造形物を、近くから（最初の山にあるもの）
	for prop_name: String in _main.features.mountain_props:
		for t: Transform3D in _main.features.mountain_props[prop_name]:
			if _main.terrain.stage_of(t.origin) != 0:
				continue
			var out := Vector3(t.basis.z.x, 0.0, t.basis.z.z).normalized()
			var side := out.cross(Vector3.UP)
			var eye := t.origin + out * 4.5 + side * 1.5 + Vector3.UP * 2.2
			await _shot_from(eye, t.origin + Vector3.UP * (0.0 if prop_name in ["bridge", "chain"] else 0.8), "look_mp_%s.png" % prop_name)
			break
	# 平地の建物・巨木を、近くから
	var shown := {}
	for node in _main.features.get_children():
		if node.has_meta("prop") and not shown.has(node.get_meta("prop")):
			shown[node.get_meta("prop")] = true
			var at := (node as Node3D).global_position
			var reach := 30.0 if node.get_meta("prop") == "shinboku" else 11.0
			await _shot_from(at + Vector3(reach * 0.7, reach * 0.45, reach * 0.7), at + Vector3.UP * reach * 0.3, "look_prop_%s.png" % node.get_meta("prop"))


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

## ロビーに戻ってからバスに乗り直し、登山口から始める（テストでは毎回同じ山）。
## all_stages なら、すべてのステージをすぐに出す（ふつうは山頂に着くたびに現れる）
func _restart(all_stages := true) -> void:
	Input.action_release("move_forward")
	Input.action_release("grab")
	_main.call("_return_to_lobby")
	_main.player.global_position = _main.lobby.get("_board_point") + Vector3(0.0, 0.3, 0.0)
	await _wait_for_climb()
	if all_stages:
		_main.unlock_all_stages()


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
	player.spawn_at(_main.terrain.foot_point(0), _main.terrain.foot_yaw(0))  # 最初の山の裾から、山へ向かって歩く
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
