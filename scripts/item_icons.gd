class_name ItemIcons
extends Node
## アイテム欄に出す絵。アイテムの 3D の見た目を小さな画面に 1 つずつ写し、画像として取っておく。
## 写し終えたら小さな画面は捨てる（画面をいくつも持ち続けると、GPU の資源を食う）。

const SIZE := 96

var _textures := {}  # 種類 → 絵


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return  # 画面なしでは写せない
	_render_all()


func icon(kind: int) -> Texture2D:
	return _textures.get(kind)


func _render_all() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	light.light_energy = 1.3
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.0, 0.0, 1.0)
	viewport.add_child(camera)
	camera.make_current()
	var pivot := Node3D.new()
	pivot.rotation = Vector3(0.35, 0.6, -0.25)  # 少し斜めから見る
	viewport.add_child(pivot)

	for kind in Items.COUNT:
		var model := Items.build_model(kind)
		pivot.add_child(model)
		var bounds := Items.model_bounds(model)
		model.position = -bounds.get_center()
		camera.size = maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z) * 1.35
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		if image:
			_textures[kind] = ImageTexture.create_from_image(image)
		model.queue_free()
	viewport.queue_free()
