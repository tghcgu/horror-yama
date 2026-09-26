class_name Vines
extends Node3D
## 樹海の崖に垂れ下がる太いつる。つるの上をつかんで登ると、ずっと疲れにくい。

const WIDTH := 3.0
const CLIMB_DRAIN := 0.4

var player: Player
var height := 6.0

var _normal := Vector3.BACK


## pos は崖の表面、normal は崖の外向き
func setup(pos: Vector3, normal: Vector3, owner_player: Player) -> void:
	player = owner_player
	_normal = Vector3(normal.x, 0.0, normal.z).normalized()
	height = randf_range(5.0, 8.0)
	global_position = pos + Vector3.UP * height * 0.5
	look_at(global_position - _normal, Vector3.UP)
	var vines := MeshBuilder.new()
	var strand := CylinderMesh.new()
	strand.top_radius = 0.035
	strand.bottom_radius = 0.025
	strand.height = 1.0
	strand.radial_segments = 5
	var blade := BoxMesh.new()
	blade.size = Vector3(0.16, 0.1, 0.01)
	for i in 7:
		var x := (i / 6.0 - 0.5) * WIDTH + randf_range(-0.15, 0.15)
		var length := height * randf_range(0.75, 1.05)
		vines.add(strand, Vector3(x, height * 0.5 - length * 0.5, 0.25), Vector3(0.0, 0.0, randf_range(-0.06, 0.06)),
			Vector3(1.0, length, 1.0), Color(0.2, 0.32, 0.12))
		for k in int(length / 0.7):
			vines.add(blade, Vector3(x + randf_range(-0.08, 0.08), height * 0.5 - 0.3 - k * 0.7, 0.28),
				Vector3(0.0, 0.0, randf_range(-0.8, 0.8)), Vector3.ONE, Color(0.25, 0.42, 0.14))
	vines.instance(self, Psx.vertex_material("", 1.0, 0.85))


func _physics_process(_delta: float) -> void:
	if player == null or player.state != Player.State.CLIMB:
		return
	var local := to_local(player.global_position + Vector3.UP * 1.0)
	if absf(local.x) < WIDTH * 0.6 and absf(local.y) < height * 0.55 and absf(local.z) < 1.5:
		player.zone_climb_drain = minf(player.zone_climb_drain, CLIMB_DRAIN)
