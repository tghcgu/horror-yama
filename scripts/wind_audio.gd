class_name WindAudio
extends AudioStreamPlayer
## 風の音をその場で合成して鳴らす。高いところほど強く吹く。

const MIX_RATE := 22050.0

var altitude := 0.0  # 0（ふもと）〜 1（山頂）

var _playback: AudioStreamGeneratorPlayback
var _gust_noise := FastNoiseLite.new()
var _brown := 0.0
var _time := 0.0


func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.25
	stream = generator
	volume_db = -4.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_gust_noise.frequency = 0.25


func _process(delta: float) -> void:
	if _playback == null:
		return
	_time += delta
	var gust := 0.5 + 0.5 * _gust_noise.get_noise_1d(_time)
	var amplitude := (0.3 + 0.7 * gust) * (0.35 + 0.65 * altitude) * 3.5
	for i in _playback.get_frames_available():
		_brown = (_brown + 0.02 * (randf() * 2.0 - 1.0)) / 1.02
		var sample := _brown * amplitude
		_playback.push_frame(Vector2(sample, sample))
