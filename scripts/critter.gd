class_name Critter
extends Node3D
## 山の動物。草を食んだり、ぶらぶら歩いたり、近づくと顔を上げてこちらを見て、もっと近づくと逃げていく。
## 鳥は地面をつついていて、近づくと飛び立つ。タカは空の高い所を回る。
## 霊峰の白ぎつねは、少し先を歩いて、次のたき火への道を案内する（狩れない。叩くとふっと消える）。
## 襲ってくる獣もいる：
##   イノシシ：近づくと前足で地面をかき、まっすぐ突進してくる
##   ツキノワグマ：寄ってきて、立ち上がって吠え、襲いかかる（熊よけの鈴を鳴らしていると寄ってこない）
##   野犬：夕暮れから群れでうろつき、まわりを回りながら、かわるがわる噛みつきにくる
## ナタで叩くと傷つき、弱ると逃げる。倒した獣は E ではぎとれる（肉・毛皮）。爆竹の音では、どれも逃げていく。
## 野犬は、食べ物で手なずけられる（近くに食べ物を投げると食べに来る。食べ物を持って E でもあげられる）。
## 手なずけた犬は、ついてきて、化け物が近づくと吠えて知らせる。
## 襲ってくる獣は、火のついたたき火やお札の守りの円には入ってこない（山頂は一息つける）。
## 見た目は Blender で作ったモデル（tools/creatures/build_animals.py）。

const SPECIES := {
	"deer": {"model": "animal_deer", "kind": "walker", "walk": 1.2, "run": 7.5, "notice": 18.0, "flee": 11.0, "slope": 1.0, "health": 60.0, "loot": [2, 1]},
	"tanuki": {"model": "animal_tanuki", "kind": "walker", "walk": 0.9, "run": 4.5, "notice": 10.0, "flee": 6.0, "slope": 1.0, "health": 30.0, "loot": [1, 1]},
	"rabbit": {"model": "animal_rabbit", "kind": "hopper", "walk": 0.8, "run": 6.0, "notice": 10.0, "flee": 7.0, "slope": 1.0, "health": 20.0, "loot": [1, 0]},
	"crow": {"model": "animal_crow", "kind": "bird", "walk": 0.6, "run": 8.0, "notice": 12.0, "flee": 8.0, "slope": 1.5, "health": 15.0, "loot": [1, 0]},
	"serow": {"model": "animal_serow", "kind": "walker", "walk": 1.0, "run": 6.0, "notice": 14.0, "flee": 9.0, "slope": 2.6, "health": 70.0, "loot": [2, 1]},
	"hawk": {"model": "animal_hawk", "kind": "soarer", "walk": 6.0, "run": 12.0, "notice": 0.0, "flee": 0.0, "slope": 99.0, "health": 0.0, "loot": [0, 0]},
	"monkey": {"model": "animal_monkey", "kind": "walker", "walk": 1.0, "run": 5.0, "notice": 9.0, "flee": 4.5, "slope": 1.8, "health": 40.0, "loot": [1, 0]},
	"ptarmigan": {"model": "animal_ptarmigan", "kind": "bird", "walk": 0.5, "run": 7.0, "notice": 8.0, "flee": 5.0, "slope": 1.5, "health": 15.0, "loot": [1, 0]},
	"snowhare": {"model": "animal_snowhare", "kind": "hopper", "walk": 0.8, "run": 6.5, "notice": 10.0, "flee": 7.0, "slope": 1.0, "health": 20.0, "loot": [1, 0]},
	"fox": {"model": "animal_fox", "kind": "guide", "walk": 3.0, "run": 5.0, "notice": 14.0, "flee": 0.0, "slope": 99.0, "health": 0.0, "loot": [0, 0]},
	# 襲ってくる獣：[突進の速さ, 当たったときの傷, 突き飛ばす強さ]
	"boar": {"model": "animal_boar", "kind": "walker", "walk": 1.0, "run": 8.0, "notice": 14.0, "flee": 0.0, "slope": 1.2, "health": 90.0, "loot": [3, 1],
		"hostile": "charge", "attack": [9.0, 18.0, 9.0]},
	"bear": {"model": "animal_bear", "kind": "walker", "walk": 1.1, "run": 7.0, "notice": 24.0, "flee": 0.0, "slope": 1.6, "health": 170.0, "loot": [4, 2],
		"hostile": "maul", "attack": [7.5, 30.0, 11.0]},
	"dog": {"model": "animal_dog", "kind": "walker", "walk": 1.8, "run": 8.5, "notice": 26.0, "flee": 0.0, "slope": 1.3, "health": 45.0, "loot": [1, 1],
		"hostile": "pack", "attack": [8.5, 10.0, 4.0]},
}
const ATTACK_REACH := 1.5
const QUAD_LEGS := ["FL", "FR", "BL", "BR"]

