extends CanvasLayer
## 游戏内暂停菜单（Esc）：Continue / Setting / Wake up。
## 设置以 overlay 方式打开，关闭后回到暂停菜单。

const SETTING_SCENE := "res://scenes/levels/setting.tscn"
const MENU_SCENE := "res://scenes/levels/menu.tscn"
const FONT_UI := "res://assets/fonts/Silkscreen-Regular.ttf"
const SFX_DB := -20.0

@onready var _panel: Panel = $Panel
@onready var _continue: Button = $Panel/Buttons/Continue
@onready var _settings: Button = $Panel/Buttons/Settings
@onready var _wake: Button = $Panel/Buttons/WakeUp
@onready var _timer: Label = $Timer

var _settings_overlay: Control
var _hud: CanvasLayer
var _bgm: Node
var _bgm_process_mode := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level := get_parent()
	if level:
		_hud = level.get_node_or_null("HUD") as CanvasLayer
		_bgm = level.get_node_or_null("Bgm")
	visible = false
	for button in [_continue, _settings, _wake]:
		_style_button(button)
		button.focus_entered.connect(func() -> void: _play_ui(&"ui_move"))
		button.mouse_entered.connect(func() -> void: _play_ui(&"ui_move"))
	_continue.pressed.connect(_on_continue)
	_settings.pressed.connect(_on_settings)
	_wake.pressed.connect(_on_wake_up)
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if _settings_overlay != null:
		return
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_resume()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	visible = true
	_panel.visible = true
	get_tree().paused = true
	_refresh_timer()
	_show_hud()
	_play_ui(&"ui_pause")
	_continue.grab_focus()


func _refresh_timer() -> void:
	var level := get_parent()
	if level == null:
		return
	_timer.text = _format_time(float(level.get("elapsed_time")))


func _show_hud() -> void:
	var level := get_parent()
	if _hud and level:
		_hud.call("show_pause_stats", int(level.get("deaths")), int(level.get("trophies_collected")))


func _hide_hud() -> void:
	if _hud:
		_hud.call("hide_pause_stats")


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	return "%02d:%02d:%02d" % [h, m, s]


func _resume() -> void:
	_play_ui(&"ui_back")
	visible = false
	_hide_hud()
	get_tree().paused = false


func _on_continue() -> void:
	_resume()


func _on_settings() -> void:
	_hide_hud()
	# 设置页不暂停音乐；暂停菜单本身仍保持暂停
	if _bgm:
		_bgm_process_mode = _bgm.process_mode
		_bgm.process_mode = Node.PROCESS_MODE_ALWAYS
	_play_ui(&"ui_confirm")
	_settings_overlay = load(SETTING_SCENE).instantiate()
	_settings_overlay.set("overlay_mode", true)
	_settings_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings_overlay)
	_settings_overlay.closed.connect(_on_settings_closed)
	_panel.visible = false


func _on_settings_closed() -> void:
	_settings_overlay = null
	if _bgm:
		_bgm.process_mode = _bgm_process_mode
	_panel.visible = true
	_show_hud()
	_continue.grab_focus()


func _on_wake_up() -> void:
	_play_ui(&"ui_back")
	_hide_hud()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _play_ui(id: StringName) -> void:
	var base := -9.0 if id == &"ui_confirm" else -10.0
	Sfx.play(id, SFX_DB - base)


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("202734")
	normal.border_color = Color("3d4a5e")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("2d3a4d")
	hover.border_color = Color("d7c4fe")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("d7c4fe")
	pressed.border_color = Color("d7c4fe")
	button.add_theme_stylebox_override("pressed", pressed)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color("263244")
	focus.border_color = Color("d7c4fe")
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", load(FONT_UI))
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color("d8deea"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_focus_color", Color("d7c4fe"))
	button.add_theme_color_override("font_pressed_color", Color("10141b"))
