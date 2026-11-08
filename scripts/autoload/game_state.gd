extends Node
## 全局状态：
## - 音量设置（master / bgm / sfx，默认 50%）
## - 按键重绑定
## - 最近存档点（checkpoint）

const SETTINGS_PATH := "user://settings.cfg"
const SAVE_PATH := "user://savegame.cfg"

const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "grab"]
const ACTION_LABELS := {
	"move_left": "Left",
	"move_right": "Right",
	"move_up": "Up",
	"move_down": "Down",
	"jump": "Jump",
	"dash": "Dash",
	"grab": "Grab",
}

var volumes := {"master": 0.5, "bgm": 0.5, "sfx": 0.5}
var continue_requested := false

var _default_events: Dictionary = {}
var _key_overrides: Dictionary = {}


func _ensure_menu_navigation() -> void:
	# 菜单选项：W/S 上下移动，J 确认
	_add_key_to_action("ui_up", KEY_W)
	_add_key_to_action("ui_down", KEY_S)
	_add_key_to_action("ui_accept", KEY_J)


func _add_key_to_action(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			if key.physical_keycode == keycode or key.keycode == keycode:
				return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _ready() -> void:
	_capture_default_events()
	_ensure_menu_navigation()
	_load_settings()
	_apply_all()


func _capture_default_events() -> void:
	for action in ACTIONS:
		var copies: Array[InputEvent] = []
		for event in InputMap.action_get_events(StringName(action)):
			copies.append(event.duplicate())
		_default_events[action] = copies


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for kind in volumes.keys():
		volumes[kind] = clampf(float(cfg.get_value("volume", kind, 0.5)), 0.0, 1.0)
	for action in ACTIONS:
		var code := int(cfg.get_value("keys", action, 0))
		if code != 0:
			_key_overrides[action] = code


func _apply_all() -> void:
	_apply_volumes()
	for action in _key_overrides.keys():
		_apply_keycode(action, int(_key_overrides[action]))


func _apply_volumes() -> void:
	_set_bus_volume("Master", volumes["master"])
	_set_bus_volume("BGM", volumes["bgm"])
	_set_bus_volume("SFX", volumes["sfx"])


func _set_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	# 50% 对应原始音量 0dB，100% 为 +6dB
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value * 2.0, 0.0001)))


func set_volume(kind: String, value: float) -> void:
	if not volumes.has(kind):
		return
	volumes[kind] = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func get_volume(kind: String) -> float:
	return float(volumes.get(kind, 0.5))


func _apply_keycode(action: String, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	InputMap.action_erase_events(StringName(action))
	InputMap.action_add_event(StringName(action), event)


func bind_action(action: String, event: InputEventKey) -> bool:
	if not ACTIONS.has(action):
		return false
	var code := event.physical_keycode
	if code == 0:
		code = event.keycode
	if code == 0:
		return false
	_key_overrides[action] = code
	_apply_keycode(action, code)
	_save_settings()
	return true


func reset_action(action: String) -> void:
	if not ACTIONS.has(action) or not _default_events.has(action):
		return
	_key_overrides.erase(action)
	InputMap.action_erase_events(StringName(action))
	for event in _default_events[action]:
		InputMap.action_add_event(StringName(action), (event as InputEvent).duplicate())
	_save_settings()


func reset_all_actions() -> void:
	for action in ACTIONS:
		reset_action(action)


func get_action_key_text(action: String) -> String:
	var events := InputMap.action_get_events(StringName(action))
	if events.is_empty():
		return "—"
	var event := events[0]
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode != 0:
			return OS.get_keycode_string(key.physical_keycode)
		if key.keycode != 0:
			return OS.get_keycode_string(key.keycode)
	return event.as_text()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for kind in volumes.keys():
		cfg.set_value("volume", kind, volumes[kind])
	for action in _key_overrides.keys():
		cfg.set_value("keys", action, int(_key_overrides[action]))
	cfg.save(SETTINGS_PATH)


# ---- checkpoint ----

func save_checkpoint(pos: Vector2) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("save", "checkpoint", pos)
	cfg.save(SAVE_PATH)


func has_save() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	return cfg.has_section_key("save", "checkpoint")


func get_checkpoint() -> Vector2:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return Vector2.ZERO
	return cfg.get_value("save", "checkpoint", Vector2.ZERO)


func clear_checkpoint() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func request_continue() -> void:
	continue_requested = true


func consume_continue() -> bool:
	var value := continue_requested
	continue_requested = false
	return value
