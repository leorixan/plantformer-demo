extends Node

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/levels/graybox_template.tscn")
	var lvl: Node = ps.instantiate()
	add_child(lvl)
	await get_tree().process_frame
	var p: Node2D = lvl.get_node("Player")
	var body: ColorRect = p.get_node("Visuals/Body")
	var ui: Node2D = p.get_node("UI")
	var with_dash: Color = body.color
	p.set("dash_count", 0)
	p.call("_update_indicators")
	await get_tree().process_frame
	var no_dash: Color = body.color
	print("TEST_BODY with_dash=", with_dash, " no_dash=", no_dash, " ui_visible=", ui.visible)
	get_tree().quit()
