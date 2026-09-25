class_name Items
extends RefCounted
## アイテムの種類・説明・見た目

enum Kind { PITON, BANDAGE, ONIGIRI, OFUDA }

const NAMES := ["ハーケン", "包帯", "おにぎり", "お札"]
const COUNT := 4
const STARTING := [1, 0, 0, 1]      # 最初から持っている数
const SPAWN_WEIGHTS := [3.0, 2.5, 2.5, 2.0]


## 拾う前の置き物や、打ち込んだハーケンの見た目
static func build_model(kind: int) -> Node3D:
	var root := Node3D.new()
	match kind:
		Kind.PITON:
			var metal := _material(Color(0.6, 0.62, 0.65), 0.9, 0.3)
			var spike := CylinderMesh.new()
			spike.top_radius = 0.004
			spike.bottom_radius = 0.018
			spike.height = 0.24
			_part(root, spike, metal, Vector3.ZERO, Vector3.ZERO)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.02
			ring.outer_radius = 0.034
			_part(root, ring, metal, Vector3(0.0, -0.14, 0.0), Vector3(PI / 2.0, 0.0, 0.0))
		Kind.BANDAGE:
			var roll := CylinderMesh.new()
			roll.top_radius = 0.06
			roll.bottom_radius = 0.06
			roll.height = 0.08
			_part(root, roll, _material(Color(0.92, 0.9, 0.84)), Vector3.ZERO, Vector3(0.0, 0.0, PI / 2.0))
			var tail := BoxMesh.new()
			tail.size = Vector3(0.075, 0.004, 0.12)
			_part(root, tail, _material(Color(0.88, 0.86, 0.8)), Vector3(0.0, -0.058, 0.06), Vector3.ZERO)
		Kind.ONIGIRI:
			var rice := PrismMesh.new()
			rice.size = Vector3(0.14, 0.13, 0.06)
			_part(root, rice, _material(Color(0.95, 0.95, 0.92)), Vector3.ZERO, Vector3.ZERO)
			var nori := BoxMesh.new()
			nori.size = Vector3(0.07, 0.05, 0.064)
			_part(root, nori, _material(Color(0.05, 0.08, 0.05)), Vector3(0.0, -0.04, 0.0), Vector3.ZERO)
		Kind.OFUDA:
			var paper := BoxMesh.new()
			paper.size = Vector3(0.07, 0.2, 0.004)
			_part(root, paper, _material(Color(0.93, 0.88, 0.74)), Vector3.ZERO, Vector3.ZERO)
			var ink := StandardMaterial3D.new()
			ink.albedo_color = Color(0.7, 0.05, 0.03)
			ink.emission_enabled = true
			ink.emission = Color(0.6, 0.03, 0.02)
			ink.emission_energy_multiplier = 1.5
			for i in 3:
				var stroke := BoxMesh.new()
				stroke.size = Vector3(0.012 if i == 1 else 0.045, 0.14 if i == 1 else 0.008, 0.006)
				var y := 0.0 if i == 1 else (0.06 if i == 0 else -0.06)
				_part(root, stroke, ink, Vector3(0.0, y, 0.0), Vector3.ZERO)
	return root


static func pick_random(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w: float in SPAWN_WEIGHTS:
		total += w
	var roll := rng.randf() * total
	for i in COUNT:
		roll -= SPAWN_WEIGHTS[i]
		if roll <= 0.0:
			return i
	return COUNT - 1


static func _part(parent: Node3D, mesh: PrimitiveMesh, material: Material, pos: Vector3, rot: Vector3) -> void:
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.rotation = rot
	parent.add_child(part)


static func _material(color: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
