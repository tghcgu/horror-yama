class_name Wanderer
extends Node3D
## 「彷徨う亡者」：山で遭難した登山者の亡霊。青白く透けた体で、平地も山肌もおかまいなしに、ふらふらとさまよう。
## 気づかれると、うめきながら、ゆっくりこちらへ寄ってくる。つかまれると、体の芯まで冷えて力が抜ける。
## ナタや拳はあまり効かず、よろめくだけ（何度も叩けば、崩れて消える）。塩やお札で消せる。お札や発煙筒の円には入れない。

const MODEL := preload("res://assets/models/climber.glb")
const ROAM_SPEED := 0.8
const FOLLOW_SPEED := 1.35
const NOTICE := 22.0
const GIVE_UP := 45.0
const GRAB_DISTANCE := 1.3
const LIFETIME := 150.0

var player: Player
var terrain: Terrain
var active := false
var state := "roam"

var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _timer := 0.0
var _life := 0.0
var _time := randf() * 10.0
var _poser: BonePoser
var _voice: AudioStreamPlayer3D
var _model: Node3D
var _hurt := 0.0      # 受けた傷（物理の攻撃は 4 分の 1 しか入らない。たまると崩れる）
var _stagger := 0.0   # よろめいて、止まっている時間


func _ready() -> void:
	add_to_group(&"spirits")
	add_to_group(&"creatures")
	_model = MODEL.instantiate() as Node3D
	# ぼろぼろの登山者の格好で、顔は描かない
	Appearance.apply_styles(_model, {"hat": "none", "hair": "long", "top": "down", "neck": "scarf", "face": "none"})
	var ghost := StandardMaterial3D.new()
	ghost.albedo_color = Color(0.72, 0.78, 0.84, 0.72)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.emission_enabled = true
	ghost.emission = Color(0.12, 0.16, 0.2)
	ghost.roughness = 1.0
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(i, ghost)
	add_child(_model)
	var skeleton := _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_poser = BonePoser.new(skeleton)
	# うつろな黒い目
	var head := BoneAttachment3D.new()
	head.bone_name = "head"
	skeleton.add_child(head)
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone("head")).affine_inverse()
	for side in [-1.0, 1.0]:
		CreatureKit.part(head, CreatureKit.sphere(0.04), CreatureKit.flat(Color(0.0, 0.0, 0.0), 1.0), rest * Vector3(0.09 * side, 1.37, -0.22))
	_voice = AudioStreamPlayer3D.new()
	_voice.stream = Sfx.wail()
	_voice.pitch_scale = 0.6
	_voice.unit_size = 6.0
	_voice.max_distance = 50.0
	_voice.volume_db = -6.0
	add_child(_voice)
	visible = false


func appear(pos: Vector3, owner_player: Player, mountain: Terrain) -> void:
	player = owner_player
	terrain = mountain
	global_position = pos
	_home = pos
	active = true
	visible = true
	_hurt = 0.0
	state = "roam"
	_life = LIFETIME
	_pick_roam()


func vanish() -> void:
	active = false
	visible = false
	_voice.stop()


## 塩で清められた
func purify() -> void:
	vanish()


## ナタで叩かれた：よろめく。傷がたまると、ふっと崩れて消える
func hit(damage: float, attacker: Node3D) -> void:
	if not active:
		return
	_hurt += damage
	_stagger = 0.8
	if _hurt < 60.0:
		return
	if attacker is Player:
		(attacker as Player).message.emit("亡者は、霧のように崩れて消えた")
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3(1.4, 0.05, 1.4), 0.35)
	tween.tween_callback(func() -> void:
		vanish()
		_model.scale = Vector3.ONE)


## 爆竹の音や、ほかの霊を払うものに驚いて、離れていく
func scare(_from: Vector3) -> void:
	if active:
		state = "roam"
		_pick_roam()


func _pick_roam() -> void:
	var angle := randf() * TAU
	_target = _home + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(8.0, 30.0)
	_target.y = terrain.height_at(_target.x, _target.z)
	_timer = randf_range(12.0, 25.0)


func _physics_process(delta: float) -> void:
	if not active or player == null:
		return
	_life -= delta
	_timer -= delta
	if _life <= 0.0 or player.frozen:
		vanish()
		return
	if _stagger > 0.0:
		_stagger -= delta
		return
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	match state:
		"roam":
			_move_toward(_target, ROAM_SPEED, delta)
			if global_position.distance_to(_target) < 1.0 or _timer <= 0.0:
				_pick_roam()
			if distance < NOTICE:
				state = "follow"
				_voice.play()
		"follow":
			_move_toward(player.global_position, FOLLOW_SPEED * (1.4 if player.night else 1.0), delta)
			if distance < GRAB_DISTANCE:
				player.chill(40.0)
				player.stamina = minf(player.stamina, player.max_stamina() * 0.2)
				player.message.emit("冷たい手に、つかまれた……")
				vanish()
			elif distance > GIVE_UP:
				state = "roam"
				_home = global_position
				_pick_roam()


## 地面や山肌をなぞって、ふらふら進む（崖も、そのまま這い上がる）
func _move_toward(goal: Vector3, speed: float, delta: float) -> void:
	var flat := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	if flat.length() < 0.05:
		return
	var steep := absf(goal.y - global_position.y) / maxf(flat.length(), 0.5)
	var step := flat.normalized() * minf(speed * delta / (1.0 + steep * 0.6), flat.length())
	var next := global_position + step
	next.y = terrain.height_at(next.x, next.z)
	if Ward.blocks(get_tree(), next):
		return
	global_position = next
	look_at(global_position + flat, Vector3.UP)


## よろよろと歩く。寄ってくるときは、両腕を前へ伸ばす
func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	var swing := sin(_time * 3.2) * 0.35
	var reach := 1.3 if state == "follow" else 0.1
	for i in 2:
		var side := "L" if i == 0 else "R"
		var s := 1.0 if i == 0 else -1.0
		_poser.set_target("upperarm." + side, Vector3(-reach + swing * s * 0.3, 0.0, 0.1 * s))
		_poser.set_target("forearm." + side, Vector3(-0.2, 0.0, 0.0))
		_poser.set_target("thigh." + side, Vector3(swing * s, 0.0, 0.0))
		_poser.set_target("shin." + side, Vector3(maxf(-swing * s, 0.0) * 0.8, 0.0, 0.0))
	_poser.set_target("spine", Vector3(0.25, 0.0, sin(_time * 1.3) * 0.12))  # 前かがみに、体をかしげる
	_poser.update(delta, 6.0)
	_model.position.y = absf(sin(_time * 3.2)) * 0.03
