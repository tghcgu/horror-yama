class_name Lobby
extends Node3D
## 山から遠く離れた町の、古いホテルのロビー。ゲームはここから始まる。
## 東の壁の大きな金縁の鏡に自分の姿が映り、鏡の前で帽子・上着・マフラーの色を選べる。
## 赤い絨毯、シャンデリア、フロントと鍵掛け、振り子の揺れる柱時計、ソファ、観葉植物、掲示板。
## 南の玄関を出ると、霊峰行きのバスが止まっている。バスの扉まで行くと出発する。原点は床の真ん中。

const INSIDE := Vector3(7.0, 4.0, 5.5)  # 部屋の内側の、横幅の半分・天井の高さ・奥行きの半分
const WALL := 0.25
const DOOR := Vector2(2.4, 2.8)
const MIRROR_SIZE := Vector2(5.2, 2.9)
const MIRROR_REACH := 3.2  # 鏡のこれだけ手前までなら、身だしなみを整えられる
const FONT := preload("res://assets/fonts/DotGothic16-Regular.ttf")
const NOTICE := """登山者の皆様へ

一、日が沈んだら
　　火のそばを離れないこと
一、崖の上から誰かが覗いていたら
　　灯りを向けること
一、雪の中に白い人が立っていたら
　　目を離さないこと
一、岩場の壁の
　　大きな蜘蛛に近づかないこと

　　　　　　　　霊峰山岳会"""

var mirror: Mirror
var spawn_position := Vector3.ZERO
var spawn_yaw := 0.0

var _body: StaticBody3D
var _pendulum: Node3D
var _chandelier: OmniLight3D
var _tick: AudioStreamPlayer3D
var _bus_door := Vector3.ZERO
var _time := 0.0
var _last_second := -1


## ツリーに追加して位置を決めてから呼ぶ。viewer は鏡を見るカメラ（プレイヤーの目）
func build(viewer: Camera3D) -> void:
	_body = StaticBody3D.new()
	add_child(_body)
	var dark_wood := Psx.material("wood", Color(0.24, 0.15, 0.1), 1.5)
	var gold := Psx.material("", Color(0.85, 0.62, 0.22))
	gold.set_shader_parameter("emission", Color(0.12, 0.08, 0.02))
	_build_room(dark_wood, gold)
	_build_mirror(viewer, gold)
	_build_reception(dark_wood, gold)
	_build_clock(dark_wood, gold)
	_build_lounge(dark_wood, gold)
	_build_board()
	_build_outside()
	_build_dust()
	# 鏡の 2 m ほど手前に、鏡のほうを向いて立つ
	spawn_position = to_global(Vector3(INSIDE.x - 2.3, 0.05, 0.4))
	spawn_yaw = rotation.y - PI / 2.0


## バスの扉の前まで来たか（出発の合図）
func is_boarding(point: Vector3) -> bool:
	return point.distance_to(_bus_door) < 2.2


## 部屋の中にいるか（霧を消すのに使う）
func contains(point: Vector3) -> bool:
	var p := to_local(point)
	return absf(p.x) < INSIDE.x + 1.0 and p.z < INSIDE.z + 9.0 and p.z > -INSIDE.z - 1.0 and p.y < INSIDE.y + 2.0 and p.y > -2.0


## 鏡の前にいて、鏡のほうを向いているか
func facing_mirror(camera: Camera3D) -> bool:
	var p := to_local(camera.global_position)
	if p.x < INSIDE.x - MIRROR_REACH or absf(p.z) > MIRROR_SIZE.x / 2.0 + 0.5:
		return false
	var forward := -camera.global_transform.basis.z
	return forward.dot(global_transform.basis.x) > 0.5


func _process(delta: float) -> void:
	_time += delta
	_pendulum.rotation.z = sin(_time * PI) * 0.25
	_chandelier.light_energy = 1.7 + sin(_time * 0.7) * 0.03
	var second := int(_time)
	if second != _last_second:
		_last_second = second
		_tick.pitch_scale = 1.0 if second % 2 == 0 else 0.85  # チク、タク
		_tick.play()


# --- 部屋 ---