var species := ""
var player: Player
var terrain: Terrain
var guide_target := Vector3.INF  # 白ぎつねが案内する先（次のたき火）
var state := "idle"
var gone := false  # 飛び去った・逃げ去った（CritterDirector が片づける）
var health := 0.0
var dead := false
var tamed := false  # 手なずけた犬（ついてくる。もう襲ってこない）

var _data: Dictionary
var _poser: BonePoser
var _model: Node3D
var _timer := 0.0
var _time := randf() * 10.0
var _target := Vector3.ZERO
var _velocity := Vector3.ZERO
var _home := Vector3.ZERO
var _phase := 0.0
var _hop := 0.0
var _charge_dir := Vector3.ZERO
var _hit_player := false
var _circle := randf() * TAU
var _voice: AudioStreamPlayer3D
var _detour := 0.0
var _food: Node3D       # 食べに向かっている、落ちた食べ物
var _food_check := 0.0
var _bark_wait := 0.0
var _prey: Node3D        # 手なずけた犬が、いっしょに襲いかかっている相手
var _prey_check := 0.0
var _bite_wait := 0.0
var _warned := {}        # 吠えて知らせた化け物（同じ相手には、しばらく吠えない）  # 崖や岩を回りこむために、向きをずらしている量 (rad)
var _bounds := AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 0.8, 0.6))  # 体の大きさ（この動物から見た向きで）


func setup(kind: String, pos: Vector3, owner_player: Player, mountain: Terrain) -> void:
	species = kind
	player = owner_player
	terrain = mountain
	_data = SPECIES[kind]
	add_to_group(&"critters")
	add_to_group(&"creatures")  # 爆竹の音で逃げる
	health = float(_data.health)
	if health > 0.0:
		add_to_group(&"huntable")  # ナタで狩れる
	if kind == "dog":
		add_to_group(&"interactables")  # 食べ物を持っていれば、E であげられる
	var skin := CreatureKit.skin(Color.WHITE, Color(1.0, 1.0, 1.0), 0.08, 0.05)
	var scene := load("res://assets/models/%s.glb" % _data.model) as PackedScene
	_model = CreatureKit.load_model(scene, skin, {
		"EyeBlack": CreatureKit.flat(Color(0.02, 0.02, 0.02), 0.2),
		"EyeShine": CreatureKit.glow(Color(1.0, 1.0, 1.0), 1.0),
		"Horn": CreatureKit.flat(Color(0.3, 0.25, 0.2), 0.6),
		"Beak": CreatureKit.flat(Color(0.3, 0.3, 0.3), 0.5),
		"Hoof": CreatureKit.flat(Color(0.07, 0.06, 0.05), 0.6),
		"Claw": CreatureKit.flat(Color(0.8, 0.77, 0.68), 0.5),
		"Tusk": CreatureKit.flat(Color(0.9, 0.87, 0.78), 0.4),
		"EarInner": CreatureKit.flat(Color(0.3, 0.22, 0.2), 0.8),
		"Whisker": CreatureKit.flat(Color(0.85, 0.85, 0.8), 0.5),
		"TailTip": CreatureKit.flat(Color(0.95, 0.3, 0.15), 0.7),
	})
	_voice = AudioStreamPlayer3D.new()
	_voice.stream = Sfx.bark() if kind == "dog" else Sfx.grunt()  # 一度だけ鳴る（くり返さない）
	_voice.unit_size = 5.0
	_voice.max_distance = 45.0
	_voice.volume_db = -4.0
	add_child(_voice)
	add_child(_model)
	_poser = BonePoser.new(_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D)
	_measure_body()
	global_position = pos
	_home = pos
	rotation.y = randf() * TAU
	_timer = randf_range(1.0, 4.0)
	if _data.kind == "soarer":
		state = "soar"
		_home = pos + Vector3.UP * 25.0
		global_position = _home
	if kind == "fox":
		# 霊峰の白ぎつねは、ほんのり光って見える
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.7)
		light.light_energy = 0.6
		light.omni_range = 3.0
		light.position.y = 0.5
		add_child(light)


