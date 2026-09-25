class_name CreatureKit
extends RefCounted
## 化け物の体を、単純な形の組み合わせで作るための道具

const SKIN_SHADER := preload("res://shaders/creature_skin.gdshader")


static func skin(color: Color, rim: Color, rim_strength := 0.3, wetness := 0.5) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SKIN_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("rim_color", rim)
	material.set_shader_parameter("rim_strength", rim_strength)
	material.set_shader_parameter("wetness", wetness)
	return material


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


static func joint(parent: Node3D, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	parent.add_child(node)
	return node


## 付け根から -Y 方向へ伸びる、節のある手足。各節の付け根の関節を返す（最後の節の先に爪）
static func limb(parent: Node3D, origin: Vector3, radius: float, lengths: Array, material: Material,
		claws: int, claw_material: Material) -> Array[Node3D]:
	var joints: Array[Node3D] = []
	var current := joint(parent, origin)
	var r := radius
	for i in lengths.size():
		var length: float = lengths[i]
		joints.append(current)
		part(current, capsule(r, length + r * 2.0), material, Vector3(0.0, -length / 2.0, 0.0))
		if i < lengths.size() - 1:
			current = joint(current, Vector3(0.0, -length, 0.0))
			r *= 0.85
	var tip: float = lengths[lengths.size() - 1]
	for c in claws:
		var spread := (c - (claws - 1) / 2.0) * 0.35
		part(current, cone(0.012, 0.2), claw_material, Vector3(sin(spread) * 0.05, -tip - 0.09, 0.0),
			Vector3(0.0, 0.0, PI + spread * 0.5))
	return joints


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	return mesh


static func sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


## 先のとがった円すい（爪や歯）。+Y 方向が先端
static func cone(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return mesh
