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
	"item_1": KEY_1,
	"item_2": KEY_2,
	"item_3": KEY_3,
	"item_4": KEY_4,
}


func _enter_tree() -> void:
	for action: String in KEY_BINDINGS:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_BINDINGS[action]
		_add(action, event)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_add("grab", click)


func _add(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_add_event(action, event)
