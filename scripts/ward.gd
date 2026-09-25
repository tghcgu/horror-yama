class_name Ward
extends Node3D
## 貼ったお札。まわりの円の中に、化け物が入れなくなる。時間がたつと燃え尽きる。

const RADIUS := 6.0
const LIFETIME := 40.0
const GROUP := &"wards"

var _time_left := LIFETIME
var _light: OmniLight3D
var _ring_material: StandardMaterial3D


## point が、どれかのお札の円の中にあるか
static func blocks(tree: SceneTree, point: Vector3) -> bool:
	for ward: Node3D in tree.get_nodes_in_group(GROUP):
		if ward.global_position.distance_to(point) < RADIUS:
			return true
	return false


## ツリーに追加して位置を決めてから呼ぶ。normal はお札を貼った面の向き（地面なら上、壁なら壁の外向き）
func setup(normal: Vector3) -> void:
	add_to_group(GROUP)
	var paper := Items.build_model(Items.Kind.OFUDA)
	add_child(paper)
	if absf(normal.y) < 0.9:
		paper.position = normal * 0.02  # 壁に貼る
		paper.look_at(global_position - normal, Vector3.UP)
	else:
		paper.position.y = 0.2  # 地面に立てる
	paper.scale = Vector3.ONE * 1.5

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.35, 0.25)
	_light.light_energy = 1.2
	_light.omni_range = RADIUS
	_light.position = normal * 0.3
	add_child(_light)

	# 守られている範囲を示す、うっすら光る輪
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color = Color(1.0, 0.3, 0.2, 0.35)
	var ring := TorusMesh.new()
	ring.inner_radius = RADIUS - 0.04
	ring.outer_radius = RADIUS
	ring.rings = 96
	ring.material = _ring_material
	var ring_instance := MeshInstance3D.new()
	ring_instance.mesh = ring
	ring_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_instance)


func _process(delta: float) -> void:
	_time_left -= delta
	var fade := clampf(_time_left / 5.0, 0.0, 1.0)  # 最後の5秒で消えていく
	_light.light_energy = (1.0 + 0.2 * sin(_time_left * 9.0)) * fade
	_ring_material.albedo_color.a = 0.35 * fade
	if _time_left <= 0.0:
		queue_free()
