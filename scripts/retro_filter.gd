class_name RetroFilter
extends CanvasLayer
## 画面全体に PS1 風の加工をかける。HUD より下の層に置くので、文字やゲージは加工されない。
## 設定の「画面の粗さ」に合わせて、画面の解像度とポリゴンの震え方を切り替える。

const POST_SHADER := preload("res://shaders/psx_post.gdshader")

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = -1
	_material = ShaderMaterial.new()
	_material.shader = POST_SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)
	Settings.changed.connect(_apply)
	_apply()


func _apply() -> void:
	var resolution := Settings.retro_resolution()
	_rect.visible = resolution > 0
	_material.set_shader_parameter("resolution", float(resolution))
	RenderingServer.global_shader_parameter_set("psx_resolution", float(resolution))