func scare(_from: Vector3) -> void:
	if dead:
		return
	if _data.has("hostile"):
		state = "retreat"
		_timer = 6.0
		return
	_start_flee()


func is_hostile() -> bool:
	return _data.has("hostile")


## モデルの大きさを覚えておく（ナタや投げた物の当たり判定に使う）
func _measure_body() -> void:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var local := (global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	if not first:
		_bounds = box


## 体の真ん中（ナタや投げた物の当たり判定）
func hit_center() -> Vector3:
	return global_transform * _bounds.get_center()


## 体の大きさ（真ん中からの半径。細長い獣は、胴の太さと長さの間くらい）
func hit_radius() -> float:
	var size := _bounds.size
	return clampf((maxf(size.x, size.z) * 0.5 + minf(size.x, size.z) * 0.5) * 0.5 + size.y * 0.15, 0.25, 1.3)


## ナタで叩かれた
func hit(damage: float, attacker: Node3D) -> void:
	if dead or gone:
		return
	if _data.kind == "guide":
		gone = true  # 霊峰の白ぎつねは、ふっと消える
		if attacker is Player:
			(attacker as Player).message.emit("白ぎつねは、ふっと消えた……")
		return
	if health <= 0.0:
		return
	health -= damage
	_model.scale = Vector3.ONE * 1.12  # びくっとする（_process で元に戻る）
	if attacker and hit_radius() < 0.6:  # 小さな獣だけ、よろける（熊やイノシシは動じない）
		var away := global_position - attacker.global_position
		away.y = 0.0
		if away.length() > 0.01:
			global_position += away.normalized() * clampf(damage / 60.0, 0.1, 0.5)  # 叩かれて、よろける
	_voice.pitch_scale = randf_range(1.2, 1.6)
	_voice.play()
	if health <= 0.0:
		_die()
		return
	if _data.has("hostile") and health > float(_data.health) * 0.35:
		_start_charge()  # 怒って向かってくる
	elif _data.has("hostile"):
		state = "retreat"  # 弱って逃げていく
		_timer = 8.0
	else:
		_start_flee()


func _die() -> void:
	dead = true
	_voice.stop()
	state = "dead"
	remove_from_group(&"creatures")
	remove_from_group(&"huntable")
	add_to_group(&"interactables")
	var tween := create_tween()
	tween.tween_property(_model, "rotation:z", PI * 0.5, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_model, "position:y", 0.15, 0.5)


func interact_hint(by: Player) -> String:
	if dead:
		return "E：はぎとる"
	if species == "dog" and not tamed and _is_food(by.holding_kind()):
		return "E：%sをあげて、手なずける" % Items.NAMES[by.holding_kind()]
	return ""


static func _is_food(kind: int) -> bool:
	return kind in Items.FOODS or kind == Items.Kind.RAW_MEAT


## 手なずけた：もう襲ってこない。ついてきて、化け物が近づくと吠える
func _tame() -> void:
	tamed = true
	_food = null
	state = "follow"
	remove_from_group(&"huntable")
	remove_from_group(&"interactables")
	player.message.emit("野犬が、なついた")
	_voice.pitch_scale = 1.2
	_voice.play()
	_add_collar()


## 仲間になった印の、赤い首輪と金色の鈴（遠くからでも、野犬と見分けられる）
func _add_collar() -> void:
	var skeleton := _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var neck := skeleton.find_bone("neck")
	if neck < 0 or _model.find_child("Collar", true, false) != null:
		return
	var head := skeleton.find_bone("head")
	var length := skeleton.get_bone_rest(head).origin.length() if head >= 0 else 0.1
	# 首の太さを、体の形から測る（首の骨に直角な面の上にある頂点の、骨からの遠さ）
	var rest := skeleton.get_bone_global_rest(neck)
	var axis := rest.basis.y.normalized()
	var along_neck := length * 0.55
	var center := rest.origin + axis * along_neck
	var thickness := 0.04
	for mesh_node: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", true, false):
		var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var offset := vertex - center
			var along := offset.dot(axis)
			var across := (offset - axis * along).length()
			if absf(along) < 0.015 and across < 0.2:
				thickness = maxf(thickness, across)
	var attach := BoneAttachment3D.new()
	attach.name = "Collar"
	attach.bone_idx = neck
	skeleton.add_child(attach)
	var ring := TorusMesh.new()
	ring.inner_radius = thickness
	ring.outer_radius = thickness + 0.024
	ring.rings = 18
	ring.ring_segments = 6
	var band := MeshInstance3D.new()
	band.mesh = ring
	band.material_override = CreatureKit.flat(Color(0.78, 0.08, 0.06), 0.5)
	band.position = Vector3(0.0, along_neck, 0.0)
	band.scale = Vector3(1.0, 1.6, 1.0)  # 輪の幅を、首に沿って少し広く
	attach.add_child(band)
	# 鈴はのどの下に下げる（首の骨から見た「下」を、骨の向きに直角な面へ落とす）
	var down := rest.basis.inverse() * Vector3.DOWN
	down = (down - Vector3.UP * down.dot(Vector3.UP)).normalized()
	var bell := MeshInstance3D.new()
	bell.mesh = CreatureKit.sphere(0.024)
	bell.material_override = CreatureKit.flat(Color(0.95, 0.75, 0.25), 0.3)
	bell.position = band.position + down * (thickness + 0.03)
	attach.add_child(bell)


## 倒した獣から、肉と毛皮をとる（持ちきれない分は、足もとに落ちる）。生きている野犬なら、食べ物をあげて手なずける
func interact(by: Player) -> void:
	if not dead and species == "dog" and not tamed and _is_food(by.holding_kind()):
		by.inventory.remove(by.holding_kind())
		by.items_changed.emit()
		_tame()
		return
	if not dead or gone:
		return
	var loot: Array = _data.loot
	var taken: Array[String] = []
	for entry: Array in [[Items.Kind.RAW_MEAT, loot[0]], [Items.Kind.PELT, loot[1]]]:
		for n in int(entry[1]):
			if not by.pick_up(entry[0]):
				by.item_thrown.emit(entry[0], global_position + Vector3.UP * 0.6, Vector3(randf_range(-1.0, 1.0), 2.0, randf_range(-1.0, 1.0)), false)
		if int(entry[1]) > 0:
			taken.append("%s×%d" % [Items.NAMES[entry[0]], entry[1]])
	by.message.emit("はぎとった：" + "、".join(taken))
	remove_from_group(&"interactables")
	gone = true


func _physics_process(delta: float) -> void:
	if player == null or gone or dead:
		return
	_time += delta
	_timer -= delta
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	if tamed:
		_process_tamed(to_player, distance, delta)
		return
	if species == "dog" and _seek_food(delta):
		return
	# 守りの円（たき火・お札）の中にいる相手には、襲いかからない
	if _data.has("hostile") and state in ["approach", "rear", "circle", "charge", "paw"] and Ward.blocks(get_tree(), player.global_position):
		state = "retreat"
		_timer = 4.0
	if _data.has("hostile") and _process_hostile(to_player, distance, delta):
		return
	match state:
		"idle", "graze":
			if _noticed(distance):
				state = "alert"
				_timer = randf_range(1.5, 3.0)
			elif _timer <= 0.0:
				_pick_wander()
		"walk":
			if _noticed(distance):
				state = "alert"
				_timer = randf_range(1.5, 3.0)
			else:
				_walk_toward(_target, float(_data.walk), delta)
				if Vector2(global_position.x - _target.x, global_position.z - _target.z).length() < 0.4 or _timer <= 0.0:
					state = "graze" if randf() < 0.6 else "idle"
					_timer = randf_range(2.0, 6.0)
		"alert":
			_face(to_player)
			if distance < float(_data.flee):
				_start_flee()
			elif _timer <= 0.0:
				state = "idle"
				_timer = randf_range(1.0, 3.0)
		"flee":
			if _data.kind == "bird":
				_velocity = _velocity.lerp(Vector3.UP * 5.0 - to_player.normalized() * float(_data.run), 1.0 - exp(-3.0 * delta))
				global_position += _velocity * delta
				_face(_velocity)
			else:
				_walk_toward(global_position - to_player.normalized() * 5.0, float(_data.run), delta)
			if _timer <= 0.0:
				if distance > float(_data.notice) * 1.6 or _data.kind == "bird":
					gone = true  # 十分に離れたら、逃げ去った（目の前では消えない）
				else:
					_timer = 2.0  # まだ近い：逃げ続ける
		"soar":
			# 空の高い所を、ゆっくり大きく回る
			var angle := _time * 0.18
			var center := _home
			var next := center + Vector3(cos(angle), 0.0, sin(angle)) * 30.0 + Vector3.UP * sin(_time * 0.3) * 3.0
			_face(next - global_position)
			global_position = global_position.lerp(next, 1.0 - exp(-0.5 * delta))
		"guide":
			_process_guide(to_player, distance, delta)


## 襲ってくる獣の動き。ふつうの動き（うろつく・草を食む）に任せるときは false を返す
func _process_hostile(to_player: Vector3, distance: float, delta: float) -> bool:
	var attack: Array = _data.attack
	match state:
		"idle", "graze", "walk", "alert":
			if distance < float(_data.notice) and not player.frozen and not (player.bell_ringing and _data.hostile == "maul"):
				match str(_data.hostile):
					"charge":
						state = "paw"  # 前足で地面をかいて、突進の構え
						_timer = 1.4
					"maul":
						state = "approach"
						_timer = 12.0
					"pack":
						state = "circle"
						_timer = randf_range(3.0, 6.0)
				_voice.pitch_scale = randf_range(0.7, 0.9)
				_voice.play()
				return true
			return false
		"paw":
			_face(to_player)
			if _timer <= 0.0:
				_start_charge()
		"approach":
			# ゆっくり寄ってきて、近くで立ち上がって吠える
			_walk_toward(player.global_position, float(_data.walk) * 1.6, delta)
			if distance < 7.0 or _timer <= 0.0:
				state = "rear"
				_timer = 1.2
				_voice.pitch_scale = 0.6
				_voice.play()
			if player.bell_ringing:
				state = "retreat"
				_timer = 6.0
		"rear":
			_face(to_player)
			if _timer <= 0.0:
				_start_charge()
		"circle":
			# 群れで、プレイヤーのまわりを回りながら、すきをうかがう
			_circle += delta * 0.6
			var around := player.global_position + Vector3(cos(_circle), 0.0, sin(_circle)) * 7.0
			_walk_toward(around, float(_data.run) * 0.5, delta)
			if _timer <= 0.0:
				_start_charge()
			if distance > float(_data.notice) * 1.5:
				state = "idle"
		"charge":
			_walk_toward(global_position + _charge_dir * 3.0, float(attack[0]), delta)
			if not _hit_player and distance < ATTACK_REACH and absf(player.global_position.y - global_position.y) < 2.0:
				_hit_player = true
				player.knock(_charge_dir * float(attack[2]) + Vector3.UP * 3.0, float(attack[1]))
			if _timer <= 0.0 or (_hit_player and distance > 3.0):
				state = "retreat" if _data.hostile != "pack" else "circle"
				_timer = randf_range(3.0, 5.0)
		"retreat":
			_walk_toward(global_position - to_player.normalized() * 5.0, float(_data.run) * 0.7, delta)
			if _timer <= 0.0:
				state = "idle"
				_timer = randf_range(6.0, 10.0)  # しばらくは落ち着いている
				if distance > float(_data.notice) * 1.8:
					gone = true
		_:
			return false
	return true


## 野犬：近くに落ちている食べ物を見つけたら、食べに行き、食べたらなつく
func _seek_food(delta: float) -> bool:
	_food_check -= delta
	if _food == null or not is_instance_valid(_food):
		_food = null
		if _food_check > 0.0:
			return false
		_food_check = 0.5
		for pickup: Node3D in get_tree().get_nodes_in_group(Pickup.GROUP):
			if _is_food(int(pickup.get("kind"))) and pickup.global_position.distance_to(global_position) < 12.0:
				_food = pickup
				break
		if _food == null:
			return false
	_walk_toward(_food.global_position, float(_data.run) * 0.6, delta)
	if Vector2(_food.global_position.x - global_position.x, _food.global_position.z - global_position.z).length() < 0.9:
		_food.queue_free()
		_tame()
	return true


## 手なずけた犬：プレイヤーのうしろについて歩く。離れすぎたら追いつき、化け物が新しく近づくと、ひと声吠えて知らせる。
## プレイヤーが叩いた相手や、襲ってくる獣・化け物には、いっしょに噛みつく
func _process_tamed(to_player: Vector3, distance: float, delta: float) -> void:
	_bite_wait -= delta
	_prey_check -= delta
	if _prey_check <= 0.0:
		_prey_check = 0.4
		_prey = _pick_prey()
	if _prey and distance < 30.0:
		var to_prey := Combat.body_center(_prey) - global_position
		to_prey.y = 0.0
		if to_prey.length() > Combat.body_radius(_prey) + 0.9:
			state = "follow"
			_walk_toward(_prey.global_position, float(_data.run), delta)
		else:
			state = "idle"
			_face(to_prey)
			if _bite_wait <= 0.0:
				_bite_wait = 0.9
				Combat.strike(_prey, 14.0, self, Combat.body_center(_prey))
				_voice.pitch_scale = randf_range(1.0, 1.2)
				_voice.play()
		return
	if distance > 40.0 and player.is_on_floor():
		# 崖を登って置いていかれたら、そのうち追いついてくる（見ていないうちに）
		var behind := player.global_position - player.global_transform.basis.z * -3.0
		behind.y = terrain.height_at(behind.x, behind.z)
		global_position = behind
		return
	if distance > 3.5:
		state = "follow"
		_walk_toward(player.global_position, float(_data.run) * (0.9 if distance > 10.0 else 0.4), delta)
	else:
		state = "idle"
		_face(to_player)
	_bark_wait -= delta
	if _bark_wait <= 0.0:
		_bark_wait = 1.0
		for creature: Node3D in get_tree().get_nodes_in_group(&"creatures"):
			if not _is_monster_out(creature) or creature.global_position.distance_to(global_position) > 20.0:
				continue
			var id := creature.get_instance_id()
			if _time - float(_warned.get(id, -100.0)) > 30.0:  # 新しく近づいた化け物にだけ、ひと声
				_warned[id] = _time
				_voice.pitch_scale = randf_range(1.1, 1.3)
				_voice.play()
				_bark_wait = 4.0
				break


## 出ている化け物か（獣・練習台・昼に隠れている岩グモや手長・消えている霊はちがう）
static func _is_monster_out(creature: Node3D) -> bool:
	if creature is Critter or creature is Hitokuma or creature.is_in_group(&"practice") or not creature.is_visible_in_tree():
		return false
	if creature.get("active") == false or creature.get("dead") == true:
		return false
	if creature.has_method("set_awake"):
		var model: Node3D = creature.get("_model")
		return model != null and model.visible
	return true


## いっしょに噛みつく相手：プレイヤーが叩いた相手、襲ってくる獣や人熊、すぐ近くの化け物
func _pick_prey() -> Node3D:
	var struck: Node3D = player.last_struck
	if struck and is_instance_valid(struck) and struck != self and struck.is_in_group(&"creatures") and struck.get("dead") != true \
			and not struck.is_in_group(&"practice") and struck.global_position.distance_to(player.global_position) < 20.0:
		return struck
	var best: Node3D = null
	var nearest := INF
	for creature: Node3D in get_tree().get_nodes_in_group(&"creatures"):
		if creature == self or not is_instance_valid(creature):
			continue
		var d := creature.global_position.distance_to(player.global_position)
		var threat := false
		if creature is Critter:
			var other := creature as Critter
			threat = other.is_hostile() and not other.tamed and not other.dead and other.state in ["approach", "rear", "circle", "charge", "paw"]
		elif creature is Hitokuma:
			threat = not (creature as Hitokuma).dead and (creature as Hitokuma).state in ["roar", "stalk", "swipe"]
		else:
			threat = _is_monster_out(creature) and d < 10.0
		if threat and d < 18.0 and d < nearest:
			nearest = d
			best = creature
	return best


func _start_charge() -> void:
	state = "charge"
	_timer = 2.8
	_hit_player = false
	var toward := player.global_position - global_position
	toward.y = 0.0
	_charge_dir = toward.normalized() if toward.length() > 0.1 else -global_transform.basis.z
	_voice.pitch_scale = randf_range(0.8, 1.0)
	_voice.play()


## 近づいてきたプレイヤーに気づいたか（夜は気づきにくい）
func _noticed(distance: float) -> bool:
	if _data.kind == "guide":
		if distance < float(_data.notice):
			state = "guide"
		return false
	return distance < float(_data.notice) and not player.frozen


func _start_flee() -> void:
	if state == "flee" or _data.kind in ["soarer", "guide"]:
		return
	state = "flee"
	_timer = 4.0 if _data.kind == "bird" else 5.0
	_velocity = Vector3.UP * 2.0


## 白ぎつね：プレイヤーの少し先へ走っていき、振り返って待つ。たき火に着いたら消える
func _process_guide(to_player: Vector3, distance: float, delta: float) -> void:
	if not guide_target.is_finite():
		_face(to_player)
		return
	var to_goal := guide_target - global_position
	to_goal.y = 0.0
	if to_goal.length() < 6.0:
		gone = true  # 案内を終えて、ふっと消える
		return
	if distance < 9.0:
		var step := global_position + to_goal.normalized() * 6.0
		_walk_toward(step, float(_data.walk), delta)
	else:
		_face(to_player)  # 振り返って待つ


func _pick_wander() -> void:
	for attempt in 6:
		var angle := randf() * TAU
		var next := _home + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(2.0, 8.0)
		next.y = terrain.height_at(next.x, next.z)
		if absf(next.y - global_position.y) / maxf(next.distance_to(global_position), 0.1) < float(_data.slope):
			_target = next
			state = "walk"
			_timer = 8.0
			return
	state = "graze"
	_timer = randf_range(2.0, 4.0)


## 地面の上を歩く。急すぎる所や大岩にはばまれたら、少しずつ向きを変えて回りこむ（崖や岩に入りこまない）
func _walk_toward(goal: Vector3, speed: float, delta: float) -> void:
	var flat := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	if flat.length() < 0.05:
		return
	var length := minf(speed * delta, flat.length())
	for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
		var step := flat.normalized().rotated(Vector3.UP, turn + _detour) * length
		var next := global_position + step
		next.y = terrain.height_at(next.x, next.z)
		if absf(next.y - global_position.y) > float(_data.slope) * step.length() + 0.05:
			continue  # 崖
		if terrain.near_rock(next + Vector3.UP * 0.4, 0.25):
			continue  # 大岩
		if _data.has("hostile") and not tamed and _food == null and state in ["approach", "circle", "charge", "paw", "rear"] 				and Ward.blocks(get_tree(), next) and not Ward.blocks(get_tree(), global_position):
			continue  # 襲いかかるときは、守りの円の中へは入らない
		if turn != 0.0:
			_detour = clampf(_detour + turn * 0.5, -2.0, 2.0)  # しばらくは、回りこむ向きを覚えておく
		else:
			_detour = move_toward(_detour, 0.0, delta)
		global_position = next
		_face(step)
		_phase += delta * speed * 4.0
		return
	_detour = -_detour if absf(_detour) > 0.1 else 1.5  # どこへも進めない：逆へ回りこんでみる
	if state == "walk":
		_timer = minf(_timer, 0.2)  # ぶらぶら歩きなら、別の行き先を選ぶ


func _face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.01:
		return
	var target := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, target, 0.2)


