class_name EnemyDirector
extends Node
## 地帯ごとの化け物（のぞき・白い人）を、状況に応じて出したり消したりする。
## 夜の“何か”と、壁の岩グモはここでは扱わない。

const PEEKER_CHANCE_DAY := 0.3
const PEEKER_CHANCE_NIGHT := 0.55
const PEEKER_COOLDOWN := 15.0

var player: Player
var terrain: Terrain
var day: DayCycle
var peeker: Peeker
var pale_one: PaleOne

var _peeker_cooldown := 8.0
var _was_climbing := false


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


func reset() -> void:
	peeker.hide_now()
	pale_one.vanish()
	pale_one.cooldown = 0.0
	_peeker_cooldown = 8.0


func _physics_process(delta: float) -> void:
	if player == null or player.frozen:
		return
	var biome := Biomes.at(player.global_position.y)

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


## いま登っている崖の上の縁を探して、そこにのぞきを出す
func spawn_peeker() -> bool:
	var normal := player.wall_normal()
	var outward := Vector3(normal.x, 0.0, normal.z)
	if outward.length() < 0.3:
		return false
	outward = outward.normalized()
	var probe := player.global_position - outward * 3.0
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(probe.x, player.global_position.y + 30.0, probe.z),
		Vector3(probe.x, player.global_position.y + 2.0, probe.z), Player.TERRAIN_LAYER)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var ledge: Vector3 = hit.position
	if ledge.y < player.global_position.y + 3.0 or ledge.y > player.global_position.y + 26.0:
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
