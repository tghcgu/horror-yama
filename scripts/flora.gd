class_name Flora
extends RefCounted
## 山や平地に生える草木と、転がっている物の形。同じ形をたくさん並べるので、MountainFeatures がマルチメッシュで置く。
##   木・竹・笹・シダ・低木・切り株・倒木：Blender で作ったモデル（tools/flora/build_flora.py）。model() で読む
##   花・小石・キノコ・遭難者の荷物など：小さな形を頂点の色つきで 1 つのメッシュにまとめたもの（Psx.vertex_material で描く）
## 乱数は決まった種から引くので、いつ作っても同じ形になる。

const MODELS := "res://assets/models/flora_%s.glb"
const PROPS := "res://assets/models/prop_%s.glb"
const FOLIAGE_SHADER := preload("res://shaders/psx_foliage.gdshader")
const ICE_SHADER := preload("res://shaders/psx_ice.gdshader")

const LEAF := Color(0.3, 0.46, 0.2)
const MOSS := Color(0.28, 0.4, 0.18)


## Blender で作った草木のメッシュ。素材は PS1 風に置きかえる（名前が leaf_ で始まる葉は、裏からも見えて透ける葉の素材）。
## 同じ名前なら使い回す
static func model(model_name: String) -> Mesh:
	return load_mesh(MODELS % model_name)


## 遠くの木の「一枚絵」：Blender で木を真横から撮った絵を、十字に組んだ 2 枚の板に貼る（三角形 4 つ）
static func impostor(model_name: String) -> Mesh:
	return Shared.get_or_make("impostor/" + model_name, func() -> Mesh:
		var aabb := model(model_name).get_aabb()
		var height := aabb.end.y
		var size := maxf(height, maxf(aabb.size.x, aabb.size.z) * 2.0)
		var bottom := height * 0.5 - size * 0.5
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		for k in 2:
			var side := Vector3.RIGHT if k == 0 else Vector3.BACK
			var facing := side.cross(Vector3.UP)
			var base := vertices.size()
			for corner in [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1)]:
				vertices.append(side * corner.x * size * 0.25 + Vector3.UP * (bottom + corner.y * size))
				normals.append(facing)
				uvs.append(Vector2(corner.x * 0.5 + 0.5, 1.0 - corner.y))
			indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var picture := ShaderMaterial.new()
		picture.shader = FOLIAGE_SHADER
		picture.set_shader_parameter("albedo_texture", load("res://assets/textures/impostor_%s.png" % model_name))
		picture.set_shader_parameter("sway", 0.01)
		mesh.surface_set_material(0, picture)
		return mesh)


## Blender で作った建物・置き物のメッシュ（tools/props/build_props.py）
static func prop(prop_name: String) -> Mesh:
	return load_mesh(PROPS % prop_name)


## モデルの、葉や紙をのぞいた固い面の当たり判定（つかんで登れる）。同じメッシュなら使い回す
static func solid_shape(mesh: Mesh) -> ConcavePolygonShape3D:
	return Shared.get_or_make("solid_shape/%d" % mesh.get_instance_id(), func() -> ConcavePolygonShape3D:
		var faces := PackedVector3Array()
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i)
			if material is ShaderMaterial and (material as ShaderMaterial).shader == FOLIAGE_SHADER:
				continue
			var arrays := mesh.surface_get_arrays(i)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for index in indices:
				faces.append(vertices[index])
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		return shape)


## GLB を読み、最初のメッシュの素材を PS1 風に置きかえたものを返す（同じファイルなら使い回す）
static func load_mesh(path: String) -> Mesh:
	return Shared.get_or_make("model/" + path, func() -> Mesh:
		var scene := (load(path) as PackedScene).instantiate()
		var source := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var mesh := source.mesh.duplicate() as ArrayMesh
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, _convert(mesh.surface_get_material(i) as BaseMaterial3D))
		scene.free()
		return mesh)


static func _convert(original: BaseMaterial3D) -> Material:
	var key := "flora_material/" + original.resource_name
	return Shared.get_or_make(key, func() -> Material:
		if original.resource_name.begins_with("leaf_"):
			var leaf := ShaderMaterial.new()
			leaf.shader = FOLIAGE_SHADER
			leaf.set_shader_parameter("albedo_texture", original.albedo_texture)
			if original.resource_name.begins_with("leaf_item") or original.resource_name == "leaf_foil":
				leaf.set_shader_parameter("sway", 0.0)  # 手に持つ小さな物の葉や包み紙は、ゆらさない
			return leaf
		if original.resource_name.begins_with("glow_"):
			var glow := StandardMaterial3D.new()  # 暗い所でも光って見える（お札の墨、キノコの斑点）
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_texture = original.albedo_texture
			glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			glow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			glow.cull_mode = BaseMaterial3D.CULL_DISABLED
			return glow
		if original.resource_name.begins_with("ice_"):
			var ice := ShaderMaterial.new()  # つるつるで、ふちが光り、奥が青く沈む氷
			ice.shader = ICE_SHADER
			ice.set_shader_parameter("albedo_texture", original.albedo_texture)
			return ice
		var bark := Psx.material("", Color.WHITE, 1.0)
		bark.set_shader_parameter("albedo_texture", original.albedo_texture)
		bark.set_shader_parameter("use_uv", true)
		return bark)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _box() -> BoxMesh:
	return BoxMesh.new()


static func _cylinder(top: float, bottom: float, height: float, segments := 7) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func _ball(segments := 7, rings := 4) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


