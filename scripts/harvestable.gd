class_name Harvestable
extends Node3D
## 実のなる木や草。見ながら E で採る（持ちきれない分は足もとに落ちる）。しばらくすると、また実る。
##   木いちごの茂み：赤い実を摘む → 木の実
##   栗の木：ゆすると、毬から栗が落ちてくる → 栗
##   キノコの群れ：根元から採る → 謎のキノコ

var kind := Items.Kind.BERRIES
var amount := Vector2i(1, 3)
var regrow := 240.0       # また実るまで (s)
var label := "木の実を摘む"
var drop := false          # true なら、採った物は足もとに落ちる（木をゆする）
var fruit: Node3D          # 実の見た目（採ると消え、また実ると出る）
var found_message := ""    # 採ったときの知らせ（%s に物の名前が入る）。空なら「〜を何個とった」
var features: MountainFeatures

var _timer := 0.0


func _ready() -> void:
	add_to_group(&"interactables")


func is_ripe() -> bool:
	return _timer <= 0.0


func interact_hint(_player: Player) -> String:
	return ("E：" + label) if is_ripe() else ""


func interact(player: Player) -> void:
	if not is_ripe():
		return
	_timer = regrow
	remove_from_group(&"interactables")
	if fruit:
		fruit.visible = false
	var count := randi_range(amount.x, amount.y)
	for i in count:
		if drop or not player.pick_up(kind):
			# 木から落ちてくる（持ちきれない分も、足もとに落とす）
			var from := global_position + Vector3(randf_range(-1.2, 1.2), 3.0 if drop else 1.0, randf_range(-1.2, 1.2))
			features.spawn_item(kind, from, Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)))
	if found_message != "":
		player.message.emit(found_message % Items.NAMES[kind])
	else:
		player.message.emit("%sを%d個とった" % [Items.NAMES[kind], count] if not drop else "木をゆすると、%sが落ちてきた" % Items.NAMES[kind])


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		add_to_group(&"interactables")
		if fruit:
			fruit.visible = true


## 木いちごの茂みの実：低木のあちこちに、赤い実の房
static func berries_mesh() -> ArrayMesh:
	return Shared.get_or_make("harvest_berries", func() -> ArrayMesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var builder := MeshBuilder.new()
		var ball := SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		ball.radial_segments = 6
		ball.rings = 3
		for i in 22:
			var angle := rng.randf() * TAU
			var center := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.2, 0.75) + Vector3.UP * rng.randf_range(0.4, 1.3)
			for k in 3:
				builder.add(ball, center + Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04)),
					Vector3.ZERO, Vector3.ONE * 0.05, Color(0.85, 0.12, 0.14) if rng.randf() < 0.8 else Color(0.95, 0.5, 0.15))
		return builder.commit())
