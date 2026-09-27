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
const JUMP_VELOCITY := 7.2   # 約 1.4 m 跳べる（こぶや岩のすき間から抜け出せるように）
const GRAVITY := 18.0
const GROUND_ACCEL := 12.0
const AIR_ACCEL := 2.5
const MOUSE_SENSITIVITY := 0.0025

# --- 滑り落ちる斜面（法線の上向き成分がこれより小さい床では、足をとられて滑る） ---
const SLIP_NORMAL_Y := 0.77        # 約 40°
const SLIP_NORMAL_Y_SNOW := 0.85   # 雪の上は約 32° から滑る
const SLIP_NORMAL_Y_LOOSE := 0.97  # ガレ場や氷の上は、ほとんど平らでも滑る
const SLIP_DELAY := 0.25           # この時間、急な所に立ち続けたら滑り出す（細かいでこぼこでは滑らない）
const SLIDE_FRICTION := 24.0       # 歩ける所に戻ったら、すぐに止まる
const STEP_HEIGHT := 0.7           # この高さまでの段差は、歩いたまま乗り越える (m)
const VAULT_HEIGHT := 1.9          # 段差に向かって跳ぶと、この高さまでの縁なら、手をかけて乗り越える (m)
const STUCK_TIME := 0.45           # 進もうとしているのに、これだけ動けなければ、引っかかっている
# 挟まって動けなくなったら、近くの空いた所へ抜け出す（岩のすき間に宙づり・張り出しの下で登れない・くぼみにはまった）
const WEDGE_AIR_TIME := 0.5        # 宙に浮いたまま、落ちも進みもしない
const WEDGE_CLIMB_TIME := 1.0      # 登ろうとしているのに、進まない
const WEDGE_GROUND_TIME := 1.5     # 歩こうとしているのに、進まない（すべり落ちるくぼみから出られない、など）
const SLIDE_ACCEL := 16.0
const MAX_SLIDE_SPEED := 14.0
const SLIDE_CONTROL := 0.25        # 滑っている間に、自分で動ける割合

# --- クライミング ---
const CLIMB_SPEED := 2.7
const GRAB_REACH := 2.0
const SWING_REACH := 2.4        # ナタの届く距離（相手の体の表面まで, m）
const SWING_DAMAGE := 34.0      # ナタの一振りの傷
const SWING_INTERVAL := 0.42    # 左クリックを押しっぱなしで、振り続ける間隔 (s)
const SWING_TIRED := 1.7        # へとへとのときは、振るのが遅くなる（間隔の倍率）
const SWING_HIT_DELAY := 0.1    # 振り始めてから、刃が届くまで (s)
const SWING_STAMINA := 3.0      # 一振りで使うスタミナ
const HEAVY_EVERY := 3          # 続けて振ると、3 振りめごとに両手で振り下ろす重い一撃になる
const HEAVY_DAMAGE := 1.7       # 重い一撃の傷の倍率
const PUNCH_REACH := 1.4        # 素手で殴れる距離（相手の体の表面まで, m）
const PUNCH_DAMAGE := 9.0
const PUNCH_INTERVAL := 0.36
const PUNCH_STAMINA := 1.5
const WALL_MAX_NORMAL_Y := 0.8   # 法線の上向き成分がこれより大きい面は「床」なので、つかめない（歩けない斜面はつかめる）
const WALL_GAP := 0.45           # 登っている間の、体の中心と壁の距離
const LUNGE_SPEED := 8.5         # 登りながら Space で飛びつくときの速さ
const LUNGE_TIME := 0.25
const MANTLE_TIME := 0.3         # 崖の上に乗り上がる時間
const GRAB_COOLDOWN := 0.3

# --- スタミナ ---
const MAX_STAMINA := 100.0
const HANG_DRAIN := 4.0
const CLIMB_DRAIN := 8.5
const SPRINT_DRAIN := 12.0
const LUNGE_COST := 20.0
const REGEN_RATE := 25.0
const REGEN_DELAY := 1.0
const MIN_GRAB_STAMINA := 5.0
const RECOVER_RATIO := 0.3  # 力尽きたあと、上限のこの割合まで回復すると再びつかめる
const OVERHANG_DRAIN := 1.6  # オーバーハング（上から覆いかぶさる壁）では疲れやすい
const BODY_RADIUS := 0.35
const BODY_HEIGHT := 1.8
const CLIMB_RADIUS := 0.2    # 登っている間は体を細くして、岩のでっぱりに引っかからないようにする
const CLIMB_HEIGHT := 1.5
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

# --- 落下（4 m くらいまでは平気。それより高いとケガをし、16 m ほど落ちれば助からない） ---
const SAFE_FALL_SPEED := 12.5
const DEADLY_FALL_SPEED := 24.0
const INJURY_PER_SPEED := 3.5
const MAX_INJURY := 70.0
const KILL_Y := -30.0

