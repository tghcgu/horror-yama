class_name Appearance
extends RefCounted
## プレイヤーの見た目の色。鏡の前で、帽子（とミトン）・上着・マフラーの色を選べる。選んだ色は Settings に保存する

const COLORS := [
	Color(0.86, 0.22, 0.22), Color(0.96, 0.52, 0.16), Color(0.96, 0.8, 0.28), Color(0.4, 0.72, 0.36),
	Color(0.22, 0.66, 0.66), Color(0.28, 0.46, 0.86), Color(0.58, 0.38, 0.82), Color(0.96, 0.58, 0.72),
	Color(0.92, 0.92, 0.88), Color(0.24, 0.24, 0.27),
]
const NAMES := ["赤", "オレンジ", "黄", "緑", "青緑", "青", "むらさき", "ピンク", "白", "黒"]
const PARTS := ["hat", "jacket", "scarf"]
const PART_NAMES := ["帽子とミトン", "上着", "マフラー"]
## モデルの焼き込みは灰色（明るさ 0.6 くらい）なので、そのぶん明るくして塗る
const TINT_BOOST := 1.6


static func color_of(part: String) -> Color:
	var index: int = Settings.get(part + "_color")
	return COLORS[clampi(index, 0, COLORS.size() - 1)]


static func tint_of(part: String) -> Color:
	var c := color_of(part)
	return Color(c.r * TINT_BOOST, c.g * TINT_BOOST, c.b * TINT_BOOST)
