class_name Spring
extends Area2D
## 素材库：弹簧。玩家接触即弹射，velocity.y 反向。
## 非实心设计：走过/踩上都会触发，不会被实体挡住。

@export var size := Vector2(8.0, 4.0)
@export var color := Color(0.35, 0.8, 0.9)
@export var launch_speed := 260.0

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.velocity.y = -launch_speed

func _apply() -> void:
	var rect := shape.shape as RectangleShape2D
	if rect: rect.size = size + Vector2(4.0, 8.0)
	visual.position = -size * 0.5
	visual.size = size
	visual.color = color
