class_name EnemyDirector
extends Node
## 地帯ごとの化け物を、状況に応じて出したり消したりする。
##   樹海：木霊（遠巻きに見ていて、持ち物を盗む）
##   樹海・岩場：のぞき（登っている崖の上から覗く）
##   岩場：石投げ（上の岩棚から石を投げる）、壁の手（夜の崖から生える）
##   岩場・雪山：怪鳥（空を旋回して急降下してくる）
##   雪山：白い人（見ていない間だけ近づく）、雪潜り（雪の下から噛みつく）
##   霊峰：影法師（目を離すたびに近づく）、壁の手、鬼火（夜はどの山にも出る）
## 夜の“何か”、壁の岩グモ、木の上の手長はここでは扱わない。

const PEEKER_CHANCE_DAY := 0.3
const PEEKER_CHANCE_NIGHT := 0.55
const PEEKER_COOLDOWN := 15.0
const KODAMA_COUNT := 5
const ONIBI_COUNT := 4
const HAND_COUNT := 3

var player: Player
var terrain: Terrain
var day: DayCycle
var features: MountainFeatures
var peeker: Peeker
var pale_one: PaleOne
var kodamas: Array[Kodama] = []
var ishinage: Ishinage
var kaichou: Kaichou
var yukimoguri: Yukimoguri
var onibi: Array[Onibi] = []
var shadow: ShadowClimber
var hands: Array[WallHand] = []

var _peeker_cooldown := 8.0
var _was_climbing := false
var _crag_ledges := PackedVector3Array()
var _cooldowns := {}  # 化け物の名前 → 次に出せるまでの秒数
var _check := 0.0


func setup(owner_player: Player, mountain: Terrain, day_cycle: DayCycle) -> void:
	player = owner_player
	terrain = mountain
	day = day_cycle
	peeker = Peeker.new()
	add_child(peeker)
	pale_one = PaleOne.new()
	pale_one.player = player
	pale_one.terrain = terrain
	add_child(pale_one)
	for i in KODAMA_COUNT:
		var kodama := Kodama.new()
		kodama.player = player
		kodama.terrain = terrain
		add_child(kodama)
		kodamas.append(kodama)
	ishinage = Ishinage.new()
	add_child(ishinage)
	kaichou = Kaichou.new()
	add_child(kaichou)
	yukimoguri = Yukimoguri.new()
	add_child(yukimoguri)
	for i in ONIBI_COUNT:
		var wisp := Onibi.new()
		add_child(wisp)
		onibi.append(wisp)
	shadow = ShadowClimber.new()
	add_child(shadow)
	for i in HAND_COUNT:
		var hand := WallHand.new()
		add_child(hand)
		hands.append(hand)


## 山を作り直したあとに呼ぶ（石投げが立つ岩棚を探しておく）
func prepare(mountain_features: MountainFeatures) -> void:
	features = mountain_features
	for kodama in kodamas:
		kodama.features = features
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.run_seed + 21
	_crag_ledges = terrain.random_ledge_points(rng, 60, Biomes.Id.CRAG, 5.0, 1, PackedVector3Array(), 0.0, 8.0, 0.8)


func reset() -> void:
	peeker.hide_now()
	pale_one.vanish()
	pale_one.cooldown = 0.0
	_peeker_cooldown = 8.0
	for kodama in kodamas:
		kodama.vanish()
	ishinage.leave()
	kaichou.state = "gone"
	kaichou.visible = false
	yukimoguri.stop()
	for wisp in onibi:
		wisp.vanish()
	shadow.vanish()
	for hand in hands:
		hand.state = "hidden"
		hand.visible = false
	_cooldowns = {"kodama": 20.0, "ishinage": 15.0, "kaichou": 20.0, "yukimoguri": 8.0, "onibi": 10.0, "shadow": 15.0, "hand": 10.0}


func _physics_process(delta: float) -> void:
	if player == null or player.frozen:
		return
	var biome := Biomes.at(player.global_position)
	for key: String in _cooldowns:
		_cooldowns[key] -= delta

	# のぞき：樹海と岩場で、新しい崖を登り始めたときに、ときどき崖の上に現れる
	_peeker_cooldown -= delta
	var climbing := player.state == Player.State.CLIMB
	if climbing and not _was_climbing and _peeker_cooldown <= 0.0 and not peeker.active \
			and (biome == Biomes.Id.FOREST or biome == Biomes.Id.CRAG):
		var chance := PEEKER_CHANCE_NIGHT if day.is_night else PEEKER_CHANCE_DAY
		if randf() < chance and spawn_peeker():
			_peeker_cooldown = PEEKER_COOLDOWN
		else:
			_peeker_cooldown = 3.0
	_was_climbing = climbing

	# 白い人：雪原にいる間だけ現れる
	if biome == Biomes.Id.SNOW:
		if not pale_one.active and pale_one.cooldown <= 0.0:
			pale_one.appear_near()
	elif pale_one.active:
		pale_one.vanish()

	# 雪潜り：雪山にいる間、雪の下からつけ狙う
	if biome == Biomes.Id.SNOW:
		if not yukimoguri.is_active() and _ready_for("yukimoguri"):
			yukimoguri.start_hunt(player, terrain)
	elif yukimoguri.is_active():
		yukimoguri.stop()

	# 怪鳥：岩場と雪山の空に現れる
	if biome == Biomes.Id.CRAG or biome == Biomes.Id.SNOW:
		if not kaichou.is_active() and _ready_for("kaichou", 60.0):
			kaichou.arrive(player)
	elif kaichou.is_active():
		kaichou.leave()

	# ほかは数秒ごとに、出すかどうかを決める
	_check -= delta
	if _check > 0.0:
		return
	_check = 2.0
	if biome == Biomes.Id.FOREST and _ready_for("kodama", 70.0) and randf() < 0.35:
		spawn_kodama()
	if biome == Biomes.Id.CRAG and climbing and not ishinage.active and _ready_for("ishinage", 30.0) and randf() < 0.4:
		spawn_ishinage()
	var hand_zone := biome == Biomes.Id.SUMMIT or (biome == Biomes.Id.CRAG and day.is_night)
	if hand_zone and climbing and _ready_for("hand", 18.0) and randf() < 0.4:
		spawn_wall_hand()
	if biome == Biomes.Id.SUMMIT and not shadow.active and _ready_for("shadow", 50.0) and randf() < 0.3:
		spawn_shadow()
	if (day.is_night or biome == Biomes.Id.SUMMIT) and _ready_for("onibi", 25.0):
		spawn_onibi(ONIBI_COUNT if day.is_night else 2)


