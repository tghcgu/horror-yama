class_name Psx
extends RefCounted
## PS1 風の見た目の素材（マテリアル）を作る道具

const LIT_SHADER := preload("res://shaders/psx_lit.gdshader")
const TERRAIN_SHADER := preload("res://shaders/psx_terrain.gdshader")
const TEXTURES := "res://assets/textures/%s.png"


## 素材を貼った置き物用のマテリアル。tint で色味を、saturation で鮮やかさを調整する
static func material(texture_name: String, tint := Color.WHITE, texture_scale := 0.5, saturation := 1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LIT_SHADER
	if texture_name != "":
		mat.set_shader_parameter("albedo_texture", texture(texture_name))
	mat.set_shader_parameter("albedo", tint)
	mat.set_shader_parameter("texture_scale", texture_scale)
	mat.set_shader_parameter("saturation", saturation)
	return mat


## 頂点の色で塗り分ける置き物用のマテリアル（MeshBuilder でまとめたメッシュに使う）。同じ設定なら使い回す
static func vertex_material(texture_name := "", texture_scale := 0.5, saturation := 1.0) -> ShaderMaterial:
	var key := "vertex_material/%s/%s/%s" % [texture_name, texture_scale, saturation]
	return Shared.get_or_make(key, func() -> ShaderMaterial:
		var mat := material(texture_name, Color.WHITE, texture_scale, saturation)
		mat.set_shader_parameter("use_vertex_color", true)
		return mat)


static func terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	for biome: String in ["forest", "crag", "snow", "summit"]:
		mat.set_shader_parameter("rock_" + biome, texture("rock_" + biome))  # 地帯ごとの岩肌
	mat.set_shader_parameter("ground_forest", texture("ground_forest"))
	mat.set_shader_parameter("ground_crag", texture("ground_crag"))
	mat.set_shader_parameter("ground_snow", texture("ground_snow"))
	mat.set_shader_parameter("ground_summit", texture("ground_summit"))
	return mat


## Blender から読み込んだモデルの素材（色・焼き込んだ模様・発光）を、PS1 風の素材に置き換える。
## 置き換えた素材を、Blender での素材の名前で引けるように返す（同じ名前の素材は 1 つにまとめる）
static func convert_model(model: Node) -> Dictionary:
	var converted := {}
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh_instance.mesh.get_surface_count():
			var original := mesh_instance.mesh.surface_get_material(i) as BaseMaterial3D
			if original == null:
				continue
			if not converted.has(original.resource_name):
				var mat := material("", original.albedo_color, 1.0)
				if original.albedo_texture:
					mat.set_shader_parameter("albedo_texture", original.albedo_texture)
					mat.set_shader_parameter("use_uv", true)
				if original.emission_enabled:
					mat.set_shader_parameter("emission", original.emission * original.emission_energy_multiplier)
				converted[original.resource_name] = mat
			mesh_instance.set_surface_override_material(i, converted[original.resource_name])
	return converted


static func texture(texture_name: String) -> Texture2D:
	return load(TEXTURES % texture_name) as Texture2D