func _build_room(dark_wood: Material, gold: Material) -> void:
	var w := INSIDE.x
	var d := INSIDE.z
	var h := INSIDE.y
	# 床（寄せ木）と、真ん中の赤い絨毯
	_box(Vector3(w * 2.0 + WALL * 2.0, 0.4, d * 2.0 + WALL * 2.0), Vector3(0.0, -0.2, 0.0), Psx.material("wood", Color(0.45, 0.3, 0.18), 1.2))
	var carpet := PlaneMesh.new()
	carpet.size = Vector2(w * 2.0 - 2.0, d * 2.0 - 2.0)
	CreatureKit.part(self, carpet, _textured(_carpet_texture(), Color.WHITE), Vector3(0.0, 0.01, 0.0))
	# 天井と梁
	_box(Vector3(w * 2.0 + WALL * 2.0, 0.3, d * 2.0 + WALL * 2.0), Vector3(0.0, h + 0.15, 0.0), Psx.material("", Color(0.78, 0.72, 0.6)))
	for x in [-4.5, -1.5, 1.5, 4.5]:
		_box(Vector3(0.3, 0.3, d * 2.0), Vector3(x, h - 0.15, 0.0), dark_wood, false)
	# 壁：下は板張り、上は縦じまの壁紙
	var paper := _textured(_wallpaper_texture(), Color.WHITE, 0.5)
	var wainscot := 1.1
	for side in [-1.0, 1.0]:
		_wall(Vector3(side * (w + WALL / 2.0), 0.0, 0.0), Vector3(WALL, 0.0, d * 2.0 + WALL * 2.0), paper, dark_wood, wainscot)
	_wall(Vector3(0.0, 0.0, -d - WALL / 2.0), Vector3(w * 2.0 + WALL * 2.0, 0.0, WALL), paper, dark_wood, wainscot)
	# 南の壁と玄関の開口
	var side_width := w + WALL - DOOR.x / 2.0
	for s in [-1.0, 1.0]:
		_wall(Vector3(s * (DOOR.x / 2.0 + side_width / 2.0), 0.0, d + WALL / 2.0), Vector3(side_width, 0.0, WALL), paper, dark_wood, wainscot)
	_box(Vector3(DOOR.x, h - DOOR.y, WALL), Vector3(0.0, DOOR.y + (h - DOOR.y) / 2.0, d + WALL / 2.0), paper)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.14, DOOR.y, WALL + 0.12), Vector3(s * (DOOR.x / 2.0 + 0.07), DOOR.y / 2.0, d + WALL / 2.0), gold, false)
	_box(Vector3(DOOR.x + 0.28, 0.14, WALL + 0.12), Vector3(0.0, DOOR.y + 0.07, d + WALL / 2.0), gold, false)
	_label("霊峰行き　バスのりば", Vector3(0.0, DOOR.y + 0.45, d - 0.02), PI, 0.006, Color(0.95, 0.85, 0.55), true)
	# 玄関の両わきの窓（外は曇り空）
	for x in [-4.0, 4.0]:
		var glass := QuadMesh.new()
		glass.size = Vector2(1.8, 1.6)
		var pane := CreatureKit.part(self, glass, CreatureKit.glow(Color(0.55, 0.58, 0.62), 0.8), Vector3(x, 2.1, d - 0.01))
		pane.rotation.y = PI
		for bar in [Vector3(2.0, 0.1, 0.1), Vector3(0.1, 1.8, 0.1)]:
			_box(bar, Vector3(x, 2.1, d - 0.05), dark_wood, false)
	# シャンデリア
	var center := Vector3(0.0, h - 1.1, 0.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.62
	CreatureKit.part(self, ring, gold, center)
	var chain := CylinderMesh.new()
	chain.top_radius = 0.02
	chain.bottom_radius = 0.02
	chain.height = 1.0
	CreatureKit.part(self, chain, gold, center + Vector3(0.0, 0.55, 0.0))
	for i in 8:
		var angle := i * TAU / 8.0
		var bulb := CreatureKit.sphere(0.07)
		CreatureKit.part(self, bulb, CreatureKit.glow(Color(1.0, 0.82, 0.55), 4.0), center + Vector3(cos(angle) * 0.6, 0.12, sin(angle) * 0.6))
	_chandelier = OmniLight3D.new()
	_chandelier.light_color = Color(1.0, 0.82, 0.6)
	_chandelier.omni_range = 13.0
	_chandelier.shadow_enabled = true
	_chandelier.position = center
	add_child(_chandelier)


func _wall(center: Vector3, size: Vector3, paper: Material, wood: Material, wainscot: float) -> void:
	var h := INSIDE.y
	_box(Vector3(size.x, wainscot, size.z), center + Vector3(0.0, wainscot / 2.0, 0.0), wood)
	_box(Vector3(size.x, h - wainscot, size.z), center + Vector3(0.0, wainscot + (h - wainscot) / 2.0, 0.0), paper)


# --- 鏡 ---

func _build_mirror(viewer: Camera3D, gold: Material) -> void:
	mirror = Mirror.new()
	add_child(mirror)
	var center := Vector3(INSIDE.x - 0.04, 0.3 + MIRROR_SIZE.y / 2.0, 0.0)
	# 鏡の +Z を部屋の内側（西, -X）へ向ける
	mirror.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), center)
	mirror.setup(MIRROR_SIZE, viewer)
	var t := 0.2
	for s in [-1.0, 1.0]:
		_box(Vector3(0.12, MIRROR_SIZE.y + t * 2.0, t), center + Vector3(-0.02, 0.0, s * (MIRROR_SIZE.x / 2.0 + t / 2.0)), gold, false)
		_box(Vector3(0.12, t, MIRROR_SIZE.x + t * 2.0), center + Vector3(-0.02, s * (MIRROR_SIZE.y / 2.0 + t / 2.0), 0.0), gold, false)
	# 枠のてっぺんの飾り
	var crest := SphereMesh.new()
	crest.radius = 0.22
	crest.height = 0.3
	CreatureKit.part(self, crest, gold, center + Vector3(-0.05, MIRROR_SIZE.y / 2.0 + t + 0.08, 0.0))