# --- アイテム ---
const PITON_REGEN := 12.0     # ハーケンでぶら下がっている間の回復量（毎秒）
const BANDAGE_HEAL := 35.0
const ONIGIRI_STAMINA := 40.0
const ONIGIRI_FILL := 35.0     # おにぎりで減る空腹
const ONIGIRI_TIME := 15.0    # おにぎりの効果（疲れにくい）が続く秒数
const THROW_SPEED := 9.0       # 火をつけて投げる物の速さ
const THROW_MIN_SPEED := 5.0   # Q をちょんと押して投げたとき（ためはじめの強さが THROW_START_CHARGE）
const THROW_MAX_SPEED := 19.0  # Q を長押しして、ためきってから投げたとき
const THROW_START_CHARGE := 0.25
const THROW_CHARGE_TIME := 0.9 # ためきるまでの時間 (s)
const EAT_TIME := 2.5         # 缶詰を食べ終わるまで動けない秒数
const AIM_DISTANCE := 2.6     # 拾う・調べるものに届く距離
const AIM_COS := 0.94

# --- 飛行モード（テスト用。F1 で切り替え。壁もすり抜ける） ---
const FLY_SPEED := 12.0
const FLY_FAST_SPEED := 40.0

# --- エモート（T を押している間に選ぶ動き） ---
const EMOTES := ["wave", "cheer", "bow", "point", "sit", "dance", "shiver", "crouch"]
const EMOTE_NAMES := ["手をふる", "ばんざい", "おじぎ", "ゆびさす", "すわる", "おどる", "ぶるぶる", "しゃがむ"]
const EMOTE_TIMES := {"wave": 2.5, "cheer": 2.5, "bow": 2.0, "point": 2.5, "sit": -1.0, "dance": -1.0, "shiver": 3.0, "crouch": -1.0}

# --- 手を差し伸べて、崖を登ってくる仲間を引き上げる（G を押している間） ---
const REACH_RANGE := 1.7
const PULL_TIME := 0.9
const PULL_COST := 15.0
const HEAD_HEIGHT := 1.42

# --- 沼 ---
const SINK_RATE := 0.22
const SINK_DEADLY := 1.1

const TERRAIN_LAYER := 1
const BARRIER_LAYER := 32  # 見えない壁（山頂のたき火をともすまで、次の平地へ進めない）。ぶつかるが、つかんで登れはしない

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
var _swing_cooldown := 0.0
var _swing_hit_in := -1.0   # 刃が届くまでの時間（振っていなければ負）
var _swing_side := 1.0      # 振る向き（右から・左から、交互に）
var _swing_heavy := false
var _swing_combo := 0       # 続けて振った回数
var _swing_last := -10.0    # 最後に振った時刻 (s)
var throw_charge := -1.0    # Q をためている強さ（0〜1）。ためていなければ負
var last_struck: Node3D     # 最後に叩いた・投げ当てた相手（手なずけた犬が、いっしょに襲いかかる）
var punch_t := -1.0         # 素手で殴っている途中（0〜1）。殴っていなければ負（一人称の手が読む）
var punch_side := 1.0       # 殴る手（1 = 右手, -1 = 左手）
var _strike_reach := SWING_REACH
var _strike_damage := SWING_DAMAGE
var _blocked_time := 0.0    # 進もうとしているのに、動けていない時間
var _wedge_time := 0.0      # 挟まって動けていない時間
var _wedge_anchor := Vector3.ZERO
var stowed := false   # 手に持っていたアイテムを、しまっている（手ぶら）
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
var altitude_drain := 1.0          # 高い山ほど空気が薄く、登ると疲れやすい（Main がステージに合わせて決める）
var flying := false                # テスト用の飛行モード
var kill_height := KILL_Y          # これより下へ落ちたら助からない（地面を突き抜けたとき）
var controlled := true             # キーボードとマウスで動かす（false なら bot_input で動く。仲間のダミーや、あとでネットの向こうの仲間）
var bot_input := {}                # controlled でないときの入力（アクションの名前 → 押しているか）
var emote := ""                    # いまのエモート（なければ ""）
var reaching := false              # 手を差し伸べている

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
var _ground_normal := Vector3.UP  # 足元の傾き（細かいでこぼこを、ならして見る）
var _slip_time := 0.0
var _stuck_time := 0.0  # 罠に足を挟まれている
var _eating := 0.0
var _safe_landing := false
var _emote_time := 0.0
var _throw_time := 0.0
var _pull_from := Vector3.ZERO
var _pull_to := Vector3.ZERO
var _pull_time := -1.0

# 今のフレームで使う、ギミックの影響
var _slow := 1.0
var _slippery := false
var _bog := false
var _climb_drain := 1.0
var _climb_slow := 1.0
var _push := Vector3.ZERO

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
## ヘッドライト。カメラとまったく同じ位置に置くと、Godot では光が描かれない（円錐の頂点がカメラと重なるため）。
## なので、額の少し右上にずらしてある（player.tscn）
@onready var _headlamp: SpotLight3D = $Head/Camera3D/Headlamp
@onready var _hands: PlayerHands = $Hands
var _held: HeldItem  # 手に持っているアイテムの見た目
@onready var _sounds: PlayerSounds = $Sounds
@onready var _body_shape: CollisionShape3D = $CollisionShape3D
var _stuck_climb := 0.0  # 登ろうとしているのに動けていない時間


