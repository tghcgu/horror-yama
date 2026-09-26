class_name Jizo
extends Node3D
## 赤いよだれかけのお地蔵さん。食べ物を選んで E でお供えすると、お守りを授かる（一体につき一度だけ）。

var offered := false

var _candle: OmniLight3D
var _flame: MeshInstance3D


func setup(pos: Vector3, facing: Vector3) -> void:
	add_to_group(&"interactables")
	global_position = pos
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length() > 0.1:
		look_at(pos + flat.normalized(), Vector3.UP)
	var stone := Color(0.72, 0.72, 0.7)
	var statue := MeshBuilder.new()
	var base := CylinderMesh.new()
	base.top_radius = 0.28
	base.bottom_radius = 0.32
	base.height = 0.2
	base.radial_segments = 8
	statue.add(base, Vector3(0.0, 0.1, 0.0), Vector3.ZERO, Vector3.ONE, Color(0.3, 0.38, 0.2))
	var body := CapsuleMesh.new()
	body.radius = 0.18
	body.height = 0.62
	body.radial_segments = 8
	body.rings = 3
	statue.add(body, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3.ONE, stone)
	var head := CreatureKit.sphere(0.14)
	head.radial_segments = 8
	head.rings = 5
	statue.add(head, Vector3(0.0, 0.92, 0.0), Vector3.ZERO, Vector3.ONE, stone)
	var bib := PrismMesh.new()
	bib.size = Vector3(0.34, 0.24, 0.04)
	statue.add(bib, Vector3(0.0, 0.66, -0.17), Vector3(PI, 0.0, 0.0), Vector3.ONE, Color(0.8, 0.12, 0.1))
	# 閉じた目
	var box := BoxMesh.new()
	for side in [-1.0, 1.0]:
		statue.add(box, Vector3(0.045 * side, 0.93, -0.135), Vector3.ZERO, Vector3(0.05, 0.008, 0.01), Color(0.2, 0.2, 0.2))
	# お供えの皿と、お供えすると灯るろうそく
	var plate := CylinderMesh.new()
	plate.top_radius = 0.12
	plate.bottom_radius = 0.1
	plate.height = 0.02
	statue.add(plate, Vector3(0.0, 0.21, -0.35), Vector3.ZERO, Vector3.ONE, Color(0.85, 0.83, 0.78))
	var candle := CylinderMesh.new()
	candle.top_radius = 0.02
	candle.bottom_radius = 0.02
	candle.height = 0.12
	statue.add(candle, Vector3(0.2, 0.26, -0.3), Vector3.ZERO, Vector3.ONE, Color(0.95, 0.93, 0.88))
	statue.instance(self, Psx.vertex_material("stone", 1.5))
	_flame = CreatureKit.part(self, CreatureKit.sphere(0.02), CreatureKit.glow(Color(1.0, 0.6, 0.2), 5.0), Vector3(0.2, 0.34, -0.3))
	_flame.visible = false
	_candle = OmniLight3D.new()
	_candle.light_color = Color(1.0, 0.6, 0.3)
	_candle.omni_range = 3.0
	_candle.position = Vector3(0.2, 0.4, -0.3)
	_candle.visible = false
	add_child(_candle)


func interact_hint(player: Player) -> String:
	if offered:
		return ""
	var kind := player.inventory.selected_kind()
	if kind in Items.FOODS:
		return "E：お供えする（%s）" % Items.NAMES[kind]
	return "お地蔵さん（食べ物を選ぶと、お供えできる）"


func interact(player: Player) -> void:
	if offered:
		return
	var kind := player.inventory.selected_kind()
	if not kind in Items.FOODS:
		return
	player.inventory.remove_from(player.inventory.selected)
	if player.inventory.is_full_for(Items.Kind.OMAMORI):
		player.inventory.add(kind)  # 受け取る場所がないので、お供えはやめておく
		player.message.emit("持ち物がいっぱい")
		return
	offered = true
	_flame.visible = true
	_candle.visible = true
	# お供えした食べ物を皿に置く
	var food := Items.build_model(kind)
	food.position = Vector3(0.0, 0.3, -0.35)
	food.scale = Vector3.ONE * 1.2
	add_child(food)
	player.pick_up(Items.Kind.OMAMORI)
	player.message.emit("お守りを授かった")
