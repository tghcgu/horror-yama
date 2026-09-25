class_name Player
extends CharacterBody3D
## 一人称の移動と、PEAK風のクライミング。
## 壁を見ながら左クリック長押しでつかみ、WASDで壁の上を移動する。つかんでいる間はスタミナが減る。

signal died
signal hurt
signal chilled
signal restart_requested
signal items_changed
signal ward_requested(point: Vector3, normal: Vector3)   # お札を貼った
signal piton_driven(point: Vector3, normal: Vector3)     # ハーケンを打ち込んだ

enum State { WALK, CLIMB, MANTLE }

# --- 地上の移動 ---
const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.0
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
const GROUND_ACCEL := 12.0
const AIR_ACCEL := 2.5
const MOUSE_SENSITIVITY := 0.0025

# --- クライミング ---
const CLIMB_SPEED := 2.2
const GRAB_REACH := 1.6
const WALL_MAX_NORMAL_Y := 0.75  # 法線の上向き成分がこれより大きい面は「床」なので、つかめない
const WALL_GAP := 0.45           # 登っている間の、体の中心と壁の距離
const LUNGE_SPEED := 7.0         # 登りながら Space で飛びつくときの速さ
const LUNGE_TIME := 0.25
const MANTLE_TIME := 0.3         # 崖の上に乗り上がる時間
const GRAB_COOLDOWN := 0.3

# --- スタミナ ---
const MAX_STAMINA := 100.0
const HANG_DRAIN := 5.0
const CLIMB_DRAIN := 9.0
const SPRINT_DRAIN := 12.0
const LUNGE_COST := 25.0
const REGEN_RATE := 30.0
const REGEN_DELAY := 0.8
const MIN_GRAB_STAMINA := 5.0
const RECOVER_RATIO := 0.3  # 力尽きたあと、上限のこの割合まで回復すると再びつかめる
const COLD_DRAIN := 1.3     # 雪原では寒さで疲れやすい

# --- 落下 ---
const SAFE_FALL_SPEED := 13.0
const DEADLY_FALL_SPEED := 26.0
const INJURY_PER_SPEED := 4.0
const MAX_INJURY := 70.0
const KILL_Y := -30.0

# --- アイテム ---
const PITON_REGEN := 12.0     # ハーケンでぶら下がっている間の回復量（毎秒）
const BANDAGE_HEAL := 35.0
const ONIGIRI_STAMINA := 50.0
const ONIGIRI_TIME := 15.0    # おにぎりの効果（疲れにくい）が続く秒数

const TERRAIN_LAYER := 1

# --- カメラ ---
const SPRINT_FOV_BONUS := 7.0
const BOB_HEIGHT := 0.035  # 歩いたときの上下の揺れ (m)
const STRIDE := 1.7        # 一歩の長さ (m)。揺れと足音の周期

var state := State.WALK
var stamina := MAX_STAMINA
var injury := 0.0  # ケガ。スタミナの上限がこの分だけ減る
var exhausted := false
var can_grab := false
var frozen := false  # 死亡・捕獲の演出中は操作を止める
var clipped := false  # ハーケンでぶら下がって休んでいる
var climb_input := Vector2.ZERO  # 登っている間の入力（x: 右, y: 上）。手の動きに使う
var items: Array[int] = []
var boost_time := 0.0  # おにぎりの効果の残り時間

var _wall_normal := Vector3.BACK
var _lunge_timer := 0.0
var _mantle_timer := 0.0
var _mantle_dir := Vector3.ZERO
var _grab_cooldown := 0.0
var _regen_wait := 0.0
var _sprinting := false
var _shake := 0.0
var _bob_time := 0.0
var _time := 0.0
var _shake_noise := FastNoiseLite.new()

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _headlamp: SpotLight3D = $Head/Camera3D/Headlamp
@onready var _hands: PlayerHands = $Hands
@onready var _sounds: PlayerSounds = $Sounds


func _ready() -> void:
	floor_max_angle = deg_to_rad(46.0)
	_hands.gripped.connect(_on_hand_gripped)
	_camera.fov = Settings.fov


func max_stamina() -> float:
	return MAX_STAMINA - injury


func get_camera() -> Camera3D:
	return _camera


func wall_normal() -> Vector3:
	return _wall_normal


func is_headlamp_on() -> bool:
	return _headlamp.visible


