@tool
extends ReferenceRect
## 房间矩形标记：既能在 Inspector 里输入 room_size（Vector2），
## 也能在 2D 视图里直接拖拽缩放 —— 两个方向双向同步。
## 相机读取的仍是该节点的 global_position + size。

@export var room_size := Vector2(480.0, 270.0) : set = _set_room_size

var _syncing := false


func _ready() -> void:
	_apply()
	resized.connect(_on_resized)


func _set_room_size(v: Vector2) -> void:
	room_size = v
	_apply()


func _apply() -> void:
	if _syncing:
		return
	if room_size.x > 0.0 and room_size.y > 0.0 and size != room_size:
		_syncing = true
		size = room_size
		_syncing = false


func _on_resized() -> void:
	# 拖拽改变 size 时，把新的尺寸写回 room_size，避免下次加载被旧值覆盖
	if _syncing:
		return
	_syncing = true
	room_size = size
	_syncing = false
