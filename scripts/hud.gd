class_name Hud
extends Control
## 画面の表示：スタミナ（赤い部分はケガで減った上限）、標高、日没までの時間、照準、アイテム欄、
## 地帯の名前、メッセージ、ダメージや暗転の演出

const SLOT_SIZE := 60.0
const SLOT_GAP := 10.0
const HINT_TIME := 10.0
const INJURY_COLOR := Color(0.7, 0.1, 0.1)
const HUNGER_COLOR := Color(0.72, 0.42, 0.12)
const COLD_COLOR := Color(0.35, 0.55, 0.9)
const NOTICE_TIME := 2.5
const EFFECT_NAMES := {
	"warmer": "ぽかぽか", "chalk": "チョーク", "crampons": "アイゼン", "compass": "方位磁石",
	"poison": "毒", "vision": "幻覚", "spores": "胞子",
}

var player: Player
var day: DayCycle
var summit_height := 100.0
var danger := 0.0
var in_lobby := false  # ホテルのロビーにいる（時間が止まっている）
var mirror_hint := false  # 鏡の前にいる（身だしなみを整えられる）

var _message := ""
var _message_time := 0.0
var _title := ""
var _title_time := 0.0
var _hint_time := 0.0
var _hurt_flash := 0.0
var _cold_flash := 0.0
var _fade := 0.0
var _fade_target := 0.0
var _time := 0.0
var _notice := ""
var _notice_time := 0.0
var _icons: ItemIcons


func _ready() -> void:
	_icons = ItemIcons.new()
	add_child(_icons)


static func format_time(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]


func clear_message() -> void:
	_message_time = 0.0
	_title_time = 0.0


func show_message(text: String, seconds: float) -> void:
	_message = text
	_message_time = seconds


## 新しい地帯に入ったときに、その名前を上のほうへ静かに出す
func show_title(text: String) -> void:
	_title = text
	_title_time = 4.0


## アイテム欄の上に、小さく知らせる（「持ち物がいっぱい」など）
func show_notice(text: String) -> void:
	_notice = text
	_notice_time = NOTICE_TIME


func show_hint() -> void:
	_hint_time = HINT_TIME


func flash_hurt() -> void:
	_hurt_flash = 1.0


func flash_cold() -> void:
	_cold_flash = 1.0


func set_blackout(on: bool) -> void:
	_fade_target = 1.0 if on else 0.0


func _process(delta: float) -> void:
	_time += delta
	_message_time = maxf(_message_time - delta, 0.0)
	_title_time = maxf(_title_time - delta, 0.0)
	_hint_time = maxf(_hint_time - delta, 0.0)
	_notice_time = maxf(_notice_time - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 2.0, 0.0)
	_cold_flash = maxf(_cold_flash - delta * 0.8, 0.0)
	_fade = move_toward(_fade, _fade_target, delta * 2.0)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var font := get_theme_default_font()
	var screen := size
	_draw_conditions(screen)
	_draw_danger(screen)
	_draw_crosshair(screen / 2.0)
	_draw_stamina(font, Rect2(40.0, screen.y - 56.0, 340.0, 18.0))
	_draw_status(font, screen)
	if not in_lobby:
		_draw_hotbar(font, screen)
		_draw_effects(font, screen)
		_draw_compass(font, screen)
	_draw_title(font, screen)
	var hint := player.aim_hint()
	if hint != "":
		draw_string(font, Vector2(0.0, screen.y * 0.5 + 40.0), hint, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, Color(1, 1, 1, 0.85))
	if player.flying:
		draw_string(font, Vector2(0.0, 76.0), "飛行モード（テスト用）　F1 でやめる　Space 上昇・Ctrl 下降・Shift 速く",
			HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, Color(0.6, 0.9, 1.0, 0.85))
	if player.held_by:
		draw_string(font, Vector2(0.0, screen.y * 0.5 + 64.0), "Space を連打して振りほどく", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16,
			Color(1.0, 0.6, 0.5, 0.6 + 0.3 * sin(_time * 10.0)))
	if _notice_time > 0.0:
		draw_string(font, Vector2(0.0, screen.y - SLOT_SIZE - 110.0), _notice, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16,
			Color(1.0, 0.95, 0.85, clampf(_notice_time, 0.0, 1.0)))

	if player.clipped:
		draw_string(font, Vector2(0.0, screen.y - 104.0), "ハーケンで休憩中　（動くと外れる）",
			HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, Color(1, 1, 1, 0.75))
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		draw_string(font, Vector2(0.0, screen.y * 0.5 + 60.0), "クリックで操作開始", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16)
	if _hint_time > 0.0:
		draw_string(font, Vector2(24.0, 36.0), "Esc：メニュー・操作方法", HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(1, 1, 1, 0.6 * clampf(_hint_time, 0.0, 1.0)))

	if _hurt_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.6, 0.0, 0.0, 0.35 * _hurt_flash))
	if _cold_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.75, 0.85, 1.0, 0.5 * _cold_flash))
	if _fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, _fade))
	if _message_time > 0.0:
		var color := Color(1, 1, 1, clampf(_message_time, 0.0, 1.0))
		draw_string(font, Vector2(0.0, screen.y * 0.3), _message, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 32, color)


