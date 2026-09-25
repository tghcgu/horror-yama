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


static func terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("rock_low", texture("rock_mossy"))
	mat.set_shader_parameter("rock_high", texture("rock"))
	mat.set_shader_parameter("ground_forest", texture("ground_forest"))
	mat.set_shader_parameter("ground_crag", texture("ground_crag"))
	mat.set_shader_parameter("ground_snow", texture("ground_snow"))
	mat.set_shader_parameter("ground_summit", texture("ground_summit"))
	mat.set_shader_parameter("biome_tops", Vector3(Biomes.TOPS[0], Biomes.TOPS[1], Biomes.TOPS[2]))
	mat.set_shader_parameter("biome_blend", Biomes.BLEND)
	return mat


static func texture(texture_name: String) -> Texture2D:
	return load(TEXTURES % texture_name) as Texture2D
