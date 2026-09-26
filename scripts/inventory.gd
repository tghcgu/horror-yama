class_name Inventory
extends RefCounted
## 持ち物。Items.SLOTS 個の欄に、同じ種類のアイテムを Items.MAX_STACK 個まで重ねて入れる。
## 数字キーやホイールで欄を選び、選んでいる欄のアイテムを使ったり投げたりする。

var kinds := PackedInt32Array()   # 欄ごとのアイテムの種類（-1 = 空）
var counts := PackedInt32Array()  # 欄ごとの数
var selected := 0


func _init() -> void:
	kinds.resize(Items.SLOTS)
	counts.resize(Items.SLOTS)
	clear()


func clear() -> void:
	kinds.fill(-1)
	counts.fill(0)
	selected = 0


## 入れられたら true（同じ種類の欄に重ねるか、空いている欄に入れる）
func add(kind: int) -> bool:
	for i in Items.SLOTS:
		if kinds[i] == kind and counts[i] < Items.MAX_STACK:
			counts[i] += 1
			return true
	for i in Items.SLOTS:
		if kinds[i] < 0:
			kinds[i] = kind
			counts[i] = 1
			return true
	return false


func count_of(kind: int) -> int:
	var total := 0
	for i in Items.SLOTS:
		if kinds[i] == kind:
			total += counts[i]
	return total


func has(kind: int) -> bool:
	return count_of(kind) > 0


func slot_of(kind: int) -> int:
	for i in Items.SLOTS:
		if kinds[i] == kind:
			return i
	return -1


func selected_kind() -> int:
	return kinds[selected]


## その欄からひとつ取り出す。空になったら欄をあける
func remove_from(slot: int) -> int:
	var kind := kinds[slot]
	if kind < 0:
		return -1
	counts[slot] -= 1
	if counts[slot] <= 0:
		kinds[slot] = -1
		counts[slot] = 0
	return kind


func remove(kind: int) -> bool:
	var slot := slot_of(kind)
	if slot < 0:
		return false
	remove_from(slot)
	return true


func select_next(step: int) -> void:
	selected = posmod(selected + step, Items.SLOTS)


func is_full_for(kind: int) -> bool:
	for i in Items.SLOTS:
		if kinds[i] < 0 or (kinds[i] == kind and counts[i] < Items.MAX_STACK):
			return false
	return true


func snapshot() -> Array:
	return [kinds.duplicate(), counts.duplicate(), selected]


func restore(data: Array) -> void:
	kinds = (data[0] as PackedInt32Array).duplicate()
	counts = (data[1] as PackedInt32Array).duplicate()
	selected = data[2]
