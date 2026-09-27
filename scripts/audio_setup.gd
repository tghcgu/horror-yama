extends Node
## 音の通り道（バス）を用意する。音は項目ごとの通り道に分けて流し、設定で項目ごとに音量を変えられる。
## “何か”の声には、山にこだまする残響をかける。

## 項目ごとの通り道（どれも Master に流れこむ）
const CATEGORY_BUSES := [&"Monsters", &"Animals", &"World", &"Self"]
## どの音を、どの通り道に流すか。音の親をたどり、この表にあるスクリプトに当たったら、その項目にする。
## どれにも当たらなければ、自然・仕掛けの音
const CATEGORIES := [
	["res://scripts/enemies/", &"Monsters"],
	["res://scripts/stalker.gd", &"Monsters"],
	["res://scripts/peeker.gd", &"Monsters"],
	["res://scripts/pale_one.gd", &"Monsters"],
	["res://scripts/crag_spider.gd", &"Monsters"],
	["res://scripts/critter.gd", &"Animals"],
	["res://scripts/hitokuma.gd", &"Animals"],
	["res://scripts/player", &"Self"],  # player.gd・player_sounds.gd など
	["res://scripts/held_item.gd", &"Self"],
	["res://scripts/pickup.gd", &"Self"],
	["res://scripts/item_box.gd", &"Self"],
]


func _enter_tree() -> void:
	for bus in CATEGORY_BUSES:
		_add_bus(bus, &"Master")
	if AudioServer.get_bus_index("Echo") == -1:
		var index := _add_bus(&"Echo", &"Monsters")
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.9
		reverb.damping = 0.3
		reverb.predelay_msec = 120.0
		reverb.dry = 0.8
		reverb.wet = 0.5
		AudioServer.add_bus_effect(index, reverb)
	Settings.apply()
	get_tree().node_added.connect(_on_node_added)


func _add_bus(bus_name: StringName, send: StringName) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send)
	return index


## 鳴らす音が木に入ったら、項目の通り道につなぐ（Echo など、決まった通り道のある音はそのまま）
func _on_node_added(node: Node) -> void:
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer3D):
		return
	if node.get("bus") != &"Master":
		return
	node.set("bus", category_of(node))


static func category_of(node: Node) -> StringName:
	var current := node
	while current != null:
		var script := current.get_script() as Script
		if script != null:
			for entry: Array in CATEGORIES:
				if script.resource_path.begins_with(entry[0]):
					return entry[1]
		current = current.get_parent()
	return &"World"