## “何か”が近いほど、画面のふちが赤黒く脈打つ
func _draw_danger(screen: Vector2) -> void:
	if danger <= 0.0:
		return
	const BANDS := 14
	var pulse := 0.75 + 0.25 * sin(_time * lerpf(6.0, 14.0, danger))
	for i in BANDS:
		var inset := Vector2.ONE * (i * 8.0)
		var alpha := danger * 0.55 * pulse * (1.0 - float(i) / BANDS)
		draw_rect(Rect2(inset, screen - inset * 2.0), Color(0.25, 0.0, 0.0, alpha), false, 8.0)


func _draw_crosshair(center: Vector2) -> void:
	if player.can_grab:
		draw_arc(center, 10.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
	else:
		draw_circle(center, 2.5, Color(1, 1, 1, 0.7))


func _draw_stamina(font: Font, bar: Rect2) -> void:
	draw_rect(bar.grow(3.0), Color(0.0, 0.0, 0.0, 0.55))
	var per_point := bar.size.x / Player.MAX_STAMINA
	var color := Color(0.95, 0.78, 0.25)
	if player.exhausted:
		color = Color(0.5, 0.5, 0.5)
	elif player.stamina < 25.0 and int(_time * 6.0) % 2 == 0:
		color = Color(1.0, 0.4, 0.2)
	elif player.boost_time > 0.0:
		color = Color(0.7, 0.95, 0.45)  # おにぎりの効果中
	draw_rect(Rect2(bar.position, Vector2(player.stamina * per_point, bar.size.y)), color)
	# 右端から、上限を削っている不調を積んでいく（PEAK と同じ見せ方）
	var right := bar.end.x
	for affliction: Array in [[player.injury, "ケガ", INJURY_COLOR], [player.hunger, "空腹", HUNGER_COLOR], [player.cold, "寒さ", COLD_COLOR]]:
		var width: float = affliction[0] * per_point
		if width <= 0.5:
			continue
		right -= width
		draw_rect(Rect2(right, bar.position.y, width, bar.size.y), affliction[2])
		if width > 34.0:
			draw_string(font, Vector2(right, bar.end.y + 18.0), affliction[1], HORIZONTAL_ALIGNMENT_CENTER, width, 16, affliction[2].lightened(0.3))
	draw_string(font, bar.position + Vector2(0.0, -8.0), "スタミナ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))


func _draw_status(font: Font, screen: Vector2) -> void:
	if in_lobby:
		draw_string(font, Vector2(0.0, 44.0), "玄関の外のバスに乗ると、山へ出発する", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, Color(1, 1, 1, 0.55))
		if mirror_hint:
			draw_string(font, Vector2(0.0, screen.y * 0.5 + 90.0), "E：身だしなみ", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, Color(1, 1, 1, 0.85))
		return
	var altitude := maxf(player.global_position.y, 0.0)
	var altitude_text := "標高 %d m / %d m" % [roundi(altitude), roundi(summit_height)]
	draw_string(font, Vector2(screen.x - 260.0, 44.0), altitude_text, HORIZONTAL_ALIGNMENT_RIGHT, 220.0, 16)
	if day == null:
		return
	if day.is_night:
		draw_string(font, Vector2(0.0, 44.0), "夜明けまで %s" % format_time(day.seconds_until_dawn()),
			HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, Color(0.65, 0.72, 1.0, 0.85))
	else:
		var left := day.seconds_until_night()
		var color := Color(1.0, 0.85, 0.6, 0.9) if left > 30.0 else Color(1.0, 0.4, 0.3, 0.95)
		draw_string(font, Vector2(0.0, 44.0), "日没まで %s" % format_time(left), HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, color)


## 画面下のアイテム欄。数字キーやホイールで選び、右クリックで使う。選んでいるアイテムの名前と使い方も出す
func _draw_hotbar(font: Font, screen: Vector2) -> void:
	var inventory := player.inventory
	var total := Items.SLOTS * SLOT_SIZE + (Items.SLOTS - 1) * SLOT_GAP
	var left := (screen.x - total) / 2.0
	var top := screen.y - SLOT_SIZE - 24.0
	for i in Items.SLOTS:
		var chosen := i == inventory.selected
		var slot := Rect2(left + i * (SLOT_SIZE + SLOT_GAP), top - (6.0 if chosen else 0.0), SLOT_SIZE, SLOT_SIZE)
		var kind := inventory.kinds[i]
		draw_rect(slot, Color(0.0, 0.0, 0.0, 0.6 if chosen else 0.45))
		draw_rect(slot, Color(1.0, 0.85, 0.5, 0.95) if chosen else Color(1, 1, 1, 0.25), false, 2.0 if chosen else 1.0)
		if kind >= 0 and _icons:
			var icon := _icons.icon(kind)
			if icon:
				draw_texture_rect(icon, slot.grow(-4.0), false)
		draw_string(font, slot.position + Vector2(5.0, 15.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))
		if kind >= 0 and inventory.counts[i] > 1:
			draw_string(font, slot.position + Vector2(0.0, SLOT_SIZE - 5.0), "×%d" % inventory.counts[i],
				HORIZONTAL_ALIGNMENT_RIGHT, SLOT_SIZE - 5.0, 16, Color(1, 1, 1, 0.9))
	var kind := inventory.selected_kind()
	if kind >= 0:
		var name_color := Color(1.0, 0.9, 0.7, 0.9)
		draw_string(font, Vector2(0.0, top - 34.0), Items.NAMES[kind], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, name_color)
		draw_string(font, Vector2(0.0, top - 14.0), Items.DESCRIPTIONS[kind], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, Color(1, 1, 1, 0.55))


## 効いているアイテムや状態（スタミナの上に並べる）
func _draw_effects(font: Font, screen: Vector2) -> void:
	var lines: Array[String] = []
	if player.boost_time > 0.0:
		lines.append("元気　%d" % ceili(player.boost_time))
	for effect: String in EFFECT_NAMES:
		if player.has_effect(effect):
			lines.append("%s　%d" % [EFFECT_NAMES[effect], ceili(player.effects[effect])])
	if player.bell_ringing:
		lines.append("鈴を鳴らしている")
	for i in lines.size():
		draw_string(font, Vector2(40.0, screen.y - 96.0 - i * 22.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.75))


## 方位磁石：次のたき火の方角と距離
func _draw_compass(font: Font, screen: Vector2) -> void:
	if not player.has_effect("compass") or not player.compass_target.is_finite():
		return
	var camera := player.get_camera()
	var to := player.compass_target - camera.global_position
	var forward := -camera.global_transform.basis.z
	var angle := atan2(forward.x, -forward.z) - atan2(to.x, -to.z)
	var center := Vector2(screen.x / 2.0, 100.0)
	draw_circle(center, 22.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_arc(center, 22.0, 0.0, TAU, 32, Color(0.9, 0.75, 0.4, 0.8), 2.0)
	var tip := center + Vector2(sin(-angle), -cos(-angle)) * 18.0
	var side := Vector2(cos(-angle), sin(-angle)) * 6.0
	draw_colored_polygon(PackedVector2Array([tip, center + side, center - side]), Color(0.9, 0.15, 0.1))
	draw_string(font, center + Vector2(-60.0, 44.0), "たき火まで %d m" % roundi(Vector2(to.x, to.z).length()),
		HORIZONTAL_ALIGNMENT_CENTER, 120.0, 16, Color(1, 1, 1, 0.8))


## 毒・幻覚・胞子・沼で、画面の色が変わる
func _draw_conditions(screen: Vector2) -> void:
	if player.has_effect("vision"):
		var hue := fmod(_time * 0.15, 1.0)
		draw_rect(Rect2(Vector2.ZERO, screen), Color.from_hsv(hue, 0.7, 0.8, 0.14))
	if player.has_effect("spores"):
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.7, 0.75, 0.3, 0.18 + 0.05 * sin(_time * 3.0)))
	if player.has_effect("poison"):
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.2, 0.5, 0.1, 0.12 + 0.06 * sin(_time * 5.0)))
	if player.sink > 0.0:
		var depth := clampf(player.sink / Player.SINK_DEADLY, 0.0, 1.0)
		draw_rect(Rect2(0.0, screen.y * (1.0 - depth), screen.x, screen.y * depth), Color(0.12, 0.1, 0.05, 0.85))


func _draw_title(font: Font, screen: Vector2) -> void:
	if _title_time <= 0.0:
		return
	var alpha := minf(clampf((4.0 - _title_time) / 0.8, 0.0, 1.0), clampf(_title_time / 1.2, 0.0, 1.0))
	var spaced := "　".join(_title.split(""))
	var y := screen.y * 0.24
	var width := font.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var color := Color(1, 1, 1, 0.85 * alpha)
	draw_string(font, Vector2(0.0, y), spaced, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 32, color)
	var mid := screen.x / 2.0
	var line_y := y - 10.0
	draw_line(Vector2(mid - width / 2.0 - 120.0, line_y), Vector2(mid - width / 2.0 - 24.0, line_y), Color(1, 1, 1, 0.5 * alpha), 1.0)
	draw_line(Vector2(mid + width / 2.0 + 24.0, line_y), Vector2(mid + width / 2.0 + 120.0, line_y), Color(1, 1, 1, 0.5 * alpha), 1.0)
