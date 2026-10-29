@tool
extends Area2D
## 位置触发标签：玩家进入区域时在屏幕上显示一段提示文字（带半透明底板）
## 用法：把本场景拖进关卡 → 调整 CollisionShape2D 大小/位置 → Inspector 填 text
## 编辑器里会直接画出区域框和文字预览

@export_multiline var text := "提示文字" : set = _set_text
@export var font_size: int = 8 : set = _set_font_size
@export var font_color := Color(0.96, 0.96, 0.96, 1.0)
@export var panel_color := Color(0.0, 0.0, 0.0, 0.55)
@export var screen_position := Vector2(8.0, 8.0) : set = _set_screen_position
@export var once := true
@export var hide_delay := 0.0   # 0 = 玩家离开区域才消失

var _ui: CanvasLayer
var _panel: ColorRect
var _label: Label
var _shown := false
var _used := false
var _timer := 0.0
var _preview_font: SystemFont


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	collision_layer = 0
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_ui()
	_apply_visible(false)


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
	if _ui == null:
		return
	_ui.visible = on


func _build_ui() -> void:
	if _ui != null:
		return
	_ui = CanvasLayer.new()
	_ui.name = "LabelUI"
	_ui.layer = 10
	add_child(_ui)
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(root)
	_panel = ColorRect.new()
	_panel.name = "Panel"
	_panel.color = panel_color
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	_label = Label.new()
	_label.name = "Text"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Arial"])
	_label.add_theme_font_override("font", font)
	_label.add_theme_color_override("font_color", font_color)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 1)
	root.add_child(_label)
	_layout()
	_ui.visible = false


func _layout() -> void:
	if _label == null:
		return
	var font := _label.get_theme_font("font")
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, 452.0, font_size)
	var w := minf(464.0, size.x + 12.0)
	var h := size.y + 8.0
	_panel.position = screen_position
	_panel.size = Vector2(w, h)
	_label.position = screen_position + Vector2(6.0, 4.0)
	_label.size = Vector2(w - 12.0, h - 8.0)
	_label.text = text


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var size := (shape_node.shape as RectangleShape2D).size
	var color := Color(0.95, 0.6, 0.2, 0.9)
	draw_rect(Rect2(-size * 0.5, size), color, false, 1.0)
	if _preview_font == null:
		_preview_font = SystemFont.new()
		_preview_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Arial"])
	draw_string(_preview_font, Vector2(-size.x * 0.5, -size.y * 0.5 - 2.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _set_text(_v: String) -> void:
	text = _v
	if Engine.is_editor_hint():
		queue_redraw()
	elif _label != null:
		_layout()


func _set_font_size(_v: int) -> void:
	font_size = _v
	if Engine.is_editor_hint():
		queue_redraw()
	elif _label != null:
		_label.add_theme_font_size_override("font_size", font_size)
		_layout()


func _set_screen_position(_v: Vector2) -> void:
	screen_position = _v
	if _label != null:
		_layout()
