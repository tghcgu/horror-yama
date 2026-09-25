extends Node
## 音の通り道（バス）を用意する。“何か”の声には、山にこだまする残響をかける。


func _enter_tree() -> void:
	if AudioServer.get_bus_index("Echo") != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, "Echo")
	AudioServer.set_bus_send(index, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.9
	reverb.damping = 0.3
	reverb.predelay_msec = 120.0
	reverb.dry = 0.8
	reverb.wet = 0.5
	AudioServer.add_bus_effect(index, reverb)
