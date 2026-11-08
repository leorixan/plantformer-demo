extends Control
## 主菜单：
## - 背景由 Room / Bed / Bubble 三层 Sprite 组成，鼠标移动产生视差，气泡是主视差层。
## - 标题、按钮都在场景里，可直接改 Text / 位置 / 字体。
## - Continue 是否可用由是否存在最近存档点决定。

const LEVEL_SCENE := "res://scenes/levels/level.tscn"
const SETTING_SCENE := preload("res://scenes/levels/setting.tscn")
const MENU_BGM := "res://assets/audio/bgm/bgm_menu.ogg"
const FONT_UI := "res://assets/fonts/Silkscreen-Regular.ttf"
const MENU_BGM_DB := -15.0
const MENU_SFX_DB := -20.0

@export var room_strength := Vector2(6.0, 4.0)
@export var bed_strength := Vector2(4.0, 2.0)
@export var bubble_strength := Vector2(12.0, 8.0)
@export var parallax_smoothing := 8.0

var _base_room := Vector2.ZERO
var _base_bed := Vector2.ZERO
var _base_bubble := Vector2.ZERO
var _target_room := Vector2.ZERO
var _target_bed := Vector2.ZERO
var _target_bubble := Vector2.ZERO
var _time := 0.0
var _bgm: AudioStreamPlayer
var _settings_overlay: Control

@onready var _room: Node2D = $Parallax/Room
@onready var _bed: Node2D = $Parallax/Bed
@onready var _bubble: Node2D = $Parallax/Bubble
@onready var _start_button: Button = $UI/Buttons/Start
@onready var _continue_button: Button = $UI/Buttons/Continue
@onready var _settings_button: Button = $UI/Buttons/Settings
@onready var _quit_button: Button = $UI/Buttons/Quit


func _ready() -> void:
	_base_room = _room.position
	_base_bed = _bed.position
	_base_bubble = _bubble.position
	_target_room = _base_room
	_target_bed = _base_bed
	_target_bubble = _base_bubble

	_setup_buttons()
	_play_bgm()

	_start_button.grab_focus()
	set_process(true)


func _process(delta: float) -> void:
	var viewport := get_viewport_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return
	_time += delta
	var mouse := get_viewport().get_mouse_position()
	var n := (mouse / viewport - Vector2(0.5, 0.5)) * 2.0
	n.x = clampf(n.x, -1.0, 1.0)
	n.y = clampf(n.y, -1.0, 1.0)

	_target_room = _base_room - n * room_strength
	_target_bed = _base_bed - n * bed_strength
	# 气泡是主要视差层，额外加一点缓慢漂浮
	_target_bubble = _base_bubble - n * bubble_strength + Vector2(0.0, sin(_time * 0.8) * 2.0)

	var t := clampf(delta * parallax_smoothing, 0.0, 1.0)
	_room.position = _room.position.lerp(_target_room, t)
	_bed.position = _bed.position.lerp(_target_bed, t)
	_bubble.position = _bubble.position.lerp(_target_bubble, t)


func _setup_buttons() -> void:
	for button in [_start_button, _continue_button, _settings_button, _quit_button]:
		_style_button(button)
		button.focus_entered.connect(_on_button_hover.bind(button))
		button.mouse_entered.connect(_on_button_hover.bind(button))

	_continue_button.disabled = not Game.has_save()
	_start_button.pressed.connect(_on_start_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("202734")
	normal.border_color = Color("3d4a5e")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
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

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("1a1f29")
	disabled.border_color = Color("2b3342")
	button.add_theme_stylebox_override("disabled", disabled)

	button.add_theme_font_override("font", load(FONT_UI))
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("d8deea"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_focus_color", Color("d7c4fe"))
	button.add_theme_color_override("font_pressed_color", Color("10141b"))
	button.add_theme_color_override("font_disabled_color", Color("5f6b7d"))


func _on_button_hover(button: Button) -> void:
	# Continue 不可用时不播放任何音效
	if button == _continue_button and button.disabled:
		return
	_play_ui(&"ui_move")


func _play_ui(id: StringName) -> void:
	# Sfx 条目本身的基准音量：ui_move/ui_back=-10，ui_confirm=-9
	var base := -10.0
	if id == &"ui_confirm":
		base = -9.0
	Sfx.play(id, MENU_SFX_DB - base)


func _play_bgm() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "MenuBgm"
	_bgm.bus = "BGM"
	add_child(_bgm)
	var stream: AudioStream = load(MENU_BGM)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_bgm.stream = stream
	_bgm.volume_db = MENU_BGM_DB
	_bgm.play()


func _unhandled_input(event: InputEvent) -> void:
	if _settings_overlay != null:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()


func _on_start_pressed() -> void:
	_play_ui(&"ui_confirm")
	Game.clear_checkpoint()
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _on_continue_pressed() -> void:
	# Continue 不可用时直接返回，不播放任何音效
	if not Game.has_save():
		return
	_play_ui(&"ui_confirm")
	Game.request_continue()
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _on_settings_pressed() -> void:
	_play_ui(&"ui_confirm")
	if _settings_overlay != null:
		return
	_settings_overlay = SETTING_SCENE.instantiate()
	_settings_overlay.set("overlay_mode", true)
	add_child(_settings_overlay)
	_settings_overlay.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	_settings_overlay = null
	_start_button.grab_focus()


func _on_quit_pressed() -> void:
	_play_ui(&"ui_back")
	get_tree().quit()
