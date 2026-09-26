class_name DayCycle
extends Node
## 昼 → 夕暮れ → 夜 → 夜明け をくり返す。空・太陽・月・霧を変化させ、
## 真っ暗になったら night_fell、明るくなり始めたら dawn_broke を出す。
## 霧は遠くの山がうっすらかすむ程度にとどめ、夜だけ濃く暗くして見通しを悪くする。

signal night_fell
signal dawn_broke

const DAY_LENGTH := 150.0    # 明るい時間（秒）
const SUNSET_LENGTH := 35.0  # 夕焼けから真っ暗になるまで（秒）
const NIGHT_LENGTH := 120.0  # 真っ暗な時間（秒）
const DAWN_LENGTH := 25.0    # 夜明けから明るくなるまで（秒）
const CYCLE := DAY_LENGTH + SUNSET_LENGTH + NIGHT_LENGTH + DAWN_LENGTH
const SKY_SHADER := preload("res://shaders/psx_sky.gdshader")

# 空と光の色。昼（曇った山の白っぽい光）→ 夕暮れ（オレンジ）→ 夜（青黒い）
const PALETTE := {
	"sky_top": [Color(0.3, 0.37, 0.48), Color(0.16, 0.2, 0.36), Color(0.012, 0.016, 0.04)],
	"sky_horizon": [Color(0.62, 0.64, 0.66), Color(0.85, 0.5, 0.35), Color(0.05, 0.06, 0.1)],
	"cloud": [Color(0.72, 0.73, 0.75), Color(0.6, 0.38, 0.35), Color(0.03, 0.035, 0.05)],
	"sun": [Color(1.0, 0.94, 0.86), Color(1.0, 0.55, 0.35), Color(0.0, 0.0, 0.0)],
	"ambient": [Color(0.62, 0.66, 0.72), Color(0.55, 0.42, 0.42), Color(0.1, 0.12, 0.2)],
	"fog": [Color(0.6, 0.62, 0.64), Color(0.55, 0.42, 0.4), Color(0.025, 0.028, 0.045)],
}
const SUN_ENERGY := [1.15, 0.8, 0.0]
const SUN_PITCH := [-42.0, -8.0, 6.0]
const AMBIENT_ENERGY := [0.75, 0.55, 0.35]
const FOG_DENSITY := [0.0022, 0.004, 0.013]

var time := 0.0
var is_night := false
var night_count := 0   # 何回目の夜か（1 から）
var darkness := 0.0  # 0（明るい）〜 1（夜）

var _environment: Environment
var _sky: ShaderMaterial
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
# いる地帯によって霧の濃さと色が変わる（なめらかに切り替える）
var _fog_multiplier := 1.0
var _fog_tint := Color(0.5, 0.45, 0.42)
var _target_fog_multiplier := 1.0
var _target_fog_tint := Color(0.5, 0.45, 0.42)
var _indoor := 0.0
var _target_indoor := 0.0
var _running := true


func _ready() -> void:
	_sky = ShaderMaterial.new()
	_sky.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL  # 空は環境光にも反射にも使わないので、映り込み用の計算は少しずつでよい
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_sky_affect = 0.1
	_environment.glow_enabled = true  # たき火や“何か”の目をぼんやり光らせる
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS  # 4 段ではなく 2 段（軽い）
	_sun.directional_shadow_max_distance = 70.0
	_sun.rotation_degrees.y = -35.0
	add_child(_sun)

	# 夜でも崖の輪郭がうっすら見える程度の月明かり
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.55, 0.65, 1.0)
	_moon.rotation_degrees = Vector3(-50.0, 140.0, 0.0)
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_moon)
	_sky.set_shader_parameter("moon_direction", -_moon.global_transform.basis.z)

	Settings.changed.connect(_apply_settings)
	_apply_settings()
	reset()


func reset() -> void:
	time = 0.0
	is_night = false
	night_count = 0
	_apply(0.0)


## 次に真っ暗になるまでの秒数
func seconds_until_night() -> float:
	var until := DAY_LENGTH + SUNSET_LENGTH - fmod(time, CYCLE)
	return until if until > 0.0 else until + CYCLE


