class_name Appearance
extends RefCounted
## プレイヤーの見た目。鏡の前で、帽子・髪・上着・首まわり・表情の形と、
## 帽子（とミトン）・上着・首まわり・髪・肌の色を選べる。選んだものは Settings に保存する。
## モデル（climber.glb）は部分ごとに別の形になっていて、名前の頭（Hat_ など）で種類がわかる

const COLORS := [
	Color(0.86, 0.22, 0.22), Color(0.96, 0.52, 0.16), Color(0.96, 0.8, 0.28), Color(0.4, 0.72, 0.36),
	Color(0.22, 0.66, 0.66), Color(0.28, 0.46, 0.86), Color(0.58, 0.38, 0.82), Color(0.96, 0.58, 0.72),
	Color(0.92, 0.92, 0.88), Color(0.24, 0.24, 0.27),
]
const NAMES := ["赤", "オレンジ", "黄", "緑", "青緑", "青", "むらさき", "ピンク", "白", "黒"]
const HAIR_COLORS := [
	Color(0.08, 0.07, 0.07), Color(0.25, 0.15, 0.08), Color(0.45, 0.28, 0.14), Color(0.62, 0.3, 0.14),
	Color(0.9, 0.75, 0.4), Color(0.75, 0.75, 0.78), Color(0.9, 0.45, 0.6), Color(0.3, 0.45, 0.85),
]
const HAIR_COLOR_NAMES := ["黒", "こげ茶", "茶", "赤茶", "金", "銀", "ピンク", "青"]
const SKIN_TONES := [
	Color(1.0, 0.88, 0.8), Color(0.98, 0.8, 0.68), Color(0.9, 0.7, 0.55), Color(0.78, 0.58, 0.42),
	Color(0.6, 0.42, 0.3), Color(0.42, 0.28, 0.2), Color(0.8, 0.88, 0.98), Color(0.7, 0.9, 0.7),
]
const SKIN_NAMES := ["色白", "ふつう", "小麦", "日焼け", "褐色", "こげ茶", "青白い", "みどり"]

## 形を選べる部分：[モデルの形の名前, 表示名] の一覧
const STYLES := {
	"hat": [["beanie", "ニット帽"], ["cap", "キャップ"], ["earflap", "耳あて帽"], ["helmet", "ヘルメット"],
		["catears", "ねこみみ"], ["bucket", "バケットハット"], ["none", "なし"]],
	"hair": [["short", "ショート"], ["bob", "ボブ"], ["long", "ロング"], ["pigtails", "おさげ"], ["none", "なし"]],
	"top": [["down", "ダウン"], ["hoodie", "パーカー"], ["coat", "コート"], ["poncho", "ポンチョ"]],
	"neck": [["scarf", "マフラー"], ["bandana", "バンダナ"], ["none", "なし"]],
	"face": [["smile", "にこにこ"], ["determined", "きりっ"], ["sleepy", "ねむそう"], ["surprised", "びっくり"],
		["cat", "ねこ口"], ["pout", "むすっ"]],
}
const STYLE_PARTS := ["hat", "hair", "top", "neck", "face"]
const STYLE_TITLES := ["帽子", "髪", "上着", "首まわり", "表情"]
const PREFIXES := {"hat": "Hat_", "hair": "Hair_", "top": "Top_", "neck": "Neck_", "face": "Face_"}
## 色を選べる部分（Settings の「部分_color」に番号を入れる）
const PARTS := ["hat", "jacket", "scarf"]
const PART_NAMES := ["帽子とミトン", "上着", "首まわり"]
## モデルの焼き込みは灰色（明るさ 0.6 くらい）なので、そのぶん明るくして塗る
const TINT_BOOST := 1.6
const SKIN_BOOST := 1.12  # 肌は明るめ（0.88 くらい）に焼いてある


static func color_of(part: String) -> Color:
	var index: int = Settings.get(part + "_color")
	return COLORS[clampi(index, 0, COLORS.size() - 1)]


static func tint_of(part: String) -> Color:
	var c := color_of(part)
	return Color(c.r * TINT_BOOST, c.g * TINT_BOOST, c.b * TINT_BOOST)


static func hair_tint() -> Color:
	var c: Color = HAIR_COLORS[clampi(Settings.hair_color, 0, HAIR_COLORS.size() - 1)]
	return Color(c.r * TINT_BOOST, c.g * TINT_BOOST, c.b * TINT_BOOST)


static func skin_tint() -> Color:
	var c: Color = SKIN_TONES[clampi(Settings.skin_tone, 0, SKIN_TONES.size() - 1)]
	return Color(c.r * SKIN_BOOST, c.g * SKIN_BOOST, c.b * SKIN_BOOST)


## いま選んでいる形の名前（"beanie" など）
static func style_of(part: String) -> String:
	var list: Array = STYLES[part]
	var index: int = Settings.get(part + "_style")
	return list[clampi(index, 0, list.size() - 1)][0]


## モデルの部分の表示を、選んだ形だけにする。styles を省くと、Settings で選んだ形にする
static func apply_styles(model: Node, styles := {}) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for part: String in PREFIXES:
			var prefix: String = PREFIXES[part]
			if mesh.name.begins_with(prefix):
				var chosen: String = styles.get(part, style_of(part)) if not styles.is_empty() else style_of(part)
				mesh.visible = String(mesh.name) == prefix + chosen


## 素材の名前から、どの色で塗る部分かを決める（塗らない素材は ""）
static func tint_part(material_name: String) -> String:
	if material_name == "mittens_tint" or (material_name.begins_with("hat_") and material_name.ends_with("_tint")):
		return "hat"
	if material_name.begins_with("top_"):
		return "jacket"
	if material_name.begins_with("neck_"):
		return "scarf"
	if material_name.begins_with("hair_"):
		return "hair"
	if material_name == "skin_tint":
		return "skin"
	return ""


static func tint_for(part: String) -> Color:
	match part:
		"hair":
			return hair_tint()
		"skin":
			return skin_tint()
	return tint_of(part)
