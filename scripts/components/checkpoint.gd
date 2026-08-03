class_name Checkpoint
extends Area2D
## 素材库：存盘点。玩家进入后记录重生点（player.set_checkpoint）。

@export var size := Vector2(16.0, 16.0)
@export var color := Color(0.35, 0.85, 0.45)

@onready var visual: ColorRect = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_checkpoint"):
		body.set_checkpoint(global_position)

func _apply() -> void:
	visual.position = -size * 0.5
	visual.size = size
	visual.color = color
