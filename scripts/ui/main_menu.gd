extends Control
## 主菜单：播放菜单 BGM，点击/回车进入关卡。

const LEVEL_SCENE := "res://scenes/levels/level.tscn"
const MENU_BGM := "res://assets/audio/bgm/bgm_menu.ogg"
const FONT_TITLE := "res://assets/fonts/PressStart2P-Regular.ttf"
const FONT_UI := "res://assets/fonts/ark-pixel-12px-proportional-zh_hans.ttf"

var _bgm: AudioStreamPlayer
var _start_button: Button


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "MenuBgm"
	add_child(_bgm)
	var stream: AudioStream = load(MENU_BGM)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_bgm.stream = stream
	_bgm.volume_db = -9.0
	_bgm.play()
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("14171c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "PLANTFORMER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load(FONT_TITLE))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f0c25a"))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "灰盒演示 · Graybox Demo"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", load(FONT_UI))
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("8a95a7"))
	box.add_child(subtitle)

	_start_button = Button.new()
	_start_button.text = "开始游戏"
	_start_button.custom_minimum_size = Vector2(120, 28)
	_start_button.add_theme_font_override("font", load(FONT_UI))
	_start_button.add_theme_font_size_override("font_size", 12)
	_style_button(_start_button)
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.focus_entered.connect(func() -> void: Sfx.play(&"ui_move"))
	_start_button.mouse_entered.connect(func() -> void: Sfx.play(&"ui_move"))
	box.add_child(_start_button)

	var hint := Label.new()
	hint.text = "按 Enter 或点击开始"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", load(FONT_UI))
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("5f6b7d"))
	box.add_child(hint)

	_start_button.grab_focus()


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("2b3342")
	normal.border_color = Color("3a4456")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("354052")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("3a6ea5")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("e8ebf1"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))


func _on_start_pressed() -> void:
	Sfx.play(&"ui_confirm")
	get_tree().change_scene_to_file(LEVEL_SCENE)