## 夜が明け始めるまでの秒数（夜のあいだだけ意味がある）
func seconds_until_dawn() -> float:
	return maxf(DAY_LENGTH + SUNSET_LENGTH + NIGHT_LENGTH - fmod(time, CYCLE), 0.0)


## いる地帯に合わせた霧（濃さの倍率と色）を指定する
func set_biome_fog(multiplier: float, tint: Color) -> void:
	_target_fog_multiplier = multiplier
	_target_fog_tint = tint


## 時計を進めるか（山小屋にいるあいだは止める）。霧や空の更新は止めない
func set_running(on: bool) -> void:
	_running = on


## 建物の中では、霧をほとんど消す
func set_indoor(on: bool) -> void:
	_target_indoor = 1.0 if on else 0.0


## 1 周期の中の位置から、暗さ（0〜1）を求める
func _darkness_at(t: float) -> float:
	var phase := fmod(t, CYCLE)
	if phase < DAY_LENGTH:
		return 0.0
	phase -= DAY_LENGTH
	if phase < SUNSET_LENGTH:
		return phase / SUNSET_LENGTH
	phase -= SUNSET_LENGTH
	if phase < NIGHT_LENGTH:
		return 1.0
	return 1.0 - (phase - NIGHT_LENGTH) / DAWN_LENGTH


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-1.5 * delta)
	_fog_multiplier = lerpf(_fog_multiplier, _target_fog_multiplier, weight)
	_fog_tint = _fog_tint.lerp(_target_fog_tint, weight)
	_indoor = move_toward(_indoor, _target_indoor, delta * 2.0)
	if _running:
		time += delta
	var phase := fmod(time, CYCLE)
	var night := phase >= DAY_LENGTH + SUNSET_LENGTH and phase < DAY_LENGTH + SUNSET_LENGTH + NIGHT_LENGTH
	_apply(_darkness_at(time))
	if night and not is_night:
		is_night = true
		night_count += 1
		night_fell.emit()
	elif not night and is_night:
		is_night = false
		dawn_broke.emit()


## t = 0 で昼、0.5 で夕暮れ、1 で夜
func _apply(t: float) -> void:
	darkness = t
	var sun_color := _palette("sun", t)
	_sun.light_color = sun_color
	_sun.rotation_degrees.x = _curve(SUN_PITCH, t)
	_sun.light_energy = _curve(SUN_ENERGY, t) * (1.0 - smoothstep(0.75, 0.95, t))
	_moon.light_energy = lerpf(0.0, 0.22, smoothstep(0.6, 1.0, t))
	_sky.set_shader_parameter("top_color", _palette("sky_top", t))
	_sky.set_shader_parameter("horizon_color", _palette("sky_horizon", t))
	_sky.set_shader_parameter("ground_color", _palette("sky_horizon", t).darkened(0.5))
	_sky.set_shader_parameter("cloud_color", _palette("cloud", t))
	_sky.set_shader_parameter("night", smoothstep(0.7, 1.0, t))
	_environment.ambient_light_color = _palette("ambient", t)
	_environment.ambient_light_energy = _curve(AMBIENT_ENERGY, t)

	var fog_color := _palette("fog", t).lerp(_fog_tint * (1.0 - 0.9 * t), 0.35)
	var outdoor := 1.0 - _indoor
	_environment.fog_light_color = fog_color
	_environment.fog_density = _curve(FOG_DENSITY, t) * _fog_multiplier * lerpf(0.08, 1.0, outdoor)


## 昼・夕暮れ・夜の 3 つの値を、t（0〜1）でなめらかにつなぐ
func _curve(values: Array, t: float) -> float:
	return lerpf(values[0], values[1], t * 2.0) if t < 0.5 else lerpf(values[1], values[2], t * 2.0 - 1.0)


func _palette(key: String, t: float) -> Color:
	var colors: Array = PALETTE[key]
	return (colors[0] as Color).lerp(colors[1], t * 2.0) if t < 0.5 else (colors[1] as Color).lerp(colors[2], t * 2.0 - 1.0)


func _apply_settings() -> void:
	_environment.tonemap_exposure = Settings.brightness
