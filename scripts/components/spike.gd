class_name Spike
extends Area2D
## 素材库：尖刺。玩家碰到 → player.take_damage() 回存盘点。

@export var size := Vector2(8.0, 8.0)
@export var color := Color(0.85, 0.25, 0.25)

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage()

func _apply() -> void:
	var rect := shape.shape as RectangleShape2D
	if rect: rect.size = size
	visual.position = -size * 0.5
	visual.size = size
	visual.color = color
