class_name DayCycle
extends Node
## 夕方から夜への移り変わり。空・太陽・霧を変化させ、真っ暗になったら night_fell を出す。

signal night_fell

const DAY_LENGTH := 75.0     # 日が傾き始めるまで（秒）
const SUNSET_LENGTH := 20.0  # 夕焼けから真っ暗になるまで（秒）

const DUSK_SKY_TOP := Color(0.16, 0.2, 0.36)
const DUSK_SKY_HORIZON := Color(0.85, 0.5, 0.35)
const DUSK_FOG := Color(0.55, 0.45, 0.45)
const NIGHT_SKY_TOP := Color(0.01, 0.01, 0.03)
const NIGHT_SKY_HORIZON := Color(0.05, 0.05, 0.08)
const NIGHT_FOG := Color(0.03, 0.03, 0.05)

var time := 0.0
var is_night := false
var darkness := 0.0  # 0（夕方）〜 1（夜）

var _environment: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
# いる地帯によって霧の濃さと色が変わる（なめらかに切り替える）
var _fog_multiplier := 1.0
var _fog_tint := Color(0.5, 0.45, 0.42)
var _target_fog_multiplier := 1.0
var _target_fog_tint := Color(0.5, 0.45, 0.42)


func _ready() -> void:
	_sky = ProceduralSkyMaterial.new()
	_sky.ground_bottom_color = Color(0.02, 0.02, 0.03)
	var sky := Sky.new()
	sky.sky_material = _sky

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_sky_affect = 0.85
	_environment.glow_enabled = true  # たき火や“何か”の目をぼんやり光らせる
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)

	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.62, 0.45)
	_sun.shadow_enabled = true
	_sun.rotation_degrees.y = -35.0
	add_child(_sun)

	# 夜でも崖の輪郭がうっすら見える程度の月明かり
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.55, 0.65, 1.0)
	_moon.rotation_degrees = Vector3(-50.0, 140.0, 0.0)
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_moon)

	Settings.changed.connect(_apply_brightness)
	_apply_brightness()
	reset()


func reset() -> void:
	time = 0.0
	is_night = false
	_apply(0.0)


func seconds_until_night() -> float:
	return maxf(DAY_LENGTH + SUNSET_LENGTH - time, 0.0)


## いる地帯に合わせた霧（濃さの倍率と色）を指定する
func set_biome_fog(multiplier: float, tint: Color) -> void:
	_target_fog_multiplier = multiplier
	_target_fog_tint = tint


func _process(delta: float) -> void:
	time += delta
	var weight := 1.0 - exp(-1.5 * delta)
	_fog_multiplier = lerpf(_fog_multiplier, _target_fog_multiplier, weight)
	_fog_tint = _fog_tint.lerp(_target_fog_tint, weight)
	var t := clampf((time - DAY_LENGTH) / SUNSET_LENGTH, 0.0, 1.0)
	_apply(t)
	if t >= 1.0 and not is_night:
		is_night = true
		night_fell.emit()


## t = 0 で夕方、t = 1 で夜
func _apply(t: float) -> void:
	darkness = t
	_sun.rotation_degrees.x = lerpf(-20.0, 4.0, t)
	_sun.light_energy = lerpf(1.0, 0.0, smoothstep(0.3, 0.9, t))
	_moon.light_energy = lerpf(0.0, 0.2, smoothstep(0.5, 1.0, t))
	_sky.sky_top_color = DUSK_SKY_TOP.lerp(NIGHT_SKY_TOP, t)
	_sky.sky_horizon_color = DUSK_SKY_HORIZON.lerp(NIGHT_SKY_HORIZON, t)
	_sky.ground_horizon_color = _sky.sky_horizon_color.darkened(0.4)
	_environment.ambient_light_energy = lerpf(0.8, 0.25, t)
	var base_fog := DUSK_FOG.lerp(NIGHT_FOG, t)
	_environment.fog_light_color = base_fog.lerp(_fog_tint * (1.0 - 0.85 * t), 0.5)
	_environment.fog_density = lerpf(0.012, 0.022, t) * _fog_multiplier


func _apply_brightness() -> void:
	_environment.tonemap_exposure = Settings.brightness
