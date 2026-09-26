class_name Mirror
extends Node3D
## 本当に映る鏡。鏡の面に対してプレイヤーのカメラと対称な位置にもう 1 台カメラを置き、
## 鏡の枠ぴったりの視野で描いた映像を、左右反転して鏡の面に貼る。
## 鏡は自分の +Z 側を映す。置くときは +Z を部屋の内側へ向ける。

const RESOLUTION_HEIGHT := 260  # 鏡の映像の縦の画素数（PS1 らしく粗く）
const GLASS_LAYER := 8          # 鏡の面そのもの。鏡のカメラには映さない
const HANDS_LAYER := 2          # 一人称の手。鏡には映さない（代わりに体が映る）
const MIRROR_SHADER := preload("res://shaders/mirror_glass.gdshader")

var size := Vector2(4.0, 2.4)
var viewer: Camera3D  # 鏡を見ているカメラ（プレイヤーの目）

var _viewport: SubViewport
var _camera: Camera3D
var _glass: MeshInstance3D


func setup(mirror_size: Vector2, viewing_camera: Camera3D) -> void:
	size = mirror_size
	viewer = viewing_camera
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(roundi(RESOLUTION_HEIGHT * size.x / size.y), RESOLUTION_HEIGHT)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.cull_mask = 0xFFFFF & ~GLASS_LAYER & ~HANDS_LAYER
	_viewport.add_child(_camera)

	var quad := QuadMesh.new()
	quad.size = size
	var material := ShaderMaterial.new()
	material.shader = MIRROR_SHADER
	material.set_shader_parameter("reflection", _viewport.get_texture())
	quad.material = material
	_glass = MeshInstance3D.new()
	_glass.mesh = quad
	_glass.layers = GLASS_LAYER
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glass)


func _process(_delta: float) -> void:
	if viewer == null:
		return
	var plane := global_transform.orthonormalized()
	var normal := plane.basis.z
	var eye := viewer.global_position
	var distance := (eye - plane.origin).dot(normal)
	# 鏡の裏側や真横すぎる所、遠く（山に出かけている間）からは映さない
	var visible_from_here := distance > 0.05 and distance < 60.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible_from_here else SubViewport.UPDATE_DISABLED
	if not visible_from_here:
		return
	# 鏡の面に対して対称な位置から、鏡の面に垂直に部屋を見る
	var mirrored_eye := eye - normal * distance * 2.0
	var right := -plane.basis.x  # 左右反転して見るので、カメラの右は鏡の左
	var camera_basis := Basis(right, plane.basis.y, -normal)
	_camera.global_transform = Transform3D(camera_basis, mirrored_eye)
	# 視野を、鏡の枠ぴったりにする（鏡より手前＝鏡の裏にあるものは映らない）
	var to_center := plane.origin - mirrored_eye
	_camera.set_frustum(size.y, Vector2(to_center.dot(right), to_center.dot(plane.basis.y)), distance, 200.0)
