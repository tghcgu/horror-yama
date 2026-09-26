class_name Player
extends CharacterBody3D
## 一人称の移動と、PEAK風のクライミング。
## 壁を見ながら左クリック長押しでつかみ、WASDで壁の上を移動する。つかんでいる間はスタミナが減る。
## 急な斜面では足をとられて滑り落ちる。持ち物は 6 つの欄に入れ、選んで使ったり投げたりする。

signal died
signal hurt
signal chilled
signal restart_requested
signal items_changed
signal message(text: String)                              # 画面に出す短い知らせ（お守りが砕けた、など）
signal ward_requested(point: Vector3, normal: Vector3)    # お札を貼った
signal piton_driven(point: Vector3, normal: Vector3)      # ハーケンを打ち込んだ
signal rope_requested(top: Vector3, outward: Vector3, length: float)  # ロープを垂らした
signal item_thrown(kind: int, origin: Vector3, velocity: Vector3, activated: bool)  # アイテムを投げた・落とした

enum State { WALK, CLIMB, MANTLE }

# --- 地上の移動 ---
const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.0
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
const GROUND_ACCEL := 12.0
const AIR_ACCEL := 2.5
const MOUSE_SENSITIVITY := 0.0025

# --- 滑り落ちる斜面（法線の上向き成分がこれより小さい床では、足をとられて滑る） ---
const SLIP_NORMAL_Y := 0.87        # 約 30°
const SLIP_NORMAL_Y_SNOW := 0.91   # 雪の上は約 24° から滑る
const SLIP_NORMAL_Y_LOOSE := 0.98  # ガレ場や氷の上は、ほとんど平らでも滑る
const SLIDE_ACCEL := 16.0
const MAX_SLIDE_SPEED := 14.0
const SLIDE_CONTROL := 0.25        # 滑っている間に、自分で動ける割合

# --- クライミング ---
const CLIMB_SPEED := 2.2
const GRAB_REACH := 1.6
const WALL_MAX_NORMAL_Y := 0.87  # 法線の上向き成分がこれより大きい面は「床」なので、つかめない（滑る斜面はつかめる）
const WALL_GAP := 0.45           # 登っている間の、体の中心と壁の距離
const LUNGE_SPEED := 7.0         # 登りながら Space で飛びつくときの速さ
const LUNGE_TIME := 0.25
const MANTLE_TIME := 0.3         # 崖の上に乗り上がる時間
const GRAB_COOLDOWN := 0.3

# --- スタミナ ---
const MAX_STAMINA := 100.0
const HANG_DRAIN := 5.0
const CLIMB_DRAIN := 10.0
const SPRINT_DRAIN := 12.0
const LUNGE_COST := 25.0
const REGEN_RATE := 25.0
const REGEN_DELAY := 1.0
const MIN_GRAB_STAMINA := 5.0
const RECOVER_RATIO := 0.3  # 力尽きたあと、上限のこの割合まで回復すると再びつかめる
const OVERHANG_DRAIN := 1.6  # オーバーハング（上から覆いかぶさる壁）では疲れやすい
const ROPE_DRAIN := 0.25
const ICE_DRAIN := 2.5
const ICE_SLIP := 0.7        # 氷の壁では、つかんでいてもずり落ちる (m/s)

# --- 体の不調（PEAK 風）。どれもスタミナの上限を削る。全部合わせて上限がなくなると倒れる ---
const HUNGER_RATE := 0.1        # 空腹がたまる速さ（毎秒）。10 分で 60
const MAX_HUNGER := 90.0
const COLD_RATE := 0.7          # 雪山で体が冷える速さ（毎秒）。夜はこの 2 倍
const MAX_COLD := 60.0
const WARM_UP_RATE := 2.0       # 雪山の外で、体が温まる速さ（毎秒）
const FIRE_WARM_UP_RATE := 10.0 # たき火のそばで温まる速さ（毎秒）
const COLLAPSE_STAMINA := 5.0   # 上限がこれを下回ると倒れる
const RESPAWN_HUNGER := 15.0    # たき火から再開するとき、空腹が増える量

