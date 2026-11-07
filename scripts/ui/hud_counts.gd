extends CanvasLayer
## 左上角计数 HUD：死亡 / 奖杯两排，格式 [图标 × 数量]。
## DeathGroup / TrophyGroup 是普通 Control，可在编辑器里直接拖动位置。
## 常态隐藏，事件后显示 2 秒，淡入淡出与 label_trigger 一致。

@export var fade_time := 0.2
@export var show_time := 2.0

var _death_group: Control
var _trophy_group: Control
var _death_label: Label
var _trophy_label: Label
var _timers: Dictionary = {}
var _tweens: Dictionary = {}


func _ready() -> void:
	_death_group = get_node_or_null("DeathGroup")
	_trophy_group = get_node_or_null("TrophyGroup")
	_death_label = get_node_or_null("DeathGroup/DeathLabel")
	_trophy_label = get_node_or_null("TrophyGroup/TrophyLabel")
	for group in [_death_group, _trophy_group]:
		if group:
			# 保留占位：不设 visible=false，否则 VBox 会把另一行顶到第一排
			group.visible = true
			group.modulate.a = 0.0
	set_process(false)


func show_death(death_count: int, trophy_count: int) -> void:
	if _death_label:
		_death_label.text = "× %d" % death_count
	_show("death", _death_group)
	if trophy_count > 0:
		if _trophy_label:
			_trophy_label.text = "× %d" % trophy_count
		_show("trophy", _trophy_group)
	else:
		_hide("trophy")


func show_trophy(count: int) -> void:
	if count <= 0:
		return
	_hide("death")
	if _trophy_label:
		_trophy_label.text = "× %d" % count
	_show("trophy", _trophy_group)


func _show(key: String, group: Control) -> void:
	if group == null:
		return
	_timers[key] = show_time
	if _tweens.has(key):
		var old: Tween = _tweens[key]
		if old != null and old.is_valid():
			old.kill()
	var tw := create_tween()
	tw.tween_property(group, "modulate:a", 1.0, fade_time)
	_tweens[key] = tw
	set_process(true)


func _process(delta: float) -> void:
	if _timers.is_empty():
		set_process(false)
		return
	for key in _timers.keys():
		_timers[key] -= delta
		if _timers[key] <= 0.0:
			_timers.erase(key)
			_hide(key)


func _hide(key: String) -> void:
	var group: Control = _death_group if key == "death" else _trophy_group
	if group == null:
		return
	if _tweens.has(key):
		var old: Tween = _tweens[key]
		if old != null and old.is_valid():
			old.kill()
	var tw := create_tween()
	tw.tween_property(group, "modulate:a", 0.0, fade_time)
	_tweens[key] = tw
