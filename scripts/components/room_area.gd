@tool
class_name RoomArea
extends Node2D
## 房间标记：position = 房间左上角，rect_size = 房间尺寸（世界像素）。
## 在编辑器里显示为彩色矩形边框；运行时只作为相机房间数据，不渲染。

@export var rect_size := Vector2(320, 184)
@export var color := Color(0.3, 0.75, 1.0, 0.9)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2.ZERO, rect_size), color, false, 1.0)