# --- フロント ---

func _build_reception(dark_wood: Material, gold: Material) -> void:
	var desk := Vector3(0.0, 0.0, -INSIDE.z + 1.3)
	_box(Vector3(4.2, 1.1, 0.8), desk + Vector3(0.0, 0.55, 0.0), dark_wood)
	_box(Vector3(4.4, 0.08, 1.0), desk + Vector3(0.0, 1.14, 0.0), Psx.material("stone", Color(0.9, 0.88, 0.85), 2.0), false)
	# 呼び鈴
	var bell := SphereMesh.new()
	bell.radius = 0.08
	bell.height = 0.08
	bell.is_hemisphere = true
	CreatureKit.part(self, bell, gold, desk + Vector3(0.9, 1.18, 0.2))
	# 奥の壁の鍵掛けと、ホテルの名前
	var rack := Vector3(0.0, 1.9, -INSIDE.z + 0.06)
	_box(Vector3(1.6, 0.9, 0.06), rack, dark_wood, false)
	for row in 2:
		for col in 6:
			var key := Vector3(-0.6 + col * 0.24, 2.1 - row * 0.4, -INSIDE.z + 0.12)
			_box(Vector3(0.05, 0.14, 0.03), key, gold, false)
	_label("霊峰ホテル", Vector3(0.0, 3.1, -INSIDE.z + 0.03), 0.0, 0.012, Color(0.95, 0.78, 0.35), true)
	_lamp(desk + Vector3(-1.5, 1.18, 0.0), 0.8, 5.0)


# --- 柱時計 ---

