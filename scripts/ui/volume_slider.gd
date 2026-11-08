extends Control
class_name VolumeSlider
## 条状音量滑块：轨道 + 填充 + 小方 knob，点击/拖动设置数值。

signal value_changed(value: float)

@export var min_value := 0.0
@export var max_value := 100.0
@export var value := 50.0:
	set(v):
		value = clampf(v, min_value, max_value)
		queue_redraw()
		value_changed.emit(value)

var _dragging := false


func _ready() -> void:
	custom_minimum_size = Vector2(200, 16)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cy := h * 0.5
	var bar_h := 4.0
	var track := Rect2(0.0, cy - bar_h * 0.5, w, bar_h)
	draw_rect(track, Color("2b3342"), true)

	var span := maxf(max_value - min_value, 0.001)
	var ratio := clampf((value - min_value) / span, 0.0, 1.0)
	var fill := Rect2(0.0, cy - bar_h * 0.5, w * ratio, bar_h)
	draw_rect(fill, Color("d7c4fe"), true)

	var knob_w := 6.0
	var knob_h := 14.0
	var kx := clampf(w * ratio - knob_w * 0.5, 0.0, maxf(0.0, w - knob_w))
	draw_rect(Rect2(kx, cy - knob_h * 0.5, knob_w, knob_h), Color("d7c4fe"), true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_set_from_x(event.position.x)
			accept_event()
		else:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()


func _set_from_x(x: float) -> void:
	if size.x <= 0.0:
		return
	var ratio := clampf(x / size.x, 0.0, 1.0)
	value = min_value + ratio * (max_value - min_value)
