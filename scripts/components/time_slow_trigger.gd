@tool
extends Area2D
## 进入区域后时间变缓，按下指定按键/动作后恢复正常
## 用法：拖进关卡 → 调 CollisionShape2D 范围 → Inspector 设 slow_scale 和恢复键

@export var slow_scale := 0.35
@export var restore_keycode: Key = KEY_SPACE
@export var restore_action: StringName = &""   # 非空时优先用 InputMap 动作名
@export var one_shot := true
@export var restore_on_exit := false           # true = 玩家离开区域也恢复

var _active := false
var _used := false


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	collision_layer = 0
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	var pressed := false
	if not restore_action.is_empty():
		pressed = event.is_action_pressed(restore_action)
	elif event is InputEventKey:
		var ke := event as InputEventKey
		pressed = ke.pressed and not ke.echo and ke.physical_keycode == restore_keycode
	if pressed:
		_restore()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body) or _active:
		return
	if one_shot and _used:
		return
	_used = true
	_active = true
	print("[timeslow] 进入区域，time_scale=", slow_scale)
	Engine.time_scale = slow_scale


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body) or not _active:
		return
	if restore_on_exit:
		_restore()


func _restore() -> void:
	if not _active:
		return
	_active = false
	Engine.time_scale = 1.0
	print("[timeslow] 恢复正常时间")


func _exit_tree() -> void:
	if _active:
		Engine.time_scale = 1.0
		_active = false


func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body.name == "Player"


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var size := (shape_node.shape as RectangleShape2D).size
	draw_rect(Rect2(-size * 0.5, size), Color(0.45, 0.7, 1.0, 0.85), false, 1.0)
