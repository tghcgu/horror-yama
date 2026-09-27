class_name Combat
extends RefCounted
## ナタで叩く・物を投げつけるときの、当たり判定と手ごたえ（血しぶき・火花）をまとめたもの。
## 獣や化け物は、hit_center() と hit_radius() があれば、それで体の大きさを知る（なければ、足もとから少し上の小さな球）。
## 当たった相手が hit(傷, 攻撃した者) を持っていれば傷を負わせ、なければ scare(どこから) でひるませる。
## お札やお守りを投げつけると、霊（グループ spirits）は消える。
## 化け物（獣でも練習台でもないもの）には、ナタも拳も投げた物も、あまり効かない（傷は MONSTER_RESIST 倍、ひるむのもときどき）。

const DEFAULT_RADIUS := 0.45
const MONSTER_RESIST := 0.25  # 化け物に与えられる傷の割合
const MONSTER_FLINCH := 0.3   # 化け物がひるむ（離れていく）確率


## 体の真ん中（ここをめがけて叩く）
static func body_center(body: Node3D) -> Vector3:
	if body.has_method("hit_center"):
		return body.call("hit_center")
	return body.global_position + Vector3.UP * 0.6


## 体の大きさ（真ん中からの半径）
static func body_radius(body: Node3D) -> float:
	if body.has_method("hit_radius"):
		return body.call("hit_radius")
	return DEFAULT_RADIUS


## 叩く・投げつけられる相手か
static func can_strike(body: Node3D) -> bool:
	return body != null and body.is_visible_in_tree() and (body.has_method("hit") or body.has_method("scare"))


## 相手に当てる。holy なら（お札やお守り）、霊は消える。当たった所に、血しぶきや火花を散らす
static func strike(target: Node3D, damage: float, attacker: Node3D, point: Vector3, holy := false) -> void:
	var spirit := target.is_in_group(&"spirits")
	if holy and spirit and target.has_method("purify"):
		target.call("purify")
		spark(target, point, Color(0.95, 0.97, 1.0), 20)
		return
	if not target.is_in_group(&"huntable") and not target.is_in_group(&"practice"):
		# 化け物：物理の攻撃は、あまり効かない
		if target.has_method("hit"):
			target.call("hit", damage * MONSTER_RESIST, attacker)
		elif target.has_method("scare") and randf() < MONSTER_FLINCH:
			target.call("scare", attacker.global_position if attacker else point)
		spark(target, point, Color(0.75, 0.8, 0.9), 6)
		if attacker is Player and randf() < 0.5:
			(attacker as Player).message.emit("……効いていないようだ")
		return
	if target.has_method("hit"):
		target.call("hit", damage, attacker)
		spark(target, point, Color(0.55, 0.04, 0.03), 16)
	elif target.has_method("scare"):
		target.call("scare", attacker.global_position if attacker else point)
		spark(target, point, Color(0.75, 0.8, 0.9), 8)


## 一度だけはじける、小さな粒（血しぶき・火花・石のかけら）。散り終えたら消える
static func spark(near: Node, point: Vector3, color: Color, amount := 12) -> void:
	var scene := near.get_tree().current_scene
	if scene == null:
		return
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.55
	particles.direction = Vector3.UP
	particles.spread = 75.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 3.8
	particles.gravity = Vector3(0.0, -9.0, 0.0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	particles.mesh = Shared.get_or_make("combat_spark_%s" % color.to_html(), func() -> Mesh:
		var box := BoxMesh.new()
		box.size = Vector3.ONE * 0.045
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material = material
		return box)
	scene.add_child(particles)
	particles.global_position = point
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
