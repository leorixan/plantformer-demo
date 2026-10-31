@tool
extends Area2D
## 上升区域：玩家进入时获得一个向上的速度（可当作上升气流 / 弹射区）

@export_range(0.0, 2000.0, 10.0) var launch_speed := 300.0
@export var one_shot := false

var _used := false


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	add_to_group("resettable_triggers")


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	if one_shot and _used:
		return
	_used = true
	var v: Vector2 = body.velocity
	body.velocity = Vector2(v.x, -launch_speed)
	print("[updraft] 向上速度 ", -launch_speed)


func reset_state() -> void:
	_used = false


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var size := (shape_node.shape as RectangleShape2D).size
	draw_rect(Rect2(-size * 0.5, size), Color(0.55, 1.0, 0.85, 0.9), false, 1.0)
