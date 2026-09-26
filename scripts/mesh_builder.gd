class_name MeshBuilder
extends RefCounted
## 小さな形（箱・円柱・球など）をたくさん、色つきで 1 つのメッシュにまとめる。
## 形ごとに別のメッシュにすると GPU のバッファが増えすぎて、数千個で描けなくなる（Vulkan の上限）。
## 置き物やアイテムは、これで 1 つにまとめてから置く。色は頂点の色になるので、
## Psx.vertex_material() か、vertex_color_use_as_albedo の素材で描く。

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()


## Node3D と同じ並び（回転 → 大きさ）で置く
func add(mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO, part_scale := Vector3.ONE, color := Color.WHITE) -> MeshBuilder:
	return add_transformed(mesh, Transform3D(Basis.from_euler(rot) * Basis.from_scale(part_scale), pos), color)


func add_transformed(mesh: Mesh, xform: Transform3D, color := Color.WHITE) -> MeshBuilder:
	if mesh is PrimitiveMesh:
		CreatureKit.coarsen(mesh)
	var arrays := (mesh as PrimitiveMesh).get_mesh_arrays() if mesh is PrimitiveMesh else mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var indices = arrays[Mesh.ARRAY_INDEX]
	var base := _vertices.size()
	var normal_basis := xform.basis.inverse().transposed()
	for i in points.size():
		_vertices.append(xform * points[i])
		_normals.append((normal_basis * normals[i]).normalized() if i < normals.size() else Vector3.UP)
		_colors.append(color)
		_uvs.append(uvs[i] if uvs != null and i < uvs.size() else Vector2.ZERO)
	if indices == null or indices.is_empty():
		indices = PackedInt32Array(range(points.size()))
	var flip := xform.basis.determinant() < 0.0  # 裏返した形は、三角形の向きも逆にする
	for t in range(0, indices.size(), 3):
		_indices.append(base + indices[t])
		_indices.append(base + (indices[t + 2] if flip else indices[t + 1]))
		_indices.append(base + (indices[t + 1] if flip else indices[t + 2]))
	return self


func is_empty() -> bool:
	return _vertices.is_empty()


func commit() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## まとめたメッシュを parent に置く
func instance(parent: Node3D, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = commit()
	node.material_override = material
	parent.add_child(node)
	return node