# --- 落下（少しの段差でもケガをし、10 m ほど落ちれば助からない） ---
const SAFE_FALL_SPEED := 10.0
const DEADLY_FALL_SPEED := 21.0
const INJURY_PER_SPEED := 5.5
const MAX_INJURY := 70.0
const KILL_Y := -30.0

# --- アイテム ---
const PITON_REGEN := 12.0     # ハーケンでぶら下がっている間の回復量（毎秒）
const BANDAGE_HEAL := 35.0
const ONIGIRI_STAMINA := 40.0
const ONIGIRI_FILL := 35.0     # おにぎりで減る空腹
const ONIGIRI_TIME := 15.0    # おにぎりの効果（疲れにくい）が続く秒数
const THROW_SPEED := 9.0
const EAT_TIME := 2.5         # 缶詰を食べ終わるまで動けない秒数
const AIM_DISTANCE := 2.6     # 拾う・調べるものに届く距離
const AIM_COS := 0.94

# --- 飛行モード（テスト用。F1 で切り替え。壁もすり抜ける） ---
const FLY_SPEED := 12.0
const FLY_FAST_SPEED := 40.0

# --- 沼 ---
const SINK_RATE := 0.22
const SINK_DEADLY := 1.1

const TERRAIN_LAYER := 1

# --- カメラ ---
const SPRINT_FOV_BONUS := 7.0
const BOB_HEIGHT := 0.035  # 歩いたときの上下の揺れ (m)
const STRIDE := 1.7        # 一歩の長さ (m)。揺れと足音の周期

var state := State.WALK
var stamina := MAX_STAMINA
var injury := 0.0  # ケガ。スタミナの上限がこの分だけ減る
var hunger := 0.0  # 空腹
var cold := 0.0    # 寒さ
var warm := false  # たき火のそばにいる（Main が毎フレーム決める）
var in_snow := false  # 雪山にいる（Main が毎フレーム決める）
var night := false    # 夜（Main が毎フレーム決める）
var exhausted := false
var can_grab := false
var frozen := false  # 死亡・捕獲の演出中は操作を止める
var clipped := false  # ハーケンでぶら下がって休んでいる
var sliding := false  # 急な斜面で足をとられている
var climb_input := Vector2.ZERO  # 登っている間の入力（x: 右, y: 上）。手の動きに使う
var inventory := Inventory.new()
var boost_time := 0.0  # おにぎり・栄養ドリンクの効果の残り時間（疲れにくい）
var effects := {}      # 効いているアイテムや状態の名前 → 残り秒数
var bell_ringing := false
var compass_target := Vector3.INF  # 方位磁石が指す、次のたき火（Main が決める）
var aimed: Node3D                  # 見ている、拾える物・調べられる物
var sink := 0.0                    # 沼に沈んだ深さ (m)
var held_by: Node3D                # 化け物につかまれて、動けない
var struggle := 0.0                # つかまれている間にもがいた量
var climb_surface := ""            # いまつかんでいる面（"rock" / "rope" / "ice" / "crumbly"）
var flying := false                # テスト用の飛行モード

# ギミックや化け物が、毎フレームかける影響（次のフレームの動きに使い、使ったら元に戻す）
var zone_slow := 1.0          # 歩く速さの倍率
var zone_slippery := false    # ガレ場・氷の上（ほとんど平らでも滑る）
var zone_bog := false         # 沼の中
var zone_climb_drain := 1.0   # 登っている間のスタミナの減り方の倍率
var zone_climb_slow := 1.0    # 登る速さの倍率（足をつかまれている）
var zone_push := Vector3.ZERO # 風などで押し流される速さ (m/s)

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
var _slide_velocity := Vector3.ZERO
var _stuck_time := 0.0  # 罠に足を挟まれている
var _eating := 0.0
var _safe_landing := false

# 今のフレームで使う、ギミックの影響
var _slow := 1.0
var _slippery := false
var _bog := false
var _climb_drain := 1.0
var _climb_slow := 1.0
var _push := Vector3.ZERO

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _headlamp: SpotLight3D = $Head/Camera3D/Headlamp
@onready var _hands: PlayerHands = $Hands
@onready var _sounds: PlayerSounds = $Sounds


