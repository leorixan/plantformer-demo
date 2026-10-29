extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/level.tscn")
	var lvl: Node = ps.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node2D = lvl.get_node("Player")
	var trig_ps: PackedScene = load("res://scenes/components/label_trigger.tscn")
	var trig: Node2D = trig_ps.instantiate()
	trig.set("text", "测试提示：按 K 冲刺")
	trig.set("font_size", 9)
	trig.global_position = player.global_position
	lvl.add_child(trig)
	for i in 10:
		await get_tree().physics_frame
	var ui: CanvasLayer = trig.get_node_or_null("LabelUI")
	var label: Label = trig.get_node_or_null("LabelUI/Control/Label") if ui else null
	print("LABEL ui=", ui != null, " visible=", ui.visible if ui else false, " text=", label.text if label else "none")
	get_tree().quit()
