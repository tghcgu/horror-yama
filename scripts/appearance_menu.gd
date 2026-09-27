class_name AppearanceMenu
extends CanvasLayer
## 鏡の前で E を押すと開く、身だしなみの画面。帽子・髪・上着・首まわり・表情の形（◀ ▶ で切り替え）と、
## 帽子とミトン・上着・首まわり・髪・肌の色を選ぶ。
## 画面の左に出すので、選びながら鏡に映った自分を確かめられる。開け閉めは Main が決める（E か Esc で閉じる）。

signal closed

const ACCENT := Color(0.85, 0.5, 0.2)
const SWATCH := 26.0

var _root: Control
var _style_labels := {}  # 部分 → いま選んでいる形の名前を出すラベル
var _swatches := {}      # 色の設定の名前 → [色見本のボタン, ...]
var _open := false


func _ready() -> void:
	layer = 9
	_build()
	_root.visible = false


func is_open() -> bool:
	return _open


func open() -> void:
	_open = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Settings.save()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()  # 一時停止メニューを開かないように


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := PanelContainer.new()
	panel.position = Vector2(40.0, 70.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.06, 0.07, 0.9)
	box.border_color = Color(0.3, 0.27, 0.24)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", box)
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.add_child(_label("身だしなみ", 28, Color(0.95, 0.92, 0.88)))

	# 形：◀ 名前 ▶
	for i in Appearance.STYLE_PARTS.size():
		var part: String = Appearance.STYLE_PARTS[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		var title := _label(Appearance.STYLE_TITLES[i], 16, ACCENT)
		title.custom_minimum_size = Vector2(90.0, 0.0)
		row.add_child(title)
		row.add_child(_arrow("◀", _step_style.bind(part, -1)))
		var shown := _label("", 16, Color(0.95, 0.92, 0.88))
		shown.custom_minimum_size = Vector2(130.0, 0.0)
		shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(shown)
		_style_labels[part] = shown
		row.add_child(_arrow("▶", _step_style.bind(part, 1)))

	column.add_child(HSeparator.new())
	# 色
	for i in Appearance.PARTS.size():
		_color_row(column, Appearance.PART_NAMES[i], Appearance.PARTS[i] + "_color", Appearance.COLORS)
	_color_row(column, "髪の色", "hair_color", Appearance.HAIR_COLORS)
	_color_row(column, "肌の色", "skin_tone", Appearance.SKIN_TONES)
	column.add_child(_label("E か Esc で閉じる", 16, Color(1, 1, 1, 0.5)))


func _color_row(column: VBoxContainer, title: String, key: String, colors: Array) -> void:
	column.add_child(_label(title, 16, ACCENT))
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 4)
	column.add_child(grid)
	var buttons: Array[Button] = []
	for c in colors.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(SWATCH, SWATCH)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.pressed.connect(_choose.bind(key, c))
		grid.add_child(swatch)
		buttons.append(swatch)
	_swatches[key] = [buttons, colors]


func _arrow(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(34.0, 30.0)
	button.pressed.connect(action)
	return button


func _step_style(part: String, step: int) -> void:
	var count: int = (Appearance.STYLES[part] as Array).size()
	Settings.set(part + "_style", posmod(int(Settings.get(part + "_style")) + step, count))
	Settings.apply()
	_refresh()


func _choose(key: String, index: int) -> void:
	Settings.set(key, index)
	Settings.apply()
	_refresh()


## 形の名前と、色見本の見た目を塗り直す。選んでいる色は白いふちで囲む
func _refresh() -> void:
	for part: String in _style_labels:
		var list: Array = Appearance.STYLES[part]
		var index := clampi(int(Settings.get(part + "_style")), 0, list.size() - 1)
		(_style_labels[part] as Label).text = list[index][1]
	for key: String in _swatches:
		var chosen: int = Settings.get(key)
		var buttons: Array = _swatches[key][0]
		var colors: Array = _swatches[key][1]
		for c in buttons.size():
			var style := StyleBoxFlat.new()
			style.bg_color = colors[c]
			style.set_corner_radius_all(3)
			if c == chosen:
				style.border_color = Color.WHITE
				style.set_border_width_all(3)
			var hover := style.duplicate() as StyleBoxFlat
			hover.border_color = Color(1, 1, 1, 0.7) if c != chosen else Color.WHITE
			hover.set_border_width_all(3)
			var button: Button = buttons[c]
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", hover)
			button.add_theme_stylebox_override("pressed", style)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