func _ready() -> void:
	add_to_group(&"players")
	floor_max_angle = deg_to_rad(46.0)
	_hands.gripped.connect(_on_hand_gripped)
	_camera.fov = Settings.fov


func max_stamina() -> float:
	return maxf(MAX_STAMINA - injury - hunger - cold, 0.0)


func get_camera() -> Camera3D:
	return _camera


func wall_normal() -> Vector3:
	return _wall_normal


func is_headlamp_on() -> bool:
	return _headlamp.visible


func is_lunging() -> bool:
	return _lunge_timer > 0.0


func has_effect(effect: String) -> bool:
	return effects.get(effect, 0.0) > 0.0


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
	hunger = 0.0
	cold = 0.0
	stamina = MAX_STAMINA
	exhausted = false
	frozen = false
	clipped = false
	boost_time = 0.0
	effects.clear()
	sink = 0.0
	held_by = null
	flying = false
	_safe_landing = false
	_stuck_time = 0.0
	_eating = 0.0
	_slide_velocity = Vector3.ZERO
	set_bell(false)
	inventory.clear()
	for kind: int in Items.STARTING:
		inventory.add(kind)
	items_changed.emit()


## たき火から再開する。ケガと寒さは治るが、空腹は増え、持ち物はそのまま
func respawn_at(pos: Vector3, yaw: float) -> void:
	var kept_hunger := minf(hunger + RESPAWN_HUNGER, MAX_HUNGER)
	var kept_items := inventory.snapshot()
	spawn_at(pos, yaw)
	hunger = kept_hunger
	inventory.restore(kept_items)
	stamina = max_stamina()
	items_changed.emit()


func set_headlamp(on: bool) -> void:
	_headlamp.visible = on


func set_bell(on: bool) -> void:
	bell_ringing = on
	_sounds.set_bell(on)


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
	held_by = null
	velocity = Vector3.ZERO
	died.emit()


# --- 敵やギミックから受けるダメージ ---

## 岩グモに噛まれた：ケガをして、壁から手を離してしまう
func bitten(amount: float) -> void:
	_add_injury(amount)
	add_shake(0.9)
	if state == State.CLIMB:
		_let_go()
		velocity = _wall_normal * 2.5


## 突き飛ばされた（のぞき・怪鳥・雪崩など）
func shove(impulse: Vector3) -> void:
	state = State.WALK
	clipped = false
	velocity = impulse
	_grab_cooldown = 0.8
	add_shake(1.0)


## 落石や体当たりを受けた：ケガをして、登っていれば壁からはがされる（ハーケンでぶら下がっていれば耐える）
func knock(impulse: Vector3, amount: float) -> void:
	_add_injury(amount)
	add_shake(1.0)
	if state == State.CLIMB and clipped:
		return
	shove(impulse)


## 白い人・鬼火に触れられた：体が一気に冷える
func chill(amount: float) -> void:
	cold = minf(cold + amount, MAX_COLD)
	stamina = minf(stamina, max_stamina() * 0.3)
	add_shake(0.7)
	chilled.emit()


## 影法師に触れられた：力が抜ける
func drain_all() -> void:
	stamina = 0.0
	exhausted = true
	_regen_wait = REGEN_DELAY * 2.0
	add_shake(0.8)
	hurt.emit()


## 罠に足を挟まれた
func trap(seconds: float, amount: float) -> void:
	_add_injury(amount)
	_stuck_time = seconds
	velocity = Vector3.ZERO
	add_shake(1.0)


## 噴気に吹き上げられた
func launch(speed: float, amount: float) -> void:
	_add_injury(amount)
	state = State.WALK
	clipped = false
	velocity.y = speed
	_grab_cooldown = 0.5
	add_shake(0.6)


## 化け物につかまれた（もがけば放される）。null で放す
func set_held(by: Node3D) -> void:
	held_by = by
	struggle = 0.0
	if by:
		state = State.WALK
		clipped = false
		velocity = Vector3.ZERO


