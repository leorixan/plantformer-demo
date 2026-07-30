extends Node
class_name ConfigLoader
## 全局配置加载器：从 CSV（可用 Excel 打开编辑）读取参数，供运行时热重载。
## 挂载为 autoload "Config"；Player 等脚本在 _ready 时调用 Config.apply_to(self)。

const CONFIG_PATH := "res://documents/player_params.csv"

var _values: Dictionary = {}

func _ready() -> void:
	load_config()

## 读取 CSV；若文件不存在或解析失败，保持当前值（即回退到 @export 默认值）
func load_config() -> void:
	_values.clear()
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("ConfigLoader: 找不到配置文件 -> " + CONFIG_PATH)
		return

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("ConfigLoader: 无法打开 " + CONFIG_PATH + " err=" + str(FileAccess.get_open_error()))
		return

	var headers := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 3 or line[0].is_empty() or line[0].begins_with("#"):
			continue
		var category := line[0].strip_edges()
		var param_name := line[1].strip_edges()
		var value_str := line[2].strip_edges()
		var type_name := line[3].strip_edges() if line.size() > 3 else "float"
		var key := category + "/" + param_name
		_values[key] = _parse(value_str, type_name)
	file.close()

func _parse(value_str: String, type_name: String):
	match type_name:
		"int":
			return value_str.to_int()
		"bool":
			return value_str.to_lower() == "true"
		_:
			return value_str.to_float()

## 取单个参数；若 CSV 未定义则返回 default
func get_value(category: String, name: String, default_value: Variant) -> Variant:
	var key := category + "/" + name
	return _values.get(key, default_value)

## 将 CSV 中所有已知属性名覆盖到 target 对象（仅覆盖 target 已有的属性）
func apply_to(target: Object) -> void:
	for key in _values:
		var parts = key.split("/")
		if parts.size() != 2:
			continue
		var param_name = parts[1]
		if param_name in target:
			target.set(param_name, _values[key])

## 重新加载并重新应用到指定对象（F5 热重载用）
func reload_and_apply(target: Object) -> void:
	load_config()
	apply_to(target)
