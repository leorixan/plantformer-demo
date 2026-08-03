class_name Wall
extends StaticBody2D
## 素材库：墙体。拖入场景，调 size/color 属性即可。

@export var size := Vector2(8.0, 8.0)
@export var color := Color(0.22, 0.25, 0.32)

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $Visual

func _ready() -> void:
	_apply()

func _apply() -> void:
	var rect := shape.shape as RectangleShape2D
	if rect: rect.size = size
	visual.position = Vector2.ZERO
	visual.size = size
	visual.position = -size * 0.5
	visual.color = color