func _ready() -> void:
	add_to_group(&"players")
	_body_shape.shape = _body_shape.shape.duplicate()  # 体の形は、このプレイヤーだけのものにする（登るときに細くするため）
	collision_mask |= BARRIER_LAYER
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35  # でこぼこの下り坂でも、地面から浮かずに歩ける
	_hands.gripped.connect(_on_hand_gripped)
	if controlled:
		_held = HeldItem.new()
		_held.player = self
		_camera.add_child(_held)
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
	emote = ""
	reaching = false
	_pull_time = -1.0
	_stuck_time = 0.0
	_eating = 0.0
	_slide_velocity = Vector3.ZERO
	set_bell(false)
	inventory.clear()
	for kind: int in Items.STARTING:
		inventory.add(kind)
	items_changed.emit()


## 霧に巻かれて、pos へ連れ戻される（体の具合も持ち物もそのまま）
func return_to(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_slide_velocity = Vector3.ZERO
	state = State.WALK
	_set_slim(false)


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


## 投げた物が獣や化け物に当たった音
func play_hit_sound() -> void:
	_sounds.play_chop()


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
	if _held:
		_held.used()
	items_changed.emit()
	_sounds.play_item()


## 選んでいるアイテムを、見ている方向へ投げる（そのまま転がる物として落ちる）。
## charge（0〜1）が大きいほど、強く遠くへ投げる。獣や化け物に当たると、アイテムの重さに応じた傷を負わせる
func throw_selected(charge := THROW_START_CHARGE) -> void:
	if frozen or held_by or inventory.selected_kind() < 0:
		return
	var kind := inventory.remove_from(inventory.selected)
	_throw(kind, false, lerpf(THROW_MIN_SPEED, THROW_MAX_SPEED, clampf(charge, 0.0, 1.0)))
	items_changed.emit()


func _throw(kind: int, activated: bool, speed := THROW_SPEED) -> void:
	_throw_time = 0.4
	var forward := -_camera.global_transform.basis.z
	var origin := _camera.global_position + forward * 0.5 - Vector3.UP * 0.15
	var lift := lerpf(2.0, 1.0, clampf((speed - THROW_MIN_SPEED) / (THROW_MAX_SPEED - THROW_MIN_SPEED), 0.0, 1.0))
	item_thrown.emit(kind, origin, forward * speed + Vector3.UP * lift + velocity * 0.5, activated)
	if _held:
		_held.used()
	_sounds.play_swing(speed > 12.0)


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
		Items.Kind.NATA:
			_swing()
			return 0  # 振る動きと音は _swing が出す
		Items.Kind.BERRIES:
			_eat(10.0, 12.0)
		Items.Kind.CHESTNUT:
			_eat(20.0, 6.0)
		Items.Kind.RAW_MEAT:
			_eat(30.0, 10.0)
			if randf() < 0.4:
				effects["poison"] = 25.0
				message.emit("生の肉で、腹をこわした")
		Items.Kind.COOKED_MEAT:
			_eat(45.0, 25.0)
			boost_time = maxf(boost_time, ONIGIRI_TIME)
		Items.Kind.PELT:
			cold = 0.0
			effects["warmer"] = 300.0
			message.emit("毛皮を身にまとった")
		Items.Kind.YAKI_ONIGIRI:
			_eat(ONIGIRI_FILL * 1.3, ONIGIRI_STAMINA * 1.2)
			boost_time = maxf(boost_time, ONIGIRI_TIME * 2.0)
			cold = maxf(cold - 25.0, 0.0)
		Items.Kind.GRILLED_MUSHROOM:
			_eat(12.0, 10.0)
			cold = 0.0
			effects["warmer"] = 90.0
			message.emit("体の芯から温まる")
		Items.Kind.ROASTED_CHESTNUT:
			_eat(35.0, 12.0)
		Items.Kind.KUMANOI:
			injury = 0.0
			cold = 0.0
			stamina = max_stamina()
			exhausted = false
			boost_time = maxf(boost_time, 120.0)
			message.emit("熊の胆を飲んだ。体の奥から力がわいてくる")
	return 1


## ナタを振る（左クリックを押しっぱなしなら、振り続ける）。右から・左からと交互に振り、
## 続けて振ると 3 振りめごとに、両手で振り下ろす重い一撃になる。刃は振り始めて少ししてから届く（_swing_strike）。
## 一振りごとにスタミナを使い、へとへとになると振るのが遅くなる
func _swing() -> bool:
	if _swing_cooldown > 0.0 or state != State.WALK or frozen or held_by != null or _eating > 0.0 or emote != "":
		return false
	var now := Time.get_ticks_msec() / 1000.0
	_swing_combo = _swing_combo + 1 if now - _swing_last < SWING_INTERVAL * SWING_TIRED + 0.35 else 1
	_swing_last = now
	_swing_heavy = _swing_combo % HEAVY_EVERY == 0
	_swing_cooldown = SWING_INTERVAL * (SWING_TIRED if exhausted else 1.0) * (1.35 if _swing_heavy else 1.0)
	_swing_side = -_swing_side
	_swing_hit_in = SWING_HIT_DELAY * (1.6 if _swing_heavy else 1.0)
	_strike_reach = SWING_REACH
	_strike_damage = SWING_DAMAGE * (HEAVY_DAMAGE if _swing_heavy else 1.0)
	_use_stamina(SWING_STAMINA * (1.6 if _swing_heavy else 1.0))
	if _held:
		_held.swing(_swing_side, _swing_heavy, _swing_cooldown)
	_sounds.play_swing(_swing_heavy)
	return true


## 素手で殴る（手ぶらで左クリック。つかめる壁があるときは、壁をつかむほう）。左右の拳で交互に殴る
func _punch() -> bool:
	if _swing_cooldown > 0.0 or state != State.WALK or frozen or held_by != null or _eating > 0.0 or emote != "":
		return false
	_swing_cooldown = PUNCH_INTERVAL * (SWING_TIRED if exhausted else 1.0)
	_swing_heavy = false
	_swing_hit_in = SWING_HIT_DELAY
	_strike_reach = PUNCH_REACH
	_strike_damage = PUNCH_DAMAGE
	punch_side = -punch_side
	punch_t = 0.0
	_use_stamina(PUNCH_STAMINA)
	_sounds.play_swing(false)
	return true


## 目の前（届く所）に、殴れる獣や化け物がいるか
func _mob_in_reach(reach: float) -> bool:
	var eye := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	for group in [&"huntable", &"creatures"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == self or not Combat.can_strike(body):
				continue
			var to := Combat.body_center(body) - eye
			if to.length() < reach + Combat.body_radius(body) and forward.dot(to.normalized()) > 0.4:
				return true
	return false


## 刃（拳）が届いた：目の前の獣や化け物（体の大きさも考えて、いちばん正面の近いもの）に当てる。
## 何もいなければ、岩や木に当たって火花が散る
func _swing_strike() -> void:
	var eye := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var target: Node3D = null
	var best := INF
	for group in [&"huntable", &"creatures"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == self or not Combat.can_strike(body):
				continue
			var radius := Combat.body_radius(body)
			var to := Combat.body_center(body) - eye
			var distance := to.length()
			if distance > _strike_reach + radius or distance < 0.01:
				continue
			var facing := forward.dot(to / distance)
			if facing < (0.1 if distance < radius + 0.9 else 0.5):
				continue  # 体に触れるほど近ければ、少し横でも当たる
			var score := distance - radius - facing
			if score < best:
				best = score
				target = body
	var damage := _strike_damage
	if target:
		var center := Combat.body_center(target)
		var point := center + (eye - center).normalized() * minf(Combat.body_radius(target), center.distance_to(eye) * 0.5)
		Combat.strike(target, damage, self, point)
		last_struck = target
		_sounds.play_chop()
		add_shake(0.25 if _swing_heavy else 0.13)
		return
	var hit := _ray(eye, eye + forward * (_strike_reach + 0.2))
	if not hit.is_empty() and _strike_reach >= SWING_REACH:
		_sounds.play_ting()
		add_shake(0.08)
		Combat.spark(self, hit.position, Color(0.95, 0.85, 0.55), 8)


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
		# 頭の上の岩肌を探す（丸く出っ張った岩でも見つかるように、高さを変えて、少し長めに）
		var wall := {}
		for height: float in [1.8, 1.4, 1.0]:
			var reach := global_position + Vector3.UP * height + _wall_normal * 0.3
			wall = _ray(reach, reach - _wall_normal * 2.5)
			if not wall.is_empty():
				break
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
	# 垂らす長さ：少し外側から真下を見て、下の地面までの高さ（斜めの岩肌でも、最低 4 m は垂らす）
	var out := top + flat * 1.5
	var below := _ray(out, out - Vector3.UP * Rope.MAX_LENGTH)
	var length := Rope.MAX_LENGTH if below.is_empty() else maxf(top.y - (below.position as Vector3).y, 4.0)
	rope_requested.emit(top, flat, length)
	return true


func _add_injury(amount: float, show_hurt := true) -> void:
	injury = minf(injury + amount, MAX_INJURY)
	stamina = minf(stamina, max_stamina())
	if show_hurt:
		hurt.emit()


## 入力（自分で動かすときはキーボードとマウス、そうでなければ bot_input）
func _pressed(action: String) -> bool:
	if not controlled:
		return bool(bot_input.get(action, false))
	if action == "grab" and holding_kind() < 0 and Input.is_action_pressed("use_item"):
		return true  # 手ぶらなら、左クリックでもつかむ
	return Input.is_action_pressed(action)


func _just_pressed(action: String) -> bool:
	if not controlled:
		return false
	if action == "grab" and holding_kind() < 0 and Input.is_action_just_pressed("use_item"):
		return true
	return Input.is_action_just_pressed(action)


## 手に持っているアイテムの種類（しまっている・持っていないなら -1）
func holding_kind() -> int:
	return -1 if stowed else inventory.selected_kind()


## 選んでいる欄のアイテムを、しまう／取り出す
func toggle_stowed() -> void:
	stowed = not stowed
	items_changed.emit()


func _vector(negative_x: String, positive_x: String, negative_y: String, positive_y: String) -> Vector2:
	if controlled:
		return Input.get_vector(negative_x, positive_x, negative_y, positive_y)
	return Vector2.ZERO


func is_eating() -> bool:
	return _eating > 0.0


## 投げてからの残り時間（体の投げる姿勢に使う）
func throw_time() -> float:
	return _throw_time


func is_being_pulled() -> bool:
	return _pull_time >= 0.0


## エモートをする（地面に立っているときだけ）。動いたり跳んだりすると、やめる
func play_emote(name: String) -> void:
	if frozen or state != State.WALK or not is_on_floor() or not EMOTE_TIMES.has(name):
		return
	emote = name
	_emote_time = EMOTE_TIMES[name]


## 差し伸べた手の先（崖のふちの少し下）
func reach_point() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return global_position + forward.normalized() * 1.0 - Vector3.UP * 0.6


## 差し伸べた手の届く所を登っている仲間がいたら、自分の横まで引き上げる
func _try_pull_up() -> void:
	for node in get_tree().get_nodes_in_group(&"players"):
		var other := node as Player
		if other == null or other == self or other.state != State.CLIMB or other.is_being_pulled():
			continue
		var chest := other.global_position + Vector3.UP * 1.2
		if chest.distance_to(reach_point()) > REACH_RANGE:
			continue
		var forward := -global_transform.basis.z
		forward.y = 0.0
		other.pull_up(global_position + global_transform.basis.x.normalized() * 0.8 + forward.normalized() * 0.1 + Vector3.UP * 0.2)
		_use_stamina(PULL_COST)
		add_shake(0.3)
		message.emit("引き上げた")


## 仲間に引き上げられる
func pull_up(to: Vector3) -> void:
	state = State.WALK
	clipped = false
	held_by = null
	velocity = Vector3.ZERO
	_pull_from = global_position
	_pull_to = to
	_pull_time = 0.0
	_safe_landing = true


func _process_pulled(delta: float) -> void:
	_pull_time += delta
	var t := clampf(_pull_time / PULL_TIME, 0.0, 1.0)
	global_position = _pull_from.lerp(_pull_to, t * t * (3.0 - 2.0 * t)) + Vector3.UP * sin(t * PI) * 0.6
	velocity = Vector3.ZERO
	if t >= 1.0:
		_pull_time = -1.0
		_set_slim(false)
		stamina = maxf(stamina, max_stamina() * 0.5)
		_grab_cooldown = 1.5  # 引き上げられた直後に、また崖をつかんでぶら下がらないように
		if not controlled:
			bot_input.erase("grab")  # 仲間のダミーは、助けられたら手を離す


func _unhandled_input(event: InputEvent) -> void:
	if not controlled:
		return
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
		stowed = false
		items_changed.emit()
		return
	if event.is_action_pressed("fly"):
		set_flying(not flying)
	elif event.is_action_pressed("toggle_lamp"):
		_headlamp.visible = not _headlamp.visible
	elif event.is_action_pressed("restart"):
		restart_requested.emit()
	elif event.is_action_pressed("use_item"):
		if holding_kind() >= 0:
			use_selected()
	elif event.is_action_pressed("throw"):
		if not frozen and held_by == null and inventory.selected_kind() >= 0:
			throw_charge = THROW_START_CHARGE  # 押している間、ためる（離すと投げる）
	elif event.is_action_released("throw"):
		if throw_charge >= 0.0:
			var charge := throw_charge
			throw_charge = -1.0
			throw_selected(charge)
	elif event.is_action_pressed("interact"):
		interact()
	else:
		for i in Items.SLOTS:
			if event.is_action_pressed("item_%d" % (i + 1)):
				if inventory.selected == i:
					toggle_stowed()  # 同じ欄をもう一度選ぶと、しまう／取り出す
				else:
					inventory.selected = i
					stowed = false
					items_changed.emit()


## たき火で焼ける物：手に持っている物が焼けるならそれ、でなければ持ち物の中で最初に見つかった焼ける物（なければ -1）
func cookable_kind() -> int:
	var held := inventory.selected_kind()
	if not stowed and Items.COOKED.has(held):
		return held
	for kind in inventory.kinds:
		if Items.COOKED.has(kind):
			return kind
	return -1


## たき火で、食べ物をひとつ焼く。焼いた物は持ち物に入る（いっぱいなら足もとに落ちる）。
## 手に持って焼いた物は、焼けたあとも手に持っている
func cook() -> bool:
	var kind := cookable_kind()
	if kind < 0:
		return false
	var slot := inventory.slot_of(kind)
	var was_selected := slot == inventory.selected
	inventory.remove_from(slot)
	var cooked: int = Items.COOKED[kind]
	if not inventory.add(cooked):
		item_thrown.emit(cooked, global_position + Vector3.UP, Vector3.UP * 2.0, false)
	elif was_selected and inventory.kinds[slot] != kind:
		inventory.selected = inventory.slot_of(cooked)
	message.emit("たき火で%sを焼いた。%sになった" % [Items.NAMES[kind], Items.NAMES[cooked]])
	_sounds.play_item()
	items_changed.emit()
	return true


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
	var input := _vector("move_left", "move_right", "move_forward", "move_back")
	var view := _camera.global_transform.basis
	var direction := view.x * input.x + view.z * input.y
	if _pressed("jump"):
		direction += Vector3.UP
	if _pressed("fly_down"):
		direction += Vector3.DOWN
	var speed := FLY_FAST_SPEED if _pressed("sprint") else FLY_SPEED
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
	elif is_being_pulled():
		_process_pulled(delta)
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
		_check_wedged(delta)
		if global_position.y < kill_height:
			die()
	_update_aim()
	_update_camera(delta)


## 挟まって動けなくなっていないか見て、動けなければ、近くの空いた所へ抜け出す
func _check_wedged(delta: float) -> void:
	if not controlled or _stuck_time > 0.0 or _eating > 0.0 or clipped or reaching or emote != "":
		_wedge_time = 0.0
		_wedge_anchor = global_position
		return
	var moving_input := _vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO
	var airborne := state == State.WALK and not is_on_floor() and velocity.y > -1.0
	var limit := 0.0
	var reach := 0.0  # どこまで上へ抜け出してよいか (m)
	if airborne:
		limit = WEDGE_AIR_TIME
		reach = 2.6
	elif state == State.CLIMB and climb_input != Vector2.ZERO and stamina > MIN_GRAB_STAMINA:
		limit = WEDGE_CLIMB_TIME
		reach = 2.0
	elif state == State.WALK and moving_input and not _blocked_by_barrier():
		limit = WEDGE_GROUND_TIME
		reach = 1.2  # 地面では、少しだけ（崖を登らずにすませることはできない）
	if limit <= 0.0 or global_position.distance_to(_wedge_anchor) > 0.3:
		_wedge_time = 0.0
		_wedge_anchor = global_position
		return
	_wedge_time += delta
	if _wedge_time < limit:
		return
	_wedge_time = 0.0
	var forward := -global_transform.basis.z
	if state == State.CLIMB:
		forward = _wall_normal  # 登っていて張り出しにつかえたら、少し外へ回りこむ
	var spot := _free_spot_near(global_position, Vector3(forward.x, 0.0, forward.z).normalized(), reach)
	if spot.is_finite():
		global_position = spot
		velocity = Vector3.ZERO
		_slide_velocity = Vector3.ZERO
		if state == State.CLIMB:
			state = State.WALK  # つかみ直す（つかむボタンを押していれば、すぐまたつかむ）
			_set_slim(false)
	_wedge_anchor = global_position


## いま、見えない壁（山頂のたき火をともすまで進めない壁）に押しつけられているか
func _blocked_by_barrier() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider() as CollisionObject3D
		if collider and collider.collision_layer & BARRIER_LAYER:
			return true
	return false


## pos の近くで、体がすっぽり入る空いた場所（上と、進みたい向きを先に探す）。なければ Vector3.INF
func _free_spot_near(pos: Vector3, prefer: Vector3, reach: float) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _body_shape.shape
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	var sides: Array[Vector3] = [Vector3.ZERO]
	for r: float in [0.7, 1.4]:
		if prefer != Vector3.ZERO:
			sides.append(prefer * r)
		for k in 8:
			sides.append(Vector3(cos(k * TAU / 8.0), 0.0, sin(k * TAU / 8.0)) * r)
	for up: float in [0.4, 0.8, 1.2, 1.8, 2.6]:
		if up > reach:
			break
		for side in sides:
			var candidate := pos + side + Vector3.UP * up
			query.transform = Transform3D(Basis(), candidate + _body_shape.position)
			if space.intersect_shape(query, 1).is_empty():
				return candidate
	return Vector3.INF


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
	if _just_pressed("jump") or _just_pressed("move_left") \
			or _just_pressed("move_right") or _just_pressed("grab"):
		struggle += 1.0
		add_shake(0.25)
	_process_afflictions(delta)


func _process_walk(delta: float) -> void:
	if (_body_shape.shape as CapsuleShape3D).radius != BODY_RADIUS:
		_set_slim(false)  # 登るのをやめたら、体の太さを戻す
	var input := _vector("move_left", "move_right", "move_forward", "move_back")
	# 手を差し伸べる（G を押している間）：ひざをついて動かない
	reaching = _pressed("reach") and is_on_floor() and _eating <= 0.0 and not sliding
	if reaching:
		emote = ""
		input = Vector2.ZERO
		_try_pull_up()
	# エモートは、動いたり跳んだりするとやめる。時間の決まったものは、終わるとやめる
	if emote != "":
		if input != Vector2.ZERO or _just_pressed("jump") or _pressed("grab") or not is_on_floor():
			emote = ""
		elif _emote_time > 0.0:
			_emote_time -= delta
			if _emote_time <= 0.0:
				emote = ""
	if _stuck_time > 0.0 or _eating > 0.0:
		input = Vector2.ZERO
	var direction := global_transform.basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	direction = direction.normalized()

	var on_floor := is_on_floor()
	_update_slide(on_floor, delta)
	var sprinting := on_floor and input.y < 0.0 and _pressed("sprint") and not exhausted and not sliding and not _bog
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
	elif _just_pressed("jump") and _stuck_time <= 0.0 and _eating <= 0.0 and not _bog:
		velocity.y = JUMP_VELOCITY
	elif sliding:
		velocity.y = minf(velocity.y, _slide_velocity.y)
	if sprinting:
		_use_stamina(SPRINT_DRAIN * delta)

	var impact_speed := -velocity.y
	move_and_slide()
	if is_on_floor() and not on_floor:
		_on_landed(impact_speed)
	if on_floor and is_on_wall() and direction != Vector3.ZERO and not sliding:
		_try_step_up(direction)
	# 進もうとしているのに動けない（こぶのすき間や岩の縁に引っかかった）：
	# 跳んで縁にぶつかったときや、しばらく押し続けたときは、手をかけて乗り越える
	var moving := Vector2(velocity.x, velocity.z).length()
	_blocked_time = _blocked_time + delta if direction != Vector3.ZERO and moving < 0.6 and state == State.WALK else 0.0
	if direction != Vector3.ZERO and (_pressed("jump") or _blocked_time > STUCK_TIME) 			and test_move(global_transform, direction * 0.3):  # 目の前に何かある（縁に乗りかけて、足もとが床に見えるときも）
		if _try_vault(direction):
			return

	var hit := _grab_probe()
	can_grab = not hit.is_empty() and not exhausted and stamina >= MIN_GRAB_STAMINA and _grab_cooldown <= 0.0 \
		and _stuck_time <= 0.0 and _eating <= 0.0
	if can_grab and _pressed("grab"):
		_start_climb(hit.normal, hit.position)


## 急な斜面では足をとられ、下り方向へどんどん速く滑っていく（アイゼンがあれば滑らない）
func _update_slide(on_floor: bool, delta: float) -> void:
	var limit := SLIP_NORMAL_Y_SNOW if in_snow else SLIP_NORMAL_Y
	if _slippery:
		limit = SLIP_NORMAL_Y_LOOSE
	if has_effect("crampons"):
		limit = -1.0
	# 足元の傾きは、踏んでいる三角形ひとつではなく、少しの間ならして見る（細かいでこぼこで滑らないように）
	var floor_normal := get_floor_normal() if on_floor else Vector3.UP
	_ground_normal = _ground_normal.slerp(floor_normal, 1.0 - exp(-8.0 * delta)).normalized()
	var steep_here := on_floor and _ground_normal.y < limit
	_slip_time = _slip_time + delta if steep_here else 0.0
	sliding = steep_here and _slip_time >= SLIP_DELAY
	if sliding:
		var downhill := (Vector3.DOWN - _ground_normal * _ground_normal.dot(Vector3.DOWN)).normalized()
		var steep := clampf((limit - _ground_normal.y) / 0.12, 0.35, 1.0)
		_slide_velocity = (_slide_velocity + downhill * SLIDE_ACCEL * steep * delta).limit_length(MAX_SLIDE_SPEED)
		if _slide_velocity.length() > 3.0:
			add_shake(0.08)
	elif on_floor:
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, SLIDE_FRICTION * delta)
	else:
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, 4.0 * delta)


## 目の前の縁（VAULT_HEIGHT まで）に手をかけて、よじ上る。上に立てる所がなければ false
func _try_vault(direction: Vector3) -> bool:
	for step: float in [0.9, 1.3, VAULT_HEIGHT]:
		var up := Vector3.UP * step
		if test_move(global_transform, up):
			return false  # 頭の上がふさがっている
		if not test_move(global_transform.translated(up), direction * 0.5):
			_wall_normal = -direction
			_start_mantle()
			_mantle_timer = MANTLE_TIME * clampf(step / 2.1, 0.45, 1.0)
			_blocked_time = 0.0
			return true
	return false


## 小さな段差（STEP_HEIGHT まで）は、歩いたまま乗り越える
func _try_step_up(direction: Vector3) -> void:
	var up := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, up):
		return  # 頭の上がふさがっている
	var forward := direction * 0.35
	if test_move(global_transform.translated(up), forward):
		return  # 上がっても進めない（段差ではなく壁）
	global_position += up + forward
	apply_floor_snap()


