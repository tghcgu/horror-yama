class_name GhostStones
extends Node3D
## 霊峰の崖沿いに浮かぶ、半透明の飛び石。崖を登らずに上へ行ける近道だが、
## 石はゆっくり現れては消えるのをくり返し、消えている間は乗れない（乗っていれば落ちる）。

const COUNT := 9
const PERIOD := 7.0
const SOLID_TIME := 4.5
const FADE := 0.8
const STEP_UP := 1.45

var _stones: Array[StaticBody3D] = []
var _materials: Array[StandardMaterial3D] = []
var _time := 0.0


## pos は崖の根元あたりの表面、normal は崖の外向き
func setup(pos: Vector3, normal: Vector3) -> void:
	global_position = pos
	var out := Vector3(normal.x, 0.0, normal.z).normalized()
	var right := out.cross(Vector3.UP).normalized()
	var slab := BoxMesh.new()  # 石の形は 1 つを使い回す
	slab.size = Vector3(1.5, 0.3, 1.5)
	for i in COUNT:
		var stone := StaticBody3D.new()
		stone.collision_layer = Player.TERRAIN_LAYER
		var size := Vector3(1.5, 0.3, 1.5)
		var box := BoxShape3D.new()
		box.size = size
		var collision := CollisionShape3D.new()
		collision.shape = box
		stone.add_child(collision)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.75, 0.85, 1.0, 0.6)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = Color(0.35, 0.5, 0.8)
		material.emission_energy_multiplier = 0.8
		var mesh := MeshInstance3D.new()
		mesh.mesh = slab
		mesh.material_override = material
		stone.add_child(mesh)
		add_child(stone)
		stone.position = out * 1.9 + Vector3.UP * (1.0 + i * STEP_UP) + right * sin(i * 1.3) * 1.6
		stone.rotation.y = randf() * TAU
		_stones.append(stone)
		_materials.append(material)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.65, 1.0)
	light.omni_range = 9.0
	light.light_energy = 0.8
	light.position = out * 1.9 + Vector3.UP * COUNT * STEP_UP * 0.5
	add_child(light)


## i 番目の石が、いま乗れるか
func is_solid(i: int) -> bool:
	return _phase(i) < SOLID_TIME


func _phase(i: int) -> float:
	return fmod(_time + i * 0.6, PERIOD)


func _physics_process(delta: float) -> void:
	_time += delta
	for i in _stones.size():
		var phase := _phase(i)
		var alpha := 0.0
		if phase < SOLID_TIME:
			alpha = 0.65 * minf(phase / FADE, 1.0)
			if phase > SOLID_TIME - FADE:
				alpha = lerpf(0.2, 0.65, (SOLID_TIME - phase) / FADE)  # 消える前に薄くなって知らせる
		else:
			alpha = 0.04
		_materials[i].albedo_color.a = alpha
		(_stones[i].get_child(0) as CollisionShape3D).disabled = not is_solid(i)
