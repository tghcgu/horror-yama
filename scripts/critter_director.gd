class_name CritterDirector
extends Node3D
## 山の動物を、プレイヤーのまわりに出したり片づけたりする。地帯ごとに、住んでいる動物が違う。
##   樹海：シカ・タヌキ・ウサギ・カラス、イノシシ・人熊（めったに出ない）・野犬（夜はホタルも飛ぶ）
##   岩場：カモシカ・タカ、人熊（めったに出ない）・野犬
##   雪山：ニホンザル・ライチョウ・ユキウサギ、野犬
## 野犬の群れは、夕暮れから夜にだけうろつく。
##   霊峰：白ぎつね（道案内）・カラス
## 遠くへ離れた動物や、逃げ去った動物は片づけて、いつも近くに十数匹ほどいるようにする。

const MAX_CRITTERS := 16
const SPAWN_DISTANCE := Vector2(24.0, 42.0)
const DESPAWN_DISTANCE := 75.0
const LIFE := {  # 地帯 → [動物, 群れの数の範囲, 出やすさ]
	Biomes.Id.FOREST: [["deer", Vector2i(2, 4), 3.0], ["tanuki", Vector2i(1, 2), 2.0], ["rabbit", Vector2i(1, 3), 2.5], ["crow", Vector2i(3, 5), 2.0],
		["boar", Vector2i(1, 2), 1.2], ["bear", Vector2i(1, 1), 0.2], ["dog", Vector2i(2, 3), 0.9]],
	Biomes.Id.CRAG: [["serow", Vector2i(1, 3), 3.0], ["hawk", Vector2i(1, 1), 1.0], ["bear", Vector2i(1, 1), 0.25], ["dog", Vector2i(2, 3), 0.8]],
	Biomes.Id.SNOW: [["monkey", Vector2i(3, 5), 3.0], ["ptarmigan", Vector2i(2, 4), 2.0], ["snowhare", Vector2i(1, 2), 2.0], ["dog", Vector2i(2, 4), 0.9]],
	Biomes.Id.SUMMIT: [["fox", Vector2i(1, 1), 1.5], ["crow", Vector2i(3, 6), 2.5]],
}

const SPECIES_HOSTILE := ["boar", "bear", "dog"]

var player: Player
var terrain: Terrain
var day: DayCycle
var guide_target := Vector3.INF  # 白ぎつねが案内する先（Main が決める）
var enabled := false

var _critters: Array[Critter] = []
var bear: Hitokuma  # 人熊（一度に一頭だけ）
var _check := 1.0
var _fireflies: CPUParticles3D


func setup(owner_player: Player, mountain: Terrain, day_cycle: DayCycle) -> void:
	player = owner_player
	terrain = mountain
	day = day_cycle
	_fireflies = CPUParticles3D.new()
	_fireflies.amount = 40
	_fireflies.lifetime = 6.0
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fireflies.emission_box_extents = Vector3(14.0, 2.0, 14.0)
	_fireflies.gravity = Vector3.ZERO
	_fireflies.initial_velocity_min = 0.1
	_fireflies.initial_velocity_max = 0.4
	_fireflies.spread = 180.0
	_fireflies.color_ramp = CreatureKit.fade_ramp()
	var dot := QuadMesh.new()
	dot.size = Vector2(0.12, 0.12)
	dot.material = CreatureKit.puff_material(Color(0.75, 1.0, 0.45, 1.0))
	_fireflies.mesh = dot
	_fireflies.emitting = false
	add_child(_fireflies)


func clear() -> void:
	for critter in _critters:
		if is_instance_valid(critter):
			critter.queue_free()
	_critters.clear()
	if bear and is_instance_valid(bear):
		bear.queue_free()
	bear = null


