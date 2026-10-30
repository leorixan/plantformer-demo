@tool
extends ReferenceRect
## 房间矩形标记：在 Inspector 里直接输入 room_size（Vector2），
## 内部同步到 Control.size；ReferenceRect 会自动画出黄色边框。
## 相机读取的仍是该节点的 global_position + size。

@export var room_size := Vector2(480.0, 270.0) : set = _set_room_size


func _ready() -> void:
	_apply()


func _set_room_size(v: Vector2) -> void:
	room_size = v
	_apply()


func _apply() -> void:
	if room_size.x > 0.0 and room_size.y > 0.0:
		size = room_size
