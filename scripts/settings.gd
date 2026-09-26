extends Node
## 設定（マウス感度・視野角・明るさ・音量・画面の粗さ・フルスクリーン）。user://settings.cfg に保存する。
## （画面の文字は project.godot の gui/theme/custom_font で、ドット文字 DotGothic16 にしている）

signal changed

const PATH := "user://settings.cfg"
const SECTION := "settings"
const RETRO_NAMES := ["なし", "弱", "標準", "強"]
const RETRO_RESOLUTIONS := [0, 360, 240, 180]  # 画面の縦の画素数（0 = 加工なし）

var mouse_sensitivity := 1.0  # 倍率
var fov := 80.0
var brightness := 1.0         # 画面の明るさ（露出の倍率）
var volume := 0.8             # 0〜1
var retro := 2                # 画面の粗さ（RETRO_NAMES の番号）
var hat_color := 0            # 見た目の色（Appearance.COLORS の番号）
var jacket_color := 1
var scarf_color := 3
var fullscreen := false


func _ready() -> void:
	_load()
	apply()


func retro_resolution() -> int:
	return RETRO_RESOLUTIONS[clampi(retro, 0, RETRO_RESOLUTIONS.size() - 1)]


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	changed.emit()


func save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "fov", fov)
	config.set_value(SECTION, "brightness", brightness)
	config.set_value(SECTION, "volume", volume)
	config.set_value(SECTION, "retro", retro)
	for part in Appearance.PARTS:
		config.set_value(SECTION, part + "_color", get(part + "_color"))
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.save(PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	mouse_sensitivity = config.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	fov = config.get_value(SECTION, "fov", fov)
	brightness = config.get_value(SECTION, "brightness", brightness)
	volume = config.get_value(SECTION, "volume", volume)
	retro = config.get_value(SECTION, "retro", retro)
	for part in Appearance.PARTS:
		set(part + "_color", config.get_value(SECTION, part + "_color", get(part + "_color")))
	fullscreen = config.get_value(SECTION, "fullscreen", fullscreen)