static func _tint(color: Color, rng: RandomNumberGenerator, amount := 0.12) -> Color:
	return color * rng.randf_range(1.0 - amount, 1.0 + amount)





## 野の花：細い茎の先に、白・黄・紫の小さな花
static func flowers() -> ArrayMesh:
	var rng := _rng(304)
	var builder := MeshBuilder.new()
	var petals := [Color(0.95, 0.95, 0.9), Color(0.95, 0.85, 0.3), Color(0.65, 0.45, 0.8)]
	for i in 9:
		var pos := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
		var height := rng.randf_range(0.2, 0.45)
		builder.add(_box(), pos + Vector3.UP * height * 0.5, Vector3.ZERO, Vector3(0.015, height, 0.015), LEAF)
		builder.add(_ball(5, 3), pos + Vector3.UP * height, Vector3.ZERO, Vector3(0.09, 0.05, 0.09), petals[i % petals.size()])
	return builder.commit()


## 苔むした小石
static func stones() -> ArrayMesh:
	var rng := _rng(305)
	var builder := MeshBuilder.new()
	for i in 4:
		var s := rng.randf_range(0.2, 0.5)
		var pos := Vector3(rng.randf_range(-0.6, 0.6), s * 0.2, rng.randf_range(-0.6, 0.6))
		var rot := Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)
		builder.add(_ball(6, 4), pos, rot, Vector3(s * 1.3, s * 0.7, s), _tint(Color(0.45, 0.46, 0.42), rng))
		builder.add(_ball(5, 3), pos + Vector3.UP * s * 0.3, rot, Vector3(s * 1.1, s * 0.25, s * 0.8), _tint(MOSS, rng))
	return builder.commit()


## キノコの群れ
static func mushrooms() -> ArrayMesh:
	var rng := _rng(306)
	var builder := MeshBuilder.new()
	var caps := [Color(0.7, 0.2, 0.12), Color(0.6, 0.45, 0.28), Color(0.9, 0.88, 0.8)]
	var cap: Color = caps[0]
	for i in 5:
		var pos := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		var height := rng.randf_range(0.06, 0.18)
		var r := rng.randf_range(0.05, 0.12)
		if i == 3:
			cap = caps[rng.randi() % caps.size()]
		builder.add(_cylinder(0.015, 0.02, height, 5), pos + Vector3.UP * height * 0.5, Vector3.ZERO, Vector3.ONE, Color(0.9, 0.88, 0.8))
		builder.add(_ball(6, 3), pos + Vector3.UP * height, Vector3.ZERO, Vector3(r * 2.0, r * 0.9, r * 2.0), cap)
	return builder.commit()







## 遭難者のザック：口の開いた古い登山ザックと、こぼれた寝袋
static func backpack() -> ArrayMesh:
	var builder := MeshBuilder.new()
	var cloth := Color(0.55, 0.22, 0.14)
	builder.add(_box(), Vector3(0.0, 0.3, 0.0), Vector3(0.25, 0.4, 0.0), Vector3(0.45, 0.6, 0.3), cloth)
	builder.add(_box(), Vector3(0.0, 0.6, -0.05), Vector3(0.25, 0.4, 0.0), Vector3(0.4, 0.12, 0.28), cloth.darkened(0.3))
	builder.add(_cylinder(0.12, 0.12, 0.55, 7), Vector3(0.45, 0.12, 0.25), Vector3(0.0, 0.3, PI * 0.5), Vector3.ONE, Color(0.25, 0.3, 0.35))
	builder.add(_box(), Vector3(-0.2, 0.05, 0.35), Vector3(0.0, 0.8, 0.0), Vector3(0.3, 0.04, 0.2), Color(0.2, 0.2, 0.18))
	return builder.commit()


## 破れたテント：傾いた三角の布と、折れたポール
static func tent() -> ArrayMesh:
	var builder := MeshBuilder.new()
	var cloth := Color(0.3, 0.42, 0.5)
	var prism := PrismMesh.new()
	builder.add(prism, Vector3(0.0, 0.55, 0.0), Vector3(0.0, 0.0, 0.25), Vector3(1.8, 1.1, 2.2), cloth)
	builder.add(_box(), Vector3(0.7, 0.3, 1.0), Vector3(0.4, 0.2, 0.9), Vector3(0.9, 0.02, 0.7), cloth.darkened(0.25))
	builder.add(_cylinder(0.02, 0.02, 1.4, 5), Vector3(-0.9, 0.5, -1.2), Vector3(0.0, 0.0, 1.0), Vector3.ONE, Color(0.6, 0.6, 0.6))
	return builder.commit()


## 卒塔婆：細長い木の板が、何本も傾いて立つ
static func grave_boards() -> ArrayMesh:
	var rng := _rng(312)
	var builder := MeshBuilder.new()
	for i in 6:
		var pos := Vector3(i * 0.28 - 0.7, 0.0, rng.randf_range(-0.15, 0.15))
		var height := rng.randf_range(1.2, 1.8)
		var rot := Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.15, 0.15))
		builder.add(_box(), pos + Vector3.UP * height * 0.5, rot, Vector3(0.12, height, 0.02), _tint(Color(0.52, 0.45, 0.35), rng, 0.2))
		builder.add(_box(), pos + Vector3.UP * (height - 0.08), rot, Vector3(0.13, 0.06, 0.025), Color(0.2, 0.16, 0.12))
	builder.add(_box(), Vector3(0.0, 0.12, 0.25), Vector3.ZERO, Vector3(0.5, 0.25, 0.3), Color(0.45, 0.45, 0.43))  # 石の台
	return builder.commit()