## 出せる時間になっていれば true を返し、次に出せるまでの時間を決める
func _ready_for(key: String, wait := 0.0) -> bool:
	if _cooldowns.get(key, 0.0) > 0.0:
		return false
	_cooldowns[key] = wait
	return true


## いま登っている崖の上の縁を探して、そこにのぞきを出す
func spawn_peeker() -> bool:
	var normal := player.wall_normal()
	var outward := Vector3(normal.x, 0.0, normal.z)
	if outward.length() < 0.3:
		return false
	outward = outward.normalized()
	var space := player.get_world_3d().direct_space_state
	# 壁に沿って上へたどり、壁が終わる高さ（崖の上）を探す
	var ledge := Vector3.INF
	for k in range(3, 45):
		var from := player.global_position + Vector3.UP * k + outward * 2.0
		var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - outward * 4.5, Player.TERRAIN_LAYER))
		if not side.is_empty() and (side.normal as Vector3).y < 0.7:
			continue
		var probe := player.global_position - outward * 1.5
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			probe + Vector3.UP * (k + 3.0), probe + Vector3.UP * (k - 6.0), Player.TERRAIN_LAYER))
		if not down.is_empty():
			ledge = down.position
		break
	if not ledge.is_finite() or ledge.y < player.global_position.y + 3.0:
		return false
	# 足場を外側へたどって、地面が落ち込むところ（崖の縁）を見つける
	var edge := ledge
	for i in 20:
		var next := edge + outward * 0.3
		var h := terrain.height_at(next.x, next.z)
		if h < ledge.y - 1.0:
			break
		edge = Vector3(next.x, h, next.z)
	peeker.appear(edge, outward, player)
	return true


## 木霊：プレイヤーのまわりの少し離れた地面に、何体も現れる
func spawn_kodama() -> int:
	var count := 0
	for kodama in kodamas:
		if kodama.state != "hidden":
			continue
		for attempt in 8:
			var angle := randf() * TAU
			var distance := randf_range(10.0, 18.0)
			var x := player.global_position.x + cos(angle) * distance
			var z := player.global_position.z + sin(angle) * distance
			var y := terrain.height_at(x, z)
			if absf(y - player.global_position.y) > 6.0:
				continue
			kodama.appear(Vector3(x, y, z))
			count += 1
			break
	return count


## 石投げ：登っているプレイヤーより上の岩棚で、プレイヤーが見える場所に現れる
func spawn_ishinage() -> bool:
	var chest := player.global_position + Vector3.UP * 1.2
	var space := player.get_world_3d().direct_space_state
	for ledge in _crag_ledges:
		var height := ledge.y - player.global_position.y
		var flat := Vector2(ledge.x - chest.x, ledge.z - chest.z).length()
		if height < 5.0 or height > 22.0 or flat < 4.0 or flat > 18.0:
			continue
		var query := PhysicsRayQueryParameters3D.create(ledge + Vector3.UP * 1.8, chest, Player.TERRAIN_LAYER)
		if not space.intersect_ray(query).is_empty():
			continue
		ishinage.appear(ledge, player)
		return true
	return false


## 壁の手：登っているプレイヤーの足元の岩肌から生える
func spawn_wall_hand() -> bool:
	if player.state != Player.State.CLIMB:
		return false
	for hand in hands:
		if hand.is_active():
			continue
		var normal := player.wall_normal()
		var up := (Vector3.UP - normal * normal.y).normalized()
		var right := (-normal).cross(up).normalized()
		var from := player.global_position - up * 0.6 + right * randf_range(-0.5, 0.5) + normal * 0.8
		var query := PhysicsRayQueryParameters3D.create(from, from - normal * 2.5, Player.TERRAIN_LAYER)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return false
		hand.emerge(hit.position, normal, player)
		return true
	return false


## 影法師：霊峰の、プレイヤーから見えていない場所に現れる
func spawn_shadow() -> bool:
	for attempt in 16:
		var angle := randf() * TAU
		var distance := randf_range(20.0, 30.0)
		var x := player.global_position.x + cos(angle) * distance
		var z := player.global_position.z + sin(angle) * distance
		shadow.appear(Vector3(x, terrain.height_at(x, z), z), player, terrain)
		if not shadow.is_seen():
			return true
	shadow.vanish()
	return false


## 鬼火：まわりの宙に、いくつか浮かび上がる
func spawn_onibi(count: int) -> int:
	var shown := 0
	for wisp in onibi:
		if shown >= count:
			break
		if wisp.active:
			continue
		var angle := randf() * TAU
		var distance := randf_range(16.0, 26.0)
		var x := player.global_position.x + cos(angle) * distance
		var z := player.global_position.z + sin(angle) * distance
		var y := maxf(terrain.height_at(x, z), player.global_position.y) + randf_range(1.5, 3.5)
		wisp.appear(Vector3(x, y, z), player)
		shown += 1
	return shown
