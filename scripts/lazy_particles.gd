class_name LazyParticles
extends Node3D
## 使うときだけ作る粒子。作っていない間は、GPU に何も作らない（置き物が多いと、GPU の上限に届くので）。
## 出し終わってしばらくたつと、また消す。near_distance を指定すると、プレイヤーがその距離より近くにいる間だけ
## 作っておく（湯気や泡のように、ずっと出ている粒子）。

var particles: CPUParticles3D  # いま作ってある粒子（なければ null）

var _make: Callable       # () -> CPUParticles3D
var _watch: Node3D        # 近さを測る相手（プレイヤー）
var _near_distance := 0.0
var _idle := 0.0
var _check := 0.0


func setup(make: Callable, watch: Node3D = null, near_distance := 0.0) -> void:
	_make = make
	_watch = watch
	_near_distance = near_distance


## 粒子を返す（まだなければ、いま作る）
func get_particles() -> CPUParticles3D:
	if particles == null:
		particles = _make.call()
		add_child(particles)
	_idle = 0.0
	return particles


## 出すか止めるか。止めるだけなら、わざわざ作らない
func set_emitting(on: bool) -> void:
	if on:
		get_particles().emitting = true
	elif particles:
		particles.emitting = false


func release() -> void:
	if particles:
		particles.queue_free()
		particles = null


func _process(delta: float) -> void:
	if _near_distance > 0.0 and _watch:
		_check -= delta
		if _check <= 0.0:
			_check = 1.0
			var near := global_position.distance_to(_watch.global_position) < _near_distance
			if near and particles == null:
				get_particles()
			elif not near and particles:
				release()
		return
	# 出し終わって、粒子が消えるまで待ってから片づける
	if particles:
		_idle = 0.0 if particles.emitting else _idle + delta
		if _idle > particles.lifetime + 1.0:
			release()
