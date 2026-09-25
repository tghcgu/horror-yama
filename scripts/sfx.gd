class_name Sfx
extends RefCounted
## 効果音をコードで合成する（本番の音素材ができるまでの仮の音）

const RATE := 22050


## 岩をつかむ「ザッ」
static func grip() -> AudioStreamWAV:
	var samples := _buffer(0.12)
	var low := 0.0
	for i in samples.size():
		var s := float(i) / RATE
		low += 0.35 * (_white() - low)
		samples[i] = low * exp(-s * 40.0) * 0.9 + _thump(s, 95.0) * 0.35
	return _to_wav(samples, false)


## 砂利を踏む「ジャリ」
static func footstep() -> AudioStreamWAV:
	var samples := _buffer(0.15)
	var low := 0.0
	for i in samples.size():
		var s := float(i) / RATE
		var grain := _white() * (1.0 if randf() < 0.25 else 0.2)
		low += 0.25 * (grain - low)
		samples[i] = low * exp(-s * 25.0) * 1.2 + _thump(s, 70.0) * 0.25
	return _to_wav(samples, false)


## 着地の「ドスッ」
static func thud() -> AudioStreamWAV:
	var samples := _buffer(0.35)
	var low := 0.0
	for i in samples.size():
		var s := float(i) / RATE
		low += 0.08 * (_white() - low)
		samples[i] = (low * 2.5 * exp(-s * 18.0) + _thump(s, 50.0) * 0.9) * 0.8
	return _to_wav(samples, false)


## 疲れたときの「ハァ…ハァ…」。ループする
static func breathing() -> AudioStreamWAV:
	var samples := _buffer(2.2)
	var low := 0.0
	for i in samples.size():
		var s := float(i) / RATE
		var inhale := _hump(s, 0.0, 0.8)
		var exhale := _hump(s, 1.0, 2.0)
		var brightness := maxf(0.35 * inhale + 0.18 * exhale, 0.02)  # 吸う音は高め、吐く音は低め
		low += brightness * (_white() - low)
		samples[i] = low * (inhale * 0.8 + exhale * 1.1)
	return _to_wav(samples, true)


## 岩をひっかく「カリ…カリカリ」と、ときどき重い足音。3秒でループする
static func scratches() -> AudioStreamWAV:
	var samples := _buffer(3.0)
	var t := 0
	while t < samples.size():
		var length := randi_range(int(RATE * 0.02), int(RATE * 0.07))
		var gain := randf_range(0.3, 0.9)
		var previous := 0.0
		for i in mini(length, samples.size() - t):
			var white := _white()
			samples[t + i] += (white - previous) * 0.5 * gain * exp(-6.0 * i / length)
			previous = white
		if randf() < 0.25:
			for i in mini(int(RATE * 0.15), samples.size() - t):
				samples[t + i] += _thump(float(i) / RATE, 70.0) * 0.8
		t += length + randi_range(int(RATE * 0.08), int(RATE * 0.33))
	return _to_wav(samples, true)


## 関節が鳴る「パキ、パキッ」
static func crack() -> AudioStreamWAV:
	var samples := _buffer(0.18)
	var click_length := int(RATE * 0.006)
	for _click in randi_range(3, 5):
		var start := randi_range(0, samples.size() - click_length - 1)
		for i in click_length:
			samples[start + i] += _white() * (1.0 - float(i) / click_length) * 0.9
	return _to_wav(samples, false)


## すぐそばで聞こえる、低くのどを鳴らすうなり声。ループする
static func growl() -> AudioStreamWAV:
	var samples := _buffer(2.0)
	var low := 0.0
	var phase := 0.0
	for i in samples.size():
		var s := float(i) / RATE
		low += 0.04 * (_white() - low)
		var rattle := 0.55 + 0.45 * sin(TAU * 9.0 * s)
		phase += TAU * (48.0 + 6.0 * sin(TAU * 0.5 * s)) / RATE
		samples[i] = (low * 3.0 * rattle + sin(phase) * 0.25) * 0.8
	return _to_wav(samples, true)


## アイテムを拾った「チリン」
static func chime() -> AudioStreamWAV:
	var samples := _buffer(0.5)
	for i in samples.size():
		var s := float(i) / RATE
		var v := sin(TAU * 880.0 * s) * exp(-s * 9.0)
		if s > 0.07:
			v += sin(TAU * 1320.0 * (s - 0.07)) * exp(-(s - 0.07) * 9.0)
		samples[i] = v * 0.35
	return _to_wav(samples, false)


## アイテムを使った「ガサッ」
static func rustle() -> AudioStreamWAV:
	var samples := _buffer(0.25)
	var low := 0.0
	for i in samples.size():
		var s := float(i) / RATE
		low += 0.5 * (_white() * (0.4 + 0.6 * absf(sin(TAU * 18.0 * s))) - low)
		samples[i] = low * _hump(s, 0.0, 0.25) * 0.7
	return _to_wav(samples, false)


## 威嚇の「シャーッ」
static func hiss() -> AudioStreamWAV:
	var samples := _buffer(0.9)
	var previous := 0.0
	for i in samples.size():
		var s := float(i) / RATE
		var white := _white()
		samples[i] = (white - previous * 0.6) * minf(s / 0.05, 1.0) * exp(-s * 3.5) * 0.6
		previous = white
	return _to_wav(samples, false)


## 雪の中で聞こえる、何を言っているのかわからないささやき。ループする
static func whisper() -> AudioStreamWAV:
	var samples := _buffer(4.0)
	var low := 0.0
	for i in samples.size():
		var s := float(i) / RATE
		# 言葉のような抑揚：短い音節がランダムに続く
		var syllable := maxf(sin(TAU * 3.1 * s) * sin(TAU * 0.75 * s + 1.0), 0.0)
		var brightness := 0.25 + 0.2 * sin(TAU * 5.3 * s)
		low += brightness * (_white() - low)
		samples[i] = low * syllable * 0.9
	return _to_wav(samples, true)


## 心臓の「ドクン」1回分
static func heartbeat() -> AudioStreamWAV:
	var samples := _buffer(0.5)
	for i in samples.size():
		var s := float(i) / RATE
		var v := _thump(s, 55.0)
		if s > 0.14:
			v += 0.7 * _thump(s - 0.14, 48.0)
		samples[i] = v * 0.9
	return _to_wav(samples, false)


## 日没の合図になる、遠くからのうめき声
static func wail() -> AudioStreamWAV:
	var duration := 2.8
	var samples := _buffer(duration)
	var phase := 0.0
	for i in samples.size():
		var s := float(i) / RATE
		var progress := s / duration
		var freq := lerpf(420.0, 170.0, progress) * (1.0 + 0.03 * sin(TAU * 5.5 * s))
		phase += TAU * freq / RATE
		var tone := sin(phase) + 0.5 * sin(2.0 * phase) + 0.25 * sin(3.0 * phase + 0.5)
		var envelope := minf(s / 0.35, 1.0) * pow(1.0 - progress, 1.5)
		samples[i] = (tone * 0.5 + _white() * 0.25) * envelope * 0.6
	return _to_wav(samples, false)


static func _white() -> float:
	return randf() * 2.0 - 1.0


static func _thump(s: float, freq: float) -> float:
	return (sin(TAU * freq * s) + 0.5 * sin(TAU * freq * 2.0 * s)) * exp(-s * 30.0)


## start 秒から end 秒までふくらんでしぼむ山形の音量
static func _hump(s: float, start: float, end: float) -> float:
	if s < start or s > end:
		return 0.0
	return sin(PI * (s - start) / (end - start))


static func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * seconds))
	return samples


static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