func _process_climb(delta: float) -> void:
	can_grab = true
	var input := _vector("move_left", "move_right", "move_back", "move_forward")
	climb_input = input
	_sprinting = false
	sliding = false
	_slide_velocity = Vector3.ZERO

	# ハーケンでぶら下がっている間は、手を離しても落ちない。動くと外れる
	if clipped:
		velocity = Vector3.ZERO
		if input != Vector2.ZERO or _just_pressed("jump"):
			clipped = false
		else:
			return
	if not _pressed("grab") or exhausted:
		_let_go()
		return

	# 胸の前の壁を探し直して、壁の向きを更新する
	var chest := global_position + Vector3.UP
	var hit := _ray(chest, chest - _wall_normal * (WALL_GAP + 1.6))
	if hit.is_empty():
		# 丸いこぶや角で壁が途切れたら、回り込んだ先の面を探してつかみ続ける
		hit = _wrap_probe(chest, input)
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

	if _just_pressed("jump") and stamina > 0.0:
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
	var before := global_position
	move_and_slide()
	# 動こうとしているのに引っかかって進めないときは、壁から少し離して押し上げる
	if input != Vector2.ZERO and global_position.distance_to(before) < CLIMB_SPEED * delta * 0.2:
		_stuck_climb += delta
		if _stuck_climb > 0.25:
			global_position += _wall_normal * 0.12 + (up * input.y + right * input.x).normalized() * 0.1
			_stuck_climb = 0.0
	else:
		_stuck_climb = 0.0
	var drain := (CLIMB_DRAIN if input != Vector2.ZERO else HANG_DRAIN) * _drain_multiplier() * surface_drain * _climb_drain * altitude_drain
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


