class_name Campfire
extends Node3D
## 山の頂上にある、休むためのたき火。たどり着くと火がともり、そこが次の再開地点になる。
## 火のついたたき火のまわりは暖かく、化け物は入ってこられない（お札と同じ仕組み）。

const LIGHT_DISTANCE := 4.0  # これより近づくと火がつく
const WARM_RADIUS := 7.0     # 体が温まる範囲
const SAFE_RADIUS := 9.0     # 化け物が入れない範囲

var lit := false
var radius := SAFE_RADIUS  # Ward.blocks() が読む

var _flame: MeshInstance3D
var _light: OmniLight3D
var _crackle: AudioStreamPlayer3D
var _time := randf() * 10.0


func _ready() -> void:
	var wood := CreatureKit.flat(Color(0.25, 0.16, 0.1))
	for i in 3:
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.07
		log_mesh.bottom_radius = 0.07
		log_mesh.height = 0.9
		var piece := CreatureKit.part(self, log_mesh, wood, Vector3(0.0, 0.12, 0.0))
		piece.rotation = Vector3(deg_to_rad(80.0), i * TAU / 3.0, 0.0)
	var stone := Psx.material("stone", Color(0.6, 0.6, 0.6), 2.0)
	for i in 8:
		var angle := i * TAU / 8.0
		var rock := CreatureKit.sphere(0.13)
		CreatureKit.part(self, rock, stone, Vector3(cos(angle) * 0.62, 0.05, sin(angle) * 0.62))
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.18
	flame_mesh.height = 0.45
	_flame = CreatureKit.part(self, flame_mesh, CreatureKit.glow(Color(1.0, 0.55, 0.15), 3.0), Vector3(0.0, 0.3, 0.0))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.25)
	_light.omni_range = 14.0
	_light.shadow_enabled = true
	_light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID  # 6 面ではなく 2 面で影を描く（軽い）
	_light.distance_fade_enabled = true  # 遠くのたき火は、影を切り、さらに遠いと光も切る
	_light.distance_fade_begin = 60.0
	_light.distance_fade_shadow = 25.0
	_light.distance_fade_length = 20.0
	_light.position.y = 0.8
	add_child(_light)
	_crackle = AudioStreamPlayer3D.new()
	_crackle.stream = Sfx.crackle()
	_crackle.unit_size = 3.0
	_crackle.max_distance = 25.0
	_crackle.position.y = 0.3
	add_child(_crackle)
	set_lit(false)


func set_lit(on: bool) -> void:
	lit = on
	_flame.visible = on
	_light.visible = on
	if on:
		add_to_group(Ward.GROUP)
		_crackle.play()
	else:
		remove_from_group(Ward.GROUP)
		_crackle.stop()


func is_warming(point: Vector3) -> bool:
	return lit and global_position.distance_to(point) < WARM_RADIUS


func _process(delta: float) -> void:
	if not lit:
		return
	_time += delta
	_light.light_energy = 2.2 + 0.35 * sin(_time * 13.0) + randf() * 0.25
	_flame.scale = Vector3(1.0, 1.0 + 0.15 * sin(_time * 17.0) + randf() * 0.1, 1.0)
