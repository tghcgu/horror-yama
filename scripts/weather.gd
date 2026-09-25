class_name Weather
extends Node3D
## 雪原の吹雪。プレイヤーのまわりにだけ雪を降らせる。夜は雪が暗く沈み、うっすらとしか見えない。

var player: Player
var day: DayCycle

var _snow: GPUParticles3D
var _flake_material: StandardMaterial3D


func _ready() -> void:
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(18.0, 8.0, 18.0)
	motion.direction = Vector3(1.0, -0.35, 0.3)
	motion.spread = 15.0
	motion.initial_velocity_min = 8.0
	motion.initial_velocity_max = 13.0
	motion.gravity = Vector3(0.0, -2.0, 0.0)
	motion.scale_min = 0.5
	motion.scale_max = 1.2

	_flake_material = StandardMaterial3D.new()
	_flake_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flake_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flake_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_flake_material.albedo_color = Color(0.9, 0.93, 1.0, 0.6)
	var flake := QuadMesh.new()
	flake.size = Vector2(0.035, 0.035)
	flake.material = _flake_material

	_snow = GPUParticles3D.new()
	_snow.amount = 3000
	_snow.lifetime = 2.5
	_snow.local_coords = false
	_snow.emitting = false
	_snow.process_material = motion
	_snow.draw_pass_1 = flake
	_snow.visibility_aabb = AABB(Vector3(-25.0, -20.0, -25.0), Vector3(50.0, 40.0, 50.0))
	add_child(_snow)


func _process(_delta: float) -> void:
	if player == null:
		return
	global_position = player.global_position + Vector3.UP * 4.0
	_snow.emitting = Biomes.at(player.global_position.y) == Biomes.Id.SNOW
	var darkness := day.darkness if day else 0.0
	_flake_material.albedo_color.a = lerpf(0.6, 0.15, darkness)