## 目の前の壁が途切れたとき、斜め下・斜め上・進む方向の横へ回り込んだ面を探す。見つかれば、その面の向きに合わせる
func _wrap_probe(chest: Vector3, input: Vector2) -> Dictionary:
	var n := _wall_normal
	var up := (Vector3.UP - n * n.y).normalized()
	var right := (-n).cross(up).normalized()
	# 進もうとしている向きを先に探す（何もしていなければ、同じ高さの横・上を先に。下は最後）
	var directions: Array[Vector3] = [-n + up * 0.6, -n - up * 0.8]
	if input.y < 0.0:
		directions.reverse()
	if input.x != 0.0:
		directions.push_front(-n + right * signf(input.x) * 1.2)
	for direction in directions:
		var hit := _ray(chest + n * 0.2, chest + n * 0.2 + direction.normalized() * (WALL_GAP + 1.4))
		if not hit.is_empty() and (hit.normal as Vector3).y <= WALL_MAX_NORMAL_Y:
			_wall_normal = hit.normal
			return hit
	return {}


## 体の太さを変える（登っている間は細く）
func _set_slim(slim: bool) -> void:
	var capsule := _body_shape.shape as CapsuleShape3D
	capsule.radius = CLIMB_RADIUS if slim else BODY_RADIUS
	capsule.height = CLIMB_HEIGHT if slim else BODY_HEIGHT


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
		_set_slim(false)
		velocity = _mantle_dir * 2.0
		_grab_cooldown = GRAB_COOLDOWN


