extends Control
## 设置页：Volume / Controls 两栏。
## 从主菜单进入时返回主菜单；从暂停菜单作为 overlay 打开时发 closed 信号。

signal closed

const MENU_SCENE := "res://scenes/levels/menu.tscn"
const FONT_UI := "res://assets/fonts/Silkscreen-Regular.ttf"
const FONT_TITLE := "res://assets/fonts/Silkscreen-Regular.ttf"
const SFX_DB := -20.0
const VOLUME_SLIDER := preload("res://scripts/ui/volume_slider.gd")

@export var overlay_mode := false

var _volume_page: Control
var _controls_page: Control
var _volume_tab: Button
var _controls_tab: Button
var _key_buttons: Dictionary = {}
var _rebinding_action := ""
var _rebinding_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_volume_page = $Panel/Content/VolumePage
	_controls_page = $Panel/Content/ControlsPage
	_volume_tab = $Panel/Tabs/VolumeTab
	_controls_tab = $Panel/Tabs/ControlsTab

	_style_button($Panel/Back, false)
	_style_button($Panel/Tabs/VolumeTab, true)
	_style_button($Panel/Tabs/ControlsTab, false)

	$Panel/Back.pressed.connect(_on_back_pressed)
	$Panel/Back.focus_entered.connect(func() -> void: _play_ui(&"ui_move"))
	$Panel/Back.mouse_entered.connect(func() -> void: _play_ui(&"ui_move"))
	_volume_tab.pressed.connect(func() -> void: _show_page(true))
	_controls_tab.pressed.connect(func() -> void: _show_page(false))
	_volume_tab.focus_entered.connect(func() -> void: _play_ui(&"ui_move"))
	_controls_tab.focus_entered.connect(func() -> void: _play_ui(&"ui_move"))

	_build_volume_page()
	_build_controls_page()
	_show_page(true)
	$Panel/Back.grab_focus()


func _play_ui(id: StringName) -> void:
	var base := -9.0 if id == &"ui_confirm" else -10.0
	Sfx.play(id, SFX_DB - base)


func _style_button(button: Button, active := false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("202734") if not active else Color("2b3a4c")
	normal.border_color = Color("3d4a5e") if not active else Color("d7c4fe")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
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


func _show_page(volume: bool) -> void:
	_volume_page.visible = volume
	_controls_page.visible = not volume
	_style_button(_volume_tab, volume)
	_style_button(_controls_tab, not volume)


func _build_volume_page() -> void:
	for child in _volume_page.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Volume"
	title.add_theme_font_override("font", load(FONT_TITLE))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("d7c4fe"))
	_volume_page.add_child(title)

	for entry in [["master", "Main"], ["bgm", "BGM"], ["sfx", "SFX"]]:
		var kind: String = entry[0]
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 26)
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size = Vector2(52, 0)
		label.add_theme_font_override("font", load(FONT_UI))
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color("d8deea"))
		row.add_child(label)

		var slider := VOLUME_SLIDER.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.value = roundf(Game.get_volume(kind) * 100.0)
		slider.custom_minimum_size = Vector2(220, 16)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(slider)

		var value_label := Label.new()
		value_label.text = "%d%%" % int(slider.value)
		value_label.custom_minimum_size = Vector2(38, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_override("font", load(FONT_UI))
		value_label.add_theme_font_size_override("font_size", 10)
		value_label.add_theme_color_override("font_color", Color("d7c4fe"))
		row.add_child(value_label)

		slider.value_changed.connect(func(value: float) -> void:
			Game.set_volume(kind, value / 100.0)
			value_label.text = "%d%%" % int(value)
		)
		_volume_page.add_child(row)

	var reset := Button.new()
	reset.text = "Reset volumes"
	reset.custom_minimum_size = Vector2(140, 22)
	_style_button(reset)
	reset.pressed.connect(func() -> void:
		Game.set_volume("master", 0.5)
		Game.set_volume("bgm", 0.5)
		Game.set_volume("sfx", 0.5)
		_build_volume_page()
	)
	_volume_page.add_child(reset)


func _build_controls_page() -> void:
	var rows := $Panel/Content/ControlsPage/Rows
	for child in rows.get_children():
		child.queue_free()
	_key_buttons.clear()

	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_override("font", load(FONT_TITLE))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("d7c4fe"))
	rows.add_child(title)

	for action in Game.ACTIONS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 22)
		row.add_theme_constant_override("separation", 6)

		var label := Label.new()
		label.text = String(Game.ACTION_LABELS.get(action, action))
		label.custom_minimum_size = Vector2(92, 0)
		label.add_theme_font_override("font", load(FONT_UI))
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color("d8deea"))
		row.add_child(label)

		var key_button := Button.new()
		key_button.text = Game.get_action_key_text(action)
		key_button.custom_minimum_size = Vector2(80, 20)
		key_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(key_button)
		key_button.pressed.connect(_begin_rebind.bind(action, key_button))
		row.add_child(key_button)
		_key_buttons[action] = key_button

		var reset := Button.new()
		reset.text = "Reset"
		reset.custom_minimum_size = Vector2(54, 20)
		_style_button(reset)
		reset.pressed.connect(func() -> void:
			Game.reset_action(action)
			_refresh_key_buttons()
		)
		row.add_child(reset)

		rows.add_child(row)


func _begin_rebind(action: String, button: Button) -> void:
	_rebinding_action = action
	_rebinding_button = button
	button.text = "Press..."


func _refresh_key_buttons() -> void:
	for action in _key_buttons.keys():
		(_key_buttons[action] as Button).text = Game.get_action_key_text(action)


func _input(event: InputEvent) -> void:
	if _rebinding_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_rebinding_action = ""
			_refresh_key_buttons()
			get_viewport().set_input_as_handled()
			return
		if Game.bind_action(_rebinding_action, event as InputEventKey):
			_rebinding_action = ""
			_refresh_key_buttons()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _rebinding_action != "":
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _on_back_pressed() -> void:
	_play_ui(&"ui_back")
	if overlay_mode:
		closed.emit()
		queue_free()
		return
	get_tree().change_scene_to_file(MENU_SCENE)
