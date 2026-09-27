class_name CrumblyRock
extends StaticBody3D
## ひびだらけの赤茶けた岩。つかめるが、つかんでいると少しずつ崩れ、しばらくすると砕けて落ちる。
## （プレイヤーが登っている間、Player._update_surface から strain() が呼ばれる）

const GROUP := &"crumbly"
const HOLD_TIME := 1.4

var strained := 0.0

var _material: Material
var _dust: LazyParticles
var _creak: AudioStreamPlayer3D
var _home := Vector3.ZERO
var _broken := false


## pos は崖の表面、normal は崖の外向き
func setup(pos: Vector3, normal: Vector3) -> void:
	add_to_group(GROUP)
	collision_layer = Player.TERRAIN_LAYER
	var out := normal.normalized()
	var up := (Vector3.UP - out * out.y).normalized()
	var size := Vector3(randf_range(1.8, 2.6), randf_range(2.0, 3.0), 1.8)
	global_transform = Transform3D(Basis(up.cross(out), up, out), pos + out * 0.6)  # 岩肌から大きく張り出す
	_home = global_position
	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.shape = box
	add_child(collision)
	# 角ばった岩のかたまり（面の少ない球をつぶして、ごつごつさせる）
	var rock := MeshBuilder.new()
	var lump := SphereMesh.new()
	lump.radius = 0.5
	lump.height = 1.0
	lump.radial_segments = 7
	lump.rings = 4
	rock.add(lump, Vector3.ZERO, Vector3(0.0, 0.0, randf() * TAU), size * 1.1, Color(0.75, 0.42, 0.3))
	# 正面を走る黒いひび（岩の表面の高さに合わせて貼る）
	for i in 7:
		var x := randf_range(-0.28, 0.28) * size.x
		var y := randf_range(-0.3, 0.3) * size.y
		var depth := sqrt(maxf(1.0 - pow(x / (size.x * 0.55), 2.0) - pow(y / (size.y * 0.55), 2.0), 0.05))
		rock.add(_unit_box(), Vector3(x, y, size.z * 0.55 * depth + 0.02),
			Vector3(0.0, 0.0, randf_range(-1.2, 1.2)), Vector3(randf_range(0.4, 1.1), 0.05, 0.03), Color(0.05, 0.03, 0.02))
	_material = Psx.material("rock", Color(0.75, 0.42, 0.3), 0.5, 0.7)
	rock.instance(self, Psx.vertex_material("rock", 0.5, 0.7))
	_dust = LazyParticles.new()
	add_child(_dust)
	_dust.setup(_make_dust.bind(size))
	_creak = AudioStreamPlayer3D.new()
	_creak.stream = Sfx.crack()
	_creak.unit_size = 5.0
	add_child(_creak)


## つかまれている。崩れたら true
func strain(amount: float) -> bool:
	if _broken:
		return true
	strained += amount
	_dust.set_emitting(true)
	if randf() < 0.08:
		_creak.pitch_scale = randf_range(0.5, 0.9)
		_creak.play()
	if strained >= HOLD_TIME:
		crumble()
		return true
	return false


func crumble() -> void:
	_broken = true
	var sound := AudioStreamPlayer3D.new()
	sound.stream = Sfx.crumble()
	sound.unit_size = 10.0
	get_parent().add_child(sound)
	sound.global_position = global_position
	sound.play()
	sound.finished.connect(sound.queue_free)
	# 砕けた破片が転がり落ちる
	for i in 5:
		var piece := RigidBody3D.new()
		piece.collision_layer = Pickup.ITEM_LAYER
		piece.collision_mask = Player.TERRAIN_LAYER
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE * randf_range(0.3, 0.6)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		piece.add_child(collision)
		var mesh := MeshInstance3D.new()
		mesh.mesh = _unit_box()
		mesh.scale = shape.size
		mesh.material_override = _material
		piece.add_child(mesh)
		get_parent().add_child(piece)
		piece.global_position = global_position + Vector3(randf_range(-0.8, 0.8), randf_range(-1.0, 1.0), 0.0)
		piece.linear_velocity = global_transform.basis.z * randf_range(1.0, 3.0)
		get_tree().create_timer(6.0).timeout.connect(piece.queue_free)
	queue_free()


## 大きさ 1 の箱（岩も破片も、これを伸ばして使い回す）
static func _unit_box() -> BoxMesh:
	return Shared.get_or_make("unit_box", func() -> BoxMesh: return BoxMesh.new())


func _process(_delta: float) -> void:
	if strained > 0.0 and not _broken:
		global_position = _home + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * 0.02 * strained
		_dust.set_emitting(strained > 0.3)


## 粒子を作る（LazyParticles が、使うときにだけ呼ぶ）
func _make_dust(size: Vector3) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.amount = 16
	particles.lifetime = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = size * 0.5
	particles.gravity = Vector3(0.0, -6.0, 0.0)
	var grit := BoxMesh.new()
	grit.size = Vector3.ONE * 0.05
	grit.material = Psx.material("", Color(0.6, 0.4, 0.3))
	particles.mesh = grit
	return particles
