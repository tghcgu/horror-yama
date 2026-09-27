extends Node
## 設定（マウス感度・視野角・明るさ・音量・画面の粗さ・フルスクリーン）。user://settings.cfg に保存する。
## （画面の文字は project.godot の gui/theme/custom_font で、ドット文字 DotGothic16 にしている）

signal changed

const PATH := "user://settings.cfg"
const SECTION := "settings"
const RETRO_NAMES := ["なし", "弱", "標準", "強"]
const RETRO_RESOLUTIONS := [0, 360, 240, 180]  # 画面の縦の画素数（0 = 加工なし）
const DETAIL_NAMES := ["軽い", "ふつう", "きれい"]
const DETAIL_HEIGHTS := [480, 640, 0]  # 画面の粗さが「なし」のとき、3D を描く縦の画素数（0 = 画面そのまま。FSR で引き伸ばす）
## 音量の項目：設定の名前、音の通り道（バス。AudioSetup が用意する）、メニューでの名前
const VOLUMES := [
	["volume", &"Master", "全体"],
	["volume_monsters", &"Monsters", "化け物"],
	["volume_animals", &"Animals", "動物"],
	["volume_world", &"World", "自然・仕掛け"],
	["volume_self", &"Self", "自分・道具"],
]

var mouse_sensitivity := 1.0  # 倍率
var fov := 80.0
var brightness := 1.0         # 画面の明るさ（露出の倍率）
var volume := 0.8             # 全体の音量 0〜1
var volume_monsters := 1.0    # 項目ごとの音量 0〜1（VOLUMES）
var volume_animals := 1.0
var volume_world := 1.0
var volume_self := 1.0
var retro := 2                # 画面の粗さ（RETRO_NAMES の番号）
var detail := 1               # 描画の細かさ（DETAIL_NAMES の番号）
var hat_color := 0            # 見た目の色（Appearance.COLORS の番号）
var jacket_color := 1
var scarf_color := 3
var hair_color := 1           # Appearance.HAIR_COLORS の番号
var skin_tone := 1            # Appearance.SKIN_TONES の番号
var hat_style := 0            # 形（Appearance.STYLES の番号）
var hair_style := 0
var top_style := 0
var neck_style := 0
var face_style := 0
var fullscreen := false


func _ready() -> void:
	_load()
	apply()


## 見た目の設定の名前（色と形）
func _look_keys() -> Array[String]:
	var keys: Array[String] = ["hair_color", "skin_tone"]
	for part in Appearance.PARTS:
		keys.append(part + "_color")
	for part in Appearance.STYLE_PARTS:
		keys.append(part + "_style")
	return keys


func retro_resolution() -> int:
	return RETRO_RESOLUTIONS[clampi(retro, 0, RETRO_RESOLUTIONS.size() - 1)]


## 3D を描く縦の画素数（画面の粗さが「なし」のとき。0 = 画面そのまま）
func detail_height() -> int:
	return DETAIL_HEIGHTS[clampi(detail, 0, DETAIL_HEIGHTS.size() - 1)]


func apply() -> void:
	for entry: Array in VOLUMES:
		var index := AudioServer.get_bus_index(entry[1])
		if index != -1:
			var level: float = get(entry[0])
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
			AudioServer.set_bus_mute(index, level <= 0.001)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	changed.emit()


var persist := true  # false なら保存しない（自動テスト中）


func save() -> void:
	if not persist:
		return
	var config := ConfigFile.new()
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "fov", fov)
	config.set_value(SECTION, "brightness", brightness)
	for entry: Array in VOLUMES:
		config.set_value(SECTION, entry[0], get(entry[0]))
	config.set_value(SECTION, "retro", retro)
	config.set_value(SECTION, "detail", detail)
	for key in _look_keys():
		config.set_value(SECTION, key, get(key))
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.save(PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	mouse_sensitivity = config.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	fov = config.get_value(SECTION, "fov", fov)
	brightness = config.get_value(SECTION, "brightness", brightness)
	for entry: Array in VOLUMES:
		set(entry[0], config.get_value(SECTION, entry[0], get(entry[0])))
	retro = config.get_value(SECTION, "retro", retro)
	detail = config.get_value(SECTION, "detail", detail)
	for key in _look_keys():
		set(key, config.get_value(SECTION, key, get(key)))
	fullscreen = config.get_value(SECTION, "fullscreen", fullscreen)
