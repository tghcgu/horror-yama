class_name AppearanceMenu
extends CanvasLayer
## 鏡の前で E を押すと開く、身だしなみの画面。帽子（とミトン）・上着・マフラーの色を選ぶ。
## 画面の左に出すので、選びながら鏡に映った自分を確かめられる。開け閉めは Main が決める（E か Esc で閉じる）。

signal closed

const ACCENT := Color(0.85, 0.5, 0.2)
const SWATCH := 38.0

var _root: Control
var _swatches := {}  # 部分の名前 → その部分の色ボタンの一覧
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
	panel.position = Vector2(40.0, 110.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.06, 0.07, 0.9)
	box.border_color = Color(0.3, 0.27, 0.24)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(22.0)
	panel.add_theme_stylebox_override("panel", box)
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_label("身だしなみ", 32, Color(0.95, 0.92, 0.88)))
	for i in Appearance.PARTS.size():
		var part: String = Appearance.PARTS[i]
		column.add_child(_label(Appearance.PART_NAMES[i], 16, ACCENT))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		column.add_child(grid)
		var buttons: Array[Button] = []
		for c in Appearance.COLORS.size():
			var swatch := Button.new()
			swatch.custom_minimum_size = Vector2(SWATCH, SWATCH)
			swatch.tooltip_text = Appearance.NAMES[c]
			swatch.focus_mode = Control.FOCUS_NONE
			swatch.pressed.connect(_choose.bind(part, c))
			grid.add_child(swatch)
			buttons.append(swatch)
		_swatches[part] = buttons
	column.add_child(_label("E か Esc で閉じる", 16, Color(1, 1, 1, 0.5)))


func _choose(part: String, index: int) -> void:
	Settings.set(part + "_color", index)
	Settings.apply()
	_refresh()


## 色見本の見た目を塗り直す。選んでいる色は白いふちで囲む
func _refresh() -> void:
	for part: String in _swatches:
		var chosen: int = Settings.get(part + "_color")
		var buttons: Array = _swatches[part]
		for c in buttons.size():
			var style := StyleBoxFlat.new()
			style.bg_color = Appearance.COLORS[c]
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
