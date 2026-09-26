class_name BearTrap
extends Node3D
## 落ち葉に半分うもれたトラバサミ。踏むとガシャンと閉じて足を挟まれ、しばらく動けない。

const TRIGGER_RADIUS := 0.55
const HOLD_TIME := 3.0
const INJURY := 20.0

var player: Player
var armed := true

var _jaws: Array[MeshInstance3D] = []
var _sound: AudioStreamPlayer3D


func setup(pos: Vector3, owner_player: Player) -> void:
	player = owner_player
	global_position = pos
	rotation.y = randf() * TAU
	var meshes: Array = Shared.get_or_make("bear_trap", _build_meshes)
	var material := Psx.vertex_material("", 1.0, 0.7)
	var base := MeshInstance3D.new()
	base.mesh = meshes[0]
	base.material_override = material
	add_child(base)
	for side in [-1.0, 1.0]:
		var jaw := MeshInstance3D.new()
		jaw.mesh = meshes[1]
		jaw.material_override = material
		jaw.position = Vector3(0.0, 0.03, 0.0)
		jaw.scale.z = side
		add_child(jaw)
		_jaws.append(jaw)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.clang()
	_sound.unit_size = 6.0
	add_child(_sound)


## 台座と落ち葉、片側のあご（ぎざぎざの歯つき）。形はすべての罠で使い回す（罠ごとに作ると、GPU のバッファが増えすぎる）
static func _build_meshes() -> Array:
	var steel := Color(0.32, 0.3, 0.28)
	var base := MeshBuilder.new()
	var plate := CylinderMesh.new()
	plate.top_radius = 0.12
	plate.bottom_radius = 0.12
	plate.height = 0.02
	base.add(plate, Vector3(0.0, 0.03, 0.0), Vector3.ZERO, Vector3.ONE, Color(0.4, 0.22, 0.12))
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.12, 0.005, 0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 10:
		base.add(leaf, Vector3(rng.randf_range(-0.35, 0.35), 0.05, rng.randf_range(-0.35, 0.35)), Vector3(0.0, rng.randf() * TAU, 0.0),
			Vector3.ONE, Color(0.35, 0.25, 0.12))
	var base_mesh := base.commit()
	var jaw := MeshBuilder.new()
	var arc := TorusMesh.new()
	arc.inner_radius = 0.26
	arc.outer_radius = 0.3
	arc.rings = 16
	arc.ring_segments = 4
	jaw.add(arc, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.5), steel)
	var tooth := CylinderMesh.new()
	tooth.top_radius = 0.0
	tooth.bottom_radius = 0.018
	tooth.height = 0.06
	tooth.radial_segments = 4
	for i in 7:
		var angle := PI * (i + 0.5) / 7.0
		jaw.add(tooth, Vector3(cos(angle) * 0.28, 0.03, sin(angle) * 0.14), Vector3.ZERO, Vector3.ONE, steel)
	return [base_mesh, jaw.commit()]


func _physics_process(_delta: float) -> void:
	if not armed or player == null or player.frozen or not player.is_on_floor():
		return
	var offset := player.global_position - global_position
	if Vector2(offset.x, offset.z).length() < TRIGGER_RADIUS and absf(offset.y) < 0.7:
		snap()


func snap() -> void:
	armed = false
	_sound.play()
	for jaw in _jaws:
		jaw.rotation.x = 1.3 * signf(jaw.scale.z)  # 両側から跳ね上がって閉じる
	player.trap(HOLD_TIME, INJURY)
	player.message.emit("トラバサミに足を挟まれた")