## 壁をつかむ。point（つかんだ所）を渡すと、胸が壁から WALL_GAP の所まで体を寄せる
func _start_climb(normal: Vector3, point := Vector3.INF) -> void:
	state = State.CLIMB
	_set_slim(true)
	_wall_normal = normal
	velocity = Vector3.ZERO
	_lunge_timer = 0.0
	if point.is_finite():
		global_position = point + normal * WALL_GAP - Vector3.UP * 1.1


func _start_mantle() -> void:
	state = State.MANTLE
	_mantle_timer = MANTLE_TIME
	var flat := Vector3(-_wall_normal.x, 0.0, -_wall_normal.z)
	_mantle_dir = flat.normalized() if flat.length() > 0.01 else -global_transform.basis.z


func _let_go() -> void:
	state = State.WALK
	_set_slim(false)
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
	_swing_cooldown = maxf(_swing_cooldown - delta, 0.0)
	if _swing_hit_in >= 0.0:
		_swing_hit_in -= delta
		if _swing_hit_in < 0.0:
			_swing_strike()
	if controlled and holding_kind() == Items.Kind.NATA and Input.is_action_pressed("use_item") \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_swing()  # 押しっぱなしで、振り続ける
	# 手ぶらの左クリックは、つかめる壁があれば壁をつかみ、なければ殴る（押しっぱなしなら、相手がいる間だけ殴り続ける）
	if controlled and holding_kind() < 0 and state == State.WALK and not can_grab and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_just_pressed("use_item") or (Input.is_action_pressed("use_item") and _mob_in_reach(PUNCH_REACH + 0.4)):
			_punch()
	if punch_t >= 0.0:
		punch_t += delta / 0.3
		if punch_t >= 1.0:
			punch_t = -1.0
	if throw_charge >= 0.0:
		if state != State.WALK or held_by or inventory.selected_kind() < 0:
			throw_charge = -1.0  # 登り始めたり、つかまれたりしたら、ためるのをやめる
		else:
			throw_charge = minf(throw_charge + delta / THROW_CHARGE_TIME, 1.0)
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
	if not controlled:
		return  # 仲間のダミーは疲れない
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
				if node.has_method("interact_hint") and String(node.call("interact_hint", self)).is_empty():
					continue  # いまは何もできない物（焼く物がないときのたき火など）は、ねらわない
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
	# すわる・しゃがむ・ひざをつくと、目の高さも下がる
	var head_height := HEAD_HEIGHT
	if emote == "sit":
		head_height = 0.95
	elif emote == "crouch":
		head_height = 0.82
	elif reaching:
		head_height = 1.02
	_head.position.y = lerpf(_head.position.y, head_height, 1.0 - exp(-10.0 * delta))
	_throw_time = maxf(_throw_time - delta, 0.0)
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
