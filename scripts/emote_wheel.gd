class_name EmoteWheel
extends CanvasLayer
## エモートの輪。T を押している間だけ画面の真ん中に出て、マウスを動かした方向のエモートを選び、
## T を離すとそのエモートをする。開いている間は、マウスで視点が動かない。

const RADIUS := 150.0
const DEAD_ZONE := 30.0  # これより少ししか動かしていなければ、何も選ばない

var player: Player

var _canvas: Control
var _open := false
var _pointer := Vector2.ZERO
var _selected := -1


func _ready() -> void:
	layer = 8
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_wheel)
	add_child(_canvas)
	_canvas.visible = false


func is_open() -> bool:
	return _open


func _process(_delta: float) -> void:
	if player == null:
		return
	var holding := Input.is_action_pressed("emote") and not player.frozen and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if holding and not _open:
		_open = true
		_pointer = Vector2.ZERO
		_selected = -1
		_canvas.visible = true
	elif not holding and _open:
		_open = false
		_canvas.visible = false
		if _selected >= 0:
			player.play_emote(Player.EMOTES[_selected])
	if _open:
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_pointer = (_pointer + motion.relative).limit_length(RADIUS)
		if _pointer.length() > DEAD_ZONE:
			var count := Player.EMOTES.size()
			var angle := fposmod(_pointer.angle() + PI / 2.0 + PI / count, TAU)  # 真上が 0 番
			_selected = int(angle / TAU * count) % count
		else:
			_selected = -1
		get_viewport().set_input_as_handled()  # 視点を動かさない


func _draw_wheel() -> void:
	var center := _canvas.size / 2.0
	var font := _canvas.get_theme_default_font()
	var count := Player.EMOTES.size()
	_canvas.draw_circle(center, RADIUS + 30.0, Color(0.0, 0.0, 0.0, 0.45))
	for i in count:
		var angle := -PI / 2.0 + i * TAU / count
		var at := center + Vector2(cos(angle), sin(angle)) * RADIUS
		var chosen := i == _selected
		_canvas.draw_circle(at, 34.0, Color(0.85, 0.5, 0.2, 0.9) if chosen else Color(0.1, 0.1, 0.12, 0.85))
		_canvas.draw_string(font, at + Vector2(-60.0, 6.0), Player.EMOTE_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, 120.0, 16,
			Color.WHITE if chosen else Color(1, 1, 1, 0.75))
	_canvas.draw_circle(center + _pointer * 0.5, 6.0, Color(1, 1, 1, 0.8))
