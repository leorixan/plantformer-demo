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
	trig.set("text", "世界坐标提示：按 K 冲刺")
	trig.set("font_size", 8)
	trig.global_position = player.global_position
	lvl.add_child(trig)
	for i in 10:
		await get_tree().physics_frame
	var holder: Node2D = trig.get_node_or_null("WorldLabel")
	var label: Label = trig.get("_label")
	print("LABEL holder=", holder != null, " class=", holder.get_class() if holder else "none",
		" visible=", holder.visible if holder else false, " text=", label.text if label else "none",
		" layer_z=", holder.z_index if holder else -1)
	get_tree().quit()
