@tool
extends Sprite2D
## 八向木质箭头路牌（纯装饰）：8 个方向，完整带直杆，无内部箭头。
## 渲染层级：z_index 与角色同为 0，但路牌是场景节点、角色运行时最后加入，
## 因此重叠时角色绘制在路牌之上，不会被挡住。

enum Direction {
	UP,
	UP_RIGHT,
	RIGHT,
	DOWN_RIGHT,
	DOWN,
	DOWN_LEFT,
	LEFT,
	UP_LEFT,
}

const TEXTURE := preload("res://assets/art/objects/direction_sign.png")

@export var direction: Direction = Direction.UP:
	set = _set_direction


func _ready() -> void:
	texture = TEXTURE
	hframes = 8
	vframes = 1
	centered = true
	offset = Vector2(0, -12)
	z_index = 0
	frame = int(direction)


func _set_direction(value: Direction) -> void:
	direction = value
	if is_node_ready():
		frame = int(value)
