class_name TerrainCache
extends Resource
## 作り終えた地形をまるごと保存したもの（高さ・隠れクレバス・区画のまとまりごとの見た目）。
## 山はいつも同じなので、2 回目からはこれを読むだけにして、待ち時間を短くする。
## 当たり判定と頂点の向きは、読んだあとに高さから作り直す（ファイルを小さくするため）。
## 地形を作るスクリプトを書きかえると version が変わり、作り直される。

@export var version := ""
@export var origin := Vector2.ZERO
@export var count_x := 0
@export var count_z := 0
@export var heights := PackedFloat32Array()
@export var built := PackedByteArray()
@export var pits := PackedVector3Array()
## まとまりごとに {"near": Mesh か null, "far": Mesh, "rects": [Rect2i...], "coarse": [bool...], "grids": [PackedFloat32Array...]}
@export var groups: Array = []
