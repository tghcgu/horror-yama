class_name Hud
extends Control
## 画面の表示：スタミナ（赤い部分はケガで減った上限）、標高、日没までの時間、照準、アイテム欄、
## 地帯の名前、メッセージ、ダメージや暗転の演出

const SLOT_SIZE := 60.0
const SLOT_GAP := 10.0
const HINT_TIME := 10.0

var player: Player
var day: DayCycle
var summit_height := 100.0
var danger := 0.0

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


static func format_time(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]


func show_message(text: String, seconds: float) -> void:
	_message = text
	_message_time = seconds


## 新しい地帯に入ったときに、その名前を上のほうへ静かに出す
func show_title(text: String) -> void:
	_title = text
	_title_time = 4.0


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
	_hurt_flash = maxf(_hurt_flash - delta * 2.0, 0.0)
	_cold_flash = maxf(_cold_flash - delta * 0.8, 0.0)
	_fade = move_toward(_fade, _fade_target, delta * 2.0)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var font := get_theme_default_font()
	var screen := size
	_draw_danger(screen)
	_draw_crosshair(screen / 2.0)
	_draw_stamina(font, Rect2(40.0, screen.y - 56.0, 340.0, 18.0))
	_draw_status(font, screen)
	_draw_hotbar(font, screen)
	_draw_title(font, screen)

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
	var injury_width := player.injury * per_point
	if injury_width > 0.0:
		draw_rect(Rect2(bar.end.x - injury_width, bar.position.y, injury_width, bar.size.y), Color(0.7, 0.1, 0.1))
	draw_string(font, bar.position + Vector2(0.0, -8.0), "スタミナ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))


func _draw_status(font: Font, screen: Vector2) -> void:
	var altitude := maxf(player.global_position.y, 0.0)
	var altitude_text := "標高 %d m / %d m" % [roundi(altitude), roundi(summit_height)]
	draw_string(font, Vector2(screen.x - 260.0, 44.0), altitude_text, HORIZONTAL_ALIGNMENT_RIGHT, 220.0, 16)
	if day and not day.is_night:
		var left := day.seconds_until_night()
		var color := Color(1.0, 0.85, 0.6, 0.9) if left > 20.0 else Color(1.0, 0.4, 0.3, 0.95)
		draw_string(font, Vector2(0.0, 44.0), "日没まで %s" % format_time(left), HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, color)


## 画面下のアイテム欄。数字キーで使う
func _draw_hotbar(font: Font, screen: Vector2) -> void:
	var total := Items.COUNT * SLOT_SIZE + (Items.COUNT - 1) * SLOT_GAP
	var left := (screen.x - total) / 2.0
	var top := screen.y - SLOT_SIZE - 24.0
	for i in Items.COUNT:
		var slot := Rect2(left + i * (SLOT_SIZE + SLOT_GAP), top, SLOT_SIZE, SLOT_SIZE)
		var count: int = player.items[i] if i < player.items.size() else 0
		var alpha := 1.0 if count > 0 else 0.3
		draw_rect(slot, Color(0.0, 0.0, 0.0, 0.5))
		draw_rect(slot, Color(1, 1, 1, 0.25 * alpha + 0.05), false, 1.0)
		_draw_item_icon(i, slot.get_center(), alpha)
		draw_string(font, slot.position + Vector2(5.0, 15.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))
		if count > 0:
			draw_string(font, slot.position + Vector2(0.0, SLOT_SIZE - 5.0), "×%d" % count,
				HORIZONTAL_ALIGNMENT_RIGHT, SLOT_SIZE - 5.0, 16, Color(1, 1, 1, 0.9))


func _draw_item_icon(kind: int, c: Vector2, alpha: float) -> void:
	match kind:
		Items.Kind.PITON:
			draw_line(c + Vector2(-9.0, 9.0), c + Vector2(11.0, -11.0), Color(0.78, 0.8, 0.84, alpha), 4.0)
			draw_arc(c + Vector2(-12.0, 12.0), 5.0, 0.0, TAU, 16, Color(0.78, 0.8, 0.84, alpha), 2.0)
		Items.Kind.BANDAGE:
			draw_rect(Rect2(c + Vector2(-2.0, 2.0), Vector2(15.0, 8.0)), Color(0.88, 0.86, 0.8, alpha))
			draw_circle(c + Vector2(-3.0, -2.0), 11.0, Color(0.93, 0.9, 0.84, alpha))
			draw_circle(c + Vector2(-3.0, -2.0), 3.5, Color(0.6, 0.58, 0.54, alpha))
		Items.Kind.ONIGIRI:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -14.0), c + Vector2(-14.0, 11.0), c + Vector2(14.0, 11.0)]),
				Color(0.96, 0.96, 0.93, alpha))
			draw_rect(Rect2(c + Vector2(-6.0, 3.0), Vector2(12.0, 8.0)), Color(0.08, 0.12, 0.08, alpha))
		Items.Kind.OFUDA:
			draw_rect(Rect2(c + Vector2(-7.0, -15.0), Vector2(14.0, 30.0)), Color(0.93, 0.88, 0.74, alpha))
			for y in [-9.0, 0.0, 9.0]:
				draw_line(c + Vector2(-4.0, y), c + Vector2(4.0, y), Color(0.75, 0.08, 0.05, alpha), 2.0)


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