func critters() -> Array[Critter]:
	return _critters


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var biome := Biomes.at(player.global_position)
	# 夜の樹海には、ホタルが飛ぶ
	_fireflies.emitting = enabled and day.is_night and biome == Biomes.Id.FOREST
	_fireflies.global_position = player.global_position + Vector3.UP * 1.5
	# 片づける：遠くへ離れた・逃げ去った・飛び去った
	for critter in _critters.duplicate():
		if not is_instance_valid(critter):
			_critters.erase(critter)
			continue
		critter.guide_target = guide_target
		if critter.gone or (critter.global_position.distance_to(player.global_position) > DESPAWN_DISTANCE and not critter.tamed):
			_critters.erase(critter)
			critter.queue_free()
	if bear and is_instance_valid(bear) and (bear.gone or (not bear.dead and bear.state in ["wander", "graze"]
			and bear.global_position.distance_to(player.global_position) > DESPAWN_DISTANCE * 1.4)):
		bear.queue_free()
		bear = null
	if not enabled:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 2.5
	if _critters.size() < MAX_CRITTERS and LIFE.has(biome):
		spawn_group(biome)


## 人熊を、少し遠くの歩ける地面に出す（一度に一頭だけ。守りの円の中にいるときは出さない）
func _spawn_bear(biome: int) -> int:
	if bear and is_instance_valid(bear) or Ward.blocks(get_tree(), player.global_position):
		return 0
	for attempt in 10:
		var angle := randf() * TAU
		var distance := randf_range(40.0, 60.0)
		var x := player.global_position.x + cos(angle) * distance
		var z := player.global_position.z + sin(angle) * distance
		var y := terrain.height_at(x, z)
		if absf(y - player.global_position.y) > 18.0 or terrain.normal_at(x, z).y < 0.8 or Biomes.at(Vector3(x, y, z)) != biome:
			continue
		if terrain.near_rock(Vector3(x, y + 1.0, z), 1.0):
			continue
		bear = Hitokuma.new()
		add_child(bear)
		bear.setup(Vector3(x, y, z), player, terrain)
		return 1
	return 0


## その地帯の動物を、ひと群れ出す。出せた数を返す
func spawn_group(biome: int) -> int:
	var choices: Array = LIFE[biome]
	var total := 0.0
	for choice: Array in choices:
		total += float(choice[2])
	var roll := randf() * total
	var chosen: Array = choices[0]
	for choice: Array in choices:
		roll -= float(choice[2])
		if roll <= 0.0:
			chosen = choice
			break
	var kind: String = chosen[0]
	var range_count: Vector2i = chosen[1]
	if kind == "bear":
		return _spawn_bear(biome)
	if kind == "fox" and _critters.any(func(c: Critter) -> bool: return c.species == "fox"):
		return 0  # 白ぎつねは一匹だけ
	if kind == "dog" and day and day.darkness < 0.3:
		return 0  # 野犬は、夕暮れから
	if SPECIES_HOSTILE.has(kind) and _critters.filter(func(c: Critter) -> bool: return is_instance_valid(c) and c.is_hostile()).size() >= 4:
		return 0  # 襲ってくる獣は、まわりに 4 匹まで
	if SPECIES_HOSTILE.has(kind) and Ward.blocks(get_tree(), player.global_position):
		return 0  # たき火やお札に守られているあいだは、襲ってくる獣は出ない
	# 群れの中心：プレイヤーから少し離れた、歩ける地面
	for attempt in 10:
		var angle := randf() * TAU
		var distance := randf_range(SPAWN_DISTANCE.x, SPAWN_DISTANCE.y) if kind != "fox" else 12.0
		var x := player.global_position.x + cos(angle) * distance
		var z := player.global_position.z + sin(angle) * distance
		var y := terrain.height_at(x, z)
		if absf(y - player.global_position.y) > 18.0 or terrain.normal_at(x, z).y < 0.75 or Biomes.at(Vector3(x, y, z)) != biome:
			continue
		var count := randi_range(range_count.x, range_count.y)
		for n in count:
			var p := Vector3(x + randf_range(-3.0, 3.0), 0.0, z + randf_range(-3.0, 3.0))
			p.y = terrain.height_at(p.x, p.z)
			var critter := Critter.new()
			add_child(critter)
			critter.setup(kind, p, player, terrain)
			critter.guide_target = guide_target
			_critters.append(critter)
		return count
	return 0