func _build_clock(dark_wood: Material, gold: Material) -> void:
	var base := Vector3(-INSIDE.x + 0.5, 0.0, -INSIDE.z + 0.6)
	_box(Vector3(0.6, 2.3, 0.45), base + Vector3(0.0, 1.15, 0.0), dark_wood)
	var face := CylinderMesh.new()
	face.top_radius = 0.22
	face.bottom_radius = 0.22
	face.height = 0.02
	var dial := CreatureKit.part(self, face, Psx.material("", Color(0.92, 0.88, 0.75)), base + Vector3(0.0, 1.95, 0.235))
	dial.rotation.x = PI / 2.0
	for i in 2:  # 針
		var hand := _box(Vector3(0.015, 0.16 - i * 0.05, 0.01), base + Vector3(0.0, 1.95 + (0.07 - i * 0.02), 0.25), CreatureKit.flat(Color.BLACK), false)
		hand.rotation.z = 0.6 + i * 2.2
	var window := QuadMesh.new()
	window.size = Vector2(0.4, 1.0)
	CreatureKit.part(self, window, CreatureKit.flat(Color(0.05, 0.04, 0.03)), base + Vector3(0.0, 1.0, 0.227))
	_pendulum = Node3D.new()
	_pendulum.position = base + Vector3(0.0, 1.45, 0.25)
	add_child(_pendulum)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.01
	rod.bottom_radius = 0.01
	rod.height = 0.6
	CreatureKit.part(_pendulum, rod, gold, Vector3(0.0, -0.3, 0.0))
	var disc := CylinderMesh.new()
	disc.top_radius = 0.09
	disc.bottom_radius = 0.09
	disc.height = 0.02
	var weight := CreatureKit.part(_pendulum, disc, gold, Vector3(0.0, -0.62, 0.0))
	weight.rotation.x = PI / 2.0
	_tick = AudioStreamPlayer3D.new()
	_tick.stream = Sfx.tick()
	_tick.unit_size = 2.0
	_tick.volume_db = -8.0
	_tick.position = base + Vector3(0.0, 1.5, 0.0)
	add_child(_tick)


# --- ソファと観葉植物 ---

func _build_lounge(dark_wood: Material, gold: Material) -> void:
	var velvet := Psx.material("", Color(0.55, 0.07, 0.1))
	var table := Vector3(-3.3, 0.0, 1.8)
	for s in [-1.0, 1.0]:
		var seat := table + Vector3(0.0, 0.0, s * 1.5)
		_box(Vector3(2.4, 0.45, 0.9), seat + Vector3(0.0, 0.225, 0.0), velvet)
		_box(Vector3(2.4, 0.6, 0.25), seat + Vector3(0.0, 0.75, s * 0.4), velvet)
		for arm in [-1.0, 1.0]:
			_box(Vector3(0.22, 0.65, 0.9), seat + Vector3(arm * 1.2, 0.33, 0.0), velvet)
	_box(Vector3(1.4, 0.06, 0.8), table + Vector3(0.0, 0.45, 0.0), dark_wood)
	for x in [-0.6, 0.6]:
		for z in [-0.32, 0.32]:
			_box(Vector3(0.06, 0.42, 0.06), table + Vector3(x, 0.21, z), gold, false)
	_lamp(table + Vector3(0.3, 0.5, 0.0), 0.9, 5.0)
	# 部屋の四すみの観葉植物
	var pot_material := Psx.material("", Color(0.6, 0.3, 0.18))
	var leaves := Psx.material("ground_forest", Color(0.25, 0.45, 0.2), 1.5, 0.6)
	for corner in [Vector3(-INSIDE.x + 0.6, 0, INSIDE.z - 0.6), Vector3(INSIDE.x - 0.6, 0, INSIDE.z - 0.6),
			Vector3(INSIDE.x - 0.6, 0, -INSIDE.z + 0.6), Vector3(-2.6, 0, -INSIDE.z + 0.6)]:
		var pot := CylinderMesh.new()
		pot.top_radius = 0.28
		pot.bottom_radius = 0.2
		pot.height = 0.5
		CreatureKit.part(self, pot, pot_material, corner + Vector3(0.0, 0.25, 0.0))
		for i in 5:
			var leaf := CreatureKit.sphere(0.28 - i * 0.02)
			var offset := Vector3(cos(i * 1.3) * 0.18, 0.75 + i * 0.22, sin(i * 1.3) * 0.18)
			CreatureKit.part(self, leaf, leaves, corner + offset)