## 木霊に持ち物をひとつ盗まれた。盗まれたアイテムの種類（なければ -1）
func steal_item() -> int:
	var filled: Array[int] = []
	for i in Items.SLOTS:
		if inventory.kinds[i] >= 0:
			filled.append(i)
	if filled.is_empty():
		return -1
	var kind := inventory.remove_from(filled.pick_random())
	items_changed.emit()
	return kind


# --- アイテム ---

## 持ち物に入れる。いっぱいなら false
func pick_up(kind: int) -> bool:
	if not inventory.add(kind):
		message.emit("持ち物がいっぱい")
		return false
	items_changed.emit()
	_sounds.play_pickup()
	return true


func use_selected() -> void:
	use_slot(inventory.selected)


## その種類のアイテムを（どの欄にあっても）使う
func use_item(kind: int) -> void:
	var slot := inventory.slot_of(kind)
	if slot >= 0:
		use_slot(slot)


func use_slot(slot: int) -> void:
	var kind := inventory.kinds[slot]
	if frozen or kind < 0 or held_by:
		return
	var result := _apply_item(kind)
	if result == 0:
		return
	if result == 1:
		inventory.remove_from(slot)
	items_changed.emit()
	_sounds.play_item()


## 選んでいるアイテムを、見ている方向へ投げる（そのまま転がる物として落ちる）
func throw_selected() -> void:
	if frozen or held_by or inventory.selected_kind() < 0:
		return
	var kind := inventory.remove_from(inventory.selected)
	_throw(kind, false)
	items_changed.emit()


func _throw(kind: int, activated: bool) -> void:
	var forward := -_camera.global_transform.basis.z
	var origin := _camera.global_position + forward * 0.5 - Vector3.UP * 0.15
	item_thrown.emit(kind, origin, forward * THROW_SPEED + Vector3.UP * 2.0 + velocity * 0.5, activated)
	_sounds.play_item()


## アイテムの効き目。0 = 使えなかった、1 = 使ってなくなった、2 = 使ったがなくならない
func _apply_item(kind: int) -> int:
	match kind:
		Items.Kind.PITON:
			return 1 if _drive_piton() else 0
		Items.Kind.BANDAGE:
			if injury <= 0.0:
				return 0
			injury = maxf(injury - BANDAGE_HEAL, 0.0)
		Items.Kind.ONIGIRI:
			_eat(ONIGIRI_FILL, ONIGIRI_STAMINA)
			boost_time = maxf(boost_time, ONIGIRI_TIME)
		Items.Kind.OFUDA:
			if state == State.CLIMB:
				var wall := _ray(global_position + Vector3.UP, global_position + Vector3.UP - _wall_normal * 1.5)
				if not wall.is_empty():
					ward_requested.emit(wall.position, wall.normal)
					return 1
			ward_requested.emit(global_position, Vector3.UP)
		Items.Kind.ROPE:
			return 1 if _hang_rope() else 0
		Items.Kind.FLARE, Items.Kind.FIRECRACKER, Items.Kind.SALT:
			_throw(kind, true)
		Items.Kind.BELL:
			set_bell(not bell_ringing)
			message.emit("鈴を鳴らしている" if bell_ringing else "鈴を止めた")
			return 2
		Items.Kind.HAND_WARMER:
			cold = 0.0
			effects["warmer"] = 90.0
		Items.Kind.THERMOS:
			cold = maxf(cold - 30.0, 0.0)
			_eat(10.0, 30.0)
		Items.Kind.CHOCOLATE:
			_eat(15.0, 25.0)
		Items.Kind.CANNED:
			if not is_on_floor() or state != State.WALK:
				message.emit("立ち止まらないと食べられない")
				return 0
			_eating = EAT_TIME
		Items.Kind.CHALK:
			effects["chalk"] = 60.0
		Items.Kind.CRAMPONS:
			effects["crampons"] = 120.0
		Items.Kind.FIRST_AID:
			if injury <= 0.0 and cold <= 0.0:
				return 0
			injury = 0.0
			cold = 0.0
		Items.Kind.OMAMORI:
			message.emit("お守りは、持っているだけで効く")
			return 0
		Items.Kind.MUSHROOM:
			_eat_mushroom()
		Items.Kind.ENERGY:
			stamina = max_stamina()
			exhausted = false
			boost_time = maxf(boost_time, 30.0)
			effects["crash"] = 30.0
		Items.Kind.COMPASS:
			effects["compass"] = 30.0
			return 2
	return 1


