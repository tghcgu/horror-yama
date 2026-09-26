class_name ToriiGate
extends Node3D
## 山のあちこちに立つ小さな鳥居。くぐると、対になったもう一つの鳥居へ飛ばされる。
## 行き先はずっと上かもしれないし、ふもとへ逆戻りかもしれない。

const TRIGGER_RADIUS := 0.9
const COOLDOWN := 3.0

var partner: ToriiGate
var player: Player
var cooldown := 0.0

var _sound: AudioStreamPlayer3D
var _swirl: MeshInstance3D


func setup(pos: Vector3, facing: Vector3, owner_player: Player) -> void:
	player = owner_player
	global_position = pos
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length() > 0.1:
		look_at(pos + flat.normalized(), Vector3.UP)
	var red := Color(1.0, 0.22, 0.12)
	var gate := MeshBuilder.new()
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.08
	pillar.bottom_radius = 0.09
	pillar.height = 2.2
	pillar.radial_segments = 8
	var box := BoxMesh.new()
	for side in [-1.0, 1.0]:
		gate.add(pillar, Vector3(0.75 * side, 1.1, 0.0), Vector3.ZERO, Vector3.ONE, red)
	gate.add(box, Vector3(0.0, 1.8, 0.0), Vector3.ZERO, Vector3(1.9, 0.12, 0.14), red)
	gate.add(box, Vector3(0.0, 2.15, 0.0), Vector3.ZERO, Vector3(2.3, 0.14, 0.2), red)
	gate.add(box, Vector3(0.0, 2.25, 0.0), Vector3.ZERO, Vector3(2.45, 0.08, 0.24), Color(0.08, 0.07, 0.07))
	gate.instance(self, Psx.vertex_material("wood", 1.0, 0.6))
	# くぐる所に揺らめく、暗い渦
	var swirl := StandardMaterial3D.new()
	swirl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	swirl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	swirl.albedo_color = Color(0.35, 0.1, 0.45, 0.45)
	swirl.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plane := QuadMesh.new()
	plane.size = Vector2(1.4, 1.75)
	_swirl = CreatureKit.part(self, plane, swirl, Vector3(0.0, 0.88, 0.0))
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.3, 0.9)
	light.omni_range = 4.0
	light.light_energy = 0.8
	light.position.y = 1.0
	add_child(light)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.shimmer()
	_sound.pitch_scale = 0.6
	_sound.unit_size = 6.0
	add_child(_sound)


func _process(delta: float) -> void:
	_swirl.rotation.z += delta * 0.8
	_swirl.scale = Vector3.ONE * (0.95 + 0.05 * sin(Time.get_ticks_msec() * 0.003))


func _physics_process(delta: float) -> void:
	cooldown -= delta
	if partner == null or player == null or player.frozen or cooldown > 0.0:
		return
	var offset := player.global_position - global_position
	if Vector2(offset.x, offset.z).length() < TRIGGER_RADIUS and absf(offset.y) < 1.5:
		warp()


## 対の鳥居の前に飛ばす（向こうの鳥居をくぐり抜けた向きで出る）
func warp() -> void:
	cooldown = COOLDOWN
	partner.cooldown = COOLDOWN
	var forward := -partner.global_transform.basis.z
	player.velocity = Vector3.ZERO
	player.global_position = partner.global_position + forward * 1.6 + Vector3.UP * 0.3
	player.face_point(player.get_camera().global_position + forward * 5.0)
	player.add_shake(0.6)
	_sound.play()
	partner._sound.play()
