class_name Shared
extends RefCounted
## 使い回すメッシュや素材の置き場。同じ形を何度も作らないようにする（GPU のバッファを節約する）。
## ゲームを閉じるときに clear() で手放す（描画の仕組みが先に終わってから消えると、落ちることがあるため）。

static var _store := {}


## key の物がなければ make() で作ってしまっておき、それを返す
static func get_or_make(key: String, make: Callable) -> Variant:
	if not _store.has(key):
		_store[key] = make.call()
	return _store[key]


static func clear() -> void:
	_store.clear()