func _eat(fill: float, energy: float) -> void:
	hunger = maxf(hunger - fill, 0.0)
	stamina = minf(stamina + energy, max_stamina())
	exhausted = false


## 謎のキノコ：何が起きるかは食べてみるまでわからない
func _eat_mushroom() -> void:
	var roll := randf()
	if roll < 0.4:
		stamina = max_stamina()
		exhausted = false
		boost_time = maxf(boost_time, 20.0)
		message.emit("力がみなぎる")
	elif roll < 0.65:
		_add_injury(20.0)
		effects["poison"] = 15.0
		message.emit("……毒キノコだった")
	elif roll < 0.85:
		cold = 0.0
		effects["warmer"] = 60.0
		message.emit("体の芯から温まる")
	else:
		effects["vision"] = 20.0
		message.emit("景色がゆがむ")


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


## ロープを垂らす。登っている最中は頭の上の壁から、立っているときは目の前の崖のふちから
func _hang_rope() -> bool:
	var top := Vector3.ZERO
	var outward := Vector3.ZERO
	if state == State.CLIMB:
		var reach := global_position + Vector3.UP * 1.8
		var wall := _ray(reach, reach - _wall_normal * 1.5)
		if wall.is_empty():
			return false
		top = wall.position
		outward = _wall_normal
	else:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var previous := global_position
		var found := false
		for i in range(1, 12):
			var probe := global_position + forward * (i * 0.3)
			var ground := _ray(probe + Vector3.UP * 1.0, probe - Vector3.UP * 3.0)
			if ground.is_empty():
				found = true
				break
			previous = ground.position
		if not found:
			message.emit("ロープを垂らせる崖のふちがない")
			return false
		top = previous
		outward = forward
	var flat := Vector3(outward.x, 0.0, outward.z)
	if flat.length() < 0.2:
		return false
	flat = flat.normalized()
	var below := _ray(top + flat * (Rope.GAP + 0.1), top + flat * (Rope.GAP + 0.1) - Vector3.UP * Rope.MAX_LENGTH)
	var length := Rope.MAX_LENGTH if below.is_empty() else top.y - (below.position as Vector3).y
	if length < 1.5:
		return false
	rope_requested.emit(top, flat, length)
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
		return
	if click and click.pressed and (click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		inventory.select_next(-1 if click.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		items_changed.emit()
		return
	if event.is_action_pressed("fly"):
		set_flying(not flying)
	elif event.is_action_pressed("toggle_lamp"):
		_headlamp.visible = not _headlamp.visible
	elif event.is_action_pressed("restart"):
		restart_requested.emit()
	elif event.is_action_pressed("use_item"):
		use_selected()
	elif event.is_action_pressed("throw"):
		throw_selected()
	elif event.is_action_pressed("interact"):
		interact()
	else:
		for i in Items.SLOTS:
			if event.is_action_pressed("item_%d" % (i + 1)):
				inventory.selected = i
				items_changed.emit()


## 見ている物を拾う・調べる
func interact() -> void:
	if frozen or aimed == null or not is_instance_valid(aimed):
		return
	if aimed is Pickup:
		if pick_up((aimed as Pickup).kind):
			aimed.queue_free()
			aimed = null
	elif aimed.has_method("interact"):
		aimed.call("interact", self)


## 見ている物の説明（「E：拾う　おにぎり」など）。なければ空
func aim_hint() -> String:
	if aimed == null or not is_instance_valid(aimed):
		return ""
	if aimed is Pickup:
		return "E：拾う　" + Items.NAMES[(aimed as Pickup).kind]
	if aimed.has_method("interact_hint"):
		return aimed.call("interact_hint", self)
	return ""


## テスト用の飛行モード。飛んでいる間は壁をすり抜け、疲れず、腹も減らない。
## やめたあと最初の着地では、落下のケガをしない
func set_flying(on: bool) -> void:
	flying = on
	state = State.WALK
	clipped = false
	velocity = Vector3.ZERO
	_slide_velocity = Vector3.ZERO
	if on:
		held_by = null
		stamina = max_stamina()
		exhausted = false
	else:
		_safe_landing = true


func _process_fly(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var view := _camera.global_transform.basis
	var direction := view.x * input.x + view.z * input.y
	if Input.is_action_pressed("jump"):
		direction += Vector3.UP
	if Input.is_action_pressed("fly_down"):
		direction += Vector3.DOWN
	var speed := FLY_FAST_SPEED if Input.is_action_pressed("sprint") else FLY_SPEED
	velocity = direction.normalized() * speed if direction.length() > 0.01 else Vector3.ZERO
	global_position += velocity * delta  # 当たり判定なしで動く
	stamina = max_stamina()
	climb_input = Vector2.ZERO
	can_grab = false
	sliding = false


func _physics_process(delta: float) -> void:
	_take_zones()
	if flying:
		_process_fly(delta)
	elif held_by:
		_process_held(delta)
	elif not frozen:
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
	_update_aim()
	_update_camera(delta)


## ギミックが前のフレームにかけた影響を受け取り、次のフレームのために元に戻す
func _take_zones() -> void:
	_slow = zone_slow
	_slippery = zone_slippery
	_bog = zone_bog
	_climb_drain = zone_climb_drain
	_climb_slow = zone_climb_slow
	_push = zone_push
	zone_slow = 1.0
	zone_slippery = false
	zone_bog = false
	zone_climb_drain = 1.0
	zone_climb_slow = 1.0
	zone_push = Vector3.ZERO


## つかまれている間は動けない。Space や移動キーを連打するともがける
func _process_held(delta: float) -> void:
	velocity = Vector3.ZERO
	climb_input = Vector2.ZERO
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_left") \
			or Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("grab"):
		struggle += 1.0
		add_shake(0.25)
	_process_afflictions(delta)


func _process_walk(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _stuck_time > 0.0 or _eating > 0.0:
		input = Vector2.ZERO
	var direction := global_transform.basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	direction = direction.normalized()

	var on_floor := is_on_floor()
	_update_slide(on_floor, delta)
	var sprinting := on_floor and input.y < 0.0 and Input.is_action_pressed("sprint") and not exhausted and not sliding and not _bog
	_sprinting = sprinting
	climb_input = Vector2.ZERO
	var speed := (SPRINT_SPEED if sprinting else WALK_SPEED) * _slow * (SLIDE_CONTROL if sliding else 1.0)
	if _bog:
		speed *= 0.35
	var target := direction * speed + _slide_velocity + _push
	var weight := 1.0 - exp(-(GROUND_ACCEL if on_floor else AIR_ACCEL) * delta)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)
	if not on_floor:
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and _stuck_time <= 0.0 and _eating <= 0.0 and not _bog:
		velocity.y = JUMP_VELOCITY
	elif sliding:
		velocity.y = minf(velocity.y, _slide_velocity.y)
	if sprinting:
		_use_stamina(SPRINT_DRAIN * delta)

	var impact_speed := -velocity.y
	move_and_slide()
	if is_on_floor() and not on_floor:
		_on_landed(impact_speed)

	var hit := _grab_probe()
	can_grab = not hit.is_empty() and not exhausted and stamina >= MIN_GRAB_STAMINA and _grab_cooldown <= 0.0 \
		and _stuck_time <= 0.0 and _eating <= 0.0
	if can_grab and Input.is_action_pressed("grab"):
		_start_climb(hit.normal)


## 急な斜面では足をとられ、下り方向へどんどん速く滑っていく（アイゼンがあれば滑らない）
func _update_slide(on_floor: bool, delta: float) -> void:
	var limit := SLIP_NORMAL_Y_SNOW if in_snow else SLIP_NORMAL_Y
	if _slippery:
		limit = SLIP_NORMAL_Y_LOOSE
	if has_effect("crampons"):
		limit = -1.0
	var floor_normal := get_floor_normal() if on_floor else Vector3.UP
	sliding = on_floor and floor_normal.y < limit
	if sliding:
		var downhill := (Vector3.DOWN - floor_normal * floor_normal.dot(Vector3.DOWN)).normalized()
		var steep := clampf((limit - floor_normal.y) / 0.12, 0.35, 1.0)
		_slide_velocity = (_slide_velocity + downhill * SLIDE_ACCEL * steep * delta).limit_length(MAX_SLIDE_SPEED)
		if _slide_velocity.length() > 3.0:
			add_shake(0.08)
	elif on_floor:
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, 7.0 * delta)  # 勢いがついていると、ゆるい所でもすぐには止まれない
	else:
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, 4.0 * delta)


func _process_climb(delta: float) -> void:
	can_grab = true
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	climb_input = input
	_sprinting = false
	sliding = false
	_slide_velocity = Vector3.ZERO

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
	var surface_drain := _update_surface(hit.get("collider") as Node, delta)
	if state != State.CLIMB:
		return  # つかんでいた岩が崩れた

	var up := (Vector3.UP - _wall_normal * _wall_normal.y).normalized()
	var right := (-_wall_normal).cross(up).normalized()
	var move := (up * input.y + right * input.x) * CLIMB_SPEED * _climb_slow
	if climb_surface == "ice" and not has_effect("crampons"):
		move -= up * ICE_SLIP

	if Input.is_action_just_pressed("jump") and stamina > 0.0:
		_use_stamina(LUNGE_COST)
		_lunge_timer = LUNGE_TIME
		add_shake(0.3)
	if _lunge_timer > 0.0:
		_lunge_timer -= delta
		move += up * LUNGE_SPEED * _climb_slow

	# 壁との距離を保って張り付く
	var gap := (chest - (hit.position as Vector3)).dot(normal)
	move -= normal * clampf(gap - WALL_GAP, -0.5, 1.0) * 8.0
	velocity = move
	move_and_slide()
	var drain := (CLIMB_DRAIN if input != Vector2.ZERO else HANG_DRAIN) * _drain_multiplier() * surface_drain * _climb_drain
	if _wall_normal.y < -0.15:
		drain *= OVERHANG_DRAIN
	_use_stamina(drain * delta)

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


## つかんでいる面の種類を調べ、スタミナの減り方の倍率を返す。崩れる岩はここで傷んでいく
func _update_surface(collider: Node, delta: float) -> float:
	climb_surface = "rock"
	if collider == null:
		return 1.0
	if collider.is_in_group(Rope.GROUP):
		climb_surface = "rope"
		return ROPE_DRAIN
	if collider.is_in_group(&"ice"):
		climb_surface = "ice"
		return 1.0 if has_effect("crampons") else ICE_DRAIN
	if collider.is_in_group(&"crumbly"):
		climb_surface = "crumbly"
		if collider.call("strain", delta * (0.5 if has_effect("chalk") else 1.0)):
			_let_go()
			velocity = _wall_normal * 1.0
	return 1.0


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
	if _safe_landing:
		_safe_landing = false  # 飛行モードをやめたあとの着地
		return
	if speed > 4.0:
		var strength := clampf((speed - 4.0) / (DEADLY_FALL_SPEED - 4.0), 0.0, 1.0)
		_sounds.play_land(strength)
		add_shake(strength * 1.2)
	if speed >= DEADLY_FALL_SPEED:
		if inventory.remove(Items.Kind.OMAMORI):
			# お守りが身代わりになって砕ける
			items_changed.emit()
			_add_injury(40.0)
			add_shake(1.2)
			message.emit("お守りが砕けた")
		else:
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
	_stuck_time = maxf(_stuck_time - delta, 0.0)
	if _eating > 0.0:
		_eating -= delta
		if _eating <= 0.0:
			_eat(70.0, 20.0)
			message.emit("缶詰を食べ終えた")
	_process_effects(delta)
	_process_afflictions(delta)
	if clipped:
		stamina = minf(stamina + PITON_REGEN * delta, max_stamina())
	elif state == State.WALK and is_on_floor() and _regen_wait <= 0.0 and not sliding:
		stamina = minf(stamina + REGEN_RATE * delta * (0.4 if has_effect("spores") else 1.0), max_stamina())
	if exhausted and stamina >= max_stamina() * RECOVER_RATIO:
		exhausted = false


## アイテムや状態の効き目を減らしていく。栄養ドリンクが切れると、どっと腹が減る
func _process_effects(delta: float) -> void:
	for effect: String in effects.keys():
		effects[effect] -= delta
		if effects[effect] <= 0.0:
			effects.erase(effect)
			if effect == "crash":
				hunger = minf(hunger + 20.0, MAX_HUNGER)
				message.emit("どっと腹が減った")
	if has_effect("poison"):
		stamina = maxf(stamina - 3.0 * delta, 0.0)
	# 沼：もがいても少しずつ沈んでいく。頭まで沈むと助からない
	if _bog:
		sink += SINK_RATE * delta
		if sink >= SINK_DEADLY:
			die()
	else:
		sink = maxf(sink - 0.8 * delta, 0.0)


## 空腹は時間とともにたまり、寒さは雪山で冷え、たき火や雪山の外で温まる。
## 全部合わせてスタミナの上限がなくなると、倒れる
func _process_afflictions(delta: float) -> void:
	hunger = minf(hunger + HUNGER_RATE * delta, MAX_HUNGER)
	if warm:
		cold = maxf(cold - FIRE_WARM_UP_RATE * delta, 0.0)
	elif has_effect("warmer"):
		cold = maxf(cold - WARM_UP_RATE * delta, 0.0)
	elif in_snow:
		cold = minf(cold + COLD_RATE * (2.0 if night else 1.0) * delta, MAX_COLD)
	else:
		cold = maxf(cold - WARM_UP_RATE * delta, 0.0)
	stamina = minf(stamina, max_stamina())
	if max_stamina() < COLLAPSE_STAMINA:
		die()


## おにぎり・チョークの効果中は疲れにくい
func _drain_multiplier() -> float:
	var multiplier := 0.5 if boost_time > 0.0 else 1.0
	if has_effect("chalk"):
		multiplier *= 0.5
	return multiplier


func _use_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_wait = REGEN_DELAY
	if stamina <= 0.0:
		exhausted = true


## 見ている先の、拾える物・調べられる物を探す
func _update_aim() -> void:
	aimed = null
	if frozen:
		return
	var eye := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var best := AIM_COS
	for group in [Pickup.GROUP, &"interactables"]:
		for node: Node3D in get_tree().get_nodes_in_group(group):
			var to := node.global_position + Vector3.UP * 0.15 - eye
			var distance := to.length()
			if distance > AIM_DISTANCE or distance < 0.05:
				continue
			var facing := forward.dot(to / distance)
			if facing > best:
				best = facing
				aimed = node


## 歩いたときの揺れ、疲れたときの震え、衝撃の揺れ、ダッシュ時の視野の広がり、沼に沈む高さ
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
	offset.y -= sink

	var roll := 0.0
	if _shake > 0.0:
		var t := _time * 35.0
		offset += Vector3(_shake_noise.get_noise_2d(t, 0.0), _shake_noise.get_noise_2d(0.0, t), 0.0) * _shake * 0.12
		roll = _shake_noise.get_noise_2d(t, t) * _shake * 0.05
		_shake = maxf(_shake - delta * 2.0, 0.0)
	# 毒やキノコの幻覚で、視界がぐらぐら揺れる
	if has_effect("poison") or has_effect("vision") or has_effect("spores"):
		roll += sin(_time * 1.3) * 0.06
		offset.x += sin(_time * 0.9) * 0.04
	_camera.position = offset
	_camera.rotation.z = roll
	var target_fov := Settings.fov + (SPRINT_FOV_BONUS if _sprinting else 0.0)
	if has_effect("vision"):
		target_fov += sin(_time * 2.0) * 12.0
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
