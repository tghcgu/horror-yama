extends Node
## 入力アクションをコードで登録する（キー配置はここを変えればOK）

const KEY_BINDINGS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"sprint": KEY_SHIFT,
	"toggle_lamp": KEY_F,
	"restart": KEY_R,
	"interact": KEY_E,
	"throw": KEY_Q,
	"fly": KEY_F1,
	"buddy": KEY_F2,
	"emote": KEY_T,
	"reach": KEY_G,
	"fly_down": KEY_CTRL,
	"item_1": KEY_1,
	"item_2": KEY_2,
	"item_3": KEY_3,
	"item_4": KEY_4,
	"item_5": KEY_5,
	"item_6": KEY_6,
}


func _ready() -> void:
	# 日本語入力（IME）がオンのままだと、キーを離したことがゲームに届かず、押しっぱなしになることがある。
	# ゲームの画面では IME を使わない
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_ime_active(false)


## 押されたままになっている入力を、すべて離したことにする（メニューを開け閉めしたときなど）
func release_all() -> void:
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _enter_tree() -> void:
	for action: String in KEY_BINDINGS:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_BINDINGS[action]
		_add(action, event)

	# 左クリック：手に持っているアイテムを使う（手ぶらなら、つかむ）。右クリック：いつでもつかむ
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_add("use_item", click)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	_add("grab", right_click)


func _add(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_add_event(action, event)
