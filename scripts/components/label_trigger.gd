@tool
extends Area2D
## 位置触发标签：结构全部在场景里（WorldLabel/Panel/Text）
## Panel/Text 的文字、字号、尺寸都可以在编辑器里直接改/拖
## 脚本只负责：玩家进入区域时显示 WorldLabel，离开/超时后隐藏

@export var once := true
@export var hide_delay := 0.0   # 0 = 玩家离开区域才消失
@export var label_path: NodePath = NodePath("") : set = _set_label_path   # 留空=用子节点 WorldLabel

var _holder: Node2D
var _shown := false
var _used := false
var _timer := 0.0


func _ready() -> void:
	_refs()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	collision_layer = 0
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_visible(false)


func _refs() -> void:
	var base := "WorldLabel"
	if not label_path.is_empty():
		base = String(label_path)
	if _holder == null:
		_holder = get_node_or_null(base) as Node2D


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _shown and hide_delay > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_apply_visible(false)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") and body.name != "Player":
		return
	if once and _used:
		return
	_used = true
	_apply_visible(true)
	if hide_delay > 0.0:
		_timer = hide_delay


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player") and body.name != "Player":
		return
	if hide_delay <= 0.0:
		_apply_visible(false)


func _apply_visible(on: bool) -> void:
	_shown = on
	if _holder != null:
		_holder.visible = on


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var size := (shape_node.shape as RectangleShape2D).size
	draw_rect(Rect2(-size * 0.5, size), Color(0.95, 0.6, 0.2, 0.9), false, 1.0)


func _set_label_path(_v: NodePath) -> void:
	label_path = _v
	_holder = null
	_refs()