func _lamp(pos: Vector3, energy: float, reach: float) -> void:
	var stand := CylinderMesh.new()
	stand.top_radius = 0.03
	stand.bottom_radius = 0.1
	stand.height = 0.3
	CreatureKit.part(self, stand, Psx.material("", Color(0.75, 0.55, 0.2)), pos + Vector3(0.0, 0.15, 0.0))
	var shade := CylinderMesh.new()
	shade.top_radius = 0.1
	shade.bottom_radius = 0.2
	shade.height = 0.22
	CreatureKit.part(self, shade, CreatureKit.glow(Color(1.0, 0.85, 0.6), 1.2), pos + Vector3(0.0, 0.4, 0.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.45)
	light.light_energy = energy
	light.omni_range = reach
	light.position = pos + Vector3(0.0, 0.4, 0.0)
	add_child(light)


# --- 掲示板：注意書きと、山脈の案内図 ---

func _build_board() -> void:
	var board := Vector3(-INSIDE.x + 0.04, 2.0, -1.2)
	_box(Vector3(0.06, 1.7, 3.2), board, Psx.material("", Color(0.5, 0.36, 0.22)), false)
	var paper := Psx.material("", Color(0.82, 0.76, 0.6))
	var notice := board + Vector3(0.04, 0.0, 0.8)
	_paper(Vector2(1.2, 1.45), notice, PI / 2.0, paper)
	_label(NOTICE, notice + Vector3(0.012, 0.0, 0.0), PI / 2.0, 0.004, Color(0.12, 0.09, 0.07))
	var map := board + Vector3(0.04, 0.1, -0.75)
	_paper(Vector2(1.5, 1.0), map, PI / 2.0, paper)
	var drawing := QuadMesh.new()
	drawing.size = Vector2(1.35, 0.6)
	var picture := CreatureKit.part(self, drawing, _textured(_map_texture(), Color.WHITE), map + Vector3(0.012, 0.05, 0.0))
	picture.rotation.y = PI / 2.0
	_label("霊峰登山道　案内図", map + Vector3(0.012, 0.42, 0.0), PI / 2.0, 0.005, Color(0.12, 0.09, 0.07))
	_label("樹海　岩場　雪山　霊峰", map + Vector3(0.012, -0.36, 0.0), PI / 2.0, 0.0042, Color(0.12, 0.09, 0.07))


func _paper(paper_size: Vector2, pos: Vector3, yaw: float, material: Material) -> void:
	var quad := QuadMesh.new()
	quad.size = paper_size
	var sheet := CreatureKit.part(self, quad, material, pos)
	sheet.rotation.y = yaw


func _label(text: String, pos: Vector3, yaw: float, pixel_size: float, color: Color, glowing := false) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 32
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.shaded = not glowing
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = pos
	label.rotation.y = yaw
	add_child(label)


# --- 玄関の外：バス停と、霊峰行きのバス ---

func _build_outside() -> void:
	var d := INSIDE.z
	# 玄関先の庇（ひさし）と、道路
	_box(Vector3(5.0, 0.4, 3.0), Vector3(0.0, -0.2, d + 1.6), Psx.material("stone", Color(0.6, 0.58, 0.55), 1.5))
	_box(Vector3(5.0, 0.15, 3.0), Vector3(0.0, 3.2, d + 1.6), Psx.material("roof", Color(0.4, 0.3, 0.25), 1.0), false)
	_box(Vector3(30.0, 0.4, 12.0), Vector3(0.0, -0.3, d + 9.0), Psx.material("stone", Color(0.25, 0.25, 0.27), 0.5))
	# バス停の標識
	var sign_post := Vector3(-4.0, 0.0, d + 4.2)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.04
	pole.bottom_radius = 0.04
	pole.height = 2.4
	CreatureKit.part(self, pole, Psx.material("", Color(0.7, 0.7, 0.7)), sign_post + Vector3(0.0, 1.2, 0.0))
	var plate := CylinderMesh.new()
	plate.top_radius = 0.35
	plate.bottom_radius = 0.35
	plate.height = 0.04
	var disc := CreatureKit.part(self, plate, Psx.material("", Color(0.9, 0.9, 0.85)), sign_post + Vector3(0.0, 2.5, 0.0))
	disc.rotation.x = PI / 2.0
	_label("霊峰\n登山口行", sign_post + Vector3(0.0, 2.5, -0.03), PI, 0.0045, Color(0.1, 0.25, 0.6))
	_build_bus(Vector3(1.0, 0.0, d + 6.5))
	# 道の向こうの町並み（ところどころ窓に灯り）
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var wall_material := Psx.material("", Color(0.18, 0.17, 0.2))
	var window_light := CreatureKit.glow(Color(1.0, 0.8, 0.5), 1.5)
	for i in 7:
		var width := rng.randf_range(4.0, 7.0)
		var height := rng.randf_range(6.0, 13.0)
		var x := -18.0 + i * 6.0
		_box(Vector3(width, height, 5.0), Vector3(x, height / 2.0 - 0.3, d + 19.0), wall_material, false)
		for w in 4:
			if rng.randf() < 0.45:
				_box(Vector3(0.6, 0.8, 0.05), Vector3(x + rng.randf_range(-width / 3.0, width / 3.0), rng.randf_range(2.0, height - 1.5), d + 16.47), window_light, false)


## 丸っこいレトロなバス（上がクリーム色、下が緑）。扉は玄関のほうを向いている
func _build_bus(pos: Vector3) -> void:
	var bus := Node3D.new()
	bus.position = pos
	add_child(bus)
	var cream := Psx.material("", Color(0.92, 0.88, 0.74))
	var green := Psx.material("", Color(0.22, 0.48, 0.38))
	var black := CreatureKit.flat(Color(0.03, 0.03, 0.03))
	var window_glass := CreatureKit.glow(Color(0.95, 0.85, 0.55), 0.6)
	_box_in(bus, Vector3(9.0, 1.1, 2.5), Vector3(0.0, 0.95, 0.0), green, true)
	_box_in(bus, Vector3(9.0, 1.3, 2.5), Vector3(0.0, 2.15, 0.0), cream, true)
	var roof := CapsuleMesh.new()
	roof.radius = 1.25
	roof.height = 9.0
	var top := CreatureKit.part(bus, roof, cream, Vector3(0.0, 2.55, 0.0))
	top.rotation.z = PI / 2.0
	top.scale = Vector3(1.0, 1.0, 0.25)
	for i in 6:  # 窓
		_box_in(bus, Vector3(1.1, 0.7, 0.05), Vector3(-3.3 + i * 1.3, 2.2, -1.26), window_glass, false)
	_box_in(bus, Vector3(0.05, 0.8, 2.1), Vector3(4.51, 2.2, 0.0), window_glass, false)  # 前の窓
	_box_in(bus, Vector3(1.0, 2.2, 0.06), Vector3(2.9, 1.5, -1.27), window_glass, false)  # 扉
	for z in [-0.8, 0.8]:  # ヘッドライト
		var lamp := CreatureKit.sphere(0.16)
		CreatureKit.part(bus, lamp, CreatureKit.glow(Color(1.0, 0.95, 0.75), 3.0), Vector3(4.52, 1.0, z))
	for x in [-3.0, 3.0]:
		for z in [-1.2, 1.2]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.5
			wheel.bottom_radius = 0.5
			wheel.height = 0.35
			var tire := CreatureKit.part(bus, wheel, black, Vector3(x, 0.5, z))
			tire.rotation.x = PI / 2.0
	var sign_board := Vector3(4.53, 2.75, 0.0)
	_box_in(bus, Vector3(0.05, 0.35, 1.6), sign_board, CreatureKit.flat(Color(0.05, 0.05, 0.05)), false)
	var destination := Label3D.new()
	destination.text = "霊峰"
	destination.font = FONT
	destination.font_size = 32
	destination.pixel_size = 0.008
	destination.modulate = Color(1.0, 0.6, 0.15)
	destination.shaded = false
	destination.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	destination.position = sign_board + Vector3(0.04, 0.0, 0.0)
	destination.rotation.y = PI / 2.0
	bus.add_child(destination)
	var inside_light := OmniLight3D.new()
	inside_light.light_color = Color(1.0, 0.85, 0.6)
	inside_light.omni_range = 5.0
	inside_light.position = Vector3(2.9, 1.8, -0.5)
	bus.add_child(inside_light)
	_bus_door = bus.to_global(Vector3(2.9, 0.5, -1.8))


# --- 空気中のほこり ---

func _build_dust() -> void:
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(INSIDE.x - 0.5, INSIDE.y / 2.0 - 0.2, INSIDE.z - 0.5)
	motion.gravity = Vector3(0.0, -0.01, 0.0)
	motion.initial_velocity_max = 0.05
	motion.spread = 180.0
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mote_material.albedo_color = Color(1.0, 0.88, 0.7, 0.35)
	var mote := QuadMesh.new()
	mote.size = Vector2(0.015, 0.015)
	mote.material = mote_material
	var dust := GPUParticles3D.new()
	dust.amount = 220
	dust.lifetime = 12.0
	dust.preprocess = 12.0
	dust.process_material = motion
	dust.draw_pass_1 = mote
	dust.position = Vector3(0.0, INSIDE.y / 2.0, 0.0)
	dust.visibility_aabb = AABB(-INSIDE, INSIDE * 2.0)
	add_child(dust)


# --- 模様の画像 ---

## 赤い絨毯。金色のひし形が並ぶ
func _carpet_texture() -> ImageTexture:
	var image := Image.create(96, 72, false, Image.FORMAT_RGB8)
	for y in 72:
		for x in 96:
			var u := absf(fmod(x, 12.0) - 6.0) + absf(fmod(y, 12.0) - 6.0)
			var color := Color(0.42, 0.05, 0.07)
			if u > 5.0 and u < 6.5:
				color = Color(0.75, 0.55, 0.2)
			elif u < 1.5:
				color = Color(0.6, 0.12, 0.1)
			if x < 3 or y < 3 or x > 92 or y > 68:
				color = Color(0.75, 0.55, 0.2)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## クリーム色の縦じまの壁紙
func _wallpaper_texture() -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 16:
			var stripe := x % 8 < 3
			image.set_pixel(x, y, Color(0.72, 0.62, 0.45) if stripe else Color(0.82, 0.75, 0.58))
	return ImageTexture.create_from_image(image)


## 4 つの山が右へ行くほど高くなっていく絵。たき火の場所に赤い点
func _map_texture() -> ImageTexture:
	var image := Image.create(180, 80, false, Image.FORMAT_RGB8)
	image.fill(Color(0.82, 0.76, 0.6))
	var ink := Color(0.25, 0.2, 0.16)
	var peaks := [Vector2(28, 52), Vector2(70, 38), Vector2(112, 24), Vector2(154, 10)]
	for i in peaks.size():
		var peak: Vector2 = peaks[i]
		var half := 26.0 + i * 3.0
		for x in range(int(peak.x - half), int(peak.x + half)):
			var top := peak.y + absf(x - peak.x) / half * (78.0 - peak.y)
			for y in range(int(top), 78):
				if x >= 0 and x < 180:
					image.set_pixel(x, y, ink.lerp(Color(0.55, 0.5, 0.42), clampf((y - top) / 30.0, 0.0, 1.0)))
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				image.set_pixel(int(peak.x) + dx, int(peak.y) - 4 + dy, Color(0.75, 0.1, 0.06))
	return ImageTexture.create_from_image(image)


## scale を渡すと面の向きに合わせて貼り（1 m あたりのくり返し回数）、渡さなければ UV で 1 枚貼る
func _textured(texture: Texture2D, tint: Color, scale := -1.0) -> ShaderMaterial:
	var material := Psx.material("", tint, scale if scale > 0.0 else 1.0)
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("use_uv", scale < 0.0)
	return material


func _box(box_size: Vector3, center: Vector3, material: Material, collide := true) -> MeshInstance3D:
	return _box_in(self, box_size, center, material, collide)


func _box_in(parent: Node3D, box_size: Vector3, center: Vector3, material: Material, collide: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := CreatureKit.part(parent, mesh, material, center)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = box_size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		# 当たり判定は、すべて部屋（このノード）から見た位置に置く
		var parent_transform := Transform3D() if parent == self else parent.transform
		collision.transform = parent_transform * Transform3D(Basis(), center)
		_body.add_child(collision)
	return instance
