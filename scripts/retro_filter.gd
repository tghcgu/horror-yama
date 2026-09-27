class_name RetroFilter
extends CanvasLayer
## 画面全体に PS1 風の加工をかける。HUD より下の層に置くので、文字やゲージは加工されない。
## 設定の「画面の粗さ」に合わせて、画面の解像度とポリゴンの震え方を切り替える。
## どうせ粗くするので、3D は最初から粗くした画面と同じ解像度で描き、GPU の負担を減らす（見た目は同じ）。
## 加工なしのときは、「描画の細かさ」の解像度で描く。

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
	get_viewport().size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var resolution := Settings.retro_resolution()
	_rect.visible = resolution > 0
	_material.set_shader_parameter("resolution", float(resolution))
	RenderingServer.global_shader_parameter_set("psx_resolution", float(resolution))
	var viewport := get_viewport()
	var height := float(get_window().size.y)  # 実際の画面の縦の画素数（フルスクリーンなら、モニターの解像度）
	if resolution == 0 or height <= 0.0:
		# 加工なし：設定の「描画の細かさ」の解像度で描き、FSR でなめらかに引き伸ばす（内蔵 GPU でも軽く）
		var target := Settings.detail_height()
		var scale := 1.0 if target == 0 or height <= 0.0 else clampf(target / height, 0.25, 1.0)
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = scale
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = clampf(resolution / height, 0.2, 1.0)
