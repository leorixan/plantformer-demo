@tool
extends Area2D
## 位置触发标签（世界坐标）：结构在场景里（WorldLabel/Panel/Text），脚本只负责
## 玩家进出时显示/隐藏，以及按 Inspector 参数更新现有节点。
## 用法：拖 label_trigger.tscn 进关卡 → 调 CollisionShape2D → 填 text / box_size

@export_multiline var text := "提示文字" : set = _set_text
@export var font_size: int = 8 : set = _set_font_size
@export var font_color := Color(0.96, 0.96, 0.96, 1.0) : set = _set_font_color
@export var panel_color := Color(0.0, 0.0, 0.0, 0.55) : set = _set_panel_color
@export var label_path: NodePath = NodePath("") : set = _set_label_path   # 留空 = 用子节点 WorldLabel；填路径 = 用外部标签节点
@export var box_size := Vector2(120.0, 0.0) : set = _set_box_size   # x=宽(<=0自适应) y=高(<=0自适应)
@export var once := false
@export var hide_delay := 0.0   # 0 = 玩家离开区域才消失

var _holder: Node2D
var _panel: ColorRect
var _label: Label
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
	_layout()
	_apply_visible(false)


func _refs() -> void:
	var base := "WorldLabel"
	if not label_path.is_empty():
		base = String(label_path)
	if _holder == null:
		_holder = get_node_or_null(base) as Node2D
	if _panel == null:
		_panel = get_node_or_null(base + "/Panel") as ColorRect
	if _label == null:
		_label = get_node_or_null(base + "/Text") as Label


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


func _layout() -> void:
	_refs()
	if _holder == null or _panel == null or _label == null:
		return
	_panel.color = panel_color
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", font_color)
	var font := _label.get_theme_font("font")
	# 不自动换行：只按显式换行测量整行宽度
	var measured := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var w := box_size.x if box_size.x > 0.0 else measured.x + 12.0
	var h := box_size.y if box_size.y > 0.0 else measured.y + 8.0
	_panel.position = Vector2(-w * 0.5, -h * 0.5)
	_panel.size = Vector2(w, h)
	_label.position = Vector2(-w * 0.5 + 6.0, -h * 0.5 + 4.0)
	_label.size = Vector2(maxf(1.0, w - 12.0), maxf(1.0, h - 8.0))


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
	_panel = null
	_label = null
	if is_node_ready():
		_layout()


func _set_text(_v: String) -> void:
	text = _v
	if _holder != null:
		_layout()
	elif Engine.is_editor_hint():
		queue_redraw()


func _set_font_size(_v: int) -> void:
	font_size = _v
	if _holder != null:
		_layout()


func _set_font_color(_v: Color) -> void:
	font_color = _v
	if _holder != null:
		_layout()


func _set_panel_color(_v: Color) -> void:
	panel_color = _v
	if _holder != null:
		_layout()


func _set_box_size(_v: Vector2) -> void:
	box_size = _v
	if _holder != null:
		_layout()