## 0（まだ平気）〜 1（限界）。手や画面の震え、息づかいに使う
func fatigue() -> float:
	if exhausted:
		return 1.0
	return clampf((0.35 - stamina / MAX_STAMINA) / 0.35, 0.0, 1.0)


## 画面を揺らす（0〜1くらい。大きいほど強い）
func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func spawn_at(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation.y = yaw
	_head.rotation.x = 0.0
	velocity = Vector3.ZERO
	state = State.WALK
	injury = 0.0
	stamina = MAX_STAMINA
	exhausted = false
	frozen = false
	clipped = false
	boost_time = 0.0
	items.assign(Items.STARTING)
	items_changed.emit()


func set_headlamp(on: bool) -> void:
	_headlamp.visible = on


## ヘッドライトがチカチカして消える（捕まった瞬間の演出）
func flicker_out() -> void:
	for i in 6:
		_headlamp.visible = i % 2 == 1
		await get_tree().create_timer(0.05 + randf() * 0.06).timeout
	_headlamp.visible = false


## 捕まったときなどに、強制的にその方向を向かせる
func face_point(point: Vector3) -> void:
	var to := point - _camera.global_position
	rotation.y = atan2(-to.x, -to.z)
	_head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func die() -> void:
	if frozen:
		return
	frozen = true
	velocity = Vector3.ZERO
	died.emit()


# --- 敵から受けるダメージ ---

## 岩グモに噛まれた：ケガをして、壁から手を離してしまう
func bitten(amount: float) -> void:
	_add_injury(amount)
	add_shake(0.9)
	if state == State.CLIMB:
		_let_go()
		velocity = _wall_normal * 2.5


## のぞきに突き飛ばされた
func shove(impulse: Vector3) -> void:
	state = State.WALK
	clipped = false
	velocity = impulse
	_grab_cooldown = 0.8
	add_shake(1.0)


## 白い人に触れられた：体が凍えてケガをする
func chill(amount: float) -> void:
	_add_injury(amount, false)
	stamina = minf(stamina, max_stamina() * 0.3)
	add_shake(0.7)
	chilled.emit()


# --- アイテム ---

func pick_up(kind: int) -> void:
	items[kind] += 1
	items_changed.emit()
	_sounds.play_pickup()


func use_item(kind: int) -> void:
	if frozen or items[kind] <= 0:
		return
	var used := false
	match kind:
		Items.Kind.PITON:
			used = _drive_piton()
		Items.Kind.BANDAGE:
			used = injury > 0.0
			injury = maxf(injury - BANDAGE_HEAL, 0.0)
		Items.Kind.ONIGIRI:
			stamina = minf(stamina + ONIGIRI_STAMINA, max_stamina())
			exhausted = false
			boost_time = ONIGIRI_TIME
			used = true
		Items.Kind.OFUDA:
			used = true
			if state == State.CLIMB:
				var wall := _ray(global_position + Vector3.UP, global_position + Vector3.UP - _wall_normal * 1.5)
				if not wall.is_empty():
					ward_requested.emit(wall.position, wall.normal)
				else:
					ward_requested.emit(global_position, Vector3.UP)
			else:
				ward_requested.emit(global_position, Vector3.UP)
	if used:
		items[kind] -= 1
		items_changed.emit()
		_sounds.play_item()


## 登っている最中なら、目の前の壁にハーケンを打ち込んでぶら下がる
func _drive_piton() -> bool:
	if state != State.CLIMB or clipped:
		return false
	var chest := global_position + Vector3.UP * 1.3
	var wall := _ray(chest, chest - _wall_normal * 1.5)
	if wall.is_empty():
		return false
	clipped = true
	velocity = Vector3.ZERO
	piton_driven.emit(wall.position, wall.normal)
	add_shake(0.2)
	return true


func _add_injury(amount: float, show_hurt := true) -> void:
	injury = minf(injury + amount, MAX_INJURY)
	stamina = minf(stamina, max_stamina())
	if show_hurt:
		hurt.emit()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not frozen:
			var sensitivity := MOUSE_SENSITIVITY * Settings.mouse_sensitivity
			rotate_y(-motion.relative.x * sensitivity)
			_head.rotate_x(-motion.relative.y * sensitivity)
			_head.rotation.x = clampf(_head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
		return

	var click := event as InputEventMouseButton
	if click and click.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("toggle_lamp"):
		_headlamp.visible = not _headlamp.visible
	elif event.is_action_pressed("restart"):
		restart_requested.emit()
	else:
		for i in Items.COUNT:
			if event.is_action_pressed("item_%d" % (i + 1)):
				use_item(i)


func _physics_process(delta: float) -> void:
	if not frozen:
		match state:
			State.WALK:
				_process_walk(delta)
			State.CLIMB:
				_process_climb(delta)
			State.MANTLE:
				_process_mantle(delta)
		_process_stamina(delta)
		if global_position.y < KILL_Y:
			die()
	_update_camera(delta)


func _process_walk(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := global_transform.basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	direction = direction.normalized()

	var on_floor := is_on_floor()
	var sprinting := on_floor and input.y < 0.0 and Input.is_action_pressed("sprint") and not exhausted
	_sprinting = sprinting
	climb_input = Vector2.ZERO
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	var weight := 1.0 - exp(-(GROUND_ACCEL if on_floor else AIR_ACCEL) * delta)
	velocity.x = lerpf(velocity.x, direction.x * speed, weight)
	velocity.z = lerpf(velocity.z, direction.z * speed, weight)
	if not on_floor:
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	if sprinting:
		_use_stamina(SPRINT_DRAIN * delta)

	var impact_speed := -velocity.y
	move_and_slide()
	if is_on_floor() and not on_floor:
		_on_landed(impact_speed)

	var hit := _grab_probe()
	can_grab = not hit.is_empty() and not exhausted and stamina >= MIN_GRAB_STAMINA and _grab_cooldown <= 0.0
	if can_grab and Input.is_action_pressed("grab"):
		_start_climb(hit.normal)


func _process_climb(delta: float) -> void:
	can_grab = true
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	climb_input = input
	_sprinting = false

	# ハーケンでぶら下がっている間は、手を離しても落ちない。動くと外れる
	if clipped:
		velocity = Vector3.ZERO
		if input != Vector2.ZERO or Input.is_action_just_pressed("jump"):
			clipped = false
		else:
			return
	if not Input.is_action_pressed("grab") or exhausted:
		_let_go()
		return

	# 胸の前の壁を探し直して、壁の向きを更新する
	var chest := global_position + Vector3.UP
	var hit := _ray(chest, chest - _wall_normal * (WALL_GAP + 1.0))
	if hit.is_empty():
		if input.y > 0.0:
			_start_mantle()
		else:
			_let_go()
		return
	var normal: Vector3 = hit.normal
	if normal.y > WALL_MAX_NORMAL_Y:
		_start_mantle()
		return
	_wall_normal = _wall_normal.slerp(normal, 0.3).normalized()

	var up := (Vector3.UP - _wall_normal * _wall_normal.y).normalized()
	var right := (-_wall_normal).cross(up).normalized()
	var move := (up * input.y + right * input.x) * CLIMB_SPEED

	if Input.is_action_just_pressed("jump") and stamina > 0.0:
		_use_stamina(LUNGE_COST)
		_lunge_timer = LUNGE_TIME
		add_shake(0.3)
	if _lunge_timer > 0.0:
		_lunge_timer -= delta
		move += up * LUNGE_SPEED

	# 壁との距離を保って張り付く
	var gap := (chest - (hit.position as Vector3)).dot(normal)
	move -= normal * clampf(gap - WALL_GAP, -0.5, 1.0) * 8.0
	velocity = move
	move_and_slide()
	_use_stamina((CLIMB_DRAIN if input != Vector2.ZERO else HANG_DRAIN) * _drain_multiplier() * delta)

	if is_on_floor() and input.y < 0.0:
		state = State.WALK  # 下まで降りた
		return
	# 頭の前に壁がなくなったら、崖のてっぺんに着いたので乗り上がる
	if input.y > 0.0 or _lunge_timer > 0.0:
		var head := global_position + Vector3.UP * 1.9
		var top := _ray(head, head - _wall_normal * (WALL_GAP + 1.0))
		if top.is_empty() or (top.normal as Vector3).y > WALL_MAX_NORMAL_Y:
			_start_mantle()
			return
	if exhausted:
		_let_go()


func _process_mantle(delta: float) -> void:
	_mantle_timer -= delta
	velocity = Vector3.UP * 7.0 + _mantle_dir * 3.0
	move_and_slide()
	if _mantle_timer <= 0.0:
		state = State.WALK
		velocity = _mantle_dir * 2.0
		_grab_cooldown = GRAB_COOLDOWN


func _start_climb(normal: Vector3) -> void:
	state = State.CLIMB
	_wall_normal = normal
	velocity = Vector3.ZERO
	_lunge_timer = 0.0


func _start_mantle() -> void:
	state = State.MANTLE
	_mantle_timer = MANTLE_TIME
	var flat := Vector3(-_wall_normal.x, 0.0, -_wall_normal.z)
	_mantle_dir = flat.normalized() if flat.length() > 0.01 else -global_transform.basis.z


func _let_go() -> void:
	state = State.WALK
	clipped = false
	velocity = _wall_normal * 0.5
	_grab_cooldown = GRAB_COOLDOWN


func _on_landed(speed: float) -> void:
	if speed > 4.0:
		var strength := clampf((speed - 4.0) / (DEADLY_FALL_SPEED - 4.0), 0.0, 1.0)
		_sounds.play_land(strength)
		add_shake(strength * 1.2)
	if speed >= DEADLY_FALL_SPEED:
		die()
	elif speed > SAFE_FALL_SPEED:
		_add_injury((speed - SAFE_FALL_SPEED) * INJURY_PER_SPEED)
		add_shake(1.0)


func _on_hand_gripped() -> void:
	_sounds.play_grip()
	add_shake(0.04)


func _process_stamina(delta: float) -> void:
	_grab_cooldown = maxf(_grab_cooldown - delta, 0.0)
	_regen_wait = maxf(_regen_wait - delta, 0.0)
	boost_time = maxf(boost_time - delta, 0.0)
	if clipped:
		stamina = minf(stamina + PITON_REGEN * delta, max_stamina())
	elif state == State.WALK and is_on_floor() and _regen_wait <= 0.0:
		stamina = minf(stamina + REGEN_RATE * delta, max_stamina())
	if exhausted and stamina >= max_stamina() * RECOVER_RATIO:
		exhausted = false


## おにぎりの効果中は疲れにくく、雪原では寒さで疲れやすい
func _drain_multiplier() -> float:
	var multiplier := 1.0
	if boost_time > 0.0:
		multiplier *= 0.5
	if Biomes.at(global_position.y) == Biomes.Id.SNOW:
		multiplier *= COLD_DRAIN
	return multiplier


func _use_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_wait = REGEN_DELAY
	if stamina <= 0.0:
		exhausted = true


## 歩いたときの揺れ、疲れたときの震え、衝撃の揺れ、ダッシュ時の視野の広がり
func _update_camera(delta: float) -> void:
	_time += delta
	var offset := Vector3.ZERO
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if state == State.WALK and is_on_floor() and not frozen:
		_bob_time += delta * horizontal * PI / STRIDE
		var amplitude := clampf(horizontal / WALK_SPEED, 0.0, 1.5)
		offset.y = sin(_bob_time * 2.0) * BOB_HEIGHT * amplitude
		offset.x = sin(_bob_time) * BOB_HEIGHT * 0.6 * amplitude
	if state == State.CLIMB and not frozen and not clipped:
		_shake = maxf(_shake, fatigue() * 0.2)

	var roll := 0.0
	if _shake > 0.0:
		var t := _time * 35.0
		offset += Vector3(_shake_noise.get_noise_2d(t, 0.0), _shake_noise.get_noise_2d(0.0, t), 0.0) * _shake * 0.12
		roll = _shake_noise.get_noise_2d(t, t) * _shake * 0.05
		_shake = maxf(_shake - delta * 2.0, 0.0)
	_camera.position = offset
	_camera.rotation.z = roll
	var target_fov := Settings.fov + (SPRINT_FOV_BONUS if _sprinting else 0.0)
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-6.0 * delta))


## カメラの正面に、つかめる急な面があればその情報を返す
func _grab_probe() -> Dictionary:
	var from := _camera.global_position
	var hit := _ray(from, from - _camera.global_transform.basis.z * GRAB_REACH)
	if hit.is_empty() or (hit.normal as Vector3).y > WALL_MAX_NORMAL_Y:
		return {}
	return hit


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, TERRAIN_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# 裏面に当たった場合でも、法線はレイの来た側を向ける
	if not hit.is_empty() and (hit.normal as Vector3).dot(to - from) > 0.0:
		hit.normal = -(hit.normal as Vector3)
	return hit
