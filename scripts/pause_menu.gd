class_name PauseMenu
extends CanvasLayer
## Esc で開くメニュー。ゲームを止めて、設定の変更・やり直し・終了ができる。

signal restart_requested

const ACCENT := Color(0.85, 0.5, 0.2)
const TEXT := Color(0.9, 0.88, 0.85)
const CONTROLS := [
	["WASD", "移動"],
	["Shift", "ダッシュ"],
	["Space", "ジャンプ／登りながら飛びつく"],
	["右クリック長押し", "壁をつかむ（手ぶらなら左クリックでも）"],
	["1〜6・ホイール", "アイテムを手に持つ（同じ数字でしまう）"],
	["左クリック", "手に持ったアイテムを使う（ナタは押しっぱなしで振り続ける）"],
	["Q（長押しでためる）", "選んだアイテムを投げる（ためるほど強く。当たると傷を負わせる）"],
	["E", "拾う・調べる"],
	["T（長押し）", "エモート"],
	["G（長押し）", "手を差し伸べて引き上げる"],
	["F", "ヘッドライト"],
	["R", "最初から"],
	["F1", "空を飛ぶ（テスト用）"],
	["F2", "仲間のダミーを呼ぶ（テスト用）"],
]

var _root: Control
var _resume_button: Button
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	_root.visible = false


func is_open() -> bool:
	return _open


func open() -> void:
	InputSetup.release_all()  # 押しっぱなしになってしまった入力は、ここで解ける
	_open = true
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume_button.grab_focus()


func close() -> void:
	InputSetup.release_all()
	_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Settings.save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	margin.add_child(columns)

	# 左：メニューと設定
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420.0, 0.0)
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	left.add_child(_label("一時停止", 32))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	left.add_child(buttons)
	_resume_button = _button(buttons, "ゲームに戻る", close)
	_button(buttons, "やり直す", _on_restart_pressed)
	_button(buttons, "ゲームを終了", _on_quit_pressed)
	left.add_child(HSeparator.new())
	left.add_child(_heading("設定"))
	_slider(left, "マウス感度", 0.2, 3.0, 0.05, Settings.mouse_sensitivity, "%.2f",
		func(v: float) -> void: Settings.mouse_sensitivity = v)
	_slider(left, "視野角", 60.0, 110.0, 1.0, Settings.fov, "%d°",
		func(v: float) -> void: Settings.fov = v)
	_slider(left, "明るさ", 0.5, 2.0, 0.05, Settings.brightness, "%.2f",
		func(v: float) -> void: Settings.brightness = v)
	_choice(left, "画面の粗さ", Settings.RETRO_NAMES, Settings.retro,
		func(v: int) -> void: Settings.retro = v)
	_choice(left, "描画の細かさ", Settings.DETAIL_NAMES, Settings.detail,
		func(v: int) -> void: Settings.detail = v)
	var fullscreen := CheckButton.new()
	fullscreen.text = "フルスクリーン"
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.toggled.connect(_on_fullscreen_toggled)
	left.add_child(fullscreen)
	left.add_child(_heading("音量"))
	for entry: Array in Settings.VOLUMES:
		var key: String = entry[0]
		_slider(left, entry[2], 0.0, 1.0, 0.01, Settings.get(key), "%.0f%%",
			func(v: float) -> void: Settings.set(key, v), 100.0)

	# 右：操作方法
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	right.add_child(_heading("操作方法"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	right.add_child(grid)
	for row: Array in CONTROLS:
		var key := _label(row[0], 16)
		key.add_theme_color_override("font_color", ACCENT)
		grid.add_child(key)
		grid.add_child(_label(row[1], 16))


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


## 見出し（アクセントの色）
func _heading(text: String) -> Label:
	var label := _label(text, 16)
	label.add_theme_color_override("font_color", ACCENT)
	return label


## いくつかの段階から選ぶスライダー（「なし・弱・標準・強」など）
func _choice(parent: Control, text: String, names: Array, value: int, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var title := _label(text, 16)
	title.custom_minimum_size = Vector2(110.0, 0.0)
	row.add_child(title)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = names.size() - 1
	slider.step = 1
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var shown := _label(names[value], 16)
	shown.custom_minimum_size = Vector2(56.0, 0.0)
	row.add_child(shown)
	slider.value_changed.connect(_on_choice_changed.bind(setter, shown, names))


func _on_choice_changed(value: float, setter: Callable, shown: Label, names: Array) -> void:
	setter.call(int(value))
	Settings.apply()
	shown.text = names[int(value)]


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## 見出し・スライダー・現在値を1行に並べる。display_scale は表示用の倍率（音量を % で見せるため）
func _slider(parent: Control, text: String, min_value: float, max_value: float, step: float,
		value: float, format: String, setter: Callable, display_scale := 1.0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var title := _label(text, 16)
	title.custom_minimum_size = Vector2(110.0, 0.0)
	row.add_child(title)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var shown := _label(format % (value * display_scale), 16)
	shown.custom_minimum_size = Vector2(56.0, 0.0)
	row.add_child(shown)
	slider.value_changed.connect(_on_slider_changed.bind(setter, shown, format, display_scale))


func _on_slider_changed(value: float, setter: Callable, shown: Label, format: String, display_scale: float) -> void:
	setter.call(value)
	Settings.apply()
	shown.text = format % (value * display_scale)


func _on_fullscreen_toggled(on: bool) -> void:
	Settings.fullscreen = on
	Settings.apply()


func _on_restart_pressed() -> void:
	close()
	restart_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_stylebox("panel", "PanelContainer", _box(Color(0.06, 0.06, 0.07, 0.95), Color(0.25, 0.23, 0.22), 1))
	theme.set_stylebox("normal", "Button", _box(Color(0.12, 0.12, 0.13), Color(0.28, 0.27, 0.26), 1))
	theme.set_stylebox("hover", "Button", _box(Color(0.2, 0.15, 0.11), ACCENT, 1))
	theme.set_stylebox("pressed", "Button", _box(Color(0.3, 0.18, 0.1), ACCENT, 1))
	theme.set_stylebox("focus", "Button", _box(Color(0.0, 0.0, 0.0, 0.0), ACCENT, 2))
	return theme


func _box(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(4)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	return box
