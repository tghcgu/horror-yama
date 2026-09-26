class_name CreatureKit
extends RefCounted
## 化け物と置き物の素材、Blender で作ったモデルの読み込み

const SKIN_SHADER := preload("res://shaders/creature_skin.gdshader")


static func skin(color: Color, rim: Color, rim_strength := 0.3, wetness := 0.5) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SKIN_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("rim_color", rim)
	material.set_shader_parameter("rim_strength", rim_strength)
	material.set_shader_parameter("wetness", wetness)
	return material


## Blender で作ったモデル（.glb）を読み込み、素材を差し替えて返す。
## materials は「Blender での素材の名前 → 使う素材」。名前が "_skin" で終わる素材は、焼き込んだ模様を
## 化け物の肌（skin_material）に貼り直す。肌の素材が複数あるときは、2 つめ以降は skin_material の複製を使う
static func load_model(scene: PackedScene, skin_material: ShaderMaterial, materials: Dictionary) -> Node3D:
	var model := scene.instantiate() as Node3D
	var skins := {}  # 焼き込んだ素材の名前 → 貼り直した肌
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance.mesh
		for i in mesh.get_surface_count():
			var original := mesh.surface_get_material(i)
			var material_name := original.resource_name if original else ""
			if material_name.ends_with("_skin"):
				if not skins.has(material_name):
					var skin := skin_material if skins.is_empty() else skin_material.duplicate() as ShaderMaterial
					var baked := original as BaseMaterial3D
					if baked:
						skin.set_shader_parameter("albedo_texture", baked.albedo_texture)
					skin.set_shader_parameter("mottle_amount", 0.0)
					skins[material_name] = skin
				mesh_instance.set_surface_override_material(i, skins[material_name])
			elif materials.has(material_name):
				mesh_instance.set_surface_override_material(i, materials[material_name])
	return model


static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func flat(color: Color, roughness := 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


static func part(parent: Node3D, mesh: PrimitiveMesh, material: Material, pos := Vector3.ZERO,
		rot := Vector3.ZERO, part_scale := Vector3.ONE) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	instance.scale = part_scale
	parent.add_child(instance)
	return instance


static func sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh
