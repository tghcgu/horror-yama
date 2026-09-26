class_name BonePoser
extends RefCounted
## Blender で作ったモデルの骨を、コードから曲げるための道具。
## 角度は体の向き（モデルは -Z が正面）を基準にした (X, Y, Z) まわりの回転で、休めの姿勢からの差で指定する。
##   X まわり：前後に振る（プラスで腕や脚が前へ上がる）
##   Y まわり：ひねる
##   Z まわり：横に振る

var skeleton: Skeleton3D

var _bones := {}    # 名前 → 番号
var _rest := {}     # 番号 → 休めの姿勢の回転
var _axes := {}     # 番号 → [X, Y, Z] 軸（親の骨から見た向き）
var _current := {}  # 番号 → いまの角度
var _target := {}   # 番号 → 目標の角度


func _init(target_skeleton: Skeleton3D) -> void:
	skeleton = target_skeleton
	for i in skeleton.get_bone_count():
		_bones[skeleton.get_bone_name(i)] = i
		_rest[i] = skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		var parent := skeleton.get_bone_parent(i)
		var parent_basis := skeleton.get_bone_global_rest(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var inverse := parent_basis.inverse()
		_axes[i] = [(inverse * Vector3.RIGHT).normalized(), (inverse * Vector3.UP).normalized(), (inverse * Vector3.BACK).normalized()]
		_current[i] = Vector3.ZERO
		_target[i] = Vector3.ZERO


func has_bone(bone_name: String) -> bool:
	return _bones.has(bone_name)


func set_target(bone_name: String, angles: Vector3) -> void:
	_target[_bones[bone_name]] = angles


## 目標の角度へ、すぐに切り替える
func snap_all() -> void:
	for i in _current:
		_current[i] = _target[i]
		_apply(i, _current[i])


## 目標の角度へ近づける。speed が大きいほど一気に曲がる（カクカクした動きになる）
func update(delta: float, speed: float) -> void:
	var weight := 1.0 - exp(-speed * delta)
	for i in _current:
		_current[i] = (_current[i] as Vector3).lerp(_target[i], weight)
		_apply(i, _current[i])


## 骨（頭など）の正面を、指定した場所へ向ける。体のほかの骨を曲げたあとで呼ぶ
func aim(bone_name: String, world_point: Vector3, roll := 0.0) -> void:
	var i: int = _bones[bone_name]
	var origin := skeleton.get_bone_global_pose(i).origin
	var direction := skeleton.global_transform.affine_inverse() * world_point - origin
	if direction.length() < 0.01:
		return
	direction = direction.normalized()
	var up := Vector3.UP if absf(direction.y) < 0.98 else Vector3.BACK
	var facing := Basis.looking_at(direction, up) * Basis(Vector3.FORWARD, roll)
	var desired := facing * skeleton.get_bone_global_rest(i).basis.orthonormalized()
	var parent := skeleton.get_bone_parent(i)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	skeleton.set_bone_pose_rotation(i, (parent_basis.inverse() * desired).get_rotation_quaternion())


func world_transform(bone_name: String) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_bones[bone_name])


func _apply(i: int, angles: Vector3) -> void:
	var axes: Array = _axes[i]
	var rotation := Quaternion(axes[0], angles.x) * Quaternion(axes[1], angles.y) * Quaternion(axes[2], angles.z) * (_rest[i] as Quaternion)
	skeleton.set_bone_pose_rotation(i, rotation)
