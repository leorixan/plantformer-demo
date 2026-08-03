class_name BreakableBlock
extends StaticBody2D
## 素材库：可破坏方块。玩家 attacking 状态撞上即碎裂。

@export var size := Vector2(8.0, 8.0)
@export var color := Color(0.6, 0.42, 0.85)

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $Visual
@onready var detector: Area2D = $Detector

func _ready() -> void:
	detector.body_entered.connect(_on_body_entered)
	_apply()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("is_attacking") and body.is_attacking():
		queue_free()

func _apply() -> void:
	var rect := shape.shape as RectangleShape2D
	if rect: rect.size = size
	visual.position = -size * 0.5
	visual.size = size
	visual.color = color
	var dshape := detector.get_node("CollisionShape2D").shape as RectangleShape2D
	if dshape: dshape.size = size + Vector2(4.0, 4.0)