## 体の動き：歩く・跳ねる・草を食む・首を上げる・羽ばたく
func _process(delta: float) -> void:
	if _poser == null:
		return
	if dead:
		return
	_model.scale = _model.scale.lerp(Vector3.ONE, 1.0 - exp(-10.0 * delta))
	var kind: String = _data.kind
	var moving := state in ["walk", "flee", "guide", "approach", "circle", "charge", "retreat", "follow"] and (kind != "guide" or player.global_position.distance_to(global_position) < 9.0)
	if kind in ["bird", "soarer"]:
		var flying := state == "flee" or state == "soar"
		var flap := sin(_time * (14.0 if state == "flee" else 3.0)) * (0.7 if flying else 0.0)
		var fold := 0.0 if flying else 1.2  # 地面では翼をたたむ
		_poser.set_target("wing.L", Vector3(0.0, fold, flap))
		_poser.set_target("wing.R", Vector3(0.0, -fold, -flap))
		var peck := maxf(sin(_time * 5.0), 0.0) * 0.8 if state == "idle" or state == "graze" else 0.0
		_poser.set_target("head", Vector3(-peck, 0.0, 0.0))
		_poser.update(delta, 14.0)
		return
	var gait := sin(_phase)
	for i in QUAD_LEGS.size():
		var leg: String = QUAD_LEGS[i]
		var swing := 0.0
		if moving:
			if kind == "hopper":
				swing = sin(_phase * 0.8) * 0.7 * (1.0 if leg.begins_with("B") else -0.6)
			else:
				swing = gait * 0.6 * (1.0 if i == 0 or i == 3 else -1.0)
		_poser.set_target("leg%sa" % leg, Vector3(swing, 0.0, 0.0))
		_poser.set_target("leg%sb" % leg, Vector3(-maxf(swing, 0.0) * 0.8, 0.0, 0.0))
	# 跳ねる動物は、体ごと上下する
	_hop = absf(sin(_phase * 0.8)) * 0.12 if kind == "hopper" and moving else 0.0
	_model.position.y = lerpf(_model.position.y, _hop, 1.0 - exp(-12.0 * delta))
	var neck := 0.0
	if state == "graze":
		neck = -0.9 + sin(_time * 3.0) * 0.08  # 首を下げて、草を食む
	elif state == "alert":
		neck = 0.25  # 首を上げて、こちらを見る
	elif state == "paw":
		neck = -0.3 + sin(_time * 12.0) * 0.1  # 頭を下げて、前足で地面をかく
	elif state == "charge":
		neck = -0.25  # 頭を低くして突っこむ
	# クマは、立ち上がって吠える
	var rear := 0.9 if state == "rear" else 0.0
	_model.rotation.x = lerpf(_model.rotation.x, rear, 1.0 - exp(-6.0 * delta))
	_poser.set_target("neck", Vector3(neck, 0.0, 0.0))
	_poser.set_target("tail", Vector3(0.2, sin(_time * (6.0 if moving else 1.5)) * 0.4, 0.0))
	_poser.update(delta, 10.0)
	if state == "alert" or state == "guide":
		_poser.aim("head", player.get_camera().global_position)
