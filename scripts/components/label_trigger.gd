@tool
extends Area2D
## 位置触发标签：结构全部在场景里（WorldLabel/Panel/Text）
## Panel/Text 的文字、字号、尺寸都可以在编辑器里直接改/拖
## 脚本只负责：玩家进入区域时显示 WorldLabel，离开/超时后隐藏

@export var once := false
@export var hide_delay := 0  # 0 = 玩家离开区域才消失
@export var fade_time := 0.2   # 渐隐/渐显时长（0 = 直接切换）
@export var label_path: NodePath = NodePath("") : set = _set_label_path   # 留空=用子节点 WorldLabel

var _holder: Node2D
var _shown := false
var _used := false
var _timer := 0.0
var _tween: Tween


func _ready() -> void:
	_refs()
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("resettable_triggers")
	_init_hidden()


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


func reset_state() -> void:
	_used = false
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


func _init_hidden() -> void:
	_shown = false
	if _holder == null:
		return
	_holder.visible = false
	_holder.modulate.a = 0.0


func _apply_visible(on: bool) -> void:
	_shown = on
	if _holder == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if on:
		_holder.visible = true
		if fade_time <= 0.0:
			_holder.modulate.a = 1.0
		else:
			_tween = create_tween()
			_tween.tween_property(_holder, "modulate:a", 1.0, fade_time)
	else:
		if fade_time <= 0.0 or not _holder.visible:
			_holder.modulate.a = 0.0
			_holder.visible = false
		else:
			_tween = create_tween()
			_tween.tween_property(_holder, "modulate:a", 0.0, fade_time)
			_tween.tween_callback(func() -> void: _holder.visible = false)



func _set_label_path(_v: NodePath) -> void:
	label_path = _v
	_holder = null
	_refs()
