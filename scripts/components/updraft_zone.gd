@tool
extends Area2D
## 上升区域：玩家进入时获得一个向上的速度（可当作上升气流 / 弹射区）

enum Mode {
	ONE_SHOT,    ## 进入时施加一次
	CONTINUOUS,  ## 在区域内持续施加
}

@export var mode: Mode = Mode.ONE_SHOT
@export_range(0.0, 2000.0, 10.0) var launch_speed := 300.0
@export var once := false   ## 只生效一次（复活后重置）

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
	body_exited.connect(_on_body_exited)
	add_to_group("resettable_triggers")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or mode != Mode.CONTINUOUS or (once and _used):
		return
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			var v: Vector2 = body.velocity
			body.velocity = Vector2(v.x, -launch_speed)


func _on_body_entered(body: Node2D) -> void:
	if mode != Mode.ONE_SHOT:
		return
	if not (body is CharacterBody2D):
		return
	if once and _used:
		return
	_used = true
	var v: Vector2 = body.velocity
	body.velocity = Vector2(v.x, -launch_speed)
	print("[updraft] 一次性向上速度 ", -launch_speed)


func _on_body_exited(_body: Node2D) -> void:
	# 持续模式下 once = 第一次离开后就失效（首次在区域内时仍然持续施加）
	if once:
		_used = true


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
